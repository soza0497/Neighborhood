class_name BuildBar
extends PanelContainer
## Barra de abajo del modo construir (Pulido 1: constructor 2.0).
##
## Tres herramientas, con nombres, íconos y orden propios:
##   1. Tienda (bolsa): muebles, electrodomésticos, electrónica, plantas y
##      adornos. Primero lo que recomienda el cuarto que se está mirando.
##   2. Obra (casco), con dos modos:
##        Agregar: cimientos, pisos, paredes, puertas, ventanas, techos,
##                 escaleras y pilares (+ "Copiar contorno de abajo").
##        Modificar: tocar algo para moverlo, girarlo, pintarlo o borrarlo
##                 (abajo, los colores de pintura).
##   3. Borrar (basurero), con "modo selección" para borrar varias cosas.
##
## Encima de la barra, a la derecha (ActionRow), van los botones que sirven
## en ese momento: flechas N/S/E/O, girar y borrar lo elegido, las flechas de
## la pintura, copiar contorno y el modo selección.
##
## No toca la casa: pide todo por EventBus (y lee el constructor para saber
## en qué cuarto se está, para la Tienda).

const SHOP_CATEGORIES := ["furniture", "appliances", "electronics", "plants", "decor", "restaurant"]
const BUILD_CATEGORIES := ["structure", "openings", "roofs", "stairs"]
const RECOMMENDED := "__recommended__"
const ITEM_BUTTON_SIZE := Vector2(150, 76)
const CATEGORY_BUTTON_SIZE := Vector2(0, 56)
const ACTION_SIZE := 60

## "shop", "build" o "erase" ("" = ninguna).
var tool := ""
## En Obra: "add" o "modify".
var build_mode := "add"
var current_category := ""

var _builder: Node
var _character: Node3D
var _action_row: HBoxContainer
var _tool_buttons: Dictionary = {}
var _mode_buttons: Dictionary = {}
var _tool_group := ButtonGroup.new()
var _mode_group := ButtonGroup.new()
var _category_group := ButtonGroup.new()
var _item_group := ButtonGroup.new()
var _actions: Dictionary = {}
## Tipo ("kind") de la pieza elegida (para mostrar "girar").
var _selected_kind := ""
var _has_selection := false
var _paint_arrows := false
var _pending := false
var _needs_approval := false
var _server_busy := false
var _confirm_label := ""
var _last_level := 0
var _room: Dictionary = {}

@onready var _tool_box: HBoxContainer = %ToolButtons
@onready var _sub_modes: HBoxContainer = %SubModes
@onready var _categories_box: HBoxContainer = %Categories
@onready var _items_box: HBoxContainer = %Items
@onready var _item_scroll: Control = %ItemScroll
@onready var _confirm_button: Button = %ConfirmButton
@onready var _cancel_button: Button = %CancelButton


