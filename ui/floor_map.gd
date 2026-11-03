class_name FloorMap
extends SubViewportContainer
## Maqueta de pisos (Pulido 1): una casa chiquita y semitransparente, vista
## desde la calle e inclinada, con solo las losas y las paredes de cada piso
## (sin muebles). El piso actual se ve resaltado y un punto parpadea donde
## está el personaje. Tocar un piso de la maqueta = ir a ese piso.
##
## Tiene su propio mundo 3D (no ve la casa de verdad): se redibuja cuando la
## casa cambia, como mucho una vez por cuadro.

## Se tocó un piso de la maqueta.
signal level_picked(level: int)

## Separación entre pisos en la maqueta (metros de la maqueta; se exagera
## un poco para que se distingan los pisos).
const LEVEL_SPACING := 3.4
## Alto de las paredes en la maqueta (solo un contorno bajito).
const WALL_HEIGHT := 0.7
const CURRENT_COLOR := Color(1.0, 0.72, 0.3, 0.85)
const OTHER_COLOR := Color(0.75, 0.88, 1.0, 0.28)
const EMPTY_COLOR := Color(1, 1, 1, 0.12)
## Cuánto se inclina la cámara de la maqueta (grados hacia abajo).
const PITCH_DEGREES := 28.0

var house: HouseData
var character: Node3D
var current_level := 0

var _viewport: SubViewport
var _camera: Camera3D
var _root: Node3D
var _dot: MeshInstance3D
var _dirty := true
var _blink := 0.0
## Pisos que se muestran (los construidos + uno vacío arriba para subir).
var _shown_levels := 1
## Centro y tamaño de lo construido (en celdas), para encuadrar.
var _center := Vector3(16, 0, 16)


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
	# Ortográfica: todos los pisos se ven del mismo tamaño y es fácil encuadrar.
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_viewport.add_child(_camera)
	_root = Node3D.new()
	_viewport.add_child(_root)
	var sphere := SphereMesh.new()
	sphere.radius = 0.6
	sphere.height = 1.2
	_dot = MeshInstance3D.new()
	_dot.mesh = sphere
	_dot.material_override = _material(Color(1.0, 0.3, 0.45, 1.0))
	_viewport.add_child(_dot)
	gui_input.connect(_on_gui_input)


## Conecta la maqueta con la casa y el personaje (los lee, no los cambia).
func setup(new_house: HouseData, new_character: Node3D) -> void:
	house = new_house
	character = new_character
	house.piece_changed.connect(func(_l: int, _layer: String, _k: String) -> void: _dirty = true)
	house.reloaded.connect(func() -> void: _dirty = true)
	_dirty = true


func set_level(level: int) -> void:
	current_level = level
	_dirty = true


func _process(delta: float) -> void:
	if house == null or not is_visible_in_tree():
		return
	if _dirty:
		_dirty = false
		_rebuild()
	# El punto del personaje parpadea (se ve y no se ve, suave).
	_blink += delta
	_dot.visible = character != null and character.visible and fmod(_blink, 1.0) < 0.65
	if character != null:
		var level: int = character.get("level") if character.get("level") != null else 0
		_dot.position = Vector3(character.position.x, level * LEVEL_SPACING + 0.6, character.position.z)


## Arma de nuevo la maqueta: una figura por piso.
func _rebuild() -> void:
	for child in _root.get_children():
		child.queue_free()
	var top_built := 0
	var lo := Vector2i(HouseGrid.LOT_SIZE)
	var hi := Vector2i(-1, -1)
	for level in HouseGrid.MAX_LEVELS:
		var cells := _level_cells(level)
		if not cells.is_empty() or not house.get_layer(level, "walls").is_empty():
			top_built = level
		for cell in cells:
			lo = Vector2i(mini(lo.x, cell.x), mini(lo.y, cell.y))
			hi = Vector2i(maxi(hi.x, cell.x), maxi(hi.y, cell.y))
	if hi.x < 0:
		lo = HouseGrid.LOT_SIZE / 2 - Vector2i(4, 4)
		hi = HouseGrid.LOT_SIZE / 2 + Vector2i(4, 4)
	_shown_levels = mini(maxi(top_built + 2, current_level + 1), HouseGrid.MAX_LEVELS)
	for level in _shown_levels:
		_root.add_child(_build_level(level, lo, hi))
	_frame(lo, hi)


