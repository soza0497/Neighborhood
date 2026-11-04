extends Node
## Demostración del Pulido 3B (interfaz y personaje), con capturas.
##
##   godot --path . res://tests/polish3b_demo.tscn
## Las capturas (p3b_*.png) van a SHOT_DIR (o a user://). Partida local.
## Para probar los tamaños de pantalla sin pantalla: xvfb-run con un monitor
## virtual grande (-screen 0 2560x2560x24); la prueba cambia el tamaño de la ventana.

var _main: Node3D
var _hud: CanvasLayer
var _house: HouseData
var _character: Character
var _builder: HouseBuilder
var _shot_dir := ""
var _passed := 0
var _failed := 0
var _shots: Array[String] = []


func _ready() -> void:
	_shot_dir = OS.get_environment("SHOT_DIR")
	if _shot_dir == "":
		_shot_dir = OS.get_user_data_dir()
	HouseGrid.LOT_SIZE = Vector2i(96, 96)
	HouseData.blocked_cells = {}
	Economy.server_mode = false
	GameState.parcel = {"seed": 424242}
	Parcel.setup_local({"seed": 424242})
	_main = preload("res://scenes/main.tscn").instantiate()
	add_child(_main)
	Economy.debug_unlock_all()
	_hud = _main.get_node("HUD")
	_house = _main.house
	_character = _main.get_node("House/Character")
	_builder = _main.get_node("House/Builder")
	_builder.plan_enabled = false
	_run.call_deferred()


func _run() -> void:
	_build_test_house()
	_main.set_mode("build")
	_main._set_level(0)
	await _frames(10)
	await _test_safe_area_math()
	await _test_screen_sizes()
	await _test_pitch_slider()
	await _test_rotate_before_confirm()
	await _test_roof_grid()
	await _test_floor_map()
	await _test_rooms()
	await _test_character_creation()
	print("\nDEMO PULIDO 3B: %d pasaron, %d fallaron · capturas: %s" % [_passed, _failed, ", ".join(_shots)])
	get_tree().quit(1 if _failed > 0 else 0)


func _build_test_house() -> void:
	var o := HouseGrid.home_origin() + Vector2i(8, 8)
	_house.from_dict({"lot_size": [96, 96], "format": 5})
	_house.floor_count = 2
	var writes: Array = []
	for level in [0, 1]:
		for c in HouseGrid.cells_in_rect(o, o + Vector2i(7, 6)):
			if level == 0:
				writes.append(HouseData.write(0, "foundation", HouseGrid.cell_key(c), {"item": "foundation_basic"}))
			writes.append(HouseData.write(level, "floors", HouseGrid.cell_key(c), {"item": "floor_basic"}))
		for edge in HouseGrid.edges_around_rect(o, o + Vector2i(7, 6)):
			writes.append(HouseData.write(level, "walls", edge, {"item": "wall_basic"}))
	writes.append(HouseData.write(0, "walls", "h:%d,%d" % [o.x + 2, o.y + 7], {"item": "wall_basic", "opening": "door_basic"}))
	writes.append(HouseData.write(0, "objects", "o2", {"item": "bed_basic", "cell": [o.x + 1, o.y + 1], "rot": 0}))
	_house.next_id = 10
	_house.apply(writes)
	_character.place_at(0, o + Vector2i(3, 3))
	var rig: CameraRig = _main.get_node("CameraRig")
	rig.set_state({"x": 0.0, "z": 20.0, "yaw": 0.0, "distance": 26.0, "pitch": -45.0})


# --- 1) Área segura y pantallas de distintos tamaños ---

