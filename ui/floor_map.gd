class_name FloorMap
extends SubViewportContainer
## Selector de pisos de frente (Pulido 2): el frente de la casa visto desde la
## calle, un poco girado, como un holograma azul semitransparente. Solo se
## dibuja lo de afuera: el contorno de las paredes de cada piso, la puerta,
## las ventanas y el techo. Cada piso tiene su propio color; el actual se ve
## más fuerte y un punto parpadea donde está el personaje.
##
## Tocar un piso = ir a ese piso. Los botones de al lado (flechas arriba y
## abajo, girar) los arma el HUD; esta clase solo dibuja y avisa.
##
## Tiene su propio mundo 3D (no ve la casa de verdad): se redibuja cuando la
## casa cambia, como mucho una vez por cuadro. El estilo (colores, grosor)
## está en las constantes de abajo: se puede cambiar sin tocar el resto.

## Se tocó un piso del dibujo.
signal level_picked(level: int)
## Cambió el ángulo con el que se mira (0..7, de a 45°).
signal angle_changed(index: int)

## Alto de cada piso en el dibujo y espacio entre pisos.
const FLOOR_HEIGHT := HouseGrid.WALL_HEIGHT
const GAP := 0.35
## Un color por piso (todos azules/celestes, distinguibles entre sí).
const LEVEL_COLORS := [
	Color("#4fd1ff"), Color("#6f9bff"), Color("#58e0c8"), Color("#9a8cff"), Color("#7cc4f5"),
]
const FILL_ALPHA := 0.13
const FILL_ALPHA_CURRENT := 0.30
const LINE_ALPHA := 0.55
const LINE_ALPHA_CURRENT := 1.0
## Cuánto se inclina la cámara (grados hacia abajo): casi de frente.
const PITCH_DEGREES := 7.0
## Giro base ("un poco girado") y de a cuánto se gira con los botones.
const BASE_YAW_DEGREES := -22.0
const STEP_DEGREES := 45.0
const ANGLE_COUNT := 8
## Una pared "mira hacia nosotros" si su normal tiene al menos esto de componente
## hacia la cámara de la maqueta (las de atrás no dibujan sus aristas).
const FACING_MIN := 0.05
## Grosor de las líneas, como fracción del tamaño de la cámara.
const LINE_WIDTH := 0.016

var house: HouseData
var character: Node3D
var current_level := 0
## Ángulo elegido (0 = de frente). Se recuerda en la configuración.
var angle_index := 0

var _viewport: SubViewport
var _camera: Camera3D
var _mesh: MeshInstance3D
var _dot: MeshInstance3D
var _dot_material: StandardMaterial3D
## Pulido 5D: ¿el personaje está dentro de la casa? Se recalcula solo si cambió algo.
var _inside := false
var _inside_key := ""
var _inside_dirty := true
var _dirty := true
var _blink := 0.0
var _center := Vector3.ZERO
var _total := 1
## Pulido 2C: el piso más alto y el más bajo (sótano) que se dibujan.
var _top := 0
var _bottom := 0


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_viewport.add_child(_camera)
	_mesh = MeshInstance3D.new()
	_mesh.material_override = _material()
	_viewport.add_child(_mesh)
	var sphere := SphereMesh.new()
	sphere.radius = 0.55
	sphere.height = 1.1
	_dot = MeshInstance3D.new()
	_dot.mesh = sphere
	var dot_mat := StandardMaterial3D.new()
	dot_mat.albedo_color = Color(1.0, 0.35, 0.5)
	dot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dot_mat.no_depth_test = true
	dot_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_dot_material = dot_mat
	_dot.material_override = dot_mat
	_viewport.add_child(_dot)
	angle_index = posmod(int(GameState.settings.get("floor_front_angle", 0)), ANGLE_COUNT)
	gui_input.connect(_on_gui_input)


## Conecta el selector con la casa y el personaje (los lee, no los cambia).
func setup(new_house: HouseData, new_character: Node3D) -> void:
	house = new_house
	character = new_character
	house.piece_changed.connect(func(_l: int, _layer: String, _k: String) -> void:
		_dirty = true
		_inside_dirty = true)
	house.reloaded.connect(func() -> void:
		_dirty = true
		_inside_dirty = true)
	_dirty = true


func set_level(level: int) -> void:
	current_level = level
	_dirty = true


## Gira la fachada de a 45° (+1 / -1) y recuerda el ángulo.
func turn(direction: int) -> void:
	set_angle(angle_index + direction)


func set_angle(index: int) -> void:
	angle_index = posmod(index, ANGLE_COUNT)
	GameState.settings["floor_front_angle"] = angle_index
	_dirty = true
	angle_changed.emit(angle_index)


