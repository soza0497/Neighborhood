extends ScrollContainer
## Lista que se desliza arrastrando el dedo (o el mouse) por encima de sus
## botones, no solo por la barrita. La barrita queda para ver dónde estamos.
##
## Si el dedo se mueve más de DRAG_THRESHOLD píxeles, se toma como
## deslizamiento: los botones se desactivan un instante para que soltar el
## dedo no elija nada por accidente.

## Píxeles que hay que mover el dedo para que cuente como deslizar.
const DRAG_THRESHOLD := 14.0

## true = se desliza de lado; false = de arriba hacia abajo.
@export var horizontal := true

var _pressing := false
var _dragging := false
var _press_pos := Vector2.ZERO
var _start_scroll := 0
var _disabled_buttons: Array[BaseButton] = []


# Se usa _input (antes que los botones) para ver el gesto completo.
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var is_touch: bool = event is InputEventScreenTouch
	var is_click: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
		and event.device != InputEvent.DEVICE_ID_EMULATION
	if is_touch or is_click:
		if event.pressed and get_global_rect().has_point(event.position):
			_pressing = true
			_dragging = false
			_press_pos = event.position
			_start_scroll = scroll_horizontal if horizontal else scroll_vertical
		elif not event.pressed and _pressing:
			_pressing = false
			if _dragging:
				# Se reactivan los botones después de que pase el "soltar".
				_enable_buttons.call_deferred()
		return

	var is_drag: bool = event is InputEventScreenDrag
	var is_motion: bool = event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION
	if _pressing and (is_drag or is_motion):
		var moved: float = (event.position - _press_pos).x if horizontal else (event.position - _press_pos).y
		if not _dragging and absf(moved) > DRAG_THRESHOLD:
			_dragging = true
			_disable_buttons(self)
		if _dragging:
			if horizontal:
				scroll_horizontal = _start_scroll - int(moved)
			else:
				scroll_vertical = _start_scroll - int(moved)


func _disable_buttons(node: Node) -> void:
	for child in node.get_children():
		if child is BaseButton and not child.disabled:
			child.disabled = true
			_disabled_buttons.append(child)
		_disable_buttons(child)


func _enable_buttons() -> void:
	for button in _disabled_buttons:
		if is_instance_valid(button):
			button.disabled = false
	_disabled_buttons.clear()
