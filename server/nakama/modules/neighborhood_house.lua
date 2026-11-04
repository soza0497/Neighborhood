--[[
Reglas de APOYO de la casa en el servidor (Fase 5): qué se sostiene sobre qué.

Desde la Fase 5 la casa la editan dos personas, así que el servidor también
revisa que nada quede "en el aire". Es la misma lógica que
scripts/house/house_rules.gd y scripts/house/house_grid.gd del juego: si
cambiás una regla allá, cambiala aquí también (las pruebas de los dos lados
usan los mismos casos).

Igual que neighborhood_rules.lua, NO usa nada de Nakama: se prueba sola con
`lua5.1 server/tests/test_rules.lua`.

Reglas de apoyo:
  - Cimientos: solo en la planta baja, dentro de la parcela.
  - Piso en planta baja: sobre cimientos.
  - Piso arriba: sobre otro piso, junto a una pared de abajo (balcón) o cerca
    de un pilar de abajo (a 2 celdas o menos), y no encima de una escalera
    ni adentro de un techo del piso de abajo.
  - Pared en planta baja: junto a cimientos. Arriba: junto a un piso de ese
    nivel, o encima de otra pared, y no atravesando un techo de abajo.
  - Objeto: todas sus celdas con piso, sin otro objeto y sin paredes
    atravesadas. Las escaleras no van en el último nivel. Lo de afuera
    ("outdoor": escalera metálica, pilar) en la planta baja no necesita piso.
    Solo los muebles van en diagonal (diag = 45° más, ver diag_cells).
  - Techo: dentro de la parcela, sin pared ni piso del nivel de arriba
    metidos adentro.

Diferencia con el teléfono: el teléfono revisa mientras arrastrás (pieza por
pieza, para pintar de verde o rojo). El servidor revisa el RESULTADO: aplica
todo el cambio a una copia y mira que cada pieza tocada, y todo lo que se
apoyaba en ellas, siga apoyado. Así sirve igual para construir, deshacer,
rehacer y deshacer lo de la pareja.

Las casas son como HouseData.to_dict del juego, con los niveles desde 1
(Lua): house.levels[nivel + 1][capa][clave]. Los "nivel" de las escrituras
empiezan en 0, como en el juego.
]]

local M = {}

M.LOT_SIZE = 96

-- Pulido 2C: celdas con un obstáculo sin limpiar ("x,z" → id). Lo pone
-- neighborhood.lua en cada pedido (según la parcela del dueño de la casa) y
-- lo borra al terminar; nada se guarda con la casa.
M.blocked_cells = nil

-- ¿Algún obstáculo sin limpiar dentro del rectángulo?
function M.rect_blocked(x, z, w, d)
  if M.blocked_cells == nil then
    return false
  end
  for cx = x, x + w - 1 do
    for cz = z, z + d - 1 do
      if M.blocked_cells[cx .. "," .. cz] ~= nil then
        return true
      end
    end
  end
  return false
end

-- ¿La celda (x, z) tiene un obstáculo sin limpiar?
function M.is_blocked(x, z)
  return M.blocked_cells ~= nil and M.blocked_cells[x .. "," .. z] ~= nil
end
M.MAX_LEVELS = 5
-- Pulido 2C: hasta 3 sótanos (niveles -1, -2 y -3). house.levels[nivel - MIN_LEVEL + 1].
M.MIN_LEVEL = -3
M.LEVEL_COUNT = 8

-- La tabla de un nivel de la casa (nil si no existe).
function M.level_table(house, level)
  return house.levels[level - M.MIN_LEVEL + 1]
end
-- Hasta cuántas celdas sostiene un pilar al piso de arriba.
M.PILLAR_REACH = 2
-- Muebles en diagonal: los mismos números que HouseGrid (house_grid.gd).
M.DIAG_COS = 0.7071067811865476
M.DIAG_SCALE = 0.9
local DIAG_SAMPLES = { 0.2, 0.5, 0.8 }
local DIAG_SIGNS = { { 1, 1 }, { -1, 1 }, { -1, -1 }, { 1, -1 } }


-- --- Celdas y bordes (house_grid.gd) ---

local function num(value)
  if value == nil then
    return nil
  end
  return tonumber(value)
end

function M.cell_key(x, z)
  return x .. "," .. z
end

