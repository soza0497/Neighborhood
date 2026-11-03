extends Node
## Demostración de la Fase 5 contra el servidor DE VERDAD (tiene que estar
## arrancado, ver docs/servidor.md), con DOS cuentas a la vez:
##
##   godot --headless --path . res://tests/couple_demo.tscn
##
## - A usa el juego de verdad: GameServer, Couple, Economy y la escena
##   principal (la casa se pone al día sola cuando B cambia algo).
## - B es un segundo cliente dentro del mismo programa (otro GameServer, con
##   su propio socket), que hace lo que haría el teléfono de la pareja.
##
## Prueba: invitar y aceptar, presencia y estado (la intención del personaje)
## en tiempo real, casarse, mudarse, cambios menores al instante con aviso y
## "Deshacer", cambios estructurales con aprobación, la caja de la casa,
## conflictos (los dos a la vez), deshacer sin pisar lo del otro, las reglas
## de apoyo en el servidor y separarse. Tarda menos de un minuto.
##
## No toca la partida ni la sesión del jugador (usa user://demo_*_session.json
## y no guarda save.json). Las cuentas demo quedan en el servidor.

const PASSWORD := "demo-clave-123"
const GameServerScript := preload("res://scripts/autoload/game_server.gd")

var _passed := 0
var _failed := 0
var _b: Node  # El segundo cliente (GameServer de B).
var _b_notes: Array = []
var _a_notices: Array = []
var _main: Node
var _user_a := ""
var _user_b := ""
var _shift_started_msec := 0


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
	# La escena principal guarda sola: se aparta la partida del jugador y se
	# devuelve al terminar (la demo no la toca).
	_backup_saves()
	var suffix := randi_range(1000, 99999)
	_user_a = "demo_a%d" % suffix
	_user_b = "demo_b%d" % suffix
	print("Servidor: %s · cuentas de prueba: %s y %s" % [GameServer.address_text(), _user_a, _user_b])
	GameServer.use_session_file("user://demo_a_session.json")
	GameServer.logout()
	GameServer.start()
	if not await GameServer.check_connection():
		print("FALLÓ  el servidor no responde en %s (¿está arrancado?)" % GameServer.address_text())
		get_tree().quit(1)
		return
	await _setup_players()
	await _test_invite_and_presence()
	await _test_marry_and_move()
	await _test_minor_changes()
	await _test_structural_changes()
	await _test_fund()
	await _test_conflicts()
	await _test_separation()

	_main.queue_free()
	GameServer.logout()
	Couple.clear()
	Economy.use_server(false)
	_b.logout()
	_restore_saves()
	print("\nDEMO PAREJA: %d pasaron, %d fallaron · cuentas %s y %s" % [_passed, _failed, _user_a, _user_b])
	get_tree().quit(1 if _failed > 0 else 0)


# --- 1) Dos jugadores ---

func _setup_players() -> void:
	print("\n1) Dos cuentas: A (el juego de verdad) y B (otro teléfono)")
	var result: Dictionary = await GameServer.register(_user_a, PASSWORD)
	_check(result["ok"], "crear la cuenta de A")
	# La casa de A: cimientos y piso de 10 x 10, y un sofá.
	var local_a := {
		"house": {"levels": [{"foundation": _cells(0, 0, 10, 10, "foundation_basic"),
			"floors": _cells(0, 0, 10, 10, "floor_basic"),
			"objects": {"o1": {"item": "sofa_basic", "cell": [2, 2], "rot": 0}}}], "next_id": 2},
		"economy": {"xp": 2000, "discovered": ["foundation_basic", "floor_basic", "sofa_basic"]},
	}
	result = await GameServer.load_game(local_a)
	_check(result["ok"], "A entra y su casa queda en el servidor")
	GameServer.game_loaded = true
	GameState.from_dict(CloudSync.merge(local_a, result["data"], GameServer.user_id(), _user_a))
	GameState.character = {}
	Economy.from_dict(GameState.economy)
	Economy.use_server(true)
	Economy.apply_server_state(result["data"])
	Couple.apply_answer(result["data"])
	GameServer.start_realtime()
	EventBus.partner_notice.connect(func(text: String, entry: int) -> void: _a_notices.append({"text": text, "entry": entry}))
	_main = preload("res://scenes/main.tscn").instantiate()
	add_child(_main)

	_b = GameServerScript.new()
	_b.name = "GameServerB"
	_b.session_path = "user://demo_b_session.json"
	_b.emits_events = false
	add_child(_b)
	_b.logout()
	_b.start()
	result = await _b.register(_user_b, PASSWORD)
	_check(result["ok"], "crear la cuenta de B")
	var local_b := {"house": {"levels": [{"foundation": _cells(20, 20, 3, 3, "foundation_basic")}], "next_id": 1},
		"economy": {"xp": 2000}}
	result = await _b.load_game(local_b)
	_check(result["ok"] and _b.user_id() != GameServer.user_id(), "B entra con su propia casa")
	_b.socket.notification_received.connect(func(code: int, _s: String, content: Dictionary) -> void:
		_b_notes.append({"code": code, "content": content}))
	_b.start_realtime()
	_check(await _wait_until(func() -> bool: return GameServer.socket.connected and _b.socket.connected),
		"los dos conectados en tiempo real (WebSocket)")


