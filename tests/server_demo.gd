extends Node
## Demostración contra el servidor DE VERDAD (tiene que estar arrancado, ver
## docs/servidor.md): crea una cuenta "demo_NNNN", entra, importa una partida,
## sube el personaje, renueva la sesión y simula quedarse sin conexión.
##
##   godot --headless --path . res://tests/server_demo.tscn
##
## No toca la partida ni la sesión del jugador: usa user://demo_session.json
## y no guarda nada en save.json. Deja la cuenta demo en el servidor (se ve en
## la consola; se puede borrar desde allí).

const PASSWORD := "demo-clave-123"

var _passed := 0
var _failed := 0
var _statuses: Array = []


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
	EventBus.server_status_changed.connect(func(online: bool, _user: String) -> void: _statuses.append(online))
	GameServer.use_session_file("user://demo_session.json")
	GameServer.logout()
	GameServer.start()
	var user := "demo_%d" % randi_range(1000, 99999)
	print("Servidor: %s · cuenta de prueba: %s" % [GameServer.address_text(), user])

	print("\n1) Cuenta")
	_check(await GameServer.check_connection(), "el servidor responde en %s" % GameServer.address_text())
	var result: Dictionary = await GameServer.login(user, PASSWORD)
	_check(not result["ok"] and result["error"].contains("No hay"), "entrar con una cuenta que no existe: \"%s\"" % result["error"])
	result = await GameServer.register(user, PASSWORD)
	_check(result["ok"] and GameServer.has_session() and GameServer.username() == user, "crear la cuenta")
	var saved := FileAccess.get_file_as_string("user://demo_session.json")
	_check(saved.contains("refresh_token") and not saved.contains(PASSWORD), "sesión recordada en el archivo, sin la contraseña")
	result = await GameServer.register(user, "otra-clave-123")
	_check(not result["ok"] and result["error"].contains("ya existe"), "crear otra vez el mismo usuario: \"%s\"" % result["error"])
	result = await GameServer.login(user, "otra-clave-123")
	_check(not result["ok"] and result["error"].contains("incorrectos"), "contraseña mala: \"%s\"" % result["error"])
	result = await GameServer.login(user, PASSWORD)
	_check(result["ok"], "entrar con la contraseña buena")

	print("\n2) Importar la partida del teléfono (una sola vez)")
	var local := {
		"house": {"levels": [{"foundation": {"1,1": {"item": "foundation_basic"}}, "walls": {}}], "next_id": 4},
		"economy": {"money": 99999, "xp": 150, "discovered": ["foundation_basic", "pieza_inventada"]},
		"character": {"data": {"name": "Demo"}, "saved_unix": 100},
		"settings": {"show_fps": false},
	}
	result = await GameServer.load_game(local)
	var data: Dictionary = result["data"]
	_check(result["ok"] and data.get("imported", false), "game_load + game_import")
	# Desde la 4B el servidor revisa la casa y la completa (todos los pisos, con
	# todas sus capas): lo construido llega igual.
	var house: Dictionary = JSON.parse_string(data["house"])
	_check(house["levels"].size() == HouseGrid.LEVEL_COUNT and house["levels"][3]["foundation"].has("1,1")
		and house["levels"][3]["walls"].is_empty() and int(house["next_id"]) == 4,
		"la casa llegó con lo construido (y las capas vacías como diccionarios)")
	_check(int(data["money"]) == 3000, "el dinero empieza en $3000 (no en el del teléfono)")
	_check(int(data["xp"]) == 150 and data["discovered"] == ["foundation_basic"], "experiencia importada; piezas que no existen, descartadas")
	local["economy"]["xp"] = 999
	result = await GameServer.load_game(local)
	_check(result["ok"] and int(result["data"]["xp"]) == 150, "segunda vez: no se vuelve a importar")

	print("\n3) Personaje y opciones en la nube")
	var state := local.duplicate(true)
	state["account"] = {"user_id": GameServer.user_id(), "username": user}
	state["character"] = {"data": {"name": "Demo cambiado"}, "saved_unix": 200}
	result = await GameServer.upload_cloud(state)
	_check(result["ok"], "subir personaje y opciones")
	result = await GameServer.load_game(local)
	_check(JSON.parse_string(result["data"]["character"])["data"]["name"] == "Demo cambiado", "el personaje vuelve de la nube")
	var merged := CloudSync.merge({}, result["data"], GameServer.user_id(), user)
	_check(merged["house"]["next_id"] == 4 and merged["settings"]["show_fps"] == false, "teléfono nuevo: casa y opciones desde la nube")
	var other := state.duplicate(true)
	other["account"] = {"user_id": "otra-cuenta"}
	result = await GameServer.upload_cloud(other)
	_check(not result["ok"], "nunca se sube la partida de otra cuenta")

	print("\n4) Acceso único: la sesión se renueva sola")
	GameServer.use_session_file("user://demo_session.json")
	_check(GameServer.has_session() and GameServer.username() == user, "al \"abrir el juego otra vez\" la sesión sigue ahí")
	GameServer.session.token_exp = 0  # Como si hubieran pasado 2 horas.
	result = await GameServer.resume()
	var now := int(Time.get_unix_time_from_system())
	_check(result["ok"] and GameServer.session.token_exp > now + 3600, "pase vencido → se pidió uno nuevo sin contraseña")
	result = await GameServer.call_rpc("game_load", {})
	_check(result["ok"], "el pase nuevo sirve")

	print("\n5) Sin conexión")
	var real_url := GameServer.base_url
	GameServer.base_url = "http://127.0.0.1:7359"  # Un puerto donde no hay nada.
	result = await GameServer.load_game(local)
	_check(not result["ok"] and result["offline"] and not GameServer.online, "sin servidor: \"%s\"" % result["error"])
	GameServer.base_url = real_url
	_check(await GameServer.check_connection() and GameServer.online, "vuelve la conexión")
	_check(_statuses.has(false) and _statuses.back() == true, "el indicador recibió desconectado → conectado")
	GameServer.base_url = "http://127.0.0.1:7350"
	_check(await GameServer.check_connection(), "también responde en 127.0.0.1")
	GameServer.base_url = real_url

	GameServer.logout()
	_check(not FileAccess.file_exists("user://demo_session.json"), "cerrar sesión borra la sesión recordada")
	print("\nDEMO SERVIDOR: %d pasaron, %d fallaron · cuenta %s" % [_passed, _failed, user])
	get_tree().quit(1 if _failed > 0 else 0)
