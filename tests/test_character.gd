extends Node
## Pruebas automáticas del personaje: necesidades, rasgos, IA y caminos.
##
## Correr desde la terminal, en la carpeta del proyecto:
##   godot --headless --path . res://tests/test_character.tscn

var _passed := 0
var _failed := 0


func _ready() -> void:
	_test_needs()
	_test_traits()
	_test_brain()
	_test_nav_walls_and_doors()
	_test_nav_stairs()
	_test_object_spots()
	print("\nPRUEBAS: %d pasaron, %d fallaron" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _check(condition: bool, description: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		print("FALLÓ: ", description)


func _test_needs() -> void:
	var data := CharacterData.new()
	data.traits = []
	data.decay(60.0)
	_check(is_equal_approx(data.needs["hunger"], 74.0), "comida baja 6 por hora")
	data.decay(100000.0)
	_check(data.needs["hunger"] == CharacterData.NEED_FLOOR, "nunca baja del mínimo")

	var offline := CharacterData.new()
	offline.traits = []
	offline.decay(100000.0, CharacterData.OFFLINE_FLOOR)
	_check(offline.needs["energy"] == CharacterData.OFFLINE_FLOOR, "sin jugar baja solo hasta 30")
	offline.needs["fun"] = 20.0
	offline.decay(600.0, CharacterData.OFFLINE_FLOOR)
	_check(offline.needs["fun"] == 20.0, "si ya estaba debajo de 30, no baja más")

	data.add_need("hunger", 500.0)
	_check(data.needs["hunger"] == 100.0, "no sube de 100")

	data.needs = {"hunger": 90.0, "energy": 90.0, "hygiene": 90.0, "fun": 90.0}
	_check(data.emotion() == "happy", "todo bien: feliz")
	data.needs["energy"] = 15.0
	_check(data.emotion() == "tired", "poca energía: cansado")
	data.needs["hunger"] = 15.0
	_check(data.emotion() == "sad", "dos necesidades bajas: triste")
	data.needs = {"hunger": 15.0, "energy": 90.0, "hygiene": 90.0, "fun": 90.0}
	_check(data.emotion() == "angry", "con hambre: enojado")
	for i in CharacterData.JOURNAL_MAX + 5:
		data.add_journal("cosa %d" % i)
	_check(data.journal.size() == CharacterData.JOURNAL_MAX, "el diario no crece sin límite")
	_check(data.journal[-1]["emotion"] == "angry", "cada entrada guarda la emoción")

	var saved := CharacterData.new()
	saved.from_dict(JSON.parse_string(JSON.stringify(data.to_dict())))
	_check(saved.needs["hunger"] == data.needs["hunger"] and saved.name == data.name, "guardar y cargar el personaje")
	_check(saved.journal.size() == data.journal.size(), "guardar y cargar el diario")


func _test_traits() -> void:
	var data := CharacterData.new()
	data.traits = ["lazy"]
	_check(is_equal_approx(data.decay_multiplier("energy"), 1.25), "perezoso: energía baja 25 % más rápido")
	data.traits = ["chef"]
	_check(is_equal_approx(data.likes(Catalog.actions["cook"]), 1.6), "cocinero: le gusta más cocinar")
	_check(is_equal_approx(data.likes(Catalog.actions["sleep"]), 1.0), "cocinero: dormir le da igual")


func _test_brain() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var data := CharacterData.new()
	data.traits = []
	data.needs = {"hunger": 15.0, "energy": 90.0, "hygiene": 90.0, "fun": 90.0}
	var options := [
		{"action": Catalog.actions["sleep"], "path_length": 3},
		{"action": Catalog.actions["snack"], "path_length": 8},
		{"action": Catalog.actions["watch_tv"], "path_length": 3},
	]
	var choice := CharacterBrain.choose(data, options, rng)
	_check(choice.get("action", {}).get("id", "") == "snack", "con hambre elige comer")

	data.needs = {"hunger": 90.0, "energy": 12.0, "hygiene": 90.0, "fun": 90.0}
	choice = CharacterBrain.choose(data, options, rng)
	_check(choice.get("action", {}).get("id", "") == "sleep", "con sueño elige dormir")

	data.needs = {"hunger": 97.0, "energy": 97.0, "hygiene": 97.0, "fun": 97.0}
	_check(CharacterBrain.choose(data, options, rng).is_empty(), "si está todo bien, pasea")

	_check(CharacterBrain.urgency(10.0) > CharacterBrain.urgency(50.0) * 3.0, "lo urgente pesa mucho más")
	var near := CharacterBrain.score(data, Catalog.actions["snack"], 2)
	var far := CharacterBrain.score(data, Catalog.actions["snack"], 40)
	_check(near > far, "lo cercano conviene más que lo lejano")


## Cuarto cerrado de 3x3 (celdas 1..3) sobre cimientos.
func _closed_room() -> HouseData:
	var house := HouseData.new()
	var writes: Array = []
	for c in HouseGrid.cells_in_rect(Vector2i(1, 1), Vector2i(3, 3)):
		writes.append(HouseData.write(0, "foundation", HouseGrid.cell_key(c), {"item": "foundation_basic"}))
		writes.append(HouseData.write(0, "floors", HouseGrid.cell_key(c), {"item": "floor_basic"}))
	for edge in HouseGrid.edges_around_rect(Vector2i(1, 1), Vector2i(3, 3)):
		writes.append(HouseData.write(0, "walls", edge, {"item": "wall_basic"}))
	house.apply(writes)
	return house


func _test_nav_walls_and_doors() -> void:
	var house := _closed_room()
	var nav := HouseNav.new(house)
	_check(nav.find_path(0, Vector2i(6, 6), 0, Vector2i(2, 2)).is_empty(), "cuarto sin puerta: no se puede entrar")
	_check(not nav.find_path(0, Vector2i(6, 6), 0, Vector2i(0, 8)).is_empty(), "afuera se camina libre")

	# Puerta en la pared de abajo (z = 4), en la celda x = 2.
	house.apply([HouseData.write(0, "walls", "h:2,4", {"item": "wall_basic", "opening": "door_basic"})])
	var path := nav.find_path(0, Vector2i(6, 6), 0, Vector2i(2, 2))
	_check(not path.is_empty(), "con puerta se puede entrar (la red se regeneró)")
	var through_door := false
	for p in path:
		if is_equal_approx(p.x, 2.5) and (is_equal_approx(p.z, 3.5) or is_equal_approx(p.z, 4.5)):
			through_door = true
	_check(through_door, "el camino pasa por la puerta")
	_check(is_equal_approx(path[-1].y, HouseGrid.level_y(0)), "adentro camina sobre los cimientos")

	# Una ventana no deja pasar.
	house.apply([HouseData.write(0, "walls", "h:2,4", {"item": "wall_basic", "opening": "window_basic"})])
	_check(nav.find_path(0, Vector2i(6, 6), 0, Vector2i(2, 2)).is_empty(), "por una ventana no se pasa")


func _test_nav_stairs() -> void:
	var house := HouseData.new()
	var writes: Array = []
	for c in HouseGrid.cells_in_rect(Vector2i(0, 0), Vector2i(4, 5)):
		writes.append(HouseData.write(0, "foundation", HouseGrid.cell_key(c), {"item": "foundation_basic"}))
		writes.append(HouseData.write(0, "floors", HouseGrid.cell_key(c), {"item": "floor_basic"}))
		writes.append(HouseData.write(1, "floors", HouseGrid.cell_key(c), {"item": "floor_basic"}))
	house.apply(writes)
	var nav := HouseNav.new(house)
	_check(nav.find_path(0, Vector2i(2, 5), 1, Vector2i(2, 0)).is_empty(), "sin escalera no se sube")

	# Escalera en x = 2, z = 1..3, sube hacia -Z: entra por (2,4), sale arriba en (2,0).
	house.apply([
		HouseData.write(0, "objects", "o1", {"item": "stairs_basic", "cell": [2, 1], "rot": 0}),
		HouseData.write(1, "floors", "2,1", null),
		HouseData.write(1, "floors", "2,2", null),
		HouseData.write(1, "floors", "2,3", null),
	])
	var path := nav.find_path(0, Vector2i(2, 5), 1, Vector2i(4, 4))
	_check(not path.is_empty(), "con escalera se llega al piso de arriba")
	_check(is_equal_approx(path[-1].y, HouseGrid.level_y(1)), "termina a la altura del primer piso")
	var climbs := true
	for i in range(1, path.size()):
		if path[i].y < path[i - 1].y - 0.01:
			climbs = false
	_check(climbs, "subiendo, nunca baja de altura")


func _test_object_spots() -> void:
	var house := _closed_room()
	# Cama de 1x2 contra la pared de arriba a la izquierda: celdas (1,1) y (1,2).
	house.apply([HouseData.write(0, "objects", "o1", {"item": "bed_basic", "cell": [1, 1], "rot": 0})])
	var nav := HouseNav.new(house)
	var spots := nav.object_spots(0, "o1")
	_check(spots.size() == 3, "cama en la esquina: 3 lugares para usarla (hay %d)" % spots.size())
	_check(not Vector2i(0, 1) in spots, "no se usa a través de una pared")
	_check(not nav.is_walkable(0, Vector2i(1, 2)), "no se camina por encima de la cama")
