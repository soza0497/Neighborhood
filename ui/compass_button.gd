class_name CompassButton
extends Button
## Brújula (Pulido 1): una flechita de navegador que apunta hacia donde está
## el personaje en la pantalla. Tocarla centra la cámara en él.

## El personaje al que apunta (lo pone la interfaz).
var target: Node3D

var _arrow: TextureRect


func _ready() -> void:
	Icons.setup(self, "compass", "Centrar en el personaje")
	icon = null  # La flecha va aparte, para poder girarla.
	_arrow = TextureRect.new()
	_arrow.texture = Icons.texture("compass")
	_arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_arrow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_arrow)
	pressed.connect(EventBus.camera_focus_character_requested.emit)


func _process(_delta: float) -> void:
	var margin := size * 0.18
	_arrow.position = margin
	_arrow.size = size - margin * 2.0
	_arrow.pivot_offset = _arrow.size / 2.0
	var cam := get_viewport().get_camera_3d()
	if target == null or cam == null or not is_instance_valid(target):
		_arrow.rotation = 0.0
		return
	# Dirección desde el centro de la pantalla hasta el personaje. Si quedó
	# detrás de la cámara, la dirección se invierte.
	var center := get_viewport().get_visible_rect().size / 2.0
	var screen := cam.unproject_position(target.global_position)
	var direction := screen - center
	if cam.is_position_behind(target.global_position):
		direction = -direction
	if direction.length() < 40.0:
		_arrow.rotation = 0.0
		modulate = Color(1, 1, 1, 0.75)  # Ya está a la vista, en el medio.
	else:
		_arrow.rotation = direction.angle() + PI / 2.0
		modulate = Color.WHITE
