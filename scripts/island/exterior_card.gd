class_name ExteriorCard
extends RefCounted
## «Ficha exterior» de una casa (Isla 1A): un resumen CHICO de cómo se ve por fuera.
##
## Se genera desde los datos de la casa (HouseData) y de ella se arman los niveles
## de detalle lejanos (LOD 1 = fachada, LOD 2 = bloques). Pesa cientos de bytes y
## se guarda como diccionario/JSON (más adelante, en el servidor).
##
## Qué lleva:
##   - por piso: la huella (lista de rectángulos [x, z, ancho, fondo] en celdas),
##     el alto de las paredes, el color de las paredes y dónde hay ventanas;
##   - techos: nivel, rectángulo, estilo (gable = dos aguas, flat = plano) y color;
##   - la puerta (nivel y pared) y la altura de los cimientos.
## No lleva nada de adentro: ni muebles, ni cuartos, ni objetos del jardín.
##
## Formato del diccionario (claves cortas para pesar poco; colores sin «#»):
##   {"v": 1, "b": 0.3,
##    "f": [{"fp": [[x, z, w, d], ...], "h": 2.7, "wc": "f2e3c6", "w": [código de pared, ...]}],
##    "r": [{"lv": 0, "r": [x, z, w, d], "s": "g"|"f", "c": "e0675a"}],
##    "d": {"lv": 0, "e": código de pared}}
## «Código de pared» = un entero que dice qué pared es (ver edge_code).

const VERSION := 1
## Si la huella de un piso necesita más rectángulos que esto, se guarda su caja.
const MAX_RECTS := 8
const DEFAULT_WALL := "f2e3c6"

## Cimientos (alto en metros).
var base_height := 0.3
## Un diccionario por piso: {"fp": Array, "h": float, "wc": String, "w": Array}.
var floors: Array = []
## Un diccionario por techo: {"lv": int, "r": Array, "s": String, "c": String}.
var roofs: Array = []
## {"lv": int, "e": int} o {} si no se encontró puerta.
var door: Dictionary = {}


# --- Generar desde una casa ---

## Arma la ficha de una casa. Solo mira el exterior: huella de cada piso, paredes
## del contorno (color, ventanas, puerta) y techos.
static func from_house(house: HouseData) -> ExteriorCard:
	var card := ExteriorCard.new()
	card.base_height = snappedf(HouseGrid.FOUNDATION_HEIGHT, 0.01)
	for level in range(0, HouseGrid.MAX_LEVELS):
		var level_cells := floor_cells(house, level)
		if level_cells.is_empty():
			break
		var floor_info := {"fp": rects_from_cells(level_cells), "h": snappedf(HouseGrid.WALL_HEIGHT, 0.01), "wc": DEFAULT_WALL, "w": []}
		var colors: Dictionary = {}
		var windows: Array = []
		var perimeter := perimeter_edges(level_cells)
		for edge in perimeter:
			var wall: Variant = house.get_piece(level, "walls", edge)
			if wall == null:
				continue
			var wall_color := Color.from_string(str(wall.get("color_a", "")), Color.from_string("#" + DEFAULT_WALL, Color.WHITE))
			var html := wall_color.to_html(false)
			colors[html] = int(colors.get(html, 0)) + 1
			var opening := str(wall.get("opening", ""))
			if opening == "":
				continue
			var kind := str(Catalog.get_item(opening).get("kind", ""))
			if kind == "door" or (kind == "" and opening.begins_with("door")):
				if card.door.is_empty() or (level < int(card.door["lv"])):
					card.door = {"lv": level, "e": edge_code(edge)}
			else:
				windows.append(edge_code(edge))
		# El color que más se repite en el contorno (empate: el de menor código, para que sea siempre igual).
		var best := ""
		var best_count := -1
		var keys: Array = colors.keys()
		keys.sort()
		for html in keys:
			if int(colors[html]) > best_count:
				best = html
				best_count = int(colors[html])
		if best != "":
			floor_info["wc"] = best
		windows.sort()
		floor_info["w"] = windows
		card.floors.append(floor_info)
	var roof_keys: Array = []
	for level in range(0, HouseGrid.MAX_LEVELS):
		var layer := house.get_layer(level, "roofs")
		var ids: Array = layer.keys()
		ids.sort()
		for id in ids:
			roof_keys.append([level, id])
	for entry in roof_keys:
		var value: Dictionary = house.get_piece(entry[0], "roofs", entry[1])
		var r := HouseData.roof_rect(value)
		var item := Catalog.get_item(str(value.get("item", "")))
		card.roofs.append({
			"lv": int(entry[0]),
			"r": [r.position.x, r.position.y, r.size.x, r.size.y],
			"s": "f" if str(item.get("roof_style", "gable")) == "flat" else "g",
			"c": HousePieces.piece_color(value).to_html(false),
		})
	return card


