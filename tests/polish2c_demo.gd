extends Node
## Demostración del Pulido 2C (parcela, servicios y entregas), con capturas.
##
##   godot --path . res://tests/polish2c_demo.tscn
## Las capturas (p2c_*.png) van a SHOT_DIR (o a user://). Partida local (sin
## servidor); las esperas se aceleran (los servicios andan 5 veces más rápido).

var _main: Node3D
var _hud: CanvasLayer
var _house: HouseData
var _character: Character
var _builder: HouseBuilder
var _services: Services
var _delivery: Delivery
var _shot_dir := ""
var _passed := 0
var _failed := 0
var _shots: Array[String] = []


func _ready() -> void:
	_shot_dir = OS.get_environment("SHOT_DIR")
	if _shot_dir == "":
		_shot_dir = OS.get_user_data_dir()
	HouseGrid.LOT_SIZE = Vector2i(96, 96)
	HouseData.blocked_cells = {}
	Economy.server_mode = false
	GameState.parcel = {"seed": 424242}
	Parcel.setup_local({"seed": 424242})
	GameState.delivery = {}
	_main = preload("res://scenes/main.tscn").instantiate()
	add_child(_main)
	Economy.debug_unlock_all()
	_hud = _main.get_node("HUD")
	_house = _main.house
	_character = _main.get_node("House/Character")
	_builder = _main.get_node("House/Builder")
	_builder.plan_enabled = false
	_services = _main.get_node("House/Services")
	_delivery = _main.get_node("House/Delivery")
	_services.speed_scale = 6.0
	_run.call_deferred()


func _run() -> void:
	_build_test_house()
	_main.set_mode("live")
	_main._set_level(0)
	await _frames(12)
	# P2C_ONLY=delivery: solo la entrega y la ambulancia (para probar más rápido).
	if OS.get_environment("P2C_ONLY") != "delivery":
		await _test_world_and_obstacles()
		await _test_person_service()
		await _test_vehicle_service()
		await _test_blocked_vehicle()
	await _test_delivery()
	await _test_ambulance()
	await _test_basement()
	print("\nDEMO PULIDO 2C: %d pasaron, %d fallaron · capturas: %s" % [_passed, _failed, ", ".join(_shots)])
	get_tree().quit(1 if _failed > 0 else 0)


func _build_test_house() -> void:
	# La casa de 8 x 7 en el centro de la parcela (la zona de la casa original).
	var o := HouseGrid.home_origin() + Vector2i(8, 8)
	_house.from_dict({"lot_size": [96, 96]})
	_house.floor_count = 1
	var writes: Array = []
	for c in HouseGrid.cells_in_rect(o, o + Vector2i(7, 6)):
		writes.append(HouseData.write(0, "foundation", HouseGrid.cell_key(c), {"item": "foundation_basic"}))
		writes.append(HouseData.write(0, "floors", HouseGrid.cell_key(c), {"item": "floor_basic"}))
	for edge in HouseGrid.edges_around_rect(o, o + Vector2i(7, 6)):
		writes.append(HouseData.write(0, "walls", edge, {"item": "wall_basic"}))
	var door := "h:%d,%d" % [o.x + 2, o.y + 7]
	writes.append(HouseData.write(0, "walls", door, {"item": "wall_basic", "opening": "door_basic"}))
	writes.append(HouseData.write(0, "objects", "o2", {"item": "bed_basic", "cell": [o.x + 1, o.y + 1], "rot": 0}))
	_house.next_id = 10
	_house.apply(writes)
	_character.place_at(0, o + Vector2i(3, 3))
	var rig: CameraRig = _main.get_node("CameraRig")
	rig.set_state({"x": 0.0, "z": 0.0, "yaw": 0.0, "distance": 30.0, "pitch": -45.0})


func _nearest(kind: String) -> Dictionary:
	var center := Vector2(48, 74)
	var best: Dictionary = {}
	var best_distance := INF
	for o in Parcel.obstacles:
		if o["kind"] != kind or Parcel.cleared.has(o["id"]) or Parcel.pending.has(o["id"]):
			continue
		var distance := Vector2(o["x"], o["z"]).distance_to(center)
		if distance < best_distance:
			best_distance = distance
			best = o
	return best


