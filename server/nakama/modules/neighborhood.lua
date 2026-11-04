--[[
Código del servidor del juego (Nakama, runtime Lua).

Desde la Fase 4B el servidor MANDA en el dinero y la propiedad: el teléfono
pide y el servidor decide (precios, nivel, obras, deshacer, empleos, turnos).
Desde la Fase 5 también manda en la PAREJA y la CASA COMPARTIDA: relación,
permisos (cambios menores al instante, estructurales con aprobación), caja de
la casa, historial y reglas de apoyo de la casa (nada "en el aire").
Las reglas están en archivos aparte, sin nada de Nakama (se prueban solas):
  neighborhood_rules.lua   dinero, obras, deshacer, empleos, caja, historial
  neighborhood_house.lua   reglas de apoyo y permisos de la casa
  neighborhood_couple.lua  la relación entre dos jugadores
Este archivo lee y guarda el estado de cada jugador, registra las funciones
(RPC) que llama el teléfono y manda los avisos en tiempo real.

RPC (el teléfono las llama con GameServer.call_rpc):
  game_load        todo lo que el teléfono necesita al entrar
  game_import      la primera vez: copia la partida del teléfono (y, una sola
                   vez, re-sincroniza las cuentas importadas en la 4A)
  build_apply      construir / quitar / mover / pintar  {writes}
                   (en la casa compartida, un cambio estructural se guarda
                   como PEDIDO para que lo apruebe la pareja)
  build_undo       deshacer el último paso propio (devuelve lo cobrado)
  build_redo       rehacer
  build_accelerate terminar todas las obras pagando
  job_apply, job_status, job_accelerate, job_quit   empleos
  shift_start, shift_complete                       turnos
  work_settle      al entrar: turno a medias + pago por días sin jugar
  game_heartbeat   "sigo jugando" (para no pagar offline lo que se jugó)
  -- Fase 5: pareja y casa compartida --
  couple_load      relación, pareja (su personaje) y hogar (caja, pedidos, historial)
  couple_invite    {username}  invitar a alguien a ser pareja
  couple_cancel    retirar la invitación mandada
  couple_answer    {from_id, accept}  responder una invitación
  couple_propose   {kind = "marry" | "move_in", home = "mine" | "yours"}
  couple_respond   {accept}  responder (o retirar) el pedido de la pareja
  couple_end       terminar la relación
  couple_switches  {drama?, family_mode?, pool_income?}
  home_load        la casa donde vive (para ponerse al día) + hogar
  home_answer      {id, approve}  aprobar o rechazar un pedido estructural
  home_cancel      {id}  retirar un pedido propio
  home_request     {id}  las piezas de un pedido, para previsualizarlo
                   (Pulido 1: la remodelación se manda entera como propuesta)
  home_revert      {id}  deshacer un cambio menor del historial
  home_contribute  {amount}  poner dinero en la caja de la casa
  -- Fase 6: el restaurante (reglas en neighborhood_business.lua) --
  restaurant_load     estado del restaurante (qué falta, caja, tope del día)
  restaurant_open     abrir el restaurante (en la casa compartida: pedido)
  restaurant_close    cerrarlo (en la casa compartida: pedido)
  restaurant_collect  cobrar lo que juntó solo (clientes de paso, con tope)
  service_start       empezar el minijuego: el servidor da la semilla
  service_finish      {actions}  los toques del jugador; el servidor repite
                      el servicio y paga lo que calcula él (tope diario)
  -- Fase 8D: meta del barrio por participación (neighborhood_goals.lua) --
  goal_load           la meta: el servidor cuenta las plantas de TU casa y acredita
                      (tope diario); los vecinos aportan un valor simulado
  goal_claim          retirar la recompensa (opcional, una sola vez)

Toda respuesta es {ok, error?, state, ...}. ok = false con un texto para el
jugador cuando una regla no lo deja (no alcanza el dinero, nivel...).

Dónde se guarda cada cosa (storage de Nakama, por usuario):
  game/house      casa (texto JSON)                (solo el servidor la escribe)
  game/home       hogar de esa casa: caja, historial, pedidos, quién vive (texto JSON)
  game/progress   experiencia y descubierto         (solo el servidor)
  game/work       empleo, currículum y turnos       (solo el servidor)
  game/history    pasos de deshacer propios (texto JSON, con la casa a la que
                  pertenecen)                       (solo el servidor)
  game/relation   relación con la pareja            (solo el servidor)
  game/business   servicio en marcha y tope diario del restaurante (solo el servidor)
  game/goal       aporte del jugador a la meta del barrio  (solo el servidor)
  cloud/character personaje                         (lo escribe el teléfono)
  cloud/settings  opciones del menú                 (lo escribe el teléfono)
  wallet "coins"  dinero (billetera de Nakama, con historial de movimientos)
Si dos viven juntos, la casa y el hogar que usan son los del DUEÑO de la
casa (relation.home_owner). La casa propia del otro queda guardada, sin
tocar, y vuelve si se separan.

Avisos en tiempo real (notificaciones de Nakama, por el socket):
  101  cambió la relación (invitación, aceptó, pedido, se mudaron, terminó)
  103  cambió el hogar (la casa, la caja o el historial): {rev, entry_id, text, kind}
  104  cambiaron los pedidos de aprobación: {text}
El teléfono, al recibirlos, vuelve a pedir lo que corresponda (couple_load
o home_load): el aviso solo dice "algo cambió", la verdad está aquí.

Casa e historial viajan como TEXTO JSON (campo "json"): Lua no distingue
una lista vacía de un diccionario vacío, y así llegan al teléfono idénticos.

Después de cambiar este archivo: docker compose restart nakama
]]

local nk = require("nakama")
local rules = require("neighborhood_rules")
local house_rules = require("neighborhood_house")
local couple = require("neighborhood_couple")
local business = require("neighborhood_business")
local parcel = require("neighborhood_parcel")
local goals = require("neighborhood_goals")

local STARTING_MONEY = 3000
local GAME = "game"
local CLOUD = "cloud"
-- Tamaño máximo de un texto guardado (una casa grande ocupa ~100 KB).
local MAX_TEXT = 512 * 1024
-- Experiencia máxima que se acepta al importar (más que esto es un error).
local MAX_XP = 10000000
-- Si dos pedidos chocan al guardar (por ejemplo, los dos de la pareja a la
-- vez), se reintenta.
local SAVE_ATTEMPTS = 6
-- Cuántas entradas del historial se mandan al teléfono.
local LOG_TO_PHONE = 30

-- Códigos de los avisos en tiempo real.
local NOTIFY_COUPLE = 101
local NOTIFY_HOME = 103
local NOTIFY_REQUESTS = 104

-- Permisos de lectura y escritura del storage de Nakama.
local READ_OWNER = 1
local WRITE_NONE = 0
local WRITE_OWNER = 1


-- Lee un archivo JSON de la carpeta data/ del juego (montada en game_data/).
local function read_game_data(file_name)
  local ok, content = pcall(nk.file_read, "game_data/" .. file_name)
  if not ok then
    nk.logger_error("No se pudo leer game_data/" .. file_name .. ": " .. tostring(content))
    return {}
  end
  return nk.json_decode(content)
end

-- Los mismos datos del juego: precios, niveles y empleos en un solo lugar.
local data = rules.new_data(read_game_data("catalog.json"), read_game_data("progression.json"),
  read_game_data("jobs.json"))
