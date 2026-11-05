class_name ExpressionArt
extends RefCounted
## Dibuja las expresiones del personaje (Pulido 6B): una nubecita de cómic con una carita o un
## símbolo adentro. Los dibujos están en data/expressions.json (figuras simples: círculos,
## líneas, arcos y polígonos), así que se pueden editar o agregar sin tocar el código ni hacer
## imágenes. Cada expresión se dibuja UNA vez (la primera que se usa) y queda guardada.
##
## Sin imágenes: todo se pinta en una `Image` con bordes suavizados. Sirve igual en el teléfono
## y sin ventana (las pruebas).

const DATA_PATH := "res://data/expressions.json"
## Punta de la colita de la nube, en píxeles de la imagen (de ahí "sale" hacia el personaje).
const TAIL_TIP := Vector2(56, 118)
## La nube: una elipse central y ocho bultos alrededor (centro, radios del óvalo, radio del bulto).
const CLOUD_CENTER := Vector2(64, 58)
const CLOUD_RADII := Vector2(46, 36)
const CLOUD_BUMP := 17.0
const CLOUD_BUMPS := 8

static var _data: Dictionary = {}
static var _textures: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if parsed is Dictionary:
			_data = parsed
		else:
			push_error("No se pudo leer %s" % DATA_PATH)
			_data = {"canvas": {}, "bubble": {}, "expressions": {}, "events": {}}
	return _data


static func bubble_config() -> Dictionary:
	return data().get("bubble", {})


static func expression_ids() -> Array:
	return data().get("expressions", {}).keys()


static func has_expression(id: String) -> bool:
	return data().get("expressions", {}).has(id)


static func expression_name(id: String) -> String:
	return str(data().get("expressions", {}).get(id, {}).get("name", id))


## Todas las situaciones que tienen expresiones (action:sleep, need:hunger, accident:fall…).
static func event_names() -> Array:
	return data().get("events", {}).keys()


## Las expresiones posibles para una situación (puede haber varias: más variedad).
static func event_variants(event: String) -> Array:
	return data().get("events", {}).get(event, [])


static func canvas_size() -> Vector2i:
	var size: Array = data().get("canvas", {}).get("size", [128, 124])
	return Vector2i(int(size[0]), int(size[1]))


## La textura (con mipmaps) de una expresión; se dibuja la primera vez y después se reutiliza.
static func texture(id: String) -> ImageTexture:
	if not _textures.has(id):
		_textures[id] = ImageTexture.create_from_image(render(id))
	return _textures[id]


## Dibuja la nube con la expresión adentro.
static func render(id: String) -> Image:
	var size := canvas_size()
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	_draw_cloud(image)
	var canvas: Dictionary = data().get("canvas", {})
	var origin_array: Array = canvas.get("art_origin", [24, 18])
	var origin := Vector2(float(origin_array[0]), float(origin_array[1]))
	var scale := float(canvas.get("art_scale", 0.8))
	var art: Array = data().get("expressions", {}).get(id, {}).get("art", [])
	for command in art:
		_draw_command(image, command, origin, scale)
	image.generate_mipmaps()
	return image


# --- La nube ---

static func _draw_cloud(image: Image) -> void:
	var cfg := bubble_config()
	var fill := Color.from_string(str(cfg.get("fill", "#ffffff")), Color.WHITE)
	var outline := Color.from_string(str(cfg.get("outline", "#2a3350")), Color.BLACK)
	var edge := float(cfg.get("outline_width", 3.0))
	var tail := PackedVector2Array([Vector2(54, 88), Vector2(78, 88), TAIL_TIP])
	# Primero el contorno de todo (un poco más grande) y después el relleno, así no se ven costuras.
	for pass_index in 2:
		var color := outline if pass_index == 0 else fill
		var grow := edge if pass_index == 0 else 0.0
		_fill_ellipse(image, CLOUD_CENTER, CLOUD_RADII + Vector2(grow, grow), color)
		for i in CLOUD_BUMPS:
			var angle := TAU * float(i) / float(CLOUD_BUMPS)
			var center := CLOUD_CENTER + Vector2(cos(angle) * (CLOUD_RADII.x - 2.0), sin(angle) * (CLOUD_RADII.y - 2.0))
			_fill_circle(image, center, CLOUD_BUMP + grow, color)
		_fill_polygon(image, tail, color)
		if pass_index == 0:
			for i in tail.size():
				_stroke_line(image, tail[i], tail[(i + 1) % tail.size()], edge * 2.0, color)


