extends Node
## Pruebas del Pulido 6A (construcción y casa), sin pantalla.
##
## Correr desde la terminal, en la carpeta del proyecto:
##   godot --headless --path . res://tests/test_build6a.tscn
## Al final dice cuántas pruebas pasaron. Si alguna falla, dice cuál.
##
## Se va llenando por sub-fase: 6A-1 (contorno, pintura, íconos), 6A-2 (cuadrícula, muebles
## afuera, mini menú, maqueta).

var _passed := 0
var _failed := 0


func _ready() -> void:
	HouseGrid.use_test_lot()
	_test_outline_modes()
	_test_wall_faces()
	_test_wall_paint_pieces()
	_test_build_bar_titles()
	_test_grid_zone_mask()
	_test_outdoor_furniture()
	_test_quick_menu_logic()
	_test_floor_map_top_edges()
	print("\nPRUEBAS 6A: %d pasaron, %d fallaron" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _check(condition: bool, description: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		print("FALLÓ: ", description)


func _box_house() -> HouseData:
	var house := HouseData.new()
	var writes: Array = []
	for c in HouseGrid.cells_in_rect(Vector2i(0, 0), Vector2i(5, 5)):
		writes.append(HouseData.write(0, "foundation", HouseGrid.cell_key(c), {"item": "foundation_basic"}))
	house.apply(writes)
	writes = []
	for c in HouseGrid.cells_in_rect(Vector2i(0, 0), Vector2i(5, 5)):
		writes.append(HouseData.write(0, "floors", HouseGrid.cell_key(c), {"item": "floor_basic"}))
	house.apply(writes)
	writes = []
	for edge in HouseGrid.edges_around_rect(Vector2i(0, 0), Vector2i(5, 5)):
		writes.append(HouseData.write(0, "walls", edge, {"item": "wall_basic"}))
	house.apply(writes)
	return house


# --- 11. Contorno fino / normal / apagado ---

func _test_outline_modes() -> void:
	print("\n11) Contorno fino / normal / apagado")
	var keep_mode: String = Style.outline_mode
	_check(Style.OUTLINE_MODES == ["thin", "normal", "off"], "tres modos de contorno")
	_check(Style.outline_width_px("thin") < Style.outline_width_px("normal"), "fino es más delgado que normal")
	_check(Style.outline_width_px("off") == 0.0, "apagado = 0 píxeles")
	var mat: ShaderMaterial = Style.toon_material(Color("#123456"))
	Style.set_outline_mode("normal")
	_check(Style.outline_enabled and mat.next_pass != null, "normal: el material lleva contorno")
	var normal_px: float = (mat.next_pass as ShaderMaterial).get_shader_parameter("outline_px")
	Style.set_outline_mode("thin")
	var thin_px: float = (mat.next_pass as ShaderMaterial).get_shader_parameter("outline_px")
	_check(thin_px < normal_px, "fino: el grosor baja en los materiales ya creados (%.1f < %.1f)" % [thin_px, normal_px])
	Style.set_outline_mode("off")
	_check(not Style.outline_enabled and mat.next_pass == null, "apagado: el material no lleva contorno")
	Style.set_outline(true)
	_check(Style.outline_enabled and Style.outline_mode == "thin" and mat.next_pass != null, "set_outline(true) vuelve al modo de antes")
	_check(Style.mode_from_settings({"outline_mode": "normal"}) == "normal", "las opciones guardadas mandan")
	_check(Style.mode_from_settings({"outline_enabled": false}) == "off", "partida vieja con contorno apagado sigue apagada")
	_check(Style.mode_from_settings({"outline_enabled": true}) == "thin", "partida vieja con contorno prendido pasa al fino")
	_check(Style.mode_from_settings({}) == "thin", "sin opciones: fino")
	Style.set_outline_mode(keep_mode)


# --- 1. Caras interior / exterior ---

func _test_wall_faces() -> void:
	print("\n1) Pared: cara interior y exterior")
	var house := _box_house()
	# h:2,0 es la pared norte de la caja: el lado «a» mira al norte (afuera), el «b» al sur (adentro).
	_check(WallFaces.is_exterior(house, 0, "h:2,0", "a") and not WallFaces.is_exterior(house, 0, "h:2,0", "b"),
		"norte de la casa: «a» es de afuera, «b» de adentro")
	_check(WallFaces.resolve_scope(house, 0, "h:2,0", "a", "inside") == "b", "tocar afuera con «adentro» pinta la cara de adentro")
	_check(WallFaces.resolve_scope(house, 0, "h:2,0", "b", "outside") == "a", "tocar adentro con «afuera» pinta la de afuera")
	_check(WallFaces.resolve_scope(house, 0, "h:2,0", "a", "touch") == "a", "«cara tocada» no cambia nada")
	_check(WallFaces.resolve_scope(house, 0, "h:2,0", "b", "inside") == "b", "ya era la de adentro")
	# Pared entre dos cuartos: las dos son de adentro, queda la tocada.
	house.apply([HouseData.write(0, "walls", "v:3,2", {"item": "wall_basic"})])
	_check(WallFaces.resolve_scope(house, 0, "v:3,2", "a", "outside") == "a", "entre dos cuartos no hay cara de afuera")
	# Herencia de color: una pared nueva sigue el color de la vecina en línea.
	var wall: Dictionary = house.get_piece(0, "walls", "h:2,0").duplicate()
	wall["color_a"] = "#ff0000"
	house.apply([HouseData.write(0, "walls", "h:2,0", wall)])
	var inherited := WallFaces.inherited_colors(house, 0, "h:3,0")
	_check(inherited.get("color_a", "") == "#ff0000" and not inherited.has("color_b"), "la pared de al lado hereda el color de afuera")
	_check(WallFaces.inherited_colors(house, 0, "h:2,1").is_empty(), "sin vecina pintada en su línea no hereda nada")
	var pending := {"h:4,0": {"item": "wall_basic", "color_a": "#00ff00"}}
	_check(WallFaces.inherited_colors(house, 0, "h:5,0", pending).get("color_a", "") == "#00ff00",
		"también hereda de la pared del mismo gesto")
	# Pintar una cara no pinta la otra (datos).
	var painted: Dictionary = house.get_piece(0, "walls", "h:2,0")
	_check(painted.has("color_a") and not painted.has("color_b"), "pintar afuera no toca adentro")


# --- 1. La pared se arma con cuerpo neutro y láminas de pintura ---

func _test_wall_paint_pieces() -> void:
	print("\n1) Pared 3D: cuerpo neutro + láminas")
	var neutral: Color = HousePieces.wall_neutral_color({"item": "wall_basic"})
	_check(neutral == Color.from_string(Catalog.get_item("wall_basic")["color"], Color.WHITE), "el color neutro es el del catálogo")
	_check(HousePieces.wall_neutral_color({"item": "wall_basic", "color_a": "#ff0000", "color": "#00ff00"}) == neutral,
		"pintar no cambia el color neutro")
	var plain := HousePieces.build_wall("h:2,2", {"item": "wall_basic"}, HouseGrid.WALL_HEIGHT)
	_check(plain.get_child_count() == 1, "pared sin pintar: solo el cuerpo (%d)" % plain.get_child_count())
	plain.free()
	var one_face := HousePieces.build_wall("h:2,2", {"item": "wall_basic", "color_a": "#ff0000"}, HouseGrid.WALL_HEIGHT)
	_check(one_face.get_child_count() == 2, "una cara pintada: cuerpo + una lámina (%d)" % one_face.get_child_count())
	var core: MeshInstance3D = one_face.get_child(0)
	var plate: MeshInstance3D = one_face.get_child(1)
	_check(core.scale.z == HouseGrid.WALL_THICKNESS, "el cuerpo tiene el grosor entero de la pared")
	_check(plate.scale.z < 0.05 and absf(plate.position.z) > HouseGrid.WALL_THICKNESS / 2.0, "la lámina es finita y queda por fuera del cuerpo")
	var plate_top: float = plate.position.y + plate.scale.y / 2.0
	_check(plate_top < HouseGrid.WALL_HEIGHT - 0.01, "la lámina no llega arriba: el canto queda neutro")
	_check(((plate.material_override as ShaderMaterial).get_shader_parameter("albedo") as Color) == Color("#ff0000"), "la lámina lleva el color pintado")
	_check(((core.material_override as ShaderMaterial).get_shader_parameter("albedo") as Color) == neutral, "el cuerpo (y el canto) siguen neutros")
	one_face.free()
	var both := HousePieces.build_wall("h:2,2", {"item": "wall_basic", "color_a": "#ff0000", "color_b": "#0000ff"}, HouseGrid.WALL_HEIGHT)
	_check(both.get_child_count() == 3, "dos caras pintadas: cuerpo + dos láminas")
	var z_a: float = both.get_child(1).position.z
	var z_b: float = both.get_child(2).position.z
	_check(z_a < 0.0 and z_b > 0.0, "una lámina a cada lado")
	both.free()


# --- 2. Barra: título del menú y modo propio de Pintar ---

func _test_build_bar_titles() -> void:
	print("\n2) Barra: títulos y nombres")
	var bar := BuildBar.new()
	bar.tool = "shop"
	_check(bar.menu_title() == "Comprar", "Tienda se llama Comprar")
	bar.tool = "build"
	for mode in ["add", "modify", "paint", "rooms", "erase"]:
		bar.build_mode = mode
		_check(bar.menu_title() == BuildBar.MODE_TITLES[mode] and bar.menu_title() != "", "título del modo %s: %s" % [mode, bar.menu_title()])
	_check(BuildBar.MODE_TITLES["paint"] == "Pintar" and BuildBar.MODE_TITLES["modify"] == "Mover", "Pintar es su propio modo y Modificar se llama Mover")
	bar.tool = ""
	_check(bar.menu_title() == "", "sin herramienta no hay título")
	bar.free()
	_check(FileAccess.file_exists("res://assets/icons/dollar.svg") and FileAccess.file_exists("res://assets/icons/pencil.svg"),
		"existen los íconos de dólar y lápiz")
	var button := Button.new()
	button.tooltip_text = "  Comprar "
	_check(LongPressTip.text_for(button) == "Comprar", "el cartel usa el tooltip del botón")
	_check(LongPressTip.HOLD_SECONDS > 0.2 and LongPressTip.HOLD_SECONDS < 1.0, "mantener presionado: entre 0,2 y 1 s")
	button.free()


# --- 5. La cuadrícula solo dentro de la valla ---

func _test_grid_zone_mask() -> void:
	print("\n5) Cuadrícula: solo dentro de la valla")
	var cfg := ParcelRules.config()
	var rects := ParcelRules.zone_rects(cfg, 1)
	var mask := ParcelRules.zone_mask_image(rects, 96)
	_check(mask.get_width() == 96 and mask.get_height() == 96, "la máscara tiene una celda por píxel")
	# Con la parcela real (96) solo se usa el centro pegado a la calle; con la de pruebas (32) es toda.
	if int(cfg["lot"]) >= 96:
		var first: Array = rects[0]
		_check(mask.get_pixel(int(first[0]) + 1, int(first[1]) + 1).r > 0.5, "una celda dentro de la zona inicial es usable")
		_check(mask.get_pixel(0, 0).r < 0.5, "la esquina lejana (zona por desbloquear) no se cuadricula")
		var all_rects := ParcelRules.zone_rects(cfg, 99)
		var open_mask := ParcelRules.zone_mask_image(all_rects, 96)
		_check(open_mask.get_pixel(0, 0).r > 0.5 or all_rects.size() == 1, "al subir de nivel se abre más terreno")
	var small := ParcelRules.zone_mask_image([[2, 3, 4, 5]], 16)
	var white := 0
	for x in 16:
		for z in 16:
			if small.get_pixel(x, z).r > 0.5:
				white += 1
	_check(white == 20, "un rectángulo de 4x5 pinta 20 celdas (%d)" % white)
	_check(small.get_pixel(2, 3).r > 0.5 and small.get_pixel(5, 7).r > 0.5 and small.get_pixel(6, 7).r < 0.5 and small.get_pixel(5, 8).r < 0.5,
		"los bordes del rectángulo están justo")
	var clipped := ParcelRules.zone_mask_image([[14, 14, 10, 10]], 16)
	_check(clipped.get_pixel(15, 15).r > 0.5, "un rectángulo que se sale del lote se recorta sin romper")


# --- 6. Muebles afuera (outdoor en el catálogo) ---

func _test_outdoor_furniture() -> void:
	print("\n6) Muebles afuera")
	var open := HouseData.new()
	for id in ["table_basic", "plant_pot", "plant_tall", "lamp_floor", "vase_basic", "bench_garden"]:
		var item := Catalog.get_item(id)
		_check(not item.is_empty() and item.get("outdoor", false) == true, "%s está marcado outdoor en el catálogo" % id)
		var value := {"item": id, "cell": [10, 10], "rot": 0}
		_check(HouseRules.is_supported(open, 0, "objects", "x1", value), "%s se apoya en el pasto" % id)
		_check(not HouseRules.is_supported(open, 1, "objects", "x1", value), "%s arriba pide piso" % id)
	for id in ["sofa_basic", "bed_basic", "fridge_basic"]:
		_check(not HouseRules.is_supported(open, 0, "objects", "x2", {"item": id, "cell": [10, 10], "rot": 0}), "%s no va afuera" % id)
	for id in ["wall_basic", "door_basic", "window_basic"]:
		_check(Catalog.get_item(id).get("outdoor", false) != true, "%s sigue necesitando estructura" % id)
	# Dos muebles de afuera no se encima.
	open.apply([HouseData.write(0, "objects", "t1", {"item": "table_basic", "cell": [10, 10], "rot": 0})])
	_check(not HouseRules.is_supported(open, 0, "objects", "t2", {"item": "plant_pot", "cell": [11, 10], "rot": 0}), "afuera tampoco se encima")
	_check(HouseRules.is_supported(open, 0, "objects", "t3", {"item": "plant_pot", "cell": [12, 10], "rot": 0}), "pero al lado sí")


# --- 7. Mini menú de «mantener presionado un mueble» ---

func _test_quick_menu_logic() -> void:
	print("\n7) Mini menú al mantener presionado un mueble")
	var points := {"0|o1": Vector2(100, 100), "0|o2": Vector2(180, 100), "1|o3": Vector2(400, 400)}
	_check(FurnitureQuickMenu.nearest_key(points, Vector2(120, 100), 170.0) == "0|o1", "elige el mueble más cercano al dedo")
	_check(FurnitureQuickMenu.nearest_key(points, Vector2(170, 105), 170.0) == "0|o2", "y si el dedo está más cerca de otro, ese")
	_check(FurnitureQuickMenu.nearest_key(points, Vector2(800, 800), 170.0) == "", "lejos de todo: ninguno")
	_check(FurnitureQuickMenu.nearest_key({}, Vector2.ZERO, 170.0) == "", "sin muebles: ninguno")
	# Cámara de frente: el norte (-Z) sube en la pantalla.
	var front := {"N": Vector2(0, -40), "S": Vector2(0, 40), "E": Vector2(60, 0), "O": Vector2(-60, 0)}
	var map := FurnitureQuickMenu.screen_direction_map(front)
	_check(map == {"up": "N", "down": "S", "left": "O", "right": "E"}, "de frente: arriba = norte (%s)" % [map])
	# Cámara girada 90°: ahora el este sube en la pantalla.
	var turned := {"E": Vector2(0, -40), "O": Vector2(0, 40), "S": Vector2(60, 0), "N": Vector2(-60, 0)}
	map = FurnitureQuickMenu.screen_direction_map(turned)
	_check(map == {"up": "E", "down": "O", "left": "N", "right": "S"}, "girada: arriba = este (%s)" % [map])
	# En diagonal (isométrica) cada flecha igual se reparte sin repetir.
	var iso := {"N": Vector2(30, -20), "S": Vector2(-30, 20), "E": Vector2(30, 20), "O": Vector2(-30, -20)}
	map = FurnitureQuickMenu.screen_direction_map(iso)
	var used := {}
	for arrow in map:
		used[map[arrow]] = true
	_check(map.size() == 4 and used.size() == 4, "en diagonal no se repite ninguna dirección (%s)" % [map])
	_check(FurnitureQuickMenu.is_movable({"item": "chair_basic", "cell": [1, 1], "rot": 0}), "una silla se puede correr")
	_check(not FurnitureQuickMenu.is_movable({"item": "stairs_basic", "cell": [1, 1], "rot": 0}), "una escalera no")
	_check(not FurnitureQuickMenu.is_movable(null), "nada tampoco")
	var center := FurnitureQuickMenu.object_center(0, {"item": "table_basic", "cell": [4, 4], "rot": 0})
	_check(is_equal_approx(center.x, 5.0) and is_equal_approx(center.z, 4.5), "el centro de una mesa 2x1 está entre sus dos celdas (%s)" % [center])
	_check(FurnitureQuickMenu.HOLD_SECONDS > 0.3 and FurnitureQuickMenu.HOLD_SECONDS < 1.0, "mantener: entre 0,3 y 1 s")


# --- 10. Maqueta de pisos: bordes de arriba ---

func _test_floor_map_top_edges() -> void:
	print("\n10) Maqueta de pisos: borde de arriba sin «hueco»")
	var house := _box_house()
	# Un segundo piso más chico en la esquina (3x3) sobre el primero, sin techo.
	var writes: Array = []
	for c in HouseGrid.cells_in_rect(Vector2i(0, 0), Vector2i(2, 2)):
		writes.append(HouseData.write(1, "floors", HouseGrid.cell_key(c), {"item": "floor_basic"}))
	house.apply(writes)
	# Pared de afuera lejos del segundo piso: se ve desde arriba.
	_check(FloorMap.top_edge_exposed(house, 0, "h:4,0"), "la pared del primero que NO tiene el segundo encima muestra su borde")
	# Pared bajo el segundo piso: queda tapada.
	_check(not FloorMap.top_edge_exposed(house, 0, "h:1,0"), "la que tiene el segundo piso encima no")
	# Una pared del límite entre lo cubierto y lo libre: cubierta si UNA de sus celdas lo está.
	_check(not FloorMap.top_edge_exposed(house, 0, "v:3,1"), "en el límite del segundo piso, también tapada")
	# Con techo sobre una parte, solo esa parte se tapa.
	house.apply([HouseData.write(0, "roofs", "o1", {"item": "roof_flat", "rect": [3, 3, 3, 3]})])
	_check(not FloorMap.top_edge_exposed(house, 0, "h:4,5"), "bajo el techo no se ve")
	_check(FloorMap.top_edge_exposed(house, 0, "h:4,0"), "fuera del techo, sí (antes todo el piso se apagaba por tener un techo)")
