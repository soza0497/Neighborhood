extends Node
## Pruebas de la isla (Isla 1A), sin ventana:
##
##   godot --headless --path . res://tests/test_island.tscn
## Los números de dibujo se ESTIMAN contando los nodos visibles (IslandStats.estimate), porque
## sin ventana el motor no dibuja. Los números de verdad se miden con tests/island_demo.tscn.

var _passed := 0
var _failed := 0


func _ready() -> void:
	HouseGrid.LOT_SIZE = Vector2i(96, 96)
	HouseData.blocked_cells = {}
	NeighborhoodMap.reload()
	IslandData.reload()
	IslandFakeHouses.clear_cache()
	_test_data()
	_test_lots_geometry()
	_test_rules_and_zones()
	_test_rects()
	_test_cards()
	_test_meshes()
	_test_lod_levels()
	_test_lod_update()
	await _test_world()
	await _test_stress()
	_test_camera_rig()
	print("\nPRUEBAS: %d pasaron, %d fallaron" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _check(condition: bool, description: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		print("FALLÓ: ", description)


# --- Datos ---

func _test_data() -> void:
	var lots := IslandData.all_lots()
	_check(not IslandData.data().is_empty(), "data/island.json se lee")
	_check(lots.size() == int(IslandData.rule("max_lots", 60)), "hay %d lotes (max_lots)" % lots.size())
	var start := 0
	var ids: Dictionary = {}
	var players := 0
	for l in lots:
		ids[l["id"]] = true
		if bool(l["start"]):
			start += 1
		if l["state"] == "player":
			players += 1
	_check(ids.size() == lots.size(), "ids de lote únicos")
	_check(start == int(IslandData.rule("start_lots", 30)), "empiezan %d lotes (start_lots)" % start)
	_check(IslandData.lots_for_count(30).size() == 30 and IslandData.lots_for_count(60).size() == 60, "lots_for_count(30) y (60)")
	_check(IslandData.lots_for_count(30).all(func(l: Dictionary) -> bool: return bool(l["start"])), "los 30 primeros son los de start")
	_check(players == 1, "hay exactamente una parcela regalada (player)")
	var sizes: Dictionary = IslandData.rule("sizes", {})
	_check(sizes.get("S") == 32 and sizes.get("M") == 48 and sizes.get("L") == 64, "tamaños S 32, M 48, L 64")
	var valid_sizes := true
	var valid_states := true
	for l in lots:
		if not sizes.has(l["size"]):
			valid_sizes = false
		if not ["player", "npc", "free", "future"].has(l["state"]):
			valid_states = false
	_check(valid_sizes, "todos los lotes son S, M o L")
	_check(valid_states, "estados válidos (player, npc, free, future)")
	var gift: Dictionary = {}
	for l in lots:
		if l["state"] == "player":
			gift = l
	_check(gift.get("size") == IslandData.rule("gift_size", "S"), "la parcela regalada es del tamaño gift_size")
	_check(int(IslandData.rule("max_lots_per_player", 0)) >= 2, "tope de parcelas por jugador (2-3)")
	_check(IslandData.all_lots().all(func(l: Dictionary) -> bool: return int(l["price"]) >= 0), "precios base válidos")


func _street_polygon(street: Dictionary, grow: float) -> PackedVector2Array:
	var dir := IslandData.polar(float(street["angle"]), 1.0)
	var d := Vector2(dir.x, dir.z)
	var n := Vector2(-d.y, d.x) * (float(street["width"]) / 2.0 + grow)
	var a := d * float(street["from"])
	var b := d * (IslandData.island_radius() + 10.0)
	return PackedVector2Array([a + n, b + n, b - n, a - n])


func _min_radius(poly: PackedVector2Array) -> float:
	var best := INF
	for i in poly.size():
		var closest := Geometry2D.get_closest_point_to_segment(Vector2.ZERO, poly[i], poly[(i + 1) % poly.size()])
		best = minf(best, closest.length())
	return best


func _max_radius(poly: PackedVector2Array) -> float:
	var best := 0.0
	for p in poly:
		best = maxf(best, p.length())
	return best


func _test_lots_geometry() -> void:
	var lots := IslandData.all_lots()
	var overlaps := 0
	for i in lots.size():
		var a := IslandData.lot_corners(lots[i], 0.5)
		for j in range(i + 1, lots.size()):
			if not Geometry2D.intersect_polygons(a, IslandData.lot_corners(lots[j], 0.5)).is_empty():
				overlaps += 1
	_check(overlaps == 0, "ningún lote se encima con otro (%d encimados, con 1 m de aire)" % overlaps)
	var island := IslandData.section("island")
	var radius := IslandData.island_radius()
	var sand := float(island.get("sand_width", 22.0))
	var park_edge := float(IslandData.section("zones").get("commerce", {}).get("outer", 47.0))
	var outside := 0
	var on_park := 0
	var on_street := 0
	var on_ring := 0
	var streets: Array = IslandData.section("streets").get("radial", [])
	var rings: Array = IslandData.section("streets").get("rings", [])
	for l in lots:
		var poly := IslandData.lot_corners(l)
		if _max_radius(poly) > radius - sand:
			outside += 1
		if _min_radius(poly) < park_edge + 2.0:
			on_park += 1
		for street in streets:
			if not Geometry2D.intersect_polygons(poly, _street_polygon(street, 0.0)).is_empty():
				on_street += 1
		var lo := _min_radius(poly)
		var hi := _max_radius(poly)
		for ring in rings:
			var half := float(ring["width"]) / 2.0
			var r := float(ring["radius"])
			if not (hi < r - half or lo > r + half):
				on_ring += 1
	_check(outside == 0, "ningún lote sale de la isla ni pisa la arena (%d)" % outside)
	_check(on_park == 0, "ningún lote invade el parque ni los comercios (%d)" % on_park)
	_check(on_street == 0, "ningún lote pisa una calle radial (%d)" % on_street)
	_check(on_ring == 0, "ningún lote pisa una calle circular (%d)" % on_ring)
	# Que el frente mire al centro: el eje +Z del lote apunta hacia (0, 0).
	var facing := 0
	for l in lots:
		var front := Basis(Vector3.UP, IslandData.lot_yaw(l)) * Vector3.BACK
		var to_center := (-IslandData.lot_center(l)).normalized()
		if front.dot(to_center) > 0.98:
			facing += 1
	_check(facing == lots.size(), "todos los lotes miran al centro de la isla (%d de %d)" % [facing, lots.size()])


func _test_rules_and_zones() -> void:
	var zones := IslandData.section("zones")
	for zone in ["park", "commerce", "beach", "pier", "volcano"]:
		_check(zones.has(zone), "zona %s en los datos" % zone)
	var volcano: Dictionary = zones["volcano"]
	var c: Array = volcano["center"]
	var volcano_distance := Vector2(float(c[0]), float(c[1])).length() - float(volcano["base_radius"])
	_check(volcano_distance > IslandData.island_radius(), "el volcán queda fuera de la isla, de fondo (%.0f m del centro)" % volcano_distance)
	_check(not IslandData.section("zones").get("commerce", {}).get("active", true), "los comercios son solo decorados (apagados)")
	var streets := IslandData.section("streets")
	_check((streets.get("radial", []) as Array).size() >= 3 and (streets.get("rings", []) as Array).size() >= 3, "calles radiales y circulares")
	var pier: Dictionary = zones["pier"]
	var avenue_found := false
	for street in streets.get("radial", []):
		if int(street["angle"]) == int(pier["angle"]):
			avenue_found = true
	_check(avenue_found, "hay una avenida que llega al muelle")
	var lod := IslandData.lod_config()
	var d: Array = lod.get("distances", [])
	_check(d.size() == 3 and float(d[0]) < float(d[1]) and float(d[1]) < float(d[2]), "distancias de LOD crecientes en los datos")
	var lots := IslandData.all_lots()
	var ok_premium := true
	for l in lots:
		if l["size"] == "L" and l["ring"] != "B" and l["ring"] != "D":
			ok_premium = false
	_check(ok_premium, "los lotes L están en los anillos exteriores")


# --- Ficha exterior ---

func _test_rects() -> void:
	var cells: Dictionary = {}
	for x in range(0, 6):
		for z in range(0, 3):
			cells[HouseGrid.cell_key(Vector2i(x, z))] = Vector2i(x, z)
	for x in range(0, 3):
		for z in range(3, 6):
			cells[HouseGrid.cell_key(Vector2i(x, z))] = Vector2i(x, z)
	var rects := ExteriorCard.rects_from_cells(cells)
	_check(rects.size() == 2, "una L se descompone en 2 rectángulos (%d)" % rects.size())
	var covered := 0
	for r in rects:
		covered += int(r[2]) * int(r[3])
	_check(covered == cells.size(), "los rectángulos cubren exactamente las celdas (%d de %d)" % [covered, cells.size()])
	var code := ExteriorCard.edge_code("h:12,34")
	_check(ExteriorCard.edge_key_of(code) == "h:12,34", "código de pared horizontal ida y vuelta")
	code = ExteriorCard.edge_code("v:0,95")
	_check(ExteriorCard.edge_key_of(code) == "v:0,95", "código de pared vertical ida y vuelta")


func _test_cards() -> void:
	var lots := IslandData.all_lots()
	var json_set: Dictionary = {}
	var floor_counts: Dictionary = {}
	var kinds: Dictionary = {}
	var wall_colors: Dictionary = {}
	var l_shapes := 0
	var with_windows := 0
	var same_after_json := 0
	var same_after_rebuild := 0
	var doors_south := 0
	var small_enough := 0
	var fit_lot := 0
	var under_limit := 0
	var sizes_ok := 0
	var limits: Dictionary = IslandData.rule("max_pieces_per_lot", {})
	var front_gap := float(IslandData.section("houses").get("front_gap", 4.0))
	for l in lots:
		var house := IslandFakeHouses.house_for(l)
		var card := ExteriorCard.from_house(house)
		json_set[card.to_json()] = true
		floor_counts[card.floor_count()] = true
		kinds[card.roof_kind()] = true
		wall_colors[str(card.floors[0]["wc"])] = true
		if (card.floors[0]["fp"] as Array).size() >= 2:
			l_shapes += 1
		for f in card.floors:
			if not (f["w"] as Array).is_empty():
				with_windows += 1
				break
		# Mismo resultado pasando por JSON de texto (como cuando se guarde en el servidor).
		var parsed: Variant = JSON.parse_string(card.to_json())
		if parsed is Dictionary and ExteriorCard.from_dict(parsed).same_shape_as(card):
			same_after_json += 1
		# Reconstruir una casa desde la ficha y sacar otra ficha: misma forma.
		var rebuilt := ExteriorCard.from_house(card.to_house_data())
		if rebuilt.same_shape_as(card):
			same_after_rebuild += 1
		if card.door_side() == "s":
			doors_south += 1
		var bytes := card.byte_size()
		if bytes >= 100 and bytes <= 1500:
			small_enough += 1
		var box := card.bounds()
		var side := IslandData.lot_side(l)
		if float(box.size.x) <= side - 4.0 and float(box.size.y) <= side - front_gap - 2.0:
			fit_lot += 1
		if IslandFakeHouses.piece_count(house) <= int(limits.get(l["size"], 0)):
			under_limit += 1
		if card.floor_count() >= 1 and card.floor_count() <= 3 and card.total_height() >= 3.0:
			sizes_ok += 1
	var n := lots.size()
	_check(same_after_json == n, "la ficha pasa por JSON y queda igual (%d de %d)" % [same_after_json, n])
	_check(same_after_rebuild == n, "ficha → casa mínima → ficha da la misma forma (%d de %d)" % [same_after_rebuild, n])
	_check(doors_south == n, "la puerta está en la fachada (lado +Z) en todas (%d de %d)" % [doors_south, n])
	_check(small_enough == n, "cada ficha pesa entre 100 y 1500 bytes (%d de %d)" % [small_enough, n])
	_check(fit_lot == n, "cada casa cabe en su lote con jardín al frente (%d de %d)" % [fit_lot, n])
	_check(under_limit == n, "ninguna casa pasa el límite de piezas por parcela (%d de %d)" % [under_limit, n])
	_check(sizes_ok == n, "1 a 3 pisos con altura razonable (%d de %d)" % [sizes_ok, n])
	_check(json_set.size() >= int(n * 0.8), "casas bien distintas entre sí (%d formas de %d)" % [json_set.size(), n])
	_check(floor_counts.has(1) and floor_counts.has(2) and floor_counts.has(3), "hay casas de 1, 2 y 3 pisos")
	_check(kinds.has("gable") and kinds.has("flat"), "hay techos a dos aguas y planos")
	_check(wall_colors.size() >= 4, "al menos 4 colores de pared (%d)" % wall_colors.size())
	_check(l_shapes >= 3, "hay casas en forma de L (%d)" % l_shapes)
	_check(with_windows >= n * 0.9, "casi todas tienen ventanas (%d de %d)" % [with_windows, n])
	# Determinista: borrar la memoria y volver a generar da lo mismo.
	var first := IslandFakeHouses.card_for(lots[5]).to_json()
	IslandFakeHouses.clear_cache()
	_check(IslandFakeHouses.card_for(lots[5]).to_json() == first, "misma casa en cada generación (determinista)")
	# Una ficha rota no rompe nada.
	_check(ExteriorCard.from_dict({"v": 99}).is_empty(), "una ficha de otra versión queda vacía")
	_check(ExteriorCard.from_dict({}).is_empty(), "un diccionario vacío da una ficha vacía")
	var sample := IslandFakeHouses.card_for(lots[0])
	_check(sample.bounds().size.x > 0 and sample.area(0) > 0 and sample.total_height() > 3.0, "consultas de la ficha (caja, área, alto)")
	print("  ficha de ejemplo (%d bytes): %s" % [sample.byte_size(), sample.to_json()])


# --- Mallas por nivel ---

func _test_meshes() -> void:
	var lots := IslandData.all_lots()
	var worse_lod2 := 0
	var max_lod1 := 0
	var max_lod2 := 0
	var surfaces_ok := true
	for l in lots:
		var card := IslandFakeHouses.card_for(l)
		var kit1 := ExteriorLod1.build_kit(card)
		var kit2 := ExteriorLod2.build_kit([{"card": card, "xf": Transform3D.IDENTITY}])
		max_lod1 = maxi(max_lod1, kit1.triangle_count())
		max_lod2 = maxi(max_lod2, kit2.triangle_count())
		if kit2.triangle_count() >= kit1.triangle_count():
			worse_lod2 += 1
		var mesh := kit1.build()
		if mesh == null or mesh.get_surface_count() != 1:
			surfaces_ok = false
	_check(worse_lod2 == 0, "el LOD 2 siempre tiene menos triángulos que el LOD 1")
	_check(max_lod1 > 0 and max_lod1 <= 600, "LOD 1: hasta %d triángulos por casa" % max_lod1)
	_check(max_lod2 > 0 and max_lod2 <= 150, "LOD 2: hasta %d triángulos por casa" % max_lod2)
	_check(surfaces_ok, "cada casa en LOD 1 es UNA malla con UNA superficie")
	var card0 := IslandFakeHouses.card_for(lots[0])
	var node1 := ExteriorLod1.build(card0)
	_check(node1.material_override == IslandMaterials.blocks(true), "LOD 1 usa el material con contorno")
	var cluster := ExteriorLod2.build_cluster([{"card": card0, "xf": Transform3D.IDENTITY}])
	_check(cluster != null and cluster.material_override == IslandMaterials.blocks(false), "LOD 2 usa el material SIN contorno")
	_check(IslandMaterials.blocks(false).next_pass == null, "el material de LOD 2 no tiene segunda pasada")
	_check((IslandMaterials.blocks(true).next_pass != null) == Style.outline_enabled, "el contorno de LOD 1 sigue el interruptor de Style")
	var outline_before := Style.outline_enabled
	Style.set_outline(false)
	_check(IslandMaterials.blocks(true).next_pass == null, "al apagar el contorno, el LOD 1 también lo pierde")
	Style.set_outline(true)
	_check(IslandMaterials.blocks(true).next_pass != null, "al prenderlo, vuelve")
	Style.set_outline(outline_before)
	_check(ExteriorLod2.build_cluster([]) == null, "una zona sin casas no arma malla")
	var cluster_entries: Array = []
	for i in 6:
		cluster_entries.append({"card": IslandFakeHouses.card_for(lots[i]), "xf": Transform3D(Basis.IDENTITY, Vector3(i * 40.0, 0, 0))})
	var big := ExteriorLod2.build_cluster(cluster_entries)
	_check(big.mesh.get_surface_count() == 1, "6 casas agrupadas = 1 superficie (1 llamada de dibujo)")
	node1.free()
	cluster.free()
	big.free()
	var map_node := IslandMapLod3.build(IslandData.lots_for_count(30))
	_check(map_node.mesh != null and map_node.mesh.get_surface_count() == 1, "el mapa LOD 3 es una sola malla")
	var map_triangles := IslandStats.estimate(map_node)
	_check(int(map_triangles["draws"]) == 1 and int(map_triangles["triangles"]) < 5000, "mapa: 1 llamada, %d triángulos" % int(map_triangles["triangles"]))
	map_node.free()


# --- Niveles de detalle ---

func _test_lod_levels() -> void:
	var lod := IslandLod.from_data()
	var d0 := lod.distances[0]
	var d1 := lod.distances[1]
	var d2 := lod.distances[2]
	_check(lod.raw_level(0.0) == 0 and lod.raw_level(d0 - 1.0) == 0, "cerca de todo: LOD 0")
	_check(lod.raw_level(d0 + 1.0) == 1 and lod.raw_level(d1 - 1.0) == 1, "entre la 1.ª y la 2.ª distancia: LOD 1")
	_check(lod.raw_level(d1 + 1.0) == 2 and lod.raw_level(d2 - 1.0) == 2, "entre la 2.ª y la 3.ª: LOD 2")
	_check(lod.raw_level(d2 + 1.0) == 3 and lod.raw_level(5000.0) == 3, "más lejos: LOD 3")
	var h := lod.hysteresis
	# Histéresis: alejándose, sube solo pasado el margen; acercándose, baja solo dentro del margen.
	_check(lod.level_for(d0 * (1.0 + h * 0.5), 0) == 0, "alejándose un poco del límite 0→1 sigue en LOD 0")
	_check(lod.level_for(d0 * (1.0 + h) + 0.5, 0) == 1, "pasado el margen sube a LOD 1")
	_check(lod.level_for(d0 * (1.0 - h * 0.5), 1) == 1, "acercándose un poco al límite 1→0 sigue en LOD 1")
	_check(lod.level_for(d0 * (1.0 - h) - 0.5, 1) == 0, "dentro del margen baja a LOD 0")
	_check(lod.level_for(d2 * (1.0 + h * 0.5), 2) == 2 and lod.level_for(d2 * (1.0 + h) + 1.0, 2) == 3, "histéresis también en 2→3")
	# Sin parpadeo: un lote que oscila ±3 % alrededor del límite no cambia de nivel.
	var level := lod.level_for(d1 * 0.98, -1)
	var changes := 0
	for i in 40:
		var wobble := d1 * (1.0 + (0.03 if i % 2 == 0 else -0.03))
		var next := lod.level_for(wobble, level)
		if next != level:
			changes += 1
		level = next
	_check(changes == 0, "oscilar ±3 %% alrededor del límite no hace parpadear el nivel (%d cambios)" % changes)
	# Un salto grande atraviesa varios niveles de una vez.
	_check(lod.level_for(5000.0, 0) == 3 and lod.level_for(1.0, 3) == 0, "saltos grandes cruzan varios niveles")
	# Mapa de toda la isla con dos distancias (entra más lejos de lo que sale).
	_check(lod.map_enter > lod.map_exit, "el mapa entra más lejos de lo que sale")
	_check(not lod.map_for(lod.map_enter - 1.0, false) and lod.map_for(lod.map_enter + 1.0, false), "el mapa entra pasada su distancia")
	_check(lod.map_for((lod.map_enter + lod.map_exit) / 2.0, true) and not lod.map_for(lod.map_exit - 1.0, true), "el mapa sale bajo su distancia (histéresis)")


func _test_lod_update() -> void:
	var lod := IslandLod.from_data()
	var centers: Dictionary = {}
	for i in 6:
		centers["near_%d" % i] = Vector3(float(i), 0.0, 10.0)
	centers["mid"] = Vector3(150.0, 0.0, 0.0)
	centers["far"] = Vector3(400.0, 0.0, 0.0)
	centers["very_far"] = Vector3(800.0, 0.0, 0.0)
	var changes := lod.update(Vector3(0.0, 10.0, 0.0), centers)
	var zero := 0
	var one_near := 0
	for i in 6:
		if int(lod.levels["near_%d" % i]) == 0:
			zero += 1
		elif int(lod.levels["near_%d" % i]) == 1:
			one_near += 1
	_check(zero == lod.lod0_max and one_near == 6 - lod.lod0_max, "solo los %d más cercanos quedan en LOD 0, el resto en LOD 1" % lod.lod0_max)
	_check(int(lod.levels["mid"]) == 1 and int(lod.levels["far"]) == 2 and int(lod.levels["very_far"]) == 3, "mid=LOD1, far=LOD2, very_far=LOD3 (%s %s %s)" % [lod.levels["mid"], lod.levels["far"], lod.levels["very_far"]])
	_check(changes.size() == centers.size(), "la primera vez todos cambian (de -1 a su nivel)")
	var again := lod.update(Vector3(0.0, 10.0, 0.0), centers)
	_check(again.is_empty(), "si la cámara no se mueve, no hay cambios")
	var far_cam := Vector3(0.0, lod.map_enter + 50.0, 0.0)
	lod.update(far_cam, centers)
	var all_three := true
	for id in centers:
		if int(lod.levels[id]) != 3:
			all_three = false
	_check(lod.map_mode and all_three, "con el mapa de toda la isla activo, todos los lotes pasan a LOD 3")
	lod.update(Vector3(0.0, 10.0, 0.0), centers)
	_check(not lod.map_mode and int(lod.levels["mid"]) == 1, "al volver, se recuperan los niveles")


# --- La isla armada ---

func _make_world(count: int) -> Array:
	var camera := Camera3D.new()
	camera.far = 3000.0
	add_child(camera)
	var world := IslandWorld.new()
	add_child(world)
	var lots: Array = []
	for l in IslandData.lots_for_count(count):
		var copy: Dictionary = (l as Dictionary).duplicate()
		if count > 30 and str(copy["state"]) != "player":
			copy["state"] = "npc"
		lots.append(copy)
	world.setup(camera, lots, {"smoke": true})
	return [world, camera]


func _player_center(world: IslandWorld) -> Vector3:
	for l in world.lots:
		if str(l["state"]) == "player":
			return IslandData.lot_center(l)
	return Vector3.ZERO


func _test_world() -> void:
	var made := _make_world(30)
	var world: IslandWorld = made[0]
	var camera: Camera3D = made[1]
	await get_tree().process_frame
	var houses := 0
	for l in world.lots:
		if l["state"] == "npc" or l["state"] == "player":
			houses += 1
	_check(world.slot_count() == houses, "una casa por cada lote con vecino o jugador (%d)" % houses)
	_check(world.tree_count > 100 and world.chunk_count() > 4, "vegetación en trozos (%d árboles, %d trozos)" % [world.tree_count, world.chunk_count()])
	var player := _player_center(world)
	# Cerca de tu parcela: LOD 0 en la tuya.
	camera.global_position = player + Vector3(0.0, 24.0, 22.0)
	world.forced_level = -1
	world.refresh()
	world.apply_pending(true)
	var counts := world.shown_counts()
	_check(counts[0] >= 1 and counts[0] <= world.lod.lod0_max, "cerca de tu parcela hay %d casa(s) en LOD 0 (máx. %d)" % [counts[0], world.lod.lod0_max])
	_check(counts[1] >= 1, "y vecinos cercanos en LOD 1 (%d)" % counts[1])
	_check(counts[2] >= 1, "y más lejos en LOD 2 (%d)" % counts[2])
	_check(not world.map_visible(), "cerca no se ve el mapa")
	var near_stats := IslandStats.estimate(world)
	# Sin parpadeo en el mundo: mover la cámara un metro no cambia ningún nivel.
	camera.global_position += Vector3(1.0, 0.0, 0.0)
	world.refresh()
	_check(world.pending_count() == 0, "mover un metro la cámara no cambia ningún nivel")
	# Vista del barrio (a unos 200 m): sin LOD 0 y presupuesto razonable.
	var l12 := IslandData.lot("i12")
	camera.global_position = IslandData.lot_center(l12) + Vector3(0.0, 160.0, 130.0)
	world.refresh()
	world.apply_pending(true)
	var mid_stats := IslandStats.estimate(world)
	_check(int(mid_stats["draws"]) <= 150, "vista del barrio: %d llamadas de dibujo estimadas (≤ 150)" % int(mid_stats["draws"]))
	# Vista lejana: el mapa de toda la isla; muy pocas llamadas.
	camera.global_position = Vector3(0.0, 600.0, 850.0)
	world.refresh()
	world.apply_pending(true)
	var far_counts := world.shown_counts()
	var far_stats := IslandStats.estimate(world)
	_check(world.map_visible(), "de muy lejos se ve el mapa estilizado")
	_check(far_counts[3] == world.slot_count(), "de muy lejos todas las casas están en LOD 3 (%d)" % far_counts[3])
	_check(int(far_stats["draws"]) <= 16, "vista lejana: %d llamadas de dibujo estimadas (≤ 16)" % int(far_stats["draws"]))
	_check(int(far_stats["triangles"]) < 60000, "vista lejana: %d triángulos estimados (< 60 mil)" % int(far_stats["triangles"]))
	# Streaming: se libera lo lejano y la vegetación se muestra por radio.
	camera.global_position = Vector3(300.0, 20.0, 0.0)
	world.refresh()
	var partial := world.visible_chunk_count()
	_check(partial > 0 and partial < world.chunk_count(), "vegetación por radio: %d de %d trozos a 300 m del centro" % [partial, world.chunk_count()])
	camera.global_position = Vector3(2400.0, 20.0, 0.0)
	world.refresh()
	_check(world.visible_chunk_count() == 0, "lejísimos no hay vegetación visible")
	# Forzar un nivel en todo.
	camera.global_position = Vector3(0.0, 300.0, 400.0)
	var draws_by_level: Array[int] = []
	var tris_by_level: Array[int] = []
	for forced in [1, 2]:
		world.set_forced_level(forced)
		world.apply_pending(true)
		var c := world.shown_counts()
		_check(c[forced] == world.slot_count(), "LOD %d forzado: todas las casas en ese nivel (%d)" % [forced, c[forced]])
		var s := IslandStats.estimate(world)
		draws_by_level.append(int(s["draws"]))
		tris_by_level.append(int(s["triangles"]))
	_check(draws_by_level[1] < draws_by_level[0], "LOD 2 gasta menos llamadas que LOD 1 (%d < %d)" % [draws_by_level[1], draws_by_level[0]])
	_check(tris_by_level[1] < tris_by_level[0], "LOD 2 gasta menos triángulos que LOD 1 (%d < %d)" % [tris_by_level[1], tris_by_level[0]])
	world.set_forced_level(3)
	_check(world.map_visible(), "LOD 3 forzado muestra el mapa")
	world.set_forced_level(0)
	world.apply_pending(true)
	var c0 := world.shown_counts()
	_check(c0[0] == world.slot_count(), "LOD 0 forzado arma todas las casas completas (%d)" % c0[0])
	world.set_forced_level(-1)
	world.apply_pending(true)
	_check(world.forced_level == -1, "volver a automático")
	_check(near_stats["draws"] > 0, "estimación de dibujo cerca: %d llamadas" % int(near_stats["draws"]))
	print("  estimado: cerca %d llamadas · barrio %d · lejos %d · LOD1 %d / %d triáng. · LOD2 %d / %d triáng. · isla armada en %d ms" % [
		int(near_stats["draws"]), int(mid_stats["draws"]), int(far_stats["draws"]), draws_by_level[0], tris_by_level[0],
		draws_by_level[1], tris_by_level[1], world.setup_ms])
	world.queue_free()
	camera.queue_free()
	await get_tree().process_frame


func _test_stress() -> void:
	var stress := IslandStress.new()
	add_child(stress)
	stress.setup(100, 52.0)
	var lod1 := IslandStats.estimate(stress)
	_check(int(lod1["meshes"]) == 101, "100 casas en LOD 1 = 100 mallas + el suelo (%d)" % int(lod1["meshes"]))
	stress.set_level(2)
	var lod2 := IslandStats.estimate(stress)
	_check(int(lod2["meshes"]) == 2, "100 casas en LOD 2 = 1 malla agrupada + el suelo (%d)" % int(lod2["meshes"]))
	_check(int(lod2["draws"]) < int(lod1["draws"]) and int(lod2["triangles"]) < int(lod1["triangles"]), "LOD 2 agrupado es más barato que LOD 1")
	print("  estrés estimado: 100 casas LOD 1 = %d llamadas / %d triáng. · LOD 2 = %d / %d" % [
		int(lod1["draws"]), int(lod1["triangles"]), int(lod2["draws"]), int(lod2["triangles"])])
	_check(stress.position_of(0) != stress.position_of(1), "las casas del estrés están en lugares distintos")
	stress.queue_free()
	await get_tree().process_frame


func _test_camera_rig() -> void:
	var rig: CameraRig = preload("res://scenes/camera_rig.tscn").instantiate()
	add_child(rig)
	var max_before := rig.max_distance
	var bounds_before := rig.bounds_half_size
	var far_before := rig.camera_node().far
	rig.enter_island_view(430.0, 1250.0, 3000.0, 1.0)
	_check(rig.in_island_view() and rig.max_distance == 1250.0 and rig.bounds_half_size == 430.0, "la cámara abre sus límites en la isla")
	rig.enter_island_view(500.0, 1300.0, 3200.0, 1.0)
	rig.exit_island_view()
	_check(not rig.in_island_view() and rig.max_distance == max_before and rig.bounds_half_size == bounds_before and rig.camera_node().far == far_before,
		"al salir de la isla vuelven los límites de antes")
	rig.queue_free()
