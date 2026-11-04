class_name NeighborhoodController
extends Node
## Maneja la vista del barrio (Fase 8B): vista aérea con la MISMA cámara
## táctil/mouse, visitar la casa de un vecino en modo solo ver y volver.
##
## Estados: "" (en mi casa), "aerial" (mirando todo el barrio) y "visit"
## (en el lote de un vecino). En "aerial" y "visit" el juego queda en el modo
## "visit" de la escena principal: no hay constructor ni se puede cambiar nada,
## y la interfaz normal se esconde. Solo se muestra una barrita con «Volver».
##
## Lo crea la escena principal (main.gd) y le pasa `main_node`.

## Inclinación y zoom de la vista aérea y de una visita.
const AERIAL_PITCH := -55.0
const AERIAL_DISTANCE := 125.0
const AERIAL_FOCUS := Vector3(0.0, 0.0, 28.0)
const VISIT_PITCH := -62.0
const VISIT_DISTANCE := 26.0
## Niebla ampliada para ver las casas lejanas.
const FOG_BEGIN := 260.0
const FOG_END := 780.0

var state := ""
var lot_id := ""

var main  # La escena principal (main.gd); sin tipo para poder leer `main.mode`.
var rig: CameraRig
var builder: NeighborhoodBuilder
var hud: CanvasLayer
var panel: Control

var _saved_camera: Dictionary = {}
var _env: Environment
var _saved_fog := Vector2.ZERO
var _open_house: NeighborHouseView
var _layer: CanvasLayer
var _bar: PanelContainer
var _title: Label
var _hint: Label


func setup(main_node) -> void:
	main = main_node
	rig = main.get_node("CameraRig")
	hud = main.get_node_or_null("HUD")
	var world := main.get_node_or_null("World") as WorldBuilder
	builder = world.neighborhood if world != null else null
	var env_node := main.get_node_or_null("WorldEnvironment") as WorldEnvironment
	_env = env_node.environment if env_node != null else null
	# Panel «Barrio» (lista de casas, privacidad, meta): en su propia capa, así se
	# ve también cuando la interfaz normal está escondida.
	var panel_layer := CanvasLayer.new()
	panel_layer.layer = 30
	panel_layer.name = "NeighborhoodPanelLayer"
	add_child(panel_layer)
	panel = load("res://ui/neighborhood_panel.tscn").instantiate()
	panel_layer.add_child(panel)
	_build_bar()
	EventBus.neighborhood_visit_requested.connect(visit)
	EventBus.neighborhood_aerial_requested.connect(enter_aerial)
	EventBus.neighborhood_return_requested.connect(return_home)


func _unhandled_key_input(event: InputEvent) -> void:
	if state != "" and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		return_home()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if state == "" or builder == null:
		return
	# Los carteles de familia se ven desde lejos; de cerca estorban.
	var show_signs := rig.current_distance() > 40.0
	for id in builder.houses:
		var house: NeighborHouseView = builder.houses[id]
		house.set_sign_visible(show_signs and house != _open_house)


# --- Entrar y salir ---

## Prepara el paso de «mi casa» al barrio. false = no se puede ahora.
func _begin() -> bool:
	if builder == null:
		EventBus.toast.emit("El barrio todavía no está disponible.")
		return false
	if state != "":
		return true
	if main.mode == "build":
		EventBus.game_mode_change_requested.emit("live")  # Si hay obras sin confirmar, main avisa y no cambia.
		if main.mode == "build":
			return false
	_saved_camera = rig.get_state()
	rig.enter_neighborhood_view()
	EventBus.game_mode_change_requested.emit("visit")
	if hud != null:
		hud.visible = false
	if _env != null:
		_saved_fog = Vector2(_env.fog_depth_begin, _env.fog_depth_end)
		_env.fog_depth_begin = FOG_BEGIN
		_env.fog_depth_end = FOG_END
	return true


## Vista aérea de todo el barrio.
func enter_aerial() -> void:
	if not _begin():
		return
	_close_interior()
	panel.hide()
	rig.set_pitch(AERIAL_PITCH)
	rig.fly_to(AERIAL_FOCUS, AERIAL_DISTANCE, 1.0)
	_set_state("aerial", "")


## Visitar un lote: la cámara va a su casa y se ve por dentro, solo para mirar.
func visit(target_id: String) -> void:
	var l := NeighborhoodMap.lot(target_id)
	if l.is_empty() or target_id == NeighborhoodMap.PLAYER_LOT:
		return
	if l["kind"] == "house" and not NeighborhoodMap.open_for_visit(target_id):
		EventBus.toast.emit("Esa casa no se puede visitar.")
		return
	if not _begin():
		return
	_close_interior()
	panel.hide()
	var focus := NeighborhoodMap.lot_center(target_id)
	if l["kind"] == "house":
		_open_house = builder.house(target_id)
		if _open_house != null:
			_open_house.set_interior(true)
			focus = _open_house.position
	rig.set_pitch(VISIT_PITCH)
	rig.fly_to(focus, VISIT_DISTANCE if l["kind"] == "house" else 40.0, 0.9)
	_set_state("visit", target_id)


## Volver a mi casa (la cámara queda como estaba).
func return_home() -> void:
	if state == "":
		return
	_close_interior()
	panel.hide()
	rig.exit_neighborhood_view()
	rig.set_state(_saved_camera)
	if hud != null:
		hud.visible = true
	if _env != null:
		_env.fog_depth_begin = _saved_fog.x
		_env.fog_depth_end = _saved_fog.y
	if builder != null:
		for id in builder.houses:
			builder.houses[id].set_sign_visible(true)
	EventBus.game_mode_change_requested.emit("live")
	_set_state("", "")


func _close_interior() -> void:
	if _open_house != null:
		_open_house.set_interior(false)
		_open_house = null


func _set_state(new_state: String, new_lot: String) -> void:
	state = new_state
	lot_id = new_lot
	_bar.visible = state != ""
	match state:
		"aerial":
			_title.text = "Vista aérea del barrio"
			_hint.text = "Arrastrá para mover · pellizcá para el zoom · dos dedos para girar"
		"visit":
			_title.text = "Visitando: %s" % NeighborhoodMap.family_label(lot_id)
			_hint.text = "Solo ver: no se puede construir ni cambiar nada"
	EventBus.neighborhood_state_changed.emit(state, lot_id)


# --- Barrita de arriba: volver, casas y vista aérea ---

func _build_bar() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 12
	_layer.name = "NeighborhoodBarLayer"
	add_child(_layer)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var insets := SafeArea.margins(Vector4(16, 16, 16, 16), SafeArea.insets(get_window()))
	margin.add_theme_constant_override("margin_left", int(insets.x))
	margin.add_theme_constant_override("margin_top", int(insets.y))
	margin.add_theme_constant_override("margin_right", int(insets.z))
	_layer.add_child(margin)
	_bar = PanelContainer.new()
	_bar.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.17, 0.25, 0.92)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(10)
	_bar.add_theme_stylebox_override("panel", style)
	margin.add_child(_bar)
	var column := VBoxContainer.new()
	_bar.add_child(column)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 22)
	column.add_child(_title)
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.add_theme_color_override("font_color", Color(0.8, 0.9, 1))
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_hint)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	column.add_child(buttons)
	buttons.add_child(PanelRows.button("← Volver a mi casa", return_home, false, 190))
	buttons.add_child(PanelRows.button("Vista aérea", enter_aerial, false, 140))
	buttons.add_child(PanelRows.button("Casas", EventBus.neighborhood_panel_requested.emit, false, 110))
