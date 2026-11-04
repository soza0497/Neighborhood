extends Node
## Pruebas automáticas de la economía: precios, deshacer con dinero, niveles,
## obras con temporizador, empleos, pago offline y migración del guardado.
##
##   godot --headless --path . res://tests/test_economy.tscn

var _passed := 0
var _failed := 0


func _ready() -> void:
	HouseGrid.use_test_lot()  # Estas pruebas arman casas en un lote de 32 (la parcela real, desde el Pulido 2C, es de 96).
	_test_costs()
	_test_quote_and_timers()
	_test_history_money()
	_test_levels()
	_test_jobs()
	_test_save_round_trip()
	_test_migration()
	print("\nPRUEBAS: %d pasaron, %d fallaron" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _check(condition: bool, description: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		print("FALLÓ: ", description)


func _fresh() -> void:
	Economy.from_dict({})
	GameClock.minutes = float(GameClock.START_MINUTES)


func _test_costs() -> void:
	_fresh()
	_check(Economy.money == SaveMigrations.STARTING_MONEY, "se empieza con el dinero inicial")
	_check(Economy.piece_cost("floors", {"item": "floor_basic"}) == 10, "un piso cuesta 10")
	_check(Economy.piece_cost("walls", {"item": "wall_basic", "opening": "window_basic"}) == 80, "pared + ventana = 20 + 60")
	_check(Economy.piece_cost("roofs", {"item": "roof_basic", "rect": [0, 0, 2, 3]}) == 90, "techo de 2x3 = 15 x 6")
	_check(Economy.change_for("floors", null, {"item": "floor_basic"}) == -10, "poner un piso: se paga 10")
	_check(Economy.change_for("floors", {"item": "floor_basic"}, null) == 5, "borrar un piso devuelve el 50 %")
	_check(Economy.change_for("floors", {"item": "floor_basic"}, {"item": "floor_basic", "color": "#fff"}) == 0, "pintar es gratis")
	_check(Economy.change_for("floors", {"item": "floor_basic"}, {"item": "floor_tile"}) == -2, "cambiar de piso: se paga la diferencia")
	_check(Economy.change_for("objects", {"item": "bed_basic", "cell": [0, 0]}, {"item": "bed_basic", "cell": [3, 3]}) == 0, "mover un mueble es gratis")


func _test_quote_and_timers() -> void:
	_fresh()
	var house := HouseData.new()
	var stairs := {"item": "stairs_basic", "cell": [1, 1], "rot": 0}
	var writes := [HouseData.write(0, "objects", "o1", stairs), HouseData.write(0, "floors", "0,0", {"item": "floor_basic"})]
	var quote := Economy.quote(house, writes)
	_check(quote["money"] == -210, "escalera + piso = -210")
	_check(int(quote["writes"][0]["value"].get("ready_at", 0)) >= Economy.now() + 119, "la escalera tarda unos 120 s")
	_check(not quote["writes"][1]["value"].has("ready_at"), "el piso es instantáneo")
	_check(not stairs.has("ready_at"), "no se modifica la escritura original")

	house.apply(quote["writes"])
	_check(HouseData.is_under_construction(house.get_piece(0, "objects", "o1")), "la escalera está en obra")
	_check(house.pending_construction().size() == 1, "hay una obra pendiente")
	var moved: Dictionary = house.get_piece(0, "objects", "o1").duplicate(true)
	moved["cell"] = [2, 2]
	var move_quote := Economy.quote(house, [HouseData.write(0, "objects", "o1", moved)])
	_check(move_quote["money"] == 0, "mover una obra no cuesta")
	_check(move_quote["writes"][0]["value"]["ready_at"] == moved["ready_at"], "mover no reinicia el temporizador")

	# Una obra vieja ya terminó.
	moved["ready_at"] = Economy.now() - 5
	house.apply([HouseData.write(0, "objects", "o1", moved)])
	_check(not HouseData.is_under_construction(house.get_piece(0, "objects", "o1")), "con la hora pasada, está terminada")
	_check(Economy.accelerate_cost(120) == 12, "acelerar 2 minutos = 12 monedas")
	_check(Economy.accelerate_cost(1) == 1, "acelerar siempre cuesta al menos 1")
	_check(Economy.accelerate_cost(0) == 0, "sin espera no se paga")


func _test_history_money() -> void:
	_fresh()
	var house := HouseData.new()
	var history := UndoHistory.new(house)
	var start := Economy.money
	history.commit([HouseData.write(0, "foundation", "1,1", {"item": "foundation_basic"})], -5)
	_check(Economy.money == start - 5, "construir cobra")
	history.undo()
	_check(Economy.money == start, "deshacer devuelve lo pagado")
	history.redo()
	_check(Economy.money == start - 5, "rehacer vuelve a cobrar")

	# Un borrado devolvió dinero; si ya se gastó, no se puede deshacer.
	history.commit([HouseData.write(0, "foundation", "1,1", null)], 3)
	Economy.money = 0
	history.undo()
	_check(house.get_piece(0, "foundation", "1,1") == null, "sin dinero para deshacer el borrado: no se deshace")
	_check(Economy.money == 0, "y el dinero no cambia")


func _test_levels() -> void:
	_fresh()
	_check(Economy.level() == 1, "se empieza en el nivel 1")
	_check(not Economy.is_unlocked("stairs_basic"), "la escalera está bloqueada")
	_check(Economy.is_unlocked("bed_basic"), "la cama está libre")
	Economy.add_xp(100)
	_check(Economy.level() == 2, "con 100 de experiencia se llega al nivel 2")
	_check(Economy.is_unlocked("stairs_basic"), "la escalera se desbloquea en el nivel 2")
	_check(Economy.xp_progress() == Vector2i(0, 150), "la barra empieza vacía en el nivel nuevo")
	Economy.add_xp(100000)
	_check(Economy.level() == Economy.max_level(), "no se pasa del nivel máximo")

	_fresh()
	var before := Economy.xp
	Economy.record_build([HouseData.write(0, "objects", "o1", {"item": "bed_basic", "cell": [0, 0], "rot": 0})])
	var first_gain := Economy.xp - before
	_check(first_gain == 30, "primera cama: 10 % de 300 = 30 de experiencia")
	Economy.record_build([HouseData.write(0, "objects", "o2", {"item": "bed_basic", "cell": [0, 0], "rot": 0})])
	_check(Economy.xp == before + first_gain, "la segunda cama no da experiencia")
	Economy.record_build([HouseData.write(0, "objects", "o1", null)])
	_check(Economy.xp == before + first_gain, "borrar no da experiencia")


func _test_jobs() -> void:
	_fresh()
	var courier: Dictionary = Catalog.jobs["courier"]
	var cashier: Dictionary = Catalog.jobs["cashier"]
	_check(Economy.can_apply(courier), "el repartidor es de nivel 1")
	_check(not Economy.can_apply(cashier), "el cajero pide nivel 2")
	_check(not Economy.apply_for_job("cashier"), "no se puede mandar currículum sin el nivel")
	_check(Economy.apply_for_job("courier"), "se manda el currículum")
	_check(Economy.resume_seconds_left() >= 299, "la respuesta tarda unos 5 minutos")
	_check(not Economy.apply_for_job("courier"), "no se manda otro mientras se espera")

	var money := Economy.money
	_check(Economy.accelerate_resume(), "se acelera la respuesta")
	_check(money - Economy.money == 30, "5 minutos de espera = 30 monedas")
	_check(Economy.job_id == "courier" and Economy.applied_job == "", "ya está contratado")
	_check(not Economy.shift_due(), "el primer turno es al día siguiente")

	GameClock.minutes = 1440.0 + 8 * 60.0
	_check(not Economy.shift_due(), "antes de las 9:00 no toca")
	GameClock.minutes = 1440.0 + 9 * 60.0 + 1.0
	_check(Economy.shift_due(), "a las 9:01 del día 2 toca el turno")
	Economy.start_shift()
	_check(not Economy.shift_due(), "ya empezó: no se repite el mismo día")
	var before := Economy.money
	var pay := Economy.complete_shift()
	_check(pay == 120 and Economy.money == before + 120, "un turno de 4 horas a $30 = $120")
	_check(Economy.complete_shift() == 0, "un turno no se cobra dos veces")
	_check(Economy.xp == 20, "el turno da 20 de experiencia")

	# Un turno que quedó a medias se cobra al volver; el trabajo offline tiene tope.
	Economy.start_shift()
	before = Economy.money
	Economy.settle_pending_shift()
	_check(Economy.money == before + 120, "el turno a medias se cobra")
	before = Economy.money
	_check(Economy.simulate_offline(100.0) == 0, "menos de un día fuera: no hay turno extra")
	_check(Economy.simulate_offline(1440.0 * 2.5) == 240, "dos días fuera: dos turnos")
	_check(Economy.simulate_offline(1440.0 * 50.0) == 360, "el pago offline tiene tope de 3 turnos")
	Economy.quit_job()
	_check(Economy.simulate_offline(1440.0 * 3.0) == 0, "sin empleo no hay pago offline")


func _test_save_round_trip() -> void:
	_fresh()
	Economy.money = 777
	Economy.add_xp(130)
	Economy.discovered = {"bed_basic": true}
	Economy.applied_job = "courier"
	Economy.resume_ready_at = 12345
	var text := JSON.stringify(Economy.to_dict())
	_fresh()
	Economy.from_dict(JSON.parse_string(text))
	_check(Economy.money == 777 and Economy.xp == 130, "guardar y cargar: dinero y experiencia")
	_check(Economy.discovered.has("bed_basic"), "guardar y cargar: piezas descubiertas")
	_check(Economy.applied_job == "courier" and Economy.resume_ready_at == 12345, "guardar y cargar: el currículum sigue en espera")


func _test_migration() -> void:
	var old := {
		"format_version": 1,
		"state": {
			"camera": {"x": 1.0},
			"house": {"levels": [{"objects": {"o1": {"item": "chair_basic", "cell": [1, 1], "rot": 0}},
				"walls": {"h:1,1": {"item": "wall_basic", "opening": "door_basic"}}}], "next_id": 2},
		},
	}
	var migrated := SaveMigrations.migrate(old.duplicate(true), SaveSystem.FORMAT_VERSION)
	_check(migrated["format_version"] == SaveSystem.FORMAT_VERSION, "migración: sube a la versión actual")
	var economy: Dictionary = migrated["state"]["economy"]
	_check(economy["money"] == SaveMigrations.STARTING_MONEY, "migración: dinero inicial")
	_check("chair_basic" in economy["discovered"] and "door_basic" in economy["discovered"] and "wall_basic" in economy["discovered"],
		"migración: lo ya construido cuenta como descubierto")
	_check(migrated["state"]["camera"]["x"] == 1.0, "migración: no toca el resto de la partida")
	var again := SaveMigrations.migrate(migrated.duplicate(true), SaveSystem.FORMAT_VERSION)
	_check(again["state"]["economy"]["money"] == SaveMigrations.STARTING_MONEY, "migración: una partida actual no cambia")
	Economy.from_dict(economy)
	_check(Economy.money == SaveMigrations.STARTING_MONEY and Economy.xp == 0, "la economía carga lo migrado")
