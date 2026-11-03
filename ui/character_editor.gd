extends Control
## Editor de personaje básico: nombre, colores y rasgos.
##
## Se eligen opciones con botones (no se "estira" el cuerpo con el dedo:
## ver docs/riesgos-legales-ea.md, sección 6). Los colores y rasgos salen de
## data/character_options.json y data/traits.json.

## Partes que se pueden pintar y su nombre en pantalla.
const PARTS := {"skin": "Piel", "hair": "Pelo", "shirt": "Camisa", "pants": "Pantalón"}
const SWATCH_SIZE := Vector2(52, 44)

@onready var _name_edit: LineEdit = %NameEdit
@onready var _parts_box: VBoxContainer = %PartsBox
@onready var _traits_label: Label = %TraitsLabel
@onready var _traits_grid: GridContainer = %TraitsGrid
@onready var _trait_info: Label = %TraitInfo
@onready var _done_button: Button = %DoneButton
@onready var _cancel_button: Button = %CancelButton

## Copia de los datos que se están editando (ver CharacterData.to_dict).
var _data: Dictionary = {}
var _trait_buttons: Dictionary = {}


func _ready() -> void:
	visible = false
	_done_button.pressed.connect(_on_done)
	_cancel_button.pressed.connect(hide)
	EventBus.character_editor_opened.connect(open)


## Abre el editor con los datos actuales del personaje.
func open(data: Dictionary) -> void:
	_data = data.duplicate(true)
	_name_edit.text = _data.get("name", "")
	_build_part_rows()
	_build_trait_buttons()
	show()


func _build_part_rows() -> void:
	for child in _parts_box.get_children():
		child.queue_free()
	var appearance: Dictionary = _data.get("appearance", {})
	for part in PARTS:
		var label := Label.new()
		label.text = PARTS[part]
		label.add_theme_font_size_override("font_size", 17)
		_parts_box.add_child(label)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_parts_box.add_child(row)
		var group := ButtonGroup.new()
		for color_text in Catalog.character_options.get(part, []):
			var button := Button.new()
			button.toggle_mode = true
			button.button_group = group
			button.custom_minimum_size = SWATCH_SIZE
			button.button_pressed = color_text == appearance.get(part, "")
			_paint_swatch(button, Color.from_string(color_text, Color.WHITE))
			button.pressed.connect(_on_color_chosen.bind(part, color_text))
			row.add_child(button)


## Botón de color: el fondo es el color; elegido, tiene borde blanco.
func _paint_swatch(button: Button, color: Color) -> void:
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = color
		style.set_corner_radius_all(10)
		if state.contains("pressed"):
			style.set_border_width_all(4)
			style.border_color = Color.WHITE
		button.add_theme_stylebox_override(state, style)


func _on_color_chosen(part: String, color_text: String) -> void:
	var appearance: Dictionary = _data.get("appearance", {})
	appearance[part] = color_text
	_data["appearance"] = appearance


func _build_trait_buttons() -> void:
	for child in _traits_grid.get_children():
		child.queue_free()
	_trait_buttons.clear()
	var chosen: Array = _data.get("traits", [])
	for trait_id in Catalog.traits:
		var button := Button.new()
		button.text = Catalog.traits[trait_id]["name"]
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(150, 48)
		button.add_theme_font_size_override("font_size", 17)
		button.button_pressed = trait_id in chosen
		# Elegido = naranja, para que se note bien.
		var chosen_style := StyleBoxFlat.new()
		chosen_style.bg_color = Color("#ff9f43")
		chosen_style.set_corner_radius_all(8)
		button.add_theme_stylebox_override("pressed", chosen_style)
		button.add_theme_stylebox_override("hover_pressed", chosen_style)
		button.toggled.connect(_on_trait_toggled.bind(trait_id))
		_traits_grid.add_child(button)
		_trait_buttons[trait_id] = button
	_traits_label.text = "Rasgos (elegí hasta %d)" % Catalog.max_traits
	_trait_info.text = ""


func _on_trait_toggled(on: bool, trait_id: String) -> void:
	var chosen: Array = _data.get("traits", [])
	if on and not trait_id in chosen:
		if chosen.size() >= Catalog.max_traits:
			# Ya tiene el máximo: se desmarca el botón sin avisar a esta función.
			_trait_buttons[trait_id].set_pressed_no_signal(false)
			_trait_info.text = "Ya elegiste %d. Quitá uno primero." % Catalog.max_traits
			return
		chosen.append(trait_id)
	elif not on:
		chosen.erase(trait_id)
	_data["traits"] = chosen
	_trait_info.text = Catalog.traits[trait_id].get("description", "") if on else ""


func _on_done() -> void:
	var new_name := _name_edit.text.strip_edges()
	if new_name != "":
		_data["name"] = new_name
	hide()
	EventBus.character_edit_finished.emit(_data)
