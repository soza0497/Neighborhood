extends Node
## Pruebas del Pulido 6B (personaje): accidentes declarados por elemento (data/accidents.json),
## caminar en cualquier dirección, puertas que se abren y la caída. Sin red.
##
##   godot --headless --path . res://tests/test_accidents.tscn

var _passed := 0
var _failed := 0
var _accidents: Array = []
var _ambulances := 0


func _ready() -> void:
	HouseGrid.use_test_lot()
	HazardMap.clear()
	EventBus.ambulance_requested.connect(func(_patient: Node3D) -> void: _ambulances += 1)
	EventBus.character_accident.connect(func(kind: String, _l: int, _c: Vector2i, _r: String) -> void: _accidents.append(kind))
	_test_data()
	_test_door_rules()
	_test_puddle_rules()
	_test_stove_rule()
	_test_smoother_math()
	_test_free_walking()
	_test_walk_turns_smoothly()
	_test_slip_in_game()
	await _test_fall_drop()
	await _test_doors_open()
	HazardMap.clear()
	print("\nPRUEBAS: %d pasaron, %d fallaron" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _check(condition: bool, description: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		print("FALLÓ: ", description)


func _free(node: Node) -> void:
	remove_child(node)
	node.free()


func _make_character(house: HouseData, start := Vector2i(4, 10)) -> Character:
	var nav := HouseNav.new(house)
	var character := Character.new()
	add_child(character)
	character.setup(CharacterData.create_default(), house, nav, null)
	character.place_at(0, start)
	character.cell = start
	return character


func _run(character: Character, until: Callable, seconds := 60.0) -> void:
	var elapsed := 0.0
	while elapsed < seconds and not until.call():
		character._process(0.1)
		elapsed += 0.1


## Un cuarto de 3x3 (celdas 1..3, piso `floor_item`) con una puerta al sur en la celda x = 2.
func _room(floor_item := "floor_basic") -> HouseData:
	var house := HouseData.new()
	var writes: Array = []
	for c in HouseGrid.cells_in_rect(Vector2i(1, 1), Vector2i(3, 3)):
		writes.append(HouseData.write(0, "foundation", HouseGrid.cell_key(c), {"item": "foundation_basic"}))
		writes.append(HouseData.write(0, "floors", HouseGrid.cell_key(c), {"item": floor_item}))
	for edge in HouseGrid.edges_around_rect(Vector2i(1, 1), Vector2i(3, 3)):
		writes.append(HouseData.write(0, "walls", edge, {"item": "wall_basic"}))
	writes.append(HouseData.write(0, "walls", "h:2,4", {"item": "wall_basic", "opening": "door_basic"}))
	house.apply(writes)
	return house


func _test_data() -> void:
	print("1) Reglas de accidentes en datos")
	var rules := AccidentRules.data()["rules"] as Dictionary
	_check(rules.size() >= 6, "hay reglas (%d)" % rules.size())
	for id in rules:
		var rule: Dictionary = rules[id]
		_check(rule.has("on") and rule.has("accident") and HazardMap.accident_info(str(rule["accident"])).size() > 0,
			"la regla «%s» usa un accidente que existe" % id)
	for item_id in Catalog.items:
		var item: Dictionary = Catalog.items[item_id]
		for rule_id in item.get("accidents", []):
			_check(not AccidentRules.rule(str(rule_id)).is_empty(), "«%s» declara la regla «%s», que existe" % [item["id"], rule_id])
	for kind in HazardMap.kinds():
		for rule_id in HazardMap.kind_info(kind).get("rules", []):
			_check(not AccidentRules.rule(str(rule_id)).is_empty(), "el peligro «%s» declara la regla «%s», que existe" % [kind, rule_id])
	_check(AccidentRules.rules_for_item("door_basic").has("door_void"), "la puerta declara su regla")
	_check(AccidentRules.rules_for_item("stove_basic").has("stove_burn"), "la cocina declara su regla")
	_check(Catalog.get_item("floor_tile").get("slippery", false) and not Catalog.get_item("floor_basic").get("slippery", false), "la baldosa es resbalosa y la madera no")
	_check(not AccidentRules.conditions_met({"when": {"condicion_inventada": true}}, {}), "una condición desconocida nunca se cumple")
	_check(AccidentRules.conditions_met({}, {}), "una regla sin condiciones siempre se cumple")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	_check(AccidentRules.rolls({"chance": 1.0}, rng) and not AccidentRules.rolls({"chance": 0.0}, rng), "la probabilidad 1 siempre y la 0 nunca")
	for hook in ["slip", "fall"]:
		_check(hook in CharacterAnimator.ANIMATIONS, "gancho «%s»" % hook)


func _test_door_rules() -> void:
	print("2) Puerta: piso a ambos lados = nada; piso de un lado y vacío = caída")
	var door_rules := AccidentRules.rules_for_item("door_basic")
	# Piso 1: puerta entre (3,1) y (4,1) (borde vertical v:4,1).
	var upper := HouseData.new()
	upper.apply([HouseData.write(1, "floors", "3,1", {"item": "floor_basic"}),
		HouseData.write(1, "walls", "v:4,1", {"item": "wall_basic", "opening": "door_basic"})])
	var ctx := {"house": upper, "level": 1, "edge": "v:4,1", "attention": 1.0}
	var found := AccidentRules.first_match(door_rules, "pass_door", ctx)
	_check(not found.is_empty() and found["rule"]["accident"] == "fall", "piso de un lado y vacío del otro: caída")
	upper.apply([HouseData.write(1, "floors", "4,1", {"item": "floor_basic"})])
	_check(AccidentRules.first_match(door_rules, "pass_door", ctx).is_empty(), "piso a ambos lados: sin accidente")
	var ground := HouseData.new()
	ground.apply([HouseData.write(0, "floors", "3,1", {"item": "floor_basic"}),
		HouseData.write(0, "walls", "v:4,1", {"item": "wall_basic", "opening": "door_basic"})])
	_check(AccidentRules.first_match(door_rules, "pass_door", {"house": ground, "level": 0, "edge": "v:4,1"}).is_empty(),
		"en la planta baja, salir al pasto no es un vacío")
	_check(AccidentRules.first_match(door_rules, "enter_cell", ctx).is_empty(), "una regla solo vale para su disparador")
	# La IA va a probar suerte solo en una puerta al vacío.
	var house := HouseData.new()
	house.apply([HouseData.write(1, "floors", "3,1", {"item": "floor_basic"}), HouseData.write(1, "floors", "2,1", {"item": "floor_basic"}),
		HouseData.write(1, "walls", "v:4,1", {"item": "wall_basic", "opening": "door_basic"})])
	var seeker := _make_character(house, Vector2i(3, 1))
	seeker.level = 1
	var door := seeker._seek_door()
	_check(not door.is_empty() and door["inside"] == Vector2i(3, 1) and door["outside"] == Vector2i(4, 1), "la IA encuentra la puerta al vacío (adentro %s)" % str(door.get("inside")))
	_check(float(door["rule"].get("seek", 0.0)) > 0.0, "y la regla dice con qué frecuencia la prueba (seek)")
	house.apply([HouseData.write(1, "floors", "4,1", {"item": "floor_basic"})])
	_check(seeker._seek_door().is_empty(), "con piso a ambos lados ya no hay puerta que probar")
	_free(seeker)


func _test_puddle_rules() -> void:
	print("3) Charco: resbala sobre piso resbaloso y frente a una puerta con piso de adentro")
	var rules := AccidentRules.rules_for_hazard("wet")
	var tile := _room("floor_tile")
	var wood := _room("floor_basic")
	var slip_inside_tile := AccidentRules.first_match(rules, "enter_cell", {"house": tile, "level": 0, "cell": Vector2i(2, 2)})
	_check(not slip_inside_tile.is_empty() and slip_inside_tile["rule"]["accident"] == "slip", "sobre baldosa: resbala")
	_check(AccidentRules.first_match(rules, "enter_cell", {"house": wood, "level": 0, "cell": Vector2i(2, 2)}).is_empty(), "sobre madera, en medio del cuarto: nada")
	var door_front := AccidentRules.first_match(rules, "enter_cell", {"house": wood, "level": 0, "cell": Vector2i(2, 4)})
	_check(not door_front.is_empty() and door_front["id"] == "puddle_door", "frente a la puerta (con piso de adentro): resbala")
	_check(AccidentRules.first_match(rules, "enter_cell", {"house": wood, "level": 0, "cell": Vector2i(6, 6)}).is_empty(), "en campo abierto: nada")
	_check(AccidentRules.first_match(rules, "enter_cell", {"house": wood, "level": 0, "cell": Vector2i(3, 5)}).is_empty(), "al lado de la puerta (no enfrente): nada")
	_check(not AccidentRules.first_match(AccidentRules.rules_for_hazard("hot"), "enter_cell", {}).is_empty(), "lo caliente siempre quema")
	_check(not AccidentRules.first_match(AccidentRules.rules_for_hazard("drop"), "enter_cell", {}).is_empty(), "el desnivel siempre hace tropezar")


func _test_stove_rule() -> void:
	print("4) Sartén: quema solo a quien anda distraído")
	var rules := AccidentRules.rules_for_item("stove_basic")
	_check(AccidentRules.first_match(rules, "use_object", {"action": "cook", "attention": 1.0}).is_empty(), "atento: no pasa nada")
	_check(not AccidentRules.first_match(rules, "use_object", {"action": "cook", "attention": 0.3})["rule"]["accident"] == "", "distraído cocinando: se quema")
	_check(AccidentRules.first_match(rules, "use_object", {"action": "snack", "attention": 0.3}).is_empty(), "distraído pero sin cocinar: nada")
	# En el juego: distraído y con la regla asegurada (probabilidad 1), se quema al empezar a cocinar.
	var house := HouseData.new()
	house.apply([HouseData.write(0, "objects", "o1", {"item": "stove_basic", "cell": [8, 10], "rot": 0})])
	var character := _make_character(house)
	var original_chance: float = AccidentRules.data()["rules"]["stove_burn"]["chance"]
	AccidentRules.data()["rules"]["stove_burn"]["chance"] = 1.0
	_accidents.clear()
	character.attention = 0.2
	character.order(0, "o1", "cook")
	_run(character, func() -> bool: return character.hurt)
	_check(character.hurt and _accidents == ["burn"], "distraído se quema con la sartén")
	AccidentRules.data()["rules"]["stove_burn"]["chance"] = original_chance
	character.recover()
	character.attention = 1.0
	character.teleport_to(0, Vector2i(4, 10))
	_accidents.clear()
	character.order(0, "o1", "cook")
	_run(character, func() -> bool: return character.state == Character.State.ACTING)
	_check(character.state == Character.State.ACTING and _accidents.is_empty(), "atento cocina sin accidentes")
	_free(character)


func _test_smoother_math() -> void:
	print("5) Alisar el camino")
	var staircase := PackedVector3Array([Vector3(0.5, 0, 0.5), Vector3(1.5, 0, 0.5), Vector3(2.5, 0, 1.5), Vector3(3.5, 0, 1.5), Vector3(4.5, 0, 2.5)])
	var always := PathSmoother.smooth(staircase, func(_a: Vector3, _b: Vector3) -> bool: return true)
	_check(always.size() == 2 and always[0] == staircase[0] and always[1] == staircase[4], "con la recta libre, va de punta a punta")
	var never := PathSmoother.smooth(staircase, func(_a: Vector3, _b: Vector3) -> bool: return false)
	_check(never.size() == staircase.size(), "si ninguna recta está libre, queda como estaba")
	var stairs := PackedVector3Array([Vector3(0.5, 0, 0.5), Vector3(1.5, 0, 0.5), Vector3(2.5, 1.0, 0.5), Vector3(3.5, 3.0, 0.5), Vector3(4.5, 3.0, 0.5)])
	var kept := PathSmoother.smooth(stairs, func(_a: Vector3, _b: Vector3) -> bool: return true)
	_check(kept.size() >= 4, "las escaleras (cambio de altura) no se cortan (%d puntos)" % kept.size())
	var short := PackedVector3Array([Vector3(0, 0, 0), Vector3(1, 0, 0)])
	_check(PathSmoother.smooth(short, func(_a: Vector3, _b: Vector3) -> bool: return false) == short, "un camino de dos puntos no cambia")
	var points := PathSmoother.samples(Vector3(0, 0, 0), Vector3(4, 0, 0))
	_check(points.size() % 3 == 0 and points.size() >= 3 * 16, "se revisa la recta cada pocos centímetros, con el cuerpo a los lados")


func _test_free_walking() -> void:
	print("6) Caminar en cualquier dirección")
	var house := HouseData.new()
	var character := _make_character(house, Vector2i(4, 10))
	var target := Vector2i(12, 13)
	var grid_path := character.nav.find_path(0, character.cell, 0, target)
	character.force_action({"type": "go", "level": 0, "cell": target})
	_check(grid_path.size() > 3, "la red da un camino de celda en celda (%d puntos)" % grid_path.size())
	_check(character._path.size() == 2, "en campo abierto el camino alisado es una recta (%d puntos)" % character._path.size())
	var direction := character._path[1] - character._path[0]
	var degrees := rad_to_deg(atan2(direction.x, direction.z))
	_check(absf(fmod(degrees, 45.0)) > 5.0 and absf(fmod(degrees, 45.0)) < 40.0, "y va en un ángulo que no es de 4 ni de 8 direcciones (%.1f°)" % degrees)
	_run(character, func() -> bool: return character.cell == target)
	_check(character.cell == target and character.state == Character.State.IDLE, "llega bien adonde iba")
	_free(character)
	# Con una pared en el medio rodea (no la atraviesa) y por la puerta pasa por el centro.
	var room := _room()
	var inside := _make_character(room, Vector2i(2, 2))
	inside.force_action({"type": "go", "level": 0, "cell": Vector2i(6, 7)})
	var through_door := false
	for point in inside._path:
		if absf(point.x - 2.5) < 0.05 and absf(point.z - 4.5) < 0.6:
			through_door = true
	_check(inside._path.size() >= 3 and through_door, "para salir del cuarto pasa por el centro de la puerta (%d puntos)" % inside._path.size())
	_run(inside, func() -> bool: return inside.cell == Vector2i(6, 7))
	_check(inside.cell == Vector2i(6, 7), "y sale")
	_free(inside)


func _test_walk_turns_smoothly() -> void:
	print("7) Giro suave")
	var character := _make_character(HouseData.new(), Vector2i(4, 10))
	character.rotation.y = 0.0
	character.force_action({"type": "go", "level": 0, "cell": Vector2i(14, 10)})  # Hacia +X: ángulo π/2.
	character._process(0.016)
	_check(character.rotation.y > 0.0 and character.rotation.y < PI / 2.0 - 0.1, "no gira de golpe: primer cuadro a %.2f rad" % character.rotation.y)
	_run(character, func() -> bool: return character.cell == Vector2i(14, 10))
	_check(absf(character.rotation.y - PI / 2.0) < 0.1, "enseguida queda mirando adonde camina")
	_free(character)


func _test_slip_in_game() -> void:
	print("8) Resbalón en el juego")
	HazardMap.clear()
	var house := HouseData.new()
	house.apply([HouseData.write(0, "foundation", "8,10", {"item": "foundation_basic"}), HouseData.write(0, "floors", "8,10", {"item": "floor_tile"})])
	HazardMap.add(0, Vector2i(8, 10), "wet")
	var character := _make_character(house, Vector2i(4, 10))
	character.attention = 0.1
	_accidents.clear()
	_ambulances = 0
	character.force_action({"type": "go", "level": 0, "cell": Vector2i(12, 10)})
	_run(character, func() -> bool: return not _accidents.is_empty())
	_check(_accidents == ["slip"] and not character.hurt and _ambulances == 0, "pasa por el charco sobre baldosa y resbala, sin ambulancia")
	_check(character._animator.current == "slip" and character.current_cell() == Vector2i(8, 10), "con su animación, en la celda del charco")
	HazardMap.clear()
	_free(character)


func _test_fall_drop() -> void:
	print("9) La caída desde un piso alto baja en arco")
	var house := HouseData.new()
	house.floor_count = 2
	house.apply([HouseData.write(1, "floors", "3,1", {"item": "floor_basic"}), HouseData.write(1, "floors", "2,1", {"item": "floor_basic"}),
		HouseData.write(1, "walls", "v:4,1", {"item": "wall_basic", "opening": "door_basic"})])
	var character := _make_character(house, Vector2i(3, 1))
	character.place_at(1, Vector2i(3, 1))
	var start_y := character.position.y
	_accidents.clear()
	_ambulances = 0
	character.fall_to(Vector2i(4, 1))
	_check(character.hurt and character.level == 0 and _accidents == ["fall"] and _ambulances == 1, "se cae por la puerta: lastimado, en el suelo y llama a la ambulancia")
	_check(absf(character.position.y - start_y) < 0.05, "empieza la caída desde arriba (y = %.2f)" % character.position.y)
	await get_tree().create_timer(0.25).timeout
	_check(character.position.y < start_y - 0.05 and character.position.y > 0.1, "a mitad de camino está en el aire (y = %.2f)" % character.position.y)
	await get_tree().create_timer(1.2).timeout
	_check(absf(character.position.y) < 0.05 and absf(character.position.x - 4.5) < 0.05, "y termina en el suelo de afuera")
	_check(character._animator.current == "fall", "mientras tanto usa la animación «fall»")
	character.recover()
	_free(character)


func _test_doors_open() -> void:
	print("10) Puertas que se abren hacia su lado")
	var house := _room()
	var view := HouseView.new()
	add_child(view)
	view.setup(house)
	var animator := DoorAnimator.new()
	add_child(animator)
	animator.setup(view, house)
	var nav := HouseNav.new(house)
	var character := Character.new()
	view.add_child(character)
	character.setup(CharacterData.create_default(), house, nav, view)
	character.place_at(0, Vector2i(6, 8))
	character.cell = Vector2i(6, 8)
	await get_tree().process_frame
	var wall_node := view.get_piece_node(0, "walls", "h:2,4")
	_check(wall_node != null and DoorAnimator.make_pivot(wall_node) != null, "la pared con puerta se dibujó y se le encuentra la hoja")
	var pivot := wall_node.get_node_or_null("DoorPivot") as Node3D
	_check(pivot != null and pivot.get_child_count() >= 1, "la hoja (y la manija) cuelgan de un pivote en la bisagra")
	# Un solo sentido: hacia adentro (el lado con piso).
	_check(DoorAnimator.swing_side(house, 0, "h:2,4") == "a", "se abre hacia adentro (la cara con piso)")
	house.apply([HouseData.write(0, "walls", "h:2,4", {"item": "wall_basic", "opening": "door_basic", "swing": "b"})])
	_check(DoorAnimator.swing_side(house, 0, "h:2,4") == "b", "si la puerta guarda su lado, se respeta")
	house.apply([HouseData.write(0, "walls", "h:2,4", {"item": "wall_basic", "opening": "door_basic"})])
	_check(DoorAnimator.swing_angle("a", 1.0) > 1.5 and DoorAnimator.swing_angle("b", 1.0) < -1.5 and DoorAnimator.swing_angle("a", 0.0) == 0.0, "el ángulo va de 0 a ~100° y cada cara tiene su signo")
	# Lejos: cerrada. Cerca: se abre. Otra vez lejos: se cierra.
	animator._process(0.3)
	_check(animator.door_count() == 1 and animator.open_amount(0, "h:2,4") == 0.0, "lejos, la puerta está cerrada")
	character.place_at(0, Vector2i(2, 4))
	for i in 12:
		animator._process(0.3)
	_check(animator.open_amount(0, "h:2,4") > 0.95, "cerca del personaje se abre del todo")
	var current_pivot := view.get_piece_node(0, "walls", "h:2,4").get_node_or_null("DoorPivot") as Node3D
	_check(current_pivot != null and current_pivot.rotation.y > 1.5, "y la hoja gira hacia la cara «a» (%.2f rad)" % (current_pivot.rotation.y if current_pivot != null else 0.0))
	character.place_at(0, Vector2i(6, 8))
	for i in 12:
		animator._process(0.3)
	_check(animator.open_amount(0, "h:2,4") < 0.05, "al alejarse, se cierra")
	# Si la casa vuelve a dibujar la pared mientras está abierta, la puerta sigue abierta.
	character.place_at(0, Vector2i(2, 4))
	for i in 12:
		animator._process(0.3)
	house.apply([HouseData.write(0, "walls", "h:2,4", {"item": "wall_basic", "opening": "door_basic", "color_a": "#ffd966"})])
	for i in 4:
		animator._process(0.3)
	var redrawn := view.get_piece_node(0, "walls", "h:2,4").get_node_or_null("DoorPivot") as Node3D
	_check(redrawn != null and redrawn.rotation.y > 1.5, "si cambian la pared mientras está abierta, la puerta sigue abierta")
	_free(animator)
	_free(view)
