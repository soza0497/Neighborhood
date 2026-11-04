extends Node
## Demostración visual: arma una casa usando el constructor (como si alguien
## arrastrara con el mouse) y saca capturas de pantalla.
##
## Correr desde la terminal (abre una ventana unos segundos):
##   godot --path . res://tests/visual_demo.tscn
## Las capturas quedan en la carpeta que diga la variable SHOT_DIR, o en
## user:// (en la PC: ~/.local/share/godot/app_userdata/Neighborhood/).
## OJO: guarda la casa de prueba encima de la partida.

var _main: Node3D
var _builder: HouseBuilder
var _house: Node3D
var _camera: Camera3D
var _shot_dir := ""
## La casa de prueba se arma cerca del centro de la parcela.
const O := Vector2(10, 10)


func _ready() -> void:
	HouseGrid.use_test_lot()  # Estas pruebas arman casas en un lote de 32 (la parcela real, desde el Pulido 2C, es de 96).
	_shot_dir = OS.get_environment("SHOT_DIR")
	if _shot_dir == "":
		_shot_dir = OS.get_user_data_dir()
	_main = preload("res://scenes/main.tscn").instantiate()
	add_child(_main)
	Economy.debug_unlock_all()  # Sin límites de dinero ni de nivel.
	_builder = _main.get_node("House/Builder")
	_builder.plan_enabled = false  # Estas pruebas construyen de una (sin plan ni factura).
	_house = _main.get_node("House")
	_camera = get_viewport().get_camera_3d()
	_run.call_deferred()


