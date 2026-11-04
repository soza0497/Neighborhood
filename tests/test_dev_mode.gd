extends Node
## Pruebas automáticas del modo desarrollador (Pulido 4B): peligros, atención, accidentes
## forzados, el interruptor, que no se guarde en el servidor y que no toque el dinero.
##
## Correr desde la terminal, en la carpeta del proyecto:
##   godot --headless --path . res://tests/test_dev_mode.tscn

var _passed := 0
var _failed := 0
var _saved_settings: Dictionary = {}
var _saved_minutes := 0.0
var _ambulances := 0
var _accidents: Array = []


func _ready() -> void:
	HouseGrid.use_test_lot()
	_saved_settings = GameState.settings.duplicate(true)
	_saved_minutes = GameClock.minutes
	GameState.settings.erase(DevMode.SETTING)
	HazardMap.clear()
	EventBus.ambulance_requested.connect(func(_patient: Node3D) -> void: _ambulances += 1)
	EventBus.character_accident.connect(func(kind: String, _l: int, _c: Vector2i, _r: String) -> void: _accidents.append(kind))

	_test_data()
	_test_switch_off_does_nothing()
	_test_switch_on_and_not_saved_to_server()
	_test_attention_and_hazards()
	_test_forced_accidents()
	_test_forced_actions_and_states()
	_test_no_money()
	_test_panel_and_view()

	GameState.settings = _saved_settings
	GameClock.minutes = _saved_minutes
	HazardMap.clear()
	print("\nPRUEBAS: %d pasaron, %d fallaron" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _check(condition: bool, description: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		print("FALLÓ: ", description)


# --- Ayudas ---

## Un personaje en campo abierto (sin paredes) en la celda indicada.
func _make_character(house: HouseData, start := Vector2i(4, 10)) -> Character:
	var nav := HouseNav.new(house)
	var character := Character.new()
	add_child(character)
	character.setup(CharacterData.create_default(), house, nav, null)
	character.place_at(0, start)
	character.cell = start
	return character


## Cuarto cerrado de 3x3 (celdas 1..3) con una puerta abajo (en la celda x = 2).
func _room_with_door() -> HouseData:
	var house := HouseData.new()
	var writes: Array = []
	for c in HouseGrid.cells_in_rect(Vector2i(1, 1), Vector2i(3, 3)):
		writes.append(HouseData.write(0, "foundation", HouseGrid.cell_key(c), {"item": "foundation_basic"}))
		writes.append(HouseData.write(0, "floors", HouseGrid.cell_key(c), {"item": "floor_basic"}))
	for edge in HouseGrid.edges_around_rect(Vector2i(1, 1), Vector2i(3, 3)):
		writes.append(HouseData.write(0, "walls", edge, {"item": "wall_basic"}))
	writes.append(HouseData.write(0, "walls", "h:2,4", {"item": "wall_basic", "opening": "door_basic"}))
	house.apply(writes)
	return house


## Hace correr al personaje (como si pasara el tiempo) hasta que se cumpla algo o se acabe el tiempo.
func _run(character: Character, until: Callable, seconds := 60.0) -> void:
	var elapsed := 0.0
	while elapsed < seconds and not until.call():
		character._process(0.1)
		elapsed += 0.1


func _path_cells(path: PackedVector3Array) -> Array:
	var cells: Array = []
	for p in path:
		cells.append(Vector2i(floori(p.x), floori(p.z)))
	return cells


func _free(node: Node) -> void:
	remove_child(node)
	node.free()


# --- 1) Datos ---

func _test_data() -> void:
	print("1) Datos de peligros y atención")
	_check(HazardMap.kinds().has("wet") and HazardMap.kinds().has("hot") and HazardMap.kinds().has("drop"), "hay charco, calor y desnivel")
	_check(HazardMap.accident_for("wet") == "fall" and HazardMap.accident_for("drop") == "trip" and HazardMap.accident_for("hot") == "burn",
		"charco = caerse, desnivel = tropezar, calor = quemarse")
	_check(HazardMap.accident_info("fall")["hurt"] and HazardMap.accident_info("burn")["hurt"] and not HazardMap.accident_info("trip")["hurt"],
		"caerse y quemarse lastiman; tropezar no")
	_check(HazardMap.default_attention() == 1.0 and HazardMap.is_careful(1.0) and not HazardMap.is_careful(0.2), "atención alta cuida, baja no")
	_check(HazardMap.presets().size() >= 3 and HazardMap.preset_value("dazed") < HazardMap.careful_at(), "hay botones rápidos y son de atención baja")
	_check(HazardMap.add(0, Vector2i(3, 3), "wet") and HazardMap.kind_at(0, Vector2i(3, 3)) == "wet", "agregar un peligro")
	_check(not HazardMap.add(0, Vector2i(3, 4), "no_existe"), "un tipo que no existe se rechaza")
	_check(HazardMap.all().size() == 1 and HazardMap.all()[0]["cell"] == Vector2i(3, 3), "listar los peligros")
	_check(HazardMap.remove(0, Vector2i(3, 3)) and HazardMap.is_empty(), "quitar un peligro")
	for hook in ["fall", "trip", "burn"]:
		_check(hook in CharacterAnimator.ANIMATIONS, "gancho de animación «%s»" % hook)


# --- 2) Apagado ---

func _test_switch_off_does_nothing() -> void:
	print("2) Con el interruptor apagado no se puede ver ni usar nada")
	var house := HouseData.new()
	var character := _make_character(house)
	var minutes := GameClock.minutes
	_check(not DevMode.is_enabled(), "apagado por defecto")
	_check(not DevMode.force_accident(character, "fall")["ok"] and not character.hurt, "no fuerza accidentes")
	_check(not DevMode.force_go(character, 0, Vector2i(8, 10))["ok"], "no fuerza acciones")
	_check(not DevMode.set_attention(character, 0.0)["ok"] and character.attention == 1.0, "no cambia la atención")
	_check(not DevMode.add_hazard(0, Vector2i(5, 5), "wet")["ok"] and HazardMap.is_empty(), "no pone peligros")
	_check(not DevMode.set_need(character, "hunger", 20.0)["ok"] and character.data.needs["hunger"] == 80.0, "no cambia necesidades")
	_check(not DevMode.teleport(character, 0, Vector2i(9, 9))["ok"] and character.cell == Vector2i(4, 10), "no teletransporta")
	_check(not DevMode.set_frozen(character, true)["ok"] and not character.ai_frozen, "no congela la IA")
	_check(not DevMode.advance_to_hour(13)["ok"] and GameClock.minutes == minutes, "no cambia la hora")
	_check(DevMode.recent_log().is_empty(), "no deja registro")
	# La interfaz: nada visible y no se puede abrir.
	var panel: DevPanel = (load("res://ui/dev_panel.tscn") as PackedScene).instantiate()
	add_child(panel)
	panel.setup(character, character.nav, null)
	panel.open()
	_check(not panel.visible and not panel.is_open() and not DevPanel.picking, "el panel no se ve, no se abre y no atrapa toques")
	var view := HazardView.new()
	add_child(view)
	view.setup(character.nav)
	HazardMap.add(0, Vector2i(6, 6), "wet")  # Algún evento futuro lo registra: igual no se ve.
	_check(not view.visible, "los marcadores no se ven")
	HazardMap.clear()
	_free(view)
	_free(panel)
	_free(character)


# --- 3) Prendido y que nunca viaje al servidor ---

func _test_switch_on_and_not_saved_to_server() -> void:
	print("3) Prendido: se guarda en la partida local y NUNCA va al servidor")
	DevMode.set_enabled(true)
	_check(DevMode.is_enabled() and GameState.settings.get("dev_mode", false), "queda en GameState.settings")
	var state := GameState.to_dict()
	_check(state["settings"].get("dev_mode", false), "se guarda en la partida local")
	var reloaded := JSON.parse_string(JSON.stringify(state)) as Dictionary
	GameState.from_dict(reloaded)
	_check(DevMode.is_enabled(), "se recupera al cargar la partida")
	state = GameState.to_dict()
	state["account"] = {"user_id": "u1", "username": "x"}
	state["settings"]["show_hints"] = false
	var objects := CloudSync.cloud_objects(state)
	var uploaded := ""
	for object in objects:
		uploaded += str(object["value"])
	_check(not uploaded.contains("dev_mode"), "no se sube al servidor (storage)")
	_check(uploaded.contains("show_hints"), "las demás opciones sí se suben")
	var payload := CloudSync.import_payload(state)
	_check(not str(payload.get("settings", "")).contains("dev_mode"), "no se manda al importar la partida")
	var only_dev := {"settings": {"dev_mode": true}, "account": {"user_id": "u1"}}
	_check(CloudSync.cloud_objects(only_dev).is_empty(), "si es la única opción, no se sube nada")
	var merged := CloudSync.merge({"settings": {}, "account": {}}, {"settings": JSON.stringify({"dev_mode": true, "show_hints": false})}, "u1", "x")
	_check(not (merged["settings"] as Dictionary).has("dev_mode") and merged["settings"].get("show_hints", true) == false,
		"si la nube trajera el modo, tampoco se aplica")
	_check(CloudSync.public_settings({"dev_mode": true, "a": 1}) == {"a": 1}, "public_settings saca solo lo local")
	DevMode.set_enabled(false)
	_check(not DevMode.is_enabled() and not GameState.settings.has("dev_mode"), "apagado: ni queda la clave guardada")


# --- 4) Atención y peligros ---

func _test_attention_and_hazards() -> void:
	print("4) Atención alta rodea los peligros; baja los pisa y se cae")
	DevMode.set_enabled(true)
	var house := HouseData.new()
	var character := _make_character(house)
	DevMode.add_hazard(0, Vector2i(8, 10), "wet")
	var target := Vector2i(12, 10)

	# Camino para quien presta atención / para quien no.
	var careful := character.nav.find_path(0, character.cell, 0, target, true)
	var careless := character.nav.find_path(0, character.cell, 0, target, false)
	_check(not careful.is_empty() and not Vector2i(8, 10) in _path_cells(careful), "con atención el camino rodea el charco")
	_check(not careless.is_empty() and Vector2i(8, 10) in _path_cells(careless), "sin atención el camino pasa por el charco")

	# Atención alta: llega rodeando, sin caerse.
	DevMode.set_attention(character, 1.0)
	_accidents.clear()
	_ambulances = 0
	var result := DevMode.force_go(character, 0, target)
	_check(result["ok"], "forzar «ir hasta ahí»")
	_run(character, func() -> bool: return character.state == Character.State.IDLE and character.cell == target)
	_check(character.cell == target and not character.hurt and _accidents.is_empty(), "atención alta: llegó sin accidentes")
	_check(_ambulances == 0, "atención alta: no se llamó a la ambulancia")

	# Atención baja: pisa el charco y se cae (queda HURT y llama a la ambulancia).
	character.teleport_to(0, Vector2i(4, 10))
	DevMode.apply_attention_preset(character, "dazed")
	_check(character.attention < HazardMap.careful_at(), "el botón «desorbitado» baja la atención")
	DevMode.force_go(character, 0, target)
	_run(character, func() -> bool: return character.hurt)
	_check(character.hurt and character.state == Character.State.HURT, "atención baja: pisó el charco y quedó lastimado")
	_check(character.last_accident.get("kind", "") == "fall" and character.cell == Vector2i(8, 10), "se cayó justo en la celda del charco")
	_check(_accidents == ["fall"] and _ambulances == 1, "avisó el accidente y llamó a la ambulancia")
	_check(character.get_intention()["verb"] == "lastimado", "su intención dice «lastimado»")
	character.recover()
	_check(not character.hurt and character.state == Character.State.IDLE, "la ambulancia lo cura")

	# Desnivel = tropezar (sin ambulancia); calor = quemarse.
	HazardMap.clear()
	DevMode.add_hazard(0, Vector2i(6, 10), "drop")
	character.teleport_to(0, Vector2i(4, 10))
	_accidents.clear()
	_ambulances = 0
	DevMode.set_attention(character, 0.2)
	DevMode.force_go(character, 0, target)
	_run(character, func() -> bool: return not _accidents.is_empty())
	_check(_accidents == ["trip"] and not character.hurt and _ambulances == 0 and character.state == Character.State.IDLE,
		"un desnivel hace tropezar (sin ambulancia)")
	HazardMap.clear()
	DevMode.add_hazard(0, Vector2i(6, 10), "hot")
	character.teleport_to(0, Vector2i(4, 10))
	_accidents.clear()
	DevMode.force_go(character, 0, target)
	_run(character, func() -> bool: return character.hurt)
	_check(_accidents == ["burn"] and character.hurt, "lo caliente quema (HURT + ambulancia)")
	character.recover()

	# Atención alta sin otro camino: cruza con cuidado, sin caerse.
	HazardMap.clear()
	_free(character)
	var room := _room_with_door()
	character = _make_character(room, Vector2i(6, 6))
	DevMode.set_enabled(true)
	DevMode.add_hazard(0, Vector2i(2, 4), "wet")  # La única entrada pasa por ahí.
	DevMode.set_attention(character, 1.0)
	_accidents.clear()
	_check(DevMode.force_go(character, 0, Vector2i(2, 2))["ok"], "hay camino al cuarto por la puerta")
	_run(character, func() -> bool: return character.cell == Vector2i(2, 2))
	_check(character.cell == Vector2i(2, 2) and _accidents.is_empty(), "sin otro camino, con atención cruza con cuidado")
	character.teleport_to(0, Vector2i(6, 6))
	DevMode.set_attention(character, 0.1)
	DevMode.force_go(character, 0, Vector2i(2, 2))
	_run(character, func() -> bool: return character.hurt)
	_check(character.hurt and character.last_accident["cell"] == Vector2i(2, 4), "distraído se cae en el umbral de la puerta")
	# Teletransportarse a un peligro sin atención también lo hace caer.
	character.recover()
	_accidents.clear()
	_check(DevMode.teleport(character, 0, Vector2i(2, 4))["ok"] and character.hurt, "teletransportarse sobre un charco sin atención: se cae")
	HazardMap.clear()
	DevMode.set_enabled(false, character)
	_check(character.attention == 1.0 and HazardMap.is_empty(), "al apagar el modo todo vuelve a lo normal")
	_free(character)


# --- 5) Accidentes forzados ---

func _test_forced_accidents() -> void:
	print("5) Accidentes forzados: caerse, tropezar, quemarse")
	DevMode.set_enabled(true)
	var character := _make_character(HouseData.new())
	var energy: float = character.data.needs["energy"]
	_ambulances = 0
	_check(DevMode.force_accident(character, "fall")["ok"] and character.hurt and character.state == Character.State.HURT, "caerse: queda HURT")
	_check(_ambulances == 1, "caerse llama a la ambulancia")
	_check(character.data.needs["energy"] < energy, "baja un poco la energía")
	_check(not DevMode.force_accident(character, "burn")["ok"], "lastimado no se vuelve a lastimar")
	character.recover()
	_check(DevMode.force_accident(character, "burn")["ok"] and character.hurt and _ambulances == 2, "quemarse: HURT y ambulancia")
	character.recover()
	_ambulances = 0
	_check(DevMode.force_accident(character, "trip")["ok"] and not character.hurt and _ambulances == 0, "tropezar: sin ambulancia")
	_check(character.state == Character.State.IDLE and character._animator.current == "trip", "tropezar usa el gancho de animación «trip»")
	_check(not DevMode.force_accident(character, "no_existe")["ok"], "un accidente desconocido se rechaza")
	_check(character.force_accident("fall") and character.hurt, "el gancho del personaje funciona directo")
	character.recover()
	var log_text := "\n".join(DevMode.recent_log())
	_check(log_text.contains("caerse") and log_text.contains("quemarse") and log_text.contains("tropezar"), "el registro anota lo forzado")
	_check(DevMode.recent_log().size() <= DevMode.LOG_MAX, "el registro es corto")
	DevMode.set_enabled(false, character)
	_free(character)


# --- 6) Acciones, estados, congelar IA, hora ---

func _test_forced_actions_and_states() -> void:
	print("6) Forzar acciones y poner estados")
	DevMode.set_enabled(true)
	var house := _room_with_door()
	house.apply([HouseData.write(0, "objects", "o1", {"item": "bed_basic", "cell": [1, 1], "rot": 0})])
	var character := _make_character(house, Vector2i(6, 6))
	var result := DevMode.force_use(character, 0, "o1", "sleep")
	_check(result["ok"], "forzar «usarlo» (dormir en la cama)")
	_run(character, func() -> bool: return character.state == Character.State.ACTING)
	_check(character.state == Character.State.ACTING and character.get_intention()["action"] == "sleep", "llegó y está durmiendo")
	_check(character.last_reason.contains("forzado"), "el motivo queda registrado: %s" % character.last_reason)
	_check(not DevMode.force_use(character, 0, "o1", "cook")["ok"], "una acción que el objeto no ofrece se rechaza")

	# Necesidades (respetan el mínimo del juego).
	_check(DevMode.set_need(character, "hunger", 30.0)["ok"] and character.data.needs["hunger"] == 30.0, "poner comida")
	DevMode.set_need(character, "energy", 5.0)
	_check(character.data.needs["energy"] == CharacterData.NEED_FLOOR, "no baja del mínimo del juego")
	DevMode.set_need(character, "fun", 500.0)
	_check(character.data.needs["fun"] == 100.0, "no pasa de 100")
	DevMode.set_need(character, "hygiene", 55.0)
	_check(character.data.needs["hygiene"] == 55.0, "poner limpieza")
	_check(not DevMode.set_need(character, "money", 5.0)["ok"], "no hay «necesidad» de dinero")

	# Teletransportar y congelar la IA.
	_check(DevMode.teleport(character, 0, Vector2i(9, 9))["ok"] and character.cell == Vector2i(9, 9) and character.state == Character.State.IDLE,
		"teletransportar")
	_check(not DevMode.teleport(character, 0, Vector2i(1, 1))["ok"], "no se teletransporta sobre un mueble")
	DevMode.set_frozen(character, true)
	var before := character.cell
	_run(character, func() -> bool: return false, 30.0)
	_check(character.state == Character.State.IDLE and character.cell == before, "IA congelada: se queda quieto")
	_check(DevMode.force_go(character, 0, Vector2i(12, 9))["ok"], "congelado igual cumple lo que se fuerza")
	_run(character, func() -> bool: return character.cell == Vector2i(12, 9))
	_check(character.cell == Vector2i(12, 9), "llegó adonde se le mandó")
	DevMode.set_frozen(character, false)
	_run(character, func() -> bool: return character.state != Character.State.IDLE, 120.0)
	_check(character.state != Character.State.IDLE, "IA reanudada: vuelve a decidir solo")

	# Hora: siempre hacia adelante.
	GameClock.minutes = 8.0 * 60.0
	DevMode.advance_to_hour(13)
	_check(GameClock.time_text() == "13:00" and GameClock.day() == 1, "hora: de 8:00 a 13:00 el mismo día")
	DevMode.advance_to_hour(9)
	_check(GameClock.time_text() == "09:00" and GameClock.day() == 2, "hora: 9:00 ya pasó, va al día siguiente")
	DevMode.set_enabled(false, character)
	_free(character)


# --- 7) Nada de dinero ---

func _test_no_money() -> void:
	print("7) El modo desarrollador no toca el dinero, la experiencia ni la propiedad")
	DevMode.set_enabled(true)
	var money := Economy.money
	var xp := Economy.xp
	var level := Economy.level()
	var house := HouseData.new()
	var house_before := JSON.stringify(house.to_dict())
	var character := _make_character(house)
	DevMode.force_accident(character, "fall")
	character.recover()
	DevMode.set_attention(character, 0.0)
	DevMode.add_hazard(0, Vector2i(7, 7), "wet")
	DevMode.set_need(character, "fun", 50.0)
	DevMode.teleport(character, 0, Vector2i(5, 5))
	DevMode.advance_to_hour(18)
	DevMode.clear_hazards()
	_check(Economy.money == money and Economy.xp == xp and Economy.level() == level, "dinero, experiencia y nivel intactos")
	_check(JSON.stringify(house.to_dict()) == house_before, "la casa (propiedad) intacta")
	# El código del modo no menciona la economía (ignorando comentarios).
	for path in ["res://scripts/debug/dev_mode.gd", "res://scripts/debug/hazard_map.gd", "res://ui/dev_panel.gd"]:
		var code_lines := FileAccess.get_file_as_string(path).split("\n")
		var mentions := 0
		for line in code_lines:
			var text: String = line.strip_edges()
			if not text.begins_with("#") and (text.contains("Economy") or text.contains("GameServer") or text.contains("money")):
				mentions += 1
		_check(mentions == 0, "%s no toca Economy ni el servidor" % path.get_file())
	DevMode.set_enabled(false, character)
	_free(character)


# --- 8) Panel y marcadores ---

func _test_panel_and_view() -> void:
	print("8) Panel y marcadores")
	DevMode.set_enabled(true)
	var house := _room_with_door()
	house.apply([HouseData.write(0, "objects", "o1", {"item": "bed_basic", "cell": [1, 1], "rot": 0})])
	var character := _make_character(house, Vector2i(6, 6))
	var panel: DevPanel = (load("res://ui/dev_panel.tscn") as PackedScene).instantiate()
	add_child(panel)
	panel.setup(character, character.nav, null)
	_check(panel.visible and not panel.is_open(), "prendido: el panel está listo pero cerrado")
	panel.open()
	_check(panel.is_open() and DevPanel.picking, "abierto: los toques en el mundo son para el panel")
	panel.show_target({"kind": "object", "level": 0, "key": "o1", "item": "bed_basic", "item_kind": "furniture", "name": "Cama", "cell": Vector2i(2, 1)})
	var buttons: Array = panel._target_box.find_children("*", "Button", true, false)
	var texts: Array = buttons.map(func(b: Button) -> String: return b.text)
	_check(texts.has("Ir hasta ahí") and texts.any(func(t: String) -> bool: return t.begins_with("Usarlo")), "un mueble ofrece ir y usarlo")
	_check(texts.has("Caerse") and texts.has("Tropezar") and texts.has("Quemarse"), "y los tres accidentes")
	panel.show_target({"kind": "floor", "level": 0, "cell": Vector2i(9, 9), "name": "Suelo", "hazard": ""})
	buttons = panel._target_box.find_children("*", "Button", true, false)
	texts = buttons.map(func(b: Button) -> String: return b.text)
	_check(texts.any(func(t: String) -> bool: return t.begins_with("Poner «charco»")) and texts.has("Teletransportar acá"), "el suelo ofrece peligros y teletransportar")
	panel._hazard_kind = "wet"
	panel.apply_hazard_tap({"kind": "floor", "level": 0, "cell": Vector2i(9, 9)})
	_check(HazardMap.kind_at(0, Vector2i(9, 9)) == "wet", "tocar el suelo pone el peligro")
	panel.apply_hazard_tap({"kind": "floor", "level": 0, "cell": Vector2i(9, 9)})
	_check(HazardMap.kind_at(0, Vector2i(9, 9)) == "", "tocarlo otra vez lo quita")
	_check(panel._need_sliders.size() == 4 and not panel._need_sliders.has("money"), "estados: solo las 4 necesidades")

	# Marcadores.
	var view := HazardView.new()
	add_child(view)
	view.setup(character.nav)
	HazardMap.add(0, Vector2i(5, 5), "wet")
	HazardMap.add(0, Vector2i(6, 5), "hot")
	var markers := view.get_children().filter(func(n: Node) -> bool: return not n.is_queued_for_deletion())
	_check(view.visible and markers.size() == 2, "dos marcadores chatos (%d)" % markers.size())
	_check(markers[0].mesh.size.y < 0.1, "son chatos")

	# Cerrar y apagar.
	panel.close()
	_check(not panel.is_open() and not DevPanel.picking, "cerrado: ya no atrapa toques")
	panel.open()
	DevMode.set_enabled(false, character)
	_check(not panel.visible and not panel.is_open() and not DevPanel.picking, "apagar el modo esconde el panel")
	_check(HazardMap.is_empty() and not view.visible, "y quita peligros y marcadores")
	_free(view)
	_free(panel)
	_free(character)
