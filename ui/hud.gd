extends CanvasLayer
## Interfaz del juego (Pulido 1: pantalla casi vacía, con íconos).
##
## Arriba a la izquierda: dinero y ánimo (cara + palabra; tocarlo abre la
##   tarjeta con las necesidades), la pareja (punto + nombre) y las obras.
## Arriba a la derecha: deshacer/rehacer (construir), velocidad (vivir),
##   construir/vivir y el menú.
## Izquierda: íconos de techo y paredes, la maqueta de pisos y la brújula.
## Abajo (modo construir): las herramientas y sus piezas.
## Menú lateral: personaje, diario, empleos, pareja, casa e Info (FPS,
##   versión, conexión, día y hora, caja de la casa).
##
## La interfaz no cambia la casa directamente: pide cosas por EventBus.
## Los botones de categorías y piezas se crean solos a partir del catálogo.

const LEVEL_NAMES := ["Planta baja", "Piso 1", "Piso 2", "Piso 3", "Piso 4"]
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
@onready var _info_fps_label: Label = %InfoFpsLabel
@onready var _info_label: Label = %InfoLabel
@onready var _hint_label: Label = %HintLabel
@onready var _clock_label: Label = %ClockLabel
@onready var _server_label: Label = %ServerLabel
@onready var _logout_button: Button = %LogoutButton
@onready var _speed_button: Button = %SpeedButton
@onready var _mood_button: Control = %MoodButton
@onready var _mood_face: MoodFace = %MoodFace
@onready var _mood_label: Label = %MoodLabel
@onready var _mood_card: Control = %MoodCard
@onready var _mood_rows: VBoxContainer = %Rows
@onready var _card_overlay: Control = %CardOverlay
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
@onready var _info_button: Button = %InfoButton
@onready var _info_panel: Control = %InfoPanel
@onready var _info_close_button: Button = %InfoCloseButton
@onready var _fps_check: CheckButton = %FpsCheck
@onready var _hints_check: CheckButton = %HintsCheck
@onready var _side_close_button: Button = %SideCloseButton
@onready var _action_menu: Control = %ActionMenu
@onready var _menu_title: Label = %MenuTitle
@onready var _menu_buttons: VBoxContainer = %MenuButtons
@onready var _menu_close_button: Button = %MenuCloseButton
@onready var _undo_button: Button = %UndoButton
@onready var _redo_button: Button = %RedoButton
@onready var _mode_button: Button = %ModeButton
@onready var _roof_button: Button = %RoofButton
@onready var _walls_button: Button = %WallsButton
@onready var _floor_map: FloorMap = %FloorMap
@onready var _level_label: Label = %LevelLabel
@onready var _compass_button: CompassButton = %CompassButton
@onready var _bottom_bar: Control = %BottomBar
@onready var _categories_box: HBoxContainer = %Categories
@onready var _items_box: HBoxContainer = %Items
@onready var _confirm_button: Button = %ConfirmButton
@onready var _cancel_button: Button = %CancelButton
@onready var _rotate_button: Button = %RotateButton
@onready var _delete_button: Button = %DeleteButton
@onready var _erase_button: Button = %EraseButton
# Fase 5: pareja y casa compartida.
@onready var _partner_chip: Control = %PartnerChip
@onready var _partner_label: Label = %PartnerLabel
@onready var _partner_info_label: Label = %PartnerInfoLabel
@onready var _fund_label: Label = %FundLabel
@onready var _couple_button: Button = %CoupleButton
@onready var _home_button: Button = %HomeButton
@onready var _notice_box: Control = %NoticeBox
@onready var _notice_label: Label = %NoticeLabel
@onready var _notice_undo_button: Button = %NoticeUndoButton
@onready var _notice_close_button: Button = %NoticeCloseButton

var _mode := "build"
var _last_save_text := "sin guardar todavía"
var _category_group := ButtonGroup.new()
var _item_group := ButtonGroup.new()
## Tipo ("kind") de la pieza elegida, para saber si mostrar "Girar".
var _selected_kind := ""
var _has_selection := false
## Lo último que se sabe del personaje (para la tarjeta del ánimo).
var _needs: Dictionary = {}
var _intention_text := ""
var _character_name := ""
## Categoría que se está mostrando y nivel del jugador (para refrescar bloqueos).
var _current_category := ""
var _last_level := 0
var _toast_tween: Tween
## Lo último que dijo el historial (para volver a prender los botones después
## de esperar al servidor).
var _can_undo := false
var _can_redo := false
var _server_busy := false
## Aviso de la pareja que se está mostrando (entrada del historial que se
## puede deshacer; 0 = ninguna).
var _notice_entry := 0
## La selección que espera Confirmar necesita aprobación (casa compartida).
var _needs_approval := false
var _notice_tween: Tween