-- "x,z" → x, z (números) o nil.
function M.parse_cell(key)
  local x, z = string.match(key or "", "^(%-?%d+),(%-?%d+)$")
  return num(x), num(z)
end

function M.edge_key(x, z, horizontal)
  return (horizontal and "h:" or "v:") .. x .. "," .. z
end

-- "h:x,z" → x, z, true (horizontal) o nil.
function M.parse_edge(key)
  local kind, x, z = string.match(key or "", "^([hv]):(%-?%d+),(%-?%d+)$")
  if kind == nil then
    return nil
  end
  return num(x), num(z), kind == "h"
end

function M.is_cell_in_lot(x, z)
  return x >= 0 and z >= 0 and x < M.LOT_SIZE and z < M.LOT_SIZE
end

function M.is_edge_in_lot(key)
  local x, z, horizontal = M.parse_edge(key)
  if x == nil then
    return false
  end
  if horizontal then
    return x >= 0 and x < M.LOT_SIZE and z >= 0 and z <= M.LOT_SIZE
  end
  return x >= 0 and x <= M.LOT_SIZE and z >= 0 and z < M.LOT_SIZE
end

-- Las 4 paredes posibles alrededor de una celda.
function M.cell_edges(x, z)
  return { M.edge_key(x, z, true), M.edge_key(x, z + 1, true), M.edge_key(x, z, false), M.edge_key(x + 1, z, false) }
end

-- Las dos celdas que comparten un borde: {{x, z}, {x, z}}.
function M.edge_cells(key)
  local x, z, horizontal = M.parse_edge(key)
  if horizontal then
    return { { x, z - 1 }, { x, z } }
  end
  return { { x - 1, z }, { x, z } }
end

-- Tamaño de un objeto girado (rot 1 y 3 intercambian ancho y fondo).
function M.rotated_size(item, rot)
  local footprint = item.footprint or { 1, 1 }
  local width, depth = num(footprint[1]) or 1, num(footprint[2]) or 1
  if (rot or 0) % 2 == 1 then
    return depth, width
  end
  return width, depth
end

-- Celdas de un mueble en diagonal (HouseGrid.object_cells_full): las que
-- toca su caja girada (90 % de su tamaño), probando 9 puntos por celda.
function M.diag_cells(item, value)
  local footprint = item.footprint or { 1, 1 }
  local fw, fd = num(footprint[1]) or 1, num(footprint[2]) or 1
  local rot = (num(value.rot) or 0) % 4
  local width, depth = M.rotated_size(item, rot)
  local cx, cz = num(value.cell[1]) + width / 2, num(value.cell[2]) + depth / 2
  local hw, hd = fw * M.DIAG_SCALE / 2, fd * M.DIAG_SCALE / 2
  local c, s = DIAG_SIGNS[rot + 1][1] * M.DIAG_COS, DIAG_SIGNS[rot + 1][2] * M.DIAG_COS
  local reach = math.ceil(math.sqrt(hw * hw + hd * hd))
  local cells = {}
  for x = math.floor(cx) - reach, math.floor(cx) + reach do
    for z = math.floor(cz) - reach, math.floor(cz) + reach do
      local inside = false
      for _, ox in ipairs(DIAG_SAMPLES) do
        for _, oz in ipairs(DIAG_SAMPLES) do
          local dx, dz = x + ox - cx, z + oz - cz
          if math.abs(dx * c + dz * s) <= hw and math.abs(-dx * s + dz * c) <= hd then
            inside = true
          end
        end
      end
      if inside then
        table.insert(cells, { x, z })
      end
    end
  end
  return cells
end

-- Celdas que ocupa un objeto: lista de {x, z}.
function M.object_cells(item, value)
  if value.diag == true then
    return M.diag_cells(item, value)
  end
  local width, depth = M.rotated_size(item, value.rot)
  local ax, az = num(value.cell[1]), num(value.cell[2])
  local cells = {}
  for x = ax, ax + width - 1 do
    for z = az, az + depth - 1 do
      table.insert(cells, { x, z })
    end
  end
  return cells
end