## Celdas con piso de un nivel ("x,z" → Vector2i). En la planta baja también cuentan los cimientos.
static func floor_cells(house: HouseData, level: int) -> Dictionary:
	var cells: Dictionary = {}
	var layers: Array = ["floors"]
	if level == 0:
		layers.append("foundation")
	for layer in layers:
		for key in house.get_layer(level, layer):
			cells[key] = HouseGrid.key_to_cell(key)
	return cells


## Paredes del contorno de un conjunto de celdas (las que tienen una celda vacía del otro lado).
static func perimeter_edges(cells: Dictionary) -> Array:
	var result: Array = []
	var neighbors := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	var keys: Array = cells.keys()
	keys.sort()
	for key in keys:
		var cell: Vector2i = cells[key]
		var edges := HouseGrid.cell_edges(cell)  # norte, sur, oeste, este
		for i in 4:
			if not cells.has(HouseGrid.cell_key(cell + neighbors[i])):
				result.append(edges[i])
	return result


## Descompone un conjunto de celdas en rectángulos [x, z, ancho, fondo]: se juntan las
## tiras de cada fila y las que se repiten en la fila de abajo se estiran. Si salen
## muchos (> MAX_RECTS) se guarda solo la caja que lo envuelve.
static func rects_from_cells(cells: Dictionary) -> Array:
	var rows: Dictionary = {}
	for key in cells:
		var c: Vector2i = cells[key]
		if not rows.has(c.y):
			rows[c.y] = []
		(rows[c.y] as Array).append(c.x)
	var zs: Array = rows.keys()
	zs.sort()
	var result: Array = []
	var open: Dictionary = {}
	var previous_z := -1000000
	for z in zs:
		var xs: Array = rows[z]
		xs.sort()
		var runs: Array = []
		var run_start: int = xs[0]
		var run_last: int = xs[0]
		for i in range(1, xs.size()):
			if int(xs[i]) == run_last + 1:
				run_last = xs[i]
			else:
				runs.append([run_start, run_last])
				run_start = xs[i]
				run_last = xs[i]
		runs.append([run_start, run_last])
		var next_open: Dictionary = {}
		for run in runs:
			var run_key := "%d:%d" % [run[0], run[1]]
			if int(z) == previous_z + 1 and open.has(run_key):
				var rect: Array = open[run_key]
				rect[3] = int(rect[3]) + 1
				next_open[run_key] = rect
			else:
				var new_rect: Array = [run[0], z, int(run[1]) - int(run[0]) + 1, 1]
				result.append(new_rect)
				next_open[run_key] = new_rect
		open = next_open
		previous_z = int(z)
	result.sort_custom(func(a: Array, b: Array) -> bool:
		return int(a[1]) < int(b[1]) or (int(a[1]) == int(b[1]) and int(a[0]) < int(b[0])))
	if result.size() > MAX_RECTS:
		var box := Rect2i(cells.values()[0], Vector2i.ONE)
		for key in cells:
			box = box.expand(cells[key])
			box = box.expand((cells[key] as Vector2i) + Vector2i.ONE)
		return [[box.position.x, box.position.y, box.size.x, box.size.y]]
	return result


