class_name LongPressTip
extends RefCounted
## Pulido 6A (2): al MANTENER presionado un botón con ícono sale un cartelito con su
## nombre (el `tooltip_text`). En el teléfono no existe el "mouse encima", así que el
## tooltip normal de Godot no sirve; esto lo reemplaza con el dedo.
##
## Mientras el cartel está a la vista el botón queda desactivado: así soltar el dedo
## NO cuenta como un toque (si no, mirar el nombre ejecutaría la acción). Al soltar,
## el cartel se va y el botón vuelve a estar activo.

## Cuánto hay que mantener presionado (segundos).
const HOLD_SECONDS := 0.5
## Cada cuánto se revisa si el dedo ya soltó (segundos).
const POLL_SECONDS := 0.08
## Tope de seguridad: el cartel se va solo a los N segundos.
const MAX_SECONDS := 6.0
const ATTACHED_META := "long_press_tip_attached"
const SERIAL_META := "long_press_tip_serial"
const NODE_META := "long_press_tip_node"
const BLOCKED_META := "long_press_tip_blocked"


## Deja el botón listo para mostrar su tooltip al mantenerlo presionado.
static func attach(button: Button) -> void:
	if button.has_meta(ATTACHED_META):
		return
	button.set_meta(ATTACHED_META, true)
	button.button_down.connect(_on_down.bind(button))
	button.button_up.connect(_on_up.bind(button))


## Texto del cartel de un botón: su tooltip.
static func text_for(button: Button) -> String:
	return button.tooltip_text.strip_edges()


## ¿Hay un cartel a la vista para este botón?
static func is_showing(button: Button) -> bool:
	var node: Variant = button.get_meta(NODE_META, null)
	return node is Node and is_instance_valid(node)


## ¿El dedo (o el mouse) sigue apretando encima del botón?
static func _is_held(button: Button) -> bool:
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
		and button.get_global_rect().has_point(button.get_global_mouse_position())


static func _on_down(button: Button) -> void:
	if not button.is_inside_tree() or text_for(button) == "":
		return
	var serial: int = int(button.get_meta(SERIAL_META, 0)) + 1
	button.set_meta(SERIAL_META, serial)
	await button.get_tree().create_timer(HOLD_SECONDS).timeout
	# ¿Sigue siendo el mismo toque, y sigue apretado?
	if not is_instance_valid(button) or int(button.get_meta(SERIAL_META, 0)) != serial or not _is_held(button):
		return
	show_tip(button)
	# El botón desactivado ya no avisa cuando se suelta: se revisa a mano.
	var waited := 0.0
	while is_instance_valid(button) and is_showing(button) and waited < MAX_SECONDS:
		await button.get_tree().create_timer(POLL_SECONDS).timeout
		waited += POLL_SECONDS
		if not is_instance_valid(button) or not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			break
	if is_instance_valid(button):
		hide_tip(button)


static func _on_up(button: Button) -> void:
	# Soltó antes de tiempo: ese toque ya no muestra cartel.
	button.set_meta(SERIAL_META, int(button.get_meta(SERIAL_META, 0)) + 1)


## Muestra el cartel arriba del botón (adentro de la pantalla).
static func show_tip(button: Button) -> void:
	hide_tip(button)
	var panel := PanelContainer.new()
	panel.name = "LongPressTip"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 100
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.2, 0.95)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = text_for(button)
	label.add_theme_font_size_override("font_size", 20)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	button.get_tree().root.add_child(panel)
	button.set_meta(NODE_META, panel)
	# Cancela el toque: soltar el dedo no ejecuta el botón.
	if not button.disabled:
		button.disabled = true
		button.set_meta(BLOCKED_META, true)
	place_tip(button, panel)


## Centra el cartel sobre el botón, sin salirse de la pantalla (si no cabe arriba, va abajo).
static func place_tip(button: Button, panel: Control) -> void:
	await button.get_tree().process_frame
	if not is_instance_valid(button) or not is_instance_valid(panel):
		return
	var rect: Rect2 = button.get_global_rect()
	var screen: Vector2 = button.get_viewport().get_visible_rect().size
	var tip_size: Vector2 = panel.size
	var x: float = clampf(rect.get_center().x - tip_size.x / 2.0, 8.0, maxf(8.0, screen.x - tip_size.x - 8.0))
	var y: float = rect.position.y - tip_size.y - 8.0
	if y < 8.0:
		y = rect.end.y + 8.0
	panel.position = Vector2(x, y)


## Saca el cartel y deja el botón como estaba.
static func hide_tip(button: Button) -> void:
	var node: Variant = button.get_meta(NODE_META, null)
	if node is Node and is_instance_valid(node):
		(node as Node).queue_free()
	button.remove_meta(NODE_META)
	# Solo se reactiva si FUE este cartel el que lo desactivó.
	if bool(button.get_meta(BLOCKED_META, false)):
		button.disabled = false
		button.set_meta(BLOCKED_META, false)
