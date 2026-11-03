extends Node
## Demostración de la Fase 4B contra el servidor DE VERDAD (tiene que estar
## arrancado, ver docs/servidor.md): el servidor manda en el dinero y la casa.
##
##   godot --headless --path . res://tests/economy_server_demo.tscn
##
## Crea una cuenta "demo_NNNN" y prueba: precios iguales a los del teléfono,
## desbloqueo por nivel, obras con la hora del servidor, deshacer/rehacer con
## el dinero exacto, acelerar, empleos, un turno completo hecho por el
## personaje dentro del juego (espera ~25 s) y que el teléfono no puede hacer
## trampa. Tarda menos de un minuto.
##
## No toca la partida ni la sesión del jugador (usa user://demo_session.json y
## no guarda save.json). La cuenta demo queda en el servidor (se puede borrar
## desde la consola).

const PASSWORD := "demo-clave-123"

var _passed := 0
var _failed := 0
var _toasts: Array = []
var house := HouseData.new()
var history := UndoHistory.new(house)


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
	EventBus.toast.connect(func(text: String) -> void: _toasts.append(text))
	GameServer.use_session_file("user://demo_session.json")
	GameServer.logout()
	GameServer.start()
	var user := "demo_%d" % randi_range(1000, 99999)
	print("Servidor: %s · cuenta de prueba: %s" % [GameServer.address_text(), user])
	if not await GameServer.check_connection():
		print("FALLÓ  el servidor no responde en %s (¿está arrancado?)" % GameServer.address_text())
		get_tree().quit(1)
		return

	print("\n1) Cuenta nueva: se importa la partida del teléfono")
	var result: Dictionary = await GameServer.register(user, PASSWORD)
	_check(result["ok"], "crear la cuenta")
	var local := {
		"house": {"levels": [{"foundation": _foundation(2, 2, 6, 6)}], "next_id": 1},
		"economy": {"money": 99999, "xp": 0, "discovered": ["foundation_basic"]},
	}
	result = await GameServer.load_game(local)
	_check(result["ok"] and result["data"].get("imported", false) and result["data"].get("house_source", "") == "server",
		"importada (la casa ya es del servidor)")
	var merged := CloudSync.merge(local, result["data"], GameServer.user_id(), user)
	house.from_dict(merged["house"])
	Economy.from_dict(merged["economy"])
	Economy.use_server(true)
	Economy.apply_server_state(result["data"])
	history.remote = true
	_check(Economy.money == 3000 and house.get_layer(0, "foundation").size() == 36, "dinero $3000 y los cimientos del teléfono")

	print("\n2) Construir: cobra el servidor")
	var writes := [
		HouseData.write(0, "floors", "2,2", {"item": "floor_basic"}),
		HouseData.write(0, "floors", "3,2", {"item": "floor_basic"}),
		HouseData.write(0, "floors", "4,2", {"item": "floor_basic"}),
		HouseData.write(0, "walls", "h:2,2", {"item": "wall_basic", "opening": "door_basic"}),
		# Fase 5: el servidor revisa el apoyo; la cama (girada) va sobre los dos pisos.
		HouseData.write(0, "objects", house.new_id(), {"item": "bed_basic", "cell": [2, 2], "rot": 1, "ready_at": 0}),
	]
	var quote := Economy.quote(house, writes)
	result = await _build(writes)
	_check(result["ok"] and int(result["data"]["money_change"]) == quote["money"],
		"el servidor cobró lo mismo que muestra el teléfono ($%d)" % -quote["money"])
	_check(Economy.money == 3000 + quote["money"], "dinero: $%d" % Economy.money)
	var bed: Dictionary = house.get_piece(0, "objects", "o1")
	var server_now := Economy.now()
	_check(bed != null and abs(int(bed.get("ready_at", 0)) - (server_now + 30)) <= 2,
		"la cama queda en obra 30 s con la hora del SERVIDOR (el ready_at del teléfono se ignora)")
	# Primera vez de cada pieza: piso 5 + pared 5 + puerta 8 + cama 30 (los
	# cimientos ya estaban descubiertos).
	_check(Economy.xp == 5 + 5 + 8 + 30, "experiencia por lo nuevo: %d" % Economy.xp)
	_check(history.can_undo() and not history.can_redo(), "el servidor guardó el paso de deshacer")

	var money := Economy.money
	result = await _build([HouseData.write(0, "objects", house.new_id(), {"item": "stairs_basic", "cell": [6, 2], "rot": 0})])
	_check(not result["ok"] and result["error"].contains("nivel 2") and Economy.money == money, "escalera bloqueada: \"%s\"" % result["error"])
	var expensive: Array = []
	for i in 10:
		expensive.append(HouseData.write(0, "objects", house.new_id(), {"item": "bed_basic", "cell": [10 + i, 10], "rot": 0}))
	result = await _build(expensive)
	_check(not result["ok"] and result["error"].begins_with("Te faltan") and Economy.money == money, "sin dinero: \"%s\"" % result["error"])

	print("\n3) Deshacer y rehacer (el servidor devuelve lo exacto)")
	await history.undo()
	_check(Economy.money == 3000 and not house.has_piece(0, "objects", "o1") and not house.has_piece(0, "floors", "2,2"),
		"deshacer devolvió todo: $%d" % Economy.money)
	_check(history.can_redo(), "se puede rehacer")
	await history.redo()
	_check(Economy.money == money and house.has_piece(0, "objects", "o1"), "rehacer volvió a cobrar: $%d" % Economy.money)
	result = await _build([HouseData.write(0, "floors", "4,2", null)])
	_check(result["ok"] and int(result["data"]["money_change"]) == 5, "borrar un piso devuelve el 50 % ($5)")
	await history.undo()
	_check(Economy.money == money and house.has_piece(0, "floors", "4,2"), "deshacer el borrado cobra los $5")

	print("\n4) Acelerar las obras")
	var left := int(house.get_piece(0, "objects", "o1")["ready_at"]) - Economy.now()
	result = await Economy.request("build_accelerate")
	var cost := -int(result["data"].get("money_change", 0))
	_check(result["ok"] and abs(cost - Economy.accelerate_cost(left)) <= 1, "acelerar %d s costó $%d" % [left, cost])
	house.apply(CloudSync.writes_from_server(result["data"].get("writes", [])))
	_check(house.pending_construction().is_empty(), "obras terminadas")
	result = await Economy.request("build_accelerate")
	_check(not result["ok"] and result["error"].contains("No hay obras"), "sin obras no se cobra nada")

	print("\n5) Empleos")
	_check(await Economy.request_apply("courier") and Economy.applied_job == "courier", "currículum de Repartidor enviado")
	_check(not await Economy.request_apply("courier"), "no se manda otro mientras se espera")
	result = await Economy.request("job_status")
	_check(result["ok"] and not result["data"].get("hired", true) and Economy.job_id == "", "todavía no respondieron")
	money = Economy.money
	_toasts.clear()
	_check(await Economy.request_accelerate_resume() and Economy.job_id == "courier", "acelerar la respuesta: contratado")
	_check(money - Economy.money in [29, 30], "acelerar ~5 minutos costó $%d" % (money - Economy.money))
	_check(_toasts.any(func(t: String) -> bool: return t.contains("contrataron")), "aviso: \"te contrataron\"")

	print("\n6) Un turno de trabajo: lo hace el personaje, cobra el servidor")
	# Se abre el juego de verdad (escena principal) con la casa del servidor,
	# a velocidad x5 y un minuto antes de la hora del turno del día siguiente.
	GameState.house = house.to_dict()
	GameState.character = {}
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	GameClock.speed = 5
	GameClock.minutes = float((GameClock.day() + 1) * 1440 + 9 * 60 - 1)
	money = Economy.money
	var xp := Economy.xp
	_check(await _wait_until(func() -> bool: return Economy.pending_pay, 20.0) and Economy.working_now,
		"a las 09:00 el personaje sale a la acera y el servidor anota el turno")
	_check(await Economy.request_shift_pay() == 0 and Economy.money == money, "cobrar enseguida: no (un turno de 4 h dura 48 s a x5)")
	print("       … esperando que termine el turno (~48 s) …")
	_check(await _wait_until(func() -> bool: return Economy.money > money, 70.0)
		and Economy.money == money + 120 and Economy.xp == xp + 20 and not Economy.pending_pay,
		"volvió del trabajo: el servidor pagó $%d y 20 de experiencia" % (Economy.money - money))
	_check(_toasts.any(func(t: String) -> bool: return t.contains("cobró $120")), "aviso: \"cobró $120 del trabajo\"")
	_check(not await Economy.request_shift_start(), "otro turno enseguida: no (como mucho uno cada 288 s)")
	main.queue_free()
	GameClock.speed = 1

	print("\n7) Al entrar: pago de días sin jugar")
	money = Economy.money
	await Economy.request_settle(0.0)
	_check(Economy.settled and Economy.money == money, "acaba de jugar: no hay pago offline")
	result = await GameServer.call_rpc("game_heartbeat", {})
	_check(result["ok"] and result["data"].get("ok", false), "\"sigo jugando\" (heartbeat)")

	print("\n8) Sin dobles toques, y dos pedidos a la vez")
	var answers: Array = []
	var send := func(key: String) -> void:
		answers.append(await _build([HouseData.write(0, "floors", key, {"item": "floor_basic"})]))
	send.call("4,2")
	send.call("5,2")
	await _wait_until(func() -> bool: return answers.size() == 2)
	_check(answers.filter(func(a: Dictionary) -> bool: return a.get("busy", false)).size() == 1,
		"dos toques seguidos: el segundo no sale mientras se espera")
	money = Economy.money
	var raw: Array = []
	var send_raw := func(key: String) -> void:
		raw.append(await GameServer.call_rpc("build_apply", {"writes": [HouseData.write(0, "floors", key, {"item": "floor_basic"})]}))
	for key in ["6,2", "7,2", "6,3"]:
		send_raw.call(key)
	await _wait_until(func() -> bool: return raw.size() == 3)
	for answer in raw:
		house.apply(CloudSync.writes_from_server(answer["data"].get("writes", [])))
	result = await GameServer.call_rpc("game_load", {})
	_check(raw.all(func(a: Dictionary) -> bool: return a["ok"] and a["data"].get("ok", false))
		and int(result["data"]["money"]) == money - 30, "tres pedidos a la vez (otro teléfono): los tres se cobran bien")

	print("\n9) El teléfono no puede hacer trampa")
	result = await GameServer._request(HTTPClient.METHOD_PUT, "/v2/storage", {"objects": [{
		"collection": "game", "key": "house", "value": JSON.stringify({"json": "{}"}),
	}]}, GameServer._bearer_auth())
	_check(not result["ok"], "escribir la casa directo: no se puede")
	result = await Economy.request("build_apply", {"writes": [HouseData.write(0, "floors", "1,1", {"item": "oro_infinito"})]})
	_check(not result["ok"] and result["error"].contains("no existe"), "pieza inventada: \"%s\"" % result["error"])
	result = await Economy.request("build_apply", {"writes": [HouseData.write(0, "floors", "99,1", {"item": "floor_basic"})]})
	_check(not result["ok"], "fuera de la parcela: \"%s\"" % result["error"])
	money = Economy.money
	result = await Economy.request("build_apply", {"writes": [HouseData.write(0, "objects", "o90", null)]})
	_check(result["ok"] and Economy.money == money, "quitar algo que no existe no devuelve dinero")

	print("\n10) Otro teléfono (o reinstalar): todo viene del servidor")
	result = await GameServer.load_game({})
	var fresh := HouseData.new()
	fresh.from_dict(CloudSync.merge({}, result["data"], GameServer.user_id(), user)["house"])
	_check(_same_house(fresh, house) and int(result["data"]["money"]) == Economy.money,
		"la casa y el dinero del servidor son los mismos que en este teléfono")
	_check(result["data"].get("can_undo", false), "y se puede seguir deshaciendo")

	Economy.use_server(false)
	GameServer.logout()
	print("\nDEMO ECONOMÍA EN EL SERVIDOR: %d pasaron, %d fallaron · cuenta %s" % [_passed, _failed, user])
	get_tree().quit(1 if _failed > 0 else 0)


