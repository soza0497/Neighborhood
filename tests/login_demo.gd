extends Node
## Demostración con ventana de la pantalla de entrada, contra el servidor de
## verdad: crear cuenta → juego con el indicador "Conectado" → construir,
## deshacer y rehacer con el servidor (Fase 4B) → abrir de nuevo (entra solo,
## sin contraseña, con la casa del servidor) → sin servidor ("Jugar sin
## conexión": se vive pero no se construye).
##
##   SHOT_DIR=/carpeta godot --path . res://tests/login_demo.tscn
##
## Usa user://demo_session.json (no la sesión del jugador) y al terminar
## devuelve la partida guardada (save.json) como estaba.

const LOGIN_SCENE := "res://ui/login_screen.tscn"
const SAVE_FILES := ["user://save.json", "user://save.json.bak"]

var _shot_dir := ""
var _passed := 0
var _failed := 0


func _ready() -> void:
	_shot_dir = OS.get_environment("SHOT_DIR")
	if _shot_dir == "":
		_shot_dir = OS.get_user_data_dir()
	_run.call_deferred()


func _check(condition: bool, description: String) -> void:
	if condition:
		_passed += 1
		print("  OK   ", description)
	else:
		_failed += 1
		print("FALLÓ  ", description)


func _run() -> void:
	_backup_saves()
	GameServer.use_session_file("user://demo_session.json")
	GameServer.logout()
	var user := "demo_%d" % randi_range(1000, 99999)

	print("1) Primera vez: crear cuenta")
	var login := await _open_login()
	await _frames(10)
	_check(login.get_node("%Form").visible, "se ve el formulario")
	login.get_node("%UserEdit").text = user
	login.get_node("%PasswordEdit").text = "demo-clave-123"
	await _shot("login_1_formulario.png")
	login.get_node("%RegisterButton").pressed.emit()
	var main := await _wait_for_main()
	_check(main != null, "se creó la cuenta y se abrió el juego")
	if main != null:
		await _frames(30)
		_check(_server_text(main).begins_with("● Conectado: " + user), "indicador: \"%s\"" % _server_text(main))
		_check(GameState.account.get("username", "") == user, "la partida quedó marcada con la cuenta")
		await _shot("login_2_juego_conectado.png")
		await _build_with_server(main)

	print("2) Abrir otra vez: entra solo")
	var built: Dictionary = main.house.to_dict()["levels"][0]["foundation"] if main != null else {}
	GameState.house = {}  # Como si el teléfono hubiera perdido la casa.
	login = await _open_login()
	await _frames(2)
	await _shot("login_3_entrando.png")
	main = await _wait_for_main()
	_check(main != null and GameServer.username() == user, "entró sin pedir la contraseña")
	if main != null:
		_check(not built.is_empty() and main.house.get_layer(0, "foundation").size() == built.size(),
			"la casa vino del servidor (%d cimientos)" % built.size())

	print("3) Sin servidor")
	# Primero se espera a que terminen los pedidos al servidor real que quedaron
	# en camino: si uno contesta tarde, el juego se marca "Conectado" (con razón).
	await _wait_until(func() -> bool: return not GameServer.get_children().any(func(c): return c is HTTPRequest))
	var real_url := GameServer.base_url
	GameServer.base_url = "http://127.0.0.1:7359"
	login = await _open_login()
	await _wait_until(func() -> bool: return login.get_node("%RetryBox").visible)
	_check(login.get_node("%OfflineButton").visible, "ofrece \"Jugar sin conexión\"")
	await _shot("login_4_sin_conexion.png")
	login.get_node("%OfflineButton").pressed.emit()
	main = await _wait_for_main()
	if main != null:
		await _frames(30)
		_check(_server_text(main).begins_with("● Sin conexión"), "indicador: \"%s\"" % _server_text(main))
		EventBus.game_mode_change_requested.emit("build")
		await _frames(5)
		_check(main.mode == "live" and _toast_text(main).begins_with("Sin conexión al servidor"),
			"Construir no se puede: \"%s\"" % _toast_text(main))
		await _shot("login_5_juego_sin_conexion.png")
	GameServer.base_url = real_url
	if main != null:
		print("4) Vuelve la conexión con el juego abierto")
		await GameServer.check_connection()
		_check(await _wait_until(func() -> bool: return GameServer.game_loaded and Economy.settled),
			"cargó la partida del servidor y cobró lo pendiente")
		EventBus.game_mode_change_requested.emit("build")
		await _frames(3)
		_check(main.mode == "build", "ya se puede construir")
		EventBus.game_mode_change_requested.emit("live")

	GameServer.logout()
	_restore_saves()
	print("\nDEMO ENTRADA: %d pasaron, %d fallaron · cuenta %s · capturas en %s" % [_passed, _failed, user, _shot_dir])
	get_tree().quit(1 if _failed > 0 else 0)


