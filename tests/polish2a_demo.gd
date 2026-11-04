extends Node
## Demostración del Pulido 2A (errores y claridad), con capturas.
##
## Correr desde la terminal (abre una ventana unos segundos):
##   godot --path . res://tests/polish2a_demo.tscn
## Las capturas (p2a_*.png) van a SHOT_DIR (o a user://).
## OJO: como las otras demos, usa una casa de prueba (no guarda sobre la partida
## si se corre con una carpeta de datos aparte).
##
## Prueba: menú hamburguesa (cerrar), márgenes, ángulo de cámara, el techo
## "trabado", el basurero con todo, Agregar piso, el selector de frente y la
## construcción planificada con factura.

var _main: Node3D
var _hud: CanvasLayer
var _builder: HouseBuilder
var _house: HouseData
var _shot_dir := ""
var _passed := 0
var _failed := 0
var _shots: Array[String] = []


func _ready() -> void:
	_shot_dir = OS.get_environment("SHOT_DIR")
	if _shot_dir == "":
		_shot_dir = OS.get_user_data_dir()
	_main = preload("res://scenes/main.tscn").instantiate()
	add_child(_main)
	Economy.debug_unlock_all()
	_hud = _main.get_node("HUD")
	_builder = _main.get_node("House/Builder")
	_house = _main.house
	_run.call_deferred()


func _run() -> void:
	_build_test_house()
	_main.set_mode("live")
	_main._set_level(0)
	await _frames(10)

	await _test_menu_and_margins()
	await _test_camera_pitch()
	await _test_stuck_roof()
	await _test_erase_everything()
	await _test_add_floor()
	await _test_plan_and_invoice()

	print("\nDEMO PULIDO 2A: %d pasaron, %d fallaron · capturas: %s" % [_passed, _failed, ", ".join(_shots)])
	get_tree().quit(1 if _failed > 0 else 0)


# --- Casa de prueba: 8x7 con una puerta, una ventana, un techo y un mueble ---

func _build_test_house() -> void:
	_house.from_dict({"lot_size": [HouseGrid.LOT_SIZE.x, HouseGrid.LOT_SIZE.y]})
	_house.floor_count = 1  # La partida guardada por otra demo pudo dejar pisos agregados.
	var writes: Array = []
	for c in HouseGrid.cells_in_rect(Vector2i(11, 12), Vector2i(18, 18)):
		writes.append(HouseData.write(0, "foundation", HouseGrid.cell_key(c), {"item": "foundation_basic"}))
		writes.append(HouseData.write(0, "floors", HouseGrid.cell_key(c), {"item": "floor_basic"}))
	for edge in HouseGrid.edges_around_rect(Vector2i(11, 12), Vector2i(18, 18)):
		writes.append(HouseData.write(0, "walls", edge, {"item": "wall_basic"}))
	writes.append(HouseData.write(0, "walls", "h:13,19", {"item": "wall_basic", "opening": "door_basic"}))
	writes.append(HouseData.write(0, "walls", "h:16,19", {"item": "wall_basic", "opening": "window_basic"}))
	writes.append(HouseData.write(0, "walls", "h:12,19", {"item": "wall_basic", "opening": "window_basic"}))
	writes.append(HouseData.write(0, "objects", "o2", {"item": "bed_basic", "cell": [12, 13], "rot": 0}))
	_house.next_id = 10
	_house.apply(writes)
	var character: Character = _main.get_node("House/Character")
	character.place_at(0, Vector2i(13, 16))
	_builder.plan_enabled = false
	_main.get_node("CameraRig").set_state({"x": 0.0, "z": 0.0, "yaw": 0.0, "distance": 18.0})


func _test_menu_and_margins() -> void:
	print("\n1) Menú hamburguesa y márgenes")
	var menu: Control = _hud.get_node("%SideMenu")
	var button: Button = _hud.get_node("%MenuButton")
	_click_control(button)
	await _frames(3)
	_check(menu.visible, "tocar el menú lo abre")
	await _shot("p2a_1_menu_abierto.png")
	_click_control(button)
	await _frames(3)
	_check(not menu.visible, "tocarlo otra vez lo cierra")
	_click_control(button)
	await _frames(3)
	_click_at(Vector2(300, 400))  # Afuera.
	await _frames(3)
	_check(not menu.visible, "tocar afuera lo cierra")
	var root: MarginContainer = _hud.get_node("Root")
	_check(root.get_theme_constant("margin_top") >= 30 and root.get_theme_constant("margin_bottom") >= 18,
		"márgenes arriba (%d) y abajo (%d)" % [root.get_theme_constant("margin_top"), root.get_theme_constant("margin_bottom")])


