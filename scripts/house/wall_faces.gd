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


# --- Pulido 6A (1): cara interior y cara exterior ---

## ¿Esta cara da hacia afuera? La cara es interior si en la celda a la que mira hay piso
## en ese nivel (hay "adentro"); si no, es exterior (mira al pasto, al aire o al vacío).
static func is_exterior(house: HouseData, level: int, edge: String, side: String) -> bool:
	var cell := cell_for_side(edge, side)
	return not house.has_piece(level, "floors", HouseGrid.cell_key(cell))


## El lado que hay que pintar según lo que pidió el jugador:
##   "touch"   = la cara que tocó (como siempre),
##   "inside"  = la interior de esa pared (aunque haya tocado la de afuera),
##   "outside" = la exterior.
## Si la pared no tiene esa clase de cara (por ejemplo, entre dos cuartos las dos son
## interiores), queda la que tocó.
static func resolve_scope(house: HouseData, level: int, edge: String, side: String, scope: String) -> String:
	if scope != "inside" and scope != "outside":
		return side
	var other := "b" if side == "a" else "a"
	var side_outside := is_exterior(house, level, edge, side)
	var other_outside := is_exterior(house, level, edge, other)
	if scope == "inside" and side_outside and not other_outside:
		return other
	if scope == "outside" and not side_outside and other_outside:
		return other
	return side


## Colores que hereda una pared NUEVA de la que ya está seguida en la misma línea (la de
## antes o la de después): así una pared que se alarga queda del mismo color por fuera y por
## dentro. `pending` = paredes que se están agregando en el mismo gesto (clave → valor).
## Devuelve {color_a?, color_b?} (vacío si no hay vecina pintada).
static func inherited_colors(house: HouseData, level: int, edge: String, pending: Dictionary = {}) -> Dictionary:
	for neighbor in [HouseGrid.previous_in_line(edge), HouseGrid.next_in_line(edge)]:
		var value: Variant = pending.get(neighbor, house.get_piece(level, "walls", neighbor))
		if value == null:
			continue
		var colors := {}
		for field in ["color_a", "color_b"]:
			if (value as Dictionary).has(field):
				colors[field] = value[field]
		if not colors.is_empty():
			return colors
	return {}
