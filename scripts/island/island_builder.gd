class_name IslandBuilder
extends RefCounted
## Arma la isla estática (Isla 1A): suelo con zonas, calles radiales y circulares,
## parque con lago, glorieta y plaza, anillo de comercios (solo decorados, apagados),
## playa con sombrillas y palmeras, muelle, volcán de fondo, mar y los lotes con su
## marcador. Todo con figuras simples y TODO sale de data/island.json.
##
## Para gastar pocas llamadas de dibujo, casi todo se junta en pocas mallas con color
## por vértice (ver IslandMeshKit): suelo (1), detalles (1), marcadores (1), mar (1),
## volcán (2) y la vegetación en trozos de MultiMesh (1 por trozo).
##
## build() devuelve {"scenery": Node3D (mar y volcán: siempre se ven),
## "detail": Node3D (todo lo demás de la isla), "tree_chunks": [{"node", "center"}],
## "smoke": Node3D o null, "tree_count": int, "markers": MeshInstance3D o null}.

## Alturas de las capas planas del suelo (separadas para que no se "peleen" de lejos).
const Y_SAND := 0.04
const Y_PARK := 0.04
const Y_SIDEWALK := 0.06
const Y_LOT := 0.07
const Y_PLAZA := 0.09
const Y_ROAD := 0.1
const Y_LAKE_EDGE := 0.09
const Y_LAKE := 0.13


static func build(lots: Array, options := {}) -> Dictionary:
	var detail := Node3D.new()
	detail.name = "Detail"
	var scenery := Node3D.new()
	scenery.name = "Scenery"
	detail.add_child(_mesh_node("Ground", ground_kit(lots).build()))
	detail.add_child(_mesh_node("Props", props_kit().build()))
	var markers := _mesh_node("Markers", markers_kit(lots).build())
	if markers != null:
		detail.add_child(markers)
	var chunks := _tree_chunks(lots)
	var tree_count := 0
	for chunk in chunks:
		detail.add_child(chunk["node"])
		tree_count += int(chunk["count"])
	scenery.add_child(_sea())
	var volcano := _volcano(bool(options.get("smoke", true)))
	scenery.add_child(volcano["node"])
	return {
		"scenery": scenery, "detail": detail, "tree_chunks": chunks, "smoke": volcano["smoke"],
		"tree_count": tree_count, "markers": markers,
	}


static func _mesh_node(node_name: String, mesh: ArrayMesh) -> MeshInstance3D:
	if mesh == null:
		return null
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.material_override = IslandMaterials.blocks(false)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


# --- Suelo ---

