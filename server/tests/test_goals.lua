--[[
Pruebas de la meta del barrio (Fase 8D, neighborhood_goals.lua), sin Nakama.
Usan el mismo data/neighborhood.json y data/catalog.json del juego.

Desde la carpeta del proyecto:
  lua5.1 server/tests/test_goals.lua

Tiene que terminar con "PRUEBAS METAS: N pasaron, 0 fallaron".
Los números esperados (vecinos 0, 1, 3, 6, 7... plantas por día; tope diario 10;
recompensa $150 + 30 XP) son LOS MISMOS que verifica tests/test_neighborhood.gd
para la copia del teléfono (scripts/neighborhood/neighborhood_goal.gd).
]]

package.path = "server/nakama/modules/?.lua;" .. package.path
local rules = require("neighborhood_rules")
local goals = require("neighborhood_goals")

local passed, failed = 0, 0
local function check(condition, description)
  if condition then
    passed = passed + 1
  else
    failed = failed + 1
    print("FALLÓ: " .. description)
  end
end

-- --- Lector de JSON mínimo (solo para leer data/*.json en las pruebas) ---

local function decode_json(text)
  local pos = 1
  local function skip()
    pos = string.find(text, "[^%s]", pos) or (#text + 1)
  end
  local value
  local function str()
    local result, i = {}, pos + 1
    while true do
      local c = string.sub(text, i, i)
      if c == '"' then break end
      if c == "\\" then
        local n = string.sub(text, i + 1, i + 1)
        local map = { n = "\n", t = "\t", ['"'] = '"', ["\\"] = "\\", ["/"] = "/" }
        if n == "u" then
          table.insert(result, "?")
          i = i + 6
        else
          table.insert(result, map[n] or n)
          i = i + 2
        end
      else
        table.insert(result, c)
        i = i + 1
      end
    end
    pos = i + 1
    return table.concat(result)
  end
  value = function()
    skip()
    local c = string.sub(text, pos, pos)
    if c == "{" then
      local obj = {}
      pos = pos + 1
      skip()
      if string.sub(text, pos, pos) == "}" then pos = pos + 1 return obj end
      while true do
        skip()
        local k = str()
        skip()
        pos = pos + 1 -- ':'
        obj[k] = value()
        skip()
        local d = string.sub(text, pos, pos)
        pos = pos + 1
        if d == "}" then return obj end
      end
    elseif c == "[" then
      local arr = {}
      pos = pos + 1
      skip()
      if string.sub(text, pos, pos) == "]" then pos = pos + 1 return arr end
      while true do
        table.insert(arr, value())
        skip()
        local d = string.sub(text, pos, pos)
        pos = pos + 1
        if d == "]" then return arr end
      end
    elseif c == '"' then
      return str()
    elseif string.sub(text, pos, pos + 3) == "true" then
      pos = pos + 4 return true
    elseif string.sub(text, pos, pos + 4) == "false" then
      pos = pos + 5 return false
    elseif string.sub(text, pos, pos + 3) == "null" then
      pos = pos + 4 return nil
    end
    local number = string.match(text, "^-?[%d%.eE+-]+", pos)
    pos = pos + #number
    return tonumber(number)
  end
  return value()
end

local function read_data(name)
  local file = assert(io.open("data/" .. name, "r"))
  local text = file:read("*a")
  file:close()
  return decode_json(text)
end


local function read_data(name)
  local file = assert(io.open("data/" .. name, "r"))
  local text = file:read("*a")
  file:close()
  return decode_json(text)
end

local data = rules.new_data(read_data("catalog.json"), read_data("progression.json"), read_data("jobs.json"))
local cfg = goals.new_config(read_data("neighborhood.json"))
local DAY = 86400
local T0 = 1800000000 - (1800000000 % DAY)  -- Un comienzo de día.

-- Una casa con `n` plantas terminadas, `m` en obra y un sofá (no cuenta).
local function house_with(plants, building)
  local objects = {}
  for i = 1, plants do
    objects["o" .. i] = { item = "plant_pot", cell = { i, 1 }, rot = 0 }
  end
  for i = 1, building do
    objects["b" .. i] = { item = "plant_tall", cell = { i, 3 }, rot = 0, ready_at = T0 + 1000 }
  end
  objects["sofa"] = { item = "sofa_basic", cell = { 1, 5 }, rot = 0 }
  return { levels = { { objects = objects } } }
end

-- --- La configuración sale de los datos ---
check(cfg.id == "plants_together" and cfg.target == 50 and cfg.daily_cap == 10, "meta: 50 plantas, tope diario 10")
check(cfg.categories.plants == true, "cuenta la categoría plantas")
check(cfg.reward_money == 150 and cfg.reward_xp == 30, "recompensa chica: $150 y 30 XP")
local bad = goals.new_config({})
check(bad.target == 50 and bad.daily_cap == 10, "sin datos usa valores seguros")

-- --- Qué cuenta ---
check(goals.count_items(cfg, house_with(4, 0), data.items, T0) == 4, "4 plantas terminadas cuentan 4 (el sofá no)")
check(goals.count_items(cfg, house_with(4, 2), data.items, T0) == 4, "las plantas en obra todavía no cuentan")
check(goals.count_items(cfg, house_with(4, 2), data.items, T0 + 2000) == 6, "terminada la obra, cuentan")
check(goals.count_items(cfg, { levels = {} }, data.items, T0) == 0, "casa vacía: 0")

-- --- Vecinos simulados: determinista según el día y con tope ---
local expected = { [0] = 0, 1, 3, 6, 7, 9, 12, 13, 15, 18, 19 }
for days, value in pairs(expected) do
  check(goals.neighbors_progress(cfg, days) == value, "vecinos al día " .. days .. " = " .. value)
end
check(goals.neighbors_progress(cfg, 100000) == 30, "los vecinos nunca pasan del 60 % de la meta (30)")
check(goals.neighbors_progress(cfg, 5) == goals.neighbors_progress(cfg, 5), "siempre da lo mismo")

-- --- Aporte del jugador: tope diario, nunca baja, no se repite ---
local record = goals.normalize_record(nil, cfg)
check(record.started_day == -1 and record.mine == 0 and not record.claimed, "registro nuevo vacío")
local gained, dirty = goals.update(cfg, record, T0, 0)
check(gained == 0 and dirty and record.started_day == goals.day_of(T0), "primer contacto: empieza la cuenta de días")
gained = goals.update(cfg, record, T0 + 10, 4)
check(gained == 4 and record.mine == 4 and record.today == 4, "4 plantas → aporte 4")
gained, dirty = goals.update(cfg, record, T0 + 20, 4)
check(gained == 0 and not dirty, "mirar de nuevo no suma otra vez")
gained = goals.update(cfg, record, T0 + 30, 20)
check(gained == 6 and record.mine == 10 and record.today == 10, "tope diario: hoy solo 10 (acreditó 6 de las 16 nuevas)")
gained = goals.update(cfg, record, T0 + 40, 20)
check(gained == 0, "ese mismo día no pasa de 10")
gained = goals.update(cfg, record, T0 + DAY + 5, 20)
check(gained == 10 and record.mine == 20, "al día siguiente se acreditan las que faltaban (otras 10)")
gained = goals.update(cfg, record, T0 + DAY + 6, 5)
check(gained == 0 and record.mine == 20, "sacar plantas no resta lo acreditado")
gained = goals.update(cfg, record, T0 + 2 * DAY, 20)
check(gained == 0, "sacar y volver a poner las mismas plantas no suma de nuevo")
gained = goals.update(cfg, record, T0 + 2 * DAY + 1, 23)
check(gained == 3 and record.mine == 23, "plantas realmente nuevas sí suman")

-- --- Resumen: vecinos + jugador ---
local s = goals.summary(cfg, record, T0 + 2 * DAY + 2)
check(s.mine == 23 and s.neighbors == 3 and s.total == 26 and not s.completed, "al día 2: vecinos 3 + yo 23 = 26 de 50")
check(s.today == 3 and s.daily_cap == 10, "hoy llevo 3 de 10")
s = goals.summary(cfg, record, T0 + 10 * DAY)
check(s.neighbors == 19 and s.total == 42 and not s.completed, "no hay fecha límite: pasan los días y la meta espera")
local lazy = goals.normalize_record(nil, cfg)
goals.update(cfg, lazy, T0, 0)
check(not goals.summary(cfg, lazy, T0 + 1000 * DAY).completed, "sin jugar nunca se cumple solo (vecinos máx. 30 de 50)")

-- --- Cumplir y retirar la recompensa ---
local now = T0 + 12 * DAY
record = goals.normalize_record(nil, cfg)
goals.update(cfg, record, T0, 0)
local reward, why = goals.claim(cfg, record, now)
check(reward == nil and why ~= nil, "sin cumplir no hay recompensa")
for day = 0, 1 do
  goals.update(cfg, record, T0 + day * DAY + 5, 20)
end
s = goals.summary(cfg, record, T0 + 30 * DAY)
check(s.completed and s.mine == 20 and s.neighbors == 30, "20 mías + 30 de los vecinos = 50: cumplida")
reward = goals.claim(cfg, record, T0 + 30 * DAY)
check(reward ~= nil and reward.money == 150 and reward.xp == 30, "retira $150 y 30 XP")
reward, why = goals.claim(cfg, record, T0 + 30 * DAY)
check(reward == nil and record.claimed, "solo una vez")
local free = goals.normalize_record(nil, cfg)
goals.update(cfg, free, T0, 0)
reward, why = goals.claim(cfg, free, T0 + 1000 * DAY)
check(reward == nil, "quien no aportó nada no cobra (aunque la meta se cumpla)")

-- --- Registros raros ---
local weird = goals.normalize_record({ goal = "plants_together", mine = -5, credited = "x", today = 99999 }, cfg)
check(weird.mine == 0 and weird.credited == 0, "registro dañado: se limpia")
local other = goals.normalize_record({ goal = "otra_meta", mine = 40 }, cfg)
check(other.mine == 0, "un registro de otra meta empieza de cero")

print(string.format("\nPRUEBAS METAS: %d pasaron, %d fallaron", passed, failed))
os.exit(failed > 0 and 1 or 0)
