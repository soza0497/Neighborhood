class_name DevPanel
extends Control
## Panel del modo desarrollador (Pulido 4B). Se abre y se cierra con su ícono (arriba, junto
## al menú); queda a la derecha, debajo de los botones, para no tapar los controles normales.
##
## Pestañas:
##   Acción    → tocá un mueble, una puerta o el suelo y elegí: ir hasta ahí, usarlo o un accidente.
##   Atención  → deslizador de 0 a 1 y botones rápidos (distraído, desorbitado, recién levantado).
##   Peligros  → tocar el suelo para poner (o quitar) charcos, calor y desniveles.
##   Estados   → comida, energía, limpieza y diversión; teletransportar; congelar la IA; la hora.
## Abajo: el registro corto de lo que el personaje decidió y por qué.
##
## Toda la lógica está en scripts/debug/dev_mode.gd; esto solo es la interfaz. NADA de dinero,
## experiencia ni propiedad. Con el modo apagado no se ve ni funciona nada.

## true mientras el panel está abierto en modo vivir: los toques en el mundo son para elegir
## (el LiveController no abre su menú de acciones).
static var picking := false

const PANEL_WIDTH := 372.0
## Los mismos márgenes que usa el HUD (izquierda, arriba, derecha, abajo).
const BASE_MARGINS := Vector4(16, 34, 16, 22)
const TAP_MAX_MOVE := 14.0
const TAP_MAX_TIME := 0.35
const HOURS := [6, 9, 13, 19, 23]
const ACCIDENT_BUTTONS := ["fall", "trip", "burn"]

var character: Character
var nav: HouseNav
var view: HouseView

var _panel: PanelContainer
var _tabs: TabContainer
var _target_label: Label
var _target_box: VBoxContainer
var _mode_label: Label
var _attention_slider: HSlider
var _attention_label: Label
var _need_sliders: Dictionary = {}
var _freeze_check: CheckButton
var _time_label: Label
var _hazard_buttons: Dictionary = {}
var _log_label: Label
var _float_log: Label
var _game_mode := "live"
## Qué hace un toque en el mundo: "inspect" (elegir), "teleport" (llevar al personaje) o
## "hazard" (poner o quitar un peligro del tipo elegido).
var _pick_mode := "inspect"
var _hazard_kind := "wet"
var _last_target: Dictionary = {}
var _press_pos := Vector2.ZERO
var _press_time := 0.0
var _pressed := false
var _refresh_timer := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	visible = false
	_panel.visible = false
	EventBus.dev_mode_changed.connect(_on_dev_mode_changed)
	EventBus.game_mode_changed.connect(func(mode: String) -> void:
		_game_mode = mode
		_update_picking())
	EventBus.dev_log.connect(func(_text: String) -> void: _refresh_log())
	EventBus.character_accident.connect(func(_k: String, _l: int, _c: Vector2i, _r: String) -> void: _refresh_log())
	EventBus.character_intention_changed.connect(_on_intention_changed)
	get_viewport().size_changed.connect(_fit)
	_fit.call_deferred()
	_on_dev_mode_changed(DevMode.is_enabled())


func setup(new_character: Character, new_nav: HouseNav, new_view: HouseView) -> void:
	character = new_character
	nav = new_nav
	view = new_view
	_sync_from_character()


# --- Abrir y cerrar ---

func is_open() -> bool:
	return _panel != null and _panel.visible


func open() -> void:
	if not DevMode.is_enabled():
		return
	_panel.visible = true
	_sync_from_character()
	_refresh_log()
	_fit()
	_update_picking()


func close() -> void:
	_panel.visible = false
	_set_pick_mode("inspect")
	_update_picking()


func toggle() -> void:
	if is_open():
		close()
	else:
		open()