# --- Códigos de pared ---

## Una pared ("h:x,z" o "v:x,z") como un entero chico. Admite coordenadas de -64 a 191.
static func edge_code(key: String) -> int:
	var vertex := HouseGrid.edge_vertex(key)
	var horizontal := 1 if HouseGrid.is_edge_horizontal(key) else 0
	return ((vertex.y + 64) * 256 + (vertex.x + 64)) * 2 + horizontal


## La pared de un código, como clave de HouseGrid.
static func edge_key_of(code: int) -> String:
	var packed: int = code >> 1
	var vertex := Vector2i((packed & 255) - 64, (packed >> 8) - 64)
	return HouseGrid.edge_key(vertex, (code & 1) == 1)


# --- Consultas ---

func floor_count() -> int:
	return floors.size()


func is_empty() -> bool:
	return floors.is_empty()


## Celdas de la huella de un piso ("x,z" → Vector2i).
func cells_of(level: int) -> Dictionary:
	var result: Dictionary = {}
	if level < 0 or level >= floors.size():
		return result
	for rect in floors[level]["fp"]:
		for x in range(int(rect[0]), int(rect[0]) + int(rect[2])):
			for z in range(int(rect[1]), int(rect[1]) + int(rect[3])):
				result[HouseGrid.cell_key(Vector2i(x, z))] = Vector2i(x, z)
	return result


## Caja (en celdas) que envuelve la huella de todos los pisos.
func bounds() -> Rect2i:
	var box := Rect2i()
	var first := true
	for f in floors:
		for rect in f["fp"]:
			var r := Rect2i(int(rect[0]), int(rect[1]), int(rect[2]), int(rect[3]))
			box = r if first else box.merge(r)
			first = false
	return box


## Alto total en metros: cimientos + pisos (sin contar la subida del techo).
func total_height() -> float:
	var h := base_height
	for f in floors:
		h += float(f["h"])
	return h


func area(level: int) -> int:
	return cells_of(level).size()


func wall_color(level: int) -> Color:
	if level < 0 or level >= floors.size():
		return Color.WHITE
	return Color.from_string("#" + str(floors[level]["wc"]), Color.WHITE)


func roof_color(index: int) -> Color:
	if index < 0 or index >= roofs.size():
		return Color.WHITE
	return Color.from_string("#" + str(roofs[index]["c"]), Color.WHITE)


func roof_is_flat(index: int) -> bool:
	return index >= 0 and index < roofs.size() and str(roofs[index]["s"]) == "f"


## Tipo de techo de la casa: "gable", "flat" o "none" (el del primer techo).
func roof_kind() -> String:
	if roofs.is_empty():
		return "none"
	return "flat" if roof_is_flat(0) else "gable"


## Lado de la fachada con la puerta: "n" (z menor), "s" (z mayor), "w" (x menor), "e" (x mayor) o "".
func door_side() -> String:
	if door.is_empty():
		return ""
	var key := edge_key_of(int(door["e"]))
	var vertex := HouseGrid.edge_vertex(key)
	var door_cells := cells_of(int(door["lv"]))
	if HouseGrid.is_edge_horizontal(key):
		return "s" if door_cells.has(HouseGrid.cell_key(vertex + Vector2i(0, -1))) else "n"
	return "e" if door_cells.has(HouseGrid.cell_key(vertex + Vector2i(-1, 0))) else "w"


# --- Guardar y reconstruir ---

func to_dict() -> Dictionary:
	var f_list: Array = []
	for f in floors:
		f_list.append({"fp": (f["fp"] as Array).duplicate(true), "h": f["h"], "wc": f["wc"], "w": (f["w"] as Array).duplicate()})
	var r_list: Array = []
	for r in roofs:
		r_list.append({"lv": r["lv"], "r": (r["r"] as Array).duplicate(), "s": r["s"], "c": r["c"]})
	var result := {"v": VERSION, "b": base_height, "f": f_list, "r": r_list}
	if not door.is_empty():
		result["d"] = door.duplicate()
	return result


