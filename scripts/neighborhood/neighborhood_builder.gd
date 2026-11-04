class_name NeighborhoodBuilder
extends Node3D
## Arma el barrio en 3D (Fase 8A) a partir de data/neighborhood.json: la acera
## de enfrente, farolas, árboles de acera, la plazoleta y las casas de los
## vecinos (siluetas). La calle y la acera de la casa del jugador ya las dibuja
## WorldBuilder; acá solo se suma lo que falta. Todo es decoración local.
##
## Cuelga de WorldBuilder (World). Si el barrio no está activo (parcela de
## pruebas), no hace nada.

var houses: Dictionary = {}     ## id de lote → NeighborHouseView
var lamp_positions: Array[Vector3] = []
var tree_positions: Array[Vector3] = []
var park_node: Node3D
## Fase 8C: vecinos que caminan y autos (ver NeighborhoodLife).
var life: NeighborhoodLife


func _ready() -> void:
	name = "Neighborhood"
	if not NeighborhoodMap.enabled():
		return
	_build_south_sidewalk()
	_build_lamps()
	_build_street_trees()
	_build_park()
	_build_houses()
	life = NeighborhoodLife.new()
	add_child(life)


func _street() -> Dictionary:
	return NeighborhoodMap.data().get("streets", [{}])[0]


## Acera del otro lado de la calle (la de la casa ya existe).
func _build_south_sidewalk() -> void:
	var street := _street()
	var half_road := float(street.get("road_width", 7.0)) / 2.0
	var width := float(street.get("sidewalk_width", 2.5))
	var length := float(street.get("to", 300)) - float(street.get("from", -300))
	var z := NeighborhoodMap.street_z() + half_road + width / 2.0
	var sidewalk := HousePieces.add_box(self, Vector3(0, 0.075, z), Vector3(length, 0.15, width),
		Style.toon_material(Style.color("sidewalk"), null, false))
	sidewalk.name = "SidewalkSouth"


# --- Farolas: poste + lámpara, con MultiMesh (2 llamadas de dibujo para todas) ---

func _build_lamps() -> void:
	var cfg: Dictionary = NeighborhoodMap.data().get("lamps", {})
	var spacing := float(cfg.get("spacing", 24.0))
	var height := float(cfg.get("height", 3.4))
	var street := _street()
	var half_road := float(street.get("road_width", 7.0)) / 2.0
	var center := NeighborhoodMap.street_z()
	var x := float(street.get("from", -300)) + 132.0  # Empieza en el último lote de la izquierda.
	var last := -float(street.get("from", -300)) - 132.0
	while x <= last + 0.01:
		# Una de cada lado de la calle, junto al cordón.
		lamp_positions.append(Vector3(x, 0.0, center - half_road - 0.4))
		lamp_positions.append(Vector3(x, 0.0, center + half_road + 0.4))
		x += spacing
	var pole := CylinderMesh.new()
	pole.top_radius = 0.07
	pole.bottom_radius = 0.1
	pole.height = height
	pole.radial_segments = 6
	pole.rings = 1
	var head := SphereMesh.new()
	head.radius = 0.28
	head.height = 0.56
	head.radial_segments = 8
	head.rings = 4
	var poles := _multimesh("LampPoles", pole, lamp_positions.size(), Style.toon_material(Color("#4a4f5a")))
	var heads := _multimesh("LampHeads", head, lamp_positions.size(),
		Style.toon_material(Color.from_string(cfg.get("light_color", "#fff1b0"), Color.WHITE)))
	for i in lamp_positions.size():
		var p := lamp_positions[i]
		poles.multimesh.set_instance_transform(i, Transform3D(Basis(), p + Vector3(0, height / 2.0 + 0.15, 0)))
		heads.multimesh.set_instance_transform(i, Transform3D(Basis(), p + Vector3(0, height + 0.3, 0)))


# --- Árboles de acera ---

func _build_street_trees() -> void:
	var cfg: Dictionary = NeighborhoodMap.data().get("trees", {})
	var spacing := float(cfg.get("spacing", 12.0))
	var offset := float(cfg.get("offset", 6.0))
	var trunk_h := float(cfg.get("trunk_height", 1.1))
	var radius := float(cfg.get("crown_radius", 1.0))
	var street := _street()
	var half_road := float(street.get("road_width", 7.0)) / 2.0
	var side := float(street.get("sidewalk_width", 2.5))
	var center := NeighborhoodMap.street_z()
	var player := NeighborhoodMap.lot_rect(NeighborhoodMap.PLAYER_LOT)
	var x := float(street.get("from", -300)) + 132.0 + offset
	var last := -float(street.get("from", -300)) - 132.0
	while x <= last:
		# En el pasto, pegados a la acera (no en ella). Ni frente a la parcela
		# del jugador (queda libre) ni frente a la plazoleta.
		var skip_north := x > player.position.x - 1.0 and x < player.end.x + 1.0
		if not skip_north:
			tree_positions.append(Vector3(x, 0.0, center - half_road - side - 0.8))
		var park := NeighborhoodMap.lot_rect("park")
		if not (x > park.position.x and x < park.end.x):
			tree_positions.append(Vector3(x, 0.0, center + half_road + side + 0.8))
		x += spacing
	_add_trees("StreetTrees", tree_positions, trunk_h, radius)