func _on_dev_mode_changed(on: bool) -> void:
	visible = on
	if not on:
		_panel.visible = false
		_pick_mode = "inspect"
		_last_target = {}
		if _freeze_check != null:
			_freeze_check.set_pressed_no_signal(false)
	_update_picking()
	_refresh_log()


func _update_picking() -> void:
	picking = DevMode.is_enabled() and is_open() and _game_mode == "live"


# --- Armado de la interfaz ---

func _build() -> void:
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.13, 0.2, 0.93)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	_panel.add_child(rows)
	var head := HBoxContainer.new()
	rows.add_child(head)
	var title := _label("Modo desarrollador", 20, Color(1, 0.85, 0.5))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close_button := Icons.make_button("close", "Cerrar el panel", 44)
	close_button.pressed.connect(close)
	head.add_child(close_button)

	_tabs = TabContainer.new()
	_tabs.custom_minimum_size = Vector2(PANEL_WIDTH - 20.0, 250)
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_theme_font_size_override("font_size", 16)
	rows.add_child(_tabs)
	_build_action_tab()
	_build_attention_tab()
	_build_hazards_tab()
	_build_states_tab()

	rows.add_child(_label("Registro", 15, Color(0.7, 0.8, 1)))
	_log_label = _label("", 13, Color(0.9, 0.95, 1))
	_log_label.custom_minimum_size = Vector2(PANEL_WIDTH - 20.0, 96)
	rows.add_child(_log_label)

	# Registro flotante (las últimas 2 líneas) cuando el panel está cerrado.
	_float_log = _label("", 14, Color(1, 0.92, 0.7))
	_float_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_float_log.add_theme_color_override("font_outline_color", Color(0.1, 0.15, 0.25))
	_float_log.add_theme_constant_override("outline_size", 6)
	add_child(_float_log)