func _test_world_and_obstacles() -> void:
	print("\n1) La parcela de 96 x 96 con obstáculos")
	_check(HouseGrid.LOT_SIZE == Vector2i(96, 96) and _main.get_node("House").position == Vector3(-48, 0, -48), "la casa se centra en una parcela de 96")
	_check(Parcel.obstacles.size() == 546 and _house.has_piece(0, "foundation", "%d,%d" % [HouseGrid.home_origin().x + 8, HouseGrid.home_origin().y + 8]),
		"%d obstáculos y la casa en la zona del centro" % Parcel.obstacles.size())
	var view: ParcelView = _main.get_node("House/ParcelView")
	_check(view.get_node_or_null("ObstacleTrunks") != null and view.get_children().any(func(c): return c.name.begins_with("Lake_")),
		"hay árboles, rocas, tocones, maleza y un laguito")
	var rig: CameraRig = _main.get_node("CameraRig")
	rig.set_state({"x": 0.0, "z": 10.0, "yaw": 30.0, "distance": 70.0, "pitch": -40.0})
	await _frames(5)
	await _shot("p2c_1_parcela.png")
	_check(Engine.get_frames_per_second() > 0, "FPS con la parcela de 96 (en esta máquina de la nube): %d" % Engine.get_frames_per_second())
	rig.set_state({"x": 0.0, "z": 3.0, "yaw": 0.0, "distance": 30.0, "pitch": -45.0})
	# Construir encima de un obstáculo está prohibido.
	var near := _nearest("tree")
	var key := "%d,%d" % [near["x"], near["z"]]
	_check(not HouseRules.is_supported(_house, 0, "foundation", key, {"item": "foundation_basic"}), "no se puede construir encima de un árbol")


func _tap_obstacle(o: Dictionary) -> void:
	var cam := get_viewport().get_camera_3d()
	var local := Vector3(o["x"] + o["w"] / 2.0, 0.3, o["z"] + o["d"] / 2.0)
	var screen := cam.unproject_position(_main.get_node("House").to_global(local))
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = screen
		event.global_position = screen
		get_viewport().push_input(event)
	await _frames(3)


func _popup_button(text_start: String) -> Button:
	if _hud._popup == null:
		return null
	for b in _hud._popup.find_children("*", "Button", true, false):
		if b.text.begins_with(text_start):
			return b
	return null


func _test_person_service() -> void:
	print("\n2) Limpiar con una persona (jardinero): cobra, espera, el personaje abre la puerta")
	var bush := _nearest("bush")
	var rig: CameraRig = _main.get_node("CameraRig")
	rig.set_state({"x": bush["x"] - 48.0 + 4.0, "z": bush["z"] - 48.0 - 3.0, "yaw": 0.0, "distance": 22.0, "pitch": -50.0})
	await _frames(4)
	await _tap_obstacle(bush)
	var call := _popup_button("Llamar servicio")
	_check(call != null and not call.disabled, "tocar la maleza muestra «Llamar servicio» (%s)" % (call.text if call != null else "sin botón"))
	await _shot("p2c_2_obstaculo.png")
	var money := Economy.money
	call.pressed.emit()
	await _frames(4)
	_check(Parcel.pending.has(bush["id"]) and Economy.money == money - 15, "cobró $15 y el servicio quedó en camino")
	# Pasa la espera real: ya llega.
	Parcel.pending[bush["id"]]["ready_at"] = Economy.now() - 1
	Parcel.check_now()
	var seen_worker := false
	var seen_open_gate := false
	var waited := 0.0
	while not Parcel.cleared.has(bush["id"]) and waited < 60.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
		if _services.get_children().any(func(c): return c.name.begins_with("Worker_gardener")):
			if not seen_worker:
				seen_worker = true
				_focus("Worker_gardener", 12.0)
				await _frames(3)
				await _shot("p2c_3_jardinero.png")
		if _character.state == Character.State.WALKING and _character._plan.has("gate"):
			seen_open_gate = true
	_check(seen_open_gate or _character._bubble.text == "¡Adelante!", "el personaje fue a abrirle la puerta al jardinero")
	_check(seen_worker, "llegó el jardinero")
	_check(Parcel.cleared.has(bush["id"]) and not HouseData.blocked_cells.has("%d,%d" % [bush["x"], bush["z"]]), "quedó limpio (%.0f s)" % waited)
	_check(Parcel.count == 1 and Parcel.cost_of(_nearest("rock")["id"]) == 255, "y el próximo servicio cuesta un poco más")


