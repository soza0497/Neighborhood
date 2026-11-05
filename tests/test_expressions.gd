extends Node
## Pruebas del Pulido 6B: expresiones (nubecita de cómic) en vez de diálogos, y el modo
## desarrollador (ir hasta el piso y el punto tocados, panel dentro de la pantalla, oculto al
## construir). Sin red.
##
##   godot --headless --path . res://tests/test_expressions.tscn

var _passed := 0
var _failed := 0
var _saved_settings: Dictionary = {}


func _ready() -> void:
	HouseGrid.use_test_lot()
	HazardMap.clear()
	_saved_settings = GameState.settings.duplicate(true)
	GameState.settings.erase(DevMode.SETTING)
	_test_data()
	_test_render()
	await _test_bubble()
	await _test_character_expressions()
	_test_services_use_clouds()
	_test_go_to_floor_and_point()
	await _test_panel()
	GameState.settings = _saved_settings
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


func _test_data() -> void:
	print("1) Datos de expresiones")
	var ids := ExpressionArt.expression_ids()
	_check(ids.size() >= 25, "hay variedad de expresiones (%d)" % ids.size())
	var kinds := ["circle", "ellipse", "line", "arc", "poly"]
	for id in ids:
		var art: Array = ExpressionArt.data()["expressions"][id]["art"]
		_check(not art.is_empty(), "«%s» tiene dibujo" % id)
		for command in art:
			var known := false
			for kind in kinds:
				known = known or command.has(kind)
			_check(known, "«%s»: todas las figuras se entienden" % id)
	for event in ExpressionArt.event_names():
		for id in ExpressionArt.event_variants(event):
			_check(ExpressionArt.has_expression(str(id)), "la situación «%s» usa «%s», que existe" % [event, id])
	# Toda acción del juego y todo accidente tienen sus expresiones.
	for action_id in Catalog.actions:
		_check(not ExpressionArt.event_variants("action:" + str(action_id)).is_empty(), "la acción «%s» tiene expresiones" % action_id)
	for need in CharacterData.NEEDS:
		_check(not ExpressionArt.event_variants("need:" + str(need)).is_empty(), "la necesidad «%s» tiene expresiones" % need)
	for accident in HazardMap.accidents():
		_check(not ExpressionArt.event_variants("accident:" + str(accident)).is_empty(), "el accidente «%s» tiene expresiones" % accident)
	var varied := 0
	for event in ExpressionArt.event_names():
		if ExpressionArt.event_variants(event).size() >= 2:
			varied += 1
	_check(varied >= 12, "muchas situaciones tienen más de una expresión (%d)" % varied)
	_check(not FileAccess.get_file_as_string("res://data/actions.json").contains("\"bubble\""), "las acciones ya no traen diálogos escritos")


