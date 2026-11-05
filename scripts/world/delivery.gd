class_name Delivery
extends Node3D
## Entrega de compras (Pulido 2C). Cuando una pieza comprada termina de
## construirse, llega un camión por la calle y un repartidor baja las cajas: se
## le caen en la puerta (animación graciosa), las junta y deja UNA CAJA en el
## lugar de cada cosa. El jugador toca «Abrir todas las cajas» (el personaje va
## a cada una, sale humo blanco, tose y aparece el mueble); si no se lo ordena,
## el personaje las abre solo cuando quiere (su IA).
##
## Es solo visual y local: el dinero y la obra ya los resolvió el servidor
## (la pieza existe en la casa); la caja es cómo se ve y se usa hasta abrirla.
## Una pieza en caja no se puede usar (la IA no la elige).
##
## Va como hijo de House (coordenadas = celdas de la casa).

## Cambió qué piezas están en caja (la vista las dibuja distinto).
signal boxes_changed
## Las cajas que hay para abrir (ya dejadas en su lugar).
signal dropped_changed(count: int)

## Hasta cuántas cajas lleva el repartidor apiladas por viaje.
const MAX_STACK := 5
## Segundos (reales) que se espera para juntar compras en un mismo camión.
const BATCH_SECONDS := 2.5
const BOX_COLOR := "#c9a06b"

var house: HouseData
var nav: HouseNav
var view: HouseView
var services: Services
## "nivel|clave" → {"state": "transit" | "dropped", "level", "key"}
var boxes: Dictionary = {}

var _queue: Array = []
var _batch_timer := -1.0
var _busy := false


func _ready() -> void:
	add_to_group("delivery")
	EventBus.game_saving.connect(func() -> void: GameState.delivery = to_dict())


func setup(new_house: HouseData, new_nav: HouseNav, new_view: HouseView, new_services: Services) -> void:
	house = new_house
	nav = new_nav
	view = new_view
	services = new_services
	# Las cajas de la partida guardada ya están en su lugar (dejadas).
	boxes = {}
	for id in GameState.delivery.get("boxes", []):
		var parts := str(id).split("|")
		if parts.size() == 2 and house.has_piece(int(parts[0]), "objects", parts[1]):
			boxes[str(id)] = {"state": "dropped", "level": int(parts[0]), "key": parts[1]}
	_announce()


func to_dict() -> Dictionary:
	return {"boxes": boxes.keys()}


## ¿Esta pieza se entrega en caja? Los muebles y aparatos, no escaleras ni pilares.
static func is_deliverable(value: Dictionary) -> bool:
	return Catalog.get_item(value.get("item", "")).get("kind", "") == "furniture"


## ¿Está en caja (en camino o ya dejada)?
func is_boxed(level: int, key: String) -> bool:
	return boxes.has("%d|%s" % [level, key])


func dropped_count() -> int:
	var n := 0
	for box in boxes.values():
		if box["state"] == "dropped":
			n += 1
	return n


## Cajas ya dejadas: [{level, key}].
func dropped_boxes() -> Array:
	var list: Array = []
	for box in boxes.values():
		if box["state"] == "dropped":
			list.append(box)
	return list


## Una pieza terminó de construirse: va a la próxima entrega.
func request(level: int, key: String) -> void:
	var value: Variant = house.get_piece(level, "objects", key)
	if value == null or not is_deliverable(value) or boxes.has("%d|%s" % [level, key]):
		return
	boxes["%d|%s" % [level, key]] = {"state": "transit", "level": level, "key": key}
	_queue.append({"level": level, "key": key})
	_batch_timer = BATCH_SECONDS
	_announce()


func _process(delta: float) -> void:
	if _batch_timer >= 0.0:
		_batch_timer -= delta
		if _batch_timer < 0.0 and not _queue.is_empty() and not _busy:
			_run_next_trip()


# --- El viaje del camión ---