## Abre la pantalla de entrada como escena principal (esta demo queda aparte,
## colgada de la raíz, y sobrevive a los cambios de escena).
func _open_login() -> Control:
	var current := get_tree().current_scene
	if current != null and current != self:
		current.queue_free()
	await _frames(1)
	var login: Control = load(LOGIN_SCENE).instantiate()
	get_tree().root.add_child(login)
	get_tree().current_scene = login
	return login


func _wait_for_main() -> Node:
	var ok: bool = await _wait_until(func() -> bool:
		var scene := get_tree().current_scene
		return scene != null and scene.name == "Main")
	return get_tree().current_scene if ok else null


func _wait_until(condition: Callable, seconds := 15.0) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < end:
		if condition.call():
			return true
		await get_tree().process_frame
	return false


## Fase 4B: arma cimientos en modo Construir (como si arrastrara el dedo) y
## comprueba que cobra el servidor; después deshace y rehace.
func _build_with_server(main: Node) -> void:
	print("1b) Construir con el servidor")
	var builder: HouseBuilder = main.get_node("House/Builder")
	builder.plan_enabled = false
	var camera := get_viewport().get_camera_3d()
	var to_screen := func(cell: Vector2) -> Vector2:
		return camera.unproject_position(main.get_node("House").to_global(Vector3(cell.x, 0.3, cell.y)))
	_check(Economy.server_mode, "con cuenta, manda el servidor")
	EventBus.game_mode_change_requested.emit("build")
	await _frames(3)
	_check(main.mode == "build", "con conexión se puede construir")
	# Un rincón de la parcela (lejos de la casa de las otras demos). Se cuentan
	# las celdas que estaban libres: esas son las que se cobran.
	var o := HouseGrid.home_origin()  # Pulido 2C: la parcela es de 96; se construye en la zona del centro.
	var free := 0
	for x in range(24 + o.x, 28 + o.x):
		for z in range(2 + o.y, 5 + o.y):
			if not main.house.has_piece(0, "foundation", "%d,%d" % [x, z]):
				free += 1
	var before: int = main.house.get_layer(0, "foundation").size()
	var money := Economy.money
	EventBus.build_item_selected.emit("foundation_basic")
	builder._begin(to_screen.call(Vector2(24.5 + o.x, 2.5 + o.y)))
	builder._update(to_screen.call(Vector2(27.5 + o.x, 4.5 + o.y)))
	builder._release()
	builder.confirm_pending()
	_check(free == 0 or Economy.busy, "esperando la respuesta del servidor (botones apagados)")
	await _wait_until(func() -> bool: return not Economy.busy)
	var added: int = main.house.get_layer(0, "foundation").size() - before
	_check(free > 0 and added == free and Economy.money == money - free * 5,
		"%d cimientos: el servidor cobró $%d" % [added, money - Economy.money])
	await _frames(5)
	await _shot("login_2b_construir.png")
	EventBus.undo_requested.emit()
	await _wait_until(func() -> bool: return not Economy.busy)
	_check(main.house.get_layer(0, "foundation").size() == before and Economy.money == money, "deshacer: devuelve los $%d" % (free * 5))
	EventBus.redo_requested.emit()
	await _wait_until(func() -> bool: return not Economy.busy)
	_check(main.house.get_layer(0, "foundation").size() == before + free and Economy.money == money - free * 5, "rehacer: vuelve a cobrar")
	EventBus.game_mode_change_requested.emit("live")
	SaveSystem.save_game()


func _toast_text(main: Node) -> String:
	return main.get_node("HUD").get_node("%ToastLabel").text


func _server_text(main: Node) -> String:
	return main.get_node("HUD").get_node("%ServerLabel").text


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_shot_dir.path_join(file_name))


func _backup_saves() -> void:
	for path in SAVE_FILES:
		if FileAccess.file_exists(path):
			DirAccess.copy_absolute(path, path + ".demo_backup")


func _restore_saves() -> void:
	for path in SAVE_FILES:
		if FileAccess.file_exists(path + ".demo_backup"):
			DirAccess.rename_absolute(path + ".demo_backup", path)
		elif FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