local item_count, job_count = 0, 0
for _ in pairs(data.items) do item_count = item_count + 1 end
for _ in pairs(data.jobs) do job_count = job_count + 1 end
nk.logger_info(string.format("Catálogo del juego leído: %d piezas, %d empleos, %d niveles",
  item_count, job_count, #data.levels))
-- Fase 6: el restaurante (data/business.json, el mismo que lee el juego).
local restaurant = business.new_config(read_game_data("business.json"))
nk.logger_info(string.format("Restaurante: servicio de %d s, tope diario $%d",
  restaurant.service.duration_ms / 1000, restaurant.daily_cap))
-- Pulido 2C: la parcela y sus obstáculos (data/parcel.json, el mismo del juego).
local parcel_cfg = read_game_data("parcel.json")
local parcel_cache = {}
-- Fase 8D: la meta del barrio (data/neighborhood.json, sección "goal").
local goal_cfg = goals.new_config(read_game_data("neighborhood.json"))
nk.logger_info(string.format("Meta del barrio: %s (%d), tope diario %d", goal_cfg.name, goal_cfg.target, goal_cfg.daily_cap))
nk.logger_info(string.format("Parcela: %d x %d celdas, %d tipos de obstáculo", parcel_cfg.lot or 0, parcel_cfg.lot or 0,
  #(parcel_cfg.order or {})))

-- Los obstáculos de la parcela del dueño de la casa (se generan de su id y se
-- guardan en memoria: son siempre los mismos).
local function parcel_obstacles(owner_id)
  local seed = parcel.seed_from_text(owner_id)
  if parcel_cache[seed] == nil then
    local size = 0
    for _ in pairs(parcel_cache) do size = size + 1 end
    if size > 40 then
      parcel_cache = {}
    end
    local started = os.clock()
    parcel_cache[seed] = parcel.generate(parcel_cfg, seed)
    nk.logger_info(string.format("Parcela generada: %d obstáculos en %.0f ms", #parcel_cache[seed], (os.clock() - started) * 1000))
  end
  return parcel_cache[seed], seed
end

-- Pulido 3A: celdas bloqueadas = obstáculos sin limpiar + zona todavía cerrada
-- (se abre por nivel, data/parcel.json "unlocks"). Se guardan las celdas de
-- cada nivel de zona porque son siempre las mismas.
local locked_cache = {}
local function parcel_locked(level)
  if locked_cache[level] == nil then
    locked_cache[level] = parcel.locked_cells(parcel_cfg, level)
  end
  return locked_cache[level]
end

local function parcel_blocked(state, obstacles, cleared)
  return (parcel.blocked_cells(obstacles, cleared, parcel_locked(rules.level_for_xp(data, state.xp))))
end

-- Lo que el hogar guarda de la parcela: limpiados, en camino y cuántos van.
local function parcel_state(state)
  local p = state.home.parcel
  if type(p.cleared) ~= "table" then p.cleared = {} end
  if type(p.pending) ~= "table" then p.pending = {} end
  p.count = math.floor(rules.num(p.count) or 0)
  return p
end

-- Semillas de los servicios: al azar (cada máquina de Lua empieza distinto).
math.randomseed(nk.time())


local function now_unix()
  return math.floor(nk.time() / 1000)
end

local function require_user(context)
  if context.user_id == nil or context.user_id == "" then
    error("Hace falta iniciar sesión")
  end
  return context.user_id
end

-- Un texto JSON que mandó el teléfono, o "" si no sirve.
local function clean_text(value)
  if type(value) ~= "string" or #value > MAX_TEXT then
    return ""
  end
  return value
end

local function decode_text(text)
  if type(text) ~= "string" or text == "" then
    return nil
  end
  local ok, value = pcall(nk.json_decode, text)
  return ok and type(value) == "table" and value or nil
end

local function decode_payload(payload)
  if payload == nil or payload == "" then
    return {}
  end
  local ok, decoded = pcall(nk.json_decode, payload)
  if not ok or type(decoded) ~= "table" then
    error("Pedido inválido")
  end
  return decoded
end

-- Lee objetos de UN usuario. Devuelve "colección/clave" → objeto (con versión).
local function read_objects(user_id, keys)
  local reads = {}
  for _, k in ipairs(keys) do
    table.insert(reads, { collection = k[1], key = k[2], user_id = user_id })
  end
  local result = {}
  for _, object in ipairs(nk.storage_read(reads)) do
    result[object.collection .. "/" .. object.key] = object
  end
  return result
end

local function value_of(objects, name)
  local object = objects[name]
  return object and object.value or nil
end

-- Escritura de storage "solo si nadie lo cambió desde que se leyó"
-- (versión leída, o "*" = no existía).
local function versioned_write(objects, user_id, collection, key, value)
  local object = objects[collection .. "/" .. key]
  return {
    collection = collection, key = key, user_id = user_id, value = value,
    permission_read = READ_OWNER, permission_write = WRITE_NONE,
    version = object and object.version or "*",
  }
end

-- Dinero de la billetera de un usuario.
local function wallet_coins(user_id)
  local account = nk.account_get_id(user_id)
  local wallet = account.wallet or {}
  if type(wallet) == "string" then
    wallet = nk.json_decode(wallet)
  end
  return math.floor(rules.num(wallet.coins) or 0)
end

local function discovered_list(set)
  local list = {}
  for id in pairs(set) do
    table.insert(list, id)
  end
  table.sort(list)
  return list
end

-- Manda avisos en tiempo real. Si alguno falla, no importa: el teléfono se
-- pone al día igual la próxima vez que pregunta.
-- `list` = {{to, code, content}}.
local function send_notifications(list, sender_id)
  for _, n in ipairs(list or {}) do
    if n.to ~= nil and n.to ~= "" and n.to ~= sender_id then
      local ok, err = pcall(nk.notification_send, n.to, n.subject or "neighborhood", n.content or {}, n.code,
        sender_id, false)
      if not ok then
        nk.logger_warn("No se pudo mandar un aviso: " .. tostring(err))
      end
    end
  end
end

-- Corre `fn` y, si al guardar chocó con otro pedido (la versión cambió), lo
-- vuelve a correr desde el principio (con lo que haya ahora).
local function with_retries(fn)
  for attempt = 1, SAVE_ATTEMPTS do
    local ok, result = pcall(fn)
    if ok then
      return result
    end
    if type(result) == "table" then
      error(result)  -- Un rechazo (refuse) que no se atrapó: lo maneja quien llama.
    end
    if not string.find(tostring(result), "version check failed", 1, true) or attempt == SAVE_ATTEMPTS then
      error(result)
    end
  end
end


-- --- Estado del jugador: leer y guardar ---

local OWN_KEYS = {
  { GAME, "house" }, { GAME, "home" }, { GAME, "progress" }, { GAME, "work" }, { GAME, "history" },
  { GAME, "relation" }, { GAME, "business" }, { GAME, "goal" },
}
local HOME_KEYS = { { GAME, "house" }, { GAME, "home" } }

-- Lee todo lo que el servidor guarda del jugador, y la casa y el hogar
-- donde vive (los suyos, o los del dueño si vive en la casa de su pareja).
local function load_state(user_id)
  local objects = read_objects(user_id, OWN_KEYS)
  local relation = couple.normalize(value_of(objects, "game/relation"))
  local owner_id = relation.home_owner ~= "" and relation.home_owner or user_id
  local home_objects = objects
  if owner_id ~= user_id then
    home_objects = read_objects(owner_id, HOME_KEYS)
  end
  local house_object = value_of(home_objects, "game/house") or {}
  local home = rules.normalize_home(decode_text((value_of(home_objects, "game/home") or {}).json), owner_id)
  local progress = value_of(objects, "game/progress")
  local history_object = value_of(objects, "game/history") or {}
  local history = decode_text(history_object.json) or {}
  -- El historial de deshacer es de UNA casa: si ahora vive en otra, empieza vacío.
  if (history_object.home or user_id) ~= owner_id then
    history = {}
  end
  local shared = relation.home_owner ~= ""
  local state = {
    user_id = user_id,
    actor = user_id,
    objects = objects,
    home_objects = home_objects,
    owner_id = owner_id,
    relation = relation,
    shared = shared,
    home = home,
    imported = progress ~= nil,
    house_source = house_object.source or "",
    house = rules.normalize_house(decode_text(house_object.json)),
    money = wallet_coins(user_id),
    fund = shared and home.fund or nil,
    pool_income = relation.pool_income,
    others = {},
    xp = math.floor(rules.num(progress and progress.xp) or 0),
    discovered = {},
    work = rules.normalize_work(value_of(objects, "game/work")),
    business = business.normalize_record(value_of(objects, "game/business")),
    goal = goals.normalize_record(value_of(objects, "game/goal"), goal_cfg),
    history = { undo = history.undo or {}, redo = history.redo or {} },
    imported_unix = progress and progress.imported_unix or 0,
    check_support = true,
    notify = {},
  }
  for _, id in ipairs(progress and progress.discovered or {}) do
    state.discovered[id] = true
  end
  state.start_money = state.money
  state.start_fund = state.fund
  state.start_xp = state.xp
  -- Pulido 2C: lo que no se limpió bloquea construir (reglas de apoyo).
  house_rules.blocked_cells = parcel_blocked(state, parcel_obstacles(owner_id), parcel_state(state).cleared)
  return state
end

-- Carga el dinero de otro jugador que este cambio toca.
local function load_other_money(state, user_id)
  if user_id ~= state.actor and state.others[user_id] == nil then
    state.others[user_id] = wallet_coins(user_id)
    state.others_start = state.others_start or {}
    state.others_start[user_id] = state.others[user_id]
  end
end

local function home_value(state)
  if state.fund ~= nil then
    state.home.fund = state.fund
  end
  return { json = nk.json_encode(state.home) }
end

-- Guarda lo que cambió (`changed` = {house = true, ...}) y el dinero, TODO
-- JUNTO: o se guarda todo o nada (multi_update de Nakama).
local function save_state(state, changed, reason)
  local writes = {}
  if state.fund ~= state.start_fund then
    changed.home = true
  end
  if changed.house then
    table.insert(writes, versioned_write(state.home_objects, state.owner_id, GAME, "house",
      { json = nk.json_encode(state.house), saved_unix = now_unix(), source = "server" }))
  end
  if changed.home then
    table.insert(writes, versioned_write(state.home_objects, state.owner_id, GAME, "home", home_value(state)))
  end
  if changed.progress then
    table.insert(writes, versioned_write(state.objects, state.user_id, GAME, "progress",
      { xp = state.xp, discovered = discovered_list(state.discovered), imported_unix = state.imported_unix }))
  end
  if changed.work then
    table.insert(writes, versioned_write(state.objects, state.user_id, GAME, "work", state.work))
  end
  if changed.business then
    table.insert(writes, versioned_write(state.objects, state.user_id, GAME, "business", state.business))
  end
  if changed.goal then
    table.insert(writes, versioned_write(state.objects, state.user_id, GAME, "goal", state.goal))
  end
  if changed.history then
    table.insert(writes, versioned_write(state.objects, state.user_id, GAME, "history",
      { json = nk.json_encode({ undo = state.history.undo, redo = state.history.redo }), home = state.owner_id }))
  end
  local wallets = {}
  local money_change = state.money - state.start_money
  if money_change ~= 0 then
    table.insert(wallets, { user_id = state.user_id, changeset = { coins = money_change },
      metadata = { reason = reason } })
  end
  for user_id, coins in pairs(state.others) do
    local change = coins - state.others_start[user_id]
    if change ~= 0 then
      table.insert(wallets, { user_id = user_id, changeset = { coins = change },
        metadata = { reason = reason, by = state.actor } })
    end
  end
  if #writes > 0 or #wallets > 0 then
    nk.multi_update(nil, writes, nil, wallets, true)
  end
end

-- Lo que el teléfono necesita saber después de cada pedido.
local function summary(state)
  local work = state.work
  return {
    money = state.money,
    xp = state.xp,
    level = rules.level_for_xp(data, state.xp),
    discovered = discovered_list(state.discovered),
    job = {
      job_id = work.job_id,
      applied_job = work.applied_job,
      resume_ready_at = work.resume_ready_at,
      shift_active = work.shift_started_unix > 0,
      shift_started_unix = work.shift_started_unix,
      last_shift_unix = work.last_shift_unix,
    },
    can_undo = #state.history.undo > 0,
    can_redo = #state.history.redo > 0,
    server_unix = now_unix(),
    -- Fase 5
    house_rev = state.home.rev,
    shared = state.shared,
    home_owner = state.owner_id,
    fund = state.fund or 0,
    pool_income = state.shared and state.relation.pool_income or false,
    requests = #state.home.requests,
    -- Fase 6
    restaurant_open = business.is_open(state.home),
  }
end

-- El hogar para el teléfono: caja, quién vive, pedidos e historial (sin las
-- piezas guardadas, que son muchas), con "se puede deshacer" ya calculado.
local function home_summary(state)
  local me = state.actor
  local requests = {}
  for _, r in ipairs(state.home.requests) do
    table.insert(requests, { id = r.id, by_me = r.by == me, by_name = r.by_name, at = r.at, text = r.text,
      cost = r.cost, business = r.business })
  end
  local log = {}
  local first = math.max(1, #state.home.log - LOG_TO_PHONE + 1)
  for i = #state.home.log, first, -1 do
    local e = state.home.log[i]
    table.insert(log, { id = e.id, rev = e.rev, by_me = e.by == me, by_name = e.by_name, at = e.at,
      kind = e.kind, text = e.text, reverted = e.reverted, can_revert = rules.can_revert(state, e) })
  end
  return {
    rev = state.home.rev,
    shared = state.shared,
    owner_id = state.owner_id,
    owner_is_me = state.owner_id == me,
    fund = state.fund or 0,
    requests = requests,
    log = log,
  }
end

local function encode_history(steps)
  return nk.json_encode(steps)
end

-- El otro que vive en la casa (si la comparten).
local function housemate(state)
  if not state.shared then
    return ""
  end
  return state.relation.partner_id
end

-- Avisa a la pareja que el hogar cambió.
local function notify_home(state, entry)
  local mate = housemate(state)
  if mate ~= "" then
    table.insert(state.notify, { to = mate, code = NOTIFY_HOME, content = {
      rev = state.home.rev, entry_id = entry and entry.id or 0, kind = entry and entry.kind or "",
      text = entry and entry.text or "", by_name = entry and entry.by_name or "",
      can_revert = entry ~= nil and entry.kind == "minor" and entry.writes ~= nil,
    } })
  end
end

-- Anota en el historial y avisa a la pareja.
local function log_and_notify(state, entry)
  entry.by = entry.by or state.actor
  entry.by_name = entry.by_name or state.username or ""
  entry.at = entry.at or now_unix()
  rules.log_entry(state.home, entry)
  notify_home(state, entry)
  return entry
end

-- Respuesta de un rechazo (refuse) con el estado actual.
local function refusal_answer(user_id, outcome)
  return nk.json_encode({ ok = false, error = outcome.refusal, reason = outcome.reason,
    seconds_left = outcome.seconds_left, state = summary(load_state(user_id)) })
end

-- Arma un RPC del juego: lee el estado, corre la regla `action` y guarda.
-- `action(state, input, now)` devuelve {changed = {...}, result}.
-- Si la regla dice que no (rules.refuse), responde ok = false y no guarda.
-- Si otro pedido guardó en el medio, vuelve a empezar (con lo nuevo: así,
-- en los cambios menores, gana la última escritura).
local function game_rpc(name, action)
  return function(context, payload)
    local user_id = require_user(context)
    local input = decode_payload(payload)
    local ok, answer = pcall(with_retries, function()
      local state = load_state(user_id)
      state.username = context.username
      if not state.imported then
        return { ok = false, error = "La partida todavía no se cargó en el servidor." }
      end
      local outcome = action(state, input, now_unix())
      save_state(state, outcome.changed or {}, name)
      send_notifications(state.notify, user_id)
      local result = outcome.result or {}
      result.ok = true
      result.state = summary(state)
      return result
    end)
    if ok then
      return nk.json_encode(answer)
    end
    if type(answer) == "table" and answer.refusal ~= nil then
      return refusal_answer(user_id, answer)
    end
    error(answer)
  end
end


-- --- Relación y pareja ---

-- Lee las relaciones de varios usuarios. Devuelve (id → relación, id → objeto).
local function load_relations(ids)
  local reads = {}
  for id in pairs(ids) do
    table.insert(reads, { collection = GAME, key = "relation", user_id = id })
  end
  local objects, rels = {}, {}
  for _, object in ipairs(nk.storage_read(reads)) do
    objects[object.user_id] = object
  end
  for id in pairs(ids) do
    rels[id] = couple.normalize(objects[id] and objects[id].value)
  end
  return rels, objects
end

local function relation_writes(rels, objects)
  local writes = {}
  for id, rel in pairs(rels) do
    local object = objects[id]
    table.insert(writes, {
      collection = GAME, key = "relation", user_id = id, value = rel,
      permission_read = READ_OWNER, permission_write = WRITE_NONE,
      version = object and object.version or "*",
    })
  end
  return writes
end

-- Lo que el teléfono necesita de la pareja: su nombre, su personaje (para
-- animarlo en la casa compartida) y la relación.
local function partner_profile(rel)
  if not couple.in_couple(rel) then
    return {}
  end
  local cloud = read_objects(rel.partner_id, { { CLOUD, "character" } })
  local character = value_of(cloud, "cloud/character") or {}
  return { user_id = rel.partner_id, username = rel.partner_name, character = character.json or "",
    character_saved_unix = character.saved_unix or 0 }
end

-- Todo lo de la pareja y el hogar (couple_load y game_load).
local function couple_answer(state)
  local partner_rel
  if couple.in_couple(state.relation) then
    partner_rel = load_relations({ [state.relation.partner_id] = true })[state.relation.partner_id]
  end
  return {
    couple = couple.summary(state.relation, partner_rel, state.actor),
    partner = partner_profile(state.relation),
    home = home_summary(state),
  }
end

-- Aviso de relación para el teléfono de `to`.
local function couple_notices(list)
  local result = {}
  for _, n in ipairs(list) do
    table.insert(result, { to = n.to, code = NOTIFY_COUPLE, content = { event = n.event, text = n.text } })
  end
  return result
end

-- Arma un RPC de pareja. `action(context, input, now)` lee y guarda lo suyo
-- y devuelve {notify = {...}, home_changed = bool}. Responde con todo lo de
-- la pareja al día.
local function couple_rpc(action)
  return function(context, payload)
    local user_id = require_user(context)
    local input = decode_payload(payload)
    local ok, outcome = pcall(with_retries, function()
      local result = action(context, input, now_unix())
      send_notifications(result.notify, user_id)
      return result
    end)
    if not ok then
      if type(outcome) == "table" and outcome.refusal ~= nil then
        local state = load_state(user_id)
        local answer = couple_answer(state)
        answer.ok = false
        answer.error = outcome.refusal
        answer.state = summary(state)
        return nk.json_encode(answer)
      end
      error(outcome)
    end
    local state = load_state(user_id)
    local answer = couple_answer(state)
    answer.ok = true
    answer.home_changed = outcome.home_changed or false
    answer.state = summary(state)
    return nk.json_encode(answer)
  end
end

local function find_user_by_name(username)
  if type(username) ~= "string" or username == "" or #username > 40 then
    return nil
  end
  local users = nk.users_get_username({ string.lower(username) })
  local user = users and users[1]
  return user and user.user_id or nil, user and user.username or nil
end

-- couple_invite {username}
local function couple_invite(context, input, now)
  local me = context.user_id
  local target, target_name = find_user_by_name(input.username)
  if target == nil then
    couple.refuse("No hay ninguna cuenta con ese usuario.")
  end
  local rels, objects = load_relations({ [me] = true, [target] = true })
  -- Si el otro ya me había invitado, se acepta: hacen falta los involucrados.
  if rels[target].invite_to_id == me then
    local ids = couple.involved_in_accept(rels[me], rels[target])
    ids[me], ids[target] = true, true
    rels, objects = load_relations(ids)
  end
  local names = { [me] = context.username, [target] = target_name }
  local notices = couple.invite(rels, me, target, names, now)
  nk.multi_update(nil, relation_writes(rels, objects), nil, nil, false)
  return { notify = couple_notices(notices) }
end

local function couple_cancel(context, _input, _now)
  local me = context.user_id
  local mine = load_relations({ [me] = true })[me]
  local ids = { [me] = true }
  if mine.invite_to_id ~= "" then
    ids[mine.invite_to_id] = true
  end
  local rels, objects = load_relations(ids)
  local notices = couple.cancel_invite(rels, me)
  nk.multi_update(nil, relation_writes(rels, objects), nil, nil, false)
  return { notify = couple_notices(notices) }
end

-- couple_answer {from_id, accept}
local function couple_answer_invite(context, input, now)
  local me = context.user_id
  local from = type(input.from_id) == "string" and input.from_id or ""
  if from == "" or from == me then
    couple.refuse("Esa invitación ya no existe.")
  end
  local rels = load_relations({ [me] = true, [from] = true })
  local ids = { [me] = true, [from] = true }
  if input.accept == true then
    for id in pairs(couple.involved_in_accept(rels[me], rels[from])) do
      ids[id] = true
    end
  end
  local objects
  rels, objects = load_relations(ids)
  local names = { [me] = context.username }
  for _, invite in ipairs(rels[me].invites_in) do
    if invite.from_id == from then
      names[from] = invite.from_name
    end
  end
  local notices = couple.answer_invite(rels, me, from, input.accept == true, names, now)
  nk.multi_update(nil, relation_writes(rels, objects), nil, nil, false)
  return { notify = couple_notices(notices) }
end

-- couple_propose {kind, home}
local function couple_propose(context, input, now)
  local me = context.user_id
  local mine = load_relations({ [me] = true })[me]
  if not couple.in_couple(mine) then
    couple.refuse("Primero tienen que ser pareja.")
  end
  local rels, objects = load_relations({ [me] = true, [mine.partner_id] = true })
  local notices = couple.propose(rels, me, input.kind, input.home, now)
  nk.multi_update(nil, relation_writes(rels, objects), nil, nil, false)
  return { notify = couple_notices(notices) }
end

-- Al mudarse: el hogar del dueño pasa a tener a los dos. La caja empieza
-- en 0 y el historial lo cuenta.
local function move_in_home(owner_id, mover_id, mover_name, now)
  local home_objects = read_objects(owner_id, HOME_KEYS)
  local home = rules.normalize_home(decode_text((value_of(home_objects, "game/home") or {}).json), owner_id)
  home.members = { owner_id, mover_id }
  home.fund = 0
  home.requests = {}
  rules.log_entry(home, { by = mover_id, by_name = mover_name, at = now, kind = "move_in",
    text = mover_name .. " se mudó a la casa" })
  return versioned_write(home_objects, owner_id, GAME, "home", { json = nk.json_encode(home) })
end

-- Al separarse: la caja se reparte en dos y el dueño se queda con la casa.
local function move_out_home(owner_id, other_id, other_name, now)
  local home_objects = read_objects(owner_id, HOME_KEYS)
  local home = rules.normalize_home(decode_text((value_of(home_objects, "game/home") or {}).json), owner_id)
  local for_owner, for_other = rules.split_fund(home.fund)
  home.members = { owner_id }
  home.fund = 0
  home.requests = {}
  rules.log_entry(home, { by = other_id, by_name = other_name, at = now, kind = "move_out",
    text = string.format("%s se fue de la casa (cada uno se llevó su mitad de la caja: $%d)", other_name, for_other) })
  local wallets = {}
  if for_owner > 0 then
    table.insert(wallets, { user_id = owner_id, changeset = { coins = for_owner }, metadata = { reason = "home_split" } })
  end
  if for_other > 0 then
    table.insert(wallets, { user_id = other_id, changeset = { coins = for_other }, metadata = { reason = "home_split" } })
  end
  return versioned_write(home_objects, owner_id, GAME, "home", { json = nk.json_encode(home) }), wallets
end

-- couple_respond {accept}
local function couple_respond(context, input, now)
  local me = context.user_id
  local mine = load_relations({ [me] = true })[me]
  if not couple.in_couple(mine) then
    couple.refuse("No hay ningún pedido esperando.")
  end
  local partner_id = mine.partner_id
  local rels, objects = load_relations({ [me] = true, [partner_id] = true })
  local notices, moved_owner = couple.respond(rels, me, input.accept == true, now)
  local writes = relation_writes(rels, objects)
  if moved_owner ~= nil then
    local mover = moved_owner == me and partner_id or me
    local mover_name = mover == me and context.username or mine.partner_name
    table.insert(writes, move_in_home(moved_owner, mover, mover_name, now))
  end
  nk.multi_update(nil, writes, nil, nil, false)
  return { notify = couple_notices(notices), home_changed = moved_owner ~= nil }
end

local function couple_end(context, _input, now)
  local me = context.user_id
  local mine = load_relations({ [me] = true })[me]
  if not couple.in_couple(mine) then
    couple.refuse("No estás en pareja.")
  end
  local partner_id = mine.partner_id
  local rels, objects = load_relations({ [me] = true, [partner_id] = true })
  local notices, shared_owner = couple.end_relation(rels, me, now)
  local writes = relation_writes(rels, objects)
  local wallets = nil
  if shared_owner ~= "" then
    local other = shared_owner == me and partner_id or me
    local other_name = other == me and context.username or mine.partner_name
    local home_write
    home_write, wallets = move_out_home(shared_owner, other, other_name, now)
    table.insert(writes, home_write)
  end
  nk.multi_update(nil, writes, nil, wallets, true)
  return { notify = couple_notices(notices), home_changed = shared_owner ~= "" }
end

-- couple_switches {drama?, family_mode?, pool_income?}
local function couple_switches(context, input, _now)
  local me = context.user_id
  local rels, objects = load_relations({ [me] = true })
  couple.set_switches(rels[me], input)
  nk.multi_update(nil, relation_writes(rels, objects), nil, nil, false)
  local notify = {}
  if couple.in_couple(rels[me]) then
    notify = couple_notices({ { to = rels[me].partner_id, event = "switches", text = "" } })
  end
  return { notify = notify }
end


-- --- Cargar e importar ---

-- RPC game_load: lo que el teléfono necesita al entrar.
local function game_load(context, _payload)
  local user_id = require_user(context)
  local state = load_state(user_id)
  local cloud = read_objects(user_id, { { CLOUD, "character" }, { CLOUD, "settings" } })
  local character = value_of(cloud, "cloud/character") or {}
  local settings = value_of(cloud, "cloud/settings") or {}
  local house_json = (value_of(state.home_objects, "game/house") or {}).json or ""
  local answer = summary(state)
  answer.imported = state.imported
  answer.house_source = state.shared and "server" or state.house_source
  answer.house = house_json
  answer.character = character.json or ""
  answer.character_saved_unix = character.saved_unix or 0
  answer.settings = settings.json or ""
  answer.settings_saved_unix = settings.saved_unix or 0
  local extra = couple_answer(state)
  answer.couple, answer.partner, answer.home = extra.couple, extra.partner, extra.home
  return nk.json_encode(answer)
end

-- RPC couple_load: la pareja y el hogar al día.
local function couple_load(context, _payload)
  local state = load_state(require_user(context))
  local answer = couple_answer(state)
  answer.ok = true
  answer.state = summary(state)
  return nk.json_encode(answer)
end

-- RPC home_load: la casa donde vive (texto JSON) y el hogar, para ponerse al
-- día cuando la pareja cambió algo.
local function home_load(context, _payload)
  local state = load_state(require_user(context))
  return nk.json_encode({
    ok = true,
    house = (value_of(state.home_objects, "game/house") or {}).json or "",
    home = home_summary(state),
    state = summary(state),
  })
end

-- Experiencia y piezas descubiertas que manda el teléfono (validadas).
local function imported_progress(input)
  local xp = math.floor(rules.num(input.xp) or 0)
  xp = math.max(0, math.min(xp, MAX_XP))
  local discovered = {}
  for _, id in ipairs(type(input.discovered) == "table" and input.discovered or {}) do
    if type(id) == "string" and data.items[id] then
      table.insert(discovered, id)
    end
  end
  return xp, discovered
end

-- Empleo que trae el teléfono, si existe y le alcanza el nivel.
local function imported_job(input, xp)
  local job = data.jobs[input.job_id]
  if job ~= nil and rules.level_for_xp(data, xp) >= (job.level or 1) then
    return input.job_id
  end
  return ""
end

-- Casa que manda el teléfono: se revisa que se pueda leer, y que solo tenga
-- piezas del catálogo. Las obras que estaban en marcha se respetan.
local function imported_house(text)
  local house = decode_text(clean_text(text))
  if house == nil then
    return ""
  end
  house = rules.normalize_house(house)
  for level = 1, rules.LEVEL_COUNT do
    for _, layer in ipairs(rules.LAYERS) do
      for key, value in pairs(house.levels[level][layer]) do
        if type(value) ~= "table" or data.items[value.item] == nil then
          house.levels[level][layer][key] = nil
        end
      end
    end
  end
  return nk.json_encode(house)
end

-- RPC game_import: la primera vez que la cuenta entra, copia la partida del
-- teléfono (casa, experiencia, lo descubierto; el dinero empieza en $3000).
-- Transición 4A → 4B: si la cuenta se importó en la 4A (la casa dice
-- source = "import"), se copia UNA vez más la casa, la experiencia, lo
-- descubierto y el empleo, para no perder lo construido en las pruebas de la
-- 4A. El dinero NO se toca. Después de eso, el teléfono ya no manda nada.
local function game_import(context, payload)
  local user_id = require_user(context)
  local existing = read_objects(user_id, { { GAME, "progress" }, { GAME, "house" }, { GAME, "relation" } })
  local progress = value_of(existing, "game/progress")
  local house_object = value_of(existing, "game/house") or {}
  local relation = couple.normalize(value_of(existing, "game/relation"))
  local resync = progress ~= nil and house_object.source == "import" and relation.home_owner == ""
  if progress ~= nil and not resync then
    return game_load(context, "")
  end

  local ok, input = pcall(nk.json_decode, payload)
  if not ok or type(input) ~= "table" then
    error("Datos de importación inválidos")
  end
  local xp, discovered = imported_progress(input)
  local now = now_unix()
  local work = rules.empty_work()
  work.job_id = imported_job(input, xp)
  work.last_seen_unix = now

  local function write(key, value, version)
    return {
      collection = GAME, key = key, user_id = user_id, value = value, version = version,
      permission_read = READ_OWNER, permission_write = WRITE_NONE,
    }
  end
  local house_version = existing["game/house"] and existing["game/house"].version or "*"
  -- version "*" = solo si no existe; la versión leída = solo si nadie lo
  -- cambió. Si dos importaciones llegan juntas, la segunda falla.
  local writes = {
    write("house", { json = imported_house(input.house), saved_unix = now, source = "server" }, house_version),
    write("progress", { xp = xp, discovered = discovered, imported_unix = now },
      resync and existing["game/progress"].version or "*"),
    write("work", work, nil),
    write("history", { json = nk.json_encode({ undo = {}, redo = {} }), home = user_id }, nil),
  }
  if not resync then
    -- Personaje y opciones: solo si el teléfono no los subió ya.
    local cloud = read_objects(user_id, { { CLOUD, "character" }, { CLOUD, "settings" } })
    for _, name in ipairs({ "character", "settings" }) do
      local text = clean_text(input[name])
      if text ~= "" and cloud[CLOUD .. "/" .. name] == nil then
        table.insert(writes, {
          collection = CLOUD, key = name, user_id = user_id,
          value = { json = text, saved_unix = now },
          permission_read = READ_OWNER, permission_write = WRITE_OWNER,
        })
      end
    end
  end
  local wallets = {}
  if not resync then
    -- El dinero empieza en el inicial (decisión del dueño), no en el del teléfono.
    table.insert(wallets, { user_id = user_id, changeset = { coins = STARTING_MONEY - wallet_coins(user_id) },
      metadata = { reason = "starting_money" } })
  end
  nk.multi_update(nil, writes, nil, wallets, true)
  nk.logger_info(string.format("Partida %s: usuario %s, xp %d, %d piezas descubiertas",
    resync and "re-sincronizada (4A → 4B)" or "importada", user_id, xp, #discovered))
  return game_load(context, "")
end


-- --- Construir ---

-- Copia del estado para probar un cambio sin guardarlo (pedidos).
local function sandbox_of(state)
  local copy = {}
  for k, v in pairs(state) do
    copy[k] = v
  end
  copy.house = rules.copy(state.house)
  copy.history = { undo = {}, redo = {} }
  copy.discovered = rules.copy(state.discovered)
  copy.others = rules.copy(state.others)
  return copy
end

local function last_inverse(state)
  local step = state.history.undo[#state.history.undo]
  return step and step.inverse or nil
end

local function build_apply(state, input, now)
  local clean = rules.clean_writes(data, input.writes)
  local text = house_rules.describe(data, state.house, clean)
  -- Casa compartida: un cambio estructural espera la aprobación de la pareja.
  if state.shared and house_rules.change_kind(data, state.house, clean) == "structural" then
    local trial = rules.build(data, sandbox_of(state), clean, now, nil)
    local wish = house_rules.describe(data, state.house, clean, true)
    local request = rules.add_request(state.home, { by = state.actor, by_name = state.username or "", at = now,
      writes = trial.writes, text = wish, done_text = text, cost = -trial.money_change })
    table.insert(state.notify, { to = housemate(state), code = NOTIFY_REQUESTS, content = {
      text = string.format("%s pide permiso para: %s", state.username or "", wish) } })
    return { changed = { home = true }, result = { requested = true, request_id = request.id, text = wish,
      cost = request.cost } }
  end
  local result = rules.build(data, state, clean, now, encode_history)
  local minor = state.shared
  log_and_notify(state, { kind = minor and "minor" or "build", text = text,
    writes = minor and result.writes or nil, inverse = minor and last_inverse(state) or nil,
    money_fund = result.money_fund, money_own = result.money_own })
  return { changed = { house = true, home = true, progress = result.xp_gained > 0, history = true }, result = result }
end

local function build_undo(state, _input, _now)
  local result = rules.undo(state, data)
  if not result.skipped then
    log_and_notify(state, { kind = "undo", text = "deshizo su último cambio" })
  end
  return { changed = { house = not result.skipped, home = not result.skipped, history = true }, result = result }
end

local function build_redo(state, _input, _now)
  local result = rules.redo(state, data)
  if not result.skipped then
    log_and_notify(state, { kind = "redo", text = "rehizo un cambio" })
  end
  return { changed = { house = not result.skipped, home = not result.skipped, history = true }, result = result }
end

local function build_accelerate(state, _input, now)
  local result = rules.accelerate_builds(data, state, now)
  log_and_notify(state, { kind = "accelerate", text = string.format("aceleró las obras ($%d)", -result.money_change),
    money_fund = result.money_fund, money_own = result.money_own })
  return { changed = { house = true, home = true }, result = result }
end


-- --- Casa compartida: pedidos, deshacer lo del otro, caja ---

local function request_id(input)
  local id = rules.num(input.id)
  if id == nil then
    rules.refuse("Ese pedido ya no existe.")
  end
  return math.floor(id)
end

-- RPC home_answer {id, approve}: la pareja aprueba o rechaza un cambio
-- estructural. Al aprobar, se construye COMO SI LO HUBIERA HECHO quien lo
-- pidió (paga la caja y su billetera, gana su experiencia, va a su deshacer).
local function home_answer(context, payload)
  local me = require_user(context)
  local input = decode_payload(payload)
  local id = nil
  local ok, answer = pcall(with_retries, function()
    id = request_id(input)
    local mine = load_state(me)
    local request
    for _, r in ipairs(mine.home.requests) do
      if r.id == id then
        request = r
      end
    end
    if request == nil then
      rules.refuse("Ese pedido ya no existe.")
    elseif request.by == me then
      rules.refuse("Lo tiene que aprobar tu pareja (podés retirarlo).")
    end
    local now = now_unix()
    if input.approve ~= true then
      rules.take_request(mine.home, id)
      mine.username = context.username
      log_and_notify(mine, { kind = "rejected", text = "no aprobó: " .. request.text })
      table.insert(mine.notify, { to = request.by, code = NOTIFY_REQUESTS, content = {
        text = string.format("%s no aprobó: %s", context.username, request.text) } })
      save_state(mine, { home = true }, "home_answer")
      send_notifications(mine.notify, me)
      return { ok = true, approved = false }
    end
    -- Se construye con el estado de quien lo pidió.
    local requester = load_state(request.by)
    requester.username = request.by_name
    if requester.owner_id ~= mine.owner_id then
      rules.refuse("Ese pedido ya no vale: ya no viven en la misma casa.")
    end
    rules.take_request(requester.home, id)
    if request.business ~= nil then
      -- Fase 6: abrir o cerrar el restaurante (no tiene piezas).
      if request.business == "open" then
        business.open(restaurant, data.items, requester, now)
      else
        business.close(requester)
      end
      log_and_notify(requester, { kind = "business", text = string.format("%s (aprobado por %s)",
        request.done_text or request.text, context.username) })
      table.insert(requester.notify, { to = request.by, code = NOTIFY_REQUESTS, content = {
        text = string.format("%s aprobó: %s", context.username, request.text) } })
      save_state(requester, { home = true }, "home_answer")
      send_notifications(requester.notify, me)
      return { ok = true, approved = true, writes = {} }
    end
    local result = rules.build(data, requester, request.writes, now, encode_history)
    log_and_notify(requester, { kind = "approved", text = string.format("%s (aprobado por %s)",
      request.done_text or request.text, context.username), money_fund = result.money_fund, money_own = result.money_own })
    table.insert(requester.notify, { to = request.by, code = NOTIFY_REQUESTS, content = {
      text = string.format("%s aprobó: %s", context.username, request.text) } })
    save_state(requester, { house = true, home = true, progress = result.xp_gained > 0, history = true },
      "home_answer")
    -- Avisos: a quien pidió (el que aprueba ya recibe esta respuesta).
    local notices = {}
    for _, n in ipairs(requester.notify) do
      if n.to ~= me then
        table.insert(notices, n)
      end
    end
    table.insert(notices, { to = request.by, code = NOTIFY_HOME, content = { rev = requester.home.rev,
      entry_id = 0, kind = "approved", text = request.text, by_name = context.username, can_revert = false } })
    send_notifications(notices, me)
    return { ok = true, approved = true, writes = result.writes }
  end)
  if not ok then
    if type(answer) == "table" and answer.refusal ~= nil then
      return refusal_answer(me, answer)
    end
    error(answer)
  end
  local state = load_state(me)
  answer.state = summary(state)
  answer.home = home_summary(state)
  return nk.json_encode(answer)
end

-- RPC home_cancel {id}: retirar un pedido propio.
local function home_cancel(state, input, _now)
  local id = request_id(input)
  for _, r in ipairs(state.home.requests) do
    if r.id == id and r.by ~= state.actor then
      rules.refuse("Solo podés retirar tus pedidos.")
    end
  end
  local request = rules.take_request(state.home, id)
  table.insert(state.notify, { to = housemate(state), code = NOTIFY_REQUESTS, content = {
    text = string.format("%s retiró su pedido: %s", state.username or "", request.text) } })
  return { changed = { home = true }, result = { home = home_summary(state) } }
end

-- RPC home_request {id}: un pedido con sus piezas (writes, como texto JSON),
-- para que la pareja vea la propuesta antes de aprobarla. No cambia nada.
local function home_request(state, input, _now)
  local id = request_id(input)
  for _, r in ipairs(state.home.requests) do
    if r.id == id then
      return { changed = {}, result = { request = { id = r.id, by_me = r.by == state.actor, by_name = r.by_name,
        text = r.text, cost = r.cost, writes_json = nk.json_encode(r.writes or {}) } } }
    end
  end
  rules.refuse("Ese pedido ya no existe.")
end

-- RPC home_revert {id}: deshacer un cambio menor del historial (de la
-- pareja, o propio). El dinero vuelve a quien lo pagó.
local function home_revert(state, input, _now)
  local id = request_id(input)
  local entry = rules.find_entry(state.home, id)
  if entry ~= nil and entry.by ~= nil then
    load_other_money(state, entry.by)
  end
  local result = rules.revert(data, state, state.home, id)
  log_and_notify(state, { kind = "revert", text = string.format("deshizo lo de %s: %s", entry.by_name, entry.text) })
  if entry.by ~= state.actor then
    -- Aviso aparte para quien lo había hecho (con su nombre en el texto).
    for _, n in ipairs(state.notify) do
      if n.code == NOTIFY_HOME and n.to == entry.by then
        n.content.text = string.format("deshizo: %s", entry.text)
      end
    end
  end
  return { changed = { house = true, home = true }, result = { writes = result.writes, home = home_summary(state) } }
end

-- RPC home_contribute {amount}
local function home_contribute(state, input, _now)
  local result = rules.contribute(state, input.amount)
  log_and_notify(state, { kind = "fund", text = string.format("puso $%d en la caja", -result.money_change) })
  return { changed = { home = true }, result = result }
end


-- --- Empleos y turnos ---

local function job_apply(state, input, now)
  return { changed = { work = true }, result = rules.job_apply(data, state, input.job_id, now) }
end

local function job_status(state, _input, now)
  local hired = rules.resolve_resume(state, now)
  return { changed = { work = hired }, result = { hired = hired } }
end

local function job_accelerate(state, _input, now)
  return { changed = { work = true }, result = rules.accelerate_resume(data, state, now) }
end

local function job_quit(state, _input, _now)
  return { changed = { work = true }, result = rules.job_quit(state) }
end

local function shift_start(state, _input, now)
  local result = rules.shift_start(data, state, now)
  state.work.last_seen_unix = now
  return { changed = { work = true }, result = result }
end

-- Si el sueldo fue a la caja ("unir ingresos"), se anota y se avisa.
local function note_income(state, result, pay, text)
  if result.to_fund and pay > 0 then
    log_and_notify(state, { kind = "fund", text = string.format(text, pay) })
  end
end

local function shift_complete(state, _input, now)
  local result = rules.shift_complete(data, state, now)
  state.work.last_seen_unix = now
  note_income(state, result, result.pay, "su sueldo ($%d) fue a la caja")
  return { changed = { work = true, progress = result.xp_gained > 0 }, result = result }
end

-- Pulido 2B: la caja del restaurante se cobra SOLA (cálculo por tiempo del
-- servidor, como los turnos). Devuelve true si cobró algo.
local function restaurant_auto(state, result, now)
  local auto = business.auto_collect(restaurant, data.items, state, now)
  if auto == nil then
    return false
  end
  result.restaurant_pay = auto.coins
  result.to_fund = result.to_fund or auto.to_fund
  if auto.to_fund then
    log_and_notify(state, { kind = "fund", text = string.format("el restaurante juntó $%d para la caja", auto.coins) })
  end
  return true
end

local function work_settle(state, _input, now)
  local result = rules.settle(data, state, now)
  note_income(state, result, result.pending_pay + result.offline_pay, "sus sueldos ($%d) fueron a la caja")
  local paid = restaurant_auto(state, result, now)
  return { changed = { work = true, home = paid, progress = result.xp_gained > 0 }, result = result }
end

-- "Sigo jugando": además de anotar la hora, cobra lo que juntó el restaurante.
local function game_heartbeat(state, _input, now)
  state.work.last_seen_unix = now
  local result = {}
  local paid = restaurant_auto(state, result, now)
  return { changed = { work = true, home = paid }, result = result }
end



-- --- Restaurante (Fase 6) ---

local function restaurant_summary(state, now)
  return business.summary(restaurant, data.items, state, now)
end

local function restaurant_load(state, _input, now)
  return { changed = {}, result = { restaurant = restaurant_summary(state, now) } }
end

-- Abrir o cerrar: en la casa compartida es un cambio estructural
-- ("convertir en negocio", VISION.md): queda como pedido para la pareja.
local function restaurant_switch(kind)
  return function(state, _input, now)
    if kind == "open" then
      business.check_open(restaurant, data.items, state, now)
    elseif not business.is_open(state.home) then
      rules.refuse("El restaurante ya está cerrado.")
    end
    local wish = kind == "open" and "abrir el restaurante" or "cerrar el restaurante"
    local done = kind == "open" and "abrió el restaurante" or "cerró el restaurante"
    if state.shared then
      local request = rules.add_request(state.home, { by = state.actor, by_name = state.username or "", at = now,
        writes = {}, business = kind, text = wish, done_text = done, cost = 0 })
      table.insert(state.notify, { to = housemate(state), code = NOTIFY_REQUESTS, content = {
        text = string.format("%s pide permiso para: %s", state.username or "", wish) } })
      return { changed = { home = true }, result = { requested = true, request_id = request.id, text = wish,
        restaurant = restaurant_summary(state, now) } }
    end
    if kind == "open" then
      business.open(restaurant, data.items, state, now)
    else
      business.close(state)
    end
    log_and_notify(state, { kind = "business", text = done })
    return { changed = { home = true }, result = { restaurant = restaurant_summary(state, now) } }
  end
end

local function restaurant_collect(state, _input, now)
  local result = business.collect(restaurant, data.items, state, now)
  if result.to_fund then
    log_and_notify(state, { kind = "fund", text = string.format("cobró el restaurante: $%d a la caja", result.coins) })
  end
  result.restaurant = restaurant_summary(state, now)
  return { changed = { home = true }, result = result }
end

local function service_start(state, _input, now)
  local result = business.service_start(restaurant, data.items, state, now, math.random(1, 2147483646))
  return { changed = { business = true }, result = result }
end

local function service_finish(state, input, now)
  local result = business.service_finish(restaurant, data.items, state, now, input.actions)
  if result.valid then
    note_income(state, result, result.pay, "lo ganado en el restaurante ($%d) fue a la caja")
  end
  result.restaurant = restaurant_summary(state, now)
  return { changed = { business = true, progress = (result.xp_gained or 0) > 0 }, result = result }
end


-- --- Parcela y servicios (Pulido 2C) ---

-- --- Fase 8D: meta del barrio ---

-- Pone al día el aporte del jugador con lo que hay en SU casa (si vive en la
-- casa de su pareja, esas plantas no son suyas y no cuentan). Devuelve lo acreditado.
local function goal_refresh(state, now)
  local counted = state.goal.credited
  if not state.shared or state.owner_id == state.user_id then
    counted = goals.count_items(goal_cfg, state.house, data.items, now)
  end
  local gained, dirty = goals.update(goal_cfg, state.goal, now, counted)
  return gained, dirty
end

-- Ver la meta: el servidor cuenta lo que hay en la casa y acredita (con tope diario).
local function goal_load(state, _input, now)
  local gained, dirty = goal_refresh(state, now)
  return { changed = { goal = dirty }, result = { goal = goals.summary(goal_cfg, state.goal, now), gained = gained } }
end

-- Retirar la recompensa (opcional, una vez).
local function goal_claim(state, _input, now)
  local _, dirty = goal_refresh(state, now)
  local reward, why = goals.claim(goal_cfg, state.goal, now)
  if reward == nil then
    rules.refuse(why)
  end
  state.money = state.money + reward.money
  state.xp = state.xp + reward.xp
  return { changed = { goal = true, progress = true },
    result = { goal = goals.summary(goal_cfg, state.goal, now), reward = reward, money_change = reward.money } }
end

local function parcel_summary(state, now)
  local p = parcel_state(state)
  local _, seed = parcel_obstacles(state.owner_id)
  local cleared = {}
  for id in pairs(p.cleared) do
    table.insert(cleared, id)
  end
  table.sort(cleared)
  local pending = {}
  for id, job in pairs(p.pending) do
    pending[id] = { ready_at = job.ready_at, service = job.service, seconds_left = math.max(0, job.ready_at - now) }
  end
  return { seed = seed, lot = parcel_cfg.lot, cleared = cleared, pending = pending, count = p.count, server_unix = now,
    level = rules.level_for_xp(data, state.xp) }
end

-- ¿Puede llegar el servicio hasta el obstáculo? (con la casa y lo que no se limpió)
local function parcel_access(state, obstacles, target, def)
  local p = parcel_state(state)
  local blocked = parcel_blocked(state, obstacles, p.cleared)
  for cx = target.x, target.x + target.w - 1 do
    for cz = target.z, target.z + target.d - 1 do
      blocked[cx .. "," .. cz] = nil
    end
  end
  local house_cells = {}
  for key in pairs(house_rules.level_table(state.house, 0).foundation) do
    house_cells[key] = true
  end
  return parcel.can_reach(parcel_cfg, blocked, house_cells, target, def.vehicle ~= "")
end

local function parcel_load(state, _input, now)
  return { changed = {}, result = { parcel = parcel_summary(state, now) } }
end

-- Llamar al servicio: cobra el servidor y arranca la espera REAL.
local function parcel_clear_start(state, input, now)
  local id = tostring(input.id or "")
  local obstacles = parcel_obstacles(state.owner_id)
  local target = parcel.find(obstacles, id)
  if target == nil then
    rules.refuse("Ese obstáculo no existe.")
  end
  local p = parcel_state(state)
  if p.cleared[id] then
    rules.refuse("Eso ya está limpio.")
  end
  if p.pending[id] then
    rules.refuse("Ya viene un servicio para eso.")
  end
  local def = parcel_cfg.obstacles[target.kind]
  if not parcel.in_zone(parcel.zone_rects(parcel_cfg, rules.level_for_xp(data, state.xp)), target.x, target.z, target.w, target.d) then
    rules.refuse("Ese terreno todavía no es tuyo: se abre al subir de nivel.")
  end
  local ok, why = parcel_access(state, obstacles, target, def)
  if not ok then
    rules.refuse(why)
  end
  local cost = parcel.cost(parcel_cfg, target.kind, p.count)
  if state.money < cost then
    rules.refuse(string.format("Te faltan $%d para llamar al servicio.", cost - state.money))
  end
  state.money = state.money - cost
  p.pending[id] = { ready_at = now + def.seconds, service = def.service, vehicle = def.vehicle, cost = cost, by = state.actor }
  log_and_notify(state, { kind = "parcel", text = string.format("llamó al servicio para limpiar: %s ($%d)", def.name, cost) })
  return { changed = { home = true }, result = { cost = cost, money_change = -cost, parcel = parcel_summary(state, now) } }
end

-- El servicio llegó (pasó la espera): limpia, si el vehículo puede entrar.
local function parcel_clear_finish(state, input, now)
  local id = tostring(input.id or "")
  local p = parcel_state(state)
  local job = p.pending[id]
  if job == nil then
    rules.refuse("No hay un servicio en camino para eso.")
  end
  if now < job.ready_at then
    rules.refuse(string.format("El servicio todavía no llegó (faltan %d s).", job.ready_at - now))
  end
  local obstacles = parcel_obstacles(state.owner_id)
  local target = parcel.find(obstacles, id)
  local def = parcel_cfg.obstacles[target.kind]
  local ok, why = parcel_access(state, obstacles, target, def)
  if not ok then
    -- El servicio avisa que no puede entrar y se queda esperando (no se cobra de nuevo).
    return { changed = {}, result = { blocked = true, reason = why, parcel = parcel_summary(state, now) } }
  end
  p.pending[id] = nil
  p.cleared[id] = true
  p.count = p.count + 1
  state.xp = state.xp + def.xp
  house_rules.blocked_cells = parcel_blocked(state, obstacles, p.cleared)
  log_and_notify(state, { kind = "parcel", text = string.format("quedó limpio: %s", def.name) })
  return { changed = { home = true, progress = true }, result = { cleared = id, xp_gained = def.xp, parcel = parcel_summary(state, now) } }
end

nk.register_rpc(game_load, "game_load")
nk.register_rpc(game_import, "game_import")
nk.register_rpc(game_rpc("build_apply", build_apply), "build_apply")
nk.register_rpc(game_rpc("build_undo", build_undo), "build_undo")
nk.register_rpc(game_rpc("build_redo", build_redo), "build_redo")
nk.register_rpc(game_rpc("build_accelerate", build_accelerate), "build_accelerate")
nk.register_rpc(game_rpc("job_apply", job_apply), "job_apply")
nk.register_rpc(game_rpc("job_status", job_status), "job_status")
nk.register_rpc(game_rpc("job_accelerate", job_accelerate), "job_accelerate")
nk.register_rpc(game_rpc("job_quit", job_quit), "job_quit")
nk.register_rpc(game_rpc("shift_start", shift_start), "shift_start")
nk.register_rpc(game_rpc("shift_complete", shift_complete), "shift_complete")
nk.register_rpc(game_rpc("work_settle", work_settle), "work_settle")
nk.register_rpc(game_rpc("game_heartbeat", game_heartbeat), "game_heartbeat")
-- Fase 5
nk.register_rpc(couple_load, "couple_load")
nk.register_rpc(couple_rpc(couple_invite), "couple_invite")
nk.register_rpc(couple_rpc(couple_cancel), "couple_cancel")
nk.register_rpc(couple_rpc(couple_answer_invite), "couple_answer")
nk.register_rpc(couple_rpc(couple_propose), "couple_propose")
nk.register_rpc(couple_rpc(couple_respond), "couple_respond")
nk.register_rpc(couple_rpc(couple_end), "couple_end")
nk.register_rpc(couple_rpc(couple_switches), "couple_switches")
nk.register_rpc(home_load, "home_load")
nk.register_rpc(home_answer, "home_answer")
nk.register_rpc(game_rpc("home_cancel", home_cancel), "home_cancel")
nk.register_rpc(game_rpc("home_request", home_request), "home_request")
nk.register_rpc(game_rpc("home_revert", home_revert), "home_revert")
nk.register_rpc(game_rpc("home_contribute", home_contribute), "home_contribute")
nk.register_rpc(game_rpc("restaurant_load", restaurant_load), "restaurant_load")
nk.register_rpc(game_rpc("restaurant_open", restaurant_switch("open")), "restaurant_open")
nk.register_rpc(game_rpc("restaurant_close", restaurant_switch("close")), "restaurant_close")
nk.register_rpc(game_rpc("restaurant_collect", restaurant_collect), "restaurant_collect")
nk.register_rpc(game_rpc("goal_load", goal_load), "goal_load")
nk.register_rpc(game_rpc("goal_claim", goal_claim), "goal_claim")
nk.register_rpc(game_rpc("parcel_load", parcel_load), "parcel_load")
nk.register_rpc(game_rpc("parcel_clear_start", parcel_clear_start), "parcel_clear_start")
nk.register_rpc(game_rpc("parcel_clear_finish", parcel_clear_finish), "parcel_clear_finish")
nk.register_rpc(game_rpc("service_start", service_start), "service_start")
nk.register_rpc(game_rpc("service_finish", service_finish), "service_finish")
