extends Node
## Pruebas de las plantillas de casa (Pulido 5E), sin pantalla ni red.
##
##   godot --headless --path . res://tests/test_template.tscn
##
## Mira: guardar una casa y colocarla igual en otra celda (ida y vuelta), que NO
## lleva muebles ni objetos, que respeta la pintura, que se rechaza lo que choca
## o se sale, y la lista de plantillas (nombres, tope, renombrar, borrar, y que
## sobrevive a guardar y leer el JSON).

var _passed := 0
var _failed := 0


func _ready() -> void:
	HouseGrid.use_test_lot()
	HouseTemplates.autosave = false  # No tocar la partida de quien corre la prueba.
	GameState.settings = {}
	Economy.server_mode = false
	Economy.debug_unlock_all()
	_test_capture()
	_test_round_trip()
	_test_rejections()
	_test_ids_and_order()
	_test_store()
	print("\nPRUEBAS: %d pasaron, %d fallaron" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _check(condition: bool, description: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		print("FALLÓ: ", description)


## Una casa de 2 pisos desde (4,4): 6 x 5 celdas, puerta, ventana, pintura, escalera, pilar,
## techo plano arriba, y MUEBLES que no deben viajar.
func _sample_house(origin := Vector2i(4, 4)) -> HouseData:
	var house := HouseData.new()
	var o := origin
	var far := o + Vector2i(5, 4)
	var writes: Array = []
	for c in HouseGrid.cells_in_rect(o, far):
		writes.append(HouseData.write(0, "foundation", HouseGrid.cell_key(c), {"item": "foundation_basic"}))
		writes.append(HouseData.write(0, "floors", HouseGrid.cell_key(c), {"item": "floor_basic", "color": "#f4d58d"}))
	for edge in HouseGrid.edges_around_rect(o, far):
		writes.append(HouseData.write(0, "walls", edge, {"item": "wall_basic", "color_a": "#cfe8ff", "color_b": "#ffd1d1"}))
	var door := HouseGrid.edge_key(Vector2i(o.x + 2, far.y + 1), true)
	writes.append(HouseData.write(0, "walls", door, {"item": "wall_basic", "opening": "door_basic"}))
	var window := HouseGrid.edge_key(Vector2i(o.x + 4, o.y), true)
	writes.append(HouseData.write(0, "walls", window, {"item": "wall_basic", "opening": "window_basic"}))
	# Escalera (1x3) y un pilar en la planta baja.
	writes.append(HouseData.write(0, "objects", "o1", {"item": "stairs_basic", "cell": [o.x + 1, o.y + 1], "rot": 0}))
	writes.append(HouseData.write(0, "objects", "o2", {"item": "pillar_basic", "cell": [o.x + 4, o.y + 3], "rot": 0}))
	# Muebles: no viajan.
	writes.append(HouseData.write(0, "objects", "o3", {"item": "bed_basic", "cell": [o.x + 3, o.y + 1], "rot": 0, "ready_at": 5}))
	writes.append(HouseData.write(0, "objects", "o4", {"item": "plant_pot", "cell": [o.x + 4, o.y + 1], "rot": 0}))
	# Segundo piso (sin las celdas de la escalera) y techo plano.
	var stair_cells := {}
	for dz in 3:
		stair_cells[HouseGrid.cell_key(Vector2i(o.x + 1, o.y + 1 + dz))] = true
	for c in HouseGrid.cells_in_rect(o, far):
		if not stair_cells.has(HouseGrid.cell_key(c)):
			writes.append(HouseData.write(1, "floors", HouseGrid.cell_key(c), {"item": "floor_basic"}))
	for edge in HouseGrid.edges_around_rect(o, far):
		writes.append(HouseData.write(1, "walls", edge, {"item": "wall_basic"}))
	writes.append(HouseData.write(1, "roofs", "o5", {"item": "roof_flat", "rect": [o.x, o.y, 6, 5]}))
	house.next_id = 6
	house.apply(writes)
	return house


func _kinds(template: Dictionary) -> Array:
	var kinds: Array = []
	for piece in template["pieces"]:
		if piece["y"] == "objects":
			kinds.append(Catalog.get_item(piece["v"]["item"]).get("kind", ""))
	return kinds


## Las piezas de una plantilla en un orden fijo, para compararlas.
func _normalized(template: Dictionary) -> Array:
	var list: Array = []
	for piece in template["pieces"]:
		var value: Dictionary = (piece["v"] as Dictionary).duplicate()
		if value.has("rot"):
			value["rot"] = roundi(float(value["rot"]))  # El JSON devuelve 0 como 0.0: es lo mismo.
		list.append("%d|%s|%s|%s" % [piece["l"], piece["y"], piece["k"] if piece["y"] not in ["objects", "roofs"] else "", JSON.stringify(value, "", true)])
	list.sort()
	return list


func _test_capture() -> void:
	print("1) Qué guarda")
	var house := _sample_house()
	var template := HouseTemplate.capture(house, "Casa")
	var layers := HouseTemplate.summary(template)
	_check(int(layers.get("foundation", 0)) == 30 and int(layers.get("floors", 0)) == 30 + 27, "cimientos 30 y pisos 57 (%s)" % str(layers))
	_check(int(layers.get("walls", 0)) == 2 * 22, "paredes de los 2 pisos (%d)" % int(layers.get("walls", 0)))
	_check(int(layers.get("roofs", 0)) == 1, "el techo viaja")
	var kinds := _kinds(template)
	_check(kinds.size() == 2 and "stairs" in kinds and "pillar" in kinds, "de los objetos solo viajan escalera y pilar (%s)" % str(kinds))
	var has_furniture := false
	var has_timer := false
	for piece in template["pieces"]:
		if piece["y"] == "objects" and Catalog.get_item(piece["v"]["item"]).get("kind", "") == "furniture":
			has_furniture = true
		if (piece["v"] as Dictionary).has("ready_at"):
			has_timer = true
	_check(not has_furniture, "NO lleva muebles ni plantas")
	_check(not has_timer, "no lleva el cronómetro de obra")
	_check(template["size"] == [6, 5], "mide 6 x 5 celdas (%s)" % str(template["size"]))
	var door_found := false
	var paint_found := false
	var floor_color := false
	for piece in template["pieces"]:
		if piece["y"] == "walls" and piece["v"].get("opening", "") == "door_basic":
			door_found = true
		if piece["y"] == "walls" and piece["v"].get("color_a", "") == "#cfe8ff":
			paint_found = true
		if piece["y"] == "floors" and piece["v"].get("color", "") == "#f4d58d":
			floor_color = true
	_check(door_found, "la puerta y la ventana viajan en la pared")
	_check(paint_found and floor_color, "la pintura de paredes y pisos viaja")
	# Relativa: la esquina de arriba a la izquierda es 0,0.
	var min_cell := Vector2i(999, 999)
	for piece in template["pieces"]:
		if piece["y"] == "foundation":
			min_cell = min_cell.min(HouseGrid.key_to_cell(piece["k"]))
	_check(min_cell == Vector2i.ZERO, "las claves son relativas a la esquina (%s)" % str(min_cell))
	_check(HouseTemplate.capture(HouseData.new(), "x").is_empty(), "una casa vacía no da plantilla")
	var furniture_only := HouseData.new()
	furniture_only.apply([HouseData.write(0, "objects", "o1", {"item": "plant_pot", "cell": [3, 3], "rot": 0})])
	_check(HouseTemplate.capture(furniture_only, "x").is_empty(), "solo muebles tampoco da plantilla")


func _test_round_trip() -> void:
	print("\n2) Ida y vuelta: guardar y colocar igual en otra celda")
	var source := _sample_house(Vector2i(4, 4))
	var template := HouseTemplate.capture(source, "Casa")
	# Por el JSON, como cuando va a la partida o a la nube.
	var json := JSON.new()
	_check(json.parse(JSON.stringify(template)) == OK, "la plantilla se vuelve texto y se lee")
	var reread: Dictionary = json.data
	var empty := HouseData.new()
	empty.next_id = 20
	var offset := Vector2i(14, 17)
	var result := HouseTemplate.check(empty, reread, offset)
	_check(result["valid"], "cabe en un lote vacío en otra celda (%s)" % HouseTemplate.reason_text(result["reason"]))
	_check(int(result["cost"]) > 0, "tiene un costo (%d)" % int(result["cost"]))
	empty.apply(result["writes"])
	var copy := HouseTemplate.capture(empty, "Casa")
	_check(_normalized(copy) == _normalized(template), "la copia tiene EXACTAMENTE la misma estructura (%d piezas)" % (copy["pieces"] as Array).size())
	_check(copy["size"] == template["size"], "mismo tamaño")
	# Y está en el lugar pedido: la esquina de los cimientos.
	var min_cell := Vector2i(999, 999)
	for key in empty.get_layer(0, "foundation"):
		min_cell = min_cell.min(HouseGrid.key_to_cell(key))
	_check(min_cell == offset, "la esquina quedó en %s (está en %s)" % [str(offset), str(min_cell)])
	_check(empty.get_layer(0, "objects").size() == 2 and empty.get_layer(1, "roofs").size() == 1, "escalera, pilar y techo con nombres nuevos")
	var no_furniture := true
	for key in empty.get_layer(0, "objects"):
		if HouseRules.kind_of(empty.get_piece(0, "objects", key)) == "furniture":
			no_furniture = false
	_check(no_furniture, "la casa nueva no tiene muebles")
	# Colocar en el mismo lugar donde estaba la original también sirve (si está vacío).
	var again := HouseData.new()
	_check(HouseTemplate.check(again, reread, Vector2i(4, 4))["valid"], "se puede volver a colocar en el lugar original (vacío)")


func _test_rejections() -> void:
	print("\n3) Lo que se rechaza")
	var template := HouseTemplate.capture(_sample_house(), "Casa")
	var house := _sample_house(Vector2i(4, 4))
	var occupied := HouseTemplate.check(house, template, Vector2i(6, 6))
	_check(not occupied["valid"] and occupied["reason"] == "occupied", "encima de lo ya construido: ocupado (%s)" % occupied["reason"])
	var empty := HouseData.new()
	var outside := HouseTemplate.check(empty, template, Vector2i(HouseGrid.LOT_SIZE.x - 2, 5))
	_check(not outside["valid"] and outside["reason"] == "outside", "saliéndose del lote: afuera (%s)" % outside["reason"])
	var negative := HouseTemplate.check(empty, template, Vector2i(-1, 3))
	_check(not negative["valid"] and negative["reason"] == "outside", "con un lado fuera por la izquierda: afuera")
	var edge_ok := HouseTemplate.check(empty, template, HouseGrid.LOT_SIZE - Vector2i(6, 5))
	_check(edge_ok["valid"], "pegada al borde, sin salirse, cabe (%s)" % edge_ok["reason"])
	HouseData.blocked_cells = {HouseGrid.cell_key(Vector2i(12, 12)): "tree"}
	var blocked := HouseTemplate.check(empty, template, Vector2i(10, 10))
	_check(not blocked["valid"] and blocked["reason"] == "blocked", "con un árbol o terreno cerrado adentro: bloqueado (%s)" % blocked["reason"])
	_check(HouseTemplate.check(empty, template, Vector2i(20, 20))["valid"], "lejos del árbol sí cabe")
	HouseData.blocked_cells = {}
	# Una plantilla con una pieza de un nivel que no se tiene.
	Economy.xp = 0
	Economy.money = 100000
	var locked := HouseTemplate.check(empty, template, Vector2i(10, 10))
	_check(not locked["valid"] and locked["reason"] == "locked", "con piezas todavía bloqueadas por nivel: bloqueado (%s)" % locked["reason"])
	Economy.debug_unlock_all()
	# Sin apoyo: una plantilla con un piso suelto (alterada a mano) no se acepta.
	var broken: Dictionary = template.duplicate(true)
	broken["pieces"] = (broken["pieces"] as Array).filter(func(p) -> bool: return p["y"] != "foundation")
	var bare := HouseData.new()  # Casa vacía de verdad: `empty` ya tiene la copia puesta.
	bare.next_id = 20
	var unsupported := HouseTemplate.check(bare, broken, Vector2i(10, 10))
	_check(not unsupported["valid"] and unsupported["reason"] == "support", "sin cimientos nada se apoya (%s)" % unsupported["reason"])
	_check(HouseTemplate.check(empty, {}, Vector2i.ZERO)["reason"] == "empty", "una plantilla vacía no vale")


func _test_ids_and_order() -> void:
	print("\n4) Orden y nombres nuevos")
	var template := HouseTemplate.capture(_sample_house(), "Casa")
	var house := HouseData.new()
	house.next_id = 40
	var writes := HouseTemplate.writes_for(template, Vector2i(2, 2), house)
	var seen := {}
	var last_foundation := -1
	var first_floor := 9999
	var first_wall := 9999
	for i in writes.size():
		var w: Dictionary = writes[i]
		if w["layer"] == "foundation":
			last_foundation = i
		if w["layer"] == "floors" and w["level"] == 0:
			first_floor = mini(first_floor, i)
		if w["layer"] == "walls" and w["level"] == 0:
			first_wall = mini(first_wall, i)
		if w["layer"] == "objects" or w["layer"] == "roofs":
			seen[w["key"]] = true
	_check(last_foundation < first_floor and first_floor < first_wall, "cimientos antes que pisos y pisos antes que paredes")
	_check(seen.size() == 3, "tres nombres nuevos distintos (escalera, pilar, techo)")
	var all_new := true
	for key in seen:
		if int(str(key).substr(1)) < 40:
			all_new = false
	_check(all_new, "los nombres nuevos arrancan en el contador de la casa (40)")
	_check(house.next_id == 40, "armar las escrituras no mueve el contador")
	HouseTemplate.claim_ids(house, writes)
	_check(house.next_id == 43, "al reservarlos, el contador pasa de ellos (%d)" % house.next_id)
	# Sótano: el orden empieza por -1.
	var base := HouseData.new()
	var dig: Array = [HouseData.write(-1, "excavation", "5,5", {"item": "excavation_basic"}),
		HouseData.write(-1, "foundation", "5,5", {"item": "foundation_basic"}),
		HouseData.write(0, "foundation", "5,5", {"item": "foundation_basic"})]
	base.apply(dig)
	var basement := HouseTemplate.capture(base, "Sótano")
	var basement_writes := HouseTemplate.writes_for(basement, Vector2i(9, 9), HouseData.new())
	# Pulido 6A (3): el sótano solo se excava bajo la casa, así que los cimientos de arriba van primero.
	_check(basement_writes[0]["level"] == 0 and basement_writes[0]["layer"] == "foundation", "primero los cimientos de arriba")
	_check(basement_writes[1]["level"] == -1 and basement_writes[1]["layer"] == "excavation", "después el sótano se excava")
	_check(HouseTemplate.check(HouseData.new(), basement, Vector2i(9, 9))["valid"], "una plantilla con sótano se puede colocar")


func _test_store() -> void:
	print("\n5) La lista de plantillas")
	GameState.settings = {}
	var house := _sample_house()
	_check(HouseTemplates.all().is_empty(), "al principio no hay plantillas")
	var saved := HouseTemplates.save_house(house, "  Mi casa  ")
	_check(saved["ok"] and saved["template"]["name"] == "Mi casa", "guardar limpia el nombre")
	var twin := HouseTemplates.save_house(house, "mi casa")
	_check(twin["ok"] and twin["template"]["name"] == "mi casa (2)", "un nombre repetido recibe (2): %s" % twin["template"].get("name", ""))
	_check(HouseTemplates.save_house(house, "   ")["ok"] == false, "sin nombre no se guarda")
	_check(HouseTemplates.save_house(HouseData.new(), "Vacía")["ok"] == false, "una casa vacía no se guarda")
	_check(HouseTemplates.all().size() == 2, "hay 2 plantillas")
	var id: String = saved["template"]["id"]
	_check(not HouseTemplates.find(id).is_empty() and id != twin["template"]["id"], "cada una tiene su id")
	_check(HouseTemplates.rename(id, "Casa grande")["ok"] and HouseTemplates.find(id)["name"] == "Casa grande", "renombrar")
	_check(HouseTemplates.rename(twin["template"]["id"], "casa grande")["ok"] and HouseTemplates.find(twin["template"]["id"])["name"] == "casa grande (2)", "renombrar a un nombre existente agrega (2)")
	_check(HouseTemplates.rename("no-existe", "x")["ok"] == false, "renombrar una que no existe avisa")
	_check(HouseTemplates.clean_name("x".repeat(60)).length() == HouseTemplates.MAX_NAME, "el nombre tiene tope de largo")
	# Va con la partida: se guarda como texto y vuelve igual.
	var json := JSON.new()
	json.parse(JSON.stringify({"settings": GameState.settings}))
	GameState.settings = json.data["settings"]
	var back := HouseTemplates.find(id)
	_check(not back.is_empty() and back["name"] == "Casa grande", "sobrevive a guardar y leer el JSON")
	_check(HouseTemplate.check(HouseData.new(), back, Vector2i(10, 12))["valid"], "y después de leerla se puede colocar")
	_check(HouseTemplates.remove(id) and HouseTemplates.find(id).is_empty() and HouseTemplates.all().size() == 1, "borrar")
	_check(not HouseTemplates.remove(id), "borrar dos veces no rompe")
	# Tope de plantillas.
	for i in HouseTemplates.MAX_TEMPLATES:
		HouseTemplates.save_house(house, "Plantilla %d" % i)
	_check(HouseTemplates.all().size() == HouseTemplates.MAX_TEMPLATES, "no pasa del tope de %d" % HouseTemplates.MAX_TEMPLATES)
	_check(HouseTemplates.save_house(house, "Una más")["ok"] == false, "al llegar al tope avisa")
	GameState.settings = {}
