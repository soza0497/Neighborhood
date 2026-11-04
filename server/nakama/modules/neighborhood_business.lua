--[[
Reglas de los negocios (Fase 6): el restaurante y su minijuego "Servicio".

Como neighborhood_rules.lua, este archivo NO usa nada de Nakama: se prueba
solo con `lua5.1 server/tests/test_rules.lua`. Los números salen de
data/business.json (el mismo archivo que lee el juego).

Cómo se evita la trampa (DECISIONES.md, "Restaurante"):
  1. Al empezar un servicio, el SERVIDOR elige una semilla y anota la hora.
  2. Con esa semilla, el teléfono y el servidor arman la MISMA lista de
     clientes (cuándo llegan, qué piden, cuánta paciencia tienen).
  3. El teléfono solo manda lo que tocó el jugador y cuándo (en ms desde
     que empezó): {t, acción, número}. Nunca manda un puntaje.
  4. El servidor revisa que haya pasado el tiempo del servicio, que los
     toques sean posibles para una persona (no más rápidos que min_gap_ms,
     no más de max_actions, en orden) y REPITE el servicio con esos toques:
     lo que gana es lo que calcula él, con el tope diario.

La simulación usa solo números enteros (milisegundos) y un generador de
números al azar simple (Park-Miller), para que dé EXACTAMENTE lo mismo en
Lua y en GDScript (scripts/business/restaurant_sim.gd es la copia del
teléfono; si cambiás algo aquí, cambialo allá, y las pruebas de los dos
lados comparan los mismos números).

Acciones (lo que manda el teléfono, en una lista de [t, código, número]):
  1 = tomar un ingrediente (número = cuál, desde 0). Los fríos van al
      plato; los calientes a la plancha (al primer lugar libre).
  2 = tocar un lugar de la plancha (número = cuál): si está a punto, va al
      plato; si se quemó, se tira; si todavía se cocina, no pasa nada.
  3 = servir el plato a la mesa (número = cuál): si es lo que pidió (sin
      importar el orden), paga; si no, el cliente pierde paciencia.
  4 = tirar el plato (número = 0).
]]

local business = {}
local rules = require("neighborhood_rules")

local MOD = 2147483647
local MUL = 16807
local BIG = 1e15

-- Margen para la demora de la red al terminar un servicio (segundos).
business.FINISH_GRACE = 3
-- Un servicio sin terminar se puede mandar hasta 24 h después (si el
-- teléfono se apagó en medio, se manda al volver: nada se pierde).
business.MAX_LATE = 86400
-- Después del servicio, este margen antes de poder empezar otro sin
-- terminar el anterior (segundos).
business.START_GRACE = 60
-- El tope diario es por 24 horas desde la primera ganancia.
business.DAY_SECONDS = 86400

business.TAKE, business.GRILL, business.SERVE, business.TRASH = 1, 2, 3, 4

local function num(value)
  if value == nil then
    return nil
  end
  return tonumber(value)
end

local function int_of(value, default)
  return math.floor(num(value) or default or 0)
end

local function is_int(value)
  return type(value) == "number" and value == math.floor(value)
end

local refuse = rules.refuse


-- --- Datos (data/business.json) ---

local SERVICE_FIELDS = {
  "duration_ms", "max_seats", "first_arrival_ms", "last_call_ms", "phase_ms", "gap_min_ms", "gap_random_ms",
  "gap_drop_ms", "patience_ms", "patience_drop_ms", "wrong_penalty_ms", "plate_max", "grill_slots", "cook_ms",
  "ready_ms", "coin_per_item", "tip_max", "streak_bonus", "streak_max_bonus", "min_gap_ms", "max_actions",
}

-- Prepara la parte del restaurante de business.json (todo en enteros).
function business.new_config(json)
  local r = ((json or {}).restaurant) or {}
  local svc = r.service or {}
  local cfg = {
    name = r.name or "Restaurante",
    requires = {},
    seats_item = r.seats_item or "",
    daily_cap = int_of(r.daily_cap, 0),
    passive_per_hour = int_of(r.passive_per_hour, 0),
    passive_cap = int_of(r.passive_cap, 0),
    xp_per_customer = int_of(r.xp_per_customer, 0),
    service = { ingredients = {} },
  }
  for id, count in pairs(r.requires or {}) do
    cfg.requires[id] = int_of(count, 1)
  end
  for _, field in ipairs(SERVICE_FIELDS) do
    cfg.service[field] = int_of(svc[field], 0)
  end
  for _, ing in ipairs(svc.ingredients or {}) do
    table.insert(cfg.service.ingredients, { id = ing.id, name = ing.name, hot = ing.hot == true })
  end
  return cfg