func _test_camera_pitch() -> void:
	print("\n2) Ángulo vertical de la cámara")
	var rig: CameraRig = _main.get_node("CameraRig")
	var seen := {}
	for i in CameraRig.PITCH_PRESETS.size():
		seen[snappedf(rig.pitch_degrees, 0.1)] = true
		_hud._pitch_button.pressed.emit()
		await _frames(2)
	_check(seen.size() == CameraRig.PITCH_PRESETS.size(), "el botón recorre los %d ángulos (de frente a desde arriba)" % seen.size())
	rig.set_pitch(CameraRig.PITCH_PRESETS[0])
	await _frames(3)
	await _shot("p2a_2_camara_de_frente.png")
	_check(is_equal_approx(rig.get_state()["pitch"], CameraRig.PITCH_PRESETS[0]), "el ángulo se guarda con la cámara")
	rig.set_pitch(-50.0)
	await _frames(2)


func _test_stuck_roof() -> void:
	print("\n3) El techo \"trabado\" se puede borrar")
	# Edición vieja: un techo en el piso 3, sin nada construido en 1 y 2.
	_house.apply([HouseData.write(3, "roofs", "o50", {"item": "roof_basic", "rect": [12, 13, 4, 4]})])
	_check(_house.floors_total() == 4, "el piso 3 existe porque tiene un techo")
	_main.set_mode("build")
	var map: FloorMap = _hud.get_node("%FloorMap")
	await _frames(4)
	_check(map.shown_levels() == 4, "el selector de pisos ofrece los 4 pisos")
	map.level_picked.emit(3)
	await _frames(4)
	_check(_builder.level == 3, "se puede ir al piso 3 (estás en %d)" % _builder.level)
	var view: HouseView = _main.get_node("House")
	if not view.show_roofs:
		EventBus.view_roofs_toggle_requested.emit()
	var bar: BuildBar = _hud.get_node("%BottomBar")
	bar._tool_buttons["build"].button_pressed = true
	bar._mode_buttons["erase"].button_pressed = true
	await _frames(3)
	var roof_point := Vector3(14.0, HouseGrid.level_y(3) + HouseGrid.WALL_HEIGHT + 0.8, 15.0)
	_main.get_node("CameraRig").set_state({"x": -2.0, "z": -1.0, "yaw": 0.0, "distance": 18.0})
	await _frames(3)
	await _tap(_screen(roof_point))
	await _frames(3)
	var confirm: Button = _hud.get_node("%ConfirmButton")
	_check(confirm.visible, "tocar el techo con el basurero pregunta (\"%s\")" % _hud.get_node("%HintLabel").text)
	await _shot("p2a_3_borrar_techo_piso3.png")
	confirm.pressed.emit()
	await _frames(4)
	_check(not _house.has_piece(3, "roofs", "o50"), "el techo se borró")
	_check(_house.floors_total() == 1, "y el piso fantasma desapareció (pisos: %d, agregados: %d, más alto con algo: %d)" % [_house.floors_total(), _house.floor_count, _house.used_top_level()])
	_main._set_level(0)
	await _frames(2)


func _test_erase_everything() -> void:
	print("\n4) El basurero borra cualquier pieza")
	var bar: BuildBar = _hud.get_node("%BottomBar")
	bar._tool_buttons["build"].button_pressed = true
	bar._mode_buttons["erase"].button_pressed = true
	await _frames(2)
	var tests := [
		[0, "walls", "h:14,12", "pared"],
		[0, "objects", "o2", "mueble"],
		[0, "floors", "15,15", "piso"],
		[0, "foundation", "18,18", "cimientos"],
	]
	var confirm: Button = _hud.get_node("%ConfirmButton")
	for t in tests:
		var entry := _builder._erase_entry({"level": t[0], "layer": t[1], "key": t[2]})
		_check(not entry.is_empty(), "%s: se puede elegir para borrar" % t[3])
		_builder._erase_items = [entry]
		_builder._ask_erase()
		await _frames(2)
		_check(confirm.visible and confirm.text.begins_with("Borrar"), "%s: pregunta \"%s\"" % [t[3], confirm.text])
		if t[1] == "foundation":
			await _shot("p2a_4_borrar_cimientos.png")
		confirm.pressed.emit()
		await _frames(3)
		_check(not _house.has_piece(t[0], t[1], t[2]), "%s: borrado" % t[3])
	_check(HouseRules.problems(_house).filter(func(p): return p["layer"] != "").is_empty(), "no quedó nada en el aire")
	_build_test_house()
	await _frames(3)


