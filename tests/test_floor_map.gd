extends Node
## Pruebas de la maqueta de pisos (Pulido 5D), sin pantalla ni red.
##
##   godot --headless --path . res://tests/test_floor_map.tscn
##
## Mira: las cuatro aristas de la losa plana, el borde de arriba de las paredes
## de atrás cuando no hay techo, y el punto del personaje (solo dentro de la
## casa, en su piso aunque se mire otro, y también mientras duerme).

var _passed := 0
var _failed := 0
var _house: HouseData
var _map: FloorMap


## Un personaje de mentira: solo lo que lee la maqueta.
class FakeCharacter extends Node3D:
	var level := 0
	var cell := Vector2i.ZERO
	var state := 0


func _ready() -> void:
	HouseGrid.use_test_lot()
	_house = HouseData.new()
	_build_house()
	_test_flat_roof_edges()
	_test_open_top()
	_test_inside()
	await _test_dot()
	print("\nPRUEBAS: %d pasaron, %d fallaron" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _check(condition: bool, description: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		print("FALLÓ: ", description)


## Casa de 4x4 celdas desde (6,6) con paredes, un segundo piso con solo losa y un balcón de pasto afuera.
func _build_house() -> void:
	var o := Vector2i(6, 6)
	var writes: Array = []
	for c in HouseGrid.cells_in_rect(o, o + Vector2i(3, 3)):
		writes.append(HouseData.write(0, "foundation", HouseGrid.cell_key(c), {"item": "foundation_basic"}))
		writes.append(HouseData.write(0, "floors", HouseGrid.cell_key(c), {"item": "floor_basic"}))
	for edge in HouseGrid.edges_around_rect(o, o + Vector2i(3, 3)):
		writes.append(HouseData.write(0, "walls", edge, {"item": "wall_basic"}))
	# Una veranda: piso suelto sin paredes, pegada a la casa.
	for c in HouseGrid.cells_in_rect(Vector2i(6, 10), Vector2i(9, 11)):
		writes.append(HouseData.write(0, "floors", HouseGrid.cell_key(c), {"item": "floor_basic"}))
	_house.next_id = 10
	_house.apply(writes)


func _vertices(st: SurfaceTool) -> PackedVector3Array:
	var mesh := st.commit()
	if mesh.get_surface_count() == 0:
		return PackedVector3Array()
	return mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]


## ¿Hay una línea dibujada pegada a la arista a-b? (todos los vértices de algún cuadrito cerca)
func _has_line(vertices: PackedVector3Array, a: Vector3, b: Vector3, tolerance: float) -> bool:
	var i := 0
	while i + 5 < vertices.size():
		var near := true
		for j in 6:
			var p := vertices[i + j]
			var closest := Geometry3D.get_closest_point_to_segment(p, a, b)
			if p.distance_to(closest) > tolerance:
				near = false
				break
		if near:
			return true
		i += 6
	return false


func _test_flat_roof_edges() -> void:
	print("1) Losa plana: las cuatro aristas, en todos los ángulos")
	var map := FloorMap.new()
	var rect := Rect2i(6, 6, 4, 4)
	var y := 2.7
	var corners := [Vector3(6, y, 6), Vector3(10, y, 6), Vector3(10, y, 10), Vector3(6, y, 10)]
	for angle in FloorMap.ANGLE_COUNT:
		var dir := FloorMap.view_direction(angle)
		var pitch := deg_to_rad(FloorMap.PITCH_DEGREES)
		var view_dir := Vector3(-dir.x * cos(pitch), -sin(pitch), -dir.y * cos(pitch)).normalized()
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		map._draw_roof(st, rect, y, true, Color.WHITE, view_dir, 0.2)
		var vertices := _vertices(st)
		var all_edges := true
		for i in 4:
			if not _has_line(vertices, corners[i], corners[(i + 1) % 4], 0.12):
				all_edges = false
				print("      falta la arista %d en el ángulo %d" % [i, angle])
		_check(all_edges, "ángulo %d: se dibujan las 4 aristas de la losa plana" % angle)
	# El techo a dos aguas sigue escondiendo las aristas de atrás (menos líneas que la losa).
	var dir0 := FloorMap.view_direction(0)
	var view0 := Vector3(-dir0.x, -0.1, -dir0.y).normalized()
	var flat_st := SurfaceTool.new()
	flat_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	map._draw_roof(flat_st, rect, y, true, Color.WHITE, view0, 0.2)
	var gable_st := SurfaceTool.new()
	gable_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	map._draw_roof(gable_st, rect, y, false, Color.WHITE, view0, 0.2)
	_check(not _has_line(_vertices(gable_st), corners[0], corners[1], 0.12) or not _has_line(_vertices(gable_st), corners[1], corners[2], 0.12),
		"el techo a dos aguas sigue sin dibujar todas las aristas de atrás")
	map.free()


func _test_open_top() -> void:
	print("\n2) Sin techo: el borde de arriba de las paredes de atrás también se dibuja")
	var map := FloorMap.new()
	map.house = _house
	var lo := Vector2(6, 6)
	var hi := Vector2(10, 10)
	var dir := FloorMap.view_direction(0)
	var view_dir := Vector3(-dir.x, -0.12, -dir.y).normalized()
	var open := SurfaceTool.new()
	open.begin(Mesh.PRIMITIVE_TRIANGLES)
	map._draw_level(open, 0, lo, hi, dir, view_dir, 0.2)
	var open_vertices := _vertices(open)
	var top := FloorMap._level_y(0) + FloorMap.FLOOR_HEIGHT
	# Pared de atrás (norte, z = 6) con la vista de frente: su borde de arriba tiene que estar.
	_check(_has_line(open_vertices, Vector3(6, top, 6), Vector3(10, top, 6), 0.12), "sin techo se ve el borde de arriba de la pared de atrás")
	# Con un piso encima, el borde de arriba no se agrega (queda más limpio).
	_house.apply([HouseData.write(1, "floors", "6,6", {"item": "floor_basic"})])
	var closed := SurfaceTool.new()
	closed.begin(Mesh.PRIMITIVE_TRIANGLES)
	map._draw_level(closed, 0, lo, hi, dir, view_dir, 0.2)
	_check(not _has_line(_vertices(closed), Vector3(6, top, 6), Vector3(10, top, 6), 0.12), "con un piso encima no se agregan aristas de atrás")
	_house.apply([HouseData.write(1, "floors", "6,6", null)])
	map.free()


func _test_inside() -> void:
	print("\n3) ¿Dentro de la casa?")
	_check(FloorMap.is_inside(_house, 0, Vector2i(7, 7)), "una celda del cuarto está dentro")
	_check(FloorMap.is_inside(_house, 0, Vector2i(6, 6)), "una celda pegada a la pared está dentro")
	_check(not FloorMap.is_inside(_house, 0, Vector2i(20, 20)), "una celda del lote, sin nada, está afuera")
	_check(not FloorMap.is_inside(_house, 0, Vector2i(7, 11)), "la veranda sin paredes está afuera")
	_check(not FloorMap.is_inside(_house, 1, Vector2i(7, 7)), "el piso de arriba, vacío, no cuenta")


func _test_dot() -> void:
	print("\n4) El punto del personaje")
	_map = FloorMap.new()
	add_child(_map)
	var who := FakeCharacter.new()
	add_child(who)
	_map.setup(_house, who)
	_map.set_level(0)
	who.level = 0
	who.cell = Vector2i(7, 7)
	who.state = 0
	var s := _map.dot_state()
	_check(s["visible"] and s["level"] == 0 and not s["dim"], "dentro de la casa, mirando su piso: punto fuerte")
	who.visible = false  # Dormido o escondido por la vista: el punto sigue.
	who.state = 1
	s = _map.dot_state()
	_check(s["visible"], "duerme o está escondido en la escena: el punto sigue donde está la cama")
	who.visible = true
	who.cell = Vector2i(20, 20)
	s = _map.dot_state()
	_check(not s["visible"], "afuera, en el lote: no hay punto")
	who.cell = Vector2i(7, 11)
	s = _map.dot_state()
	_check(not s["visible"], "en la veranda sin paredes: no hay punto")
	who.cell = Vector2i(7, 7)
	_check(_map.dot_state()["visible"], "vuelve a entrar: vuelve el punto")
	# Otro piso: el punto queda apagado en el piso correcto.
	_house.apply([HouseData.write(1, "floors", "7,7", {"item": "floor_basic"}), HouseData.write(1, "walls", HouseGrid.edge_key(Vector2i(7, 7), true), {"item": "wall_basic"})])
	who.level = 1
	_map.set_level(0)
	s = _map.dot_state()
	_check(s["visible"] and s["level"] == 1 and s["dim"], "en el piso 1 mirando el 0: punto apagado en el piso 1")
	_map.set_level(1)
	s = _map.dot_state()
	_check(s["visible"] and not s["dim"], "al mirar el piso 1 se ve fuerte")
	# Trabajando: está fuera de la casa.
	who.state = Character.State.WORKING
	_check(not _map.dot_state()["visible"], "en el trabajo no hay punto")
	await get_tree().process_frame
	who.queue_free()
	_map.queue_free()
