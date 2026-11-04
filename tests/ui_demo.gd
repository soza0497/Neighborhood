extends Node
## Demostración de la interfaz nueva (Pulido 1), con capturas.
##
## Correr desde la terminal (abre una ventana unos segundos):
##   godot --path . res://tests/ui_demo.tscn
## Las capturas (ui_*.png) quedan en la carpeta de SHOT_DIR, o en user://
## (en la PC: ~/.local/share/godot/app_userdata/Neighborhood/).
## OJO: como visual_demo, guarda la casa de prueba encima de la partida.
##
## P1A: pantalla limpia, tarjeta del ánimo, Info, maqueta de pisos, íconos
## de techo y paredes, brújula y velocidades.
## P1B: Tienda / Obra / Borrar, pintar una cara, borrar un techo con
## confirmación, silla en diagonal, pared que sostiene, copiar contorno, lo
## que falta, cuartos que recomiendan y borrar varias cosas.

var _main: Node3D
var _hud: CanvasLayer
var _builder: HouseBuilder
var _shot_dir := ""
var _passed := 0
var _failed := 0
var _shots: Array[String] = []


func _ready() -> void:
	HouseGrid.use_test_lot()  # Estas pruebas arman casas en un lote de 32 (la parcela real, desde el Pulido 2C, es de 96).
	_shot_dir = OS.get_environment("SHOT_DIR")
	if _shot_dir == "":
		_shot_dir = OS.get_user_data_dir()
	_main = preload("res://scenes/main.tscn").instantiate()
	add_child(_main)
	Economy.debug_unlock_all()
	_hud = _main.get_node("HUD")
	_builder = _main.get_node("House/Builder")
	_builder.plan_enabled = false  # Estas pruebas construyen de una (sin plan ni factura).
	_run.call_deferred()


