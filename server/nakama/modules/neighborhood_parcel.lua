--[[
Parcela y obstáculos (Pulido 2C). Sin Nakama: se prueba sola con lua5.1.
Copia EXACTA de scripts/house/parcel_rules.gd (el teléfono genera los mismos
obstáculos desde la misma semilla; si cambiás algo acá, cambialo allá también).

La parcela es de LOT x LOT celdas; la casa queda centrada y CERCA de la calle
(home_zone + home_street_gap, Pulido 3A). Al principio solo se usa la start_zone
(el doble de la parcela original); el resto se abre por nivel (unlocks).
Lo demás se llena de obstáculos (árboles, rocas, un laguito,
tocones y maleza) que bloquean construir. Cada obstáculo tiene un id estable
("t:x,z"); el servidor solo guarda cuáles se limpiaron.
]]

local parcel = {}

-- Generador de números al azar de Park–Miller: la cuenta cabe justa en un
-- número entero de Lua (y de GDScript), así los dos dan lo mismo.
local MODULUS = 2147483647
local FACTOR = 48271

function parcel.next_random(seed)
  return (seed * FACTOR) % MODULUS
end

-- Una semilla válida (1 a MODULUS-1) a partir de un texto (el id del dueño).
function parcel.seed_from_text(text)
  local h = 5381
  for i = 1, #text do
    h = (h * 33 + string.byte(text, i)) % MODULUS
  end
  if h <= 0 then
    h = 1
  end
  return h
end

local function key(x, z)
  return x .. "," .. z
end

-- Esquina de la casa (la "zona de la casa"): centrada y a `home_street_gap`
-- celdas de la calle. Con una parcela del tamaño de la casa es (0, 0).
function parcel.home_origin(cfg)
  return math.floor((cfg.lot - cfg.home_zone) / 2), math.max(0, cfg.lot - cfg.home_zone - (cfg.home_street_gap or 0))
end

-- Zona usable con el nivel del jugador: lista de { x, z, w, d }.
function parcel.zone_rects(cfg, player_level)
  local lot = cfg.lot
  local start = cfg.start_zone or lot
  if lot <= start then
    return { { lot = true, x = 0, z = 0, w = lot, d = lot } }
  end
  local rects = { { x = math.floor((lot - start) / 2), z = lot - start, w = start, d = start } }
  for _, unlock in ipairs(cfg.unlocks or {}) do
    if unlock.level <= player_level then
      table.insert(rects, { x = unlock.rect[1], z = unlock.rect[2], w = unlock.rect[3], d = unlock.rect[4] })
    end
  end
  return rects
end

function parcel.in_zone(rects, x, z, w, d)
  for cx = x, x + (w or 1) - 1 do
    for cz = z, z + (d or 1) - 1 do
      local inside = false
      for _, r in ipairs(rects) do
        if cx >= r.x and cx < r.x + r.w and cz >= r.z and cz < r.z + r.d then
          inside = true
          break
        end
      end
      if not inside then
        return false
      end
    end
  end
  return true
end

-- Celdas fuera de la zona usable: "x,z" → "zone".
function parcel.locked_cells(cfg, player_level)
  local rects = parcel.zone_rects(cfg, player_level)
  local cells = {}
  if rects[1].lot then
    return cells
  end
  for z = 0, cfg.lot - 1 do
    for x = 0, cfg.lot - 1 do
      if not parcel.in_zone(rects, x, z, 1, 1) then
        cells[key(x, z)] = "zone"
      end
    end
  end
  return cells
end