# --- Una figura del dibujo (coordenadas 0 a 100 → píxeles) ---

static func _draw_command(image: Image, command: Dictionary, origin: Vector2, scale: float) -> void:
	var fill := Color.from_string(str(command.get("fill", "#00000000")), Color(0, 0, 0, 0))
	var has_fill := command.has("fill")
	var outline := Color.from_string(str(command.get("outline", "#00000000")), Color(0, 0, 0, 0))
	var has_outline := command.has("outline")
	var stroke := Color.from_string(str(command.get("color", "#3a2f2f")), Color.BLACK)
	var width := float(command.get("w", 3.0)) * scale
	if command.has("circle"):
		var v: Array = command["circle"]
		var center := _map(v, 0, origin, scale)
		var radius := float(v[2]) * scale
		if has_fill and has_outline:
			_fill_circle(image, center, radius + width / 2.0, outline)
			_fill_circle(image, center, radius - width / 2.0, fill)
		elif has_fill:
			_fill_circle(image, center, radius, fill)
		elif has_outline:
			_ring(image, center, radius, width, outline)
	elif command.has("ellipse"):
		var e: Array = command["ellipse"]
		var e_center := _map(e, 0, origin, scale)
		var radii := Vector2(float(e[2]), float(e[3])) * scale
		if has_fill and has_outline:
			_fill_ellipse(image, e_center, radii + Vector2(width, width) / 2.0, outline)
			_fill_ellipse(image, e_center, radii - Vector2(width, width) / 2.0, fill)
		elif has_fill:
			_fill_ellipse(image, e_center, radii, fill)
		elif has_outline:
			_fill_ellipse(image, e_center, radii + Vector2(width, width) / 2.0, outline)
	elif command.has("line"):
		var l: Array = command["line"]
		_stroke_line(image, _map(l, 0, origin, scale), _map(l, 2, origin, scale), width, stroke)
	elif command.has("arc"):
		var a: Array = command["arc"]
		var a_center := _map(a, 0, origin, scale)
		var a_radius := float(a[2]) * scale
		var start := float(a[3])
		var end := float(a[4])
		var steps := maxi(3, int(ceil(absf(end - start) / 12.0)))
		var previous := a_center + Vector2(cos(deg_to_rad(start)), sin(deg_to_rad(start))) * a_radius
		for i in range(1, steps + 1):
			var angle := deg_to_rad(lerpf(start, end, float(i) / float(steps)))
			var next := a_center + Vector2(cos(angle), sin(angle)) * a_radius
			_stroke_line(image, previous, next, width, stroke)
			previous = next
	elif command.has("poly"):
		var flat: Array = command["poly"]
		var points := PackedVector2Array()
		for i in range(0, flat.size() - 1, 2):
			points.append(origin + Vector2(float(flat[i]), float(flat[i + 1])) * scale)
		if has_fill:
			_fill_polygon(image, points, fill)
		if has_outline:
			for i in points.size():
				_stroke_line(image, points[i], points[(i + 1) % points.size()], width, outline)


## Punto (x, y) que empieza en la posición `index` de la lista, ya en píxeles.
static func _map(values: Array, index: int, origin: Vector2, scale: float) -> Vector2:
	return origin + Vector2(float(values[index]), float(values[index + 1])) * scale


# --- Pintar (con bordes suaves) ---

