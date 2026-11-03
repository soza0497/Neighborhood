class_name PanelRows
## Ayudantes para armar las filas de los paneles por código (Pareja, Casa):
## textos, botones e interruptores con el mismo tamaño y estilo en todos.


static func label(text: String, font_size := 17, color := Color.WHITE) -> Label:
	var result := Label.new()
	result.text = text
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.custom_minimum_size = Vector2(380, 0)
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	return result


static func title(text: String) -> Label:
	return label(text, 20, Color(1, 0.88, 0.6))


static func button(text: String, on_pressed: Callable, disabled := false, width := 190.0) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size = Vector2(width, 52)
	result.add_theme_font_size_override("font_size", 17)
	result.disabled = disabled
	result.pressed.connect(on_pressed)
	return result


static func check(text: String, pressed: bool, on_toggled: Callable, disabled := false) -> CheckButton:
	var result := CheckButton.new()
	result.text = text
	result.button_pressed = pressed
	result.disabled = disabled
	result.custom_minimum_size = Vector2(0, 46)
	result.add_theme_font_size_override("font_size", 17)
	result.toggled.connect(on_toggled)
	return result


## Una fila: lo que se le pase, uno al lado del otro.
static func row(children: Array) -> HBoxContainer:
	var result := HBoxContainer.new()
	result.add_theme_constant_override("separation", 10)
	for child in children:
		result.add_child(child)
	return result


## Hora local "14:02" de una hora Unix.
static func time_text(unix: int) -> String:
	var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var t := Time.get_datetime_dict_from_unix_time(unix + bias)
	return "%02d/%02d %02d:%02d" % [t["day"], t["month"], t["hour"], t["minute"]]


static func clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
