class_name FurnitureQuickMenu
extends CanvasLayer
## Pulido 6A (7): MANTENER PRESIONADO un mueble (en modo vivir) abre un mini menú con
## flechas alrededor para correrlo por la cuadrícula y un botón para girarlo, sin entrar al
## menú de construcción. El juego elige el mueble MÁS CERCANO al dedo (no hace falta
## acertarle justo). Las flechas son de la pantalla (arriba, abajo, izquierda, derecha) y
## se traducen a norte/sur/este/oeste según hacia dónde mira la cámara.
##
## No consume los toques (la cámara sigue andando igual): solo mira cuánto tiempo se
## mantuvo el dedo quieto. Los cálculos de "cuál mueble" y "qué flecha es qué dirección"
## son funciones sin 3D (se prueban sin pantalla).

## Segundos que hay que mantener el dedo quieto.
const HOLD_SECONDS := 0.55
## Cuánto se puede mover el dedo antes de que ya no cuente como «mantener».
const HOLD_MOVE_PIXELS := 14.0
## A cuántos píxeles del dedo puede estar el mueble para que se elija.
const PICK_RADIUS := 170.0
## Tamaño de los botones y separación de la cruz.
const BUTTON_SIZE := 72
const CROSS_RADIUS := 92.0
## Segundos sin tocar el menú para que se cierre solo.
const IDLE_SECONDS := 8.0
## Margen contra el borde de la pantalla (para no taparse con el borde).
const SCREEN_MARGIN := 110.0

## Se activa solo en modo vivir.
var active := false
var builder: HouseBuilder
var view: HouseView
var house: HouseData

var _pressing := false
var _press_pos := Vector2.ZERO
var _press_time := 0.0
var _root: Control
var _target_level := 0
var _target_key := ""
var _screen_map: Dictionary = {}
var _idle := 0.0
var _busy := false


func _ready() -> void:
	layer = 6
	_root = Control.new()
	_root.name = "Root"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_root.visible = false


func setup(new_builder: HouseBuilder, new_view: HouseView, new_house: HouseData) -> void:
	builder = new_builder
	view = new_view
	house = new_house


## ¿Está abierto el mini menú?
func is_open() -> bool:
	return _root != null and _root.visible


## Cierra el menú.
func close() -> void:
	if _root == null:
		return
	_root.visible = false
	_target_key = ""
	for child in _root.get_children():
		child.queue_free()


func set_active(value: bool) -> void:
	active = value
	_pressing = false
	if not value:
		close()


# --- Entrada (no consume nada) ---

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventScreenTouch:
		if event.index != 0:
			_pressing = false  # Dos dedos: es la cámara.
			return
		_on_press(event.position, event.pressed)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		_on_press(event.position, event.pressed)
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and _pressing:
		if event.position.distance_to(_press_pos) > HOLD_MOVE_PIXELS:
			_pressing = false  # Movió el dedo: es arrastrar la cámara.


func _on_press(position_2d: Vector2, pressed: bool) -> void:
	if pressed:
		_pressing = true
		_press_pos = position_2d
		_press_time = Time.get_ticks_msec() / 1000.0
		if is_open():
			close()  # Tocar el mundo cierra el menú anterior.
	else:
		_pressing = false


func _process(delta: float) -> void:
	if not active:
		return
	if _pressing and Time.get_ticks_msec() / 1000.0 - _press_time >= HOLD_SECONDS:
		_pressing = false
		open_at(_press_pos)
	if is_open():
		_idle += delta
		if _idle > IDLE_SECONDS or not house.has_piece(_target_level, "objects", _target_key):
			close()
			return
		_place_buttons()


# --- Elegir el mueble ---

## Abre el menú para el mueble más cercano a `screen_pos`. Devuelve true si había uno.
func open_at(screen_pos: Vector2) -> bool:
	var found := find_target(screen_pos)
	if found.is_empty():
		return false
	_target_level = found["level"]
	_target_key = found["key"]
	_build_buttons()
	_idle = 0.0
	_root.visible = true
	_place_buttons()
	return true


