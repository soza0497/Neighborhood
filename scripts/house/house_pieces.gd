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
static var _quad_mesh: QuadMesh = QuadMesh.new()
static var _materials: Dictionary = {}


## Material de una pieza: toon con contorno (uno por color, compartido).
## Todo el arte pasa por acá y por Style: ver data/style.json.
static func material(color: Color) -> Material:
	return Style.toon_material(color)


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


## Material de vidrio: transparente y visible de los dos lados.
static func glass_material(color: Color) -> StandardMaterial3D:
	var key := "g" + color.to_html()
	if not _materials.has(key):
		var mat := transparent_material(color).duplicate()
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materials[key] = mat
	return _materials[key]


## Color de una pieza: el pintado, o si no, el del catálogo.
static func piece_color(value: Dictionary) -> Color:
	if value.has("color"):
		return Color.from_string(value["color"], Color.MAGENTA)
	var item := Catalog.get_item(value.get("item", ""))
	return Color.from_string(item.get("color", "#ff00ff"), Color.MAGENTA)


## Color de una cara de pared ("a" o "b", ver HouseData): la pintada, o el
## color viejo de toda la pared, o el del catálogo.
static func wall_face_color(value: Dictionary, face: String) -> Color:
	var field := "color_" + face
	if value.has(field):
		return Color.from_string(value[field], Color.MAGENTA)
	return piece_color(value)


## Pinta de rojo una pieza con problemas (sin apoyo): la lista de "lo que falta".
static func make_problem(node: Node) -> void:
	_apply_override(node, transparent_material(Color(1.0, 0.15, 0.1, 0.75)))


## Pinta una pieza que todavía se está construyendo (naranja transparente).
static func make_construction(node: Node) -> void:
	_apply_override(node, transparent_material(Color(1.0, 0.7, 0.2, 0.5)))


## Pinta todo un nodo (y sus hijos) de verde o rojo transparente.
static func make_ghost(node: Node, valid: bool) -> void:
	var color := Color(0.3, 1.0, 0.45, 0.55) if valid else Color(1.0, 0.25, 0.2, 0.55)
	_apply_override(node, transparent_material(color))


## Pulido 2: deja una pieza "prevista": igual que la real pero con el color
## aclarado y un brillo que la vista prende y apaga. Devuelve los materiales
## (copias propias de esta pieza) para animarles el brillo ("glow").
static func make_planned(node: Node) -> Array:
	var result: Array = []
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node
		if mesh_instance.material_override is ShaderMaterial:
			var copy := _planned_copy(mesh_instance.material_override)
			mesh_instance.material_override = copy
			result.append(copy)
		elif mesh_instance.mesh != null:
			for surface in mesh_instance.mesh.get_surface_count():
				var source: Material = mesh_instance.mesh.surface_get_material(surface)
				if source is ShaderMaterial:
					var copy := _planned_copy(source)
					mesh_instance.set_surface_override_material(surface, copy)
					result.append(copy)
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		result.append_array(make_planned(child))
	return result


static func _planned_copy(source: ShaderMaterial) -> ShaderMaterial:
	var copy: ShaderMaterial = source.duplicate()
	var base: Color = source.get_shader_parameter("albedo")
	copy.set_shader_parameter("albedo", base.lerp(Color(0.72, 0.95, 1.0), 0.4))
	copy.set_shader_parameter("glow", 0.0)
	return copy


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


# --- Modelos del catálogo (.glb) con respaldo a las figuras simples ---