# --- 2) Invitar, aceptar, presencia ---

func _test_invite_and_presence() -> void:
	print("\n2) Invitar, aceptar y verse en tiempo real")
	var result: Dictionary = await Couple.invite("nadie_existe_123")
	_check(not result["ok"] and result["error"].contains("No hay"), "invitar a alguien que no existe: \"%s\"" % result["error"])
	result = await Couple.invite(_user_b)
	_check(result["ok"] and Couple.couple["invite_to_name"] == _user_b, "A invita a B")
	_check(await _wait_until(func() -> bool: return _b_has_note(101)), "a B le llega el aviso al instante (código 101)")
	result = await _b.call_rpc("couple_load", {})
	var invites: Array = CouplePanelData.invites(result)
	_check(invites.size() == 1 and invites[0]["from_name"] == _user_a, "B ve la invitación de A")
	result = await _b.call_rpc("couple_answer", {"from_id": GameServer.user_id(), "accept": true})
	_check(result["ok"] and result["data"].get("ok", false), "B acepta")
	_check(await _wait_until(func() -> bool: return Couple.in_couple()), "A se entera solo: son pareja")
	_check(Couple.couple["status"] == "dating" and Couple.partner_name() == _user_b, "estado: \"%s\"" % CoupleState.status_text(Couple.couple))

	# Presencia: A sigue a B (Couple lo hace solo); B sigue a A.
	_b.socket.follow([GameServer.user_id()])
	_check(await _wait_until(func() -> bool: return Couple.partner_online), "A ve a B en línea")
	var intention := {"character": "Beto", "state": "acting", "action": "cook", "verb": "cocinando",
		"object": "Cocina", "key": "o9", "object_level": 0, "level": 0, "since": int(Time.get_unix_time_from_system())}
	_b.socket.update_status(CoupleState.encode_status(intention))
	_check(await _wait_until(func() -> bool: return Couple.partner_intention.get("verb", "") == "cocinando"),
		"A recibe lo que hace el personaje de B: \"%s\"" % Character.intention_text(Couple.partner_intention))
	EventBus.character_intention_changed.emit({"character": "Ana", "state": "acting", "action": "sleep",
		"verb": "durmiendo", "object": "Cama", "key": "o3", "object_level": 0, "level": 0, "since": 0})
	_check(await _wait_until(func() -> bool:
		return CoupleState.decode_status(_b.socket.status_of(GameServer.user_id())).get("verb", "") == "durmiendo"),
		"B recibe lo que hace el personaje de A (se mandan estados, no movimientos)")
	_b.stop_realtime()
	_check(await _wait_until(func() -> bool: return not Couple.partner_online), "B se desconecta: A lo ve fuera de línea")
	_b.start_realtime()
	_check(await _wait_until(func() -> bool: return Couple.partner_online), "B vuelve: en línea otra vez")


# --- 3) Casarse y mudarse ---

func _test_marry_and_move() -> void:
	print("\n3) Casarse y mudarse juntos")
	_b_notes.clear()
	var result: Dictionary = await Couple.propose("marry")
	_check(result["ok"] and Couple.couple["proposal_kind"] == "marry", "A pide casamiento")
	_check(await _wait_until(func() -> bool: return _b_has_note(101)), "a B le llega el pedido")
	result = await _b.call_rpc("couple_respond", {"accept": true})
	_check(result["data"].get("ok", false) and CoupleState.normalize_couple(result["data"]["couple"])["status"] == "married",
		"B acepta: matrimonio")
	_check(await _wait_until(func() -> bool: return Couple.couple["status"] == "married"), "A se entera solo")
	result = await _b.call_rpc("couple_propose", {"kind": "move_in", "home": "yours"})
	_check(result["data"].get("ok", false), "B propone mudarse a la casa de A")
	_check(await _wait_until(func() -> bool: return Couple.couple["proposal_kind"] == "move_in"), "A ve el pedido")
	result = await Couple.respond(true)
	_check(result["ok"] and Couple.shared() and Couple.home["owner_is_me"], "A acepta: viven juntos en la casa de A")
	result = await _b.call_rpc("game_load", {})
	var b_house := _house_of(result["data"].get("house", ""))
	_check(b_house.get_piece(0, "objects", "o1") != null and bool(result["data"].get("shared", false)),
		"B ahora carga la casa de A (con el sofá)")
	await _wait_until(func() -> bool: return not Economy.busy)


