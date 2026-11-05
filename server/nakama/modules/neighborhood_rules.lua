--[[
Reglas del juego que decide el servidor (Fase 4B): precios, obras, deshacer,
aceleradores, empleos, turnos y pago offline.

Este archivo NO usa nada de Nakama: solo tablas de Lua. Así se puede probar
solo, con `lua5.1 server/tests/test_rules.lua` (ver docs/servidor.md), y el
módulo neighborhood.lua lo usa con los datos reales.

Las cuentas son las mismas que hace el teléfono (scripts/autoload/economy.gd):
si cambiás una regla aquí, cambiala también allá (el teléfono la usa para
MOSTRAR precios; el que decide es el servidor).

El "estado" de un jugador es una tabla:
  house    casa (como HouseData.to_dict del juego: levels, next_id, lot_size)
  money    dinero (de la billetera de Nakama)
  xp       experiencia
  discovered  { [id de pieza] = true }  (ya construidas alguna vez)
  history  { undo = {pasos}, redo = {pasos} }  (deshacer / rehacer)
  work     { job_id, applied_job, resume_ready_at, shift_job,
             shift_started_unix, last_shift_unix, last_seen_unix }
Desde la Fase 5 (casa compartida), además:
  actor    id del jugador que hace el cambio (su dinero es `money`)
  fund     caja de la casa común (nil = no comparte casa)
  others   { [id] = dinero } de otros jugadores que este cambio toca (por
           ejemplo, al deshacer lo que hizo la pareja se le devuelve a ella)
  check_support  true = revisar las reglas de apoyo (neighborhood_house.lua)
Cada función cambia el estado EN EL LUGAR. Si algo no se puede, llama a
rules.refuse("texto para el jugador") y el módulo no guarda nada.
]]

local rules = {}
local house_rules = require("neighborhood_house")

-- Medidas de la casa: las mismas que scripts/house/house_grid.gd.
rules.LOT_SIZE = 96
rules.MAX_LEVELS = 5
-- Pulido 2C: 3 sótanos (niveles -1 a -3); house.levels[nivel + 4].
rules.MIN_LEVEL = -3
rules.LEVEL_COUNT = 8
rules.LAYERS = { "foundation", "floors", "walls", "objects", "roofs", "excavation" }
-- Capas cuyas piezas tardan en construirse (economy.gd, TIMED_LAYERS).
local TIMED_LAYERS = { objects = true, roofs = true, excavation = true }
-- Qué tipos ("kind") del catálogo van en cada capa.
local LAYER_KINDS = {
  foundation = { foundation = true },
  floors = { floor = true },
  walls = { wall = true },
  objects = { furniture = true, stairs = true, pillar = true },
  roofs = { roof = true },
  excavation = { excavation = true },
}
local OPENING_KINDS = { door = true, window = true }

-- Deshacer: hasta 100 pasos (como en el teléfono) y, para que el guardado
-- no crezca sin fin, como mucho ~400 KB de pasos (se olvidan los más viejos).
rules.MAX_UNDO_STEPS = 100
rules.MAX_HISTORY_BYTES = 400 * 1024
-- Máximo de escrituras en un solo cambio (una parcela entera de cimientos
-- son 1024).
rules.MAX_WRITES = 3000

-- Empleos (DECISIONES.md, "Cuentas y servidor"): el servidor no conoce el
-- reloj del juego. Un turno se cobra si pasó al menos su duración a x5
-- (hora real) y se empieza como mucho uno cada 288 s reales (un día a x5).
-- Pulido 1: la velocidad más rápida bajó de x10 a x5 (GameClock.SPEEDS):
-- los turnos tardan más en tiempo real, así que no da ninguna ventaja.
rules.FASTEST_SPEED = 5
rules.DAY_AT_FASTEST = 288
-- Margen por la demora de la red entre empezar y cobrar.
rules.SHIFT_GRACE_SECONDS = 2
-- Pago offline: un turno por cada día del juego sin entrar (a x1, un día =
-- 1440 s reales), con tope de 3.
rules.OFFLINE_DAY_SECONDS = 1440
rules.MAX_OFFLINE_SHIFTS = 3


-- --- Ayudantes ---

-- Corta lo que se está haciendo con un texto para el jugador.
function rules.refuse(text, extra)
  local refusal = extra or {}
  refusal.refusal = text
  error(refusal, 0)
end
local refuse = rules.refuse

-- Número o nil (el tonumber de Nakama falla si no recibe nada).
local function num(value)
  if value == nil then
    return nil
  end
  return tonumber(value)
end
rules.num = num

local function is_int(value)
  return type(value) == "number" and value == math.floor(value)
end

local function in_range(value, low, high)
  return is_int(value) and value >= low and value <= high
end

-- Copia completa de una tabla (las piezas tienen listas adentro).
local function copy(value)
  if type(value) ~= "table" then
    return value
  end
  local result = {}
  for k, v in pairs(value) do
    result[k] = copy(v)
  end
  return result
end
rules.copy = copy

local function count(list)
  return list and #list or 0
end


-- --- Dinero: billetera propia y caja de la casa (Fase 5) ---

-- Dinero de un jugador: el del que hace el cambio, o el de otro (`others`).
local function money_of(state, user_id)
  if user_id == nil or user_id == state.actor then
    return state.money
  end
  return (state.others or {})[user_id] or 0
end

local function set_money(state, user_id, value)
  if user_id == nil or user_id == state.actor then
    state.money = value
  else
    state.others[user_id] = value
  end
end

-- Cómo se reparte un cambio NUEVO de dinero (negativo = se paga): en la
-- casa compartida se paga primero con la caja y lo que falta con la
-- billetera; lo que se devuelve (vender) va a la caja. Sin casa compartida,
-- todo es de la billetera. Devuelve (cambio de la caja, cambio de la billetera).
function rules.split_for(state, change)
  if state.fund == nil then
    return 0, change
  end
  if change >= 0 then
    return change, 0
  end
  local from_fund = math.min(state.fund, -change)
  return -from_fund, change + from_fund
end

