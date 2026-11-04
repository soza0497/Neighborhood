extends Node
## Demostración del Pulido 5C (menús sin choques y pantalla despejada), con capturas.
##
##   godot --path . res://tests/polish5c_demo.tscn
## Las capturas (p5c_*.png) van a SHOT_DIR (o a user://). Partida local.
## En la nube/PC sin pantalla: SHOT_DIR=docs/capturas xvfb-run -a -s "-screen 0 2560x2560x24" godot --path . res://tests/polish5c_demo.tscn

var _main: Node3D
var _hud: CanvasLayer
var _shot_dir := ""
var _passed := 0
var _failed := 0
var _shots: Array[String] = []

## [ancho, alto de la ventana, área segura en píxeles reales (x, y, w, h)]
const SIZES := [
	[1920, 1080, [60, 0, 1800, 1080]],
	[1080, 2400, [0, 96, 1080, 2244]],
	[2400, 1080, [96, 0, 2208, 1020]],
]


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
	_hud = _main.get_node("HUD")
	_run.call_deferred()


func _run() -> void:
	_main.set_mode("build")
	_main._set_level(0)
	await _frames(10)
	await _test_menus_float()
	await _test_exclusive()
	await _test_mode_interface()
	print("\nDEMO PULIDO 5C: %d pasaron, %d fallaron · capturas: %s" % [_passed, _failed, ", ".join(_shots)])
	get_tree().quit(1 if _failed > 0 else 0)


func _rects() -> Dictionary:
	return {
		"root": _hud.get_node("Root").get_global_rect(),
		"top": _hud.get_node("Root/Layout/TopRow").get_global_rect(),
		"bottom": _hud.get_node("%BottomBar").get_global_rect(),
		"menu_button": _hud.get_node("%MenuButton").get_global_rect(),
	}


## Abrir el ☰ (con la tienda abierta) no mueve ni achica nada, en tres tamaños.
func _test_menus_float() -> void:
	print("\n1) El menú ☰ flota: no empuja ni achica la interfaz")
	var window := get_window()
	var original := window.size
	var bar: BuildBar = _hud.get_node("%BottomBar")
	for entry in SIZES:
		var size := Vector2i(entry[0], entry[1])
		var r: Array = entry[2]
		window.size = size
		SafeArea.override_screen = size
		SafeArea.override_rect = Rect2i(r[0], r[1], r[2], r[3])
		await _frames(6)
		_hud._fit_to_screen()
		await _frames(3)
		var label := "%dx%d" % [size.x, size.y]
		bar._tool_buttons["shop"].button_pressed = true
		await _frames(4)
		var before := _rects()
		_hud.get_node("%MenuButton").pressed.emit()
		await _frames(4)
		var after := _rects()
		var side: Control = _hud.get_node("%SideMenu")
		_check(side.visible, "%s: el menú ☰ se abre" % label)
		for key in before:
			_check(before[key].is_equal_approx(after[key]), "%s: «%s» no cambió al abrir el ☰ (%s → %s)" % [label, key, str(before[key]), str(after[key])])
		var view: Vector2 = get_viewport().get_visible_rect().size
		_check(Rect2(Vector2.ZERO, view).grow(0.5).encloses(side.get_global_rect()), "%s: el ☰ cabe en la pantalla (%s)" % [label, str(side.get_global_rect())])
		var style: StyleBox = side.get_theme_stylebox("panel")
		_check(style is StyleBoxFlat and (style as StyleBoxFlat).bg_color.a >= 0.999, "%s: el ☰ es opaco" % label)
		_check(side.get_parent() == _hud.get_node("Overlay"), "%s: el ☰ vive en la capa libre, no en el contenedor" % label)
		await _shot("p5c_menu_%s.png" % label)
		_hud.get_node("%MenuButton").pressed.emit()
		bar._tool_buttons["shop"].button_pressed = false
		await _frames(3)
	SafeArea.override_rect = Rect2i()
	SafeArea.override_screen = Vector2i.ZERO
	window.size = original
	await _frames(4)


## Abrir un menú cierra los demás; la barra del ángulo no queda encima.
func _test_exclusive() -> void:
	print("\n2) Menús exclusivos")
	var side: Control = _hud.get_node("%SideMenu")
	var info: Control = _hud.get_node("%InfoPanel")
	var slider: Control = _hud.get_node("PitchSlider")
	await _frames(2)
	_check(slider.visible, "con todo cerrado se ve la barra del ángulo")
	_hud.get_node("%MenuButton").pressed.emit()
	await _frames(3)
	_check(side.visible and not slider.visible, "con el ☰ abierto la barra del ángulo se esconde")
	_hud.get_node("%InfoButton").pressed.emit()
	await _frames(3)
	_check(info.visible and not side.visible, "abrir Info cierra el ☰")
	_hud.get_node("%MenuButton").pressed.emit()
	await _frames(3)
	_check(side.visible and not info.visible, "abrir el ☰ cierra Info")
	_hud._open_popup("Prueba")
	await _frames(3)
	_check(not side.visible and _hud.get("_popup") != null, "una ventanita cierra el ☰")
	_hud._close_popup()
	_hud._close_floating()
	await _frames(3)
	_check(slider.visible, "al cerrar todo vuelve la barra del ángulo")
	# La barra del ángulo no pisa la barra de abajo con la tienda abierta.
	var bar: BuildBar = _hud.get_node("%BottomBar")
	bar._tool_buttons["shop"].button_pressed = true
	await _frames(6)
	_check(slider.get_global_rect().end.y <= bar.get_global_rect().position.y + 0.5,
		"la barra del ángulo (%s) termina antes de la barra de abajo (%s)" % [str(slider.get_global_rect()), str(bar.get_global_rect())])
	await _shot("p5c_tienda_y_angulo.png")
	bar._tool_buttons["shop"].button_pressed = false
	await _frames(2)


## Al construir se ocultan el ánimo y las necesidades; al vivir vuelven.
func _test_mode_interface() -> void:
	print("\n3) Interfaz según lo que se hace")
	var mood: Control = _hud.get_node("%MoodButton")
	var money: Control = _hud.get_node("%MoneyLabel")
	_check(not mood.visible and money.is_visible_in_tree(), "construyendo: sin ánimo, con dinero y nivel")
	await _shot("p5c_construir.png")
	_main.set_mode("live")
	await _frames(6)
	_check(mood.visible and money.is_visible_in_tree(), "viviendo: se ve el ánimo y el dinero")
	await _shot("p5c_vivir.png")
	mood.gui_input.emit(_click())
	await _frames(3)
	_check(_hud.get_node("%MoodCard").visible, "la tarjeta del ánimo se abre al vivir")
	_hud.get_node("%MenuButton").pressed.emit()
	await _frames(3)
	_check(not _hud.get_node("%MoodCard").visible and _hud.get_node("%SideMenu").visible, "el ☰ cierra la tarjeta del ánimo")
	_hud._close_floating()
	_main.set_mode("build")
	await _frames(4)
	_check(not mood.visible, "al volver a construir se esconde otra vez")


func _click() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event


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