## Cuántos pisos se dibujan (los de la casa, con sus sótanos).
func shown_levels() -> int:
	return _top - _bottom + 1


func _process(delta: float) -> void:
	if house == null or not is_visible_in_tree():
		return
	if _dirty:
		_dirty = false
		_rebuild()
	# El punto del personaje (Pulido 5D): solo si está DENTRO de la casa, en el piso donde
	# está aunque se mire otro (apagado y más chico), y también mientras duerme.
	_blink += delta
	var state := dot_state()
	_dot.visible = state["visible"]
	if state["visible"]:
		var level: int = state["level"]
		var pulse := fmod(_blink, 1.0) < 0.65
		_dot_material.albedo_color = Color(1.0, 0.35, 0.5, 1.0 if pulse else 0.0) if not state["dim"] else Color(1.0, 0.35, 0.5, 0.55)
		_dot.scale = Vector3.ONE * (0.7 if state["dim"] else 1.0)
		_dot.position = Vector3(character.position.x, _level_y(level) + 0.9, character.position.z)


## Qué hace el punto del personaje: {visible, level, dim}. `dim` = está en otro piso
## que el que se mira (queda quieto y apagado, como una marca en el piso correcto).
func dot_state() -> Dictionary:
	var result := {"visible": false, "level": 0, "dim": false}
	if character == null or house == null:
		return result
	# Trabajando está fuera de la casa; dormido sigue en su cama (no se esconde por el sueño).
	if character.get("state") == Character.State.WORKING:
		return result
	var level: int = int(character.get("level")) if character.get("level") != null else 0
	var cell: Vector2i = character.get("cell") if character.get("cell") != null else Vector2i(-1, -1)
	var key := "%d:%d,%d" % [level, cell.x, cell.y]
	if _inside_dirty or key != _inside_key:
		_inside_dirty = false
		_inside_key = key
		_inside = is_inside(house, level, cell)
	result["visible"] = _inside
	result["level"] = level
	result["dim"] = level != current_level
	return result


## ¿La celda está dentro de la casa? Un cuarto cerrado, o una celda con piso y pared
## al lado (pasillo, puerta, descanso de escalera). En el lote, afuera: no.
static func is_inside(target: HouseData, level: int, cell: Vector2i) -> bool:
	if not target.has_piece(level, "floors", HouseGrid.cell_key(cell)):
		return false
	if not HouseRooms.room_at(target, level, cell).is_empty():
		return true
	for edge in HouseGrid.cell_edges(cell):
		if target.has_piece(level, "walls", edge):
			return true
	return false


## Altura (en el dibujo) del suelo de un piso.
static func _level_y(level: int) -> float:
	return level * (FLOOR_HEIGHT + GAP)


# --- Datos del dibujo (sin 3D: se pueden probar) ---

## Paredes de AFUERA de un piso: las que tienen piso de un solo lado. Si el
## piso no tiene losa (solo paredes), cuentan todas. Cada una:
## {key, normal: Vector2i (hacia afuera), opening: String ("door"/"window"/"")}.
static func exterior_walls(target: HouseData, level: int) -> Array:
	var cells := {}
	for key in target.get_layer(level, "floors"):
		cells[key] = true
	if level == 0:
		for key in target.get_layer(0, "foundation"):
			cells[key] = true
	var result: Array = []
	for key in target.get_layer(level, "walls"):
		var sides := HouseGrid.edge_cells(key)
		var inside_a: bool = cells.has(HouseGrid.cell_key(sides[0]))
		var inside_b: bool = cells.has(HouseGrid.cell_key(sides[1]))
		if not cells.is_empty() and inside_a == inside_b:
			continue  # Pared de adentro (o suelta, lejos de la losa).
		# La normal apunta del lado que NO tiene losa.
		var horizontal := HouseGrid.is_edge_horizontal(key)
		var toward_a := inside_b and not inside_a
		var normal := Vector2i.ZERO
		if horizontal:
			normal = Vector2i(0, -1) if toward_a else Vector2i(0, 1)
		else:
			normal = Vector2i(-1, 0) if toward_a else Vector2i(1, 0)
		var opening_kind := ""
		var wall: Dictionary = target.get_piece(level, "walls", key)
		if wall.get("opening", "") != "":
			opening_kind = str(Catalog.get_item(wall["opening"]).get("kind", ""))
		result.append({"key": key, "normal": normal, "opening": opening_kind})
	return result


