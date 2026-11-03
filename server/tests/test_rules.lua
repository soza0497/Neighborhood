--[[
Pruebas de las reglas del servidor (neighborhood_rules.lua), sin Nakama.
Usan los mismos data/*.json del juego.

Desde la carpeta del proyecto:
  lua5.1 server/tests/test_rules.lua

Tiene que terminar con "PRUEBAS LUA: N pasaron, 0 fallaron".
(En CachyOS, Lua 5.1 es el paquete `lua51` de pacman; Nakama usa Lua 5.1.)
]]

package.path = "server/nakama/modules/?.lua;" .. package.path
local rules = require("neighborhood_rules")

local passed, failed = 0, 0
local function check(condition, description)
  if condition then
    passed = passed + 1
  else
    failed = failed + 1
    print("FALLÓ: " .. description)
  end
end

-- Corre algo que debería ser rechazado; devuelve el rechazo (o nil).
local function refusal_of(fn, ...)
  local ok, err = pcall(fn, ...)
  if ok then
    return nil
  end
  if type(err) ~= "table" then
    error(err)
  end
  return err
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

local data = rules.new_data(read_data("catalog.json"), read_data("progression.json"), read_data("jobs.json"))

local NOW = 1800000000

local function new_state(money, xp)
  return {
    house = rules.empty_house(), money = money or 3000, xp = xp or 0,
    discovered = {}, history = { undo = {}, redo = {} }, work = rules.empty_work(),
  }
end

local function w(level, layer, key, value)
  return { level = level, layer = layer, key = key, value = value }
end


-- --- Precios (los mismos números que tests/test_economy.gd) ---

check(rules.piece_cost(data, "floors", { item = "floor_basic" }) == 10, "un piso cuesta 10")
check(rules.piece_cost(data, "walls", { item = "wall_basic", opening = "window_basic" }) == 80, "pared + ventana = 80")
check(rules.piece_cost(data, "roofs", { item = "roof_basic", rect = { 0, 0, 2, 3 } }) == 90, "techo de 2x3 = 90")
check(rules.change_for(data, "floors", nil, { item = "floor_basic" }) == -10, "poner un piso: -10")
check(rules.change_for(data, "floors", { item = "floor_basic" }, nil) == 5, "borrar un piso devuelve el 50 %")
check(rules.change_for(data, "floors", { item = "floor_basic" }, { item = "floor_basic", color = "#ffffff" }) == 0, "pintar es gratis")
check(rules.change_for(data, "floors", { item = "floor_basic" }, { item = "floor_tile" }) == -2, "cambiar de piso: la diferencia")
check(rules.change_for(data, "walls", { item = "wall_basic", opening = "door_basic" }, { item = "wall_basic" }) == 40, "quitar una puerta devuelve 40")
check(rules.accelerate_cost(data, 120) == 12, "acelerar 2 minutos = 12")
check(rules.accelerate_cost(data, 1) == 1, "acelerar cuesta al menos 1")
check(rules.accelerate_cost(data, 0) == 0, "sin espera no se paga")
check(rules.level_for_xp(data, 0) == 1 and rules.level_for_xp(data, 100) == 2 and rules.level_for_xp(data, 99999) == 6, "niveles")
check(rules.discovery_xp(data, "foundation_basic") == 5 and rules.discovery_xp(data, "bed_basic") == 30, "experiencia por descubrir")


-- --- Construir ---

local s = new_state()
local result = rules.build(data, s, {
  w(0, "foundation", "1,1", { item = "foundation_basic" }),
  w(0, "foundation", "2,1", { item = "foundation_basic", ready_at = 5 }),
}, NOW)
check(result.money_change == -10 and s.money == 2990, "dos cimientos cobran 10")
check(s.house.levels[1].foundation["1,1"].item == "foundation_basic", "la casa cambió")
check(s.house.levels[1].foundation["2,1"].ready_at == nil, "el servidor ignora el ready_at del teléfono")
check(result.xp_gained == 5 and s.xp == 5 and s.discovered.foundation_basic, "primera vez: experiencia")
check(#s.history.undo == 1 and #s.history.redo == 0, "un paso de deshacer")

result = rules.build(data, s, { w(0, "objects", "o7", { item = "bed_basic", cell = { 3, 3 }, rot = 0, extra = "basura" }) }, NOW)
local bed = s.house.levels[1].objects["o7"]
check(bed.ready_at == NOW + 30, "la cama tarda 30 s (hora del servidor)")
check(bed.extra == nil, "campos desconocidos se descartan")
check(s.house.next_id == 8, "el contador de objetos sigue al nombre nuevo")
check(s.money == 2990 - 300, "la cama cuesta 300")

-- Mover la cama: gratis y conserva la obra.
rules.build(data, s, { w(0, "objects", "o7", { item = "bed_basic", cell = { 5, 5 }, rot = 1 }) }, NOW + 10)
bed = s.house.levels[1].objects["o7"]
check(s.money == 2690 and bed.ready_at == NOW + 30 and bed.cell[1] == 5, "mover no cobra ni reinicia la obra")

-- Rechazos.
local r = refusal_of(rules.build, data, s, { w(0, "objects", "o9", { item = "stairs_basic", cell = { 1, 1 }, rot = 0 }) }, NOW)
check(r ~= nil and string.find(r.refusal, "nivel 2"), "la escalera pide nivel 2")
r = refusal_of(rules.build, data, new_state(5), { w(0, "objects", "o1", { item = "bed_basic", cell = { 1, 1 }, rot = 0 }) }, NOW)
check(r ~= nil and r.reason == "money" and string.find(r.refusal, "295"), "sin dinero: dice cuánto falta")
check(refusal_of(rules.build, data, s, { w(0, "floors", "1,1", { item = "bed_basic" }) }, NOW) ~= nil, "una cama no es un piso")
check(refusal_of(rules.build, data, s, { w(0, "floors", "40,1", { item = "floor_basic" }) }, NOW) ~= nil, "fuera de la parcela")
check(refusal_of(rules.build, data, s, { w(1, "foundation", "1,1", { item = "foundation_basic" }) }, NOW) ~= nil, "cimientos arriba no")
check(refusal_of(rules.build, data, s, { w(5, "floors", "1,1", { item = "floor_basic" }) }, NOW) ~= nil, "nivel inexistente")
check(refusal_of(rules.build, data, s, { w(0, "floors", "1,1", { item = "inventado" }) }, NOW) ~= nil, "pieza inventada")
check(refusal_of(rules.build, data, s, { w(0, "objects", "o2", { item = "bed_basic", cell = { 31, 31 }, rot = 0 }) }, NOW) ~= nil, "cama que sale de la parcela")
check(refusal_of(rules.build, data, s, { w(0, "walls", "h:1,1", { item = "wall_basic", opening = "bed_basic" }) }, NOW) ~= nil, "una cama no es una ventana")
check(refusal_of(rules.build, data, s, {}, NOW) ~= nil, "lista vacía")
check(refusal_of(rules.build, data, s, { w(0, "floors", "1,1", { item = "floor_basic", color = "rojo; DROP" }) }, NOW) ~= nil, "color inválido")
local money_before = s.money
check(refusal_of(rules.build, data, s, { w(0, "walls", "h:1,1", { item = "wall_brick" }) }, NOW) ~= nil and s.money == money_before,
  "pared de ladrillo bloqueada (nivel 3)")

-- Pieza bloqueada ya puesta (de antes): se puede pintar sin problema.
local locked = new_state()
locked.house.levels[1].walls["h:2,2"] = { item = "wall_brick" }
result = rules.build(data, locked, { w(0, "walls", "h:2,2", { item = "wall_brick", color = "#ffeeaa" }) }, NOW)
check(result.money_change == 0, "pintar algo bloqueado que ya estaba: gratis y permitido")


-- --- Deshacer / rehacer ---

local u = new_state(100)
rules.build(data, u, { w(0, "floors", "1,1", { item = "floor_basic" }), w(0, "floors", "2,1", { item = "floor_basic" }) }, NOW)
check(u.money == 80, "dos pisos: -20")
result = rules.undo(u)
check(u.money == 100 and u.house.levels[1].floors["1,1"] == nil and result.money_change == 20, "deshacer devuelve EXACTAMENTE lo cobrado")
check(#result.writes == 2 and result.writes[1].value == nil, "deshacer manda las escrituras inversas")
result = rules.redo(u)
check(u.money == 80 and u.house.levels[1].floors["2,1"] ~= nil and result.money_change == -20, "rehacer vuelve a cobrar")
check(u.xp == 5, "deshacer y rehacer no repiten la experiencia")
rules.build(data, u, { w(0, "floors", "1,1", nil) }, NOW)
check(u.money == 85, "borrar devuelve el 50 %")
rules.undo(u)
check(u.money == 80, "deshacer el borrado cobra lo devuelto")
check(refusal_of(rules.redo, new_state()) ~= nil and refusal_of(rules.undo, new_state()) ~= nil, "sin pasos no hace nada")

-- Si ya se gastó el dinero devuelto, no se deshace.
local spent = new_state(10)
rules.build(data, spent, { w(0, "floors", "1,1", { item = "floor_basic" }) }, NOW)
rules.build(data, spent, { w(0, "floors", "1,1", nil) }, NOW)
spent.money = 0
r = refusal_of(rules.undo, spent)
check(r ~= nil and r.reason == "money", "no alcanza para deshacer un borrado")

-- Hasta 100 pasos.
local many = new_state(100000)
for i = 1, 105 do
  rules.build(data, many, { w(0, "floors", (i % 30) .. "," .. math.floor(i / 30), { item = "floor_basic" }) }, NOW)
end
check(#many.history.undo == 100, "se guardan como mucho 100 pasos")
rules.undo(many)
rules.build(data, many, { w(0, "floors", "31,31", { item = "floor_basic" }) }, NOW)
check(#many.history.redo == 0, "un cambio nuevo borra lo que se podía rehacer")
-- Tope de tamaño.
local big = new_state(1000000)
local function measure(steps) return string.rep("x", #steps * 150 * 1024) end
rules.build(data, big, { w(0, "floors", "1,1", { item = "floor_basic" }) }, NOW, measure)
rules.build(data, big, { w(0, "floors", "2,1", { item = "floor_basic" }) }, NOW, measure)
rules.build(data, big, { w(0, "floors", "3,1", { item = "floor_basic" }) }, NOW, measure)
check(#big.history.undo == 2, "historial muy grande: se olvidan los pasos viejos")


-- --- Obras y acelerar ---

local a = new_state()
rules.build(data, a, { w(0, "objects", "o1", { item = "bed_basic", cell = { 1, 1 }, rot = 0 }),
  w(0, "objects", "o2", { item = "fridge_basic", cell = { 4, 4 }, rot = 0 }) }, NOW)
check(#rules.pending_construction(a.house, NOW) == 2, "dos obras en marcha")
check(#rules.pending_construction(a.house, NOW + 30) == 0, "a los 30 s terminaron")
local money = a.money
result = rules.accelerate_builds(data, a, NOW + 10)
check(result.money_change == -4 and a.money == money - 4, "acelerar 40 s de obras = 4 monedas")
check(#rules.pending_construction(a.house, NOW + 10) == 0 and a.house.levels[1].objects.o1.ready_at == nil, "obras terminadas")
check(#a.history.undo == 1, "acelerar no agrega un paso de deshacer")
check(refusal_of(rules.accelerate_builds, data, a, NOW) ~= nil, "sin obras no se acelera")
local poor = new_state(301)
rules.build(data, poor, { w(0, "objects", "o1", { item = "bed_basic", cell = { 1, 1 }, rot = 0 }) }, NOW)
check(refusal_of(rules.accelerate_builds, data, poor, NOW) ~= nil, "acelerar sin dinero: no")


-- --- Empleos ---

local j = new_state(100)
check(refusal_of(rules.job_apply, data, j, "cashier", NOW) ~= nil, "cajero pide nivel 2")
check(refusal_of(rules.job_apply, data, j, "inventado", NOW) ~= nil, "empleo inventado")
rules.job_apply(data, j, "courier", NOW)
check(j.work.applied_job == "courier" and j.work.resume_ready_at == NOW + 300, "currículum: responden en 5 min")
check(refusal_of(rules.job_apply, data, j, "courier", NOW) ~= nil, "no se manda otro mientras se espera")
check(not rules.resolve_resume(j, NOW + 299), "todavía no responden")
result = rules.accelerate_resume(data, j, NOW + 180)
check(result.money_change == -12 and j.money == 88 and j.work.job_id == "courier", "acelerar 2 min = 12 y te contratan")

-- Turnos (repartidor: 4 h, $30 por hora, 20 de experiencia).
rules.shift_start(data, j, NOW)
check(j.work.shift_started_unix == NOW, "empieza el turno")
check(refusal_of(rules.shift_start, data, j, NOW + 1) ~= nil, "no hay dos turnos a la vez")
r = refusal_of(rules.shift_complete, data, j, NOW + 10)
check(r ~= nil and r.reason == "too_early" and r.seconds_left == 12, "a los 10 s no se cobra (mínimo 24 s a x10, 2 de margen)")
result = rules.shift_complete(data, j, NOW + 24)
check(result.pay == 120 and j.money == 208 and j.xp == 20, "a los 24 s se cobra $120 y 20 de experiencia")
check(refusal_of(rules.shift_complete, data, j, NOW + 25) ~= nil, "un turno no se cobra dos veces")
r = refusal_of(rules.shift_start, data, j, NOW + 100)
check(r ~= nil and r.reason == "too_early" and r.seconds_left == 44, "como mucho un turno cada 144 s")
rules.shift_start(data, j, NOW + 144)
rules.job_quit(j)
check(j.work.job_id == "" and j.work.shift_started_unix == 0, "renunciar corta el turno sin cobrar")
check(refusal_of(rules.shift_start, data, j, NOW + 1000) ~= nil, "sin empleo no hay turno")


-- --- Al entrar: turno a medias y pago offline ---

local o = new_state(0)
o.work.job_id = "courier"
o.work.last_seen_unix = NOW
result = rules.settle(data, o, NOW + 100)
check(result.offline_shifts == 0 and o.money == 0, "menos de un día fuera: nada")
check(o.work.last_seen_unix == NOW + 100, "queda anotado cuándo entró")
result = rules.settle(data, o, NOW + 100 + 1440 * 2.5)
check(result.offline_shifts == 2 and result.offline_pay == 240 and o.xp == 40, "dos días fuera: dos turnos")
result = rules.settle(data, o, NOW + 1440 * 60)
check(result.offline_shifts == 3 and result.offline_pay == 360, "tope de 3 turnos")
result = rules.settle(data, o, NOW + 1440 * 60)
check(result.offline_shifts == 0, "entrar dos veces seguidas no paga doble")
o.work.shift_job = "courier"
o.work.shift_started_unix = NOW + 1440 * 60
o.work.last_shift_unix = NOW + 1440 * 60
result = rules.settle(data, o, NOW + 1440 * 60 + 5)
check(result.pending_pay == 0 and result.pending_seconds_left ~= nil, "turno a medias muy reciente: espera")
result = rules.settle(data, o, NOW + 1440 * 60 + 600)
check(result.pending_pay == 120 and o.work.shift_started_unix == 0, "turno a medias: se cobra al volver")
local nojob = new_state(0)
nojob.work.last_seen_unix = NOW
check(rules.settle(data, nojob, NOW + 1440 * 3).offline_shifts == 0, "sin empleo no hay pago offline")
local fresh = new_state(0)
fresh.work.job_id = "courier"
check(rules.settle(data, fresh, NOW).offline_shifts == 0, "cuenta sin registro de entrada: nada")


-- --- Datos guardados viejos o incompletos ---

local work = rules.normalize_work({ job_id = "courier", resume_ready_at = "basura" })
check(work.job_id == "courier" and work.resume_ready_at == 0 and work.applied_job == "", "trabajo incompleto se completa")
local house = rules.normalize_house({ levels = { { floors = { ["1,1"] = { item = "floor_basic" } } } }, next_id = 4 })
check(#house.levels == 2 and house.levels[2].walls ~= nil and house.next_id == 4, "casa incompleta se completa")


print(string.format("\nPRUEBAS LUA: %d pasaron, %d fallaron", passed, failed))
os.exit(failed > 0 and 1 or 0)