func _test_vehicle_service() -> void:
	print("\n3) Limpiar con vehículo pesado (tractor para rocas)")
	var rock := _nearest("rock")
	var rig: CameraRig = _main.get_node("CameraRig")
	rig.set_state({"x": rock["x"] - 48.0 + 6.0, "z": rock["z"] - 48.0 + 5.0, "yaw": 0.0, "distance": 30.0, "pitch": -45.0})
	var access := Parcel.access(rock["id"], _house)
	_check(access["ok"], "hay camino libre desde la calle hasta la roca (%d celdas)" % access["path"].size())
	var money := Economy.money
	var result: Dictionary = await Parcel.call_service(rock["id"], _house)
	_check(result["ok"] and Economy.money == money - 255, "llamar al servicio cobró $255")
	Parcel.pending[rock["id"]]["ready_at"] = Economy.now() - 1
	Parcel.check_now()
	var seen_tractor := false
	var waited := 0.0
	while not Parcel.cleared.has(rock["id"]) and waited < 90.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
		if not seen_tractor and _services.get_children().any(func(c): return c.name == "Vehicle_tractor"):
			seen_tractor = true
			_focus("Vehicle_tractor", 14.0)
			await _frames(3)
			await _shot("p2c_4_tractor.png")
	_check(seen_tractor, "llegó el tractor por la calle")
	_check(Parcel.cleared.has(rock["id"]), "la roca quedó limpia (%.0f s)" % waited)


func _test_blocked_vehicle() -> void:
	print("\n4) Sin camino libre, el vehículo avisa que no puede entrar")
	var lake := Parcel.obstacle("l:2,88")
	var def := Parcel.definition("l:2,88")
	# Con todo el frente tapado por una casa larga, no hay camino.
	var wall := HouseData.new()
	var writes: Array = []
	for x in 96:
		writes.append(HouseData.write(0, "foundation", HouseGrid.cell_key(Vector2i(x, 94)), {"item": "foundation_basic"}))
	wall.apply(writes)
	var route := Parcel.access("l:2,88", wall)
	_check(not route["ok"] and str(route["reason"]).contains("vehículo"), "el servidor y el teléfono coinciden: \"%s\"" % route["reason"])
	var rig: CameraRig = _main.get_node("CameraRig")
	rig.set_state({"x": -30.0, "z": 30.0, "yaw": 0.0, "distance": 30.0, "pitch": -40.0})
	var seen_excavator := false
	# (Una función "lambda" copia las variables simples: se usa un diccionario compartido.)
	var box := {"done": false, "result": {}}
	_services.finished.connect(func(r: Dictionary) -> void:
		box["result"] = r
		box["done"] = true, CONNECT_ONE_SHOT)
	_services.run_clear(lake, def, route, true)
	var waited := 0.0
	while not box["done"] and waited < 60.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
		if not seen_excavator and _services.get_children().any(func(c): return c.name == "Vehicle_excavator"):
			seen_excavator = true
			await get_tree().create_timer(1.5).timeout
			_focus("Vehicle_excavator", 16.0)
			await _frames(3)
			await _shot("p2c_5_no_puede_entrar.png")
	var result: Dictionary = box["result"]
	_check(seen_excavator and result.get("blocked", false), "la retroexcavadora llegó y se fue sin poder entrar")
	_check(not Parcel.cleared.has("l:2,88"), "y el laguito sigue ahí")