func _run_next_trip() -> void:
	_busy = true
	var trip: Array = []
	while not _queue.is_empty() and trip.size() < MAX_STACK:
		trip.append(_queue.pop_front())
	await _run_trip(trip)
	_busy = false
	if not _queue.is_empty():
		_batch_timer = 0.5


func _run_trip(trip: Array) -> void:
	var gate := Vector2i(lot_center_x(), HouseGrid.LOT_SIZE.y - 1)
	# Pulido 6B: el camión llega por su carril y se estaciona como cualquier otro vehículo.
	var side := services.next_side("delivery")
	await services.wait_road(side)
	var truck := services.spawn_vehicle("truck", side)
	Sound.play("truck")
	await services.park(truck, side, gate.x + 0.5)
	# Baja el repartidor con las cajas apiladas.
	var courier := services.make_worker("courier")
	courier.position = services.exit_point(truck)
	services.add_child(courier)
	var stack := Node3D.new()
	stack.name = "Stack"
	stack.position = Vector3(0, 0, 0.55)
	courier.add_child(stack)
	for i in trip.size():
		var crate := _make_box(0.45)
		crate.position = Vector3(0, 0.55 + i * 0.4, 0)
		stack.add_child(crate)
	var door := front_door_cell(house, nav)
	var path := _walk_path(gate, door)
	await services.travel(courier, services.walk_route(courier.position, [Vector3(gate.x + 0.5, 0, services.sidewalk_z)]), Services.WALK_SPEED * 1.4)
	await services.travel(courier, path, Services.WALK_SPEED * 1.4)
	# En la puerta se le inclinan y se le caen (animación graciosa).
	await _stumble(courier, stack)
	# Las lleva de a una, cada caja en el lugar de su cosa.
	for entry in trip:
		await _deliver_one(courier, entry, door)
	# Vuelve al camión y se van.
	await services.travel(courier, _reversed(path), Services.WALK_SPEED * 1.6)
	await services.travel(courier, services.walk_route(courier.position, [Vector3(gate.x + 0.5, 0, services.sidewalk_z), services.exit_point(truck)]), Services.WALK_SPEED * 1.6)
	courier.queue_free()
	await services.unpark(truck, side)


static func lot_center_x() -> int:
	return HouseGrid.LOT_SIZE.x / 2


func _reversed(points: Array) -> Array:
	var copy := points.duplicate()
	copy.reverse()
	return copy


## Puntos de la entrada de la parcela a la puerta (caminando por el pasto).
func _walk_path(gate: Vector2i, door: Vector2i) -> Array:
	var points: Array = [Vector3(gate.x + 0.5, 0, gate.y + 0.5)]
	# Un quiebre para no cruzar la casa: primero hacia el costado, después hacia adelante.
	points.append(Vector3(door.x + 0.5, 0, gate.y - 1.0))
	points.append(Vector3(door.x + 0.5, 0, door.y + 0.5))
	return points


## Se resbala: se inclina, las cajas salen volando y caen revueltas.
func _stumble(courier: Node3D, stack: Node3D) -> void:
	services._bubble(courier, "ouch", 1.6)
	Sound.play("box_fall")
	var tilt := create_tween()
	tilt.tween_property(courier, "rotation:x", -0.45, 0.25)
	tilt.tween_property(courier, "rotation:x", 0.0, 0.5)
	for crate in stack.get_children():
		var crate_world: Vector3 = crate.global_position
		crate.reparent(services, true)
		crate.global_position = crate_world
		var drop := create_tween()
		var scatter := Vector3(randf_range(-1.2, 1.2), 0.2, randf_range(0.4, 1.6))
		drop.set_parallel(true)
		drop.tween_property(crate, "position", Vector3(courier.position.x + scatter.x, 0.2, courier.position.z + scatter.z), 0.5)
		drop.tween_property(crate, "rotation", Vector3(randf_range(-0.6, 0.6), randf_range(0, 3), randf_range(-0.6, 0.6)), 0.5)
	await get_tree().create_timer(1.6 / services.speed_scale).timeout
	# Recoge las cajas desparramadas (de a poco).
	for crate in services.get_children():
		if crate is Node3D and crate.has_meta("loose_box"):
			crate.queue_free()


