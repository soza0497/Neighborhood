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

@onready var _pitch: Node3D = $Pitch
@onready var _camera: Camera3D = $Pitch/Camera3D

var _distance := 22.0
## Dedos que están tocando la pantalla: número de dedo → posición.
var _touches: Dictionary = {}
var _mouse_left_down := false
var _mouse_middle_down := false
var _mouse_rotating := false


func _ready() -> void:
	_pitch.rotation_degrees.x = pitch_degrees
	reset_view()
	EventBus.camera_reset_requested.connect(reset_view)


## Vuelve la cámara a su posición inicial.
func reset_view() -> void:
	position = Vector3.ZERO
	rotation_degrees.y = default_yaw_degrees
	_set_distance(default_distance)


## Devuelve el estado actual para guardarlo.
func get_state() -> Dictionary:
	return {
		"x": position.x,
		"z": position.z,
		"yaw": rotation_degrees.y,
		"distance": _distance,
	}


## Aplica un estado guardado. Si falta algún dato, usa el valor por defecto.
func set_state(state: Dictionary) -> void:
	position = Vector3(state.get("x", 0.0), 0.0, state.get("z", 0.0))
	rotation_degrees.y = state.get("yaw", default_yaw_degrees)
	_set_distance(state.get("distance", default_distance))
	_clamp_position()


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

## Mueve la cámara para que el punto del suelo que estaba bajo `from`
## quede bajo `to`. Así se siente como "agarrar el suelo" con el dedo.
func _pan(from: Vector2, to: Vector2) -> void:
	var ground_from: Variant = _screen_to_ground(from)
	var ground_to: Variant = _screen_to_ground(to)
	if ground_from == null or ground_to == null:
		return
	position += ground_from - ground_to
	_clamp_position()


## Devuelve el punto del suelo (altura 0) que está bajo un punto de la
## pantalla, o null si ese punto mira al cielo.
func _screen_to_ground(screen_position: Vector2) -> Variant:
	var origin := _camera.project_ray_origin(screen_position)
	var direction := _camera.project_ray_normal(screen_position)
	return Plane(Vector3.UP, 0.0).intersects_ray(origin, direction)


func _set_distance(value: float) -> void:
	_distance = clampf(value, min_distance, max_distance)
	_camera.position = Vector3(0.0, 0.0, _distance)


func _clamp_position() -> void:
	position.x = clampf(position.x, -bounds_half_size, bounds_half_size)
	position.z = clampf(position.z, -bounds_half_size, bounds_half_size)
	position.y = 0.0
