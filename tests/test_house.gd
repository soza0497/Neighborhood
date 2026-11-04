extends Node
## Pruebas automáticas de los datos y las reglas de la casa (sin pantalla).
##
## Correr desde la terminal, en la carpeta del proyecto:
##   godot --headless --path . res://tests/test_house.tscn
## Al final dice cuántas pruebas pasaron. Si alguna falla, dice cuál.

var _passed := 0
var _failed := 0


func _ready() -> void:
	HouseGrid.use_test_lot()  # Estas pruebas arman casas en un lote de 32 (la parcela real, desde el Pulido 2C, es de 96).
	_test_grid()
	_test_apply_and_undo()
	_test_support_rules()
	_test_removal_rules()
	_test_objects()
	_test_save_round_trip()
	_test_window_merge()
	_test_pulido_rules()
	_test_pulido_faces_and_rooms()
	_test_pulido_migration()
	_test_pulido2_roofs_and_floors()
	_test_pulido2_erase_everything()
	_test_pulido2_basements()
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
	old["levels"][3]["walls"] = {"h:1,2": {"item": "wall_basic"}}
	old["levels"][3]["roofs"] = {"o9": {"item": "roof_basic", "rect": [0, 0, 2, 2]}}
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
	# Pulido 1: la unión es de la JUNTURA (join_end en la pared que termina ahí).
	var window := {"item": "wall_basic", "opening": "window_basic"}
	house.apply([HouseData.write(0, "walls", "h:1,1", window), HouseData.write(0, "walls", "h:2,1", window)])
	_check(view._merged_window(0, Vector2i(2, 1)).is_empty(), "sin marca en la juntura: se ven separadas")
	var joined := window.duplicate()
	joined["join_end"] = true
	house.apply([HouseData.write(0, "walls", "h:1,1", joined)])
	_check(not view._merged_window(0, Vector2i(2, 1)).is_empty(), "con la juntura marcada: unidas")
	_check(HouseView.joint_walls(house, 0, Vector2i(2, 1)) == ["h:1,1", "h:2,1"], "la juntura es de la pared que termina ahí")
	house.apply([HouseData.write(0, "walls", "h:2,1", {"item": "wall_basic", "opening": "window_tall"})])
	_check(view._merged_window(0, Vector2i(2, 1)).is_empty(), "ventanas distintas no se unen")
	view.queue_free()


# --- Pulido 1: constructor 2.0 ---

## Casa de prueba: cimientos y piso de (0,0) a (5,5) con paredes alrededor.
func _box_house() -> HouseData:
	var house := HouseData.new()
	_foundation(house, Vector2i(0, 0), Vector2i(5, 5))
	_floor(house, 0, Vector2i(0, 0), Vector2i(5, 5))
	var writes: Array = []
	for edge in HouseGrid.edges_around_rect(Vector2i(0, 0), Vector2i(5, 5)):
		writes.append(HouseData.write(0, "walls", edge, {"item": "wall_basic"}))
	house.apply(writes)
	return house


