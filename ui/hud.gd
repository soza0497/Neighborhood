extends CanvasLayer
## Interfaz del juego.
##
## Arriba: FPS, reloj, velocidad, deshacer/rehacer, vista, centrar y modo.
## Izquierda: subir/bajar de piso (construir) o el panel del personaje (vivir).
## Abajo (modo construir): categorías del catálogo y sus piezas.
## Centro (modo vivir): menú de acciones al tocar un mueble.
##
## La interfaz no cambia la casa directamente: pide cosas por EventBus.
## Los botones de categorías y piezas se crean solos a partir del catálogo.

const VIEW_MODE_NAMES := ["Vista: completa", "Vista: sin techo", "Vista: paredes bajas"]
const LEVEL_NAMES := ["Planta baja", "Primer piso"]
const ITEM_BUTTON_SIZE := Vector2(150, 76)
const CATEGORY_BUTTON_SIZE := Vector2(150, 52)
## Color de cada barra de necesidad (paleta propia del juego).
const NEED_COLORS := {
	"hunger": Color("#ff9f43"),
	"energy": Color("#feca57"),
	"hygiene": Color("#54a0ff"),
	"fun": Color("#ff6b9d"),
}

@onready var _fps_label: Label = %FpsLabel
@onready var _info_label: Label = %InfoLabel
@onready var _hint_label: Label = %HintLabel
@onready var _clock_label: Label = %ClockLabel
@onready var _server_label: Label = %ServerLabel
@onready var _logout_button: Button = %LogoutButton
@onready var _speed_button: Button = %SpeedButton
@onready var _character_panel: Control = %CharacterPanel
@onready var _name_label: Label = %NameLabel
@onready var _mood_label: Label = %MoodLabel
@onready var _needs_box: VBoxContainer = %NeedsBox
@onready var _intention_label: Label = %IntentionLabel
@onready var _money_label: Label = %MoneyLabel
@onready var _xp_bar: ProgressBar = %XpBar
@onready var _builds_button: Button = %BuildsButton
@onready var _toast_box: Control = %ToastBox
@onready var _toast_label: Label = %ToastLabel
@onready var _jobs_button: Button = %JobsButton
@onready var _menu_button: Button = %MenuButton
@onready var _side_menu: Control = %SideMenu
@onready var _character_button: Button = %CharacterButton
@onready var _diary_button: Button = %DiaryButton
@onready var _fps_check: CheckButton = %FpsCheck
@onready var _hints_check: CheckButton = %HintsCheck
@onready var _side_close_button: Button = %SideCloseButton
@onready var _action_menu: Control = %ActionMenu
@onready var _menu_title: Label = %MenuTitle
@onready var _menu_buttons: VBoxContainer = %MenuButtons
@onready var _menu_close_button: Button = %MenuCloseButton
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
@onready var _confirm_button: Button = %ConfirmButton
@onready var _cancel_button: Button = %CancelButton
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
## Barras de necesidades: nombre → ProgressBar.
var _need_bars: Dictionary = {}
## Categoría que se está mostrando y nivel del jugador (para refrescar bloqueos).
var _current_category := ""
var _last_level := 0
var _toast_tween: Tween
## Lo último que dijo el historial (para volver a prender los botones después
## de esperar al servidor).
var _can_undo := false
var _can_redo := false
var _server_busy := false


