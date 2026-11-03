extends Node3D
## Escena principal: crea la casa del jugador y conecta todo.
##
## - La casa (datos) vive en `house`; su historial de deshacer en `history`.
## - La vista 3D ($House) la dibuja; el constructor ($House/Builder) la edita.
## - La interfaz no toca nada directo: pide cosas por EventBus y aquí se hacen.
## - Cada cambio en la casa se guarda solo, un segundo después.

## Segundos de espera después de un cambio antes de guardar.
const AUTOSAVE_DELAY := 1.0

@onready var _camera_rig: CameraRig = $CameraRig
@onready var _house_view: HouseView = $House
@onready var _builder: HouseBuilder = $House/Builder

var house := HouseData.new()
var history: UndoHistory
## "build" (construir) o "live" (vivir).
var mode := ""

var _autosave_timer: Timer


func _ready() -> void:
	# SaveSystem ya cargó la partida antes de que exista esta escena.
	if not GameState.camera.is_empty():
		_camera_rig.set_state(GameState.camera)
	if not GameState.house.is_empty():
		house.from_dict(GameState.house)

	history = UndoHistory.new(house)
	_house_view.setup(house)
	_builder.setup(house, history, _house_view, _camera_rig)

	_autosave_timer = Timer.new()
	_autosave_timer.one_shot = true
	_autosave_timer.wait_time = AUTOSAVE_DELAY
	_autosave_timer.timeout.connect(SaveSystem.save_game)
	add_child(_autosave_timer)

	history.changed.connect(EventBus.history_changed.emit)
	history.house_edited.connect(_autosave_timer.start)
	EventBus.game_saving.connect(_on_game_saving)
	EventBus.game_mode_change_requested.connect(set_mode)
	EventBus.build_item_selected.connect(_on_build_item_selected)
	EventBus.build_erase_toggled.connect(_builder.set_erase_mode)
	EventBus.build_rotate_requested.connect(_builder.rotate_object)
	EventBus.build_delete_requested.connect(_builder.delete_selected)
	EventBus.build_level_change_requested.connect(_on_level_change_requested)
	EventBus.view_mode_cycle_requested.connect(_on_view_mode_cycle_requested)
	EventBus.undo_requested.connect(history.undo)
	EventBus.redo_requested.connect(history.redo)

	set_mode("build")
	EventBus.view_mode_changed.emit(_house_view.view_mode)
	EventBus.build_level_changed.emit(_builder.level)
	EventBus.history_changed.emit(false, false)


func _unhandled_key_input(event: InputEvent) -> void:
	# Atajos de teclado para probar en la PC: Ctrl+Z deshace, Ctrl+Y rehace.
	if event.is_action_pressed("ui_undo"):
		history.undo()
	elif event.is_action_pressed("ui_redo"):
		history.redo()


## Cambia entre construir y vivir.
func set_mode(new_mode: String) -> void:
	if new_mode == mode:
		return
	mode = new_mode
	_builder.set_active(mode == "build")
	EventBus.game_mode_changed.emit(mode)


func _on_build_item_selected(item_id: String) -> void:
	_builder.select_item(item_id)
	# Para poner techos hay que verlos.
	if Catalog.get_item(item_id).get("kind", "") == "roof":
		_set_view_mode(HouseView.ViewMode.FULL)


func _on_level_change_requested(delta: int) -> void:
	var new_level := _builder.set_level(_builder.level + delta)
	EventBus.build_level_changed.emit(new_level)


func _on_view_mode_cycle_requested() -> void:
	var next: int = (_house_view.view_mode + 1) % HouseView.ViewMode.size()
	_set_view_mode(next as HouseView.ViewMode)


func _set_view_mode(view_mode: HouseView.ViewMode) -> void:
	_house_view.set_view_mode(view_mode)
	EventBus.view_mode_changed.emit(view_mode)


func _on_game_saving() -> void:
	GameState.camera = _camera_rig.get_state()
	GameState.house = house.to_dict()
