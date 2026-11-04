class_name CameraRig
extends Node3D
## Cámara vista desde arriba en diagonal, que se maneja con los dedos o el mouse.
##
## Cómo está armada (cada nodo hace UNA cosa):
##   CameraRig  → está en el suelo, en el punto que se mira; su giro en Y es la rotación.
##     Pitch    → inclina la vista hacia abajo.
##       Camera3D → se aleja del punto según el zoom.
##
## Controles táctiles: 1 dedo arrastra, 2 dedos pellizcan (zoom) y giran.
## Controles de mouse: clic izquierdo (o rueda apretada) arrastra,
## clic derecho gira, la rueda hace zoom.

## Distancia mínima y máxima al punto que se mira (zoom).
@export var min_distance := 6.0
@export var max_distance := 60.0
@export var default_distance := 22.0
## Inclinación de la vista, en grados (más negativo = más desde arriba).
@export var pitch_degrees := -50.0
## Pulido 2: inclinaciones que se pueden elegir (grados hacia abajo), de
## "de frente" (casi horizontal) a "desde arriba" del todo. Editables acá.
const PITCH_PRESETS := [-20.0, -30.0, -50.0, -70.0, -89.0]
const PITCH_NAMES := ["De frente", "Baja", "Normal", "Alta", "Desde arriba"]
## Giro inicial, en grados.
@export var default_yaw_degrees := 45.0
## Hasta dónde se puede mover el punto que se mira, desde el centro del mapa.
@export var bounds_half_size := 28.0
## Grados que gira la cámara por cada píxel que se mueve el mouse.
@export var mouse_rotate_speed := 0.3
## Cuánto acerca o aleja cada paso de la rueda del mouse.
@export var wheel_zoom_factor := 1.1
## Si es false, la cámara ignora los toques (útil cuando otro modo los usa).
@export var input_enabled := true
## Si es false, un solo dedo (o el clic izquierdo) NO mueve la cámara: lo usa
## el constructor. Dos dedos, clic derecho, rueda y rueda apretada siguen igual.
var single_finger_pan := true

## Pulido 5B: parámetros de data/camera.json (si falta algo, valen estos).
const CONFIG_PATH := "res://data/camera.json"
const DEFAULT_CONFIG := {
	"pitch_min_degrees": -20.0, "pitch_max_degrees": -89.0, "low_pitch_below": -35.0,
	"pan_cap": 0.3, "frame_cap": 0.12, "pending_cap": 0.5, "damping": 18.0,
	"low_side_factor": 0.8, "low_forward_factor": 0.3, "low_dead_zone_px": 14.0,
	"lot_margin": 3.0, "lot_soft_border": 6.0,
}
## Si es true, en la vista normal la cámara no sale de la parcela usable (+ margen).
## La vista del barrio (y la isla, a futuro) lo apagan y conservan sus límites.
var lot_limit_enabled := true
var config: Dictionary = DEFAULT_CONFIG.duplicate()

@onready var _pitch: Node3D = $Pitch
@onready var _camera: Camera3D = $Pitch/Camera3D

var _distance := 22.0
## Dedos que están tocando la pantalla: número de dedo → posición.
var _touches: Dictionary = {}
var _mouse_left_down := false
var _mouse_middle_down := false
var _mouse_rotating := false
## Pulido 5B: lo que falta mover (metros, plano XZ). Se gasta de a poco cada cuadro.
var _pending := Vector3.ZERO
## Píxeles verticales arrastrados en este gesto (para la zona muerta con la cámara baja).
var _drag_y := 0.0


func _ready() -> void:
	config = load_config()
	# Pulido 2C: se puede mirar toda la parcela (no más allá de sus bordes).
	bounds_half_size = maxf(28.0, HouseGrid.LOT_SIZE.x / 2.0 - 2.0)
	_pitch.rotation_degrees.x = pitch_degrees
	reset_view()
	EventBus.camera_reset_requested.connect(reset_view)


## Cambia la inclinación vertical (grados; negativo = mira hacia abajo).
func set_pitch(degrees: float) -> void:
	# Pulido 5B: no baja de pitch_min_degrees (nada de «primera persona»).
	pitch_degrees = clampf(degrees, float(config["pitch_max_degrees"]), float(config["pitch_min_degrees"]))
	_pitch.rotation_degrees.x = pitch_degrees


