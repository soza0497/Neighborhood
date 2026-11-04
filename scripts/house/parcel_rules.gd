class_name ParcelRules
## Parcela y obstáculos (Pulido 2C): reglas sin pantalla.
##
## COPIA EXACTA de server/nakama/modules/neighborhood_parcel.lua: el teléfono y
## el servidor generan los MISMOS obstáculos desde la misma semilla (y revisan
## el mismo camino). Si cambiás algo acá, cambialo allá y en sus pruebas.
##
## La parcela es de LOT x LOT celdas; la casa de antes queda en el centro
## (home_zone). Lo demás se llena de obstáculos (árboles, rocas, un laguito,
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
	var zone_lo := int(floor((lot - int(cfg["home_zone"])) / 2.0))
	var zone_hi := zone_lo + int(cfg["home_zone"]) - 1
	var margin := int(cfg.get("clear_margin", 0))
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
					if _fits(taken, lot, zone_lo, zone_hi, margin, x, z, w, d):
						_place(taken, list, kind, def, x, z)
						break
		else:
			# Por densidad: se recorren las celdas en orden y cada una "tira un dado".
			var density := float(def["density"])
			for z in lot:
				for x in lot:
					state = next_random(state)
					var roll := float(state) / MODULUS
					if roll < density and _fits(taken, lot, zone_lo, zone_hi, margin, x, z, w, d):
						_place(taken, list, kind, def, x, z)
	return list


static func _fits(taken: Dictionary, lot: int, zone_lo: int, zone_hi: int, margin: int, x: int, z: int, w: int, d: int) -> bool:
	if x < 0 or z < 0 or x + w > lot or z + d > lot:
		return false
	for cx in range(x, x + w):
		for cz in range(z, z + d):
			var in_zone := cx >= zone_lo - margin and cx <= zone_hi + margin and cz >= zone_lo - margin and cz <= zone_hi + margin
			if taken.has(_key(cx, cz)) or in_zone:
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


## Celdas ocupadas por los obstáculos que NO se limpiaron: "x,z" → id.
static func blocked_cells(obstacles: Array, cleared: Dictionary) -> Dictionary:
	var cells := {}
	for o in obstacles:
		if cleared.has(o["id"]):
			continue
		for cx in range(o["x"], o["x"] + o["w"]):
			for cz in range(o["z"], o["z"] + o["d"]):
				cells[_key(cx, cz)] = o["id"]
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
