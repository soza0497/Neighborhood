class_name NeighborhoodMap
extends RefCounted
## El mapa del barrio (Fase 8A): lotes, calles y las casas de los vecinos.
##
## Todo sale de data/neighborhood.json. Los vecinos NO son jugadores reales
## (todavía): cada casa se genera siempre igual a partir de la semilla del
## archivo y el id del lote, así que el barrio es el mismo en todos los
## teléfonos sin guardar nada. Solo la pareja del jugador será otro jugador real.
##
## Coordenadas: las del MUNDO (metros). El origen es el centro de la parcela
## del jugador (96 x 96), la calle principal corre por el eje X al frente (+Z).
## No necesita nodos: son funciones estáticas, así se prueba sin pantalla.

const PATH := "res://data/neighborhood.json"
## Id del lote del jugador (su parcela, la que ya existía antes del barrio).
const PLAYER_LOT := "player"

static var _data: Dictionary = {}
static var _loaded := false
static var _names: Dictionary = {}
static var _designs: Dictionary = {}


## Lee el archivo (una sola vez). Si no se puede leer, el barrio queda vacío.
static func data() -> Dictionary:
	if not _loaded:
		_loaded = true
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else {}
		_names.clear()
		_designs.clear()
	return _data


## Fuerza a volver a leer el archivo (lo usan las pruebas).
static func reload() -> void:
	_loaded = false
	data()


## ¿Se dibuja el barrio? Solo con la parcela real de 96 x 96 (las pruebas con
## la parcela chica de 32 no lo necesitan).
static func enabled() -> bool:
	return HouseGrid.LOT_SIZE == Vector2i(96, 96) and not lots().is_empty()


# --- Lotes ---

static func lots() -> Array:
	return data().get("lots", [])


static func lot(lot_id: String) -> Dictionary:
	for l in lots():
		if l["id"] == lot_id:
			return l
	return {}


## Los lotes con casa de vecino (sin el del jugador ni la plazoleta).
static func house_lots() -> Array:
	var result: Array = []
	for l in lots():
		if l["kind"] == "house":
			result.append(l)
	return result


## Rectángulo del lote en el mundo: x, z = esquina, tamaño = ancho, fondo.
static func lot_rect(lot_id: String) -> Rect2:
	var r: Array = lot(lot_id).get("rect", [0, 0, 0, 0])
	return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))


static func lot_center(lot_id: String) -> Vector3:
	var rect := lot_rect(lot_id)
	var c := rect.get_center()
	return Vector3(c.x, 0.0, c.y)


## Z del centro de la calle principal (la misma que dibuja world.json).
static func street_z() -> float:
	var street: Dictionary = data().get("streets", [{}])[0]
	return float(street.get("center", 54.0))


## Los dos lotes pegados al del jugador (a la izquierda y a la derecha): la
## casa que se ve detrás de la valla es la de uno de ellos.
static func side_lots() -> Dictionary:
	var player := lot_rect(PLAYER_LOT)
	var result := {"left": "", "right": ""}
	for l in house_lots():
		var rect := lot_rect(l["id"])
		if not (rect.position.y < player.end.y and player.position.y < rect.end.y):
			continue  # No está en la misma fila.
		if is_equal_approx(rect.end.x, player.position.x):
			result["left"] = l["id"]
		elif is_equal_approx(rect.position.x, player.end.x):
			result["right"] = l["id"]
	return result


## ¿El punto (x, z) del mundo cae en la zona de lotes de los vecinos? El bosque
## de decoración no planta árboles ahí.
static func is_built_area(x: float, z: float, margin := 2.0) -> bool:
	for l in lots():
		if l["id"] == PLAYER_LOT:
			continue
		var rect := lot_rect(l["id"]).grow(margin)
		if rect.has_point(Vector2(x, z)):
			return true
	return false


# --- Familias y casas (siempre iguales) ---

## Generador de azar propio de un lote: misma semilla + mismo id = mismos números.
static func rng_for(lot_id: String, salt := "") -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = ("%d:%s:%s" % [int(data().get("seed", 1)), lot_id, salt]).hash()
	return rng


