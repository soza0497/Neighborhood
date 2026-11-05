class_name Services
extends Node3D
## Servicios que llegan (Pulido 2C, rehecho en el Pulido 6B): personas y vehículos que
## vienen por la calle, se estacionan, hacen algo y se van. Lo usan la limpieza de terreno
## (jardinero, leñador, cuadrilla con tractor o retroexcavadora), la entrega de compras
## (camión y repartidor) y la ambulancia.
##
## Pulido 6B:
##   - Los vehículos llegan desde un extremo de la calle POR SU CARRIL (los que vienen por la
##     izquierda usan el carril del lado de tu parcela; los de la derecha, el de enfrente) y
##     se estacionan junto al cordón sin dar vueltas en U. Dos vehículos NUNCA se atraviesan:
##     el segundo busca otro lugar y, mientras anda, espera detrás del de adelante.
##   - Un mismo equipo atiende, uno tras otro, los obstáculos pedidos juntos. Tipos distintos
##     (leñador y cuadrilla, por ejemplo) llegan en vehículos distintos a la vez.
##   - Apenas termina el corte avisa (`cut_finished`): el obstáculo desaparece en ese momento,
##     no cuando el equipo se va.
##   - La gente a pie rodea los postes de luz (VehicleSpace.avoid_circles).
##
## Va como hijo de House: las coordenadas son CELDAS de la casa (x, z).
## Todo es visual y local; el que cobra y decide es el servidor (Parcel).
## Los números (carriles, tamaños, velocidades) están en data/services.json.
##
## Modelos y animaciones SIMPLES (cajas y la figura chibi); en la Fase 7 se reemplazan por
## arte de verdad. Los colores salen de la paleta.

## Terminó el trabajo de un obstáculo: {id, kind, ok, blocked, reason}.
signal finished(result: Dictionary)
## Terminó el corte: el obstáculo ya se puede quitar (Parcel.finish) y se ve cómo cae.
signal cut_finished(id: String)

## Velocidades de respaldo (las de verdad salen de data/services.json).
const DRIVE_SPEED := 9.0
const WALK_SPEED := 2.4

var lot := Vector2i(96, 96)
## Dónde están la acera y la calle, en celdas de la casa (z).
var sidewalk_z := 98.0
var road_z := 103.0
var road_half := 3.5
var running := 0
## Para las demos: qué tan rápido pasan los servicios (1 = normal).
var speed_scale := 1.0
## Para las demos y pruebas: fuerza de qué lado llegan ("left", "right" o "" = según datos).
var force_side := ""
## Los pone la escena principal.
var world: WorldBuilder
var house: HouseData
## Lo llama el equipo a pie al llegar a la reja: el personaje va y le abre. (Lo pone main.)
var gate_handler := Callable()

## Todos los vehículos que andan por la calle o están estacionados.
var _vehicles: Array = []
## "near" (cordón de tu parcela) o "far" (el de enfrente) → [{node, min, max}].
var _parked: Dictionary = {"near": [], "far": []}
## Tramos del cordón que se dejan libres (la entrada de una máquina): id → Vector2(min, max).
var _reserved: Dictionary = {}
## Equipos en marcha: clave → {key, service, queue, open}.
var _crews: Dictionary = {}
## Obstáculos que ya tomó un equipo (para que no lo espere de más).
var _handled: Dictionary = {}
var _arrivals := 0