end


-- --- Números al azar que dan lo mismo en Lua y en GDScript ---

function business.new_rng(seed)
  local s = math.floor(num(seed) or 1) % MOD
  if s <= 0 then
    s = s + MOD - 1
  end
  return { state = s }
end

-- Entero de 0 a n - 1.
function business.next_int(rng, n)
  rng.state = (rng.state * MUL) % MOD
  return rng.state % n
end


-- --- La lista de clientes (sale de la semilla, igual en los dos lados) ---

-- Cada cliente: {arrive (ms), order (ingredientes, desde 0), patience (ms)}.
-- A medida que pasa el servicio piden más cosas, llegan más seguido y
-- tienen menos paciencia (fases de phase_ms).
function business.customers(svc, seed)
  local rng = business.new_rng(seed)
  local list = {}
  local t = svc.first_arrival_ms
  local stop = svc.duration_ms - svc.last_call_ms
  local kinds = #svc.ingredients
  while t < stop and kinds > 0 do
    local phase = math.floor(t / svc.phase_ms)
    local size_max = math.min(2 + phase, svc.plate_max)
    local size = 2 + business.next_int(rng, size_max - 1)
    local order = {}
    for k = 1, size do
      order[k] = business.next_int(rng, kinds)
    end
    local patience = math.max(svc.patience_ms - phase * svc.patience_drop_ms, 5000)
    table.insert(list, { arrive = t, order = order, patience = patience })
    local gap = svc.gap_min_ms + business.next_int(rng, svc.gap_random_ms + 1) - phase * svc.gap_drop_ms
    t = t + math.max(gap, 1000)
  end
  return list
end


-- --- La simulación del servicio ---

function business.new_sim(svc, seed, seats)
  local sim = {
    svc = svc, customers = business.customers(svc, seed), next = 1, seats = {}, plate = {}, grill = {},
    coins = 0, tips = 0, served = 0, lost = 0, wrong = 0, skipped = 0, burned = 0, trashed = 0,
    streak = 0, best_streak = 0,
  }
  for s = 1, math.max(1, math.min(seats, svc.max_seats)) do
    sim.seats[s] = false
  end
  for g = 1, svc.grill_slots do
    sim.grill[g] = false
  end
  return sim
end

-- La mesa que se vacía primero (por falta de paciencia): (hora, mesa).
local function next_leave(sim)
  local best, seat = BIG, nil
  for s, c in ipairs(sim.seats) do
    if c and c.deadline < best then
      best, seat = c.deadline, s
    end
  end
  return best, seat
end

-- Avanza el reloj hasta `t`: llegan clientes (a la primera mesa libre; si
-- no hay, siguen de largo) y se van los que perdieron la paciencia. Si
-- pasan las dos cosas a la vez, primero se va el que se va.
function business.advance(sim, t)
  while true do
    local c = sim.customers[sim.next]
    local arrive = c and c.arrive or BIG
    local leave, seat = next_leave(sim)
    if math.min(arrive, leave) > t then
      return
    end
    if leave <= arrive then
      sim.seats[seat] = false
      sim.lost = sim.lost + 1
      sim.streak = 0
    else
      local free = nil
      for s, occupied in ipairs(sim.seats) do
        if not occupied then
          free = s
          break
        end
      end
      if free then
        sim.seats[free] = { c = sim.next, deadline = c.arrive + c.patience }
      else
        sim.skipped = sim.skipped + 1
      end
      sim.next = sim.next + 1
    end
  end
end

-- ¿El plato tiene lo mismo que el pedido? (sin importar el orden)
local function same_items(plate, order)
  if #plate ~= #order then
    return false
  end
  local counts = {}
  for _, i in ipairs(order) do
    counts[i] = (counts[i] or 0) + 1
  end
  for _, i in ipairs(plate) do
    if (counts[i] or 0) == 0 then
      return false
    end
    counts[i] = counts[i] - 1
  end
  return true
end