func _ready() -> void:
	_item_group.allow_unpress = true
	_setup_icons()

	_undo_button.pressed.connect(EventBus.undo_requested.emit)
	_redo_button.pressed.connect(EventBus.redo_requested.emit)
	_roof_button.pressed.connect(EventBus.view_roofs_toggle_requested.emit)
	_walls_button.pressed.connect(EventBus.view_walls_toggle_requested.emit)
	_floor_map.level_picked.connect(EventBus.build_level_set_requested.emit)
	_mode_button.pressed.connect(_on_mode_button_pressed)
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
	EventBus.view_changed.connect(_on_view_changed)
	EventBus.history_changed.connect(_on_history_changed)

	_speed_button.pressed.connect(GameClock.cycle_speed)
	_menu_button.pressed.connect(_side_menu.show)
	_side_close_button.pressed.connect(_side_menu.hide)
	_character_button.pressed.connect(_open_from_menu.bind(EventBus.character_editor_requested))
	_diary_button.pressed.connect(_open_from_menu.bind(EventBus.journal_requested))
	_jobs_button.pressed.connect(_open_from_menu.bind(EventBus.jobs_requested))
	_info_button.pressed.connect(_open_info)
	_info_close_button.pressed.connect(_info_panel.hide)
	_builds_button.pressed.connect(EventBus.construction_accelerate_requested.emit)
	_mood_button.gui_input.connect(func(event: InputEvent) -> void:
		if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
				or (event is InputEventScreenTouch and event.pressed):
			_toggle_mood_card())
	_card_overlay.gui_input.connect(_on_overlay_input)
	EventBus.economy_changed.connect(_on_economy_changed)
	EventBus.toast.connect(_on_toast)
	EventBus.build_cost_changed.connect(_on_build_cost_changed)
	EventBus.build_approval_changed.connect(func(needed: bool) -> void: _needs_approval = needed)
	EventBus.construction_changed.connect(_on_construction_changed)
	_setup_xp_bar()
	var progress := Economy.xp_progress()
	_on_economy_changed(Economy.money, Economy.level(), progress.x, progress.y)
	_fps_check.button_pressed = GameState.settings.get("show_fps_overlay", false)
	_hints_check.button_pressed = GameState.settings.get("show_hints", true)
	_fps_check.toggled.connect(_on_setting_toggled.bind("show_fps_overlay"))
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
	# Fase 5
	_couple_button.pressed.connect(_open_from_menu.bind(EventBus.couple_panel_requested))
	_home_button.pressed.connect(_open_from_menu.bind(EventBus.home_panel_requested))
	EventBus.couple_changed.connect(_update_partner_label)
	EventBus.partner_presence_changed.connect(func(_online: bool, _intention: Dictionary) -> void: _update_partner_label())
	EventBus.fund_changed.connect(_on_fund_changed)
	EventBus.partner_notice.connect(_on_partner_notice)
	_notice_undo_button.pressed.connect(_on_notice_undo)
	_notice_close_button.pressed.connect(_notice_box.hide)
	_update_partner_label()
	_on_fund_changed(Economy.shared, Economy.fund)

	if SaveSystem.has_save():
		_last_save_text = "partida cargada"
	_update_info()
	_create_category_buttons()
	_update_object_buttons()
	_on_pending_changed(false)
	_apply_settings()


## La escena principal pasa la casa, el personaje y el constructor (la
## maqueta de pisos y la brújula solo los leen).
func setup_house(house: HouseData, character: Node3D, _builder: Node) -> void:
	_floor_map.setup(house, character)
	_compass_button.target = character


## Íconos propios en lugar de botones con texto (el texto queda de ayuda).
func _setup_icons() -> void:
	Icons.setup(_undo_button, "undo", "Deshacer")
	Icons.setup(_redo_button, "redo", "Rehacer")
	Icons.setup(_mode_button, "helmet", "Construir")
	Icons.setup(_menu_button, "menu", "Menú")
	Icons.setup(_roof_button, "roof_off", "Techos")
	Icons.setup(_walls_button, "walls_high", "Paredes altas o bajas")
	Icons.setup(_cancel_button, "close", "Cancelar", 56)
	Icons.setup(_rotate_button, "rotate", "Girar", 56)
	Icons.setup(_delete_button, "trash", "Quitar", 56)
	Icons.setup(_erase_button, "trash", "Modo borrar", 56)
	Icons.setup(_notice_close_button, "close", "Cerrar", 48)
	Icons.setup(_speed_button, "speed", "Velocidad del tiempo")
	_speed_button.custom_minimum_size = Vector2(104, 64)
	_speed_button.expand_icon = false
	_speed_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_speed_button.add_theme_constant_override("icon_max_width", 26)
	_speed_button.add_theme_font_size_override("font_size", 22)
	_speed_button.text = "x%d" % GameClock.speed
	for pair in [[_character_button, "person"], [_diary_button, "diary"], [_jobs_button, "work"],
			[_couple_button, "heart"], [_home_button, "home"], [_info_button, "info"], [_logout_button, "logout"]]:
		pair[0].icon = Icons.texture(pair[1])
		pair[0].add_theme_constant_override("icon_max_width", 30)