func _ready() -> void:
	_item_group.allow_unpress = true

	_undo_button.pressed.connect(EventBus.undo_requested.emit)
	_redo_button.pressed.connect(EventBus.redo_requested.emit)
	_view_button.pressed.connect(EventBus.view_mode_cycle_requested.emit)
	_center_button.pressed.connect(EventBus.camera_reset_requested.emit)
	_mode_button.pressed.connect(_on_mode_button_pressed)
	_level_up_button.pressed.connect(EventBus.build_level_change_requested.emit.bind(1))
	_level_down_button.pressed.connect(EventBus.build_level_change_requested.emit.bind(-1))
	_confirm_button.pressed.connect(EventBus.build_confirm_requested.emit)
	_cancel_button.pressed.connect(EventBus.build_cancel_requested.emit)
	_rotate_button.pressed.connect(EventBus.build_rotate_requested.emit)
	_delete_button.pressed.connect(EventBus.build_delete_requested.emit)
	_erase_button.toggled.connect(EventBus.build_erase_toggled.emit)

	EventBus.game_saved.connect(_on_game_saved)
	EventBus.game_mode_changed.connect(_on_game_mode_changed)
	EventBus.build_hint.connect(_hint_label.set_text)
	EventBus.build_level_changed.connect(_on_level_changed)
	EventBus.build_selection_changed.connect(_on_selection_changed)
	EventBus.build_pending_changed.connect(_on_pending_changed)
	EventBus.view_mode_changed.connect(_on_view_mode_changed)
	EventBus.history_changed.connect(_on_history_changed)

	_speed_button.pressed.connect(GameClock.cycle_speed)
	_menu_button.pressed.connect(_side_menu.show)
	_side_close_button.pressed.connect(_side_menu.hide)
	_character_button.pressed.connect(_open_from_menu.bind(EventBus.character_editor_requested))
	_diary_button.pressed.connect(_open_from_menu.bind(EventBus.journal_requested))
	_jobs_button.pressed.connect(_open_from_menu.bind(EventBus.jobs_requested))
	_builds_button.pressed.connect(EventBus.construction_accelerate_requested.emit)
	EventBus.economy_changed.connect(_on_economy_changed)
	EventBus.toast.connect(_on_toast)
	EventBus.build_cost_changed.connect(_on_build_cost_changed)
	EventBus.construction_changed.connect(_on_construction_changed)
	_setup_xp_bar()
	var progress := Economy.xp_progress()
	_on_economy_changed(Economy.money, Economy.level(), progress.x, progress.y)
	_fps_check.button_pressed = GameState.settings.get("show_fps", true)
	_hints_check.button_pressed = GameState.settings.get("show_hints", true)
	_fps_check.toggled.connect(_on_setting_toggled.bind("show_fps"))
	_hints_check.toggled.connect(_on_setting_toggled.bind("show_hints"))
	_menu_close_button.pressed.connect(_action_menu.hide)
	_logout_button.pressed.connect(_open_from_menu.bind(EventBus.logout_requested))
	EventBus.server_status_changed.connect(_on_server_status_changed)
	EventBus.server_busy_changed.connect(_on_server_busy_changed)
	_on_server_status_changed(GameServer.online, GameServer.username())
	GameClock.speed_changed.connect(_on_speed_changed)
	EventBus.character_needs_changed.connect(_on_needs_changed)
	EventBus.character_intention_changed.connect(_on_intention_changed)
	EventBus.object_menu_requested.connect(_on_object_menu_requested)
	_create_need_bars()

	if SaveSystem.has_save():
		_last_save_text = "partida cargada"
	_update_info()
	_create_category_buttons()
	_update_object_buttons()
	_on_pending_changed(false)


func _process(_delta: float) -> void:
	_fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	_clock_label.text = "Día %d · %s" % [GameClock.day(), GameClock.time_text()]


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
	_current_category = category_id
	for child in _items_box.get_children():
		child.queue_free()
	_select_item("", "")

	# En Muebles, la primera opción es la mano para mover lo ya colocado.
	if category_id == "furniture":
		_add_item_button(HouseBuilder.MOVE_TOOL_ID, "Mover\n(mano)", Color(1, 0.85, 0.2), "move")
	# En Puertas y ventanas, la primera opción une o separa ventanas vecinas.
	if category_id == "openings":
		_add_item_button(HouseBuilder.WINDOW_JOIN_TOOL_ID, "Unir /\nseparar", Color(0.75, 0.9, 1), "window_join")
	for item in Catalog.get_items_in_category(category_id):
		var text := "%s\n$ %d" % [item["name"], int(item["price"])]
		if item["kind"] == "paint":
			text = item["name"]
		var color := Color.from_string(item.get("color", "#ffffff"), Color.WHITE)
		var unlocked := Economy.is_unlocked(item["id"])
		if not unlocked:
			text = "%s\nNivel %d" % [item["name"], Catalog.unlock_level(item["id"])]
		_add_item_button(item["id"], text, color, item["kind"]).disabled = not unlocked


