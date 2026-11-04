class_name IslandFakeHouses
extends RefCounted
## Casas simuladas de la isla (Isla 1A): una casa «de mentira» determinista por lote.
##
## Reutiliza el generador de casas vecinas de la Fase 8 (NeighborHouseDesign.make):
## de ahí salen los colores de paredes y techo, el tipo de techo, el piso y los
## muebles. Esta clase le suma lo que la isla necesita: tamaños distintos según el
## lote (S/M/L), casas en forma de L, 1 a 3 pisos con pisos de arriba más chicos,
## puerta al frente y ventanas. Mismo lote = misma casa, siempre.
##
## Sistema de la casa: celda (0, 0) = esquina de atrás a la izquierda; el FRENTE
## (con la puerta) mira a +Z. El lote tiene su frente hacia el centro de la isla.

static var _cards: Dictionary = {}


static func clear_cache() -> void:
	_cards.clear()


## La ficha exterior de la casa de un lote (guardada en memoria).
static func card_for(l: Dictionary) -> ExteriorCard:
	var id := str(l["id"])
	if not _cards.has(id):
		_cards[id] = ExteriorCard.from_house(house_for(l))
	return _cards[id]


## Los datos completos de la casa (para el LOD 0 y para sacar la ficha).
static func house_for(l: Dictionary) -> HouseData:
	var design := design_for(l)
	var house := HouseData.new()
	var writes: Array = []
	var floors: Array = design["floors"]  # Por piso: lista de rectángulos [x, z, w, d].
	var wall_colors: Array = design["wall_colors"]
	var door_key := HouseGrid.edge_key(Vector2i(int(design["door_col"]), int(design["front_row"]) + 1), true)
	var all_cells: Array = []
	for level in floors.size():
		var cells: Dictionary = {}
		for rect in floors[level]:
			for x in range(int(rect[0]), int(rect[0]) + int(rect[2])):
				for z in range(int(rect[1]), int(rect[1]) + int(rect[3])):
					cells[HouseGrid.cell_key(Vector2i(x, z))] = Vector2i(x, z)
		all_cells.append(cells)
		var keys: Array = cells.keys()
		keys.sort()
		for key in keys:
			if level == 0:
				writes.append(HouseData.write(0, "foundation", key, {"item": "foundation_basic"}))
			writes.append(HouseData.write(level, "floors", key, {"item": design["floor_item"]}))
		var color: String = wall_colors[level]
		var window_rng := IslandData.rng_for("%s:win:%d" % [l["id"], level])
		var edges := ExteriorCard.perimeter_edges(cells)
		var window_count := 0
		for edge in edges:
			var wall := {"item": "wall_basic", "color_a": color, "color_b": color}
			if level == 0 and edge == door_key:
				wall["opening"] = "door_basic"
			elif window_count < 14 and window_rng.randf() < 0.4:
				wall["opening"] = "window_basic"
				window_count += 1
			writes.append(HouseData.write(level, "walls", edge, wall))
	# Muebles de la planta baja (solo los que caen sobre el piso: sirven para el LOD 0).
	var index := 1
	for f in design["furniture"]:
		var item := Catalog.get_item(str(f["item"]))
		var anchor := Vector2i(int(f["cell"][0]), int(f["cell"][1]))
		var fits := not item.is_empty()
		if fits:
			for cell in HouseGrid.object_cells(HouseData.item_footprint(item), anchor, int(f["rot"])):
				if not (all_cells[0] as Dictionary).has(HouseGrid.cell_key(cell)):
					fits = false
					break
		if fits:
			writes.append(HouseData.write(0, "objects", "o%d" % index, {"item": f["item"], "cell": f["cell"], "rot": f["rot"]}))
			index += 1
	# Techos: sobre cada bloque más alto de su zona.
	for roof in design["roofs"]:
		writes.append(HouseData.write(int(roof["level"]), "roofs", "o%d" % index, {
			"item": roof["item"], "rect": roof["rect"], "color": roof["color"]}))
		index += 1
	house.next_id = index + 1
	house.floor_count = floors.size()
	house.apply(writes)
	return house


