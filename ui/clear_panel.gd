class_name ClearPanel
extends PanelContainer
## Panel de «Llamar al servicio» (Pulido 6B): aparece arriba, al centro, mientras hay
## obstáculos marcados en Eliminar. Muestra qué se llama, el total y cuándo llega cada tipo
## (la espera sale de data/parcel.json), y se confirma con un solo botón.
## Siempre queda dentro del área segura de la pantalla.

const WIDTH := 340.0
const BASE_MARGINS := Vector4(16, 34, 16, 22)

var planner: ClearPlanner

var _rows: VBoxContainer
var _call_button: Button
var _busy := false


func setup(new_planner: ClearPlanner) -> void:
	planner = new_planner
	name = "ClearPanel"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size.x = WIDTH
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	var title := Label.new()
	title.text = "Llamar al servicio"
	title.add_theme_font_size_override("font_size", 20)
	box.add_child(title)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 2)
	box.add_child(_rows)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	box.add_child(buttons)
	_call_button = Button.new()
	_call_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_call_button.custom_minimum_size.y = 44
	_call_button.pressed.connect(_on_call_pressed)
	buttons.add_child(_call_button)
	var cancel := Button.new()
	cancel.text = "Cancelar"
	cancel.custom_minimum_size = Vector2(96, 44)
	cancel.pressed.connect(planner.clear_selection)
	buttons.add_child(cancel)
	planner.changed.connect(refresh)
	refresh()


## Vuelve a escribir el contenido según lo marcado.
func refresh() -> void:
	if planner == null:
		return
	visible = not planner.selected.is_empty()
	for child in _rows.get_children():
		child.queue_free()
	var quote := planner.quote()
	for line in planner.summary_lines():
		var text := "%s%s · $%d · %s" % [line["name"], " ×%d" % line["count"] if int(line["count"]) > 1 else "", int(line["cost"]),
			ClearPlanner.arrival_text(int(line["seconds"]))]
		_add_row(text, Color.WHITE)
	for problem in quote["problems"]:
		_add_row("No se puede: " + str(problem["reason"]), Color(1.0, 0.75, 0.4))
	var total := int(quote["total"])
	_call_button.text = "Llamar ($%d)" % total
	_call_button.disabled = _busy or quote["items"].is_empty()
	if not quote["items"].is_empty() and Economy.money < total and not Economy.server_mode:
		_add_row("Te faltan $%d." % (total - Economy.money), Color(1.0, 0.6, 0.5))
		_call_button.disabled = true
	_fit()


func _add_row(text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color)
	_rows.add_child(label)


func _on_call_pressed() -> void:
	if _busy:
		return
	_busy = true
	_call_button.disabled = true
	await planner.confirm()
	_busy = false
	refresh()


func _process(_delta: float) -> void:
	if visible:
		_fit()


## Arriba al centro, dentro del área segura, sin salirse de la pantalla.
func _fit() -> void:
	if not is_inside_tree():
		return
	var view: Vector2 = get_viewport().get_visible_rect().size
	var margins := SafeArea.margins(BASE_MARGINS, SafeArea.insets(get_window()))
	var width := minf(WIDTH, view.x - margins.x - margins.z)
	custom_minimum_size.x = width
	size.x = width
	size.y = 0.0  # Que se ajuste al contenido.
	position.x = clampf((view.x - width) / 2.0, margins.x, maxf(margins.x, view.x - margins.z - width))
	position.y = margins.y + 70.0
	# Si no entra hacia abajo, se sube todo lo que haga falta (sin pasar el margen de arriba).
	var overflow := position.y + size.y - (view.y - margins.w)
	if overflow > 0.0:
		position.y = maxf(margins.y, position.y - overflow)
