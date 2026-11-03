class_name WallFaces
## Caras de pared (Pulido 1): cada pared tiene dos caras y se pinta cada una
## aparte. Una "cara" es la pared `edge` vista desde la celda `cell`.
##   - Lado "a": la cara que mira a la 1.ª celda de HouseGrid.edge_cells
##     (norte en las horizontales, oeste en las verticales). Lado "b": la otra.
## Sin nada 3D: solo cuentas sobre la casa.


## "a" o "b": qué lado de la pared mira a esa celda.
static func side_for_cell(edge: String, cell: Vector2i) -> String:
	return "a" if HouseGrid.edge_cells(edge)[0] == cell else "b"


## La celda a la que mira un lado de la pared.
static func cell_for_side(edge: String, side: String) -> Vector2i:
	return HouseGrid.edge_cells(edge)[0 if side == "a" else 1]


## La cara que sigue al recorrer la pared hacia un lado (dir = +1 hacia
## donde crecen las coordenadas, -1 al revés), como quien camina pegado a la
## pared por adentro del cuarto: en una esquina de adentro dobla, si la pared
## sigue derecha sigue, y en una esquina de afuera la rodea.
## Devuelve {edge, side} o {} si no hay más pared.
static func next_face(house: HouseData, level: int, edge: String, side: String, dir: int) -> Dictionary:
	var cell := cell_for_side(edge, side)
	var other := cell_for_side(edge, "b" if side == "a" else "a")
	var normal := cell - other  # Desde la pared hacia la celda.
	var axis := Vector2i(1, 0) if HouseGrid.is_edge_horizontal(edge) else Vector2i(0, 1)
	var step := axis * dir
	var cell_next := cell + step
	# 1) Esquina de adentro: una pared cierra el paso por este lado.
	var inner := HouseGrid.shared_edge(cell, cell_next)
	if house.has_piece(level, "walls", inner):
		return {"edge": inner, "side": side_for_cell(inner, cell)}
	# 2) La pared sigue derecha.
	var straight := HouseGrid.shared_edge(cell_next, cell_next - normal)
	if house.has_piece(level, "walls", straight):
		return {"edge": straight, "side": side_for_cell(straight, cell_next)}
	# 3) Esquina de afuera: la pared dobla hacia el otro lado.
	var outer := HouseGrid.shared_edge(cell - normal, cell_next - normal)
	if house.has_piece(level, "walls", outer):
		return {"edge": outer, "side": side_for_cell(outer, cell_next - normal)}
	return {}


## Centro de una cara (en el suelo del nivel, coordenadas de la casa), un
## poquito hacia su lado. Sirve para saber dónde queda en la pantalla.
static func face_center(edge: String, side: String) -> Vector3:
	var center := HouseGrid.edge_center(edge)
	var cell := cell_for_side(edge, side)
	var toward := HouseGrid.cell_center(cell) - center
	return center + toward * 0.2
