--[[
Código del servidor del juego (Nakama, runtime Lua).

Desde la Fase 4B el servidor MANDA en el dinero y la propiedad: el teléfono
pide y el servidor decide (precios, nivel, obras, deshacer, empleos, turnos).
Las reglas están en neighborhood_rules.lua (sin nada de Nakama, se prueban
solas); este archivo lee y guarda el estado de cada jugador y registra las
funciones (RPC) que llama el teléfono.

RPC (el teléfono las llama con GameServer.call_rpc):
  game_load        todo lo que el teléfono necesita al entrar
  game_import      la primera vez: copia la partida del teléfono (y, una sola
                   vez, re-sincroniza las cuentas importadas en la 4A)
  build_apply      construir / quitar / mover / pintar  {writes}
  build_undo       deshacer el último paso (devuelve lo cobrado)
  build_redo       rehacer
  build_accelerate terminar todas las obras pagando
  job_apply        mandar currículum  {job_id}
  job_status       ¿ya respondieron al currículum?
  job_accelerate   pagar para que respondan ya
  job_quit         renunciar
  shift_start      empieza un turno de trabajo
  shift_complete   cobra el turno
  work_settle      al entrar: turno a medias + pago por días sin jugar
  game_heartbeat   "sigo jugando" (para no pagar offline lo que se jugó)

Toda respuesta es {ok, error?, state, ...}. ok = false con un texto para el
jugador cuando una regla no lo deja (no alcanza el dinero, nivel...).

Dónde se guarda cada cosa (storage de Nakama, por usuario):
  game/house      casa (texto JSON)                (solo el servidor la escribe)
  game/progress   experiencia y descubierto         (solo el servidor)
  game/work       empleo, currículum y turnos       (solo el servidor)
  game/history    pasos de deshacer (texto JSON)    (solo el servidor)
  cloud/character personaje                         (lo escribe el teléfono)
  cloud/settings  opciones del menú                 (lo escribe el teléfono)
  wallet "coins"  dinero (billetera de Nakama, con historial de movimientos)

Casa e historial viajan como TEXTO JSON (campo "json"): Lua no distingue
una lista vacía de un diccionario vacío, y así llegan al teléfono idénticos.

Después de cambiar este archivo: docker compose restart nakama
]]

local nk = require("nakama")
local rules = require("neighborhood_rules")

local STARTING_MONEY = 3000
local GAME = "game"
local CLOUD = "cloud"
-- Tamaño máximo de un texto guardado (una casa grande ocupa ~100 KB).
local MAX_TEXT = 512 * 1024
-- Experiencia máxima que se acepta al importar (más que esto es un error).
local MAX_XP = 10000000
-- Si dos pedidos del mismo jugador chocan al guardar, se reintenta.
local SAVE_ATTEMPTS = 4

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

-- Lee objetos del usuario. Devuelve "colección/clave" → objeto (con versión).
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

-- Dinero de la billetera del usuario.
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


-- --- Estado del jugador: leer y guardar ---

local STATE_KEYS = { { GAME, "house" }, { GAME, "progress" }, { GAME, "work" }, { GAME, "history" } }

-- Lee todo lo que el servidor guarda del jugador.
local function load_state(user_id)
  local objects = read_objects(user_id, STATE_KEYS)
  local house_object = value_of(objects, "game/house") or {}
  local progress = value_of(objects, "game/progress")
  local history = decode_text((value_of(objects, "game/history") or {}).json) or {}
  local state = {
    user_id = user_id,
    objects = objects,
    imported = progress ~= nil,
    house_source = house_object.source or "",
    house = rules.normalize_house(decode_text(house_object.json)),
    money = wallet_coins(user_id),
    xp = math.floor(rules.num(progress and progress.xp) or 0),
    discovered = {},
    work = rules.normalize_work(value_of(objects, "game/work")),
    history = { undo = history.undo or {}, redo = history.redo or {} },
    imported_unix = progress and progress.imported_unix or 0,
  }
  for _, id in ipairs(progress and progress.discovered or {}) do
    state.discovered[id] = true
  end
  state.start_money = state.money
  return state
end

local function storage_write(state, key, value)
  local write = {
    collection = GAME, key = key, user_id = state.user_id, value = value,
    permission_read = READ_OWNER, permission_write = WRITE_NONE,
  }
  -- Solo se guarda si nadie lo cambió desde que se leyó ("*" = no existía).
  local object = state.objects[GAME .. "/" .. key]
  write.version = object and object.version or "*"
  return write
end