## Dirección (en el plano X-Z) hacia la cámara del dibujo con el ángulo dado.
static func view_direction(index: int) -> Vector2:
	var yaw := deg_to_rad(BASE_YAW_DEGREES + posmod(index, ANGLE_COUNT) * STEP_DEGREES)
	return Vector2(sin(yaw), cos(yaw))


# --- Armado del dibujo ---

func _rebuild() -> void:
	_total = house.floors_total()
	_top = _total - 1
	_bottom = house.lowest_level()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for level in range(_bottom, _top + 1):
		for key in house.get_layer(level, "floors"):
			var cell := Vector2(HouseGrid.key_to_cell(key))
			lo = lo.min(cell)
			hi = hi.max(cell + Vector2.ONE)
		for key in house.get_layer(level, "walls"):
			for v in HouseGrid.edge_vertices(key):
				lo = lo.min(Vector2(v))
				hi = hi.max(Vector2(v))
	for key in house.get_layer(0, "foundation"):
		var cell := Vector2(HouseGrid.key_to_cell(key))
		lo = lo.min(cell)
		hi = hi.max(cell + Vector2.ONE)
	if hi.x < lo.x:
		lo = Vector2(HouseGrid.LOT_SIZE) / 2.0 - Vector2(4, 4)
		hi = Vector2(HouseGrid.LOT_SIZE) / 2.0 + Vector2(4, 4)
	var dir := view_direction(angle_index)
	var pitch := deg_to_rad(PITCH_DEGREES)
	var view_dir := Vector3(-dir.x * cos(pitch), -sin(pitch), -dir.y * cos(pitch)).normalized()
	var line_width := maxf(maxf(hi.x - lo.x, hi.y - lo.y), (_top - _bottom + 1) * 3.0) * LINE_WIDTH * 1.3

	var fill := SurfaceTool.new()
	fill.begin(Mesh.PRIMITIVE_TRIANGLES)
	for level in range(_bottom, _top + 1):
		_draw_level(fill, level, lo, hi, dir, view_dir, line_width)
	# El suelo: una franja verde entre el sótano y la planta baja.
	if _bottom < 0:
		_quad(fill, Vector3(lo.x - 1, _level_y(0), hi.y + 1), Vector3(hi.x + 1, _level_y(0), hi.y + 1),
			Vector3(hi.x + 1, _level_y(0) - 0.15, hi.y + 1), Vector3(lo.x - 1, _level_y(0) - 0.15, hi.y + 1), Color(0.45, 0.9, 0.5, 0.45))
	_mesh.mesh = fill.commit()
	_frame(lo, hi, dir, pitch)


