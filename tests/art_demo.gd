extends Node
## Demostración de la Fase 7 (preparación de arte), con capturas.
##
##   godot --path . res://tests/art_demo.tscn
## (en la nube: xvfb-run -a godot --path . res://tests/art_demo.tscn con SHOT_DIR=docs/capturas)
##
## Un cuarto con los .glb de ejemplo (silla, mesa y un peinado) y las mismas
## piezas con los respaldos (figuras simples), más el recoloreo desde la paleta.
## Capturas art_*.png → SHOT_DIR (o user://).

const O := Vector2i(40, 66)
const SIZE := Vector2i(7, 5)

var _main: Node3D
var _house: HouseData
var _view: HouseView
var _shot_dir := ""
var _passed := 0
var _failed := 0
var _shots: Array[String] = []
var _bodies: Array[Node3D] = []


func _ready() -> void:
	_shot_dir = OS.get_environment("SHOT_DIR")
	if _shot_dir == "":
		_shot_dir = OS.get_user_data_dir()
	HouseGrid.LOT_SIZE = Vector2i(96, 96)
	HouseData.blocked_cells = {}
	Economy.server_mode = false
	Parcel.setup_local({"seed": 424242})
	ModelLoader.clear_cache()
	ModelLoader.enabled = true
	_main = preload("res://scenes/main.tscn").instantiate()
	add_child(_main)
	Economy.debug_unlock_all()
	_house = _main.house
	_view = _main.get_node("House")
	_run.call_deferred()


func _run() -> void:
	_build_room()
	_main.set_mode("live")
	_main._set_level(0)
	_main.get_node("HUD").visible = false
	var center := Vector3(O.x + SIZE.x / 2.0 - 48.0, 0, O.y + SIZE.y / 2.0 - 48.0)
	var rig: CameraRig = _main.get_node("CameraRig")
	rig.set_state({"x": center.x, "z": center.z + 0.5, "yaw": 0.0, "distance": 10.0, "pitch": -38.0})
	# Peinado con modelo para el personaje de la demo.
	var hairstyles: Array = Catalog.character_options["hairstyles"]
	var first_style: Dictionary = hairstyles[0]
	first_style["model"] = "res://assets/models/character/hair_round.glb"
	await _frames(8)

	print("\n1) Con modelos (silla, mesa y pelo en .glb)")
	_place_bodies(str(first_style["id"]))
	await _frames(4)
	var with_models := _model_count()
	_check(with_models >= 5, "hay modelos en el cuarto (%d)" % with_models)
	_check(_bodies[0].get_meta("model_slots").has("hair"), "el personaje usa el peinado .glb")
	await _shot("art_1_con_modelos.png")

	print("\n2) Interruptor apagado: respaldos (figuras simples)")
	ModelLoader.set_enabled(false)  # avisa a la casa, que se arma otra vez
	_place_bodies(str(first_style["id"]))
	await _frames(6)
	_check(_model_count() == 0, "ningún modelo: todo son figuras simples")
	_check(_bodies[0].get_meta("model_slots").is_empty(), "el personaje vuelve al pelo simple")
	await _shot("art_2_respaldos.png")

	print("\n3) Recoloreo desde la paleta")
	ModelLoader.set_enabled(true)
	var old_wood: String = Style.materials["wood"]
	var old_cloth: String = Style.materials["cloth_red"]
	var old_hair: String = Style.materials["hair"]
	Style.materials["wood"] = "#4f86c6"
	Style.materials["wood_light"] = "#9cc3ee"
	Style.materials["cloth_red"] = "#58b85a"
	_view.rebuild_all()
	_place_bodies(str(first_style["id"]))
	await _frames(6)
	_check(_model_count() >= 5, "los modelos siguen")
	await _shot("art_3_recoloreo.png")
	Style.materials["wood"] = old_wood
	Style.materials["cloth_red"] = old_cloth
	Style.materials["hair"] = old_hair
	Style.reload()

	first_style.erase("model")
	ModelLoader.clear_cache()
	print("\nDEMO FASE 7: %d pasaron, %d fallaron · capturas: %s" % [_passed, _failed, ", ".join(_shots)])
	get_tree().quit(1 if _failed > 0 else 0)


func _build_room() -> void:
	_house.from_dict({"lot_size": [96, 96], "format": 5})
	_house.floor_count = 1
	var end := O + SIZE
	var writes: Array = []
	for c in HouseGrid.cells_in_rect(O, end):
		writes.append(HouseData.write(0, "foundation", HouseGrid.cell_key(c), {"item": "foundation_basic"}))
		writes.append(HouseData.write(0, "floors", HouseGrid.cell_key(c), {"item": "floor_basic"}))
	for edge in HouseGrid.edges_around_rect(O, end):
		writes.append(HouseData.write(0, "walls", edge, {"item": "wall_basic"}))
	# Mesa de 2 x 1 con cuatro sillas, un sofá y una cama (estos dos no tienen modelo: siempre simples).
	var furniture := [
		["table_basic", O.x + 2, O.y + 2, 0], ["chair_basic", O.x + 2, O.y + 1, 0], ["chair_basic", O.x + 3, O.y + 1, 0],
		["chair_basic", O.x + 2, O.y + 3, 2], ["chair_basic", O.x + 3, O.y + 3, 2],
		["sofa_basic", O.x + 5, O.y + 0, 0], ["bed_basic", O.x + 0, O.y + 0, 0]]
	var next := 1
	for entry in furniture:
		writes.append(HouseData.write(0, "objects", "o%d" % next, {"item": entry[0], "cell": [entry[1], entry[2]], "rot": entry[3]}))
		next += 1
	_house.next_id = 100
	_house.apply(writes)


## Dos personajes: uno con el peinado del catálogo y uno de la misma apariencia.
func _place_bodies(style_id: String) -> void:
	for body in _bodies:
		body.queue_free()
	_bodies.clear()
	var container := _view.get_level_container(0)
	var colors := ["#e8c36a", "#d9573c"]
	for i in 2:
		var body := CharacterAssembler.build({"hairstyle": style_id, "hair": colors[i], "skin": "#f5c9a6", "shirt": "#6fb7ff", "pants": "#3b4a5e"})
		body.position = Vector3(O.x + 5.0 + i * 0.9, 0.0, O.y + 3.6)
		container.add_child(body)
		_bodies.append(body)


func _model_count() -> int:
	var count := 0
	for node in _view.get_level_container(0).find_children("Model", "Node3D", true, false):
		count += 1
	return count


func _check(condition: bool, description: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		print("FALLÓ: ", description)


func _shot(file_name: String) -> void:
	await _frames(3)
	var image := get_viewport().get_texture().get_image()
	_check(image != null and image.get_width() > 100, "captura " + file_name)
	image.save_png(_shot_dir.path_join(file_name))
	_shots.append(file_name)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
