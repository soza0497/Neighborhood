extends Control
## Editor de personaje: nombre, peinado, ojos, boca, colores y rasgos, con una
## vista previa que gira (Pulido 3B).
##
## Se eligen opciones con botones (no se "estira" el cuerpo con el dedo:
## ver docs/riesgos-legales-ea.md, sección 6). Los colores, las piezas
## (peinados, ojos, bocas) y los rasgos salen de data/character_options.json y
## data/traits.json: agregar una opción es editar el archivo.
##
## Dos usos: dentro del juego (Menú → Personaje; emite
## EventBus.character_edit_finished) y como PANTALLA DE CREACIÓN al registrarse
## (open_for_creation; emite la señal `created` y no se puede cancelar).

## Solo en la creación: el jugador tocó «Listo» (datos del personaje).
signal created(data: Dictionary)

## Partes que se pueden pintar y su nombre en pantalla.
const PARTS := {"skin": "Piel", "hair": "Pelo", "shirt": "Ropa (camisa)", "pants": "Pantalón"}
## Piezas intercambiables: clave de appearance → [lista en character_options.json, nombre].
const PIECES := {"hairstyle": ["hairstyles", "Peinado"], "eyes": ["eyes", "Ojos"], "mouth": ["mouths", "Boca"]}
## Grados por segundo que gira la vista previa.
const SPIN_SPEED := 35.0
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
var _creation := false
var _preview_viewport: SubViewport
var _preview_pivot: Node3D
var _preview_body: Node3D
var _dragging_preview := false


func _ready() -> void:
	visible = false
	_done_button.pressed.connect(_on_done)
	_cancel_button.pressed.connect(hide)
	EventBus.character_editor_opened.connect(open)
	_build_preview()
	_wrap_parts_in_scroll()
	_name_edit.text_changed.connect(func(_t: String) -> void: _update_preview_name())


## Abre el editor con los datos actuales del personaje.
func open(data: Dictionary) -> void:
	_creation = false
	_start(data)


## Pantalla de creación (primera vez, después de crear la cuenta): sin cancelar;
## «Listo» emite `created` con el personaje elegido.
func open_for_creation(data: Dictionary) -> void:
	_creation = true
	_start(data)


func _start(data: Dictionary) -> void:
	_data = data.duplicate(true)
	_name_edit.text = _data.get("name", "")
	_build_part_rows()
	_build_trait_buttons()
	_cancel_button.visible = not _creation
	$Center/Panel/Columns/Left/Title.text = "Creá tu personaje" if _creation else "Tu personaje"
	_refresh_preview()
	show()


## Un panel con el cuerpo de arriba (sin tapar el resto): la vista previa gira
## sola y también se puede girar arrastrando el dedo o el mouse encima.
func _build_preview() -> void:
	var columns: HBoxContainer = $Center/Panel/Columns
	var box := VBoxContainer.new()
	box.name = "PreviewBox"
	var container := SubViewportContainer.new()
	container.name = "Preview"
	container.stretch = true
	container.custom_minimum_size = Vector2(220, 340)
	container.gui_input.connect(_on_preview_input)
	box.add_child(container)
	_preview_viewport = SubViewport.new()
	_preview_viewport.own_world_3d = true
	_preview_viewport.transparent_bg = true
	_preview_viewport.msaa_3d = Viewport.MSAA_2X
	container.add_child(_preview_viewport)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 0.72, 3.6)
	camera.look_at_from_position(camera.position, Vector3(0, 0.68, 0))
	camera.fov = 38.0
	_preview_viewport.add_child(camera)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, 30, 0)
	_preview_viewport.add_child(light)
	_preview_pivot = Node3D.new()
	_preview_viewport.add_child(_preview_pivot)
	columns.add_child(box)
	columns.move_child(box, 1)


func _on_preview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging_preview = event.pressed
	elif event is InputEventMouseMotion and _dragging_preview and _preview_pivot != null:
		_preview_pivot.rotation_degrees.y += event.relative.x * 0.8


func _process(delta: float) -> void:
	if visible and _preview_pivot != null and not _dragging_preview:
		_preview_pivot.rotation_degrees.y += SPIN_SPEED * delta


## Vuelve a armar el muñeco de la vista previa con lo elegido hasta ahora.
func _refresh_preview() -> void:
	if _preview_pivot == null:
		return
	if _preview_body != null:
		_preview_pivot.remove_child(_preview_body)
		_preview_body.queue_free()
	_preview_body = CharacterLook.build(_data.get("appearance", {}))
	_preview_pivot.add_child(_preview_body)


func _update_preview_name() -> void:
	pass  # El nombre no cambia el dibujo; queda para una etiqueta futura.


## La lista de colores y piezas es larga: va dentro de un recuadro con scroll
## para que la pantalla nunca se salga de los bordes en un teléfono bajo.
func _wrap_parts_in_scroll() -> void:
	var left: VBoxContainer = $Center/Panel/Columns/Left
	var scroll := ScrollContainer.new()
	scroll.name = "PartsScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 400)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(scroll)
	_parts_box.reparent(scroll, false)
	_parts_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.set_script(preload("res://ui/drag_scroll.gd"))
	scroll.set("horizontal", false)  # Se desliza de arriba hacia abajo.


func _build_part_rows() -> void:
	for child in _parts_box.get_children():
		child.queue_free()
	var appearance: Dictionary = _data.get("appearance", {})
	# Piezas intercambiables: peinado, ojos y boca (botones con el nombre).
	for key in PIECES:
		var label := Label.new()
		label.text = PIECES[key][1]
		label.add_theme_font_size_override("font_size", 17)
		_parts_box.add_child(label)
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 6)
		flow.add_theme_constant_override("v_separation", 6)
		_parts_box.add_child(flow)
		var piece_group := ButtonGroup.new()
		var current := str(appearance.get(key, CharacterLook.DEFAULT_PIECES[key]))
		for option in Catalog.character_options.get(PIECES[key][0], []):
			var button := Button.new()
			button.toggle_mode = true
			button.button_group = piece_group
			button.text = option["name"]
			button.name = "%s_%s" % [key, option["id"]]
			button.custom_minimum_size = Vector2(96, 44)
			button.add_theme_font_size_override("font_size", 16)
			button.button_pressed = option["id"] == current
			button.pressed.connect(_on_color_chosen.bind(key, option["id"]))
			flow.add_child(button)
	for part in PARTS:
		var label := Label.new()
		label.text = PARTS[part]
		label.add_theme_font_size_override("font_size", 17)
		_parts_box.add_child(label)
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 6)
		row.add_theme_constant_override("v_separation", 6)
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


## Se eligió un color (o una pieza: el valor es el id de la opción).
func _on_color_chosen(part: String, color_text: String) -> void:
	var appearance: Dictionary = _data.get("appearance", {})
	appearance[part] = color_text
	_data["appearance"] = appearance
	_refresh_preview()


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
	if _creation:
		created.emit(_data)
	else:
		EventBus.character_edit_finished.emit(_data)
