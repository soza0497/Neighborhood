--[[
Metas del barrio por participación (Fase 8D). Sin Nakama: se prueba sola con lua5.1
(server/tests/test_goals.lua). La copia en el teléfono (scripts/neighborhood/
neighborhood_goal.gd, para partidas sin cuenta) usa EXACTAMENTE los mismos números:
si cambiás algo acá, cambialo allá también (y los números de las dos pruebas).

Principios (VISION.md):
  - Se mide PARTICIPACIÓN (cuántas plantas hay en tu casa), nunca dinero generado.
  - Nada obliga a conectarse ni castiga: no hay fecha límite, el progreso nunca baja.
  - El servidor calcula el aporte del jugador a partir de lo que HAY en su casa
    (el teléfono no puede inventarlo) y lo limita por día.
  - Los vecinos aún no son jugadores: aportan un valor simulado y determinista que
    solo depende de los días desde que el jugador empezó (y de la meta).

La meta sale de data/neighborhood.json, sección "goal".
]]

local goals = {}

local SECONDS_PER_DAY = 86400

local function num(value, default)
  if type(value) == "number" and value == value then
    return value
  end
  return default
end

-- La configuración de la meta, con valores seguros si el archivo viene mal.
function goals.new_config(raw)
  local g = (type(raw) == "table" and raw.goal) or {}
  local neighbors = g.neighbors or {}
  local reward = g.reward or {}
  local categories = {}
  for _, category in ipairs(g.categories or {}) do
    categories[category] = true
  end
  local per_min = math.max(0, math.floor(num(neighbors.per_day_min, 1)))
  return {
    id = tostring(g.id or "plants_together"),
    name = tostring(g.name or "Meta del barrio"),
    target = math.max(1, math.floor(num(g.target, 50))),
    categories = categories,
    daily_cap = math.max(0, math.floor(num(g.daily_cap, 10))),
    neighbors_share = math.min(1, math.max(0, num(neighbors.share, 0.6))),
    neighbors_min = per_min,
    neighbors_max = math.max(per_min, math.floor(num(neighbors.per_day_max, 3))),
    neighbors_salt = math.floor(num(neighbors.salt, 5)),
    reward_money = math.max(0, math.floor(num(reward.money, 0))),
    reward_xp = math.max(0, math.floor(num(reward.xp, 0))),
  }
end

-- Lo que se guarda de cada jugador (game/goal). Si es de otra meta, empieza de cero.
function goals.normalize_record(raw, cfg)
  local r = type(raw) == "table" and raw or {}
  if r.goal ~= cfg.id then
    r = {}
  end
  return {
    goal = cfg.id,
    started_day = math.floor(num(r.started_day, -1)),
    mine = math.max(0, math.floor(num(r.mine, 0))),
    credited = math.max(0, math.floor(num(r.credited, 0))),
    day = math.floor(num(r.day, -1)),
    today = math.max(0, math.floor(num(r.today, 0))),
    claimed = r.claimed == true,
  }
end

function goals.day_of(now)
  return math.floor(now / SECONDS_PER_DAY)
end

-- Cuántas piezas cuentan HOY en la casa: las ya terminadas (no en obra) de una
-- categoría de la meta. `items` = catálogo por id (data.items de las reglas).
function goals.count_items(cfg, house, items, now)
  local total = 0
  for _, level in pairs(house.levels or {}) do
    for _, value in pairs(level.objects or {}) do
      local item = items[value.item]
      if item and cfg.categories[item.category] and (num(value.ready_at, 0) <= now) then
        total = total + 1
      end
    end
  end
  return total
end

-- Lo que aportan los vecinos simulados `days` días después de que el jugador
-- empezó: de 1 a 3 por día (según el día), sin pasar de la parte que les toca.
function goals.neighbors_progress(cfg, days)
  local cap = math.floor(cfg.target * cfg.neighbors_share)
  local span = cfg.neighbors_max - cfg.neighbors_min + 1
  local total = 0
  for day = 1, math.max(0, days) do
    total = total + cfg.neighbors_min + ((day * 7 + cfg.neighbors_salt) % span)
    if total >= cap then
      return cap
    end
  end
  return math.min(total, cap)
end

-- Pone al día el registro del jugador. `counted` = cuántas piezas que cuentan hay
-- ahora en su casa. Devuelve (cuánto se acreditó, ¿cambió algo que haya que guardar?).
-- Lo acreditado nunca baja: sacar y volver a poner una planta no suma dos veces.
function goals.update(cfg, record, now, counted)
  local day = goals.day_of(now)
  local dirty = false
  if record.started_day < 0 then
    record.started_day = day
    dirty = true
  end
  if record.day ~= day then
    record.day = day
    record.today = 0
    dirty = true
  end
  local pending = math.max(0, math.floor(counted) - record.credited)
  local room = math.max(0, cfg.daily_cap - record.today)
  local gained = math.min(pending, room)
  if gained > 0 then
    record.credited = record.credited + gained
    record.mine = record.mine + gained
    record.today = record.today + gained
    dirty = true
  end
  return gained, dirty
end

-- Lo que el teléfono muestra.
function goals.summary(cfg, record, now)
  local day = goals.day_of(now)
  local days = record.started_day >= 0 and math.max(0, day - record.started_day) or 0
  local neighbors = goals.neighbors_progress(cfg, days)
  local total = neighbors + record.mine
  return {
    id = cfg.id,
    name = cfg.name,
    target = cfg.target,
    mine = record.mine,
    today = record.day == day and record.today or 0,
    daily_cap = cfg.daily_cap,
    neighbors = neighbors,
    total = total,
    completed = total >= cfg.target,
    claimed = record.claimed,
    reward = { money = cfg.reward_money, xp = cfg.reward_xp },
  }
end

-- Retirar la recompensa (una sola vez, solo con la meta cumplida y con aporte
-- propio: quien no puso nada no cobra). Devuelve (recompensa) o (nil, motivo).
function goals.claim(cfg, record, now)
  local s = goals.summary(cfg, record, now)
  if not s.completed then
    return nil, "La meta todavía no se cumplió."
  end
  if record.claimed then
    return nil, "Ya retiraste la recompensa de esta meta."
  end
  if record.mine <= 0 then
    return nil, "Para retirar la recompensa hay que haber aportado algo."
  end
  record.claimed = true
  return { money = cfg.reward_money, xp = cfg.reward_xp }
end

return goals