-- Aplica un cambio de dinero a la caja y a la billetera de `user_id` (nil =
-- el que hace el cambio). Si la caja no alcanza, lo que falta sale de la
-- billetera; si tampoco alcanza, refuse(`text`). Devuelve lo que cambió de
-- verdad cada una (caja, billetera).
function rules.apply_split(state, fund_change, own_change, user_id, text)
  if state.fund == nil then
    own_change = own_change + fund_change
    fund_change = 0
  elseif state.fund + fund_change < 0 then
    own_change = own_change + state.fund + fund_change
    fund_change = -state.fund
  end
  local money = money_of(state, user_id)
  if money + own_change < 0 then
    refuse(text or string.format("Te faltan $%d.", -own_change - money), { reason = "money" })
  end
  if state.fund ~= nil then
    state.fund = state.fund + fund_change
  end
  set_money(state, user_id, money + own_change)
  return fund_change, own_change
end

-- Lo que se pagó en un paso viejo (antes de la Fase 5 solo había `money`).
local function step_split(step)
  if step.money_fund == nil and step.money_own == nil then
    return 0, step.money or 0
  end
  return step.money_fund or 0, step.money_own or 0
end
rules.step_split = step_split

-- ¿Dos piezas son la misma? (la hora de fin de obra no cuenta: acelerar no
-- cambia la pieza)
local function same_value(a, b)
  if type(a) ~= "table" or type(b) ~= "table" then
    return a == b
  end
  for k, v in pairs(a) do
    if k ~= "ready_at" and not same_value(v, b[k]) then
      return false
    end
  end
  for k, v in pairs(b) do
    if k ~= "ready_at" and a[k] == nil and v ~= nil then
      return false
    end
  end
  return true
end
rules.same_value = same_value

-- ¿La casa sigue como la dejaron estas escrituras? (si alguien las cambió
-- después, no se pueden deshacer sin pisar lo que hizo el otro)
function rules.writes_match(house, writes)
  for _, w in ipairs(writes) do
    local current = house_rules.level_table(house, w.level)[w.layer][w.key]
    if not same_value(current, w.value) then
      return false
    end
  end
  return true
end

-- ¿Esta escritura pone algo encima de un obstáculo sin limpiar?
function rules.touches_obstacle(w)
  if w.layer == "foundation" or w.layer == "floors" then
    local x, z = house_rules.parse_cell(w.key)
    return x ~= nil and house_rules.is_blocked(x, z)
  elseif w.layer == "roofs" and type(w.value) == "table" and type(w.value.rect) == "table" then
    local r = w.value.rect
    return house_rules.rect_blocked(r[1], r[2], r[3], r[4])
  elseif w.layer == "objects" and type(w.value) == "table" and type(w.value.cell) == "table" then
    return house_rules.is_blocked(w.value.cell[1], w.value.cell[2])
  end
  return false
end

-- Revisa las reglas de apoyo (si el estado lo pide).
local function check_support(data, state, writes, text, house)
  if not state.check_support then
    return
  end
  local ok = house_rules.check_batch(data, house or state.house, writes)
  if not ok then
    -- Pulido 2C: si lo que falla está encima de un obstáculo, se dice.
    for _, w in ipairs(writes) do
      if w.value ~= nil and rules.touches_obstacle(w) then
        refuse("Ahí hay un obstáculo (árbol, roca, laguito...): tocalo y llamá al servicio para limpiarlo.", { reason = "obstacle" })
      end
    end
    refuse(text or "Eso no tiene dónde apoyarse, o dejaría algo en el aire.", { reason = "support" })
  end
end


-- --- Datos del juego ---