func _draw_level(st: SurfaceTool, level: int, lo: Vector2, hi: Vector2, dir: Vector2, view_dir: Vector3, width: float) -> void:
	var base: Color = LEVEL_COLORS[posmod(level, LEVEL_COLORS.size())]
	var current := level == current_level
	var fill_color := Color(base, FILL_ALPHA_CURRENT if current else FILL_ALPHA)
	var line_color := Color(base, LINE_ALPHA_CURRENT if current else LINE_ALPHA)
	var detail_color := Color(1, 1, 1, 0.95 if current else 0.6)
	var y0 := _level_y(level)
	var y1 := y0 + FLOOR_HEIGHT
	var walls := exterior_walls(house, level)
	if walls.is_empty():
		# Piso agregado todavía vacío: marco tenue para poder tocarlo.
		_quad(st, Vector3(lo.x, y0, hi.y), Vector3(hi.x, y0, hi.y), Vector3(hi.x, y1, hi.y), Vector3(lo.x, y1, hi.y), Color(base, FILL_ALPHA * 0.6))
		_rect_outline(st, Vector3(lo.x, y0, hi.y), Vector3(hi.x, y0, hi.y), Vector3(hi.x, y1, hi.y), Vector3(lo.x, y1, hi.y), Color(base, 0.4), view_dir, width * 0.7)
	var corner_count := {}
	for w in walls:
		for v in HouseGrid.edge_vertices(w["key"]):
			corner_count[v] = int(corner_count.get(v, 0)) + 1
	for w in walls:
		var a_v: Vector2i = HouseGrid.edge_vertices(w["key"])[0]
		var b_v: Vector2i = HouseGrid.edge_vertices(w["key"])[1]
		var a := Vector3(a_v.x, y0, a_v.y)
		var b := Vector3(b_v.x, y0, b_v.y)
		var up := Vector3(0, FLOOR_HEIGHT, 0)
		# Pulido 3B: la paredes de ATRÁS no dibujan sus aristas (si no, se ven
		# los bordes del fondo como en un cubo transparente y ensucia). Solo se
		# dibujan las aristas de las caras que miran hacia nosotros.
		var facing := Vector2(w["normal"]).dot(dir) > FACING_MIN
		_quad(st, a, b, b + up, a + up, fill_color)
		# Pulido 5D: sin techo ni piso encima, la cara de arriba de la casa se ve desde
		# arriba: el borde de arriba de las paredes de atrás también es silueta.
		# Pulido 6A (10): se decide pared por pared (antes era «todo el piso o nada»: con un segundo
		# piso más chico, el borde de arriba del primero quedaba sin dibujar y parecía un hueco).
		if not facing and top_edge_exposed(house, level, w["key"]):
			_line(st, a + up, b + up, line_color, view_dir, width)
		if not facing:
			continue
		_line(st, a, b, line_color, view_dir, width)
		_line(st, a + up, b + up, line_color, view_dir, width)
		# Vertical solo donde la pared no sigue recta (esquinas y puntas).
		for v in [a_v, b_v]:
			if int(corner_count[v]) != 2 or _is_corner(walls, v):
				var p := Vector3(v.x, y0, v.y)
				_line(st, p, p + up, line_color, view_dir, width)
		# Puerta y ventanas: solo en las paredes que miran hacia nosotros.
		if facing and w["opening"] != "":
			var normal := Vector3(w["normal"].x, 0, w["normal"].y) * 0.06
			var mid := (a + b) / 2.0 + normal
			var along := (b - a) * 0.5
			if w["opening"] == "door":
				var lo_p := mid - along * 0.6
				var hi_p := mid + along * 0.6
				_rect_outline(st, lo_p, hi_p, hi_p + Vector3(0, 2.1, 0), lo_p + Vector3(0, 2.1, 0), detail_color, view_dir, width * 0.8)
				_quad(st, lo_p, hi_p, hi_p + Vector3(0, 2.1, 0), lo_p + Vector3(0, 2.1, 0), Color(detail_color, 0.22))
			else:
				var lo_w := mid - along * 0.6 + Vector3(0, 0.9, 0)
				var hi_w := mid + along * 0.6 + Vector3(0, 0.9, 0)
				_rect_outline(st, lo_w, hi_w, hi_w + Vector3(0, 1.0, 0), lo_w + Vector3(0, 1.0, 0), detail_color, view_dir, width * 0.8)
				_quad(st, lo_w, hi_w, hi_w + Vector3(0, 1.0, 0), lo_w + Vector3(0, 1.0, 0), Color(detail_color, 0.25))
	# Techos de este piso (encima de las paredes).
	for key in house.get_layer(level, "roofs"):
		var value: Dictionary = house.get_piece(level, "roofs", key)
		_draw_roof(st, HouseData.roof_rect(value), y1, Catalog.get_item(value.get("item", "")).get("roof_style", "") == "flat", line_color, view_dir, width)


## Pulido 6A (10): ¿el borde de arriba de esta pared se ve desde arriba? Sí si NADA lo cubre:
## ni un piso del nivel de arriba, ni un techo de este nivel, en ninguna de sus dos celdas vecinas.
static func top_edge_exposed(target: HouseData, level: int, key: String) -> bool:
	for cell in HouseGrid.edge_cells(key):
		if target.has_piece(level + 1, "floors", HouseGrid.cell_key(cell)):
			return false
		for roof_key in target.get_layer(level, "roofs"):
			var rect := HouseData.roof_rect(target.get_piece(level, "roofs", roof_key))
			if rect.has_point(cell):
				return false
	return true


## Una esquina de verdad: dos paredes que no siguen en línea recta.
static func _is_corner(walls: Array, vertex: Vector2i) -> bool:
	var horizontal := 0
	var vertical := 0
	for w in walls:
		if vertex in HouseGrid.edge_vertices(w["key"]):
			if HouseGrid.is_edge_horizontal(w["key"]):
				horizontal += 1
			else:
				vertical += 1
	return horizontal > 0 and vertical > 0