## Sube (+) o baja (-) el ángulo `degrees` grados (lo usa la barra del ángulo).
## Subir = mirar más desde arriba, hasta la vista aérea de cielo (-89).
func step_pitch(degrees: float) -> void:
	set_pitch(pitch_degrees - degrees)


## Pasa a la siguiente inclinación de PITCH_PRESETS. Devuelve su nombre.
func cycle_pitch() -> String:
	var best := 0
	for i in PITCH_PRESETS.size():
		if absf(PITCH_PRESETS[i] - pitch_degrees) < absf(PITCH_PRESETS[best] - pitch_degrees):
			best = i
	var next := (best + 1) % PITCH_PRESETS.size()
	set_pitch(PITCH_PRESETS[next])
	return PITCH_NAMES[next]


## Vuelve la cámara a su posición inicial.
func reset_view() -> void:
	position = Vector3(0.0, floor_height, 0.0)
	rotation_degrees.y = default_yaw_degrees
	_set_distance(default_distance)


## Altura del piso que se está mirando (Pulido 1: con 5 pisos, la cámara
## sube con el piso para no quedar metida entre las paredes de arriba).
var floor_height := 0.0


func set_floor_height(height: float) -> void:
	floor_height = height
	_clamp_position()


## Centra la cámara en un punto del mundo (por ejemplo, el personaje).
## Conserva el giro y el zoom.
func focus_on(world_point: Vector3) -> void:
	position = Vector3(world_point.x, floor_height, world_point.z)
	_clamp_position()


## Devuelve el estado actual para guardarlo.
func get_state() -> Dictionary:
	return {
		"x": position.x,
		"z": position.z,
		"yaw": rotation_degrees.y,
		"distance": _distance,
		"pitch": pitch_degrees,
	}


## Aplica un estado guardado. Si falta algún dato, usa el valor por defecto.
func set_state(state: Dictionary) -> void:
	position = Vector3(state.get("x", 0.0), 0.0, state.get("z", 0.0))
	rotation_degrees.y = state.get("yaw", default_yaw_degrees)
	_set_distance(state.get("distance", default_distance))
	# Una partida vieja (sin ángulo) vuelve al ángulo normal.
	set_pitch(float(state.get("pitch", PITCH_PRESETS[2])))
	_clamp_position()


# --- Vista del barrio (Fase 8B) ---
# Misma cámara y mismos gestos (arrastrar, pellizcar, dos dedos para girar); solo
# se amplían los límites para poder ver todo el barrio desde arriba.

## Límites de antes de entrar al barrio ({} = no se está en el barrio).
var _home_limits: Dictionary = {}
var _fly_tween: Tween
## Cuánto se abre la cámara en el barrio.
const NEIGHBORHOOD_BOUNDS := 190.0
const NEIGHBORHOOD_MAX_DISTANCE := 170.0
const NEIGHBORHOOD_FAR := 800.0


func in_neighborhood_view() -> bool:
	return not _home_limits.is_empty()


## Abre los límites (zoom, borde y alcance de la vista) para mirar el barrio.
func enter_neighborhood_view() -> void:
	if not _home_limits.is_empty():
		return
	_home_limits = {"bounds": bounds_half_size, "max": max_distance, "far": _camera.far, "floor": floor_height}
	bounds_half_size = NEIGHBORHOOD_BOUNDS
	lot_limit_enabled = false  # Pulido 5B: en el barrio valen los límites del barrio.
	max_distance = NEIGHBORHOOD_MAX_DISTANCE
	_camera.far = NEIGHBORHOOD_FAR
	floor_height = 0.0
	single_finger_pan = true


## Vuelve a los límites de siempre.
func exit_neighborhood_view() -> void:
	if _home_limits.is_empty():
		return
	if _fly_tween != null and _fly_tween.is_valid():
		_fly_tween.kill()
	bounds_half_size = _home_limits["bounds"]
	lot_limit_enabled = true
	max_distance = _home_limits["max"]
	_camera.far = _home_limits["far"]
	floor_height = _home_limits["floor"]
	_home_limits = {}
	_set_distance(_distance)
	_clamp_position()


