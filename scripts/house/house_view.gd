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
## Pulido 1: la vista se maneja con dos íconos independientes.
## Techos: se ven o no. Paredes: altas o bajas (siempre del piso actual).
var show_roofs := false
var low_walls := false
## La vista como uno de los tres modos de antes (la usan pruebas y demos).
var view_mode: ViewMode:
	get:
		if low_walls:
			return ViewMode.CUTAWAY
		return ViewMode.FULL if show_roofs else ViewMode.NO_ROOF
## Piso actual: los de arriba no se dibujan; a este se le aplica la vista.
var top_visible_level := HouseGrid.MAX_LEVELS - 1

## Contenedor de cada nivel.
var _levels: Array[Node3D] = []
## Nodo 3D de cada pieza: "nivel|capa|clave" → Node3D.
var _nodes: Dictionary = {}
## Columnas de las esquinas: "nivel|x,z" → Node3D.
var _posts: Dictionary = {}
## Piezas en obra: "nivel|capa|clave" → [nivel, capa, clave].
var _pending: Dictionary = {}
## Piezas con problemas (sin apoyo), pintadas de rojo: "nivel|capa|clave" → true.
var _problem_ids: Dictionary = {}
var _last_pending_count := -1
## Pulido 3C: las cajas que dan el contorno de cada pared completa se vuelven a
## armar (una vez por cuadro, como mucho) cuando cambia alguna pared.
var _outlines_dirty := true
## Pulido 3C: false = el contorno de antes (por tramo, con costuras). Solo lo
## usan las demos para comparar «antes y después».
static var seamless_outline := true
var _outline_nodes: Dictionary = {}


func _ready() -> void:
	for level in HouseGrid.level_range():
		var container := Node3D.new()
		container.name = "Level%d" % level
		container.position.y = HouseGrid.level_y(level)
		add_child(container)
		_levels.append(container)
	# Cada segundo se revisa si alguna obra terminó.
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(check_construction)
	add_child(timer)
	# Fase 7: «Usar modelos» en Info → se arma todo otra vez.
	EventBus.models_toggled.connect(_on_models_toggled)


func _on_models_toggled(_on: bool) -> void:
	rebuild_all()


## Conecta la vista con una casa y la dibuja completa.
func setup(new_house: HouseData) -> void:
	house = new_house
	house.piece_changed.connect(_on_piece_changed)
	house.reloaded.connect(rebuild_all)
	rebuild_all()


func set_view_mode(mode: ViewMode) -> void:
	set_view(mode == ViewMode.FULL, mode == ViewMode.CUTAWAY)


## Techos visibles o no, y paredes del piso actual altas o bajas.
func set_view(roofs: bool, low: bool) -> void:
	if roofs == show_roofs and low == low_walls:
		return
	show_roofs = roofs
	low_walls = low
	rebuild_all()


func set_top_visible_level(level: int) -> void:
	for i in _levels.size():
		_levels[i].visible = HouseGrid.MIN_LEVEL + i <= level
	if level != top_visible_level:
		top_visible_level = level
		rebuild_all()  # Cambian las alturas de paredes y qué techos se ven.


## Alto con el que se dibujan las paredes de un nivel según la vista: los
## pisos de abajo del actual siempre van completos.
func wall_height(level: int) -> float:
	if level < top_visible_level or not low_walls:
		return HouseGrid.WALL_HEIGHT
	return HouseGrid.CUT_WALL_HEIGHT


## ¿Se dibujan los techos de este nivel?
func roofs_visible(level: int) -> bool:
	return level < top_visible_level or show_roofs


## Nodo 3D de una pieza (o null). El constructor lo usa para esconder un
## mueble mientras se mueve.
func get_piece_node(level: int, layer: String, key: String) -> Node3D:
	return _nodes.get(_node_id(level, layer, key))


## Revisa las obras: las que terminaron se dibujan normales y avisan a la
## navegación; además avisa cuántas quedan y cuánto cuesta acelerarlas.
func check_construction() -> void:
	if house == null:
		return
	var now := Economy.now()
	var count := 0
	var seconds_left := 0
	for id in _pending.keys():
		var info: Array = _pending[id]
		var value: Variant = house.get_piece(info[0], info[1], info[2])
		if value == null:
			_pending.erase(id)
			continue
		var left := int(value.get("ready_at", 0)) - now
		if left <= 0:
			_pending.erase(id)
			EventBus.toast.emit("Terminó: %s" % Catalog.get_item(value["item"]).get("name", ""))
			# Pulido 2C: lo comprado llega en camión, en caja.
			if info[1] == "objects":
				var delivery := get_tree().get_first_node_in_group("delivery")
				if delivery != null:
					delivery.request(info[0], info[2])
			house.piece_changed.emit(info[0], info[1], info[2])  # Se redibuja y la navegación se entera.
		else:
			count += 1
			seconds_left += left
	if count > 0 or _last_pending_count != 0:
		EventBus.construction_changed.emit(count, Economy.accelerate_cost(seconds_left))
	_last_pending_count = count


