class_name HouseMove
extends RefCounted
## Pulido 6A (8): MOVER LA CASA ENTERA a otro lugar de la parcela, con un costo.
##
## El material no se pierde: no se vende ni se vuelve a comprar nada. Todas las piezas
## (también los muebles, la pintura y las obras en marcha) se corren las mismas celdas y
## el jugador paga solo la MUDANZA: `base + por pieza + por distancia`, con un tope
## (data/progression.json → move_house). El servidor repite esta misma cuenta
## (neighborhood_rules.lua → move_fee / move_house) y es el que cobra.
##
## Comparte la lógica de las plantillas (5E): se elige el lugar con la misma silueta
## (TemplatePlacer) y las revisiones de apoyo son las de siempre (HouseRules).
## Sin nada 3D: todo son cuentas sobre la casa.

## Capas en el orden en que se escriben (cada una se apoya en la anterior).
const LAYER_ORDER := ["foundation", "excavation", "floors", "walls", "objects", "roofs"]
## Respaldo si falta la sección en progression.json.
const DEFAULT_CONFIG := {"base": 60, "per_piece": 1, "per_step": 4, "max": 5000}


static func config() -> Dictionary:
	var cfg: Dictionary = DEFAULT_CONFIG.duplicate()
	var saved: Variant = Catalog.progression.get("move_house", {})
	if saved is Dictionary:
		for field in saved:
			cfg[field] = saved[field]
	return cfg


## Cuántas piezas tiene la casa (todas las capas, todos los niveles).
static func piece_count(house: HouseData) -> int:
	var total := 0
	for level in HouseGrid.level_range():
		for layer in LAYER_ORDER:
			total += house.get_layer(level, layer).size()
	return total


## Lo que cuesta mudar la casa `delta` celdas. 0 si no se mueve (o la casa está vacía).
static func fee(house: HouseData, delta: Vector2i) -> int:
	if delta == Vector2i.ZERO or piece_count(house) == 0:
		return 0
	var cfg := config()
	var total := float(cfg["base"]) + float(cfg["per_piece"]) * piece_count(house) \
		+ float(cfg["per_step"]) * (absi(delta.x) + absi(delta.y))
	return mini(int(round(total)), int(cfg["max"]))


## El rectángulo (en celdas) que ocupa toda la casa: Rect2i. Vacío si no hay nada.
static func footprint(house: HouseData) -> Rect2i:
	var lo := Vector2i(1 << 20, 1 << 20)
	var hi := Vector2i(-(1 << 20), -(1 << 20))
	var found := false
	for level in HouseGrid.level_range():
		for layer in LAYER_ORDER:
			var pieces: Dictionary = house.get_layer(level, layer)
			for key in pieces:
				var box := HouseTemplate.piece_box(layer, key, pieces[key])
				lo = Vector2i(mini(lo.x, box.position.x), mini(lo.y, box.position.y))
				hi = Vector2i(maxi(hi.x, box.end.x), maxi(hi.y, box.end.y))
				found = true
	if not found:
		return Rect2i()
	return Rect2i(lo, hi - lo)


## Una "plantilla" con TODA la casa (también muebles), para dibujar la silueta con el mismo
## código de las plantillas. `origin` = la esquina de la casa ahora; las piezas van relativas a ella.
static func as_template(house: HouseData) -> Dictionary:
	var box := footprint(house)
	if box.size == Vector2i.ZERO:
		return {}
	var pieces: Array = []
	for level in HouseGrid.level_range():
		for layer in LAYER_ORDER:
			var layer_pieces: Dictionary = house.get_layer(level, layer)
			for key in layer_pieces:
				var value: Dictionary = (layer_pieces[key] as Dictionary).duplicate(true)
				var relative_key: String = key
				match layer:
					"objects":
						var anchor := HouseData.object_anchor(value) - box.position
						value["cell"] = [anchor.x, anchor.y]
					"roofs":
						var rect := HouseData.roof_rect(value)
						value["rect"] = [rect.position.x - box.position.x, rect.position.y - box.position.y, rect.size.x, rect.size.y]
					_:
						relative_key = HouseTemplate.shift_key(layer, key, -box.position)
				pieces.append({"l": level, "y": layer, "k": relative_key, "v": value})
	return {"name": "La casa", "size": [box.size.x, box.size.y], "pieces": pieces, "origin": [box.position.x, box.position.y], "move": true}


