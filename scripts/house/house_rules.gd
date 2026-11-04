class_name HouseRules
## Reglas de construcción: qué se puede poner, qué se puede quitar y dónde.
##
## Solo lógica sobre HouseData (nada 3D, nada de pantalla). El servidor tiene
## una copia exacta en server/nakama/modules/neighborhood_house.lua: si
## cambiás una regla aquí, cambiala allá también (y sus pruebas).
##
## Reglas de "apoyo" (algo tiene que sostener cada pieza):
##   - Cimientos: solo en la planta baja, dentro del lote.
##   - Piso en planta baja: sobre cimientos.
##   - Piso en un nivel de arriba: sobre otro piso, junto a una pared de
##     abajo (así sirve para hacer un balcón) o cerca de un PILAR de abajo
##     (a 2 celdas o menos), y no encima de una escalera ni de un techo.
##   - Pared en planta baja: junto a cimientos.
##   - Pared arriba: junto a un piso de ese nivel, o encima de otra pared, y
##     no atravesando un techo del piso de abajo.
##   - Objeto: todas sus celdas con piso, sin otro objeto y sin paredes
##     atravesadas. Las escaleras no pueden ir en el último nivel. Lo que va
##     "afuera" (escalera metálica, pilar) en la planta baja no necesita piso:
##     va sobre el pasto o los cimientos.
##   - Techo: dentro del lote, y sin una pared o un piso del nivel de arriba
##     metidos adentro (lo atravesarían).
##
## Además (avisos, no prohíben): un piso de arriba sin escalera que llegue
## queda "sin acceso" (ver problems).

## Hasta cuántas celdas de distancia sostiene un pilar al piso de arriba.
const PILLAR_REACH := 2


## ¿Esta pieza queda bien apoyada en la casa?
## `value` es la pieza (hace falta para los objetos y techos).
static func is_supported(house: HouseData, level: int, layer: String, key: String, value: Dictionary) -> bool:
	match layer:
		"foundation":
			var foundation_cell := HouseGrid.key_to_cell(key)
			if level > 0 or not HouseGrid.is_valid_level(level) or not HouseGrid.is_cell_in_lot(foundation_cell) or is_blocked(foundation_cell):
				return false
			# Pulido 2C: en un sótano, antes hay que excavar esa celda.
			return level == 0 or house.has_piece(level, "excavation", key)
		"excavation":
			var dig_cell := HouseGrid.key_to_cell(key)
			if level >= 0 or not HouseGrid.is_valid_level(level) or not HouseGrid.is_cell_in_lot(dig_cell) or is_blocked(dig_cell):
				return false
			# Se excava de arriba hacia abajo: el sótano de abajo sobre el de arriba.
			return level == -1 or house.has_piece(level + 1, "excavation", key)
		"floors":
			var cell := HouseGrid.key_to_cell(key)
			if not HouseGrid.is_cell_in_lot(cell) or is_blocked(cell):
				return false
			if level < 0:
				return house.has_piece(level, "foundation", key)
			if level == 0:
				return house.has_piece(0, "foundation", key) and not is_stairs_cell(house, -1, cell)
			if is_stairs_cell(house, level - 1, cell) or is_under_roof(house, level - 1, [cell]):
				return false
			if house.has_piece(level - 1, "floors", key):
				return true
			# También sirve una pared de abajo en cualquiera de sus 4 lados.
			for edge in HouseGrid.cell_edges(cell):
				if house.has_piece(level - 1, "walls", edge):
					return true
			return has_pillar_near(house, level - 1, cell)
		"walls":
			if not HouseGrid.is_edge_in_lot(key):
				return false
			if level > 0 and is_under_roof(house, level - 1, HouseGrid.edge_cells(key)):
				return false
			if level < 0 and not house.has_piece(level, "foundation", HouseGrid.cell_key(HouseGrid.edge_cells(key)[0])) \
					and not house.has_piece(level, "foundation", HouseGrid.cell_key(HouseGrid.edge_cells(key)[1])):
				return false
			var support_layer := "foundation" if level <= 0 else "floors"
			for cell in HouseGrid.edge_cells(key):
				if house.has_piece(level, support_layer, HouseGrid.cell_key(cell)):
					return true
			return level > 0 and house.has_piece(level - 1, "walls", key)
		"objects":
			return _is_object_supported(house, level, key, value)
		"roofs":
			var rect := HouseData.roof_rect(value)
			if level < 0 or not Rect2i(Vector2i.ZERO, HouseGrid.LOT_SIZE).encloses(rect):
				return false
			for roof_x in range(rect.position.x, rect.end.x):
				for roof_z in range(rect.position.y, rect.end.y):
					if is_blocked(Vector2i(roof_x, roof_z)):
						return false
			return roof_blocker(house, level, rect) == ""
	return false


