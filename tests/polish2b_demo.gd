extends Node
## Demostración del Pulido 2B (estilo y vida), con capturas.
##
## Correr desde la terminal (abre una ventana unos segundos):
##   godot --path . res://tests/polish2b_demo.tscn
## Las capturas (p2b_*.png) van a SHOT_DIR (o a user://).
##
## Prueba: shader toon con contorno (y apagarlo), terreno de un solo color,
## niebla, bosque, vecinos, autos y gente, modelos del catálogo con respaldo,
## el trabajo como título (saco y maleta), animaciones de reposo, sonido y las
## opciones de Info.

var _main: Node3D
var _hud: CanvasLayer
var _house: HouseData
var _character: Character
var _shot_dir := ""
var _passed := 0
var _failed := 0
var _shots: Array[String] = []


func _ready() -> void:
	HouseGrid.use_test_lot()  # Estas pruebas arman casas en un lote de 32 (la parcela real, desde el Pulido 2C, es de 96).
	_shot_dir = OS.get_environment("SHOT_DIR")
	if _shot_dir == "":
		_shot_dir = OS.get_user_data_dir()
	_main = preload("res://scenes/main.tscn").instantiate()
	add_child(_main)
	Economy.debug_unlock_all()
	_hud = _main.get_node("HUD")
	_house = _main.house
	_character = _main.get_node("House/Character")
	_run.call_deferred()


func _run() -> void:
	_build_test_house()
	_main.set_mode("live")
	_main._set_level(0)
	await _frames(12)
	await _test_style()
	await _test_world()
	await _test_model_hook()
	await _test_work_visuals()
	await _test_idle_sound_info()
	print("\nDEMO PULIDO 2B: %d pasaron, %d fallaron · capturas: %s" % [_passed, _failed, ", ".join(_shots)])
	get_tree().quit(1 if _failed > 0 else 0)


func _build_test_house() -> void:
	_house.from_dict({"lot_size": [HouseGrid.LOT_SIZE.x, HouseGrid.LOT_SIZE.y]})
	_house.floor_count = 1
	var writes: Array = []
	for c in HouseGrid.cells_in_rect(Vector2i(11, 12), Vector2i(18, 18)):
		writes.append(HouseData.write(0, "foundation", HouseGrid.cell_key(c), {"item": "foundation_basic"}))
		writes.append(HouseData.write(0, "floors", HouseGrid.cell_key(c), {"item": "floor_basic"}))
	for edge in HouseGrid.edges_around_rect(Vector2i(11, 12), Vector2i(18, 18)):
		writes.append(HouseData.write(0, "walls", edge, {"item": "wall_basic"}))
	writes.append(HouseData.write(0, "walls", "h:13,19", {"item": "wall_basic", "opening": "door_basic"}))
	writes.append(HouseData.write(0, "walls", "h:16,19", {"item": "wall_basic", "opening": "window_basic"}))
	writes.append(HouseData.write(0, "objects", "o2", {"item": "bed_basic", "cell": [12, 13], "rot": 0}))
	writes.append(HouseData.write(0, "objects", "o3", {"item": "sofa_basic", "cell": [15, 17], "rot": 2}))
	writes.append(HouseData.write(0, "roofs", "o4", {"item": "roof_basic", "rect": [11, 12, 8, 7]}))
	_house.next_id = 10
	_house.apply(writes)
	_character.place_at(0, Vector2i(13, 16))
	var rig: CameraRig = _main.get_node("CameraRig")
	rig.set_state({"x": 0.0, "z": 4.0, "yaw": 0.0, "distance": 26.0, "pitch": -35.0})


func _test_style() -> void:
	print("\n1) Shader toon con contorno")
	var mat: ShaderMaterial = HousePieces.material(Color("#e0675a"))
	_check(mat is ShaderMaterial and mat.shader.resource_path.ends_with("toon.gdshader"), "las piezas usan el shader toon")
	_check(mat.next_pass is ShaderMaterial and mat.next_pass.shader.resource_path.ends_with("outline.gdshader"),
		"el contorno es una segunda pasada (geometría invertida)")
	_check(HousePieces.material(Color("#e0675a")) == mat, "un solo material por color (compartido)")
	var tones: Vector3 = mat.get_shader_parameter("tones")
	_check(tones.x < tones.y and tones.y < tones.z, "3 tonos de sombra: %s" % str(tones))
	_check(Style.color("ground") != Color.MAGENTA and Style.palette.has("fog"), "la paleta sale de data/style.json")
	await _shot("p2b_1_toon.png")
	Style.set_outline(false)
	await _frames(3)
	_check(mat.next_pass == null, "apagar el contorno lo saca de los materiales")
	await _shot("p2b_2_sin_contorno.png")
	Style.set_outline(true)
	_check(mat.next_pass != null, "y se vuelve a prender")
	var flat := Style.toon_material(Style.color("ground"), null, false)
	_check(flat.next_pass == null, "el suelo no lleva contorno")
	# Los personajes también.
	var body: Node3D = _character.get_node("Body") if _character.has_node("Body") else null
	var has_toon := false
	if body != null:
		for part in body.get_children():
			if part is MeshInstance3D and part.material_override is ShaderMaterial:
				has_toon = true
	_check(has_toon, "el personaje usa el mismo shader")


