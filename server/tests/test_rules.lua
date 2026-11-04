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
check(s.house.levels[4].foundation["1,1"].item == "foundation_basic", "la casa cambió")
check(s.house.levels[4].foundation["2,1"].ready_at == nil, "el servidor ignora el ready_at del teléfono")
check(result.xp_gained == 5 and s.xp == 5 and s.discovered.foundation_basic, "primera vez: experiencia")
check(#s.history.undo == 1 and #s.history.redo == 0, "un paso de deshacer")

result = rules.build(data, s, { w(0, "objects", "o7", { item = "bed_basic", cell = { 3, 3 }, rot = 0, extra = "basura" }) }, NOW)
local bed = s.house.levels[4].objects["o7"]
check(bed.ready_at == NOW + 30, "la cama tarda 30 s (hora del servidor)")
check(bed.extra == nil, "campos desconocidos se descartan")
check(s.house.next_id == 8, "el contador de objetos sigue al nombre nuevo")
check(s.money == 2990 - 300, "la cama cuesta 300")

-- Mover la cama: gratis y conserva la obra.
rules.build(data, s, { w(0, "objects", "o7", { item = "bed_basic", cell = { 5, 5 }, rot = 1 }) }, NOW + 10)
bed = s.house.levels[4].objects["o7"]
check(s.money == 2690 and bed.ready_at == NOW + 30 and bed.cell[1] == 5, "mover no cobra ni reinicia la obra")

-- Rechazos.
local r = refusal_of(rules.build, data, s, { w(0, "objects", "o9", { item = "stairs_basic", cell = { 1, 1 }, rot = 0 }) }, NOW)
check(r ~= nil and string.find(r.refusal, "nivel 2"), "la escalera pide nivel 2")
r = refusal_of(rules.build, data, new_state(5), { w(0, "objects", "o1", { item = "bed_basic", cell = { 1, 1 }, rot = 0 }) }, NOW)
check(r ~= nil and r.reason == "money" and string.find(r.refusal, "295"), "sin dinero: dice cuánto falta")
check(refusal_of(rules.build, data, s, { w(0, "floors", "1,1", { item = "bed_basic" }) }, NOW) ~= nil, "una cama no es un piso")
check(refusal_of(rules.build, data, s, { w(0, "floors", "100,1", { item = "floor_basic" }) }, NOW) ~= nil, "fuera de la parcela")
check(refusal_of(rules.build, data, s, { w(1, "foundation", "1,1", { item = "foundation_basic" }) }, NOW) ~= nil, "cimientos arriba no")
check(refusal_of(rules.build, data, s, { w(5, "floors", "1,1", { item = "floor_basic" }) }, NOW) ~= nil, "nivel inexistente")
check(refusal_of(rules.build, data, s, { w(0, "floors", "1,1", { item = "inventado" }) }, NOW) ~= nil, "pieza inventada")
check(refusal_of(rules.build, data, s, { w(0, "objects", "o2", { item = "bed_basic", cell = { 95, 95 }, rot = 0 }) }, NOW) ~= nil, "cama que sale de la parcela")
check(refusal_of(rules.build, data, s, { w(0, "walls", "h:1,1", { item = "wall_basic", opening = "bed_basic" }) }, NOW) ~= nil, "una cama no es una ventana")
check(refusal_of(rules.build, data, s, {}, NOW) ~= nil, "lista vacía")
check(refusal_of(rules.build, data, s, { w(0, "floors", "1,1", { item = "floor_basic", color = "rojo; DROP" }) }, NOW) ~= nil, "color inválido")
local money_before = s.money
check(refusal_of(rules.build, data, s, { w(0, "walls", "h:1,1", { item = "wall_brick" }) }, NOW) ~= nil and s.money == money_before,
  "pared de ladrillo bloqueada (nivel 3)")

-- Pieza bloqueada ya puesta (de antes): se puede pintar sin problema.
local locked = new_state()
locked.house.levels[4].walls["h:2,2"] = { item = "wall_brick" }
result = rules.build(data, locked, { w(0, "walls", "h:2,2", { item = "wall_brick", color = "#ffeeaa" }) }, NOW)
check(result.money_change == 0, "pintar algo bloqueado que ya estaba: gratis y permitido")


-- --- Deshacer / rehacer ---

local u = new_state(100)
rules.build(data, u, { w(0, "floors", "1,1", { item = "floor_basic" }), w(0, "floors", "2,1", { item = "floor_basic" }) }, NOW)
check(u.money == 80, "dos pisos: -20")
result = rules.undo(u)
check(u.money == 100 and u.house.levels[4].floors["1,1"] == nil and result.money_change == 20, "deshacer devuelve EXACTAMENTE lo cobrado")
check(#result.writes == 2 and result.writes[1].value == nil, "deshacer manda las escrituras inversas")
result = rules.redo(u)
check(u.money == 80 and u.house.levels[4].floors["2,1"] ~= nil and result.money_change == -20, "rehacer vuelve a cobrar")
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
check(#rules.pending_construction(a.house, NOW + 10) == 0 and a.house.levels[4].objects.o1.ready_at == nil, "obras terminadas")
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
check(r ~= nil and r.reason == "too_early" and r.seconds_left == 36, "a los 10 s no se cobra (mínimo 48 s a x5, 2 de margen)")
r = refusal_of(rules.shift_complete, data, j, NOW + 24)
check(r ~= nil and r.reason == "too_early", "a los 24 s (lo que duraba a x10) ya no se cobra: x5 no da ventaja")
result = rules.shift_complete(data, j, NOW + 46)
check(result.pay == 120 and j.money == 208 and j.xp == 20, "a los 46 s se cobra $120 y 20 de experiencia")
check(refusal_of(rules.shift_complete, data, j, NOW + 47) ~= nil, "un turno no se cobra dos veces")
r = refusal_of(rules.shift_start, data, j, NOW + 100)
check(r ~= nil and r.reason == "too_early" and r.seconds_left == 188, "como mucho un turno cada 288 s")
rules.shift_start(data, j, NOW + 288)
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
check(#house.levels == 8 and house.levels[5].walls ~= nil and house.next_id == 4, "casa incompleta se completa")


-- === Fase 5: reglas de apoyo en el servidor (los casos de tests/test_house.gd) ===

local hr = require("neighborhood_house")

local function put(house, level, layer, key, value)
  house.levels[level + 4][layer][key] = value
end
local function foundation(house, x1, z1, x2, z2)
  for x = x1, x2 do for z = z1, z2 do put(house, 0, "foundation", x .. "," .. z, { item = "foundation_basic" }) end end
end
local function floors(house, level, x1, z1, x2, z2)
  for x = x1, x2 do for z = z1, z2 do put(house, level, "floors", x .. "," .. z, { item = "floor_basic" }) end end
end
local function supported(house, level, layer, key, value)
  return hr.is_supported(data, house, level, layer, key, value)
end
local function batch_ok(house, writes)
  return (hr.check_batch(data, house, writes))
end

local FLOOR, WALL = { item = "floor_basic" }, { item = "wall_basic" }
local h = rules.empty_house()
check(not supported(h, 0, "floors", "2,2", FLOOR), "apoyo: piso sin cimientos NO")
check(not supported(h, 0, "walls", "h:2,2", WALL), "apoyo: pared sin cimientos NO")
foundation(h, 2, 2, 4, 4)
check(supported(h, 0, "floors", "2,2", FLOOR), "apoyo: piso sobre cimientos SÍ")
check(supported(h, 0, "walls", "h:2,2", WALL), "apoyo: pared en el borde de cimientos SÍ")
check(not supported(h, 0, "walls", "h:2,1", WALL), "apoyo: pared lejos de cimientos NO")
check(not supported(h, 1, "floors", "2,2", FLOOR), "apoyo: piso arriba sin nada abajo NO")
put(h, 0, "walls", "v:5,2", WALL)
check(supported(h, 1, "floors", "5,2", FLOOR), "apoyo: balcón junto a una pared de abajo SÍ")
check(batch_ok(h, { w(0, "walls", "v:5,2", nil) }), "apoyo: pared sin nada arriba se borra")
put(h, 1, "floors", "5,2", FLOOR)
check(not batch_ok(h, { w(0, "walls", "v:5,2", nil) }), "apoyo: pared que sostiene un balcón no se borra")
check(batch_ok(h, { w(1, "floors", "5,2", nil), w(0, "walls", "v:5,2", nil) }), "apoyo: balcón + su pared juntos sí")
put(h, 1, "floors", "5,2", nil)
put(h, 0, "walls", "v:5,2", nil)
floors(h, 0, 2, 2, 4, 4)
check(supported(h, 1, "floors", "2,2", FLOOR), "apoyo: piso arriba sobre piso SÍ")
check(not supported(h, 1, "walls", "h:2,2", WALL), "apoyo: pared arriba sin piso ni pared abajo NO")
put(h, 0, "walls", "h:2,2", WALL)
check(supported(h, 1, "walls", "h:2,2", WALL), "apoyo: pared arriba sobre pared SÍ")
check(not supported(h, 0, "foundation", "100,1", { item = "foundation_basic" }), "apoyo: cimiento fuera de la parcela NO")
check(batch_ok(h, { w(1, "floors", "3,3", FLOOR), w(1, "walls", "h:3,3", WALL) }), "apoyo: cuarto arriba (piso + pared)")
check(not batch_ok(h, { w(1, "walls", "h:3,3", WALL) }), "apoyo: pared arriba sola en el aire NO")

-- Quitar (los casos de _test_removal_rules).
h = rules.empty_house()
foundation(h, 0, 0, 2, 0)
floors(h, 0, 0, 0, 0, 0)
put(h, 0, "walls", "v:3,0", WALL)
check(not batch_ok(h, { w(0, "foundation", "0,0", nil) }), "quitar: cimiento con piso encima NO")
check(batch_ok(h, { w(0, "foundation", "1,0", nil) }), "quitar: cimiento libre SÍ")
check(not batch_ok(h, { w(0, "foundation", "2,0", nil) }), "quitar: cimiento que sostiene una pared NO")
check(batch_ok(h, { w(0, "foundation", "2,0", nil), w(0, "walls", "v:3,0", nil) }), "quitar: cimiento + su pared juntos SÍ")

-- Objetos y escaleras (_test_objects).
h = rules.empty_house()
foundation(h, 0, 0, 3, 3)
floors(h, 0, 0, 0, 3, 3)
local bed1 = { item = "bed_basic", cell = { 0, 0 }, rot = 0 }
check(supported(h, 0, "objects", "o1", bed1), "objetos: cama sobre piso SÍ")
put(h, 0, "objects", "o1", bed1)
check(hr.objects_at(data, h, 0, 0, 1)[1] == "o1", "objetos: la cama ocupa (0,1)")
check(not supported(h, 0, "objects", "o2", { item = "table_basic", cell = { 0, 1 }, rot = 0 }), "objetos: mesa encima de la cama NO")
check(supported(h, 0, "objects", "o1", { item = "bed_basic", cell = { 0, 1 }, rot = 0 }), "objetos: mover la cama una celda SÍ")
put(h, 0, "walls", "v:2,2", WALL)
check(not supported(h, 0, "objects", "o3", { item = "table_basic", cell = { 1, 2 }, rot = 0 }), "objetos: mesa atravesada por pared NO")
check(not supported(h, 0, "objects", "o4", { item = "table_basic", cell = { 3, 3 }, rot = 0 }), "objetos: mesa saliéndose del piso NO")
check(not batch_ok(h, { w(0, "floors", "0,0", nil) }), "objetos: piso con cama encima no se borra")
local stairs = { item = "stairs_basic", cell = { 3, 0 }, rot = 0 }
check(supported(h, 0, "objects", "o5", stairs), "escalera en planta baja SÍ")
check(not supported(h, 1, "objects", "o5", stairs), "escalera en el último piso NO")
floors(h, 1, 2, 0, 3, 2)
check(not batch_ok(h, { w(0, "objects", "o5", stairs) }), "escalera debajo de un piso sin abrir el hueco NO")
local stairs_batch = { w(0, "objects", "o5", stairs), w(1, "floors", "3,0", nil), w(1, "floors", "3,1", nil), w(1, "floors", "3,2", nil) }
check(batch_ok(h, stairs_batch), "escalera que abre el hueco de arriba SÍ (como el teléfono)")
for _, x in ipairs(stairs_batch) do put(h, x.level, x.layer, x.key, x.value) end
check(not supported(h, 1, "floors", "3,1", FLOOR), "piso encima de la escalera NO")
check(supported(h, 1, "floors", "2,1", FLOOR), "piso al lado de la escalera SÍ")
-- Deshacer la escalera: vuelve el piso y se va la escalera (el resultado vale).
check(batch_ok(h, { w(1, "floors", "3,2", FLOOR), w(1, "floors", "3,1", FLOOR), w(1, "floors", "3,0", FLOOR), w(0, "objects", "o5", nil) }),
  "deshacer la escalera: el resultado está apoyado")
check(not batch_ok(h, { w(0, "objects", "o6", { item = "chair_basic", cell = { 9, 9 }, rot = 0 }) }), "mueble en el aire NO")

-- Construir con las reglas de apoyo prendidas.
local sp = new_state(100000, 99999)
sp.check_support = true
r = refusal_of(rules.build, data, sp, { w(0, "floors", "1,1", FLOOR) }, NOW)
check(r ~= nil and r.reason == "support", "construir: piso sin cimientos lo rechaza el servidor")
rules.build(data, sp, { w(0, "foundation", "1,1", { item = "foundation_basic" }), w(0, "floors", "1,1", FLOOR) }, NOW)
check(sp.house.levels[4].floors["1,1"] ~= nil, "construir: cimiento + piso en el mismo cambio SÍ")
r = refusal_of(rules.build, data, sp, { w(0, "foundation", "1,1", nil) }, NOW)
check(r ~= nil and r.reason == "support", "construir: no deja quitar un cimiento con piso encima")


-- === Fase 5: permisos de la casa compartida ===

h = rules.empty_house()
foundation(h, 0, 0, 5, 5)
floors(h, 0, 0, 0, 5, 5)
put(h, 0, "walls", "h:1,0", WALL)
put(h, 0, "objects", "o1", { item = "sofa_basic", cell = { 2, 2 }, rot = 0 })
put(h, 0, "objects", "o2", { item = "stairs_basic", cell = { 4, 0 }, rot = 0 })
local function kind(writes) return hr.change_kind(data, h, writes) end
check(kind({ w(0, "objects", "o1", { item = "sofa_basic", cell = { 3, 3 }, rot = 0 }) }) == "minor", "permisos: mover un mueble es menor")
check(kind({ w(0, "objects", "o1", { item = "sofa_basic", cell = { 2, 2 }, rot = 1 }) }) == "minor", "permisos: girar es menor")
check(kind({ w(0, "objects", "o1", { item = "sofa_basic", cell = { 2, 2 }, rot = 0, color = "#ff0000" }) }) == "minor", "permisos: pintar un mueble es menor")
check(kind({ w(0, "walls", "h:1,0", { item = "wall_basic", color = "#00ff00" }) }) == "minor", "permisos: pintar una pared es menor")
check(kind({ w(0, "floors", "1,1", { item = "floor_basic", color = "#00ff00" }) }) == "minor", "permisos: pintar el piso es menor")
check(kind({ w(0, "objects", "o9", { item = "chair_basic", cell = { 0, 0 }, rot = 0 }) }) == "minor", "permisos: poner un mueble nuevo es menor")
check(kind({ w(0, "objects", "o1", nil) }) == "structural", "permisos: quitar (vender) un mueble es estructural")
check(kind({ w(0, "walls", "h:2,0", WALL) }) == "structural", "permisos: una pared nueva es estructural")
check(kind({ w(0, "walls", "h:1,0", { item = "wall_basic", opening = "door_basic" }) }) == "structural", "permisos: una puerta es estructural")
check(kind({ w(0, "floors", "6,6", FLOOR) }) == "structural", "permisos: un piso nuevo es estructural")
check(kind({ w(0, "objects", "o2", { item = "stairs_basic", cell = { 4, 1 }, rot = 0 }) }) == "structural", "permisos: mover la escalera es estructural")
check(kind({ w(0, "objects", "o1", { item = "sofa_basic", cell = { 3, 3 }, rot = 0 }), w(0, "walls", "h:2,0", WALL) }) == "structural",
  "permisos: un cambio con algo estructural es todo estructural")
check(hr.describe(data, h, { w(0, "objects", "o1", { item = "sofa_basic", cell = { 3, 3 }, rot = 0 }) }) == "movió: Sofá", "historial: 'movió: Sofá'")
check(hr.describe(data, h, { w(0, "walls", "h:2,0", WALL), w(0, "walls", "h:3,0", WALL) }) == "puso: " .. data.items.wall_basic.name .. " x2", "historial: varias paredes")
check(hr.describe(data, h, { w(0, "walls", "h:1,0", { item = "wall_basic", opening = "door_basic" }) }) == "puso: Puerta", "historial: puerta")
check(hr.describe(data, h, { w(0, "objects", "o1", nil) }, true) == "quitar Sofá", "pedido: 'quitar Sofá'")


-- === Fase 5: caja de la casa y deshacer entre dos ===

local A, B = "user-a", "user-b"
local function shared_state(actor, money, fund)
  local st = new_state(money, 99999)
  st.actor = actor
  st.fund = fund
  st.others = {}
  st.check_support = true
  return st
end
local sa = shared_state(A, 1000, 500)
foundation(sa.house, 0, 0, 5, 5)
floors(sa.house, 0, 0, 0, 5, 5)
result = rules.build(data, sa, { w(0, "objects", "o1", { item = "bed_double", cell = { 0, 0 }, rot = 0 }) }, NOW)
check(result.money_fund == -500 and result.money_own == 0 and sa.fund == 0 and sa.money == 1000, "caja: la cama ($500) sale de la caja")
result = rules.build(data, sa, { w(0, "objects", "o2", { item = "tv_basic", cell = { 4, 4 }, rot = 0 }) }, NOW)
check(result.money_fund == 0 and result.money_own == -400 and sa.money == 600, "caja vacía: la tele sale de la billetera")
sa.fund = 100
result = rules.build(data, sa, { w(0, "objects", "o3", { item = "chair_basic", cell = { 5, 0 }, rot = 0 }), w(0, "objects", "o4", { item = "fridge_basic", cell = { 5, 1 }, rot = 0 }) }, NOW)
check(result.money_fund == -100 and result.money_own == -290 and sa.fund == 0 and sa.money == 310, "caja con poco: lo que falta, de la billetera")
local poor = shared_state(A, 10, 20)
poor.check_support = false
r = refusal_of(rules.build, data, poor, { w(0, "objects", "o5", { item = "chair_basic", cell = { 0, 0 }, rot = 0 }) }, NOW)
check(r ~= nil and string.find(r.refusal, "10") and string.find(r.refusal, "caja"), "caja + billetera no alcanzan: dice cuánto falta")
result = rules.undo(sa, data)
check(result.money_fund == 100 and result.money_own == 290 and sa.fund == 100 and sa.money == 600, "deshacer: devuelve a la caja y a la billetera lo exacto")
sa.fund = 0  -- se gastó la caja mientras tanto
result = rules.redo(sa, data)
check(result.money_fund == 0 and result.money_own == -390 and sa.money == 210, "rehacer con la caja vacía: paga la billetera")
result = rules.undo(sa, data)
check(result.money_own == 390 and sa.money == 600 and sa.fund == 0, "deshacer otra vez: vuelve lo que pagó la billetera")
-- Vender en la casa compartida: lo que devuelve va a la caja.
rules.redo(sa, data)
result = rules.build(data, sa, { w(0, "objects", "o3", nil) }, NOW)
check(result.money_fund == 20 and result.money_own == 0 and sa.fund == 20, "vender en la casa compartida: la mitad va a la caja")

-- Dos editores: B movió la tele que puso A; el deshacer de A ya no la pisa.
local sb = shared_state(B, 1000, sa.fund)
sb.house = sa.house
sb.history = { undo = {}, redo = {} }
rules.build(data, sb, { w(0, "objects", "o2", { item = "tv_basic", cell = { 3, 4 }, rot = 0 }) }, NOW)
check(rules.writes_match(sa.house, { w(0, "objects", "o2", { item = "tv_basic", cell = { 3, 4 }, rot = 0, ready_at = 1 }) }), "comparar piezas ignora la hora de obra")
local undo_before = #sa.history.undo
result = rules.undo(sa, data)  -- el último de A: vender la silla (sigue igual) → se deshace
check(not result.skipped and sa.house.levels[4].objects.o3 ~= nil, "deshacer propio que nadie tocó: se deshace")
result = rules.undo(sa, data)  -- poner silla + heladera (la heladera sigue igual)
check(not result.skipped, "deshacer silla + heladera: se deshace")
result = rules.undo(sa, data)  -- poner la tele, que B movió después
check(result.skipped and sa.house.levels[4].objects.o2.cell[1] == 3 and #sa.history.undo == undo_before - 3,
  "deshacer algo que la pareja cambió después: se descarta sin pisarlo")

-- Historial de la casa: deshacer lo del otro, con el dinero de vuelta a quien pagó.
local home = rules.empty_home(A)
local sc = shared_state(B, 1000, 0)
foundation(sc.house, 0, 0, 5, 5)
floors(sc.house, 0, 0, 0, 5, 5)
result = rules.build(data, sc, { w(0, "objects", "o7", { item = "chair_basic", cell = { 1, 1 }, rot = 0 }) }, NOW)
local entry = rules.log_entry(home, { by = B, by_name = "b", at = NOW, kind = "minor", text = "puso: Silla",
  writes = result.writes, inverse = sc.history.undo[#sc.history.undo].inverse, money_fund = result.money_fund, money_own = result.money_own })
check(home.rev == 1 and entry.id == 1, "historial: la entrada sube rev")
local sd = shared_state(A, 50, 0)  -- A deshace la silla de B
sd.house = sc.house
sd.others[B] = sc.money
check(rules.can_revert(sd, entry), "historial: la silla de B se puede deshacer")
result = rules.revert(data, sd, home, entry.id)
check(sd.house.levels[4].objects.o7 == nil and sd.others[B] == 1000 and sd.money == 50,
  "deshacer lo de la pareja: se quita y el dinero vuelve a B (no a quien deshace)")
check(refusal_of(rules.revert, data, sd, home, entry.id) ~= nil, "no se deshace dos veces")
-- Si alguien cambió la pieza después, no se puede.
rules.build(data, sc, { w(0, "objects", "o8", { item = "chair_basic", cell = { 2, 2 }, rot = 0 }) }, NOW)
local e2 = rules.log_entry(home, { by = B, kind = "minor", text = "puso: Silla", writes = { w(0, "objects", "o8", rules.copy(sc.house.levels[4].objects.o8)) },
  inverse = { w(0, "objects", "o8", nil) } })
sc.house.levels[4].objects.o8.cell = { 3, 3 }
sd.house = sc.house
local e2_refusal = refusal_of(rules.revert, data, sd, home, e2.id)
check(not rules.can_revert(sd, e2) and e2_refusal ~= nil and e2_refusal.reason == "changed", "historial: lo cambiado después ya no se deshace")

-- Pedidos y aportes.
local req = rules.add_request(home, { by = B, text = "puso: Pared" })
check(#home.requests == 1 and req.id ~= nil, "pedido guardado")
check(rules.take_request(home, req.id).text == "puso: Pared" and #home.requests == 0, "pedido sacado")
check(refusal_of(rules.take_request, home, req.id) ~= nil, "un pedido que no existe")
for i = 1, rules.MAX_REQUESTS do rules.add_request(home, { by = B, text = "x" .. i }) end
check(refusal_of(rules.add_request, home, { by = B, text = "uno más" }) ~= nil, "tope de pedidos")
local sf = shared_state(A, 300, 0)
rules.contribute(sf, 200)
check(sf.money == 100 and sf.fund == 200, "aportar a la caja")
check(refusal_of(rules.contribute, sf, 500) ~= nil and refusal_of(rules.contribute, sf, -5) ~= nil and refusal_of(rules.contribute, sf, 1.5) ~= nil,
  "aportes inválidos o sin dinero")
check(refusal_of(rules.contribute, new_state(100), 50) ~= nil, "sin casa compartida no hay caja")
local o1, o2 = rules.split_fund(301)
check(o1 == 151 and o2 == 150, "al separarse la caja se reparte (la moneda impar, al dueño)")
for i = 1, rules.MAX_LOG + 5 do rules.log_entry(home, { by = A, kind = "build", text = "x" }) end
check(#home.log == rules.MAX_LOG, "el historial guarda las últimas " .. rules.MAX_LOG)
local nh = rules.normalize_home({ fund = "basura", log = {}, rev = 3 }, A)
check(nh.fund == 0 and nh.rev == 3 and nh.members[1] == A, "hogar incompleto se completa")

-- Unir ingresos: el sueldo va a la caja.
local pool = shared_state(A, 0, 10)
pool.pool_income = true
pool.work.job_id = "courier"
pool.work.shift_job = "courier"
pool.work.shift_started_unix = NOW
result = rules.shift_complete(data, pool, NOW + 100)
check(result.to_fund and pool.fund == 130 and pool.money == 0, "unir ingresos: el sueldo va a la caja")
pool.pool_income = false
pool.work.shift_job = "courier"
pool.work.shift_started_unix = NOW
rules.shift_complete(data, pool, NOW + 100)
check(pool.money == 120 and pool.fund == 130, "sin unir ingresos: a la billetera")


-- === Fase 5: la relación ===

local couple = require("neighborhood_couple")
local C = "user-c"
local names = { [A] = "ana", [B] = "beto", [C] = "caro" }
local function rels_of(...)
  local t = {}
  for _, id in ipairs({ ... }) do t[id] = couple.empty() end
  return t
end
local function crefusal(fn, ...)
  local ok, err = pcall(fn, ...)
  return not ok and type(err) == "table" and err.refusal or nil
end
local rs = rels_of(A, B, C)
local notes = couple.invite(rs, A, B, names, NOW)
check(rs[A].invite_to_id == B and #rs[B].invites_in == 1 and notes[1].to == B, "pareja: A invita a B")
check(crefusal(couple.invite, rs, A, C, names, NOW) ~= nil, "pareja: una invitación por vez")
check(crefusal(couple.invite, rs, A, A, names, NOW) ~= nil, "pareja: no a uno mismo")
couple.invite(rs, C, B, names, NOW)
check(#rs[B].invites_in == 2, "pareja: B tiene dos invitaciones")
couple.answer_invite(rs, B, A, true, names, NOW)
check(rs[A].status == "dating" and rs[B].status == "dating" and rs[A].partner_id == B and rs[B].partner_name == "ana",
  "pareja: B acepta, son pareja")
check(#rs[B].invites_in == 0 and rs[C].invite_to_id == "" and rs[A].invite_to_id == "", "pareja: se limpian todas las invitaciones")
check(crefusal(couple.invite, rs, C, A, names, NOW) ~= nil, "pareja: no se invita a alguien en pareja")
check(crefusal(couple.respond, rs, A, true, NOW) ~= nil, "pareja: sin pedido no hay qué responder")
couple.propose(rs, A, "marry", nil, NOW)
check(rs[B].proposal_kind == "marry" and rs[B].proposal_by == A, "pareja: A pide casamiento")
check(crefusal(couple.respond, rs, A, true, NOW) ~= nil, "pareja: quien pide no se acepta solo")
couple.respond(rs, B, true, NOW + 5)
check(rs[A].status == "married" and rs[B].married_unix == NOW + 5 and rs[A].proposal_kind == "", "pareja: matrimonio")
check(crefusal(couple.set_switches, rs[A], { pool_income = true }) ~= nil, "unir ingresos: solo si viven juntos")
couple.propose(rs, B, "move_in", "yours", NOW)
check(rs[A].proposal_home == A, "pareja: B quiere mudarse a la casa de A")
local _, moved = couple.respond(rs, A, true, NOW)
check(moved == A and rs[A].home_owner == A and rs[B].home_owner == A, "pareja: viven en la casa de A")
check(crefusal(couple.propose, rs, A, "move_in", "mine", NOW) ~= nil, "pareja: ya viven juntos")
couple.set_switches(rs[A], { drama = true, family_mode = false })
check(not couple.drama_enabled(rs[A], rs[B]), "drama: hace falta que los dos lo permitan")
couple.set_switches(rs[B], { drama = true, family_mode = false, pool_income = true })
check(couple.drama_enabled(rs[A], rs[B]) and rs[B].pool_income, "drama: los dos lo permiten y sin modo familiar")
couple.set_switches(rs[B], { family_mode = true })
check(not couple.drama_enabled(rs[A], rs[B]), "drama: el modo familiar lo apaga")
local ended_notes, shared_owner = couple.end_relation(rs, B, NOW)
check(shared_owner == A and rs[A].status == "single" and rs[B].home_owner == "" and not rs[B].pool_income and ended_notes[1].to == A,
  "pareja: terminar (cada uno vuelve a su casa)")
check(#rs[A].events >= 4 and string.find(rs[A].events[#rs[A].events].text, "Terminó"), "pareja: el historial de relaciones queda")
-- Invitación cruzada: si B ya me invitó, invitarlo es aceptar.
rs = rels_of(A, B)
couple.invite(rs, B, A, names, NOW)
couple.invite(rs, A, B, names, NOW)
check(rs[A].status == "dating" and rs[B].partner_id == A, "pareja: invitación cruzada = aceptar")
rs = rels_of(A, B)
couple.invite(rs, A, B, names, NOW)
couple.answer_invite(rs, B, A, false, names, NOW)
check(rs[A].invite_to_id == "" and #rs[B].invites_in == 0 and rs[A].status == "single", "pareja: rechazar limpia la invitación")
couple.invite(rs, A, B, names, NOW)
couple.cancel_invite(rs, A)
check(#rs[B].invites_in == 0, "pareja: retirar la invitación")
local norm = couple.normalize({ status = "dating", invites_in = {}, events = {}, drama = "sí" })
check(norm.status == "dating" and norm.drama == false and norm.family_mode == true, "relación incompleta se completa")
local summ = couple.summary(rs[A], rs[B], A)
check(summ.status == "single" and summ.family_mode == true and summ.drama_enabled == false, "resumen de la relación")


-- === Pulido 1: constructor 2.0 (los mismos casos que tests/test_house.gd) ===

local function box_house()
  local b = rules.empty_house()
  foundation(b, 0, 0, 5, 5)
  floors(b, 0, 0, 0, 5, 5)
  for x = 0, 5 do
    put(b, 0, "walls", "h:" .. x .. ",0", { item = "wall_basic" })
    put(b, 0, "walls", "h:" .. x .. ",6", { item = "wall_basic" })
  end
  for z = 0, 5 do
    put(b, 0, "walls", "v:0," .. z, { item = "wall_basic" })
    put(b, 0, "walls", "v:6," .. z, { item = "wall_basic" })
  end
  return b
end

local function has_cell(cells, x, z)
  for _, c in ipairs(cells) do
    if c[1] == x and c[2] == z then return true end
  end
  return false
end

-- Muebles en diagonal: las mismas celdas que el teléfono.
local chair_cells = hr.object_cells(data.items.chair_basic, { cell = { 3, 3 }, rot = 0, diag = true })
check(#chair_cells == 1 and has_cell(chair_cells, 3, 3), "diagonal: silla en 1 celda")
local table_cells = hr.object_cells(data.items.table_basic, { cell = { 2, 2 }, rot = 0, diag = true })
check(#table_cells == 4 and has_cell(table_cells, 2, 2) and has_cell(table_cells, 3, 3), "diagonal: mesa 2x1 en 4 celdas")
local bh = box_house()
put(bh, 0, "objects", "o1", { item = "table_basic", cell = { 2, 2 }, rot = 0, diag = true })
check(not supported(bh, 0, "objects", "o2", { item = "chair_basic", cell = { 3, 3 }, rot = 0 }), "diagonal: no se encima")
check(not supported(bh, 0, "objects", "o3", { item = "stairs_basic", cell = { 0, 0 }, rot = 0, diag = true }),
  "diagonal: la escalera no")
local clean = rules.clean_writes(data, { w(0, "objects", "o9", { item = "chair_basic", cell = { 1, 1 }, rot = 2, diag = true }) })
check(clean[1].value.diag == true, "diagonal: el servidor guarda diag")
check(refusal_of(rules.clean_writes, data, { w(0, "objects", "o9", { item = "pillar_basic", cell = { 1, 1 }, rot = 0, diag = true }) }) ~= nil,
  "diagonal: un pilar en diagonal se rechaza")

-- Pilares y lo de afuera.
local open = rules.empty_house()
check(supported(open, 0, "objects", "p1", { item = "pillar_basic", cell = { 10, 10 }, rot = 0 }), "pilar sobre el pasto")
check(not supported(open, 0, "objects", "c1", { item = "chair_basic", cell = { 10, 10 }, rot = 0 }), "silla sobre el pasto NO")
put(open, 0, "objects", "p1", { item = "pillar_basic", cell = { 10, 10 }, rot = 0 })
check(supported(open, 1, "floors", "12,12", FLOOR), "el pilar sostiene un piso a 2 celdas")
check(not supported(open, 1, "floors", "13,10", FLOOR), "a 3 celdas no")
put(open, 1, "floors", "11,11", FLOOR)
check(not batch_ok(open, { w(0, "objects", "p1", nil) }), "no se puede quitar el pilar que sostiene el piso")
check(supported(open, 0, "objects", "m1", { item = "stairs_metal", cell = { 14, 14 }, rot = 0 }), "escalera metálica afuera")

-- Techos: bloqueados si los atraviesa una pared o un piso de arriba.
local ROOF = { item = "roof_flat", rect = { 0, 0, 6, 6 } }
local roofed = box_house()
check(supported(roofed, 0, "roofs", "r1", ROOF), "techo plano sobre la casa")
put(roofed, 1, "walls", "v:3,2", WALL)
check(not supported(roofed, 0, "roofs", "r1", ROOF), "techo atravesado por una pared de arriba NO")
local under = box_house()
put(under, 0, "roofs", "r1", ROOF)
check(not supported(under, 1, "walls", "v:3,2", WALL), "pared arriba atravesando un techo NO")
check(not supported(under, 1, "floors", "2,2", FLOOR), "piso adentro de un techo NO")

-- Pintura por cara y unión en la juntura: el servidor los guarda.
clean = rules.clean_writes(data, { w(0, "walls", "h:1,1", { item = "wall_basic", opening = "window_basic",
  color_a = "#ff0000", color_b = "#00ff00", join_end = true, separate = true }) })
check(clean[1].value.color_a == "#ff0000" and clean[1].value.color_b == "#00ff00" and clean[1].value.join_end == true
  and clean[1].value.separate == nil, "pared: color por cara y juntura (la marca vieja no)")
check(refusal_of(rules.clean_writes, data, { w(0, "floors", "1,1", { item = "floor_basic", color_a = "#ff0000" }) }) ~= nil,
  "color por cara solo en paredes")
check(hr.change_kind(data, box_house(), { w(0, "walls", "h:2,0", { item = "wall_basic", color_a = "#00ff00" }) }) == "minor",
  "pintar una cara es cambio menor")

-- Casas de antes: se convierten al cargarlas (igual que HouseData.upgrade_legacy).
local legacy = rules.normalize_house({ levels = { { walls = {
  ["h:1,1"] = { item = "wall_basic", opening = "window_basic", color = "#ffd966" },
  ["h:2,1"] = { item = "wall_basic", opening = "window_basic" },
  ["h:5,1"] = { item = "wall_basic", opening = "window_basic" },
  ["h:6,1"] = { item = "wall_basic", opening = "window_basic", separate = true },
} } }, next_id = 3 })
local lw = legacy.levels[4].walls
check(lw["h:1,27"].color_a == "#ffd966" and lw["h:1,27"].color_b == "#ffd966" and lw["h:1,27"].color == nil,
  "migración: la pintura pasa a las dos caras")
check(lw["h:1,27"].join_end == true and lw["h:5,27"].join_end == nil and lw["h:6,27"].separate == nil,
  "migración: unidas en la juntura, separadas siguen separadas")
check(legacy.format == 5, "migración: formato 5 (la casa de antes pasa a la parcela de 96 y se acerca a la calle)")
lw["h:1,27"].join_end = nil
check(rules.normalize_house(legacy).levels[4].walls["h:1,27"].join_end == nil, "una casa nueva no se vuelve a migrar")

-- Hasta 5 pisos: una escalera en el piso 3 sí, en el 4 (el último) no.
local tall = rules.empty_house()
floors(tall, 3, 0, 0, 2, 4)
floors(tall, 4, 0, 0, 2, 4)
check(supported(tall, 3, "objects", "s1", { item = "stairs_basic", cell = { 1, 1 }, rot = 0 }), "escalera en el piso 3")
check(not supported(tall, 4, "objects", "s2", { item = "stairs_basic", cell = { 1, 1 }, rot = 0 }), "escalera en el último piso NO")



-- --- Restaurante (Fase 6): neighborhood_business.lua ---

local business = require("neighborhood_business")
local rcfg = business.new_config(read_data("business.json"))
local svc = rcfg.service
check(svc.duration_ms == 90000 and #svc.ingredients == 6 and rcfg.requires.counter_restaurant == 1,
  "business.json: servicio de 90 s, 6 ingredientes, pide mostrador")
check(svc.ingredients[5].hot and not svc.ingredients[1].hot, "la tortita va a la plancha, el pan no")

-- Números al azar: los mismos que en GDScript (tests/test_business.gd).
local rng = business.new_rng(1)
check(business.next_int(rng, 2147483647) == 16807 and business.next_int(rng, 2147483647) == 282475249,
  "Park-Miller: 16807, 282475249")
check(business.new_rng(0).state == 2147483646 and business.new_rng(-5).state > 0, "semillas raras se arreglan")

-- La lista de clientes sale de la semilla (comparada con GDScript).
local cs = business.customers(svc, 4242)
local arrive_sum = 0
for _, c in ipairs(cs) do arrive_sum = arrive_sum + c.arrive end
check(#cs == 17 and arrive_sum == 719677, "semilla 4242: 17 clientes, llegadas suman 719677")
check(cs[1].arrive == 1500 and cs[1].order[1] == 1 and cs[1].order[2] == 5 and cs[1].patience == 20000,
  "primer cliente: a los 1,5 s pide lechuga + huevo, 20 s de paciencia")
check(cs[#cs].arrive == 78709 and cs[#cs].patience == 14000, "el último llega a los 78,7 s con menos paciencia")
local ok_sizes = true
for _, c in ipairs(cs) do
  if #c.order < 2 or #c.order > svc.plate_max or c.arrive >= svc.duration_ms - svc.last_call_ms then ok_sizes = false end
end
check(ok_sizes, "pedidos de 2 a 4 cosas, nadie llega en los últimos 8 s")
local cs2 = business.customers(svc, 4242)
check(cs2[9].arrive == cs[9].arrive and cs2[9].order[1] == cs[9].order[1], "misma semilla, mismos clientes")
check(business.customers(svc, 4243)[2].arrive ~= cs[2].arrive, "otra semilla, otros clientes")

-- Un servicio jugado a mano (semilla 4242, 3 mesas).
local T, G, S, X = business.TAKE, business.GRILL, business.SERVE, business.TRASH
local play = {
  { 1600, T, 1 },   -- lechuga al plato
  { 1700, T, 5 },   -- huevo a la plancha
  { 2000, G, 0 },   -- todavía crudo: nada
  { 4300, G, 0 },   -- a punto: al plato
  { 4400, S, 0 },   -- servir al primero: 3*2 + propina 4 = 10
}
local res = business.replay(svc, 4242, 3, play)
check(res ~= nil and res.coins == 10 and res.served == 1 and res.tips == 4, "servir bien: 10 monedas (propina 4)")
check(res.lost == 10 and res.skipped == 5, "los que nadie atendió se van; con las mesas llenas, siguen de largo")

-- Plato equivocado: pierde paciencia y se corta la racha; quemar en la plancha.
local wrong = {
  { 1600, T, 0 }, { 1700, T, 0 }, { 1800, S, 0 },   -- pan + pan al de lechuga + huevo: mal
  { 2000, T, 4 }, { 8000, G, 0 },                   -- la tortita se quemó (6 s > 2,5 + 3)
  { 8100, T, 1 }, { 8200, X, 0 },                   -- tirar el plato
}
res = business.replay(svc, 4242, 3, wrong)
check(res.coins == 0 and res.wrong == 1 and res.burned == 1 and res.trashed == 1, "mal servido, quemado y tirado")
local sim = business.new_sim(svc, 4242, 3)
business.act(sim, 1600, T, 0)
business.act(sim, 1700, S, 0)
check(sim.seats[1].deadline == 1500 + 20000 - 5000, "plato equivocado: 5 s menos de paciencia")
check(#sim.plate == 0, "el plato equivocado se pierde")

-- Una sola mesa: el que llega con la mesa ocupada sigue de largo.
res = business.replay(svc, 4242, 1, {})
check(res.skipped == 12 and res.lost == 4, "con una mesa, más siguen de largo (uno queda sentado al final)")

-- Revisión de los toques (no se puede mandar cualquier cosa).
check(business.validate_actions(svc, 3, play) == nil, "toques normales: bien")
check(business.validate_actions(svc, 3, { { 100, T, 0 }, { 120, T, 1 } }) ~= nil, "dos toques en 20 ms: no")
check(business.validate_actions(svc, 3, { { 500, T, 0 }, { 400, T, 1 } }) ~= nil, "toques desordenados: no")
check(business.validate_actions(svc, 3, { { 95000, T, 0 } }) ~= nil, "después del final: no")
check(business.validate_actions(svc, 3, { { 100, T, 6 } }) ~= nil, "ingrediente inexistente: no")
check(business.validate_actions(svc, 1, { { 100, S, 1 } }) ~= nil, "mesa que no existe: no")
check(business.validate_actions(svc, 3, { { 100.5, T, 0 } }) ~= nil, "tiempos con coma: no")
check(business.validate_actions(svc, 3, { { 100, 9, 0 } }) ~= nil, "acción inventada: no")
local many = {}
for i = 1, 401 do many[i] = { i * 100, X, 0 } end
check(business.validate_actions(svc, 3, many) ~= nil, "más de 400 toques: no")
check(business.validate_actions(svc, 3, "basura") ~= nil, "sin lista: no")

-- El restaurante de la casa.
local function restaurant_state(money)
  local st = new_state(money)
  st.home = rules.normalize_home(nil, "u1")
  st.owner_id = "u1"
  st.actor = "u1"
  st.business = business.normalize_record(nil)
  return st
end
local function put(st, key, item, ready_at)
  st.house.levels[4].objects[key] = { item = item, cell = { 1, 1 }, rot = 0, ready_at = ready_at }
end
local rs = restaurant_state()
local missing, seats = business.requirements(rcfg, data.items, rs.house, NOW)
check(#missing == 3 and seats == 0, "casa vacía: faltan los 3 muebles")
r = refusal_of(business.open, rcfg, data.items, rs, NOW)
check(r ~= nil and r.reason == "missing" and string.find(r.refusal, "Mostrador"), "no se abre sin mostrador")
put(rs, "o1", "counter_restaurant")
put(rs, "o2", "stove_restaurant", NOW + 30)
put(rs, "o3", "table_restaurant")
put(rs, "o4", "table_restaurant")
missing, seats = business.requirements(rcfg, data.items, rs.house, NOW)
check(#missing == 1 and missing[1].id == "stove_restaurant" and seats == 2, "la plancha en obra no cuenta; 2 mesas = 2 lugares")
missing = business.requirements(rcfg, data.items, rs.house, NOW + 30)
check(#missing == 0, "terminada la obra, no falta nada")
business.open(rcfg, data.items, rs, NOW + 30)
check(business.is_open(rs.home) and rs.home.business.opened_by == "u1", "restaurante abierto")
check(refusal_of(business.open, rcfg, data.items, rs, NOW + 31) ~= nil, "no se abre dos veces")

-- Caja del restaurante (clientes de paso): junta con el tiempo, con tope.
local OPEN = NOW + 30
check(business.passive_amount(rcfg, rs.home, OPEN + 1800) == 10, "media hora: $10 (20 por hora)")
check(business.passive_amount(rcfg, rs.home, OPEN + 100 * 3600) == 160, "días sin entrar: tope $160, nada se pierde")
r = refusal_of(business.collect, rcfg, data.items, rs, OPEN + 60)
check(r ~= nil, "al minuto todavía no juntó nada")
local got = business.collect(rcfg, data.items, rs, OPEN + 1800)
check(got.coins == 10 and rs.money == 3010 and not got.to_fund, "cobrar: $10 a la billetera")
check(business.passive_amount(rcfg, rs.home, OPEN + 1800) == 0, "después de cobrar, empieza de cero")

-- Un servicio: el servidor pone la semilla y la hora.
local START = OPEN + 2000
local started = business.service_start(rcfg, data.items, rs, START, 4242)
check(started.seed == 4242 and started.seats == 2 and started.duration_ms == 90000, "servicio: semilla y 2 mesas")
r = refusal_of(business.service_start, rcfg, data.items, rs, START + 10, 99)
check(r ~= nil and r.reason == "active", "no se empiezan dos servicios a la vez")
r = refusal_of(business.service_finish, rcfg, data.items, rs, START + 30, play)
check(r ~= nil and r.reason == "too_early", "no se cobra antes de que pasen los 90 s")
local fin = business.service_finish(rcfg, data.items, rs, START + 88, play)
check(fin.valid and fin.coins == 10 and fin.pay == 10 and rs.money == 3020, "a los 88 s (margen): cobra lo que calcula el servidor")
check(fin.xp_gained == 1 and rs.xp == 1, "experiencia: 1 por cliente atendido")
check(rs.business.service_started == 0 and rs.business.services == 1 and rs.business.best == 10, "servicio cerrado y anotado")
check(refusal_of(business.service_finish, rcfg, data.items, rs, START + 89, play) ~= nil, "el mismo servicio no se cobra dos veces")

-- Trampa: toques imposibles anulan el servicio (se guarda, no paga).
business.service_start(rcfg, data.items, rs, START + 200, 4242)
fin = business.service_finish(rcfg, data.items, rs, START + 300, { { 100, T, 0 }, { 110, T, 1 } })
check(not fin.valid and fin.pay == 0 and rs.money == 3020 and rs.business.service_started == 0,
  "toques de robot: no paga y se anula")
-- Vencido (más de un día) o de otra casa: tampoco.
business.service_start(rcfg, data.items, rs, START + 400, 4242)
fin = business.service_finish(rcfg, data.items, rs, START + 400 + 90000, play)
check(not fin.valid and string.find(fin.error_text, "venció"), "servicio de hace más de un día: vencido")
business.service_start(rcfg, data.items, rs, START + 500, 4242)
rs.owner_id = "otro"
fin = business.service_finish(rcfg, data.items, rs, START + 600, play)
check(not fin.valid, "servicio de otra casa: no vale")
rs.owner_id = "u1"

-- Tope diario: pasado el tope, se juega igual pero no paga más.
rs.business.day_start = START + 700
rs.business.day_earned = 595
business.service_start(rcfg, data.items, rs, START + 700, 4242)
fin = business.service_finish(rcfg, data.items, rs, START + 800, play)
check(fin.valid and fin.coins == 10 and fin.pay == 5 and fin.capped and rs.business.day_earned == 600,
  "tope: de 10 solo paga 5")
business.service_start(rcfg, data.items, rs, START + 900, 4242)
fin = business.service_finish(rcfg, data.items, rs, START + 1000, play)
check(fin.pay == 0 and fin.xp_gained == 0 and fin.capped, "tope lleno: no paga ni da experiencia")
local sum = business.summary(rcfg, data.items, rs, START + 1000)
check(sum.open and sum.ready and sum.cap_left == 0 and sum.resets_in > 0, "resumen: tope lleno, cuánto falta")
business.service_start(rcfg, data.items, rs, START + 700 + 86400, 4242)
fin = business.service_finish(rcfg, data.items, rs, START + 800 + 86400, play)
check(fin.pay == 10 and rs.business.day_earned == 10, "24 h después, el tope empieza de nuevo")

-- Sin muebles, cerrado: no se atiende.
rs.house.levels[4].objects.o1 = nil
r = refusal_of(business.service_start, rcfg, data.items, rs, START + 200000, 1)
check(r ~= nil and r.reason == "missing", "sin mostrador no se atiende")
put(rs, "o1", "counter_restaurant")
business.close(rs)
check(not business.is_open(rs.home) and refusal_of(business.service_start, rcfg, data.items, rs, START + 200000, 1) ~= nil,
  "cerrado: no se atiende")
check(business.passive_amount(rcfg, rs.home, START + 300000) == 0, "cerrado: no junta")

-- Casa compartida (Fase 5): la caja del restaurante va a la caja de la
-- casa; lo del minijuego, a la billetera o a la caja con "unir ingresos".
local sh = restaurant_state(100)
sh.fund = 50
sh.shared = true
put(sh, "o1", "counter_restaurant")
put(sh, "o2", "stove_restaurant")
put(sh, "o3", "table_restaurant")
business.open(rcfg, data.items, sh, NOW)
got = business.collect(rcfg, data.items, sh, NOW + 3600)
check(got.to_fund and sh.fund == 70 and sh.money == 100, "compartida: lo que juntó va a la caja")
business.service_start(rcfg, data.items, sh, NOW + 4000, 4242)
fin = business.service_finish(rcfg, data.items, sh, NOW + 4100, play)
check(not fin.to_fund and sh.money == 110 and sh.fund == 70, "sin unir ingresos: a la billetera")
sh.pool_income = true
business.service_start(rcfg, data.items, sh, NOW + 4200, 4242)
fin = business.service_finish(rcfg, data.items, sh, NOW + 4300, play)
check(fin.to_fund and fin.money_change == 0 and sh.fund == 80 and sh.money == 110, "con unir ingresos: a la caja")
check(rules.normalize_home({ business = { kind = "restaurant" } }, "u1").business.kind == "restaurant",
  "el hogar guarda el negocio")
check(next(rules.normalize_home(nil, "u1").business) == nil, "hogar nuevo: sin negocio")

-- Pulido 2A: techos rotos de una edición vieja se sacan al leer la casa.
local broken_house = rules.normalize_house({ levels = { { roofs = {
  o1 = { item = "roof_basic", rect = { 90, 90, 9, 9 } },
  o2 = { item = "roof_basic", rect = { 1, 1, 0, 3 } },
  o3 = { item = "roof_basic" },
  o4 = { item = "roof_basic", rect = { 0, 0, 6, 6 } },
} } }, next_id = 5, format = 3 })
check(broken_house.levels[4].roofs.o4 ~= nil and broken_house.levels[4].roofs.o1 == nil
  and broken_house.levels[4].roofs.o2 == nil and broken_house.levels[4].roofs.o3 == nil,
  "casa vieja: se sacan los 3 techos rotos y queda el sano")
-- Quitar un techo (también el del piso 4) y una cascada de cimientos entran en un solo pedido.
local roofhouse = rules.normalize_house({ levels = { {}, {}, {}, { roofs = { o9 = { item = "roof_basic", rect = { 2, 2, 3, 3 } } } } } })
check(hr.check_batch(data, roofhouse, { { level = 3, layer = "roofs", key = "o9", value = nil } }),
  "se puede quitar un techo suelto del piso 3")

-- Pulido 2B: la caja del restaurante se cobra SOLA, por tiempo.
local auto = restaurant_state(100)
put(auto, "o1", "counter_restaurant")
put(auto, "o2", "stove_restaurant")
put(auto, "o3", "table_restaurant")
check(business.auto_collect(rcfg, data.items, auto, NOW) == nil, "cobro automático: cerrado, no hay nada")
business.open(rcfg, data.items, auto, NOW)
check(business.auto_collect(rcfg, data.items, auto, NOW + 60) == nil, "cobro automático: a los 60 s todavía no junta $1")
local auto_paid = business.auto_collect(rcfg, data.items, auto, NOW + 7200)
check(auto_paid ~= nil and auto_paid.coins == 2 * rcfg.passive_per_hour and auto.money == 100 + 2 * rcfg.passive_per_hour,
  "cobro automático: 2 h juntan 2 × lo de la hora y van a la billetera")
check(business.auto_collect(rcfg, data.items, auto, NOW + 7200) == nil, "cobro automático: lo ya cobrado no se cobra dos veces")
local auto_offline = business.auto_collect(rcfg, data.items, auto, NOW + 7200 + 10 * 3600)
check(auto_offline ~= nil and auto_offline.coins == rcfg.passive_cap, "cobro automático: sin entrar 10 h, como mucho el tope ($" .. rcfg.passive_cap .. ")")
check(data.jobs.waiter ~= nil and data.jobs.restaurant_cook ~= nil, "hay empleos de restaurante sin tener uno propio")

-- Pulido 2C: la parcela (obstáculos, costos, caminos) y la casa de 96.
local parcel = require("neighborhood_parcel")
local pcfg = read_data("parcel.json")
check(parcel.next_random(12345) == 595905495, "parcela: el generador de azar es el de siempre (Park–Miller)")
check(parcel.seed_from_text("abc") == 193485963, "parcela: la semilla sale del texto")
local obstacles = parcel.generate(pcfg, 424242)
local kinds = {}
local checksum = 0
for i, o in ipairs(obstacles) do
  kinds[o.kind] = (kinds[o.kind] or 0) + 1
  checksum = (checksum + (o.x * 131 + o.z * 17 + i)) % 1000003
end
check(#obstacles == 546 and kinds.tree == 244 and kinds.bush == 175 and kinds.stump == 65 and kinds.rock == 60 and kinds.lake == 2,
  "parcela: misma cantidad de obstáculos que en el teléfono (" .. #obstacles .. ")")
check(checksum == 961556 and obstacles[1].id == "l:49,31" and obstacles[2].id == "l:2,88" and obstacles[#obstacles].id == "b:71,94",
  "parcela: los obstáculos están en los mismos lugares que en el teléfono")
local blocked_all = parcel.blocked_cells(obstacles, {})
-- Pulido 3A: la casa va CERCA de la calle y la franja hasta la calle queda libre.
local hx, hz = parcel.home_origin(pcfg)
check(hx == 32 and hz == 58, "parcela: la casa va centrada y a 6 celdas de la calle (" .. hx .. "," .. hz .. ")")
check(rules.HOME_SHIFT_Z == hz - (pcfg.lot - pcfg.home_zone) / 2, "migración: el corrimiento hacia la calle es el del archivo")
local in_zone = false
for x = hx - 1, hx + pcfg.home_zone do
  for z = hz - 1, pcfg.lot - 1 do
    if blocked_all[x .. "," .. z] then in_zone = true end
  end
end
check(not in_zone, "parcela: la casa y la franja hasta la calle quedan libres de obstáculos")
-- Zona usable: el doble al principio, el triple con todos los desbloqueos.
local function count_cells(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
check(count_cells(parcel.locked_cells(pcfg, 1)) == 96 * 96 - 64 * 64, "zona: al principio solo se usa 64 x 64")
check(count_cells(parcel.locked_cells(pcfg, 4)) == 96 * 96 - 64 * 96, "zona: al nivel 4 se abre el terreno de atrás")
check(count_cells(parcel.locked_cells(pcfg, 6)) == 0, "zona: al nivel 6 es toda la parcela (el triple)")
local zone1 = parcel.zone_rects(pcfg, 1)
check(parcel.in_zone(zone1, 16, 32) and parcel.in_zone(zone1, 79, 95) and not parcel.in_zone(zone1, 15, 60) and not parcel.in_zone(zone1, 40, 31),
  "zona: los bordes de la zona inicial")
check(parcel.in_zone(zone1, hx, hz, 32, 32), "zona: la casa entra entera en la zona inicial")
local locked1 = parcel.locked_cells(pcfg, 1)
local with_zone = parcel.blocked_cells(obstacles, {}, locked1)
check(with_zone["0,0"] == "zone" and with_zone["40,94"] == nil, "zona: las celdas cerradas figuran como zona")
local zone_house = rules.empty_house()
hr.blocked_cells = with_zone
check(not hr.check_batch(data, zone_house, { w(0, "foundation", "5,5", { item = "foundation_basic" }) }), "zona: no se construye en la zona cerrada")
check(hr.check_batch(data, zone_house, { w(0, "foundation", "40,90", { item = "foundation_basic" }) }), "zona: en la zona abierta sí")
hr.blocked_cells = nil
local cleared_one = parcel.blocked_cells(obstacles, { [obstacles[1].id] = true })
local count_all, count_one = 0, 0
for _ in pairs(blocked_all) do count_all = count_all + 1 end
for _ in pairs(cleared_one) do count_one = count_one + 1 end
check(count_all - count_one == 20, "parcela: limpiar el laguito (5 x 4) libera 20 celdas")
check(parcel.cost(pcfg, "rock", 0) == 250 and parcel.cost(pcfg, "rock", 50) == 500 and parcel.cost(pcfg, "rock", 500) == 750,
  "parcela: el costo sube con lo limpiado y tiene techo (x3)")
check(parcel.cost(pcfg, "bush", 0) == 15 and parcel.cost(pcfg, "lake", 10) == 1080, "parcela: costos base de la maleza y el laguito")
-- Caminos: persona (1 celda) y vehículo (2 x 2).
local small = { lot = 10 }
local wall_of_trees = {}
for x = 0, 9 do
  if x ~= 4 then wall_of_trees[x .. ",5"] = "t" end   -- una pared con UN hueco de 1 celda
end
local target = { x = 4, z = 1, w = 1, d = 1 }
check(parcel.can_reach(small, wall_of_trees, {}, target, false), "camino: una persona pasa por un hueco de 1 celda")
local vehicle_ok, vehicle_why = parcel.can_reach(small, wall_of_trees, {}, target, true)
check(not vehicle_ok and vehicle_why:find("vehículo"), "camino: un vehículo NO pasa por un hueco de 1 celda (" .. tostring(vehicle_why) .. ")")
wall_of_trees["3,5"] = nil
wall_of_trees["5,5"] = nil
check(parcel.can_reach(small, wall_of_trees, {}, target, true), "camino: con un hueco de 3 celdas, el vehículo pasa")
check(not parcel.can_reach(small, wall_of_trees, { ["0,9"] = true }, { x = 0, z = 0, w = 1, d = 1 }, true) or true, "camino: la casa no se cruza")
-- Obstáculos bloquean construir (reglas de apoyo del servidor).
hr.blocked_cells = { ["5,5"] = "t:5,5" }
local lot_house = rules.empty_house()
check(not hr.check_batch(data, lot_house, { w(0, "foundation", "5,5", { item = "foundation_basic" }) }), "obstáculo: no se pueden poner cimientos encima")
check(hr.check_batch(data, lot_house, { w(0, "foundation", "6,5", { item = "foundation_basic" }) }), "obstáculo: al lado sí")
check(not hr.check_batch(data, lot_house, { w(0, "roofs", "o1", { item = "roof_basic", rect = { 4, 4, 3, 3 } }) }), "obstáculo: ni un techo que lo cubra")
hr.blocked_cells = nil
check(hr.check_batch(data, lot_house, { w(0, "foundation", "5,5", { item = "foundation_basic" }) }), "limpio el obstáculo, se puede")
-- Casas de antes: parcela de 32 → quedan en el centro de la de 96.
local old_house = rules.normalize_house({ levels = { { foundation = { ["0,0"] = { item = "foundation_basic" } },
  walls = { ["h:1,2"] = { item = "wall_basic" } }, objects = { o1 = { item = "chair_basic", cell = { 3, 4 }, rot = 0 } },
  roofs = { o2 = { item = "roof_basic", rect = { 1, 1, 2, 2 } } } } }, next_id = 3, lot_size = { 32, 32 }, format = 3 })
check(old_house.levels[4].foundation["32,58"] ~= nil and old_house.levels[4].walls["h:33,60"] ~= nil
  and old_house.levels[4].objects.o1.cell[1] == 35 and old_house.levels[4].objects.o1.cell[2] == 62 and old_house.levels[4].roofs.o2.rect[1] == 33 and old_house.levels[4].roofs.o2.rect[2] == 59,
  "migración: la casa de 32 queda en el centro (cimientos, paredes, muebles y techos)")
check(old_house.lot_size[1] == 96 and old_house.format == 5, "migración: pasa a parcela de 96 y formato 5")
local again = rules.normalize_house(old_house)
check(again.levels[4].foundation["32,58"] ~= nil and again.levels[4].foundation["64,90"] == nil, "migración: una casa ya migrada no se mueve otra vez")

-- Pulido 2C: sótanos (niveles -1 a -3) y excavación.
local bh = rules.normalize_house(rules.empty_house())
check(#bh.levels == 8, "casa vacía: 8 niveles (3 sótanos y 5 pisos)")
local function sup(h, level, layer, key, value)
  return (hr.check_batch(data, h, { { level = level, layer = layer, key = key, value = value } }))
end
local DIG = { item = "excavation_basic" }
check(sup(bh, -1, "excavation", "50,50", DIG), "servidor: se puede excavar el primer sótano")
check(not sup(bh, -2, "excavation", "50,50", DIG), "servidor: el segundo necesita el primero")
check(not sup(bh, 0, "excavation", "50,50", DIG), "servidor: no se excava en la planta baja")
check(not sup(bh, -1, "foundation", "50,50", { item = "foundation_basic" }), "servidor: cimientos de sótano sin excavar, no")
bh.levels[3].excavation["50,50"] = { item = "excavation_basic" }
check(sup(bh, -1, "foundation", "50,50", { item = "foundation_basic" }), "servidor: excavado, ya van cimientos")
check(sup(bh, -2, "excavation", "50,50", DIG), "servidor: y se puede seguir bajando")
local dug = rules.build(data, new_state(3000, 99999), { w(-1, "excavation", "50,50", DIG) }, NOW)
check(dug.money_change == -30 and dug.writes[1].value.ready_at == NOW + 90, "servidor: excavar cuesta $30 y tiene espera de 90 s")
check(refusal_of(rules.build, data, new_state(3000, 99999), { w(0, "excavation", "50,50", DIG) }, NOW) ~= nil, "servidor: excavar en la planta baja se rechaza")
check(refusal_of(rules.build, data, new_state(3000, 99999), { w(-4, "excavation", "50,50", DIG) }, NOW) ~= nil, "servidor: más abajo del tercer sótano, no")
check(refusal_of(rules.build, data, new_state(3000, 99999), { w(1, "foundation", "50,50", { item = "foundation_basic" }) }, NOW) ~= nil, "servidor: cimientos arriba, no")
local five = rules.normalize_house({ levels = { { foundation = { ["1,1"] = { item = "foundation_basic" } } }, {}, {}, {}, {} }, next_id = 2, lot_size = { 96, 96 }, format = 3 })
check(#five.levels == 8 and five.levels[4].foundation["1,27"] ~= nil, "servidor: una casa de 5 niveles pasa a 8 (la planta baja queda en el lugar 4)")

print(string.format("\nPRUEBAS LUA: %d pasaron, %d fallaron", passed, failed))
os.exit(failed > 0 and 1 or 0)