func _test_render() -> void:
	print("2) La nube se dibuja")
	var size := ExpressionArt.canvas_size()
	var image := ExpressionArt.render("happy")
	_check(image.get_width() == size.x and image.get_height() == size.y, "la imagen mide %d x %d" % [size.x, size.y])
	var center := image.get_pixel(size.x / 2, size.y / 2 - 6)
	_check(center.a > 0.99, "el centro de la nube es opaco")
	_check(image.get_pixel(1, 1).a < 0.01 and image.get_pixel(size.x - 2, size.y - 2).a < 0.01, "las esquinas son transparentes")
	_check(image.get_pixel(int(ExpressionArt.TAIL_TIP.x), int(ExpressionArt.TAIL_TIP.y) - 3).a > 0.5, "la colita de la nube llega abajo")
	var opaque := 0
	var colored := 0
	for y in size.y:
		for x in size.x:
			var pixel := image.get_pixel(x, y)
			if pixel.a > 0.5:
				opaque += 1
				if absf(pixel.r - pixel.b) > 0.3:
					colored += 1
	_check(opaque > 4000 and opaque < size.x * size.y * 0.8, "la nube ocupa buena parte de la imagen (%d píxeles)" % opaque)
	_check(colored > 400, "y adentro hay colores (la carita: %d píxeles amarillos o de color)" % colored)
	var happy := ExpressionArt.render("happy")
	var sad := ExpressionArt.render("sad")
	var different := 0
	for y in size.y:
		for x in size.x:
			if happy.get_pixel(x, y).is_equal_approx(sad.get_pixel(x, y)) == false:
				different += 1
	_check(different > 300, "una cara contenta y una triste no se ven igual (%d píxeles distintos)" % different)
	_check(ExpressionArt.texture("happy") == ExpressionArt.texture("happy"), "cada expresión se dibuja una sola vez y se reutiliza")
	_check(ExpressionArt.texture("zzz") is ImageTexture, "la textura es una ImageTexture")
	# Todas se dibujan sin errores y no quedan vacías.
	var empty := 0
	for id in ExpressionArt.expression_ids():
		var drawn := ExpressionArt.render(str(id))
		var inner := 0
		for y in range(30, 80, 3):
			for x in range(40, 90, 3):
				var pixel := drawn.get_pixel(x, y)
				if pixel.a > 0.5 and not (pixel.r > 0.97 and pixel.g > 0.97 and pixel.b > 0.97):
					inner += 1
		if inner < 5:
			empty += 1
			print("  (sin dibujo visible: %s)" % id)
	_check(empty == 0, "ninguna expresión queda en blanco")


func _test_bubble() -> void:
	print("3) La nubecita")
	var cloud := ExpressionBubble.new()
	add_child(cloud)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	_check(not cloud.visible and cloud.current == "", "empieza escondida")
	_check(cloud.billboard == BaseMaterial3D.BILLBOARD_ENABLED and cloud.no_depth_test, "mira siempre a la cámara y se ve aunque haya algo adelante")
	var id := cloud.say_event("action:sleep", rng)
	_check(id in ExpressionArt.event_variants("action:sleep") and cloud.visible and cloud.current == id, "una situación elige una de sus expresiones (%s)" % id)
	_check(cloud.say_event("action:sleep", rng) == id, "pedir la misma situación otra vez no la cambia (no parpadea)")
	var seen := {}
	for i in 40:
		cloud.say_event("arrive", rng, 0.0, true)
		seen[cloud.current] = true
	_check(seen.size() >= 3, "con varias variantes se ve variedad (%d distintas)" % seen.size())
	cloud.show_expression("ouch", 0.3)
	_check(cloud.current == "ouch" and cloud.is_held(), "una expresión con tiempo queda vigente")
	await get_tree().create_timer(0.5).timeout
	_check(not cloud.is_held() and cloud.current == "", "y se va sola al terminar su tiempo")
	await get_tree().create_timer(0.3).timeout
	_check(not cloud.visible, "y se esconde")
	cloud.show_expression("no_existe")
	_check(cloud.current == "" and not cloud.visible, "una expresión que no existe no muestra nada")
	_check(cloud.say_event("situacion_inventada", rng) == "", "una situación sin expresiones no muestra nada")
	var tail_screen_offset := cloud.offset
	_check(tail_screen_offset.y > 40.0, "la colita queda abajo, en el origen del nodo (offset %s)" % str(tail_screen_offset))
	_free(cloud)


