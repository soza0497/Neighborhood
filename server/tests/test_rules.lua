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


-- === Fase 5: reglas de apoyo en el servidor (los casos de tests/test_house.gd) ===

local hr = require("neighborhood_house")

local function put(house, level, layer, key, value)
  house.levels[level + 1][layer][key] = value
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
check(not supported(h, 0, "foundation", "40,1", { item = "foundation_basic" }), "apoyo: cimiento fuera de la parcela NO")
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
check(sp.house.levels[1].floors["1,1"] ~= nil, "construir: cimiento + piso en el mismo cambio SÍ")
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
check(not result.skipped and sa.house.levels[1].objects.o3 ~= nil, "deshacer propio que nadie tocó: se deshace")
result = rules.undo(sa, data)  -- poner silla + heladera (la heladera sigue igual)
check(not result.skipped, "deshacer silla + heladera: se deshace")
result = rules.undo(sa, data)  -- poner la tele, que B movió después
check(result.skipped and sa.house.levels[1].objects.o2.cell[1] == 3 and #sa.history.undo == undo_before - 3,
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
check(sd.house.levels[1].objects.o7 == nil and sd.others[B] == 1000 and sd.money == 50,
  "deshacer lo de la pareja: se quita y el dinero vuelve a B (no a quien deshace)")
check(refusal_of(rules.revert, data, sd, home, entry.id) ~= nil, "no se deshace dos veces")
-- Si alguien cambió la pieza después, no se puede.
rules.build(data, sc, { w(0, "objects", "o8", { item = "chair_basic", cell = { 2, 2 }, rot = 0 }) }, NOW)
local e2 = rules.log_entry(home, { by = B, kind = "minor", text = "puso: Silla", writes = { w(0, "objects", "o8", rules.copy(sc.house.levels[1].objects.o8)) },
  inverse = { w(0, "objects", "o8", nil) } })
sc.house.levels[1].objects.o8.cell = { 3, 3 }
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


print(string.format("\nPRUEBAS LUA: %d pasaron, %d fallaron", passed, failed))
os.exit(failed > 0 and 1 or 0)
