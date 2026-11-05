extends Node
## Pruebas del Pulido 6A (construcción y casa), sin pantalla.
##
## Correr desde la terminal, en la carpeta del proyecto:
##   godot --headless --path . res://tests/test_build6a.tscn
## Al final dice cuántas pruebas pasaron. Si alguna falla, dice cuál.
##
## Se va llenando por sub-fase: 6A-1 (contorno, pintura, íconos), 6A-2 (cuadrícula, muebles
## afuera, mini menú, maqueta), 6A-3 (sótano, cimientos sobre obstáculos, mover la casa).

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
	_test_basement()
	_test_foundation_queue()
	_test_house_move()
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


# --- 3. Sótano: solo bajo la casa, guía y efecto hueco ---

func _test_basement() -> void:
	print("\n3) Sótano")
	var house := _box_house()
	var dig := {"item": "excavation_basic"}
	_check(HouseRules.is_supported(house, -1, "excavation", "2,2", dig), "se excava bajo la casa")
	_check(not HouseRules.is_supported(house, -1, "excavation", "12,12", dig), "no se excava donde no hay casa")
	house.apply([HouseData.write(-1, "excavation", "2,2", dig)])
	_check(HouseRules.is_supported(house, -2, "excavation", "2,2", dig), "el segundo sótano sigue sobre el primero")
	# La guía: la huella de la casa de arriba.
	var guide := BasementView.guide_cells(house, -1)
	_check(guide.size() == 36 and Vector2i(0, 0) in guide and Vector2i(5, 5) in guide and not Vector2i(6, 6) in guide,
		"la guía del sótano 1 es la huella de la casa (%d celdas)" % guide.size())
	var guide2 := BasementView.guide_cells(house, -2)
	_check(guide2 == [Vector2i(2, 2)], "la guía del sótano 2 es lo excavado arriba (%s)" % [guide2])
	_check(BasementView.guide_cells(house, 0).is_empty(), "en la planta baja no hay guía")
	# Efecto hueco: el sótano excavado en un rectángulo 4x3.
	var basement := HouseData.new()
	var writes: Array = []
	for c in HouseGrid.cells_in_rect(Vector2i(2, 2), Vector2i(5, 4)):
		writes.append(HouseData.write(-1, "excavation", HouseGrid.cell_key(c), dig))
		writes.append(HouseData.write(-1, "foundation", HouseGrid.cell_key(c), {"item": "foundation_basic"}))
	for edge in HouseGrid.edges_around_rect(Vector2i(2, 2), Vector2i(5, 4)):
		writes.append(HouseData.write(-1, "walls", edge, {"item": "wall_basic"}))
	basement.apply(writes)
	_check(HouseView.has_hole_cell(basement, -1, Vector2i(3, 3)) and not HouseView.has_hole_cell(basement, -1, Vector2i(9, 9)), "una celda excavada es parte del hoyo")
	# Cámara al sur (+Z) del hoyo: la pared sur es la del frente y la norte la del fondo.
	var to_cam := Vector2(0, 1)
	_check(HouseView.wall_is_front(basement, -1, "h:3,5", to_cam), "la pared sur (cara a la cámara) se esconde")
	_check(not HouseView.wall_is_front(basement, -1, "h:3,2", to_cam), "la pared norte (el fondo) se ve")
	_check(not HouseView.wall_is_front(basement, -1, "v:2,3", to_cam) and not HouseView.wall_is_front(basement, -1, "v:6,3", to_cam),
		"las de los lados (de perfil) se ven")
	# Cámara al este: la pared este es la del frente.
	_check(HouseView.wall_is_front(basement, -1, "v:6,3", Vector2(1, 0)) and not HouseView.wall_is_front(basement, -1, "v:2,3", Vector2(1, 0)),
		"mirando desde el este se esconde la pared este y se ve la oeste")
	_check(not HouseView.wall_is_front(basement, -1, "h:3,5", Vector2.ZERO), "mirando derecho hacia abajo no se esconde nada")
	# Una pared de adentro (entre dos celdas del hoyo) siempre se ve.
	basement.apply([HouseData.write(-1, "walls", "v:4,3", {"item": "wall_basic"})])
	_check(not HouseView.wall_is_front(basement, -1, "v:4,3", Vector2(1, 0)) and not HouseView.wall_is_front(basement, -1, "v:4,3", Vector2(-1, 0)),
		"una pared de adentro del hoyo siempre se ve")
	# Colores del sótano en el estilo.
	_check(Style.color("basement_bg", Color.MAGENTA) != Color.MAGENTA and Style.color("basement_ground", Color.MAGENTA) != Color.MAGENTA,
		"el estilo tiene los cafés oscuros del sótano")
	var bg: Color = Style.color("basement_bg")
	_check(bg.get_luminance() < 0.1, "el fondo del sótano es muy oscuro")


