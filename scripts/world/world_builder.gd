class_name WorldBuilder
extends Node3D
## El mundo alrededor de la casa (Pulido 2B): terreno del mismo color en toda
## la parcela, calle con acera, bosque atrás y a los costados, casas de
## vecinos de decoración, niebla en los bordes y vida (autos y gente).
##
## Todo se arma con código a partir de data/world.json y data/style.json, y
## del tamaño de la parcela (HouseGrid.LOT_SIZE): cuando la parcela crece, el
## mundo la sigue. Es decoración: no toca el servidor ni la casa.
##
## Coordenadas: la parcela está centrada en el origen (la casa vive en
## House, que main.gd pone en -LOT/2). La calle queda al frente (+Z).

const CONFIG_PATH := "res://data/world.json"

var config: Dictionary = {}
var life: WorldLife
## Dónde está la calle (para quien necesite saberlo: personajes, servicios).
var lot_half := Vector2(16, 16)
var sidewalk_z := 17.25
var road_z := 22.0

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	config = parsed if parsed is Dictionary else {}
	_rng.seed = int(config.get("seed", 7))
	lot_half = Vector2(HouseGrid.LOT_SIZE) / 2.0
	var street: Dictionary = config.get("street", {})
	var sidewalk_width := float(street.get("sidewalk_width", 2.5))
	var road_width := float(street.get("road_width", 7.0))
	sidewalk_z = lot_half.y + sidewalk_width / 2.0
	road_z = lot_half.y + sidewalk_width + road_width / 2.0
	_build_terrain(street)
	_build_forest()
	_build_neighbors()
	# Hojitas que caen despacio sobre la parcela (partículas, solo decoración).
	if bool(config.get("life", {}).get("particles", true)):
		Fx.falling_leaves(self, Vector3(0, 8.0, 0), Vector3(lot_half.x, 0.5, lot_half.y), 14)
	life = WorldLife.new()
	life.name = "Life"
	life.config = config.get("life", {})
	life.road_z = road_z
	life.sidewalk_z = sidewalk_z
	life.road_width = road_width
	life.length = float(street.get("length", 600.0))
	add_child(life)
	_apply_environment()


## Luz, ambiente y niebla según data/style.json.
func _apply_environment() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var env_node := parent.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var sun := parent.get_node_or_null("Sun") as DirectionalLight3D
	if env_node != null:
		Style.apply_world(sun, env_node.environment)
	elif sun != null:
		Style.apply_world(sun, null)


# --- Terreno y calle ---

func _build_terrain(street: Dictionary) -> void:
	var size := float(config.get("terrain_size", 900))
	# El suelo es de un solo color: la parcela NO se ve más clara (Pulido 2B).
	_add_plane("Terrain", Vector2(size, size), Vector3(0, 0, 0), Style.color("ground"))
	var sidewalk_width := float(street.get("sidewalk_width", 2.5))
	var road_width := float(street.get("road_width", 7.0))
	var length := float(street.get("length", 600.0))
	var sidewalk := HousePieces.add_box(self, Vector3(0, 0.075, sidewalk_z), Vector3(length, 0.15, sidewalk_width),
		Style.toon_material(Style.color("sidewalk"), null, false))
	sidewalk.name = "Sidewalk"
	_add_plane("Road", Vector2(length, road_width), Vector3(0, 0.02, road_z), Style.color("road"))
	_add_plane("RoadLine", Vector2(length, 0.2), Vector3(0, 0.03, road_z), Style.color("road_line"))