func _ready() -> void:
	lot = HouseGrid.LOT_SIZE
	if world != null:
		sidewalk_z = world.sidewalk_z + lot.y / 2.0
		road_z = world.road_z + lot.y / 2.0
		road_half = float(world.config.get("street", {}).get("road_width", 7.0)) / 2.0
	else:
		sidewalk_z = lot.y + 1.25
		road_z = lot.y + 6.0
		road_half = 3.5


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
		"pickup":
			# Camioneta del leñador: cabina roja y una caja con troncos.
			var red := Style.toon_material(Color("#d9534f"))
			HousePieces.add_box(vehicle, Vector3(0, 0.95, 1.0), Vector3(1.8, 1.1, 1.5), red)
			HousePieces.add_box(vehicle, Vector3(0, 1.25, 1.77), Vector3(1.5, 0.45, 0.05), Style.toon_material(Color("#a9d6f5")))
			HousePieces.add_box(vehicle, Vector3(0, 0.7, -0.8), Vector3(1.8, 0.5, 2.1), Style.toon_material(Color("#a83f3c")))
			var wood := Style.toon_material(Style.color("trunk"))
			HousePieces.add_box(vehicle, Vector3(-0.4, 1.1, -0.8), Vector3(0.45, 0.4, 1.9), wood)
			HousePieces.add_box(vehicle, Vector3(0.4, 1.1, -0.8), Vector3(0.45, 0.4, 1.9), wood)
			for z in [-1.3, 1.2]:
				_wheel(vehicle, Vector3(-0.95, 0.4, z), 0.4, dark)
				_wheel(vehicle, Vector3(0.95, 0.4, z), 0.4, dark)
		_:
			# Furgoneta del jardinero.
			HousePieces.add_box(vehicle, Vector3(0, 0.9, 0), Vector3(1.7, 1.3, 3.2), Style.toon_material(Style.color("van")))
			HousePieces.add_box(vehicle, Vector3(0, 1.1, 1.62), Vector3(1.5, 0.5, 0.05), Style.toon_material(Color("#a9d6f5")))
			for z in [-1.0, 1.0]:
				_wheel(vehicle, Vector3(-0.85, 0.35, z), 0.35, dark)
				_wheel(vehicle, Vector3(0.85, 0.35, z), 0.35, dark)
	# Pulido 6B: cada vehículo sabe qué es y cuánto ocupa (para no atravesarse).
	vehicle.set_meta("kind", kind)
	vehicle.set_meta("footprint", VehicleSpace.footprint(kind))
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


# --- Calle: carriles, cordones y lugares ---

func drive_speed() -> float:
	return VehicleSpace.road_value("drive_speed", DRIVE_SPEED)


## +1 si el vehículo viene por la izquierda (va hacia +X), -1 si viene por la derecha.
func _dir(side: String) -> float:
	return 1.0 if side == "left" else -1.0


func _heading(side: String) -> float:
	return PI / 2.0 if side == "left" else -PI / 2.0


func _start_x(side: String) -> float:
	var far := VehicleSpace.road_value("arrive_distance", 140.0)
	return -far if side == "left" else lot.x + far


func _end_x(side: String) -> float:
	var far := VehicleSpace.road_value("arrive_distance", 140.0)
	return lot.x + far if side == "left" else -far


## z del carril de cada lado: izquierda = el del lado de tu parcela.
func lane_z(side: String) -> float:
	var offset := VehicleSpace.road_value("lane_offset", 0.35)
	return road_z - offset if side == "left" else road_z + offset


## z de un vehículo estacionado pegado al cordón de ese lado.
func curb_z(side: String, kind: String) -> float:
	var half_width := VehicleSpace.footprint(kind).y / 2.0
	var gap := VehicleSpace.road_value("curb_gap", 0.12)
	if side == "left":
		return road_z - road_half + half_width + gap
	return road_z + road_half - half_width - gap


func _curb_name(side: String) -> String:
	return "near" if side == "left" else "far"


## De qué lado llega la próxima cosa de esa clase ("foot", "machine", "ambulance", "delivery").
func next_side(kind: String) -> String:
	var side := force_side if force_side != "" else VehicleSpace.arrival_side(kind, _arrivals)
	_arrivals += 1
	return side


## Postes de luz de la calle (centros, en celdas de la casa) para que la gente los rodee.
func pole_circles() -> Array:
	var circles: Array = []
	if world == null or world.neighborhood == null:
		return circles
	var shift := Vector3(lot.x / 2.0, 0.0, lot.y / 2.0)
	for position_world in world.neighborhood.lamp_positions:
		circles.append(position_world + shift)
	return circles


