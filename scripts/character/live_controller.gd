class_name LiveController
extends Node3D
## Modo vivir: detecta toques cortos sobre los muebles y pide a la interfaz
## que muestre sus acciones ("Dormir", "Cocinar"...).
##
## No consume los toques: la cámara sigue moviéndose igual. Un "toque" es
## apretar y soltar rápido y casi sin moverse.

## Máximo de píxeles que se puede mover el dedo para que cuente como toque.
const TAP_MAX_MOVE := 14.0
## Máximo de segundos entre apretar y soltar.
const TAP_MAX_TIME := 0.35

var view: HouseView
var active := false

var _press_pos := Vector2.ZERO
var _press_time := 0.0
var _pressed := false


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	var position_2d := Vector2.ZERO
	var pressed := false
	if event is InputEventScreenTouch:
		if event.index != 0:
			_pressed = false  # Dos dedos: no es un toque.
			return
		position_2d = event.position
		pressed = event.pressed
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		position_2d = event.position
		pressed = event.pressed
	else:
		return

	if pressed:
		_pressed = true
		_press_pos = position_2d
		_press_time = Time.get_ticks_msec() / 1000.0
	elif _pressed:
		_pressed = false
		var quick := Time.get_ticks_msec() / 1000.0 - _press_time <= TAP_MAX_TIME
		if quick and position_2d.distance_to(_press_pos) <= TAP_MAX_MOVE:
			_on_tap(position_2d)


func _on_tap(screen_pos: Vector2) -> void:
	var cam := get_viewport().get_camera_3d()
	var origin := to_local(cam.project_ray_origin(screen_pos))
	var direction := global_transform.basis.inverse() * cam.project_ray_normal(screen_pos)
	# Se prueba desde el piso que se ve hacia abajo: lo de arriba tapa lo de abajo.
	for level in range(view.top_visible_level, -1, -1):
		var key := view.pick_object(origin, direction, level)
		if key != "":
			var item_id: String = view.house.get_piece(level, "objects", key)["item"]
			if not Catalog.get_item_actions(item_id).is_empty():
				EventBus.object_menu_requested.emit(level, key, item_id)
			return