func _test_world() -> void:
	print("\n2) Entorno: terreno, niebla, bosque, vecinos, vida")
	var world: WorldBuilder = _main.get_node("World")
	_check(world.get_node_or_null("Terrain") != null and _main.get_node_or_null("Lot") == null and world.get_node_or_null("Lot") == null,
		"el terreno es uno solo (sin parcela más clara)")
	var ground: ShaderMaterial = world.get_node("Terrain").material_override
	_check(ground.get_shader_parameter("albedo") == Style.color("ground"), "el terreno usa el color de la paleta")
	var env: Environment = _main.get_node("WorldEnvironment").environment
	_check(env.fog_enabled and env.fog_depth_end > env.fog_depth_begin, "hay niebla en los bordes (%d a %d m)" % [env.fog_depth_begin, env.fog_depth_end])
	_check(env.background_color == Style.color("sky") and env.fog_light_color == Style.color("fog"), "el cielo y la niebla son del mismo color")
	var trunks: MultiMeshInstance3D = world.get_node("ForestTrunks")
	_check(trunks.multimesh.instance_count >= 300, "bosque atrás y a los lados: %d árboles" % trunks.multimesh.instance_count)
	var behind := 0
	var sides := 0
	for i in trunks.multimesh.instance_count:
		var p := trunks.multimesh.get_instance_transform(i).origin
		if p.z < -world.lot_half.y:
			behind += 1
		if absf(p.x) > world.lot_half.x:
			sides += 1
	_check(behind > 100 and sides > 100, "hay árboles atrás (%d) y a los costados (%d)" % [behind, sides])
	var neighbors := world.get_node("Neighbors")
	_check(neighbors.get_child_count() >= 5, "casas de vecinos de decoración: %d" % neighbors.get_child_count())
	var all_back := true
	for house in neighbors.get_children():
		if house.position.z > -world.lot_half.y:
			all_back = false
	_check(all_back, "los vecinos quedan atrás de la parcela")
	var life: WorldLife = world.life
	_check(life.get_child_count() >= 6, "autos y gente en la calle (%d)" % life.get_child_count())
	var first_car: Node3D = life._cars[0]["node"]
	var x0 := first_car.position.x
	var walker: Node3D = life._walkers[0]["node"]
	var wx0 := walker.position.x
	await get_tree().create_timer(0.6).timeout
	_check(absf(first_car.position.x - x0) > 0.5 and absf(walker.position.x - wx0) > 0.1, "los autos y la gente se mueven")
	_check(world.get_children().any(func(c): return c is CPUParticles3D), "hay partículas (hojitas)")
	var rig: CameraRig = _main.get_node("CameraRig")
	rig.set_state({"x": 0.0, "z": 6.0, "yaw": 0.0, "distance": 40.0, "pitch": -14.0})
	await _frames(4)
	await _shot("p2b_3_entorno.png")
	rig.set_state({"x": 0.0, "z": 0.0, "yaw": 25.0, "distance": 22.0, "pitch": -35.0})
	await _frames(3)


func _test_model_hook() -> void:
	print("\n3) El catálogo puede apuntar a un modelo (.glb) con respaldo")
	var packed := PackedScene.new()
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.6, 0.6, 0.6)
	mesh.mesh = box
	mesh.name = "Cubo"
	root.add_child(mesh)
	mesh.owner = root
	packed.pack(root)
	ResourceSaver.save(packed, "user://p2b_model.tscn")
	var item: Dictionary = Catalog.get_item("chair_basic")
	# Fase 7: la silla ya trae su modelo de ejemplo; se guarda para devolverlo al final.
	var original_model: String = str(item.get("model", ""))
	item.erase("model")
	var value := {"item": "chair_basic", "cell": [3, 3], "rot": 0}
	var fallback := HousePieces.build_object(value)
	_check(fallback.get_child_count() > 0 and fallback.find_child("Model", true, false) == null, "sin campo model: figuras simples")
	item["model"] = "user://no_existe.glb"
	_check(HousePieces.build_object(value).find_child("Model", true, false) == null, "modelo que no existe: vuelve a las figuras simples")
	item["model"] = "user://p2b_model.tscn"
	item["model_scale"] = 2.0
	var with_model := HousePieces.build_object(value)
	var model := with_model.find_child("Model", true, false)
	_check(model != null and is_equal_approx(model.scale.x, 2.0), "con modelo: se usa, con su escala")
	var cube: MeshInstance3D = with_model.find_child("Cubo", true, false)
	_check(cube != null and cube.get_surface_override_material(0) is ShaderMaterial, "y se pasa solo al estilo toon con contorno")
	_check(with_model.find_children("*", "MeshInstance3D", true, false).size() == 1, "reemplaza las figuras (no se suman)")
	item.erase("model_scale")
	if original_model != "":
		item["model"] = original_model
	else:
		item.erase("model")