func _test_add_floor() -> void:
	print("\n5) Agregar piso")
	_main.set_mode("build")
	_main._set_level(0)
	var bar: BuildBar = _hud.get_node("%BottomBar")
	bar._tool_buttons["build"].button_pressed = true
	bar._mode_buttons["add"].button_pressed = true
	await _frames(2)
	var map: FloorMap = _hud.get_node("%FloorMap")
	_check(map.shown_levels() == 1, "una casa de un piso muestra 1 piso (sin piso de regalo)")
	# Todo techado: avisa.
	_house.apply([HouseData.write(0, "roofs", "o60", {"item": "roof_basic", "rect": [11, 12, 8, 7]})])
	var toasts: Array = []
	var on_toast := func(text: String) -> void: toasts.append(text)
	EventBus.toast.connect(on_toast)
	EventBus.build_add_floor_requested.emit()
	await _frames(3)
	EventBus.toast.disconnect(on_toast)
	_check(toasts.has("Para agregar un piso tiene que haber una parte sin techo."), "todo techado: avisa \"%s\"" % ("; ".join(toasts)))
	_check(_house.floors_total() == 1, "no se agregó el piso")
	_house.apply([HouseData.write(0, "roofs", "o60", null)])
	EventBus.build_add_floor_requested.emit()
	await _frames(4)
	_check(_house.floors_total() == 2 and _builder.level == 1, "con una parte sin techo, agrega el piso y va a él")
	await _frames(3)
	_check(map.shown_levels() == 2, "el selector muestra 2 pisos")
	# Dos pisos con algo para mostrar el frente.
	var writes: Array = []
	for c in HouseGrid.cells_in_rect(Vector2i(11, 12), Vector2i(18, 18)):
		writes.append(HouseData.write(1, "floors", HouseGrid.cell_key(c), {"item": "floor_tile"}))
	for edge in HouseGrid.edges_around_rect(Vector2i(12, 13), Vector2i(17, 17)):
		writes.append(HouseData.write(1, "walls", edge, {"item": "wall_basic"}))
	writes.append(HouseData.write(1, "walls", "h:14,18", {"item": "wall_basic", "opening": "window_basic"}))
	_house.apply(writes)
	_house.apply([HouseData.write(1, "roofs", "o61", {"item": "roof_basic", "rect": [12, 13, 5, 5]})])
	await _frames(4)
	await _shot("p2a_5_fachada_2_pisos.png")
	# Girar la fachada: 8 ángulos y se recuerda.
	var start := map.angle_index
	for i in 3:
		map.turn(1)
	await _frames(3)
	_check(map.angle_index == (start + 3) % 8 and GameState.settings["floor_front_angle"] == map.angle_index, "girar la fachada se recuerda (ángulo %d)" % map.angle_index)
	await _shot("p2a_6_fachada_girada.png")
	# Flechitas arriba y abajo.
	EventBus.build_level_change_requested.emit(-1)
	await _frames(2)
	_check(_builder.level == 0, "la flecha de abajo baja un piso")
	EventBus.build_level_change_requested.emit(1)
	await _frames(2)
	_check(_builder.level == 1, "la flecha de arriba sube un piso")
	_main._set_level(0)