func _ready() -> void:
	_item_group.allow_unpress = true
	_tool_group.allow_unpress = true
	for entry in [["shop", "shop", "Tienda"], ["build", "helmet", "Obra"], ["erase", "trash", "Borrar"]]:
		var button := Icons.make_button(entry[1], entry[2], 56, true)
		button.button_group = _tool_group
		button.toggled.connect(_on_tool_toggled.bind(entry[0]))
		_tool_box.add_child(button)
		_tool_buttons[entry[0]] = button
	var separator := VSeparator.new()
	_sub_modes.add_child(separator)
	for entry in [["add", "plus", "Agregar"], ["modify", "hand", "Modificar"]]:
		var button := Icons.make_button(entry[1], entry[2], 56, true)
		button.button_group = _mode_group
		button.toggled.connect(func(on: bool) -> void:
			if on:
				_set_build_mode(entry[0]))
		_sub_modes.add_child(button)
		_mode_buttons[entry[0]] = button
	_mode_buttons["add"].button_pressed = true
	Icons.setup(_cancel_button, "close", "Cancelar", 56)
	_confirm_button.pressed.connect(EventBus.build_confirm_requested.emit)
	_cancel_button.pressed.connect(EventBus.build_cancel_requested.emit)

	EventBus.build_selection_changed.connect(func(on: bool) -> void:
		_has_selection = on
		_update_actions())
	EventBus.build_paint_arrows.connect(func(on: bool) -> void:
		_paint_arrows = on
		_update_actions())
	EventBus.build_pending_changed.connect(_on_pending_changed)
	EventBus.build_cost_changed.connect(_on_cost_changed)
	EventBus.build_approval_changed.connect(func(needed: bool) -> void: _needs_approval = needed)
	EventBus.build_confirm_label.connect(func(text: String) -> void:
		_confirm_label = text
		_confirm_button.text = text)
	EventBus.build_level_changed.connect(func(_level: int) -> void:
		_update_actions()
		if tool == "shop":
			_show_category(current_category))
	EventBus.economy_changed.connect(_on_economy_changed)
	EventBus.server_busy_changed.connect(func(busy: bool) -> void:
		_server_busy = busy
		if _confirm_button.visible:
			_confirm_button.disabled = busy)
	_on_pending_changed(false)


## El HUD pasa la fila de acciones (encima de la barra), el constructor y el
## personaje (para saber el cuarto).
func setup(action_row: HBoxContainer, builder: Node, character: Node3D) -> void:
	_action_row = action_row
	_builder = builder
	_character = character
	_create_actions()
	_update_actions()


## Al entrar a construir se empieza sin herramienta (se ve todo limpio).
func reset() -> void:
	for button in _tool_buttons.values():
		button.set_pressed_no_signal(false)
	_set_tool("")


func _create_actions() -> void:
	if _action_row == null:
		return
	for entry in [["copy", "copy_outline", "Copiar contorno de abajo", EventBus.build_copy_outline_requested.emit],
			["paint_left", "left", "Pintar la pared de la izquierda", EventBus.build_paint_step_requested.emit.bind(-1)],
			["paint_right", "right", "Pintar la pared de la derecha", EventBus.build_paint_step_requested.emit.bind(1)],
			["O", "arrow", "Correr al oeste", EventBus.build_nudge_requested.emit.bind("O")],
			["N", "arrow", "Correr al norte", EventBus.build_nudge_requested.emit.bind("N")],
			["S", "arrow", "Correr al sur", EventBus.build_nudge_requested.emit.bind("S")],
			["E", "arrow", "Correr al este", EventBus.build_nudge_requested.emit.bind("E")],
			["rotate", "rotate45", "Girar", EventBus.build_rotate_requested.emit],
			["delete", "trash", "Borrar", EventBus.build_delete_requested.emit]]:
		var button := Icons.make_button(entry[1], entry[2], ACTION_SIZE)
		button.pressed.connect(entry[3])
		_action_row.add_child(button)
		_actions[entry[0]] = button
	# Las flechas cardinales: el mismo ícono girado (N arriba, E derecha...).
	for pair in [["N", 0.0], ["E", 90.0], ["S", 180.0], ["O", 270.0]]:
		_actions[pair[0]].icon = _rotated_arrow(pair[1])
	var multi := Icons.make_button("select", "Modo selección: borrar varias cosas", ACTION_SIZE, true)
	multi.toggled.connect(EventBus.build_erase_multi_toggled.emit)
	_action_row.add_child(multi)
	_actions["multi"] = multi


