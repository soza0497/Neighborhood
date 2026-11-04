class_name IslandMeshKit
extends RefCounted
## Acumula triángulos con color por vértice y arma UNA malla (Isla 1A).
##
## Sirve para juntar muchas piezas simples (cajas, techos, conos, discos) en una
## sola malla con un solo material: eso es lo que baja las llamadas de dibujo.
## Los colores se guardan en espacio lineal (el shader island_blocks los usa tal cual).
## Las mallas no llevan índices: cada triángulo tiene sus 3 vértices y su normal
## (aspecto facetado, que va con el estilo toon).

var _positions := PackedVector3Array()
var _normals := PackedVector3Array()
var _colors := PackedColorArray()


@warning_ignore("integer_division")
func triangle_count() -> int:
	return _positions.size() / 3


func is_empty() -> bool:
	return _positions.is_empty()


func clear() -> void:
	_positions.clear()
	_normals.clear()
	_colors.clear()


## Agrega todo lo de otro acumulador, movido por `xf`.
func append(other: IslandMeshKit, xf: Transform3D) -> void:
	for i in other._positions.size():
		_positions.append(xf * other._positions[i])
		_normals.append((xf.basis * other._normals[i]).normalized())
		_colors.append(other._colors[i])


## Triángulo con la cara hacia `normal`. Godot dibuja de frente las caras con los
## puntos en sentido horario, así que el orden se corrige solo.
func add_tri(a: Vector3, b: Vector3, c: Vector3, normal: Vector3, color: Color) -> void:
	if (b - a).cross(c - a).dot(normal) > 0.0:
		var tmp := b
		b = c
		c = tmp
	var linear := color.srgb_to_linear()
	_positions.append(a)
	_positions.append(b)
	_positions.append(c)
	for i in 3:
		_normals.append(normal)
		_colors.append(linear)


func add_quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, color: Color) -> void:
	add_tri(a, b, c, normal, color)
	add_tri(a, c, d, normal, color)


## Caja centrada en el origen de `xf`, de tamaño `size` (en los ejes de `xf`).
## Sin la cara de abajo por defecto (nadie la ve y ahorra triángulos).
func add_box(xf: Transform3D, size: Vector3, color: Color, with_bottom := false) -> void:
	var h := size / 2.0
	var faces: Array = [
		[Vector3.UP, Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)],
		[Vector3.BACK, Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)],
		[Vector3.FORWARD, Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z)],
		[Vector3.RIGHT, Vector3(h.x, -h.y, -h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(h.x, h.y, -h.z)],
		[Vector3.LEFT, Vector3(-h.x, -h.y, -h.z), Vector3(-h.x, -h.y, h.z), Vector3(-h.x, h.y, h.z), Vector3(-h.x, h.y, -h.z)],
	]
	if with_bottom:
		faces.append([Vector3.DOWN, Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, -h.y, h.z), Vector3(-h.x, -h.y, h.z)])
	for face in faces:
		var normal: Vector3 = (xf.basis * (face[0] as Vector3)).normalized()
		add_quad(xf * (face[1] as Vector3), xf * (face[2] as Vector3), xf * (face[3] as Vector3), xf * (face[4] as Vector3), normal, color)


## Techo a dos aguas. El origen de `xf` es el centro del borde bajo (alero). La
## cumbrera corre a lo largo de x (`length`); `width` es el fondo en z. Dos caídas
## y las dos puntas triangulares en `gable_color`. Sin cara de abajo.
func add_gable(xf: Transform3D, length: float, width: float, ridge: float, roof_color: Color, gable_color: Color) -> void:
	var hl := length / 2.0
	var hw := width / 2.0
	var a := Vector3(-hl, 0.0, -hw)
	var b := Vector3(hl, 0.0, -hw)
	var c := Vector3(hl, ridge, 0.0)
	var d := Vector3(-hl, ridge, 0.0)
	var e := Vector3(-hl, 0.0, hw)
	var f := Vector3(hl, 0.0, hw)
	var n_back := Vector3(0.0, hw, -ridge).normalized()
	var n_front := Vector3(0.0, hw, ridge).normalized()
	add_quad(xf * a, xf * b, xf * c, xf * d, (xf.basis * n_back).normalized(), roof_color)
	add_quad(xf * e, xf * f, xf * c, xf * d, (xf.basis * n_front).normalized(), roof_color)
	add_tri(xf * a, xf * d, xf * e, (xf.basis * Vector3.LEFT).normalized(), gable_color)
	add_tri(xf * b, xf * c, xf * f, (xf.basis * Vector3.RIGHT).normalized(), gable_color)


