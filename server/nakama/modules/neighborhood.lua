--[[
Código del servidor del juego (Nakama, runtime Lua).

Fase 4A: cargar la partida de la cuenta e importar UNA vez la partida local.
  game_load   → todo lo que el teléfono necesita al entrar.
  game_import → la primera vez: copia la casa, la experiencia y lo descubierto
                del teléfono; el dinero empieza en el inicial.

Dónde se guarda cada cosa (storage de Nakama, por usuario):
  game/house      casa del jugador         (solo el servidor la escribe)
  game/progress   experiencia y descubierto (solo el servidor la escribe)
  cloud/character personaje                 (lo escribe el teléfono)
  cloud/settings  opciones del menú         (lo escribe el teléfono)
  wallet "coins"  dinero (billetera de Nakama, con historial)

La casa, el personaje y las opciones viajan como TEXTO JSON (campo "json"):
en la 4A el servidor todavía no los lee, y así llegan al teléfono idénticos
(Lua no distingue una lista vacía de un diccionario vacío).

Después de cambiar este archivo: docker compose restart nakama
]]

local nk = require("nakama")

local STARTING_MONEY = 3000
local GAME = "game"
local CLOUD = "cloud"
-- Tamaño máximo de un texto guardado (una casa grande ocupa ~100 KB).
local MAX_TEXT = 512 * 1024
-- Experiencia máxima que se acepta al importar (más que esto es un error).
local MAX_XP = 10000000

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

-- Ids de todas las piezas del catálogo (el mismo catalog.json del juego).
local catalog = read_game_data("catalog.json")
local item_ids = {}
local item_count = 0
for _, item in ipairs(catalog.items or {}) do
  item_ids[item.id] = true
  item_count = item_count + 1
end
nk.logger_info(string.format("Catálogo del juego leído: %d piezas", item_count))


local function now_unix()
  return math.floor(nk.time() / 1000)
end

-- Lee varios objetos del usuario. Devuelve "colección/clave" → valor.
local function read_objects(user_id, keys)
  local reads = {}
  for _, k in ipairs(keys) do
    table.insert(reads, { collection = k[1], key = k[2], user_id = user_id })
  end
  local result = {}
  for _, object in ipairs(nk.storage_read(reads)) do
    result[object.collection .. "/" .. object.key] = object.value
  end
  return result
end

-- Dinero de la billetera del usuario.
local function wallet_coins(user_id)
  local account = nk.account_get_id(user_id)
  local wallet = account.wallet or {}
  if type(wallet) == "string" then
    wallet = nk.json_decode(wallet)
  end
  return math.floor(tonumber(wallet.coins) or 0)
end

-- Un texto JSON que mandó el teléfono, o "" si no sirve.
local function clean_text(value)
  if type(value) ~= "string" or #value > MAX_TEXT then
    return ""
  end
  return value
end

local function require_user(context)
  if context.user_id == nil or context.user_id == "" then
    error("Hace falta iniciar sesión")
  end
  return context.user_id
end


-- RPC game_load: lo que el teléfono necesita al entrar.
local function game_load(context, _payload)
  local user_id = require_user(context)
  local objects = read_objects(user_id, {
    { GAME, "house" }, { GAME, "progress" }, { CLOUD, "character" }, { CLOUD, "settings" },
  })
  local house = objects["game/house"] or {}
  local progress = objects["game/progress"]
  local character = objects["cloud/character"] or {}
  local settings = objects["cloud/settings"] or {}
  return nk.json_encode({
    imported = progress ~= nil,
    house = house.json or "",
    xp = progress and progress.xp or 0,
    discovered = progress and progress.discovered or {},
    money = wallet_coins(user_id),
    character = character.json or "",
    character_saved_unix = character.saved_unix or 0,
    settings = settings.json or "",
    settings_saved_unix = settings.saved_unix or 0,
    server_unix = now_unix(),
  })
end


-- RPC game_import: la primera vez que la cuenta entra, copia la partida del
-- teléfono. Si ya se importó, no hace nada (y devuelve lo de game_load).
local function game_import(context, payload)
  local user_id = require_user(context)
  local existing = read_objects(user_id, { { GAME, "progress" } })
  if existing["game/progress"] ~= nil then
    return game_load(context, "")
  end

  local ok, data = pcall(nk.json_decode, payload)
  if not ok or type(data) ~= "table" then
    error("Datos de importación inválidos")
  end

  local xp = math.floor(tonumber(data.xp) or 0)
  xp = math.max(0, math.min(xp, MAX_XP))
  -- Solo se aceptan piezas que existen en el catálogo.
  local discovered = {}
  for _, id in ipairs(type(data.discovered) == "table" and data.discovered or {}) do
    if type(id) == "string" and item_ids[id] then
      table.insert(discovered, id)
    end
  end

  local now = now_unix()
  local writes = {
    {
      collection = GAME, key = "house", user_id = user_id,
      value = { json = clean_text(data.house), saved_unix = now, source = "import" },
      permission_read = READ_OWNER, permission_write = WRITE_NONE,
    },
    {
      -- version "*" = solo si no existe: si dos importaciones llegan juntas,
      -- la segunda falla y no se duplica nada.
      collection = GAME, key = "progress", user_id = user_id, version = "*",
      value = { xp = xp, discovered = discovered, imported_unix = now },
      permission_read = READ_OWNER, permission_write = WRITE_NONE,
    },
  }
  -- Personaje y opciones: solo si el teléfono no los subió ya.
  local cloud = read_objects(user_id, { { CLOUD, "character" }, { CLOUD, "settings" } })
  for _, name in ipairs({ "character", "settings" }) do
    local text = clean_text(data[name])
    if text ~= "" and cloud[CLOUD .. "/" .. name] == nil then
      table.insert(writes, {
        collection = CLOUD, key = name, user_id = user_id,
        value = { json = text, saved_unix = now },
        permission_read = READ_OWNER, permission_write = WRITE_OWNER,
      })
    end
  end
  nk.storage_write(writes)

  -- El dinero empieza en el inicial (decisión del dueño), no en el del teléfono.
  nk.wallet_update(user_id, { coins = STARTING_MONEY - wallet_coins(user_id) },
    { reason = "starting_money" }, true)
  nk.logger_info(string.format("Partida importada: usuario %s, xp %d, %d piezas descubiertas",
    user_id, xp, #discovered))
  return game_load(context, "")
end


nk.register_rpc(game_load, "game_load")
nk.register_rpc(game_import, "game_import")
