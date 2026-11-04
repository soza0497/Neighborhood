extends Node
## Demostración de la Fase 6 (restaurante) contra el servidor DE VERDAD, con
## ventana y capturas. Tiene que estar arrancado el servidor (docs/servidor.md).
##
##   godot --path . res://tests/restaurant_demo.tscn
##
## Tarda unos 2 minutos y medio (un servicio de verdad dura 1:30). Hace:
##   1. Una cuenta con casa y, aparte en la parcela, un edificio con mostrador
##      y mesas. Compra la plancha (el servidor cobra) y espera la obra.
##   2. Abre el restaurante (Menú → Restaurante) y mira la Tienda (★ Restaurante).
##   3. Juega un servicio entero en la pantalla del minijuego (lo juega un
##      jugador automático, tests/restaurant_bot.gd, con toques de persona) y
##      compara lo que contó el teléfono con lo que pagó el servidor.
##   4. Trampas: una segunda cuenta manda toques de robot y un puntaje
##      inventado; no cobra nada.
##   5. Casa compartida: viviendo juntos, cerrar el restaurante pide permiso.
## Capturas: restaurante_*.png en user:// (o en SHOT_DIR).
##
## No toca la partida del jugador (la aparta y la devuelve). Las cuentas
## demo quedan en el servidor (se pueden borrar desde la consola).

const PASSWORD := "demo-clave-123"
const SAVE_FILES := ["user://save.json", "user://save.json.bak"]
const GameServerScript := preload("res://scripts/autoload/game_server.gd")

var _passed := 0
var _failed := 0
var _shots: Array = []
var _shot_dir := ""
var _main: Node3D
var _b: Node


