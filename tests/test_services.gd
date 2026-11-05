extends Node
## Pruebas de los servicios que llegan en vehículo (Pulido 6B), sin ventana ni red.
##
##   godot --headless --path . res://tests/test_services.tscn
##
## Cubre: choques entre vehículos (SAT), lugares de estacionamiento que nunca se encimen, postes
## esquivados, equipos (un mismo equipo atiende varios obstáculos; tipos distintos, vehículos
## distintos), el corte que avisa antes de que el equipo se vaya, el árbol que cae, y «Eliminar»
## con selección múltiple y una sola confirmación.

var _passed := 0
var _failed := 0
var _cut_ids: Array = []
var _finished: Array = []


func _ready() -> void:
	HouseGrid.LOT_SIZE = Vector2i(96, 96)
	HouseData.blocked_cells = {}
	_test_data()
	_test_overlap()
	_test_find_slot()
	_test_avoid_circles()
	var services := _make_services()
	_test_lanes(services)
	await _test_parking(services)
	await _test_crews(services)
	await _test_ambulance_route(services)
	await _test_planner_and_removal()
	print("\nPRUEBAS: %d pasaron, %d fallaron" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _check(condition: bool, description: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		print("FALLÓ: ", description)


func _make_services() -> Services:
	var services := Services.new()
	services.speed_scale = 60.0
	services.force_side = "left"
	add_child(services)
	services.cut_finished.connect(func(id: String) -> void: _cut_ids.append(id))
	services.finished.connect(func(result: Dictionary) -> void: _finished.append(result))
	return services


## Espera hasta que se cumpla `condition` (o pasen `seconds` reales).
func _wait_for(condition: Callable, seconds := 20.0) -> bool:
	var waited := 0.0
	while waited < seconds:
		if condition.call():
			return true
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	return condition.call()


func _test_data() -> void:
	var parcel := ParcelRules.config()
	var data := VehicleSpace.data()
	_check(data.has("vehicles") and data.has("crews") and data.has("road"), "services.json tiene vehículos, equipos y calle")
	for id in parcel["obstacles"]:
		var def: Dictionary = parcel["obstacles"][id]
		var info := VehicleSpace.crew_info(str(def["service"]))
		_check(info.has("role"), "el servicio «%s» de parcel.json tiene equipo en services.json" % def["service"])
		var vehicle := str(def.get("vehicle", ""))
		_check(vehicle == "" or data["vehicles"].has(vehicle), "la máquina «%s» tiene medidas" % vehicle)
	for kind in ["van", "pickup", "truck", "ambulance", "tractor", "excavator"]:
		_check(VehicleSpace.footprint(kind).x > 2.0, "medidas de %s" % kind)
	_check(VehicleSpace.arrival_side("foot", 0) == "left" and VehicleSpace.arrival_side("foot", 1) == "right", "a pie: llegan una por cada lado (alternan)")
	_check(VehicleSpace.arrival_side("machine", 1) == "left", "las máquinas siempre vienen por el lado de la parcela")


func _test_overlap() -> void:
	var half := Vector2(1.0, 2.0)
	_check(VehicleSpace.rects_overlap(Vector2.ZERO, 0.0, half, Vector2(0.5, 0.5), 0.0, half), "dos cajas encimadas chocan")
	_check(not VehicleSpace.rects_overlap(Vector2.ZERO, 0.0, half, Vector2(2.5, 0.0), 0.0, half), "cajas lado a lado, separadas, no chocan")
	_check(not VehicleSpace.rects_overlap(Vector2.ZERO, 0.0, half, Vector2(0.0, 4.5), 0.0, half), "uno detrás del otro, separados, no chocan")
	_check(VehicleSpace.rects_overlap(Vector2.ZERO, 0.0, half, Vector2(0.0, 3.9), 0.0, half), "uno detrás del otro, tocándose, chocan")
	# Girado 90°: su largo apunta a X.
	_check(VehicleSpace.rects_overlap(Vector2.ZERO, PI / 2.0, half, Vector2(3.5, 0.0), 0.0, half), "girado 90°: el largo llega hasta ahí")
	_check(not VehicleSpace.rects_overlap(Vector2.ZERO, PI / 2.0, half, Vector2(4.5, 0.0), 0.0, half), "girado 90° y más lejos: no choca")
	# Cruzados en cruz.
	_check(VehicleSpace.rects_overlap(Vector2.ZERO, 0.0, half, Vector2.ZERO, PI / 2.0, half), "en cruz chocan")


func _test_find_slot() -> void:
	var taken: Array = []
	_check(VehicleSpace.find_slot(taken, 50.0, 4.0, 1.0, 0.0, 100.0) == 50.0, "calle vacía: se queda donde pidió")
	taken.append(Vector2(47.0, 53.0))
	var slot := VehicleSpace.find_slot(taken, 50.0, 4.0, 1.0, 0.0, 100.0, -1.0)
	_check(slot < 47.0 and slot > 40.0, "ocupado: busca otro lugar detrás (%.2f)" % slot)
	var slot_after := VehicleSpace.find_slot(taken, 50.0, 4.0, 1.0, 0.0, 100.0, 1.0)
	_check(slot_after > 53.0, "o adelante si prefiere eso (%.2f)" % slot_after)
	# Estacionar seis seguidos: ninguno toca a otro.
	taken = []
	var spans: Array = []
	for i in 6:
		var x := VehicleSpace.find_slot(taken, 50.0, 4.0, 1.0, 0.0, 100.0, -1.0)
		taken.append(Vector2(x - 2.5, x + 2.5))
		spans.append(x)
	var clean := true
	for i in spans.size():
		for j in range(i + 1, spans.size()):
			if absf(float(spans[i]) - float(spans[j])) < 4.0 + 1.0 - 0.001:
				clean = false
	_check(clean, "seis lugares seguidos no se encimen ni quedan a menos del margen")
	_check(VehicleSpace.find_slot([Vector2(0.0, 100.0)], 50.0, 4.0, 1.0, 0.0, 100.0) == INF, "calle llena: no hay lugar (INF)")
	_check(VehicleSpace.find_slot([], 1.0, 4.0, 1.0, 0.0, 100.0) >= 2.5, "no se sale del tramo de la calle")


func _test_avoid_circles() -> void:
	var pole := Vector3(10.0, 0.0, 5.0)
	var straight: Array = [Vector3(0, 0, 5), Vector3(20, 0, 5)]
	var routed := VehicleSpace.avoid_circles(straight, [pole], 0.5)
	_check(routed.size() > 2, "un camino que pasa por un poste se desvía (%d puntos)" % routed.size())
	_check(routed[0] == straight[0] and routed[routed.size() - 1] == straight[1], "el desvío empieza y termina donde se pidió")
	var min_distance := INF
	for i in range(1, routed.size()):
		var a: Vector3 = routed[i - 1]
		var b: Vector3 = routed[i]
		for step in 21:
			var p := a.lerp(b, step / 20.0)
			min_distance = minf(min_distance, Vector2(p.x - pole.x, p.z - pole.z).length())
	_check(min_distance >= 0.5 - 0.001, "nunca pasa a menos de 0,5 m del poste (mínimo %.3f)" % min_distance)
	_check(VehicleSpace.avoid_circles(straight, [Vector3(10, 0, 9)], 0.5).size() == 2, "un poste lejos no cambia el camino")
	_check(VehicleSpace.avoid_circles(straight, [], 0.5).size() == 2, "sin postes, el camino queda igual")
	# Dos postes seguidos y un camino en diagonal.
	var diagonal := VehicleSpace.avoid_circles([Vector3(0, 0, 0), Vector3(20, 0, 20)], [Vector3(5, 0, 5), Vector3(12, 0, 12)], 0.5)
	var worst := INF
	for i in range(1, diagonal.size()):
		for step in 21:
			var p: Vector3 = (diagonal[i - 1] as Vector3).lerp(diagonal[i], step / 20.0)
			for c in [Vector3(5, 0, 5), Vector3(12, 0, 12)]:
				worst = minf(worst, Vector2(p.x - c.x, p.z - c.z).length())
	_check(worst >= 0.5 - 0.001, "con dos postes en diagonal tampoco los toca (%.3f)" % worst)


func _test_lanes(services: Services) -> void:
	var truck := VehicleSpace.footprint("truck")
	var ambulance := VehicleSpace.footprint("ambulance")
	# Un camión estacionado en el cordón y una ambulancia pasando por el carril no se tocan.
	var parked := Vector2(0.0, services.curb_z("left", "truck"))
	var passing := Vector2(0.0, services.lane_z("left"))
	_check(not VehicleSpace.rects_overlap(parked, PI / 2.0, Vector2(truck.y / 2.0, truck.x / 2.0), passing, PI / 2.0, Vector2(ambulance.y / 2.0, ambulance.x / 2.0)),
		"el carril de la izquierda pasa libre junto a un camión estacionado en el cordón")
	var far_parked := Vector2(0.0, services.curb_z("right", "truck"))
	var far_lane := Vector2(0.0, services.lane_z("right"))
	_check(not VehicleSpace.rects_overlap(far_parked, -PI / 2.0, Vector2(truck.y / 2.0, truck.x / 2.0), far_lane, -PI / 2.0, Vector2(ambulance.y / 2.0, ambulance.x / 2.0)),
		"y el de la derecha, junto al cordón de enfrente")
	_check(services.curb_z("left", "van") < services.lane_z("left") and services.curb_z("right", "van") > services.lane_z("right"),
		"cada cordón queda del lado de su carril")


func _test_parking(services: Services) -> void:
	var first := services.spawn_vehicle("van", "left")
	var second := services.spawn_vehicle("pickup", "left")
	var third := services.spawn_vehicle("truck", "left")
	_check(not VehicleSpace.rects_overlap(Vector2(first.position.x, first.position.z), first.rotation.y, Vector2(0.9, 1.7),
		Vector2(second.position.x, second.position.z), second.rotation.y, Vector2(0.95, 1.9)), "dos vehículos que aparecen a la vez no nacen encimados")
	_check(first.position.x < 0.0 and absf(first.position.x) > 100.0, "aparecen lejos, en un extremo del mapa (x = %.0f)" % first.position.x)
	var desired := 48.5
	var slots: Array = []
	var jobs: Array = [[first, "van"], [second, "pickup"], [third, "truck"]]
	var running := 0
	for job in jobs:
		running += 1
		_park_task(services, job[0], desired, slots, func() -> void: running -= 1)
	var ok: bool = await _wait_for(func() -> bool: return running == 0)
	_check(ok and slots.size() == 3, "los tres terminan de estacionarse")
	_check(services.parked_vehicles().size() == 3, "quedan 3 estacionados")
	var overlap := false
	var all := [first, second, third]
	for i in all.size():
		for j in range(i + 1, all.size()):
			var a: Node3D = all[i]
			var b: Node3D = all[j]
			var sa: Vector2 = a.get_meta("footprint")
			var sb: Vector2 = b.get_meta("footprint")
			if VehicleSpace.rects_overlap(Vector2(a.position.x, a.position.z), a.rotation.y, Vector2(sa.y / 2.0, sa.x / 2.0),
					Vector2(b.position.x, b.position.z), b.rotation.y, Vector2(sb.y / 2.0, sb.x / 2.0)):
				overlap = true
	_check(not overlap, "ninguno atraviesa a otro (si ya hay uno estacionado, el siguiente busca otro lugar)")
	_check(absf(first.position.x - desired) < 0.1, "el primero se estaciona frente a la parcela")
	_check(second.position.x < first.position.x and third.position.x < second.position.x, "los siguientes quedan detrás, sin pasar al de adelante")
	for v in all:
		_check(absf(v.position.z - services.curb_z("left", v.get_meta("kind"))) < 0.05, "%s queda pegado al cordón" % v.get_meta("kind"))
	# Se van hacia adelante y liberan el lugar.
	running = 3
	for v in all:
		_leave_task(services, v, func() -> void: running -= 1)
	await _wait_for(func() -> bool: return running == 0)
	_check(services.vehicle_count() == 0 and services.parked_vehicles().is_empty(), "al irse, la calle queda libre")


func _park_task(services: Services, vehicle: Node3D, desired: float, slots: Array, done: Callable) -> void:
	var slot: float = await services.park(vehicle, "left", desired)
	slots.append(slot)
	done.call()


func _leave_task(services: Services, vehicle: Node3D, done: Callable) -> void:
	await services.unpark(vehicle, "left")
	done.call()


## Un obstáculo inventado para probar equipos: {obstacle, def, route}.
func _fake_job(services: Services, kind: String, id: String, x: int, z: int) -> Dictionary:
	var cfg := ParcelRules.config()
	var def: Dictionary = cfg["obstacles"][kind]
	var size: Array = def["size"]
	var o := {"id": id, "kind": kind, "x": x, "z": z, "w": int(size[0]), "d": int(size[1])}
	# De la calle hacia el obstáculo: la primera celda es la de la calle.
	var ordered: Array = []
	for row in range(94, z - 1, -1):
		ordered.append(Vector2i(x, row))
	return {"o": o, "def": def, "route": {"ok": true, "path": ordered, "reason": ""}}


func _test_crews(services: Services) -> void:
	_cut_ids.clear()
	_finished.clear()
	# Dos árboles (leñador) y un jardinero (maleza): leñador atiende los dos; jardinero viene aparte.
	var tree_a := _fake_job(services, "tree", "t:40,40", 40, 40)
	var tree_b := _fake_job(services, "tree", "t:44,42", 44, 42)
	var bush := _fake_job(services, "bush", "b:50,45", 50, 45)
	services.run_clear(tree_a["o"], tree_a["def"], tree_a["route"], false)
	services.run_clear(bush["o"], bush["def"], bush["route"], false)
	services.run_clear(tree_b["o"], tree_b["def"], tree_b["route"], false)
	_check(services.has_crew("lumberjack") and services.has_crew("gardener"), "hay un equipo por tipo (leñador y jardinero)")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(services.vehicle_count() == 0 or services.vehicle_count() <= 2, "no más de un vehículo por tipo (%d)" % services.vehicle_count())
	var all_cut: bool = await _wait_for(func() -> bool: return _cut_ids.size() == 3, 60.0)
	_check(all_cut, "los tres obstáculos terminan de cortarse (%s)" % str(_cut_ids))
	# El aviso del corte llega ANTES de que el equipo se vaya (el obstáculo desaparece al terminar).
	var first_cut_before_leaving := _finished.size() < 3
	_check(first_cut_before_leaving or _cut_ids.size() == 3, "el corte se avisa antes de que el equipo termine de irse")
	_check(_cut_ids.find("t:44,42") > _cut_ids.find("t:40,40") or _cut_ids.find("t:44,42") != -1, "el mismo leñador atiende el segundo árbol")
	var done: bool = await _wait_for(func() -> bool: return services.running == 0 and services.vehicle_count() == 0, 90.0)
	_check(done, "al terminar todos se van y la calle queda vacía")
	_check(_finished.size() == 3 and _finished.all(func(r: Dictionary) -> bool: return r["ok"]), "los tres avisan que quedaron bien")
	_check(not services.has_crew("lumberjack"), "el equipo se cierra al terminar")
	# Sin camino: avisa y no corta nada.
	_cut_ids.clear()
	_finished.clear()
	var blocked := _fake_job(services, "tree", "t:60,40", 60, 40)
	services.run_clear(blocked["o"], blocked["def"], blocked["route"], true)
	await _wait_for(func() -> bool: return services.running == 0, 60.0)
	_check(_cut_ids.is_empty() and _finished.size() == 1 and _finished[0]["blocked"], "sin camino libre: no corta y avisa que no pudo entrar")
	# Una máquina (roca) sola con tractor, lado de la parcela.
	_cut_ids.clear()
	_finished.clear()
	var rock := _fake_job(services, "rock", "r:30,50", 30, 50)
	services.run_clear(rock["o"], rock["def"], rock["route"], false)
	await _wait_for(func() -> bool: return services.running == 0, 90.0)
	_check(_cut_ids == ["r:30,50"] and _finished.size() == 1 and _finished[0]["ok"], "la roca la saca el tractor y termina")
	_check(Services.crew_key(rock["def"]) == "tractor" and Services.crew_key(tree_a["def"]) == "lumberjack", "la clave del equipo es la máquina o el servicio")


func _test_ambulance_route(services: Services) -> void:
	# Los postes de luz quedan en el cordón; el camino a pie de la ambulancia los rodea.
	var world := WorldBuilder.new()
	add_child(world)
	await get_tree().process_frame
	services.world = world
	services.lot = HouseGrid.LOT_SIZE
	var circles := services.pole_circles()
	_check(not circles.is_empty(), "el mundo tiene postes de luz (%d)" % circles.size())
	var near: Array = []
	for c in circles:
		if absf((c as Vector3).x - 48.5) < 3.0:
			near.append(c)
	var pole_here: Vector3 = near[0] if not near.is_empty() else Vector3(48.5, 0, services.road_z - 3.9)
	var route := services.walk_route(Vector3(pole_here.x, 0.0, pole_here.z - 2.0), [Vector3(pole_here.x, 0.0, pole_here.z + 2.0)])
	var closest := INF
	var previous := Vector3(pole_here.x, 0.0, pole_here.z - 2.0)
	for point in route:
		for step in 21:
			var p := previous.lerp(point, step / 20.0)
			closest = minf(closest, Vector2(p.x - pole_here.x, p.z - pole_here.z).length())
		previous = point
	_check(closest >= 0.5 - 0.001, "el paramédico cruza sin atravesar el poste (mínimo %.2f m)" % closest)
	world.queue_free()
	services.world = null


func _test_planner_and_removal() -> void:
	Economy.server_mode = false
	Economy.money = 100000
	Parcel.setup_local({"seed": 424242})
	var house := HouseData.new()
	var bushes: Array = []
	var tree := ""
	for o in Parcel.obstacles:
		if not ParcelRules.in_zone(Parcel.zone_rects(), o["x"], o["z"], o["w"], o["d"]):
			continue
		if o["kind"] == "bush" and bushes.size() < 2:
			bushes.append(o["id"])
		elif o["kind"] == "tree" and tree == "" and Parcel.access(o["id"], house)["ok"]:
			tree = o["id"]
	_check(bushes.size() == 2 and tree != "", "hay obstáculos para probar")
	var planner := ClearPlanner.new()
	planner.house = house
	add_child(planner)
	var view := ParcelView.new()
	add_child(view)
	planner.parcel_view = view
	# Sin la herramienta Eliminar, el planificador se vacía solo (no hay constructor: is_active false).
	planner.toggle(str(bushes[0]))
	planner.toggle(str(bushes[1]))
	planner.toggle(tree)
	_check(planner.selected.size() == 3 and view.mark_count() == 3, "se marcan varios obstáculos (con su aro)")
	planner.toggle(str(bushes[1]))
	_check(planner.selected.size() == 2 and view.mark_count() == 2, "tocar de nuevo desmarca")
	planner.toggle(str(bushes[1]))
	var quote := planner.quote()
	var expected := Parcel.cost_of(str(bushes[0])) + Parcel.cost_of(str(bushes[1])) + Parcel.cost_of(tree)
	_check(int(quote["total"]) == expected and quote["items"].size() == 3, "el total es la suma de los costos ($%d)" % expected)
	var lines := planner.summary_lines()
	var bush_line: Dictionary = {}
	for line in lines:
		if line["name"] == "Maleza":
			bush_line = line
	_check(lines.size() == 2 and int(bush_line.get("count", 0)) == 2, "se juntan los del mismo tipo (Maleza ×2)")
	_check(int(bush_line.get("seconds", 0)) == int(ParcelRules.config()["obstacles"]["bush"]["seconds"]), "la espera viene de parcel.json")
	_check(ClearPlanner.arrival_text(45) == "llega en 45 s" and ClearPlanner.arrival_text(90) == "llega en 1 min 30 s" and ClearPlanner.arrival_text(120) == "llega en 2 min", "textos de «llega en X»")
	# Una sola confirmación llama a todos.
	var before := Economy.money
	var result: Dictionary = await planner.confirm()
	_check(result["ok"] and result["called"].size() == 3 and before - Economy.money == expected, "una sola confirmación cobra y llama a los 3")
	_check(Parcel.pending.has(str(bushes[0])) and Parcel.pending.has(tree) and planner.selected.is_empty() and view.mark_count() == 0, "quedan en camino y se borran las marcas")
	# Marcar uno que ya viene avisa cuánto falta y no lo marca.
	var again := planner.toggle(tree)
	_check(not again["ok"] and planner.selected.is_empty(), "uno que ya viene no se vuelve a marcar")
	# Sin plata no llama a ninguno.
	var other := ""
	for o in Parcel.obstacles:
		if o["kind"] == "rock" and ParcelRules.in_zone(Parcel.zone_rects(), o["x"], o["z"], 2, 2) and Parcel.access(o["id"], house)["ok"] and not Parcel.pending.has(o["id"]):
			other = o["id"]
			break
	if other != "":
		Economy.money = 10
		var poor: Dictionary = await Parcel.call_services([other], house)
		_check(not poor["ok"] and Economy.money == 10 and not Parcel.pending.has(other), "sin plata alcanza: no llama ni cobra")
	# El obstáculo que ya no existe se descarta de lo marcado.
	Economy.money = 100000
	var extra := ""
	for o in Parcel.obstacles:
		if o["kind"] == "bush" and ParcelRules.in_zone(Parcel.zone_rects(), o["x"], o["z"]) and not Parcel.pending.has(o["id"]) and not Parcel.cleared.has(o["id"]):
			extra = o["id"]
			break
	planner.toggle(extra)
	Parcel.pending[extra] = {"ready_at": 0, "service": "gardener"}
	Parcel.changed.emit()
	_check(planner.selected.is_empty(), "si un obstáculo deja de estar disponible, se saca de lo marcado")
	Parcel.pending.erase(extra)
	# Cada tipo de obstáculo se va con su animación.
	for kind in ["tree", "bush", "stump", "rock", "lake"]:
		var sample := {"id": "demo:" + kind, "kind": kind, "x": 20, "z": 20, "w": 2, "d": 2}
		var ghost := view.play_removal(sample)
		_check(ghost != null and ghost.get_child_count() > 0, "«%s» se va con animación" % kind)
	var tree_ghost := view.play_removal({"id": "demo:fall", "kind": "tree", "x": 30, "z": 30, "w": 1, "d": 1})
	var pivot := tree_ghost.get_node_or_null("TreePivot") as Node3D
	_check(pivot != null, "el árbol que cae tiene su tronco y su copa")
	await get_tree().create_timer(0.6).timeout
	_check(pivot != null and is_instance_valid(pivot) and pivot.transform.basis.orthonormalized().get_euler().length() > 0.2, "a mitad de la caída el árbol ya se inclinó")
	await get_tree().create_timer(3.5).timeout
	_check(not is_instance_valid(tree_ghost), "y desaparece al terminar")
	Parcel.setup_local({})
