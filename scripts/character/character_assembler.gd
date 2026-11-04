class_name CharacterAssembler
## Arma el personaje por piezas (Fase 7): un cuerpo con esqueleto y un modelo
## .glb por "slot" (cuerpo, cabeza, pelo, ojos, boca, orejas, cola, ropa,
## accesorio). Los slots y los huesos se definen en data/character_slots.json.
##
## Siempre parte de la figura simple (CharacterLook.build). Cada pieza .glb que
## carga bien esconde las figuras simples que reemplaza; la que falta o está
## rota se queda como figura simple. Con «Usar modelos» apagado no se toca nada.
## Quien usa al personaje no se entera: recibe el mismo nodo "Body".

const SLOTS_PATH := "res://data/character_slots.json"

static var _config: Dictionary = {}


## Datos de data/character_slots.json (se leen una vez; `reload` para releer).
static func config() -> Dictionary:
	if _config.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SLOTS_PATH))
		_config = parsed if parsed is Dictionary else {"slots": [], "animations": {}, "skeleton": []}
	return _config


static func reload() -> void:
	_config = {}


## Lista de slots (cada uno es un Dictionary, ver el JSON).
static func slots() -> Array:
	return config().get("slots", [])


## Opciones de un slot: las de character_options.json (options_key) o las propias.
static func slot_options(slot: Dictionary) -> Array:
	if slot.has("options_key"):
		return Catalog.character_options.get(str(slot["options_key"]), [])
	return slot.get("options", [])


## Ruta del .glb de la opción elegida en un slot, o "" si no tiene.
static func slot_model_path(slot: Dictionary, appearance: Dictionary) -> String:
	var chosen := str(appearance.get(str(slot.get("appearance_key", slot.get("id", ""))), ""))
	var options := slot_options(slot)
	var option: Dictionary = {}
	for candidate in options:
		if str(candidate.get("id", "")) == chosen:
			option = candidate
			break
	if option.is_empty() and chosen == "" and not options.is_empty():
		option = options[0]
	var path := str(option.get("model", ""))
	if path != "" and not path.begins_with("res://") and not path.begins_with("user://"):
		path = str(config().get("model_dir", "res://assets/models/character/")) + path
	return path


## Figura completa del personaje (nodo "Body", pies en y = 0, cara hacia +z).
static func build(appearance: Dictionary) -> Node3D:
	var body := CharacterLook.build(appearance)
	body.set_meta("model_slots", [])
	if not ModelLoader.enabled:
		return body
	var used: Array = body.get_meta("model_slots")
	var skeleton: Skeleton3D = null
	# El cuerpo va primero: de él sale el esqueleto donde se pegan las demás.
	var ordered: Array = []
	for slot in slots():
		if slot.get("id", "") == "body":
			ordered.push_front(slot)
		else:
			ordered.append(slot)
	for slot in ordered:
		var path := slot_model_path(slot, appearance)
		if path == "":
			continue
		var piece := ModelLoader.load_path(path, Vector3.ZERO, _colors_for(slot, appearance))
		if piece == null:
			continue  # Se queda la figura simple.
		piece.name = "Slot_" + str(slot.get("id", "piece"))
		if slot.get("id", "") == "body":
			skeleton = _find_skeleton(piece)
		_attach(body, piece, slot, skeleton)
		_hide_fallbacks(body, slot)
		used.append(str(slot.get("id", "")))
	return body


## Colores de la apariencia que le tocan a la pieza ({material: Color}).
static func _colors_for(slot: Dictionary, appearance: Dictionary) -> Dictionary:
	var result := {}
	var wanted: Dictionary = slot.get("colors", {})
	for material_name in wanted:
		var key := str(wanted[material_name])
		if appearance.has(key):
			result[str(material_name)] = Color.from_string(str(appearance[key]), Color.MAGENTA)
	return result


static func _attach(body: Node3D, piece: Node3D, slot: Dictionary, skeleton: Skeleton3D) -> void:
	var bone := str(slot.get("attach", ""))
	if slot.get("id", "") != "body" and skeleton != null and skeleton.find_bone(bone) >= 0:
		var attachment := BoneAttachment3D.new()
		attachment.name = "Attach_" + bone
		skeleton.add_child(attachment)
		attachment.bone_name = bone
		attachment.add_child(piece)
		return
	var pos: Array = slot.get("fallback_pos", [0, 0, 0])
	var anchor := Node3D.new()
	anchor.name = "Anchor_" + str(slot.get("id", "piece"))
	anchor.position = Vector3(pos[0], pos[1], pos[2]) if slot.get("id", "") != "body" else Vector3.ZERO
	body.add_child(anchor)
	anchor.add_child(piece)


static func _hide_fallbacks(body: Node3D, slot: Dictionary) -> void:
	for pattern in slot.get("hides", []):
		for child in body.get_children():
			if child is MeshInstance3D and String(child.name).match(str(pattern)):
				(child as MeshInstance3D).visible = false


static func _find_skeleton(root: Node) -> Skeleton3D:
	var found := root.find_children("*", "Skeleton3D", true, false)
	return found[0] as Skeleton3D if not found.is_empty() else null