static func ground_kit(lots: Array) -> IslandMeshKit:
	var kit := IslandMeshKit.new()
	var island := IslandData.section("island")
	var radius := float(island.get("radius", 350.0))
	var segments := int(island.get("ring_segments", 96))
	# Isla de pasto y arena alrededor.
	kit.add_disc(Vector2.ZERO, radius, 0.0, segments, IslandData.color("ground"))
	var sand := IslandData.color("sand")
	kit.add_annulus(radius - float(island.get("sand_width", 22.0)), radius, Y_SAND, segments, sand)
	# Playa ancha del lado del muelle (el sur).
	var span := float(island.get("south_sand_span", 130.0))
	var pier := IslandData.section("zones").get("pier", {}) as Dictionary
	var center_angle := float(pier.get("angle", 90.0))
	kit.add_annulus(radius - float(island.get("south_sand_width", 40.0)), radius, Y_SAND * 1.5, segments, sand,
		center_angle - span / 2.0, center_angle + span / 2.0)
	# Parque, plaza y lago.
	var zones := IslandData.section("zones")
	var park: Dictionary = zones.get("park", {})
	var park_radius := float(park.get("radius", 34.0))
	kit.add_disc(Vector2.ZERO, park_radius, Y_PARK, segments, IslandData.color("park"))
	var plaza: Dictionary = park.get("plaza", {})
	if not plaza.is_empty():
		kit.add_disc(_xz(plaza["center"]), float(plaza["radius"]), Y_PLAZA, 40, IslandData.color("plaza"))
	var lake: Dictionary = park.get("lake", {})
	if not lake.is_empty():
		kit.add_disc(_xz(lake["center"]), float(lake["radius"]) + 1.4, Y_LAKE_EDGE, 40, IslandData.color("lake_edge"))
		kit.add_disc(_xz(lake["center"]), float(lake["radius"]), Y_LAKE, 40, IslandData.color("lake"))
	# Piso de los comercios (anillo pegado al parque).
	var commerce: Dictionary = zones.get("commerce", {})
	if not commerce.is_empty():
		kit.add_annulus(park_radius, float(commerce.get("outer", 47.0)) + 2.0, Y_PARK, segments, IslandData.color("commerce_floor"))
	# Calles: primero la vereda (más ancha) y encima el asfalto.
	var streets := IslandData.section("streets")
	var sidewalk := float(streets.get("sidewalk", 2.0))
	var road_color := IslandData.color("road")
	var side_color := IslandData.color("road_edge")
	for ring in streets.get("rings", []):
		var arc: Array = ring.get("arc", [0, 360])
		var r := float(ring["radius"])
		var half := float(ring["width"]) / 2.0
		kit.add_annulus(r - half - sidewalk, r + half + sidewalk, Y_SIDEWALK, segments, side_color, float(arc[0]), float(arc[1]))
		kit.add_annulus(r - half, r + half, Y_ROAD, segments, road_color, float(arc[0]), float(arc[1]))
	for street in streets.get("radial", []):
		var direction := IslandData.polar(float(street["angle"]), 1.0)
		var from := Vector2(direction.x, direction.z) * float(street["from"])
		var to := Vector2(direction.x, direction.z) * float(street["to"])
		var w := float(street["width"])
		kit.add_strip(from, to, w + sidewalk * 2.0, Y_SIDEWALK, side_color)
		kit.add_strip(from, to, w, Y_ROAD, road_color)
	# La avenida sigue hasta la arena (donde empieza el muelle).
	for street in streets.get("radial", []):
		if int(round(float(street["angle"]))) == int(round(center_angle)):
			var direction := IslandData.polar(float(street["angle"]), 1.0)
			kit.add_strip(Vector2(direction.x, direction.z) * float(street["to"]), Vector2(direction.x, direction.z) * (radius - 6.0),
				float(street["width"]), Y_ROAD, road_color)
	# Terreno de cada lote.
	for l in lots:
		var key := "lot_" + str(l.get("state", "npc"))
		var side := IslandData.lot_side(l)
		kit.add_ground_rect(IslandData.lot_center(l) + Vector3(0, Y_LOT, 0), Vector2(side, side), IslandData.lot_yaw(l),
			IslandData.color(key, IslandData.color("lot_npc")))
	return kit


static func _xz(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))


# --- Detalles: parque, comercios, playa y muelle ---

static func props_kit() -> IslandMeshKit:
	var kit := IslandMeshKit.new()
	var zones := IslandData.section("zones")
	var rng := IslandData.rng_for("props")
	var park: Dictionary = zones.get("park", {})
	_add_park_props(kit, park, rng)
	var commerce: Dictionary = zones.get("commerce", {})
	if not commerce.is_empty():
		_add_commerce(kit, commerce, rng)
	_add_beach_props(kit, zones.get("beach", {}), rng)
	_add_pier(kit, zones.get("pier", {}))
	return kit


static func _at(position: Vector3) -> Transform3D:
	return Transform3D(Basis.IDENTITY, position)


