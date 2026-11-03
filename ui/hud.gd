extends CanvasLayer
## Interfaz del juego.
##
## Arriba: FPS, deshacer/rehacer, vista de paredes, centrar y cambio de modo.
## Izquierda: subir/bajar de piso (modo construir).
## Abajo (modo construir): categorías del catálogo y sus piezas.
##
## La interfaz no cambia la casa directamente: pide cosas por EventBus.
## Los botones de categorías y piezas se crean solos a partir del catálogo.

const VIEW_MODE_NAMES := ["Vista: completa", "Vista: sin techo", "Vista: paredes bajas"]
const LEVEL_NAMES := ["Planta baja", "Primer piso"]
const ITEM_BUTTON_SIZE := Vector2(150, 76)
const CATEGORY_BUTTON_SIZE := Vector2(150, 52)

@onready var _fps_label: Label = %FpsLabel
@onready var _info_label: Label = %InfoLabel
@onready var _hint_label: Label = %HintLabel
@onready var _undo_button: Button = %UndoButton
@onready var _redo_button: Button = %RedoButton
@onready var _view_button: Button = %ViewButton
@onready var _center_button: Button = %CenterButton
@onready var _mode_button: Button = %ModeButton
@onready var _level_panel: Control = %LevelPanel
@onready var _level_label: Label = %LevelLabel
@onready var _level_up_button: Button = %LevelUpButton
@onready var _level_down_button: Button = %LevelDownButton
@onready var _bottom_bar: Control = %BottomBar
@onready var _categories_box: HBoxContainer = %Categories
@onready var _items_box: HBoxContainer = %Items
@onready var _rotate_button: Button = %RotateButton
@onready var _delete_button: Button = %DeleteButton
@onready var _erase_button: Button = %EraseButton

var _mode := "build"
var _last_save_text := "sin guardar todavía"
var _category_group := ButtonGroup.new()
var _item_group := ButtonGroup.new()
## Tipo ("kind") de la pieza elegida, para saber si mostrar "Girar".
var _selected_kind := ""
var _has_selection := false


func _ready() -> void:
	_item_group.allow_unpress = true

	_undo_button.pressed.connect(EventBus.undo_requested.emit)
	_redo_button.pressed.connect(EventBus.redo_requested.emit)
	_view_button.pressed.connect(EventBus.view_mode_cycle_requested.emit)
	_center_button.pressed.connect(EventBus.camera_reset_requested.emit)
	_mode_button.pressed.connect(_on_mode_button_pressed)
	_level_up_button.pressed.connect(EventBus.build_level_change_requested.emit.bind(1))
	_level_down_button.pressed.connect(EventBus.build_level_change_requested.emit.bind(-1))
	_rotate_button.pressed.connect(EventBus.build_rotate_requested.emit)
	_delete_button.pressed.connect(EventBus.build_delete_requested.emit)
	_erase_button.toggled.connect(EventBus.build_erase_toggled.emit)

	EventBus.game_saved.connect(_on_game_saved)
	EventBus.game_mode_changed.connect(_on_game_mode_changed)
	EventBus.build_hint.connect(_hint_label.set_text)
	EventBus.build_level_changed.connect(_on_level_changed)
	EventBus.build_selection_changed.connect(_on_selection_changed)
	EventBus.view_mode_changed.connect(_on_view_mode_changed)
	EventBus.history_changed.connect(_on_history_changed)

	if SaveSystem.has_save():
		_last_save_text = "partida cargada"
	_update_info()
	_create_category_buttons()
	_update_object_buttons()


func _process(_delta: float) -> void:
	_fps_label.text = "%d FPS" % Engine.get_frames_per_second()


# --- Categorías y piezas ---

func _create_category_buttons() -> void:
	var first := true
	for category in Catalog.categories.values():
		var button := Button.new()
		button.text = category["name"]
		button.toggle_mode = true
		button.button_group = _category_group
		button.custom_minimum_size = CATEGORY_BUTTON_SIZE
		button.add_theme_font_size_override("font_size", 18)
		button.pressed.connect(_show_category.bind(category["id"]))
		_categories_box.add_child(button)
		if first:
			button.button_pressed = true
			_show_category(category["id"])
			first = false