-- Una acción del jugador a la hora `t` (ya revisada por validate_actions).
-- Lo que no tiene sentido (servir sin plato, plancha llena...) no hace nada.
function business.act(sim, t, code, arg)
  local svc = sim.svc
  business.advance(sim, t)
  if code == business.TAKE then
    local ing = svc.ingredients[arg + 1]
    if ing.hot then
      for g, slot in ipairs(sim.grill) do
        if not slot then
          sim.grill[g] = { item = arg, placed = t }
          return
        end
      end
    elseif #sim.plate < svc.plate_max then
      table.insert(sim.plate, arg)
    end
  elseif code == business.GRILL then
    local slot = sim.grill[arg + 1]
    if not slot then
      return
    end
    local elapsed = t - slot.placed
    if elapsed < svc.cook_ms then
      return  -- Todavía se está cocinando.
    elseif elapsed <= svc.cook_ms + svc.ready_ms then
      if #sim.plate < svc.plate_max then
        table.insert(sim.plate, slot.item)
        sim.grill[arg + 1] = false
      end
    else
      sim.grill[arg + 1] = false  -- Se quemó: a la basura.
      sim.burned = sim.burned + 1
    end
  elseif code == business.SERVE then
    local seat = sim.seats[arg + 1]
    if not seat or #sim.plate == 0 then
      return
    end
    local customer = sim.customers[seat.c]
    if same_items(sim.plate, customer.order) then
      local tip = math.floor(svc.tip_max * (seat.deadline - t) / customer.patience)
      sim.streak = sim.streak + 1
      sim.best_streak = math.max(sim.best_streak, sim.streak)
      local bonus = math.min((sim.streak - 1) * svc.streak_bonus, svc.streak_max_bonus)
      sim.coins = sim.coins + svc.coin_per_item * #sim.plate + tip + bonus
      sim.tips = sim.tips + tip + bonus
      sim.served = sim.served + 1
      sim.seats[arg + 1] = false
    else
      seat.deadline = seat.deadline - svc.wrong_penalty_ms
      sim.wrong = sim.wrong + 1
      sim.streak = 0
      if seat.deadline <= t then
        sim.seats[arg + 1] = false
        sim.lost = sim.lost + 1
      end
    end
    sim.plate = {}
  elseif code == business.TRASH then
    if #sim.plate > 0 then
      sim.trashed = sim.trashed + 1
    end
    sim.plate = {}
  end
end

-- Revisa que los toques sean posibles. Devuelve nil si está bien, o el
-- motivo (texto) si no.
function business.validate_actions(svc, seats, actions)
  if type(actions) ~= "table" then
    return "sin acciones"
  end
  if #actions > svc.max_actions then
    return "demasiados toques"
  end
  local limits = {
    [business.TAKE] = #svc.ingredients, [business.GRILL] = svc.grill_slots,
    [business.SERVE] = math.max(1, math.min(seats, svc.max_seats)), [business.TRASH] = 1,
  }
  local last = nil
  for i, a in ipairs(actions) do
    if type(a) ~= "table" then
      return "acción " .. i .. " inválida"
    end
    local t, code, arg = num(a[1]), num(a[2]), num(a[3])
    if not (is_int(t) and is_int(code) and is_int(arg)) then
      return "acción " .. i .. " inválida"
    elseif t < 0 or t > svc.duration_ms then
      return "acción " .. i .. " fuera de tiempo"
    elseif limits[code] == nil or arg < 0 or arg >= limits[code] then
      return "acción " .. i .. " inválida"
    elseif last ~= nil and t < last + svc.min_gap_ms then
      return "toques demasiado rápidos"
    end
    last = t
  end
  return nil
end

-- Repite un servicio entero y devuelve el resultado (o nil, motivo).
function business.replay(svc, seed, seats, actions)
  local why = business.validate_actions(svc, seats, actions)
  if why ~= nil then
    return nil, why
  end
  local sim = business.new_sim(svc, seed, seats)
  for _, a in ipairs(actions) do
    business.act(sim, num(a[1]), num(a[2]), num(a[3]))
  end
  business.advance(sim, svc.duration_ms)
  return {
    coins = sim.coins, tips = sim.tips, served = sim.served, lost = sim.lost, wrong = sim.wrong,
    skipped = sim.skipped, burned = sim.burned, trashed = sim.trashed, best_streak = sim.best_streak,
    customers = #sim.customers,
  }
end


-- --- El restaurante de la casa ---

-- ¿Qué le falta a la casa para ser restaurante? Cuenta los muebles
-- terminados (las obras en marcha no cuentan). Devuelve (faltan, mesas):
-- faltan = lista {id, name, need, have}, ordenada por id.
function business.requirements(cfg, items, house, now)
  local counts = {}
  for _, level in ipairs(house.levels or {}) do
    for _, value in pairs(level.objects or {}) do
      if type(value) == "table" and value.item ~= nil and (num(value.ready_at) or 0) <= now then
        counts[value.item] = (counts[value.item] or 0) + 1
      end
    end
  end
  local ids = {}
  for id in pairs(cfg.requires) do
    table.insert(ids, id)
  end
  table.sort(ids)
  local missing = {}
  for _, id in ipairs(ids) do
    local have = counts[id] or 0
    if have < cfg.requires[id] then
      local item = items[id] or {}
      table.insert(missing, { id = id, name = item.name or id, need = cfg.requires[id], have = have })
    end
  end
  return missing, math.min(counts[cfg.seats_item] or 0, cfg.service.max_seats)