## Tronco de cono (o cilindro si los radios son iguales) con el origen en el centro
## de la base, de `height` hacia arriba. `top_radius` 0 = cono. Con tapa de arriba.
func add_frustum(xf: Transform3D, bottom_radius: float, top_radius: float, height: float, segments: int, color: Color, color_top: Color = Color(0, 0, 0, 0)) -> void:
	var cap_color := color if color_top.a == 0.0 else color_top
	for i in segments:
		var a0 := TAU * float(i) / segments
		var a1 := TAU * float(i + 1) / segments
		var b0 := Vector3(cos(a0) * bottom_radius, 0.0, sin(a0) * bottom_radius)
		var b1 := Vector3(cos(a1) * bottom_radius, 0.0, sin(a1) * bottom_radius)
		var t0 := Vector3(cos(a0) * top_radius, height, sin(a0) * top_radius)
		var t1 := Vector3(cos(a1) * top_radius, height, sin(a1) * top_radius)
		var mid := (a0 + a1) / 2.0
		var slope := (bottom_radius - top_radius) / maxf(height, 0.001)
		var n := Vector3(cos(mid), slope, sin(mid)).normalized()
		var wn := (xf.basis * n).normalized()
		if top_radius <= 0.0001:
			add_tri(xf * b0, xf * b1, xf * t0, wn, color)
		else:
			add_quad(xf * b0, xf * b1, xf * t1, xf * t0, wn, color)
			add_tri(xf * t0, xf * t1, xf * Vector3(0.0, height, 0.0), (xf.basis * Vector3.UP).normalized(), cap_color)


## "Bola" de baja poligonación: dos conos pegados por la base (bipirámide).
func add_blob(xf: Transform3D, radius: float, segments: int, color: Color) -> void:
	for i in segments:
		var a0 := TAU * float(i) / segments
		var a1 := TAU * float(i + 1) / segments
		var p0 := Vector3(cos(a0) * radius, 0.0, sin(a0) * radius)
		var p1 := Vector3(cos(a1) * radius, 0.0, sin(a1) * radius)
		var mid := (a0 + a1) / 2.0
		var up := Vector3(cos(mid), 0.8, sin(mid)).normalized()
		var down := Vector3(cos(mid), -0.8, sin(mid)).normalized()
		add_tri(xf * p0, xf * p1, xf * Vector3(0.0, radius * 0.9, 0.0), (xf.basis * up).normalized(), color)
		add_tri(xf * p0, xf * p1, xf * Vector3(0.0, -radius * 0.9, 0.0), (xf.basis * down).normalized(), color)


# --- Suelo (todo plano, normal hacia arriba) ---

## Disco plano a la altura `y`.
func add_disc(center: Vector2, radius: float, y: float, segments: int, color: Color) -> void:
	for i in segments:
		var a0 := TAU * float(i) / segments
		var a1 := TAU * float(i + 1) / segments
		add_tri(Vector3(center.x, y, center.y),
			Vector3(center.x + cos(a0) * radius, y, center.y + sin(a0) * radius),
			Vector3(center.x + cos(a1) * radius, y, center.y + sin(a1) * radius), Vector3.UP, color)


## Anillo plano (o un arco: ángulos en grados, 90 = sur) entre dos radios.
func add_annulus(r_in: float, r_out: float, y: float, segments: int, color: Color, from_deg := 0.0, to_deg := 360.0) -> void:
	var count := maxi(1, int(round(segments * absf(to_deg - from_deg) / 360.0)))
	for i in count:
		var a0 := deg_to_rad(from_deg + (to_deg - from_deg) * float(i) / count)
		var a1 := deg_to_rad(from_deg + (to_deg - from_deg) * float(i + 1) / count)
		var p0 := Vector3(cos(a0) * r_in, y, sin(a0) * r_in)
		var p1 := Vector3(cos(a1) * r_in, y, sin(a1) * r_in)
		var q0 := Vector3(cos(a0) * r_out, y, sin(a0) * r_out)
		var q1 := Vector3(cos(a1) * r_out, y, sin(a1) * r_out)
		add_quad(p0, p1, q1, q0, Vector3.UP, color)


## Rectángulo plano de lados `size` (x, z), girado `yaw` radianes alrededor de `center`.
func add_ground_rect(center: Vector3, size: Vector2, yaw: float, color: Color) -> void:
	var basis := Basis(Vector3.UP, yaw)
	var hx := size.x / 2.0
	var hz := size.y / 2.0
	add_quad(center + basis * Vector3(-hx, 0, -hz), center + basis * Vector3(hx, 0, -hz),
		center + basis * Vector3(hx, 0, hz), center + basis * Vector3(-hx, 0, hz), Vector3.UP, color)


## Tira plana (calle) de `from` a `to`, de ancho `width`, a la altura `y`.
func add_strip(from: Vector2, to: Vector2, width: float, y: float, color: Color) -> void:
	var dir := (to - from).normalized()
	var side := Vector2(-dir.y, dir.x) * width / 2.0
	add_quad(Vector3(from.x + side.x, y, from.y + side.y), Vector3(to.x + side.x, y, to.y + side.y),
		Vector3(to.x - side.x, y, to.y - side.y), Vector3(from.x - side.x, y, from.y - side.y), Vector3.UP, color)


## Arma la malla: UNA superficie con posición, normal y color por vértice.
## Devuelve null si no hay nada.
func build() -> ArrayMesh:
	if _positions.is_empty():
		return null
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _positions
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_COLOR] = _colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
