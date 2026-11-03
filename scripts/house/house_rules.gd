class_name HouseRules
## Reglas de construcción: qué se puede poner, qué se puede quitar y dónde.
##
## Solo lógica sobre HouseData (nada 3D, nada de pantalla). Así, en la Fase 4
## el servidor puede revisar las mismas reglas.
##
## Reglas de "apoyo" (algo tiene que sostener cada pieza):
##   - Cimientos: solo en la planta baja, dentro del lote.
##   - Piso en planta baja: sobre cimientos.
##   - Piso en un nivel de arriba: sobre otro piso o junto a una pared de
##     abajo (así sirve para hacer un balcón), y no encima de una escalera.
##   - Pared en planta baja: junto a cimientos.
##   - Pared arriba: junto a un piso de ese nivel, o encima de otra pared.
##   - Objeto: todas sus celdas con piso, sin otro objeto y sin paredes
##     atravesadas. Las escaleras no pueden ir en el último nivel.


## ¿Esta pieza queda bien apoyada en la casa?
## `value` es la pieza (hace falta para los objetos y techos).
static func is_supported(house: HouseData, level: int, layer: String, key: String, value: Dictionary) -> bool:
	match layer:
		"foundation":
			return level == 0 and HouseGrid.is_cell_in_lot(HouseGrid.key_to_cell(key))
		"floors":
			var cell := HouseGrid.key_to_cell(key)
			if not HouseGrid.is_cell_in_lot(cell):
				return false
			if level == 0:
				return house.has_piece(0, "foundation", key)
			if is_stairs_cell(house, level - 1, cell):
				return false
			if house.has_piece(level - 1, "floors", key):
				return true
			# También sirve una pared de abajo en cualquiera de sus 4 lados.
			for edge in HouseGrid.cell_edges(cell):
				if house.has_piece(level - 1, "walls", edge):
					return true
			return false
		"walls":
			if not HouseGrid.is_edge_in_lot(key):
				return false
			var support_layer := "foundation" if level == 0 else "floors"
			for cell in HouseGrid.edge_cells(key):
				if house.has_piece(level, support_layer, HouseGrid.cell_key(cell)):
					return true
			return level > 0 and house.has_piece(level - 1, "walls", key)
		"objects":
			return _is_object_supported(house, level, key, value)
		"roofs":
			var rect := HouseData.roof_rect(value)
			return Rect2i(Vector2i.ZERO, HouseGrid.LOT_SIZE).encloses(rect)
	return false


## ¿Hay una escalera en esa celda de ese nivel?
static func is_stairs_cell(house: HouseData, level: int, cell: Vector2i) -> bool:
	var key := house.object_at(level, cell)
	if key == "":
		return false
	var item := Catalog.get_item(house.get_piece(level, "objects", key)["item"])
	return item.get("kind", "") == "stairs"


## Piezas que se apoyan en esta (si se quita, podrían quedar en el aire).
## Devuelve una lista de [nivel, capa, clave].
static func dependents(house: HouseData, level: int, layer: String, key: String) -> Array:
	var result: Array = []
	match layer:
		"foundation":
			result.append([0, "floors", key])
			for edge in HouseGrid.cell_edges(HouseGrid.key_to_cell(key)):
				result.append([0, "walls", edge])
		"floors":
			var cell := HouseGrid.key_to_cell(key)
			var object_key := house.object_at(level, cell)
			if object_key != "":
				result.append([level, "objects", object_key])
			result.append([level + 1, "floors", key])
			for edge in HouseGrid.cell_edges(cell):
				result.append([level, "walls", edge])
		"walls":
			result.append([level + 1, "walls", key])
			for cell in HouseGrid.edge_cells(key):
				result.append([level + 1, "floors", HouseGrid.cell_key(cell)])
	return result


## Revisa una lista de escrituras que AGREGAN o cambian piezas.
## Las revisa en orden, como si se fueran aplicando (así un "cuarto" puede
## poner el piso y después las paredes que se apoyan en él).
## Devuelve {"ok": escrituras válidas, "blocked": escrituras rechazadas}.
static func check_placement(house: HouseData, writes: Array) -> Dictionary:
	var sim := house.duplicate_data()
	var ok: Array = []
	var blocked: Array = []
	for w in writes:
		if is_supported(sim, w["level"], w["layer"], w["key"], w["value"]):
			ok.append(w)
			sim.apply([w])
		else:
			blocked.append(w)
	return {"ok": ok, "blocked": blocked}


## Revisa una lista de escrituras que QUITAN piezas (value = null).
## Una pieza no se puede quitar si algo que no se quita con ella quedaría en
## el aire (por ejemplo, cimientos con un piso encima).
## Devuelve {"ok": escrituras válidas, "blocked": escrituras rechazadas}.
static func check_removal(house: HouseData, writes: Array) -> Dictionary:
	var ok: Array = writes.duplicate()
	var blocked: Array = []
	# Se repite hasta que no cambie nada: si se bloquea una pieza, otra que
	# dependía de que esa se quitara también puede quedar bloqueada.
	while true:
		var removing := {}
		for w in ok:
			removing[_id(w["level"], w["layer"], w["key"])] = true
		var sim := house.duplicate_data()
		sim.apply(ok)

		var newly_blocked: Array = []
		for w in ok:
			for dep in dependents(house, w["level"], w["layer"], w["key"]):
				if removing.has(_id(dep[0], dep[1], dep[2])):
					continue
				var dep_value: Variant = sim.get_piece(dep[0], dep[1], dep[2])
				if dep_value != null and not is_supported(sim, dep[0], dep[1], dep[2], dep_value):
					newly_blocked.append(w)
					break

		if newly_blocked.is_empty():
			break
		for w in newly_blocked:
			ok.erase(w)
			blocked.append(w)
	return {"ok": ok, "blocked": blocked}


static func _is_object_supported(house: HouseData, level: int, key: String, value: Dictionary) -> bool:
	var item := Catalog.get_item(value["item"])
	if item.is_empty():
		return false
	if item.get("kind", "") == "stairs" and level >= HouseGrid.MAX_LEVELS - 1:
		return false
	var footprint := HouseData.item_footprint(item)
	var anchor := HouseData.object_anchor(value)
	var rot := int(value.get("rot", 0))

	for cell in HouseGrid.object_cells(footprint, anchor, rot):
		if not house.has_piece(level, "floors", HouseGrid.cell_key(cell)):
			return false
		var other := house.object_at(level, cell)
		if other != "" and other != key:
			return false
	for edge in HouseGrid.object_inner_edges(footprint, anchor, rot):
		if house.has_piece(level, "walls", edge):
			return false
	return true


static func _id(level: int, layer: String, key: String) -> String:
	return "%d|%s|%s" % [level, layer, key]