# --- 4) Cambios menores: al instante, con aviso y Deshacer ---

func _test_minor_changes() -> void:
	print("\n4) Cambios menores: al instante, con aviso y \"Deshacer\"")
	_a_notices.clear()
	var result: Dictionary = await _b.call_rpc("build_apply", {"writes": [
		HouseData.write(0, "objects", "o1", {"item": "sofa_basic", "cell": [5, 5], "rot": 1})]})
	_check(result["data"].get("ok", false) and not result["data"].get("requested", false), "B mueve el sofá: al instante (sin permiso)")
	_check(await _wait_until(func() -> bool: return _cell_of("o1") == Vector2i(5, 5)),
		"en la pantalla de A el sofá se movió solo (la casa se puso al día)")
	_check(await _wait_until(func() -> bool: return not _a_notices.is_empty()) and _a_notices[0]["text"].contains("movió")
		and _a_notices[0]["entry"] > 0, "a A le aparece el aviso: \"%s\" con Deshacer" % (_a_notices[0]["text"] if not _a_notices.is_empty() else ""))
	var b_money := int((await _b.call_rpc("game_load", {}))["data"]["money"])
	result = await _b.call_rpc("build_apply", {"writes": [
		HouseData.write(0, "objects", "o50", {"item": "chair_basic", "cell": [8, 8], "rot": 0})]})
	_check(result["data"].get("ok", false) and int(result["data"]["state"]["money"]) == b_money - 40,
		"B pone una silla: le cobra a B ($40, la caja está vacía)")
	_check(await _wait_until(func() -> bool: return _main.house.get_piece(0, "objects", "o50") != null), "A ve la silla")
	await _wait_until(func() -> bool: return _a_notices.size() >= 2)
	var entry: int = _a_notices.back()["entry"]
	result = await Couple.revert(entry)
	_check(result["ok"], "A toca Deshacer en el aviso de la silla")
	_check(await _wait_until(func() -> bool: return _main.house.get_piece(0, "objects", "o50") == null), "la silla se fue")
	result = await _b.call_rpc("game_load", {})
	_check(int(result["data"]["money"]) == b_money and _house_of(result["data"]["house"]).get_piece(0, "objects", "o50") == null,
		"a B le devolvieron sus $40 (el dinero vuelve a quien pagó)")
	result = await Couple.revert(entry)
	_check(not result["ok"], "no se deshace dos veces: \"%s\"" % result["error"])


# --- 5) Cambios estructurales: piden aprobación ---

