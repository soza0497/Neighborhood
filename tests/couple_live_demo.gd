extends Node
## Demostración CON VENTANA de la Fase 5 (servidor arrancado): lo que ve A
## en su pantalla cuando vive con B en la casa compartida.
##
##   godot --path . res://tests/couple_live_demo.tscn
##
## Arma dos cuentas que viven juntas en la casa de A y, desde el "teléfono"
## de B (un segundo cliente), manda estados y cambios. Revisa que en la
## pantalla de A:
##   - el personaje de B aparece (con su nombre arriba),
##   - camina hasta la cocina y cocina cuando B dice "cocinando", y se va
##     cuando B se desconecta (vive con su propia IA),
##   - el personaje de A no elige el mueble que usa B,
##   - aparece el aviso "B movió: Sofá" con Deshacer,
##   - los paneles Pareja y Casa muestran todo.
## Guarda capturas en user:// (pareja_*.png). No toca la partida del jugador.

const PASSWORD := "demo-clave-123"
const GameServerScript := preload("res://scripts/autoload/game_server.gd")
const SAVE_FILES := ["user://save.json", "user://save.json.bak"]

var _passed := 0
var _failed := 0
var _b: Node
var _main: Node
var _shots: Array = []


func _ready() -> void:
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
	var suffix := randi_range(1000, 99999)
	var user_a := "demo_la%d" % suffix
	var user_b := "demo_lb%d" % suffix
	print("Servidor: %s · cuentas %s y %s" % [GameServer.address_text(), user_a, user_b])
	GameServer.use_session_file("user://demo_a_session.json")
	GameServer.logout()
	GameServer.start()
	if not await GameServer.check_connection():
		print("FALLÓ  el servidor no responde")
		get_tree().quit(1)
		return

	print("\n1) Viven juntos en la casa de A")
	await GameServer.register(user_a, PASSWORD)
	var local_a := {
		"house": {"levels": [{"foundation": _cells(10, 18, 8, 8, "foundation_basic"),
			"floors": _cells(10, 18, 8, 8, "floor_basic"),
			"objects": {
				"o1": {"item": "sofa_basic", "cell": [11, 22], "rot": 0},
				"o2": {"item": "stove_basic", "cell": [16, 19], "rot": 0},
				"o3": {"item": "fridge_basic", "cell": [15, 19], "rot": 0},
				"o4": {"item": "bed_double", "cell": [11, 19], "rot": 0},
			}}], "next_id": 5},
		"economy": {"xp": 2000},
		"character": {"data": {"name": "Ana", "appearance": {"shirt": "#ffd166"}}, "level": 0, "cell": [13, 24],
			"saved_unix": int(Time.get_unix_time_from_system())},
	}
	var result: Dictionary = await GameServer.load_game(local_a)
	_b = GameServerScript.new()
	_b.session_path = "user://demo_b_session.json"
	_b.emits_events = false
	add_child(_b)
	_b.logout()
	_b.start()
	await _b.register(user_b, PASSWORD)
	await _b.load_game({"house": {}, "character": {"data": {"name": "Beto", "appearance": {"shirt": "#ff6b9d", "hair": "#222222"}},
		"level": 0, "cell": [14, 24], "saved_unix": int(Time.get_unix_time_from_system())}})
	await _b.call_rpc("couple_invite", {"username": user_a})
	result = await GameServer.call_rpc("couple_load", {})
	await GameServer.call_rpc("couple_answer", {"from_id": _b.user_id(), "accept": true})
	await _b.call_rpc("couple_propose", {"kind": "move_in", "home": "yours"})
	await GameServer.call_rpc("couple_respond", {"accept": true})
	result = await GameServer.call_rpc("game_load", {})
	_check(result["ok"] and bool(result["data"].get("shared", false)), "pareja y casa compartida armadas por el servidor")

	GameServer.game_loaded = true
	GameState.from_dict(CloudSync.merge(local_a, result["data"], GameServer.user_id(), user_a))
	Economy.from_dict(GameState.economy)
	Economy.use_server(true)
	Economy.apply_server_state(result["data"])
	Couple.apply_answer(result["data"])
	GameServer.start_realtime()
	_b.start_realtime()
	_b.socket.follow([GameServer.user_id()])
	_main = preload("res://scenes/main.tscn").instantiate()
	add_child(_main)
	GameClock.speed = 3
	var partner: Character = _main.partner_character
	_check(partner != null and partner.is_partner and partner.data.name == "Beto",
		"el personaje de B está en la casa de A (con su nombre)")
	await _wait_until(func() -> bool: return Couple.partner_online, 10.0)
	_check(Couple.partner_online, "B está en línea")

	print("\n2) B cocina en su teléfono: en la pantalla de A, su personaje también")
	_b.socket.update_status(CoupleState.encode_status({"character": "Beto", "state": "acting", "action": "cook",
		"verb": "cocinando", "object": "Cocina", "key": "o2", "object_level": 0, "level": 0,
		"since": int(Time.get_unix_time_from_system())}))
	_check(await _wait_until(func() -> bool: return partner.state == Character.State.ACTING and partner.using(0, "o2"), 20.0),
		"el personaje de B caminó hasta la cocina y está cocinando")
	_check(partner._animator.current == "cook", "con la animación de cocinar (\"%s\")" % partner._animator.current)
	_check(not _main._character.using(0, "o2"), "el personaje de A no usa la cocina mientras la usa B")
	await _shot("pareja_1_cocinando.png")
	_check(_hud_text("PartnerInfoLabel").contains("cocinando"), "en Info dice: \"%s\"" % _hud_text("PartnerInfoLabel"))

	print("\n3) B se duerme, después se desconecta")
	_b.socket.update_status(CoupleState.encode_status({"character": "Beto", "state": "walking", "action": "sleep",
		"verb": "yendo a: dormir", "object": "Cama doble", "key": "o4", "object_level": 0, "level": 0, "since": 0}))
	_check(await _wait_until(func() -> bool: return partner.state == Character.State.ACTING and partner.using(0, "o4"), 20.0),
		"va a la cama y duerme (anim \"%s\")" % partner._animator.current)
	_b.stop_realtime()
	_check(await _wait_until(func() -> bool: return not Couple.partner_online and not partner.remote_driven, 10.0),
		"B se desconectó: su personaje sigue con su propia IA")
	await _shot("pareja_2_fuera_de_linea.png")
	_b.start_realtime()

	print("\n4) B mueve el sofá: aviso con Deshacer en la pantalla de A")
	await _b.call_rpc("build_apply", {"writes": [HouseData.write(0, "objects", "o1",
		{"item": "sofa_basic", "cell": [12, 24], "rot": 0})]})
	_check(await _wait_until(func() -> bool: return _hud_node("NoticeBox").visible, 10.0)
		and _hud_text("NoticeLabel").contains("movió") and _hud_node("NoticeUndoButton").visible,
		"aviso: \"%s\" [Deshacer]" % _hud_text("NoticeLabel"))
	await _shot("pareja_3_aviso.png")

	print("\n5) Paneles")
	await _b.call_rpc("build_apply", {"writes": [HouseData.write(0, "walls", "h:10,18", {"item": "wall_basic"}),
		HouseData.write(0, "walls", "h:11,18", {"item": "wall_basic"})]})
	await _b.call_rpc("home_contribute", {"amount": 250})
	await _wait_until(func() -> bool: return Couple.home["requests"].size() == 1, 10.0)
	EventBus.home_panel_requested.emit()
	await _wait_until(func() -> bool: return Economy.fund == 250, 10.0)
	await _frames(20)
	var home_panel: Control = _main.get_node("HUD/HomePanel")
	_check(home_panel.visible and _text_in(home_panel).contains("Aprobar") and _text_in(home_panel).contains("Caja de la casa: $ 250"),
		"panel Casa: caja, pedido de B con Aprobar, historial")
	await _shot("pareja_4_panel_casa.png")
	home_panel.hide()
	EventBus.couple_panel_requested.emit()
	await _frames(20)
	var couple_panel: Control = _main.get_node("HUD/CouplePanel")
	_check(couple_panel.visible and _text_in(couple_panel).contains("Modo familiar"), "panel Pareja: estado, interruptores, historial")
	await _shot("pareja_5_panel_pareja.png")
	couple_panel.hide()

	_main.queue_free()
	GameClock.speed = 1
	GameServer.logout()
	Couple.clear()
	Economy.use_server(false)
	_b.logout()
	_restore_saves()
	print("\nDEMO PAREJA EN PANTALLA: %d pasaron, %d fallaron · capturas: %s" % [_passed, _failed, ", ".join(_shots)])
	get_tree().quit(1 if _failed > 0 else 0)


