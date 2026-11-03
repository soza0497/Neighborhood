class_name HousePieces
## Fabrica las figuras 3D provisionales de cada pieza de la casa
## (cajas y prismas de colores planos, hasta tener arte en la Fase 7).
##
## Cada función devuelve un Node3D listo para agregar dentro del contenedor
## de su nivel (Y = 0 es la superficie del piso de ese nivel).

## Cuánto sobresale el techo por fuera de las paredes.
const ROOF_OVERHANG := 0.3
## Inclinación del techo (alto que sube por cada metro hacia el centro).
const ROOF_SLOPE := 0.7
## Cuánto se levanta el techo sobre las paredes (para que no asomen).
const ROOF_LIFT := 0.1
## Grosor del techo.
const ROOF_THICKNESS := 0.12
## Ancho del marco de las puertas.
const DOOR_FRAME := 0.07
## Cuántos escalones tiene una escalera.
const STAIR_STEPS := 12

# Se reutilizan la misma caja y los mismos materiales en todas las piezas:
# así el teléfono trabaja menos.
static var _box_mesh: BoxMesh = BoxMesh.new()
static var _materials: Dictionary = {}


## Material de color plano (uno por color, compartido).
static func material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.9
		_materials[key] = mat
	return _materials[key]


## Material transparente (vidrios y "fantasmas" de vista previa).
static func transparent_material(color: Color) -> StandardMaterial3D:
	var key := "t" + color.to_html()
	if not _materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_materials[key] = mat
	return _materials[key]


## Color de una pieza: el pintado, o si no, el del catálogo.
static func piece_color(value: Dictionary) -> Color:
	if value.has("color"):
		return Color.from_string(value["color"], Color.MAGENTA)
	var item := Catalog.get_item(value.get("item", ""))
	return Color.from_string(item.get("color", "#ff00ff"), Color.MAGENTA)


## Pinta todo un nodo (y sus hijos) de verde o rojo transparente.
static func make_ghost(node: Node, valid: bool) -> void:
	var color := Color(0.3, 1.0, 0.45, 0.55) if valid else Color(1.0, 0.25, 0.2, 0.55)
	_apply_override(node, transparent_material(color))