func _test_delivery() -> void:
	print("\n5) Entrega de compras: camión, caja que se cae, abrir todas las cajas")
	var o := HouseGrid.home_origin() + Vector2i(8, 8)
	var rig: CameraRig = _main.get_node("CameraRig")
	rig.set_state({"x": 0.0, "z": 4.0, "yaw": 0.0, "distance": 28.0, "pitch": -45.0})
	_main.get_node("House").check_construction()
	# Dos muebles comprados: terminan de construirse en 1 s.
	var ready_at := Economy.now() + 1
	_house.apply([
		HouseData.write(0, "objects", "o20", {"item": "sofa_basic", "cell": [o.x + 4, o.y + 4], "rot": 0, "ready_at": ready_at}),
		HouseData.write(0, "objects", "o21", {"item": "chair_basic", "cell": [o.x + 6, o.y + 2], "rot": 0, "ready_at": ready_at}),
	])
	await _frames(5)
	var waited := 0.0
	var truck_seen := false
	while _delivery.dropped_count() < 2 and waited < 90.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
		_main.get_node("House").check_construction()
		if not truck_seen and _services.get_children().any(func(c): return c.name == "Vehicle_truck"):
			truck_seen = true
			await get_tree().create_timer(1.2).timeout
			_focus("Vehicle_truck", 16.0)
			await _frames(3)
			await _shot("p2c_6_camion.png")
	_check(truck_seen, "llegó el camión por la calle")
	_check(_delivery.dropped_count() == 2 and _delivery.is_boxed(0, "o20") and _delivery.is_boxed(0, "o21"), "el repartidor dejó una caja en el lugar de cada cosa (%.0f s)" % waited)
	var view: HouseView = _main.get_node("House")
	_check(view.get_piece_node(0, "objects", "o20") != null and view.get_piece_node(0, "objects", "o20").find_children("*", "MeshInstance3D", true, false).size() <= 3,
		"la pieza se ve como una caja de cartón")
	GameClock.speed = 5  # El personaje venía de la puerta de la calle: que camine más rápido.
	var button: Button = _hud._boxes_button
	_check(button.visible and button.text.contains("2"), "aparece «%s»" % button.text)
	await _shot("p2c_7_cajas.png")
	# La IA no usa una cosa que está en su caja.
	_check(not _character._gather_options().any(func(op): return op["key"] in ["o20", "o21"]), "el personaje no usa lo que sigue en su caja")
	button.pressed.emit()
	var saw_cough := false
	waited = 0.0
	while _delivery.dropped_count() > 0 and waited < 60.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
		if _character.state == Character.State.OPENING and not saw_cough:
			saw_cough = true
			await _shot("p2c_8_abre_caja.png")
	_check(saw_cough and _character._animator.current in ["cough", "idle", "walk"], "el personaje fue a cada caja y tosió")
	await _frames(10)
	_check(_delivery.dropped_count() == 0 and not _delivery.is_boxed(0, "o20") and not button.visible,
		"todas las cajas abiertas: aparece el mueble (cajas: %s, botón: %s, estado: %d, esperó %.0f s, reloj x%d pausado=%s, plan=%s)" % [str(_delivery.boxes), str(button.visible), _character.state, waited, GameClock.speed, str(GameClock.paused), str(_character._plan.keys())])
	_check(view.get_piece_node(0, "objects", "o20") != null, "el sofá está en la casa")
	GameClock.speed = 1
	# Si no se lo ordena, las abre solo (su IA).
	_house.apply([HouseData.write(0, "objects", "o22", {"item": "chair_basic", "cell": [o.x + 5, o.y + 5], "rot": 0})])
	_delivery.boxes["0|o22"] = {"state": "dropped", "level": 0, "key": "o22"}
	_delivery._announce()
	await _frames(3)
	var opened := false
	for attempt in 40:
		_character._set_idle()
		_character._idle_minutes = 0.0
		_character._think()
		for i in 120:
			await get_tree().process_frame
			if not _delivery.is_boxed(0, "o22"):
				opened = true
				break
		if opened:
			break
	_check(opened, "si no se lo ordenan, el personaje abre las cajas solo, cuando quiere")