## Qué botones se ven según la herramienta y lo elegido.
func _update_actions() -> void:
	if _actions.is_empty():
		return
	var level: int = _builder.level if _builder != null else 0
	var modifying := tool == "build" and build_mode == "modify"
	var placing := _selected_kind in ["furniture", "stairs", "pillar"] and not modifying
	_actions["copy"].visible = tool == "build" and build_mode == "add" and level > 0
	_actions["paint_left"].visible = modifying and _paint_arrows
	_actions["paint_right"].visible = modifying and _paint_arrows
	for direction in ["N", "S", "E", "O"]:
		_actions[direction].visible = modifying and _has_selection
	_actions["rotate"].visible = (modifying and _has_selection) or placing
	_actions["delete"].visible = modifying and _has_selection
	_actions["multi"].visible = tool == "erase"
	if tool != "erase" and _actions["multi"].button_pressed:
		_actions["multi"].button_pressed = false


# --- Herramientas ---

func _on_tool_toggled(on: bool, id: String) -> void:
	if on:
		_set_tool(id)
	elif _tool_group.get_pressed_button() == null:
		_set_tool("")


func _set_tool(id: String) -> void:
	tool = id
	_sub_modes.visible = id == "build"
	_select_item("", "")
	match id:
		"shop":
			_fill_categories(SHOP_CATEGORIES, true)
		"build":
			_set_build_mode(build_mode)
			return
		"erase":
			_fill_categories([], false)
			EventBus.build_item_selected.emit(HouseBuilder.ERASE_TOOL_ID)
		_:
			_fill_categories([], false)
			EventBus.build_item_selected.emit("")
	_update_actions()


func _set_build_mode(mode: String) -> void:
	build_mode = mode
	if tool != "build":
		return
	_select_item("", "")
	if mode == "add":
		_fill_categories(BUILD_CATEGORIES, false)
	else:
		_fill_categories([], false)
		EventBus.build_item_selected.emit(HouseBuilder.MODIFY_TOOL_ID)
		_show_paints()
	_update_actions()


## Pestañas de categorías (y en la Tienda, "Para este cuarto" primero).
func _fill_categories(ids: Array, with_recommended: bool) -> void:
	for child in _categories_box.get_children():
		child.queue_free()
	for child in _items_box.get_children():
		child.queue_free()
	_item_scroll.visible = not ids.is_empty()
	current_category = ""
	if ids.is_empty():
		return
	var tabs: Array = ids.duplicate()
	if with_recommended:
		_room = _builder.room_here(_character.get("level") if _character != null else -1,
			_character.get("cell") if _character != null else Vector2i(-1, -1)) if _builder != null else {}
		if not _room.is_empty() and not HouseRooms.recommended_items(_room).is_empty():
			tabs.push_front(RECOMMENDED)
	var first := true
	for id in tabs:
		var button := Button.new()
		button.text = _category_name(id)
		button.toggle_mode = true
		button.button_group = _category_group
		button.custom_minimum_size = CATEGORY_BUTTON_SIZE
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 16)
		button.pressed.connect(_show_category.bind(id))
		_categories_box.add_child(button)
		if first:
			button.button_pressed = true
			_show_category(id)
			first = false


func _category_name(id: String) -> String:
	if id == RECOMMENDED:
		return "★ %s" % _room.get("name", "Este cuarto")
	return Catalog.categories.get(id, {}).get("name", id)


## Llena la fila de piezas con las de una categoría. En la Tienda, lo que
## recomienda el cuarto va primero (con ★). Nunca se esconde nada.
func _show_category(category_id: String) -> void:
	if category_id == "":
		return
	current_category = category_id
	for child in _items_box.get_children():
		child.queue_free()
	_select_item("", "")
	var recommended: Array = HouseRooms.recommended_items(_room) if tool == "shop" else []
	var items: Array = []
	if category_id == RECOMMENDED:
		for id in recommended:
			if not Catalog.get_item(id).is_empty():
				items.append(Catalog.get_item(id))
	else:
		items = Catalog.get_items_in_category(category_id)
		items.sort_custom(func(a, b) -> bool:
			var ra := recommended.find(a["id"])
			var rb := recommended.find(b["id"])
			ra = 999 if ra < 0 else ra
			rb = 999 if rb < 0 else rb
			return ra < rb)
	for item in items:
		var text := "%s\n$ %d" % [item["name"], int(item["price"])]
		if recommended.has(item["id"]) and category_id != RECOMMENDED:
			text = "★ " + text
		var unlocked := Economy.is_unlocked(item["id"])
		if not unlocked:
			text = "%s\nNivel %d" % [item["name"], Catalog.unlock_level(item["id"])]
		var color := Color.from_string(item.get("color", "#ffffff"), Color.WHITE)
		_add_item_button(item["id"], text, color, item["kind"]).disabled = not unlocked