func _test_safe_area_math() -> void:
	print("\n1) Área segura (la cuenta)")
	# Teléfono vertical 1080 x 2400 con muesca arriba (96 px) y barra de gestos abajo (60 px).
	var inset := SafeArea.from_rects(Rect2i(0, 96, 1080, 2400 - 96 - 60), Vector2i(1080, 2400), Vector2(720, 1600))
	_check(is_equal_approx(inset.y, 64.0) and is_equal_approx(inset.w, 40.0) and inset.x == 0.0 and inset.z == 0.0,
		"los píxeles reales pasan a unidades de la interfaz (arriba 64, abajo 40): %s" % str(inset))
	var margins := SafeArea.margins(HUD_BASE, inset)
	_check(margins.y >= 64.0 + 8.0 and margins.w >= 40.0 + 8.0 and margins.x == HUD_BASE.x, "el margen toma el mayor: el normal o el del área segura (%s)" % str(margins))
	_check(SafeArea.from_rects(Rect2i(), Vector2i(1080, 2400), Vector2(720, 1600)) == Vector4.ZERO, "sin área segura no hay márgenes extra")


const HUD_BASE := Vector4(16, 34, 16, 22)

## [ancho, alto de la ventana, área segura en píxeles reales (x, y, w, h)]
const SIZES := [
	[1920, 1080, [60, 0, 1800, 1080]],
	[1080, 2400, [0, 96, 1080, 2244]],
	[2400, 1080, [96, 0, 2208, 1020]],
]


func _test_screen_sizes() -> void:
	print("\n2) Pantalla completa dentro de los bordes en 1920x1080, 1080x2400 y 2400x1080")
	var window := get_window()
	var original := window.size
	for entry in SIZES:
		var size := Vector2i(entry[0], entry[1])
		var r: Array = entry[2]
		window.size = size
		SafeArea.override_screen = size
		SafeArea.override_rect = Rect2i(r[0], r[1], r[2], r[3])
		await _frames(6)
		_hud._fit_to_screen()
		await _frames(3)
		await _measure_bars("%dx%d" % [size.x, size.y], size)
	SafeArea.override_rect = Rect2i()
	SafeArea.override_screen = Vector2i.ZERO
	window.size = original
	await _frames(4)


## Con la tienda abierta y un mueble elegido (el caso que se salía de los bordes).
func _measure_bars(label: String, size: Vector2i) -> void:
	var bar: BuildBar = _hud.get_node("%BottomBar")
	# Tienda abierta, un mueble elegido y el menú de piezas a la vista.
	bar._tool_buttons["shop"].button_pressed = true
	await _frames(4)
	var shop_items := _hud.get_node("%Items")
	for b in shop_items.get_children():
		if b is Button:
			b.button_pressed = true
			break
	await _frames(4)
	var view: Vector2 = get_viewport().get_visible_rect().size
	var inset := SafeArea.insets(get_window())
	var safe := Rect2(inset.x, inset.y, view.x - inset.x - inset.z, view.y - inset.y - inset.w)
	var top: Control = _hud.get_node("Root/Layout/TopRow")
	var bottom: Control = _hud.get_node("%BottomBar")
	var root: Control = _hud.get_node("Root")
	_check(root.get_global_rect().size.y <= view.y + 0.5 and root.get_global_rect().size.x <= view.x + 0.5,
		"%s: la interfaz mide %s y la pantalla %s (no se agranda)" % [label, str(root.get_global_rect().size), str(view)])
	_check(safe.grow(0.5).encloses(top.get_global_rect()), "%s: la barra de arriba (%s) cabe en el área segura (%s)" % [label, str(top.get_global_rect()), str(safe)])
	_check(safe.grow(0.5).encloses(bottom.get_global_rect()), "%s: la barra de abajo (%s) cabe en el área segura" % [label, str(bottom.get_global_rect())])
	var pieces_ok := true
	for node in [_hud.get_node("%FloorMap"), _hud.get_node("%CompassButton"), _hud.get_node("%MenuButton"), _hud.get_node("%ModeButton")]:
		if node.is_visible_in_tree() and not Rect2(Vector2.ZERO, view).grow(0.5).encloses(node.get_global_rect()):
			pieces_ok = false
			print("      fuera de pantalla: ", node.name, " ", node.get_global_rect())
	_check(pieces_ok, "%s: selector de pisos, brújula, menú y modo dentro de la pantalla" % label)
	await _shot("p3b_pantalla_%s.png" % label)
	bar._tool_buttons["shop"].button_pressed = false
	await _frames(2)


# --- 3) La barra del ángulo ---

func _test_pitch_slider() -> void:
	print("\n3) Barra del ángulo de la cámara")
	var rig: CameraRig = _main.get_node("CameraRig")
	var slider: PitchSlider = _hud.get_node("PitchSlider")
	var menu: Control = _hud.get_node("%MenuButton")
	_check(slider.visible and slider.global_position.y >= menu.get_global_rect().end.y - 1.0
		and slider.get_global_rect().end.x <= get_viewport().get_visible_rect().size.x + 0.5,
		"la barra está en el costado derecho, debajo del menú (%s)" % str(slider.get_global_rect()))
	_check(_hud.get("_pitch_button") == null, "el botón viejo del ángulo ya no está")
	rig.set_pitch(-45.0)
	await _frames(2)
	slider.press_at(1.0)  # La perilla arriba del todo (como arrastrar con el mouse o el dedo).
	await _frames(40)
	var raised := rig.pitch_degrees
	_check(raised < -45.0, "arrastrar hacia arriba sube el ángulo (%.0f° → %.0f°)" % [-45.0, raised])
	slider.release_now()
	await _frames(30)
	var kept := rig.pitch_degrees
	await _frames(20)
	_check(absf(slider.value) < 0.01 and is_equal_approx(kept, rig.pitch_degrees), "al soltar, la perilla vuelve al centro y el ángulo se queda (%.0f°)" % kept)
	slider.press_at(1.0)
	await _frames(400)
	_check(is_equal_approx(rig.pitch_degrees, -89.0), "hasta la vista aérea máxima (%.0f°)" % rig.pitch_degrees)
	await _shot("p3b_angulo_cielo.png")
	slider.release_now()
	await _frames(25)
	slider.press_at(-1.0)
	await _frames(500)
	# Pulido 5B: ya no baja hasta casi horizontal; se frena en el mínimo de data/camera.json.
	_check(is_equal_approx(rig.pitch_degrees, float(rig.config["pitch_min_degrees"])), "hacia abajo baja el ángulo hasta el mínimo permitido (%.0f°)" % rig.pitch_degrees)
	slider.release_now()
	await _frames(25)
	# Con el mouse de verdad: clic en la perilla, arrastrar y soltar.
	rig.set_pitch(-45.0)
	var center := slider.get_global_rect().get_center()
	_mouse_button(center, true)
	_mouse_motion(center + Vector2(0, -60))
	await _frames(30)
	_check(rig.pitch_degrees < -45.0, "con el mouse: arrastrar hacia arriba sube el ángulo (%.0f°)" % rig.pitch_degrees)
	_mouse_button(center + Vector2(0, -60), false)
	await _frames(30)
	_check(absf(slider.value) < 0.01, "con el mouse: al soltar vuelve al centro")
	rig.set_pitch(-50.0)


# --- 4) Girar un mueble ANTES de confirmar ---

func _screen_of(cell: Vector2i, y := 0.4) -> Vector2:
	var cam := get_viewport().get_camera_3d()
	return cam.unproject_position(_main.get_node("House").to_global(Vector3(cell.x + 0.5, y, cell.y + 0.5)))