static func _plot(image: Image, x: int, y: int, color: Color, coverage: float) -> void:
	if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
		return
	var alpha := color.a * clampf(coverage, 0.0, 1.0)
	if alpha <= 0.001:
		return
	if alpha >= 0.999:
		image.set_pixel(x, y, Color(color.r, color.g, color.b, 1.0))
		return
	var under := image.get_pixel(x, y)
	var out_alpha := alpha + under.a * (1.0 - alpha)
	var mix := Color(
		(color.r * alpha + under.r * under.a * (1.0 - alpha)) / out_alpha,
		(color.g * alpha + under.g * under.a * (1.0 - alpha)) / out_alpha,
		(color.b * alpha + under.b * under.a * (1.0 - alpha)) / out_alpha,
		out_alpha)
	image.set_pixel(x, y, mix)


static func _fill_circle(image: Image, center: Vector2, radius: float, color: Color) -> void:
	if radius <= 0.0:
		return
	for y in range(int(floor(center.y - radius - 1.0)), int(ceil(center.y + radius + 1.0)) + 1):
		for x in range(int(floor(center.x - radius - 1.0)), int(ceil(center.x + radius + 1.0)) + 1):
			var distance := Vector2(x + 0.5, y + 0.5).distance_to(center)
			_plot(image, x, y, color, radius + 0.5 - distance)


static func _ring(image: Image, center: Vector2, radius: float, width: float, color: Color) -> void:
	var reach := radius + width
	for y in range(int(floor(center.y - reach - 1.0)), int(ceil(center.y + reach + 1.0)) + 1):
		for x in range(int(floor(center.x - reach - 1.0)), int(ceil(center.x + reach + 1.0)) + 1):
			var distance := Vector2(x + 0.5, y + 0.5).distance_to(center)
			_plot(image, x, y, color, width / 2.0 + 0.5 - absf(distance - radius))


static func _fill_ellipse(image: Image, center: Vector2, radii: Vector2, color: Color) -> void:
	if radii.x <= 0.0 or radii.y <= 0.0:
		return
	var smallest := minf(radii.x, radii.y)
	for y in range(int(floor(center.y - radii.y - 1.0)), int(ceil(center.y + radii.y + 1.0)) + 1):
		for x in range(int(floor(center.x - radii.x - 1.0)), int(ceil(center.x + radii.x + 1.0)) + 1):
			var delta := Vector2(x + 0.5 - center.x, y + 0.5 - center.y)
			var normalized := sqrt(pow(delta.x / radii.x, 2.0) + pow(delta.y / radii.y, 2.0))
			_plot(image, x, y, color, (1.0 - normalized) * smallest + 0.5)


## Una línea con puntas redondas.
static func _stroke_line(image: Image, from: Vector2, to: Vector2, width: float, color: Color) -> void:
	var half := maxf(width, 1.0) / 2.0
	var low := Vector2(minf(from.x, to.x), minf(from.y, to.y)) - Vector2(half + 1.0, half + 1.0)
	var high := Vector2(maxf(from.x, to.x), maxf(from.y, to.y)) + Vector2(half + 1.0, half + 1.0)
	var segment := to - from
	var length_squared := segment.length_squared()
	for y in range(int(floor(low.y)), int(ceil(high.y)) + 1):
		for x in range(int(floor(low.x)), int(ceil(high.x)) + 1):
			var point := Vector2(x + 0.5, y + 0.5)
			var t := 0.0 if length_squared < 0.0001 else clampf((point - from).dot(segment) / length_squared, 0.0, 1.0)
			_plot(image, x, y, color, half + 0.5 - point.distance_to(from + segment * t))


static func _fill_polygon(image: Image, points: PackedVector2Array, color: Color) -> void:
	if points.size() < 3:
		return
	var low := points[0]
	var high := points[0]
	for point in points:
		low = Vector2(minf(low.x, point.x), minf(low.y, point.y))
		high = Vector2(maxf(high.x, point.x), maxf(high.y, point.y))
	for y in range(int(floor(low.y)), int(ceil(high.y)) + 1):
		for x in range(int(floor(low.x)), int(ceil(high.x)) + 1):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), points):
				_plot(image, x, y, color, 1.0)