func _test_pulido_rules() -> void:
	# Muebles en diagonal: una silla ocupa 1 celda; una mesa 2x1 más.
	var chair := HouseGrid.object_cells_full(Vector2i(1, 1), Vector2i(3, 3), 0, true)
	_check(chair == [Vector2i(3, 3)], "silla en diagonal: 1 celda")
	var table := HouseGrid.object_cells_full(Vector2i(2, 1), Vector2i(2, 2), 0, true)
	_check(table.size() == 4 and Vector2i(2, 2) in table and Vector2i(3, 3) in table, "mesa 2x1 en diagonal: 4 celdas (%s)" % [table])
	_check(HouseGrid.object_angle(1, true) == 135, "giro de a 45°: 90 + 45 = 135")
	_check(HouseBuilder.next_orientation("chair_basic", 0, false) == [0, true]
		and HouseBuilder.next_orientation("chair_basic", 0, true) == [1, false], "la silla gira de a 45° (8 direcciones)")
	_check(HouseBuilder.next_orientation("stairs_basic", 0, false) == [1, false], "la escalera gira de a 90°")

	var house := _box_house()
	house.apply([HouseData.write(0, "objects", "o1", {"item": "table_basic", "cell": [2, 2], "rot": 0, "diag": true})])
	_check(house.object_at(0, Vector2i(3, 3)) == "o1", "la mesa en diagonal ocupa sus celdas")
	_check(not HouseRules.is_supported(house, 0, "objects", "o2", {"item": "chair_basic", "cell": [3, 3], "rot": 0}),
		"no se puede encimar una silla sobre la mesa en diagonal")
	_check(not HouseRules.is_supported(house, 0, "objects", "o3", {"item": "stairs_basic", "cell": [0, 0], "rot": 0, "diag": true}),
		"la escalera no va en diagonal")

	# Pilares: sostienen el piso de arriba a 2 celdas; lo de afuera va sobre el pasto.
	var open := HouseData.new()
	_check(HouseRules.is_supported(open, 0, "objects", "p1", {"item": "pillar_basic", "cell": [10, 10], "rot": 0}),
		"un pilar va sobre el pasto")
	_check(not HouseRules.is_supported(open, 0, "objects", "c1", {"item": "chair_basic", "cell": [10, 10], "rot": 0}),
		"una silla no va sobre el pasto")
	open.apply([HouseData.write(0, "objects", "p1", {"item": "pillar_basic", "cell": [10, 10], "rot": 0})])
	_check(HouseRules.is_supported(open, 1, "floors", "12,12", {"item": "floor_basic"}), "el pilar sostiene un piso a 2 celdas")
	_check(not HouseRules.is_supported(open, 1, "floors", "13,10", {"item": "floor_basic"}), "a 3 celdas ya no")
	open.apply([HouseData.write(1, "floors", "11,11", {"item": "floor_basic"})])
	var removal := HouseRules.check_removal(open, [HouseData.write(0, "objects", "p1", null)])
	_check(not removal["blocked"].is_empty(), "no se puede quitar el pilar que sostiene el piso")
	_check(HouseRules.removal_reason(open, HouseData.write(0, "objects", "p1", null)).begins_with("Este pilar sostiene"),
		"aviso: \"%s\"" % HouseRules.removal_reason(open, HouseData.write(0, "objects", "p1", null)))
	_check(HouseRules.is_supported(open, 0, "objects", "m1", {"item": "stairs_metal", "cell": [14, 14], "rot": 0}),
		"la escalera metálica va afuera, sobre el pasto")

	# Una pared que sostiene el piso de arriba no se puede quitar.
	var two := _box_house()
	two.apply([HouseData.write(1, "floors", "2,0", {"item": "floor_basic"})])
	two.apply([HouseData.write(0, "floors", "2,0", null)])  # Abajo, solo la pared lo sostiene.
	_check(HouseRules.removal_reason(two, HouseData.write(0, "walls", "h:2,0", null)) == "Esta pared sostiene el piso de arriba.",
		"\"Esta pared sostiene el piso de arriba\"")

	# Techos: bloqueados si los atraviesa una pared o un piso de arriba.
	var roofed := _box_house()
	var roof := {"item": "roof_flat", "rect": [0, 0, 6, 6]}
	_check(HouseRules.is_supported(roofed, 0, "roofs", "r1", roof), "techo plano sobre la casa")
	roofed.apply([HouseData.write(1, "walls", "v:3,2", {"item": "wall_basic"})])
	_check(not HouseRules.is_supported(roofed, 0, "roofs", "r1", roof), "no se puede poner techo si una pared lo atraviesa")
	_check(HouseRules.roof_blocker(roofed, 0, Rect2i(0, 0, 6, 6)).contains("pared"), "y se explica por qué")
	var under := _box_house()
	under.apply([HouseData.write(0, "roofs", "r1", roof)])
	_check(not HouseRules.is_supported(under, 1, "walls", "v:3,2", {"item": "wall_basic"}), "ni una pared arriba atravesando el techo")
	_check(not HouseRules.is_supported(under, 1, "floors", "2,2", {"item": "floor_basic"}), "ni un piso adentro del techo")

	# Sin escalera no se sube: el piso de arriba queda "sin acceso".
	var upstairs := _box_house()
	upstairs.apply([HouseData.write(1, "floors", "1,1", {"item": "floor_basic"})])
	_check(not HouseRules.has_access(upstairs, 1), "sin escalera: piso 1 sin acceso")
	var problems := HouseRules.problems(upstairs)
	_check(problems.size() == 1 and problems[0]["text"].contains("sin acceso"), "lo que falta: \"%s\"" % (problems[0]["text"] if problems.size() > 0 else ""))
	upstairs.apply([HouseData.write(0, "objects", "s1", {"item": "stairs_spiral", "cell": [3, 3], "rot": 0})])
	_check(HouseRules.has_access(upstairs, 1) and HouseRules.problems(upstairs).is_empty(), "con la escalera de caracol: con acceso")
	_check(upstairs.object_cells(0, "s1").size() == 4, "la escalera de caracol ocupa 2x2")

	# Copiar contorno de abajo: losa completa + paredes de afuera.
	var outline := HouseBuilder.outline_writes(_box_house(), 1)
	var floors := outline.filter(func(w): return w["layer"] == "floors").size()
	var walls := outline.filter(func(w): return w["layer"] == "walls").size()
	_check(floors == 36 and walls == 24, "copiar contorno: 36 pisos y 24 paredes (%d, %d)" % [floors, walls])
	var check := HouseRules.check_placement(_box_house(), outline)
	_check(check["blocked"].is_empty(), "el contorno copiado se puede construir")


