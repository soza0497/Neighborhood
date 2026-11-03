--[[
Reglas de la RELACIÓN entre dos jugadores (Fase 5): invitar, aceptar,
noviazgo, casarse, mudarse juntos y terminar.

Igual que neighborhood_rules.lua, NO usa nada de Nakama: se prueba sola con
`lua5.1 server/tests/test_rules.lua`. El módulo neighborhood.lua lee las
relaciones de los jugadores que hacen falta, llama a estas funciones y
guarda todo junto.

Cada jugador tiene su "relación" (storage game/relation, solo la escribe el
servidor):
  status          "single" (sin pareja), "dating" (en pareja), "married" (matrimonio)
  partner_id, partner_name   con quién
  since, married_unix        desde cuándo (hora Unix del servidor)
  home_owner      "" = cada uno vive en su casa; si no, el id del jugador
                  dueño de la casa donde viven los dos (los dos tienen el mismo)
  invite_to_id, invite_to_name, invite_at   invitación que mandó (una por vez)
  invites_in      invitaciones que recibió: {from_id, from_name, at}
  proposal_kind   pedido pendiente dentro de la pareja: "" (ninguno),
                  "marry" (casarse) o "move_in" (mudarse juntos)
  proposal_by, proposal_home, proposal_at   quién lo pidió y a qué casa
  events          historial de relaciones: {at, text} (las últimas 30)
  drama           interruptor "permitir drama en mi relación" (apagado)
  family_mode     modo familiar: oculta todo el drama (prendido)
  pool_income     "unir ingresos": mi sueldo va a la caja de la casa

Las funciones reciben `rels` (id → relación, ya leídas), cambian lo que haga
falta EN EL LUGAR y devuelven una lista de avisos para mandar:
  {to = id, text = "texto para el jugador", event = "nombre"}
Si algo no se puede, llaman a refuse("texto") (igual que las reglas de la
casa) y el módulo no guarda nada.
]]

local M = {}

M.MAX_INVITES_IN = 10
M.MAX_EVENTS = 30

local function refuse(text)
  error({ refusal = text }, 0)
end
M.refuse = refuse

function M.empty()
  return {
    status = "single", partner_id = "", partner_name = "", since = 0, married_unix = 0,
    home_owner = "",
    invite_to_id = "", invite_to_name = "", invite_at = 0, invites_in = {},
    proposal_kind = "", proposal_by = "", proposal_home = "", proposal_at = 0,
    events = {},
    drama = false, family_mode = true, pool_income = false,
  }
end

-- Completa una relación leída del storage (le pueden faltar campos).
function M.normalize(rel)
  local result = M.empty()
  if type(rel) == "table" then
    for k, default in pairs(result) do
      if type(rel[k]) == type(default) then
        result[k] = rel[k]
      end
    end
  end
  -- Lua no distingue una lista vacía de un diccionario vacío.
  local invites = {}
  for _, invite in ipairs(result.invites_in) do
    if type(invite) == "table" and type(invite.from_id) == "string" then
      table.insert(invites, invite)
    end
  end
  result.invites_in = invites
  local events = {}
  for _, e in ipairs(result.events) do
    table.insert(events, e)
  end
  result.events = events
  return result
end

local function in_couple(rel)
  return rel.status == "dating" or rel.status == "married"
end
M.in_couple = in_couple

local function add_event(rel, now, text)
  table.insert(rel.events, { at = now, text = text })
  while #rel.events > M.MAX_EVENTS do
    table.remove(rel.events, 1)
  end
end

local function remove_invite_from(rel, from_id)
  for i = #rel.invites_in, 1, -1 do
    if rel.invites_in[i].from_id == from_id then
      table.remove(rel.invites_in, i)
    end
  end
end

local function has_invite_from(rel, from_id)
  for _, invite in ipairs(rel.invites_in) do
    if invite.from_id == from_id then
      return true
    end
  end
  return false
end

local function clear_proposal(rel)
  rel.proposal_kind, rel.proposal_by, rel.proposal_home, rel.proposal_at = "", "", "", 0
end

local function clear_invite_out(rel)
  rel.invite_to_id, rel.invite_to_name, rel.invite_at = "", "", 0
end


-- --- Invitaciones ---

-- Jugadores cuyas relaciones hacen falta para formar la pareja `a` + `b`
-- (además de ellos dos): a quién invitó cada uno y quién los invitó.
function M.involved_in_accept(rel_a, rel_b)
  local ids = {}
  for _, rel in ipairs({ rel_a, rel_b }) do
    if rel.invite_to_id ~= "" then
      ids[rel.invite_to_id] = true
    end
    for _, invite in ipairs(rel.invites_in) do
      ids[invite.from_id] = true
    end
  end
  return ids
end

