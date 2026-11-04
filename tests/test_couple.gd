extends Node
## Pruebas automáticas de la Fase 5 (pareja y casa compartida), SIN red:
## cómo se lee lo que manda el servidor, el estado que va por el socket,
## ponerse al día con la casa, los permisos (los mismos casos que las
## pruebas en Lua), la presencia, el personaje de la pareja y la caja.
##
##   godot --headless --path . res://tests/test_couple.tscn
##
## La prueba contra el servidor de verdad (dos cuentas a la vez) es
## tests/couple_demo.tscn, y con ventana tests/couple_live_demo.tscn.

var _passed := 0
var _failed := 0


func _ready() -> void:
	HouseGrid.use_test_lot()  # Estas pruebas arman casas en un lote de 32 (la parcela real, desde el Pulido 2C, es de 96).
	_test_normalize()
	_test_texts()
	_test_status()
	_test_diff()
	_test_permissions()
	_test_socket()
	_test_partner_character()
	_test_fund()
	print("\nPRUEBAS: %d pasaron, %d fallaron" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _check(condition: bool, description: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		print("FALLÓ: ", description)


func _test_normalize() -> void:
	# El servidor (Lua) manda las listas vacías como {}.
	var couple := CoupleState.normalize_couple({"status": "dating", "partner_name": "sofia", "invites_in": {}, "events": {}})
	_check(couple["invites_in"] is Array and couple["invites_in"].is_empty() and couple["events"].is_empty(),
		"listas vacías del servidor ({}) quedan como listas")
	_check(couple["family_mode"] and not couple["drama"], "por defecto: modo familiar prendido, drama apagado")
	_check(CoupleState.in_couple(couple) and not CoupleState.in_couple(CoupleState.normalize_couple(null)), "¿en pareja?")
	var home := CoupleState.normalize_home({"rev": 7.0, "fund": 250.0, "requests": [{"id": 3.0, "text": "poner Pared",
		"by_me": false, "cost": 40.0}], "log": {}})
	_check(home["rev"] == 7 and home["fund"] == 250 and home["requests"][0]["id"] == 3 and home["log"].is_empty(),
		"el hogar: números enteros y listas")
	var partner := CoupleState.normalize_partner({"user_id": "u2", "username": "sofia",
		"character": JSON.stringify({"data": {"name": "Sofi"}, "cell": [3, 4]})})
	_check(partner["character"]["data"]["name"] == "Sofi", "el personaje de la pareja llega como texto y se lee")
	_check(CoupleState.normalize_partner({}).is_empty(), "sin pareja: {}")


func _test_texts() -> void:
	var single := CoupleState.normalize_couple({})
	_check(CoupleState.status_text(single) == "Sin pareja.", "texto: sin pareja")
	single["invite_to_name"] = "beto"
	_check(CoupleState.status_text(single).contains("beto"), "texto: invitación esperando")
	var married := CoupleState.normalize_couple({"status": "married", "partner_name": "sofia", "shared": true})
	_check(CoupleState.status_text(married) == "Matrimonio con sofia · viven juntos.", "texto: matrimonio y viven juntos")
	var proposal := CoupleState.normalize_couple({"status": "dating", "partner_name": "sofia", "proposal_kind": "move_in",
		"proposal_by_me": false, "proposal_home_is_mine": true})
	_check(CoupleState.proposal_text(proposal) == "sofia quiere mudarse a tu casa.", "texto: pedido de mudarse")
	proposal["proposal_kind"] = "marry"
	proposal["proposal_by_me"] = true
	_check(CoupleState.proposal_text(proposal).begins_with("Le pediste casamiento"), "texto: casamiento pedido por mí")


func _test_status() -> void:
	var intention := {"character": "Alex", "state": "acting", "action": "cook", "verb": "cocinando", "object": "Cocina",
		"key": "o5", "object_level": 1, "level": 1, "since": 1800000000}
	var text := CoupleState.encode_status(intention)
	var back := CoupleState.decode_status(text)
	_check(back["action"] == "cook" and back["key"] == "o5" and back["object_level"] == 1 and back["since"] == 1800000000,
		"la intención va y vuelve por el socket")
	_check(text.length() <= CoupleState.MAX_STATUS_LENGTH, "el estado es corto (%d letras)" % text.length())
	_check(CoupleState.decode_status("").is_empty() and CoupleState.decode_status("hola").is_empty()
		and CoupleState.decode_status("{\"v\": 99}").is_empty(), "estados vacíos o de otra versión: {}")
	intention["verb"] = "x".repeat(600)
	_check(CoupleState.encode_status(intention).length() <= CoupleState.MAX_STATUS_LENGTH, "un estado enorme se recorta")
	_check(Character.intention_text({"character": "A", "verb": "paseando", "object": "", "since": 0}) == "A: paseando",
		"sin hora conocida no dice \"desde las 00:00\"")


func _test_diff() -> void:
	var local := HouseData.new()
	local.apply([HouseData.write(0, "foundation", "1,1", {"item": "foundation_basic"}),
		HouseData.write(0, "objects", "o1", {"item": "sofa_basic", "cell": [2, 2], "rot": 0}),
		HouseData.write(0, "objects", "o2", {"item": "chair_basic", "cell": [4, 4], "rot": 0})])
	# Lo que manda el servidor: los números como decimales (JSON).
	var server: Dictionary = JSON.parse_string(JSON.stringify(local.to_dict()))
	_check(CoupleState.diff_writes(local.to_dict(), server).is_empty(), "casa igual (con decimales): nada que cambiar")
	server["levels"][3]["objects"]["o1"]["cell"] = [5.0, 5.0]
	server["levels"][3]["objects"].erase("o2")
	server["levels"][3]["walls"]["h:1,1"] = {"item": "wall_basic"}
	var writes := CoupleState.diff_writes(local.to_dict(), server)
	_check(writes.size() == 3, "tres cambios: mover, quitar y poner (%d)" % writes.size())
	local.apply(writes)
	_check(CoupleState.diff_writes(local.to_dict(), server).is_empty() and HouseData.object_anchor(local.get_piece(0, "objects", "o1")) == Vector2i(5, 5)
		and not local.has_piece(0, "objects", "o2") and local.has_piece(0, "walls", "h:1,1"), "después de aplicar, iguales")
	_check(CoupleState.diff_writes(local.to_dict(), {}).size() == 3, "servidor sin casa: se quita todo")


func _test_permissions() -> void:
	# Los mismos casos que server/tests/test_rules.lua ("permisos").
	var h := HouseData.new()
	h.apply([HouseData.write(0, "walls", "h:1,0", {"item": "wall_basic"}),
		HouseData.write(0, "objects", "o1", {"item": "sofa_basic", "cell": [2, 2], "rot": 0}),
		HouseData.write(0, "objects", "o2", {"item": "stairs_basic", "cell": [4, 0], "rot": 0}),
		HouseData.write(0, "floors", "1,1", {"item": "floor_basic"})])
	var minor := func(writes: Array) -> bool: return HousePermissions.is_minor(h, writes)
	_check(minor.call([HouseData.write(0, "objects", "o1", {"item": "sofa_basic", "cell": [3, 3], "rot": 0})]), "mover un mueble: menor")
	_check(minor.call([HouseData.write(0, "objects", "o1", {"item": "sofa_basic", "cell": [2.0, 2.0], "rot": 1})]), "girar (con decimales): menor")
	_check(minor.call([HouseData.write(0, "walls", "h:1,0", {"item": "wall_basic", "color": "#00ff00"})]), "pintar una pared: menor")
	_check(minor.call([HouseData.write(0, "floors", "1,1", {"item": "floor_basic", "color": "#00ff00"})]), "pintar el piso: menor")
	_check(minor.call([HouseData.write(0, "objects", "o9", {"item": "chair_basic", "cell": [0, 0], "rot": 0})]), "mueble nuevo: menor")
	_check(not minor.call([HouseData.write(0, "objects", "o1", null)]), "vender un mueble: estructural")
	_check(not minor.call([HouseData.write(0, "walls", "h:2,0", {"item": "wall_basic"})]), "pared nueva: estructural")
	_check(not minor.call([HouseData.write(0, "walls", "h:1,0", {"item": "wall_basic", "opening": "door_basic"})]), "puerta: estructural")
	_check(not minor.call([HouseData.write(0, "floors", "6,6", {"item": "floor_basic"})]), "piso nuevo: estructural")
	_check(not minor.call([HouseData.write(0, "objects", "o2", {"item": "stairs_basic", "cell": [4, 1], "rot": 0})]), "mover la escalera: estructural")
	_check(not minor.call([HouseData.write(0, "objects", "o1", {"item": "sofa_basic", "cell": [3, 3], "rot": 0}),
		HouseData.write(0, "walls", "h:2,0", {"item": "wall_basic"})]), "un cambio con algo estructural: todo estructural")


func _test_socket() -> void:
	var socket := RealtimeSocket.new()
	add_child(socket)
	var notes: Array = []
	var presences: Array = []
	socket.notification_received.connect(func(code: int, _s: String, content: Dictionary) -> void: notes.append([code, content]))
	socket.presence_changed.connect(func(id: String, online: bool, status: String) -> void: presences.append([id, online, status]))
	socket.follow(["u2"])
	socket.handle_envelope({"notifications": {"notifications": [{"code": 103, "subject": "x",
		"content": "{\"rev\": 4, \"text\": \"movió: Sofá\"}"}]}})
	_check(notes.size() == 1 and notes[0][0] == 103 and int(notes[0][1]["rev"]) == 4, "aviso del servidor: código y contenido")
	socket.handle_envelope({"status": {"presences": [{"user_id": "u2", "session_id": "s1", "status": "a"},
		{"user_id": "otro", "session_id": "s9", "status": "z"}]}})
	_check(presences == [["u2", true, "a"]] and socket.is_online("u2"), "presencia: solo de quien sigo")
	presences.clear()
	socket.handle_envelope({"status_presence_event": {"leaves": [{"user_id": "u2", "session_id": "s1", "status": "a"}],
		"joins": [{"user_id": "u2", "session_id": "s1", "status": "b"}]}})
	_check(presences == [["u2", true, "b"]], "cambiar de estado no parece desconectarse")
	socket.handle_envelope({"status_presence_event": {"joins": [{"user_id": "u2", "session_id": "s2", "status": "c"}]}})
	socket.handle_envelope({"status_presence_event": {"leaves": [{"user_id": "u2", "session_id": "s1"}]}})
	_check(socket.is_online("u2") and presences.back() == ["u2", true, "c"], "con dos teléfonos, si se va uno sigue en línea")
	socket.handle_envelope({"status_presence_event": {"leaves": [{"user_id": "u2", "session_id": "s2"}]}})
	_check(not socket.is_online("u2") and presences.back() == ["u2", false, ""], "se fue del todo: fuera de línea")
	socket.follow([])
	_check(socket._following.is_empty(), "dejar de seguir")
	socket.queue_free()


func _test_partner_character() -> void:
	var house := HouseData.new()
	var writes: Array = []
	for x in range(0, 6):
		for z in range(0, 6):
			writes.append(HouseData.write(0, "foundation", "%d,%d" % [x, z], {"item": "foundation_basic"}))
			writes.append(HouseData.write(0, "floors", "%d,%d" % [x, z], {"item": "floor_basic"}))
	writes.append(HouseData.write(0, "objects", "o1", {"item": "stove_basic", "cell": [4, 1], "rot": 0}))
	writes.append(HouseData.write(0, "objects", "o2", {"item": "fridge_basic", "cell": [1, 1], "rot": 0}))
	house.apply(writes)
	var nav := HouseNav.new(house)
	var intentions: Array = []
	var listener := func(intention: Dictionary) -> void: intentions.append(intention)
	EventBus.character_intention_changed.connect(listener)

	var partner := Character.new()
	partner.is_partner = true
	add_child(partner)
	partner.cell = Vector2i(2, 4)
	partner.setup(CharacterData.create_default(), house, nav, null)
	partner.follow_intention(true, {"state": "acting", "action": "cook", "key": "o1", "object_level": 0})
	_check(partner.remote_driven and partner.state == Character.State.WALKING and partner.using(0, "o1"),
		"en línea: va al mueble que dice su intención")
	_check(intentions.is_empty(), "el personaje de la pareja no avisa a MI interfaz")
	partner.follow_intention(true, {"state": "working", "action": "", "key": ""})
	_check(partner.state == Character.State.WORKING, "si trabaja, se va de la casa")
	partner.follow_intention(true, {"state": "idle", "action": "", "key": ""})
	# Pulido 2B: vuelve de la calle caminando (con saco y maleta) hasta la casa.
	_check(partner.cell == Character.work_cell() and (partner._returning or partner.state == Character.State.IDLE),
		"vuelve del trabajo por la acera (caminando hasta la puerta, o ya en casa si no hay puerta)")
	partner._arrive_home()
	partner.follow_intention(true, {"state": "acting", "action": "cook", "key": "o99"})
	_check(partner.state == Character.State.IDLE, "un mueble que no está en mi casa: pasea")
	partner.follow_intention(false, {})
	_check(not partner.remote_driven, "fuera de línea: vive con su propia IA")

	# El mío no elige lo que está usando la pareja.
	var mine := Character.new()
	add_child(mine)
	mine.cell = Vector2i(3, 3)
	mine.setup(CharacterData.create_default(), house, nav, null)
	partner.follow_intention(true, {"state": "acting", "action": "cook", "key": "o1", "object_level": 0})
	mine.companion = partner
	var keys: Array = mine._gather_options().map(func(o: Dictionary) -> String: return o["key"])
	_check(not "o1" in keys and "o2" in keys, "mi personaje no elige la cocina que usa la pareja")
	EventBus.character_intention_changed.disconnect(listener)
	partner.queue_free()
	mine.queue_free()


func _test_fund() -> void:
	Economy.money = 100
	Economy.fund = 500
	Economy.shared = false
	_check(not Economy.can_change(-300), "sin casa compartida, la caja no cuenta")
	Economy.shared = true
	_check(Economy.can_change(-550) and not Economy.can_change(-650), "en la casa compartida: caja + billetera")
	Economy.shared = false
	Economy.fund = 0
	Economy.money = SaveMigrations.STARTING_MONEY
