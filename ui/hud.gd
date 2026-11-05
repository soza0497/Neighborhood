extends CanvasLayer
## Interfaz del juego (Pulido 1: pantalla casi vacía, con íconos).
##
## Arriba a la izquierda: dinero y ánimo (cara + palabra; tocarlo abre la
##   tarjeta con las necesidades), la pareja (punto + nombre) y las obras.
## Arriba a la derecha: deshacer/rehacer (construir), velocidad (vivir),
##   construir/vivir y el menú.
## Izquierda: íconos de techo, paredes y ángulo de cámara, el selector de pisos
##   (el frente de la casa, con flechas y botones de girar) y la brújula.
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
@onready var _restaurant_button: Button = %RestaurantButton
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
@onready var _bottom_bar: BuildBar = %BottomBar
@onready var _action_row: HBoxContainer = %ActionRow
@onready var _problems_button: Button = %ProblemsButton
# Fase 5: pareja y casa compartida.
@onready var _partner_chip: Control = %PartnerChip
@onready var _partner_label: Label = %PartnerLabel
@onready var _partner_info_label: Label = %PartnerInfoLabel
@onready var _fund_label: Label = %FundLabel
@onready var _couple_button: Button = %CoupleButton
@onready var _home_button: Button = %HomeButton
@onready var _neighborhood_button: Button = %NeighborhoodButton
@onready var _notice_box: Control = %NoticeBox
@onready var _notice_label: Label = %NoticeLabel
@onready var _notice_undo_button: Button = %NoticeUndoButton
@onready var _notice_close_button: Button = %NoticeCloseButton

var _mode := "build"
var _builder: Node
var _house_data: HouseData
var _boxes_button: Button
## Pulido 4B: modo desarrollador (ícono arriba y panel). Solo se ven con el interruptor de Info prendido.
var _dev_button: Button
var _dev_panel: DevPanel
var _character: Character
## Pulido 3B: barra vertical del ángulo de la cámara (debajo del menú).
var _pitch_slider: PitchSlider
## Márgenes normales de la interfaz (izquierda, arriba, derecha, abajo).
const BASE_MARGINS := Vector4(16, 34, 16, 22)
## Cuántos grados por segundo cambia el ángulo con la perilla al tope.
const PITCH_RATE := 60.0
## Contenedor de la columna izquierda: así la columna no empuja la pantalla
## fuera de sus bordes (si no cabe, se achica).
var _left_holder: Control
var _plan_bar: Control
var _last_save_text := "sin guardar todavía"
## Lo que falta en la casa (HouseRules.problems) y los paneles que se
## arman por código: menú de una pieza, lista de "lo que falta" y la barra
## de la propuesta (casa compartida).
var _problems: Array = []
var _popup: PanelContainer
var _proposal_bar: PanelContainer
## Lo último que se sabe del personaje (para la tarjeta del ánimo).
var _needs: Dictionary = {}
var _intention_text := ""
var _character_name := ""
var _toast_tween: Tween
## Lo último que dijo el historial (para volver a prender los botones después
## de esperar al servidor).
var _can_undo := false
var _can_redo := false
var _server_busy := false
## Aviso de la pareja que se está mostrando (entrada del historial que se
## puede deshacer; 0 = ninguna).
var _notice_entry := 0
var _notice_tween: Tween


