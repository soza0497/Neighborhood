class_name ParcelRules
## Parcela y obstáculos (Pulido 2C): reglas sin pantalla.
##
## COPIA EXACTA de server/nakama/modules/neighborhood_parcel.lua: el teléfono y
## el servidor generan los MISMOS obstáculos desde la misma semilla (y revisan
## el mismo camino). Si cambiás algo acá, cambialo allá y en sus pruebas.
##
## La parcela es de LOT x LOT celdas; la casa queda centrada y CERCA de la calle
## (home_zone + home_street_gap, Pulido 3A). Al principio solo se usa la
## start_zone (el doble de la parcela original); el resto se abre por nivel
## (unlocks) y mientras tanto es "zona cerrada". Lo demás se llena de obstáculos (árboles, rocas, un laguito,
## tocones y maleza) que bloquean construir hasta que se limpian con un
## servicio. Cada obstáculo tiene un id estable ("t:x,z").

const CONFIG_PATH := "res://data/parcel.json"
## Generador de Park–Miller: la cuenta cabe justa en un entero (de Lua y de
## GDScript), así los dos dan lo mismo.
const MODULUS := 2147483647
const FACTOR := 48271

static var _config: Dictionary = {}


## data/parcel.json (se lee una vez). El tamaño de la parcela es el de
## HouseGrid.LOT_SIZE (si es de 32, toda la parcela es "la zona de la casa" y no
## hay obstáculos: así las pruebas viejas siguen igual).
static func config() -> Dictionary:
	if _config.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
		_config = parsed if parsed is Dictionary else {}
	var copy := _config.duplicate()
	copy["lot"] = HouseGrid.LOT_SIZE.x
	return copy


## Esquina de la casa (la "zona de la casa") dentro de la parcela: centrada de
## izquierda a derecha y a `home_street_gap` celdas de la calle (Pulido 3A).
## Si la parcela es del tamaño de la casa (las pruebas viejas) es (0, 0).
static func home_origin(cfg: Dictionary) -> Vector2i:
	var lot := int(cfg["lot"])
	var home := int(cfg["home_zone"])
	return Vector2i((lot - home) / 2, maxi(0, lot - home - int(cfg.get("home_street_gap", 0))))


## Zona que el jugador puede usar con `player_level`: lista de [x, z, ancho, fondo].
## Empieza con la start_zone (pegada a la calle, centrada) y suma los `unlocks`
## cuyo nivel ya se alcanzó. Con una parcela chica (pruebas) es toda.
static func zone_rects(cfg: Dictionary, player_level: int) -> Array:
	var lot := int(cfg["lot"])
	var start := int(cfg.get("start_zone", lot))
	if lot <= start:
		return [[0, 0, lot, lot]]
	var rects: Array = [[(lot - start) / 2, lot - start, start, start]]
	for unlock in cfg.get("unlocks", []):
		if int(unlock["level"]) <= player_level:
			var r: Array = unlock["rect"]
			rects.append([int(r[0]), int(r[1]), int(r[2]), int(r[3])])
	return rects


## Pulido 6A (5): imagen de L8 (1 píxel por celda del lote) con blanco en las celdas de la
## parcela usable y negro afuera. El shader de la cuadrícula la usa para no dibujar fuera de la valla.
static func zone_mask_image(rects: Array, lot: int) -> Image:
	var image := Image.create(lot, lot, false, Image.FORMAT_L8)
	image.fill(Color.BLACK)
	for r in rects:
		var x0: int = clampi(int(r[0]), 0, lot)
		var z0: int = clampi(int(r[1]), 0, lot)
		var x1: int = clampi(int(r[0]) + int(r[2]), 0, lot)
		var z1: int = clampi(int(r[1]) + int(r[3]), 0, lot)
		if x1 > x0 and z1 > z0:
			image.fill_rect(Rect2i(x0, z0, x1 - x0, z1 - z0), Color.WHITE)
	return image