static func _add_park_props(kit: IslandMeshKit, park: Dictionary, rng: RandomNumberGenerator) -> void:
	# Glorieta: 6 postes, piso y techo cónico.
	var gazebo: Dictionary = park.get("gazebo", {})
	if not gazebo.is_empty():
		var c := _xz(gazebo["center"])
		var r := float(gazebo["radius"])
		var h := float(gazebo.get("height", 4.4))
		kit.add_frustum(_at(Vector3(c.x, 0.1, c.y)), r, r, 0.25, 10, IslandData.color("plaza"))
		for i in 6:
			var a := TAU * float(i) / 6.0
			kit.add_frustum(_at(Vector3(c.x + cos(a) * (r - 0.5), 0.3, c.y + sin(a) * (r - 0.5))), 0.16, 0.16, h - 1.2, 6,
				IslandData.color("bench"))
		kit.add_frustum(_at(Vector3(c.x, h - 1.0, c.y)), r + 0.6, 0.0, 1.8, 10, IslandData.color("gazebo_roof"))
	# Fuente en el centro de la plaza.
	var plaza: Dictionary = park.get("plaza", {})
	if not plaza.is_empty():
		var p := _xz(plaza["center"])
		kit.add_frustum(_at(Vector3(p.x, 0.1, p.y)), 1.8, 1.8, 0.6, 10, IslandData.color("lake_edge"), IslandData.color("lake"))
		kit.add_frustum(_at(Vector3(p.x, 0.7, p.y)), 0.3, 0.3, 1.4, 6, IslandData.color("lake_edge"))
	# Bancas alrededor del parque.
	var benches := int(park.get("benches", 6))
	var park_radius := float(park.get("radius", 34.0))
	for i in benches:
		var a := TAU * (float(i) + 0.5) / maxi(1, benches)
		var pos := Vector3(cos(a) * (park_radius - 4.0), 0.0, sin(a) * (park_radius - 4.0))
		var basis := Basis(Vector3.UP, -a + PI / 2.0)
		kit.add_box(Transform3D(basis, pos + Vector3(0, 0.4, 0)), Vector3(2.0, 0.12, 0.6), IslandData.color("bench"))
		kit.add_box(Transform3D(basis, pos + basis * Vector3(0, 0.75, 0.25)), Vector3(2.0, 0.5, 0.1), IslandData.color("bench"))


## Comercios decorados (la fachada está apagada: cartel oscuro y sin luces).
static func _add_commerce(kit: IslandMeshKit, commerce: Dictionary, rng: RandomNumberGenerator) -> void:
	var count := int(commerce.get("count", 18))
	var inner := float(commerce.get("inner", 37.0))
	var depth := float(commerce.get("depth", 8.0))
	var walls := IslandData.color_list("shop_walls")
	var awnings := IslandData.color_list("shop_awnings")
	var streets := IslandData.section("streets").get("radial", []) as Array
	for i in count:
		var angle := 360.0 * float(i) / count + 360.0 / count / 2.0
		var r_mid := inner + depth / 2.0
		# Deja libres las calles radiales.
		var blocked := false
		for street in streets:
			var diff := absf(fposmod(angle - float(street["angle"]) + 180.0, 360.0) - 180.0)
			if diff < rad_to_deg((float(street["width"]) / 2.0 + 7.0) / r_mid):
				blocked = true
		if blocked:
			continue
		var width := rng.randf_range(float(commerce.get("min_width", 9.0)), float(commerce.get("max_width", 13.0)))
		var height := rng.randf_range(float(commerce.get("min_height", 4.5)), float(commerce.get("max_height", 8.5)))
		var pos := IslandData.polar(angle, r_mid)
		# El frente de cada comercio mira al parque (al centro).
		var yaw := atan2(-cos(deg_to_rad(angle)), -sin(deg_to_rad(angle)))
		var basis := Basis(Vector3.UP, yaw)
		var wall_color := walls[rng.randi_range(0, walls.size() - 1)]
		var awning_color := awnings[rng.randi_range(0, awnings.size() - 1)]
		kit.add_box(Transform3D(basis, pos + Vector3(0, height / 2.0, 0)), Vector3(width, height, depth), wall_color)
		kit.add_box(Transform3D(basis, pos + Vector3(0, height + 0.15, 0)), Vector3(width + 0.4, 0.3, depth + 0.4), awning_color.darkened(0.2))
		var front := basis * Vector3(0, 0, depth / 2.0 + 0.9)
		kit.add_box(Transform3D(basis, pos + front + Vector3(0, 3.1, 0)), Vector3(width - 1.0, 0.18, 2.0), awning_color)
		var sign_pos := basis * Vector3(0, 0, depth / 2.0 + 0.06)
		kit.add_box(Transform3D(basis, pos + sign_pos + Vector3(0, height - 1.0, 0)), Vector3(width * 0.6, 0.9, 0.12), IslandData.color("shop_off"))
		kit.add_box(Transform3D(basis, pos + sign_pos + Vector3(0, 1.3, 0)), Vector3(width * 0.45, 2.3, 0.12), IslandData.color("shop_off"))