## El diseño como datos simples (sin 3D): {size, floors: [[rects]...], door_col, front_row,
## wall_colors, floor_item, roofs: [{level, item, rect, color}], furniture}.
static func design_for(l: Dictionary) -> Dictionary:
	var id := str(l["id"])
	var cfg := IslandData.section("houses")
	var size_cfg: Dictionary = cfg.get(str(l["size"]), {})
	var rng := NeighborhoodMap.rng_for(id, "island")
	# La base sale del generador de la Fase 8 (colores, techo, piso, muebles).
	var base := NeighborHouseDesign.make(id)
	var cols_range: Array = size_cfg.get("cols", [8, 12])
	var rows_range: Array = size_cfg.get("rows", [7, 10])
	var floors_range: Array = size_cfg.get("floors", [1, 2])
	var cols := rng.randi_range(int(cols_range[0]), int(cols_range[1]))
	var rows := rng.randi_range(int(rows_range[0]), int(rows_range[1]))
	var floor_count := rng.randi_range(int(floors_range[0]), int(floors_range[1]))
	# Planta baja: un rectángulo o una L (se le saca una esquina de atrás).
	var ground: Array = [[0, 0, cols, rows]]
	var front_block: Array = [0, 0, cols, rows]
	if rng.randf() < float(cfg.get("l_shape_chance", 0.35)) and cols >= 8 and rows >= 7:
		var notch_w := rng.randi_range(maxi(2, int(cols * 0.3)), maxi(3, int(cols * 0.45)))
		var notch_d := rng.randi_range(maxi(2, int(rows * 0.35)), maxi(3, int(rows * 0.5)))
		var on_left := rng.randf() < 0.5
		var back_x := notch_w if on_left else 0
		# Bloque del frente (todo el ancho) y bloque de atrás (lo que queda de la esquina).
		front_block = [0, notch_d, cols, rows - notch_d]
		ground = [[back_x, 0, cols - notch_w, notch_d], front_block.duplicate()]
	var floors: Array = [ground]
	for level in range(1, floor_count):
		# El primer piso de arriba se apoya en el bloque del frente; los siguientes, en el de abajo.
		var rect: Array = front_block if level == 1 else (floors[level - 1] as Array)[0]
		var x: int = int(rect[0])
		var z: int = int(rect[1])
		var w: int = int(rect[2])
		var d: int = int(rect[3])
		if rng.randf() < float(cfg.get("setback_chance", 0.6)):
			var inset_x := rng.randi_range(0, 1)
			var inset_z := rng.randi_range(0, 1)
			if w - inset_x * 2 >= 4 and d - inset_z * 2 >= 4:
				x += inset_x
				z += inset_z
				w -= inset_x * 2
				d -= inset_z * 2
		floors.append([[x, z, w, d]])
	# La puerta mira al frente: en la última fila del bloque de adelante.
	var front_row := int(front_block[1]) + int(front_block[3]) - 1
	var door_col := rng.randi_range(1, maxi(1, cols - 2))
	# Colores de las paredes por piso.
	var palette: Array = NeighborhoodMap.data().get("houses", {}).get("wall_colors", ["#f2e3c6"])
	var wall_colors: Array = [base["wall_color"]]
	for level in range(1, floor_count):
		wall_colors.append(palette[rng.randi_range(0, palette.size() - 1)] if rng.randf() < 0.4 else base["wall_color"])
	# Techos.
	var flat := rng.randf() < float(cfg.get("flat_roof_chance", 0.25))
	var roof_item: String = "roof_flat" if flat else str(base["roof_item"])
	var roofs: Array = []
	var top: int = floor_count - 1
	for rect in floors[top]:
		roofs.append(_roof(top, rect, roof_item, flat, str(base["roof_color"])))
	if top >= 1 and (floors[0] as Array).size() > 1:
		# La parte de atrás de la L queda a un piso: lleva su propio techo.
		roofs.append(_roof(0, (floors[0] as Array)[0], roof_item, flat, str(base["roof_color"])))
	# Muebles (mismo generador de la Fase 8, sobre el rectángulo completo).
	var extras: Array = NeighborhoodMap.data().get("houses", {}).get("furniture", [])
	var furniture := NeighborHouseDesign._make_furniture(rng, cols, rows, door_col, extras)
	return {
		"size": str(l["size"]), "floors": floors, "door_col": door_col, "front_row": front_row,
		"wall_colors": wall_colors, "floor_item": base["floor_item"], "roofs": roofs, "furniture": furniture,
	}


static func _roof(level: int, rect: Array, item: String, flat: bool, color: String) -> Dictionary:
	var value := {"level": level, "item": item, "rect": [int(rect[0]), int(rect[1]), int(rect[2]), int(rect[3])]}
	value["color"] = "#b9bec4" if flat else color
	return value


# --- Dónde queda la casa dentro de su lote ---

## Transformación (mundo) del CENTRO de la huella de la casa: dentro del lote, hacia el
## frente (con `houses.front_gap` de jardín delante) y mirando al centro de la isla.
static func house_transform(l: Dictionary, card: ExteriorCard) -> Transform3D:
	var box := card.bounds()
	var gap := float(IslandData.section("houses").get("front_gap", 4.0))
	var front_z := IslandData.lot_side(l) / 2.0 - gap - float(box.size.y) / 2.0
	var local := Vector3(0.0, 0.0, front_z)
	return Transform3D(Basis(Vector3.UP, IslandData.lot_yaw(l)), IslandData.lot_to_world(l, local))


## Cuántas piezas tiene la casa (para compararlo con el límite de piezas por parcela).
static func piece_count(house: HouseData) -> int:
	var total := 0
	for level in range(HouseGrid.MIN_LEVEL, HouseGrid.MAX_LEVELS):
		for layer in ["foundation", "floors", "walls", "objects", "roofs"]:
			total += house.get_layer(level, layer).size()
	return total