-- Bordes que quedan DENTRO de un objeto (entre dos de sus celdas): no puede
-- tener una pared atravesada.
function M.object_inner_edges(item, value)
  local cells = M.object_cells(item, value)
  local set = {}
  for _, cell in ipairs(cells) do
    set[M.cell_key(cell[1], cell[2])] = true
  end
  local edges = {}
  for _, cell in ipairs(cells) do
    if set[M.cell_key(cell[1] + 1, cell[2])] then
      table.insert(edges, M.edge_key(cell[1] + 1, cell[2], false))
    end
    if set[M.cell_key(cell[1], cell[2] + 1)] then
      table.insert(edges, M.edge_key(cell[1], cell[2] + 1, true))
    end
  end
  return edges
end


-- --- Leer la casa ---

function M.get_piece(house, level, layer, key)
  local lvl = M.level_table(house, level)
  if lvl == nil or lvl[layer] == nil then
    return nil
  end
  return lvl[layer][key]
end

local function has_piece(house, level, layer, key)
  return M.get_piece(house, level, layer, key) ~= nil
end

local function object_covers(data, value, x, z)
  local item = data.items[value.item]
  if item == nil or type(value.cell) ~= "table" then
    return false
  end
  for _, cell in ipairs(M.object_cells(item, value)) do
    if cell[1] == x and cell[2] == z then
      return true
    end
  end
  return false
end

-- Objetos que ocupan una celda: lista de claves (en orden, para que sea
-- siempre igual).
function M.objects_at(data, house, level, x, z)
  local result = {}
  local lvl = M.level_table(house, level)
  if lvl == nil then
    return result
  end
  for key, value in pairs(lvl.objects) do
    if object_covers(data, value, x, z) then
      table.insert(result, key)
    end
  end
  table.sort(result)
  return result
end

local function kind_of(data, value)
  if value == nil then
    return nil
  end
  return (data.items[value.item] or {}).kind
end
M.kind_of = kind_of

-- ¿Hay un pilar de ese nivel a PILLAR_REACH celdas o menos de (x, z)?
function M.has_pillar_near(data, house, level, x, z)
  local lvl = M.level_table(house, level)
  if lvl == nil then
    return false
  end
  for _, value in pairs(lvl.objects) do
    if kind_of(data, value) == "pillar" and type(value.cell) == "table" then
      local px, pz = num(value.cell[1]), num(value.cell[2])
      if math.abs(px - x) <= M.PILLAR_REACH and math.abs(pz - z) <= M.PILLAR_REACH then
        return true
      end
    end
  end
  return false
end

local function roof_rect(value)
  local r = value.rect
  if type(r) ~= "table" then
    return nil
  end
  return num(r[1]), num(r[2]), num(r[3]), num(r[4])
end

local function rect_has(x, z, w, d, cx, cz)
  return cx >= x and cz >= z and cx < x + w and cz < z + d
end

-- ¿Todas esas celdas ({{x, z}, ...}) quedan adentro de un techo de ese nivel?
function M.is_under_roof(house, level, cells)
  local lvl = M.level_table(house, level)
  if level < 0 or lvl == nil then
    return false
  end
  for _, roof in pairs(lvl.roofs) do
    local x, z, w, d = roof_rect(roof)
    if x ~= nil then
      local all_inside = true
      for _, cell in ipairs(cells) do
        if not rect_has(x, z, w, d, cell[1], cell[2]) then
          all_inside = false
        end
      end
      if all_inside then
        return true
      end
    end
  end
  return false
end

-- Por qué no va un techo ahí (nil = sí va): pared o piso de arriba adentro.
function M.roof_blocker(house, level, x, z, w, d)
  local above = M.level_table(house, level + 1)
  if above == nil then
    return nil
  end
  for key in pairs(above.walls) do
    local cells = M.edge_cells(key)
    if rect_has(x, z, w, d, cells[1][1], cells[1][2]) and rect_has(x, z, w, d, cells[2][1], cells[2][2]) then
      return "Ahí pasa una pared del piso de arriba: atravesaría el techo."
    end
  end
  for key in pairs(above.floors) do
    local cx, cz = M.parse_cell(key)
    if cx ~= nil and rect_has(x, z, w, d, cx, cz) then
      return "Ahí arriba hay piso: el techo va encima de todo."
    end
  end
  return nil
end

function M.is_stairs_cell(data, house, level, x, z)
  for _, key in ipairs(M.objects_at(data, house, level, x, z)) do
    local item = data.items[M.get_piece(house, level, "objects", key).item] or {}
    if item.kind == "stairs" then
      return true
    end
  end
  return false