## Lee una ficha de un diccionario (también de uno que vino de JSON: ahí los
## números llegan como decimales y se vuelven enteros). Si está rota, devuelve una ficha vacía.
static func from_dict(data: Dictionary) -> ExteriorCard:
	var card := ExteriorCard.new()
	if int(data.get("v", 0)) != VERSION or not (data.get("f") is Array):
		return card
	card.base_height = float(data.get("b", 0.3))
	for f in data["f"]:
		var rects: Array = []
		for rect in f.get("fp", []):
			rects.append([int(rect[0]), int(rect[1]), int(rect[2]), int(rect[3])])
		var windows: Array = []
		for code in f.get("w", []):
			windows.append(int(code))
		card.floors.append({"fp": rects, "h": float(f.get("h", 2.7)), "wc": str(f.get("wc", DEFAULT_WALL)), "w": windows})
	for r in data.get("r", []):
		var rect: Array = r["r"]
		card.roofs.append({"lv": int(r["lv"]), "r": [int(rect[0]), int(rect[1]), int(rect[2]), int(rect[3])],
			"s": str(r.get("s", "g")), "c": str(r.get("c", "e0675a"))})
	var d: Variant = data.get("d")
	if d is Dictionary:
		card.door = {"lv": int(d["lv"]), "e": int(d["e"])}
	return card


## Texto JSON de la ficha (con las claves ordenadas: la misma ficha da siempre el mismo texto).
func to_json() -> String:
	return JSON.stringify(to_dict(), "", true)


## Cuántos bytes pesa la ficha como JSON.
func byte_size() -> int:
	return to_json().to_utf8_buffer().size()


## ¿Es la misma forma y los mismos colores que otra ficha?
func same_shape_as(other: ExteriorCard) -> bool:
	return to_json() == other.to_json()


## Reconstruye una casa mínima (solo exterior: cimientos, pisos, paredes del contorno con su
## puerta y ventanas, y techos) para volver a sacar de ella una ficha igual. También sirve
## para dibujar una casa vecina "de mentira" si nunca se tuvo la verdadera.
func to_house_data() -> HouseData:
	var house := HouseData.new()
	var writes: Array = []
	var door_key := edge_key_of(int(door["e"])) if not door.is_empty() else ""
	for level in floors.size():
		var f: Dictionary = floors[level]
		var level_cells := cells_of(level)
		var window_keys: Dictionary = {}
		for code in f["w"]:
			window_keys[edge_key_of(int(code))] = true
		var color := "#" + str(f["wc"])
		var keys: Array = level_cells.keys()
		keys.sort()
		for key in keys:
			if level == 0:
				writes.append(HouseData.write(level, "foundation", key, {"item": "foundation_basic"}))
			writes.append(HouseData.write(level, "floors", key, {"item": "floor_basic"}))
		for edge in perimeter_edges(level_cells):
			var wall := {"item": "wall_basic", "color_a": color, "color_b": color}
			if level == int(door.get("lv", -1)) and edge == door_key:
				wall["opening"] = "door_basic"
			elif window_keys.has(edge):
				wall["opening"] = "window_basic"
			writes.append(HouseData.write(level, "walls", edge, wall))
	var index := 1
	for r in roofs:
		var item_id := "roof_flat" if str(r["s"]) == "f" else "roof_basic"
		writes.append(HouseData.write(int(r["lv"]), "roofs", "r%d" % index,
			{"item": item_id, "rect": (r["r"] as Array).duplicate(), "color": "#" + str(r["c"])}))
		index += 1
	house.next_id = index + 1
	house.floor_count = maxi(1, floors.size())
	house.apply(writes)
	return house
