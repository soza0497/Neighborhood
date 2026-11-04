extends Node
## Demostración del Pulido 3A (parcela, camino y obstáculos), con capturas.
##
##   godot --path . res://tests/polish3a_demo.tscn
## Las capturas (p3a_*.png) van a SHOT_DIR (o a user://). Partida local, sin servidor.
## NO toca tu partida: la migración se prueba con una COPIA de una partida del
## Pulido 2 armada acá mismo (nada se guarda en disco).

var _main: Node3D
var _house: HouseData
var _character: Character
var _shot_dir := ""
var _passed := 0
var _failed := 0
var _shots: Array[String] = []


func _ready() -> void:
	_shot_dir = OS.get_environment("SHOT_DIR")
	if _shot_dir == "":
		_shot_dir = OS.get_user_data_dir()
	HouseGrid.LOT_SIZE = Vector2i(96, 96)
	HouseData.blocked_cells = {}
	Economy.server_mode = false
	Economy.xp = 0
	GameState.parcel = {"seed": 424242}
	Parcel.setup_local({"seed": 424242})
	_main = preload("res://scenes/main.tscn").instantiate()
	add_child(_main)
	_house = _main.house
	_character = _main.get_node("House/Character")
	_main.get_node("House/Builder").plan_enabled = false
	_run.call_deferred()


func _run() -> void:
	await _frames(10)
	await _test_migration_copy()
	await _test_zone_and_world()
	await _test_walk_around_tree()
	print("\nDEMO PULIDO 3A: %d pasaron, %d fallaron · capturas: %s" % [_passed, _failed, ", ".join(_shots)])
	get_tree().quit(1 if _failed > 0 else 0)


func _rig() -> CameraRig:
	return _main.get_node("CameraRig")


## Una casa de 8 x 7 con puerta al frente, a `o` (celda de la esquina).
func _build_house(o: Vector2i) -> void:
	_house.from_dict({"lot_size": [96, 96], "format": 5})
	_house.floor_count = 1
	var writes: Array = []
	for c in HouseGrid.cells_in_rect(o, o + Vector2i(7, 6)):
		writes.append(HouseData.write(0, "foundation", HouseGrid.cell_key(c), {"item": "foundation_basic"}))
		writes.append(HouseData.write(0, "floors", HouseGrid.cell_key(c), {"item": "floor_basic"}))
	for edge in HouseGrid.edges_around_rect(o, o + Vector2i(7, 6)):
		writes.append(HouseData.write(0, "walls", edge, {"item": "wall_basic"}))
	writes.append(HouseData.write(0, "walls", "h:%d,%d" % [o.x + 2, o.y + 7], {"item": "wall_basic", "opening": "door_basic"}))
	writes.append(HouseData.write(0, "objects", "o2", {"item": "bed_basic", "cell": [o.x + 1, o.y + 1], "rot": 0}))
	_house.next_id = 10
	_house.apply(writes)


func _test_migration_copy() -> void:
	print("\n1) Migración de una COPIA de una partida del Pulido 2 (casa centrada en la parcela)")
	# La casa del Pulido 2 estaba en el centro (32,32); su personaje en (36,36).
	var old_save := {
		"format_version": 4,
		"state": {
			"house": {"levels": [{
				"foundation": {"34,34": {"item": "foundation_basic"}, "35,34": {"item": "foundation_basic"}},
				"floors": {"34,34": {"item": "floor_basic"}},
				"walls": {"h:34,34": {"item": "wall_basic"}},
				"objects": {"o1": {"item": "bed_basic", "cell": [35, 34], "rot": 0}}}],
				"next_id": 2, "lot_size": [96, 96], "format": 4},
			"character": {"cell": [36, 36]},
		},
	}
	var copy: Dictionary = old_save.duplicate(true)
	var migrated := SaveMigrations.migrate(copy, SaveSystem.FORMAT_VERSION)
	var house := HouseData.new()
	house.from_dict(migrated["state"]["house"])
	var street_before := 96 - 34 - 1  # celdas entre el cimiento y la calle (antes)
	var street_after := 96 - 60 - 1
	_check(house.has_piece(0, "foundation", "34,60") and house.has_piece(0, "walls", "h:34,60") and not house.has_piece(0, "foundation", "34,34"),
		"la casa se corrió 26 celdas hacia la calle")
	_check(HouseData.object_anchor(house.get_piece(0, "objects", "o1")) == Vector2i(35, 60), "el mueble quedó en el mismo lugar relativo a la casa")
	_check(house.migrated_offset == Vector2i(0, 26) and Vector2i(36, 36) + house.migrated_offset == Vector2i(36, 62), "el personaje se mueve igual que la casa")
	_check(street_after < street_before and street_after == 35, "antes había %d celdas hasta la calle; ahora %d (cerca, no pegada)" % [street_before, street_after])
	_check(old_save["state"]["house"]["format"] == 4, "la partida original (la copia sin tocar) quedó igual")


