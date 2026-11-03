class_name CharacterLook
## Arma la figura chibi provisional del personaje (hasta la Fase 7):
## cuerpo de cápsulas y una cabeza grande con ojos y pelo.
## Mira hacia +Z. Los pies quedan en Y = 0.

const BODY_PARTS := ["Legs", "Body", "ArmLeft", "ArmRight", "Head", "Hair", "EyeLeft", "EyeRight"]


## Devuelve un Node3D "Body" con todas las partes. `appearance` trae los
## colores: skin, hair, shirt, pants.
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
	var hair_cap := _sphere(body, "Hair", Vector3(0, 1.09, -0.03), 0.31, hair)
	hair_cap.scale = Vector3(1.0, 0.75, 1.0)
	for side in [-1, 1]:
		_sphere(body, "EyeLeft" if side < 0 else "EyeRight", Vector3(side * 0.1, 1.0, 0.27), 0.045, Color(0.12, 0.1, 0.12))
	return body


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