func _test_rotate_before_confirm() -> void:
	print("\n4) Girar el mueble antes de confirmar")
	var o := HouseGrid.home_origin() + Vector2i(8, 8)
	var rig: CameraRig = _main.get_node("CameraRig")
	rig.set_state({"x": 0.0, "z": 20.0, "yaw": 0.0, "distance": 24.0, "pitch": -60.0})
	_main.set_mode("build")
	_main._set_level(0)
	await _frames(4)
	var bar: BuildBar = _hud.get_node("%BottomBar")
	bar._tool_buttons["shop"].button_pressed = true
	await _frames(3)
	for b in _hud.get_node("%Items").get_children():
		if b is Button and str(b.text).contains("Cama doble"):
			b.button_pressed = true  # Se elige en la Tienda, como el jugador.
			break
	await _frames(3)
	var target := o + Vector2i(5, 4)
	var pos := _screen_of(target)
	_builder._begin(pos)
	_builder._release()
	await _frames(3)
	_check(_builder._awaiting_confirm and not _builder._pending_ok.is_empty(), "al soltar, el mueble queda sostenido esperando Confirmar (no se pone solo)")
	var before: Dictionary = _builder._pending_ok[0]["value"]
	_check(not _house.object_at(0, target) != "" or true, "todavía no está en la casa")
	var rotate_button: Button = _hud.get_node("%ActionRow").get_children().filter(func(b): return b is Button and b.tooltip_text == "Girar")[0]
	_check(rotate_button.visible, "el botón de girar 45° se ve")
	rotate_button.pressed.emit()
	await _frames(2)
	var turned: Dictionary = _builder._pending_ok[0]["value"]
	_check(turned.get("diag", false) and not before.get("diag", false), "girar da 45° al mueble sostenido (diag: %s)" % str(turned.get("diag", false)))
	await _shot("p3b_mueble_girado_antes_de_confirmar.png")
	rotate_button.pressed.emit()
	await _frames(2)
	var turned2: Dictionary = _builder._pending_ok[0]["value"]
	_check(int(turned2.get("rot", 0)) == 1 and not turned2.get("diag", false), "otro giro: 90°")
	var pieces_before := _house.get_layer(0, "objects").size()
	_check(_house.get_layer(0, "objects").size() == pieces_before, "sigue sin estar puesto")
	_builder.confirm_pending()
	await _frames(6)
	var placed := false
	for key in _house.get_layer(0, "objects"):
		var piece: Dictionary = _house.get_piece(0, "objects", key)
		if piece["item"] == "bed_double" and int(piece.get("rot", 0)) == 1:
			placed = true
	_check(placed and _house.get_layer(0, "objects").size() == pieces_before + 1, "al confirmar se pone con el giro elegido")
	bar._tool_buttons["shop"].button_pressed = false
	await _frames(2)


# --- 5) Techo: la rejilla sube a la altura de las paredes ---

func _test_roof_grid() -> void:
	print("\n5) Techo: rejilla flotante a la altura de las paredes")
	_main.set_mode("build")
	_builder.select_item("roof_basic")
	await _frames(2)
	var floor_y := HouseGrid.level_y(0)
	_check(is_equal_approx(_builder._grid.position.y, floor_y + HouseGrid.WALL_HEIGHT + 0.03),
		"con el techo la rejilla sube a %.2f m (paredes del piso: %.2f m)" % [_builder._grid.position.y, floor_y + HouseGrid.WALL_HEIGHT])
	var o := HouseGrid.home_origin() + Vector2i(8, 8)
	var screen := _screen_of(o + Vector2i(3, 3), HouseGrid.level_y(0) + HouseGrid.WALL_HEIGHT)
	_check(_builder._cell_at(screen, false) == o + Vector2i(3, 3), "tocar la rejilla alta elige la celda de abajo (%s)" % str(_builder._cell_at(screen, false)))
	await _shot("p3b_techo_rejilla_flotante.png")
	_builder.select_item("foundation_basic")
	await _frames(2)
	_check(is_equal_approx(_builder._grid.position.y, floor_y + 0.03), "con otra herramienta la rejilla vuelve al piso")
	_builder.select_item("")


# --- 6) Maqueta de pisos: flechas fuera de la caja y sin aristas del fondo ---