## Viaja suavemente a un punto del suelo con cierto zoom.
func fly_to(point: Vector3, distance: float, duration := 0.8) -> void:
	if _fly_tween != null and _fly_tween.is_valid():
		_fly_tween.kill()
	if duration <= 0.0 or not is_inside_tree():
		position = Vector3(point.x, floor_height, point.z)
		_set_distance(distance)
		_clamp_position()
		return
	_fly_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_fly_tween.tween_property(self, "position", Vector3(point.x, floor_height, point.z), duration)
	_fly_tween.tween_method(_set_distance, _distance, distance, duration)


# --- Vista de la isla (Isla 1A) ---
# Igual que la del barrio: misma cámara y mismos gestos; solo se amplían los límites
# (borde, zoom mínimo y máximo, alcance de la vista) para recorrer toda la isla.

var _island_limits: Dictionary = {}


func in_island_view() -> bool:
	return not _island_limits.is_empty()


## Abre los límites para recorrer la isla. `half_size` = hasta dónde se puede mover el
## punto que se mira; `far` = alcance de la vista (la isla y el volcán son grandes).
func enter_island_view(half_size: float, new_max_distance: float, far: float, near := 1.0) -> void:
	if _island_limits.is_empty():
		_island_limits = {"bounds": bounds_half_size, "max": max_distance, "far": _camera.far, "near": _camera.near,
			"floor": floor_height, "min": min_distance}
	bounds_half_size = half_size
	max_distance = new_max_distance
	_camera.far = far
	_camera.near = near
	floor_height = 0.0
	single_finger_pan = true


## Vuelve a los límites de antes de entrar a la isla.
func exit_island_view() -> void:
	if _island_limits.is_empty():
		return
	bounds_half_size = _island_limits["bounds"]
	max_distance = _island_limits["max"]
	_camera.far = _island_limits["far"]
	_camera.near = _island_limits["near"]
	floor_height = _island_limits["floor"]
	min_distance = _island_limits["min"]
	_island_limits = {}
	_set_distance(_distance)
	_clamp_position()


## La cámara 3D (la usa la isla para medir distancias).
func camera_node() -> Camera3D:
	return _camera


func current_distance() -> float:
	return _distance


# Se usa _unhandled_input para que los botones de la interfaz reciban
# los toques primero y la cámara solo los que nadie más usó.
func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return

	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)
	elif event is InputEventMouseButton or event is InputEventMouseMotion:
		# Godot también crea eventos de mouse "falsos" a partir de los toques
		# (para que los botones funcionen). Esos se ignoran aquí, porque el
		# toque ya se manejó arriba.
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if event is InputEventMouseButton:
			_handle_mouse_button(event)
		else:
			_handle_mouse_motion(event)


# --- Táctil ---

func _handle_touch(event: InputEventScreenTouch) -> void:
	_drag_y = 0.0
	if event.pressed:
		_touches[event.index] = event.position
	else:
		_touches.erase(event.index)


func _handle_drag(event: InputEventScreenDrag) -> void:
	if not _touches.has(event.index):
		return
	var old_position: Vector2 = _touches[event.index]

	if _touches.size() == 1:
		# Un dedo: arrastrar el mapa (si el constructor no está usando el dedo).
		if single_finger_pan:
			_pan(old_position, event.position)
	elif _touches.size() == 2:
		# Dos dedos: comparar dónde estaban y dónde están ahora.
		var other_index: int = _touches.keys()[0] if _touches.keys()[0] != event.index else _touches.keys()[1]
		var other: Vector2 = _touches[other_index]

		var old_vector := old_position - other
		var new_vector := event.position - other

		# Pellizcar: si los dedos se separan, la cámara se acerca.
		if new_vector.length() > 1.0:
			_set_distance(_distance * old_vector.length() / new_vector.length())
		# Girar: el ángulo entre los dedos cambió.
		rotation.y += new_vector.angle() - old_vector.angle()
		# Arrastrar con dos dedos: se mueve el punto medio.
		_pan((old_position + other) / 2.0, (event.position + other) / 2.0)

	_touches[event.index] = event.position


