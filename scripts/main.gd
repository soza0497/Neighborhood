extends Node3D
## Escena principal: crea la casa del jugador, su personaje y conecta todo.
##
## - La casa (datos) vive en `house`; su historial de deshacer en `history`.
## - La vista 3D ($House) la dibuja; el constructor ($House/Builder) la edita.
## - El personaje ($House/Character) camina por `nav` y vive con su IA.
## - La interfaz no toca nada directo: pide cosas por EventBus y aquí se hacen.
## - Cada cambio en la casa se guarda solo, un segundo después.
## - Con cuenta (Fase 4B) el servidor manda en el dinero y la casa: sin
##   conexión no se puede Construir (se sigue viviendo).

## Segundos de espera después de un cambio antes de guardar.
const AUTOSAVE_DELAY := 1.0
## Máximo de minutos sin jugar que se cuentan al volver (3 días del juego).
const MAX_OFFLINE_MINUTES := 3 * 1440
const LOGIN_SCENE := "res://ui/login_screen.tscn"

@onready var _camera_rig: CameraRig = $CameraRig
@onready var _house_view: HouseView = $House
@onready var _builder: HouseBuilder = $House/Builder
@onready var _character: Character = $House/Character
@onready var _live: LiveController = $House/LiveController

var house := HouseData.new()
var history: UndoHistory
var nav: HouseNav
var character_data: CharacterData
## "build" (construir) o "live" (vivir).
var mode := ""

var _autosave_timer: Timer
## Para saber cuándo VUELVE la conexión.
var _was_online := false


func _ready() -> void:
	# SaveSystem ya cargó la partida antes de que exista esta escena.
	if not GameState.camera.is_empty():
		_camera_rig.set_state(GameState.camera)
	if not GameState.house.is_empty():
		house.from_dict(GameState.house)

	history = UndoHistory.new(house)
	history.remote = Economy.server_mode
	nav = HouseNav.new(house)
	_house_view.setup(house)
	_builder.setup(house, history, _house_view, _camera_rig)
	_live.view = _house_view
	_load_character()

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
	EventBus.build_confirm_requested.connect(_builder.confirm_pending)
	EventBus.build_cancel_requested.connect(_builder.cancel_pending)
	EventBus.undo_requested.connect(_undo)
	EventBus.redo_requested.connect(_redo)
	EventBus.character_order_requested.connect(_character.order)
	EventBus.character_editor_requested.connect(_on_character_editor_requested)
	EventBus.character_edit_finished.connect(_on_character_edit_finished)
	EventBus.journal_requested.connect(_on_journal_requested)
	EventBus.construction_accelerate_requested.connect(_on_accelerate_requested)
	EventBus.logout_requested.connect(_on_logout_requested)
	EventBus.server_status_changed.connect(_on_server_status_changed)
	_was_online = GameServer.online

	set_mode("live")
	EventBus.view_mode_changed.emit(_house_view.view_mode)
	_set_level(_character.level)  # Se empieza viendo el piso del personaje.
	history.refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	# Atajos de teclado para probar en la PC: Ctrl+Z deshace, Ctrl+Y rehace.
	if event.is_action_pressed("ui_undo"):
		_undo()
	elif event.is_action_pressed("ui_redo"):
		_redo()


# Antes de deshacer o rehacer se descarta una selección sin confirmar
# (se calculó con la casa de antes).
func _undo() -> void:
	_builder.cancel_pending()
	history.undo()


func _redo() -> void:
	_builder.cancel_pending()
	history.redo()


## Cambia entre construir y vivir. Con cuenta y sin conexión no se puede
## construir (decisión del dueño): se avisa y se sigue viviendo.
func set_mode(new_mode: String) -> void:
	if new_mode == mode:
		return
	if new_mode == "build" and Economy.server_mode and not GameServer.online:
		EventBus.toast.emit(Economy.OFFLINE_TEXT + ": por ahora no se puede construir.")
		return
	mode = new_mode
	_builder.set_active(mode == "build")
	_live.active = mode == "live"
	# En modo construir el tiempo se detiene; al volver, el personaje se
	# reubica (la casa pudo cambiar).
	GameClock.set_paused(mode == "build")
	if mode == "live":
		_character.reset_after_build()
	EventBus.game_mode_changed.emit(mode)


func _on_build_item_selected(item_id: String) -> void:
	_builder.select_item(item_id)
	# Para poner techos hay que verlos.
	if Catalog.get_item(item_id).get("kind", "") == "roof":
		_set_view_mode(HouseView.ViewMode.FULL)


## Cambia el piso que se ve (y donde se construye). Los de arriba se ocultan.
func _on_level_change_requested(delta: int) -> void:
	_set_level(_builder.level + delta)


func _set_level(level: int) -> void:
	var new_level := _builder.set_level(level)
	_house_view.set_top_visible_level(new_level)
	EventBus.build_level_changed.emit(new_level)


func _on_view_mode_cycle_requested() -> void:
	var next: int = (_house_view.view_mode + 1) % HouseView.ViewMode.size()
	_set_view_mode(next as HouseView.ViewMode)


func _set_view_mode(view_mode: HouseView.ViewMode) -> void:
	_house_view.set_view_mode(view_mode)
	EventBus.view_mode_changed.emit(view_mode)