func _ready() -> void:
	_shot_dir = OS.get_environment("SHOT_DIR")
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
	var user_a := "demo_ra%d" % suffix
	var user_b := "demo_rb%d" % suffix
	GameServer.use_session_file("user://demo_a_session.json")
	GameServer.logout()
	GameServer.start()
	print("Servidor: %s · cuentas %s y %s" % [GameServer.address_text(), user_a, user_b])
	if not await GameServer.check_connection():
		print("FALLÓ  el servidor no responde")
		get_tree().quit(1)
		return

	print("\n1) Casa + restaurante aparte en la parcela")
	await GameServer.register(user_a, PASSWORD)
	var local_a := {"house": _demo_house(), "economy": {"xp": 0},
		"character": {"data": {"name": "Ana", "appearance": {"shirt": "#ffd166"}}, "level": 0, "cell": [8, 27],
			"saved_unix": int(Time.get_unix_time_from_system())}}
	var result: Dictionary = await GameServer.load_game(local_a)
	_check(result["ok"], "cuenta nueva con la partida importada")
	GameServer.game_loaded = true
	GameState.from_dict(CloudSync.merge(local_a, result["data"], GameServer.user_id(), user_a))
	Economy.from_dict(GameState.economy)
	Economy.use_server(true)
	Economy.apply_server_state(result["data"])

	# La segunda cuenta empieza un servicio ya (para la trampa del paso 4).
	_b = GameServerScript.new()
	_b.session_path = "user://demo_b_session.json"
	_b.emits_events = false
	add_child(_b)
	_b.logout()
	_b.start()
	await _b.register(user_b, PASSWORD)
	await _b.load_game({"house": _demo_house(), "economy": {"xp": 0}})
	var b_stove: Dictionary = await _b.call_rpc("build_apply", {"writes": [
		HouseData.write(0, "objects", "o50", {"item": "stove_restaurant", "cell": [21, 18], "rot": 0})]})
	await _b.call_rpc("build_accelerate", {})
	var b_open: Dictionary = await _b.call_rpc("restaurant_open", {})
	var b_start: Dictionary = await _b.call_rpc("service_start", {})
	_check(b_stove["ok"] and b_open["data"].get("ok", false) and b_start["data"].get("ok", false),
		"la cuenta B abre su restaurante y empieza un servicio")
	var b_money := int(b_start["data"]["state"]["money"])
	var early: Dictionary = await _b.call_rpc("service_finish", {"actions": [], "coins": 99999})
	_check(not early["data"].get("ok", true) and early["data"].get("reason", "") == "too_early",
		"cobrar antes de los 90 s: \"%s\"" % early["data"].get("error", ""))

	var load: Dictionary = await Economy.request("restaurant_load")
	var summary := Restaurant.normalize(load["data"].get("restaurant"))
	_check(not summary["open"] and summary["missing"].size() == 1 and summary["missing"][0]["id"] == "stove_restaurant",
		"el servidor dice que falta: %s" % Restaurant.missing_text(summary["missing"]))
	_check(summary["seats"] == 3, "3 mesas de restaurante = 3 lugares")
	var refused: Dictionary = await Economy.request("restaurant_open")
	_check(not refused["ok"] and refused["error"].contains("Plancha"), "sin plancha no abre: \"%s\"" % refused["error"])
	var money := Economy.money
	result = await Economy.request("build_apply", {"writes": [
		HouseData.write(0, "objects", "o40", {"item": "stove_restaurant", "cell": [21, 18], "rot": 0})]})
	_check(result["ok"] and Economy.money == money - 450, "comprar la plancha: el servidor cobra $450")
	load = await Economy.request("restaurant_load")
	_check(Restaurant.normalize(load["data"]["restaurant"])["missing"].size() == 1, "mientras está en obra, todavía falta")
	result = await Economy.request("build_accelerate")
	_check(result["ok"], "acelerar la obra")

	_main = preload("res://scenes/main.tscn").instantiate()
	add_child(_main)
	var rig: Node3D = _main.get_node("CameraRig")
	_main.house.from_dict(_house_from_server())
	_main.set_mode("live")
	var view: HouseView = _main.get_node("House")
	if view.low_walls:
		EventBus.view_walls_toggle_requested.emit()
	var walls: Dictionary = _main.house.get_layer(0, "walls")
	_check(walls.has("h:20,17") and walls.has("h:21,26"), "el edificio del restaurante tiene sus paredes (%d en total)" % walls.size())
	rig.set_state({"x": 21.0 - 16.0, "z": 21.5 - 16.0, "yaw": 20.0, "distance": 17.0})
	await _frames(10)
	await _shot("restaurante_1_parcela.png")

	print("\n2) Abrir el restaurante (Menú → Restaurante)")
	EventBus.restaurant_panel_requested.emit()
	var panel: Control = _main.get_node("HUD/RestaurantPanel")
	await _wait_until(func() -> bool: return not Restaurant.summary.is_empty(), 10.0)
	await _frames(5)
	_check(panel.visible and panel.get_node("%OpenButton").visible and not panel.get_node("%OpenButton").disabled,
		"panel: \"%s\"" % panel.get_node("%StatusLabel").text)
	panel.get_node("%OpenButton").pressed.emit()
	await _wait_until(func() -> bool: return Restaurant.is_open(), 10.0)
	await _frames(5)
	_check(Restaurant.is_open() and panel.get_node("%ServeButton").visible, "abierto: aparece Atender")
	_check(panel.get_node("%InfoLabel").text.contains("$600"), "muestra el tope de hoy: \"%s\"" %
		panel.get_node("%InfoLabel").text.split("\n")[1])
	await _shot("restaurante_2_panel.png")
	result = await Economy.request("restaurant_collect")
	_check(not result["ok"] and result["error"].contains("Todavía"), "recién abierto, la caja no juntó nada")
	panel.hide()

	_main.set_mode("build")
	await _frames(5)
	var bar: Node = _main.get_node("HUD").find_child("BottomBar", true, false)
	bar._tool_buttons["shop"].button_pressed = true
	await _frames(4)
	var tabs := _main.get_node("HUD").get_node("%Categories").get_children().filter(
		func(b): return not b.is_queued_for_deletion())
	_check(tabs.size() > 0 and tabs[0].text.contains("Restaurante"),
		"la Tienda, mirando el restaurante, recomienda primero: \"%s\"" % (tabs[0].text if tabs.size() > 0 else ""))
	await _shot("restaurante_3_tienda.png")
	bar._tool_buttons["shop"].button_pressed = false
	_main.set_mode("live")
	await _frames(3)

	print("\n3) Un servicio entero (1:30) jugado en la pantalla")
	EventBus.restaurant_panel_requested.emit()
	await _frames(5)
	money = Economy.money
	panel.get_node("%ServeButton").pressed.emit()
	var game: Control = _main.get_node("HUD/RestaurantGame")
	_check(await _wait_until(func() -> bool: return game.visible, 10.0), "se abre el minijuego (semilla del servidor)")
	var other: Dictionary = await GameServer.call_rpc("service_start", {})
	_check(not other["data"].get("ok", true) and other["data"].get("reason", "") == "active",
		"no se puede empezar otro servicio a la vez")
	var answer := {}
	EventBus.restaurant_service_finished.connect(func(r): answer.merge(r), CONNECT_ONE_SHOT)
	var bot := RestaurantBot.new()
	bot.step_ms = 450
	var shot_times := {12000: "restaurante_4_servicio.png"}
	var grill_shot := false
	var next_tap := 0
	while game._running:
		var t: int = game.service_time()
		if t >= next_tap and t >= 0:
			var a := bot.next_action(game.sim, t)
			if not a.is_empty():
				game.do_action(a[0], a[1], t)
			next_tap = t + bot.step_ms
		# Captura de la plancha: con algo cocinándose y el plato a medio armar.
		if not grill_shot and t > 30000 and not game.sim.plate.is_empty() and game.sim.grill.any(func(g): return g != null):
			await _shot("restaurante_5_plancha.png")
			grill_shot = true
		for when in shot_times.keys():
			if t >= when:
				await _shot(shot_times[when])
				shot_times.erase(when)
		await get_tree().process_frame
	var local: Dictionary = game.sim.result()
	_check(local["served"] >= 5, "en el teléfono: %d clientes atendidos, $%d" % [local["served"], local["coins"]])
	_check(await _wait_until(func() -> bool: return not answer.is_empty(), 30.0), "el servidor respondió")
	_check(answer.get("valid", false) and int(answer.get("coins", -1)) == local["coins"],
		"el SERVIDOR repitió el servicio y contó lo mismo: $%d" % int(answer.get("coins", -1)))
	_check(int(answer.get("pay", 0)) == local["coins"] and Economy.money == money + local["coins"],
		"cobró $%d (dinero: $%d)" % [int(answer.get("pay", 0)), Economy.money])
	_check(int(answer.get("xp_gained", 0)) == local["served"], "experiencia: %d" % int(answer.get("xp_gained", 0)))
	await _frames(5)
	_check(game.visible and game._result_label.text.contains("Cobraste"), "pantalla final con lo cobrado")
	await _shot("restaurante_6_resultado.png")
	game._done_button.pressed.emit()
	await _frames(5)
	await _wait_until(func() -> bool: return int(Restaurant.summary.get("services", 0)) == 1, 10.0)
	_check(int(Restaurant.summary["day_earned"]) == local["coins"] and int(Restaurant.summary["services"]) == 1,
		"el panel anota el servicio y lo ganado hoy")
	_check(not Restaurant.has_pending(), "no queda nada pendiente")
	await _shot("restaurante_7_panel_despues.png")
	panel.hide()

	print("\n4) Trampas (cuenta B, su servicio ya pasó los 90 s)")
	var robot: Array = []
	for i in 300:
		robot.append([500 + i * 10, RestaurantSim.TAKE, i % 6])
	var cheat: Dictionary = await _b.call_rpc("service_finish", {"actions": robot, "coins": 99999, "pay": 99999})
	_check(cheat["data"].get("ok", false) and not cheat["data"].get("valid", true),
		"toques de robot + puntaje inventado: \"%s\"" % cheat["data"].get("error_text", ""))
	_check(int(cheat["data"]["state"]["money"]) == b_money, "B no cobró nada ($%d)" % int(cheat["data"]["state"]["money"]))
	var again: Dictionary = await _b.call_rpc("service_finish", {"actions": []})
	_check(not again["data"].get("ok", true), "el mismo servicio no se puede mandar de nuevo")

	print("\n5) Casa compartida: cerrar el restaurante pide permiso")
	_main.queue_free()
	_main = null
	await _frames(3)
	await _b.call_rpc("couple_invite", {"username": user_a})
	await GameServer.call_rpc("couple_answer", {"from_id": _b.user_id(), "accept": true})
	await _b.call_rpc("couple_propose", {"kind": "move_in", "home": "yours"})
	await GameServer.call_rpc("couple_respond", {"accept": true})
	var b_load: Dictionary = await _b.call_rpc("restaurant_load", {})
	_check(Restaurant.normalize(b_load["data"]["restaurant"])["open"], "B vive con A: ve el restaurante de la casa, abierto")
	var close: Dictionary = await GameServer.call_rpc("restaurant_close", {})
	_check(close["data"].get("requested", false), "A pide cerrarlo: queda como pedido")
	var home: Dictionary = await _b.call_rpc("home_load", {})
	var requests: Array = home["data"].get("home", {}).get("requests", [])
	_check(requests.size() == 1 and requests[0].get("business", "") == "close", "B ve el pedido \"%s\"" %
		(requests[0].get("text", "") if requests.size() > 0 else ""))
	if requests.size() > 0:
		await _b.call_rpc("home_answer", {"id": requests[0]["id"], "approve": true})
	var a_load: Dictionary = await GameServer.call_rpc("restaurant_load", {})
	_check(not Restaurant.normalize(a_load["data"]["restaurant"])["open"], "B aprobó: el restaurante quedó cerrado")
	await GameServer.call_rpc("couple_end", {})

	GameServer.logout()
	Economy.use_server(false)
	_b.logout()
	_restore_saves()
	print("\nDEMO RESTAURANTE: %d pasaron, %d fallaron · capturas: %s" % [_passed, _failed, ", ".join(_shots)])
	get_tree().quit(1 if _failed > 0 else 0)