## Camino a pie desde `from` pasando por `targets` (en orden), rodeando los postes.
func walk_route(from: Vector3, targets: Array) -> Array:
	var points: Array = [from]
	points.append_array(targets)
	var clear := float(VehicleSpace.data().get("walk", {}).get("pole_clear", 0.5))
	var routed := VehicleSpace.avoid_circles(points, pole_circles(), clear)
	routed.remove_at(0)
	return routed


## Dónde pisa la gente al bajarse de un vehículo estacionado (del lado de tu parcela).
func exit_point(vehicle: Node3D) -> Vector3:
	var size: Vector2 = vehicle.get_meta("footprint", Vector2(3.5, 1.9))
	return vehicle.position + Vector3(0.0, 0.0, -(size.y / 2.0 + 0.5))


# --- Vehículos: aparecer, andar sin chocar, estacionar, irse ---

## Un vehículo nuevo al extremo de la calle, en su carril, mirando hacia donde va.
func spawn_vehicle(kind: String, side: String) -> Node3D:
	var vehicle := make_vehicle(kind)
	var size := VehicleSpace.footprint(kind)
	var x := _start_x(side)
	# Si ya hay otro vehículo justo ahí (dos equipos que llegan a la vez), este arranca más atrás.
	for attempt in 8:
		if not _spawn_taken(x, lane_z(side), _heading(side), size):
			break
		x -= _dir(side) * (size.x + VehicleSpace.road_value("follow_gap", 0.6) + 1.0)
	vehicle.position = Vector3(x, 0.0, lane_z(side))
	vehicle.rotation.y = _heading(side)
	vehicle.set_meta("side", side)
	vehicle.set_meta("parked", false)
	add_child(vehicle)
	_vehicles.append(vehicle)
	return vehicle


func _spawn_taken(x: float, z: float, yaw: float, size: Vector2) -> bool:
	var mine := Vector2(size.y / 2.0, size.x / 2.0 + 0.5)
	for other in _vehicles:
		if is_instance_valid(other) and VehicleSpace.rects_overlap(Vector2(x, z), yaw, mine,
				Vector2(other.position.x, other.position.z), other.rotation.y, _half(other, false)):
			return true
	return false


## Lo saca de la calle.
func retire(vehicle: Node3D) -> void:
	_vehicles.erase(vehicle)
	if is_instance_valid(vehicle):
		vehicle.queue_free()


## Todos los que están estacionados ahora (para pruebas y demos).
func parked_vehicles() -> Array:
	var result: Array = []
	for curb in _parked:
		for entry in _parked[curb]:
			result.append(entry["node"])
	return result


func vehicle_count() -> int:
	return _vehicles.size()


## Espera a que no venga un vehículo en sentido contrario (las dos manos se cruzarían).
func wait_road(side: String) -> void:
	var waited := 0.0
	while waited < VehicleSpace.road_value("max_wait", 12.0):
		var busy := false
		for vehicle in _vehicles:
			if is_instance_valid(vehicle) and not vehicle.get_meta("parked", false) \
					and str(vehicle.get_meta("side", side)) != side:
				busy = true
		if not busy:
			return
		await get_tree().create_timer(0.4).timeout
		waited += 0.4


## Medio ancho y medio largo (con el aire que guarda con el de adelante).
func _half(vehicle: Node3D, with_gap: bool) -> Vector2:
	var size: Vector2 = vehicle.get_meta("footprint", Vector2(3.5, 1.9))
	var gap := VehicleSpace.road_value("follow_gap", 0.6) if with_gap else 0.0
	return Vector2(size.y / 2.0, size.x / 2.0 + gap)


