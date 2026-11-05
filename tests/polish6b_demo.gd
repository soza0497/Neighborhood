extends Node
## Demostración del Pulido 6B (servicios, personaje y accidentes), con capturas.
##
##   godot --path . res://tests/polish6b_demo.tscn
## Las capturas (p6b_*.png) van a SHOT_DIR (o a user://). Partida local.
## En la nube/PC sin pantalla: SHOT_DIR=docs/capturas xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . res://tests/polish6b_demo.tscn

var _main: Node3D
var _rig: CameraRig
var _character: Character
var _services: Services
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
	_main = preload("res://scenes/main.tscn").instantiate()
	add_child(_main)
	Economy.debug_unlock_all()
	Economy.money = 100000
	_rig = _main.get_node("CameraRig")
	_character = _main.get_node("House/Character")
	_services = _main.get_node("House/Services")
	_run.call_deferred()


func _run() -> void:
	_main.set_mode("live")
	await _frames(10)
	await _sheet_of_expressions()
	await _demo_service_arrives()
	await _demo_tree_falls()
	await _demo_erase_selection()
	await _demo_cloud_on_character()
	await _demo_slip_and_fall()
	await _demo_door_opens()
	await _demo_dev_panel()
	print("\nDEMO PULIDO 6B: %d pasaron, %d fallaron · capturas: %s" % [_passed, _failed, ", ".join(_shots)])
	get_tree().quit(1 if _failed > 0 else 0)


