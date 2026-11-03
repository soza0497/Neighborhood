class_name HouseView
extends Node3D
## Dibuja en 3D una casa (HouseData) y la mantiene al día.
##
## Cuando una pieza cambia, se redibuja SOLO esa pieza (y las columnas de las
## esquinas que la tocan), no toda la casa.
##
## Cada nivel tiene su propio contenedor, colocado a la altura de ese piso.

## Cómo se ven las paredes y el techo.
enum ViewMode {
	FULL,      ## Paredes altas y techo.
	NO_ROOF,   ## Paredes altas, sin techo.
	CUTAWAY,   ## Paredes bajas (para ver adentro), sin techo.
}

var house: HouseData
var view_mode := ViewMode.NO_ROOF
## Los niveles por encima de este no se dibujan (para construir abajo).
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
	top_visible_level = level
	for i in _levels.size():
		_levels[i].visible = i <= top_visible_level


## Alto con el que se dibujan las paredes según la vista.
func wall_height() -> float:
	return HouseGrid.CUT_WALL_HEIGHT if view_mode == ViewMode.CUTAWAY else HouseGrid.WALL_HEIGHT


## Nodo 3D de una pieza (o null). El constructor lo usa para esconder un
## mueble mientras se mueve.
func get_piece_node(level: int, layer: String, key: String) -> Node3D:
	return _nodes.get(_node_id(level, layer, key))


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
			return HousePieces.build_wall(key, value, wall_height(), preview)
		"objects":
			return HousePieces.build_object(value)
		"roofs":
			if view_mode == ViewMode.FULL or preview:
				return HousePieces.build_roof(value)
	return null


func _on_piece_changed(level: int, layer: String, key: String) -> void:
	_refresh_piece(level, layer, key)
	if layer == "walls":
		for vertex in HouseGrid.edge_vertices(key):
			_refresh_post(level, vertex)


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
	for edge in HouseGrid.vertex_edges(vertex):
		var wall: Variant = house.get_piece(level, "walls", edge)
		if wall != null:
			var post := HousePieces.build_post(vertex, HousePieces.piece_color(wall), wall_height())
			_levels[level].add_child(post)
			_posts[id] = post
			return


func _node_id(level: int, layer: String, key: String) -> String:
	return "%d|%s|%s" % [level, layer, key]