-- Guarda lo que cambió (`changed` = {house = true, ...}) y el dinero, TODO
-- JUNTO: o se guarda todo o nada (multi_update de Nakama).
local function save_state(state, changed, reason)
  local writes = {}
  if changed.house then
    table.insert(writes, storage_write(state, "house",
      { json = nk.json_encode(state.house), saved_unix = now_unix(), source = "server" }))
  end
  if changed.progress then
    table.insert(writes, storage_write(state, "progress",
      { xp = state.xp, discovered = discovered_list(state.discovered), imported_unix = state.imported_unix }))
  end
  if changed.work then
    table.insert(writes, storage_write(state, "work", state.work))
  end
  if changed.history then
    table.insert(writes, storage_write(state, "history",
      { json = nk.json_encode({ undo = state.history.undo, redo = state.history.redo }) }))
  end
  local wallets = {}
  local money_change = state.money - state.start_money
  if money_change ~= 0 then
    table.insert(wallets, { user_id = state.user_id, changeset = { coins = money_change },
      metadata = { reason = reason } })
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
  }
end

local function encode_history(steps)
  return nk.json_encode(steps)
end

-- Arma un RPC del juego: lee el estado, corre la regla `action` y guarda.
-- `action(state, input, now)` devuelve {changed = {...}, reason, result}.
-- Si la regla dice que no (rules.refuse), responde ok = false y no guarda.
-- Si otro pedido del mismo jugador guardó en el medio, vuelve a empezar.
local function game_rpc(name, action)
  return function(context, payload)
    local user_id = require_user(context)
    local input = {}
    if payload ~= nil and payload ~= "" then
      local ok, decoded = pcall(nk.json_decode, payload)
      if not ok or type(decoded) ~= "table" then
        error("Pedido inválido")
      end
      input = decoded
    end
    for attempt = 1, SAVE_ATTEMPTS do
      local state = load_state(user_id)
      if not state.imported then
        return nk.json_encode({ ok = false, error = "La partida todavía no se cargó en el servidor." })
      end
      local ok, outcome = pcall(action, state, input, now_unix())
      if not ok then
        if type(outcome) == "table" and outcome.refusal ~= nil then
          local answer = { ok = false, error = outcome.refusal, reason = outcome.reason,
            seconds_left = outcome.seconds_left, state = summary(load_state(user_id)) }
          return nk.json_encode(answer)
        end
        error(outcome)
      end
      local saved, save_error = pcall(save_state, state, outcome.changed or {}, name)
      if saved then
        local answer = outcome.result or {}
        answer.ok = true
        answer.state = summary(state)
        return nk.json_encode(answer)
      end
      if not string.find(tostring(save_error), "version check failed", 1, true) or attempt == SAVE_ATTEMPTS then
        error(save_error)
      end
    end
  end
end


-- --- Cargar e importar ---

-- RPC game_load: lo que el teléfono necesita al entrar.
local function game_load(context, _payload)
  local user_id = require_user(context)
  local state = load_state(user_id)
  local cloud = read_objects(user_id, { { CLOUD, "character" }, { CLOUD, "settings" } })
  local character = value_of(cloud, "cloud/character") or {}
  local settings = value_of(cloud, "cloud/settings") or {}
  local house_json = (value_of(state.objects, "game/house") or {}).json or ""
  local answer = summary(state)
  answer.imported = state.imported
  answer.house_source = state.house_source
  answer.house = house_json
  answer.character = character.json or ""
  answer.character_saved_unix = character.saved_unix or 0
  answer.settings = settings.json or ""
  answer.settings_saved_unix = settings.saved_unix or 0
  return nk.json_encode(answer)
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
  for level = 1, rules.MAX_LEVELS do
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
  local existing = read_objects(user_id, { { GAME, "progress" }, { GAME, "house" } })
  local progress = value_of(existing, "game/progress")
  local house_object = value_of(existing, "game/house") or {}
  local resync = progress ~= nil and house_object.source == "import"
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
    write("history", { json = nk.json_encode({ undo = {}, redo = {} }) }, nil),
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

local function build_apply(state, input, now)
  local result = rules.build(data, state, input.writes, now, encode_history)
  return { changed = { house = true, progress = result.xp_gained > 0, history = true }, result = result }
end

local function build_undo(state, _input, _now)
  return { changed = { house = true, history = true }, result = rules.undo(state) }
end

local function build_redo(state, _input, _now)
  return { changed = { house = true, history = true }, result = rules.redo(state) }
end

local function build_accelerate(state, _input, now)
  return { changed = { house = true }, result = rules.accelerate_builds(data, state, now) }
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

local function shift_complete(state, _input, now)
  local result = rules.shift_complete(data, state, now)
  state.work.last_seen_unix = now
  return { changed = { work = true, progress = result.xp_gained > 0 }, result = result }
end

local function work_settle(state, _input, now)
  local result = rules.settle(data, state, now)
  return { changed = { work = true, progress = result.xp_gained > 0 }, result = result }
end

local function game_heartbeat(state, _input, now)
  state.work.last_seen_unix = now
  return { changed = { work = true } }
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