## Instancia el modelo de una pieza del catálogo (campo "model": ruta a un
## .glb o a una escena) con su escala, desplazamiento y giro. Devuelve null si
## no hay campo o el archivo no existe: entonces se usan las figuras de siempre.
## Ver docs/estilo.md (convenciones de importación).
static func load_model(item: Dictionary) -> Node3D:
	var path: String = str(item.get("model", ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	var scene: Variant = load(path)
	if not scene is PackedScene:
		return null
	var instance: Variant = (scene as PackedScene).instantiate()
	if not instance is Node3D:
		return null
	var holder := Node3D.new()
	holder.name = "Model"
	holder.add_child(instance)
	var model_scale: Variant = item.get("model_scale", 1.0)
	if model_scale is Array:
		holder.scale = Vector3(model_scale[0], model_scale[1], model_scale[2])
	else:
		holder.scale = Vector3.ONE * float(model_scale)
	var offset: Array = item.get("model_offset", [0, 0, 0])
	holder.position = Vector3(offset[0], offset[1], offset[2])
	holder.rotation.y = deg_to_rad(float(item.get("model_rotation", 0)))
	if not item.get("model_keep_materials", false):
		Style.toonify(holder)
	return holder


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
## `merge_start` / `merge_end`: su ventana se une con la de la pared vecina
## en ese extremo (el vidrio sigue de largo, sin columna en medio).
static func build_wall(key: String, value: Dictionary, visible_height: float, full_length := false,
		merge_start := false, merge_end := false) -> Node3D:
	var node := Node3D.new()
	node.position = HouseGrid.edge_center(key)
	var horizontal := HouseGrid.is_edge_horizontal(key)
	if not horizontal:
		node.rotation.y = PI / 2.0

	var t := HouseGrid.WALL_THICKNESS
	var length := 1.0 if full_length else 1.0 - t
	# Cada cara con su color (Pulido 1): la cara "a" mira a -Z local (norte u
	# oeste). Si las dos son iguales, una sola caja.
	var color_a := wall_face_color(value, "a")
	var color_b := wall_face_color(value, "b")

	# Partes macizas de la pared: todo, menos el hueco de la puerta o ventana.
	var solid: Array = [[0.0, HouseGrid.WALL_HEIGHT]]
	var opening_item := Catalog.get_item(value.get("opening", ""))
	if not opening_item.is_empty():
		var hole: Array = opening_item.get("opening", [0.0, 2.1])
		var bottom := float(hole[0])
		var hole_top := float(hole[1])
		solid = [[0.0, bottom], [hole_top, HouseGrid.WALL_HEIGHT]]
		if opening_item.get("kind", "") == "door":
			# La puerta se ve entera aunque las paredes estén bajas.
			_add_door(node, opening_item, bottom, hole_top, length)
		else:
			# Girada, la pared vertical tiene su inicio hacia +X local.
			var join_minus := merge_start if horizontal else merge_end
			var join_plus := merge_end if horizontal else merge_start
			_add_window(node, opening_item, bottom, minf(hole_top, visible_height), hole_top,
				length, join_minus, join_plus)

	for part in solid:
		var bottom: float = part[0]
		var top: float = minf(part[1], visible_height)
		if top - bottom <= 0.01:
			continue
		if color_a == color_b:
			add_box(node, Vector3(0, (bottom + top) / 2.0, 0), Vector3(length, top - bottom, t), material(color_a))
		else:
			add_box(node, Vector3(0, (bottom + top) / 2.0, -t / 4.0), Vector3(length, top - bottom, t / 2.0), material(color_a))
			add_box(node, Vector3(0, (bottom + top) / 2.0, t / 4.0), Vector3(length, top - bottom, t / 2.0), material(color_b))
	return node


## Marco (lados y arriba) y hoja de la puerta: llenan todo el hueco.
static func _add_door(node: Node3D, item: Dictionary, bottom: float, top: float, length: float) -> void:
	var color := Color.from_string(item.get("color", "#ffffff"), Color.WHITE)
	var height := top - bottom
	var depth := HouseGrid.WALL_THICKNESS + 0.02
	var frame_mat := material(color.darkened(0.35))
	for side in [-1, 1]:
		add_box(node, Vector3(side * (length - DOOR_FRAME) / 2.0, bottom + height / 2.0, 0),
			Vector3(DOOR_FRAME, height, depth), frame_mat)
	add_box(node, Vector3(0, top - DOOR_FRAME / 2.0, 0), Vector3(length, DOOR_FRAME, depth), frame_mat)
	var leaf_height := height - DOOR_FRAME
	add_box(node, Vector3(0, bottom + leaf_height / 2.0, 0), Vector3(length - DOOR_FRAME * 2.0, leaf_height, 0.06), material(color))
	# Manija.
	add_box(node, Vector3(length / 2.0 - DOOR_FRAME - 0.1, bottom + 1.0, 0), Vector3(0.08, 0.04, 0.12), material(color.darkened(0.5)))


## Vidrio de ventana con repisa abajo (y marco arriba si se ve).
## `top` puede venir recortado (paredes bajas); `hole_top` es el real.
## Si se une con la vecina, el vidrio y los marcos se estiran media columna
## hacia ese lado, hasta encontrarse con los de la otra ventana.
static func _add_window(node: Node3D, item: Dictionary, bottom: float, top: float, hole_top: float,
		length: float, join_minus: bool, join_plus: bool) -> void:
	if top - bottom <= 0.01:
		return
	var half_post := HouseGrid.WALL_THICKNESS / 2.0
	var extra_minus := half_post if join_minus else 0.0
	var extra_plus := half_post if join_plus else 0.0
	var width := length + extra_minus + extra_plus
	var center_x := (extra_plus - extra_minus) / 2.0

	# El vidrio es un plano (no una caja): así dos vidrios seguidos no
	# dibujan una línea donde se tocan.
	var color := Color.from_string(item.get("color", "#ffffff"), Color.WHITE)
	color.a = 0.45
	var glass := MeshInstance3D.new()
	glass.mesh = _quad_mesh
	glass.position = Vector3(center_x, (bottom + top) / 2.0, 0)
	glass.scale = Vector3(width, top - bottom, 1)
	glass.material_override = glass_material(color)
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(glass)

	var frame_mat := material(Color.WHITE)
	var frame_size := Vector3(width, 0.06, HouseGrid.WALL_THICKNESS + 0.04)
	add_box(node, Vector3(center_x, bottom + 0.03, 0), frame_size, frame_mat)
	if top >= hole_top - 0.001:
		add_box(node, Vector3(center_x, top - 0.03, 0), frame_size, frame_mat)


## Columna que tapa la esquina donde se juntan paredes.
## Si está entre dos ventanas unidas (`window_item`), la columna se corta a
## la altura de la ventana: ahí pasan el vidrio y los marcos de las paredes.
static func build_post(vertex: Vector2i, color: Color, visible_height: float, window_item: Dictionary = {}) -> Node3D:
	var node := Node3D.new()
	var t := HouseGrid.WALL_THICKNESS
	var center := Vector3(vertex.x, 0, vertex.y)
	var parts: Array = [[0.0, HouseGrid.WALL_HEIGHT]]
	if not window_item.is_empty():
		var hole: Array = window_item.get("opening", [0.9, 2.0])
		parts = [[0.0, float(hole[0])], [float(hole[1]), HouseGrid.WALL_HEIGHT]]
	for part in parts:
		var bottom: float = part[0]
		var top: float = minf(part[1], visible_height)
		if top - bottom > 0.01:
			add_box(node, center + Vector3(0, (bottom + top) / 2.0, 0), Vector3(t, top - bottom, t), material(color))
	return node


## Mueble, escalera o pilar. Se arma "mirando" hacia +Z y después se gira
## (de a 90°, o 45° más si va en diagonal). `ground_drop` = cuánto más abajo
## está el suelo (algo de afuera sobre el pasto, sin cimientos).
static func build_object(value: Dictionary, ground_drop := 0.0) -> Node3D:
	var item := Catalog.get_item(value["item"])
	var footprint := HouseData.item_footprint(item)
	var rot := int(value.get("rot", 0))
	var anchor := HouseData.object_anchor(value)
	var size := HouseGrid.rotated_size(footprint, rot)

	var node := Node3D.new()
	node.position = Vector3(anchor.x + size.x / 2.0, -ground_drop, anchor.y + size.y / 2.0)
	node.rotation.y = -deg_to_rad(HouseGrid.object_angle(rot, value.get("diag", false)))

	# Pulido 2B: si el catálogo trae un modelo (.glb o escena) que existe, se
	# usa; si no, las figuras simples de abajo (el arte se cambia sin tocar código).
	if item.get("kind", "") != "stairs":
		var model := load_model(item)
		if model != null:
			node.add_child(model)
			return node

	var w := float(footprint.x)
	var d := float(footprint.y)
	var h := float(item.get("height", 1.0))
	var color := piece_color(value)
	var main_mat := material(color)
	var dark_mat := material(color.darkened(0.3))
	var light_mat := material(color.lightened(0.6))

	if item.get("kind", "") == "stairs":
		var rise := HouseGrid.WALL_HEIGHT + ground_drop
		match item.get("stairs_style", "straight"):
			"spiral":
				_build_spiral_stairs(node, w, d, rise, main_mat, dark_mat)
			"metal":
				_build_metal_stairs(node, w, d, rise, main_mat, dark_mat)
			_:
				_build_stairs(node, w, d, rise, main_mat, dark_mat)
		return node
	if item.get("kind", "") == "pillar":
		var tall := HouseGrid.WALL_HEIGHT + ground_drop
		add_box(node, Vector3(0, tall / 2.0, 0), Vector3(0.32, tall, 0.32), main_mat)
		add_box(node, Vector3(0, 0.08, 0), Vector3(0.46, 0.16, 0.46), dark_mat)
		add_box(node, Vector3(0, tall - 0.08, 0), Vector3(0.46, 0.16, 0.46), dark_mat)
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
		"plant":
			var pot := material(Color("#c9774f"))
			add_box(node, Vector3(0, 0.15, 0), Vector3(0.4, 0.3, 0.4), pot)
			add_box(node, Vector3(0, 0.3 + (h - 0.3) * 0.45, 0), Vector3(0.55, (h - 0.3) * 0.9, 0.55), main_mat)
			add_box(node, Vector3(0, h - 0.12, 0), Vector3(0.35, 0.24, 0.35), light_mat)
		"lamp":
			add_box(node, Vector3(0, 0.03, 0), Vector3(0.35, 0.06, 0.35), dark_mat)
			add_box(node, Vector3(0, h / 2.0, 0), Vector3(0.05, h, 0.05), dark_mat)
			add_box(node, Vector3(0, h - 0.15, 0), Vector3(0.4, 0.3, 0.4), main_mat)
		"vase":
			add_box(node, Vector3(0, h * 0.3, 0), Vector3(0.3, h * 0.6, 0.3), main_mat)
			add_box(node, Vector3(0, h * 0.8, 0), Vector3(0.4, h * 0.4, 0.4), material(Color("#ff9db5")))
		_:
			add_box(node, Vector3(0, h / 2.0, 0), Vector3(w * 0.9, h, d * 0.9), main_mat)
			# Marca en el frente, para saber hacia dónde mira.
			add_box(node, Vector3(0, h * 0.7, d * 0.45), Vector3(w * 0.5, 0.06, 0.04), dark_mat)
	return node


## Escalones que suben hacia atrás (-Z) hasta el nivel de arriba.
static func _build_stairs(node: Node3D, w: float, d: float, rise: float, mat: Material, side_mat: Material) -> void:
	var step_depth := d / STAIR_STEPS
	for i in STAIR_STEPS:
		var step_top := (i + 1) * rise / STAIR_STEPS
		var z := d / 2.0 - (i + 0.5) * step_depth
		add_box(node, Vector3(0, step_top / 2.0, z), Vector3(w * 0.85, step_top, step_depth), mat if i % 2 == 0 else side_mat)


## Escalera metálica (de afuera): escalones finos sin relleno, dos largueros
## y una baranda de un lado.
static func _build_metal_stairs(node: Node3D, w: float, d: float, rise: float, mat: Material, side_mat: Material) -> void:
	var step_depth := d / STAIR_STEPS
	for i in STAIR_STEPS:
		var step_top := (i + 1) * rise / STAIR_STEPS
		var z := d / 2.0 - (i + 0.5) * step_depth
		add_box(node, Vector3(0, step_top - 0.03, z), Vector3(w * 0.8, 0.06, step_depth * 0.9), mat)
	var slope := atan2(rise, d)
	var length := sqrt(rise * rise + d * d)
	for side in [-1, 1]:
		var rail := add_box(node, Vector3(side * w * 0.42, rise / 2.0, 0), Vector3(0.06, 0.18, length), side_mat)
		rail.rotation.x = slope
	var handrail := add_box(node, Vector3(w * 0.42, rise / 2.0 + 0.9, 0), Vector3(0.05, 0.05, length), side_mat)
	handrail.rotation.x = slope


## Escalera de caracol: un poste en el medio y escalones en abanico que dan
## una vuelta completa.
static func _build_spiral_stairs(node: Node3D, w: float, d: float, rise: float, mat: Material, side_mat: Material) -> void:
	var radius := minf(w, d) * 0.45
	add_box(node, Vector3(0, rise / 2.0, 0), Vector3(0.14, rise, 0.14), side_mat)
	var steps := STAIR_STEPS + 2
	for i in steps:
		var step := add_box(node, Vector3.ZERO, Vector3(radius, 0.06, 0.42), mat if i % 2 == 0 else side_mat)
		var angle := PI / 2.0 + float(i) / steps * TAU
		step.position = Vector3(cos(angle) * radius / 2.0, (i + 1) * rise / steps - 0.03, -sin(angle) * radius / 2.0)
		step.rotation.y = angle


## Techo a dos aguas sobre un rectángulo de celdas. Va encima de las paredes.
## Tiene grosor, y en cada punta una pared triangular de remate (del color de
## las paredes, `gable_color`) para que no quede un hueco bajo el techo.
static func build_roof(value: Dictionary, gable_color: Color) -> Node3D:
	var rect := HouseData.roof_rect(value)
	if Catalog.get_item(value.get("item", "")).get("roof_style", "gable") == "flat":
		return build_flat_roof(value)

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


## Techo plano de concreto (casa moderna): una losa con un pretil bajito
## alrededor. Va encima de las paredes, como el de dos aguas.
static func build_flat_roof(value: Dictionary) -> Node3D:
	var rect := HouseData.roof_rect(value)
	var node := Node3D.new()
	node.position = Vector3(rect.position.x + rect.size.x / 2.0, HouseGrid.WALL_HEIGHT,
		rect.position.y + rect.size.y / 2.0)
	var color := piece_color(value)
	var slab := 0.22
	var over := 0.12
	var size := Vector2(rect.size.x + over * 2.0, rect.size.y + over * 2.0)
	add_box(node, Vector3(0, slab / 2.0, 0), Vector3(size.x, slab, size.y), material(color))
	var parapet_mat := material(color.darkened(0.12))
	var ph := 0.3
	var pt := 0.14
	for side in [-1, 1]:
		add_box(node, Vector3(0, slab + ph / 2.0, side * (size.y - pt) / 2.0), Vector3(size.x, ph, pt), parapet_mat)
		add_box(node, Vector3(side * (size.x - pt) / 2.0, slab + ph / 2.0, 0), Vector3(pt, ph, size.y - pt * 2.0), parapet_mat)
	return node