func _test_pulido_faces_and_rooms() -> void:
	var house := _box_house()
	_check(WallFaces.side_for_cell("h:2,0", Vector2i(2, 0)) == "b" and WallFaces.side_for_cell("h:2,0", Vector2i(2, -1)) == "a",
		"lado a = norte, lado b = sur")
	var next := WallFaces.next_face(house, 0, "h:2,0", "b", 1)
	_check(next == {"edge": "h:3,0", "side": "b"}, "la pared de al lado (sigue derecha)")
	var corner := WallFaces.next_face(house, 0, "h:5,0", "b", 1)
	_check(corner == {"edge": "v:6,0", "side": "a"}, "en la esquina de adentro dobla (%s)" % [corner])
	var outside := WallFaces.next_face(house, 0, "h:5,0", "a", 1)
	_check(outside == {"edge": "v:6,0", "side": "b"}, "por afuera rodea la esquina (%s)" % [outside])

	# Pintar una cara no pinta la otra.
	var wall: Dictionary = house.get_piece(0, "walls", "h:2,0").duplicate()
	wall["color_b"] = "#ff0000"
	house.apply([HouseData.write(0, "walls", "h:2,0", wall)])
	_check(HousePieces.wall_face_color(house.get_piece(0, "walls", "h:2,0"), "b") == Color("#ff0000")
		and HousePieces.wall_face_color(house.get_piece(0, "walls", "h:2,0"), "a") != Color("#ff0000"),
		"pintar adentro no pinta afuera")
	_check(HousePermissions.is_minor(house, [HouseData.write(0, "walls", "h:2,1", {"item": "wall_basic", "color_a": "#00ff00"})]) == false,
		"una pared nueva no es cambio menor")
	_check(HousePermissions.is_minor(house, [HouseData.write(0, "walls", "h:2,0", {"item": "wall_basic", "color_a": "#00ff00"})]),
		"pintar una cara sí es cambio menor")

	# Cuartos: cerrados por paredes; el tipo sale de los muebles.
	var rooms := HouseRooms.detect(house, 0)
	_check(rooms.size() == 1 and rooms[0]["cells"].size() == 36 and rooms[0]["type"] == "empty", "un cuarto cerrado y vacío")
	house.apply([HouseData.write(0, "objects", "b1", {"item": "bed_basic", "cell": [1, 1], "rot": 0})])
	var room := HouseRooms.room_at(house, 0, Vector2i(4, 4))
	_check(room["type"] == "bedroom" and room["name"] == "Dormitorio", "con una cama es dormitorio")
	_check(HouseRooms.recommended_items(room)[0] in ["bed_basic", "bed_double"], "la Tienda recomienda primero cosas de dormitorio")
	house.apply([HouseData.write(0, "objects", "k1", {"item": "stove_basic", "cell": [4, 1], "rot": 0})])
	_check(HouseRooms.room_at(house, 0, Vector2i(4, 4))["type"] == "mixed", "cama y cocina: multiuso")
	house.apply([HouseData.write(0, "walls", "h:0,0", null)])
	_check(HouseRooms.room_at(house, 0, Vector2i(4, 4)).is_empty(), "si se abre una pared ya no es un cuarto")


