extends Node
## Pruebas del barrio (Fase 8A y 8B), sin pantalla ni red.
##
##   godot --headless --path . res://tests/test_neighborhood.tscn

var _passed := 0
var _failed := 0


func _ready() -> void:
	HouseGrid.LOT_SIZE = Vector2i(96, 96)
	NeighborhoodMap.reload()
	_test_map()
	_test_determinism()
	_test_side_neighbors()
	_test_designs()
	_test_privacy()
	await _test_scene()
	await _test_life()
	print("\nPRUEBAS: %d pasaron, %d fallaron" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _check(condition: bool, description: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		print("FALLÓ: ", description)


func _test_map() -> void:
	var lots := NeighborhoodMap.lots()
	_check(lots.size() >= 20 and lots.size() <= 30, "el barrio tiene 20-30 lotes (%d)" % lots.size())
	var ids: Dictionary = {}
	var overlaps := 0
	for i in lots.size():
		ids[lots[i]["id"]] = true
		for j in range(i + 1, lots.size()):
			if NeighborhoodMap.lot_rect(lots[i]["id"]).intersects(NeighborhoodMap.lot_rect(lots[j]["id"])):
				overlaps += 1
	_check(ids.size() == lots.size(), "ids de lote únicos")
	_check(overlaps == 0, "ningún lote se encima con otro (%d)" % overlaps)
	var player := NeighborhoodMap.lot_rect("player")
	_check(player == Rect2(-48, -48, 96, 96), "el lote del jugador es su parcela de 96 x 96 centrada")
	# La calle principal coincide con la que dibuja WorldBuilder (world.json).
	var world: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world.json"))
	var street: Dictionary = world["street"]
	var road_z := 48.0 + float(street["sidewalk_width"]) + float(street["road_width"]) / 2.0
	_check(is_equal_approx(NeighborhoodMap.street_z(), road_z), "la calle del barrio es la de world.json (z=%.1f)" % road_z)
	_check(NeighborhoodMap.house_lots().size() >= 20, "al menos 20 casas de vecinos")
	_check(NeighborhoodMap.lot("park").get("kind", "") == "park", "hay una plazoleta")
	_check(NeighborhoodMap.enabled(), "el barrio está activo con la parcela de 96")
	HouseGrid.LOT_SIZE = Vector2i(32, 32)
	_check(not NeighborhoodMap.enabled(), "con la parcela chica de pruebas no se dibuja")
	HouseGrid.LOT_SIZE = Vector2i(96, 96)
	_check(NeighborhoodMap.is_built_area(0.0, 80.0) and not NeighborhoodMap.is_built_area(0.0, 0.0),
		"is_built_area: lotes de enfrente sí, tu parcela no")
	# Las casas miran hacia la calle: cada lote tiene el frente del lado de la calle.
	var street_z := NeighborhoodMap.street_z()
	var facing_ok := true
	for l in NeighborhoodMap.house_lots():
		var rect := NeighborhoodMap.lot_rect(l["id"])
		if (l["facing"] == "south") != (rect.get_center().y < street_z):
			facing_ok = false
	_check(facing_ok, "el frente de cada casa mira a la calle")


func _test_determinism() -> void:
	var first: Dictionary = {}
	for l in NeighborhoodMap.house_lots():
		first[l["id"]] = [NeighborhoodMap.family_name(l["id"]), JSON.stringify(NeighborhoodMap.design(l["id"]))]
	NeighborhoodMap.reload()
	var same := true
	for l in NeighborhoodMap.house_lots():
		var again := [NeighborhoodMap.family_name(l["id"]), JSON.stringify(NeighborhoodMap.design(l["id"]))]
		if again != first[l["id"]]:
			same = false
	_check(same, "nombres y diseños de los vecinos salen siempre iguales")
	var names: Dictionary = {}
	for l in NeighborhoodMap.house_lots():
		names[NeighborhoodMap.family_name(l["id"])] = true
	_check(names.size() == NeighborhoodMap.house_lots().size(), "cada casa tiene un apellido distinto")
	var sizes: Dictionary = {}
	for l in NeighborhoodMap.house_lots():
		var d := NeighborhoodMap.design(l["id"])
		sizes["%dx%d" % [d["cols"], d["rows"]]] = true
	_check(sizes.size() >= 3, "las casas no son todas iguales (%d tamaños)" % sizes.size())


func _test_side_neighbors() -> void:
	var sides := NeighborhoodMap.side_lots()
	_check(sides["left"] != "" and sides["right"] != "", "el lote del jugador tiene vecino a cada lado")
	var player := NeighborhoodMap.lot_rect("player")
	for side in ["left", "right"]:
		var placed := NeighborhoodMap.placement(sides[side])
		var size: Vector2 = placed["size"]
		var center: Vector3 = placed["center"]
		var gap := absf(center.x - player.get_center().x) - size.x / 2.0 - player.size.x / 2.0
		_check(absf(gap) < 6.0, "la casa del lote %s queda pegada a la valla (distancia %.1f m)" % [side, gap])
		# La casa está dentro de su lote.
		var rect := NeighborhoodMap.lot_rect(sides[side])
		var footprint := Rect2(center.x - size.x / 2.0, center.z - size.y / 2.0, size.x, size.y)
		_check(rect.encloses(footprint), "la casa de %s cabe en su lote" % side)
	# La valla de la zona usa los límites de Parcel; la casa vecina queda detrás.
	var fence_x := float(Parcel.zone_bounds().end.x) - 48.0
	_check(NeighborhoodMap.placement(sides["right"])["center"].x - 3.0 > fence_x, "la casa derecha está detrás de la valla")


func _test_designs() -> void:
	var bad := 0
	var no_door := 0
	var overlap := 0
	for l in NeighborhoodMap.house_lots():
		var d := NeighborhoodMap.design(l["id"])
		var house := NeighborHouseDesign.build_house_data(d)
		var cols: int = d["cols"]
		var rows: int = d["rows"]
		if house.get_layer(0, "foundation").size() != cols * rows or house.get_layer(0, "floors").size() != cols * rows:
			bad += 1
		var doors := 0
		for key in house.get_layer(0, "walls"):
			if house.get_piece(0, "walls", key).get("opening", "") == "door_basic":
				doors += 1
		if doors != 1:
			no_door += 1
		if house.get_layer(0, "roofs").size() != 1:
			bad += 1
		var seen: Dictionary = {}
		for key in house.get_layer(0, "objects"):
			var value: Dictionary = house.get_piece(0, "objects", key)
			if Catalog.get_item(value["item"]).is_empty():
				bad += 1
			for cell in HouseData.value_cells(value):
				if cell.x < 0 or cell.y < 0 or cell.x >= cols or cell.y >= rows:
					bad += 1
				if seen.has(HouseGrid.cell_key(cell)):
					overlap += 1
				seen[HouseGrid.cell_key(cell)] = true
		var door_cell := Vector2i(int(d["door_col"]), rows - 1)
		if seen.has(HouseGrid.cell_key(door_cell)):
			overlap += 1
		# El punto de la puerta queda fuera de la casa y dentro del lote.
		var door := NeighborhoodMap.door_point(l["id"])
		if not NeighborhoodMap.lot_rect(l["id"]).has_point(Vector2(door.x, door.z)):
			bad += 1
	_check(bad == 0, "las casas vecinas son válidas (piezas del catálogo, techo, pisos) (%d problemas)" % bad)
	_check(no_door == 0, "cada casa tiene exactamente una puerta")
	_check(overlap == 0, "los muebles no se encima ni tapan la puerta (%d)" % overlap)


func _test_privacy() -> void:
	GameState.settings.erase("house_visitable")
	_check(not NeighborhoodMap.is_my_house_visitable(), "«Mi casa se puede visitar» empieza apagado")
	_check(not NeighborhoodMap.open_for_visit("player"), "con el interruptor apagado, tu casa no se puede visitar")
	NeighborhoodMap.set_my_house_visitable(true)
	_check(NeighborhoodMap.open_for_visit("player"), "encendido, sí")
	GameState.settings.erase("house_visitable")
	_check(NeighborhoodMap.open_for_visit("n_r1"), "las casas vecinas generadas se pueden ver (solo ver)")
	_check(not NeighborhoodMap.open_for_visit("park"), "la plazoleta no es una casa")
	_check(NeighborhoodMap.visit_list().size() == NeighborhoodMap.lots().size() - 1, "el menú Barrio lista todo menos tu casa")


func _test_scene() -> void:
	var holder := Node3D.new()
	add_child(holder)
	var builder := NeighborhoodBuilder.new()
	holder.add_child(builder)
	await get_tree().process_frame
	_check(builder.houses.size() == NeighborhoodMap.house_lots().size(), "se dibujó una casa por lote (%d)" % builder.houses.size())
	_check(builder.lamp_positions.size() >= 20, "hay farolas (%d)" % builder.lamp_positions.size())
	_check(builder.tree_positions.size() >= 10, "hay árboles de acera (%d)" % builder.tree_positions.size())
	_check(builder.park_node != null, "hay plazoleta")
	var house: NeighborHouseView = builder.house("n_r1")
	_check(house != null and not house.interior_on, "la casa se ve de afuera (silueta) al principio")
	house.set_interior(true)
	await get_tree().process_frame
	_check(house.interior_on and house.get_node_or_null("Inner/Interior") != null, "al visitar se arma el interior")
	house.set_interior(false)
	await get_tree().process_frame
	_check(not house.interior_on and house.get_node_or_null("Inner/Interior") == null, "al irse se desarma")
	holder.queue_free()


func _test_life() -> void:
	var holder := Node3D.new()
	add_child(holder)
	var builder := NeighborhoodBuilder.new()
	holder.add_child(builder)
	await get_tree().process_frame
	var life := builder.life
	life.camera_override = Vector3(0, 40, 60)
	var cfg: Dictionary = NeighborhoodMap.data()["life"]
	_check(life.walkers.size() == int(cfg["max_walkers"]), "hay %d vecinos caminantes (máximo de data)" % life.walkers.size())
	_check(life.cars.size() == int(cfg["max_cars"]), "hay %d autos" % life.cars.size())
	# Rutas por puntos: de una casa a otra de enfrente cruza la calle (y marca el cruce).
	var route := life.route_lots("n_r1", "s_12")
	_check(route["flags"].has(true), "una ruta al otro lado de la calle tiene un cruce marcado")
	_check((route["points"][0] as Vector3).distance_to(NeighborhoodMap.door_point("n_r1", 1.0)) < 0.1, "la ruta sale de la puerta")
	_check((route["points"][-1] as Vector3).distance_to(NeighborhoodMap.door_point("s_12", 1.0)) < 0.1, "y llega a la puerta del destino")
	var same_side := life.route_lots("n_r1", "n_r3")
	_check(not same_side["flags"].has(true), "del mismo lado no hay cruce")
	# Diez minutos de juego simulados (6000 pasos de 0,1 s).
	for i in 6000:
		life.step(0.1)
	_check(life.stats["left"] > 0 and life.stats["entered"] > 0, "salen de sus casas (%d) y entran (%d)" % [life.stats["left"], life.stats["entered"]])
	_check(life.stats["min_car_gap"] >= float(cfg["car_min_gap"]) - 0.01,
		"los autos nunca se tocan: la menor distancia entre centros fue %.2f m (mínimo %.1f)" % [life.stats["min_car_gap"], float(cfg["car_min_gap"])])
	var inside_bounds := true
	for w in life.walkers:
		var p: Vector3 = (w["node"] as Node3D).position
		if not (is_finite(p.x) and is_finite(p.z)) or absf(p.x) > 300.0 or p.z < -5.0 or p.z > 120.0:
			inside_bounds = false
	for c in life.cars:
		var p: Vector3 = (c["node"] as Node3D).position
		if not is_finite(p.x) or absf(p.x) > 300.0 or absf(p.z - life.street_z) > 4.0:
			inside_bounds = false
	_check(inside_bounds, "todos siguen dentro del barrio y de la calle")
	print("  saludos en 10 minutos: %d" % life.stats["greets"])
	# LOD: con la cámara lejísimos, nada se dibuja; cerca, los autos sí.
	life.camera_override = Vector3(5000, 40, 5000)
	life._update_lod()
	var any_visible := false
	for e in life.walkers + life.cars:
		if (e["node"] as Node3D).visible:
			any_visible = true
	_check(not any_visible, "LOD: lejos de la cámara no se dibuja nada")
	life.camera_override = Vector3(0, 40, life.street_z)
	life._update_lod()
	var cars_visible := 0
	for c in life.cars:
		if (c["node"] as Node3D).visible:
			cars_visible += 1
	_check(cars_visible > 0, "LOD: cerca de la cámara se dibujan los autos (%d)" % cars_visible)
	# Límite de activos: con 3 activos, los demás se esconden.
	life.active_limit = 3
	life.step(0.1)
	life.step(0.6)
	var shown := 0
	for w in life.walkers:
		if (w["node"] as Node3D).visible:
			shown += 1
	_check(shown <= 3, "con límite de 3 activos se ven como mucho 3 vecinos (%d)" % shown)
	holder.queue_free()