## Llena la fila de piezas con las de una categoría.
func _show_category(category_id: String) -> void:
	for child in _items_box.get_children():
		child.queue_free()
	_select_item("", "")

	# En Muebles, la primera opción es la mano para mover lo ya colocado.
	if category_id == "furniture":
		_add_item_button(HouseBuilder.MOVE_TOOL_ID, "Mover\n(mano)", Color(1, 0.85, 0.2), "move")
	for item in Catalog.get_items_in_category(category_id):
		var text := "%s\n$ %d" % [item["name"], int(item["price"])]
		if item["kind"] == "paint":
			text = item["name"]
		var color := Color.from_string(item.get("color", "#ffffff"), Color.WHITE)
		_add_item_button(item["id"], text, color, item["kind"])


func _add_item_button(item_id: String, text: String, color: Color, kind: String) -> void:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.button_group = _item_group
	button.custom_minimum_size = ITEM_BUTTON_SIZE
	button.icon = _make_swatch(color)
	button.add_theme_font_size_override("font_size", 16)
	button.toggled.connect(_on_item_toggled.bind(item_id, kind))
	_items_box.add_child(button)


func _on_item_toggled(on: bool, item_id: String, kind: String) -> void:
	if on:
		_select_item(item_id, kind)
	elif _item_group.get_pressed_button() == null:
		_select_item("", "")


func _select_item(item_id: String, kind: String) -> void:
	_selected_kind = kind
	EventBus.build_item_selected.emit(item_id)
	_update_object_buttons()


## Cuadradito de color para el ícono de cada pieza.
func _make_swatch(color: Color) -> ImageTexture:
	var image := Image.create(28, 28, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.1, 0.1, 0.1))
	image.fill_rect(Rect2i(2, 2, 24, 24), color)
	return ImageTexture.create_from_image(image)


## "Girar" y "Quitar" solo aparecen cuando sirven.
func _update_object_buttons() -> void:
	var placing_object := _selected_kind == "furniture" or _selected_kind == "stairs"
	_rotate_button.visible = placing_object or _has_selection
	_delete_button.visible = _has_selection


# --- Avisos ---

func _on_mode_button_pressed() -> void:
	EventBus.game_mode_change_requested.emit("live" if _mode == "build" else "build")


func _on_game_mode_changed(mode: String) -> void:
	_mode = mode
	var building := mode == "build"
	_mode_button.text = "Vivir" if building else "Construir"
	_bottom_bar.visible = building
	_level_panel.visible = building
	_hint_label.visible = building
	_undo_button.visible = building
	_redo_button.visible = building
	if not building:
		# Al volver a construir se empieza sin pieza elegida.
		var pressed := _item_group.get_pressed_button()
		if pressed != null:
			pressed.button_pressed = false
		_erase_button.button_pressed = false


func _on_level_changed(level: int) -> void:
	_level_label.text = LEVEL_NAMES[level] if level < LEVEL_NAMES.size() else "Piso %d" % level
	_level_down_button.disabled = level <= 0
	_level_up_button.disabled = level >= HouseGrid.MAX_LEVELS - 1


func _on_selection_changed(has_selection: bool) -> void:
	_has_selection = has_selection
	_update_object_buttons()


func _on_view_mode_changed(mode: int) -> void:
	_view_button.text = VIEW_MODE_NAMES[mode]


func _on_history_changed(can_undo: bool, can_redo: bool) -> void:
	_undo_button.disabled = not can_undo
	_redo_button.disabled = not can_redo


func _on_game_saved(success: bool) -> void:
	_last_save_text = "guardado OK" if success else "ERROR al guardar"
	_update_info()


func _update_info() -> void:
	_info_label.text = "Neighborhood %s · %s" % [
		ProjectSettings.get_setting("application/config/version"),
		_last_save_text,
	]
