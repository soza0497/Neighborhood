extends Node
## Pruebas automáticas de la Fase 6 (restaurante), SIN red: la simulación
## del minijuego da los MISMOS números que el servidor (los mismos casos que
## server/tests/test_rules.lua), la revisión de toques, lo que le falta a
## la casa, lo que manda el servidor y la pantalla del minijuego.
##
##   godot --headless --path . res://tests/test_business.tscn
##
## La prueba contra el servidor de verdad (y con capturas) es
## tests/restaurant_demo.tscn.

var _passed := 0
var _failed := 0
var _svc: Dictionary


func _ready() -> void:
	_svc = RestaurantSim.normalize_service(Catalog.business["restaurant"]["service"])
	_test_data()
	_test_random()
	_test_customers()
	_test_scoring()
	_test_validation()
	_test_bot()
	_test_requirements()
	_test_summary()
	await _test_screen()
	print("\nPRUEBAS: %d pasaron, %d fallaron" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _check(condition: bool, description: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		print("FALLÓ: ", description)


func _test_data() -> void:
	var r: Dictionary = Catalog.business["restaurant"]
	_check(_svc["duration_ms"] == 90000 and _svc["ingredients"].size() == 6, "business.json: 90 s y 6 ingredientes")
	_check(r["requires"].has("counter_restaurant") and r["requires"].has("stove_restaurant")
		and r["requires"].has("table_restaurant"), "pide mostrador, plancha y mesa")
	for id in r["requires"]:
		_check(Catalog.get_item(id).get("category", "") == "restaurant", "%s está en el catálogo (Restaurante)" % id)
	_check(Catalog.categories.has("restaurant"), "categoría Restaurante en la Tienda")
	var rooms := JSON.parse_string(FileAccess.get_file_as_string("res://data/rooms.json")) as Dictionary
	var found := false
	for type in rooms["types"]:
		if type["id"] == "restaurant" and type["items"].has("counter_restaurant"):
			found = true
	_check(found, "rooms.json entiende el cuarto Restaurante")
	_check(int(r["daily_cap"]) > 0 and int(r["passive_cap"]) > 0, "hay tope diario y tope de la caja")


func _test_random() -> void:
	_check(RestaurantSim.new_rng_state(0) == 2147483646, "semilla 0 se arregla (como en Lua)")
	var rng := RestaurantSim._Rng.new(1)
	_check(rng.next_int(2147483647) == 16807 and rng.next_int(2147483647) == 282475249, "Park-Miller: 16807, 282475249")


func _test_customers() -> void:
	# Mismos números que server/tests/test_rules.lua (semilla 4242).
	var cs := RestaurantSim.make_customers(_svc, 4242)
	var arrive_sum := 0
	for c in cs:
		arrive_sum += int(c["arrive"])
	_check(cs.size() == 17 and arrive_sum == 719677, "semilla 4242: 17 clientes, llegadas suman 719677 (igual que Lua)")
	_check(cs[0]["arrive"] == 1500 and cs[0]["order"] == [1, 5] and cs[0]["patience"] == 20000,
		"primer cliente: lechuga + huevo, 20 s (igual que Lua)")
	_check(cs[-1]["arrive"] == 78709 and cs[-1]["patience"] == 14000, "último cliente igual que Lua")
	_check(RestaurantSim.make_customers(_svc, 4243)[1]["arrive"] != cs[1]["arrive"], "otra semilla, otros clientes")


func _test_scoring() -> void:
	var T := RestaurantSim.TAKE
	var G := RestaurantSim.GRILL
	var S := RestaurantSim.SERVE
	var X := RestaurantSim.TRASH
	var play := [[1600, T, 1], [1700, T, 5], [2000, G, 0], [4300, G, 0], [4400, S, 0]]
	var res := RestaurantSim.replay(_svc, 4242, 3, play)
	_check(res["coins"] == 10 and res["served"] == 1 and res["tips"] == 4, "servir bien: 10 monedas (igual que Lua)")
	_check(res["lost"] == 10 and res["skipped"] == 5, "los que se van y los que siguen de largo (igual que Lua)")
	var wrong := [[1600, T, 0], [1700, T, 0], [1800, S, 0], [2000, T, 4], [8000, G, 0], [8100, T, 1], [8200, X, 0]]
	res = RestaurantSim.replay(_svc, 4242, 3, wrong)
	_check(res["coins"] == 0 and res["wrong"] == 1 and res["burned"] == 1 and res["trashed"] == 1,
		"mal servido, quemado y tirado (igual que Lua)")
	res = RestaurantSim.replay(_svc, 4242, 1, [])
	_check(res["skipped"] == 12 and res["lost"] == 4, "una mesa: 12 siguen de largo (igual que Lua)")
	var sim := RestaurantSim.new(_svc, 4242, 3)
	sim.act(1600, T, 0)
	sim.act(1700, S, 0)
	_check(sim.seats[0]["deadline"] == 16500 and sim.plate.is_empty(), "plato equivocado: -5 s de paciencia")
	sim = RestaurantSim.new(_svc, 4242, 3)
	sim.act(1600, T, 4)
	_check(sim.grill_state(0, 2000) == "cooking" and sim.grill_state(0, 4200) == "ready"
		and sim.grill_state(0, 7200) == "burned", "plancha: cocinando, a punto, quemado")
	sim.act(1700, T, 0)
	sim.act(1800, T, 0)
	sim.act(1900, T, 0)
	sim.act(2000, T, 0)
	sim.act(2100, T, 1)
	_check(sim.plate.size() == 4, "el plato lleva 4 cosas como mucho")


func _test_validation() -> void:
	var T := RestaurantSim.TAKE
	_check(RestaurantSim.validate_actions(_svc, 3, [[100, T, 0], [200, T, 1]]) == "", "toques normales")
	_check(RestaurantSim.validate_actions(_svc, 3, [[100, T, 0], [120, T, 1]]) != "", "20 ms entre toques: no")
	_check(RestaurantSim.validate_actions(_svc, 3, [[500, T, 0], [400, T, 1]]) != "", "desordenados: no")
	_check(RestaurantSim.validate_actions(_svc, 3, [[95000, T, 0]]) != "", "después del final: no")
	_check(RestaurantSim.validate_actions(_svc, 1, [[100, RestaurantSim.SERVE, 1]]) != "", "mesa inexistente: no")
	_check(RestaurantSim.replay(_svc, 1, 3, [[100, 9, 0]]).has("invalid"), "acción inventada: inválido")


func _test_bot() -> void:
	# Un jugador ordenado gana algo razonable, y repetir sus toques da lo mismo.
	var sim := RestaurantSim.new(_svc, 4242, 3)
	var actions := RestaurantBot.new().play(sim)
	var live := sim.result()
	var again := RestaurantSim.replay(_svc, 4242, 3, actions)
	_check(live["coins"] > 50 and live["served"] >= 6, "el jugador automático gana algo (%d monedas, %d clientes)" % [
		live["coins"], live["served"]])
	_check(again == live, "repetir los mismos toques da exactamente lo mismo")
	_check(RestaurantSim.validate_actions(_svc, 3, actions) == "", "los toques del jugador automático son válidos")
	_check(live["coins"] < int(Catalog.business["restaurant"]["daily_cap"]), "un servicio no llena el tope del día")


func _test_requirements() -> void:
	var house := HouseData.new()
	var cfg: Dictionary = Catalog.business["restaurant"]
	var req := RestaurantSim.requirements(cfg, house, 1000)
	_check(req["missing"].size() == 3 and req["seats"] == 0, "casa vacía: faltan 3")
	house.apply([
		HouseData.write(0, "objects", "o1", {"item": "counter_restaurant", "cell": [2, 2], "rot": 0}),
		HouseData.write(0, "objects", "o2", {"item": "stove_restaurant", "cell": [2, 4], "rot": 0, "ready_at": 2000}),
		HouseData.write(0, "objects", "o3", {"item": "table_restaurant", "cell": [5, 5], "rot": 0}),
		HouseData.write(0, "objects", "o4", {"item": "table_restaurant", "cell": [7, 5], "rot": 0}),
		HouseData.write(0, "objects", "o5", {"item": "table_restaurant", "cell": [9, 5], "rot": 0}),
		HouseData.write(0, "objects", "o6", {"item": "table_restaurant", "cell": [11, 5], "rot": 0}),
	])
	req = RestaurantSim.requirements(cfg, house, 1000)
	_check(req["missing"].size() == 1 and req["missing"][0]["id"] == "stove_restaurant", "la plancha en obra no cuenta")
	_check(req["missing"][0]["name"] == "Plancha de restaurante", "el nombre sale del catálogo")
	_check(req["seats"] == 3, "4 mesas: 3 lugares (el máximo)")
	_check(RestaurantSim.requirements(cfg, house, 2000)["missing"].is_empty(), "terminada la obra: no falta nada")


func _test_summary() -> void:
	var s := Restaurant.normalize({"open": true, "ready": true, "missing": {}, "seats": 2.0, "passive": 15.0,
		"day_earned": 40.0, "cap_left": 560.0, "daily_cap": 600.0, "active": {}})
	_check(s["open"] and s["missing"] is Array and s["missing"].is_empty() and s["seats"] == 2 and s["passive"] == 15,
		"lo que manda el servidor: listas vacías ({}) y enteros")
	_check(s["active"].is_empty(), "sin servicio en marcha")
	s = Restaurant.normalize({"missing": [{"id": "counter_restaurant", "name": "Mostrador", "need": 1.0, "have": 0.0}],
		"active": {"seed": 5.0, "seats": 1.0, "started_unix": 10.0, "seconds_left": 3.0}})
	_check(Restaurant.missing_text(s["missing"]) == "Mostrador" and s["active"]["seed"] == 5, "falta y servicio en marcha")
	_check(Restaurant.normalize(null)["open"] == false, "sin datos: cerrado")


func _test_screen() -> void:
	var game: Control = load("res://ui/restaurant_game.tscn").instantiate()
	add_child(game)
	game.start({"seed": 4242, "seats": 3, "practice": true})
	_check(game.visible and game.sim.seats.size() == 3, "la pantalla del minijuego se abre con 3 mesas")
	await get_tree().process_frame
	game.do_action(RestaurantSim.TAKE, 1, 1600)
	game.do_action(RestaurantSim.TAKE, 5, 1620)  # Demasiado rápido: no cuenta.
	_check(game.actions.size() == 1, "un toque a los 20 ms del anterior se ignora (el servidor lo rechazaría)")
	game.do_action(RestaurantSim.TAKE, 5, 1700)
	game.do_action(RestaurantSim.GRILL, 0, 4300)
	game.do_action(RestaurantSim.SERVE, 0, 4400)
	_check(game.sim.coins == 10, "servir desde la pantalla: 10 monedas")
	_check(RestaurantSim.replay(_svc, 4242, 3, game.actions)["coins"] == 10, "lo anotado da lo mismo al repetirlo")
	# Los toques en la pantalla caen en el lugar correcto.
	var rect: Rect2 = game._rects["take:0"]
	var before: int = game.actions.size()
	game._start_ms = Time.get_ticks_msec() - 6000
	game.tap(rect.get_center())
	_check(game.actions.size() == before + 1 and game.actions[-1][1] == RestaurantSim.TAKE and game.actions[-1][2] == 0,
		"tocar el pan anota 'tomar pan'")
	game.queue_redraw()
	await get_tree().process_frame
	_check(true, "dibuja sin errores")
	game.queue_free()