# --- 4. Cimientos sobre obstáculos ---

func _test_foundation_queue() -> void:
	print("\n4) Cimientos sobre obstáculos")
	var of := func(cell: Vector2i) -> String:
		if cell == Vector2i(5, 5) or cell == Vector2i(6, 5):
			return "r:5,5"  # Una roca de 2x1.
		if cell == Vector2i(9, 9):
			return "t:9,9"
		return ""
	var blocked: Array = [
		HouseData.write(0, "foundation", "5,5", {"item": "foundation_basic"}),
		HouseData.write(0, "foundation", "6,5", {"item": "foundation_basic"}),
		HouseData.write(0, "foundation", "9,9", {"item": "foundation_basic"}),
		HouseData.write(0, "foundation", "20,20", {"item": "foundation_basic"}),  # Zona cerrada: sin obstáculo.
		HouseData.write(0, "floors", "5,5", {"item": "floor_basic"}),
	]
	var split := FoundationQueue.split_blocked(blocked, of)
	_check(split["deferred"].keys().size() == 2 and split["deferred"]["r:5,5"].size() == 2 and split["deferred"]["t:9,9"].size() == 1,
		"los cimientos se agrupan por obstáculo (roca: 2, árbol: 1)")
	_check(split["impossible"].size() == 2, "lo que no es un obstáculo (zona cerrada) o no es un cimiento queda imposible")
	var cost := FoundationQueue.total_service_cost(["r:5,5", "t:9,9"], func(id: String) -> int: return 250 if id.begins_with("r") else 90)
	_check(cost == 340, "el costo suma los servicios (%d)" % cost)
	var queue := {"r:5,5": [blocked[0]], "t:9,9": [blocked[2]]}
	var found := FoundationQueue.ready_entries(queue, func(id: String) -> bool: return id == "t:9,9")
	_check(found["ready"].keys() == ["t:9,9"] and found["waiting"] == ["r:5,5"], "lo ya retirado se coloca; lo demás espera")
	_check(FoundationQueue.ready_entries({}, func(_id: String) -> bool: return true)["ready"].is_empty(), "una cola vacía no hace nada")
	_check(FoundationQueue.SETTINGS_KEY in CloudSync.LOCAL_ONLY_SETTINGS, "la cola es solo de este teléfono (no viaja al servidor)")
	var public_settings := CloudSync.public_settings({"pending_foundations": {"r:5,5": []}, "use_models": true})
	_check(not public_settings.has("pending_foundations") and public_settings.has("use_models"), "public_settings la saca")


# --- 8. Mover la casa ---

