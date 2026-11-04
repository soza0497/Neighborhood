class_name HouseTemplate
extends RefCounted
## Plantilla de casa (Pulido 5E): la ESTRUCTURA de una casa, sin muebles, para
## volver a colocarla en otro lugar del lote (una mudanza).
##
## Lleva: cimientos, excavación de sótanos, pisos, paredes (con sus puertas y
## ventanas), techos, escaleras y pilares, con su pintura. NO lleva muebles,
## electrodomésticos, plantas ni adornos.
##
## Una plantilla es un diccionario simple (va a la partida y a la nube con las
## opciones):
##   {id, name, format, size: [ancho, fondo], saved_unix,
##    pieces: [{l: nivel, y: capa, k: clave, v: pieza}]}
## Las claves van relativas a la esquina de arriba a la izquierda de la plantilla
## (celda 0,0). Los objetos y techos no traen nombre: reciben uno nuevo al colocar.
##
## Aquí no hay nada 3D ni de pantalla: todo son funciones sin estado (se prueban
## sin abrir el juego). Colocar de verdad pasa por el plan y la factura del
## constructor (HouseBuilder.place_template) y el servidor lo revisa todo otra vez.

const FORMAT := 1
## Capas que viajan, en el orden en que se colocan (cada una se apoya en la anterior).
const LAYER_ORDER := ["excavation", "foundation", "floors", "walls", "objects", "roofs"]
## De los objetos solo viajan estos tipos del catálogo (nada de muebles).
const STRUCTURAL_KINDS := ["stairs", "pillar"]
## Campos de una pieza que son del momento y no de la plantilla (el cronómetro de obra).
const TRANSIENT_FIELDS := ["ready_at"]


## Orden de los niveles al colocar: primero los sótanos de arriba hacia abajo
## (-1, -2, -3) y después de la planta baja hacia arriba.
static func level_order() -> Array:
	var result: Array = []
	for level in range(-1, HouseGrid.MIN_LEVEL - 1, -1):
		result.append(level)
	for level in range(0, HouseGrid.MAX_LEVELS):
		result.append(level)
	return result


## ¿Esta pieza viaja en la plantilla?
static func is_structural(layer: String, value: Variant) -> bool:
	if not (value is Dictionary) or not layer in LAYER_ORDER:
		return false
	if layer == "objects":
		return Catalog.get_item(value.get("item", "")).get("kind", "") in STRUCTURAL_KINDS
	return true


## Saca la plantilla de una casa. Devuelve {} si no hay nada que guardar.
static func capture(house: HouseData, template_name := "") -> Dictionary:
	var lo := Vector2i(1 << 20, 1 << 20)
	var hi := Vector2i(-(1 << 20), -(1 << 20))
	var found: Array = []
	for level in HouseGrid.level_range():
		for layer in LAYER_ORDER:
			var pieces: Dictionary = house.get_layer(level, layer)
			for key in pieces:
				var value: Dictionary = pieces[key]
				if not is_structural(layer, value):
					continue
				var box := piece_box(layer, key, value)
				lo = Vector2i(mini(lo.x, box.position.x), mini(lo.y, box.position.y))
				hi = Vector2i(maxi(hi.x, box.end.x), maxi(hi.y, box.end.y))
				found.append([level, layer, key, value])
	if found.is_empty():
		return {}
	var pieces_out: Array = []
	for entry in found:
		var layer: String = entry[1]
		var value: Dictionary = (entry[3] as Dictionary).duplicate(true)
		for field in TRANSIENT_FIELDS:
			value.erase(field)
		var key: String = entry[2]
		match layer:
			"objects":
				var anchor := HouseData.object_anchor(value)
				value["cell"] = [anchor.x - lo.x, anchor.y - lo.y]
				key = ""
			"roofs":
				var rect := HouseData.roof_rect(value)
				value["rect"] = [rect.position.x - lo.x, rect.position.y - lo.y, rect.size.x, rect.size.y]
				key = ""
			_:
				key = shift_key(layer, key, -lo)
		pieces_out.append({"l": entry[0], "y": layer, "k": key, "v": value})
	return {"id": "", "name": template_name, "format": FORMAT, "size": [hi.x - lo.x, hi.y - lo.y],
		"saved_unix": int(Time.get_unix_time_from_system()), "pieces": pieces_out}


## Cuadro de celdas que ocupa una pieza (para medir la plantilla). Las paredes
## cuentan sus dos vértices: el cuadro llega justo hasta su borde.
static func piece_box(layer: String, key: String, value: Dictionary) -> Rect2i:
	match layer:
		"walls":
			var vertices := HouseGrid.edge_vertices(key)
			return Rect2i(vertices[0], vertices[1] - vertices[0])
		"objects":
			var cells := HouseData.value_cells(value)
			var box := Rect2i(cells[0], Vector2i.ONE)
			for cell in cells:
				box = box.merge(Rect2i(cell, Vector2i.ONE))
			return box
		"roofs":
			return HouseData.roof_rect(value)
	return Rect2i(HouseGrid.key_to_cell(key), Vector2i.ONE)


## Mueve la clave de una pieza de celda ("x,z") o de pared ("h:x,z" / "v:x,z").
static func shift_key(layer: String, key: String, offset: Vector2i) -> String:
	if layer == "walls":
		return HouseGrid.edge_key(HouseGrid.edge_vertex(key) + offset, HouseGrid.is_edge_horizontal(key))
	return HouseGrid.cell_key(HouseGrid.key_to_cell(key) + offset)


