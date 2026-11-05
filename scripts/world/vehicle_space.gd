class_name VehicleSpace
extends RefCounted
## Matemática de los vehículos de servicio (Pulido 6B), sin escenas: se puede probar sola.
##   - rects_overlap: ¿dos vehículos (rectángulos girados) se atraviesan?
##   - find_slot: dónde estacionarse junto al cordón sin tocar a otro.
##   - avoid_circles: rodea postes y otras cosas redondas con un camino a pie.
## Los datos (largos, anchos, carriles) salen de data/services.json.

const DATA_PATH := "res://data/services.json"

static var _data: Dictionary = {}


## Los datos de data/services.json (se leen una vez).
static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if parsed is Dictionary:
			_data = parsed
		else:
			push_error("No se pudo leer %s" % DATA_PATH)
			_data = {"road": {}, "vehicles": {}, "crews": {}, "arrival": {}, "parking": {}, "walk": {}, "removal": {}, "crew": {}}
	return _data


static func road() -> Dictionary:
	return data().get("road", {})


static func road_value(key: String, fallback: float) -> float:
	return float(road().get(key, fallback))


## (largo, ancho) en metros de un vehículo.
static func footprint(kind: String) -> Vector2:
	var info: Dictionary = data().get("vehicles", {}).get(kind, {})
	return Vector2(float(info.get("length", 3.5)), float(info.get("width", 1.9)))


## Quién viene para un tipo de servicio de parcel.json: {role, vehicle}.
static func crew_info(service: String) -> Dictionary:
	return data().get("crews", {}).get(service, {"role": "driver", "vehicle": ""})


## "left" o "right" para una clase de llegada ("foot", "machine", "ambulance", "delivery").
## `count` es cuántas llegadas hubo (para alternar).
static func arrival_side(kind: String, count: int) -> String:
	var rule := str(data().get("arrival", {}).get(kind, "left"))
	if rule == "alternate":
		return "left" if count % 2 == 0 else "right"
	return "right" if rule == "right" else "left"


# --- Choques ---

## ¿Se tocan dos rectángulos girados en el plano XZ? `pos` = centro (x, z), `yaw` = rotation.y
## del nodo, `half` = (medio ancho, medio largo). Eje de separación (SAT).
static func rects_overlap(pos_a: Vector2, yaw_a: float, half_a: Vector2, pos_b: Vector2, yaw_b: float, half_b: Vector2) -> bool:
	var right_a := Vector2(cos(yaw_a), -sin(yaw_a))
	var front_a := Vector2(sin(yaw_a), cos(yaw_a))
	var right_b := Vector2(cos(yaw_b), -sin(yaw_b))
	var front_b := Vector2(sin(yaw_b), cos(yaw_b))
	var between := pos_b - pos_a
	for axis in [right_a, front_a, right_b, front_b]:
		var axis_v: Vector2 = axis
		var reach_a := half_a.x * absf(right_a.dot(axis_v)) + half_a.y * absf(front_a.dot(axis_v))
		var reach_b := half_b.x * absf(right_b.dot(axis_v)) + half_b.y * absf(front_b.dot(axis_v))
		if absf(between.dot(axis_v)) > reach_a + reach_b:
			return false
	return true


# --- Estacionar ---

## Centro x de un lugar libre junto al cordón. `taken` = tramos ocupados (Vector2 min, max).
## Busca lo más cerca posible de `desired_x`; entre dos lugares igual de cerca prefiere el que
## está hacia `prefer` (-1 = atrás/izquierda, 1 = adelante/derecha). Devuelve INF si no hay.
static func find_slot(taken: Array, desired_x: float, length: float, margin: float,
		range_min: float, range_max: float, prefer := -1.0) -> float:
	var half := length / 2.0 + margin / 2.0
	var offset := 0.0
	var limit := maxf(desired_x - range_min, range_max - desired_x)
	while offset <= limit:
		for sign_value in [prefer, -prefer]:
			var x: float = desired_x + float(sign_value) * offset
			if x - half < range_min or x + half > range_max:
				continue
			if _slot_free(taken, x, half):
				return x
			if offset == 0.0:
				break
		offset += 0.25
	return INF


static func _slot_free(taken: Array, x: float, half: float) -> bool:
	for entry in taken:
		var span: Vector2 = entry
		if x + half > span.x and x - half < span.y:
			return false
	return true


# --- Caminar sin chocar con postes ---

## Agrega puntos intermedios para que un camino a pie (lista de Vector3) no pase a menos de
## `radius` metros del centro de ningún círculo de `circles` (lista de Vector3; se usa x y z).
static func avoid_circles(points: Array, circles: Array, radius: float) -> Array:
	var result: Array = []
	if points.is_empty():
		return result
	result.append(points[0])
	for i in range(1, points.size()):
		var detour: Array = _detour(result[result.size() - 1], points[i], circles, radius, 6)
		result.append_array(detour)
		result.append(points[i])
	return result


static func _detour(a: Vector3, b: Vector3, circles: Array, radius: float, depth: int) -> Array:
	var empty: Array = []
	if depth <= 0 or circles.is_empty():
		return empty
	var from := Vector2(a.x, a.z)
	var along := Vector2(b.x, b.z) - from
	var length_squared := along.length_squared()
	if length_squared < 0.0001:
		return empty
	var best_t := 2.0
	var best_center := Vector2.ZERO
	for circle in circles:
		var c: Vector3 = circle
		var center := Vector2(c.x, c.z)
		var t := clampf((center - from).dot(along) / length_squared, 0.0, 1.0)
		if (from + along * t).distance_to(center) < radius and t < best_t:
			best_t = t
			best_center = center
	if best_t > 1.5:
		return empty
	var direction := along.normalized()
	var normal := Vector2(-direction.y, direction.x)
	# Pasa por el lado contrario al que queda el poste.
	var side := -1.0 if normal.dot(best_center - from) >= 0.0 else 1.0
	var spot := best_center + normal * side * (radius + 0.15)
	var waypoint := Vector3(spot.x, a.y, spot.y)
	var result: Array = _detour(a, waypoint, circles, radius, depth - 1)
	result.append(waypoint)
	result.append_array(_detour(waypoint, b, circles, radius, depth - 1))
	return result