## Crea el personaje (o lo carga) y descuenta el tiempo que pasó sin jugar.
func _load_character() -> void:
	character_data = CharacterData.create_default()
	var saved := GameState.character
	if not saved.is_empty():
		character_data.from_dict(saved.get("data", {}))
		var cell_array: Array = saved.get("cell", [Character.SPAWN_CELL.x, Character.SPAWN_CELL.y])
		_character.level = int(saved.get("level", 0))
		_character.cell = Vector2i(int(cell_array[0]), int(cell_array[1])) + house.migrated_offset
		var away_seconds := Time.get_unix_time_from_system() - float(saved.get("saved_unix", 0))
		# A velocidad x1, 1 segundo real = 1 minuto del juego.
		var away_minutes := clampf(away_seconds, 0.0, MAX_OFFLINE_MINUTES)
		character_data.decay(away_minutes, CharacterData.OFFLINE_FLOOR)
		# El trabajo no se pierde por desconectarse (con servidor, él mide
		# el tiempo con su propia hora).
		Economy.request_settle(away_minutes)
	elif Economy.server_mode:
		Economy.request_settle(0.0)
	GameClock.minutes = float(GameState.clock.get("minutes", GameClock.minutes))
	_character.setup(character_data, house, nav, _house_view)


func _on_character_editor_requested() -> void:
	EventBus.character_editor_opened.emit(character_data.to_dict())


## Paga para terminar todas las obras en marcha de una vez.
func _on_accelerate_requested() -> void:
	var pending := house.pending_construction()
	if pending.is_empty() or not Economy.can_request():
		return
	if Economy.server_mode:
		var result: Dictionary = await Economy.request("build_accelerate")
		if not result["ok"]:
			EventBus.toast.emit(result["error"])
			return
		house.apply(CloudSync.writes_from_server(result["data"].get("writes", [])))
		_finish_acceleration(-int(result["data"].get("money_change", 0)))
		return
	var now := Economy.now()
	var seconds := 0
	for p in pending:
		seconds += int(p[3]) - now
	var cost := Economy.accelerate_cost(seconds)
	if not Economy.can_change(-cost):
		EventBus.toast.emit("Te faltan $%d para acelerar." % (cost - Economy.money))
		return
	Economy.add_money(-cost)
	var writes: Array = []
	for p in pending:
		var value: Dictionary = house.get_piece(p[0], p[1], p[2]).duplicate(true)
		value.erase("ready_at")
		writes.append(HouseData.write(p[0], p[1], p[2], value))
	house.apply(writes)  # Directo, sin historial: no se "des-acelera".
	_finish_acceleration(cost)


func _finish_acceleration(cost: int) -> void:
	_house_view.check_construction()
	EventBus.toast.emit("Obras terminadas (-$%d)" % cost)
	_autosave_timer.start()


## Con cuenta: si se corta la conexión en modo Construir, se vuelve a Vivir.
func _on_server_status_changed(online: bool, _username: String) -> void:
	if not Economy.server_mode:
		return
	if not online and mode == "build":
		_builder.cancel_pending()
		set_mode("live")
		EventBus.toast.emit(Economy.OFFLINE_TEXT + ": volviste a Vivir.")
	if online and not _was_online:
		_on_reconnected()
	_was_online = online


## Volvió la conexión (por ejemplo, al llegar a casa con el juego abierto).
## Si se había entrado "sin conexión", primero se carga la partida del
## servidor (como al entrar). Después se cobran los días sin conexión, ANTES
## de volver a avisar "sigo jugando" (si no, el servidor no los contaría).
func _on_reconnected() -> void:
	GameServer.heartbeat_enabled = false
	if not GameServer.game_loaded:
		await _load_from_server()
	Economy.request_settle(0.0)


func _load_from_server() -> void:
	SaveSystem.save_game()  # GameState al día con lo de esta pantalla.
	var result: Dictionary = await GameServer.load_game(GameState.to_dict())
	if not result["ok"]:
		return  # Se intenta de nuevo la próxima vez que vuelva la conexión.
	GameServer.game_loaded = true
	var merged := CloudSync.merge(GameState.to_dict(), result["data"], GameServer.user_id(), GameServer.username())
	if not _same_house(merged["house"], house.to_dict()):
		_builder.cancel_pending()
		house.from_dict(merged["house"])
		_character.reset_after_build()  # Por si quedó parado donde ahora hay algo.
	Economy.apply_server_state(result["data"])
	history.refresh()
	EventBus.toast.emit("Volvió la conexión: tu partida está al día.")
	_autosave_timer.start()


## ¿Dos casas (como diccionarios) son iguales? Se comparan como texto, después
## de pasar las dos por JSON (así los números quedan del mismo tipo).
static func _same_house(a: Dictionary, b: Dictionary) -> bool:
	var levels_a: Variant = JSON.parse_string(JSON.stringify(a.get("levels", [])))
	var levels_b: Variant = JSON.parse_string(JSON.stringify(b.get("levels", [])))
	return JSON.stringify(levels_a, "", true) == JSON.stringify(levels_b, "", true)


## Cierra la sesión: guarda, sube lo que falte a la nube y vuelve a la
## pantalla de entrada. La partida queda en el teléfono.
func _on_logout_requested() -> void:
	SaveSystem.save_game()
	if GameServer.online:
		await GameServer.upload_cloud()
	GameServer.logout()
	Economy.use_server(false)
	get_tree().change_scene_to_file(LOGIN_SCENE)


func _on_journal_requested() -> void:
	EventBus.journal_opened.emit(character_data.name, character_data.emotion(), character_data.journal)


func _on_character_edit_finished(data: Dictionary) -> void:
	data.erase("needs")  # El editor no toca las necesidades (siguen bajando).
	data.erase("journal")
	character_data.from_dict(data)
	character_data.add_journal("Cambió de look")
	_character.refresh_look()
	EventBus.character_intention_changed.emit(_character.get_intention())
	_autosave_timer.start()


func _on_game_saving() -> void:
	GameState.camera = _camera_rig.get_state()
	GameState.house = house.to_dict()
	GameState.character = _character.to_dict()
	GameState.clock = {"minutes": GameClock.minutes}
