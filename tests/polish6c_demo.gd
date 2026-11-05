extends Node
## Demostración del Pulido 6C (interfaz y cámara), con capturas.
##
##   godot --path . res://tests/polish6c_demo.tscn
## Las capturas (p6c_*.png) van a SHOT_DIR (o a user://). Partida local.

var _main: Node3D
var _hud: CanvasLayer
var _shot_dir := ""
var _passed := 0
var _failed := 0
var _shots: Array[String] = []

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
	_main.set_mode("live")
	await _frames(10)
	await _test_mood_tap()
	await _test_popup_inside()
	await _test_follow_button()
	await _test_menu_hides_behind()
	await _test_signs_hidden()
	print("\nDEMO PULIDO 6C: %d pasaron, %d fallaron · capturas: %s" % [_passed, _failed, ", ".join(_shots)])
	get_tree().quit(1 if _failed > 0 else 0)


## El toque llega dos veces (toque + clic emulado): la tarjeta no se abre y se cierra sola.
func _test_mood_tap() -> void:
	print("\n1) Botón de ánimo: un toque = una sola vez")
	var mood: Control = _hud.get_node("%MoodButton")
	var card: Control = _hud.get_node("%MoodCard")
	_check(not card.visible, "empieza cerrada")
	mood.gui_input.emit(_click())
	var echo := InputEventScreenTouch.new()
	echo.pressed = true
	mood.gui_input.emit(echo)  # El eco del mismo toque, al instante.
	await _frames(3)
	_check(card.visible, "un toque con eco la deja abierta")
	_hud._close_cards()
	await _frames(20)  # Pasa la guarda: otro toque vuelve a funcionar.
	await get_tree().create_timer(0.3).timeout
	mood.gui_input.emit(_click())
	await _frames(3)
	_check(card.visible, "un toque posterior la abre otra vez")
	_hud._close_cards()
	await _frames(2)


## El menú de servicio y los otros flotantes quedan dentro de la pantalla, en tres tamaños.
func _test_popup_inside() -> void:
	print("\n2) Menús dentro de la pantalla")
	var window := get_window()
	for entry in SIZES:
		var size := Vector2i(entry[0], entry[1])
		var r: Array = entry[2]
		window.size = size
		SafeArea.override_screen = size
		SafeArea.override_rect = Rect2i(r[0], r[1], r[2], r[3])
		await _frames(6)
		_hud._fit_to_screen()
		await _frames(3)
		var rows: VBoxContainer = _hud._open_popup("Tala de árbol")
		_hud._popup_button(rows, "Llamar servicio ($94)", func() -> void: pass)
		_hud._popup_button(rows, "Cerrar", func() -> void: pass)
		await _frames(6)
		var area := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
		var rect: Rect2 = _hud._popup.get_global_rect()
		_check(area.encloses(rect), "%dx%d: el menú de servicio está entero en pantalla (%s)" % [size.x, size.y, str(rect)])
		_check(rect.position.x > 50.0 and rect.position.y > 50.0, "%dx%d: no está pegado a la esquina" % [size.x, size.y])
		if size.x == 1920:
			await _shot("p6c_servicio_1920x1080.png")
		_hud._close_popup()
		await _frames(2)


## La brújula está arriba junto a techos y paredes, y alterna libre/siguiendo.
func _test_follow_button() -> void:
	print("\n3) Centrar: libre o siguiendo")
	var compass: CompassButton = _hud.get_node("%CompassButton")
	var roof: Control = _hud.get_node("%RoofButton")
	_check(compass.get_parent() == roof.get_parent(), "está en la misma fila que techos y paredes")
	_main._character.global_position = Vector3(30, 0, 30)
	_main._camera_rig.focus_on(Vector3(-20, 0, -20))
	await _frames(2)
	compass.button_pressed = true
	compass.pressed.emit()
	await _frames(6)
	var cam: Vector3 = _main._camera_rig.position
	_check(is_equal_approx(cam.x, _main._character.global_position.x) or cam.distance_to(Vector3(_main._character.global_position.x, cam.y, _main._character.global_position.z)) < 1.0,
		"siguiendo: la cámara va al personaje")
	_main._character.global_position = Vector3(10, 0, 5)
	await _frames(4)
	var cam2: Vector3 = _main._camera_rig.position
	_check(absf(cam2.x - 10.0) < 1.0, "siguiendo: lo acompaña cuando se mueve")
	# Se va a trabajar: vuelve solo a libre.
	_main._character.state = Character.State.WORKING
	await _frames(4)
	_check(not compass.button_pressed, "al irse a trabajar el botón vuelve a libre")
	_main._character.state = Character.State.IDLE
	await _shot("p6c_centrar_arriba.png")


## Con el ☰ abierto, los botones de atrás se esconden (no asoman) y un toque afuera lo cierra.
func _test_menu_hides_behind() -> void:
	print("\n5) Menú abierto: lo de atrás no está")
	var layout: Control = _hud.get_node("Root/Layout")
	var overlay: Control = _hud.get_node("%CardOverlay")
	_check(layout.visible, "con todo cerrado la interfaz se ve")
	_hud.get_node("%MenuButton").pressed.emit()
	await _frames(4)
	_check(not layout.visible, "con el ☰ abierto los botones de atrás se esconden")
	_check(overlay.visible, "y hay un velo que recibe el toque de afuera")
	await _shot("p6c_menu_abierto.png")
	overlay.gui_input.emit(_click())
	await _frames(4)
	_check(layout.visible and not _hud.get_node("%SideMenu").visible, "tocar afuera cierra el menú y vuelve todo")


## Los carteles de las casas de vecinos están apagados hasta tocar la casa.
func _test_signs_hidden() -> void:
	print("\n4) Nombres de las casas")
	var count := 0
	var visible_count := 0
	for node in _main.find_children("Sign", "Label3D", true, false):
		count += 1
		if (node as Label3D).visible:
			visible_count += 1
	_check(count > 0, "hay carteles construidos (%d)" % count)
	_check(visible_count == 0, "ninguno se ve por defecto (%d visibles)" % visible_count)
	await _shot("p6c_sin_nombres.png")


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