func _run() -> void:
	_build_test_house()
	EventBus.camera_reset_requested.emit()
	_main.set_mode("live")
	_main._set_level(0)
	await _frames(10)

	print("\n1) Pantalla de juego limpia")
	_check(_hud.get_node("%MoodLabel").text != "", "arriba: ánimo con palabra (\"%s\")" % _hud.get_node("%MoodLabel").text)
	_check(not _hud.get_node("%InfoPanel").visible and not _hud.get_node("%FpsLabel").visible,
		"FPS, versión y conexión no están sueltos en la pantalla")
	_check(_hud.find_child("NeedsBox", true, false) == null, "ya no está el recuadro de necesidades")
	_check(_hud.get_node("%UndoButton").icon != null and _hud.get_node("%MenuButton").text == "",
		"botones con ícono, sin texto")
	await _shot("ui_1_pantalla.png")

	print("\n2) Tocar el ánimo abre la tarjeta de necesidades")
	_click_control(_hud.get_node("%MoodButton"))
	await _frames(3)
	var card: Control = _hud.get_node("%MoodCard")
	var bars := card.find_children("*", "ProgressBar", true, false)
	_check(card.visible and bars.size() == CharacterData.NEEDS.size(), "tarjeta abierta con %d barras" % bars.size())
	_check(card.find_children("*", "TextureRect", true, false).size() >= 4, "cada necesidad con su ícono")
	await _shot("ui_2_animo.png")
	_click_at(Vector2(900, 500))  # Tocar afuera.
	await _frames(3)
	_check(not card.visible, "tocar afuera la cierra")

	print("\n3) Menú → Info")
	_hud.get_node("%MenuButton").pressed.emit()
	_hud.get_node("%InfoButton").pressed.emit()
	await _frames(5)
	_check(_hud.get_node("%InfoPanel").visible and _hud.get_node("%InfoFpsLabel").text.contains("FPS"),
		"Info muestra los FPS (%s)" % _hud.get_node("%InfoFpsLabel").text)
	_check(_hud.get_node("%InfoLabel").text.contains(ProjectSettings.get_setting("application/config/version")),
		"Info muestra la versión")
	_check(_hud.get_node("%ClockLabel").text.begins_with("Día"), "Info muestra día y hora")
	await _shot("ui_3_info.png")
	_hud.get_node("%FpsCheck").button_pressed = true
	await _frames(3)
	_check(_hud.get_node("%FpsLabel").visible, "«Mostrar FPS» los pone en pantalla")
	_hud.get_node("%FpsCheck").button_pressed = false
	_hud.get_node("%InfoCloseButton").pressed.emit()

	print("\n4) Maqueta de pisos: tocar el piso 1 sube")
	_main.set_mode("build")
	await _frames(5)
	var map: FloorMap = _hud.get_node("%FloorMap")
	_click_at(_map_point(map, 1))
	await _frames(5)
	_check(_builder.level == 1, "tocando la maqueta se fue al piso %d" % _builder.level)
	await _shot("ui_4_piso_1.png")
	_click_at(_map_point(map, 0))
	await _frames(3)
	_check(_builder.level == 0, "y tocando abajo se vuelve a la planta baja")

	print("\n5) Íconos de techo y paredes")
	var view: HouseView = _main.get_node("House")
	var roofs_before := view.show_roofs
	_hud.get_node("%RoofButton").pressed.emit()
	await _frames(2)
	_check(view.show_roofs != roofs_before, "el ícono del techo los muestra / esconde")
	_hud.get_node("%WallsButton").pressed.emit()
	await _frames(2)
	_check(view.low_walls and not view.show_roofs, "paredes bajas (y sin techo)")
	await _shot("ui_5_paredes_bajas.png")
	_hud.get_node("%WallsButton").pressed.emit()
	await _frames(2)
	_check(not view.low_walls, "paredes altas de nuevo")

	print("\n6) Brújula y velocidades")
	var rig: Node3D = _main.get_node("CameraRig")
	rig.set_state({"x": -15.0, "z": -15.0, "yaw": 0.0, "distance": 18.0})
	await _frames(3)
	_hud.get_node("%CompassButton").pressed.emit()
	await _frames(2)
	var character: Node3D = _main.get_node("House/Character")
	var gap := Vector2(rig.global_position.x - character.global_position.x, rig.global_position.z - character.global_position.z)
	_check(gap.length() < 0.5, "la brújula centra la cámara en el personaje")
	_check(GameClock.SPEEDS == [1, 2, 5], "velocidades x1, x2, x5")
	_check(HouseGrid.MAX_LEVELS == 5, "hasta 5 pisos")
	await _test_builder()
	_main.set_mode("live")
	await _frames(3)

	print("\nDEMO INTERFAZ: %d pasaron, %d fallaron · capturas: %s" % [_passed, _failed, ", ".join(_shots)])
	get_tree().quit(1 if _failed > 0 else 0)


## Una casa de dos pisos con escalera y algunos muebles (sin pasar por el
## constructor, directo a los datos).
func _build_test_house() -> void:
	var house: HouseData = _main.house
	house.from_dict({"lot_size": [HouseGrid.LOT_SIZE.x, HouseGrid.LOT_SIZE.y]})  # Vacía (y la vista se entera).
	var writes: Array = []
	for c in HouseGrid.cells_in_rect(Vector2i(11, 12), Vector2i(18, 18)):
		writes.append(HouseData.write(0, "foundation", HouseGrid.cell_key(c), {"item": "foundation_basic"}))
		writes.append(HouseData.write(0, "floors", HouseGrid.cell_key(c), {"item": "floor_basic"}))
	for edge in HouseGrid.edges_around_rect(Vector2i(11, 12), Vector2i(18, 18)):
		writes.append(HouseData.write(0, "walls", edge, {"item": "wall_basic"}))
	for edge in HouseGrid.edges_in_line(Vector2i(15, 12), Vector2i(15, 19)):
		writes.append(HouseData.write(0, "walls", edge, {"item": "wall_basic", "opening": "door_basic"} if edge == "v:15,16" else {"item": "wall_basic"}))
	writes.append(HouseData.write(0, "walls", "h:13,19", {"item": "wall_basic", "opening": "door_basic"}))
	# Balcón: un piso de arriba que solo sostiene la pared del fondo.
	writes.append(HouseData.write(1, "floors", "12,11", {"item": "floor_basic"}))
	writes.append(HouseData.write(0, "roofs", "o5", {"item": "roof_flat", "rect": [16, 19, 2, 2]}))
	writes.append(HouseData.write(0, "objects", "o1", {"item": "stairs_basic", "cell": [17, 14], "rot": 0}))
	writes.append(HouseData.write(0, "objects", "o2", {"item": "bed_basic", "cell": [12, 13], "rot": 0}))
	writes.append(HouseData.write(0, "objects", "o3", {"item": "sofa_basic", "cell": [16, 18], "rot": 2}))
	for c in HouseGrid.cells_in_rect(Vector2i(11, 12), Vector2i(18, 18)):
		if not c in [Vector2i(17, 14), Vector2i(17, 15), Vector2i(17, 16)]:
			writes.append(HouseData.write(1, "floors", HouseGrid.cell_key(c), {"item": "floor_tile"}))
	for edge in HouseGrid.edges_around_rect(Vector2i(11, 12), Vector2i(18, 18)):
		writes.append(HouseData.write(1, "walls", edge, {"item": "wall_basic"}))
	house.next_id = 10
	house.apply(writes)
	var character: Character = _main.get_node("House/Character")
	character.place_at(0, Vector2i(13, 16))


# --- P1B: constructor 2.0 ---

func _test_builder() -> void:
	print("\n7) Barra de abajo: Tienda, Obra y Borrar")
	_main.set_mode("build")
	_main._set_level(0)
	EventBus.camera_reset_requested.emit()
	var rig: Node3D = _main.get_node("CameraRig")
	rig.set_state({"x": 0.0, "z": 0.0, "yaw": 0.0, "distance": 16.0})
	await _frames(3)
	var bar: BuildBar = _hud.get_node("%BottomBar")
	var tips: Array = []
	for button in _hud.get_node("%ToolButtons").get_children():
		tips.append(button.tooltip_text)
	_check(tips == ["Tienda", "Obra"], "herramientas: %s" % ", ".join(tips))

	print("\n8) Pintar una cara de pared (Obra → Modificar → color)")
	bar._tool_buttons["build"].button_pressed = true
	bar._mode_buttons["modify"].button_pressed = true
	await _frames(2)
	_check(_builder.tool == HouseBuilder.Tool.MODIFY, "Obra › Modificar")
	var paint_button := _find_item_button(bar, "Rosado")
	paint_button.button_pressed = true
	await _frames(2)
	_check(_builder.tool == HouseBuilder.Tool.PAINT, "elegir un color = pintar")
	var house: HouseData = _main.house
	var before: Dictionary = house.get_piece(0, "walls", "h:17,12").duplicate()
	await _tap(_wall_screen("h:17,12", 1.6))
	await _frames(3)
	var after: Dictionary = house.get_piece(0, "walls", "h:17,12")
	var painted := "a" if after.has("color_a") else ("b" if after.has("color_b") else "")
	var other := "b" if painted == "a" else "a"
	_check(painted != "" and not after.has("color_" + other) and not before.has("color_" + painted),
		"se pintó solo una cara (la %s); la otra no" % painted)
	_check(_hud.get_node("%ActionRow").get_children().any(func(b): return b.visible and b.tooltip_text.contains("derecha")),
		"aparecen las flechas izquierda / derecha")
	await _shot("ui_6_pintar_cara.png")
	var painted_before := _painted_faces(house)
	EventBus.build_paint_step_requested.emit(1)
	await _frames(3)
	_check(_painted_faces(house) == painted_before + 1, "la flecha pinta la pared de al lado")

	print("\n9) Borrar un techo, con confirmación")
	bar._tool_buttons["build"].button_pressed = true
	bar._mode_buttons["erase"].button_pressed = true
	await _frames(2)
	var view: HouseView = _main.get_node("House")
	if not view.show_roofs:
		EventBus.view_roofs_toggle_requested.emit()
	await _frames(2)
	var money := Economy.money
	var roof_center := Vector3(17.0, HouseGrid.level_y(0) + HouseGrid.WALL_HEIGHT + 0.15, 20.0)
	await _tap(_screen(roof_center))
	await _frames(3)
	var confirm: Button = _hud.get_node("%ConfirmButton")
	_check(confirm.visible and confirm.text.contains("te devuelven $"), "pregunta: \"%s\" / %s" % [_hud.get_node("%HintLabel").text, confirm.text])
	await _shot("ui_7_borrar_techo.png")
	confirm.pressed.emit()
	await _frames(3)
	var refund := int(round(18 * 4 * 0.5))
	_check(not house.has_piece(0, "roofs", "o5") and Economy.money == money + refund,
		"techo borrado: te devolvieron $%d" % (Economy.money - money))
	EventBus.view_roofs_toggle_requested.emit()

	print("\n10) No se puede quitar una pared que sostiene el piso de arriba")
	var toasts: Array = []
	var on_toast := func(text: String) -> void: toasts.append(text)
	EventBus.toast.connect(on_toast)
	await _tap(_wall_screen("h:12,12", 0.5))
	await _frames(2)
	EventBus.toast.disconnect(on_toast)
	# Pulido 2: el basurero borra TODO; la pared que sostiene el piso de arriba
	# se borra con ese piso, y la pregunta lo dice (en rojo, con confirmación).
	_check(confirm.visible and _hud.get_node("%HintLabel").text.contains("se apoya"),
		"pregunta que también se lleva lo de arriba: \"%s\"" % _hud.get_node("%HintLabel").text)
	EventBus.build_cancel_requested.emit()
	await _frames(2)

	print("\n11) Borrar varias cosas a la vez (modo selección)")
	EventBus.build_erase_multi_toggled.emit(true)
	var bed_point := Vector3(12.5, HouseGrid.level_y(0) + 0.4, 13.9)
	var sofa_point := Vector3(17.0, HouseGrid.level_y(0) + 0.4, 18.5)
	await _tap(_screen(bed_point))
	await _tap(_screen(sofa_point))
	await _frames(2)
	_check(confirm.visible and confirm.text.begins_with("Borrar 2 cosas"), "\"%s\"" % confirm.text)
	await _shot("ui_8_borrar_varias.png")
	EventBus.build_cancel_requested.emit()
	EventBus.build_erase_multi_toggled.emit(false)
	await _frames(2)
	_check(house.has_piece(0, "objects", "o2") and house.has_piece(0, "objects", "o3"), "cancelar no borra nada")

	print("\n12) Tienda: la cama en el cuarto hace recomendar cosas de dormitorio")
	rig.set_state({"x": 13.0 - 16.0, "z": 15.0 - 16.0, "yaw": 0.0, "distance": 16.0})
	await _frames(2)
	var room := _builder.room_here()
	_check(room.get("type", "") == "bedroom", "el cuarto que se mira es: %s" % room.get("name", "ninguno"))
	# Pulido 4A: la columna izquierda ya no tiene el botón de cuartos (es una herramienta de Obra).
	var left_buttons: Array = _hud.get_node("%LeftColumn").get_node("ViewIcons").get_children()
	_check(left_buttons.size() == 2, "la columna izquierda solo tiene techo y paredes (%d íconos)" % left_buttons.size())
	bar._tool_buttons["shop"].button_pressed = true
	await _frames(2)
	var tabs := _hud.get_node("%Categories").get_children().filter(func(b): return not b.is_queued_for_deletion())
	_check(tabs.size() > 0 and tabs[0].text.contains("Dormitorio"), "primera pestaña: \"%s\"" % (tabs[0].text if tabs.size() > 0 else ""))
	var first_items := _hud.get_node("%Items").get_children().filter(func(b): return not b.is_queued_for_deletion())
	_check(first_items.size() > 0 and first_items[0].text.begins_with("Cama"), "lo primero recomendado: %s" % first_items[0].text.split("\n")[0])
	await _shot("ui_9_tienda_dormitorio.png")

	print("\n13) Silla en diagonal")
	var chair_tab := tabs.filter(func(b): return b.text == "Muebles")
	chair_tab[0].pressed.emit()
	await _frames(2)
	_find_item_button(bar, "Silla").button_pressed = true
	EventBus.build_rotate_requested.emit()
	await _frames(1)
	_check(_builder.place_diag, "girar una vez = 45°")
	await _tap(_screen(Vector3(16.5, HouseGrid.level_y(0), 13.5)))
	await _frames(3)
	# Pulido 3B: el mueble queda sostenido hasta Confirmar (así se puede girar antes).
	_check(_builder._awaiting_confirm, "la silla queda sostenida esperando Confirmar")
	_builder.confirm_pending()
	await _frames(4)
	var chair_key := ""
	for key in house.get_layer(0, "objects"):
		if house.get_piece(0, "objects", key)["item"] == "chair_basic":
			chair_key = key
	_check(chair_key != "" and house.get_piece(0, "objects", chair_key).get("diag", false), "silla puesta en diagonal")
	await _shot("ui_10_silla_diagonal.png")

	print("\n14) Copiar el contorno de abajo y lo que falta")
	house.floor_count = 3  # "Agregar piso" (Pulido 2): el piso 2 existe aunque esté vacío.
	_main._set_level(2)
	bar._tool_buttons["build"].button_pressed = true
	bar._mode_buttons["add"].button_pressed = true
	await _frames(2)
	_check(_hud.get_node("%ActionRow").get_children().any(func(b): return b.visible and b.tooltip_text == "Copiar contorno de abajo"),
		"en Obra › Agregar, arriba, aparece \"Copiar contorno de abajo\"")
	EventBus.build_copy_outline_requested.emit()
	await _frames(2)
	_check(confirm.visible, "el contorno espera Confirmar (%s)" % confirm.text)
	confirm.pressed.emit()
	await _frames(3)
	_check(house.get_layer(2, "floors").size() > 30 and house.get_layer(2, "walls").size() >= 26,
		"piso 2 armado: %d pisos y %d paredes" % [house.get_layer(2, "floors").size(), house.get_layer(2, "walls").size()])
	await get_tree().create_timer(0.6).timeout
	var problems_button: Button = _hud.get_node("%ProblemsButton")
	_check(problems_button.visible and problems_button.text.begins_with("Falta"), "aviso arriba: %s" % problems_button.text)
	problems_button.pressed.emit()
	await _frames(3)
	await _shot("ui_11_lo_que_falta.png")
	_check(HouseRules.problems(house).any(func(p): return p["text"].contains("sin acceso")), "piso 2: sin acceso (no hay escalera)")
	_hud._close_popup()


