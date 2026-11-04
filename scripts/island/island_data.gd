class_name IslandData
extends RefCounted
## Datos de la isla (Isla 1A, prototipo): lotes, zonas, calles, reglas y distancias
## de los niveles de detalle. Todo sale de data/island.json; aquí no hay números
## de diseño escritos. Son funciones estáticas (se prueban sin pantalla).
##
## Coordenadas: metros. (0, 0) = centro del parque, +Z = sur (avenida y muelle).

const PATH := "res://data/island.json"

static var _data: Dictionary = {}
static var _loaded := false
static var _by_id: Dictionary = {}
static var _colors: Dictionary = {}


## Lee el archivo (una sola vez). Si falla, devuelve un diccionario vacío.
static func data() -> Dictionary:
	if not _loaded:
		_loaded = true
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else {}
		_by_id.clear()
		_colors.clear()
		for l in _data.get("lots", []):
			_by_id[str(l["id"])] = l
	return _data


## Fuerza a leer de nuevo el archivo (lo usan las pruebas).
static func reload() -> void:
	_loaded = false
	data()


static func section(section_name: String) -> Dictionary:
	var value: Variant = data().get(section_name, {})
	return value if value is Dictionary else {}


# --- Lotes ---

## Todos los lotes del archivo (hasta 60).
static func all_lots() -> Array:
	return data().get("lots", [])


static func lot(lot_id: String) -> Dictionary:
	data()
	return _by_id.get(lot_id, {})


## Los lotes que existen con `count` lotes en la isla: los de "start" primero
## (los 30 del comienzo) y después los demás, en orden, hasta completar.
static func lots_for_count(count: int) -> Array:
	var result: Array = []
	for l in all_lots():
		if bool(l.get("start", false)):
			result.append(l)
	for l in all_lots():
		if result.size() >= count:
			break
		if not bool(l.get("start", false)):
			result.append(l)
	if result.size() > count:
		result.resize(count)
	return result


## Lado del lote en metros (S, M o L según rules.sizes).
static func lot_side(l: Dictionary) -> float:
	return float(rule("sizes", {}).get(str(l.get("size", "S")), 32.0))


static func lot_center(l: Dictionary) -> Vector3:
	var c: Array = l["center"]
	return Vector3(float(c[0]), 0.0, float(c[1]))


## Giro del lote en radianes (el frente de la casa mira al centro de la isla).
static func lot_yaw(l: Dictionary) -> float:
	return deg_to_rad(float(l.get("yaw", 0.0)))


## Las 4 esquinas del lote en el plano (x, z), agrandadas `grow` metros por lado.
static func lot_corners(l: Dictionary, grow := 0.0) -> PackedVector2Array:
	var half := lot_side(l) / 2.0 + grow
	var basis := Basis(Vector3.UP, lot_yaw(l))
	var c := lot_center(l)
	var result := PackedVector2Array()
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var p := basis * Vector3(corner.x * half, 0.0, corner.y * half) + c
		result.append(Vector2(p.x, p.z))
	return result


## Posición en el mundo de un punto local del lote (x a la derecha, z hacia el frente).
static func lot_to_world(l: Dictionary, local: Vector3) -> Vector3:
	return Basis(Vector3.UP, lot_yaw(l)) * local + lot_center(l)


# --- Reglas, colores y zonas ---

static func rule(rule_name: String, fallback: Variant = null) -> Variant:
	return section("rules").get(rule_name, fallback)


static func island_radius() -> float:
	return float(section("island").get("radius", 350.0))


static func lod_config() -> Dictionary:
	return section("lod")


static func color(color_name: String, fallback := Color.MAGENTA) -> Color:
	if not _colors.has(color_name):
		_colors[color_name] = Color.from_string(str(section("colors").get(color_name, "")), fallback)
	return _colors[color_name]


## Lista de colores (por ejemplo "crowns" o "shop_walls").
static func color_list(color_name: String) -> Array[Color]:
	var result: Array[Color] = []
	var list: Variant = section("colors").get(color_name, [])
	if list is Array:
		for entry in list:
			result.append(Color.from_string(str(entry), Color.MAGENTA))
	if result.is_empty():
		result.append(Color.MAGENTA)
	return result


## Generador de azar propio: misma semilla + misma etiqueta = mismos números.
static func rng_for(label: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = ("%d:%s" % [int(data().get("seed", 1)), label]).hash()
	return rng


## Punto (x, z) sobre un círculo de la isla: ángulo en grados (90 = sur) y radio.
static func polar(angle_deg: float, radius: float) -> Vector3:
	var a := deg_to_rad(angle_deg)
	return Vector3(cos(a) * radius, 0.0, sin(a) * radius)