func _process(_delta: float) -> void:
	var fps_text := "%d FPS" % Engine.get_frames_per_second()
	if _fps_label.visible:
		_fps_label.text = fps_text
	if _info_panel.visible:
		_info_fps_label.text = fps_text
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


# --- Personaje: ánimo y tarjeta de necesidades ---

func _on_needs_changed(needs: Dictionary, mood_text: String) -> void:
	_needs = needs
	_mood_label.text = mood_text
	_mood_face.emotion = CharacterData.emotion_for(needs)
	if _mood_card.visible:
		_fill_mood_card()


func _on_intention_changed(intention: Dictionary) -> void:
	_character_name = str(intention.get("character", ""))
	_intention_text = Character.intention_text(intention)
	if _mood_card.visible:
		_fill_mood_card()


func _toggle_mood_card() -> void:
	if _mood_card.visible:
		_close_cards()
		return
	_fill_mood_card()
	_mood_card.show()
	_card_overlay.show()


## Tocar afuera de la tarjeta la cierra.
func _on_overlay_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		_close_cards()
		_card_overlay.accept_event()


func _close_cards() -> void:
	_mood_card.hide()
	_card_overlay.hide()


## La tarjeta: nombre, qué hace, las necesidades (ícono + barra) y qué está
## afectando el ánimo (emociones activas y su motivo).
func _fill_mood_card() -> void:
	for child in _mood_rows.get_children():
		child.queue_free()
	var title := Label.new()
	title.text = "%s · %s" % [_character_name, _mood_label.text] if _character_name != "" else _mood_label.text
	title.add_theme_font_size_override("font_size", 22)
	_mood_rows.add_child(title)
	if _intention_text != "":
		_mood_rows.add_child(_small_label("Ahora: " + _intention_text, Color(0.85, 0.9, 1)))
	for need in CharacterData.NEEDS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var icon := TextureRect.new()
		icon.texture = Icons.texture("need_" + need)
		icon.custom_minimum_size = Vector2(36, 36)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.tooltip_text = CharacterData.NEED_NAMES[need]
		row.add_child(icon)
		row.add_child(_need_bar(need, float(_needs.get(need, 0.0))))
		_mood_rows.add_child(row)
	_mood_rows.add_child(_small_label("Qué afecta el ánimo:", Color(1, 0.88, 0.6)))
	for factor in CharacterData.mood_factors(_needs):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var face := MoodFace.new()
		face.emotion = factor["emotion"]
		face.custom_minimum_size = Vector2(28, 28)
		row.add_child(face)
		row.add_child(_small_label(factor["text"]))
		_mood_rows.add_child(row)


