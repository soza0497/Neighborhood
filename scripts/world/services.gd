class_name Services
extends Node3D
## Servicios que llegan (Pulido 2C): un sistema genérico de personas y
## vehículos que vienen por la calle, entran a la parcela por un camino, hacen
## algo y se van. Lo usan la limpieza de terreno (jardinero, leñador,
## cuadrilla con tractor o retroexcavadora), la entrega de compras (camión y
## repartidor) y la ambulancia.
##
## Va como hijo de House: las coordenadas son CELDAS de la casa (x, z).
## Todo es visual y local; el que cobra y decide es el servidor (Parcel).
##
## Modelos y animaciones SIMPLES (cajas, cápsulas y la figura chibi); en la
## Fase 7 se reemplazan por arte de verdad. Los colores salen de la paleta.

## Terminó un servicio: {id, kind, ok, blocked, reason}.
signal finished(result: Dictionary)

const DRIVE_SPEED := 7.0
const WALK_SPEED := 2.4
## Cuánto antes de la parcela empiezan los vehículos (celdas).
const APPROACH := 40.0

var lot := Vector2i(96, 96)
## Dónde están la acera y la calle, en celdas de la casa (z).
var sidewalk_z := 98.0
var road_z := 103.0
var running := 0
## Para las demos: qué tan rápido pasan los servicios (1 = normal).
var speed_scale := 1.0
## Los pone la escena principal.
var world: WorldBuilder
var house: HouseData


func _ready() -> void:
	lot = HouseGrid.LOT_SIZE
	if world != null:
		sidewalk_z = world.sidewalk_z + lot.y / 2.0
		road_z = world.road_z + lot.y / 2.0
	else:
		sidewalk_z = lot.y + 1.25
		road_z = lot.y + 6.0


# --- Modelos simples ---

## Un vehículo por tipo. Mira hacia +Z (el adelante). Pies en Y = 0.
func make_vehicle(kind: String) -> Node3D:
	var vehicle := Node3D.new()
	vehicle.name = "Vehicle_" + kind
	var dark := Style.toon_material(Color("#2b2b33"))
	match kind:
		"tractor":
			var body := Style.toon_material(Color("#4aa65b"))
			HousePieces.add_box(vehicle, Vector3(0, 0.75, 0.25), Vector3(1.1, 0.7, 1.9), body)
			HousePieces.add_box(vehicle, Vector3(0, 1.45, -0.3), Vector3(0.95, 0.8, 0.9), Style.toon_material(Color("#a9d6f5")))
			HousePieces.add_box(vehicle, Vector3(0, 1.9, -0.3), Vector3(1.1, 0.1, 1.05), body)
			_wheel(vehicle, Vector3(-0.7, 0.55, -0.45), 0.55, dark)
			_wheel(vehicle, Vector3(0.7, 0.55, -0.45), 0.55, dark)
			_wheel(vehicle, Vector3(-0.6, 0.35, 1.0), 0.35, dark)
			_wheel(vehicle, Vector3(0.6, 0.35, 1.0), 0.35, dark)
			HousePieces.add_box(vehicle, Vector3(0, 0.45, 1.5), Vector3(1.5, 0.5, 0.2), Style.toon_material(Color("#9aa0a8")))
		"excavator":
			var body := Style.toon_material(Style.color("truck"))
			HousePieces.add_box(vehicle, Vector3(-0.6, 0.3, 0), Vector3(0.5, 0.6, 2.4), dark)
			HousePieces.add_box(vehicle, Vector3(0.6, 0.3, 0), Vector3(0.5, 0.6, 2.4), dark)
			var turret := Node3D.new()
			turret.name = "Turret"
			turret.position = Vector3(0, 0.6, 0)
			vehicle.add_child(turret)
			HousePieces.add_box(turret, Vector3(0, 0.45, -0.2), Vector3(1.5, 0.8, 1.6), body)
			HousePieces.add_box(turret, Vector3(0.35, 1.1, 0.2), Vector3(0.8, 0.7, 0.8), Style.toon_material(Color("#a9d6f5")))
			var arm := Node3D.new()
			arm.name = "Arm"
			arm.position = Vector3(-0.3, 0.8, 0.6)
			turret.add_child(arm)
			HousePieces.add_box(arm, Vector3(0, 0.0, 0.9), Vector3(0.22, 0.22, 1.9), body)
			HousePieces.add_box(arm, Vector3(0, -0.45, 1.8), Vector3(0.6, 0.7, 0.4), Style.toon_material(Color("#9aa0a8")))
		"truck":
			HousePieces.add_box(vehicle, Vector3(0, 1.2, -0.7), Vector3(2.0, 1.9, 2.8), Style.toon_material(Style.color("truck")))
			HousePieces.add_box(vehicle, Vector3(0, 0.95, 1.4), Vector3(1.9, 1.4, 1.3), Style.toon_material(Style.color("truck").darkened(0.15)))
			HousePieces.add_box(vehicle, Vector3(0, 1.25, 2.07), Vector3(1.6, 0.6, 0.05), Style.toon_material(Color("#a9d6f5")))
			for z in [-1.4, 1.5]:
				_wheel(vehicle, Vector3(-1.0, 0.4, z), 0.4, dark)
				_wheel(vehicle, Vector3(1.0, 0.4, z), 0.4, dark)
		"ambulance":
			HousePieces.add_box(vehicle, Vector3(0, 1.1, -0.2), Vector3(1.9, 1.7, 3.6), Style.toon_material(Style.color("ambulance")))
			HousePieces.add_box(vehicle, Vector3(0, 1.3, 1.62), Vector3(1.7, 0.6, 0.05), Style.toon_material(Color("#a9d6f5")))
			var cross := Style.toon_material(Style.color("cross"))
			HousePieces.add_box(vehicle, Vector3(0.96, 1.2, -0.3), Vector3(0.05, 0.9, 0.3), cross)
			HousePieces.add_box(vehicle, Vector3(0.96, 1.2, -0.3), Vector3(0.05, 0.3, 0.9), cross)
			HousePieces.add_box(vehicle, Vector3(-0.96, 1.2, -0.3), Vector3(0.05, 0.9, 0.3), cross)
			HousePieces.add_box(vehicle, Vector3(-0.96, 1.2, -0.3), Vector3(0.05, 0.3, 0.9), cross)
			var siren := HousePieces.add_box(vehicle, Vector3(0, 2.05, 0.8), Vector3(0.7, 0.18, 0.3), cross)
			siren.name = "Siren"
			for z in [-1.2, 1.1]:
				_wheel(vehicle, Vector3(-0.95, 0.38, z), 0.38, dark)
				_wheel(vehicle, Vector3(0.95, 0.38, z), 0.38, dark)
		_:
			HousePieces.add_box(vehicle, Vector3(0, 0.8, 0), Vector3(1.6, 1.2, 3.0), Style.toon_material(Style.color("van")))
	return vehicle