# --- La parcela de prueba: casa a la izquierda, restaurante a la derecha ---

func _demo_house() -> Dictionary:
	var level := {"foundation": {}, "floors": {}, "walls": {}, "objects": {}}
	_building(level, Vector2i(4, 19), Vector2i(11, 25), Vector2i(7, 25))
	_building(level, Vector2i(16, 17), Vector2i(26, 25), Vector2i(21, 25))
	level["objects"] = {
		"o1": {"item": "bed_basic", "cell": [5, 20], "rot": 0},
		"o2": {"item": "stove_basic", "cell": [9, 20], "rot": 0},
		"o3": {"item": "sofa_basic", "cell": [6, 23], "rot": 0},
		"o10": {"item": "counter_restaurant", "cell": [18, 18], "rot": 0},
		"o11": {"item": "table_restaurant", "cell": [18, 22], "rot": 0},
		"o12": {"item": "table_restaurant", "cell": [21, 22], "rot": 0},
		"o13": {"item": "table_restaurant", "cell": [24, 22], "rot": 0},
		"o14": {"item": "stool_restaurant", "cell": [18, 23], "rot": 0},
		"o15": {"item": "stool_restaurant", "cell": [21, 23], "rot": 0},
		"o16": {"item": "stool_restaurant", "cell": [24, 23], "rot": 0},
		"o17": {"item": "plant_pot", "cell": [25, 18], "rot": 0},
	}
	return {"levels": [level], "next_id": 60, "lot_size": [HouseGrid.LOT_SIZE.x, HouseGrid.LOT_SIZE.y]}