func _run() -> void:
	_main.house.clear()
	EventBus.camera_reset_requested.emit()
	await _frames(3)

	await _drag("foundation_basic", Vector2(2.5, 2.5), Vector2(9.5, 8.5))
	await _drag("room_basic", Vector2(2.5, 2.5), Vector2(5.5, 8.5))
	await _drag("room_basic", Vector2(6.5, 2.5), Vector2(9.5, 8.5))
	await _drag("floor_tile", Vector2(6.5, 6.5), Vector2(9.5, 8.5))
	await _drag("wall_basic", Vector2(6, 6), Vector2(10, 6))
	await _drag("stairs_basic", Vector2(9.5, 3.5), Vector2(9.5, 3.5))
	await _drag("bed_double", Vector2(3, 3), Vector2(3, 3))
	await _drag("table_basic", Vector2(4, 6.5), Vector2(4, 6.5))
	await _drag("sofa_basic", Vector2(7.5, 4.5), Vector2(7.5, 4.5))
	await _drag("fridge_basic", Vector2(6.5, 8.5), Vector2(6.5, 8.5))
	await _drag("paint_mint", Vector2(2.5, 3.5), Vector2(2.5, 3.5))

	# Puertas y ventanas en la pared del frente (la de z = 9).
	await _set_view(HouseView.ViewMode.CUTAWAY)
	await _drag("door_basic", Vector2(4.5, 9), Vector2(4.5, 9))
	await _drag("window_basic", Vector2(2.5, 9), Vector2(2.5, 9))
	await _drag("window_basic", Vector2(3.5, 9), Vector2(3.5, 9))
	await _drag("window_tall", Vector2(7.5, 9), Vector2(7.5, 9))
	await _drag("window_basic", Vector2(10, 4.5), Vector2(10, 4.5))
	await _shot("1_cortada.png")

	# Primer piso encima del cuarto de la derecha.
	EventBus.build_level_change_requested.emit(1)
	await _frames(2)
	await _drag("room_basic", Vector2(6.5, 2.5), Vector2(9.5, 8.5))
	await _drag("chair_basic", Vector2(7.5, 7.5), Vector2(7.5, 7.5))
	await _shot("2_primer_piso.png")

	# Techos.
	await _drag("roof_basic", Vector2(6.5, 2.5), Vector2(9.5, 8.5))
	EventBus.build_level_change_requested.emit(-1)
	await _drag("roof_blue", Vector2(2.5, 2.5), Vector2(5.5, 8.5))
	EventBus.build_item_selected.emit("")
	await _shot("3_completa.png")

	# Primer plano del frente: puerta, ventanas unidas y techo.
	EventBus.game_mode_change_requested.emit("live")
	_main.get_node("CameraRig").set_state({"x": -1.0, "z": 3.0, "yaw": 0.0, "distance": 13.0})
	await _shot("6_frente.png")
	# Separar las dos ventanas (tocar la juntura en Modificar) y volver a unirlas.
	EventBus.game_mode_change_requested.emit("build")
	await _builder.toggle_joint(Vector2i(3, 9) + Vector2i(O))
	EventBus.game_mode_change_requested.emit("live")
	await _shot("6b_separadas.png")
	EventBus.game_mode_change_requested.emit("build")
	await _builder.toggle_joint(Vector2i(3, 9) + Vector2i(O))
	EventBus.game_mode_change_requested.emit("build")

	# Modo vivir, desde otro ángulo.
	EventBus.game_mode_change_requested.emit("live")
	_main.get_node("CameraRig").rotation_degrees.y = -30
	await _shot("4_vivir.png")

	# Deshacer 3 veces.
	for i in 3:
		EventBus.undo_requested.emit()
	await _shot("5_deshacer.png")

	# Prueba con eventos de mouse de verdad (pasan por la interfaz y la cámara).
	EventBus.game_mode_change_requested.emit("build")
	EventBus.camera_reset_requested.emit()
	EventBus.build_item_selected.emit("foundation_basic")
	await _frames(2)
	var before: int = _main.house.get_layer(0, "foundation").size()
	_push_mouse_button(_to_screen(Vector2(0.5, 0.5) + O), true)
	_push_mouse_motion(_to_screen(Vector2(1.5, 1.5) + O))
	_push_mouse_button(_to_screen(Vector2(1.5, 1.5) + O), false)
	EventBus.build_confirm_requested.emit()
	await _frames(2)
	var added: int = _main.house.get_layer(0, "foundation").size() - before
	print("Mouse real: %d cimientos nuevos (se esperaban 4) -> %s" % [added, "OK" if added == 4 else "FALLÓ"])

	# Tocar fuera del lote no construye (mueve la cámara).
	before = _main.house.get_layer(0, "foundation").size()
	_builder._begin(_to_screen(Vector2(-3, 16)))
	var takeover: bool = _main.get_node("CameraRig").single_finger_pan
	_builder._release()
	var outside_ok: bool = takeover and not _builder._awaiting_confirm
	print("Fuera del lote: %s" % ("OK" if outside_ok else "FALLÓ"))

	# Manijas: tocar una celda, arrastrar la manija y confirmar.
	_builder._begin(_to_screen(Vector2(0.5, 10.5) + O))
	_builder._release()
	var waiting: bool = _builder._awaiting_confirm
	_builder._begin(_to_screen(Vector2(0.5, 10.5) + O))
	_builder._update(_to_screen(Vector2(3.5, 11.5) + O))
	_builder._release()
	await _shot("7_manijas.png")
	EventBus.build_confirm_requested.emit()
	await _frames(2)
	added = _main.house.get_layer(0, "foundation").size() - before
	print("Manijas: esperaba confirmar=%s, %d cimientos (se esperaban 8) -> %s" % [
		waiting, added, "OK" if waiting and added == 8 else "FALLÓ"])

	# Rendimiento con la casa quieta.
	EventBus.build_item_selected.emit("")
	await get_tree().create_timer(2.0).timeout
	print("FPS: %d · llamadas de dibujo: %d · objetos dibujados: %d" % [
		Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
	])

	print("Demo lista. Capturas en: ", _shot_dir)
	get_tree().quit()


## Elige una pieza y "arrastra" de una posición de la cuadrícula a otra.
func _drag(item_id: String, from: Vector2, to: Vector2) -> void:
	EventBus.build_item_selected.emit(item_id)
	var start := _to_screen(from + O)
	var end := _to_screen(to + O)
	_builder._begin(start)
	for i in range(1, 5):
		_builder._update(start.lerp(end, i / 4.0))
	_builder._release()
	# Las herramientas de arrastre esperan "Confirmar".
	_builder.confirm_pending()
	await _frames(2)


func _push_mouse_button(pos: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = pos
	event.global_position = pos
	get_viewport().push_input(event)


func _push_mouse_motion(pos: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = pos
	event.global_position = pos
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(event)


func _set_view(mode: HouseView.ViewMode) -> void:
	_main._set_view_mode(mode)
	await _frames(2)


## Posición de la cuadrícula (en el nivel actual) → píxel de la pantalla.
func _to_screen(grid_pos: Vector2) -> Vector2:
	var local := Vector3(grid_pos.x, HouseGrid.level_y(_builder.level), grid_pos.y)
	return _camera.unproject_position(_house.to_global(local))


func _shot(file_name: String) -> void:
	await _frames(4)
	var image := get_viewport().get_texture().get_image()
	image.save_png(_shot_dir.path_join(file_name))


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