## ¿Chocaría con otro vehículo que tiene ADELANTE si se mueve a `next_position`?
func _is_blocked(vehicle: Node3D, next_position: Vector3, direction: Vector3) -> bool:
	var mine := _half(vehicle, true)
	for other in _vehicles:
		if other == vehicle or not is_instance_valid(other):
			continue
		var ahead: Vector3 = other.position - vehicle.position
		if ahead.x * direction.x + ahead.z * direction.z <= 0.0:
			continue  # Está atrás: no estorba.
		if VehicleSpace.rects_overlap(Vector2(next_position.x, next_position.z), vehicle.rotation.y, mine,
				Vector2(other.position.x, other.position.z), other.rotation.y, _half(other, false)):
			return true
	return false


## Maneja un vehículo por los puntos, girando suave. Si hay otro adelante, espera (hasta
## `max_wait` segundos; después sigue para no trabarse nunca).
func _drive(vehicle: Node3D, points: Array, speed: float) -> void:
	var max_wait := VehicleSpace.road_value("max_wait", 12.0)
	for point in points:
		var target: Vector3 = point
		var waited := 0.0
		while is_instance_valid(vehicle):
			var to_target: Vector3 = target - vehicle.position
			to_target.y = 0.0
			var distance := to_target.length()
			if distance < 0.03:
				break
			var delta := get_process_delta_time()
			var direction := to_target / distance
			vehicle.rotation.y = lerp_angle(vehicle.rotation.y, atan2(direction.x, direction.z), clampf(6.0 * delta, 0.0, 1.0))
			var step := minf(distance, speed * speed_scale * delta)
			var next_position: Vector3 = vehicle.position + direction * step
			if waited < max_wait and _is_blocked(vehicle, next_position, direction):
				waited += delta
				await get_tree().process_frame
				continue
			vehicle.position = next_position
			await get_tree().process_frame
		if not is_instance_valid(vehicle):
			return


## Se estaciona junto al cordón lo más cerca posible de `desired_x`. Devuelve el centro x.
func park(vehicle: Node3D, side: String, desired_x: float) -> float:
	var kind := str(vehicle.get_meta("kind", "van"))
	var size := VehicleSpace.footprint(kind)
	var curb := _curb_name(side)
	var taken: Array = []
	for entry in _parked[curb]:
		taken.append(Vector2(entry["min"], entry["max"]))
	for span in _reserved.values():
		taken.append(span)
	var parking: Dictionary = VehicleSpace.data().get("parking", {})
	var margin := float(parking.get("margin", 1.0))
	var slot := VehicleSpace.find_slot(taken, desired_x, size.x, margin,
		-float(parking.get("range_before", 40.0)), lot.x + float(parking.get("range_after", 40.0)), -_dir(side))
	if slot == INF:
		slot = desired_x  # Calle llena: no debería pasar; se queda donde pidió.
	var direction := _dir(side)
	var lane := lane_z(side)
	var curb_line := curb_z(side, kind)
	var entry := {"node": vehicle, "min": slot - size.x / 2.0 - margin / 2.0, "max": slot + size.x / 2.0 + margin / 2.0}
	_parked[curb].append(entry)  # Se reserva ya, para que otro no elija el mismo lugar.
	await _drive(vehicle, [Vector3(slot - direction * 9.0, 0.0, lane), Vector3(slot - direction * 2.0, 0.0, curb_line),
		Vector3(slot, 0.0, curb_line)], drive_speed())
	if is_instance_valid(vehicle):
		vehicle.rotation.y = _heading(side)
		vehicle.set_meta("parked", true)
	return slot


## Sale del lugar, vuelve a su carril y se va por donde iba (sin vuelta en U).
func unpark(vehicle: Node3D, side: String) -> void:
	await wait_road(side)
	if not is_instance_valid(vehicle):
		return
	var curb := _curb_name(side)
	for entry in _parked[curb].duplicate():
		if entry["node"] == vehicle:
			_parked[curb].erase(entry)
	vehicle.set_meta("parked", false)
	var kind := str(vehicle.get_meta("kind", "van"))
	var direction := _dir(side)
	var x := vehicle.position.x
	await _drive(vehicle, [Vector3(x + direction * 2.5, 0.0, curb_z(side, kind)), Vector3(x + direction * 9.0, 0.0, lane_z(side)),
		Vector3(_end_x(side), 0.0, lane_z(side))], drive_speed())
	retire(vehicle)