## Troncos y copas en MultiMesh (mismas formas simples que el bosque).
func _add_trees(node_name: String, spots: Array[Vector3], trunk_h: float, radius: float) -> void:
	if spots.is_empty():
		return
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.12
	trunk.bottom_radius = 0.18
	trunk.height = trunk_h
	trunk.radial_segments = 6
	trunk.rings = 1
	var crown := SphereMesh.new()
	crown.radius = radius
	crown.height = radius * 2.0
	crown.radial_segments = 8
	crown.rings = 4
	var trunks := _multimesh(node_name + "Trunks", trunk, spots.size(), Style.toon_material(Style.color("trunk")))
	var crowns := _multimesh(node_name + "Crowns", crown, spots.size(), Style.toon_material(Style.color("leaf")))
	for i in spots.size():
		trunks.multimesh.set_instance_transform(i, Transform3D(Basis(), spots[i] + Vector3(0, trunk_h / 2.0, 0)))
		crowns.multimesh.set_instance_transform(i, Transform3D(Basis(), spots[i] + Vector3(0, trunk_h + radius * 0.7, 0)))


# --- Plazoleta: sendero, fuente, bancas y árboles ---

func _build_park() -> void:
	var cfg: Dictionary = NeighborhoodMap.data().get("park", {})
	var rect := NeighborhoodMap.lot_rect("park")
	var center := Vector3(rect.get_center().x, 0.0, rect.get_center().y)
	park_node = Node3D.new()
	park_node.name = "Park"
	add_child(park_node)
	var path_mat := Style.toon_material(Style.color("sidewalk"), null, false)
	# Dos senderos en cruz y una plaza redonda en el medio.
	HousePieces.add_box(park_node, center + Vector3(0, 0.05, 0), Vector3(rect.size.x, 0.1, 2.0), path_mat)
	HousePieces.add_box(park_node, center + Vector3(0, 0.05, 0), Vector3(2.0, 0.1, rect.size.y), path_mat)
	var radius := float(cfg.get("fountain_radius", 2.0))
	var basin := CylinderMesh.new()
	basin.top_radius = radius
	basin.bottom_radius = radius
	basin.height = 0.6
	basin.radial_segments = 14
	var basin_node := MeshInstance3D.new()
	basin_node.mesh = basin
	basin_node.material_override = Style.toon_material(Color("#c9c4b6"))
	basin_node.position = center + Vector3(0, 0.3, 0)
	park_node.add_child(basin_node)
	var water := CylinderMesh.new()
	water.top_radius = radius * 0.85
	water.bottom_radius = radius * 0.85
	water.height = 0.1
	water.radial_segments = 14
	var water_node := MeshInstance3D.new()
	water_node.mesh = water
	water_node.material_override = Style.toon_material(Style.color("water"))
	water_node.position = center + Vector3(0, 0.62, 0)
	park_node.add_child(water_node)
	# Bancas alrededor de la fuente.
	var benches := int(cfg.get("benches", 4))
	var wood := Style.toon_material(Style.color("fence"))
	for i in benches:
		var angle := TAU * i / benches + PI / 4.0
		var spot := center + Vector3(cos(angle), 0, sin(angle)) * (radius + 3.2)
		var bench := HousePieces.add_box(park_node, spot + Vector3(0, 0.3, 0), Vector3(1.8, 0.12, 0.6), wood)
		bench.rotation.y = -angle + PI / 2.0
		var back := HousePieces.add_box(park_node, spot + Vector3(0, 0.6, 0), Vector3(1.8, 0.4, 0.1), wood)
		back.rotation.y = bench.rotation.y
		back.position += Vector3(cos(angle), 0, sin(angle)) * 0.25
	# Árboles en las esquinas de la plazoleta.
	var rng := NeighborhoodMap.rng_for("park")
	var trees: Array[Vector3] = []
	for i in int(cfg.get("trees", 6)):
		trees.append(center + Vector3(rng.randf_range(-rect.size.x / 2.0 + 3.0, rect.size.x / 2.0 - 3.0), 0,
			rng.randf_range(-rect.size.y / 2.0 + 3.0, rect.size.y / 2.0 - 3.0)))
	# Que no caigan encima de los senderos en cruz.
	var cleaned: Array[Vector3] = []
	for t in trees:
		if absf(t.x - center.x) > 2.5 and absf(t.z - center.z) > 2.5:
			cleaned.append(t)
	_add_trees("ParkTrees", cleaned, 1.3, 1.3)
	var title := Label3D.new()
	title.text = str(NeighborhoodMap.lot("park").get("name", "Plazoleta"))
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title.pixel_size = 0.012
	title.font_size = 56
	title.outline_size = 14
	title.outline_modulate = Color("#2b2233")
	title.no_depth_test = true
	title.position = center + Vector3(0, 4.5, 0)
	park_node.add_child(title)


# --- Casas de los vecinos ---

func _build_houses() -> void:
	var holder := Node3D.new()
	holder.name = "Houses"
	add_child(holder)
	for l in NeighborhoodMap.house_lots():
		var house := NeighborHouseView.new()
		holder.add_child(house)  # Primero al árbol y después setup (la vista necesita estar adentro).
		house.setup(l["id"])
		houses[l["id"]] = house
		_build_front_path(holder, l["id"])


## Caminito de la puerta a la acera.
func _build_front_path(parent: Node3D, lot_id: String) -> void:
	var door := NeighborhoodMap.door_point(lot_id, 0.6)
	var walk := NeighborhoodMap.sidewalk_point(lot_id)
	var length := absf(walk.z - door.z)
	var mid := Vector3(door.x, 0.04, (door.z + walk.z) / 2.0)
	HousePieces.add_box(parent, mid, Vector3(1.2, 0.08, length), Style.toon_material(Style.color("sidewalk"), null, false))


func house(lot_id: String) -> NeighborHouseView:
	return houses.get(lot_id)


func _multimesh(node_name: String, mesh: Mesh, count: int, material: Material) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = count
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multi
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance
