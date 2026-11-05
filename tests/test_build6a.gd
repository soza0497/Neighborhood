extends Node
## Pruebas del Pulido 6A (construcción y casa), sin pantalla.
##
## Correr desde la terminal, en la carpeta del proyecto:
##   godot --headless --path . res://tests/test_build6a.tscn
## Al final dice cuántas pruebas pasaron. Si alguna falla, dice cuál.
##
## Se va llenando por sub-fase: 6A-1 (contorno, pintura, íconos).

var _passed := 0
var _failed := 0


func _ready() -> void:
	HouseGrid.use_test_lot()
	_test_outline_modes()
	_test_wall_faces()
	_test_wall_paint_pieces()
	_test_build_bar_titles()
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
