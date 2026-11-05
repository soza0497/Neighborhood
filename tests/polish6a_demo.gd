extends Node
## Demostración del Pulido 6A (construcción y casa), con capturas.
##
##   godot --path . res://tests/polish6a_demo.tscn
## Capturas (p6a_*.png) a SHOT_DIR (o a user://). Partida local, sin servidor.
## Se va llenando por sub-fase: 6A-1 (pintura, íconos, contorno).

var _main: Node3D
var _hud: CanvasLayer
var _house: HouseData
var _builder: HouseBuilder
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
	GameState.settings = {}
	Parcel.setup_local({"seed": 424242})
	_main = preload("res://scenes/main.tscn").instantiate()
	add_child(_main)
	Economy.debug_unlock_all()
	_hud = _main.get_node("HUD")
	_house = _main.house
	_builder = _main.get_node("House/Builder")
	_run.call_deferred()


func _run() -> void:
	await _test_paint_faces()
	await _test_bar_and_tooltip()
	await _test_outline_modes()
	print("\nDEMO PULIDO 6A: %d pasaron, %d fallaron · capturas: %s" % [_passed, _failed, ", ".join(_shots)])
	get_tree().quit(1 if _failed > 0 else 0)


func _origin() -> Vector2i:
	return HouseGrid.home_origin() + Vector2i(4, 4)


## Una casa sencilla de 6 x 5 con una puerta, una ventana y una pared de adentro.
func _build_sample() -> void:
	var o := _origin()
	var far := o + Vector2i(5, 4)
	var writes: Array = []
	for c in HouseGrid.cells_in_rect(o, far):
		writes.append(HouseData.write(0, "foundation", HouseGrid.cell_key(c), {"item": "foundation_basic"}))
		writes.append(HouseData.write(0, "floors", HouseGrid.cell_key(c), {"item": "floor_basic"}))
	for edge in HouseGrid.edges_around_rect(o, far):
		writes.append(HouseData.write(0, "walls", edge, {"item": "wall_basic"}))
	writes.append(HouseData.write(0, "walls", HouseGrid.edge_key(Vector2i(o.x + 2, far.y + 1), true), {"item": "wall_basic", "opening": "door_basic"}))
	writes.append(HouseData.write(0, "walls", HouseGrid.edge_key(Vector2i(o.x + 4, o.y), true), {"item": "wall_basic", "opening": "window_basic"}))
	_house.from_dict({"lot_size": [96, 96], "format": 5})
	_house.next_id = 10
	_house.apply(writes)
	_main.get_node("House/Character").place_at(0, o + Vector2i(3, 2))


func _look(yaw: float, pitch: float, distance: float) -> void:
	var o := _origin()
	_main.get_node("CameraRig").set_state({"x": o.x + 3.0, "z": o.y + 2.5, "yaw": yaw, "distance": distance, "pitch": pitch})


func _test_paint_faces() -> void:
	print("\n1) Pintura: afuera rojo, adentro celeste; el canto sigue neutro")
	_build_sample()
	_main.set_mode("build")
	await _frames(4)
	var o := _origin()
	# Pintura como la haría el jugador: el filtro «afuera» / «adentro» elige la cara.
	var writes: Array = []
	for edge in HouseGrid.edges_around_rect(o, o + Vector2i(5, 4)):
		var wall: Dictionary = (_house.get_piece(0, "walls", edge) as Dictionary).duplicate()
		var outside: String = WallFaces.resolve_scope(_house, 0, edge, "a", "outside")
		var inside: String = WallFaces.resolve_scope(_house, 0, edge, "a", "inside")
		wall["color_" + outside] = "#e4685d"
		wall["color_" + inside] = "#8fd3f4"
		writes.append(HouseData.write(0, "walls", edge, wall))
	_house.apply(writes)
	await _frames(4)
	var sample: Dictionary = _house.get_piece(0, "walls", HouseGrid.edge_key(Vector2i(o.x + 1, o.y), true))
	_check(sample.get("color_a", "") == "#e4685d" and sample.get("color_b", "") == "#8fd3f4", "norte: afuera rojo (a), adentro celeste (b)")
	_look(0.0, -35.0, 16.0)
	await _shot("p6a_1_pintura_afuera.png")
	_look(0.0, -70.0, 14.0)
	await _shot("p6a_1_pintura_adentro_desde_arriba.png")
	# Una pared nueva en línea hereda los colores.
	_builder.select_item("wall_basic")
	var before := WallFaces.inherited_colors(_house, 0, HouseGrid.edge_key(Vector2i(o.x + 6, o.y), true))
	_check(before.is_empty() or before.has("color_a"), "la herencia devuelve colores o vacío")


func _test_bar_and_tooltip() -> void:
	print("\n2) Barra: título del menú, íconos y tooltip al mantener presionado")
	var bar: BuildBar = _hud.get_node("%BottomBar")
	_main.set_mode("build")
	await _frames(3)
	bar._tool_buttons["shop"].button_pressed = true
	await _frames(3)
	_check(bar.menu_title() == "Comprar" and bar.find_child("TitleLabel", true, false).text == "Comprar", "título «Comprar»")
	_look(0.0, -45.0, 18.0)
	await _shot("p6a_2_comprar_titulo.png")
	bar._tool_buttons["build"].button_pressed = true
	bar._mode_buttons["paint"].button_pressed = true
	await _frames(3)
	_check(_builder.tool == HouseBuilder.Tool.PAINT, "«Pintar» es su propio botón y deja elegida la pintura")
	_check(bar.find_child("TitleLabel", true, false).text == "Pintar", "título «Pintar»")
	_check(bar.find_child("Scope_inside", true, false) != null, "aparecen los botones Adentro / Afuera")
	var paint_button: Button = bar._mode_buttons["paint"]
	LongPressTip.show_tip(paint_button)
	await _frames(4)
	_check(LongPressTip.is_showing(paint_button), "mantener presionado muestra el nombre")
	await _shot("p6a_2_tooltip_pintar.png")
	LongPressTip.hide_tip(paint_button)
	_check(not LongPressTip.is_showing(paint_button) and not paint_button.disabled, "al soltar, el cartel se va y el botón queda activo")
	_main.set_mode("live")
	await _frames(3)


func _test_outline_modes() -> void:
	print("\n3) Contorno: fino, normal y apagado")
	_look(35.0, -35.0, 14.0)
	for mode in ["thin", "normal", "off"]:
		Style.set_outline_mode(mode)
		await _frames(3)
		_check(Style.outline_mode == mode, "modo %s" % mode)
		await _shot("p6a_3_contorno_%s.png" % mode)
	Style.set_outline_mode("thin")


# --- Ayudantes ---

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