static func _add_beach_props(kit: IslandMeshKit, beach: Dictionary, rng: RandomNumberGenerator) -> void:
	var island := IslandData.section("island")
	var radius := float(island.get("radius", 350.0))
	var pier := IslandData.section("zones").get("pier", {}) as Dictionary
	var center_angle := float(pier.get("angle", 90.0))
	var span := float(island.get("south_sand_span", 130.0))
	var sand_width := float(island.get("south_sand_width", 40.0))
	var colors := IslandData.color_list("umbrella")
	for i in int(beach.get("umbrellas", 10)):
		var angle := center_angle + rng.randf_range(-span / 2.0 + 6.0, span / 2.0 - 6.0)
		if absf(angle - center_angle) < 8.0:
			angle += 14.0  # Lejos del muelle.
		var pos := IslandData.polar(angle, radius - rng.randf_range(6.0, sand_width * 0.7))
		kit.add_frustum(_at(pos), 0.06, 0.06, 2.2, 5, IslandData.color("pier_post"))
		kit.add_frustum(_at(pos + Vector3(0, 2.0, 0)), 1.6, 0.0, 0.7, 8, colors[i % colors.size()])


static func _add_pier(kit: IslandMeshKit, pier: Dictionary) -> void:
	if pier.is_empty():
		return
	var island := IslandData.section("island")
	var radius := float(island.get("radius", 350.0))
	var angle := float(pier.get("angle", 90.0))
	var length := float(pier.get("length", 90.0))
	var width := float(pier.get("width", 9.0))
	var start := radius - 6.0
	# El muelle sale del borde de la isla hacia afuera, a lo largo de `angle`.
	var dir := IslandData.polar(angle, 1.0)
	var basis := Basis(Vector3.UP, atan2(dir.x, dir.z))
	var mid := dir * (start + length / 2.0)
	kit.add_box(Transform3D(basis, mid + Vector3(0, 0.45, 0)), Vector3(width, 0.3, length), IslandData.color("pier"))
	var post_every := float(pier.get("post_every", 6.0))
	var steps := int(length / post_every)
	for i in steps + 1:
		var along := start + post_every * i
		for side in [-1.0, 1.0]:
			var pos := dir * along + basis * Vector3(side * (width / 2.0 - 0.3), -0.8, 0)
			kit.add_frustum(_at(pos), 0.25, 0.25, 1.7, 6, IslandData.color("pier_post"))
	var platform := float(pier.get("end_platform", 16.0))
	kit.add_box(Transform3D(basis, dir * (start + length) + Vector3(0, 0.5, 0)), Vector3(platform, 0.3, platform * 0.75), IslandData.color("pier"))


# --- Marcadores de lotes ---

## Un cartel en el frente de cada lote libre ("free") o todavía cerrado ("future").
static func markers_kit(lots: Array) -> IslandMeshKit:
	var kit := IslandMeshKit.new()
	for l in lots:
		var state := str(l.get("state", "npc"))
		if state != "free" and state != "future":
			continue
		var side := IslandData.lot_side(l)
		var pos := IslandData.lot_to_world(l, Vector3(0, 0, side / 2.0 - 1.5))
		var basis := Basis(Vector3.UP, IslandData.lot_yaw(l))
		var color := IslandData.color("marker" if state == "free" else "marker_future")
		kit.add_frustum(_at(pos), 0.12, 0.12, 2.3, 5, IslandData.color("pier_post"))
		kit.add_box(Transform3D(basis, pos + Vector3(0, 2.0, 0)), Vector3(1.8, 1.0, 0.12), color)
		# Cuatro estacas en las esquinas para que se vea el tamaño del terreno.
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var corner := IslandData.lot_to_world(l, Vector3(sx * (side / 2.0 - 0.6), 0.0, sz * (side / 2.0 - 0.6)))
				kit.add_frustum(_at(corner), 0.1, 0.0, 1.0, 4, color)
	return kit


