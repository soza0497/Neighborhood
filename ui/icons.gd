class_name Icons
## Íconos propios del juego (SVG simples en assets/icons/) y botones con
## ícono. Pulido 1: la pantalla usa íconos en vez de botones con texto; el
## texto queda como "tooltip" (se ve al dejar el mouse encima en la PC).

const ICON_PATH := "res://assets/icons/%s.svg"
## Tamaño normal de un botón con ícono (cómodo para el dedo).
const BUTTON_SIZE := 64


## Textura de un ícono por su nombre (por ejemplo "menu", "trash").
static func texture(icon_name: String) -> Texture2D:
	return load(ICON_PATH % icon_name)


## Convierte un botón en botón con ícono (sin texto).
static func setup(button: Button, icon_name: String, tooltip: String, size := BUTTON_SIZE) -> void:
	button.text = ""
	button.icon = texture(icon_name)
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(size, size)
	button.focus_mode = Control.FOCUS_NONE
	var margin := size * 0.16
	for state in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.13, 0.17, 0.25, 0.85)
		if state == "pressed" or state == "hover_pressed":
			style.bg_color = Color(0.95, 0.6, 0.25, 0.95)
		elif state == "hover":
			style.bg_color = Color(0.2, 0.26, 0.38, 0.9)
		style.set_corner_radius_all(int(size * 0.3))
		style.content_margin_left = margin
		style.content_margin_right = margin
		style.content_margin_top = margin
		style.content_margin_bottom = margin
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 0.35))
	LongPressTip.attach(button)


## Botón nuevo con ícono.
static func make_button(icon_name: String, tooltip: String, size := BUTTON_SIZE, toggle := false) -> Button:
	var button := Button.new()
	button.toggle_mode = toggle
	setup(button, icon_name, tooltip, size)
	return button


## Textura de un ícono girada `turns` cuartos de vuelta (sentido del reloj).
static func rotated(icon_name: String, turns: int) -> Texture2D:
	var image := texture(icon_name).get_image()
	if image.is_compressed():
		image.decompress()
	for i in posmod(turns, 4):
		image.rotate_90(CLOCKWISE)
	return ImageTexture.create_from_image(image)