## Puntos de la calle hasta la entrada de un camino y de vuelta (se dejan por compatibilidad;
## ahora los vehículos usan spawn_vehicle / park / unpark).
func road_in(first_cell: Vector2i) -> Array:
	var x := first_cell.x + 0.5
	return [Vector3(_start_x("left"), 0, lane_z("left")), Vector3(x, 0, road_z), Vector3(x, 0, sidewalk_z)]


func road_out(first_cell: Vector2i) -> Array:
	var x := first_cell.x + 0.5
	return [Vector3(x, 0, sidewalk_z), Vector3(x, 0, road_z), Vector3(_end_x("left"), 0, lane_z("left"))]


# --- Movimiento a pie ---

## Mueve `node` por `points` (en orden) a `speed` m/s, mirando hacia donde va. Los vehículos
## usan _drive (giran suave y no se atraviesan); la gente, un movimiento simple.
func travel(node: Node3D, points: Array, speed: float) -> void:
	if node.has_meta("footprint"):
		await _drive(node, points, speed)
		return
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


func path_points(cells: Array, vehicle: bool) -> Array:
	var points: Array = []
	var shift := 1.0 if vehicle else 0.5  # El bloque de un vehículo mide 2 x 2.
	for cell in cells:
		points.append(Vector3(cell.x + shift, 0, cell.y + shift))
	return points


func _reversed(points: Array) -> Array:
	var copy := points.duplicate()
	copy.reverse()
	return copy


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

## La clave del equipo: la máquina (tractor, retroexcavadora) o, si no hay, el servicio.
static func crew_key(def: Dictionary) -> String:
	var machine := str(def.get("vehicle", ""))
	return machine if machine != "" else str(def.get("service", ""))


func _entry(job: Dictionary) -> Vector2i:
	var path: Array = job["route"].get("path", [])
	return path[0] if not path.is_empty() else Vector2i(lot.x / 2, lot.y - 1)


## ¿Ya hay un equipo de esa clase en camino o trabajando? (para pruebas)
func has_crew(key: String) -> bool:
	return _crews.has(key) and _crews[key]["open"]


## Llega el servicio para limpiar el obstáculo `o`. `route` es el resultado de
## ParcelRules.find_path (path de celdas, de la calle al lugar). Si `blocked`, el equipo llega,
## avisa que no puede entrar y sigue. Si ya hay un equipo de ese tipo en marcha, este obstáculo
## se suma a su lista (los atiende uno tras otro); si es de otro tipo, viene otro vehículo.
func run_clear(o: Dictionary, def: Dictionary, route: Dictionary, blocked: bool) -> void:
	var machine := str(def.get("vehicle", "")) != ""
	var job := {"o": o, "def": def, "route": route, "blocked": blocked}
	var key := crew_key(def)
	_handled[str(o["id"])] = true
	if machine:
		var entry := _entry(job)
		_reserved[str(o["id"])] = Vector2(entry.x - 2.0, entry.x + 4.0)
	if _crews.has(key) and _crews[key]["open"]:
		_crews[key]["queue"].append(job)
		return
	var crew := {"key": key, "service": str(def.get("service", "")), "queue": [job], "open": true, "machine": machine}
	_crews[key] = crew
	if machine:
		_run_machine_crew(crew)
	else:
		_run_foot_crew(crew)


## ¿Hay otro obstáculo del mismo equipo que llega pronto? Si sí, espera un segundo y dice true.
func _linger(crew: Dictionary) -> bool:
	var seconds := float(VehicleSpace.data().get("crew", {}).get("linger_seconds", 30.0))
	var soon := false
	for id in Parcel.pending:
		if _handled.has(str(id)):
			continue
		var def := Parcel.definition(str(id))
		if def.is_empty() or crew_key(def) != crew["key"]:
			continue
		if int(Parcel.pending[id]["ready_at"]) - Economy.now() <= seconds:
			soon = true
	if soon:
		await get_tree().create_timer(1.0 / speed_scale).timeout
	return soon