func _test_pulido_migration() -> void:
	# Una casa de antes: pintura de toda la pared y ventanas unidas solas.
	var old := {"levels": [{"walls": {
		"h:1,1": {"item": "wall_basic", "opening": "window_basic", "color": "#ffd966"},
		"h:2,1": {"item": "wall_basic", "opening": "window_basic"},
		"h:5,1": {"item": "wall_basic", "opening": "window_basic"},
		"h:6,1": {"item": "wall_basic", "opening": "window_basic", "separate": true},
	}}], "next_id": 3, "lot_size": [32, 32]}
	var house := HouseData.new()
	house.from_dict(old)
	var a: Dictionary = house.get_piece(0, "walls", "h:1,1")
	_check(a.get("color_a") == "#ffd966" and a.get("color_b") == "#ffd966" and not a.has("color"), "migración: la pintura pasa a las dos caras")
	_check(a.get("join_end", false), "migración: las ventanas que se veían unidas quedan unidas en la juntura")
	_check(not house.get_piece(0, "walls", "h:5,1").has("join_end") and not house.get_piece(0, "walls", "h:6,1").has("separate"),
		"migración: las separadas quedan separadas (y sin la marca vieja)")
	_check(house.to_dict()["format"] == HouseData.FORMAT, "la casa se guarda con formato 3")
	var again := HouseData.new()
	var dict := house.to_dict()
	dict["levels"][3]["walls"]["h:1,1"].erase("join_end")  # El jugador las separó.
	again.from_dict(dict)
	_check(not again.get_piece(0, "walls", "h:1,1").has("join_end"), "una casa nueva no se vuelve a migrar")
	var save := SaveMigrations.migrate({"format_version": 2, "state": {"house": old.duplicate(true), "economy": {}}}, 3)
	_check(save["state"]["house"]["format"] == 3
		and save["state"]["house"]["levels"][0]["walls"]["h:1,1"].get("color_b") == "#ffd966", "guardado v2 → v3")