-- Arma la pareja: los dos pasan a "en pareja" y se limpian TODAS las
-- invitaciones de los dos (las que mandaron y las que recibieron).
-- `rels` tiene que traer a los involucrados (involved_in_accept).
local function form_couple(rels, a, b, names, now)
  for _, id in ipairs({ a, b }) do
    local rel = rels[id]
    if rel.invite_to_id ~= "" and rels[rel.invite_to_id] ~= nil then
      remove_invite_from(rels[rel.invite_to_id], id)
    end
    clear_invite_out(rel)
    for _, invite in ipairs(rel.invites_in) do
      local sender = rels[invite.from_id]
      if sender ~= nil and sender.invite_to_id == id then
        clear_invite_out(sender)
      end
    end
    rel.invites_in = {}
  end
  for _, pair in ipairs({ { a, b }, { b, a } }) do
    local rel = rels[pair[1]]
    rel.status = "dating"
    rel.partner_id = pair[2]
    rel.partner_name = names[pair[2]] or ""
    rel.since = now
    rel.married_unix = 0
    rel.home_owner = ""
    clear_proposal(rel)
    rel.drama = false
    rel.pool_income = false
    add_event(rel, now, "Empezó a salir con " .. rel.partner_name)
  end
  return {
    { to = a, event = "accepted", text = string.format("¡%s aceptó! Ahora son pareja.", names[b] or "") },
    { to = b, event = "accepted", text = string.format("Ahora sos pareja de %s.", names[a] or "") },
  }
end

-- `me` invita a `target`. `names` = id → nombre de usuario.
-- Si `target` ya había invitado a `me`, se acepta directamente (hace falta
-- que `rels` traiga a los involucrados en ese caso).
function M.invite(rels, me, target, names, now)
  local mine, theirs = rels[me], rels[target]
  if target == me then
    refuse("No podés invitarte a vos.")
  elseif in_couple(mine) then
    refuse("Ya estás en pareja.")
  elseif in_couple(theirs) then
    refuse(string.format("%s ya está en pareja.", names[target] or ""))
  end
  if theirs.invite_to_id == me then
    return form_couple(rels, me, target, names, now)
  end
  if mine.invite_to_id ~= "" then
    refuse(string.format("Ya invitaste a %s: esperá su respuesta o cancelala.", mine.invite_to_name))
  elseif #theirs.invites_in >= M.MAX_INVITES_IN then
    refuse(string.format("%s tiene demasiadas invitaciones sin responder.", names[target] or ""))
  end
  mine.invite_to_id, mine.invite_to_name, mine.invite_at = target, names[target] or "", now
  remove_invite_from(theirs, me)
  table.insert(theirs.invites_in, { from_id = me, from_name = names[me] or "", at = now })
  return { { to = target, event = "invite", text = string.format("%s te invitó a ser su pareja.", names[me] or "") } }
end

-- `me` retira la invitación que mandó.
function M.cancel_invite(rels, me)
  local mine = rels[me]
  if mine.invite_to_id == "" then
    refuse("No mandaste ninguna invitación.")
  end
  local target = mine.invite_to_id
  if rels[target] ~= nil then
    remove_invite_from(rels[target], me)
  end
  clear_invite_out(mine)
  return { { to = target, event = "invite_cancelled", text = "" } }
end

-- `me` responde la invitación de `from`. `rels` tiene que traer a los
-- involucrados (involved_in_accept) si acepta.
function M.answer_invite(rels, me, from, accept, names, now)
  local mine, theirs = rels[me], rels[from]
  if not has_invite_from(mine, from) then
    refuse("Esa invitación ya no existe.")
  end
  if not accept then
    remove_invite_from(mine, from)
    if theirs.invite_to_id == me then
      clear_invite_out(theirs)
    end
    return { { to = from, event = "rejected", text = string.format("%s no aceptó la invitación.", names[me] or "") } }
  end
  if theirs.invite_to_id ~= me or in_couple(theirs) then
    remove_invite_from(mine, from)
    refuse("Esa invitación ya no vale.")
  elseif in_couple(mine) then
    refuse("Ya estás en pareja.")
  end
  return form_couple(rels, from, me, names, now)
end


-- --- Pedidos dentro de la pareja: casarse y mudarse ---

-- `kind` = "marry" o "move_in". Para mudarse, `home` = "mine" (a mi casa)
-- o "yours" (a la casa de mi pareja).
function M.propose(rels, me, kind, home, now)
  local mine = rels[me]
  if not in_couple(mine) then
    refuse("Primero tienen que ser pareja.")
  end
  local partner = rels[mine.partner_id]
  if mine.proposal_kind ~= "" then
    refuse("Ya hay un pedido esperando respuesta.")
  end
  local owner = ""
  if kind == "marry" then
    if mine.status == "married" then
      refuse("Ya son matrimonio.")
    end
  elseif kind == "move_in" then
    if mine.home_owner ~= "" then
      refuse("Ya viven juntos.")
    end
    if home == "mine" then
      owner = me
    elseif home == "yours" then
      owner = mine.partner_id
    else
      refuse("¿A qué casa se mudan?")
    end
  else
    refuse("Pedido desconocido.")
  end
  for _, rel in ipairs({ mine, partner }) do
    rel.proposal_kind, rel.proposal_by, rel.proposal_home, rel.proposal_at = kind, me, owner, now
  end
  local text
  if kind == "marry" then
    text = string.format("%s te pidió casamiento.", partner.partner_name)
  elseif owner == me then
    text = string.format("%s te invita a vivir en su casa.", partner.partner_name)
  else
    text = string.format("%s quiere mudarse a tu casa.", partner.partner_name)
  end
  return { { to = mine.partner_id, event = "proposal", text = text } }