func _close_crew(crew: Dictionary) -> void:
	if _crews.get(crew["key"]) == crew:
		_crews.erase(crew["key"])
	running -= 1


func _done(job: Dictionary, ok: bool, blocked: bool, reason: String) -> void:
	var id := str(job["o"]["id"])
	_handled.erase(id)
	_reserved.erase(id)
	finished.emit({"id": id, "kind": "clear", "ok": ok, "blocked": blocked, "reason": reason})


## Equipo a pie (jardinero, leñador): una camioneta se estaciona y la persona va obstáculo por obstáculo.
func _run_foot_crew(crew: Dictionary) -> void:
	running += 1
	var info := VehicleSpace.crew_info(str(crew["service"]))
	var role := str(info.get("role", "driver"))
	var vehicle_kind := str(info.get("vehicle", "van"))
	if vehicle_kind == "":
		vehicle_kind = "van"
	var side := next_side("foot")
	await wait_road(side)
	var van := spawn_vehicle(vehicle_kind, side)
	Sound.play("truck")
	await park(van, side, float(_entry(crew["queue"][0]).x) + 0.5)
	var worker := make_worker(role)
	worker.position = exit_point(van)
	add_child(worker)
	Fx.puff(self, worker.position + Vector3(0, 0.5, 0), 5, Color(0.9, 0.9, 0.9, 0.7))
	var gate_open := false
	while true:
		if crew["queue"].is_empty():
			var again: bool = await _linger(crew)
			if crew["queue"].is_empty() and not again:
				crew["open"] = false
				break
			continue
		var job: Dictionary = crew["queue"].pop_front()
		var o: Dictionary = job["o"]
		var route: Dictionary = job["route"]
		var path: Array = route.get("path", [])
		if job["blocked"] or path.is_empty():
			_bubble(worker, "No hay paso")
			await get_tree().create_timer(2.5 / speed_scale).timeout
			_done(job, false, true, str(route.get("reason", "No hay paso.")))
			continue
		var first: Vector2i = path[0]
		await travel(worker, walk_route(worker.position, [Vector3(first.x + 0.5, 0, sidewalk_z)]), WALK_SPEED * 1.6)
		if not gate_open:
			gate_open = true
			if gate_handler.is_valid():
				await gate_handler.call()
		await travel(worker, path_points(path, false), WALK_SPEED * 1.6)
		var target := Vector3(o["x"] + o["w"] / 2.0, 0.0, o["z"] + o["d"] / 2.0)
		await _work_at(worker, target, float(job["def"].get("seconds", 20)) * 0.08 + 3.0, role)
		cut_finished.emit(str(o["id"]))
		await travel(worker, _reversed(path_points(path, false)), WALK_SPEED * 1.6)
		_done(job, true, false, "")
	# Vuelve a la camioneta, sube y se van.
	await travel(worker, walk_route(worker.position, [Vector3(worker.position.x, 0, sidewalk_z), exit_point(van)]), WALK_SPEED * 1.6)
	worker.queue_free()
	await unpark(van, side)
	_close_crew(crew)


## Equipo con máquina (tractor, retroexcavadora): la máquina entra sola hasta el obstáculo. Los
## obstáculos se atienden de izquierda a derecha (sin vuelta en U); si llegan más mientras
## trabaja, vuelve a venir.
func _run_machine_crew(crew: Dictionary) -> void:
	running += 1
	while true:
		var jobs: Array = crew["queue"].duplicate()
		crew["queue"].clear()
		if jobs.is_empty():
			var again: bool = await _linger(crew)
			if crew["queue"].is_empty() and not again:
				crew["open"] = false
				break
			continue
		jobs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _entry(a).x < _entry(b).x)
		await _machine_trip(jobs)
	_close_crew(crew)


