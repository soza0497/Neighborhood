class_name DoorAnimator
extends Node
## Puertas que se abren (Pulido 6B).
##
## Cuando un personaje se acerca a una puerta, la hoja gira sobre sus bisagras y se abre; al
## alejarse, se cierra. Siempre se abre HACIA EL MISMO LADO (un solo sentido), el que dice la
## puerta: si la pared guarda `swing` ("a" o "b") se usa ese lado; si no, la puerta se abre hacia
## adentro (el lado con piso) y, si los dos lados son iguales, hacia la cara «b» (sur o este).
##
## La casa dibuja la puerta como cajas dentro de la pared (scripts/house/house_pieces.gd, que no se
## toca acá): este nodo busca la hoja y la manija en la pared ya dibujada, las mete en un pivote
## puesto en la bisagra y gira ese pivote. Si la casa vuelve a dibujar la pared (la cambiaron),
## se arma otra vez el pivote y se conserva cuánto estaba abierta. Con un modelo .glb de puerta
## (sin cajas que encontrar) la puerta queda quieta, como antes.

## Cuánto se abre la hoja (grados) y a qué distancia empieza a abrirse / se cierra.
const OPEN_DEGREES := 100.0
const OPEN_DISTANCE := 1.15
const CLOSE_DISTANCE := 1.7
## Qué tan rápido se mueve (más alto = más rápido).
const SWING_RATE := 7.0
## Cada cuántos segundos revisa quién está cerca de qué puerta.
const SCAN_SECONDS := 0.2

var view: HouseView
var house: HouseData
## Otros nodos a tener en cuenta además de los personajes que cuelgan de la vista.
var extra_trackers: Array[Node3D] = []

## "nivel|clave" → {level, key, center, wall, pivot, open, target, side}
var _doors: Dictionary = {}
var _dirty := true
var _scan_timer := 0.0


func setup(new_view: HouseView, new_house: HouseData) -> void:
	view = new_view
	house = new_house
	house.piece_changed.connect(func(_l: int, _layer: String, _k: String) -> void: _dirty = true)
	house.reloaded.connect(func() -> void: _dirty = true)


## Hacia qué cara se abre la puerta de ese borde: "a" (norte u oeste) o "b" (sur o este).
static func swing_side(target_house: HouseData, level: int, key: String) -> String:
	var wall: Variant = target_house.get_piece(level, "walls", key)
	if wall != null:
		var stored := str(wall.get("swing", ""))
		if stored == "a" or stored == "b":
			return stored
	var sides := HouseGrid.edge_cells(key)
	var a_floor := target_house.has_piece(level, "floors", HouseGrid.cell_key(sides[0]))
	var b_floor := target_house.has_piece(level, "floors", HouseGrid.cell_key(sides[1]))
	return "a" if a_floor and not b_floor else "b"


## Ángulo del pivote (radianes) para esa cara y cuánto está abierta (0 a 1). Girar hacia
## +Y lleva el extremo libre hacia la cara «a» (-Z local) y hacia -Y, a la «b» (+Z local).
static func swing_angle(side: String, open: float) -> float:
	var sign_value := 1.0 if side == "a" else -1.0
	return sign_value * deg_to_rad(OPEN_DEGREES) * clampf(open, 0.0, 1.0)