static func _apply_override(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_apply_override(child, mat)


## Caja de tamaño `size` centrada en `center`, agregada a `parent`.
static func add_box(parent: Node3D, center: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var box := MeshInstance3D.new()
	box.mesh = _box_mesh
	box.position = center
	box.scale = size
	box.material_override = mat
	parent.add_child(box)
	return box


# --- Piezas ---

static func build_foundation(cell: Vector2i, value: Dictionary) -> Node3D:
	var node := Node3D.new()
	var h := HouseGrid.FOUNDATION_HEIGHT
	add_box(node, HouseGrid.cell_center(cell) + Vector3(0, -h / 2.0, 0), Vector3(1, h, 1), material(piece_color(value)))
	return node


static func build_floor(cell: Vector2i, value: Dictionary) -> Node3D:
	var node := Node3D.new()
	# La baldosa queda un poquito por encima del nivel (para no "pelearse"
	# con los cimientos) y tiene grosor para verse desde abajo.
	add_box(node, HouseGrid.cell_center(cell) + Vector3(0, -0.05, 0), Vector3(1, 0.14, 1), material(piece_color(value)))
	return node


## Una pared. `visible_height` es el alto según la vista (alta o baja).
## `full_length` = true la dibuja de esquina a esquina (para la vista previa).
static func build_wall(key: String, value: Dictionary, visible_height: float, full_length := false) -> Node3D:
	var node := Node3D.new()
	node.position = HouseGrid.edge_center(key)
	if not HouseGrid.is_edge_horizontal(key):
		node.rotation.y = PI / 2.0

	var t := HouseGrid.WALL_THICKNESS
	var length := 1.0 if full_length else 1.0 - t
	var wall_mat := material(piece_color(value))

	# Partes macizas de la pared: todo, menos el hueco de la puerta o ventana.
	var solid: Array = [[0.0, HouseGrid.WALL_HEIGHT]]
	var opening_item := Catalog.get_item(value.get("opening", ""))
	if not opening_item.is_empty():
		var hole: Array = opening_item.get("opening", [0.0, 2.1])
		solid = [[0.0, float(hole[0])], [float(hole[1]), HouseGrid.WALL_HEIGHT]]
		_add_opening_fill(node, opening_item, float(hole[0]), minf(float(hole[1]), visible_height), float(hole[1]), length)

	for part in solid:
		var bottom: float = part[0]
		var top: float = minf(part[1], visible_height)
		if top - bottom > 0.01:
			add_box(node, Vector3(0, (bottom + top) / 2.0, 0), Vector3(length, top - bottom, t), wall_mat)
	return node


## Lo que va dentro del hueco: marco + hoja de la puerta, o vidrio + marco.
## `top` puede venir recortado (vista de paredes bajas); `hole_top` es el real.
static func _add_opening_fill(node: Node3D, item: Dictionary, bottom: float, top: float, hole_top: float, length: float) -> void:
	if top - bottom <= 0.01:
		return
	var color := Color.from_string(item.get("color", "#ffffff"), Color.WHITE)
	var height := top - bottom
	var depth := HouseGrid.WALL_THICKNESS + 0.02
	var show_head := top >= hole_top - 0.001
	if item.get("kind", "") == "door":
		# Marco a los lados y arriba; la hoja llena el resto del hueco.
		var frame_mat := material(color.darkened(0.35))
		for side in [-1, 1]:
			add_box(node, Vector3(side * (length - DOOR_FRAME) / 2.0, bottom + height / 2.0, 0),
				Vector3(DOOR_FRAME, height, depth), frame_mat)
		var leaf_height := height
		if show_head:
			add_box(node, Vector3(0, top - DOOR_FRAME / 2.0, 0), Vector3(length, DOOR_FRAME, depth), frame_mat)
			leaf_height -= DOOR_FRAME
		add_box(node, Vector3(0, bottom + leaf_height / 2.0, 0), Vector3(length - DOOR_FRAME * 2.0, leaf_height, 0.06), material(color))
		# Manija.
		if bottom + 1.0 < top:
			add_box(node, Vector3(length / 2.0 - DOOR_FRAME - 0.1, bottom + 1.0, 0), Vector3(0.08, 0.04, 0.12), material(color.darkened(0.5)))
	else:
		_add_window_glass(node, item, Vector3.ZERO, Vector3(length, 0, 0.03), bottom, top, show_head, Vector3(length, 0, depth + 0.02))


## Vidrio de ventana con repisa abajo (y marco arriba si se ve).
## `glass_size` y `frame_size` traen el alto en 0: se completa aquí.
static func _add_window_glass(node: Node3D, item: Dictionary, base: Vector3, glass_size: Vector3,
		bottom: float, top: float, show_head: bool, frame_size: Vector3) -> void:
	var color := Color.from_string(item.get("color", "#ffffff"), Color.WHITE)
	color.a = 0.45
	glass_size.y = top - bottom
	add_box(node, base + Vector3(0, (bottom + top) / 2.0, 0), glass_size, transparent_material(color))
	var frame_mat := material(Color.WHITE)
	frame_size.y = 0.06
	add_box(node, base + Vector3(0, bottom + 0.03, 0), frame_size, frame_mat)
	if show_head:
		add_box(node, base + Vector3(0, top - 0.03, 0), frame_size, frame_mat)


## Columna que tapa la esquina donde se juntan paredes.
## Si está entre dos ventanas iguales en línea (`window_item`), la columna se
## abre y el vidrio sigue de largo: las ventanas quedan unidas.
static func build_post(vertex: Vector2i, color: Color, visible_height: float,
		window_item: Dictionary = {}, horizontal := true) -> Node3D:
	var node := Node3D.new()
	var t := HouseGrid.WALL_THICKNESS
	var center := Vector3(vertex.x, 0, vertex.y)
	var parts: Array = [[0.0, HouseGrid.WALL_HEIGHT]]
	if not window_item.is_empty():
		var hole: Array = window_item.get("opening", [0.9, 2.0])
		var bottom := float(hole[0])
		var top := float(hole[1])
		parts = [[0.0, bottom], [top, HouseGrid.WALL_HEIGHT]]
		var glass_top := minf(top, visible_height)
		if glass_top - bottom > 0.01:
			var glass := Vector3(t, 0, 0.03) if horizontal else Vector3(0.03, 0, t)
			var frame := Vector3(t, 0, t + 0.04) if horizontal else Vector3(t + 0.04, 0, t)
			_add_window_glass(node, window_item, center, glass, bottom, glass_top, glass_top >= top, frame)
	for part in parts:
		var bottom: float = part[0]
		var top: float = minf(part[1], visible_height)
		if top - bottom > 0.01:
			add_box(node, center + Vector3(0, (bottom + top) / 2.0, 0), Vector3(t, top - bottom, t), material(color))
	return node


## Mueble o escalera. Se arma "mirando" hacia +Z y después se gira.
static func build_object(value: Dictionary) -> Node3D:
	var item := Catalog.get_item(value["item"])
	var footprint := HouseData.item_footprint(item)
	var rot := int(value.get("rot", 0))
	var anchor := HouseData.object_anchor(value)
	var size := HouseGrid.rotated_size(footprint, rot)

	var node := Node3D.new()
	node.position = Vector3(anchor.x + size.x / 2.0, 0, anchor.y + size.y / 2.0)
	node.rotation.y = -rot * PI / 2.0

	var w := float(footprint.x)
	var d := float(footprint.y)
	var h := float(item.get("height", 1.0))
	var color := piece_color(value)
	var main_mat := material(color)
	var dark_mat := material(color.darkened(0.3))
	var light_mat := material(color.lightened(0.6))

	if item.get("kind", "") == "stairs":
		_build_stairs(node, w, d, main_mat, dark_mat)
		return node

	match item.get("shape", "box"):
		"table":
			add_box(node, Vector3(0, h - 0.03, 0), Vector3(w * 0.92, 0.06, d * 0.85), main_mat)
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					add_box(node, Vector3(sx * (w * 0.42), (h - 0.06) / 2.0, sz * (d * 0.36)),
						Vector3(0.07, h - 0.06, 0.07), dark_mat)
		"bed":
			add_box(node, Vector3(0, h * 0.3, 0), Vector3(w * 0.9, h * 0.6, d * 0.95), dark_mat)
			add_box(node, Vector3(0, h * 0.75, 0.05), Vector3(w * 0.86, h * 0.3, d * 0.85), main_mat)
			add_box(node, Vector3(0, h * 0.95, -d * 0.36), Vector3(w * 0.7, 0.12, 0.3), light_mat)
			add_box(node, Vector3(0, (h + 0.35) / 2.0, -d * 0.47), Vector3(w * 0.9, h + 0.35, 0.08), dark_mat)
		"chair":
			var seat := h * 0.5
			add_box(node, Vector3(0, seat, 0), Vector3(w * 0.6, 0.08, d * 0.6), main_mat)
			add_box(node, Vector3(0, seat / 2.0, 0), Vector3(w * 0.45, seat, d * 0.45), dark_mat)
			add_box(node, Vector3(0, (seat + h) / 2.0, -d * 0.27), Vector3(w * 0.6, h - seat, 0.06), main_mat)
		"sofa":
			add_box(node, Vector3(0, h * 0.25, 0.05), Vector3(w * 0.92, h * 0.5, d * 0.75), main_mat)
			add_box(node, Vector3(0, h / 2.0, -d * 0.36), Vector3(w * 0.92, h, d * 0.2), dark_mat)
			for sx in [-1, 1]:
				add_box(node, Vector3(sx * w * 0.42, h * 0.35, 0.05), Vector3(w * 0.08, h * 0.7, d * 0.75), dark_mat)
		_:
			add_box(node, Vector3(0, h / 2.0, 0), Vector3(w * 0.9, h, d * 0.9), main_mat)
			# Marca en el frente, para saber hacia dónde mira.
			add_box(node, Vector3(0, h * 0.7, d * 0.45), Vector3(w * 0.5, 0.06, 0.04), dark_mat)
	return node


## Escalones que suben hacia atrás (-Z) hasta el nivel de arriba.
static func _build_stairs(node: Node3D, w: float, d: float, mat: Material, side_mat: Material) -> void:
	var step_depth := d / STAIR_STEPS
	for i in STAIR_STEPS:
		var step_top := (i + 1) * HouseGrid.WALL_HEIGHT / STAIR_STEPS
		var z := d / 2.0 - (i + 0.5) * step_depth
		add_box(node, Vector3(0, step_top / 2.0, z), Vector3(w * 0.85, step_top, step_depth), mat if i % 2 == 0 else side_mat)


## Techo a dos aguas sobre un rectángulo de celdas. Va encima de las paredes.
## Tiene grosor, y en cada punta una pared triangular de remate (del color de
## las paredes, `gable_color`) para que no quede un hueco bajo el techo.
static func build_roof(value: Dictionary, gable_color: Color) -> Node3D:
	var rect := HouseData.roof_rect(value)

	# Se arma con la cumbrera (la parte más alta) a lo largo del lado largo,
	# en un sistema "a lo largo" (x) y "a lo ancho" (z), centrado.
	var along_x := rect.size.x >= rect.size.y
	var inner_length := float(rect.size.x if along_x else rect.size.y)
	var length := inner_length + ROOF_OVERHANG * 2.0
	var half := float(rect.size.y if along_x else rect.size.x) / 2.0
	var ridge := half * ROOF_SLOPE
	var eave := -ROOF_OVERHANG * ROOF_SLOPE
	var o := half + ROOF_OVERHANG
	var down := Vector3(0, -ROOF_THICKNESS, 0)

	var a := Vector3(-length / 2.0, eave, -o)
	var b := Vector3(length / 2.0, eave, -o)
	var c := Vector3(length / 2.0, ridge, 0)
	var d := Vector3(-length / 2.0, ridge, 0)
	var e := Vector3(-length / 2.0, eave, o)
	var f := Vector3(length / 2.0, eave, o)
	var n_back := Vector3(0, o, -(ridge - eave)).normalized()
	var n_front := Vector3(0, o, ridge - eave).normalized()

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Las dos caídas, por arriba y por abajo.
	_add_quad(st, a, b, c, d, n_back)
	_add_quad(st, e, f, c, d, n_front)
	_add_quad(st, a + down, b + down, c + down, d + down, -n_back)
	_add_quad(st, e + down, f + down, c + down, d + down, -n_front)
	# Cantos: aleros (frente y fondo) y puntas.
	_add_quad(st, a, b, b + down, a + down, Vector3(0, 0, -1))
	_add_quad(st, e, f, f + down, e + down, Vector3(0, 0, 1))
	_add_quad(st, a, d, d + down, a + down, Vector3.LEFT)
	_add_quad(st, d, e, e + down, d + down, Vector3.LEFT)
	_add_quad(st, b, c, c + down, b + down, Vector3.RIGHT)
	_add_quad(st, c, f, f + down, c + down, Vector3.RIGHT)
	var mesh := st.commit()
	mesh.surface_set_material(0, material(piece_color(value)))

	# Paredes de remate: triángulos sobre las paredes de las puntas, con el
	# mismo grosor que una pared. Sus bordes quedan escondidos dentro del techo.
	var gable := SurfaceTool.new()
	gable.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wall_top := -ROOF_LIFT
	var apex := ridge - ROOF_THICKNESS * 0.5
	var spread := half + HouseGrid.WALL_THICKNESS / 2.0
	for side in [-1.0, 1.0]:
		for face in [-1.0, 1.0]:
			var x: float = side * inner_length / 2.0 + face * HouseGrid.WALL_THICKNESS / 2.0
			_add_tri(gable, Vector3(x, wall_top, -spread), Vector3(x, apex, 0), Vector3(x, wall_top, spread),
				Vector3(face, 0, 0))
	mesh = gable.commit(mesh)
	mesh.surface_set_material(1, material(gable_color))

	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = Vector3(rect.position.x + rect.size.x / 2.0, HouseGrid.WALL_HEIGHT + ROOF_LIFT,
		rect.position.y + rect.size.y / 2.0)
	if not along_x:
		node.rotation.y = PI / 2.0
	return node


## Agrega un triángulo con la cara hacia `normal` (Godot dibuja solo el
## frente, así que el orden de los puntos importa: se corrige solo).
static func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	if (b - a).cross(c - a).dot(normal) > 0.0:
		var tmp := b
		b = c
		c = tmp
	for p in [a, b, c]:
		st.set_normal(normal)
		st.add_vertex(p)


static func _add_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
	_add_tri(st, a, b, c, normal)
	_add_tri(st, a, c, d, normal)