## Mueble que toca un rayo (en coordenadas de la casa) en un nivel.
## Devuelve su clave, o "" si no toca ninguno. Se prueba celda por celda
## (así sirve también para los muebles en diagonal).
func pick_object(origin: Vector3, direction: Vector3, level: int) -> String:
	var best_key := ""
	var best_dist := INF
	var base := HouseGrid.level_y(level)
	for key in house.get_layer(level, "objects"):
		var value: Dictionary = house.get_piece(level, "objects", key)
		var item := Catalog.get_item(value["item"])
		var kind: String = item.get("kind", "")
		var height := HouseGrid.WALL_HEIGHT if kind == "stairs" or kind == "pillar" else float(item.get("height", 1.0))
		for cell in HouseData.value_cells(value):
			var box := AABB(Vector3(cell.x, base, cell.y), Vector3(1, height, 1))
			var hit: Variant = box.intersects_ray(origin, direction)
			if hit != null and origin.distance_to(hit) < best_dist:
				best_dist = origin.distance_to(hit)
				best_key = key
	return best_key


## Techo que toca un rayo en un nivel (solo si los techos se ven). "" si no.
func pick_roof(origin: Vector3, direction: Vector3, level: int) -> String:
	if not roofs_visible(level):
		return ""
	var best_key := ""
	var best_dist := INF
	var base := HouseGrid.level_y(level) + HouseGrid.WALL_HEIGHT
	for key in house.get_layer(level, "roofs"):
		var rect := HouseData.roof_rect(house.get_piece(level, "roofs", key))
		var top := float(mini(rect.size.x, rect.size.y)) / 2.0 * HousePieces.ROOF_SLOPE + 0.4
		var box := AABB(Vector3(rect.position.x, base, rect.position.y), Vector3(rect.size.x, top, rect.size.y))
		var hit: Variant = box.intersects_ray(origin, direction)
		if hit != null and origin.distance_to(hit) < best_dist:
			best_dist = origin.distance_to(hit)
			best_key = key
	return best_key


## Marca qué piezas tienen problemas (se pintan de rojo). `problems` es la
## lista de HouseRules.problems.
func set_problems(problems: Array) -> void:
	var old := _problem_ids
	_problem_ids = {}
	for p in problems:
		if p["layer"] != "":
			_problem_ids[_node_id(p["level"], p["layer"], p["key"])] = true
	for id in old:
		if not _problem_ids.has(id):
			_refresh_by_id(id)
	for id in _problem_ids:
		if not old.has(id):
			_refresh_by_id(id)


## Pulido 2: piezas "previstas" (el plan de obra sin confirmar). Se ven tal
## cual, un poco transparentes, y brillan un instante cada PLAN_GLOW_PERIOD s.
const PLAN_GLOW_PERIOD := 3.0
const PLAN_GLOW_SECONDS := 0.8
var _planned: Dictionary = {}
## Pulido 2C: piezas en caja ("nivel|objects|clave" → "transit" | "dropped").
## En camino no se ven; ya dejadas se ven como una caja de cartón.
var _boxed: Dictionary = {}
var _planned_materials: Array = []
var _glow_clock := 0.0


## `ids`: "nivel|capa|clave" → true. Se vuelven a dibujar solo las que cambian.
func set_planned(ids: Dictionary) -> void:
	var old := _planned
	_planned = ids
	if old.is_empty() and ids.is_empty():
		return
	for id in old:
		if not ids.has(id):
			_refresh_by_id(id)
	for id in ids:
		if not old.has(id):
			_refresh_by_id(id)
	if ids.is_empty():
		_planned_materials.clear()


## Qué piezas están en caja (las manda Delivery). Se redibujan solo las que cambian.
func set_boxed(ids: Dictionary) -> void:
	var old := _boxed
	_boxed = ids
	for id in old:
		if not ids.has(id) or ids[id] != old[id]:
			_refresh_by_id(id)
	for id in ids:
		if not old.has(id):
			_refresh_by_id(id)