end

local function missing_text(missing)
  local names = {}
  for _, m in ipairs(missing) do
    table.insert(names, m.name)
  end
  return table.concat(names, ", ")
end

local function check_ready(cfg, items, state, now, what)
  local missing, seats = business.requirements(cfg, items, state.house, now)
  if #missing > 0 then
    refuse(string.format("%s: al restaurante le falta %s.", what, missing_text(missing)),
      { reason = "missing" })
  end
  return seats
end

function business.is_open(home)
  return type(home) == "table" and type(home.business) == "table" and home.business.kind == "restaurant"
end

-- Revisa que se pueda abrir (sin abrir): para los pedidos de la casa compartida.
function business.check_open(cfg, items, state, now)
  if business.is_open(state.home) then
    refuse("El restaurante ya está abierto.")
  end
  check_ready(cfg, items, state, now, "No se puede abrir")
end

function business.open(cfg, items, state, now)
  business.check_open(cfg, items, state, now)
  state.home.business = { kind = "restaurant", opened_unix = now, opened_by = state.actor, passive_since = now }
  return {}
end

function business.close(state)
  if not business.is_open(state.home) then
    refuse("El restaurante ya está cerrado.")
  end
  state.home.business = {}
  return {}
end

-- Lo que juntó solo el restaurante abierto ("clientes de paso"), con tope.
function business.passive_amount(cfg, home, now)
  if not business.is_open(home) or cfg.passive_per_hour <= 0 then
    return 0
  end
  local since = int_of(home.business.passive_since, now)
  local amount = math.floor(math.max(0, now - since) * cfg.passive_per_hour / 3600)
  return math.min(amount, cfg.passive_cap)
end

-- Cobrar la caja del restaurante. En la casa compartida va a la caja de la
-- casa (el restaurante es de los dos); si no, a la billetera.
function business.collect(cfg, items, state, now)
  if not business.is_open(state.home) then
    refuse("El restaurante está cerrado.")
  end
  local amount = business.passive_amount(cfg, state.home, now)
  if amount <= 0 then
    refuse("Todavía no juntó nada: vuelve a juntar con el tiempo.")
  end
  check_ready(cfg, items, state, now, "No atiende")
  local b = state.home.business
  if amount >= cfg.passive_cap then
    b.passive_since = now
  else
    b.passive_since = int_of(b.passive_since, now) + math.floor(amount * 3600 / cfg.passive_per_hour)
  end
  local to_fund = state.fund ~= nil
  if to_fund then
    state.fund = state.fund + amount
  else
    state.money = state.money + amount
  end
  return { coins = amount, to_fund = to_fund, money_change = to_fund and 0 or amount }
end

-- Pulido 2B: los ingresos normales del restaurante son AUTOMÁTICOS. El
-- servidor los calcula por tiempo (como los turnos) y los cobra solo cuando
-- el jugador entra (work_settle) o el teléfono avisa que sigue jugando.
-- Devuelve nil si no había nada (cerrado, sin lo necesario, o $0).
function business.auto_collect(cfg, items, state, now)
  local ok, result = pcall(business.collect, cfg, items, state, now)
  if ok then
    return result
  end
  return nil
end


-- --- Lo de cada jugador: servicio en marcha, tope diario (game/business) ---

function business.empty_record()
  return {
    service_seed = 0, service_started = 0, service_seats = 0, service_home = "",
    day_start = 0, day_earned = 0, services = 0, best = 0, total = 0,
  }
end

function business.normalize_record(record)
  local result = business.empty_record()
  if type(record) == "table" then
    for k, default in pairs(result) do
      if type(record[k]) == type(default) then
        result[k] = record[k]
      end
    end
  end
  for k, v in pairs(result) do
    if type(v) == "number" then
      result[k] = math.floor(v)
    end
  end
  return result
end

-- Pasaron 24 h desde la primera ganancia: el tope empieza de nuevo.
local function roll_day(record, now)
  if now >= record.day_start + business.DAY_SECONDS then
    record.day_start = now
    record.day_earned = 0
  end
end

local function day_view(cfg, record, now)
  if now >= record.day_start + business.DAY_SECONDS then
    return 0, cfg.daily_cap, 0
  end
  return record.day_earned, math.max(0, cfg.daily_cap - record.day_earned),
    record.day_start + business.DAY_SECONDS - now