func _test_character_expressions() -> void:
	print("4) El personaje usa expresiones, no diálogos")
	var house := HouseData.new()
	house.apply([HouseData.write(0, "objects", "o1", {"item": "bed_basic", "cell": [8, 10], "rot": 0})])
	var character := _make_character(house)
	_check(character._bubble is ExpressionBubble, "la burbuja es una nubecita")
	var labels := character.find_children("*", "Label3D", false, false)
	_check(labels.is_empty(), "no hay texto flotando sobre su cabeza")
	# Durmiendo: carita de dormir.
	character.order(0, "o1", "sleep")
	_run(character, func() -> bool: return character.state == Character.State.ACTING)
	character._update_bubble()
	_check(character._bubble.visible and character._bubble.key == "action:sleep" and character._bubble.current in ExpressionArt.event_variants("action:sleep"),
		"durmiendo muestra una expresión de dormir (%s)" % character._bubble.current)
	# Hambre: cuando le falta comida.
	character._stop_action()
	character._set_idle()
	character._bubble.clear()
	character.data.needs["hunger"] = 12.0
	character._update_bubble()
	_check(character._bubble.key == "need:hunger" and character._bubble.visible, "con hambre muestra su expresión de hambre")
	character.data.needs["hunger"] = 90.0
	character._bubble.clear()
	# Un resbalón: expresión de resbalón con tiempo; lastimado: se queda hasta la ambulancia.
	character._update_bubble()
	_check(not character._bubble.visible or character._bubble.key != "need:hunger", "sin necesidades urgentes no queda la carita de hambre")
	character.attention = 0.1
	_check(character.force_accident("slip"), "resbala")
	_check(character._bubble.key == "accident:slip" and character._bubble.is_held(), "el resbalón muestra su expresión por un rato")
	character._update_bubble()
	_check(character._bubble.key == "accident:slip", "y la actualización normal no la pisa mientras dura")
	character._set_idle()
	character._bubble.clear()
	_check(character.force_accident("fall") and character.hurt, "se cae")
	_check(character._bubble.key == "accident:fall" and not character._bubble._timed, "lastimado: la expresión se queda sin límite")
	character._update_bubble()
	_check(character._bubble.key == "accident:fall", "y no la pisan mientras espera la ambulancia")
	character.recover()
	_check(character._bubble.key == "thanks" and character._bubble.current in ExpressionArt.event_variants("thanks"), "al curarse agradece con una carita")
	_free(character)


func _test_services_use_clouds() -> void:
	print("5) Los servicios también usan nubecitas")
	var services := Services.new()
	add_child(services)
	var worker := services.make_worker("lumberjack")
	services.add_child(worker)
	services._bubble(worker, "no_entry", 1.0)
	var clouds := worker.find_children("*", "Sprite3D", false, false)
	_check(clouds.size() == 1 and (clouds[0] as ExpressionBubble).current == "no_entry", "«no puedo entrar» es una nubecita con una señal de prohibido")
	_check(worker.find_children("*", "Label3D", true, false).is_empty(), "sin texto escrito")
	var vehicle := services.make_vehicle("ambulance")
	services.add_child(vehicle)
	services._bubble(vehicle, "medic", 1.0)
	var vehicle_cloud := vehicle.find_children("*", "Sprite3D", false, false)
	_check(vehicle_cloud.size() == 1 and (vehicle_cloud[0] as Sprite3D).position.y > 2.0, "sobre un vehículo queda más arriba")
	_free(services)


func _test_go_to_floor_and_point() -> void:
	print("6) Ir hasta ahí respeta el piso y el punto tocado")
	DevMode.set_enabled(true)
	var house := HouseData.new()
	house.floor_count = 2
	var writes: Array = []
	for x in range(2, 9):
		writes.append(HouseData.write(1, "floors", HouseGrid.cell_key(Vector2i(x, 2)), {"item": "floor_basic"}))
	house.apply(writes)
	var character := _make_character(house, Vector2i(2, 2))
	character.place_at(1, Vector2i(2, 2))
	character.level = 1
	var target := Vector2i(7, 2)
	var point := Vector3(7.8, HouseGrid.level_y(1), 2.3)
	var result := DevMode.force_go(character, 1, target, point)
	_check(result["ok"], "ir al otro lado del piso de arriba")
	_run(character, func() -> bool: return character.cell == target and character.state == Character.State.IDLE)
	_check(character.level == 1 and character.cell == target, "llegó al piso 1 (no bajó a la planta baja)")
	_check(absf(character.position.x - 7.8) < 0.05 and absf(character.position.z - 2.3) < 0.05, "y quedó en el punto exacto tocado (%.2f, %.2f)" % [character.position.x, character.position.z])
	_check(absf(character.position.y - HouseGrid.level_y(1)) < 0.05, "a la altura del piso de arriba")
	# Sin escalera, ir al piso de abajo explica por qué no.
	var no_way := DevMode.force_go(character, 0, Vector2i(5, 5))
	_check(not no_way["ok"] and str(no_way["reason"]).contains("escalera"), "sin escalera lo dice: \"%s\"" % no_way["reason"])
	# El punto tiene que estar en la celda pedida; si no, se ignora.
	character.teleport_to(1, Vector2i(2, 2))
	DevMode.force_go(character, 1, Vector2i(5, 2), Vector3(0.0, 0.0, 0.0))
	_run(character, func() -> bool: return character.cell == Vector2i(5, 2))
	_check(absf(character.position.x - 5.5) < 0.05, "un punto fuera de la celda se ignora (va al centro)")
	var floor_pick := DevMode.pick_floor(null, null, Vector2.ZERO)
	_check(floor_pick.is_empty(), "sin vista no hay qué elegir")
	_free(character)
	DevMode.set_enabled(false)