func _process(delta: float) -> void:
	if _outlines_dirty:
		_rebuild_outlines()
	if _planned_materials.is_empty():
		return
	_glow_clock = fmod(_glow_clock + delta, PLAN_GLOW_PERIOD)
	# Un destello que sube y baja suave al principio de cada período.
	var glow := 0.0
	if _glow_clock < PLAN_GLOW_SECONDS:
		glow = sin(_glow_clock / PLAN_GLOW_SECONDS * PI)
	for mat in _planned_materials:
		if is_instance_valid(mat):
			mat.set_shader_parameter("glow", glow * 0.9)


func _refresh_by_id(id: String) -> void:
	var parts := id.split("|")
	_refresh_piece(int(parts[0]), parts[1], parts[2])
	if parts[1] == "walls":
		for vertex in HouseGrid.edge_vertices(parts[2]):
			_refresh_post(int(parts[0]), vertex)


# --- Contorno sin costuras (Pulido 3C) ---

## ¿Este tramo de pared forma parte del contorno "de pared completa"? Sí si es
## macizo (sin puerta ni ventana) y se ve normal (no en obra, ni prevista, ni
## en rojo): esos tramos no llevan contorno propio y una sola caja envuelve
## todos los que son contiguos en línea recta, así la pared se ve continua.
func _wall_is_flat(level: int, key: String, value: Variant) -> bool:
	if not seamless_outline or value == null or str(value.get("opening", "")) != "":
		return false
	if HouseData.is_under_construction(value):
		return false
	var id := _node_id(level, "walls", key)
	return not _planned.has(id) and not _problem_ids.has(id)


## Arma, por nivel, una caja invisible por cada tramo recto de paredes contiguas
## (misma línea y mismo alto): lleva el contorno de toda la silueta de una vez.
func _rebuild_outlines() -> void:
	_outlines_dirty = false
	for node in _outline_nodes.values():
		node.get_parent().remove_child(node)  # Se saca ya (si no, el nombre nuevo se renombra).
		node.queue_free()
	_outline_nodes.clear()
	if house == null:
		return
	var t := HouseGrid.WALL_THICKNESS
	for level in HouseGrid.level_range():
		var layer := house.get_layer(level, "walls")
		if layer.is_empty():
			continue
		# Línea → posiciones de los tramos sueltos (horizontales: z → [x...]).
		var lines := {}
		for key in layer:
			if not _wall_is_flat(level, key, layer[key]):
				continue
			var v := HouseGrid.edge_vertex(key)
			var horizontal := HouseGrid.is_edge_horizontal(key)
			var line_id := "%s%d" % ["h" if horizontal else "v", v.y if horizontal else v.x]
			if not lines.has(line_id):
				lines[line_id] = []
			lines[line_id].append(v.x if horizontal else v.y)
		if lines.is_empty():
			continue
		var holder := Node3D.new()
		holder.name = "WallOutlines"
		_levels[HouseGrid.level_index(level)].add_child(holder)
		_outline_nodes[level] = holder
		var height := wall_height(level)
		for line_id in lines:
			var positions: Array = lines[line_id]
			positions.sort()
			var horizontal: bool = str(line_id).begins_with("h")
			var line_pos := float(str(line_id).substr(1))
			var run_start: int = positions[0]
			var previous: int = positions[0]
			for i in range(1, positions.size() + 1):
				if i < positions.size() and positions[i] == previous + 1:
					previous = positions[i]
					continue
				var count := previous - run_start + 1
				var mid := run_start + count / 2.0
				var center := Vector3(mid, height / 2.0, line_pos) if horizontal else Vector3(line_pos, height / 2.0, mid)
				var size := Vector3(count + t, height, t) if horizontal else Vector3(t, height, count + t)
				var box := HousePieces.add_box(holder, center, size, Style.outline_only_material())
				box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				if i < positions.size():
					run_start = positions[i]
					previous = positions[i]


## Contenedor de un nivel (para poner cosas a la altura de ese piso).
func get_level_container(level: int) -> Node3D:
	return _levels[HouseGrid.level_index(level)]