## Pulido 2C: ¿hay un obstáculo sin limpiar (árbol, roca, laguito...) en la celda?
static func is_blocked(cell: Vector2i) -> bool:
	return not HouseData.blocked_cells.is_empty() and HouseData.blocked_cells.has(HouseGrid.cell_key(cell))


## ¿Hay una escalera en esa celda de ese nivel?
static func is_stairs_cell(house: HouseData, level: int, cell: Vector2i) -> bool:
	var key := house.object_at(level, cell)
	if key == "":
		return false
	return kind_of(house.get_piece(level, "objects", key)) == "stairs"


## Tipo ("kind") del catálogo de una pieza.
static func kind_of(value: Variant) -> String:
	if value == null:
		return ""
	return Catalog.get_item(value.get("item", "")).get("kind", "")


## ¿Hay un pilar de ese nivel a PILLAR_REACH celdas o menos?
static func has_pillar_near(house: HouseData, level: int, cell: Vector2i) -> bool:
	for key in house.get_layer(level, "objects"):
		var value: Dictionary = house.get_piece(level, "objects", key)
		if kind_of(value) != "pillar":
			continue
		var pillar := HouseData.object_anchor(value)
		if absi(pillar.x - cell.x) <= PILLAR_REACH and absi(pillar.y - cell.y) <= PILLAR_REACH:
			return true
	return false


## ¿Alguna de esas celdas queda adentro de un techo de ese nivel?
static func is_under_roof(house: HouseData, level: int, cells: Array) -> bool:
	if level < 0:
		return false  # En un sótano no hay techos (el techo es el piso de arriba).
	for key in house.get_layer(level, "roofs"):
		var rect := HouseData.roof_rect(house.get_piece(level, "roofs", key))
		var all_inside := true
		for cell in cells:
			if not rect.has_point(cell):
				all_inside = false
		if all_inside:
			return true
	return false


## Por qué no se puede poner un techo ahí ("" = se puede): una pared o un
## piso del nivel de arriba metido adentro del techo lo atravesaría.
static func roof_blocker(house: HouseData, level: int, rect: Rect2i) -> String:
	var above := level + 1
	if above >= HouseGrid.MAX_LEVELS or level < 0:
		return ""
	for key in house.get_layer(above, "walls"):
		var cells := HouseGrid.edge_cells(key)
		if rect.has_point(cells[0]) and rect.has_point(cells[1]):
			return "Ahí pasa una pared del piso de arriba: atravesaría el techo."
	for key in house.get_layer(above, "floors"):
		if rect.has_point(HouseGrid.key_to_cell(key)):
			return "Ahí arriba hay piso: el techo va encima de todo."
	return ""


## Lo que se borra de verdad al quitar una pieza (Pulido 2: el basurero borra
## TODO): la pieza y, en cascada, lo que se apoyaba solo en ella y quedaría en
## el aire (paredes de un cimiento, el piso de arriba de una pared...).
## Devuelve la lista de escrituras de quitar, la pieza pedida primero.
static func removal_closure(house: HouseData, first: Dictionary) -> Array:
	var result: Array = [first]
	var sim := house.duplicate_data()
	sim.apply([first])
	var changed := true
	while changed:
		changed = false
		var fallen: Array = []
		for level in HouseGrid.level_range():
			for layer in HouseData.LAYERS:
				for key in sim.get_layer(level, layer):
					var value: Dictionary = sim.get_piece(level, layer, key)
					# Solo cae lo que estaba bien apoyado antes y ahora no.
					if is_supported(house, level, layer, key, house.get_piece(level, layer, key)) \
							and not is_supported(sim, level, layer, key, value):
						fallen.append(HouseData.write(level, layer, key, null))
		if not fallen.is_empty():
			changed = true
			result.append_array(fallen)
			sim.apply(fallen)
	return result


