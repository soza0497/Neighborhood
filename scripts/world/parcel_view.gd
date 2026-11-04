class_name ParcelView
extends Node3D
## Dibuja los obstáculos de la parcela (Pulido 2C): árboles, rocas, un laguito,
## tocones y maleza. Va como hijo de House (coordenadas = celdas de la casa).
##
## Árboles, maleza, tocones y rocas van con MultiMesh (cientos de obstáculos
## en pocas llamadas de dibujo: pensado para un Android de gama media); el
## laguito es un disco plano. Lo que se limpió desaparece. Todo con el estilo
## toon y los colores de la paleta (data/style.json).
##
## También sabe "agarrar" un obstáculo con un toque (pick).

## Alto aproximado de cada tipo (para tocarlo con el dedo).
const HEIGHTS := {"tree": 3.0, "rock": 1.3, "bush": 0.9, "stump": 0.55, "lake": 0.2}

var _nodes: Array[Node] = []
var _hash_seed := 0


func _ready() -> void:
	Parcel.changed.connect(rebuild)
	rebuild()


## Borra y vuelve a dibujar todo lo que queda sin limpiar.
func rebuild() -> void:
	for node in _nodes:
		node.queue_free()
	_nodes.clear()
	var by_kind := {}
	for o in Parcel.obstacles:
		if Parcel.cleared.has(o["id"]):
			continue
		if not by_kind.has(o["kind"]):
			by_kind[o["kind"]] = []
		by_kind[o["kind"]].append(o)
	_trees(by_kind.get("tree", []))
	_blobs("bush", by_kind.get("bush", []), SphereMesh.new(), Style.color("bush"), Vector3(0.5, 0.34, 0.5), 0.34)
	_blobs("stump", by_kind.get("stump", []), _cylinder(0.32, 0.36), Style.color("stump"), Vector3.ONE, 0.18)
	_blobs("rock", by_kind.get("rock", []), SphereMesh.new(), Style.color("rock"), Vector3(1.0, 0.7, 0.9), 0.5)
	_lakes(by_kind.get("lake", []))


func _cylinder(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.9
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 1
	return mesh


## Un número entre 0 y 1 que siempre es el mismo para un obstáculo (para
## variar tamaños y giros sin azar nuevo en cada dibujo).
func _jitter(o: Dictionary, salt: int) -> float:
	var h := hash("%s:%d" % [o["id"], salt])
	return float(absi(h) % 1000) / 1000.0


func _multimesh(node_name: String, mesh: Mesh, count: int, color: Color) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = count
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multi
	instance.material_override = Style.toon_material(color)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	_nodes.append(instance)
	return instance


func _trees(list: Array) -> void:
	if list.is_empty():
		return
	var trunk_mesh := _cylinder(0.2, 1.3)
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 0.95
	crown_mesh.height = 1.9
	crown_mesh.radial_segments = 8
	crown_mesh.rings = 4
	var trunks := _multimesh("ObstacleTrunks", trunk_mesh, list.size(), Style.color("trunk"))
	var crowns := _multimesh("ObstacleCrowns", crown_mesh, list.size(), Style.color("leaf"))
	for i in list.size():
		var o: Dictionary = list[i]
		var s := 0.85 + _jitter(o, 1) * 0.5
		var base := Vector3(o["x"] + 0.5 + (_jitter(o, 2) - 0.5) * 0.3, 0.0, o["z"] + 0.5 + (_jitter(o, 3) - 0.5) * 0.3)
		var basis := Basis().scaled(Vector3.ONE * s)
		trunks.multimesh.set_instance_transform(i, Transform3D(basis, base + Vector3(0, 0.65 * s, 0)))
		crowns.multimesh.set_instance_transform(i, Transform3D(basis, base + Vector3(0, 1.3 * s + 0.65 * s, 0)))


func _blobs(kind: String, list: Array, mesh: Mesh, color: Color, shape: Vector3, lift: float) -> void:
	if list.is_empty():
		return
	if mesh is SphereMesh:
		mesh.radial_segments = 8
		mesh.rings = 4
	var blobs := _multimesh("Obstacle_" + kind, mesh, list.size(), color)
	for i in list.size():
		var o: Dictionary = list[i]
		var s := 0.8 + _jitter(o, 1) * 0.45
		var size := Vector3(o["w"], 1.0, o["d"]) if kind == "rock" else Vector3.ONE
		var basis := Basis().rotated(Vector3.UP, _jitter(o, 4) * TAU).scaled(Vector3(shape.x * s * size.x, shape.y * s, shape.z * s * size.z))
		var center := Vector3(o["x"] + o["w"] / 2.0, lift * s, o["z"] + o["d"] / 2.0)
		blobs.multimesh.set_instance_transform(i, Transform3D(basis, center))


func _lakes(list: Array) -> void:
	for o in list:
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.5
		mesh.bottom_radius = 0.5
		mesh.height = 0.08
		mesh.radial_segments = 20
		mesh.rings = 1
		var instance := MeshInstance3D.new()
		instance.name = "Lake_" + o["id"]
		instance.mesh = mesh
		instance.scale = Vector3(o["w"], 1.0, o["d"])
		instance.position = Vector3(o["x"] + o["w"] / 2.0, 0.04, o["z"] + o["d"] / 2.0)
		instance.material_override = Style.toon_material(Style.color("water"))
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)
		_nodes.append(instance)


## El obstáculo (sin limpiar) que toca un rayo en coordenadas de la casa
## ("" si ninguno). Se prueba contra la caja de cada uno: el más cercano gana.
func pick(origin: Vector3, direction: Vector3) -> String:
	var best := ""
	var best_distance := INF
	for o in Parcel.obstacles:
		if Parcel.cleared.has(o["id"]):
			continue
		var height: float = HEIGHTS.get(o["kind"], 1.0)
		var box := AABB(Vector3(o["x"], 0.0, o["z"]), Vector3(o["w"], height, o["d"]))
		var hit: Variant = box.intersects_ray(origin, direction)
		if hit != null and origin.distance_to(hit) < best_distance:
			best_distance = origin.distance_to(hit)
			best = o["id"]
	return best