end


-- --- ¿Está apoyada? (HouseRules.is_supported) ---

local function is_object_supported(data, house, level, key, value)
  local item = data.items[value.item]
  if item == nil or type(value.cell) ~= "table" then
    return false
  end
  if item.kind == "stairs" and level >= M.MAX_LEVELS - 1 then
    return false
  end
  if value.diag == true and item.kind ~= "furniture" then
    return false
  end
  local on_ground = level == 0 and item.outdoor == true
  for _, cell in ipairs(M.object_cells(item, value)) do
    if on_ground then
      if not M.is_cell_in_lot(cell[1], cell[2]) or M.is_blocked(cell[1], cell[2]) then
        return false
      end
    elseif not has_piece(house, level, "floors", M.cell_key(cell[1], cell[2])) then
      return false
    end
    -- Ningún OTRO objeto en esa celda.
    for _, other in ipairs(M.objects_at(data, house, level, cell[1], cell[2])) do
      if other ~= key then
        return false
      end
    end
  end
  for _, edge in ipairs(M.object_inner_edges(item, value)) do
    if has_piece(house, level, "walls", edge) then
      return false
    end
  end
  return true
end

function M.is_supported(data, house, level, layer, key, value)
  if layer == "foundation" then
    local x, z = M.parse_cell(key)
    if level > 0 or level < M.MIN_LEVEL or x == nil or not M.is_cell_in_lot(x, z) or M.is_blocked(x, z) then
      return false
    end
    -- Pulido 2C: en un sótano, antes hay que excavar esa celda.
    return level == 0 or has_piece(house, level, "excavation", key)
  elseif layer == "excavation" then
    local x, z = M.parse_cell(key)
    if level >= 0 or level < M.MIN_LEVEL or x == nil or not M.is_cell_in_lot(x, z) or M.is_blocked(x, z) then
      return false
    end
    return level == -1 or has_piece(house, level + 1, "excavation", key)
  elseif layer == "floors" then
    local x, z = M.parse_cell(key)
    if x == nil or not M.is_cell_in_lot(x, z) or M.is_blocked(x, z) then
      return false
    end
    if level < 0 then
      return has_piece(house, level, "foundation", key)
    end
    if level == 0 then
      return has_piece(house, 0, "foundation", key) and not M.is_stairs_cell(data, house, -1, x, z)
    end
    if M.is_stairs_cell(data, house, level - 1, x, z) or M.is_under_roof(house, level - 1, { { x, z } }) then
      return false
    end
    if has_piece(house, level - 1, "floors", key) then
      return true
    end
    -- También sirve una pared de abajo en cualquiera de sus 4 lados.
    for _, edge in ipairs(M.cell_edges(x, z)) do
      if has_piece(house, level - 1, "walls", edge) then
        return true
      end
    end
    return M.has_pillar_near(data, house, level - 1, x, z)
  elseif layer == "walls" then
    if not M.is_edge_in_lot(key) then
      return false
    end
    if level > 0 and M.is_under_roof(house, level - 1, M.edge_cells(key)) then
      return false
    end
    local support_layer = level <= 0 and "foundation" or "floors"
    for _, cell in ipairs(M.edge_cells(key)) do
      if has_piece(house, level, support_layer, M.cell_key(cell[1], cell[2])) then
        return true
      end
    end
    return level > 0 and has_piece(house, level - 1, "walls", key)
  elseif layer == "objects" then
    return is_object_supported(data, house, level, key, value)
  elseif layer == "roofs" then
    local r = value.rect
    if type(r) ~= "table" then
      return false
    end
    local x, z, w, d = num(r[1]), num(r[2]), num(r[3]), num(r[4])
    return level >= 0 and x ~= nil and z ~= nil and w ~= nil and d ~= nil and x >= 0 and z >= 0 and w >= 1 and d >= 1
      and x + w <= M.LOT_SIZE and z + d <= M.LOT_SIZE and M.roof_blocker(house, level, x, z, w, d) == nil
      and not M.rect_blocked(x, z, w, d)
  end
  return false
end


-- --- Qué se apoya en una pieza (HouseRules.dependents) ---