## Pulido 2A: el techo "trabado". Causa real: un techo en un piso más alto
## que cualquier cosa construida no tenía a dónde ir (el selector de pisos
## solo ofrecía "lo construido + 1"), y uno roto (sin medidas o fuera de la
## parcela) no se podía tocar. Ahora: todo piso con algo cuenta, y lo roto se
## saca al cargar.
func _test_pulido2_roofs_and_floors() -> void:
	var house := _box_house()
	_check(house.floors_total() == 1, "casa de un piso: 1 piso (sin piso de regalo)")
	# Techo "viejo" en el piso 3, sin nada abajo.
	house.apply([HouseData.write(3, "roofs", "o50", {"item": "roof_basic", "rect": [0, 0, 6, 6]})])
	_check(house.floors_total() == 4, "un techo en el piso 3 hace que el piso 3 exista (se puede llegar y borrar)")
	var erase := HouseRules.removal_closure(house, HouseData.write(3, "roofs", "o50", null))
	_check(erase.size() == 1, "un techo se borra solo, sin arrastrar nada")
	house.apply(erase)
	_check(house.floors_total() == 1, "al borrarlo, el piso fantasma desaparece")

	# Techos rotos se sacan al cargar.
	var broken := _box_house().to_dict()
	broken["levels"][3]["roofs"] = {
		"o1": {"item": "roof_basic", "rect": [30, 30, 9, 9]},
		"o2": {"item": "roof_basic", "rect": [1, 1, 0, 3]},
		"o3": {"item": "roof_basic"},
		"o4": {"item": "roof_basic", "rect": [0, 0, 6, 6]},
	}
	var loaded := HouseData.new()
	loaded.from_dict(broken)
	_check(loaded.repaired_count == 3 and loaded.get_layer(0, "roofs").keys() == ["o4"], "al cargar se sacan los 3 techos rotos y queda el sano")

	# Agregar piso.
	var base := _box_house()
	_check(HouseRules.add_floor_problem(base) == "", "casa sin techo: se puede agregar un piso")
	base.apply([HouseData.write(0, "roofs", "o60", {"item": "roof_basic", "rect": [0, 0, 6, 6]})])
	_check(HouseRules.add_floor_problem(base) == "Para agregar un piso tiene que haber una parte sin techo.",
		"todo el piso techado: avisa que falta una parte sin techo")
	base.apply([HouseData.write(0, "roofs", "o60", {"item": "roof_basic", "rect": [0, 0, 3, 6]})])
	_check(HouseRules.add_floor_problem(base) == "", "con una parte sin techo, sí se puede")
	base.floor_count = 2
	_check(base.floors_total() == 2, "piso agregado (vacío) cuenta como piso")
	_check(HouseRules.add_floor_problem(base).begins_with("Primero construí"), "no se agrega otro piso sobre uno vacío")
	_check(HouseData.new().floors_total() == 1 and HouseRules.add_floor_problem(HouseData.new()).begins_with("Primero construí"),
		"casa vacía: no se puede agregar piso")
	var five := _box_house()
	five.floor_count = HouseGrid.MAX_LEVELS
	_check(HouseRules.add_floor_problem(five).begins_with("Ya tenés"), "tope de pisos")
	var saved := HouseData.new()
	saved.from_dict(base.to_dict())
	_check(saved.floors_total() == 2, "los pisos agregados se guardan")

	# El dibujo de la fachada: solo paredes de afuera, con puerta y ventana.
	var facade := _box_house()
	facade.apply([HouseData.write(0, "walls", "h:2,6", {"item": "wall_basic", "opening": "door_basic"}),
		HouseData.write(0, "walls", "h:4,6", {"item": "wall_basic", "opening": "window_basic"}),
		HouseData.write(0, "walls", "h:3,2", {"item": "wall_basic"})])  # Una de adentro.
	var walls := FloorMap.exterior_walls(facade, 0)
	_check(walls.size() == 24, "la fachada dibuja las 24 paredes de afuera, no la de adentro (%d)" % walls.size())
	var door: Dictionary = walls.filter(func(w): return w["key"] == "h:2,6")[0]
	_check(door["opening"] == "door" and door["normal"] == Vector2i(0, 1), "la puerta del frente mira hacia la calle (+Z)")
	_check(FloorMap.view_direction(0).y > 0.9 and FloorMap.view_direction(4).y < -0.9, "8 ángulos: el 4 mira desde atrás")