func _test_zone_and_world() -> void:
	print("\n2) Zona disponible, vallas y vecinos")
	var o := HouseGrid.home_origin() + Vector2i(8, 8)
	_build_house(o)
	_character.place_at(0, o + Vector2i(3, 3))
	_main.set_mode("live")
	_main._set_level(0)
	var world: WorldBuilder = _main.get_node("World")
	_check(Parcel.zone_bounds() == Rect2i(16, 32, 64, 64), "al principio la zona es de 64 x 64 pegada a la calle")
	var zone: Node = world.get_node_or_null("ZoneDecor")
	_check(zone != null and zone.get_node_or_null("Fences") != null and zone.get_node_or_null("SideNeighbors") != null and zone.get_node("SideNeighbors").get_child_count() == 2,
		"hay vallas de madera y una casa de vecino de cada lado")
	_check(zone.get_children().any(func(c): return c.name == "LockedShade"), "lo cerrado se ve (sombreado) pero no se puede usar")
	var free_strip := true
	for x in range(32, 64):
		for z in range(58, 96):
			if Parcel.obstacle_at(Vector2i(x, z)) != "":
				free_strip = false
	_check(free_strip, "entre la casa y la calle no hay ningún obstáculo")
	_check(_house.has_piece(0, "foundation", "%d,%d" % [o.x, o.y]) and o.y + 7 + 1 < 96 - 3, "la casa está cerca de la calle (la puerta a %d celdas)" % (96 - (o.y + 8)))
	_rig().set_state({"x": 0.0, "z": 22.0, "yaw": 35.0, "distance": 85.0, "pitch": -32.0})
	await _shot("p3a_1_parcela_vallas.png")
	_rig().set_state({"x": 0.0, "z": 28.0, "yaw": 20.0, "distance": 26.0, "pitch": -28.0})
	await _shot("p3a_2_casa_cerca_de_la_calle.png")
	# Subir de nivel abre terreno y mueve la valla.
	Economy.xp = 500
	Parcel._rebuild()
	await _frames(3)
	_check(Parcel.zone_bounds() == Rect2i(16, 0, 64, 96), "al nivel 4 se abre el terreno de atrás")
	_rig().set_state({"x": 0.0, "z": 0.0, "yaw": 0.0, "distance": 80.0, "pitch": -55.0})
	await _shot("p3a_3_terreno_ampliado.png")
	Economy.xp = 0
	Parcel._rebuild()
	await _frames(2)


func _test_walk_around_tree() -> void:
	print("\n3) El personaje esquiva un árbol")
	var o := HouseGrid.home_origin() + Vector2i(8, 8)
	_build_house(o)
	# Un árbol y un par de piedras en el pasto, delante de la puerta.
	var tree := {"id": "t:60,86", "kind": "tree", "x": 60, "z": 86, "w": 1, "d": 1}
	Parcel.obstacles.append(tree)
	Parcel.cleared.erase(tree["id"])
	HouseData.blocked_cells = Parcel.blocked_now()
	Parcel.changed.emit()
	await _frames(4)
	var from := Vector2i(58, 86)
	var to := Vector2i(62, 86)
	_character.place_at(0, from)
	_character.reset_after_build()
	var nav: HouseNav = _main.nav
	var path := nav.find_path(0, from, 0, to)
	_check(not path.is_empty(), "hay camino hasta el otro lado del árbol (%d puntos)" % path.size())
	_rig().set_state({"x": 12.5, "z": 38.5, "yaw": 0.0, "distance": 11.0, "pitch": -75.0})
	_character._go({"level": 0, "spot": to, "path": path})
	var min_distance := INF
	var shot := false
	for i in 400:
		await get_tree().process_frame
		var p := _character.position
		min_distance = minf(min_distance, Vector2(p.x, p.z).distance_to(Vector2(60.5, 86.5)))
		if not shot and absf(p.x - 60.5) < 0.6 and absf(p.z - 86.5) > 0.9:
			shot = true
			await _shot("p3a_4_esquiva_arbol.png")
		if _character.state != Character.State.WALKING:
			break
	_check(_character.cell == to, "el personaje llegó al otro lado del árbol: celda %s" % str(_character.cell))
	_check(min_distance >= 0.99, "nunca pisó la celda del árbol (se acercó a %.2f m de su centro)" % min_distance)
	# Limpiar el árbol regenera el camino.
	var around := nav.find_path(0, from, 0, to).size()
	Parcel.cleared[tree["id"]] = true
	Parcel._rebuild()
	var straight := nav.find_path(0, from, 0, to).size()
	_check(straight < around, "al limpiarlo, el camino se regenera y es más corto (%d → %d puntos)" % [around, straight])
	Parcel.obstacles.erase(tree)
	Parcel.setup_local({})


func _check(condition: bool, description: String) -> void:
	if condition:
		_passed += 1
		print("  OK     ", description)
	else:
		_failed += 1
		print("  FALLÓ  ", description)


func _shot(file_name: String) -> void:
	await _frames(4)
	get_viewport().get_texture().get_image().save_png(_shot_dir.path_join(file_name))
	_shots.append(file_name)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