func _ready() -> void:
	_setup_icons()
	_build_floor_selector()
	_build_pitch_slider()
	_build_overlay()  # Pulido 5C: los menús flotan fuera del contenedor (no empujan nada).
	_build_left_holder()
	get_viewport().size_changed.connect(_fit_to_screen)
	_fit_to_screen.call_deferred()
	_build_boxes_button()
	_build_dev_mode()
	EventBus.parcel_obstacle_tapped.connect(_show_obstacle)
	EventBus.boxes_changed.connect(_on_boxes_changed)

	_undo_button.pressed.connect(EventBus.undo_requested.emit)
	_redo_button.pressed.connect(EventBus.redo_requested.emit)
	_roof_button.pressed.connect(EventBus.view_roofs_toggle_requested.emit)
	_walls_button.pressed.connect(EventBus.view_walls_toggle_requested.emit)
	_floor_map.level_picked.connect(EventBus.build_level_set_requested.emit)
	_mode_button.pressed.connect(_on_mode_button_pressed)
	_problems_button.pressed.connect(_show_problems)
	EventBus.house_problems_changed.connect(_on_problems_changed)
	EventBus.build_context_menu.connect(_show_context_menu)
	EventBus.room_menu_requested.connect(_show_room_menu)
	EventBus.proposal_changed.connect(_on_proposal_changed)

	EventBus.game_saved.connect(_on_game_saved)
	EventBus.game_mode_changed.connect(_on_game_mode_changed)
	EventBus.build_hint.connect(_hint_label.set_text)
	EventBus.build_level_changed.connect(_on_level_changed)
	EventBus.view_changed.connect(_on_view_changed)
	EventBus.history_changed.connect(_on_history_changed)

	_speed_button.pressed.connect(GameClock.cycle_speed)
	_menu_button.pressed.connect(_toggle_side_menu)
	_side_close_button.pressed.connect(_close_side_menu)
	_character_button.pressed.connect(_open_from_menu.bind(EventBus.character_editor_requested))
	_diary_button.pressed.connect(_open_from_menu.bind(EventBus.journal_requested))
	_jobs_button.pressed.connect(_open_from_menu.bind(EventBus.jobs_requested))
	_restaurant_button.pressed.connect(_open_from_menu.bind(EventBus.restaurant_panel_requested))
	_restaurant_button.visible = Catalog.feature("player_business")  # Pulido 5A
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
	EventBus.construction_changed.connect(_on_construction_changed)
	_setup_xp_bar()
	var progress := Economy.xp_progress()
	_on_economy_changed(Economy.money, Economy.level(), progress.x, progress.y)
	_fps_check.button_pressed = GameState.settings.get("show_fps_overlay", false)
	_hints_check.button_pressed = GameState.settings.get("show_hints", true)
	_fps_check.toggled.connect(_on_setting_toggled.bind("show_fps_overlay"))
	_build_info_extras()
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
	_neighborhood_button.pressed.connect(_open_from_menu.bind(EventBus.neighborhood_panel_requested))
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
	_apply_settings()


## La escena principal pasa la casa, el personaje y el constructor (la
## maqueta de pisos y la brújula solo los leen).
func setup_house(house: HouseData, character: Node3D, builder: Node) -> void:
	_builder = builder
	_house_data = house
	_floor_map.setup(house, character)
	$RestaurantPanel.house = house
	$HomePanel.house = house
	_character = character as Character
	_compass_button.target = character
	_bottom_bar.setup(_action_row, builder, character)


## Pulido 4B: ícono del modo desarrollador junto al menú y su panel. La escena principal
## llama a `setup_dev` con la navegación y la vista de la casa.
func _build_dev_mode() -> void:
	_dev_button = Icons.make_button("dev", "Modo desarrollador")
	_dev_button.visible = DevMode.is_enabled()
	var top_buttons: Control = %MenuButton.get_parent()
	top_buttons.add_child(_dev_button)
	top_buttons.move_child(_dev_button, %MenuButton.get_index())
	_dev_panel = (load("res://ui/dev_panel.tscn") as PackedScene).instantiate()
	_dev_panel.name = "DevPanel"
	add_child(_dev_panel)
	_dev_button.pressed.connect(_dev_panel.toggle)
	EventBus.dev_mode_changed.connect(func(on: bool) -> void:
		_dev_button.visible = on)


## La escena principal pasa lo que necesita el panel para elegir cosas en el mundo.
func setup_dev(character: Character, nav: HouseNav, view: HouseView) -> void:
	_dev_panel.setup(character, nav, view)


## Pulido 2: el selector de pisos es el frente de la casa. Al lado van las
## flechas de arriba y abajo y, debajo, los botones para girarlo (8 ángulos).
func _build_floor_selector() -> void:
	# Pulido 3B: la CAJA (el cuadro translúcido) es solo para la casa en 3D; las
	# flechas de subir y bajar y los botones de girar van FUERA de ella, con un
	# color azul/verde translúcido parecido al de la caja.
	var panel: Control = _floor_map.get_parent()
	var column: Control = panel.get_parent()
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	column.add_child(outer)
	column.move_child(outer, panel.get_index())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	outer.add_child(row)
	panel.reparent(row, false)
	var arrows := VBoxContainer.new()
	arrows.alignment = BoxContainer.ALIGNMENT_CENTER
	arrows.add_theme_constant_override("separation", 10)
	for entry in [["Subir un piso", 1, 0], ["Bajar un piso", -1, 2]]:
		var button := Icons.make_button("arrow", entry[0], 48)
		button.icon = Icons.rotated("arrow", entry[2])
		button.pressed.connect(EventBus.build_level_change_requested.emit.bind(entry[1]))
		_tint_like_map(button)
		arrows.add_child(button)
	row.add_child(arrows)
	var turn := HBoxContainer.new()
	turn.alignment = BoxContainer.ALIGNMENT_CENTER
	turn.add_theme_constant_override("separation", 10)
	for entry in [["Girar la fachada a la izquierda", -1, "left"], ["Girar la fachada a la derecha", 1, "right"]]:
		var button := Icons.make_button(entry[2], entry[0], 44)
		button.pressed.connect(_floor_map.turn.bind(entry[1]))
		_tint_like_map(button)
		turn.add_child(button)
	outer.add_child(turn)
	_floor_map.owner = self  # Para que %FloorMap siga encontrándose.