-- Prepara los datos leídos de data/*.json (catálogo, progresión, empleos).
function rules.new_data(catalog, progression, jobs)
  local data = { items = {}, jobs = {}, progression = progression or {} }
  for _, item in ipairs((catalog or {}).items or {}) do
    data.items[item.id] = item
  end
  for _, job in ipairs((jobs or {}).jobs or {}) do
    data.jobs[job.id] = job
  end
  data.levels = data.progression.levels or { 0 }
  -- La última que se armó queda a mano para normalize_house (necesita saber
  -- qué pieza es ventana al convertir casas viejas).
  rules.data = data
  return data
end

function rules.unlock_level(data, item_id)
  local item = data.items[item_id]
  return item and math.floor(num(item.unlock_level) or 1) or 1
end

-- Nivel según la experiencia (economy.gd, level()).
function rules.level_for_xp(data, xp)
  local level = 1
  for i, needed in ipairs(data.levels) do
    if xp >= needed then
      level = i
    end
  end
  return level
end

-- Versión del formato de la casa (HouseData.FORMAT): 3 = Pulido 1, 4 = Pulido 2C
-- (parcela de 96: las casas de 32 quedan en el centro).
-- 5 = Pulido 3A (la casa pasa de estar centrada a estar CERCA de la calle:
-- se corre rules.HOME_SHIFT_Z celdas hacia la calle).
rules.HOUSE_FORMAT = 5
-- Cuánto se corre hacia la calle una casa de formato < 5: es
-- (lot - home_zone - home_street_gap) - (lot - home_zone) / 2 de data/parcel.json
-- (96 - 32 - 6 - 32 = 26). Lo verifica test_rules.lua con el archivo real.
rules.HOME_SHIFT_Z = 26

function rules.empty_house()
  local levels = {}
  for i = 1, rules.LEVEL_COUNT do
    levels[i] = { foundation = {}, floors = {}, walls = {}, objects = {}, roofs = {}, excavation = {} }
  end
  return { levels = levels, next_id = 1, lot_size = { rules.LOT_SIZE, rules.LOT_SIZE }, format = rules.HOUSE_FORMAT }
end

-- Casas de antes del Pulido 1 (HouseData.upgrade_legacy, la misma cuenta):
-- el color de una pared pasa a sus dos caras, y las ventanas iguales que se
-- veían unidas (sin "separate", solo esas dos en la esquina) quedan unidas
-- en la juntura (join_end en la pared que termina ahí).
local function next_in_line(key)
  local x, z, horizontal = house_rules.parse_edge(key)
  if horizontal then
    return house_rules.edge_key(x + 1, z, true), x + 1, z
  end
  return house_rules.edge_key(x, z + 1, false), x, z + 1
end

local function window_kind(data, item_id)
  local item = item_id and data and data.items[item_id]
  return item ~= nil and item.kind == "window"
end

function rules.upgrade_legacy(data, house)
  for _, level in ipairs(house.levels) do
    local walls = level.walls or {}
    local joins = {}
    for key, wall in pairs(walls) do
      if type(wall) == "table" and wall.opening ~= nil and wall.separate ~= true and window_kind(data, wall.opening) then
        local next_key, vx, vz = next_in_line(key)
        local other = walls[next_key]
        if type(other) == "table" and other.opening == wall.opening and other.separate ~= true then
          local around = 0
          for _, edge in ipairs({ house_rules.edge_key(vx, vz, true), house_rules.edge_key(vx - 1, vz, true),
              house_rules.edge_key(vx, vz, false), house_rules.edge_key(vx, vz - 1, false) }) do
            if walls[edge] ~= nil then
              around = around + 1
            end
          end
          if around == 2 then
            table.insert(joins, key)
          end
        end
      end
    end
    for _, wall in pairs(walls) do
      if type(wall) == "table" then
        if wall.color ~= nil then
          wall.color_a = wall.color_a or wall.color
          wall.color_b = wall.color_b or wall.color
          wall.color = nil
        end
        wall.separate = nil
      end
    end
    for _, key in ipairs(joins) do
      walls[key].join_end = true
    end
  end
  house.format = rules.HOUSE_FORMAT
end

-- Pulido 2: saca los techos rotos que una edición vieja pudo dejar (sin
-- medidas o fuera de la parcela: no se podían tocar ni borrar). Es la misma
-- cuenta que HouseData.repair en el teléfono. Devuelve cuántos sacó.
function rules.repair_house(house)
  local removed = 0
  for _, level in ipairs(house.levels) do
    if type(level.roofs) == "table" then
      for key, roof in pairs(level.roofs) do
        local r = type(roof) == "table" and roof.rect or nil
        local ok = type(r) == "table" and #r == 4
        if ok then
          for i = 1, 4 do
            if num(r[i]) == nil then
              ok = false
            end
          end
        end
        if ok then
          local x, z, w, d = math.floor(r[1]), math.floor(r[2]), math.floor(r[3]), math.floor(r[4])
          ok = w >= 1 and d >= 1 and x >= 0 and z >= 0 and x + w <= rules.LOT_SIZE and z + d <= rules.LOT_SIZE
        end
        if not ok then
          level.roofs[key] = nil
          removed = removed + 1
        end
      end
    end
  end
  return removed
end

-- Pulido 2C: mueve toda la casa (dx, dz) celdas. Es la misma cuenta que
-- HouseData._shift en el teléfono (las casas viejas quedan en el centro).
function rules.shift_house(house, dx, dz)
  for _, level in ipairs(house.levels) do
    for _, layer in ipairs({ "foundation", "floors", "excavation" }) do
      local moved = {}
      for key, value in pairs(level[layer]) do
        local x, z = house_rules.parse_cell(key)
        moved[house_rules.cell_key(x + dx, z + dz)] = value
      end
      level[layer] = moved
    end
    local walls = {}
    for key, value in pairs(level.walls) do
      local x, z, horizontal = house_rules.parse_edge(key)
      walls[house_rules.edge_key(x + dx, z + dz, horizontal)] = value
    end
    level.walls = walls
    for _, value in pairs(level.objects) do
      if type(value.cell) == "table" then
        value.cell = { value.cell[1] + dx, value.cell[2] + dz }
      end
    end
    for _, value in pairs(level.roofs) do
      if type(value.rect) == "table" then
        value.rect = { value.rect[1] + dx, value.rect[2] + dz, value.rect[3], value.rect[4] }
      end
    end
  end
end

-- Completa una casa leída (le pueden faltar niveles o capas vacías).
function rules.normalize_house(house)
  if type(house) ~= "table" then
    return rules.empty_house()
  end
  house.levels = type(house.levels) == "table" and house.levels or {}
  -- Pulido 2C: las casas de antes tienen 5 niveles (0 a 4): los 3 sótanos
  -- (vacíos) van al principio.
  if #house.levels <= rules.MAX_LEVELS then
    for _ = 1, rules.LEVEL_COUNT - rules.MAX_LEVELS do
      table.insert(house.levels, 1, {})
    end
  end
  for i = 1, rules.LEVEL_COUNT do
    house.levels[i] = type(house.levels[i]) == "table" and house.levels[i] or {}
    for _, layer in ipairs(rules.LAYERS) do
      if type(house.levels[i][layer]) ~= "table" then
        house.levels[i][layer] = {}
      end
    end
  end
  house.next_id = math.floor(num(house.next_id) or 1)
  house.lot_size = type(house.lot_size) == "table" and house.lot_size or { rules.LOT_SIZE, rules.LOT_SIZE }
  rules.repair_house(house)
  local old_format = num(house.format) or 1
  -- Pulido 2C: si la parcela era más chica, la casa se centra en la nueva.
  local saved = num(house.lot_size[1]) or rules.LOT_SIZE
  if saved ~= rules.LOT_SIZE then
    local offset = math.floor((rules.LOT_SIZE - saved) / 2)
    rules.shift_house(house, offset, offset)
    house.lot_size = { rules.LOT_SIZE, rules.LOT_SIZE }
  end
  if old_format < 3 then
    rules.upgrade_legacy(rules.data, house)
  end
  -- Pulido 3A: la casa se acerca a la calle (después de centrarla).
  if old_format < 5 then
    rules.shift_house(house, 0, rules.HOME_SHIFT_Z)
  end
  house.format = rules.HOUSE_FORMAT
  return house
end


-- --- Precios (economy.gd: piece_cost, change_for, accelerate_cost) ---

function rules.piece_cost(data, layer, value)
  if value == nil then
    return 0
  end
  local item = data.items[value.item] or {}
  local cost = math.floor(num(item.price) or 0)
  if layer == "walls" and value.opening ~= nil then
    local opening = data.items[value.opening] or {}
    cost = cost + math.floor(num(opening.price) or 0)
  elseif layer == "roofs" and type(value.rect) == "table" then
    cost = cost * (value.rect[3] or 0) * (value.rect[4] or 0)
  end
  return cost
end

-- Cambio de dinero por pasar de `old` a `new` (negativo = se paga).
-- Subir de valor se paga entero; bajar devuelve un % (reventa).
function rules.change_for(data, layer, old, new)
  local difference = rules.piece_cost(data, layer, new) - rules.piece_cost(data, layer, old)
  if difference >= 0 then
    return -difference
  end
  local percent = num(data.progression.resale_percent) or 50
  -- round() de Godot: la mitad se redondea hacia arriba.
  return math.floor(-difference * percent / 100 + 0.5)
end

function rules.accelerate_cost(data, seconds)
  if seconds <= 0 then
    return 0
  end
  local per_minute = num(data.progression.accelerate_coins_per_minute) or 6
  return math.max(1, math.ceil(seconds / 60 * per_minute))
end

-- Experiencia por construir un tipo de pieza por primera vez.
function rules.discovery_xp(data, item_id)
  local item = data.items[item_id] or {}
  local price = math.floor(num(item.price) or 0)
  local min_xp = num(data.progression.discovery_xp_min) or 5
  local percent = num(data.progression.discovery_xp_percent) or 10
  return math.max(min_xp, math.floor(price * percent / 100))
end


-- --- Validar lo que manda el teléfono ---

-- Clave de celda "x,z" (cimientos y pisos) dentro de la parcela.
local function check_cell_key(key)
  local x, z = string.match(key, "^(%-?%d+),(%-?%d+)$")
  x, z = num(x), num(z)
  return x ~= nil and in_range(x, 0, rules.LOT_SIZE - 1) and in_range(z, 0, rules.LOT_SIZE - 1)
end

-- Clave de pared "h:x,z" o "v:x,z" (vértice de la cuadrícula).
local function check_edge_key(key)
  local x, z = string.match(key, "^[hv]:(%-?%d+),(%-?%d+)$")
  x, z = num(x), num(z)
  return x ~= nil and in_range(x, 0, rules.LOT_SIZE) and in_range(z, 0, rules.LOT_SIZE)
end

-- Clave de objeto o techo "o7". Devuelve el número.
local function object_number(key)
  local number = string.match(key, "^o(%d+)$")
  return num(number)
end

local function check_key(layer, key)
  if type(key) ~= "string" or #key > 16 then
    return false
  end
  if layer == "foundation" or layer == "floors" or layer == "excavation" then
    return check_cell_key(key)
  elseif layer == "walls" then
    return check_edge_key(key)
  end
  return object_number(key) ~= nil
end

local function check_color(color)
  return type(color) == "string" and #color <= 9 and string.match(color, "^#%x+$") ~= nil
end

-- Deja solo los campos conocidos de una pieza (y revisa que tengan sentido).
-- `ready_at` NUNCA se acepta del teléfono: lo pone el servidor.
local function clean_value(data, layer, value)
  if type(value) ~= "table" then
    refuse("Pieza inválida.")
  end
  local item = data.items[value.item]
  if item == nil then
    refuse("Esa pieza no existe en el catálogo: " .. tostring(value.item))
  end
  if not LAYER_KINDS[layer][item.kind] then
    refuse(item.name .. " no va ahí.")
  end
  local clean = { item = value.item }
  -- color: piso, mueble, techo (y paredes de antes). color_a / color_b:
  -- las dos caras de una pared (Pulido 1).
  for _, field in ipairs({ "color", "color_a", "color_b" }) do
    if value[field] ~= nil then
      if not check_color(value[field]) or (field ~= "color" and layer ~= "walls") then
        refuse("Color inválido.")
      end
      clean[field] = value[field]
    end
  end
  if layer == "walls" then
    if value.opening ~= nil then
      local opening = data.items[value.opening]
      if opening == nil or not OPENING_KINDS[opening.kind] then
        refuse("Puerta o ventana inválida.")
      end
      clean.opening = value.opening
    end
    if value.join_end == true then
      clean.join_end = true
    end
  elseif layer == "objects" then
    local cell, rot = value.cell, value.rot or 0
    if type(cell) ~= "table" or not in_range(rot, 0, 3) then
      refuse("Posición inválida.")
    end
    local footprint = item.footprint or { 1, 1 }
    local width, depth = footprint[1], footprint[2]
    if rot % 2 == 1 then
      width, depth = depth, width
    end
    if not in_range(cell[1], 0, rules.LOT_SIZE - width) or not in_range(cell[2], 0, rules.LOT_SIZE - depth) then
      refuse("Eso queda fuera de la parcela.")
    end
    clean.cell = { cell[1], cell[2] }
    clean.rot = rot
    -- 45° más (solo muebles; las reglas de apoyo lo revisan).
    if value.diag == true then
      if item.kind ~= "furniture" then
        refuse("Eso no se puede poner en diagonal.")
      end
      clean.diag = true
    end
  elseif layer == "roofs" then
    local r = value.rect
    if type(r) ~= "table" or not in_range(r[1], 0, rules.LOT_SIZE - 1) or not in_range(r[2], 0, rules.LOT_SIZE - 1)
        or not in_range(r[3], 1, rules.LOT_SIZE - r[1]) or not in_range(r[4], 1, rules.LOT_SIZE - r[2]) then
      refuse("Techo fuera de la parcela.")
    end
    clean.rect = { r[1], r[2], r[3], r[4] }
  end
  return clean
end

-- Revisa una escritura {level, layer, key, value} y la devuelve limpia.
local function clean_write(data, w)
  if type(w) ~= "table" or not in_range(w.level, rules.MIN_LEVEL, rules.MAX_LEVELS - 1) or LAYER_KINDS[w.layer] == nil then
    refuse("Cambio inválido.")
  end
  if w.layer == "foundation" and w.level > 0 then
    refuse("Los cimientos van solo en la planta baja o en un sótano.")
  end
  if w.layer == "excavation" and w.level >= 0 then
    refuse("Solo se excava en un sótano.")
  end
  if not check_key(w.layer, w.key) then
    refuse("Lugar inválido: " .. tostring(w.key))
  end
  local clean = { level = w.level, layer = w.layer, key = w.key }
  if w.value ~= nil then
    clean.value = clean_value(data, w.layer, w.value)
  end
  return clean
end


-- --- Casa ---

local function get_piece(house, w)
  return house_rules.level_table(house, w.level)[w.layer][w.key]
end

-- Aplica escrituras a la casa y devuelve las que la deshacen (al revés,
-- como HouseData.apply del juego). value = nil significa "quitar".
function rules.apply_writes(house, writes)
  local inverse = {}
  for _, w in ipairs(writes) do
    local previous = get_piece(house, w)
    table.insert(inverse, 1, { level = w.level, layer = w.layer, key = w.key, value = copy(previous) })
    house_rules.level_table(house, w.level)[w.layer][w.key] = copy(w.value)
  end
  return inverse
end

-- ¿La pieza es nueva o de otro tipo que la anterior? (cobra tiempo de obra
-- y revisa el nivel)
local function is_new_item(old, value)
  return old == nil or old.item ~= value.item
end

-- Pone la hora de fin de obra (con la hora del SERVIDOR). Mover o pintar
-- una pieza conserva su obra; una pieza nueva empieza la suya.
local function stamp_timer(data, w, old, now)
  local value = w.value
  if value == nil or not TIMED_LAYERS[w.layer] then
    return
  end
  local seconds = math.floor(num((data.items[value.item] or {}).build_seconds) or 0)
  if is_new_item(old, value) then
    if seconds > 0 then
      value.ready_at = now + seconds
    end
  elseif old.ready_at ~= nil then
    value.ready_at = old.ready_at
  end
end

-- Guarda un paso de deshacer (y olvida los más viejos si hay demasiados).
local function push_step(history, step, encode)
  table.insert(history.undo, step)
  while #history.undo > rules.MAX_UNDO_STEPS do
    table.remove(history.undo, 1)
  end
  if encode ~= nil then
    while #history.undo > 1 and #encode(history.undo) > rules.MAX_HISTORY_BYTES do
      table.remove(history.undo, 1)
    end
  end
  history.redo = {}
end

-- Revisa y limpia todas las escrituras que mandó el teléfono (rechaza el
-- cambio entero si alguna no sirve).
function rules.clean_writes(data, writes)
  if type(writes) ~= "table" or count(writes) == 0 then
    refuse("No hay nada que construir.")
  end
  if count(writes) > rules.MAX_WRITES then
    refuse("Es demasiado de una vez: hacelo por partes.")
  end
  local clean = {}
  for _, raw in ipairs(writes) do
    table.insert(clean, clean_write(data, raw))
  end
  return clean
end

-- Construir: cobra, pone obras, da experiencia por lo nuevo y guarda el paso
-- de deshacer. `encode` (opcional) mide el tamaño del historial.
-- En la casa compartida se paga primero con la caja (ver split_for).
-- Devuelve {writes = escrituras aplicadas, money_change, money_fund,
-- money_own, xp_gained}.
function rules.build(data, state, writes, now, encode)
  local clean = rules.clean_writes(data, writes)
  -- Las reglas de apoyo se revisan al final (con la casa de antes), para
  -- que primero se avise lo más útil: nivel y dinero.
  local original = state.check_support and copy(state.house) or nil
  local level = rules.level_for_xp(data, state.xp)
  local house = state.house
  local applied, inverse = {}, {}
  local money_change, xp_gained = 0, 0
  for _, w in ipairs(clean) do
    local old = get_piece(house, w)
    if w.value ~= nil then
      for _, field in ipairs({ "item", "opening" }) do
        local item_id = w.value[field]
        local is_new = item_id ~= nil and (old == nil or old[field] ~= item_id)
        if is_new and rules.unlock_level(data, item_id) > level then
          refuse(string.format("%s se desbloquea en el nivel %d.", data.items[item_id].name, rules.unlock_level(data, item_id)))
        end
      end
      stamp_timer(data, w, old, now)
    end
    money_change = money_change + rules.change_for(data, w.layer, old, w.value)
    table.insert(inverse, 1, rules.apply_writes(house, { w })[1])
    table.insert(applied, w)
    -- Los objetos y techos nuevos traen su nombre ("o12"): el contador sigue.
    local number = object_number(w.key)
    if number ~= nil and number >= house.next_id then
      house.next_id = number + 1
    end
    -- La primera vez de cada tipo de pieza da experiencia.
    if w.value ~= nil then
      for _, item_id in ipairs({ w.value.item, w.value.opening }) do
        if item_id ~= nil and not state.discovered[item_id] then
          state.discovered[item_id] = true
          xp_gained = xp_gained + rules.discovery_xp(data, item_id)
        end
      end
    end
  end
  local available = state.money + (state.fund or 0)
  if available + money_change < 0 then
    local where = state.fund ~= nil and " (entre la caja de la casa y tu billetera)" or ""
    refuse(string.format("Te faltan $%d para construir esto%s.", -money_change - available, where),
      { reason = "money" })
  end
  check_support(data, state, clean, nil, original)
  local fund_change, own_change = rules.split_for(state, money_change)
  rules.apply_split(state, fund_change, own_change)
  state.xp = state.xp + xp_gained
  push_step(state.history, { writes = applied, inverse = inverse, money = money_change,
    money_fund = fund_change, money_own = own_change }, encode)
  return { writes = applied, money_change = money_change, money_fund = fund_change, money_own = own_change,
    xp_gained = xp_gained }
end

-- --- Mudar la casa entera (Pulido 6A, 8) ---

-- La misma cuenta que HouseMove.fee del juego: base + por pieza + por distancia, con tope.
local MOVE_LAYERS = { "foundation", "excavation", "floors", "walls", "objects", "roofs" }

function rules.piece_count(house)
  local total = 0
  for _, level in ipairs(house.levels) do
    for _, layer in ipairs(MOVE_LAYERS) do
      for _ in pairs(level[layer] or {}) do
        total = total + 1
      end
    end
  end
  return total
end

function rules.move_fee(data, house, dx, dz)
  if (dx == 0 and dz == 0) or rules.piece_count(house) == 0 then
    return 0
  end
  local cfg = (data.progression or {}).move_house or {}
  local total = (num(cfg.base) or 60) + (num(cfg.per_piece) or 1) * rules.piece_count(house)
    + (num(cfg.per_step) or 4) * (math.abs(dx) + math.abs(dz))
  local top = num(cfg.max) or 5000
  return math.min(math.floor(total + 0.5), top)
end

-- Las escrituras de la mudanza (como HouseMove.writes_for): primero se quita lo de las celdas
-- viejas y después se pone todo en las nuevas. Objetos y techos conservan su nombre.
function rules.move_writes(house, dx, dz)
  local moved = copy(house)
  rules.shift_house(moved, dx, dz)
  local removals, placements = {}, {}
  for index, level in ipairs(house.levels) do
    local level_number = index - 1 + rules.MIN_LEVEL
    local new_level = moved.levels[index]
    for _, layer in ipairs(MOVE_LAYERS) do
      for key in pairs(level[layer]) do
        if layer ~= "objects" and layer ~= "roofs" and new_level[layer][key] == nil then
          table.insert(removals, { level = level_number, layer = layer, key = key, value = nil })
        end
      end
      for key, value in pairs(new_level[layer]) do
        table.insert(placements, { level = level_number, layer = layer, key = key, value = value })
      end
    end
  end
  for _, w in ipairs(placements) do
    table.insert(removals, w)
  end
  return removals
end

-- Muda la casa (dx, dz) celdas. El material no se pierde: solo se paga la mudanza. El servidor revisa
-- que todo quede apoyado, dentro del lote y sin obstáculos (las mismas reglas de siempre).
-- Devuelve {writes, money_change, money_fund, money_own, xp_gained}.
function rules.move_house(data, state, dx, dz, now, encode)
  dx, dz = num(dx), num(dz)
  if not (is_int(dx) and is_int(dz)) or math.abs(dx) > rules.LOT_SIZE or math.abs(dz) > rules.LOT_SIZE then
    refuse("Ese lugar no existe.")
  end
  if dx == 0 and dz == 0 then
    refuse("La casa ya está ahí.")
  end
  if state.shared then
    refuse("Mudar la casa compartida se pide entre los dos: por ahora no se puede.")
  end
  if rules.piece_count(state.house) == 0 then
    refuse("Todavía no hay casa para mudar.")
  end
  local fee = rules.move_fee(data, state.house, dx, dz)
  local available = state.money + (state.fund or 0)
  if available < fee then
    refuse(string.format("Te faltan $%d para la mudanza.", fee - available), { reason = "money" })
  end
  local original = copy(state.house)
  local writes = rules.move_writes(state.house, dx, dz)
  local inverse = {}
  for _, w in ipairs(writes) do
    table.insert(inverse, 1, rules.apply_writes(state.house, { w })[1])
  end
  check_support(data, state, writes, "No se puede mudar la casa ahí: algo no entra (borde, obstáculo, terreno cerrado o sin apoyo).", original)
  local money_change = -fee
  local fund_change, own_change = rules.split_for(state, money_change)
  rules.apply_split(state, fund_change, own_change)
  push_step(state.history, { writes = writes, inverse = inverse, money = money_change,
    money_fund = fund_change, money_own = own_change }, encode)
  return { writes = writes, money_change = money_change, money_fund = fund_change, money_own = own_change, xp_gained = 0 }
end

-- Deshacer el último paso: devuelve EXACTAMENTE lo que se cobró (a la caja
-- lo que salió de la caja, a la billetera lo de la billetera).
-- Con dos personas editando: si alguien cambió después esas piezas, no se
-- deshace (pisaría lo del otro). `data` (opcional) para las reglas de apoyo.
function rules.undo(state, data)
  local step = state.history.undo[#state.history.undo]
  if step == nil then
    refuse("No hay nada para deshacer.")
  end
  if not rules.writes_match(state.house, step.writes) then
    -- Alguien (la pareja) cambió esas piezas después: deshacer pisaría lo
    -- suyo. El paso se descarta (si no, trabaría los anteriores).
    table.remove(state.history.undo)
    return { writes = {}, money_change = 0, skipped = true,
      message = "Eso ya lo cambiaron después: se quitó de deshacer." }
  end
  if data ~= nil then
    check_support(data, state, step.inverse, "No se puede deshacer: algo quedaría en el aire.")
  end
  local mf, mo = step_split(step)
  local fund_change, own_change = rules.apply_split(state, -mf, -mo, nil, "No alcanza el dinero para deshacer esto.")
  table.remove(state.history.undo)
  rules.apply_writes(state.house, step.inverse)
  -- Rehacer revierte exactamente lo que hizo este deshacer.
  step.money_fund, step.money_own, step.money = -fund_change, -own_change, -(fund_change + own_change)
  table.insert(state.history.redo, step)
  return { writes = step.inverse, money_change = fund_change + own_change, money_fund = fund_change,
    money_own = own_change }
end

-- Rehacer: vuelve a cobrar lo mismo.
function rules.redo(state, data)
  local step = state.history.redo[#state.history.redo]
  if step == nil then
    refuse("No hay nada para rehacer.")
  end
  if not rules.writes_match(state.house, step.inverse) then
    table.remove(state.history.redo)
    return { writes = {}, money_change = 0, skipped = true,
      message = "Eso ya lo cambiaron después: se quitó de rehacer." }
  end
  if data ~= nil then
    check_support(data, state, step.writes, "No se puede rehacer: algo quedaría en el aire.")
  end
  local mf, mo = step_split(step)
  local total = mf + mo
  local available = state.money + (state.fund or 0)
  if total < 0 and available + total < 0 then
    refuse(string.format("Te faltan $%d para rehacerlo.", -total - available), { reason = "money" })
  end
  local fund_change, own_change = rules.apply_split(state, mf, mo)
  table.remove(state.history.redo)
  rules.apply_writes(state.house, step.writes)
  step.money_fund, step.money_own, step.money = fund_change, own_change, fund_change + own_change
  table.insert(state.history.undo, step)
  return { writes = step.writes, money_change = fund_change + own_change, money_fund = fund_change,
    money_own = own_change }
end

-- Obras en marcha: lista de {level, layer, key, ready_at}.
function rules.pending_construction(house, now)
  local result = {}
  for level = rules.MIN_LEVEL, rules.MAX_LEVELS - 1 do
    for layer in pairs(TIMED_LAYERS) do
      for key, value in pairs(house_rules.level_table(house, level)[layer]) do
        local ready_at = num(value.ready_at) or 0
        if ready_at > now then
          table.insert(result, { level = level, layer = layer, key = key, ready_at = ready_at })
        end
      end
    end
  end
  return result
end

-- Termina todas las obras de una vez (sin paso de deshacer: no se
-- "des-acelera").
function rules.accelerate_builds(data, state, now)
  local pending = rules.pending_construction(state.house, now)
  if #pending == 0 then
    refuse("No hay obras en marcha.")
  end
  local seconds = 0
  for _, p in ipairs(pending) do
    seconds = seconds + p.ready_at - now
  end
  local cost = rules.accelerate_cost(data, seconds)
  local available = state.money + (state.fund or 0)
  if available < cost then
    refuse(string.format("Te faltan $%d para acelerar.", cost - available), { reason = "money" })
  end
  local writes = {}
  for _, p in ipairs(pending) do
    local value = copy(house_rules.level_table(state.house, p.level)[p.layer][p.key])
    value.ready_at = nil
    table.insert(writes, { level = p.level, layer = p.layer, key = p.key, value = value })
  end
  rules.apply_writes(state.house, writes)
  local fund_change, own_change = rules.split_for(state, -cost)
  rules.apply_split(state, fund_change, own_change)
  return { writes = writes, money_change = -cost, money_fund = fund_change, money_own = own_change }
end


-- --- Empleos ---

-- Si ya llegó la respuesta al currículum, te contratan. Devuelve true si
-- te contrataron ahora.
function rules.resolve_resume(state, now)
  local work = state.work
  if work.applied_job ~= "" and now >= work.resume_ready_at then
    work.job_id = work.applied_job
    work.applied_job = ""
    work.resume_ready_at = 0
    return true
  end
  return false
end

function rules.job_apply(data, state, job_id, now)
  local job = data.jobs[job_id]
  local work = state.work
  rules.resolve_resume(state, now)
  if job == nil then
    refuse("Ese empleo no existe.")
  elseif work.applied_job ~= "" then
    refuse("Ya mandaste un currículum: esperá la respuesta.")
  elseif work.job_id == job_id then
    refuse("Ese ya es tu empleo.")
  elseif rules.level_for_xp(data, state.xp) < (job.level or 1) then
    refuse(string.format("%s pide nivel %d.", job.name, job.level))
  end
  work.applied_job = job_id
  work.resume_ready_at = now + math.floor(num(job.resume_minutes) or 5) * 60
  return {}
end

-- Paga para recibir la respuesta del currículum ya.
function rules.accelerate_resume(data, state, now)
  local work = state.work
  rules.resolve_resume(state, now)
  if work.applied_job == "" then
    refuse("No hay currículum esperando respuesta.")
  end
  local cost = rules.accelerate_cost(data, work.resume_ready_at - now)
  if state.money < cost then
    refuse(string.format("Te faltan $%d para acelerar.", cost - state.money), { reason = "money" })
  end
  state.money = state.money - cost
  work.resume_ready_at = now
  rules.resolve_resume(state, now)
  return { money_change = -cost }
end

-- Renunciar: un turno en marcha no se cobra (como en el teléfono).
function rules.job_quit(state)
  local work = state.work
  if work.job_id == "" then
    refuse("No tenés empleo.")
  end
  work.job_id = ""
  work.shift_job = ""
  work.shift_started_unix = 0
  return {}
end

-- Cobra un sueldo: va a la billetera, o a la caja de la casa si el jugador
-- eligió "unir ingresos" (y vive en una casa compartida). Devuelve true si
-- fue a la caja.
function rules.add_income(state, amount)
  if state.pool_income and state.fund ~= nil then
    state.fund = state.fund + amount
    return true
  end
  state.money = state.money + amount
  return false
end

function rules.shift_pay(job)
  return math.floor(num(job.pay_per_hour) or 0) * math.floor(num(job.shift_hours) or 0)
end

-- Segundos reales que dura un turno a la velocidad más rápida (x5).
function rules.min_shift_seconds(job)
  return math.floor(num(job.shift_hours) or 0) * 60 / rules.FASTEST_SPEED
end

-- Empieza un turno (el personaje llegó a la acera).
function rules.shift_start(data, state, now)
  local work = state.work
  rules.resolve_resume(state, now)
  if work.job_id == "" or data.jobs[work.job_id] == nil then
    refuse("No tenés empleo.")
  elseif work.shift_started_unix > 0 then
    refuse("Ya hay un turno en marcha.")
  end
  local wait = work.last_shift_unix + rules.DAY_AT_FASTEST - now
  if wait > 0 then
    refuse("Todavía no toca otro turno.", { reason = "too_early", seconds_left = wait })
  end
  work.shift_job = work.job_id
  work.shift_started_unix = now
  work.last_shift_unix = now
  return {}
end

-- Cobra el turno en marcha si ya pasó su duración (a x5, con margen).
-- Devuelve {pay, xp_gained} o nil si todavía no se puede.
local function pay_shift(data, state, now)
  local work = state.work
  local job = data.jobs[work.shift_job]
  if work.shift_started_unix <= 0 or job == nil then
    return nil
  end
  local left = work.shift_started_unix + rules.min_shift_seconds(job) - rules.SHIFT_GRACE_SECONDS - now
  if left > 0 then
    return nil, left
  end
  local pay = rules.shift_pay(job)
  local xp = math.floor(num(job.xp_per_shift) or 0)
  local to_fund = rules.add_income(state, pay)
  state.xp = state.xp + xp
  work.shift_started_unix = 0
  work.shift_job = ""
  return { pay = pay, xp_gained = xp, money_change = to_fund and 0 or pay, to_fund = to_fund }
end

function rules.shift_complete(data, state, now)
  if state.work.shift_started_unix <= 0 then
    refuse("No hay turno que cobrar.")
  end
  local result, left = pay_shift(data, state, now)
  if result == nil then
    if left == nil then
      state.work.shift_started_unix = 0  -- El empleo ya no existe.
      refuse("Ese empleo ya no existe.")
    end
    refuse("El turno todavía no terminó.", { reason = "too_early", seconds_left = math.ceil(left) })
  end
  return result
end

-- Al entrar al juego: cobra el turno que quedó a medias y paga un turno por
-- cada día del juego que pasó sin entrar (tope 3). "Nada castiga por
-- desconectarse" (VISION.md).
function rules.settle(data, state, now)
  local work = state.work
  local result = { pending_pay = 0, offline_shifts = 0, offline_pay = 0, money_change = 0, xp_gained = 0 }
  result.hired = rules.resolve_resume(state, now)
  local paid, left = pay_shift(data, state, now)
  if paid ~= nil then
    result.pending_pay = paid.pay
    result.money_change = paid.money_change
    result.to_fund = paid.to_fund
    result.xp_gained = paid.xp_gained
  elseif left ~= nil then
    result.pending_seconds_left = math.ceil(left)
  end
  local job = data.jobs[work.job_id]
  if job ~= nil and work.last_seen_unix > 0 then
    local days = math.floor((now - work.last_seen_unix) / rules.OFFLINE_DAY_SECONDS)
    local shifts = math.max(0, math.min(days, rules.MAX_OFFLINE_SHIFTS))
    if shifts > 0 then
      local pay = rules.shift_pay(job) * shifts
      local xp = math.floor(num(job.xp_per_shift) or 0) * shifts
      result.to_fund = rules.add_income(state, pay) or result.to_fund
      result.offline_shifts = shifts
      result.offline_pay = pay
      state.xp = state.xp + xp
      result.money_change = result.money_change + (result.to_fund and 0 or pay)
      result.xp_gained = result.xp_gained + xp
    end
  end
  work.last_seen_unix = now
  return result
end

-- --- Casa compartida (Fase 5): historial, pedidos y caja ---

-- El "hogar" vive junto a la casa (storage game/home del dueño):
--   rev       número que sube con cada cambio (para que los teléfonos sepan
--             si están al día)
--   fund      caja de la casa común (dinero)
--   members   ids de quienes viven ahí
--   log       historial: {id, rev, by, by_name, at, kind, text, writes?,
--             inverse?, money_fund, money_own, reverted}
--             kind: "build" (casa de uno solo), "minor" (cambio menor en la
--             casa compartida: se puede deshacer por el otro), "approved",
--             "undo", "redo", "revert", "accelerate", "fund", "request",
--             "rejected", "move_in", "move_out"
--   requests  cambios estructurales esperando aprobación:
--             {id, by, by_name, at, writes, text, cost}
rules.MAX_LOG = 40
-- Un cambio menor con más escrituras que esto no guarda sus piezas en el
-- historial (no se podrá deshacer desde ahí; sí con el Deshacer propio).
rules.MAX_LOG_WRITES = 300
rules.MAX_REQUESTS = 10

function rules.empty_home(owner_id)
  -- business: el negocio de la casa (Fase 6, neighborhood_business.lua);
  -- vacío = ninguno.
  -- parcel: obstáculos limpiados y servicios en camino (Pulido 2C).
  return { rev = 0, fund = 0, members = { owner_id }, log = {}, requests = {}, next_id = 1, business = {}, parcel = {} }
end

-- Completa un hogar leído (le pueden faltar campos).
function rules.normalize_home(home, owner_id)
  local result = rules.empty_home(owner_id)
  if type(home) == "table" then
    for k, default in pairs(result) do
      if type(home[k]) == type(default) then
        result[k] = home[k]
      end
    end
  end
  result.rev = math.floor(num(result.rev) or 0)
  result.fund = math.max(0, math.floor(num(result.fund) or 0))
  result.next_id = math.floor(num(result.next_id) or 1)
  -- Listas: Lua no distingue {} vacío de lista vacía.
  for _, list in ipairs({ "log", "requests", "members" }) do
    local clean = {}
    for _, v in ipairs(result[list]) do
      table.insert(clean, v)
    end
    result[list] = clean
  end
  if #result.members == 0 then
    result.members = { owner_id }
  end
  return result
end

-- Anota algo en el historial (sube rev). Devuelve la entrada.
function rules.log_entry(home, entry)
  entry.id = home.next_id
  home.next_id = home.next_id + 1
  home.rev = home.rev + 1
  entry.rev = home.rev
  entry.money_fund = entry.money_fund or 0
  entry.money_own = entry.money_own or 0
  entry.reverted = false
  if entry.writes ~= nil and count(entry.writes) > rules.MAX_LOG_WRITES then
    entry.writes, entry.inverse = nil, nil
  end
  table.insert(home.log, entry)
  while #home.log > rules.MAX_LOG do
    table.remove(home.log, 1)
  end
  return entry
end

function rules.find_entry(home, id)
  for _, entry in ipairs(home.log) do
    if entry.id == id then
      return entry
    end
  end
  return nil
end

-- ¿Esta entrada del historial se puede deshacer todavía?
function rules.can_revert(state, entry)
  return entry.kind == "minor" and not entry.reverted and entry.writes ~= nil and entry.inverse ~= nil
    and rules.writes_match(state.house, entry.writes)
end

-- Deshacer un cambio menor del historial (normalmente, uno de la pareja).
-- El dinero vuelve a quien lo pagó (su billetera y la caja), nunca al que
-- deshace. Si alguien cambió esas piezas después, ya no se puede.
function rules.revert(data, state, home, entry_id)
  local entry = rules.find_entry(home, entry_id)
  if entry == nil or entry.kind ~= "minor" or entry.writes == nil or entry.inverse == nil then
    refuse("Eso no se puede deshacer desde el historial.")
  elseif entry.reverted then
    refuse("Eso ya se deshizo.")
  elseif not rules.writes_match(state.house, entry.writes) then
    refuse("Ya no se puede deshacer: alguien lo cambió después.", { reason = "changed" })
  end
  check_support(data, state, entry.inverse, "No se puede deshacer: algo quedaría en el aire.")
  local fund_change, own_change = rules.apply_split(state, -entry.money_fund, -entry.money_own, entry.by,
    "No alcanza el dinero para deshacerlo.")
  rules.apply_writes(state.house, entry.inverse)
  entry.reverted = true
  return { writes = entry.inverse, money_fund = fund_change, money_own = own_change, entry = entry }
end

-- Guarda un pedido de cambio estructural (ya revisado). Devuelve el pedido.
function rules.add_request(home, request)
  if #home.requests >= rules.MAX_REQUESTS then
    refuse("Hay demasiados pedidos esperando: que tu pareja responda los que hay.")
  end
  request.id = home.next_id
  home.next_id = home.next_id + 1
  home.rev = home.rev + 1
  table.insert(home.requests, request)
  return request
end

-- Saca un pedido de la lista. Devuelve el pedido (o refuse si no existe).
function rules.take_request(home, id)
  for i, request in ipairs(home.requests) do
    if request.id == id then
      table.remove(home.requests, i)
      home.rev = home.rev + 1
      return request
    end
  end
  refuse("Ese pedido ya no existe.")
end

-- Aportar dinero de la billetera propia a la caja de la casa.
rules.MAX_CONTRIBUTION = 1000000
function rules.contribute(state, amount)
  amount = num(amount)
  if state.fund == nil then
    refuse("La caja es para cuando viven juntos.")
  elseif amount == nil or not is_int(amount) or amount <= 0 or amount > rules.MAX_CONTRIBUTION then
    refuse("Monto inválido.")
  elseif state.money < amount then
    refuse(string.format("No tenés tanto: tu billetera tiene $%d.", state.money), { reason = "money" })
  end
  state.money = state.money - amount
  state.fund = state.fund + amount
  return { money_change = -amount, fund = state.fund }
end

-- Al separarse, la caja se reparte en dos (la moneda que sobra, al dueño
-- de la casa). Devuelve (para el dueño, para el otro).
function rules.split_fund(fund)
  local half = math.floor(fund / 2)
  return fund - half, half
end


-- Un trabajo vacío (cuenta nueva).
function rules.empty_work()
  return {
    job_id = "", applied_job = "", resume_ready_at = 0, shift_job = "",
    shift_started_unix = 0, last_shift_unix = 0, last_seen_unix = 0,
  }
end

-- Completa un trabajo leído del storage (por si le faltan campos).
function rules.normalize_work(work)
  local result = rules.empty_work()
  if type(work) == "table" then
    for k, default in pairs(result) do
      local v = work[k]
      if type(v) == type(default) then
        result[k] = v
      end
    end
  end
  return result
end

return rules