## Las escrituras de la mudanza: primero se quita lo de las celdas viejas y después se pone
## todo en las nuevas (mismas piezas, mismos colores y obras). Objetos y techos conservan su nombre.
static func writes_for(house: HouseData, delta: Vector2i) -> Array:
	var removals: Array = []
	var placements: Array = []
	if delta == Vector2i.ZERO:
		return []
	for level in HouseGrid.level_range():
		for layer in LAYER_ORDER:
			var pieces: Dictionary = house.get_layer(level, layer)
			var new_keys := {}
			for key in pieces:
				var value: Dictionary = (pieces[key] as Dictionary).duplicate(true)
				var new_key: String = key
				match layer:
					"objects":
						var anchor := HouseData.object_anchor(value) + delta
						value["cell"] = [anchor.x, anchor.y]
					"roofs":
						var rect := HouseData.roof_rect(value)
						value["rect"] = [rect.position.x + delta.x, rect.position.y + delta.y, rect.size.x, rect.size.y]
					_:
						new_key = HouseTemplate.shift_key(layer, key, delta)
				new_keys[new_key] = true
				placements.append(HouseData.write(level, layer, new_key, value))
			# Lo de las celdas viejas que no vuelve a ocupar otra pieza se quita.
			if layer != "objects" and layer != "roofs":
				for key in pieces:
					if not new_keys.has(key):
						removals.append(HouseData.write(level, layer, key, null))
	return removals + placements


## Revisa la mudanza. Devuelve {valid, reason, writes, fee}.
## reason: "empty" (no hay casa), "same" (no se movió), "outside" (se sale del lote),
## "blocked" (obstáculos, la cerca o terreno cerrado) o "support" (algo quedaría sin apoyo).
static func check(house: HouseData, delta: Vector2i) -> Dictionary:
	var result := {"valid": false, "reason": "empty", "writes": [], "fee": 0}
	if piece_count(house) == 0:
		return result
	if delta == Vector2i.ZERO:
		result["reason"] = "same"
		return result
	var writes := writes_for(house, delta)
	result["writes"] = writes
	result["fee"] = fee(house, delta)
	# Con la casa ya mudada, ¿cada pieza tiene dónde apoyarse y está libre de obstáculos?
	for w in writes:
		if w["value"] == null:
			continue
		if w["layer"] == "walls":
			if not HouseGrid.is_edge_in_lot(w["key"]):
				result["reason"] = "outside"
				return result
			continue
		for cell in HouseTemplate.cells_of(w["layer"], w["key"], w["value"]):
			if not HouseGrid.is_cell_in_lot(cell):
				result["reason"] = "outside"
				return result
	var moved := house.duplicate_data()
	moved.apply(writes)
	for w in writes:
		if w["value"] == null or w["layer"] == "walls":
			continue
		for cell in HouseTemplate.cells_of(w["layer"], w["key"], w["value"]):
			if HouseRules.is_blocked(cell):
				result["reason"] = "blocked"
				return result
	for w in writes:
		if w["value"] != null and not HouseRules.is_supported(moved, w["level"], w["layer"], w["key"], w["value"]):
			result["reason"] = "support"
			return result
	result["valid"] = true
	result["reason"] = ""
	return result


static func reason_text(reason: String) -> String:
	match reason:
		"empty":
			return "Todavía no hay casa para mudar."
		"same":
			return "Arrastrá la casa a otro lugar."
		"outside":
			return "Se sale del lote."
		"blocked":
			return "Hay obstáculos, la cerca o terreno todavía cerrado."
		"support":
			return "Algo no tendría apoyo ahí."
	return ""
