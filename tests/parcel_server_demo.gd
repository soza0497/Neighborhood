extends Node
## Demostración contra el servidor DE VERDAD (Pulido 2C): la parcela y los
## servicios de limpieza. El servidor tiene que estar arrancado (docs/servidor.md).
##
##   godot --headless --path . res://tests/parcel_server_demo.tscn
##
## Crea una cuenta "demo_NNNN". Tarda ~25 segundos (la espera real de la maleza).
## No toca la partida del jugador (usa user://demo_session.json).

const PASSWORD := "demo-clave-123"

var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()


func _check(condition: bool, description: String) -> void:
	if condition:
		_passed += 1
		print("  OK   ", description)
	else:
		_failed += 1
		print("FALLÓ  ", description)


func _rpc(name: String, payload := {}) -> Dictionary:
	var result: Dictionary = await GameServer.call_rpc(name, payload)
	return result["data"] if result.get("ok", false) else {"ok": false, "error": str(result.get("error", "sin respuesta"))}


func _run() -> void:
	GameServer.use_session_file("user://demo_session.json")
	GameServer.logout()
	GameServer.start()
	var user := "demo_%d" % randi_range(1000, 99999)
	print("Servidor: %s · cuenta de prueba: %s" % [GameServer.address_text(), user])
	_check(await GameServer.check_connection(), "el servidor responde")
	var result: Dictionary = await GameServer.register(user, PASSWORD)
	_check(result["ok"], "crear la cuenta")

	print("\n1) La casa vieja (parcela de 32) queda en el centro de la de 96")
	var local := {
		"house": {"levels": [{"foundation": {"1,1": {"item": "foundation_basic"}}, "walls": {"h:2,3": {"item": "wall_basic"}}}],
			"next_id": 4, "lot_size": [32, 32], "format": 3},
		"economy": {"money": 99999, "xp": 0, "discovered": []},
		"character": {"data": {"name": "Demo"}, "saved_unix": 100},
	}
	result = await GameServer.load_game(local)
	var house: Dictionary = JSON.parse_string(result["data"]["house"])
	_check(house["levels"][3]["foundation"].has("33,33") and not house["levels"][3]["foundation"].has("1,1") and house["levels"][3]["walls"].has("h:34,35"),
		"cimientos y paredes se movieron 32 celdas")
	_check(house["lot_size"] == [96.0, 96.0] or house["lot_size"] == [96, 96], "la casa ahora dice que la parcela mide 96")
	_check(int(result["data"]["money"]) == 3000, "dinero inicial $3000")

	print("\n2) La parcela del servidor es la misma que genera el teléfono")
	var data := await _rpc("parcel_load")
	_check(data.get("ok", false) and data["parcel"].has("seed"), "parcel_load responde con la semilla")
	var seed := int(data["parcel"]["seed"])
	var obstacles := ParcelRules.generate(ParcelRules.config(), seed)
	_check(obstacles.size() > 400 and int(data["parcel"]["count"]) == 0 and data["parcel"]["cleared"].is_empty(), "%d obstáculos, ninguno limpio" % obstacles.size())
	var bush := {}
	var tree := {}
	var center := Vector2(48, 74)
	for o in obstacles:
		if o["kind"] == "bush" and (bush.is_empty() or Vector2(o["x"], o["z"]).distance_to(center) < Vector2(bush["x"], bush["z"]).distance_to(center)):
			bush = o
		if o["kind"] == "tree" and (tree.is_empty() or Vector2(o["x"], o["z"]).distance_to(center) < Vector2(tree["x"], tree["z"]).distance_to(center)):
			tree = o

	print("\n3) Nada se construye encima de un obstáculo (servidor autoritativo)")
	var key := "%d,%d" % [bush["x"], bush["z"]]
	data = await _rpc("build_apply", {"writes": [HouseData.write(0, "foundation", key, {"item": "foundation_basic"})]})
	_check(not data.get("ok", true) and str(data.get("error", "")).contains("obstáculo"), "cimientos sobre la maleza: \"%s\"" % data.get("error", ""))
	data = await _rpc("build_apply", {"writes": [HouseData.write(0, "foundation", "%d,%d" % [tree["x"], tree["z"]], {"item": "foundation_basic"})]})
	_check(not data.get("ok", true), "cimientos sobre un árbol: no")
	data = await _rpc("build_apply", {"writes": [HouseData.write(0, "foundation", "40,40", {"item": "foundation_basic"})]})
	_check(data.get("ok", false), "en la zona libre de la casa sí")

	print("\n4) Llamar al servicio: cobra el servidor, espera real")
	var money_before := int((await _rpc("parcel_load"))["state"]["money"])
	data = await _rpc("parcel_clear_start", {"id": "x:1,1"})
	_check(not data.get("ok", true) and str(data.get("error", "")).contains("no existe"), "un obstáculo inventado: \"%s\"" % data.get("error", ""))
	data = await _rpc("parcel_clear_start", {"id": bush["id"]})
	_check(data.get("ok", false) and int(data["cost"]) == 15, "llamar al servicio de la maleza cuesta $15")
	_check(int(data["state"]["money"]) == money_before - 15, "el servidor cobró: $%d → $%d" % [money_before, int(data["state"]["money"])])
	_check(data["parcel"]["pending"].has(bush["id"]) and int(data["parcel"]["pending"][bush["id"]]["seconds_left"]) > 0, "queda en camino")
	var again := await _rpc("parcel_clear_start", {"id": bush["id"]})
	_check(not again.get("ok", true), "no se llama dos veces: \"%s\"" % again.get("error", ""))
	var early := await _rpc("parcel_clear_finish", {"id": bush["id"]})
	_check(not early.get("ok", true) and str(early.get("error", "")).contains("todavía no llegó"), "terminar antes de tiempo: \"%s\"" % early.get("error", ""))
	var rock := {}
	for o in obstacles:
		if o["kind"] == "rock":
			rock = o
			break
	var money_now := int(data["state"]["money"])
	data = await _rpc("parcel_clear_start", {"id": rock["id"]})
	if data.get("ok", false):
		_check(int(data["cost"]) == 250 and int(data["state"]["money"]) == money_now - 250, "la roca cuesta $250 (el precio sube recién cuando se limpia algo)")
	else:
		_check(str(data.get("error", "")).contains("camino") or str(data.get("error", "")).contains("entrar"), "la roca no tiene camino libre: \"%s\" (el servidor revisa el acceso)" % data.get("error", ""))

	print("\n5) Pasa la espera: el servicio llega y limpia (~20 s)")
	await get_tree().create_timer(21.0).timeout
	data = await _rpc("parcel_clear_finish", {"id": bush["id"]})
	if data.get("blocked", false):
		_check(false, "no debería estar bloqueado: %s" % data.get("reason", ""))
	_check(data.get("ok", false) and data.get("cleared", "") == bush["id"], "la maleza quedó limpia")
	_check(int(data["xp_gained"]) == 2 and int(data["parcel"]["count"]) == 1 and data["parcel"]["cleared"] == [bush["id"]], "da 2 de experiencia y queda anotada")
	data = await _rpc("build_apply", {"writes": [HouseData.write(0, "foundation", key, {"item": "foundation_basic"})]})
	_check(data.get("ok", false), "ahora sí se puede construir donde estaba la maleza")
	data = await _rpc("parcel_load")
	_check(data["parcel"]["cleared"] == [bush["id"]] and int(data["parcel"]["count"]) == 1, "queda guardado en el servidor")
	data = await _rpc("parcel_clear_finish", {"id": bush["id"]})
	_check(not data.get("ok", true), "no se limpia dos veces")

	print("\nDEMO PARCELA EN EL SERVIDOR: %d pasaron, %d fallaron · cuenta %s" % [_passed, _failed, user])
	get_tree().quit(1 if _failed > 0 else 0)