## Las escrituras que colocan la plantilla con su esquina en `offset`, ya en orden
## (cada pieza se apoya en las de antes). Los objetos y techos reciben nombres
## nuevos "o<N>" a partir del contador de la casa (que NO se mueve: ver claim_ids).
static func writes_for(template: Dictionary, offset: Vector2i, house: HouseData) -> Array:
	var by_level := {}
	for piece in template.get("pieces", []):
		var level := int(piece["l"])
		if not by_level.has(level):
			by_level[level] = {}
		var layer: String = piece["y"]
		if not by_level[level].has(layer):
			by_level[level][layer] = []
		by_level[level][layer].append(piece)
	var writes: Array = []
	var next_number := house.next_id
	for level in level_order():
		if not by_level.has(level):
			continue
		for layer in LAYER_ORDER:
			for piece in by_level[level].get(layer, []):
				var value: Dictionary = (piece["v"] as Dictionary).duplicate(true)
				var key: String = piece["k"]
				match layer:
					"objects":
						var cell: Array = value["cell"]
						value["cell"] = [int(cell[0]) + offset.x, int(cell[1]) + offset.y]
						key = "o%d" % next_number
						next_number += 1
					"roofs":
						var rect: Array = value["rect"]
						value["rect"] = [int(rect[0]) + offset.x, int(rect[1]) + offset.y, int(rect[2]), int(rect[3])]
						key = "o%d" % next_number
						next_number += 1
					_:
						key = shift_key(layer, key, offset)
				writes.append(HouseData.write(level, layer, key, value))
	return writes


## Reserva los nombres "o<N>" que usan las escrituras (el contador de la casa pasa
## de ellos), para que lo que se construya después no los repita.
static func claim_ids(house: HouseData, writes: Array) -> void:
	for w in writes:
		var key: String = w["key"]
		if key.begins_with("o") and key.substr(1).is_valid_int():
			house.next_id = maxi(house.next_id, int(key.substr(1)) + 1)


## ¿Se puede colocar ahí? Devuelve:
##   {valid, reason, writes, cost}
## reason (si no vale): "outside" (se sale del lote), "blocked" (obstáculo o terreno
## todavía cerrado, la cerca incluida), "occupied" (choca con lo ya construido),
## "support" (algo quedaría sin apoyo), "locked" (piezas de un nivel que todavía
## no tenés) o "empty". El servidor repite todas estas revisiones al cobrar.
static func check(house: HouseData, template: Dictionary, offset: Vector2i) -> Dictionary:
	var writes := writes_for(template, offset, house)
	var result := {"valid": false, "reason": "empty", "writes": writes, "cost": 0}
	if writes.is_empty():
		return result
	var reason := _first_problem(house, writes)
	if reason == "":
		var quote := Economy.quote(house, writes)
		result["cost"] = -int(quote["money"])
		reason = ""
	result["valid"] = reason == ""
	result["reason"] = reason
	return result


static func _first_problem(house: HouseData, writes: Array) -> String:
	var lot := Rect2i(Vector2i.ZERO, HouseGrid.LOT_SIZE)
	var blocked := false
	var occupied := false
	var locked := false
	for w in writes:
		var layer: String = w["layer"]
		var value: Dictionary = w["value"]
		var box := piece_box(layer, w["key"], value)
		# Las paredes pueden tocar el borde del lote (su vértice llega justo al final).
		var fits := lot.encloses(box) if layer != "walls" else HouseGrid.is_edge_in_lot(w["key"])
		if not fits:
			return "outside"
		for cell in cells_of(layer, w["key"], value):
			if HouseRules.is_blocked(cell):
				blocked = true
		if layer != "objects" and layer != "roofs" and house.has_piece(w["level"], layer, w["key"]):
			occupied = true
		for field in ["item", "opening"]:
			var item_id: String = str(value.get(field, ""))
			if item_id != "" and not Economy.is_unlocked(item_id):
				locked = true
	if blocked:
		return "blocked"
	if occupied:
		return "occupied"
	if locked:
		return "locked"
	var placement := HouseRules.check_placement(house, writes)
	if not placement["blocked"].is_empty():
		# Si falta apoyo de piso, pared o cimiento, es «support». Un objeto o techo que
		# choca con otro (sin que falte estructura) es «ocupado».
		for w in placement["blocked"]:
			if w["layer"] != "objects" and w["layer"] != "roofs":
				return "support"
		return "occupied"
	return ""


## Las celdas que toca una pieza (para mirar obstáculos).
static func cells_of(layer: String, key: String, value: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	match layer:
		"walls":
			for cell in HouseGrid.edge_cells(key):
				result.append(cell)
		"objects":
			result.append_array(HouseData.value_cells(value))
		"roofs":
			var rect := HouseData.roof_rect(value)
			for x in range(rect.position.x, rect.end.x):
				for z in range(rect.position.y, rect.end.y):
					result.append(Vector2i(x, z))
		_:
			result.append(HouseGrid.key_to_cell(key))
	return result


## Qué le decimos al jugador según el motivo.
static func reason_text(reason: String) -> String:
	match reason:
		"outside":
			return "Se sale del lote."
		"blocked":
			return "Hay obstáculos, la cerca o terreno todavía cerrado."
		"occupied":
			return "Choca con algo que ya está construido."
		"support":
			return "Algo no tendría apoyo ahí."
		"locked":
			return "Tiene piezas de un nivel que todavía no desbloqueaste."
		"empty":
			return "La plantilla está vacía."
	return ""


## Cuántas piezas de cada tipo tiene (para mostrar un resumen): {floors: n, walls: n...}.
static func summary(template: Dictionary) -> Dictionary:
	var counts := {}
	for piece in template.get("pieces", []):
		var layer: String = piece["y"]
		counts[layer] = int(counts.get(layer, 0)) + 1
	return counts