## Una pestaña con scroll (el contenido puede ser largo en pantallas bajas).
func _tab(tab_name: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = tab_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	scroll.add_child(box)
	return box


func _build_action_tab() -> void:
	var box := _tab("Acción")
	box.add_child(_label("Tocá un mueble, una puerta o el suelo del mundo y elegí qué pasa.", 14, Color(0.8, 0.9, 1)))
	_mode_label = _label("", 14, Color(1, 0.9, 0.6))
	box.add_child(_mode_label)
	_target_label = _label("Nada elegido todavía.", 16)
	box.add_child(_target_label)
	_target_box = VBoxContainer.new()
	_target_box.add_theme_constant_override("separation", 6)
	box.add_child(_target_box)


func _build_attention_tab() -> void:
	var box := _tab("Atención")
	box.add_child(_label("Con atención alta el personaje esquiva los peligros; con atención baja no los esquiva y le pasa el accidente.", 14, Color(0.8, 0.9, 1)))
	_attention_label = _label("", 17)
	box.add_child(_attention_label)
	_attention_slider = HSlider.new()
	_attention_slider.min_value = 0.0
	_attention_slider.max_value = 1.0
	_attention_slider.step = 0.05
	_attention_slider.custom_minimum_size = Vector2(0, 40)
	_attention_slider.value_changed.connect(func(value: float) -> void:
		if character != null and DevMode.is_enabled():
			character.attention = value
		_update_attention_label())
	_attention_slider.drag_ended.connect(func(_changed: bool) -> void:
		DevMode.set_attention(character, _attention_slider.value)
		_refresh_log())
	box.add_child(_attention_slider)
	var row := HFlowContainer.new()
	box.add_child(row)
	for preset in HazardMap.presets():
		var id: String = preset["id"]
		row.add_child(_button("%s (%.2f)" % [preset["name"], float(preset["value"])], func() -> void:
			DevMode.apply_attention_preset(character, id)
			_sync_from_character()))
	row.add_child(_button("Atento (1.0)", func() -> void:
		DevMode.set_attention(character, 1.0)
		_sync_from_character()))
	box.add_child(_label("Los botones solo ponen un número de atención; el juego los usará después con sus propias reglas.", 12, Color(0.7, 0.75, 0.85)))


func _build_hazards_tab() -> void:
	var box := _tab("Peligros")
	box.add_child(_label("Elegí un tipo, apretá «Poner peligros» y tocá el suelo. Tocar un peligro del mismo tipo lo quita.", 14, Color(0.8, 0.9, 1)))
	var row := HFlowContainer.new()
	box.add_child(row)
	var group := ButtonGroup.new()
	for kind in HazardMap.kinds():
		var info := HazardMap.kind_info(kind)
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.text = "%s → %s" % [info["name"], str(HazardMap.accident_info(HazardMap.accident_for(kind)).get("name", "")).to_lower()]
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(0, 48)
		button.add_theme_color_override("font_color", HazardMap.color_of(kind).lightened(0.3))
		button.add_theme_color_override("font_pressed_color", HazardMap.color_of(kind).lightened(0.5))
		button.button_pressed = kind == _hazard_kind
		button.pressed.connect(func() -> void: _hazard_kind = kind)
		row.add_child(button)
		_hazard_buttons[kind] = button
	var arm := _button("Poner peligros (tocar el suelo)", func() -> void: _set_pick_mode("hazard"))
	box.add_child(arm)
	box.add_child(_button("Terminar", func() -> void: _set_pick_mode("inspect")))
	box.add_child(_button("Quitar todos los peligros", func() -> void:
		DevMode.clear_hazards()
		_refresh_log()))
	box.add_child(_label("Charco = caerse · Caliente = quemarse · Desnivel = tropezar.", 12, Color(0.7, 0.75, 0.85)))


func _build_states_tab() -> void:
	var box := _tab("Estados")
	for need in CharacterData.NEEDS:
		var row := HBoxContainer.new()
		box.add_child(row)
		var label := _label(CharacterData.NEED_NAMES[need], 15)
		label.custom_minimum_size = Vector2(86, 0)
		row.add_child(label)
		var slider := HSlider.new()
		slider.min_value = CharacterData.NEED_FLOOR
		slider.max_value = 100.0
		slider.step = 5.0
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size = Vector2(0, 36)
		slider.drag_ended.connect(func(_changed: bool) -> void:
			DevMode.set_need(character, need, slider.value)
			_refresh_log())
		row.add_child(slider)
		_need_sliders[need] = slider
	box.add_child(_button("Teletransportar (tocar el suelo)", func() -> void: _set_pick_mode("teleport")))
	_freeze_check = CheckButton.new()
	_freeze_check.text = "Congelar la IA"
	_freeze_check.focus_mode = Control.FOCUS_NONE
	_freeze_check.add_theme_font_size_override("font_size", 17)
	_freeze_check.toggled.connect(func(on: bool) -> void:
		var result := DevMode.set_frozen(character, on)
		if not result["ok"]:
			_freeze_check.set_pressed_no_signal(not on)
		_refresh_log())
	box.add_child(_freeze_check)
	_time_label = _label("", 15)
	box.add_child(_time_label)
	var hours := HFlowContainer.new()
	box.add_child(hours)
	for hour in HOURS:
		hours.add_child(_button("%d:00" % hour, func() -> void:
			DevMode.advance_to_hour(hour)
			_refresh_log()))
	box.add_child(_label("La hora siempre avanza (hasta la próxima vez que sea esa hora). El dinero, la experiencia y la propiedad no se pueden tocar desde acá: los decide el servidor.", 12, Color(0.7, 0.75, 0.85)))


func _label(text: String, size := 16, color := Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 48)
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(on_pressed)
	return button


# --- Posición (respeta el área segura) ---

## Panel a la derecha, debajo de los botones de arriba y a la izquierda de la barra del
## ángulo de la cámara; nunca se sale de la pantalla.
func _fit() -> void:
	if _panel == null:
		return
	var screen := get_viewport().get_visible_rect().size
	var margins := SafeArea.margins(BASE_MARGINS, SafeArea.insets(get_window()))
	var top := margins.y + float(Icons.BUTTON_SIZE) + 10.0
	var width := minf(PANEL_WIDTH, screen.x - margins.x - margins.z - 16.0)
	var right_edge := screen.x - margins.z - PitchSlider.TRACK_WIDTH - 12.0
	var left := clampf(right_edge - width, margins.x, maxf(margins.x, screen.x - margins.z - width))
	var height := maxf(160.0, screen.y - top - margins.w - 8.0)
	_panel.position = Vector2(left, top)
	_panel.size = Vector2(width, 0.0)
	_panel.custom_minimum_size = Vector2(width, 0.0)
	_tabs.custom_minimum_size = Vector2(width - 20.0, clampf(height - 190.0, 120.0, 300.0))
	_panel.size = Vector2(width, minf(_panel.get_combined_minimum_size().y, height))
	_float_log.position = Vector2(margins.x + 190.0, screen.y - margins.w - 62.0)
	_float_log.size = Vector2(minf(560.0, screen.x - margins.x - margins.z - 200.0), 50.0)


# --- Toques en el mundo ---

func _unhandled_input(event: InputEvent) -> void:
	if not picking:
		return
	var position_2d := Vector2.ZERO
	var down := false
	if event is InputEventScreenTouch:
		if event.index != 0:
			_pressed = false
			return
		position_2d = event.position
		down = event.pressed
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		position_2d = event.position
		down = event.pressed
	else:
		return
	if down:
		_pressed = true
		_press_pos = position_2d
		_press_time = Time.get_ticks_msec() / 1000.0
	elif _pressed:
		_pressed = false
		var quick := Time.get_ticks_msec() / 1000.0 - _press_time <= TAP_MAX_TIME
		if quick and position_2d.distance_to(_press_pos) <= TAP_MAX_MOVE:
			handle_world_tap(position_2d)


## Un toque corto en el mundo (también se llama desde las pruebas).
func handle_world_tap(screen_pos: Vector2) -> void:
	if not DevMode.is_enabled() or view == null:
		return
	var camera := get_viewport().get_camera_3d()
	match _pick_mode:
		"hazard":
			apply_hazard_tap(DevMode.pick_floor(view, camera, screen_pos))
		"teleport":
			var floor_target := DevMode.pick_floor(view, camera, screen_pos)
			if floor_target.is_empty():
				return
			DevMode.teleport(character, floor_target["level"], floor_target["cell"])
			_set_pick_mode("inspect")
			_refresh_log()
		_:
			show_target(DevMode.pick_target(view, nav, camera, screen_pos))


## Poner o quitar un peligro en el suelo tocado.
func apply_hazard_tap(floor_target: Dictionary) -> void:
	if floor_target.is_empty():
		return
	var level: int = floor_target["level"]
	var cell: Vector2i = floor_target["cell"]
	if HazardMap.kind_at(level, cell) == _hazard_kind:
		DevMode.remove_hazard(level, cell)
	else:
		DevMode.add_hazard(level, cell, _hazard_kind)
	_refresh_log()


func _set_pick_mode(mode: String) -> void:
	_pick_mode = mode
	match mode:
		"hazard":
			_tabs.current_tab = 2
			_mode_label.text = "Tocá el suelo: pone o quita «%s»." % str(HazardMap.kind_info(_hazard_kind).get("name", "")).to_lower()
		"teleport":
			_mode_label.text = "Tocá el suelo para llevar al personaje."
		_:
			_mode_label.text = ""
	_refresh_log()


## Muestra qué se tocó y los botones de lo que se puede forzar ahí.
func show_target(target: Dictionary) -> void:
	_last_target = target
	for child in _target_box.get_children():
		child.queue_free()
	_tabs.current_tab = 0
	if target.is_empty():
		_target_label.text = "Ahí no hay nada de la casa."
		return
	var level: int = target["level"]
	var cell: Vector2i = target["cell"]
	_target_label.text = "Elegido: %s · %s (%d, %d)" % [target["name"], HouseGrid.level_name(level).to_lower(), cell.x, cell.y]
	_target_box.add_child(_button("Ir hasta ahí", func() -> void: _report(DevMode.force_go(character, level, cell))))
	if target["kind"] == "object":
		for action in Catalog.get_item_actions(str(target["item"])):
			var action_id: String = action["id"]
			_target_box.add_child(_button("Usarlo: %s" % str(action.get("name", action_id)), func() -> void:
				_report(DevMode.force_use(character, level, str(target["key"]), action_id))))
	_target_box.add_child(_label("Accidente en ese lugar:", 14, Color(1, 0.8, 0.6)))
	var row := HFlowContainer.new()
	_target_box.add_child(row)
	for kind in ACCIDENT_BUTTONS:
		row.add_child(_button(str(HazardMap.accident_info(kind).get("name", kind)), func() -> void:
			_report(DevMode.force_accident(character, kind, level, cell))))
	if target["kind"] == "floor":
		for kind in HazardMap.kinds():
			_target_box.add_child(_button("Poner «%s» acá" % str(HazardMap.kind_info(kind).get("name", kind)).to_lower(), func() -> void:
				DevMode.add_hazard(level, cell, kind)
				_refresh_log()))
		_target_box.add_child(_button("Quitar el peligro de acá", func() -> void:
			DevMode.remove_hazard(level, cell)
			_refresh_log()))
		_target_box.add_child(_button("Teletransportar acá", func() -> void:
			DevMode.teleport(character, level, cell)
			_refresh_log()))


## Si lo forzado no se pudo, lo dice en el registro.
func _report(result: Dictionary) -> void:
	if not result["ok"]:
		DevMode.log_line("No se pudo: %s" % result["reason"])
	_refresh_log()


# --- Registro y valores en pantalla ---

func _sync_from_character() -> void:
	if character == null or character.data == null or _attention_slider == null:
		return
	_attention_slider.set_value_no_signal(character.attention)
	_update_attention_label()
	for need in _need_sliders:
		(_need_sliders[need] as HSlider).set_value_no_signal(float(character.data.needs.get(need, 50.0)))
	_freeze_check.set_pressed_no_signal(character.ai_frozen)


func _update_attention_label() -> void:
	var value := _attention_slider.value
	_attention_label.text = "Atención: %.2f — %s" % [value, "esquiva los peligros" if HazardMap.is_careful(value) else "NO esquiva los peligros"]


func _on_intention_changed(intention: Dictionary) -> void:
	if not DevMode.is_enabled() or character == null:
		return
	var reason := character.last_reason
	DevMode.log_line("Decidió: %s%s" % [Character.intention_text(intention), (" — " + reason) if reason != "" else ""])


func _refresh_log() -> void:
	if _log_label == null:
		return
	var lines := DevMode.recent_log()
	var shown: Array = lines.slice(maxi(0, lines.size() - 5))
	var text := "\n".join(shown)
	if character != null and not character.last_accident.is_empty():
		text += "\nÚltimo accidente: %s — %s" % [HazardMap.accident_info(character.last_accident["kind"]).get("name", ""), character.last_accident["reason"]]
	_log_label.text = text
	_float_log.text = "\n".join(lines.slice(maxi(0, lines.size() - 2)))
	_float_log.visible = DevMode.is_enabled() and not is_open() and _game_mode == "live"


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = 0.5
		if _time_label != null:
			_time_label.text = "Hora del juego: día %d · %s" % [GameClock.day(), GameClock.time_text()]
		if is_open() and character != null and character.data != null:
			for need in _need_sliders:
				(_need_sliders[need] as HSlider).set_value_no_signal(float(character.data.needs.get(need, 50.0)))