# --- Vegetación (MultiMesh por trozos) ---

static func tree_mesh() -> ArrayMesh:
	var kit := IslandMeshKit.new()
	var crowns := IslandData.color_list("crowns")
	kit.add_frustum(Transform3D.IDENTITY, 0.28, 0.2, 1.4, 6, IslandData.color("trunk"))
	kit.add_frustum(_at(Vector3(0, 1.0, 0)), 1.7, 0.0, 2.3, 7, crowns[0])
	kit.add_frustum(_at(Vector3(0, 2.4, 0)), 1.25, 0.0, 1.9, 7, crowns[1 % crowns.size()])
	return kit.build()


## Posiciones de todos los árboles: [{"pos": Vector3, "scale": float, "yaw": float}].
static func tree_points(lots: Array) -> Array:
	var rng := IslandData.rng_for("trees")
	var points: Array = []
	var island := IslandData.section("island")
	var radius := float(island.get("radius", 350.0))
	var zones := IslandData.section("zones")
	var streets := IslandData.section("streets")
	var spacing := float(streets.get("tree_spacing", 16.0))
	# A los lados de las calles radiales (sobre la vereda).
	for street in streets.get("radial", []):
		var half := float(street["width"]) / 2.0 + 1.0
		var dir := IslandData.polar(float(street["angle"]), 1.0)
		var normal := Vector3(-dir.z, 0.0, dir.x)
		var r := float(street["from"]) + 14.0
		while r < float(street["to"]) - 10.0:
			for side in [-1.0, 1.0]:
				var pos := dir * r + normal * half * side
				# No dentro de la plaza ni del lago.
				points.append({"pos": pos, "scale": rng.randf_range(0.8, 1.15), "yaw": rng.randf() * TAU})
			r += spacing
	# Parque: al azar, lejos del lago, la plaza y la glorieta.
	var park: Dictionary = zones.get("park", {})
	var avoid: Array = []
	for key in ["lake", "plaza", "gazebo"]:
		if park.has(key):
			var entry: Dictionary = park[key]
			avoid.append([_xz(entry["center"]), float(entry["radius"]) + 4.0])
	var tries := 0
	var planted := 0
	while planted < int(park.get("trees", 20)) and tries < 400:
		tries += 1
		var a := rng.randf() * TAU
		var rr := sqrt(rng.randf()) * (float(park.get("radius", 34.0)) - 3.0)
		var p := Vector2(cos(a) * rr, sin(a) * rr)
		var free := true
		for item in avoid:
			if p.distance_to(item[0]) < float(item[1]):
				free = false
		if free:
			points.append({"pos": Vector3(p.x, 0.0, p.y), "scale": rng.randf_range(0.9, 1.3), "yaw": rng.randf() * TAU})
			planted += 1
	# Jardines: árboles en el fondo de los lotes ocupados y libres.
	var garden: Array = IslandData.section("houses").get("garden_trees", [2, 4])
	for l in lots:
		if str(l.get("state", "npc")) == "future":
			continue
		var lot_rng := IslandData.rng_for("garden:" + str(l["id"]))
		var side := IslandData.lot_side(l)
		for i in lot_rng.randi_range(int(garden[0]), int(garden[1])):
			var local := Vector3(lot_rng.randf_range(-side / 2.0 + 2.5, side / 2.0 - 2.5), 0.0, lot_rng.randf_range(-side / 2.0 + 2.5, -2.0))
			points.append({"pos": IslandData.lot_to_world(l, local), "scale": lot_rng.randf_range(0.8, 1.2), "yaw": lot_rng.randf() * TAU})
	# Palmeras (los mismos árboles, más chicos) en la playa, lejos del muelle.
	var beach: Dictionary = zones.get("beach", {})
	var pier := zones.get("pier", {}) as Dictionary
	var pier_angle := float(pier.get("angle", 90.0))
	for i in int(beach.get("palms", 36)):
		var angle := rng.randf() * 360.0
		if absf(fposmod(angle - pier_angle + 180.0, 360.0) - 180.0) < 9.0:
			continue
		var pos := IslandData.polar(angle, radius - rng.randf_range(5.0, 14.0))
		points.append({"pos": pos, "scale": rng.randf_range(0.6, 0.9), "yaw": rng.randf() * TAU})
	return points


