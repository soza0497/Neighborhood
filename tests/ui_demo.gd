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

var _main: Node3D
var _hud: CanvasLayer
var _builder: HouseBuilder
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


## Punto de la pantalla donde se ve un piso en la maqueta.
func _map_point(map: FloorMap, level: int) -> Vector2:
	var cam: Camera3D = map.get_child(0).get_child(0)
	var screen := cam.unproject_position(Vector3(map._center.x, level * FloorMap.LEVEL_SPACING, map._center.z))
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