func _add_item_button(item_id: String, text: String, color: Color, kind: String) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.button_group = _item_group
	button.custom_minimum_size = ITEM_BUTTON_SIZE
	button.icon = _make_swatch(color)
	button.add_theme_font_size_override("font_size", 16)
	button.toggled.connect(_on_item_toggled.bind(item_id, kind))
	_items_box.add_child(button)
	return button


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


# --- Personaje (modo vivir) ---

## Una fila por necesidad: nombre + barra de su color.
func _create_need_bars() -> void:
	for need in CharacterData.NEEDS:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = CharacterData.NEED_NAMES[need]
		label.custom_minimum_size = Vector2(92, 0)
		label.add_theme_font_size_override("font_size", 16)
		row.add_child(label)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(150, 20)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.show_percentage = false
		var background := StyleBoxFlat.new()
		background.bg_color = Color(1, 1, 1, 0.15)
		background.set_corner_radius_all(10)
		var fill := StyleBoxFlat.new()
		fill.bg_color = NEED_COLORS[need]
		fill.set_corner_radius_all(10)
		bar.add_theme_stylebox_override("background", background)
		bar.add_theme_stylebox_override("fill", fill)
		row.add_child(bar)
		_needs_box.add_child(row)
		_need_bars[need] = bar


func _on_needs_changed(needs: Dictionary, mood_text: String) -> void:
	for need in _need_bars:
		_need_bars[need].value = needs.get(need, 0.0)
	_mood_label.text = "Ánimo: " + mood_text


func _on_intention_changed(intention: Dictionary) -> void:
	_name_label.text = intention["character"]
	_intention_label.text = Character.intention_text(intention)


func _on_object_menu_requested(level: int, key: String, item_id: String) -> void:
	for child in _menu_buttons.get_children():
		child.queue_free()
	_menu_title.text = Catalog.get_item(item_id).get("name", "")
	for action in Catalog.get_item_actions(item_id):
		var button := Button.new()
		button.text = action["name"]
		button.custom_minimum_size = Vector2(240, 56)
		button.add_theme_font_size_override("font_size", 20)
		button.pressed.connect(_on_menu_action.bind(level, key, action["id"]))
		_menu_buttons.add_child(button)
	_action_menu.show()


func _on_menu_action(level: int, key: String, action_id: String) -> void:
	_action_menu.hide()
	EventBus.character_order_requested.emit(level, key, action_id)


func _on_speed_changed(speed: int) -> void:
	_speed_button.text = "x%d" % speed


# --- Dinero, nivel, avisos y obras ---

func _setup_xp_bar() -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = Color(1, 1, 1, 0.2)
	background.set_corner_radius_all(6)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#ffd166")
	fill.set_corner_radius_all(6)
	_xp_bar.add_theme_stylebox_override("background", background)
	_xp_bar.add_theme_stylebox_override("fill", fill)


func _on_economy_changed(money: int, level: int, xp_in_level: int, xp_needed: int) -> void:
	_money_label.text = "$ %d · Nivel %d" % [money, level]
	_xp_bar.max_value = maxi(xp_needed, 1)
	_xp_bar.value = xp_in_level
	# Si subió de nivel, se actualizan las piezas bloqueadas.
	if level != _last_level:
		_last_level = level
		if _current_category != "":
			_show_category(_current_category)


## Lo que cuesta (o devuelve) la selección que espera Confirmar.
func _on_build_cost_changed(cost: int) -> void:
	if cost > 0:
		_confirm_button.text = "Confirmar ($%d)" % cost
	elif cost < 0:
		_confirm_button.text = "Confirmar (+$%d)" % -cost
	else:
		_confirm_button.text = "Confirmar"
	_confirm_button.disabled = cost > Economy.money or _server_busy