-- Genera todos los obstáculos: lista de {id, kind, x, z, w, d} en orden fijo.
-- (Las celdas ocupadas se anotan con un número, z * lot + x: así es más
-- rápido que con texto, y el resultado es idéntico al del teléfono.)
function parcel.generate(cfg, seed)
  local lot = cfg.lot
  -- Zona siempre libre: la casa, su margen y toda la franja hasta la calle.
  local home_x, home_z = parcel.home_origin(cfg)
  local margin = cfg.clear_margin or 0
  local free_x0, free_x1 = home_x - margin, home_x + cfg.home_zone - 1 + margin
  local free_z0 = home_z - margin
  local taken = {}
  local list = {}
  local state = seed

  local function fits(x, z, w, d)
    if x < 0 or z < 0 or x + w > lot or z + d > lot then
      return false
    end
    for cx = x, x + w - 1 do
      for cz = z, z + d - 1 do
        if taken[cz * lot + cx] or (cx >= free_x0 and cx <= free_x1 and cz >= free_z0) then
          return false
        end
      end
    end
    return true
  end

  local function place(kind, def, x, z)
    local w, d = def.size[1], def.size[2]
    for cx = x, x + w - 1 do
      for cz = z, z + d - 1 do
        taken[cz * lot + cx] = true
      end
    end
    table.insert(list, { id = def.letter .. ":" .. x .. "," .. z, kind = kind, x = x, z = z, w = w, d = d })
  end

  for _, kind in ipairs(cfg.order) do
    local def = cfg.obstacles[kind]
    local w, d = def.size[1], def.size[2]
    if def.count ~= nil then
      -- Cantidad fija (rocas, laguitos): se prueban lugares al azar.
      for _ = 1, def.count do
        for _ = 1, 30 do
          state = (state * FACTOR) % MODULUS
          local x = math.floor(state / MODULUS * (lot - w + 1))
          state = (state * FACTOR) % MODULUS
          local z = math.floor(state / MODULUS * (lot - d + 1))
          if fits(x, z, w, d) then
            place(kind, def, x, z)
            break
          end
        end
      end
    else
      -- Por densidad: se recorren las celdas en orden y cada una "tira un dado".
      local density = def.density
      for z = 0, lot - 1 do
        for x = 0, lot - 1 do
          state = (state * FACTOR) % MODULUS
          if state / MODULUS < density and fits(x, z, w, d) then
            place(kind, def, x, z)
          end
        end
      end
    end
  end
  return list
end

-- Celdas ocupadas por la lista de obstáculos que NO se limpiaron.
-- Devuelve (celdas "x,z" → id, cantidad).
function parcel.blocked_cells(obstacles, cleared, locked)
  local cells, count = {}, 0
  for _, o in ipairs(obstacles) do
    if not (cleared and cleared[o.id]) then
      count = count + 1
      for cx = o.x, o.x + o.w - 1 do
        for cz = o.z, o.z + o.d - 1 do
          cells[key(cx, cz)] = o.id
        end
      end
    end
  end
  -- La zona cerrada manda: ahí tampoco se llama a ningún servicio.
  for k, v in pairs(locked or {}) do
    cells[k] = v
  end
  return cells, count
end

-- Busca un obstáculo por id.
function parcel.find(obstacles, id)
  for _, o in ipairs(obstacles) do
    if o.id == id then
      return o
    end
  end
  return nil
end

-- Cuánto cuesta limpiar el obstáculo `kind` si ya se limpiaron `cleared_count`.
function parcel.cost(cfg, kind, cleared_count)
  local def = cfg.obstacles[kind]
  local multiplier = math.min(cfg.max_multiplier, 1 + cfg.growth * cleared_count)
  return math.floor(def.base_cost * multiplier + 0.5)
end

-- ¿Hay camino libre desde la calle (el borde de adelante, z = lot-1) hasta
-- pegado al obstáculo? Persona: 1 celda. Vehículo: ocupa un bloque de 2x2.
--   `blocked`: celdas ocupadas ("x,z" → algo) sin contar el obstáculo objetivo.
--   `house_cells`: celdas con la casa encima ("x,z" → true): no se cruzan.
-- Devuelve true, o false y el motivo.
function parcel.can_reach(cfg, blocked, house_cells, target, vehicle)
  local lot = cfg.lot
  local size = vehicle and 2 or 1
  local function free(x, z)
    if x < 0 or z < 0 or x + size > lot or z + size > lot then
      return false
    end
    for cx = x, x + size - 1 do
      for cz = z, z + size - 1 do
        local k = key(cx, cz)
        if blocked[k] or house_cells[k] then
          return false
        end
      end
    end
    return true
  end
  -- Una posición sirve de meta si el bloque toca (8 vecinos) al objetivo.
  local function touches(x, z)
    return x + size - 1 >= target.x - 1 and x <= target.x + target.w and z + size - 1 >= target.z - 1 and z <= target.z + target.d
  end
  local queue, head, seen = {}, 1, {}
  for x = 0, lot - size do
    local z = lot - size
    if free(x, z) then
      table.insert(queue, { x, z })
      seen[key(x, z)] = true
    end
  end
  if #queue == 0 then
    return false, vehicle and "El vehículo no puede entrar desde la calle." or "No hay paso desde la calle."
  end
  while head <= #queue do
    local cur = queue[head]
    head = head + 1
    if touches(cur[1], cur[2]) then
      return true
    end
    for _, step in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
      local nx, nz = cur[1] + step[1], cur[2] + step[2]
      local k = key(nx, nz)
      if not seen[k] and free(nx, nz) then
        seen[k] = true
        table.insert(queue, { nx, nz })
      end
    end
  end
  if vehicle then
    return false, "No hay camino libre para el vehículo hasta ahí."
  end
  return false, "No hay paso hasta ahí."
end

return parcel
