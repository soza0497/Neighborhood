extends Node
## Pruebas automáticas del cliente del servidor, SIN red: sesión (JWT),
## validación de usuario y contraseña, textos de error, qué se importa, cómo se
## une la partida del teléfono con la de la nube, qué se sube, y (Fase 4B)
## cómo se copia lo que responde el servidor (dinero, empleo, casa, deshacer).
##
##   godot --headless --path . res://tests/test_server.tscn
##
## La prueba contra el servidor de verdad es tests/server_demo.tscn.

var _passed := 0
var _failed := 0


func _ready() -> void:
	_test_session()
	_test_credentials()
	_test_error_texts()
	_test_import_payload()
	_test_merge()
	_test_cloud_objects()
	_test_config()
	_test_server_answers()
	_test_server_state()
	await _test_server_mode()
	print("\nPRUEBAS: %d pasaron, %d fallaron" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _check(condition: bool, description: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		print("FALLÓ: ", description)


## Arma un JWT de mentira (sin firma válida) con estos datos.
func _fake_jwt(claims: Dictionary) -> String:
	var payload := Marshalls.utf8_to_base64(JSON.stringify(claims))
	payload = payload.replace("+", "-").replace("/", "_").replace("=", "")
	return "eyJhbGciOiJIUzI1NiJ9.%s.firma" % payload


func _test_session() -> void:
	var now := 1_800_000_000
	var token := _fake_jwt({"exp": now + 7200, "uid": "u-1", "usn": "andres_ñ"})
	var refresh := _fake_jwt({"exp": now + 31536000, "uid": "u-1", "usn": "andres_ñ"})
	var session := ServerSession.from_tokens(token, refresh)
	_check(session.is_valid(), "sesión con los dos pases es válida")
	_check(session.user_id == "u-1" and session.username == "andres_ñ", "lee id y usuario del token (con tildes)")
	_check(session.token_exp == now + 7200, "lee el vencimiento del token")
	_check(not session.token_expiring(now), "token recién dado no vence")
	_check(session.token_expiring(now + 7200 - 30), "a 30 s de vencer pide renovar")
	_check(not session.refresh_expired(now + 1000), "el pase largo dura")
	_check(session.refresh_expired(now + 31536000), "el pase largo también vence")

	var new_token := _fake_jwt({"exp": now + 9000, "uid": "u-1", "usn": "andres_ñ"})
	session.update_tokens(new_token, "")
	_check(session.refresh_token == refresh and session.token_exp == now + 9000, "renovar sin pase largo nuevo conserva el anterior")

	var copy := ServerSession.from_dict(session.to_dict())
	_check(copy.token == new_token and copy.refresh_token == refresh and copy.user_id == "u-1", "la sesión se guarda y se lee igual")
	_check(not session.to_dict().has("password"), "la sesión no guarda contraseña")
	_check(ServerSession.parse_claims("basura").is_empty(), "un token roto no rompe nada")
	_check(not ServerSession.from_dict({}).is_valid(), "sesión vacía no es válida")


func _test_credentials() -> void:
	_check(GameServer.check_credentials("andres", "12345678") == "", "usuario y contraseña buenos")
	_check(GameServer.check_credentials("an", "12345678") != "", "usuario muy corto")
	_check(GameServer.check_credentials("Andrés", "12345678") != "", "sin mayúsculas ni tildes")
	_check(GameServer.check_credentials("mi casa", "12345678") != "", "sin espacios")
	_check(GameServer.check_credentials("andres", "1234567") != "", "contraseña de 7 es corta")


func _test_error_texts() -> void:
	_check(GameServer.error_text(409, "Username is already in use.").contains("ya existe"), "409 = usuario repetido")
	_check(GameServer.error_text(401, "Invalid credentials.").contains("incorrectos"), "401 = datos incorrectos")
	_check(GameServer.error_text(404, "").contains("No hay"), "404 = no existe la cuenta")
	_check(GameServer.error_text(400, "Password must be at least 8 characters long.").contains("8"), "400 = contraseña corta")


func _local_state() -> Dictionary:
	return {
		"house": {"levels": [{"floors": {"1,1": {"item": "floor_basic"}}}], "next_id": 3},
		"economy": {"money": 1234, "xp": 150, "discovered": ["floor_basic"], "job": {"job_id": "cashier"}},
		"character": {"data": {"name": "Ana"}, "saved_unix": 100},
		"settings": {"show_fps": false},
		"account": {},
	}


func _test_import_payload() -> void:
	var payload := CloudSync.import_payload(_local_state())
	_check(JSON.parse_string(payload["house"])["next_id"] == 3, "la casa va como texto JSON")
	_check(payload["xp"] == 150 and payload["discovered"] == ["floor_basic"], "experiencia y descubiertas")
	_check(not payload.has("money"), "el dinero NO se importa (empieza en el inicial)")
	_check(JSON.parse_string(payload["character"])["data"]["name"] == "Ana", "personaje como texto")
	var empty := CloudSync.import_payload({})
	_check(empty["house"] == "" and empty["xp"] == 0 and empty["discovered"] == [], "partida vacía: todo vacío")


func _server_answer() -> Dictionary:
	return {
		"imported": true,
		"house": JSON.stringify({"levels": [{"walls": {"h:0,0": {"item": "wall_basic"}}}], "next_id": 9}),
		"xp": 300,
		"discovered": {},  # Lua devuelve la lista vacía así.
		"money": 3000,
		"character": JSON.stringify({"data": {"name": "Nube"}, "saved_unix": 50}),
		"settings": JSON.stringify({"show_fps": true, "show_hints": false}),
	}


func _test_merge() -> void:
	# Mismo teléfono (partida sin cuenta todavía): desde la 4B manda el servidor.
	var merged := CloudSync.merge(_local_state(), _server_answer(), "u-1", "andres")
	_check(merged["house"]["next_id"] == 9, "aunque el teléfono tenga casa, manda la del servidor (4B)")
	_check(merged["economy"]["money"] == 3000, "y su economía (el dinero del servidor)")
	_check(merged["character"]["data"]["name"] == "Ana", "personaje del teléfono si es más nuevo")
	_check(merged["settings"]["show_fps"] == false, "opciones del teléfono")
	_check(merged["account"] == {"user_id": "u-1", "username": "andres"}, "la partida queda marcada con la cuenta")

	# Teléfono recién instalado: todo de la nube.
	merged = CloudSync.merge({}, _server_answer(), "u-1", "andres")
	_check(merged["house"]["next_id"] == 9, "sin casa en el teléfono: la del servidor")
	_check(merged["economy"]["money"] == 3000 and merged["economy"]["xp"] == 300, "dinero y experiencia del servidor")
	_check(merged["economy"]["discovered"] == [], "lista vacía de Lua ({}) se lee como lista")
	_check(merged["character"]["data"]["name"] == "Nube", "personaje de la nube")
	_check(merged["settings"]["show_hints"] == false, "opciones de la nube")

	# Personaje más nuevo en la nube (otro teléfono): gana la nube.
	var newer := _server_answer()
	newer["character"] = JSON.stringify({"data": {"name": "Otra"}, "saved_unix": 500})
	merged = CloudSync.merge(_local_state(), newer, "u-1", "andres")
	_check(merged["character"]["data"]["name"] == "Otra", "gana el personaje más nuevo")

	# La partida del teléfono es de OTRA cuenta: no se mezcla nada.
	var other := _local_state()
	other["account"] = {"user_id": "u-2", "username": "pareja"}
	merged = CloudSync.merge(other, _server_answer(), "u-1", "andres")
	_check(merged["house"]["next_id"] == 9 and merged["economy"]["money"] == 3000, "otra cuenta: casa y dinero del servidor")
	_check(merged["character"]["data"]["name"] == "Nube", "otra cuenta: personaje de la nube")
	var empty_server := {"imported": true, "house": "", "money": 3000, "xp": 0, "discovered": {}}
	merged = CloudSync.merge(other, empty_server, "u-1", "andres")
	_check(merged["house"].is_empty() and merged["economy"]["xp"] == 0, "otra cuenta y servidor vacío: partida nueva")

	# Misma cuenta: casa y empleo del servidor; del teléfono, el día del turno.
	var mine := _local_state()
	mine["account"] = {"user_id": "u-1", "username": "andres"}
	mine["economy"]["job"]["last_work_day"] = 7
	merged = CloudSync.merge(mine, _server_answer(), "u-1", "andres")
	_check(merged["house"]["next_id"] == 9 and merged["economy"]["job"]["job_id"] == ""
		and merged["economy"]["job"]["last_work_day"] == 7, "misma cuenta: manda el servidor; del teléfono solo el día del último turno")


func _test_cloud_objects() -> void:
	var objects := CloudSync.cloud_objects(_local_state())
	_check(objects.size() == 2, "se suben personaje y opciones")
	var character: Dictionary = objects[0]
	var value: Dictionary = JSON.parse_string(character["value"])
	_check(character["collection"] == "cloud" and character["key"] == "character", "personaje en cloud/character")
	_check(JSON.parse_string(value["json"])["data"]["name"] == "Ana" and int(value["saved_unix"]) == 100, "valor = {json, saved_unix}")
	_check(character["permission_read"] == 1 and character["permission_write"] == 1, "solo lo ve y lo cambia el dueño")
	_check(CloudSync.cloud_objects(_local_state())[1]["value"] == objects[1]["value"], "opciones iguales = mismo valor (no se resuben)")
	_check(CloudSync.cloud_objects({}).is_empty(), "nada que subir")


func _test_config() -> void:
	_check(GameServer.base_url == "http://192.168.100.177:7350", "dirección del servidor leída de data/server.json")
	_check(GameServer.server_key == "neighborhood-family", "llave del cliente leída")
	_check(not GameServer.active, "sin pantalla de entrada no habla con el servidor")
	_check(SaveSystem.account_save_path("a/b").begins_with("user://save.account_"), "partida apartada por cuenta")


# --- Fase 4B: lo que responde el servidor ---

func _test_server_answers() -> void:
	var payload := CloudSync.import_payload(_local_state())
	_check(payload["job_id"] == "cashier", "se importa el empleo (el servidor revisa el nivel)")

	var economy := CloudSync.economy_from_server({
		"money": 2500.0, "xp": 120.0, "discovered": {},
		"job": {"job_id": "courier", "applied_job": "", "resume_ready_at": 0, "shift_active": true, "last_shift_unix": 99.0},
	}, {"job": {"last_work_day": 4}})
	_check(economy["money"] == 2500 and economy["xp"] == 120 and economy["discovered"] == [], "economía del servidor (números enteros, lista vacía de Lua)")
	_check(economy["job"]["job_id"] == "courier" and economy["job"]["pending_pay"] == true, "turno en marcha = pendiente de cobrar")
	_check(economy["job"]["last_work_day"] == 4 and economy["job"]["last_shift_unix"] == 99, "el día del turno es del teléfono")
	_check(CloudSync.economy_from_server({})["money"] == SaveMigrations.STARTING_MONEY, "respuesta vacía: valores iniciales")

	var writes := CloudSync.writes_from_server([
		{"level": 1.0, "layer": "floors", "key": "2,3", "value": {"item": "floor_basic"}},
		{"level": 0.0, "layer": "objects", "key": "o4"},  # Lua no manda el null de "quitar".
	])
	_check(writes.size() == 2 and writes[0]["level"] == 1 and typeof(writes[0]["level"]) == TYPE_INT, "nivel como entero")
	_check(writes[1].has("value") and writes[1]["value"] == null, "sin value = quitar (null)")
	_check(CloudSync.writes_from_server({}).is_empty(), "lista vacía de Lua ({}) = sin escrituras")
	var house := HouseData.new()
	house.apply([HouseData.write(0, "objects", "o4", {"item": "chair_basic", "cell": [1, 1], "rot": 0})])
	house.apply(writes)
	_check(house.has_piece(1, "floors", "2,3") and not house.has_piece(0, "objects", "o4"), "las escrituras del servidor se aplican a la casa")


func _test_server_state() -> void:
	var levels: Array = []
	var toasts: Array = []
	var on_level := func(level: int, _names: Array) -> void: levels.append(level)
	var on_toast := func(text: String) -> void: toasts.append(text)
	EventBus.level_up.connect(on_level)
	EventBus.toast.connect(on_toast)
	Economy.from_dict({})
	Economy.use_server(true)
	_check(Economy.server_mode and not Economy.busy, "modo servidor encendido")

	var now := int(Time.get_unix_time_from_system())
	Economy.applied_job = "courier"
	Economy.apply_server_state({
		"money": 1500, "xp": 260, "discovered": ["bed_basic"], "can_undo": true, "can_redo": false,
		"server_unix": now + 30,
		"job": {"job_id": "courier", "applied_job": "", "resume_ready_at": 0, "shift_active": false, "last_shift_unix": 0},
	})
	_check(Economy.money == 1500 and Economy.xp == 260 and Economy.discovered.has("bed_basic"), "dinero, experiencia y descubiertas del servidor")
	_check(Economy.level() == 3 and levels == [3], "subir de nivel con lo del servidor avisa una vez")
	_check(Economy.job_id == "courier" and toasts.any(func(t: String) -> bool: return t.contains("contrataron")), "respuesta del currículum: avisa que te contrataron")
	_check(Economy.last_work_day == GameClock.day(), "el primer turno es al día siguiente")
	_check(abs(Economy.now() - (now + 30)) <= 1, "la hora se ajusta a la del servidor")
	_check(Economy.server_can_undo and not Economy.server_can_redo, "deshacer según el servidor")

	var history := UndoHistory.new(HouseData.new())
	history.remote = true
	_check(history.can_undo() and not history.can_redo(), "historial remoto: pregunta al servidor")
	var flags: Array = []
	history.changed.connect(func(u: bool, r: bool) -> void: flags.append([u, r]))
	history.apply_remote([HouseData.write(0, "foundation", "1,1", {"item": "foundation_basic"})])
	_check(flags == [[true, false]], "aplicar lo del servidor actualiza los botones")

	EventBus.level_up.disconnect(on_level)
	EventBus.toast.disconnect(on_toast)


func _test_server_mode() -> void:
	# Sin conexión (las pruebas no hablan con el servidor): no se pide nada.
	_check(not GameServer.online, "en las pruebas no hay conexión")
	_check(not Economy.can_request(), "sin conexión no se pide nada al servidor")
	GameClock.minutes = float(GameClock.START_MINUTES) + 1440.0 * 3 + 12 * 60
	Economy.job_id = "courier"
	Economy.last_work_day = 0
	_check(not Economy.shift_due(), "sin conexión no se sale a trabajar")
	var result: Dictionary = await Economy.request("build_apply", {"writes": []})
	_check(not result["ok"] and result["error"] != "", "pedido sin servidor ni cuenta: \"%s\"" % result["error"])
	_check(not Economy.busy, "después de fallar ya no espera")
	Economy.busy = true
	result = await Economy.request("build_apply", {"writes": []})
	_check(not result["ok"] and result["busy"], "un segundo pedido mientras se espera: no sale (sin dobles toques)")
	Economy.busy = false
	_check(not await Economy.request_apply("courier"), "mandar currículum sin conexión: no")
	_check(await Economy.request_shift_pay() == 0, "cobrar sin conexión: 0 (se reintenta después)")

	# Modo de prueba otra vez (como lo usan las otras pruebas).
	Economy.use_server(false)
	Economy.from_dict({})
	_check(not Economy.server_mode and Economy.now() == int(Time.get_unix_time_from_system()), "modo de prueba: hora del teléfono")