func _check(condition: bool, description: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		print("FALLÓ: ", description)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _shot(file_name: String) -> void:
	await _frames(4)
	get_viewport().get_texture().get_image().save_png(_shot_dir.path_join(file_name))
	_shots.append(file_name)


## Mira hacia un punto de la casa (coordenadas de celdas) desde cerca.
func _look_at_cell(cell: Vector2, distance := 24.0, yaw := 0.0, pitch := -42.0) -> void:
	var half := Vector2(HouseGrid.LOT_SIZE) / 2.0
	_rig.set_state({"x": cell.x - half.x, "z": cell.y - half.y, "yaw": yaw, "distance": distance, "pitch": pitch})


## Una hoja con todas las expresiones (no necesita ventana: se arma con las imágenes).
func _sheet_of_expressions() -> void:
	print("\n1) Hoja de expresiones")
	var ids := ExpressionArt.expression_ids()
	var size := ExpressionArt.canvas_size()
	var columns := 7
	var rows := ceili(float(ids.size()) / float(columns))
	var sheet := Image.create(columns * size.x, rows * size.y, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#9fd3ff"))
	for i in ids.size():
		var cloud := ExpressionArt.render(str(ids[i]))
		cloud.convert(Image.FORMAT_RGBA8)
		sheet.blend_rect(cloud, Rect2i(0, 0, size.x, size.y), Vector2i((i % columns) * size.x, (i / columns) * size.y))
	sheet.save_png(_shot_dir.path_join("p6b_1_expresiones.png"))
	_shots.append("p6b_1_expresiones.png")
	_check(ids.size() >= 25, "la hoja tiene %d expresiones" % ids.size())


func _first_obstacle(kind: String) -> Dictionary:
	for o in Parcel.obstacles:
		if o["kind"] == kind and ParcelRules.in_zone(Parcel.zone_rects(), o["x"], o["z"], o["w"], o["d"]) and Parcel.access(o["id"], _main.house)["ok"]:
			return o
	return {}


## El servicio llega en su camioneta y se estaciona junto al cordón.
func _demo_service_arrives() -> void:
	print("\n2) El servicio llega en vehículo y se estaciona")
	var tree := _first_obstacle("tree")
	_check(not tree.is_empty(), "hay un árbol al que se pueda llegar")
	var result: Dictionary = await Parcel.call_service(tree["id"], _main.house)
	_check(result["ok"], "se llama al servicio")
	_services.speed_scale = 3.0
	_services.force_side = "left"
	Parcel.pending[tree["id"]]["ready_at"] = Economy.now() - 1
	Parcel.service_due.emit(tree["id"])
	var waited := 0.0
	while _services.parked_vehicles().is_empty() and waited < 40.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	_check(not _services.parked_vehicles().is_empty(), "la camioneta se estacionó")
	_look_at_cell(Vector2(48.0, 98.0), 22.0, 0.0, -35.0)
	await _frames(25)
	await _shot("p6b_2_servicio_estacionado.png")
	var guard := 0.0
	while _services.running > 0 and guard < 90.0:
		await get_tree().process_frame
		guard += get_process_delta_time()
	_check(Parcel.cleared.has(tree["id"]), "el árbol quedó limpio")
	_services.speed_scale = 1.0


## El árbol cae, rueda y desaparece (dos cuadros de la animación).
func _demo_tree_falls() -> void:
	print("\n3) El árbol cae y desaparece")
	var tree := _first_obstacle("tree")
	if tree.is_empty():
		return
	_look_at_cell(Vector2(tree["x"] + 0.5, tree["z"] + 0.5), 12.0, 20.0, -35.0)
	var view: ParcelView = _main.get_node("House/ParcelView")
	var ghost := view.play_removal({"id": "demo:fall", "kind": "tree", "x": tree["x"], "z": tree["z"], "w": 1, "d": 1})
	_check(ghost != null, "empieza la caída")
	await get_tree().create_timer(0.55).timeout
	await _shot("p6b_3_arbol_cayendo.png")
	await get_tree().create_timer(1.0).timeout
	await _shot("p6b_3_arbol_rodando.png")
	await get_tree().create_timer(1.6).timeout
	_check(not is_instance_valid(ghost), "y desaparece")


## Eliminar: se marcan varios obstáculos y se confirma una sola vez.
func _demo_erase_selection() -> void:
	print("\n4) Llamar al servicio desde «Eliminar»")
	_main.set_mode("build")
	await _frames(6)
	(_main.get_node("House/Builder") as HouseBuilder).select_item(HouseBuilder.ERASE_TOOL_ID)
	await _frames(4)
	var ids: Array = []
	for kind in ["tree", "bush", "stump"]:
		var o := _first_obstacle(kind)
		if not o.is_empty() and not Parcel.pending.has(o["id"]):
			ids.append(o["id"])
	for id in ids:
		_main._planner.toggle(str(id))
	_check(_main._planner.selected.size() == ids.size() and not ids.is_empty(), "se marcaron %d obstáculos" % ids.size())
	if not ids.is_empty():
		var first := Parcel.obstacle(str(ids[0]))
		_look_at_cell(Vector2(first["x"] + 0.5, first["z"] + 0.5), 26.0, 0.0, -50.0)
	await _frames(10)
	await _shot("p6b_4_eliminar_seleccion.png")
	var result: Dictionary = await _main._planner.confirm()
	_check(result["ok"], "una sola confirmación llama a todos")
	await _shot("p6b_4_eliminar_confirmado.png")
	_main.set_mode("live")
	await _frames(6)


## Una nubecita sobre la cabeza en lugar de un diálogo.
func _demo_cloud_on_character() -> void:
	print("\n5) Nubecita sobre el personaje")
	_character.place_at(0, Character.spawn_cell())
	_character._set_idle()
	_look_at_cell(Vector2(_character.position.x, _character.position.z), 7.0, 15.0, -25.0)
	for id in ["love", "hungry", "zzz"]:
		_character._bubble.show_expression(id, 0.0)
		await _frames(18)
		await _shot("p6b_5_nube_%s.png" % id)
	_character._bubble.clear()


## Un resbalón (piso de baldosa) y una caída desde la puerta de un piso alto.
func _demo_slip_and_fall() -> void:
	print("\n6) Resbalón y caída")
	var origin := _character.cell
	_main.house.apply([HouseData.write(0, "foundation", HouseGrid.cell_key(origin + Vector2i(2, 0)), {"item": "foundation_basic"}),
		HouseData.write(0, "floors", HouseGrid.cell_key(origin + Vector2i(2, 0)), {"item": "floor_tile"})])
	HazardMap.add(0, origin + Vector2i(2, 0), "wet")
	_character.attention = 0.1
	_character.place_at(0, origin)
	_character.force_action({"type": "go", "level": 0, "cell": origin + Vector2i(5, 0)})
	var waited := 0.0
	while _character.last_accident.is_empty() and waited < 20.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	_check(_character.last_accident.get("kind", "") == "slip", "resbaló en el charco sobre la baldosa")
	_look_at_cell(Vector2(_character.position.x, _character.position.z), 7.0, 15.0, -25.0)
	for frame in [0.15, 0.35, 1.0]:
		await get_tree().create_timer(frame).timeout
		await _shot("p6b_6_resbalon_%d.png" % int(frame * 100))
	HazardMap.clear()
	_character.attention = 1.0
	await get_tree().create_timer(2.6).timeout
	_character.force_accident("fall")
	await get_tree().create_timer(0.3).timeout
	await _shot("p6b_6_caida_30.png")
	await get_tree().create_timer(0.7).timeout
	await _shot("p6b_6_caida_100.png")
	_character.recover()


## La puerta se abre hacia su lado cuando el personaje se acerca.
func _demo_door_opens() -> void:
	print("\n7) Puerta que se abre")
	var base := HouseGrid.home_origin() + Vector2i(4, 4)
	var writes: Array = []
	for c in HouseGrid.cells_in_rect(base, base + Vector2i(3, 3)):
		writes.append(HouseData.write(0, "foundation", HouseGrid.cell_key(c), {"item": "foundation_basic"}))
		writes.append(HouseData.write(0, "floors", HouseGrid.cell_key(c), {"item": "floor_basic"}))
	for edge in HouseGrid.edges_around_rect(base, base + Vector2i(3, 3)):
		writes.append(HouseData.write(0, "walls", edge, {"item": "wall_basic"}))
	var door_edge := HouseGrid.edge_key(base + Vector2i(2, 4), true)
	writes.append(HouseData.write(0, "walls", door_edge, {"item": "wall_basic", "opening": "door_basic"}))
	_main.house.apply(writes)
	await _frames(6)
	_look_at_cell(Vector2(base.x + 2.5, base.y + 4.0), 9.0, 25.0, -30.0)
	await _shot("p6b_7_puerta_cerrada.png")
	_character.place_at(0, base + Vector2i(2, 5))
	await _frames(40)
	await _shot("p6b_7_puerta_abierta.png")
	var doors: DoorAnimator = _main.get_node("DoorAnimator")
	_check(doors.open_amount(0, door_edge) > 0.9, "la puerta se abrió al acercarse el personaje")


## El panel del modo desarrollador en una pantalla chica y escondido al construir.
func _demo_dev_panel() -> void:
	print("\n8) Panel del modo desarrollador")
	DevMode.set_enabled(true, _character)
	var hud: CanvasLayer = _main.get_node("HUD")
	var panel: DevPanel = hud.get_node("DevPanel")
	var window := get_window()
	var original := window.size
	window.size = Vector2i(1280, 540)
	await _frames(6)
	panel.open()
	await _frames(8)
	await _shot("p6b_8_panel_dev_pantalla_chica.png")
	var screen := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	_check(screen.encloses(panel.panel_rect()), "el panel entra en la pantalla (%s en %s)" % [str(panel.panel_rect()), str(screen)])
	_main.set_mode("build")
	await _frames(8)
	_check(not panel.is_open(), "al construir el panel no se ve")
	await _shot("p6b_8_panel_dev_oculto_al_construir.png")
	_main.set_mode("live")
	await _frames(4)
	panel.close()
	DevMode.set_enabled(false, _character)
	window.size = original