## ¿Se puede agregar otro piso? "" si sí; si no, el motivo en palabras.
## Hace falta algo construido en el piso de arriba y que no todo esté tapado
## por un techo (nada se apoya en un techo).
static func add_floor_problem(house: HouseData) -> String:
	var total := house.floors_total()
	if total >= HouseGrid.MAX_LEVELS:
		return "Ya tenés todos los pisos que entran (la planta baja y %d más)." % (HouseGrid.MAX_LEVELS - 1)
	var top := total - 1
	var cells: Array = []
	for key in house.get_layer(top, "floors"):
		cells.append(HouseGrid.key_to_cell(key))
	if top == 0:
		for key in house.get_layer(0, "foundation"):
			var cell := HouseGrid.key_to_cell(key)
			if not cell in cells:
				cells.append(cell)
	if cells.is_empty():
		return "Primero construí el piso de abajo (cimientos o piso)."
	for cell in cells:
		if not is_under_roof(house, top, [cell]):
			return ""
	return "Para agregar un piso tiene que haber una parte sin techo."


## ¿Se puede agregar otro sótano? "" si sí; si no, el motivo.
## Hace falta algo construido en el nivel de arriba (cimientos si es el primero).
static func add_basement_problem(house: HouseData) -> String:
	var lowest := house.lowest_level()
	if -lowest >= HouseGrid.MAX_BASEMENTS:
		return "Ya tenés los %d sótanos que entran." % HouseGrid.MAX_BASEMENTS
	if house.get_layer(lowest, "foundation").is_empty() and house.get_layer(lowest, "floors").is_empty():
		return "Primero construí cimientos o piso en %s." % level_name(lowest).to_lower()
	return ""


## Piezas que se apoyan en esta (si se quita, podrían quedar en el aire).
## Devuelve una lista de [nivel, capa, clave].
static func dependents(house: HouseData, level: int, layer: String, key: String) -> Array:
	var result: Array = []
	match layer:
		"foundation":
			result.append([level, "floors", key])
			for edge in HouseGrid.cell_edges(HouseGrid.key_to_cell(key)):
				result.append([level, "walls", edge])
			# Lo de afuera (pilares, escalera metálica) puede ir sobre cimientos.
			var object_key := house.object_at(level, HouseGrid.key_to_cell(key))
			if object_key != "":
				result.append([level, "objects", object_key])
		"excavation":
			# Lo que se construyó adentro de la excavación y la de más abajo.
			result.append([level, "foundation", key])
			result.append([level, "floors", key])
			for edge in HouseGrid.cell_edges(HouseGrid.key_to_cell(key)):
				result.append([level, "walls", edge])
			if level > HouseGrid.MIN_LEVEL:
				result.append([level - 1, "excavation", key])
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
		"objects":
			var value: Variant = house.get_piece(level, layer, key)
			if kind_of(value) == "pillar":
				var pillar := HouseData.object_anchor(value)
				for x in range(pillar.x - PILLAR_REACH, pillar.x + PILLAR_REACH + 1):
					for z in range(pillar.y - PILLAR_REACH, pillar.y + PILLAR_REACH + 1):
						result.append([level + 1, "floors", HouseGrid.cell_key(Vector2i(x, z))])
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
			if _falling_dependent(house, sim, removing, w).size() > 0:
				newly_blocked.append(w)

		if newly_blocked.is_empty():
			break
		for w in newly_blocked:
			ok.erase(w)
			blocked.append(w)
	return {"ok": ok, "blocked": blocked}


## Lo primero que quedaría en el aire si se quita `w` (y lo de `removing`):
## [nivel, capa, clave], o [] si nada.
static func _falling_dependent(house: HouseData, sim: HouseData, removing: Dictionary, w: Dictionary) -> Array:
	for dep in dependents(house, w["level"], w["layer"], w["key"]):
		if removing.has(_id(dep[0], dep[1], dep[2])):
			continue
		if not HouseGrid.is_valid_level(dep[0]):
			continue
		var dep_value: Variant = sim.get_piece(dep[0], dep[1], dep[2])
		if dep_value != null and not is_supported(sim, dep[0], dep[1], dep[2], dep_value):
			return dep
	return []