func _machine_trip(jobs: Array) -> void:
	var kind := str(jobs[0]["def"].get("vehicle", "tractor"))
	var side := next_side("machine")
	await wait_road(side)
	var machine := spawn_vehicle(kind, side)
	Sound.play("truck")
	var lane := lane_z(side)
	var speed := drive_speed()
	for job in jobs:
		var o: Dictionary = job["o"]
		var route: Dictionary = job["route"]
		var path: Array = route.get("path", [])
		var entry_x := float(_entry(job).x) + 1.0
		# Por el carril hasta un poco antes de la entrada y gira hacia la acera.
		var approach: Array = []
		if machine.position.x < entry_x - 5.0:
			approach.append(Vector3(entry_x - 5.0, 0, lane))
		approach.append(Vector3(entry_x, 0, sidewalk_z if not (job["blocked"] or path.is_empty()) else lane))
		await _drive(machine, approach, speed)
		if job["blocked"] or path.is_empty():
			_bubble(machine, "No puedo entrar: no hay camino libre")
			Sound.play("truck")
			await get_tree().create_timer(3.2 / speed_scale).timeout
			_done(job, false, true, str(route.get("reason", "No hay camino libre.")))
			continue
		await _drive(machine, path_points(path, true), speed * 0.5)
		var target := Vector3(o["x"] + o["w"] / 2.0, 0.0, o["z"] + o["d"] / 2.0)
		await _work_at(machine, target, float(job["def"].get("seconds", 20)) * 0.08 + 4.0, kind)
		cut_finished.emit(str(o["id"]))
		await _drive(machine, _reversed(path_points(path, true)), speed * 0.5)
		await _drive(machine, [Vector3(entry_x, 0, sidewalk_z), Vector3(entry_x + 5.0, 0, lane)], speed)
		_done(job, true, false, "")
	await _drive(machine, [Vector3(_end_x(side), 0, lane)], speed)
	retire(machine)


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
	var blocked := Parcel.blocked_now()
	blocked.erase("%d,%d" % [cell.x, cell.y])
	var house_cells := {}
	if house != null:
		for key in house.get_layer(0, "foundation"):
			house_cells[key] = true
	var route := ParcelRules.find_path(Parcel.cfg, blocked, house_cells, target, false)
	if route["ok"] and not route["path"].is_empty():
		return path_points(route["path"], false)
	return [Vector3(cell.x + 0.5, 0, lot.y - 1.0), Vector3(cell.x + 0.5, 0, cell.y + 0.5)]


## La ambulancia llega por su carril y se estaciona (como cualquier otro vehículo); un
## paramédico cruza hasta el personaje lastimado esquivando los postes, lo revisa y lo
## cura; vuelve, sube y la ambulancia se va hacia adelante (sin retroceder sobre nada).
func run_ambulance(patient: Character) -> void:
	running += 1
	var gate_x := lot.x / 2.0 + 0.5
	var side := next_side("ambulance")
	await wait_road(side)
	var ambulance := spawn_vehicle("ambulance", side)
	Sound.play("siren")
	var siren: MeshInstance3D = ambulance.find_child("Siren", true, false)
	await park(ambulance, side, gate_x)
	var medic := make_worker("paramedic")
	medic.position = exit_point(ambulance)
	add_child(medic)
	var points := person_path_to(patient.cell)
	var gate_point := Vector3(gate_x, 0, sidewalk_z)
	await travel(medic, walk_route(medic.position, [gate_point] + points), WALK_SPEED * 1.8)
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
	await travel(medic, walk_route(medic.position, _reversed(points) + [gate_point, exit_point(ambulance)]), WALK_SPEED * 1.8)
	medic.queue_free()
	await unpark(ambulance, side)
	running -= 1
	finished.emit({"id": "ambulance", "kind": "ambulance", "ok": true, "blocked": false, "reason": ""})
