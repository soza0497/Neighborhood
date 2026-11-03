class_name HouseView
extends Node3D
## Dibuja en 3D una casa (HouseData) y la mantiene al día.
##
## Cuando una pieza cambia, se redibuja SOLO esa pieza (y las columnas de las
## esquinas que la tocan), no toda la casa.
##
## Cada nivel tiene su propio contenedor, colocado a la altura de ese piso.

## Cómo se ven las paredes y el techo DEL PISO ACTUAL (los de abajo se ven
## completos y los de arriba no se dibujan).
enum ViewMode {
	FULL,      ## Paredes altas y techo.
	NO_ROOF,   ## Paredes altas, sin techo.
	CUTAWAY,   ## Paredes bajas (para ver adentro), sin techo.
}

var house: HouseData
var view_mode := ViewMode.NO_ROOF
## Piso actual: los de arriba no se dibujan; a este se le aplica la vista.
var top_visible_level := HouseGrid.MAX_LEVELS - 1

## Contenedor de cada nivel.
var _levels: Array[Node3D] = []
## Nodo 3D de cada pieza: "nivel|capa|clave" → Node3D.
var _nodes: Dictionary = {}
## Columnas de las esquinas: "nivel|x,z" → Node3D.
var _posts: Dictionary = {}


func _ready() -> void:
	for i in HouseGrid.MAX_LEVELS:
		var container := Node3D.new()
		container.name = "Level%d" % i
		container.position.y = HouseGrid.level_y(i)
		add_child(container)
		_levels.append(container)


## Conecta la vista con una casa y la dibuja completa.
func setup(new_house: HouseData) -> void:
	house = new_house
	house.piece_changed.connect(_on_piece_changed)
	house.reloaded.connect(rebuild_all)
	rebuild_all()


func set_view_mode(mode: ViewMode) -> void:
	if mode == view_mode:
		return
	view_mode = mode
	rebuild_all()


func set_top_visible_level(level: int) -> void:
	for i in _levels.size():
		_levels[i].visible = i <= level
	if level != top_visible_level:
		top_visible_level = level
		rebuild_all()  # Cambian las alturas de paredes y qué techos se ven.


## Alto con el que se dibujan las paredes de un nivel según la vista: los
## pisos de abajo del actual siempre van completos.
func wall_height(level: int) -> float:
	if level < top_visible_level or view_mode != ViewMode.CUTAWAY:
		return HouseGrid.WALL_HEIGHT
	return HouseGrid.CUT_WALL_HEIGHT


## ¿Se dibujan los techos de este nivel?
func roofs_visible(level: int) -> bool:
	return level < top_visible_level or view_mode == ViewMode.FULL


## Nodo 3D de una pieza (o null). El constructor lo usa para esconder un
## mueble mientras se mueve.
func get_piece_node(level: int, layer: String, key: String) -> Node3D:
	return _nodes.get(_node_id(level, layer, key))


## Mueble que toca un rayo (en coordenadas de la casa) en un nivel.
## Devuelve su clave, o "" si no toca ninguno.
func pick_object(origin: Vector3, direction: Vector3, level: int) -> String:
	var best_key := ""
	var best_dist := INF
	var base := HouseGrid.level_y(level)
	for key in house.get_layer(level, "objects"):
		var value: Dictionary = house.get_piece(level, "objects", key)
		var item := Catalog.get_item(value["item"])
		var size := HouseGrid.rotated_size(HouseData.item_footprint(item), int(value.get("rot", 0)))
		var anchor := HouseData.object_anchor(value)
		var height := HouseGrid.WALL_HEIGHT if item.get("kind", "") == "stairs" else float(item.get("height", 1.0))
		var box := AABB(Vector3(anchor.x, base, anchor.y), Vector3(size.x, height, size.y))
		var hit: Variant = box.intersects_ray(origin, direction)
		if hit != null and origin.distance_to(hit) < best_dist:
			best_dist = origin.distance_to(hit)
			best_key = key
	return best_key


## Contenedor de un nivel (para poner cosas a la altura de ese piso).
func get_level_container(level: int) -> Node3D:
	return _levels[level]


## Borra todo y vuelve a dibujar la casa entera.
func rebuild_all() -> void:
	for node in _nodes.values():
		node.queue_free()
	for node in _posts.values():
		node.queue_free()
	_nodes.clear()
	_posts.clear()
	if house == null:
		return
	for level in HouseGrid.MAX_LEVELS:
		for layer in HouseData.LAYERS:
			for key in house.get_layer(level, layer):
				_refresh_piece(level, layer, key)
		for key in house.get_layer(level, "walls"):
			for vertex in HouseGrid.edge_vertices(key):
				_refresh_post(level, vertex)


## Fabrica el 3D de una pieza (o null si en esta vista no se ve).
## También lo usa el constructor para la vista previa ("fantasma").
func make_piece(level: int, layer: String, key: String, value: Dictionary, preview := false) -> Node3D:
	match layer:
		"foundation":
			return HousePieces.build_foundation(HouseGrid.key_to_cell(key), value)
		"floors":
			return HousePieces.build_floor(HouseGrid.key_to_cell(key), value)
		"walls":
			var vertices := HouseGrid.edge_vertices(key)
			return HousePieces.build_wall(key, value, wall_height(level), preview,
				not preview and not _merged_window(level, vertices[0]).is_empty(),
				not preview and not _merged_window(level, vertices[1]).is_empty())
		"objects":
			return HousePieces.build_object(value)
		"roofs":
			if roofs_visible(level) or preview:
				return HousePieces.build_roof(value, _gable_color(level, value))
	return null