## Los árboles repartidos en trozos cuadrados; cada trozo es un MultiMeshInstance3D que se
## muestra u oculta según la distancia a la cámara (streaming por radio).
static func _tree_chunks(lots: Array) -> Array:
	var chunk_size := float(IslandData.lod_config().get("vegetation_chunk", 140.0))
	var groups: Dictionary = {}
	for p in tree_points(lots):
		var pos: Vector3 = p["pos"]
		var key := Vector2i(floori(pos.x / chunk_size), floori(pos.z / chunk_size))
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(p)
	var mesh := tree_mesh()
	var result: Array = []
	var keys: Array = groups.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	for key in keys:
		var list: Array = groups[key]
		var center := Vector3((key.x + 0.5) * chunk_size, 0.0, (key.y + 0.5) * chunk_size)
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = mesh
		multimesh.instance_count = list.size()
		for i in list.size():
			var scale_value: float = list[i]["scale"]
			var basis := Basis(Vector3.UP, float(list[i]["yaw"])).scaled(Vector3(scale_value, scale_value, scale_value))
			multimesh.set_instance_transform(i, Transform3D(basis, (list[i]["pos"] as Vector3) - center))
		var node := MultiMeshInstance3D.new()
		node.name = "Trees_%d_%d" % [key.x, key.y]
		node.multimesh = multimesh
		node.material_override = IslandMaterials.blocks(false)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.position = center
		result.append({"node": node, "center": center, "count": list.size()})
	return result


# --- Mar y volcán ---

static func _sea() -> MeshInstance3D:
	var island := IslandData.section("island")
	var plane := PlaneMesh.new()
	var size := float(island.get("sea_size", 3600.0))
	plane.size = Vector2(size, size)
	var node := MeshInstance3D.new()
	node.name = "Sea"
	node.mesh = plane
	node.material_override = Style.toon_material(IslandData.color("sea"), null, false)
	node.position = Vector3(0.0, float(island.get("sea_level", -0.35)), 0.0)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


## El volcán de fondo (escenario: no se construye encima). Devuelve {"node", "smoke"}.
static func _volcano(with_smoke: bool) -> Dictionary:
	var cfg: Dictionary = IslandData.section("zones").get("volcano", {})
	var root := Node3D.new()
	root.name = "Volcano"
	var c := _xz(cfg.get("center", [0, -600]))
	root.position = Vector3(c.x, 0.0, c.y)
	var base := float(cfg.get("base_radius", 170.0))
	var height := float(cfg.get("height", 210.0))
	var top := float(cfg.get("crater_radius", 34.0))
	var segments := int(cfg.get("segments", 20))
	var kit := IslandMeshKit.new()
	kit.add_frustum(Transform3D.IDENTITY, base, top, height, segments, IslandData.color("volcano"), IslandData.color("lava"))
	# Falda más oscura abajo (roca) un poquito más ancha que la montaña.
	var dark_height := height * 0.35
	var dark_top := base - (base - top) * 0.35
	kit.add_frustum(Transform3D.IDENTITY, base + 0.6, dark_top + 0.6, dark_height, segments, IslandData.color("volcano_dark"))
	var body := _mesh_node("Cone", kit.build())
	root.add_child(body)
	var smoke: IslandSmoke = null
	var smoke_cfg: Dictionary = cfg.get("smoke", {})
	if with_smoke and bool(smoke_cfg.get("enabled", true)):
		smoke = IslandSmoke.new()
		smoke.name = "Smoke"
		smoke.puff_count = int(smoke_cfg.get("puffs", 7))
		smoke.puff_radius = top * 0.8
		smoke.rise_height = height * 0.7
		smoke.color = IslandData.color("smoke")
		smoke.position = Vector3(0.0, height, 0.0)
		root.add_child(smoke)
	return {"node": root, "smoke": smoke}