## Botón del color de la caja del selector de pisos (azul/verde translúcido).
func _tint_like_map(button: Button) -> void:
	for state in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
		var style := button.get_theme_stylebox(state).duplicate() as StyleBoxFlat
		var color := Color(0.2, 0.62, 0.66, 0.5)
		if state == "hover":
			color = Color(0.27, 0.72, 0.74, 0.6)
		elif state == "pressed" or state == "hover_pressed":
			color = Color(0.35, 0.85, 0.8, 0.75)
		style.bg_color = color
		style.border_color = Color(0.4, 0.8, 1, 0.45)
		style.set_border_width_all(2)
		button.add_theme_stylebox_override(state, style)


## Pulido 6A (11): el jugador eligió un modo de contorno en Info.
func _on_outline_mode_chosen(mode: String) -> void:
	GameState.settings["outline_mode"] = mode
	GameState.settings["outline_enabled"] = mode != "off"
	Style.set_outline_mode(mode)


## Pulido 2B: en Info, el contorno (calidad) y los volúmenes de sonido.
func _build_info_extras() -> void:
	var rows: VBoxContainer = _info_panel.get_node("Rows")
	var anchor := _fps_check.get_index() + 1
	# Pulido 6A (11): contorno fino / normal / apagado (tres botones en fila).
	var outline_row := HBoxContainer.new()
	outline_row.add_theme_constant_override("separation", 8)
	var outline_label := Label.new()
	outline_label.text = "Contorno"
	outline_label.add_theme_font_size_override("font_size", 20)
	outline_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outline_row.add_child(outline_label)
	var mode_group := ButtonGroup.new()
	var mode_names := {"thin": "Fino", "normal": "Normal", "off": "Apagado"}
	for mode in Style.OUTLINE_MODES:
		var mode_button := Button.new()
		mode_button.name = "Outline_" + str(mode)
		mode_button.text = mode_names[mode]
		mode_button.toggle_mode = true
		mode_button.button_group = mode_group
		mode_button.button_pressed = (mode == Style.outline_mode)
		mode_button.focus_mode = Control.FOCUS_NONE
		mode_button.add_theme_font_size_override("font_size", 18)
		mode_button.pressed.connect(_on_outline_mode_chosen.bind(str(mode)))
		outline_row.add_child(mode_button)
	rows.add_child(outline_row)
	rows.move_child(outline_row, anchor)
	anchor += 1
	# Fase 7: comparar el arte nuevo (.glb) con las figuras simples.
	var use_models := CheckButton.new()
	use_models.text = "Usar modelos 3D (arte)"
	use_models.add_theme_font_size_override("font_size", 20)
	use_models.focus_mode = Control.FOCUS_NONE
	use_models.button_pressed = ModelLoader.enabled
	use_models.toggled.connect(func(on: bool) -> void:
		GameState.settings["use_models"] = on
		ModelLoader.set_enabled(on))
	rows.add_child(use_models)
	rows.move_child(use_models, anchor)
	anchor += 1
	# Pulido 4B: modo desarrollador (apagado por defecto; solo de este teléfono, nunca se sube).
	var dev_check := CheckButton.new()
	dev_check.text = "Modo desarrollador (probar situaciones)"
	dev_check.add_theme_font_size_override("font_size", 20)
	dev_check.focus_mode = Control.FOCUS_NONE
	dev_check.button_pressed = DevMode.is_enabled()
	dev_check.toggled.connect(func(on: bool) -> void:
		DevMode.set_enabled(on, _character))
	rows.add_child(dev_check)
	rows.move_child(dev_check, anchor)
	anchor += 1
	# Isla 1A: demo de rendimiento escondida detrás de «Herramientas de prueba».
	anchor = IslandTestEntry.add_to(rows, anchor, get_tree())
	for entry in [["master", "Volumen"], ["sfx", "Efectos"], ["music", "Música"]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var label := Label.new()
		label.text = entry[1]
		label.custom_minimum_size = Vector2(110, 0)
		label.add_theme_font_size_override("font_size", 18)
		row.add_child(label)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = Sound.volume(entry[0])
		slider.custom_minimum_size = Vector2(200, 36)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.value_changed.connect(func(v: float) -> void: Sound.set_volume(entry[0], v))
		row.add_child(slider)
		rows.add_child(row)
		rows.move_child(row, anchor)
		anchor += 1


## Pulido 2C: «Abrir todas las cajas» (aparece cuando el repartidor dejó cajas).
func _build_boxes_button() -> void:
	_boxes_button = Button.new()
	_boxes_button.icon = Icons.texture("truck")
	_boxes_button.add_theme_constant_override("icon_max_width", 30)
	_boxes_button.add_theme_font_size_override("font_size", 18)
	_boxes_button.text = "Abrir todas las cajas"
	_boxes_button.focus_mode = Control.FOCUS_NONE
	_boxes_button.visible = false
	_boxes_button.custom_minimum_size = Vector2(0, 52)
	_boxes_button.pressed.connect(EventBus.boxes_open_all_requested.emit)
	%LeftColumn.add_child(_boxes_button)


func _on_boxes_changed(dropped: int) -> void:
	_boxes_button.visible = dropped > 0
	_boxes_button.text = "Abrir todas las cajas (%d)" % dropped


## Tocaste un obstáculo de la parcela: qué es, qué servicio lo limpia, cuánto
## cuesta y cuánto tarda. «Llamar servicio» cobra (el servidor) y empieza la espera.
func _show_obstacle(id: String) -> void:
	var def := Parcel.definition(id)
	if def.is_empty():
		return
	var vehicle_names := {"tractor": "tractor", "excavator": "retroexcavadora"}
	var service_text: String = {"gardener": "Jardinero", "lumberjack": "Leñador"}.get(def["service"],
		"Cuadrilla con %s" % vehicle_names.get(def["vehicle"], "vehículo pesado"))
	var rows := _open_popup(str(def["name"]))
	if Parcel.pending.has(id):
		var left := int(Parcel.pending[id]["ready_at"]) - Economy.now()
		rows.add_child(_small_label("Ya viene: %s." % service_text, Color(0.75, 0.95, 1)))
		rows.add_child(_small_label("Llega en %s." % duration_text(maxi(left, 0)) if left > 0 else "Está por llegar (o esperando que haya paso).", Color(0.85, 0.9, 1)))
		_popup_button(rows, "Reintentar ahora", func() -> void:
			_close_popup()
			Parcel.service_due.emit(id))
	else:
		var access := Parcel.access(id, _house_data)
		var cost := Parcel.cost_of(id)
		rows.add_child(_small_label("Lo limpia: %s" % service_text, Color(0.85, 0.9, 1)))
		rows.add_child(_small_label("Cuesta $%d · Espera %s" % [cost, duration_text(int(def["seconds"]))], Color(1, 0.9, 0.7)))
		rows.add_child(_small_label("Bloquea construir en esa zona hasta limpiarlo.", Color(0.85, 0.9, 1)))
		if not access["ok"]:
			rows.add_child(_small_label("No puede llegar: %s Despejá un camino desde la calle." % str(access["reason"]), Color(1, 0.7, 0.6)))
		var call := _popup_button(rows, "Llamar servicio ($%d)" % cost, func() -> void:
			_close_popup()
			var result: Dictionary = await Parcel.call_service(id, _house_data)
			EventBus.toast.emit("Viene el servicio: %s." % service_text if result["ok"] else str(result["error"])))
		call.disabled = not access["ok"] or Economy.money < cost
	_popup_button(rows, "Cerrar", _close_popup)


## Menú del tipo de un cuarto (Pulido 3B): elegir cocina, dormitorio, baño, sala,
## estudio… y, si es un dormitorio, si es el PRINCIPAL o uno secundario. Lo
## elegido manda sobre lo que el juego deduce por los muebles.
func _show_room_menu(level: int, cell: Vector2i) -> void:
	var room := HouseRooms.room_at(_house_data, level, cell)
	if room.is_empty():
		EventBus.toast.emit("Ahí no hay un cuarto cerrado.")
		return
	var rows := _open_popup("Tipo de cuarto")
	var origin := "elegido por vos" if room.get("assigned", false) else "según los muebles"
	rows.add_child(_small_label("Ahora: %s%s (%s)" % [room["name"], " · principal" if room.get("main", false) else "", origin], Color(0.85, 0.9, 1)))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	rows.add_child(grid)
	for type in HouseRooms.choosable_types():
		var is_current: bool = room.get("assigned", false) and room["type"] == type["id"]
		var button := _popup_button(grid, ("✓ " if is_current else "") + str(type["name"]), func() -> void:
			if type["id"] == HouseRooms.BEDROOM:
				_show_bedroom_menu(room)
			else:
				_assign_room(room, str(type["id"]), false))
		button.custom_minimum_size = Vector2(200, 52)
	var auto := _popup_button(grid, "Que decida el juego", func() -> void: _assign_room(room, "", false))
	auto.custom_minimum_size = Vector2(200, 52)
	auto.disabled = not room.get("assigned", false)
	_popup_button(rows, "Cerrar", _close_popup)


## Segundo paso: ¿dormitorio principal o secundario? (solo hay un principal).
func _show_bedroom_menu(room: Dictionary) -> void:
	var rows := _open_popup("Dormitorio")
	rows.add_child(_small_label("Solo uno es el principal del personaje.", Color(0.85, 0.9, 1)))
	_popup_button(rows, "★ Principal", func() -> void: _assign_room(room, HouseRooms.BEDROOM, true))
	_popup_button(rows, "Secundario", func() -> void: _assign_room(room, HouseRooms.BEDROOM, false))
	_popup_button(rows, "Cerrar", _close_popup)


func _assign_room(room: Dictionary, type_id: String, main: bool) -> void:
	HouseRooms.set_room_type(_house_data, room, type_id, main)
	_close_popup()
	var label := "ya no tiene un tipo elegido" if type_id == "" else "ahora es %s%s" % [HouseRooms.type_name(type_id).to_lower(), " principal" if main else ""]
	EventBus.toast.emit("El cuarto %s." % label)
	EventBus.rooms_changed.emit()


## Pulido 5C: capa libre (no es un contenedor) para los menús que flotan encima de
## la interfaz: ☰, Info, tarjeta del ánimo, menú de una pieza y ventanitas. Antes
## vivían dentro de `Root` (un MarginContainer): su tamaño mínimo agrandaba a
## `Root` y corría las barras de arriba y de abajo. Aquí cada uno tiene sus anclas.
var _overlay: Control


func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.name = "Overlay"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	# Los menús son opacos (sin ver los botones de atrás).
	for menu in [_side_menu, _info_panel, _action_menu, _mood_card.get_child(0)]:
		var style := menu.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		if style != null:
			style.bg_color.a = 1.0
			menu.add_theme_stylebox_override("panel", style)
	_float_control(_side_menu, 1.0, 0.5)
	_float_control(_info_panel, 0.5, 0.5)
	_float_control(_action_menu, 0.5, 0.5)
	_float_control(_mood_card, 0.0, 0.0)
	# La barra del ángulo se acomoda sobre la fila de acciones / barra de abajo cuando cambian.
	for bar in [_bottom_bar, _action_row]:
		bar.resized.connect(_fit_to_screen.call_deferred)
		bar.visibility_changed.connect(_fit_to_screen.call_deferred)


## Saca un nodo de `Root` y lo ancla a un punto de la pantalla (0..1 en cada eje).
## Su tamaño sale de su tamaño mínimo y crece hacia adentro de la pantalla.
func _float_control(control: Control, anchor_x: float, anchor_y: float) -> void:
	control.reparent(_overlay, false)
	control.anchor_left = anchor_x
	control.anchor_right = anchor_x
	control.anchor_top = anchor_y
	control.anchor_bottom = anchor_y
	control.grow_horizontal = Control.GROW_DIRECTION_BEGIN if anchor_x >= 1.0 \
		else (Control.GROW_DIRECTION_BOTH if anchor_x > 0.0 else Control.GROW_DIRECTION_END)
	control.grow_vertical = Control.GROW_DIRECTION_BEGIN if anchor_y >= 1.0 \
		else (Control.GROW_DIRECTION_BOTH if anchor_y > 0.0 else Control.GROW_DIRECTION_END)
	control.offset_left = 0.0
	control.offset_right = 0.0
	control.offset_top = 0.0
	control.offset_bottom = 0.0


## Deja cada menú flotante a su distancia del borde (área segura incluida).
func _place_floating(margins: Vector4) -> void:
	if _overlay == null:
		return
	_side_menu.offset_left = -margins.z
	_side_menu.offset_right = -margins.z
	_mood_card.offset_left = margins.x
	_mood_card.offset_right = margins.x
	_mood_card.offset_top = margins.y
	_mood_card.offset_bottom = margins.y


## ¿Hay algún menú abierto? (la barra del ángulo se esconde para no quedar encima)
func _any_menu_open() -> bool:
	return _side_menu.visible or _action_menu.visible or _mood_card.visible or _info_panel.visible \
		or (_popup != null and is_instance_valid(_popup))


## Pulido 5C: menús exclusivos. Abrir uno cierra los demás (menos `keep`).
func _close_floating(keep: Control = null) -> void:
	if _side_menu != keep:
		_side_menu.hide()
	if _action_menu != keep:
		_action_menu.hide()
	if _info_panel != keep:
		_info_panel.hide()
	if _mood_card != keep:
		_mood_card.hide()
	if keep != _side_menu and keep != _mood_card:
		_card_overlay.hide()
	if keep != _popup:
		_close_popup()


## Barra del ángulo de la cámara (Pulido 3B): costado derecho, debajo del menú.
## Reemplaza al botón de antes (que pasaba de a saltos por 5 ángulos).
func _build_pitch_slider() -> void:
	_pitch_slider = PitchSlider.new()
	_pitch_slider.name = "PitchSlider"
	add_child(_pitch_slider)


## Pulido 3B: la columna izquierda (íconos, selector de pisos, brújula) va dentro
## de un contenedor que no le exige altura a la pantalla.
func _build_left_holder() -> void:
	var column: Control = %LeftColumn
	var middle: Control = column.get_parent()
	_left_holder = Control.new()
	_left_holder.name = "LeftHolder"
	_left_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_left_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_child(_left_holder)
	middle.move_child(_left_holder, column.get_index())
	column.reparent(_left_holder, false)
	column.set_anchors_preset(Control.PRESET_TOP_LEFT)
	column.position = Vector2.ZERO
	column.pivot_offset = Vector2.ZERO
	column.resized.connect(_fit_to_screen.call_deferred)


## Acomoda la interfaz a la pantalla (Pulido 3B): respeta el área segura, no se
## sale de los bordes en ningún tamaño y ubica la barra del ángulo.
func _fit_to_screen() -> void:
	var root: MarginContainer = $Root
	var view := get_viewport().get_visible_rect().size
	var margins := SafeArea.margins(BASE_MARGINS, SafeArea.insets(get_window()))
	root.add_theme_constant_override("margin_left", int(margins.x))
	root.add_theme_constant_override("margin_top", int(margins.y))
	root.add_theme_constant_override("margin_right", int(margins.z))
	root.add_theme_constant_override("margin_bottom", int(margins.w))
	# La columna izquierda se achica si no hay altura (pantalla baja + barra de abajo).
	if _left_holder != null:
		var column: Control = %LeftColumn
		var need := column.get_combined_minimum_size()
		_left_holder.custom_minimum_size = Vector2(need.x, 0.0)
		column.size = need
		var available := maxf(40.0, _left_holder.size.y)
		var factor := clampf(available / maxf(1.0, need.y), 0.45, 1.0)
		column.scale = Vector2(factor, factor)
		column.position = Vector2(0.0, maxf(0.0, (available - need.y * factor) / 2.0))
	_place_floating(margins)
	# Barra del ángulo: costado derecho, debajo del menú hamburguesa.
	if _pitch_slider != null:
		var menu_bottom := margins.y + float(Icons.BUTTON_SIZE) + 10.0
		# Pulido 5C: termina antes de la fila de acciones o de la barra de abajo (la que esté más arriba).
		var floor_y := view.y - margins.w - 150.0
		for bar in [_bottom_bar, _action_row]:
			if bar.is_visible_in_tree() and bar.size.y > 0.0:
				floor_y = minf(floor_y, bar.get_global_rect().position.y - 10.0)
		var height := clampf(floor_y - menu_bottom, 90.0, PitchSlider.TRACK_HEIGHT)
		_pitch_slider.position = Vector2(view.x - margins.z - PitchSlider.TRACK_WIDTH, menu_bottom)
		_pitch_slider.size = Vector2(PitchSlider.TRACK_WIDTH, height)


## Íconos propios en lugar de botones con texto (el texto queda de ayuda).
func _setup_icons() -> void:
	Icons.setup(_undo_button, "undo", "Deshacer")
	Icons.setup(_redo_button, "redo", "Rehacer")
	Icons.setup(_mode_button, "helmet", "Construir")
	Icons.setup(_menu_button, "menu", "Menú")
	Icons.setup(_roof_button, "roof_off", "Techos")
	Icons.setup(_walls_button, "walls_high", "Paredes altas o bajas")
	_problems_button.icon = Icons.texture("warning")
	_problems_button.add_theme_constant_override("icon_max_width", 30)
	Icons.setup(_notice_close_button, "close", "Cerrar", 48)
	Icons.setup(_speed_button, "speed", "Velocidad del tiempo")
	_speed_button.custom_minimum_size = Vector2(104, 64)
	_speed_button.expand_icon = false
	_speed_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_speed_button.add_theme_constant_override("icon_max_width", 26)
	_speed_button.add_theme_font_size_override("font_size", 22)
	_speed_button.text = "x%d" % GameClock.speed
	for pair in [[_character_button, "person"], [_diary_button, "diary"], [_jobs_button, "work"], [_restaurant_button, "dish"],
			[_couple_button, "heart"], [_home_button, "home"], [_neighborhood_button, "home"], [_info_button, "info"], [_logout_button, "logout"]]:
		pair[0].icon = Icons.texture(pair[1])
		pair[0].add_theme_constant_override("icon_max_width", 30)


func _process(delta: float) -> void:
	# Pulido 3B: con la perilla del ángulo desviada, la cámara sube o baja.
	if _pitch_slider != null and absf(_pitch_slider.value) > 0.05:
		EventBus.camera_pitch_step_requested.emit(_pitch_slider.value * PITCH_RATE * delta)
	if _pitch_slider != null:
		_pitch_slider.visible = not _any_menu_open()
	var fps_text := "%d FPS" % Engine.get_frames_per_second()
	if _fps_label.visible:
		_fps_label.text = fps_text
	if _info_panel.visible:
		_info_fps_label.text = fps_text
		_clock_label.text = "Día %d · %s" % [GameClock.day(), GameClock.time_text()]


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
	_close_floating(_mood_card)
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
	_side_menu.hide()


## Pulido 2: el menú hamburguesa se abre y se cierra con el mismo botón, y
## también tocando afuera (el velo transparente de atrás).
func _toggle_side_menu() -> void:
	if _side_menu.visible:
		_close_side_menu()
		return
	_close_floating(_side_menu)
	_side_menu.show()
	_card_overlay.show()


func _close_side_menu() -> void:
	_side_menu.hide()
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
	_close_floating(_action_menu)
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
	_close_side_menu()
	request.emit()


func _open_info() -> void:
	_close_floating(_info_panel)
	_close_side_menu()
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
	# Pulido 5C: al construir se ocultan el ánimo y las necesidades (quedan el dinero y el nivel).
	_mood_button.visible = not building
	_close_cards()
	_undo_button.visible = building
	_redo_button.visible = building
	_speed_button.visible = not building
	_action_menu.hide()
	_close_side_menu()
	_apply_settings()
	_on_server_status_changed(GameServer.online, GameServer.username())
	_action_row.visible = building
	_problems_button.visible = building and not _problems.is_empty()
	# Al entrar o salir de construir se empieza sin herramienta elegida.
	_bottom_bar.reset()
	_close_popup()


func _on_level_changed(level: int) -> void:
	_level_label.text = HouseGrid.level_name(level)
	_floor_map.set_level(level)


## Los dos íconos de la vista muestran cómo está: techo normal o tachado,
## pared alta o bajita.
func _on_view_changed(show_roofs: bool, low_walls: bool) -> void:
	Icons.setup(_roof_button, "roof" if show_roofs else "roof_off", "Techos: se ven" if show_roofs else "Techos: escondidos")
	Icons.setup(_walls_button, "walls_low" if low_walls else "walls_high", "Paredes bajas" if low_walls else "Paredes altas")


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


# --- Constructor 2.0: menú de una pieza, "lo que falta" y propuesta ---

## Un panel chico en el medio, armado por código (menú de una pieza o lista
## de "lo que falta"). Tocar "Cerrar" lo saca.
func _open_popup(title: String) -> VBoxContainer:
	_close_floating()
	_popup = PanelContainer.new()
	_popup.add_theme_stylebox_override("panel", _mood_card.get_child(0).get_theme_stylebox("panel"))
	_popup.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_popup.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	_popup.add_child(rows)
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 22)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(label)
	# Pulido 5C: flota en el centro de la capa libre (no en el contenedor de la interfaz).
	_overlay.add_child(_popup)
	_popup.set_anchors_preset(Control.PRESET_CENTER)
	_popup.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_popup.grow_vertical = Control.GROW_DIRECTION_BOTH
	return rows