## Busca la hoja y la manija en una pared dibujada y las pasa a un pivote en la bisagra.
## Devuelve el pivote, o null si la pared no tiene una puerta de cajas (por ejemplo un modelo).
static func make_pivot(wall_node: Node3D) -> Node3D:
	var existing := wall_node.get_node_or_null("DoorPivot") as Node3D
	if existing != null:
		return existing
	var leaf: MeshInstance3D = null
	var handle: MeshInstance3D = null
	for child in wall_node.get_children():
		if not child is MeshInstance3D:
			continue
		var box := child as MeshInstance3D
		# add_box dibuja con un cubo de 1 m escalado al tamaño de la pieza.
		if absf(box.scale.z - 0.06) < 0.005 and box.scale.x > 0.3:
			leaf = box
		elif absf(box.scale.y - 0.04) < 0.005 and absf(box.scale.z - 0.12) < 0.005:
			handle = box
	if leaf == null:
		return null
	var pivot := Node3D.new()
	pivot.name = "DoorPivot"
	# La bisagra queda en el borde del lado opuesto a la manija.
	pivot.position = Vector3(leaf.position.x - leaf.scale.x / 2.0, 0.0, 0.0)
	wall_node.add_child(pivot)
	leaf.reparent(pivot, true)
	if handle != null:
		handle.reparent(pivot, true)
	return pivot


## Cuánto está abierta una puerta ahora (0 a 1); 0 si no se conoce.
func open_amount(level: int, key: String) -> float:
	return float(_doors.get("%d|%s" % [level, key], {}).get("open", 0.0))


## Cuántas puertas animadas conoce (para pruebas).
func door_count() -> int:
	return _doors.size()


func _process(delta: float) -> void:
	if house == null or view == null:
		return
	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = SCAN_SECONDS
		if _dirty:
			_rebuild_list()
		_update_targets()
	for id in _doors:
		_animate(_doors[id], delta)


## Vuelve a armar la lista de puertas de la casa (conservando cuánto estaba abierta cada una).
func _rebuild_list() -> void:
	_dirty = false
	var fresh: Dictionary = {}
	for level in HouseGrid.level_range():
		for key in house.get_layer(level, "walls"):
			var wall: Dictionary = house.get_piece(level, "walls", key)
			if Catalog.get_item(str(wall.get("opening", ""))).get("kind", "") != "door":
				continue
			var id := "%d|%s" % [level, key]
			var old: Dictionary = _doors.get(id, {})
			fresh[id] = {"level": level, "key": key, "center": HouseGrid.edge_center(key), "wall": null, "pivot": null,
				"open": float(old.get("open", 0.0)), "target": 0.0, "side": swing_side(house, level, key)}
	_doors = fresh


## Quién está cerca de cada puerta: se abre; si nadie, se cierra (con un poco de margen).
func _update_targets() -> void:
	var walkers: Array[Node3D] = []
	for child in view.get_children():
		if child is Character and (child as Character).visible:
			walkers.append(child)
	walkers.append_array(extra_trackers)
	for id in _doors:
		var door: Dictionary = _doors[id]
		var center: Vector3 = door["center"]
		var floor_y := HouseGrid.level_y(int(door["level"]))
		var near := false
		var limit := CLOSE_DISTANCE if float(door["open"]) > 0.05 else OPEN_DISTANCE
		for walker in walkers:
			if not is_instance_valid(walker):
				continue
			if absf(walker.position.y - floor_y) > 1.5:
				continue
			if Vector2(walker.position.x - center.x, walker.position.z - center.z).length() <= limit:
				near = true
				break
		door["target"] = 1.0 if near else 0.0


func _animate(door: Dictionary, delta: float) -> void:
	var open := float(door["open"])
	var target := float(door["target"])
	if open <= 0.0 and target <= 0.0:
		return  # Cerrada y quieta: nada que hacer.
	# La pared pudo haberse vuelto a dibujar: entonces es otro nodo y se arma su pivote de nuevo.
	var wall_node: Node3D = view.get_piece_node(int(door["level"]), "walls", str(door["key"]))
	if wall_node == null:
		return
	if door["wall"] != wall_node:
		door["wall"] = wall_node
		door["pivot"] = make_pivot(wall_node)
	open = lerpf(open, target, clampf(SWING_RATE * delta, 0.0, 1.0))
	if absf(open - target) < 0.01:
		open = target
	door["open"] = open
	var pivot := door["pivot"] as Node3D
	if pivot != null:
		pivot.rotation.y = swing_angle(str(door["side"]), open)
