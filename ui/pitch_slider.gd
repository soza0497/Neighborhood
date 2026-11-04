class_name PitchSlider
extends Control
## Barra vertical del ángulo de la cámara (Pulido 3B): una perilla en el centro.
## Arrastrar hacia ARRIBA sube el ángulo (hasta la vista aérea de cielo), hacia
## ABAJO lo baja (hasta casi de frente). Cuanto más lejos del centro, más
## rápido cambia. Al soltar, la perilla vuelve sola al centro y el ángulo se
## queda como estaba. Funciona con el mouse y con el dedo (el toque se
## convierte en clic del mouse, así que se maneja todo desde `_gui_input`).

## Cuánto está desviada la perilla: de -1 (abajo del todo) a 1 (arriba del todo).
signal deflection_changed(value: float)

const TRACK_WIDTH := 64.0
const TRACK_HEIGHT := 220.0
const KNOB_RADIUS := 24.0

## Desvío actual (-1 a 1). 0 = en el centro.
var value := 0.0
var _dragging := false
var _tween: Tween


func _init() -> void:
	custom_minimum_size = Vector2(TRACK_WIDTH, TRACK_HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Ángulo de la cámara: arrastrá la perilla hacia arriba o abajo"


## Cuánto puede subir o bajar la perilla desde el centro (en píxeles).
func _travel() -> float:
	return size.y / 2.0 - KNOB_RADIUS - 4.0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			if _tween != null:
				_tween.kill()
			_set_from_position(event.position)
		elif _dragging:
			_release()
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_set_from_position(event.position)
		accept_event()


## Si el dedo sale de la barra al soltar, igual se suelta (no queda trabada).
func _notification(what: int) -> void:
	if what == NOTIFICATION_FOCUS_EXIT or what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		if _dragging:
			_release()


func _set_from_position(local: Vector2) -> void:
	var travel := maxf(1.0, _travel())
	_set_value(clampf((size.y / 2.0 - local.y) / travel, -1.0, 1.0))


func _set_value(new_value: float) -> void:
	value = new_value
	deflection_changed.emit(value)
	queue_redraw()


func _release() -> void:
	_dragging = false
	# Vuelve sola al centro (el ángulo no cambia, solo la perilla).
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_value, value, 0.0, 0.18).set_trans(Tween.TRANS_SINE)


## Empuja la perilla por código (lo usan las pruebas, igual que el dedo).
func press_at(deflection: float) -> void:
	_dragging = true
	if _tween != null:
		_tween.kill()
	_set_value(clampf(deflection, -1.0, 1.0))


func release_now() -> void:
	_release()


func is_dragging() -> bool:
	return _dragging


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.13, 0.17, 0.25, 0.7)
	panel.set_corner_radius_all(int(size.x / 2.0))
	draw_style_box(panel, r)
	var cx := size.x / 2.0
	# La ranura por donde corre la perilla.
	var slot := Rect2(cx - 4.0, KNOB_RADIUS, 8.0, size.y - KNOB_RADIUS * 2.0)
	var slot_style := StyleBoxFlat.new()
	slot_style.bg_color = Color(1, 1, 1, 0.16)
	slot_style.set_corner_radius_all(4)
	draw_style_box(slot_style, slot)
	# Flechitas de arriba (sube el ángulo) y de abajo (lo baja).
	var white := Color(1, 1, 1, 0.55)
	draw_colored_polygon(PackedVector2Array([Vector2(cx, 8.0), Vector2(cx - 8.0, 20.0), Vector2(cx + 8.0, 20.0)]), white)
	draw_colored_polygon(PackedVector2Array([Vector2(cx, size.y - 8.0), Vector2(cx - 8.0, size.y - 20.0), Vector2(cx + 8.0, size.y - 20.0)]), white)
	# La perilla.
	var knob_y := size.y / 2.0 - value * _travel()
	var knob_color := Color(0.95, 0.6, 0.25, 1.0) if _dragging else Color(0.96, 0.96, 0.98, 1.0)
	draw_circle(Vector2(cx, knob_y), KNOB_RADIUS, Color(0.1, 0.12, 0.2, 0.9))
	draw_circle(Vector2(cx, knob_y), KNOB_RADIUS - 3.0, knob_color)