func _test_structural_changes() -> void:
	print("\n5) Cambios estructurales: piden aprobación")
	var walls := [HouseData.write(0, "walls", "h:0,0", {"item": "wall_basic"}),
		HouseData.write(0, "walls", "h:1,0", {"item": "wall_basic"})]
	var result: Dictionary = await _b.call_rpc("build_apply", {"writes": walls})
	_check(result["data"].get("ok", false) and result["data"].get("requested", false), "B levanta 2 paredes: queda como pedido")
	_check(await _wait_until(func() -> bool: return Couple.home["requests"].size() == 1), "A ve el pedido: \"%s\"" %
		(Couple.home["requests"][0]["text"] if not Couple.home["requests"].is_empty() else ""))
	_check(_main.house.get_piece(0, "walls", "h:0,0") == null, "todavía no está construido")
	var b_money := int((await _b.call_rpc("game_load", {}))["data"]["money"])
	result = await Couple.answer_request(Couple.home["requests"][0]["id"], true)
	_check(result["ok"], "A aprueba")
	_check(await _wait_until(func() -> bool: return _main.house.get_piece(0, "walls", "h:0,0") != null), "las paredes aparecen en la casa de A")
	result = await _b.call_rpc("game_load", {})
	_check(int(result["data"]["money"]) == b_money - 40 and result["data"].get("can_undo", false),
		"lo pagó B ($40) y le queda en su Deshacer")
	_b_notes.clear()
	result = await _b.call_rpc("build_apply", {"writes": [HouseData.write(0, "walls", "h:2,0", {"item": "wall_basic"})]})
	await _wait_until(func() -> bool: return Couple.home["requests"].size() == 1)
	result = await Couple.answer_request(Couple.home["requests"][0]["id"], false)
	_check(result["ok"] and Couple.home["requests"].is_empty() and _main.house.get_piece(0, "walls", "h:2,0") == null,
		"A rechaza otro pedido: no se construye")
	_check(await _wait_until(func() -> bool: return _b_has_note(104)), "a B le avisan que no se aprobó")
	result = await _b.call_rpc("build_apply", {"writes": [HouseData.write(0, "walls", "h:20,1", {"item": "wall_basic"})]})
	_check(not result["data"].get("ok", true) and str(result["data"].get("error", "")).contains("apoyarse"),
		"una pared en el aire: el servidor la rechaza (reglas de apoyo)")
	# Pulido 1: A arma una PROPUESTA con varios cambios y la manda entera.
	var builder: HouseBuilder = _main.get_node("House/Builder")
	_main.set_mode("build")
	var asked: bool = await builder._apply([HouseData.write(0, "walls", "v:0,0", {"item": "wall_basic"})])
	await builder._apply([HouseData.write(0, "walls", "v:0,1", {"item": "wall_basic"})])
	_check(asked and builder.draft_mode() == "own" and builder.draft_writes().size() == 2
		and _main.house.get_piece(0, "walls", "v:0,0") != null, "A arma una propuesta de 2 cambios (se ven en su casa)")
	_check(Couple.home["requests"].is_empty(), "todavía no se mandó nada")
	_main._on_game_saving()
	_check(not GameState.house["levels"][0]["walls"].has("v:0,0"), "la propuesta no se guarda como si estuviera construida")
	_check(await builder.send_draft(), "A manda la propuesta")
	await _wait_until(func() -> bool: return not Economy.busy)
	await Couple.refresh()
	_check(Couple.home["requests"].size() == 1 and Couple.home["requests"][0]["by_me"]
		and str(Couple.home["requests"][0]["text"]).contains("x2") and _main.house.get_piece(0, "walls", "v:0,0") == null,
		"un solo pedido con todo (\"%s\"); en la casa todavía no está" % (Couple.home["requests"][0]["text"] if not Couple.home["requests"].is_empty() else ""))
	result = await _b.call_rpc("couple_load", {})
	var pending: Array = CoupleState.normalize_home(result["data"]["home"])["requests"]
	_check(pending.size() == 1 and not pending[0]["by_me"], "B ve la propuesta de A")
	result = await _b.call_rpc("home_request", {"id": pending[0]["id"]})
	var preview: Variant = JSON.parse_string(str(result["data"].get("request", {}).get("writes_json", "")))
	_check(result["data"].get("ok", false) and preview is Array and preview.size() == 2,
		"B la puede previsualizar entera (2 piezas)")
	result = await _b.call_rpc("home_answer", {"id": pending[0]["id"], "approve": true})
	var both_built := func() -> bool: return _main.house.get_piece(0, "walls", "v:0,0") != null and _main.house.get_piece(0, "walls", "v:0,1") != null
	_check(result["data"].get("ok", false) and await _wait_until(both_built), "B la aprueba entera: aparece en la pantalla de A")

	# Y al revés: B propone, A la ve en su casa y la aprueba desde la barra.
	result = await _b.call_rpc("build_apply", {"writes": [HouseData.write(0, "walls", "h:3,0", {"item": "wall_basic"})]})
	_check(await _wait_until(func() -> bool: return Couple.home["requests"].size() == 1), "B propone otra pared")
	EventBus.proposal_review_requested.emit(Couple.home["requests"][0]["id"])
	_check(await _wait_until(func() -> bool: return builder.draft_mode() == "review"), "A la previsualiza en su casa")
	_check(_main.house.get_piece(0, "walls", "h:3,0") != null, "se ve la pared propuesta")
	EventBus.proposal_answer_requested.emit(true)
	var approved := func() -> bool: return not builder.has_draft() and Couple.home["requests"].is_empty() and _main.house.get_piece(0, "walls", "h:3,0") != null
	_check(await _wait_until(approved, 10.0), "A la aprueba: queda construida")
	_main.set_mode("live")