func _on_piece_changed(level: int, layer: String, key: String) -> void:
	_refresh_piece(level, layer, key)
	if layer == "walls":
		for vertex in HouseGrid.edge_vertices(key):
			_refresh_post(level, vertex)
		# Las paredes vecinas en línea pueden unir (o separar) su ventana.
		for neighbor in _neighbors_in_line(key):
			if house.has_piece(level, "walls", neighbor):
				_refresh_piece(level, "walls", neighbor)
		# Los remates del techo copian el color de las paredes.
		for roof_key in house.get_layer(level, "roofs"):
			_refresh_piece(level, "roofs", roof_key)


## Quita el 3D viejo de una pieza y pone el nuevo (si la pieza existe).
func _refresh_piece(level: int, layer: String, key: String) -> void:
	var id := _node_id(level, layer, key)
	if _nodes.has(id):
		_nodes[id].queue_free()
		_nodes.erase(id)
	var value: Variant = house.get_piece(level, layer, key)
	if value == null:
		return
	var node := make_piece(level, layer, key, value)
	if node != null:
		_levels[level].add_child(node)
		_nodes[id] = node


## Pone o quita la columna de una esquina según si llega alguna pared.
func _refresh_post(level: int, vertex: Vector2i) -> void:
	var id := "%d|%s" % [level, HouseGrid.cell_key(vertex)]
	if _posts.has(id):
		_posts[id].queue_free()
		_posts.erase(id)
	var walls: Array = []
	for edge in HouseGrid.vertex_edges(vertex):
		if house.has_piece(level, "walls", edge):
			walls.append(edge)
	if walls.is_empty():
		return
	var first: Dictionary = house.get_piece(level, "walls", walls[0])
	var post := HousePieces.build_post(vertex, HousePieces.piece_color(first), wall_height(level),
		_merged_window(level, vertex))
	_levels[level].add_child(post)
	_posts[id] = post


## Si en una esquina se juntan justo dos paredes en línea recta con la misma
## ventana, y ninguna está marcada "separada", devuelve esa ventana (del
## catálogo) para unirlas. Si no, {}.
func _merged_window(level: int, vertex: Vector2i) -> Dictionary:
	var walls: Array = []
	for edge in HouseGrid.vertex_edges(vertex):
		var wall: Variant = house.get_piece(level, "walls", edge)
		if wall != null:
			walls.append([edge, wall])
	if walls.size() != 2:
		return {}
	if HouseGrid.is_edge_horizontal(walls[0][0]) != HouseGrid.is_edge_horizontal(walls[1][0]):
		return {}
	var a: Dictionary = walls[0][1]
	var b: Dictionary = walls[1][1]
	if a.get("separate", false) or b.get("separate", false):
		return {}
	var opening: String = a.get("opening", "")
	if opening == "" or opening != b.get("opening", ""):
		return {}
	var item := Catalog.get_item(opening)
	return item if item.get("kind", "") == "window" else {}


## Las dos paredes que siguen en línea recta a cada lado de una pared.
static func _neighbors_in_line(key: String) -> Array[String]:
	var v := HouseGrid.edge_vertex(key)
	if HouseGrid.is_edge_horizontal(key):
		return [HouseGrid.edge_key(v - Vector2i(1, 0), true), HouseGrid.edge_key(v + Vector2i(1, 0), true)]
	return [HouseGrid.edge_key(v - Vector2i(0, 1), false), HouseGrid.edge_key(v + Vector2i(0, 1), false)]


## Color para los remates de un techo: el de una pared que esté debajo de
## una de sus puntas, o si no hay, el de cualquier pared del contorno.
func _gable_color(level: int, roof: Dictionary) -> Color:
	var rect := HouseData.roof_rect(roof)
	var lo := rect.position
	var hi := rect.end - Vector2i.ONE
	var candidates: Array[String] = []
	if rect.size.x >= rect.size.y:
		candidates.append_array(HouseGrid.edges_in_line(Vector2i(lo.x, lo.y), Vector2i(lo.x, hi.y + 1)))
		candidates.append_array(HouseGrid.edges_in_line(Vector2i(hi.x + 1, lo.y), Vector2i(hi.x + 1, hi.y + 1)))
	else:
		candidates.append_array(HouseGrid.edges_in_line(Vector2i(lo.x, lo.y), Vector2i(hi.x + 1, lo.y)))
		candidates.append_array(HouseGrid.edges_in_line(Vector2i(lo.x, hi.y + 1), Vector2i(hi.x + 1, hi.y + 1)))
	candidates.append_array(HouseGrid.edges_around_rect(lo, hi))
	for edge in candidates:
		var wall: Variant = house.get_piece(level, "walls", edge)
		if wall != null:
			return HousePieces.piece_color(wall)
	return HousePieces.piece_color({"item": "wall_basic"})


func _node_id(level: int, layer: String, key: String) -> String:
	return "%d|%s|%s" % [level, layer, key]