func _on_toast(text: String) -> void:
	_toast_label.text = text
	_toast_box.show()
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(3.5)
	_toast_tween.tween_callback(_toast_box.hide)


func _on_construction_changed(count: int, accelerate_cost: int) -> void:
	_builds_button.visible = count > 0
	_builds_button.text = "Obras: %d · Acelerar $%d" % [count, accelerate_cost]


# --- Menú y opciones ---

## Cierra el menú y pide abrir otra ventana (personaje o diario).
func _open_from_menu(request: Signal) -> void:
	_side_menu.hide()
	request.emit()


func _on_setting_toggled(on: bool, setting: String) -> void:
	GameState.settings[setting] = on
	_apply_settings()


func _apply_settings() -> void:
	_fps_label.visible = GameState.settings.get("show_fps", true)
	_hint_label.visible = _mode == "build" and GameState.settings.get("show_hints", true)


# --- Servidor ---

## Indicador de conexión: verde con el usuario, o gris "sin conexión".
## Con cuenta y sin conexión, el botón Construir se ve apagado (tocarlo
## avisa "Sin conexión al servidor"; ver main.gd, set_mode).
func _on_server_status_changed(online: bool, username: String) -> void:
	_logout_button.visible = username != ""
	var can_build := online or not Economy.server_mode
	_mode_button.modulate = Color.WHITE if can_build or _mode == "build" else Color(1, 1, 1, 0.45)
	_mode_button.tooltip_text = "" if can_build else Economy.OFFLINE_TEXT
	_builds_button.disabled = not can_build
	if online and username != "":
		_server_label.text = "● Conectado: %s" % username
		_server_label.add_theme_color_override("font_color", Color("#7bed9f"))
	else:
		_server_label.text = "● Sin conexión" + (" (%s)" % username if username != "" else "")
		_server_label.add_theme_color_override("font_color", Color("#d0d0d0"))


# --- Avisos ---

func _on_mode_button_pressed() -> void:
	EventBus.game_mode_change_requested.emit("live" if _mode == "build" else "build")


func _on_game_mode_changed(mode: String) -> void:
	_mode = mode
	var building := mode == "build"
	_mode_button.text = "Vivir" if building else "Construir"
	_bottom_bar.visible = building
	_undo_button.visible = building
	_redo_button.visible = building
	_character_panel.visible = not building
	_speed_button.visible = not building
	_action_menu.hide()
	_side_menu.hide()
	_apply_settings()
	_on_server_status_changed(GameServer.online, GameServer.username())
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


func _on_pending_changed(has_pending: bool) -> void:
	_confirm_button.visible = has_pending
	_confirm_button.text = "Confirmar"
	_confirm_button.disabled = false
	_cancel_button.visible = has_pending


func _on_selection_changed(has_selection: bool) -> void:
	_has_selection = has_selection
	_update_object_buttons()


func _on_view_mode_changed(mode: int) -> void:
	_view_button.text = VIEW_MODE_NAMES[mode]


func _on_history_changed(can_undo: bool, can_redo: bool) -> void:
	_can_undo = can_undo
	_can_redo = can_redo
	_undo_button.disabled = not can_undo or _server_busy
	_redo_button.disabled = not can_redo or _server_busy


## Mientras se espera al servidor, los botones que cambian dinero no
## responden (así no hay dobles toques).
func _on_server_busy_changed(busy: bool) -> void:
	_server_busy = busy
	_on_history_changed(_can_undo, _can_redo)
	if _confirm_button.visible:
		_confirm_button.disabled = busy
	_builds_button.disabled = busy or (Economy.server_mode and not GameServer.online)


func _on_game_saved(success: bool) -> void:
	_last_save_text = "guardado OK" if success else "ERROR al guardar"
	_update_info()


func _update_info() -> void:
	_info_label.text = "Neighborhood %s · %s" % [
		ProjectSettings.get_setting("application/config/version"),
		_last_save_text,
	]
