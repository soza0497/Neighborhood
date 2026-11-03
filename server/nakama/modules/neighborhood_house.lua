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
  - Piso arriba: sobre otro piso o junto a una pared de abajo (balcón), y no
    encima de una escalera.
  - Pared en planta baja: junto a cimientos. Arriba: junto a un piso de ese
    nivel, o encima de otra pared.
  - Objeto: todas sus celdas con piso, sin otro objeto y sin paredes
    atravesadas. Las escaleras no van en el último nivel.
  - Techo: dentro de la parcela.

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

M.LOT_SIZE = 32
M.MAX_LEVELS = 5


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

-- Celdas que ocupa un objeto: lista de {x, z}.
function M.object_cells(item, value)
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

-- Bordes que quedan DENTRO de un objeto (no puede tener una pared atravesada).
function M.object_inner_edges(item, value)
  local width, depth = M.rotated_size(item, value.rot)
  local ax, az = num(value.cell[1]), num(value.cell[2])
  local edges = {}
  for x = ax, ax + width - 1 do
    for z = az + 1, az + depth - 1 do
      table.insert(edges, M.edge_key(x, z, true))
    end
  end
  for z = az, az + depth - 1 do
    for x = ax + 1, ax + width - 1 do
      table.insert(edges, M.edge_key(x, z, false))
    end
  end
  return edges
end


-- --- Leer la casa ---

function M.get_piece(house, level, layer, key)
  local lvl = house.levels[level + 1]
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
  local lvl = house.levels[level + 1]
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
  for _, cell in ipairs(M.object_cells(item, value)) do
    if not has_piece(house, level, "floors", M.cell_key(cell[1], cell[2])) then
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
    return level == 0 and x ~= nil and M.is_cell_in_lot(x, z)
  elseif layer == "floors" then
    local x, z = M.parse_cell(key)
    if x == nil or not M.is_cell_in_lot(x, z) then
      return false
    end
    if level == 0 then
      return has_piece(house, 0, "foundation", key)
    end
    if M.is_stairs_cell(data, house, level - 1, x, z) then
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
    return false
  elseif layer == "walls" then
    if not M.is_edge_in_lot(key) then
      return false
    end
    local support_layer = level == 0 and "foundation" or "floors"
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
    return x ~= nil and z ~= nil and w ~= nil and d ~= nil and x >= 0 and z >= 0 and w >= 1 and d >= 1
      and x + w <= M.LOT_SIZE and z + d <= M.LOT_SIZE
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
    add(0, "floors", key)
    for _, edge in ipairs(M.cell_edges(x, z)) do
      add(0, "walls", edge)
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
    local lvl = sim.levels[w.level + 1]
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
local COSMETIC_FIELDS = { color = true, separate = true, ready_at = true }

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