func _test_plan_and_invoice() -> void:
	print("\n6) Construcción planificada y factura")
	_builder.plan_enabled = true
	var money := Economy.money
	var bar: BuildBar = _hud.get_node("%BottomBar")
	bar._tool_buttons["build"].button_pressed = true
	bar._mode_buttons["add"].button_pressed = true
	await _frames(2)
	# Dos tramos de cimientos con el gesto de arrastrar (se acumulan en el plan).
	for pair in [[Vector2i(20, 12), Vector2i(23, 13)], [Vector2i(20, 14), Vector2i(23, 15)]]:
		await _drag_cells(pair[0], pair[1])
	_check(_builder.has_draft() and _builder.draft_mode() == "plan", "lo agregado queda como plan (previsto)")
	_check(Economy.money == money, "todavía no se cobró nada")
	_check(_house.has_piece(0, "foundation", "20,12"), "los cimientos previstos se ven en la casa")
	var view: HouseView = _main.get_node("House")
	_check(not view._planned_materials.is_empty(), "las piezas previstas tienen material que brilla")
	var peak := 0.0
	for i in 40:
		await get_tree().process_frame
		for mat in view._planned_materials:
			peak = maxf(peak, mat.emission_energy_multiplier)
		if peak > 0.2:
			break
	await get_tree().create_timer(0.6).timeout
	var glowing := false
	for i in 120:
		await get_tree().process_frame
		for mat in view._planned_materials:
			if mat.emission_energy_multiplier > 0.5:
				glowing = true
		if glowing:
			break
	_check(glowing or peak > 0.2, "las piezas previstas brillan cada pocos segundos (pico %.2f)" % peak)
	await _shot("p2a_7_obra_prevista.png")
	var invoice: Dictionary = _builder.plan_invoice()
	_check(invoice["lines"].size() == 1 and invoice["lines"][0]["qty"] == 16 and invoice["total"] > 0,
		"la factura: %s, total $%d" % [str(invoice["lines"]), invoice["total"]])
	_hud._show_invoice()
	await _frames(3)
	var popup: Node = _hud._popup
	_check(popup != null and popup.find_children("*", "Button", true, false).size() == 3, "la factura tiene Confirmar, Seguir y Descartar")
	await _shot("p2a_8_factura.png")
	# Seguir planeando no cambia nada.
	_hud._close_popup()
	_check(_builder.has_draft() and Economy.money == money, "seguir planeando no cobra")
	_hud._show_invoice()
	await _frames(2)
	# Confirmar: se cobra y corre el tiempo de espera.
	for b in _hud._popup.find_children("*", "Button", true, false):
		if b.text == "Confirmar y construir":
			b.pressed.emit()
	await _frames(8)
	_check(not _builder.has_draft(), "confirmado: ya no hay plan")
	_check(Economy.money == money - invoice["total"], "se cobró la factura: $%d (de $%d a $%d)" % [invoice["total"], money, Economy.money])
	_check(_house.has_piece(0, "foundation", "23,15"), "los cimientos quedaron construidos")
	await _shot("p2a_9_construyendo.png")
	# Descartar vuelve todo atrás.
	await _drag_cells(Vector2i(20, 17), Vector2i(23, 17))
	_check(_builder.draft_mode() == "plan" and _house.has_piece(0, "foundation", "20,17"), "otro plan")
	EventBus.plan_discard_requested.emit()
	await _frames(3)
	_check(not _builder.has_draft() and not _house.has_piece(0, "foundation", "20,17"), "descartar saca lo previsto")


func _drag_cells(from_cell: Vector2i, to_cell: Vector2i) -> void:
	EventBus.build_item_selected.emit("foundation_basic")
	await _frames(1)
	var cam := get_viewport().get_camera_3d()
	var house_node: Node3D = _main.get_node("House")
	var a := cam.unproject_position(house_node.to_global(Vector3(from_cell.x + 0.5, HouseGrid.level_y(0), from_cell.y + 0.5)))
	var b := cam.unproject_position(house_node.to_global(Vector3(to_cell.x + 0.5, HouseGrid.level_y(0), to_cell.y + 0.5)))
	_builder._begin(a)
	for i in range(1, 5):
		_builder._update(a.lerp(b, i / 4.0))
	_builder._release()
	_builder.confirm_pending()
	await _frames(3)


# --- Ayudantes ---

func _screen(local: Vector3) -> Vector2:
	var house_node: Node3D = _main.get_node("House")
	return get_viewport().get_camera_3d().unproject_position(house_node.to_global(local))


func _tap(pos: Vector2) -> void:
	_click_at(pos)
	await _frames(2)


func _click_control(control: Control) -> void:
	_click_at(control.get_global_rect().get_center())


func _click_at(pos: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = pos
		event.global_position = pos
		get_viewport().push_input(event)


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