func _test_ambulance() -> void:
	print("\n6) Ambulancia: una caída por una puerta al vacío (sin muerte ni pérdida de progreso)")
	var o := HouseGrid.home_origin() + Vector2i(8, 8)
	# Un piso alto con una puerta al vacío (hay piso pero no hay balcón del otro lado).
	var upper: Array = []
	for c in HouseGrid.cells_in_rect(o + Vector2i(1, 1), o + Vector2i(5, 4)):
		upper.append(HouseData.write(1, "floors", HouseGrid.cell_key(c), {"item": "floor_tile"}))
	_house.floor_count = 2
	_house.apply(upper)
	var edge := "v:%d,%d" % [o.x + 6, o.y + 2]
	_house.apply([HouseData.write(1, "walls", edge, {"item": "wall_basic", "opening": "door_basic"})])
	_check(_character.level == 0, "el personaje está en la planta baja")
	_character.place_at(1, o + Vector2i(4, 2))
	_character.level = 1
	var void_door := _character._void_door_inside()
	_check(void_door == o + Vector2i(5, 2), "hay una puerta al vacío en el piso 1 (celda de adentro %s)" % str(void_door))
	var energy: float = _character.data.needs["energy"]
	var xp := Economy.xp
	var rig: CameraRig = _main.get_node("CameraRig")
	rig.set_state({"x": 5.0, "z": 3.0, "yaw": 0.0, "distance": 26.0, "pitch": -45.0})
	_character.fall_to(Vector2i(o.x + 7, o.y + 2))
	await _frames(3)
	_check(_character.hurt and _character.state == Character.State.HURT and _character.level == 0, "se cayó y quedó lastimado en el suelo de afuera")
	_check(_character.data.needs["energy"] < energy and Economy.xp == xp, "pierde un poco de energía pero ningún progreso")
	var saw_ambulance := false
	var waited := 0.0
	while _character.hurt and waited < 60.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
		if not saw_ambulance and _services.get_children().any(func(c): return c.name == "Vehicle_ambulance"):
			saw_ambulance = true
			await get_tree().create_timer(1.0).timeout
			_focus("Vehicle_ambulance", 16.0)
			await _frames(3)
			await _shot("p2c_9_ambulancia.png")
	_check(saw_ambulance, "llegó la ambulancia")
	_check(not _character.hurt and _character.state != Character.State.HURT, "lo revisaron y lo curaron (%.0f s)" % waited)
	_check(not (_character.data.journal.is_empty()), "queda anotado en el diario")