# --- Mouse ---

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			_mouse_left_down = event.pressed
			_drag_y = 0.0
		MOUSE_BUTTON_MIDDLE:
			_mouse_middle_down = event.pressed
		MOUSE_BUTTON_RIGHT:
			_mouse_rotating = event.pressed
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				_set_distance(_distance / wheel_zoom_factor)
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				_set_distance(_distance * wheel_zoom_factor)


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	# Se revisa single_finger_pan al moverse (no al apretar) porque el
	# constructor decide en el mismo clic si lo va a usar.
	if _mouse_middle_down or (_mouse_left_down and single_finger_pan):
		_pan(event.position - event.relative, event.position)
	elif _mouse_rotating:
		rotation_degrees.y -= event.relative.x * mouse_rotate_speed


# --- Ayudantes ---

## Mueve la cámara siguiendo el gesto de `from` a `to` (píxeles).
## Vista normal: «agarrar el suelo» (el punto bajo el dedo queda bajo el dedo).
## Cámara baja (Pulido 5B): el suelo agarrado casi en el horizonte se dispara,
## así que se usa otro control: a los lados desplaza, adelante/atrás avanza
## despacio y con zona muerta. En los dos casos la velocidad es proporcional a
## la distancia, con tope por gesto, y el movimiento se amortigua (ver _process).
func _pan(from: Vector2, to: Vector2) -> void:
	var move := Vector3.ZERO
	if is_low_pitch():
		move = _low_pitch_move(from, to)
	else:
		var ground_from: Variant = _screen_to_ground(from)
		var ground_to: Variant = _screen_to_ground(to)
		if ground_from == null or ground_to == null:
			return
		move = ground_from - ground_to
	queue_move(move)


## ¿La cámara está tan baja que cambian los controles?
func is_low_pitch() -> bool:
	return pitch_degrees > float(config["low_pitch_below"])


## Metros que mide un píxel a la distancia a la que se mira (proporcional al zoom).
func meters_per_pixel() -> float:
	var height := maxf(1.0, get_viewport().get_visible_rect().size.y) if is_inside_tree() else 1080.0
	return 2.0 * _distance * tan(deg_to_rad(_camera.fov) / 2.0) / height


## Control de cámara baja: x = a los lados, y = adelante/atrás (despacio, con zona muerta).
func _low_pitch_move(from: Vector2, to: Vector2) -> Vector3:
	var delta := to - from
	var mpp := meters_per_pixel()
	var side := delta.x * mpp * float(config["low_side_factor"])
	# Zona muerta: el dedo tiene que recorrer low_dead_zone_px en vertical antes de avanzar.
	var dead := float(config["low_dead_zone_px"])
	var before := dead_zone(_drag_y, dead)
	_drag_y += delta.y
	var forward := (dead_zone(_drag_y, dead) - before) * mpp * float(config["low_forward_factor"])
	# Agarrar el suelo: dedo a la derecha = el mundo va a la derecha = la cámara a la izquierda.
	var local := Vector3(-side, 0.0, -forward)
	return global_transform.basis * local if is_inside_tree() else local.rotated(Vector3.UP, rotation.y)


## Suma un movimiento pendiente (metros, plano XZ) con tope proporcional a la distancia.
func queue_move(move: Vector3) -> void:
	move.y = 0.0
	_pending += cap_length(move, float(config["pan_cap"]) * _distance)
	_pending = cap_length(_pending, float(config["pending_cap"]) * _distance)


## Gasta una parte del movimiento pendiente (amortiguado y con tope por cuadro).
func step_pending(delta: float) -> void:
	if _pending.length_squared() < 0.000001:
		_pending = Vector3.ZERO
		return
	var fraction := 1.0 - exp(-float(config["damping"]) * delta)
	var step := cap_length(_pending * fraction, float(config["frame_cap"]) * _distance)
	_pending -= step
	move_by(step)


## Deja todo el movimiento pendiente aplicado ya (para pruebas y saltos de cámara).
func flush_pending() -> void:
	var guard := 0
	while _pending.length_squared() > 0.000001 and guard < 400:
		step_pending(1.0 / 60.0)
		guard += 1
	_pending = Vector3.ZERO