## Por qué no se puede quitar una pieza, en palabras ("Esta pared sostiene
## el piso de arriba"). "" si sí se puede.
static func removal_reason(house: HouseData, w: Dictionary) -> String:
	var removing := {_id(w["level"], w["layer"], w["key"]): true}
	var sim := house.duplicate_data()
	sim.apply([HouseData.write(w["level"], w["layer"], w["key"], null)])
	var dep := _falling_dependent(house, sim, removing, w)
	if dep.is_empty():
		return ""
	var what: String = {"floors": "el piso", "walls": "la pared", "objects": "lo que está"}.get(dep[1], "algo")
	var where := " de arriba" if dep[0] > w["level"] else " de encima"
	match w["layer"]:
		"walls":
			return "Esta pared sostiene %s%s." % [what, where]
		"objects":
			return "Este pilar sostiene %s%s." % [what, where]
		"floors":
			return "Este piso tiene %s%s." % [what, where] if dep[1] != "objects" else "Este piso tiene un mueble encima."
		"foundation":
			return "Estos cimientos sostienen %s%s." % [what, " de encima"]
	return "Hay algo apoyado encima."


## ¿Se puede llegar a ese piso? La planta baja sí; uno de arriba, si hay una
## escalera terminada en el piso de abajo y a ese también se llega.
static func has_access(house: HouseData, level: int) -> bool:
	if level == 0:
		return true
	# Una escalera de un nivel lo une con el de arriba: para subir al piso 2 se usa
	# la del piso 1; para bajar al sótano -1, la que está EN el sótano -1.
	var stairs_level := level - 1 if level > 0 else level
	for key in house.get_layer(stairs_level, "objects"):
		var value: Dictionary = house.get_piece(stairs_level, "objects", key)
		if kind_of(value) == "stairs" and not HouseData.is_under_construction(value):
			return has_access(house, level - 1 if level > 0 else level + 1)
	return false


## Lo que falta o está mal en la casa (para la lista de "lo que falta"):
## [{level, layer, key, text}]. layer = "" para un piso entero.
##   - Un piso de arriba con algo construido y sin escalera que llegue.
##   - Una pieza sin apoyo (no debería pasar, pero las casas viejas o las
##     reglas nuevas pueden dejar alguna).
static func problems(house: HouseData) -> Array:
	var result: Array = []
	for level in HouseGrid.level_range():
		for layer in HouseData.LAYERS:
			for key in house.get_layer(level, layer):
				var value: Dictionary = house.get_piece(level, layer, key)
				if not is_supported(house, level, layer, key, value):
					var item_name: String = Catalog.get_item(value.get("item", "")).get("name", "Pieza")
					result.append({"level": level, "layer": layer, "key": key,
						"text": "%s: %s sin apoyo" % [level_name(level), item_name]})
		if level != 0 and not house.get_layer(level, "floors").is_empty() and not has_access(house, level):
			var from_level: int = level - 1 if level > 0 else level + 1
			result.append({"level": level, "layer": "", "key": "",
				"text": "%s: sin acceso (falta una escalera desde %s)" % [level_name(level), level_name(from_level).to_lower()]})
	return result


static func level_name(level: int) -> String:
	return HouseGrid.level_name(level)


static func _is_object_supported(house: HouseData, level: int, key: String, value: Dictionary) -> bool:
	var item := Catalog.get_item(value["item"])
	if item.is_empty():
		return false
	var kind: String = item.get("kind", "")
	if kind == "stairs" and level >= HouseGrid.MAX_LEVELS - 1:
		return false
	# Solo los muebles van en diagonal.
	if value.get("diag", false) and kind != "furniture":
		return false
	var cells := HouseData.value_cells(value)
	# Lo de afuera, en la planta baja, va sobre el pasto o los cimientos.
	var on_ground: bool = level == 0 and item.get("outdoor", false)
	for cell in cells:
		if on_ground:
			if not HouseGrid.is_cell_in_lot(cell) or is_blocked(cell):
				return false
		elif not house.has_piece(level, "floors", HouseGrid.cell_key(cell)):
			return false
		var other := house.object_at(level, cell)
		if other != "" and other != key:
			return false
	for edge in HouseGrid.inner_edges_of_cells(cells):
		if house.has_piece(level, "walls", edge):
			return false
	return true


static func _id(level: int, layer: String, key: String) -> String:
	return "%d|%s|%s" % [level, layer, key]