func _draw_roof(st: SurfaceTool, rect: Rect2i, y: float, flat: bool, color: Color, view_dir: Vector3, width: float) -> void:
	var x0 := float(rect.position.x)
	var z0 := float(rect.position.y)
	var x1 := x0 + rect.size.x
	var z1 := z0 + rect.size.y
	var base := [Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1)]
	# Pulido 3B: solo las aristas del techo que miran hacia la cámara de la maqueta.
	var toward := -Vector2(view_dir.x, view_dir.z)
	var edge_normals := [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]
	var facing := [false, false, false, false]
	for i in 4:
		facing[i] = edge_normals[i].dot(toward) > FACING_MIN
		if facing[i] or flat:
			_line(st, base[i], base[(i + 1) % 4], color, view_dir, width)
	# Pulido 5D: la losa plana se ve desde arriba, así que sus CUATRO aristas son visibles
	# (antes faltaba la de atrás/izquierda). El techo a dos aguas esconde las de atrás.
	if flat:
		return
	# Una esquina se dibuja si toca una arista que mira hacia nosotros.
	var corner_shown := func(c: int) -> bool: return facing[c] or facing[(c + 3) % 4]
	var rise := minf(rect.size.x, rect.size.y) / 2.0 * 0.6 + 0.2
	var ridge_a: Vector3
	var ridge_b: Vector3
	if rect.size.x >= rect.size.y:
		ridge_a = Vector3(x0, y + rise, (z0 + z1) / 2.0)
		ridge_b = Vector3(x1, y + rise, (z0 + z1) / 2.0)
		if corner_shown.call(0):
			_line(st, base[0], ridge_a, color, view_dir, width)
		if corner_shown.call(3):
			_line(st, base[3], ridge_a, color, view_dir, width)
		if corner_shown.call(1):
			_line(st, base[1], ridge_b, color, view_dir, width)
		if corner_shown.call(2):
			_line(st, base[2], ridge_b, color, view_dir, width)
	else:
		ridge_a = Vector3((x0 + x1) / 2.0, y + rise, z0)
		ridge_b = Vector3((x0 + x1) / 2.0, y + rise, z1)
		if corner_shown.call(0):
			_line(st, base[0], ridge_a, color, view_dir, width)
		if corner_shown.call(1):
			_line(st, base[1], ridge_a, color, view_dir, width)
		if corner_shown.call(3):
			_line(st, base[3], ridge_b, color, view_dir, width)
		if corner_shown.call(2):
			_line(st, base[2], ridge_b, color, view_dir, width)
	_line(st, ridge_a, ridge_b, color, view_dir, width)


## Pone la cámara de frente (con el ángulo elegido) encuadrando toda la casa.
func _frame(lo: Vector2, hi: Vector2, dir: Vector2, pitch: float) -> void:
	var size := hi - lo
	var bottom_y := _level_y(_bottom)
	var height := _level_y(_top) + FLOOR_HEIGHT + 1.6 - bottom_y
	_center = Vector3((lo.x + hi.x) / 2.0, bottom_y + height / 2.0, (lo.y + hi.y) / 2.0)
	var wide := absf(size.x * dir.y) + absf(size.y * dir.x)
	var tall := height * cos(pitch) + (absf(size.x * dir.x) + absf(size.y * dir.y)) * sin(pitch)
	var aspect := self.size.x / maxf(self.size.y, 1.0)
	_camera.size = maxf(tall, wide / maxf(aspect, 0.1)) * 1.15
	var offset := Vector3(dir.x * cos(pitch), sin(pitch), dir.y * cos(pitch)) * 60.0
	_camera.position = _center + offset
	_camera.look_at(_center, Vector3.UP)


# --- Dibujo básico ---

static func _material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true
	return mat


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	for p in [a, b, c, a, c, d]:
		st.set_color(color)
		st.add_vertex(p)


## Una línea gruesa: un rectángulo angosto perpendicular a la mirada.
static func _line(st: SurfaceTool, a: Vector3, b: Vector3, color: Color, view_dir: Vector3, width: float) -> void:
	var side := (b - a).cross(view_dir)
	if side.length() < 0.0001:
		return
	side = side.normalized() * width / 2.0
	_quad(st, a - side, b - side, b + side, a + side, color)


static func _rect_outline(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, view_dir: Vector3, width: float) -> void:
	_line(st, a, b, color, view_dir, width)
	_line(st, b, c, color, view_dir, width)
	_line(st, c, d, color, view_dir, width)
	_line(st, d, a, color, view_dir, width)


# --- Tocar ---

func _on_gui_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if not pressed or house == null:
		return
	var level := level_at(event.position)
	if level >= 0:
		level_picked.emit(level)
	accept_event()


## Piso del dibujo bajo un punto del control (o -1): el más cercano en altura.
func level_at(local_pos: Vector2) -> int:
	var scale_factor := Vector2(_viewport.size) / size if size.x > 0 and size.y > 0 else Vector2.ONE
	var point := local_pos * scale_factor
	var best := -1
	var best_dist := INF
	for level in range(_bottom, _top + 1):
		var screen := _camera.unproject_position(Vector3(_center.x, _level_y(level) + FLOOR_HEIGHT / 2.0, _center.z))
		var dist := absf(screen.y - point.y)
		if dist < best_dist:
			best_dist = dist
			best = level
	return best