func _test_work_visuals() -> void:
	print("\n4) Trabajo como título: saco, maleta, sale a la calle y vuelve")
	_character._show_work_props(true)
	await _frames(2)
	var props: Node3D = _character._work_props
	_check(props != null and props.visible and props.get_child_count() >= 3, "saco y maleta de utilería")
	_character._show_work_props(false)
	_check(not props.visible, "y se guardan")
	# Va al trabajo: camina a la acera con la utilería puesta.
	_character._go_to_work()
	await _frames(3)
	_check(_character._plan.has("work") and _character._work_props.visible, "sale con saco y maleta")
	var rig: CameraRig = _main.get_node("CameraRig")
	rig.set_state({"x": 0.0, "z": 8.0, "yaw": 0.0, "distance": 24.0, "pitch": -30.0})
	GameClock.speed = 5
	var walked := 0.0
	while _character.state == Character.State.WALKING and walked < 25.0:
		await get_tree().process_frame
		walked += get_process_delta_time()
		if walked > 1.2 and not _shots.has("p2b_4_sale_a_trabajar.png"):
			await _shot("p2b_4_sale_a_trabajar.png")
	_check(_character.state == Character.State.WORKING and not _character.visible, "llega a la acera y desaparece del lote")
	_check(not _character._work_props.visible, "la utilería se va con él")
	# Mientras tanto, no está en la casa; vuelve con otra animación.
	_character.state = Character.State.IDLE
	_character._return_from_work()
	await _frames(3)
	_check(_character._returning and _character._work_props.visible and _character.cell == Character.work_cell(),
		"vuelve: aparece en la acera con saco y maleta y camina hasta la puerta (%s)" % str(_character._plan.get("spot")))
	_check(_character._plan.get("spot", Vector2i.ZERO) != Character.work_cell() and _character._path.size() > 2, "el camino de vuelta es largo (%d tramos)" % _character._path.size())
	var waited := 0.0
	while _character._returning and waited < 25.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	GameClock.speed = 1
	_check(not _character._returning and not _character._work_props.visible, "llega a la casa y se le guardan las cosas")
	_check(_character._animator.current == "arrive", "y hace su saltito de llegada (animación \"arrive\")")
	await _shot("p2b_5_vuelve.png")
	# Para la pareja se ve igual, usando lo que ya hay de intención.
	_character.is_partner = true
	_character.follow_intention(true, {"character": "Beto", "state": "walking", "verb": "yendo a trabajar", "object": "Repartidor"})
	await _frames(2)
	_check(_character._plan.has("work") and _character._work_props.visible, "la pareja \"yendo a trabajar\" sale con saco y maleta")
	_character.follow_intention(true, {"character": "Beto", "state": "working", "verb": "trabajando"})
	await _frames(3)
	_check(_character.state == Character.State.WORKING and not _character.visible, "la pareja \"trabajando\" no está en el lote")
	_character.follow_intention(false, {})
	await _frames(2)
	_check(_character._returning, "al volver (o desconectarse) se ve regresar de la calle")
	_character.is_partner = false
	_character.remote_driven = false
	_character.reset_after_build()
	_character.place_at(0, Vector2i(13, 16))
	_character._returning = false
	_character._show_work_props(false)
	_character._set_idle()


func _test_idle_sound_info() -> void:
	print("\n5) Reposo, sonido y opciones de Info")
	var animator: CharacterAnimator = _character._animator
	animator.play("idle")
	await _frames(20)
	var body: Node3D = _character._body
	_check(body.scale != Vector3.ONE or body.position.y != 0.0, "reposo: respira y se mece")
	_check(not Sound.play("no_hay_este_sonido") and not Sound.has_sound("build"), "sin archivos de sonido, los ganchos no hacen nada (ni fallan)")
	Sound.set_volume("sfx", 0.5)
	var bus := AudioServer.get_bus_index(Sound.BUS_SFX)
	_check(bus >= 0 and is_equal_approx(AudioServer.get_bus_volume_db(bus), linear_to_db(0.5)) and GameState.settings["volume_sfx"] == 0.5,
		"el volumen de efectos se aplica y se guarda")
	Sound.set_volume("sfx", 1.0)
	var info: Control = _hud.get_node("%InfoPanel")
	_hud._open_info()
	await _frames(3)
	var checks := info.find_children("*", "CheckButton", true, false).filter(func(c): return c.text.contains("Contorno"))
	var sliders := info.find_children("*", "HSlider", true, false)
	_check(checks.size() == 1 and sliders.size() == 3, "Info tiene el interruptor de contorno y %d volúmenes" % sliders.size())
	checks[0].button_pressed = false
	await _frames(2)
	_check(not Style.outline_enabled and GameState.settings["outline_enabled"] == false, "el interruptor apaga el contorno y se guarda")
	checks[0].button_pressed = true
	_check(Style.outline_enabled, "y lo prende")
	await _shot("p2b_6_info.png")
	_hud.get_node("%InfoCloseButton").pressed.emit()


# --- Ayudantes ---

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
