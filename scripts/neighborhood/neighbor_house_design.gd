class_name NeighborHouseDesign
extends RefCounted
## Diseño simple y determinista de una casa de vecino (Fase 8A), armado con
## piezas del catálogo existente (cimientos, piso, paredes, puerta, ventanas,
## techo y muebles). Mismo lote = misma casa, siempre.
##
## Sistema de la casa: celda (0, 0) es la esquina de atrás a la izquierda; el
## FRENTE (con la puerta) mira a +Z local. NeighborhoodMap.placement la gira
## para las casas que miran hacia el otro lado de la calle.

## Cuántos intentos se dan a cada mueble para encontrar lugar.
const FURNITURE_TRIES := 14


## El diseño como datos simples: {family, cols, rows, wall_color, roof_item,
## roof_color, floor_item, door_col, windows: [clave de pared], furniture:
## [{item, cell: [x, z], rot}]}.
static func make(lot_id: String) -> Dictionary:
	var cfg: Dictionary = NeighborhoodMap.data().get("houses", {})
	var rng := NeighborhoodMap.rng_for(lot_id, "design")
	var cols_range: Array = cfg.get("cols", [5, 8])
	var rows_range: Array = cfg.get("rows", [4, 6])
	var cols := rng.randi_range(int(cols_range[0]), int(cols_range[1]))
	var rows := rng.randi_range(int(rows_range[0]), int(rows_range[1]))
	var design := {
		"family": NeighborhoodMap.family_name(lot_id),
		"cols": cols,
		"rows": rows,
		"wall_color": _pick(rng, cfg.get("wall_colors", ["#f2e3c6"])),
		"roof_item": _pick(rng, cfg.get("roof_items", ["roof_basic"])),
		"roof_color": _pick(rng, cfg.get("roof_colors", ["#e0675a"])),
		"floor_item": _pick(rng, cfg.get("floor_items", ["floor_basic"])),
		"door_col": rng.randi_range(1, maxi(1, cols - 2)),
	}
	design["windows"] = _make_windows(rng, cols, rows, int(design["door_col"]))
	design["furniture"] = _make_furniture(rng, cols, rows, int(design["door_col"]), cfg.get("furniture", []))
	return design


static func _pick(rng: RandomNumberGenerator, list: Array) -> Variant:
	return list[rng.randi_range(0, list.size() - 1)]


## Ventanas: en el frente (lejos de la puerta), atrás y a los costados.
static func _make_windows(rng: RandomNumberGenerator, cols: int, rows: int, door_col: int) -> Array:
	var keys: Array = []
	for c in cols:
		if absi(c - door_col) < 2:
			continue  # Nada pegado a la puerta.
		if c % 2 == rng.randi_range(0, 1):
			keys.append(HouseGrid.edge_key(Vector2i(c, rows), true))  # Frente.
	for c in cols:
		if c % 2 == rng.randi_range(0, 1) and c > 0 and c < cols - 1:
			keys.append(HouseGrid.edge_key(Vector2i(c, 0), true))  # Atrás.
	keys.append(HouseGrid.edge_key(Vector2i(0, int(rows * 0.5)), false))  # Costado izquierdo.
	keys.append(HouseGrid.edge_key(Vector2i(cols, int(rows * 0.5)), false))  # Costado derecho.
	return keys


## Muebles: se prueba cada uno en lugares y giros al azar hasta que entra sin
## encimarse ni tapar la puerta. Siempre hay cama, mesa, sillas y cocina si caben.
static func _make_furniture(rng: RandomNumberGenerator, cols: int, rows: int, door_col: int, extras: Array) -> Array:
	var wanted: Array = ["bed_basic", "table_basic", "chair_basic", "chair_basic", "stove_basic", "sofa_basic"]
	# Dos o tres extras al azar del listado de data/neighborhood.json.
	var pool := extras.duplicate()
	for i in rng.randi_range(2, 3):
		if pool.is_empty():
			break
		wanted.append(pool[rng.randi_range(0, pool.size() - 1)])
	var used: Dictionary = {}
	# La puerta y la celda de adentro quedan libres.
	used[HouseGrid.cell_key(Vector2i(door_col, rows - 1))] = true
	var placed: Array = []
	for item_id in wanted:
		var item := Catalog.get_item(item_id)
		if item.is_empty():
			continue
		var footprint := HouseData.item_footprint(item)
		for attempt in FURNITURE_TRIES:
			var rot := rng.randi_range(0, 3)
			var size := HouseGrid.rotated_size(footprint, rot)
			if size.x > cols or size.y > rows:
				continue
			var anchor := Vector2i(rng.randi_range(0, cols - size.x), rng.randi_range(0, rows - size.y))
			var cells := HouseGrid.object_cells(footprint, anchor, rot)
			var free := true
			for cell in cells:
				if used.has(HouseGrid.cell_key(cell)):
					free = false
					break
			if not free:
				continue
			for cell in cells:
				used[HouseGrid.cell_key(cell)] = true
			placed.append({"item": item_id, "cell": [anchor.x, anchor.y], "rot": rot})
			break
	return placed


## Arma los DATOS de la casa (HouseData) con piezas del catálogo: cimientos,
## pisos, paredes con puerta y ventanas, techo y muebles. No hace nada en 3D.
static func build_house_data(design: Dictionary) -> HouseData:
	var cols: int = design["cols"]
	var rows: int = design["rows"]
	var house := HouseData.new()
	var writes: Array = []
	var origin := Vector2i.ZERO
	var last := Vector2i(cols - 1, rows - 1)
	for cell in HouseGrid.cells_in_rect(origin, last):
		var key := HouseGrid.cell_key(cell)
		writes.append(HouseData.write(0, "foundation", key, {"item": "foundation_basic"}))
		writes.append(HouseData.write(0, "floors", key, {"item": design["floor_item"]}))
	var door_key := HouseGrid.edge_key(Vector2i(int(design["door_col"]), rows), true)
	var windows: Array = design["windows"]
	for edge in HouseGrid.edges_around_rect(origin, last):
		var wall := {"item": "wall_basic", "color_a": design["wall_color"], "color_b": design["wall_color"]}
		if edge == door_key:
			wall["opening"] = "door_basic"
		elif windows.has(edge):
			wall["opening"] = "window_basic"
		writes.append(HouseData.write(0, "walls", edge, wall))
	var index := 1
	for f in design["furniture"]:
		writes.append(HouseData.write(0, "objects", "o%d" % index, {"item": f["item"], "cell": f["cell"], "rot": f["rot"]}))
		index += 1
	writes.append(HouseData.write(0, "roofs", "o%d" % index, {
		"item": design["roof_item"], "rect": [0, 0, cols, rows], "color": design["roof_color"]}))
	house.next_id = index + 1
	house.apply(writes)
	return house