## Pide construir y, si el servidor acepta, lo aplica a la casa (como el
## constructor del juego).
func _build(writes: Array) -> Dictionary:
	var result: Dictionary = await Economy.request("build_apply", {"writes": writes})
	if result["ok"]:
		history.apply_remote(CloudSync.writes_from_server(result["data"].get("writes", [])))
	return result


func _foundation(x0: int, z0: int, width: int, depth: int) -> Dictionary:
	var cells := {}
	for x in range(x0, x0 + width):
		for z in range(z0, z0 + depth):
			cells["%d,%d" % [x, z]] = {"item": "foundation_basic"}
	return cells


## Compara dos casas (como texto, porque los números del JSON llegan como
## decimales).
func _same_house(a: HouseData, b: HouseData) -> bool:
	var normalize := func(h: HouseData) -> String:
		return JSON.stringify(JSON.parse_string(JSON.stringify(h.levels)), "", true)
	return normalize.call(a) == normalize.call(b)


## Espera hasta que se cumpla la condición. Devuelve false si se pasó el tiempo.
func _wait_until(condition: Callable, max_seconds := 10.0) -> bool:
	var end := Time.get_ticks_msec() + int(max_seconds * 1000)
	while not condition.call():
		if Time.get_ticks_msec() > end:
			return false
		await get_tree().process_frame
	return true