func _test_house_move() -> void:
	print("\n8) Mover la casa entera")
	var house := _box_house()
	house.apply([
		HouseData.write(0, "objects", "o1", {"item": "table_basic", "cell": [1, 1], "rot": 0}),
		HouseData.write(0, "roofs", "o2", {"item": "roof_flat", "rect": [0, 0, 6, 6]}),
	])
	var wall: Dictionary = house.get_piece(0, "walls", "h:2,0").duplicate()
	wall["color_a"] = "#ff0000"
	house.apply([HouseData.write(0, "walls", "h:2,0", wall)])
	var pieces := HouseMove.piece_count(house)
	_check(pieces == 36 + 36 + 24 + 1 + 1, "cuenta las piezas de todas las capas (%d)" % pieces)
	var cfg := HouseMove.config()
	_check(HouseMove.fee(house, Vector2i.ZERO) == 0, "no moverse no cuesta")
	_check(HouseMove.fee(house, Vector2i(3, 0)) == int(cfg["base"]) + int(cfg["per_piece"]) * pieces + int(cfg["per_step"]) * 3, "la mudanza cuesta base + piezas + distancia")
	_check(HouseMove.fee(house, Vector2i(5, -2)) == int(cfg["base"]) + int(cfg["per_piece"]) * pieces + int(cfg["per_step"]) * 7, "la distancia suma X y Z")
	_check(HouseMove.fee(house, Vector2i(5000, 5000)) <= int(cfg["max"]), "tiene tope")
	_check(HouseMove.fee(HouseData.new(), Vector2i(3, 0)) == 0, "una casa vacía no cuesta")
	var box := HouseMove.footprint(house)
	_check(box.position == Vector2i(0, 0) and box.size.x >= 6 and box.size.y >= 6, "el rectángulo de la casa (%s)" % [box])
	var template := HouseMove.as_template(house)
	_check(not template.is_empty() and template["move"] == true and (template["pieces"] as Array).size() == pieces, "la silueta lleva todas las piezas, también los muebles")
	var has_furniture := false
	for piece in template["pieces"]:
		if piece["y"] == "objects":
			has_furniture = true
	_check(has_furniture, "los muebles viajan en la mudanza")
	# Mudarla 10 a la derecha y 4 abajo.
	var delta := Vector2i(10, 4)
	var check := HouseMove.check(house, delta)
	_check(check["valid"] and check["fee"] == HouseMove.fee(house, delta), "10 a la derecha y 4 abajo cabe (%s)" % check.get("reason", ""))
	var moved := house.duplicate_data()
	moved.apply(check["writes"])
	_check(HouseMove.piece_count(moved) == pieces, "no se pierde ninguna pieza")
	_check(moved.has_piece(0, "foundation", "12,4") and not moved.has_piece(0, "foundation", "2,0") and moved.has_piece(0, "foundation", "10,4"),
		"los cimientos se corrieron")
	_check(moved.has_piece(0, "walls", "h:12,4") and (moved.get_piece(0, "walls", "h:12,4") as Dictionary).get("color_a", "") == "#ff0000", "las paredes llevan su pintura")
	var table: Dictionary = moved.get_piece(0, "objects", "o1")
	_check(table["cell"] == [11, 5], "el mueble se corrió igual (%s)" % [table["cell"]])
	_check(moved.get_piece(0, "roofs", "o2")["rect"] == [10, 4, 6, 6], "el techo también")
	_check(moved.next_id == house.next_id, "los nombres de objetos siguen")
	# Deshacer con las escrituras inversas deja todo como estaba.
	var inverse := house.duplicate_data()
	var undo_writes := inverse.apply(check["writes"])
	inverse.apply(undo_writes)
	_check(inverse.has_piece(0, "foundation", "2,0") and not inverse.has_piece(0, "foundation", "12,4"), "deshacer vuelve la casa a su lugar")
	# Lugares que no sirven.
	_check(HouseMove.check(house, Vector2i.ZERO)["reason"] == "same", "al mismo lugar: no")
	_check(HouseMove.check(house, Vector2i(-3, 0))["reason"] == "outside", "fuera del lote (izquierda)")
	_check(HouseMove.check(house, Vector2i(HouseGrid.LOT_SIZE.x, 0))["reason"] == "outside", "fuera del lote (derecha)")
	_check(HouseMove.check(HouseData.new(), Vector2i(3, 0))["reason"] == "empty", "sin casa: no hay qué mudar")
	HouseData.blocked_cells = {"12,5": "t:12,5"}
	_check(HouseMove.check(house, delta)["reason"] == "blocked", "un árbol en el destino la bloquea")
	HouseData.blocked_cells = {}
	# Con un sótano debajo, también viaja.
	house.apply([HouseData.write(-1, "excavation", "2,2", {"item": "excavation_basic"})])
	var with_basement := HouseMove.check(house, delta)
	_check(with_basement["valid"], "una casa con sótano se muda entera (%s)" % with_basement.get("reason", ""))
	var moved2 := house.duplicate_data()
	moved2.apply(with_basement["writes"])
	_check(moved2.has_piece(-1, "excavation", "12,6"), "el sótano se mueve con la casa")
	# Los tipos de cuarto viajan.
	house.room_types = {"0:3,3": "bedroom"}
	house.main_bedroom_cell = "0:3,3"
	house.shift_room_data(delta)
	_check(house.room_types.has("0:13,7") and house.main_bedroom_cell == "0:13,7", "los tipos de cuarto se corren con la casa")