end

local function service_seconds(cfg)
  return math.floor(cfg.service.duration_ms / 1000)
end

local function clear_service(record)
  record.service_seed, record.service_started, record.service_seats, record.service_home = 0, 0, 0, ""
end

-- Empieza un servicio. `seed` la elige el servidor (neighborhood.lua).
function business.service_start(cfg, items, state, now, seed)
  if not business.is_open(state.home) then
    refuse("El restaurante está cerrado.")
  end
  local seats = check_ready(cfg, items, state, now, "No se puede atender")
  local record = state.business
  if record.service_started > 0 and now < record.service_started + service_seconds(cfg) + business.START_GRACE then
    refuse("Ya hay un servicio en marcha.", { reason = "active" })
  end
  record.service_seed = seed
  record.service_started = now
  record.service_seats = seats
  record.service_home = state.owner_id or ""
  local earned, left = day_view(cfg, record, now)
  return { seed = seed, seats = seats, started_unix = now, duration_ms = cfg.service.duration_ms,
    day_earned = earned, cap_left = left }
end

-- Termina un servicio: repite los toques y paga (con el tope diario). Si
-- el servicio no vale (toques imposibles, vencido, otra casa), se anula sin
-- pagar y responde valid = false con el motivo (no es un rechazo: así se
-- guarda que ya no está en marcha).
function business.service_finish(cfg, items, state, now, actions)
  local record = state.business
  if record.service_started <= 0 then
    refuse("No hay servicio que cobrar.")
  end
  local elapsed = now - record.service_started
  local min_elapsed = service_seconds(cfg) - business.FINISH_GRACE
  if elapsed < min_elapsed then
    refuse("El servicio todavía no terminó.", { reason = "too_early", seconds_left = min_elapsed - elapsed })
  end
  local seed, seats, home = record.service_seed, record.service_seats, record.service_home
  clear_service(record)
  local void = nil
  if elapsed > business.MAX_LATE then
    void = "Ese servicio ya venció (pasó más de un día)."
  elseif home ~= (state.owner_id or "") then
    void = "Ese servicio era de otra casa."
  end
  local result, why = nil, nil
  if void == nil then
    result, why = business.replay(cfg.service, seed, seats, actions)
    if result == nil then
      void = "El servicio no es válido (" .. why .. "): no se cobró."
    end
  end
  if void ~= nil then
    return { valid = false, error_text = void, coins = 0, pay = 0, money_change = 0 }
  end
  roll_day(record, now)
  local cap_left = math.max(0, cfg.daily_cap - record.day_earned)
  local pay = math.min(result.coins, cap_left)
  if pay > 0 and record.day_earned == 0 then
    record.day_start = now
  end
  record.day_earned = record.day_earned + pay
  record.services = record.services + 1
  record.best = math.max(record.best, result.coins)
  record.total = record.total + pay
  local xp = pay > 0 and result.served * cfg.xp_per_customer or 0
  local to_fund = rules.add_income(state, pay)
  state.xp = state.xp + xp
  result.valid = true
  result.pay = pay
  result.capped = pay < result.coins
  result.xp_gained = xp
  result.to_fund = to_fund
  result.money_change = to_fund and 0 or pay
  result.day_earned = record.day_earned
  result.daily_cap = cfg.daily_cap
  result.best = record.best
  return result
end


-- Lo que el teléfono necesita para el panel del restaurante.
function business.summary(cfg, items, state, now)
  local missing, seats = business.requirements(cfg, items, state.house, now)
  local record = state.business
  local earned, left, resets_in = day_view(cfg, record, now)
  local active = nil
  if record.service_started > 0 then
    active = { seed = record.service_seed, seats = record.service_seats, started_unix = record.service_started,
      seconds_left = math.max(0, record.service_started + service_seconds(cfg) - now) }
  end
  local missing_list = {}
  for _, m in ipairs(missing) do
    table.insert(missing_list, { id = m.id, name = m.name, need = m.need, have = m.have })
  end
  return {
    open = business.is_open(state.home),
    ready = #missing == 0,
    missing = missing_list,
    seats = seats,
    passive = business.passive_amount(cfg, state.home, now),
    passive_cap = cfg.passive_cap,
    passive_per_hour = cfg.passive_per_hour,
    day_earned = earned,
    cap_left = left,
    daily_cap = cfg.daily_cap,
    resets_in = resets_in,
    services = record.services,
    best = record.best,
    total = record.total,
    active = active,
    shared = state.shared == true,
  }
end

return business