-- Lista de {nivel, capa, clave}. Además de lo que dice el teléfono, una
-- escalera "sostiene" (en realidad, prohíbe) el piso que tenga encima.
function M.dependents(data, house, level, layer, key)
  local result = {}
  local function add(l, lay, k)
    table.insert(result, { l, lay, k })
  end
  if layer == "foundation" then
    local x, z = M.parse_cell(key)
    add(level, "floors", key)
    for _, edge in ipairs(M.cell_edges(x, z)) do
      add(level, "walls", edge)
    end
    for _, object_key in ipairs(M.objects_at(data, house, level, x, z)) do
      add(level, "objects", object_key)
    end
  elseif layer == "excavation" then
    local x, z = M.parse_cell(key)
    add(level, "foundation", key)
    add(level, "floors", key)
    for _, edge in ipairs(M.cell_edges(x, z)) do
      add(level, "walls", edge)
    end
    if level > M.MIN_LEVEL then
      add(level - 1, "excavation", key)
    end
  elseif layer == "floors" then
    local x, z = M.parse_cell(key)
    for _, object_key in ipairs(M.objects_at(data, house, level, x, z)) do
      add(level, "objects", object_key)
    end
    add(level + 1, "floors", key)
    for _, edge in ipairs(M.cell_edges(x, z)) do
      add(level, "walls", edge)
    end
  elseif layer == "walls" then
    add(level + 1, "walls", key)
    for _, cell in ipairs(M.edge_cells(key)) do
      add(level + 1, "floors", M.cell_key(cell[1], cell[2]))
    end
  elseif layer == "objects" then
    local value = M.get_piece(house, level, layer, key)
    local item = value and data.items[value.item]
    if item ~= nil and item.kind == "stairs" and type(value.cell) == "table" then
      for _, cell in ipairs(M.object_cells(item, value)) do
        add(level + 1, "floors", M.cell_key(cell[1], cell[2]))
      end
    elseif item ~= nil and item.kind == "pillar" and type(value.cell) == "table" then
      local px, pz = num(value.cell[1]), num(value.cell[2])
      for x = px - M.PILLAR_REACH, px + M.PILLAR_REACH do
        for z = pz - M.PILLAR_REACH, pz + M.PILLAR_REACH do
          add(level + 1, "floors", M.cell_key(x, z))
        end
      end
    end
  end
  return result
end


-- --- Revisar un cambio entero ---

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

-- Revisa que, después de aplicar `writes` ({level, layer, key, value};
-- value = nil es quitar), cada pieza que se pone o cambia esté apoyada y
-- que nada de lo que se apoyaba en lo tocado quede en el aire.
-- No cambia `house`. Devuelve true, o false y la pieza que falla
-- ({level, layer, key}).
function M.check_batch(data, house, writes)
  local sim = copy(house)
  for _, w in ipairs(writes) do
    local lvl = M.level_table(sim, w.level)
    if lvl == nil or lvl[w.layer] == nil then
      return false, { w.level, w.layer, w.key }
    end
    lvl[w.layer][w.key] = copy(w.value)
  end
  local seen, to_check = {}, {}
  local function add(l, layer, key)
    local id = l .. "|" .. layer .. "|" .. key
    if not seen[id] then
      seen[id] = true
      table.insert(to_check, { l, layer, key })
    end
  end
  for _, w in ipairs(writes) do
    add(w.level, w.layer, w.key)
    for _, dep in ipairs(M.dependents(data, house, w.level, w.layer, w.key)) do
      add(dep[1], dep[2], dep[3])
    end
    for _, dep in ipairs(M.dependents(data, sim, w.level, w.layer, w.key)) do
      add(dep[1], dep[2], dep[3])
    end
  end
  for _, piece in ipairs(to_check) do
    local value = M.get_piece(sim, piece[1], piece[2], piece[3])
    if value ~= nil and not M.is_supported(data, sim, piece[1], piece[2], piece[3], value) then
      return false, piece
    end
  end
  return true
end


-- --- Permisos de la casa compartida (Fase 5) ---

-- Campos que NO cambian qué es la pieza (pintar, unir/separar ventanas).
local COSMETIC_FIELDS = { color = true, color_a = true, color_b = true, separate = true, join_end = true,
  ready_at = true }