## Mueve la cámara frenando suave cerca del límite de la parcela (sin golpe).
func move_by(step: Vector3) -> void:
	var rect := limit_rect()
	var soft := soft_limit_step(Vector2(position.x, position.z), Vector2(step.x, step.z), rect,
		float(config["lot_soft_border"]) if lot_limit_enabled else 0.0)
	position.x += soft.x
	position.z += soft.y
	_clamp_position()


func _process(delta: float) -> void:
	step_pending(delta)


## Cuadro (en metros del mundo) donde puede estar el punto que se mira.
func limit_rect() -> Rect2:
	var map_rect := Rect2(-bounds_half_size, -bounds_half_size, bounds_half_size * 2.0, bounds_half_size * 2.0)
	if lot_limit_enabled:
		var usable := _usable_rect().intersection(map_rect)
		if usable.has_area():
			return usable
	return map_rect


## Parcela usable hoy (+ margen) en metros del mundo, o un Rect2 vacío si no se sabe.
func _usable_rect() -> Rect2:
	# Sin datos, o con el lote de pruebas (32), no se sabe cuál es la zona: sin límite de parcela.
	if Parcel.cfg.is_empty() or Parcel.zone_rects().is_empty() or int(Parcel.cfg.get("lot", 0)) != HouseGrid.LOT_SIZE.x:
		return Rect2()
	var cells := Parcel.zone_bounds()
	var origin := Vector2(HouseGrid.LOT_SIZE) / 2.0  # La casa se dibuja centrada: celda (0,0) está en (-lote/2).
	var margin := float(config["lot_margin"])
	return Rect2(Vector2(cells.position) - origin - Vector2(margin, margin), Vector2(cells.size) + Vector2(margin, margin) * 2.0)


## Zona muerta: ignora los primeros `dead` píxeles del recorrido (0 hasta `dead`, después crece).
static func dead_zone(value: float, dead: float) -> float:
	return signf(value) * maxf(0.0, absf(value) - dead)


## Recorta un vector a un largo máximo (sin cambiar su dirección).
static func cap_length(v: Vector3, max_length: float) -> Vector3:
	if max_length <= 0.0 or v.length() <= max_length:
		return v
	return v.normalized() * max_length


## Frena un paso (plano XZ) al acercarse al límite: por cada eje, si el paso
## va hacia el borde y quedan menos de `border` metros, se multiplica por una
## curva suave que llega a 0 justo en el borde. Alejarse no se frena.
static func soft_limit_step(pos: Vector2, step: Vector2, rect: Rect2, border: float) -> Vector2:
	var result := step
	for axis in 2:
		var s := step[axis]
		if s == 0.0 or border <= 0.0:
			continue
		var room: float = (rect.end[axis] - pos[axis]) if s > 0.0 else (pos[axis] - rect.position[axis])
		var t := clampf(room / border, 0.0, 1.0)
		result[axis] = s * (t * t * (3.0 - 2.0 * t))
	return result


## Lee data/camera.json y completa lo que falte con los valores de DEFAULT_CONFIG.
static func load_config() -> Dictionary:
	var result := DEFAULT_CONFIG.duplicate()
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(CONFIG_PATH)) == OK and json.data is Dictionary:
		for key in DEFAULT_CONFIG:
			if json.data.has(key):
				result[key] = json.data[key]
	return result


## Devuelve el punto del suelo (altura 0) que está bajo un punto de la
## pantalla, o null si ese punto mira al cielo.
func _screen_to_ground(screen_position: Vector2) -> Variant:
	var origin := _camera.project_ray_origin(screen_position)
	var direction := _camera.project_ray_normal(screen_position)
	return Plane(Vector3.UP, floor_height).intersects_ray(origin, direction)


func _set_distance(value: float) -> void:
	_distance = clampf(value, min_distance, max_distance)
	_camera.position = Vector3(0.0, 0.0, _distance)


func _clamp_position() -> void:
	var rect := limit_rect()
	position.x = clampf(position.x, rect.position.x, rect.end.x)
	position.z = clampf(position.z, rect.position.y, rect.end.y)
	position.y = floor_height