## Pulido 2A: el basurero borra cualquier pieza (con lo que se apoya en ella).
func _test_pulido2_erase_everything() -> void:
	var house := _box_house()
	house.apply([HouseData.write(1, "floors", "2,2", {"item": "floor_basic"}),
		HouseData.write(0, "objects", "o1", {"item": "chair_basic", "cell": [3, 3], "rot": 0}),
		HouseData.write(0, "roofs", "o2", {"item": "roof_basic", "rect": [0, 0, 6, 6]})])
	for entry in [[0, "roofs", "o2"], [0, "objects", "o1"], [0, "walls", "h:1,0"], [0, "floors", "1,1"], [1, "floors", "2,2"]]:
		var closure := HouseRules.removal_closure(house, HouseData.write(entry[0], entry[1], entry[2], null))
		var copy := house.duplicate_data()
		copy.apply(closure)
		_check(not copy.has_piece(entry[0], entry[1], entry[2]), "se puede borrar %s de %s" % [entry[2], entry[1]])
		_check(HouseRules.problems(copy).filter(func(p): return p["layer"] != "").size() <= HouseRules.problems(house).filter(func(p): return p["layer"] != "").size(),
			"borrar %s no deja piezas en el aire" % entry[2])
	# Los cimientos arrastran piso, paredes y mueble de esa celda.
	var closure := HouseRules.removal_closure(house, HouseData.write(0, "foundation", "3,3", null))
	var ids := closure.map(func(w): return "%s:%s" % [w["layer"], w["key"]])
	_check("floors:3,3" in ids and "objects:o1" in ids, "borrar cimientos se lleva el piso y el mueble de arriba")
	# Una pared que sostiene un piso de arriba se lleva ese piso.
	var upper := _box_house()
	upper.apply([HouseData.write(0, "floors", "2,0", null)])
	upper.apply([HouseData.write(1, "floors", "2,0", {"item": "floor_basic"})])
	var wall_closure := HouseRules.removal_closure(upper, HouseData.write(0, "walls", "h:2,0", null))
	_check(wall_closure.size() >= 2 and wall_closure.any(func(w): return w["layer"] == "floors" and w["level"] == 1),
		"borrar la pared que sostiene el piso de arriba borra también ese piso")