## Nombre de familia de un lote ("Pérez"). Cada casa tiene uno distinto
## (mientras haya menos casas que apellidos en el archivo).
static func family_name(lot_id: String) -> String:
	if _names.is_empty():
		var pool: Array = (data().get("houses", {}).get("families", ["Vecina"])).duplicate()
		var rng := rng_for("names")
		# Se baraja el listado con la semilla (Fisher-Yates) y se reparte en orden.
		for i in range(pool.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp = pool[i]
			pool[i] = pool[j]
			pool[j] = tmp
		var index := 0
		for l in house_lots():
			_names[l["id"]] = pool[index % pool.size()]
			index += 1
	return _names.get(lot_id, "")


## Texto para mostrar: "Familia Pérez".
static func family_label(lot_id: String) -> String:
	var l := lot(lot_id)
	if l.is_empty():
		return ""
	if l["kind"] == "park":
		return str(l.get("name", "Plazoleta"))
	if l["kind"] == "player":
		return "Tu casa"
	return "Familia %s" % family_name(lot_id)


## El diseño de la casa de un lote (ver NeighborHouseDesign), guardado en memoria.
static func design(lot_id: String) -> Dictionary:
	if not _designs.has(lot_id):
		_designs[lot_id] = NeighborHouseDesign.make(lot_id)
	return _designs[lot_id]


## Dónde queda la casa dentro de su lote: {center: Vector3 (centro de la casa),
## rot_y: giro (0 = el frente mira a +Z, PI = mira a -Z), size: Vector2 (celdas)}.
static func placement(lot_id: String) -> Dictionary:
	var l := lot(lot_id)
	var d := design(lot_id)
	var rect := lot_rect(lot_id)
	var cols := float(d["cols"])
	var rows := float(d["rows"])
	var cfg: Dictionary = data().get("houses", {})
	var front_gap := float(cfg.get("front_gap", 5.0))
	var near_gap := float(cfg.get("near_edge_gap", 3.0))
	var rng := rng_for(lot_id, "place")
	# Hacia la izquierda o la derecha dentro del lote, un poco al azar.
	var slack := maxf(0.0, rect.size.x - cols - 2.0)
	var x := rect.get_center().x + rng.randf_range(-slack / 2.0, slack / 2.0)
	# Los dos lotes pegados a la parcela del jugador: la casa se arrima a la valla.
	var sides := side_lots()
	if lot_id == sides["left"]:
		x = rect.end.x - near_gap - cols / 2.0
	elif lot_id == sides["right"]:
		x = rect.position.x + near_gap + cols / 2.0
	var south: bool = l.get("facing", "south") == "south"
	var z := rect.end.y - front_gap - rows / 2.0 if south else rect.position.y + front_gap + rows / 2.0
	return {"center": Vector3(x, 0.0, z), "rot_y": 0.0 if south else PI, "size": Vector2(cols, rows)}


## Punto del suelo delante de la puerta de la casa (donde la gente se para para
## entrar), en coordenadas del mundo.
static func door_point(lot_id: String, distance := 1.2) -> Vector3:
	var p := placement(lot_id)
	var d := design(lot_id)
	var size: Vector2 = p["size"]
	# Puerta en el sistema de la casa: celda (door_col + 0.5, rows) del lado del frente.
	var local := Vector3(float(d["door_col"]) + 0.5 - size.x / 2.0, 0.0, size.y / 2.0 + distance)
	var rotated := local.rotated(Vector3.UP, float(p["rot_y"]))
	return (p["center"] as Vector3) + rotated


## Punto de la acera, justo frente a la puerta (para que la gente salga a la calle).
static func sidewalk_point(lot_id: String) -> Vector3:
	var rect := lot_rect(lot_id)
	var door := door_point(lot_id)
	var south: bool = lot(lot_id).get("facing", "south") == "south"
	var street: Dictionary = data().get("streets", [{}])[0]
	var half_road := float(street.get("road_width", 7.0)) / 2.0
	var side := float(street.get("sidewalk_width", 2.5))
	var z := street_z() - half_road - side / 2.0 if south else street_z() + half_road + side / 2.0
	return Vector3(door.x, 0.0, z)


# --- Visitas y privacidad (Fase 8B) ---

## ¿Se puede ver por dentro esa casa? Las vecinas generadas siempre (en modo
## solo ver). La del jugador depende del interruptor de privacidad.
static func open_for_visit(lot_id: String) -> bool:
	var l := lot(lot_id)
	if l.is_empty() or l["kind"] == "park":
		return false
	if l["kind"] == "player":
		return is_my_house_visitable()
	return true


## Interruptor «Mi casa se puede visitar» (por defecto apagado). Se guarda en la
## partida (GameState.settings) y queda listo para cuando haya visitantes reales.
static func is_my_house_visitable() -> bool:
	return bool(GameState.settings.get("house_visitable", false))


static func set_my_house_visitable(on: bool) -> void:
	GameState.settings["house_visitable"] = on


## Los lotes que se pueden elegir en el menú «Barrio»: [{id, label, kind}].
static func visit_list() -> Array:
	var result: Array = []
	for l in lots():
		if l["kind"] == "player":
			continue
		result.append({"id": l["id"], "label": family_label(l["id"]), "kind": l["kind"]})
	return result
