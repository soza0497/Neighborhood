class_name HouseGrid
## Medidas de la casa y "direcciones" de la cuadrícula.
##
## La casa se arma sobre una cuadrícula de celdas de 1 × 1 m:
##   - CELDA (cell): un cuadrado. Ahí van cimientos, pisos y muebles.
##     Se escribe como texto "x,z", por ejemplo "3,5".
##   - VÉRTICE (vertex): una esquina entre celdas. Va de 0 a LOT_SIZE.
##   - BORDE (edge): el lado entre dos celdas. Ahí van paredes, puertas y ventanas.
##     "h:x,z" = borde horizontal (a lo largo de X) que sale del vértice (x,z).
##     "v:x,z" = borde vertical (a lo largo de Z) que sale del vértice (x,z).
##
## Todo está en coordenadas LOCALES de la casa: la celda (0,0) empieza en (0,0,0).

## Tamaño del lote en celdas (ancho X, fondo Z).
const LOT_SIZE := Vector2i(12, 12)
## Cantidad de pisos (niveles) que se pueden construir: planta baja + 1.
const MAX_LEVELS := 2

## Alto de los cimientos: la planta baja queda a esta altura del pasto.
const FOUNDATION_HEIGHT := 0.3
## Alto de una pared (= distancia entre un piso y el siguiente).
const WALL_HEIGHT := 2.7
## Grosor de las paredes.
const WALL_THICKNESS := 0.15
## Alto de las paredes cuando la vista es "paredes bajas".
const CUT_WALL_HEIGHT := 0.5


## Altura (Y local) de la superficie de un nivel. Nivel 0 = planta baja.
static func level_y(level: int) -> float:
	return FOUNDATION_HEIGHT + level * WALL_HEIGHT


# --- Celdas ---

static func cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


static func key_to_cell(key: String) -> Vector2i:
	var parts := key.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))


static func is_cell_in_lot(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < LOT_SIZE.x and cell.y < LOT_SIZE.y


## Centro de una celda, en el suelo (Y = 0).
static func cell_center(cell: Vector2i) -> Vector3:
	return Vector3(cell.x + 0.5, 0.0, cell.y + 0.5)


## Las 4 paredes posibles alrededor de una celda.
static func cell_edges(cell: Vector2i) -> Array[String]:
	return [
		edge_key(cell, true),                      # norte
		edge_key(cell + Vector2i(0, 1), true),     # sur
		edge_key(cell, false),                     # oeste
		edge_key(cell + Vector2i(1, 0), false),    # este
	]


## Todas las celdas de un rectángulo entre dos celdas (en cualquier orden).
static func cells_in_rect(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
		for z in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
			result.append(Vector2i(x, z))
	return result


# --- Bordes (paredes) ---

static func edge_key(vertex: Vector2i, horizontal: bool) -> String:
	return "%s:%d,%d" % ["h" if horizontal else "v", vertex.x, vertex.y]


static func is_edge_horizontal(key: String) -> bool:
	return key.begins_with("h")


## Vértice donde empieza el borde.
static func edge_vertex(key: String) -> Vector2i:
	return key_to_cell(key.substr(2))


## Los dos vértices de un borde.
static func edge_vertices(key: String) -> Array[Vector2i]:
	var start := edge_vertex(key)
	var step := Vector2i(1, 0) if is_edge_horizontal(key) else Vector2i(0, 1)
	return [start, start + step]


## Las dos celdas que comparten un borde (pueden quedar fuera del lote).
static func edge_cells(key: String) -> Array[Vector2i]:
	var v := edge_vertex(key)
	if is_edge_horizontal(key):
		return [Vector2i(v.x, v.y - 1), v]
	return [Vector2i(v.x - 1, v.y), v]


static func is_edge_in_lot(key: String) -> bool:
	var v := edge_vertex(key)
	if is_edge_horizontal(key):
		return v.x >= 0 and v.x < LOT_SIZE.x and v.y >= 0 and v.y <= LOT_SIZE.y
	return v.x >= 0 and v.x <= LOT_SIZE.x and v.y >= 0 and v.y < LOT_SIZE.y


## Centro de un borde, en el suelo (Y = 0).
static func edge_center(key: String) -> Vector3:
	var v := edge_vertex(key)
	if is_edge_horizontal(key):
		return Vector3(v.x + 0.5, 0.0, v.y)
	return Vector3(v.x, 0.0, v.y + 0.5)


## Los 4 bordes que tocan un vértice.
static func vertex_edges(vertex: Vector2i) -> Array[String]:
	return [
		edge_key(vertex, true),
		edge_key(vertex - Vector2i(1, 0), true),
		edge_key(vertex, false),
		edge_key(vertex - Vector2i(0, 1), false),
	]


## Bordes en línea recta entre dos vértices. Si no están alineados, se usa
## el eje donde la distancia es mayor (la línea "se pega" a ese eje).
static func edges_in_line(a: Vector2i, b: Vector2i) -> Array[String]:
	var result: Array[String] = []
	if absi(b.x - a.x) >= absi(b.y - a.y):
		for x in range(mini(a.x, b.x), maxi(a.x, b.x)):
			result.append(edge_key(Vector2i(x, a.y), true))
	else:
		for z in range(mini(a.y, b.y), maxi(a.y, b.y)):
			result.append(edge_key(Vector2i(a.x, z), false))
	return result


## Bordes del contorno de un rectángulo de celdas.
static func edges_around_rect(a: Vector2i, b: Vector2i) -> Array[String]:
	var lo := Vector2i(mini(a.x, b.x), mini(a.y, b.y))
	var hi := Vector2i(maxi(a.x, b.x) + 1, maxi(a.y, b.y) + 1)
	var result: Array[String] = []
	result.append_array(edges_in_line(lo, Vector2i(hi.x, lo.y)))
	result.append_array(edges_in_line(Vector2i(lo.x, hi.y), hi))
	result.append_array(edges_in_line(lo, Vector2i(lo.x, hi.y)))
	result.append_array(edges_in_line(Vector2i(hi.x, lo.y), hi))
	return result


# --- Objetos (muebles, escaleras) ---

## Tamaño en celdas que ocupa un objeto girado. rotation = 0..3 (cuartos de vuelta).
static func rotated_size(footprint: Vector2i, rotation: int) -> Vector2i:
	if rotation % 2 == 1:
		return Vector2i(footprint.y, footprint.x)
	return footprint


## Celdas que ocupa un objeto. `anchor` es su celda de menor x y menor z.
static func object_cells(footprint: Vector2i, anchor: Vector2i, rotation: int) -> Array[Vector2i]:
	var size := rotated_size(footprint, rotation)
	return cells_in_rect(anchor, anchor + size - Vector2i.ONE)


## Bordes que quedan DENTRO de un objeto (entre sus propias celdas).
## Un objeto no puede tener una pared atravesada.
static func object_inner_edges(footprint: Vector2i, anchor: Vector2i, rotation: int) -> Array[String]:
	var size := rotated_size(footprint, rotation)
	var result: Array[String] = []
	for x in range(anchor.x, anchor.x + size.x):
		for z in range(anchor.y + 1, anchor.y + size.y):
			result.append(edge_key(Vector2i(x, z), true))
	for z in range(anchor.y, anchor.y + size.y):
		for x in range(anchor.x + 1, anchor.x + size.x):
			result.append(edge_key(Vector2i(x, z), false))
	return result
