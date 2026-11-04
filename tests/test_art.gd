extends Node
## Pruebas de la preparación de arte (Fase 7), sin pantalla ni red.
##
##   godot --headless --path . res://tests/test_art.tscn
##
## Cubre: paleta y luz (un solo lugar), .glb de ejemplo (convenciones), cargar con
## y sin archivo / roto / interruptor apagado, caja de celdas, recoloreo por
## nombre de material, puertas y ventanas con modelo, personaje por slots y
## ganchos de animación.

const CHAIR := "res://assets/models/chair.glb"
const TABLE := "res://assets/models/table.glb"
const HAIR := "res://assets/models/character/hair_round.glb"

var _passed := 0
var _failed := 0


func _ready() -> void:
	ModelLoader.clear_cache()
	ModelLoader.enabled = true
	_test_palette_and_light()
	_test_sample_models()
	_test_load_variants()
	_test_box_fit()
	_test_recolor()
	_test_furniture_integration()
	_test_openings()
	_test_character_slots()
	_test_animation_hooks()
	_test_toggle_signal()
	ModelLoader.clear_cache()
	print("\nPRUEBAS DE ARTE: %d pasaron, %d fallaron" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _check(condition: bool, description: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		print("FALLÓ: ", description)


## Primer MeshInstance3D del modelo cuyo material de la malla se llame `material_name`.
func _surface_with(root: Node, material_name: String) -> Array:
	for mesh_node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_node as MeshInstance3D
		for surface in mesh_instance.mesh.get_surface_count():
			if ModelLoader.material_name_of(mesh_instance.mesh.surface_get_material(surface)) == material_name:
				return [mesh_instance, surface]
	return []


func _test_palette_and_light() -> void:
	print("\n1) Paleta y luz en data/palette.json (un solo lugar)")
	_check(Style.materials.size() >= 20, "la paleta trae materiales con nombre (%d)" % Style.materials.size())
	var valid := true
	for material_name in Style.materials:
		if material_name != material_name.to_lower() or not Color.html_is_valid(str(Style.materials[material_name])):
			valid = false
	_check(valid, "nombres en minúsculas y colores #rrggbb válidos")
	_check(Style.has_material_color("wood") and not Style.has_material_color("inventado"), "has_material_color")
	_check(Style.material_color("inventado", Color.RED) == Color.RED, "material desconocido: usa el color de respaldo")
	var tones: Array = Style.data.get("toon", {}).get("tones", [])
	_check(tones.size() == 3 and tones[0] < tones[1] and tones[1] <= tones[2], "tonos de sombra 3: %s" % str(tones))
	_check(Style.data.get("light", {}).has("sun_color"), "la luz sale de la paleta")
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/style.json"))
	_check(not raw.has("toon") and not raw.has("light"), "style.json ya no repite tonos ni luz (un solo lugar)")


func _test_sample_models() -> void:
	print("\n2) Los .glb de ejemplo cumplen las convenciones")
	for entry in [[CHAIR, Vector3(1, 0.9, 1), 400], [TABLE, Vector3(2, 0.78, 1), 400], [HAIR, Vector3(0.7, 0.5, 0.7), 400]]:
		var report := ModelLoader.inspect(entry[0])
		_check(report["ok"], "%s se lee" % entry[0])
		_check(report["triangles"] > 0 and report["triangles"] <= entry[2], "%s: pocos triángulos (%d)" % [entry[0], report["triangles"]])
		var size: Vector3 = report["size"]
		var box: Vector3 = entry[1]
		_check(size.x <= box.x + 0.01 and size.y <= box.y + 0.01 and size.z <= box.z + 0.01, "%s cabe en su caja %s (mide %s)" % [entry[0], box, size])
		_check("wood" in report["materials"] or "hair" in report["materials"], "%s: materiales con nombre %s" % [entry[0], str(report["materials"])])
		if entry[0] != HAIR:
			_check(report["warnings"].is_empty(), "%s: pivote y paleta sin avisos %s" % [entry[0], str(report["warnings"])])


func _test_load_variants() -> void:
	print("\n3) Con archivo, sin archivo, roto y apagado")
	var item := {"model": CHAIR}
	var model := ModelLoader.load_for_item(item, Vector3(1, 0.9, 1))
	_check(model != null and model.name == "Model", "con archivo: carga")
	if model != null:
		_check(model.find_children("*", "MeshInstance3D", true, false).size() >= 1, "tiene mallas")
		model.free()
	_check(ModelLoader.load_for_item({}, Vector3.ONE) == null, "sin campo model: null")
	_check(ModelLoader.load_for_item({"model": "res://assets/models/no_existe.glb"}, Vector3.ONE) == null, "archivo que no existe: null")
	_check(ModelLoader.last_error.contains("no existe"), "y dice por qué: %s" % ModelLoader.last_error)
	# Roto: basura, y un .glb de verdad cortado a la mitad.
	var garbage := FileAccess.open("user://art_garbage.glb", FileAccess.WRITE)
	garbage.store_string("esto no es un modelo 3d")
	garbage.close()
	var full := FileAccess.get_file_as_bytes(CHAIR)
	var cut := FileAccess.open("user://art_cut.glb", FileAccess.WRITE)
	cut.store_buffer(full.slice(0, full.size() / 2))
	cut.close()
	_check(ModelLoader.load_for_item({"model": "user://art_garbage.glb"}, Vector3.ONE) == null, "archivo de basura: null, sin romper")
	_check(ModelLoader.load_for_item({"model": "user://art_cut.glb"}, Vector3.ONE) == null, "glb cortado: null, sin romper")
	_check(ModelLoader.broken_models().has("user://art_garbage.glb"), "queda anotado como roto")
	_check(not ModelLoader.is_loadable("user://art_garbage.glb") and ModelLoader.is_loadable(CHAIR), "is_loadable")
	# Una copia buena en user:// también carga (ruta fuera del proyecto).
	var good := FileAccess.open("user://art_good.glb", FileAccess.WRITE)
	good.store_buffer(full)
	good.close()
	var copy := ModelLoader.load_for_item({"model": "user://art_good.glb"}, Vector3.ONE)
	_check(copy != null, "glb bueno en user:// carga")
	if copy != null:
		copy.free()
	# Interruptor apagado.
	ModelLoader.enabled = false
	_check(ModelLoader.load_for_item(item, Vector3.ONE) == null, "«Usar modelos» apagado: null")
	ModelLoader.enabled = true
	for path in ["user://art_garbage.glb", "user://art_cut.glb", "user://art_good.glb"]:
		DirAccess.remove_absolute(path)


func _test_box_fit() -> void:
	print("\n4) Caja de celdas (escala y pivote)")
	var normal := ModelLoader.load_for_item({"model": CHAIR}, Vector3(1, 0.9, 1))
	var fit_normal := normal.get_node("Fit") as Node3D
	_check(fit_normal.scale.is_equal_approx(Vector3.ONE), "cabe: no se toca la escala")
	normal.free()
	var small := ModelLoader.load_for_item({"model": CHAIR}, Vector3(0.5, 0.45, 0.5))
	var fit_small := small.get_node("Fit") as Node3D
	_check(absf(fit_small.scale.x - 0.5) < 0.05 and is_equal_approx(fit_small.scale.x, fit_small.scale.y), "se pasa de la caja: se achica parejo (%s)" % fit_small.scale)
	small.free()
	var stretched := ModelLoader.load_for_item({"model": TABLE, "model_fit": "stretch"}, Vector3(1, 1.56, 1))
	var fit_stretched := stretched.get_node("Fit") as Node3D
	_check(fit_stretched.scale.y > 1.9 and fit_stretched.scale.x < 0.6, "stretch: se estira a la caja (%s)" % fit_stretched.scale)
	stretched.free()
	var no_fit := ModelLoader.load_for_item({"model": CHAIR, "model_fit": "none"}, Vector3(0.2, 0.2, 0.2))
	_check((no_fit.get_node("Fit") as Node3D).scale.is_equal_approx(Vector3.ONE), "none: no escala")
	no_fit.free()
	# Pivote automático: el pelo trae su base en y = -0,1; queda apoyado en 0.
	var auto := ModelLoader.load_for_item({"model": HAIR, "model_pivot": "auto"}, Vector3.ZERO)
	_check(absf((auto.get_node("Fit") as Node3D).position.y - 0.1) < 0.02, "pivote auto: sube la base a y = 0")
	auto.free()
	# Ajustes finos del dueño.
	var tuned := ModelLoader.load_for_item({"model": CHAIR, "model_scale": 2.0, "model_offset": [0, 0.1, 0], "model_rotation": 90}, Vector3.ZERO)
	_check(is_equal_approx(tuned.scale.x, 2.0) and is_equal_approx(tuned.position.y, 0.1) and is_equal_approx(tuned.rotation.y, PI / 2.0), "model_scale, model_offset y model_rotation")
	tuned.free()


func _test_recolor() -> void:
	print("\n5) Recoloreo por nombre de material")
	var model := ModelLoader.load_for_item({"model": CHAIR}, Vector3(1, 0.9, 1))
	var found := _surface_with(model, "wood")
	var mesh_instance: MeshInstance3D = found[0]
	var material := mesh_instance.get_surface_override_material(found[1]) as ShaderMaterial
	_check(material != null and material.next_pass != null, "el material es toon con contorno")
	_check(material.get_shader_parameter("albedo") == Style.material_color("wood"), "«wood» toma el color de la paleta")
	# Cambia la paleta y se recolorea.
	var old: String = Style.materials["wood"]
	Style.materials["wood"] = "#123456"
	ModelLoader.apply_materials(model)
	var recolored := mesh_instance.get_surface_override_material(found[1]) as ShaderMaterial
	_check(recolored.get_shader_parameter("albedo") == Color("#123456"), "al cambiar la paleta y recolorear, cambia")
	Style.materials["wood"] = old
	# Color solo para esta pieza.
	var custom := ModelLoader.load_for_item({"model": CHAIR, "model_colors": {"cloth_red": "#00ff00"}}, Vector3.ZERO)
	var red_found := _surface_with(custom, "cloth_red")
	var red_material := (red_found[0] as MeshInstance3D).get_surface_override_material(red_found[1]) as ShaderMaterial
	_check(red_material.get_shader_parameter("albedo") == Color("#00ff00"), "model_colors pinta solo esta pieza")
	# Contorno apagado también llega a los modelos.
	Style.set_outline(false)
	_check(material.next_pass == null, "con contorno apagado, el modelo no lo lleva")
	Style.set_outline(true)
	_check(material.next_pass != null, "y vuelve")
	# Nombres de Blender con sufijo.
	var named := StandardMaterial3D.new()
	named.resource_name = "Wood.001"
	_check(ModelLoader.material_name_of(named) == "wood", "«Wood.001» de Blender se lee como «wood»")
	model.free()
	custom.free()


func _test_furniture_integration() -> void:
	print("\n6) Muebles del catálogo con y sin modelo")
	var value := {"item": "chair_basic", "cell": [3, 3], "rot": 0}
	_check(Catalog.get_item("chair_basic").get("model", "") == CHAIR, "la silla del catálogo apunta a su .glb")
	var with_model := HousePieces.build_object(value)
	_check(with_model.find_child("Model", true, false) != null, "con modelo: se usa el .glb")
	with_model.free()
	ModelLoader.enabled = false
	var simple := HousePieces.build_object(value)
	_check(simple.find_child("Model", true, false) == null and simple.get_child_count() > 0, "interruptor apagado: figuras simples")
	simple.free()
	ModelLoader.enabled = true
	var item := Catalog.get_item("chair_basic")
	item["model"] = "res://assets/models/borrado.glb"
	var fallback := HousePieces.build_object(value)
	_check(fallback.find_child("Model", true, false) == null and fallback.get_child_count() > 0, "archivo que falta: figuras simples")
	fallback.free()
	item["model"] = CHAIR
	# Una mesa de 2 x 1 con modelo y girada: el nodo ya viene con su giro.
	var table := HousePieces.build_object({"item": "table_basic", "cell": [2, 2], "rot": 1})
	_check(table.find_child("Model", true, false) != null, "mesa con modelo y girada")
	table.free()


func _test_openings() -> void:
	print("\n7) Puertas y ventanas con modelo")
	var door := Catalog.get_item("door_basic")
	var window := Catalog.get_item("window_basic")
	var wall := {"item": "wall_basic", "opening": "door_basic"}
	var plain := HousePieces.build_wall("h:2,2", wall, HouseGrid.WALL_HEIGHT)
	_check(plain.find_child("Model", true, false) == null, "puerta sin modelo: marco y hoja de siempre")
	plain.free()
	door["model"] = CHAIR
	var with_door := HousePieces.build_wall("h:2,2", wall, HouseGrid.WALL_HEIGHT)
	_check(with_door.find_child("Model", true, false) != null, "puerta con modelo: se usa")
	with_door.free()
	door["model"] = "res://assets/models/no_existe.glb"
	var broken_door := HousePieces.build_wall("h:2,2", wall, HouseGrid.WALL_HEIGHT)
	_check(broken_door.find_child("Model", true, false) == null and broken_door.get_child_count() > 1, "puerta con modelo que falta: figuras simples")
	broken_door.free()
	door.erase("model")
	window["model"] = TABLE
	var with_window := HousePieces.build_wall("h:2,2", {"item": "wall_basic", "opening": "window_basic"}, HouseGrid.WALL_HEIGHT)
	_check(with_window.find_child("Model", true, false) != null, "ventana con modelo: se usa (el vidrio sigue)")
	with_window.free()
	window.erase("model")
	var stairs := Catalog.get_item("stairs_basic")
	if not stairs.is_empty():
		stairs["model"] = TABLE
		stairs["model_fit"] = "stretch"
		var with_stairs := HousePieces.build_object({"item": "stairs_basic", "cell": [2, 2], "rot": 0})
		_check(with_stairs.find_child("Model", true, false) != null, "escalera con modelo: se usa y se estira al alto")
		with_stairs.free()
		stairs.erase("model")
		stairs.erase("model_fit")


func _test_character_slots() -> void:
	print("\n8) Personaje por slots")
	var slot_ids: Array = []
	for slot in CharacterAssembler.slots():
		slot_ids.append(slot["id"])
	for needed in ["body", "head", "hair", "eyes", "mouth", "ears", "tail", "clothes", "accessory"]:
		_check(needed in slot_ids, "slot «%s» definido" % needed)
	var hairstyles: Array = Catalog.character_options["hairstyles"]
	var style_id := str(hairstyles[0]["id"])
	var appearance := {"hairstyle": style_id, "hair": "#ff0000", "skin": "#f5c9a6"}
	var plain := CharacterAssembler.build(appearance)
	_check(plain.get_meta("model_slots").is_empty() and plain.get_node("Hair").visible, "sin modelos en los datos: figuras simples")
	plain.free()
	hairstyles[0]["model"] = HAIR
	var assembled := CharacterAssembler.build(appearance)
	_check("hair" in assembled.get_meta("model_slots"), "con modelo de pelo: el slot se llena")
	_check(not assembled.get_node("Hair").visible and assembled.get_node("Head").visible, "el pelo simple se esconde y la cabeza queda")
	var piece := assembled.find_child("Slot_hair", true, false)
	var found := _surface_with(piece, "hair")
	var hair_material := (found[0] as MeshInstance3D).get_surface_override_material(found[1]) as ShaderMaterial
	_check(hair_material.get_shader_parameter("albedo") == Color("#ff0000"), "el pelo toma el color elegido en el editor")
	assembled.free()
	ModelLoader.enabled = false
	var off := CharacterAssembler.build(appearance)
	_check(off.get_meta("model_slots").is_empty() and off.get_node("Hair").visible, "interruptor apagado: figuras simples")
	off.free()
	ModelLoader.enabled = true
	hairstyles[0]["model"] = "res://assets/models/character/no_existe.glb"
	var broken := CharacterAssembler.build(appearance)
	_check(broken.get_meta("model_slots").is_empty() and broken.get_node("Hair").visible, "pieza que falta: queda la figura simple")
	broken.free()
	hairstyles[0].erase("model")
	_check(CharacterAssembler.slot_model_path({"appearance_key": "tail", "options": [{"id": "fox", "model": "fox_tail.glb"}]}, {"tail": "fox"}).ends_with("character/fox_tail.glb"), "ruta relativa se completa con model_dir")


func _test_animation_hooks() -> void:
	print("\n9) Ganchos de animación por nombre")
	var holder := Node3D.new()
	add_child(holder)
	var player := AnimationPlayer.new()
	holder.add_child(player)
	var library := AnimationLibrary.new()
	library.add_animation("Walking", Animation.new())
	library.add_animation("idle", Animation.new())
	player.add_animation_library("", library)
	var animator := CharacterAnimator.new()
	add_child(animator)
	animator.bind_model(holder)
	_check(animator.animation_player == player, "encuentra el AnimationPlayer del modelo")
	_check(animator._clip_names.get("idle", "") == "idle", "idle ↔ idle")
	_check(animator._clip_names.get("walk", "") == "Walking", "walk ↔ «Walking» (nombre aceptado, sin importar mayúsculas)")
	library.add_animation("Nombre_raro", Animation.new())
	animator.bind_model(holder)
	_check(not animator._clip_names.values().has("Nombre_raro"), "un nombre que no es de ningún gancho se ignora")
	_check(not animator._clip_names.has("cook"), "cook sin animación en el modelo: sigue la simple")
	animator.bind_model(null)
	_check(animator.animation_player == null, "sin modelo: vuelve a las animaciones simples")
	holder.queue_free()
	animator.queue_free()


func _test_toggle_signal() -> void:
	print("\n10) Interruptor «Usar modelos»")
	var received: Array = []
	var listener := func(on: bool) -> void: received.append(on)
	EventBus.models_toggled.connect(listener)
	ModelLoader.set_enabled(false)
	ModelLoader.set_enabled(false)
	ModelLoader.set_enabled(true)
	EventBus.models_toggled.disconnect(listener)
	_check(received == [false, true], "avisa solo cuando cambia: %s" % str(received))