func _test_basement() -> void:
	print("\n7) Sótanos: hasta 3 hacia abajo, con excavación antes de los cimientos")
	_character.hurt = false
	_character.place_at(0, HouseGrid.home_origin() + Vector2i(11, 11))
	_character._set_idle()
	_main.set_mode("build")
	_main._set_level(0)
	await _frames(3)
	var o := HouseGrid.home_origin() + Vector2i(9, 9)
	var added: bool = _builder.add_basement()
	_check(added and _house.basement_count == 1, "«Agregar sótano» suma el sótano 1")
	await _frames(4)
	_check(_builder.level == -1 and _hud.get_node("%LevelLabel").text == "Sótano 1", "y se va a él (%s)" % _hud.get_node("%LevelLabel").text)
	var map: FloorMap = _hud.get_node("%FloorMap")
	_check(map.shown_levels() == _house.floors_total() + 1, "el selector de pisos muestra el sótano debajo de la planta baja")
	var world := _main.get_node("World")
	_check(not world.visible and not _main.get_node("House/ParcelView").visible, "bajo tierra se esconde el terreno (la casa se ve «cortada»)")
	var dig := HouseData.write(-1, "excavation", HouseGrid.cell_key(o), {"item": "excavation_basic"})
	var foundation := HouseData.write(-1, "foundation", HouseGrid.cell_key(o), {"item": "foundation_basic"})
	_check(not _builder._check([foundation])["blocked"].is_empty(), "antes de excavar, los cimientos del sótano se rechazan")
	var money := Economy.money
	_check(_builder._check([dig])["blocked"].is_empty(), "excavar sí se puede")
	await _builder._apply([dig])
	_check(Economy.money == money - 30, "excavar cuesta $30 por celda (cobró $%d)" % (money - Economy.money))
	var piece: Dictionary = _house.get_piece(-1, "excavation", HouseGrid.cell_key(o))
	_check(HouseData.is_under_construction(piece), "y tiene espera (como una obra)")
	await _shot("p2c_10_excavando.png")
	# Pasa la espera y ya van los cimientos, el piso y las paredes del sótano.
	piece["ready_at"] = Economy.now() - 1
	_house.apply([HouseData.write(-1, "excavation", HouseGrid.cell_key(o), piece)])
	var build_writes: Array = [foundation, HouseData.write(-1, "floors", HouseGrid.cell_key(o), {"item": "floor_basic"})]
	for edge in HouseGrid.cell_edges(o):
		build_writes.append(HouseData.write(-1, "walls", edge, {"item": "wall_basic"}))
	var check: Dictionary = _builder._check(build_writes)
	_check(check["blocked"].is_empty(), "ya excavado: cimientos, piso y paredes del sótano entran")
	_house.apply(check["ok"])
	await _frames(4)
	_check(_house.has_piece(-1, "walls", HouseGrid.cell_edges(o)[0]) and _house.lowest_level() == -1, "el sótano quedó armado")
	_check(HouseRules.problems(_house).any(func(p): return str(p["text"]).contains("Sótano 1: sin acceso")), "avisa que falta una escalera para llegar")
	var rig: CameraRig = _main.get_node("CameraRig")
	rig.set_state({"x": o.x - 48.0 + 2.0, "z": o.y - 48.0 + 2.0, "yaw": 20.0, "distance": 12.0, "pitch": -50.0})
	await _frames(4)
	await _shot("p2c_11_sotano.png")
	# Un sótano más abajo necesita excavar primero el de arriba (y cimientos en el de arriba).
	_house.basement_count = 2
	var deeper: Dictionary = _builder._check([HouseData.write(-2, "excavation", HouseGrid.cell_key(o), {"item": "excavation_basic"})])
	_check(deeper["blocked"].is_empty(), "el segundo sótano se excava debajo del primero")
	var skipped: Dictionary = _builder._check([HouseData.write(-2, "excavation", HouseGrid.cell_key(o + Vector2i(5, 0)), {"item": "excavation_basic"})])
	_check(not skipped["blocked"].is_empty(), "donde el primero no está excavado, no")
	_main._set_level(0)
	await _frames(3)
	_check(world.visible and _main.get_node("House/ParcelView").visible, "al volver a la planta baja reaparece el terreno")
	# Borrar la excavación se lleva todo lo de adentro.
	var closure := HouseRules.removal_closure(_house, HouseData.write(-1, "excavation", HouseGrid.cell_key(o), null))
	_check(closure.size() >= 3, "borrar la excavación borra también el piso y los cimientos de adentro (%d piezas)" % closure.size())
	_main.set_mode("live")


# --- Ayudantes ---

## Mira a un servicio que está en la calle o en la parcela (para las capturas).
func _focus(name_start: String, distance := 16.0) -> void:
	for child in _services.get_children():
		if child.name.begins_with(name_start):
			var p: Vector3 = child.position
			_main.get_node("CameraRig").set_state({"x": p.x - 48.0, "z": p.z - 48.0, "yaw": 25.0, "distance": distance, "pitch": -35.0})
			return


func _check(condition: bool, description: String) -> void:
	if condition:
		_passed += 1
		print("  OK     ", description)
	else:
		_failed += 1
		print("  FALLÓ  ", description)


func _shot(file_name: String) -> void:
	await _frames(4)
	get_viewport().get_texture().get_image().save_png(_shot_dir.path_join(file_name))
	_shots.append(file_name)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