func _close_popup() -> void:
	if _popup != null and is_instance_valid(_popup):
		_popup.queue_free()
	_popup = null


func _popup_button(rows: Control, text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(280, 56)
	button.add_theme_font_size_override("font_size", 19)
	button.pressed.connect(on_pressed)
	rows.add_child(button)
	return button


## Menú de una pared, techo, piso o cimiento (Modificar).
func _show_context_menu(title: String, options: Array) -> void:
	var rows := _open_popup(title)
	for option in options:
		_popup_button(rows, option["text"], func() -> void:
			_close_popup()
			EventBus.build_context_action_requested.emit(option["id"]))
	_popup_button(rows, "Cerrar", _close_popup)


func _on_problems_changed(problems: Array) -> void:
	_problems = problems
	_problems_button.visible = _mode == "build" and not problems.is_empty()
	_problems_button.text = "Falta: %d" % problems.size()
	_problems_button.tooltip_text = "Lo que falta o está mal en la casa"


## Lista de "lo que falta": lo que está sin apoyo o sin acceso (en rojo).
func _show_problems() -> void:
	var rows := _open_popup("Lo que falta")
	for p in _problems:
		var label := _small_label("• " + str(p["text"]), Color(1, 0.8, 0.7))
		rows.add_child(label)
	rows.add_child(_small_label("Lo que tiene problemas se ve en rojo.", Color(0.85, 0.9, 1)))
	_popup_button(rows, "Cerrar", _close_popup)


## Barra de la propuesta (casa compartida): la que armo yo (mandar o
## descartar) o la de mi pareja (aprobar, no aprobar o cerrar).
func _on_proposal_changed(mode: String, summary: Dictionary) -> void:
	if _proposal_bar != null and is_instance_valid(_proposal_bar):
		_proposal_bar.queue_free()
	_proposal_bar = null
	if mode == "":
		return
	_proposal_bar = PanelContainer.new()
	_proposal_bar.add_theme_stylebox_override("panel", _mood_card.get_child(0).get_theme_stylebox("panel"))
	_proposal_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_proposal_bar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_proposal_bar.add_child(row)
	var partner := Couple.partner_name()
	var cost := int(summary.get("cost", 0))
	var cost_text := (" · $%d" % cost) if cost > 0 else ((" · +$%d" % -cost) if cost < 0 else "")
	if mode == "plan":
		row.add_child(_small_label("Obra prevista: %d paso%s%s" % [int(summary.get("steps", 0)), "" if int(summary.get("steps", 0)) == 1 else "s", cost_text], Color(0.75, 0.95, 1)))
		var invoice_button := _bar_button("Factura", _show_invoice)
		invoice_button.icon = Icons.texture("invoice")
		invoice_button.add_theme_constant_override("icon_max_width", 26)
		row.add_child(invoice_button)
		row.add_child(_bar_button("Descartar", EventBus.plan_discard_requested.emit))
	elif mode == "own":
		row.add_child(_small_label("Propuesta: %d cambios%s" % [int(summary.get("steps", 0)), cost_text], Color(1, 0.9, 0.7)))
		row.add_child(_bar_button("Mandar a %s" % partner, EventBus.proposal_send_requested.emit))
		row.add_child(_bar_button("Descartar", EventBus.proposal_discard_requested.emit))
	else:
		var request: Dictionary = get_tree().current_scene.get_node("House/Builder").review_request() \
			if get_tree().current_scene.has_node("House/Builder") else {}
		row.add_child(_small_label("Propuesta de %s: %s" % [str(request.get("by_name", partner)), str(request.get("text", ""))], Color(1, 0.85, 0.92)))
		row.add_child(_bar_button("Aprobar", EventBus.proposal_answer_requested.emit.bind(true)))
		row.add_child(_bar_button("No", EventBus.proposal_answer_requested.emit.bind(false)))
		row.add_child(_bar_button("Cerrar", EventBus.proposal_close_requested.emit))
	var box := MarginContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	box.add_theme_constant_override("margin_top", 150)
	box.add_child(_proposal_bar)
	$Root.add_child(box)
	_proposal_bar.tree_exited.connect(box.queue_free)


func _bar_button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 52)
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(on_pressed)
	return button