## Pulido 2C: sótanos (niveles -1 a -3), excavación y migración de casas de 5 niveles.
func _test_pulido2_basements() -> void:
	_check(HouseGrid.level_range() == [-3, -2, -1, 0, 1, 2, 3, 4], "niveles de -3 a 4 (3 sótanos y 5 pisos)")
	_check(HouseGrid.level_index(-3) == 0 and HouseGrid.level_index(0) == 3 and HouseGrid.LEVEL_COUNT == 8, "el sótano -3 es la posición 0")
	_check(HouseGrid.level_name(-2) == "Sótano 2" and HouseGrid.level_name(0) == "Planta baja" and HouseGrid.level_name(2) == "Piso 2", "nombres de los niveles")
	var house := _box_house()
	var item := {"item": "excavation_basic"}
	_check(HouseRules.is_supported(house, -1, "excavation", "2,2", item), "se puede excavar el primer sótano")
	_check(not HouseRules.is_supported(house, -2, "excavation", "2,2", item), "el segundo sótano necesita el primero excavado")
	_check(not HouseRules.is_supported(house, 0, "excavation", "2,2", item) and not HouseRules.is_supported(house, 1, "excavation", "2,2", item), "no se excava en la planta baja ni arriba")
	_check(not HouseRules.is_supported(house, -4, "excavation", "2,2", item), "más abajo del tercer sótano, no")
	var foundation := {"item": "foundation_basic"}
	_check(not HouseRules.is_supported(house, -1, "foundation", "2,2", foundation), "antes de los cimientos de un sótano hay que excavar")
	house.apply([HouseData.write(-1, "excavation", "2,2", item), HouseData.write(-2, "excavation", "2,2", item)])
	_check(HouseRules.is_supported(house, -1, "foundation", "2,2", foundation) and HouseRules.is_supported(house, -2, "excavation", "2,2", item), "excavado: ya van cimientos (y se sigue bajando)")
	house.apply([HouseData.write(-1, "foundation", "2,2", foundation)])
	_check(HouseRules.is_supported(house, -1, "floors", "2,2", {"item": "floor_basic"}), "el piso del sótano va sobre sus cimientos")
	house.apply([HouseData.write(-1, "floors", "2,2", {"item": "floor_basic"})])
	_check(HouseRules.is_supported(house, -1, "walls", "h:2,2", {"item": "wall_basic"}) and not HouseRules.is_supported(house, -1, "walls", "h:20,20", {"item": "wall_basic"}), "paredes del sótano junto a los cimientos")
	_check(not HouseRules.is_supported(house, -1, "roofs", "o1", {"item": "roof_basic", "rect": [2, 2, 1, 1]}), "un sótano no lleva techo")
	_check(HouseRules.is_supported(house, 0, "floors", "2,2", {"item": "floor_basic"}), "el piso de la planta baja sigue apoyado en sus cimientos")
	# Quitar la excavación se lleva todo lo de adentro y la de más abajo.
	var closure := HouseRules.removal_closure(house, HouseData.write(-1, "excavation", "2,2", null))
	var ids := closure.map(func(w): return "%d:%s" % [w["level"], w["layer"]])
	_check("-1:foundation" in ids and "-1:floors" in ids and "-2:excavation" in ids, "borrar la excavación se lleva los cimientos, el piso y la de abajo (%s)" % str(ids))
	# Acceso: a un sótano se baja por una escalera que está EN el sótano.
	var home := _box_house()
	home.apply([HouseData.write(-1, "excavation", "1,1", item), HouseData.write(-1, "foundation", "1,1", foundation), HouseData.write(-1, "floors", "1,1", {"item": "floor_basic"}),
		HouseData.write(-1, "excavation", "1,2", item), HouseData.write(-1, "foundation", "1,2", foundation), HouseData.write(-1, "floors", "1,2", {"item": "floor_basic"})])
	_check(not HouseRules.has_access(home, -1), "sin escalera, al sótano no se llega")
	_check(HouseRules.problems(home).any(func(p): return p["text"].contains("Sótano 1: sin acceso")), "avisa que le falta una escalera")
	home.apply([HouseData.write(-1, "objects", "o5", {"item": "stairs_basic", "cell": [1, 1], "rot": 2})])
	_check(HouseRules.has_access(home, -1), "con una escalera en el sótano, se llega")
	# Agregar sótano.
	var base := _box_house()
	_check(HouseRules.add_basement_problem(base) == "", "con cimientos en la planta baja, se puede agregar el primer sótano")
	base.basement_count = 1
	_check(base.lowest_level() == -1 and HouseRules.add_basement_problem(base).begins_with("Primero construí"), "no se agrega otro sin construir en el de arriba")
	base.basement_count = 3
	_check(base.lowest_level() == -3 and HouseRules.add_basement_problem(base).begins_with("Ya tenés"), "tope de 3 sótanos")
	# Casas de antes (5 niveles) y guardado.
	var legacy := {"levels": [{"foundation": {"1,1": {"item": "foundation_basic"}}}, {}, {}, {}, {}], "next_id": 2, "lot_size": [32, 32], "format": 3}
	var old := HouseData.new()
	old.from_dict(legacy)
	_check(old.levels.size() == 8 and old.has_piece(0, "foundation", "1,1") and old.get_layer(-1, "foundation").is_empty(), "una casa de 5 niveles pasa a 8 (los sótanos, vacíos)")
	var saved := HouseData.new()
	saved.from_dict({"levels": [{}, {}, {"excavation": {"3,3": item}}, {"foundation": {"3,3": foundation}}, {}, {}, {}, {}], "next_id": 2, "lot_size": [32, 32], "format": 4})
	_check(saved.has_piece(-1, "excavation", "3,3") and saved.has_piece(0, "foundation", "3,3") and saved.lowest_level() == -1, "una casa de 8 niveles se lee tal cual")
	var again := HouseData.new()
	again.from_dict(saved.to_dict())
	_check(again.has_piece(-1, "excavation", "3,3") and again.levels.size() == 8, "ida y vuelta del guardado con sótano")