## Un edificio de un piso: cimientos, piso, paredes alrededor y una puerta.
func _building(level: Dictionary, a: Vector2i, b: Vector2i, door_cell: Vector2i) -> void:
	for c in HouseGrid.cells_in_rect(a, b):
		level["foundation"][HouseGrid.cell_key(c)] = {"item": "foundation_basic"}
		level["floors"][HouseGrid.cell_key(c)] = {"item": "floor_basic"} if a.x < 12 else \
			{"item": "floor_tile", "color": "#ffe1b0"}
	for edge in HouseGrid.edges_around_rect(a, b):
		level["walls"][edge] = {"item": "wall_basic"} if a.x < 12 else \
			{"item": "wall_basic", "color_a": "#ff8f6b", "color_b": "#ff8f6b"}
	var door := "h:%d,%d" % [door_cell.x, door_cell.y + 1]
	if level["walls"].has(door):
		level["walls"][door]["opening"] = "door_basic"


## La casa tal como quedó en el servidor (después de comprar y acelerar).
func _house_from_server() -> Dictionary:
	var house := HouseData.new()
	house.from_dict(GameState.house)
	house.apply([HouseData.write(0, "objects", "o40", {"item": "stove_restaurant", "cell": [21, 18], "rot": 0})])
	return house.to_dict()


# --- Ayudantes (como en couple_live_demo) ---

func _shot(file_name: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image != null:
		var dir := _shot_dir if _shot_dir != "" else "user://"
		image.save_png(dir.path_join(file_name))
		_shots.append(file_name)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


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
			DirAccess.copy_absolute(path, path + ".rest_demo")


func _restore_saves() -> void:
	for path in SAVE_FILES:
		if FileAccess.file_exists(path + ".rest_demo"):
			DirAccess.copy_absolute(path + ".rest_demo", path)
			DirAccess.remove_absolute(path + ".rest_demo")
		elif FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