# --- Factura de la obra planificada (Pulido 2) ---

## Resumen tipo factura de todo lo previsto: qué se agrega y cuánto cuesta.
## Confirmar → se cobra y corre el tiempo de espera (en pareja, antes la
## aprueba ella). Seguir planeando la cierra sin cambiar nada.
func _show_invoice() -> void:
	if _builder == null:
		return
	var invoice: Dictionary = _builder.plan_invoice()
	var rows := _open_popup("Factura de obra")
	for line in invoice["lines"]:
		var row := HBoxContainer.new()
		var name_label := _small_label("%d × %s" % [line["qty"], line["name"]])
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		row.add_child(_small_label("$ %d" % line["cost"], Color(1, 0.9, 0.7)))
		rows.add_child(row)
	rows.add_child(HSeparator.new())
	var total := int(invoice["total"])
	var total_text := "Total: $ %d" % total if total >= 0 else "Te devuelven: $ %d" % -total
	var total_label := _small_label(total_text, Color(1, 0.95, 0.6))
	total_label.add_theme_font_size_override("font_size", 22)
	rows.add_child(total_label)
	if int(invoice["seconds"]) > 0:
		rows.add_child(_small_label("Espera hasta que termine: %s" % duration_text(int(invoice["seconds"])), Color(0.85, 0.9, 1)))
	_popup_button(rows, "Confirmar y construir", func() -> void:
		_close_popup()
		EventBus.plan_confirm_requested.emit())
	_popup_button(rows, "Seguir planeando", _close_popup)
	_popup_button(rows, "Descartar el plan", func() -> void:
		_close_popup()
		EventBus.plan_discard_requested.emit())


## "45 s", "3 min", "1 h 20 min" para los tiempos de espera.
static func duration_text(seconds: int) -> String:
	if seconds < 60:
		return "%d s" % seconds
	if seconds < 3600:
		return "%d min" % ceili(seconds / 60.0)
	return "%d h %d min" % [seconds / 3600, (seconds % 3600) / 60]