# --- 6) La caja de la casa ---

func _test_fund() -> void:
	print("\n6) Caja de la casa común y unir ingresos")
	var result: Dictionary = await _b.call_rpc("home_contribute", {"amount": 500})
	_check(result["data"].get("ok", false) and int(result["data"]["state"]["fund"]) == 500, "B pone $500 en la caja")
	await Couple.refresh()
	_check(await _wait_until(func() -> bool: return Economy.fund == 500), "A ve la caja: $%d" % Economy.fund)
	var a_money := Economy.money
	var ok: bool = await _main.get_node("House/Builder")._apply([HouseData.write(0, "objects", _main.house.new_id(),
		{"item": "tv_basic", "cell": [0, 9], "rot": 0})])
	_check(ok and Economy.fund == 100 and Economy.money == a_money, "A pone una tele ($400): sale de la caja, no de su billetera")
	result = await Couple.contribute(99999999)
	_check(not result["ok"], "no se puede aportar más de lo que se tiene")
	result = await _b.call_rpc("couple_switches", {"pool_income": true})
	_check(result["data"].get("ok", false), "B prende \"unir ingresos\" (su sueldo irá a la caja)")
	_check(await _wait_until(func() -> bool: return Couple.couple["partner_pool_income"]), "A lo ve")
	# B consigue empleo y empieza un turno (se cobra más adelante, en el 8).
	await _b.call_rpc("job_apply", {"job_id": "courier"})
	await _b.call_rpc("job_accelerate", {})
	result = await _b.call_rpc("shift_start", {})
	_shift_started_msec = Time.get_ticks_msec()
	_check(result["data"].get("ok", false), "B empieza un turno de Repartidor")


# --- 7) Conflictos: los dos a la vez ---

func _test_conflicts() -> void:
	print("\n7) Los dos a la vez: gana la última escritura, y nadie pisa lo del otro")
	var answers: Array = []
	var move := func(client: Node, cell: Array) -> void:
		answers.append(await client.call_rpc("build_apply", {"writes": [
			HouseData.write(0, "objects", "o1", {"item": "sofa_basic", "cell": cell, "rot": 0})]}))
	move.call(GameServer, [1, 6])
	move.call(_b, [6, 1])
	await _wait_until(func() -> bool: return answers.size() == 2)
	_check(answers.all(func(a: Dictionary) -> bool: return a["data"].get("ok", false)), "los dos mueven el mismo sofá a la vez: los dos se aceptan")
	var server := _house_of((await _b.call_rpc("home_load", {}))["data"]["house"])
	var final_cell := HouseData.object_anchor(server.get_piece(0, "objects", "o1"))
	_check(final_cell in [Vector2i(1, 6), Vector2i(6, 1)], "queda donde lo dejó el último (%s)" % final_cell)
	_main.call("_on_home_remote_changed", {"rev": Economy.house_rev + 100})
	_check(await _wait_until(func() -> bool: return _cell_of("o1") == final_cell), "A queda igual que el servidor")

	answers.clear()
	var build := func(client: Node, key: String, cell: Array) -> void:
		answers.append(await client.call_rpc("build_apply", {"writes": [
			HouseData.write(0, "objects", key, {"item": "chair_basic", "cell": cell, "rot": 0})]}))
	build.call(GameServer, "o60", [3, 8])
	build.call(_b, "o61", [4, 8])
	await _wait_until(func() -> bool: return answers.size() == 2)
	server = _house_of((await _b.call_rpc("home_load", {}))["data"]["house"])
	_check(server.get_piece(0, "objects", "o60") != null and server.get_piece(0, "objects", "o61") != null,
		"dos sillas a la vez en lugares distintos: quedan las dos")

	# A pone una biblioteca; B la mueve; el Deshacer de A no pisa lo de B.
	await _main.get_node("House/Builder")._apply([HouseData.write(0, "objects", "o70",
		{"item": "bookshelf_basic", "cell": [7, 3], "rot": 0})])
	await _b.call_rpc("build_apply", {"writes": [HouseData.write(0, "objects", "o70",
		{"item": "bookshelf_basic", "cell": [7, 4], "rot": 0})]})
	var undo: Dictionary = await Economy.request("build_undo")
	_check(undo["ok"] and undo["data"].get("skipped", false), "A deshace la biblioteca que B movió: se descarta (\"%s\")" % undo["data"].get("message", ""))
	server = _house_of((await _b.call_rpc("home_load", {}))["data"]["house"])
	_check(server.get_piece(0, "objects", "o70") != null and HouseData.object_anchor(server.get_piece(0, "objects", "o70")) == Vector2i(7, 4),
		"la biblioteca sigue donde la dejó B")
	await Couple.refresh()
	var log: Array = Couple.home["log"]
	_check(log.size() >= 8 and log.any(func(e: Dictionary) -> bool: return e["kind"] == "approved")
		and log.any(func(e: Dictionary) -> bool: return e["kind"] == "revert"), "historial de la casa: %d entradas (con aprobados y deshechos)" % log.size())