func _add_plane(node_name: String, size: Vector2, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = Style.toon_material(color, null, false)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance


# --- Bosque (MultiMesh: miles de árboles en pocas llamadas de dibujo) ---

func _build_forest() -> void:
	var forest: Dictionary = config.get("forest", {})
	var depth := float(forest.get("depth", 55.0))
	var gap := float(forest.get("gap", 9.0))
	var spots: Array[Vector3] = []
	var length := float(config.get("street", {}).get("length", 600.0)) / 2.0
	var half_wide := minf(length, 130.0)
	# Atrás: una franja ancha detrás de la parcela.
	for i in int(forest.get("back_trees", 260)):
		spots.append(Vector3(_rng.randf_range(-half_wide, half_wide),
			0, -lot_half.y - gap - _rng.randf() * depth))
	# A los costados: franjas a izquierda y derecha, hasta la acera.
	for side in [-1.0, 1.0]:
		for i in int(forest.get("side_trees", 160)):
			spots.append(Vector3(side * (lot_half.x + gap + _rng.randf() * depth),
				0, _rng.randf_range(-lot_half.y - gap, lot_half.y + 1.0)))
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.14
	trunk_mesh.bottom_radius = 0.2
	trunk_mesh.height = float(forest.get("trunk_height", 1.3))
	trunk_mesh.radial_segments = 6
	trunk_mesh.rings = 1
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = float(forest.get("crown_radius", 1.1))
	crown_mesh.height = crown_mesh.radius * 2.0
	crown_mesh.radial_segments = 8
	crown_mesh.rings = 4
	var trunks := _multimesh("ForestTrunks", trunk_mesh, spots.size(), Style.color("trunk"))
	var crowns_a := _multimesh("ForestLeaves", crown_mesh, (spots.size() + 1) / 2, Style.color("leaf"))
	var crowns_b := _multimesh("ForestLeavesDark", crown_mesh, spots.size() / 2, Style.color("leaf_dark"))
	var variation := float(forest.get("size_variation", 0.45))
	var count_a := 0
	var count_b := 0
	for i in spots.size():
		var scale_factor := 1.0 + _rng.randf_range(-variation, variation)
		var base := spots[i]
		var trunk_height := trunk_mesh.height * scale_factor
		var t := Transform3D(Basis().scaled(Vector3.ONE * scale_factor), base + Vector3(0, trunk_height / 2.0, 0))
		trunks.multimesh.set_instance_transform(i, t)
		var crown := Transform3D(Basis().scaled(Vector3.ONE * scale_factor),
			base + Vector3(0, trunk_height + crown_mesh.radius * scale_factor * 0.7, 0))
		if i % 2 == 0:
			crowns_a.multimesh.set_instance_transform(count_a, crown)
			count_a += 1
		else:
			crowns_b.multimesh.set_instance_transform(count_b, crown)
			count_b += 1


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
	return instance


# --- Casas de vecinos (decoración estática) ---

func _build_neighbors() -> void:
	var neighbors: Dictionary = config.get("neighbors", {})
	var count := int(neighbors.get("count", 7))
	var spacing := float(neighbors.get("spacing", 24.0))
	var back := float(neighbors.get("distance_back", 20.0))
	var width_range: Array = neighbors.get("width", [7.0, 11.0])
	var depth_range: Array = neighbors.get("depth", [6.0, 9.0])
	var walls := [Style.color("neighbor_wall"), Color("#dfe9f5"), Color("#f4d9d0"), Color("#e6f0d4")]
	var roofs := [Style.color("neighbor_roof"), Color("#5b8fd6"), Color("#8a6b5a"), Color("#6a8f6a")]
	var holder := Node3D.new()
	holder.name = "Neighbors"
	add_child(holder)
	for i in count:
		var width := _rng.randf_range(width_range[0], width_range[1])
		var depth := _rng.randf_range(depth_range[0], depth_range[1])
		var x := (i - (count - 1) / 2.0) * spacing + _rng.randf_range(-2.0, 2.0)
		var z := -lot_half.y - back - depth
		holder.add_child(_neighbor_house(Vector2(width, depth), Vector3(x - width / 2.0, 0, z),
			walls[i % walls.size()], roofs[(i * 3) % roofs.size()]))


## Una casita simple: caja, techo a dos aguas, puerta y ventanas al frente.
func _neighbor_house(size: Vector2, origin: Vector3, wall: Color, roof: Color) -> Node3D:
	var house := Node3D.new()
	house.position = origin
	var wall_height := HouseGrid.WALL_HEIGHT
	HousePieces.add_box(house, Vector3(size.x / 2.0, wall_height / 2.0, size.y / 2.0),
		Vector3(size.x, wall_height, size.y), Style.toon_material(wall))
	# Frente hacia la calle (+Z): puerta y dos ventanas.
	var front := size.y + 0.04
	HousePieces.add_box(house, Vector3(size.x / 2.0, 1.0, front), Vector3(0.9, 2.0, 0.1), Style.toon_material(Color("#8a5a3a")))
	for side in [-1.0, 1.0]:
		HousePieces.add_box(house, Vector3(size.x / 2.0 + side * size.x * 0.3, 1.5, front),
			Vector3(1.0, 0.9, 0.1), Style.toon_material(Color("#a9d6f5")))
	var roof_node := HousePieces.build_roof({"item": "roof_basic", "rect": [0, 0, int(round(size.x)), int(round(size.y))]}, wall)
	if roof_node != null:
		# build_roof usa el color del catálogo: se pinta del color del vecino.
		house.add_child(roof_node)
		_tint(roof_node, roof)
		roof_node.position.x = size.x / 2.0
		roof_node.position.z = size.y / 2.0
	return house


func _tint(node: Node, color: Color) -> void:
	if node is MeshInstance3D and node.mesh != null and node.mesh.get_surface_count() > 0:
		node.set_surface_override_material(0, Style.toon_material(color))
	for child in node.get_children():
		_tint(child, color)