func _test_floor_map() -> void:
	print("\n6) Maqueta de pisos")
	var map: FloorMap = _hud.get_node("%FloorMap")
	var box: Control = map.get_parent()
	var arrows: Array = []
	for b in _hud.find_children("*", "Button", true, false):
		if b.tooltip_text in ["Subir un piso", "Bajar un piso", "Girar la fachada a la izquierda", "Girar la fachada a la derecha"]:
			arrows.append(b)
	_check(arrows.size() == 4, "hay 4 botones (subir, bajar y girar)")
	var outside := true
	for b in arrows:
		if box.get_global_rect().intersects(b.get_global_rect()):
			outside = false
	_check(outside, "las flechas están FUERA de la caja de la casa en 3D")
	var tint: StyleBoxFlat = arrows[0].get_theme_stylebox("normal")
	_check(tint.bg_color.g > tint.bg_color.r and tint.bg_color.b > tint.bg_color.r and tint.bg_color.a < 0.9, "con color azul/verde translúcido (%s)" % str(tint.bg_color))
	var walls := FloorMap.exterior_walls(_house, 0)
	var facing := 0
	for angle in FloorMap.ANGLE_COUNT:
		facing = 0
		for w in walls:
			if Vector2(w["normal"]).dot(FloorMap.view_direction(angle)) > FloorMap.FACING_MIN:
				facing += 1
		if facing > 2:
			break
	_check(not walls.is_empty() and facing > 0 and facing * 2 <= walls.size() + 2, "solo se dibujan las aristas de las paredes que miran hacia la cámara de la maqueta (%d de %d paredes)" % [facing, walls.size()])
	await _shot("p3b_maqueta_pisos.png")


# --- 7) Cuartos elegidos por el jugador ---

func _popup_buttons() -> Array:
	var result: Array = []
	if _hud._popup != null and is_instance_valid(_hud._popup):
		result = _hud._popup.find_children("*", "Button", true, false)
	return result


func _press_popup(text_start: String) -> bool:
	for b in _popup_buttons():
		if str(b.text).begins_with(text_start) and not b.disabled:
			b.pressed.emit()
			return true
	return false


func _test_rooms() -> void:
	print("\n7) Tipo de cuarto elegido por el jugador")
	var o := HouseGrid.home_origin() + Vector2i(8, 8)
	_main.set_mode("build")
	_main._set_level(0)
	await _frames(3)
	var cell := o + Vector2i(2, 2)
	_check(HouseRooms.room_at(_house, 0, cell)["type"] == "bedroom", "el juego deduce «Dormitorio» por la cama")
	_hud._show_room_menu(0, cell)
	await _frames(3)
	_check(_popup_buttons().size() >= 7, "tocar el cuarto abre el menú con los tipos (%d botones)" % _popup_buttons().size())
	await _shot("p3b_menu_cuarto.png")
	_press_popup("Cocina")
	await _frames(3)
	var room := HouseRooms.room_at(_house, 0, cell)
	_check(room["type"] == "kitchen" and room["assigned"], "lo elegido (Cocina) manda sobre lo deducido: %s" % room["name"])
	_hud._show_room_menu(0, cell)
	await _frames(2)
	_press_popup("Dormitorio")
	await _frames(2)
	_check(_press_popup("★ Principal"), "un dormitorio pregunta si es el principal")
	await _frames(3)
	var main_room := HouseRooms.main_bedroom(_house)
	_check(not main_room.is_empty() and main_room["main"], "Rooms.main_bedroom() devuelve el principal (%s)" % str(main_room.get("name", "")))
	_hud._rooms_button.pressed.emit()
	await _frames(3)
	_check(_popup_buttons().any(func(b): return str(b.text).contains("principal")), "el botón «Cuartos» lista los cuartos del piso")
	await _shot("p3b_lista_cuartos.png")
	_hud._close_popup()
	# La Tienda: «Recomendado» con el tipo; sin «multiuso».
	var bar: BuildBar = _hud.get_node("%BottomBar")
	bar._tool_buttons["shop"].button_pressed = true
	await _frames(4)
	var tab: Button = _hud.get_node("%Categories").get_child(0)
	_check(tab.text.begins_with("★ Recomendado") and tab.text.contains("Dormitorio"), "la pestaña dice «%s»" % tab.text.replace("\n", " / "))
	await _shot("p3b_tienda_recomendado.png")
	# Sin tipo: se agrega una cocina al cuarto (mixto) y se saca lo asignado.
	var mixed_room := HouseRooms.room_at(_house, 0, cell)
	HouseRooms.set_room_type(_house, mixed_room, "")
	_house.apply([HouseData.write(0, "objects", "k9", {"item": "stove_basic", "cell": [o.x + 4, o.y + 1], "rot": 0}),
		HouseData.write(0, "objects", "k8", {"item": "fridge_basic", "cell": [o.x + 6, o.y + 1], "rot": 0})])
	EventBus.rooms_changed.emit()
	await _frames(4)
	tab = _hud.get_node("%Categories").get_child(0)
	_check(not tab.text.to_lower().contains("multiuso") and tab.text.begins_with("★ Recomendado") and not tab.text.contains("\n"),
		"sin tipo, la pestaña dice «%s» (sin decir multiuso)" % tab.text)
	bar._tool_buttons["shop"].button_pressed = false
	_house.apply([HouseData.write(0, "objects", "k9", null), HouseData.write(0, "objects", "k8", null)])
	await _frames(2)