end

-- `me` responde el pedido pendiente. Quien lo hizo solo puede retirarlo
-- (accept = false). Devuelve los avisos y, si se mudaron, el dueño de la casa.
function M.respond(rels, me, accept, now)
  local mine = rels[me]
  if not in_couple(mine) or mine.proposal_kind == "" then
    refuse("No hay ningún pedido esperando.")
  end
  local partner_id = mine.partner_id
  local partner = rels[partner_id]
  local kind, owner = mine.proposal_kind, mine.proposal_home
  local by_me = mine.proposal_by == me
  if by_me and accept then
    refuse("Tu pareja tiene que responder.")
  end
  clear_proposal(mine)
  clear_proposal(partner)
  if not accept then
    local text = by_me and "" or string.format("%s dijo que no, por ahora.", partner.partner_name)
    return { { to = partner_id, event = by_me and "proposal_cancelled" or "proposal_rejected", text = text } }, nil
  end
  local moved
  if kind == "marry" then
    for _, rel in ipairs({ mine, partner }) do
      rel.status = "married"
      rel.married_unix = now
      add_event(rel, now, "Se casó con " .. rel.partner_name)
    end
  else
    for _, rel in ipairs({ mine, partner }) do
      rel.home_owner = owner
    end
    local owner_name = owner == me and partner.partner_name or mine.partner_name
    add_event(mine, now, "Se mudaron juntos a la casa de " .. owner_name)
    add_event(partner, now, "Se mudaron juntos a la casa de " .. owner_name)
    moved = owner
  end
  local text = kind == "marry" and string.format("¡%s aceptó! Ahora son matrimonio.", partner.partner_name)
    or string.format("¡%s aceptó! Ahora viven juntos.", partner.partner_name)
  return { { to = partner_id, event = kind == "marry" and "married" or "moved_in", text = text } }, moved
end

-- `me` termina la relación (no hace falta que la otra persona acepte).
-- Devuelve los avisos y el dueño de la casa que compartían ("" si no).
function M.end_relation(rels, me, now)
  local mine = rels[me]
  if not in_couple(mine) then
    refuse("No estás en pareja.")
  end
  local partner_id = mine.partner_id
  local partner = rels[partner_id]
  local shared_owner = mine.home_owner
  for _, rel in ipairs({ mine, partner }) do
    add_event(rel, now, "Terminó con " .. rel.partner_name)
    rel.status = "single"
    rel.partner_id, rel.partner_name = "", ""
    rel.since, rel.married_unix = 0, 0
    rel.home_owner = ""
    clear_proposal(rel)
    rel.drama = false
    rel.pool_income = false
  end
  return { { to = partner_id, event = "ended", text = "Tu pareja terminó la relación." } }, shared_owner
end

-- Interruptores de `me`: drama, modo familiar, unir ingresos (solo los
-- que vengan en `changes`).
function M.set_switches(rel, changes)
  for _, name in ipairs({ "drama", "family_mode", "pool_income" }) do
    if type(changes[name]) == "boolean" then
      rel[name] = changes[name]
    end
  end
  if rel.pool_income and rel.home_owner == "" then
    rel.pool_income = false
    refuse("Unir ingresos es para cuando viven juntos.")
  end
end

-- ¿Hay drama en esta pareja? Solo si los DOS lo permiten y ninguno tiene
-- el modo familiar. (Todavía no hay drama en el juego: es el interruptor.)
function M.drama_enabled(mine, partner)
  return in_couple(mine) and mine.drama and not mine.family_mode
    and partner ~= nil and partner.drama and not partner.family_mode
end

-- Lo que el teléfono necesita saber de la relación.
function M.summary(mine, partner, me)
  local invites = {}
  for _, invite in ipairs(mine.invites_in) do
    table.insert(invites, { from_id = invite.from_id, from_name = invite.from_name, at = invite.at })
  end
  return {
    status = mine.status,
    partner_id = mine.partner_id,
    partner_name = mine.partner_name,
    since = mine.since,
    married_unix = mine.married_unix,
    home_owner = mine.home_owner,
    shared = mine.home_owner ~= "",
    invite_to_name = mine.invite_to_name,
    invites_in = invites,
    proposal_kind = mine.proposal_kind,
    proposal_by_me = mine.proposal_kind ~= "" and mine.proposal_by == me,
    proposal_home_is_mine = mine.proposal_home == me,
    events = mine.events,
    drama = mine.drama,
    family_mode = mine.family_mode,
    pool_income = mine.pool_income,
    partner_drama = partner ~= nil and partner.drama or false,
    partner_pool_income = partner ~= nil and partner.pool_income or false,
    drama_enabled = M.drama_enabled(mine, partner),
  }
end

return M