# --- Ayudantes ---

func _hud_node(node_name: String) -> Control:
	return _main.get_node("HUD").find_child(node_name, true, false)


func _hud_text(node_name: String) -> String:
	var node := _hud_node(node_name)
	return node.text if node != null else ""


## Todo el texto de un panel (etiquetas y botones), para revisarlo.
func _text_in(node: Node) -> String:
	var parts: Array = []
	for child in node.find_children("*", "", true, false):
		if child is Label or child is Button:
			parts.append(child.text)
	return " | ".join(parts)


func _shot(file_name: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image != null:
		image.save_png("user://" + file_name)
		_shots.append(file_name)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _cells(x0: int, z0: int, width: int, depth: int, item: String) -> Dictionary:
	var cells := {}
	for x in range(x0, x0 + width):
		for z in range(z0, z0 + depth):
			cells["%d,%d" % [x, z]] = {"item": item}
	return cells


func _wait_until(condition: Callable, max_seconds := 10.0) -> bool:
	var end := Time.get_ticks_msec() + int(max_seconds * 1000)
	while not condition.call():
		if Time.get_ticks_msec() > end:
			return false
		await get_tree().process_frame
	return true


func _backup_saves() -> void:
	for path in SAVE_FILES:
		if FileAccess.file_exists(path):
			DirAccess.copy_absolute(path, path + ".live_demo")


func _restore_saves() -> void:
	for path in SAVE_FILES:
		if FileAccess.file_exists(path + ".live_demo"):
			DirAccess.copy_absolute(path + ".live_demo", path)
			DirAccess.remove_absolute(path + ".live_demo")
		elif FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