static func in_zone(rects: Array, x: int, z: int, w := 1, d := 1) -> bool:
	for cx in range(x, x + w):
		for cz in range(z, z + d):
			var inside := false
			for r in rects:
				if cx >= r[0] and cx < r[0] + r[2] and cz >= r[1] and cz < r[1] + r[3]:
					inside = true
					break
			if not inside:
				return false
	return true


## Celdas fuera de la zona usable: "x,z" → "zone" (se ven, pero no se pisan ni se construyen).
static func locked_cells(cfg: Dictionary, player_level: int) -> Dictionary:
	var lot := int(cfg["lot"])
	var rects := zone_rects(cfg, player_level)
	var cells := {}
	if rects.size() == 1 and rects[0][2] >= lot and rects[0][3] >= lot:
		return cells
	for z in lot:
		for x in lot:
			if not in_zone(rects, x, z):
				cells[_key(x, z)] = "zone"
	return cells


static func next_random(seed: int) -> int:
	return (seed * FACTOR) % MODULUS


## Una semilla válida (1 a MODULUS-1) a partir de un texto (el id del dueño).
static func seed_from_text(text: String) -> int:
	var h := 5381
	for byte in text.to_utf8_buffer():
		h = (h * 33 + byte) % MODULUS
	if h <= 0:
		h = 1
	return h


## Genera todos los obstáculos: lista de {id, kind, x, z, w, d} en orden fijo.
static func generate(cfg: Dictionary, seed: int) -> Array:
	var lot := int(cfg["lot"])
	# Zona siempre libre: la casa, su margen y toda la franja hasta la calle.
	var home := home_origin(cfg)
	var margin := int(cfg.get("clear_margin", 0))
	var free := Rect2i(home.x - margin, home.y - margin, int(cfg["home_zone"]) + 2 * margin, lot - home.y + margin)
	var taken := {}
	var list: Array = []
	var state := seed
	var obstacles: Dictionary = cfg["obstacles"]

	for kind in cfg["order"]:
		var def: Dictionary = obstacles[kind]
		var w := int(def["size"][0])
		var d := int(def["size"][1])
		if def.has("count"):
			# Cantidad fija (rocas, laguitos): se prueban lugares al azar.
			for n in int(def["count"]):
				for attempt in 30:
					state = next_random(state)
					var x := int(floor(float(state) / MODULUS * (lot - w + 1)))
					state = next_random(state)
					var z := int(floor(float(state) / MODULUS * (lot - d + 1)))
					if _fits(taken, lot, free, x, z, w, d):
						_place(taken, list, kind, def, x, z)
						break
		else:
			# Por densidad: se recorren las celdas en orden y cada una "tira un dado".
			var density := float(def["density"])
			for z in lot:
				for x in lot:
					state = next_random(state)
					var roll := float(state) / MODULUS
					if roll < density and _fits(taken, lot, free, x, z, w, d):
						_place(taken, list, kind, def, x, z)
	return list


static func _fits(taken: Dictionary, lot: int, free: Rect2i, x: int, z: int, w: int, d: int) -> bool:
	if x < 0 or z < 0 or x + w > lot or z + d > lot:
		return false
	for cx in range(x, x + w):
		for cz in range(z, z + d):
			if taken.has(_key(cx, cz)) or free.has_point(Vector2i(cx, cz)):
				return false
	return true


static func _place(taken: Dictionary, list: Array, kind: String, def: Dictionary, x: int, z: int) -> void:
	var w := int(def["size"][0])
	var d := int(def["size"][1])
	for cx in range(x, x + w):
		for cz in range(z, z + d):
			taken[_key(cx, cz)] = true
	list.append({"id": "%s:%d,%d" % [def["letter"], x, z], "kind": kind, "x": x, "z": z, "w": w, "d": d})


static func _key(x: int, z: int) -> String:
	return "%d,%d" % [x, z]


