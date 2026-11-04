class_name IslandMapLod3
extends RefCounted
## LOD 3 (Isla 1A): la vista de TODA la isla como un mapa estilizado. Un solo plano
## de malla baja con color plano por vértice (una sola llamada de dibujo): la isla,
## la arena, el parque con su lago, el anillo de comercios, las calles (un poco más
## anchas que las de verdad para que se lean de lejos), el muelle y los lotes
## coloreados (con borde). No tiene casas en 3D.

## Alturas de las capas (separadas bastante: de lejos el buffer de profundidad es burdo).
const Y_LAND := 0.2
const Y_SAND := 0.5
const Y_PARK := 0.8
const Y_LAKE := 1.1
const Y_ROAD := 1.4
const Y_OUTLINE := 1.7
const Y_LOT := 2.0
const ROAD_SCALE := 1.6


static func build_kit(lots: Array) -> IslandMeshKit:
	var kit := IslandMeshKit.new()
	var island := IslandData.section("island")
	var radius := float(island.get("radius", 350.0))
	var segments := int(island.get("ring_segments", 96))
	var zones := IslandData.section("zones")
	kit.add_disc(Vector2.ZERO, radius, Y_LAND, segments, IslandData.color("map_land"))
	kit.add_annulus(radius - float(island.get("sand_width", 22.0)), radius, Y_SAND, segments, IslandData.color("map_sand"))
	var park: Dictionary = zones.get("park", {})
	var park_radius := float(park.get("radius", 34.0))
	kit.add_disc(Vector2.ZERO, park_radius, Y_PARK, segments, IslandData.color("map_park"))
	var lake: Dictionary = park.get("lake", {})
	if not lake.is_empty():
		var c: Array = lake["center"]
		kit.add_disc(Vector2(float(c[0]), float(c[1])), float(lake["radius"]), Y_LAKE, 32, IslandData.color("map_lake"))
	var commerce: Dictionary = zones.get("commerce", {})
	if not commerce.is_empty():
		kit.add_annulus(park_radius + 1.0, float(commerce.get("outer", 47.0)), Y_PARK, segments, IslandData.color("map_commerce"))
	# Calles.
	var streets := IslandData.section("streets")
	for ring in streets.get("rings", []):
		var arc: Array = ring.get("arc", [0, 360])
		var half := float(ring["width"]) * ROAD_SCALE / 2.0
		kit.add_annulus(float(ring["radius"]) - half, float(ring["radius"]) + half, Y_ROAD, segments, IslandData.color("map_road"),
			float(arc[0]), float(arc[1]))
	for street in streets.get("radial", []):
		var dir := IslandData.polar(float(street["angle"]), 1.0)
		kit.add_strip(Vector2(dir.x, dir.z) * float(street["from"]), Vector2(dir.x, dir.z) * (radius - 4.0),
			float(street["width"]) * ROAD_SCALE, Y_ROAD, IslandData.color("map_road"))
	# Muelle.
	var pier: Dictionary = zones.get("pier", {})
	if not pier.is_empty():
		var dir := IslandData.polar(float(pier.get("angle", 90.0)), 1.0)
		var length := float(pier.get("length", 90.0))
		kit.add_strip(Vector2(dir.x, dir.z) * (radius - 6.0), Vector2(dir.x, dir.z) * (radius + length),
			float(pier.get("width", 9.0)) * 1.4, Y_ROAD, IslandData.color("map_pier"))
	# Lotes: borde oscuro y relleno de color. Con casa = el color de su techo.
	for l in lots:
		var side := IslandData.lot_side(l)
		var center := IslandData.lot_center(l)
		var yaw := IslandData.lot_yaw(l)
		kit.add_ground_rect(center + Vector3(0, Y_OUTLINE, 0), Vector2(side + 2.5, side + 2.5), yaw, IslandData.color("map_lot_outline"))
		var fill := _lot_color(l)
		kit.add_ground_rect(center + Vector3(0, Y_LOT, 0), Vector2(side - 1.0, side - 1.0), yaw, fill)
	return kit


## Color de un lote en el mapa: dorado el tuyo, claro si está libre, apagado si está cerrado
## y el color del techo de la casa si hay un vecino.
static func _lot_color(l: Dictionary) -> Color:
	match str(l.get("state", "npc")):
		"player":
			return IslandData.color("map_player")
		"free":
			return IslandData.color("map_lot_free")
		"future":
			return IslandData.color("map_lot_future")
	var card := IslandFakeHouses.card_for(l)
	return card.roof_color(0) if not card.roofs.is_empty() else IslandData.color("map_lot_free")


static func build(lots: Array) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = "MapLod3"
	node.mesh = build_kit(lots).build()
	node.material_override = IslandMaterials.map()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node