# --- 8) Separarse ---

func _test_separation() -> void:
	print("\n8) El sueldo de B va a la caja; después se separan")
	await _wait_until(func() -> bool: return Time.get_ticks_msec() - _shift_started_msec > 48000, 60.0)
	await _wait_until(func() -> bool: return not Economy.busy)
	var fund_before := Economy.fund
	var b_before := int((await _b.call_rpc("game_load", {}))["data"]["money"])
	var paid: Dictionary = await _b.call_rpc("shift_complete", {})
	_check(paid["data"].get("ok", false) and paid["data"].get("to_fund", false)
		and int(paid["data"]["state"]["money"]) == b_before, "B cobra el turno: $%d van a la caja, no a su billetera" % int(paid["data"].get("pay", 0)))
	_check(await _wait_until(func() -> bool: return Economy.fund == fund_before + 120), "A ve la caja con el sueldo de B ($%d)" % Economy.fund)
	await _wait_until(func() -> bool: return not Economy.busy)
	await _b.call_rpc("home_contribute", {"amount": 301})
	# A se entera por el aviso del servidor (Couple vuelve a preguntar solo).
	_check(await _wait_until(func() -> bool: return Economy.fund >= 301), "B pone $301 más: A ve la caja en $%d" % Economy.fund)
	await _wait_until(func() -> bool: return not Economy.busy)
	var fund := Economy.fund
	var b_money := int((await _b.call_rpc("game_load", {}))["data"]["money"])
	var a_money := Economy.money
	var result: Dictionary = await _b.call_rpc("couple_end", {})
	_check(result["data"].get("ok", false) and result["data"].get("home_changed", false), "B termina la relación")
	_check(await _wait_until(func() -> bool: return not Couple.in_couple()), "A se entera solo")
	result = await _b.call_rpc("game_load", {})
	var b_house := _house_of(result["data"]["house"])
	_check(b_house.get_layer(0, "foundation").has("20,20") and b_house.get_piece(0, "objects", "o1") == null,
		"B vuelve a su propia casa (que quedó guardada)")
	_check(int(result["data"]["money"]) == b_money + fund / 2, "B se lleva la mitad de la caja ($%d)" % (fund / 2))
	await _wait_until(func() -> bool: return not Economy.busy)
	await Couple.refresh()
	_check(await _wait_until(func() -> bool: return Economy.money == a_money + fund - fund / 2 and not Economy.shared),
		"A se queda con su casa y la otra mitad ($%d)" % (fund - fund / 2))
	_check(Couple.couple["events"].size() >= 4, "queda el historial de relaciones")


# --- Ayudantes ---

const SAVE_FILES := ["user://save.json", "user://save.json.bak"]


func _backup_saves() -> void:
	for path in SAVE_FILES:
		if FileAccess.file_exists(path):
			DirAccess.copy_absolute(path, path + ".couple_demo")


func _restore_saves() -> void:
	for path in SAVE_FILES:
		if FileAccess.file_exists(path + ".couple_demo"):
			DirAccess.copy_absolute(path + ".couple_demo", path)
			DirAccess.remove_absolute(path + ".couple_demo")
		elif FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _b_has_note(code: int) -> bool:
	return _b_notes.any(func(n: Dictionary) -> bool: return n["code"] == code)


func _cell_of(key: String) -> Vector2i:
	var piece: Variant = _main.house.get_piece(0, "objects", key)
	return HouseData.object_anchor(piece) if piece != null else Vector2i(-1, -1)


func _house_of(text: Variant) -> HouseData:
	var house := HouseData.new()
	var data: Variant = JSON.parse_string(str(text)) if str(text) != "" else {}
	if data is Dictionary:
		house.from_dict(data)
	return house


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


## Lee las invitaciones de una respuesta de couple_load.
class CouplePanelData:
	static func invites(result: Dictionary) -> Array:
		return CoupleState.normalize_couple(result["data"].get("couple", {}))["invites_in"]
