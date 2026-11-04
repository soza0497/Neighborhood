class_name CharacterLook
## Arma la figura chibi provisional del personaje (hasta la Fase 7):
## cuerpo de cápsulas y una cabeza grande con ojos y pelo.
## Mira hacia +Z. Los pies quedan en Y = 0.

const BODY_PARTS := ["Legs", "Body", "ArmLeft", "ArmRight", "Head", "Hair", "EyeLeft", "EyeRight", "Mouth"]
## Opciones de pieza que usa un personaje sin esa elección (partidas viejas).
const DEFAULT_PIECES := {"hairstyle": "cap", "eyes": "dots", "mouth": "smile"}


## Devuelve un Node3D "Body" con todas las partes. `appearance` trae los
## colores (skin, hair, shirt, pants) y las piezas elegidas (hairstyle, eyes,
## mouth: ids de data/character_options.json). Las piezas son intercambiables:
## cada peinado, par de ojos y boca es una lista de formas simples en los datos.
static func build(appearance: Dictionary) -> Node3D:
	var skin := _color(appearance, "skin", "#f5c9a6")
	var hair := _color(appearance, "hair", "#5a3a22")
	var shirt := _color(appearance, "shirt", "#6fb7ff")
	var pants := _color(appearance, "pants", "#3b4a5e")

	var body := Node3D.new()
	body.name = "Body"
	_capsule(body, "Legs", Vector3(0, 0.2, 0), 0.15, 0.4, pants)
	_capsule(body, "Body", Vector3(0, 0.5, 0), 0.2, 0.5, shirt)
	_capsule(body, "ArmLeft", Vector3(-0.24, 0.5, 0), 0.06, 0.36, skin)
	_capsule(body, "ArmRight", Vector3(0.24, 0.5, 0), 0.06, 0.36, skin)
	_sphere(body, "Head", Vector3(0, 1.0, 0), 0.3, skin)
	_add_piece(body, "hairstyles", str(appearance.get("hairstyle", DEFAULT_PIECES["hairstyle"])), "Hair", hair)
	var eye_names := ["EyeLeft", "EyeRight"]
	_add_piece(body, "eyes", str(appearance.get("eyes", DEFAULT_PIECES["eyes"])), "Eye", skin, eye_names)
	_add_piece(body, "mouths", str(appearance.get("mouth", DEFAULT_PIECES["mouth"])), "Mouth", skin)
	return body


## La opción `id` de la lista `list_key` de data/character_options.json (o la
## primera si no existe: un guardado de otra versión no rompe nada).
static func piece_option(list_key: String, id: String) -> Dictionary:
	var list: Array = Catalog.character_options.get(list_key, [])
	for option in list:
		if option["id"] == id:
			return option
	return list[0] if not list.is_empty() else {}


## Agrega las formas de una opción. `fallback_color` pinta las formas que no
## traen su propio color. `names` (opcional) da el nombre de las primeras formas.
static func _add_piece(body: Node3D, list_key: String, id: String, base_name: String, fallback_color: Color, names := []) -> void:
	var option := piece_option(list_key, id)
	var index := 0
	for part in option.get("parts", []):
		var color := Color.from_string(str(part["color"]), fallback_color) if part.has("color") else fallback_color
		var pos := Vector3(part["pos"][0], part["pos"][1], part["pos"][2])
		var part_name: String = names[index] if index < names.size() else (base_name if index == 0 else "%s%d" % [base_name, index + 1])
		var node: MeshInstance3D
		if str(part.get("shape", "sphere")) == "capsule":
			node = _capsule(body, part_name, pos, float(part["radius"]), float(part["height"]), color)
		else:
			node = _sphere(body, part_name, pos, float(part["radius"]), color)
		if part.has("scale"):
			node.scale = Vector3(part["scale"][0], part["scale"][1], part["scale"][2])
		if part.has("rot"):
			node.rotation_degrees = Vector3(part["rot"][0], part["rot"][1], part["rot"][2])
		index += 1


## Utilería del trabajo (Pulido 2B): un saco encima del cuerpo y una maleta en
## la mano. Es de mentira: solo se ve mientras va o vuelve del trabajo. Los
## colores salen de la paleta (data/style.json).
static func build_work_props() -> Node3D:
	var props := Node3D.new()
	props.name = "WorkProps"
	var jacket := CapsuleMesh.new()
	jacket.radius = 0.225
	jacket.height = 0.5
	jacket.radial_segments = 12
	jacket.rings = 4
	var jacket_node := MeshInstance3D.new()
	jacket_node.mesh = jacket
	jacket_node.position = Vector3(0, 0.52, 0)
	jacket_node.material_override = HousePieces.material(Style.color("suit", Color("#33384a")))
	props.add_child(jacket_node)
	var case_node := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.1, 0.22, 0.3)
	case_node.mesh = box
	case_node.position = Vector3(0.3, 0.22, 0.05)
	case_node.material_override = HousePieces.material(Style.color("suitcase", Color("#8a5a3a")))
	props.add_child(case_node)
	var handle := MeshInstance3D.new()
	var handle_mesh := BoxMesh.new()
	handle_mesh.size = Vector3(0.04, 0.05, 0.12)
	handle.mesh = handle_mesh
	handle.position = Vector3(0.3, 0.36, 0.05)
	handle.material_override = HousePieces.material(Color("#3a2a20"))
	props.add_child(handle)
	return props


static func _color(appearance: Dictionary, part: String, fallback: String) -> Color:
	return Color.from_string(appearance.get(part, fallback), Color.from_string(fallback, Color.WHITE))


static func _capsule(parent: Node3D, part_name: String, pos: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh.rings = 4
	return _add(parent, part_name, mesh, pos, color)


static func _sphere(parent: Node3D, part_name: String, pos: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	return _add(parent, part_name, mesh, pos, color)


static func _add(parent: Node3D, part_name: String, mesh: Mesh, pos: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = part_name
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = HousePieces.material(color)
	parent.add_child(instance)
	return instance