## Celdas con losa de un piso (en la planta baja, también los cimientos).
func _level_cells(level: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for key in house.get_layer(level, "floors"):
		result.append(HouseGrid.key_to_cell(key))
	if level == 0:
		for key in house.get_layer(0, "foundation"):
			var cell := HouseGrid.key_to_cell(key)
			if not cell in result:
				result.append(cell)
	return result


## Un piso de la maqueta: losas planas y paredes bajitas, de un solo color.
## Un piso vacío se dibuja como un marco tenue (para poder tocarlo y subir).
func _build_level(level: int, lo: Vector2i, hi: Vector2i) -> MeshInstance3D:
	var cells := _level_cells(level)
	var color := CURRENT_COLOR if level == current_level else OTHER_COLOR
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var y := level * LEVEL_SPACING
	if cells.is_empty() and house.get_layer(level, "walls").is_empty():
		var empty := EMPTY_COLOR if level != current_level else CURRENT_COLOR * Color(1, 1, 1, 0.4)
		_add_box(st, Vector3(lo.x, y - 0.05, lo.y), Vector3(hi.x + 1, y, hi.y + 1), empty)
	for cell in cells:
		_add_box(st, Vector3(cell.x + 0.04, y - 0.12, cell.y + 0.04), Vector3(cell.x + 0.96, y, cell.y + 0.96), color)
	var wall_color := Color(color, minf(color.a + 0.25, 1.0))
	for key in house.get_layer(level, "walls"):
		var v := HouseGrid.edge_vertex(key)
		var t := 0.12
		if HouseGrid.is_edge_horizontal(key):
			_add_box(st, Vector3(v.x, y, v.y - t), Vector3(v.x + 1, y + WALL_HEIGHT, v.y + t), wall_color)
		else:
			_add_box(st, Vector3(v.x - t, y, v.y), Vector3(v.x + t, y + WALL_HEIGHT, v.y + 1), wall_color)
	var node := MeshInstance3D.new()
	node.mesh = st.commit()
	node.material_override = _material(Color.WHITE)
	return node


## Pone la cámara de la maqueta mirando desde la calle (+Z), inclinada.
func _frame(lo: Vector2i, hi: Vector2i) -> void:
	var size := Vector2(hi - lo + Vector2i.ONE)
	var height := _shown_levels * LEVEL_SPACING
	_center = Vector3(lo.x + size.x / 2.0, height / 2.0 - LEVEL_SPACING * 0.3, lo.y + size.y / 2.0)
	var pitch := deg_to_rad(PITCH_DEGREES)
	# Un poco girada (desde la esquina del frente) para que se note el 3D.
	var yaw := deg_to_rad(-25.0)
	# Lo que ocupa la casa en la pantalla (ancho y alto), para que entre toda.
	var wide := size.x * cos(yaw) + size.y * absf(sin(yaw))
	var deep := size.x * absf(sin(yaw)) + size.y * cos(yaw)
	var tall := height * cos(pitch) + deep * sin(pitch)
	var aspect := self.size.x / maxf(self.size.y, 1.0)
	_camera.size = maxf(tall, wide / maxf(aspect, 0.1)) * 1.12
	var offset := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * 60.0
	_camera.position = _center + offset
	_camera.look_at(_center, Vector3.UP)


## Tocar la maqueta: el piso más cercano (en la pantalla) a donde se tocó.
func _on_gui_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if not pressed or house == null:
		return
	var level := level_at(event.position)
	if level >= 0:
		level_picked.emit(level)
	accept_event()


## Piso de la maqueta bajo un punto del control (o -1).
func level_at(local_pos: Vector2) -> int:
	var scale_factor := Vector2(_viewport.size) / size if size.x > 0 and size.y > 0 else Vector2.ONE
	var point := local_pos * scale_factor
	var best := -1
	var best_dist := INF
	for level in _shown_levels:
		var screen := _camera.unproject_position(Vector3(_center.x, level * LEVEL_SPACING, _center.z))
		var dist := absf(screen.y - point.y)
		if dist < best_dist:
			best_dist = dist
			best = level
	return best


static func _add_box(st: SurfaceTool, a: Vector3, b: Vector3, color: Color) -> void:
	var p := [
		Vector3(a.x, a.y, a.z), Vector3(b.x, a.y, a.z), Vector3(b.x, a.y, b.z), Vector3(a.x, a.y, b.z),
		Vector3(a.x, b.y, a.z), Vector3(b.x, b.y, a.z), Vector3(b.x, b.y, b.z), Vector3(a.x, b.y, b.z),
	]
	for face in [[4, 5, 6, 7], [3, 2, 1, 0], [7, 6, 2, 3], [5, 4, 0, 1], [4, 7, 3, 0], [6, 5, 1, 2]]:
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_color(color)
			st.add_vertex(p[face[i]])


static func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = false
	return mat