func _need_bar(need: String, value: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(300, 22)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.show_percentage = false
	bar.value = value
	var background := StyleBoxFlat.new()
	background.bg_color = Color(1, 1, 1, 0.15)
	background.set_corner_radius_all(11)
	var fill := StyleBoxFlat.new()
	fill.bg_color = NEED_COLORS[need]
	fill.set_corner_radius_all(11)
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


static func _small_label(text: String, color := Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", color)
	return label


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
	background.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#ffd166")
	fill.set_corner_radius_all(4)
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
	var verb := "Pedir permiso" if _needs_approval else "Confirmar"
	if cost > 0:
		_confirm_button.text = "%s ($%d)" % [verb, cost]
	elif cost < 0:
		_confirm_button.text = "%s (+$%d)" % [verb, -cost]
	else:
		_confirm_button.text = verb
	_confirm_button.disabled = not Economy.can_change(-cost) or _server_busy


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


# --- Menú, Info y opciones ---

## Cierra el menú y pide abrir otra ventana (personaje o diario).
func _open_from_menu(request: Signal) -> void:
	_side_menu.hide()
	request.emit()


func _open_info() -> void:
	_side_menu.hide()
	_update_info()
	_update_partner_label()
	_clock_label.text = "Día %d · %s" % [GameClock.day(), GameClock.time_text()]
	_info_panel.show()


func _on_setting_toggled(on: bool, setting: String) -> void:
	GameState.settings[setting] = on
	_apply_settings()


func _apply_settings() -> void:
	_fps_label.visible = GameState.settings.get("show_fps_overlay", false)
	_hint_label.visible = _mode == "build" and GameState.settings.get("show_hints", true)


# --- Servidor ---

## Indicador de conexión (en Info): verde con el usuario, o gris "sin
## conexión". Con cuenta y sin conexión, el botón Construir se ve apagado
## (tocarlo avisa "Sin conexión al servidor"; ver main.gd, set_mode).
func _on_server_status_changed(online: bool, username: String) -> void:
	_logout_button.visible = username != ""
	var can_build := online or not Economy.server_mode
	_mode_button.modulate = Color.WHITE if can_build or _mode == "build" else Color(1, 1, 1, 0.45)
	_mode_button.tooltip_text = ("Vivir" if _mode == "build" else "Construir") if can_build else Economy.OFFLINE_TEXT
	_builds_button.disabled = not can_build
	if online and username != "":
		_server_label.text = "● Conectado: %s" % username
		_server_label.add_theme_color_override("font_color", Color("#7bed9f"))
	else:
		_server_label.text = "● Sin conexión" + (" (%s)" % username if username != "" else "")
		_server_label.add_theme_color_override("font_color", Color("#d0d0d0"))


# --- Modos, pisos y vista ---

func _on_mode_button_pressed() -> void:
	EventBus.game_mode_change_requested.emit("live" if _mode == "build" else "build")


func _on_game_mode_changed(mode: String) -> void:
	_mode = mode
	var building := mode == "build"
	Icons.setup(_mode_button, "live" if building else "helmet", "Vivir" if building else "Construir")
	_bottom_bar.visible = building
	_undo_button.visible = building
	_redo_button.visible = building
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
	_floor_map.set_level(level)


## Los dos íconos de la vista muestran cómo está: techo normal o tachado,
## pared alta o bajita.
func _on_view_changed(show_roofs: bool, low_walls: bool) -> void:
	Icons.setup(_roof_button, "roof" if show_roofs else "roof_off", "Techos: se ven" if show_roofs else "Techos: escondidos")
	Icons.setup(_walls_button, "walls_low" if low_walls else "walls_high", "Paredes bajas" if low_walls else "Paredes altas")


func _on_pending_changed(has_pending: bool) -> void:
	_confirm_button.visible = has_pending
	_confirm_button.text = "Confirmar"
	_confirm_button.disabled = false
	_cancel_button.visible = has_pending


func _on_selection_changed(has_selection: bool) -> void:
	_has_selection = has_selection
	_update_object_buttons()


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


# --- Pareja (Fase 5) ---

## Arriba, chico: un punto de color (en línea o no) y el nombre. El texto
## largo (qué hace su personaje) va en Info.
func _update_partner_label() -> void:
	var in_couple := Couple.in_couple()
	_partner_chip.visible = in_couple
	_partner_info_label.visible = in_couple
	if not in_couple:
		return
	var name := Couple.partner_name()
	var text := "Pareja: %s " % name
	if Couple.partner_online:
		text += "● en línea"
		var intention := Couple.partner_intention
		if not intention.is_empty():
			text += " · " + str(intention.get("verb", ""))
			if str(intention.get("object", "")) != "":
				text += " (%s)" % intention["object"]
		_partner_label.text = "● " + name
		_partner_label.add_theme_color_override("font_color", Color("#ffb3d1"))
	else:
		text += "○ fuera de línea"
		_partner_label.text = "○ " + name
		_partner_label.add_theme_color_override("font_color", Color("#d0c0c8"))
	_partner_info_label.text = text
	_partner_chip.tooltip_text = text


func _on_fund_changed(shared: bool, fund: int) -> void:
	_fund_label.visible = shared
	_fund_label.text = "Caja de la casa: $ %d" % fund


## La pareja cambió algo: aviso arriba con "Deshacer" (si se puede).
func _on_partner_notice(text: String, entry_id: int) -> void:
	_notice_label.text = text
	_notice_entry = entry_id
	_notice_undo_button.visible = entry_id > 0
	_notice_undo_button.disabled = false
	_notice_box.show()
	if _notice_tween != null:
		_notice_tween.kill()
	_notice_tween = create_tween()
	_notice_tween.tween_interval(8.0)
	_notice_tween.tween_callback(_notice_box.hide)


func _on_notice_undo() -> void:
	if _notice_entry <= 0:
		return
	_notice_undo_button.disabled = true
	var result: Dictionary = await Couple.revert(_notice_entry)
	if result["ok"]:
		_notice_box.hide()
	else:
		_notice_undo_button.disabled = false


func _on_game_saved(success: bool) -> void:
	_last_save_text = "guardado OK" if success else "ERROR al guardar"
	_update_info()


func _update_info() -> void:
	_info_label.text = "Neighborhood %s · %s" % [
		ProjectSettings.get_setting("application/config/version"),
		_last_save_text,
	]