func _find_item_button(bar: BuildBar, name_start: String) -> Button:
	for button in bar.get_node("%Items").get_children():
		if not button.is_queued_for_deletion() and button.text.begins_with(name_start):
			return button
	return null


## Caras de pared pintadas en toda la casa.
func _painted_faces(house: HouseData) -> int:
	var count := 0
	for key in house.get_layer(0, "walls"):
		var wall: Dictionary = house.get_piece(0, "walls", key)
		count += int(wall.has("color_a")) + int(wall.has("color_b"))
	return count


## Un toque rápido (apretar y soltar) en un punto de la pantalla.
func _tap(pos: Vector2) -> void:
	_click_at(pos)
	await _frames(2)


func _screen(local: Vector3) -> Vector2:
	var house_node: Node3D = _main.get_node("House")
	return get_viewport().get_camera_3d().unproject_position(house_node.to_global(local))


func _wall_screen(edge: String, height: float) -> Vector2:
	return _screen(HouseGrid.edge_center(edge) + Vector3(0, HouseGrid.level_y(0) + height, 0))


## Punto de la pantalla donde se ve un piso en la maqueta.
func _map_point(map: FloorMap, level: int) -> Vector2:
	var cam: Camera3D = map.get_child(0).get_child(0)
	var screen := cam.unproject_position(Vector3(map._center.x, FloorMap._level_y(level) + FloorMap.FLOOR_HEIGHT / 2.0, map._center.z))
	var vp_size := Vector2(map.get_child(0).size)
	return map.get_global_rect().position + screen * map.size / vp_size


func _click_control(control: Control) -> void:
	_click_at(control.get_global_rect().get_center())


## Un clic de mouse de verdad (pasa por toda la interfaz).
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