func _make_box(size: float) -> Node3D:
	var node := Node3D.new()
	node.set_meta("loose_box", true)
	HousePieces.add_box(node, Vector3(0, size / 2.0, 0), Vector3(size, size, size), Style.toon_material(Color(BOX_COLOR)))
	HousePieces.add_box(node, Vector3(0, size + 0.005, 0), Vector3(size * 0.2, 0.03, size * 1.02), Style.toon_material(Color("#e7d7b5")))
	return node


## Lleva una caja hasta el lugar de su pieza y la deja.
func _deliver_one(courier: Node3D, entry: Dictionary, door: Vector2i) -> void:
	var level: int = entry["level"]
	var key: String = entry["key"]
	var value: Variant = house.get_piece(level, "objects", key)
	if value == null:
		boxes.erase("%d|%s" % [level, key])
		return
	var spots := nav.object_spots(level, key)
	var path := PackedVector3Array()
	if not spots.is_empty():
		path = nav.find_path(0, door, level, spots[0])
	var carried := _make_box(0.5)
	carried.position = Vector3(0, 0.7, 0.5)
	courier.add_child(carried)
	if not path.is_empty():
		await services.travel(courier, Array(path), Services.WALK_SPEED * 1.6)
	carried.queue_free()
	boxes["%d|%s" % [level, key]]["state"] = "dropped"
	Sound.play("box_drop")
	_announce()
	if not path.is_empty():
		await services.travel(courier, Array(nav.find_path(level, spots[0], 0, door)), Services.WALK_SPEED * 1.6)


# --- Abrir ---

## Se abrió una caja: aparece el mueble (con humo blanco).
func open_box(level: int, key: String) -> void:
	var id := "%d|%s" % [level, key]
	if not boxes.has(id):
		return
	boxes.erase(id)
	var value: Variant = house.get_piece(level, "objects", key)
	if value != null:
		var cells := HouseData.value_cells(value)
		var center := HouseGrid.cell_center(cells[0]) + Vector3(0, HouseGrid.level_y(level), 0)
		Fx.puff(self, center + Vector3(0, 0.3, 0), 22)
	Sound.play("box_open")
	_announce()


func _announce() -> void:
	boxes_changed.emit()
	dropped_changed.emit(dropped_count())
	EventBus.boxes_changed.emit(dropped_count())
	if view != null:
		var ids := {}
		for id in boxes:
			ids["%s|objects|%s" % [boxes[id]["level"], boxes[id]["key"]]] = boxes[id]["state"]
		view.set_boxed(ids)


## La celda de afuera junto a la puerta de la planta baja más cercana a la
## calle (o el frente de la parcela si no hay puerta). La usa también el
## personaje para volver del trabajo.
static func front_door_cell(target: HouseData, grid_nav: HouseNav) -> Vector2i:
	var work_cell := Vector2i(HouseGrid.LOT_SIZE.x / 2, HouseGrid.LOT_SIZE.y - 1)
	var best := Vector2i(work_cell.x, work_cell.y - 1)
	var best_distance := 1 << 30
	for key in target.get_layer(0, "walls"):
		var wall: Dictionary = target.get_piece(0, "walls", key)
		if Catalog.get_item(wall.get("opening", "")).get("kind", "") != "door":
			continue
		for side in HouseGrid.edge_cells(key):
			if target.has_piece(0, "floors", HouseGrid.cell_key(side)):
				continue
			var distance := absi(side.x - work_cell.x) + absi(side.y - work_cell.y)
			if grid_nav.is_walkable(0, side) and distance < best_distance:
				best_distance = distance
				best = side
	return best