-- ¿`old` y `new` son la misma pieza salvo color o "separada"?
local function only_cosmetic(old, new)
  for k, v in pairs(new) do
    if not COSMETIC_FIELDS[k] and old[k] ~= v then
      if type(v) ~= "table" or type(old[k]) ~= "table" then
        return false
      end
      -- Listas (celda, rectángulo): se comparan número por número.
      for i, n in ipairs(v) do
        if old[k][i] ~= n then
          return false
        end
      end
      if #old[k] ~= #v then
        return false
      end
    end
  end
  for k in pairs(old) do
    if not COSMETIC_FIELDS[k] and new[k] == nil then
      return false
    end
  end
  return true
end

-- Qué tipo de cambio es una escritura, para la casa compartida:
--   "minor"      cambio menor: mover, girar o pintar un mueble, pintar
--                paredes y pisos, unir/separar ventanas, poner un mueble nuevo.
--   "structural" todo lo demás: cimientos, pisos, paredes, puertas,
--                ventanas, techos, escaleras, y QUITAR (vender) cualquier cosa.
function M.write_kind(data, house, w)
  local old = M.get_piece(house, w.level, w.layer, w.key)
  local new = w.value
  if new == nil then
    return old == nil and "minor" or "structural"
  end
  if old ~= nil and old.item == new.item and only_cosmetic(old, new) then
    return "minor"
  end
  if w.layer == "objects" then
    local item = data.items[new.item] or {}
    if item.kind == "furniture" and (old == nil or old.item == new.item) then
      return "minor"
    end
  end
  return "structural"
end

-- Un cambio entero es menor solo si TODAS sus escrituras lo son.
function M.change_kind(data, house, writes)
  for _, w in ipairs(writes) do
    if M.write_kind(data, house, w) ~= "minor" then
      return "structural"
    end
  end
  return "minor"
end


-- --- Descripción para el historial ("puso: Cama, Silla x2") ---

-- Verbo de una escritura: "puso", "quitó", "movió", "pintó", "cambió".
function M.write_verb(house, w)
  local old = M.get_piece(house, w.level, w.layer, w.key)
  local new = w.value
  if new == nil then
    return "quitó"
  elseif old == nil then
    return "puso"
  elseif old.item ~= new.item or old.opening ~= new.opening then
    return "cambió"
  elseif old.color ~= new.color then
    return "pintó"
  elseif w.layer == "objects" then
    return "movió"
  end
  return "cambió"
end

-- El mismo verbo para un pedido ("pide permiso para: poner Pared x2").
local INFINITIVE = { ["puso"] = "poner", ["quitó"] = "quitar", ["movió"] = "mover", ["pintó"] = "pintar",
  ["cambió"] = "cambiar" }

-- Texto corto de un cambio (con la casa ANTES de aplicarlo): "puso: Cama,
-- Silla x2". Con `infinitive`, para un pedido: "poner Cama, Silla x2".
function M.describe(data, house, writes, infinitive)
  local order, groups = {}, {}
  for _, w in ipairs(writes) do
    local verb = M.write_verb(house, w)
    local value = w.value or M.get_piece(house, w.level, w.layer, w.key) or {}
    local item_id = value.item
    -- Puertas y ventanas son parte de la pared: se nombra la abertura.
    local old = M.get_piece(house, w.level, w.layer, w.key) or {}
    if verb == "cambió" and w.value ~= nil and old.opening ~= w.value.opening then
      if w.value.opening ~= nil then
        verb, item_id = "puso", w.value.opening
      else
        verb, item_id = "quitó", old.opening
      end
    end
    local name = (data.items[item_id] or {}).name or "pieza"
    if groups[verb] == nil then
      groups[verb] = { names = {}, counts = {} }
      table.insert(order, verb)
    end
    local g = groups[verb]
    if g.counts[name] == nil then
      g.counts[name] = 0
      table.insert(g.names, name)
    end
    g.counts[name] = g.counts[name] + 1
  end
  local parts = {}
  for _, verb in ipairs(order) do
    local g = groups[verb]
    local names = {}
    for i, name in ipairs(g.names) do
      if i > 3 then
        table.insert(names, "…")
        break
      end
      local n = g.counts[name]
      table.insert(names, n > 1 and (name .. " x" .. n) or name)
    end
    if infinitive then
      table.insert(parts, INFINITIVE[verb] .. " " .. table.concat(names, ", "))
    else
      table.insert(parts, verb .. ": " .. table.concat(names, ", "))
    end
  end
  return table.concat(parts, "; ")
end

return M