## Celdas ocupadas por los obstáculos que NO se limpiaron: "x,z" → id (y las de
## la zona cerrada, `locked`: "x,z" → "zone").
static func blocked_cells(obstacles: Array, cleared: Dictionary, locked := {}) -> Dictionary:
	var cells := {}
	for o in obstacles:
		if cleared.has(o["id"]):
			continue
		for cx in range(o["x"], o["x"] + o["w"]):
			for cz in range(o["z"], o["z"] + o["d"]):
				cells[_key(cx, cz)] = o["id"]
	# La zona cerrada manda: ahí tampoco se llama a ningún servicio.
	cells.merge(locked, true)
	return cells


## Busca un obstáculo por id ({} si no está).
static func find(obstacles: Array, id: String) -> Dictionary:
	for o in obstacles:
		if o["id"] == id:
			return o
	return {}


## Cuánto cuesta limpiar el obstáculo `kind` si ya se limpiaron `cleared_count`:
## el precio sube con lo ya limpiado (hasta max_multiplier).
static func cost(cfg: Dictionary, kind: String, cleared_count: int) -> int:
	var def: Dictionary = cfg["obstacles"][kind]
	var multiplier := minf(float(cfg["max_multiplier"]), 1.0 + float(cfg["growth"]) * cleared_count)
	return int(floor(float(def["base_cost"]) * multiplier + 0.5))


## Camino libre desde la calle (el borde de adelante, z = lot-1) hasta pegado
## al obstáculo `target`. Persona: 1 celda. Vehículo: un bloque de 2x2.
##   blocked: celdas ocupadas ("x,z" → algo) SIN contar el obstáculo objetivo.
##   house_cells: celdas con la casa encima ("x,z" → true): no se cruzan.
## Devuelve {ok, reason, path} (path = lista de Vector2i, de la calle al lugar).
static func find_path(cfg: Dictionary, blocked: Dictionary, house_cells: Dictionary, target: Dictionary, vehicle: bool) -> Dictionary:
	var lot := int(cfg["lot"])
	var size := 2 if vehicle else 1
	var queue: Array = []
	var came := {}
	for x in range(0, lot - size + 1):
		var z := lot - size
		if _free(blocked, house_cells, lot, size, x, z):
			queue.append(Vector2i(x, z))
			came[_key(x, z)] = Vector2i(-1, -1)
	if queue.is_empty():
		return {"ok": false, "reason": "El vehículo no puede entrar desde la calle." if vehicle else "No hay paso desde la calle.", "path": []}
	var head := 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		if _touches(cur, size, target):
			var path: Array = []
			var node := cur
			while node != Vector2i(-1, -1):
				path.push_front(node)
				node = came[_key(node.x, node.y)]
			return {"ok": true, "reason": "", "path": path}
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = cur + step
			var k := _key(next.x, next.y)
			if not came.has(k) and _free(blocked, house_cells, lot, size, next.x, next.y):
				came[k] = cur
				queue.append(next)
	return {"ok": false, "reason": "No hay camino libre para el vehículo hasta ahí." if vehicle else "No hay paso hasta ahí.", "path": []}


static func _free(blocked: Dictionary, house_cells: Dictionary, lot: int, size: int, x: int, z: int) -> bool:
	if x < 0 or z < 0 or x + size > lot or z + size > lot:
		return false
	for cx in range(x, x + size):
		for cz in range(z, z + size):
			var k := _key(cx, cz)
			if blocked.has(k) or house_cells.has(k):
				return false
	return true


## El bloque toca (8 vecinos) al objetivo.
static func _touches(origin: Vector2i, size: int, target: Dictionary) -> bool:
	return origin.x + size - 1 >= target["x"] - 1 and origin.x <= target["x"] + target["w"] \
		and origin.y + size - 1 >= target["z"] - 1 and origin.y <= target["z"] + target["d"]
