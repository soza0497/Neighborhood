extends Node
## Demostración del personaje: arma una casa amueblada, le da hambre y sueño,
## y deja que la IA decida. Imprime lo que hace y saca capturas.
##
##   godot --path . res://tests/character_demo.tscn
## Capturas en SHOT_DIR (o user://). OJO: pisa la partida guardada.

var _main: Node3D
var _shot_dir := ""
var _log: Array[String] = []


func _ready() -> void:
	_shot_dir = OS.get_environment("SHOT_DIR")
	if _shot_dir == "":
		_shot_dir = OS.get_user_data_dir()
	_main = preload("res://scenes/main.tscn").instantiate()
	add_child(_main)
	EventBus.character_intention_changed.connect(_on_intention)
	_run.call_deferred()


func _run() -> void:
	_build_house()
	var data: CharacterData = _main.character_data
	data.needs = {"hunger": 15.0, "energy": 30.0, "hygiene": 70.0, "fun": 60.0}
	_main.get_node("House/Character").place_at(0, Vector2i(16, 21))
	_main.set_mode("build")
	_main.set_mode("live")
	EventBus.camera_reset_requested.emit()
	_main._set_view_mode(HouseView.ViewMode.CUTAWAY)
	GameClock.speed = 10

	# Esperar a que llegue y empiece a comer.
	for i in 40:
		await get_tree().create_timer(0.25).timeout
		if _main.get_node("House/Character").state == Character.State.ACTING:
			break
	await _frames(10)
	await _shot("c1_comiendo.png")

	# Seguir viviendo un rato (unas horas del juego).
	await get_tree().create_timer(6.0).timeout
	await _shot("c2_despues.png")

	# Orden del jugador: ver tele.
	var tv_key := _find_object("tv_basic")
	EventBus.object_menu_requested.emit(0, tv_key, "tv_basic")
	await _shot("c3_menu.png")
	EventBus.character_order_requested.emit(0, tv_key, "watch_tv")
	_main.get_node("HUD/Root/ActionMenu").hide()
	await get_tree().create_timer(3.0).timeout
	var intention: Dictionary = _main.get_node("House/Character").get_intention()
	print("Orden 'ver tele' -> %s" % ("OK" if intention["action"] == "watch_tv" else "FALLÓ (" + intention["verb"] + ")"))

	# Menú oculto, diario y editor de personaje.
	_main.get_node("HUD/Root/SideMenu").show()
	await _shot("c5_menu.png")
	_main.get_node("HUD/Root/SideMenu").hide()
	EventBus.journal_requested.emit()
	await _shot("c6_diario.png")
	_main.get_node("HUD/DiaryPanel").hide()
	EventBus.character_editor_requested.emit()
	await _shot("c4_editor.png")

	print("\n".join(_log))
	print("Necesidades al final: ", data.needs)
	get_tree().quit()


## Casa de un cuarto grande con puerta al frente y muebles.
func _build_house() -> void:
	var house: HouseData = _main.house
	house.clear()
	var writes: Array = []
	var o := Vector2i(10, 10)  # Cerca del centro de la parcela.
	for c in HouseGrid.cells_in_rect(Vector2i(2, 2) + o, Vector2i(9, 8) + o):
		writes.append(HouseData.write(0, "foundation", HouseGrid.cell_key(c), {"item": "foundation_basic"}))
		writes.append(HouseData.write(0, "floors", HouseGrid.cell_key(c), {"item": "floor_basic"}))
	for edge in HouseGrid.edges_around_rect(Vector2i(2, 2) + o, Vector2i(9, 8) + o):
		writes.append(HouseData.write(0, "walls", edge, {"item": "wall_basic"}))
	writes.append(HouseData.write(0, "walls", HouseGrid.edge_key(Vector2i(5, 9) + o, true),
		{"item": "wall_basic", "opening": "door_basic"}))
	var furniture := [
		["fridge_basic", 2, 2, 0], ["stove_basic", 3, 2, 0], ["bed_basic", 9, 2, 0],
		["sofa_basic", 5, 6, 2], ["tv_basic", 5, 4, 0], ["shower_basic", 2, 8, 0],
		["bookshelf_basic", 8, 8, 2], ["computer_basic", 9, 6, 1],
	]
	for f in furniture:
		writes.append(HouseData.write(0, "objects", house.new_id(), {"item": f[0], "cell": [f[1] + o.x, f[2] + o.y], "rot": f[3]}))
	house.apply(writes)


func _find_object(item_id: String) -> String:
	var objects: Dictionary = _main.house.get_layer(0, "objects")
	for key in objects:
		if objects[key]["item"] == item_id:
			return key
	return ""


func _on_intention(intention: Dictionary) -> void:
	_log.append("[%s] %s" % [GameClock.time_text(), Character.intention_text(intention)])


func _shot(file_name: String) -> void:
	await _frames(4)
	get_viewport().get_texture().get_image().save_png(_shot_dir.path_join(file_name))


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
