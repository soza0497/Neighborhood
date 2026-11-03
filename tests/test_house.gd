extends Node
## Pruebas automáticas de los datos y las reglas de la casa (sin pantalla).
##
## Correr desde la terminal, en la carpeta del proyecto:
##   godot --headless --path . res://tests/test_house.tscn
## Al final dice cuántas pruebas pasaron. Si alguna falla, dice cuál.

var _passed := 0
var _failed := 0


func _ready() -> void:
	_test_grid()
	_test_apply_and_undo()
	_test_support_rules()
	_test_removal_rules()
	_test_objects()
	_test_save_round_trip()
	_test_window_merge()
	print("\nPRUEBAS: %d pasaron, %d fallaron" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _check(condition: bool, description: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		print("FALLÓ: ", description)


func _foundation(house: HouseData, a: Vector2i, b: Vector2i) -> void:
	var writes: Array = []
	for c in HouseGrid.cells_in_rect(a, b):
		writes.append(HouseData.write(0, "foundation", HouseGrid.cell_key(c), {"item": "foundation_basic"}))
	house.apply(writes)


func _floor(house: HouseData, level: int, a: Vector2i, b: Vector2i) -> void:
	var writes: Array = []
	for c in HouseGrid.cells_in_rect(a, b):
		writes.append(HouseData.write(level, "floors", HouseGrid.cell_key(c), {"item": "floor_basic"}))
	house.apply(writes)


func _test_grid() -> void:
	_check(HouseGrid.edges_in_line(Vector2i(0, 0), Vector2i(3, 1)).size() == 3, "línea horizontal de 3 tramos")
	_check(HouseGrid.edges_in_line(Vector2i(2, 0), Vector2i(2, 4))[0] == "v:2,0", "línea vertical empieza en v:2,0")
	_check(HouseGrid.edges_around_rect(Vector2i(0, 0), Vector2i(1, 2)).size() == 10, "contorno de 2x3 = 10 tramos")
	_check(HouseGrid.edge_cells("h:3,4") == [Vector2i(3, 3), Vector2i(3, 4)], "celdas a los lados de h:3,4")
	_check(HouseGrid.object_cells(Vector2i(1, 3), Vector2i(2, 2), 1).size() == 3, "objeto 1x3 girado ocupa 3 celdas")
	_check(HouseGrid.rotated_size(Vector2i(1, 3), 1) == Vector2i(3, 1), "objeto 1x3 girado mide 3x1")
	_check(HouseGrid.object_inner_edges(Vector2i(2, 1), Vector2i(0, 0), 0) == ["v:1,0"], "mesa 2x1 tiene un borde interno")


func _test_apply_and_undo() -> void:
	var house := HouseData.new()
	var history := UndoHistory.new(house)
	history.commit([HouseData.write(0, "foundation", "1,1", {"item": "foundation_basic"})])
	_check(house.has_piece(0, "foundation", "1,1"), "se pone un cimiento")
	history.undo()
	_check(not house.has_piece(0, "foundation", "1,1"), "deshacer lo quita")
	history.redo()
	_check(house.has_piece(0, "foundation", "1,1"), "rehacer lo vuelve a poner")
	history.commit([HouseData.write(0, "foundation", "1,1", null)])
	history.undo()
	_check(house.has_piece(0, "foundation", "1,1"), "deshacer un borrado lo restaura")
	history.undo()
	_check(history.can_redo(), "se puede rehacer después de deshacer")


func _test_support_rules() -> void:
	var house := HouseData.new()
	var floor_value := {"item": "floor_basic"}
	var wall_value := {"item": "wall_basic"}
	_check(not HouseRules.is_supported(house, 0, "floors", "2,2", floor_value), "piso sin cimientos: NO")
	_check(not HouseRules.is_supported(house, 0, "walls", "h:2,2", wall_value), "pared sin cimientos: NO")
	_foundation(house, Vector2i(2, 2), Vector2i(4, 4))
	_check(HouseRules.is_supported(house, 0, "floors", "2,2", floor_value), "piso sobre cimientos: SÍ")
	_check(HouseRules.is_supported(house, 0, "walls", "h:2,2", wall_value), "pared en el borde de cimientos: SÍ")
	_check(not HouseRules.is_supported(house, 0, "walls", "h:2,1", wall_value), "pared lejos de cimientos: NO")
	_check(not HouseRules.is_supported(house, 1, "floors", "2,2", floor_value), "piso arriba sin piso ni pared abajo: NO")
	house.apply([HouseData.write(0, "walls", "v:5,2", wall_value)])
	_check(HouseRules.is_supported(house, 1, "floors", "5,2", floor_value), "piso arriba junto a una pared de abajo (balcón): SÍ")
	_check(HouseRules.check_removal(house, [HouseData.write(0, "walls", "v:5,2", null)])["blocked"].is_empty(),
		"pared sin nada arriba: se borra")
	house.apply([HouseData.write(1, "floors", "5,2", floor_value)])
	_check(not HouseRules.check_removal(house, [HouseData.write(0, "walls", "v:5,2", null)])["blocked"].is_empty(),
		"pared que sostiene un balcón: no se borra")
	house.apply([HouseData.write(1, "floors", "5,2", null), HouseData.write(0, "walls", "v:5,2", null)])
	_floor(house, 0, Vector2i(2, 2), Vector2i(4, 4))
	_check(HouseRules.is_supported(house, 1, "floors", "2,2", floor_value), "piso arriba sobre piso: SÍ")
	_check(not HouseRules.is_supported(house, 1, "walls", "h:2,2", wall_value), "pared arriba sin piso ni pared abajo: NO")
	house.apply([HouseData.write(0, "walls", "h:2,2", wall_value)])
	_check(HouseRules.is_supported(house, 1, "walls", "h:2,2", wall_value), "pared arriba sobre pared: SÍ")
	_check(not HouseRules.is_supported(house, 0, "foundation", "40,1", {"item": "foundation_basic"}), "cimiento fuera del lote: NO")

	# Un "cuarto" arriba: el piso se pone primero y las paredes se apoyan en él.
	var room: Array = []
	room.append(HouseData.write(1, "floors", "3,3", floor_value))
	room.append(HouseData.write(1, "walls", "h:3,3", wall_value))
	_check(HouseRules.check_placement(house, room)["blocked"].is_empty(), "cuarto arriba: piso y paredes en orden")


func _test_removal_rules() -> void:
	var house := HouseData.new()
	_foundation(house, Vector2i(0, 0), Vector2i(2, 0))
	_floor(house, 0, Vector2i(0, 0), Vector2i(0, 0))
	house.apply([HouseData.write(0, "walls", "v:3,0", {"item": "wall_basic"})])

	var remove_one := [HouseData.write(0, "foundation", "0,0", null)]
	_check(HouseRules.check_removal(house, remove_one)["ok"].is_empty(), "cimiento con piso encima: no se borra")

	var remove_free := [HouseData.write(0, "foundation", "1,0", null)]
	_check(HouseRules.check_removal(house, remove_free)["ok"].size() == 1, "cimiento libre: se borra")

	var remove_wall_support := [HouseData.write(0, "foundation", "2,0", null)]
	_check(HouseRules.check_removal(house, remove_wall_support)["ok"].is_empty(), "cimiento que sostiene una pared: no se borra")

	var remove_both := [
		HouseData.write(0, "foundation", "2,0", null),
		HouseData.write(0, "walls", "v:3,0", null),
	]
	_check(HouseRules.check_removal(house, remove_both)["ok"].size() == 2, "cimiento + su pared juntos: se borran")


func _test_objects() -> void:
	var house := HouseData.new()
	_foundation(house, Vector2i(0, 0), Vector2i(3, 3))
	_floor(house, 0, Vector2i(0, 0), Vector2i(3, 3))
	var bed := {"item": "bed_basic", "cell": [0, 0], "rot": 0}
	_check(HouseRules.is_supported(house, 0, "objects", "o1", bed), "cama sobre piso: SÍ")
	house.apply([HouseData.write(0, "objects", "o1", bed)])
	_check(house.object_at(0, Vector2i(0, 1)) == "o1", "la cama ocupa la celda (0,1)")
	var table := {"item": "table_basic", "cell": [0, 1], "rot": 0}
	_check(not HouseRules.is_supported(house, 0, "objects", "o2", table), "mesa encima de la cama: NO")
	_check(HouseRules.is_supported(house, 0, "objects", "o1", {"item": "bed_basic", "cell": [0, 1], "rot": 0}),
		"mover la cama una celda (se ignora a sí misma): SÍ")
	house.apply([HouseData.write(0, "walls", "v:2,2", {"item": "wall_basic"})])
	_check(not HouseRules.is_supported(house, 0, "objects", "o3", {"item": "table_basic", "cell": [1, 2], "rot": 0}),
		"mesa atravesada por una pared: NO")
	_check(not HouseRules.is_supported(house, 0, "objects", "o4", {"item": "table_basic", "cell": [3, 3], "rot": 0}),
		"mesa saliéndose del piso: NO")
	_check(not HouseRules.check_removal(house, [HouseData.write(0, "floors", "0,0", null)])["blocked"].is_empty(),
		"piso con cama encima: no se borra")

	# Escaleras: no en el último nivel, y el piso de arriba no va encima.
	var stairs := {"item": "stairs_basic", "cell": [3, 0], "rot": 0}
	_check(HouseRules.is_supported(house, 0, "objects", "o5", stairs), "escalera en planta baja: SÍ")
	_check(not HouseRules.is_supported(house, 1, "objects", "o5", stairs), "escalera en el último piso: NO")
	house.apply([HouseData.write(0, "objects", "o5", stairs)])
	_check(not HouseRules.is_supported(house, 1, "floors", "3,1", {"item": "floor_basic"}), "piso encima de la escalera: NO")
	_check(HouseRules.is_supported(house, 1, "floors", "2,1", {"item": "floor_basic"}), "piso al lado de la escalera: SÍ")


func _test_save_round_trip() -> void:
	var house := HouseData.new()
	_foundation(house, Vector2i(0, 0), Vector2i(1, 1))
	house.apply([HouseData.write(0, "objects", house.new_id(), {"item": "chair_basic", "cell": [1, 1], "rot": 2})])
	# Pasar por texto JSON, como hace el guardado de verdad.
	var text := JSON.stringify(house.to_dict())
	var loaded := HouseData.new()
	loaded.from_dict(JSON.parse_string(text))
	_check(loaded.get_layer(0, "foundation").size() == 4, "guardar y cargar: 4 cimientos")
	_check(loaded.object_at(0, Vector2i(1, 1)) == "o1", "guardar y cargar: la silla sigue ahí")
	_check(loaded.next_id == 2, "guardar y cargar: el contador de ids sigue")
	_check(loaded.migrated_offset == Vector2i.ZERO, "guardar y cargar: no se mueve nada")

	# Una casa guardada con el lote viejo de 12x12 se centra en la parcela.
	var old := house.to_dict()
	old.erase("lot_size")
	old["levels"][0]["walls"] = {"h:1,2": {"item": "wall_basic"}}
	old["levels"][0]["roofs"] = {"o9": {"item": "roof_basic", "rect": [0, 0, 2, 2]}}
	var migrated := HouseData.new()
	migrated.from_dict(JSON.parse_string(JSON.stringify(old)))
	var offset := (HouseGrid.LOT_SIZE - Vector2i(12, 12)) / 2
	_check(migrated.migrated_offset == offset, "migración: se calcula cuánto mover")
	_check(migrated.has_piece(0, "foundation", HouseGrid.cell_key(offset)), "migración: los cimientos se movieron")
	_check(migrated.object_at(0, Vector2i(1, 1) + offset) == "o1", "migración: la silla se movió")
	_check(migrated.has_piece(0, "walls", HouseGrid.edge_key(Vector2i(1, 2) + offset, true)), "migración: la pared se movió")
	_check(HouseData.roof_rect(migrated.get_piece(0, "roofs", "o9")).position == offset, "migración: el techo se movió")


func _test_window_merge() -> void:
	var house := HouseData.new()
	var view := HouseView.new()
	add_child(view)
	view.setup(house)
	var window := {"item": "wall_basic", "opening": "window_basic"}
	house.apply([HouseData.write(0, "walls", "h:1,1", window), HouseData.write(0, "walls", "h:2,1", window)])
	_check(not view._merged_window(0, Vector2i(2, 1)).is_empty(), "dos ventanas iguales seguidas se unen")
	var separate := window.duplicate()
	separate["separate"] = true
	house.apply([HouseData.write(0, "walls", "h:2,1", separate)])
	_check(view._merged_window(0, Vector2i(2, 1)).is_empty(), "marcada como separada: no se une")
	house.apply([HouseData.write(0, "walls", "h:2,1", {"item": "wall_basic", "opening": "window_tall"})])
	_check(view._merged_window(0, Vector2i(2, 1)).is_empty(), "ventanas distintas no se unen")
	view.queue_free()