## Borra todo y vuelve a dibujar la casa entera.
func rebuild_all() -> void:
	for node in _nodes.values():
		node.queue_free()
	for node in _posts.values():
		node.queue_free()
	_nodes.clear()
	_posts.clear()
	_pending.clear()
	_outlines_dirty = true
	if house == null:
		return
	for level in HouseGrid.level_range():
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
		"excavation":
			return HousePieces.build_excavation(HouseGrid.key_to_cell(key), value)
		"floors":
			return HousePieces.build_floor(HouseGrid.key_to_cell(key), value)
		"walls":
			var vertices := HouseGrid.edge_vertices(key)
			return HousePieces.build_wall(key, value, wall_height(level), preview,
				not preview and not _merged_window(level, vertices[0]).is_empty(),
				not preview and not _merged_window(level, vertices[1]).is_empty(),
				not preview and _wall_is_flat(level, key, value))
		"objects":
			var boxed: String = _boxed.get(_node_id(level, layer, key), "")
			if boxed == "transit":
				return null
			if boxed == "dropped" and not preview:
				return HousePieces.build_delivery_box(value)
			return HousePieces.build_object(value, _ground_drop(level, value))
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
	if layer == "walls":
		_outlines_dirty = true
	var id := _node_id(level, layer, key)
	if _nodes.has(id):
		_nodes[id].queue_free()
		_nodes.erase(id)
	var value: Variant = house.get_piece(level, layer, key)
	if value == null:
		return
	var node := make_piece(level, layer, key, value)
	_pending.erase(id)
	if node != null:
		if _planned.has(id):
			_planned_materials.append_array(HousePieces.make_planned(node))
		if _problem_ids.has(id):
			HousePieces.make_problem(node)
		elif HouseData.is_under_construction(value):
			HousePieces.make_construction(node)
			_pending[id] = [level, layer, key]
		_levels[HouseGrid.level_index(level)].add_child(node)
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
	# Pulido 3C: la columna no lleva contorno propio si todas las paredes que
	# llegan ahí tampoco (lo lleva la caja de la pared completa).
	var flat := true
	for edge in walls:
		if not _wall_is_flat(level, edge, house.get_piece(level, "walls", edge)):
			flat = false
	var post := HousePieces.build_post(vertex, HousePieces.wall_face_color(first, "b"), wall_height(level),
		_merged_window(level, vertex), flat and _merged_window(level, vertex).is_empty())
	_levels[HouseGrid.level_index(level)].add_child(post)
	_posts[id] = post


## Si en una esquina (juntura) dos ventanas iguales en línea están UNIDAS
## (join_end en la pared que termina ahí), devuelve esa ventana (del
## catálogo). Si no, {}. Lo que se ve es exactamente lo que está guardado.
func _merged_window(level: int, vertex: Vector2i) -> Dictionary:
	return HouseView.joint_window(house, level, vertex)


## Lo mismo, sin vista (lo usa también el constructor para las junturas).
static func joint_window(target: HouseData, level: int, vertex: Vector2i) -> Dictionary:
	var pair := joint_walls(target, level, vertex)
	if pair.is_empty():
		return {}
	var a: Dictionary = target.get_piece(level, "walls", pair[0])
	var b: Dictionary = target.get_piece(level, "walls", pair[1])
	if not a.get("join_end", false):
		return {}
	var opening: String = a.get("opening", "")
	if opening == "" or opening != b.get("opening", ""):
		return {}
	var item := Catalog.get_item(opening)
	return item if item.get("kind", "") == "window" else {}


## Las dos paredes en línea que se juntan en una esquina, si son solo esas
## dos y las dos tienen ventana: [la que termina ahí, la que empieza]. Si no, [].
static func joint_walls(target: HouseData, level: int, vertex: Vector2i) -> Array:
	var walls: Array = []
	for edge in HouseGrid.vertex_edges(vertex):
		if target.has_piece(level, "walls", edge):
			walls.append(edge)
	if walls.size() != 2 or HouseGrid.is_edge_horizontal(walls[0]) != HouseGrid.is_edge_horizontal(walls[1]):
		return []
	for edge in walls:
		if Catalog.get_item(target.get_piece(level, "walls", edge).get("opening", "")).get("kind", "") != "window":
			return []
	# La que termina en el vértice es la de coordenada menor.
	if HouseGrid.edge_vertex(walls[0]) == vertex:
		walls.reverse()
	return walls


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


## Cuánto más abajo está el suelo para algo de afuera (pilar, escalera
## metálica) puesto en la planta baja sobre el pasto, sin cimientos.
func _ground_drop(level: int, value: Dictionary) -> float:
	if level != 0 or not Catalog.get_item(value.get("item", "")).get("outdoor", false):
		return 0.0
	if house.has_piece(0, "foundation", HouseGrid.cell_key(HouseData.object_anchor(value))):
		return 0.0
	return HouseGrid.FOUNDATION_HEIGHT