func _test_panel() -> void:
	print("7) El panel del modo desarrollador")
	DevMode.set_enabled(true)
	var character := _make_character(HouseData.new())
	var panel: DevPanel = (load("res://ui/dev_panel.tscn") as PackedScene).instantiate()
	add_child(panel)
	panel.setup(character, character.nav, null)
	await get_tree().process_frame
	panel.open()
	_check(panel.is_open() and DevPanel.picking, "abierto en modo vivir se ve y atrapa toques")
	# Pantallas de varios tamaños (ancho x alto) y áreas seguras: siempre entra.
	var screens := [Vector2(1080, 1920) / 2.0, Vector2(720, 360), Vector2(640, 300), Vector2(360, 640), Vector2(412, 915)]
	var margin_sets := [Vector4(16, 34, 16, 22), Vector4(60, 40, 60, 30), Vector4(16, 60, 16, 40)]
	for screen in screens:
		for margins in margin_sets:
			panel.fit_to(screen, margins)
			var rect := panel.panel_rect()
			var inside := rect.position.x >= margins.x - 0.5 and rect.position.y >= margins.y - 0.5 \
				and rect.end.x <= screen.x - margins.z + 0.5 and rect.end.y <= screen.y - margins.w + 0.5
			_check(inside, "en %s con márgenes %s el panel queda dentro (%s)" % [str(screen), str(margins), str(rect)])
	# Se desliza si no entra todo.
	panel.fit_to(Vector2(720, 360), Vector4(16, 34, 16, 22))
	var content: Control = panel._scroll.get_child(0)
	_check(content.get_combined_minimum_size().y + 20.0 > panel.panel_rect().size.y, "en una pantalla baja el contenido es más largo que el panel, por eso tiene scroll")
	# Al construir no se ve; al volver a vivir reaparece.
	EventBus.game_mode_changed.emit("build")
	_check(not panel.is_open() and not DevPanel.picking and not panel._panel.visible, "en modo construir el panel NO se ve y no atrapa toques")
	EventBus.game_mode_changed.emit("live")
	_check(panel.is_open() and DevPanel.picking, "al volver a vivir reaparece (estaba abierto)")
	panel.close()
	EventBus.game_mode_changed.emit("build")
	EventBus.game_mode_changed.emit("live")
	_check(not panel.is_open(), "si lo había cerrado, no reaparece")
	# En construir, tocar el ícono no abre nada (queda pedido para después).
	EventBus.game_mode_changed.emit("build")
	panel.open()
	_check(not panel.is_open(), "en modo construir, abrirlo no lo muestra")
	EventBus.game_mode_changed.emit("live")
	_check(panel.is_open(), "pero aparece al volver a vivir")
	DevMode.set_enabled(false, character)
	_check(not panel.is_open() and not DevPanel.picking, "apagar el modo lo esconde")
	_free(panel)
	_free(character)