## El mueble que mejor responde a un dedo en `screen_pos`: {level, key} o {}.
## Primero el que está justo bajo el dedo; si no, el más cercano dentro del radio.
func find_target(screen_pos: Vector2) -> Dictionary:
	var cam := get_viewport().get_camera_3d()
	if cam == null or view == null:
		return {}
	var origin := view.to_local(cam.project_ray_origin(screen_pos))
	var direction := view.global_transform.basis.inverse() * cam.project_ray_normal(screen_pos)
	for level in range(view.top_visible_level, HouseGrid.MIN_LEVEL - 1, -1):
		var hit := view.pick_object(origin, direction, level)
		if hit != "" and is_movable(house.get_piece(level, "objects", hit)):
			return {"level": level, "key": hit}
	var points := {}
	for level in range(mini(view.top_visible_level, HouseGrid.MAX_LEVELS - 1), HouseGrid.MIN_LEVEL - 1, -1):
		for key in house.get_layer(level, "objects"):
			var value: Dictionary = house.get_piece(level, "objects", key)
			if not is_movable(value):
				continue
			var world := view.to_global(object_center(level, value))
			if cam.is_position_behind(world):
				continue
			points["%d|%s" % [level, key]] = cam.unproject_position(world)
	var best := nearest_key(points, screen_pos, PICK_RADIUS)
	if best == "":
		return {}
	var parts := best.split("|")
	return {"level": int(parts[0]), "key": parts[1]}


## Los muebles se pueden correr; escaleras y pilares son estructura (no).
static func is_movable(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	return Catalog.get_item((value as Dictionary).get("item", "")).get("kind", "") == "furniture" \
		and not HouseData.is_under_construction(value)


## Centro de un mueble en el mundo de la casa (a media altura).
static func object_center(level: int, value: Dictionary) -> Vector3:
	var cells := HouseData.value_cells(value)
	var sum := Vector2.ZERO
	for cell in cells:
		sum += Vector2(cell) + Vector2(0.5, 0.5)
	var middle := sum / maxf(1.0, float(cells.size()))
	var height := float(Catalog.get_item(value.get("item", "")).get("height", 1.0))
	return Vector3(middle.x, HouseGrid.level_y(level) + height / 2.0, middle.y)


## La clave de `points` (clave → posición en pantalla) más cercana a `finger`, si está a
## `max_distance` o menos. "" si ninguna. Ante un empate gana la primera.
static func nearest_key(points: Dictionary, finger: Vector2, max_distance: float) -> String:
	var best := ""
	var best_dist := max_distance
	for key in points:
		var dist: float = (points[key] as Vector2).distance_to(finger)
		if dist <= best_dist:
			best_dist = dist
			best = key
	return best


## Qué dirección del mundo (N/S/E/O) es cada flecha de la pantalla. `vectors` = para cada
## dirección del mundo, hacia dónde apunta EN LA PANTALLA (y crece hacia abajo).
## Devuelve {"up": "N", "down": "S", "left": "O", "right": "E"} según la cámara.
static func screen_direction_map(vectors: Dictionary) -> Dictionary:
	var wanted := {"up": Vector2(0, -1), "down": Vector2(0, 1), "left": Vector2(-1, 0), "right": Vector2(1, 0)}
	var result := {}
	var taken := {}
	# Se reparte de a una, empezando por el par más claro, para que no se repita ninguna.
	var pairs: Array = []
	for arrow in wanted:
		for dir in vectors:
			var v: Vector2 = vectors[dir]
			pairs.append({"arrow": arrow, "dir": dir, "score": v.normalized().dot(wanted[arrow]) if v.length() > 0.0001 else -2.0})
	pairs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["score"] > b["score"])
	for pair in pairs:
		if result.has(pair["arrow"]) or taken.has(pair["dir"]):
			continue
		result[pair["arrow"]] = pair["dir"]
		taken[pair["dir"]] = true
	return result