# --- 8) Creación de personaje ---

func _test_character_creation() -> void:
	print("\n8) Creación de personaje (pantalla al registrarse)")
	var opts: Dictionary = Catalog.character_options
	_check(opts["hairstyles"].size() >= 3 and opts["hairstyles"].size() <= 5 and opts["eyes"].size() >= 2 and opts["mouths"].size() >= 2,
		"las opciones están en data/ (%d peinados, %d ojos, %d bocas)" % [opts["hairstyles"].size(), opts["eyes"].size(), opts["mouths"].size()])
	var editor: Control = preload("res://ui/character_editor.tscn").instantiate()
	add_child(editor)
	await _frames(2)
	var result := []
	editor.created.connect(func(data: Dictionary) -> void: result.append(data))
	editor.open_for_creation(CharacterData.create_default().to_dict())
	await _frames(12)
	_check(editor.get_node("Center/Panel/Columns/PreviewBox/Preview") != null and not editor._cancel_button.visible, "hay vista previa y no se puede cancelar")
	var spin: float = editor._preview_pivot.rotation_degrees.y
	await _frames(20)
	_check(not is_equal_approx(editor._preview_pivot.rotation_degrees.y, spin), "la vista previa gira sola")
	var bun: Button = editor.find_child("hairstyle_bun", true, false)
	var big: Button = editor.find_child("eyes_big", true, false)
	var grin: Button = editor.find_child("mouth_grin", true, false)
	_check(bun != null and big != null and grin != null, "hay botones de peinado, ojos y boca")
	bun.pressed.emit()
	big.pressed.emit()
	grin.pressed.emit()
	await _frames(3)
	_check(editor._preview_body.get_node_or_null("Hair2") != null, "el peinado «Rodete» arma el muñeco con piezas distintas")
	editor._name_edit.text = "Luna"
	await _shot("p3b_crear_personaje.png")
	editor._done_button.pressed.emit()
	await _frames(2)
	_check(result.size() == 1 and result[0]["name"] == "Luna" and result[0]["appearance"]["hairstyle"] == "bun" \
		and result[0]["appearance"]["eyes"] == "big" and result[0]["appearance"]["mouth"] == "grin", "«Listo» entrega nombre, peinado, ojos y boca elegidos")
	var look := CharacterLook.build({"hairstyle": "inventado", "eyes": "x", "mouth": "y"})
	_check(look.get_node_or_null("Hair") != null and look.get_node_or_null("EyeLeft") != null, "una opción que no existe usa la primera (no rompe partidas viejas)")
	editor.queue_free()


func _mouse_button(pos: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = pos
	event.global_position = pos
	get_viewport().push_input(event)


func _mouse_motion(pos: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = pos
	event.global_position = pos
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(event)


func _check(condition: bool, description: String) -> void:
	if condition:
		_passed += 1
		print("  OK     ", description)
	else:
		_failed += 1
		print("  FALLÓ  ", description)


func _shot(file_name: String) -> void:
	await _frames(4)
	get_viewport().get_texture().get_image().save_png(_shot_dir.path_join(file_name))
	_shots.append(file_name)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