## En Modificar: los colores de pintura (tocar uno = pintar con ese color).
func _show_paints() -> void:
	_item_scroll.visible = true
	for item in Catalog.get_items_in_category("paint"):
		var color := Color.from_string(item.get("color", "#ffffff"), Color.WHITE)
		_add_item_button(item["id"], item["name"], color, "paint")


func _add_item_button(item_id: String, text: String, color: Color, kind: String) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.button_group = _item_group
	button.custom_minimum_size = ITEM_BUTTON_SIZE if kind != "paint" else Vector2(130, 64)
	button.focus_mode = Control.FOCUS_NONE
	button.icon = _make_swatch(color)
	button.add_theme_font_size_override("font_size", 15)
	button.toggled.connect(_on_item_toggled.bind(item_id, kind))
	_items_box.add_child(button)
	return button


func _on_item_toggled(on: bool, item_id: String, kind: String) -> void:
	if on:
		_select_item(item_id, kind)
	elif _item_group.get_pressed_button() == null:
		# Sin pieza elegida: en Modificar se vuelve a la mano.
		_select_item("", "")
		if tool == "build" and build_mode == "modify":
			EventBus.build_item_selected.emit(HouseBuilder.MODIFY_TOOL_ID)


func _select_item(item_id: String, kind: String) -> void:
	_selected_kind = kind
	if item_id != "" or tool == "shop" or (tool == "build" and build_mode == "add"):
		EventBus.build_item_selected.emit(item_id)
	_update_actions()


## Cuadradito de color para el ícono de cada pieza.
static func _make_swatch(color: Color) -> ImageTexture:
	var image := Image.create(28, 28, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.1, 0.1, 0.1))
	image.fill_rect(Rect2i(2, 2, 24, 24), color)
	return ImageTexture.create_from_image(image)


## La flecha del ícono, girada (para N, E, S, O).
static func _rotated_arrow(degrees: float) -> Texture2D:
	var image := Icons.texture("arrow").get_image()
	if image.is_compressed():
		image.decompress()
	var turns := int(degrees / 90.0) % 4
	for i in turns:
		image.rotate_90(CLOCKWISE)
	return ImageTexture.create_from_image(image)


# --- Confirmar y cancelar ---

func _on_pending_changed(has_pending: bool) -> void:
	_pending = has_pending
	_confirm_button.visible = has_pending
	_cancel_button.visible = has_pending
	_confirm_label = ""
	_confirm_button.text = "Confirmar"
	_confirm_button.disabled = false


## Lo que cuesta (o devuelve) la selección que espera Confirmar.
func _on_cost_changed(cost: int) -> void:
	if _confirm_label != "":
		_confirm_button.text = _confirm_label
	else:
		var verb := "A la propuesta" if _needs_approval else "Confirmar"
		if cost > 0:
			_confirm_button.text = "%s ($%d)" % [verb, cost]
		elif cost < 0:
			_confirm_button.text = "%s (+$%d)" % [verb, -cost]
		else:
			_confirm_button.text = verb
	_confirm_button.disabled = (not _needs_approval and not Economy.can_change(-cost)) or _server_busy


func _on_economy_changed(_money: int, level: int, _xp_in_level: int, _xp_needed: int) -> void:
	# Si subió de nivel, se actualizan las piezas bloqueadas.
	if level != _last_level:
		_last_level = level
		if current_category != "" and is_inside_tree():
			_show_category(current_category)