# --- Los botones ---

func _build_buttons() -> void:
	for child in _root.get_children():
		child.queue_free()
	# Hacia dónde apunta cada dirección del mundo en la pantalla (según la cámara de ahora).
	var cam := get_viewport().get_camera_3d()
	var value: Dictionary = house.get_piece(_target_level, "objects", _target_key)
	var center3 := object_center(_target_level, value)
	var vectors := {}
	for dir in HouseBuilder.DIRECTIONS:
		var step: Vector2i = HouseBuilder.DIRECTIONS[dir]
		var a := cam.unproject_position(view.to_global(center3))
		var b := cam.unproject_position(view.to_global(center3 + Vector3(step.x, 0, step.y)))
		vectors[dir] = b - a
	_screen_map = screen_direction_map(vectors)
	var names := {"N": "norte", "S": "sur", "E": "este", "O": "oeste"}
	for arrow in ["up", "down", "left", "right"]:
		var world_dir: String = _screen_map.get(arrow, "N")
		var button := Icons.make_button("arrow", "Correr hacia %s" % names[world_dir], BUTTON_SIZE)
		button.name = "Arrow_" + arrow
		button.icon = Icons.rotated("arrow", {"up": 0, "right": 1, "down": 2, "left": 3}[arrow])
		button.pressed.connect(_on_nudge.bind(world_dir))
		_root.add_child(button)
	var rotate := Icons.make_button("rotate45", "Girar", BUTTON_SIZE)
	rotate.name = "Rotate"
	rotate.pressed.connect(_on_rotate)
	_root.add_child(rotate)
	var close_button := Icons.make_button("close", "Cerrar", 56)
	close_button.name = "Close"
	close_button.pressed.connect(close)
	_root.add_child(close_button)


## Acomoda la cruz alrededor del mueble (siguiéndolo si se mueve o gira la cámara).
func _place_buttons() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or not house.has_piece(_target_level, "objects", _target_key):
		return
	var value: Dictionary = house.get_piece(_target_level, "objects", _target_key)
	var screen := cam.unproject_position(view.to_global(object_center(_target_level, value)))
	var size: Vector2 = get_viewport().get_visible_rect().size
	# El centro de la cruz se mantiene adentro de la pantalla.
	var center := Vector2(clampf(screen.x, SCREEN_MARGIN, size.x - SCREEN_MARGIN), clampf(screen.y, SCREEN_MARGIN, size.y - SCREEN_MARGIN))
	var offsets := {"Arrow_up": Vector2(0, -CROSS_RADIUS), "Arrow_down": Vector2(0, CROSS_RADIUS),
		"Arrow_left": Vector2(-CROSS_RADIUS, 0), "Arrow_right": Vector2(CROSS_RADIUS, 0), "Rotate": Vector2.ZERO,
		"Close": Vector2(CROSS_RADIUS * 0.85, -CROSS_RADIUS * 1.25)}
	for node_name in offsets:
		var button: Control = _root.get_node_or_null(node_name)
		if button != null:
			button.position = center + offsets[node_name] - button.size / 2.0


func _on_nudge(world_dir: String) -> void:
	if _busy or _target_key == "":
		return
	_busy = true
	_idle = 0.0
	var moved: bool = await builder.nudge_piece(_target_level, _target_key, world_dir)
	_busy = false
	if not moved:
		EventBus.toast.emit("Ahí no entra.")


func _on_rotate() -> void:
	if _busy or _target_key == "":
		return
	_busy = true
	_idle = 0.0
	var turned: bool = await builder.rotate_piece(_target_level, _target_key)
	_busy = false
	if not turned:
		EventBus.toast.emit("No hay lugar para girarlo.")