func _wheel(parent: Node3D, pos: Vector3, radius: float, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.3
	mesh.radial_segments = 10
	var wheel := MeshInstance3D.new()
	wheel.mesh = mesh
	wheel.material_override = material
	wheel.rotation.z = PI / 2.0
	wheel.position = pos
	parent.add_child(wheel)


## Una persona del servicio (la figura chibi con chaleco de su color).
func make_worker(role: String) -> Node3D:
	var looks := {
		"gardener": {"skin": "#d9a67c", "shirt": "#6fd1a0", "pants": "#3b4a5e", "hair": "#5a3a22"},
		"lumberjack": {"skin": "#f5c9a6", "shirt": "#d9534f", "pants": "#3b4a5e", "hair": "#8a5a3a"},
		"driver": {"skin": "#8d5a3b", "shirt": "#ffb347", "pants": "#3b4a5e", "hair": "#222222"},
		"courier": {"skin": "#f5c9a6", "shirt": "#ffd166", "pants": "#33384a", "hair": "#c9a227"},
		"paramedic": {"skin": "#f5c9a6", "shirt": "#f6f6f6", "pants": "#4f8fe0", "hair": "#5a3a22"},
	}
	var body := CharacterLook.build(looks.get(role, looks["driver"]))
	body.name = "Worker_" + role
	body.scale = Vector3.ONE * 0.95
	return body


# --- Movimiento ---

## Mueve `node` por `points` (en orden) a `speed` m/s, mirando hacia donde va.
func travel(node: Node3D, points: Array, speed: float) -> void:
	for point in points:
		var target: Vector3 = point
		var delta := target - node.position
		delta.y = 0.0
		if delta.length() < 0.01:
			continue
		node.rotation.y = atan2(delta.x, delta.z)
		var tween := create_tween()
		tween.tween_property(node, "position", Vector3(target.x, node.position.y, target.z), delta.length() / (speed * speed_scale))
		await tween.finished
		if not is_instance_valid(node):
			return


## Puntos de la calle hasta la entrada de un camino (la primera celda) y de
## vuelta: el vehículo llega por la calle desde el oeste y se va al este.
func road_in(first_cell: Vector2i) -> Array:
	var x := first_cell.x + 0.5
	return [Vector3(-APPROACH, 0, road_z), Vector3(x, 0, road_z), Vector3(x, 0, sidewalk_z)]


func road_out(first_cell: Vector2i) -> Array:
	var x := first_cell.x + 0.5
	return [Vector3(x, 0, sidewalk_z), Vector3(x, 0, road_z), Vector3(lot.x + APPROACH, 0, road_z)]


func path_points(cells: Array, vehicle: bool) -> Array:
	var points: Array = []
	var shift := 1.0 if vehicle else 0.5  # El bloque de un vehículo mide 2 x 2.
	for cell in cells:
		points.append(Vector3(cell.x + shift, 0, cell.y + shift))
	return points


func _bubble(node: Node3D, text: String, seconds := 3.0) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = Vector3(0, 3.0, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 52
	label.outline_size = 12
	label.pixel_size = 0.006
	label.outline_modulate = Color(0.15, 0.2, 0.3)
	node.add_child(label)
	get_tree().create_timer(seconds).timeout.connect(label.queue_free)


# --- Limpieza de terreno ---

## Llega el servicio para limpiar el obstáculo `o`. `route` es el resultado
## de ParcelRules.find_path (path de celdas, de la calle al lugar). Si
## `blocked`, el vehículo llega, avisa que no puede entrar y se va.
func run_clear(o: Dictionary, def: Dictionary, route: Dictionary, blocked: bool) -> void:
	running += 1
	var id: String = o["id"]
	var vehicle_kind: String = str(def.get("vehicle", ""))
	var path: Array = route.get("path", [])
	var role: String = {"gardener": "gardener", "lumberjack": "lumberjack", "crew": "driver"}.get(def.get("service", ""), "driver")
	var target := Vector3(o["x"] + o["w"] / 2.0, 0.0, o["z"] + o["d"] / 2.0)
	var first: Vector2i = path[0] if not path.is_empty() else Vector2i(lot.x / 2, lot.y - 1)
	if vehicle_kind != "":
		var vehicle := make_vehicle(vehicle_kind)
		vehicle.position = road_in(first)[0]
		add_child(vehicle)
		await travel(vehicle, road_in(first), DRIVE_SPEED)
		if blocked or path.is_empty():
			_bubble(vehicle, "No puedo entrar: no hay camino libre")
			Sound.play("truck")
			await get_tree().create_timer(3.2 / speed_scale).timeout
			await travel(vehicle, road_out(first).slice(1), DRIVE_SPEED)
			vehicle.queue_free()
			running -= 1
			finished.emit({"id": id, "kind": "clear", "ok": false, "blocked": true, "reason": str(route.get("reason", "No hay camino libre."))})
			return
		await travel(vehicle, path_points(path, true), DRIVE_SPEED * 0.5)
		await _work_at(vehicle, target, float(def.get("seconds", 20)) * 0.08 + 4.0, vehicle_kind)
		await travel(vehicle, _reversed(path_points(path, true)), DRIVE_SPEED * 0.5)
		await travel(vehicle, road_out(first), DRIVE_SPEED)
		vehicle.queue_free()
	else:
		# Solo la persona: llega caminando por la acera y entra por el camino.
		var worker := make_worker(role)
		worker.position = Vector3(first.x - 30.0, 0, sidewalk_z)
		add_child(worker)
		await travel(worker, [Vector3(first.x + 0.5, 0, sidewalk_z)], WALK_SPEED * 1.6)
		if path.is_empty():
			_bubble(worker, "No hay paso")
			await get_tree().create_timer(2.5 / speed_scale).timeout
			await travel(worker, [Vector3(first.x + 40.0, 0, sidewalk_z)], WALK_SPEED * 1.6)
			worker.queue_free()
			running -= 1
			finished.emit({"id": id, "kind": "clear", "ok": false, "blocked": true, "reason": str(route.get("reason", "No hay paso."))})
			return
		await travel(worker, path_points(path, false), WALK_SPEED * 1.6)
		await _work_at(worker, target, float(def.get("seconds", 20)) * 0.08 + 3.0, role)
		await travel(worker, _reversed(path_points(path, false)), WALK_SPEED * 1.6)
		await travel(worker, [Vector3(first.x + 40.0, 0, sidewalk_z)], WALK_SPEED * 1.6)
		worker.queue_free()
	running -= 1
	finished.emit({"id": id, "kind": "clear", "ok": true, "blocked": false, "reason": ""})


func _reversed(points: Array) -> Array:
	var copy := points.duplicate()
	copy.reverse()
	return copy


## Trabaja un rato en el lugar: se mece, levanta humo/polvo y suena.
func _work_at(node: Node3D, target: Vector3, seconds: float, what: String) -> void:
	var delta := target - node.position
	delta.y = 0.0
	if delta.length() > 0.01:
		node.rotation.y = atan2(delta.x, delta.z)
	var elapsed := 0.0
	seconds /= speed_scale
	var arm: Node3D = node.find_child("Arm", true, false)
	while elapsed < seconds:
		await get_tree().process_frame
		var step := get_process_delta_time()
		elapsed += step
		node.position.y = absf(sin(elapsed * 9.0)) * 0.05
		if arm != null:
			arm.rotation.x = sin(elapsed * 3.0) * 0.4
		if fmod(elapsed, 0.9) < step:
			Fx.puff(self, target + Vector3(0, 0.5, 0), 8, Color(0.85, 0.8, 0.7, 0.8))
			Sound.play("chop" if what in ["lumberjack", "gardener"] else "dig")
	node.position.y = 0.0


# --- Ambulancia ---

## Camino a pie desde la calle hasta una celda (esquivando obstáculos y la casa).
## Si no hay, una línea recta (los paramédicos "se las arreglan").
func person_path_to(cell: Vector2i) -> Array:
	var target := {"x": cell.x, "z": cell.y, "w": 1, "d": 1}
	var blocked := ParcelRules.blocked_cells(Parcel.obstacles, Parcel.cleared)
	blocked.erase("%d,%d" % [cell.x, cell.y])
	var house_cells := {}
	if house != null:
		for key in house.get_layer(0, "foundation"):
			house_cells[key] = true
	var route := ParcelRules.find_path(Parcel.cfg, blocked, house_cells, target, false)
	if route["ok"] and not route["path"].is_empty():
		return path_points(route["path"], false)
	return [Vector3(cell.x + 0.5, 0, lot.y - 1.0), Vector3(cell.x + 0.5, 0, cell.y + 0.5)]


## La ambulancia llega por la calle (sirena), un paramédico camina hasta el
## personaje lastimado, lo revisa y lo cura; después se van.
func run_ambulance(patient: Character) -> void:
	running += 1
	var gate := Vector2i(lot.x / 2, lot.y - 1)
	var ambulance := make_vehicle("ambulance")
	ambulance.position = road_in(gate)[0]
	add_child(ambulance)
	Sound.play("siren")
	var siren: MeshInstance3D = ambulance.find_child("Siren", true, false)
	await travel(ambulance, [Vector3(gate.x + 0.5, 0, road_z - 1.2)], DRIVE_SPEED * 1.4)
	var medic := make_worker("paramedic")
	medic.position = ambulance.position + Vector3(-1.7, 0, 0)
	add_child(medic)
	var points := person_path_to(patient.cell)
	await travel(medic, [Vector3(gate.x + 0.5, 0, sidewalk_z)], WALK_SPEED * 1.8)
	await travel(medic, points, WALK_SPEED * 1.8)
	# Lo revisa un rato (cruz roja y humito) y lo cura.
	_bubble(medic, "Lo revisamos…", 2.4)
	var elapsed := 0.0
	while elapsed < 2.6 / speed_scale:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		if siren != null:
			siren.visible = int(elapsed * 6.0) % 2 == 0
	Fx.puff(self, Vector3(patient.cell.x + 0.5, 0.4, patient.cell.y + 0.5), 14, Color(1.0, 0.7, 0.7, 0.8))
	if is_instance_valid(patient):
		patient.recover()
	await travel(medic, _reversed(points), WALK_SPEED * 1.8)
	await travel(medic, [ambulance.position + Vector3(-1.7, 0, 0)], WALK_SPEED * 1.8)
	medic.queue_free()
	await travel(ambulance, road_out(gate), DRIVE_SPEED * 1.4)
	ambulance.queue_free()
	running -= 1
	finished.emit({"id": "ambulance", "kind": "ambulance", "ok": true, "blocked": false, "reason": ""})
