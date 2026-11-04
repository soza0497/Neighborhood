extends Node
## Pruebas de la parcela de 96 x 96 (Pulido 2C), sin pantalla ni red.
##
##   godot --headless --path . res://tests/test_parcel.tscn
##
## Los números esperados (546 obstáculos, dónde está cada uno) son LOS MISMOS que
## verifica server/tests/test_rules.lua: si alguna de las dos copias de la regla
## cambia, una de las dos pruebas falla.

var _passed := 0
var _failed := 0


func _ready() -> void:
	HouseGrid.LOT_SIZE = Vector2i(96, 96)
	HouseData.blocked_cells = {}
	_test_generation_matches_server()
	_test_costs_and_paths()
	_test_blocking_rules()
	_test_migration_to_96()
	_test_nav_is_cheap()
	await _test_zone()
	_test_walk_around_tree()
	await _test_local_service()
	print("\nPRUEBAS: %d pasaron, %d fallaron" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _check(condition: bool, description: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		print("FALLÓ: ", description)


func _test_generation_matches_server() -> void:
	var cfg := ParcelRules.config()
	_check(int(cfg["lot"]) == 96 and int(cfg["home_zone"]) == 32, "parcela de 96 con la casa de 32")
	_check(ParcelRules.next_random(12345) == 595905495, "el generador de azar da lo mismo que en el servidor")
	_check(ParcelRules.seed_from_text("abc") == 193485963, "la semilla sale del texto igual que en el servidor")
	var list := ParcelRules.generate(cfg, 424242)
	var kinds := {}
	var checksum := 0
	for i in list.size():
		var o: Dictionary = list[i]
		kinds[o["kind"]] = int(kinds.get(o["kind"], 0)) + 1
		checksum = (checksum + (o["x"] * 131 + o["z"] * 17 + (i + 1))) % 1000003
	_check(list.size() == 546 and kinds["tree"] == 244 and kinds["bush"] == 175 and kinds["stump"] == 65 \
		and kinds["rock"] == 60 and kinds["lake"] == 2, "misma cantidad que el servidor (%d: %s)" % [list.size(), str(kinds)])
	_check(checksum == 961556 and list[0]["id"] == "l:49,31" and list[1]["id"] == "l:2,88" and list[-1]["id"] == "b:71,94",
		"los obstáculos están en los mismos lugares que en el servidor (suma %d)" % checksum)
	var blocked := ParcelRules.blocked_cells(list, {})
	var in_zone := false
	for x in range(31, 65):
		for z in range(57, 96):
			if blocked.has("%d,%d" % [x, z]):
				in_zone = true
	_check(not in_zone, "la casa y toda la franja hasta la calle quedan libres de obstáculos")
	_check(ParcelRules.home_origin(cfg) == Vector2i(32, 58) and HouseGrid.home_origin() == Vector2i(32, 58), "la casa va centrada y a 6 celdas de la calle")
	_check(26 == ParcelRules.home_origin(cfg).y - (96 - 32) / 2, "el corrimiento hacia la calle (26) es el que usa el servidor")
	var cleared := ParcelRules.blocked_cells(list, {"l:2,88": true})
	_check(blocked.size() - cleared.size() == 20, "limpiar el laguito (5 x 4) libera 20 celdas")
	_check(ParcelRules.generate(cfg, 424242) == list and ParcelRules.generate(cfg, 777) != list, "misma semilla = mismos obstáculos")
	# Con una parcela de 32 toda es "la zona de la casa": sin obstáculos (pruebas viejas).
	HouseGrid.LOT_SIZE = Vector2i(32, 32)
	_check(ParcelRules.generate(ParcelRules.config(), 424242).is_empty(), "parcela de 32: sin obstáculos")
	HouseGrid.LOT_SIZE = Vector2i(96, 96)


func _test_costs_and_paths() -> void:
	var cfg := ParcelRules.config()
	_check(ParcelRules.cost(cfg, "rock", 0) == 250 and ParcelRules.cost(cfg, "rock", 50) == 500 and ParcelRules.cost(cfg, "rock", 500) == 750,
		"el costo sube con lo limpiado y tiene techo (x3)")
	_check(ParcelRules.cost(cfg, "bush", 0) == 15 and ParcelRules.cost(cfg, "lake", 10) == 1080, "costos base de la maleza y el laguito")
	var small := {"lot": 10}
	var wall := {}
	for x in 10:
		if x != 4:
			wall["%d,5" % x] = "t"
	var target := {"x": 4, "z": 1, "w": 1, "d": 1}
	var person := ParcelRules.find_path(small, wall, {}, target, false)
	_check(person["ok"] and person["path"][0].y == 9 and person["path"].size() > 5, "una persona pasa por un hueco de 1 celda (camino de %d)" % person["path"].size())
	var vehicle := ParcelRules.find_path(small, wall, {}, target, true)
	_check(not vehicle["ok"] and str(vehicle["reason"]).contains("vehículo"), "un vehículo NO pasa por un hueco de 1 celda: \"%s\"" % vehicle["reason"])
	wall.erase("3,5")
	wall.erase("5,5")
	_check(ParcelRules.find_path(small, wall, {}, target, true)["ok"], "con un hueco de 3 celdas, el vehículo pasa")
	var house_wall := {}
	for x in 10:
		house_wall["%d,5" % x] = true
	_check(not ParcelRules.find_path(small, {}, house_wall, target, false)["ok"], "la casa no se cruza")


func _test_blocking_rules() -> void:
	var house := HouseData.new()
	HouseData.blocked_cells = {"40,40": "t:40,40", "41,40": "r:41,40"}
	_check(not HouseRules.is_supported(house, 0, "foundation", "40,40", {"item": "foundation_basic"}), "no se pueden poner cimientos sobre un obstáculo")
	_check(HouseRules.is_supported(house, 0, "foundation", "42,40", {"item": "foundation_basic"}), "al lado sí")
	_check(not HouseRules.is_supported(house, 0, "roofs", "o1", {"item": "roof_basic", "rect": [39, 39, 3, 3]}), "ni un techo que lo cubra")
	_check(not HouseRules.is_supported(house, 0, "objects", "o2", {"item": "pillar_basic", "cell": [40, 40], "rot": 0}), "ni un pilar al aire libre encima")
	_check(HouseRules.is_blocked(Vector2i(41, 40)) and not HouseRules.is_blocked(Vector2i(0, 0)), "is_blocked mira la celda")
	var nav := HouseNav.new(house)
	_check(not nav.is_walkable(0, Vector2i(40, 40)) and nav.is_walkable(0, Vector2i(42, 40)), "el personaje no pisa un obstáculo")
	HouseData.blocked_cells = {}
	var copy := house.duplicate_data()
	_check(copy.floors_total() == 1, "una casa copiada sigue igual")


func _test_migration_to_96() -> void:
	# Una casa guardada con parcela de 32: pasa a la de 96, centrada y cerca de la calle (32 y 58 celdas).
	# Una de formato 4 (Pulido 2: ya centrada en la de 96) solo se acerca a la calle (26 celdas).
	var saved := {"levels": [{"foundation": {"0,0": {"item": "foundation_basic"}}, "floors": {"0,0": {"item": "floor_basic"}},
		"walls": {"h:1,2": {"item": "wall_basic"}}, "objects": {"o1": {"item": "chair_basic", "cell": [3, 4], "rot": 0}},
		"roofs": {"o2": {"item": "roof_basic", "rect": [1, 1, 2, 2]}}}], "next_id": 3, "lot_size": [32, 32], "format": 3}
	var house := HouseData.new()
	house.from_dict(saved)
	_check(house.migrated_offset == Vector2i(32, 58), "el personaje se mueve igual que la casa: %s" % str(house.migrated_offset))
	_check(house.has_piece(0, "foundation", "32,58") and house.has_piece(0, "walls", "h:33,60") and house.has_piece(0, "floors", "32,58"),
		"cimientos, pisos y paredes de la casa vieja quedan cerca de la calle")
	_check(HouseData.object_anchor(house.get_piece(0, "objects", "o1")) == Vector2i(35, 62) and HouseData.roof_rect(house.get_piece(0, "roofs", "o2")).position == Vector2i(33, 59),
		"muebles y techos también")
	_check(house.to_dict()["format"] == 5 and house.to_dict()["lot_size"] == [96, 96], "se guarda con formato 5 y parcela de 96")
	var again := HouseData.new()
	again.from_dict(house.to_dict())
	_check(again.migrated_offset == Vector2i.ZERO and again.has_piece(0, "foundation", "32,58"), "una casa ya migrada no se mueve otra vez")
	var f4 := HouseData.new()
	f4.from_dict({"levels": [{"foundation": {"32,32": {"item": "foundation_basic"}}}], "next_id": 1, "lot_size": [96, 96], "format": 4})
	_check(f4.migrated_offset == Vector2i(0, 26) and f4.has_piece(0, "foundation", "32,58"), "una casa del Pulido 2 (formato 4) se acerca 26 celdas a la calle")
	var migrated := SaveMigrations.migrate({"format_version": 3, "state": {"house": saved.duplicate(true), "economy": {}}}, 4)
	_check(migrated["state"].has("parcel") and migrated["state"].has("delivery") and int(migrated["format_version"]) == 4, "guardado v3 → v4")


## Pulido 3A: al principio solo se usa el doble de la parcela original (64 x 64
## pegado a la calle); con los niveles se abre hasta el triple (toda).
func _test_zone() -> void:
	var cfg := ParcelRules.config()
	_check(ParcelRules.locked_cells(cfg, 1).size() == 96 * 96 - 64 * 64, "al principio solo se usa 64 x 64")
	_check(ParcelRules.locked_cells(cfg, 4).size() == 96 * 96 - 64 * 96 and ParcelRules.locked_cells(cfg, 6).is_empty(), "con los niveles se abre el resto (el triple)")
	Economy.server_mode = false
	Economy.xp = 0
	Parcel.setup_local({"seed": 424242})
	_check(Parcel.zone_bounds() == Rect2i(16, 32, 64, 64), "la zona usable empieza en 16,32 y mide 64 x 64: %s" % str(Parcel.zone_bounds()))
	_check(Parcel.is_locked(Vector2i(5, 5)) and not Parcel.is_locked(Vector2i(40, 90)) and Parcel.obstacle_at(Vector2i(5, 5)) == "", "una celda de la zona cerrada se ve como cerrada")
	var house := HouseData.new()
	_check(not HouseRules.is_supported(house, 0, "foundation", "5,5", {"item": "foundation_basic"}), "no se construye en la zona cerrada")
	_check(HouseRules.is_supported(house, 0, "foundation", "40,90", {"item": "foundation_basic"}), "en la zona abierta sí")
	var nav := HouseNav.new(house)
	_check(not nav.is_walkable(0, Vector2i(5, 5)), "el personaje no pisa la zona cerrada")
	# Un obstáculo de la zona cerrada no se puede mandar a limpiar.
	var far := ""
	for o in Parcel.obstacles:
		if o["kind"] == "bush" and not ParcelRules.in_zone(Parcel.zone_rects(), o["x"], o["z"]):
			far = o["id"]
			break
	Economy.money = 10000
	var refused: Dictionary = await Parcel.call_service(far, house)
	_check(far != "" and not refused["ok"] and str(refused["error"]).contains("todavía no es tuyo"), "en la zona cerrada no se llama a servicios: \"%s\"" % refused["error"])
	# Subir de nivel abre terreno.
	Economy.xp = 500
	Parcel._rebuild()
	_check(Economy.level() == 4 and Parcel.zone_bounds() == Rect2i(16, 0, 64, 96) and not Parcel.is_locked(Vector2i(40, 5)), "al nivel 4 se abre el terreno de atrás")
	Economy.xp = 0
	Parcel.setup_local({})


## Pulido 3A: el camino rodea los árboles y se regenera al limpiarlos.
func _test_walk_around_tree() -> void:
	Economy.server_mode = false
	Economy.xp = 0
	Parcel.setup_local({"seed": 1})
	HouseData.blocked_cells = {"61,85": "t:61,85"}
	var house := HouseData.new()
	var nav := HouseNav.new(house)
	var path := nav.find_path(0, Vector2i(60, 85), 0, Vector2i(62, 85))
	var through := false
	for point in path:
		if Vector2i(int(point.x), int(point.z)) == Vector2i(61, 85):
			through = true
	_check(not path.is_empty() and not through and path.size() >= 3, "el personaje llega al otro lado de un árbol rodeándolo (%d puntos)" % path.size())
	# Con un tronco de 3 celdas de ancho, el camino hace una vuelta más larga.
	HouseData.blocked_cells = {"61,84": "t", "61,85": "t", "61,86": "t"}
	nav.mark_dirty()
	var longer := nav.find_path(0, Vector2i(60, 85), 0, Vector2i(62, 85))
	_check(not longer.is_empty() and longer.size() > path.size() - 1, "con un hilera de obstáculos da la vuelta (%d puntos)" % longer.size())
	# Limpiar un obstáculo regenera la red: ahora pasa derecho.
	Parcel.obstacles = [{"id": "t:61,85", "kind": "tree", "x": 61, "z": 85, "w": 1, "d": 1}]
	Parcel.cleared = {}
	HouseData.blocked_cells = Parcel.blocked_now()
	nav.mark_dirty()
	var around := nav.find_path(0, Vector2i(60, 85), 0, Vector2i(62, 85))
	Parcel.cleared = {"t:61,85": true}
	Parcel._rebuild()  # Avisa "changed": la red de caminos se marca sucia sola.
	var straight := nav.find_path(0, Vector2i(60, 85), 0, Vector2i(62, 85))
	_check(straight.size() == 3 and around.size() > straight.size(), "al limpiar el árbol, el camino se regenera y pasa derecho (%d → %d puntos)" % [around.size(), straight.size()])
	Parcel.setup_local({})


func _test_nav_is_cheap() -> void:
	var house := HouseData.new()
	var writes: Array = []
	for c in HouseGrid.cells_in_rect(Vector2i(40, 40), Vector2i(50, 48)):
		writes.append(HouseData.write(0, "foundation", HouseGrid.cell_key(c), {"item": "foundation_basic"}))
		writes.append(HouseData.write(0, "floors", HouseGrid.cell_key(c), {"item": "floor_basic"}))
	house.apply(writes)
	var nav := HouseNav.new(house)
	var start := Time.get_ticks_msec()
	nav.rebuild()
	var elapsed := Time.get_ticks_msec() - start
	var area := nav.nav_area()
	_check(area.size.x * area.size.y < 4500 and area.end.y == 96, "la red de caminos cubre %d celdas (no las 9216) y llega a la calle" % (area.size.x * area.size.y))
	_check(elapsed < 1500, "armar los caminos de la parcela de 96 toma %d ms" % elapsed)
	var path := nav.find_path(0, Vector2i(45, 49), 0, Character.work_cell())
	_check(not path.is_empty(), "de la casa a la acera hay camino (%d puntos)" % path.size())
	print("  (armar la red: %d ms, %d celdas)" % [elapsed, area.size.x * area.size.y])


func _test_local_service() -> void:
	# Partida sin servidor: las mismas reglas con el dinero del teléfono.
	Economy.server_mode = false
	Economy.money = 10000
	Parcel.setup_local({"seed": 424242})
	var house := HouseData.new()
	var bush := ""
	for o in Parcel.obstacles:
		if o["kind"] == "bush" and ParcelRules.in_zone(Parcel.zone_rects(), o["x"], o["z"]):
			bush = o["id"]
			break
	_check(Parcel.obstacles.size() == 546 and bush != "" and Parcel.obstacle_at(Vector2i(Parcel.obstacle(bush)["x"], Parcel.obstacle(bush)["z"])) == bush,
		"la parcela local tiene los obstáculos y sabe cuál ocupa una celda")
	var before := Economy.money
	var result: Dictionary = await Parcel.call_service(bush, house)
	_check(result["ok"] and Economy.money == before - 15 and Parcel.pending.has(bush), "llamar al servicio cobra $15 y queda en camino")
	_check(not (await Parcel.call_service(bush, house))["ok"], "no se puede llamar dos veces")
	var early: Dictionary = await Parcel.finish(bush, house)
	_check(early["ok"] and not Parcel.pending.has(bush) and Parcel.cleared.has(bush) and Parcel.count == 1, "al terminar, el obstáculo queda limpio")
	var o: Dictionary = Parcel.obstacle(bush)
	_check(Parcel.obstacle_at(Vector2i(o["x"], o["z"])) == "" and not HouseData.blocked_cells.has("%d,%d" % [o["x"], o["z"]]), "y deja de bloquear construir")
	var rock := ""
	for ob in Parcel.obstacles:
		if ob["kind"] == "rock" and ParcelRules.in_zone(Parcel.zone_rects(), ob["x"], ob["z"], 2, 2):
			rock = ob["id"]
			break
	_check(Parcel.cost_of(rock) == 255, "la próxima limpieza ya cuesta más: $%d (250 × 1,02)" % Parcel.cost_of(rock))
	Economy.money = 10
	var poor: Dictionary = await Parcel.call_service(rock, house)
	_check(not poor["ok"] and str(poor["error"]).begins_with("Te faltan"), "sin plata: \"%s\"" % poor["error"])
	_check(Parcel.to_dict()["cleared"] == [bush] and int(Parcel.to_dict()["seed"]) == 424242, "se guarda para la próxima vez")
	# Un vehículo no entra si la casa le tapa todo el frente.
	Economy.money = 10000
	var wall := HouseData.new()
	var wall_writes: Array = []
	for x in 96:
		wall_writes.append(HouseData.write(0, "foundation", HouseGrid.cell_key(Vector2i(x, 94)), {"item": "foundation_basic"}))
	wall.apply(wall_writes)
	var blocked: Dictionary = await Parcel.call_service(rock, wall)
	_check(not blocked["ok"], "con el frente tapado, el servicio avisa que no puede entrar: \"%s\"" % blocked["error"])
	Parcel.setup_local({})
