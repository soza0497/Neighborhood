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
## - Casa compartida (Fase 5): si la pareja cambia algo, el servidor avisa y
##   aquí la casa "se pone al día" (solo las piezas que cambiaron). Si se
##   mudan juntos o se separan, se carga la casa entera de nuevo.

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
## Fase 5: hay que preguntar al servidor cómo está la casa (la pareja cambió
## algo), y si ya se está preguntando.
var _sync_pending := false
var _syncing := false
var _sync_retry_at := 0
## El personaje de la pareja (en la casa compartida), o null.
var partner_character: Character
var _partner_saved_unix := -1
## Pulido 1: hay que volver a revisar "lo que falta" (se hace como mucho
## cada PROBLEMS_INTERVAL segundos, y solo en modo construir).
var _problems_dirty := true
## Pulido 2C: obstáculos de la parcela, servicios que llegan y entrega de compras.
var _parcel_view: ParcelView
var _services: Services
var _delivery: Delivery
var _problems_timer := 0.0
var _neighborhood: NeighborhoodController
var _template_placer: TemplatePlacer
const PROBLEMS_INTERVAL := 0.4


func _ready() -> void:
	# Pulido 2B: estilo (contorno) y volúmenes guardados en las opciones.
	Style.set_outline(GameState.settings.get("outline_enabled", true))
	ModelLoader.enabled = GameState.settings.get("use_models", true)
	Sound.apply_volumes()
	# SaveSystem ya cargó la partida antes de que exista esta escena.
	if not GameState.camera.is_empty():
		_camera_rig.set_state(GameState.camera)
	if not GameState.house.is_empty():
		house.from_dict(GameState.house)

	history = UndoHistory.new(house)
	history.remote = Economy.server_mode
	nav = HouseNav.new(house)
	# Pulido 2C: la parcela mide 96 x 96; el origen del mundo es su centro.
	_house_view.position = Vector3(-HouseGrid.LOT_SIZE.x / 2.0, 0.0, -HouseGrid.LOT_SIZE.y / 2.0)
	_house_view.setup(house)
	_builder.setup(house, history, _house_view, _camera_rig)
	# Pulido 5E: colocar plantillas de casa (hijo de la casa, después del constructor).
	_template_placer = TemplatePlacer.new()
	_template_placer.name = "TemplatePlacer"
	_house_view.add_child(_template_placer)
	_template_placer.setup(_builder, house, _house_view, _camera_rig)
	_live.view = _house_view
	_setup_parcel_nodes()
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
	EventBus.build_level_set_requested.connect(_set_level)
	EventBus.view_roofs_toggle_requested.connect(_on_roofs_toggle)
	EventBus.view_walls_toggle_requested.connect(_on_walls_toggle)
	EventBus.camera_focus_character_requested.connect(_focus_character)
	EventBus.camera_follow_changed.connect(func(on: bool) -> void: _follow_character = on)
	# Constructor 2.0 (Pulido 1).
	EventBus.build_nudge_requested.connect(_builder.nudge_selected)
	EventBus.build_paint_step_requested.connect(_builder.paint_step)
	EventBus.build_context_action_requested.connect(_builder.context_action)
	EventBus.build_erase_multi_toggled.connect(_builder.set_erase_multi)
	EventBus.build_copy_outline_requested.connect(_builder.copy_outline)
	EventBus.build_add_floor_requested.connect(_builder.add_floor)
	EventBus.build_add_basement_requested.connect(_builder.add_basement)
	EventBus.plan_confirm_requested.connect(_builder.confirm_plan)
	EventBus.plan_discard_requested.connect(_builder.discard_draft)
	EventBus.camera_pitch_requested.connect(_camera_rig.set_pitch)
	EventBus.camera_pitch_step_requested.connect(_camera_rig.step_pitch)
	EventBus.proposal_send_requested.connect(_builder.send_draft)
	EventBus.proposal_discard_requested.connect(_builder.discard_draft)
	EventBus.proposal_review_requested.connect(_on_proposal_review_requested)
	EventBus.proposal_answer_requested.connect(_on_proposal_answer_requested)
	EventBus.proposal_close_requested.connect(_builder.close_review)
	house.piece_changed.connect(func(_l: int, _layer: String, _k: String) -> void: _problems_dirty = true)
	house.reloaded.connect(func() -> void: _problems_dirty = true)
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
	EventBus.home_remote_changed.connect(_on_home_remote_changed)
	EventBus.home_reload_requested.connect(_on_home_reload_requested)
	EventBus.couple_changed.connect(_update_partner_character)
	EventBus.partner_presence_changed.connect(_on_partner_presence_changed)
	_was_online = GameServer.online
	house.rev = Economy.house_rev
	Economy.own_rev = -1

	# Fase 8: el barrio (vista aérea, visitas, vida y metas).
	_neighborhood = NeighborhoodController.new()
	_neighborhood.name = "NeighborhoodController"
	add_child(_neighborhood)
	_neighborhood.setup(self)

	# Pulido 4B: marcadores de las celdas peligrosas (solo con el modo desarrollador prendido).
	var hazard_view := HazardView.new()
	hazard_view.name = "HazardView"
	_house_view.add_child(hazard_view)
	hazard_view.setup(nav)

	set_mode("live")
	_update_partner_character()
	_emit_view()
	if has_node("HUD"):
		$HUD.setup_house(house, _character, _builder)
		$HUD.setup_dev(_character, nav, _house_view)
	_set_level(_character.level)  # Se empieza viendo el piso del personaje.
	history.refresh()


## Obstáculos, servicios y entregas (Pulido 2C): cuelgan de la casa (celdas).
func _setup_parcel_nodes() -> void:
	Parcel.refresh_config()
	_parcel_view = ParcelView.new()
	_parcel_view.name = "ParcelView"
	_house_view.add_child(_parcel_view)
	_services = Services.new()
	_services.name = "Services"
	_services.world = get_node_or_null("World") as WorldBuilder
	_services.house = house
	_house_view.add_child(_services)
	_delivery = Delivery.new()
	_delivery.name = "Delivery"
	_house_view.add_child(_delivery)
	_delivery.setup(house, nav, _house_view, _services)
	_live.parcel_view = _parcel_view
	_live.builder = _builder
	Parcel.service_due.connect(_on_service_due)
	EventBus.ambulance_requested.connect(func(patient: Node3D) -> void: _services.run_ambulance(patient))
	EventBus.boxes_open_all_requested.connect(func() -> void: _character.open_all_boxes())
	EventBus.box_tapped.connect(func(box_level: int, key: String) -> void: _character.open_box_order(box_level, key))
	# Servicios que ya estaban en camino al abrir el juego.
	Parcel.check_now()


## Pasó la espera de un servicio de limpieza: llega. Si solo hace falta una
## persona, el personaje del jugador va a abrirle la puerta; si hace falta un
## vehículo y no hay camino libre, avisa que no puede entrar.
func _on_service_due(id: String) -> void:
	var def := Parcel.definition(id)
	var obstacle := Parcel.obstacle(id)
	if def.is_empty() or obstacle.is_empty():
		return
	var route := Parcel.access(id, house)
	var needs_vehicle := str(def.get("vehicle", "")) != ""
	if not needs_vehicle and route["ok"]:
		_character.go_open_gate()
		await _character.gate_opened
	_services.run_clear(obstacle, def, route, not route["ok"])
	var result: Dictionary = await _services.finished
	while str(result.get("id", "")) != id:
		result = await _services.finished
	if result.get("blocked", false):
		EventBus.toast.emit("El servicio no pudo entrar: %s" % str(result.get("reason", "")))
		return
	var done: Dictionary = await Parcel.finish(id, house)
	if done["ok"]:
		EventBus.toast.emit("Listo: quedó limpio (%s)." % str(def.get("name", "")).to_lower())
		_problems_dirty = true
	elif done["blocked"]:
		EventBus.toast.emit("El servicio no pudo entrar: %s" % done["reason"])
	else:
		EventBus.toast.emit(str(done["reason"]))


func _process(delta: float) -> void:
	_check_home_sync()
	if mode == "live":
		_follow_step()
	_problems_timer -= delta
	if _problems_dirty and _problems_timer <= 0.0 and mode == "build":
		_problems_dirty = false
		_problems_timer = PROBLEMS_INTERVAL
		_update_problems()


## Lista de "lo que falta" (sin apoyo, sin acceso): las piezas se pintan de
## rojo y la interfaz muestra el aviso. Solo en modo construir.
func _update_problems() -> void:
	var problems: Array = HouseRules.problems(house) if mode == "build" else []
	_house_view.set_problems(problems)
	EventBus.house_problems_changed.emit(problems)


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
	if _builder.has_draft():
		_builder.draft_undo()  # Dentro de la propuesta, deshace en ella.
		return
	history.undo()


func _redo() -> void:
	_builder.cancel_pending()
	if _builder.has_draft():
		return
	history.redo()


## Cambia entre construir y vivir. Con cuenta y sin conexión no se puede
## construir (decisión del dueño): se avisa y se sigue viviendo.
func set_mode(new_mode: String) -> void:
	if new_mode == mode:
		return
	if new_mode == "build" and Economy.server_mode and not GameServer.online:
		EventBus.toast.emit(Economy.OFFLINE_TEXT + ": por ahora no se puede construir.")
		return
	if new_mode == "live" and _builder.has_draft():
		if _builder.draft_mode() == "own":
			EventBus.toast.emit("Primero mandá o descartá la propuesta.")
			return
		if _builder.draft_mode() == "plan":
			EventBus.toast.emit("Tenés obras previstas: tocá Factura para construirlas o descartalas.")
			return
		_builder.close_review()
	mode = new_mode
	_builder.set_active(mode == "build")
	_live.active = mode == "live"
	# En modo construir el tiempo se detiene; al volver, el personaje se
	# reubica (la casa pudo cambiar).
	GameClock.set_paused(mode == "build")
	if mode == "live":
		_character.reset_after_build()
		if partner_character != null:
			partner_character.reset_after_build()
	EventBus.game_mode_changed.emit(mode)
	_problems_dirty = true
	if mode == "live":
		_update_problems()  # Fuera de construir no se pinta nada de rojo.


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
	# Pulido 2C: en un sótano se esconde el terreno (se ve la casa "cortada").
	var world := get_node_or_null("World")
	if world != null:
		world.visible = new_level >= 0
	if _parcel_view != null:
		_parcel_view.visible = new_level >= 0
	# La cámara mira a la altura de ese piso (la planta baja queda igual).
	_camera_rig.set_floor_height(new_level * HouseGrid.WALL_HEIGHT)
	EventBus.build_level_changed.emit(new_level)


func _on_view_mode_cycle_requested() -> void:
	var next: int = (_house_view.view_mode + 1) % HouseView.ViewMode.size()
	_set_view_mode(next as HouseView.ViewMode)


func _set_view_mode(view_mode: HouseView.ViewMode) -> void:
	_house_view.set_view_mode(view_mode)
	_emit_view()


## Ícono del techo: se ven o no. Para ver los techos, las paredes vuelven a
## ser altas (un techo sobre paredes bajas taparía el cuarto).
func _on_roofs_toggle() -> void:
	var roofs := not _house_view.show_roofs
	_house_view.set_view(roofs, _house_view.low_walls and not roofs)
	_emit_view()


## Ícono de las paredes: altas o bajas (bajas = sin techo, para ver adentro).
func _on_walls_toggle() -> void:
	var low := not _house_view.low_walls
	_house_view.set_view(_house_view.show_roofs and not low, low)
	_emit_view()


func _emit_view() -> void:
	EventBus.view_mode_changed.emit(_house_view.view_mode)
	EventBus.view_changed.emit(_house_view.show_roofs, _house_view.low_walls)


## Brújula: la cámara va al personaje y se ve su piso.
## Pulido 6C: con el modo «siguiendo» la cámara acompaña al personaje. Si se va a trabajar
## (desaparece de la casa), vuelve sola a libre.
var _follow_character := false


func _follow_step() -> void:
	if not _follow_character or _character == null:
		return
	if _character.state == Character.State.WORKING:
		_follow_character = false
		EventBus.camera_follow_changed.emit(false)
		return
	_camera_rig.focus_on(_character.global_position)


func _focus_character() -> void:
	_set_level(_character.level)
	_camera_rig.focus_on(_character.global_position)


## Crea el personaje (o lo carga) y descuenta el tiempo que pasó sin jugar.
func _load_character() -> void:
	character_data = CharacterData.create_default()
	var saved := GameState.character
	if not saved.is_empty():
		character_data.from_dict(saved.get("data", {}))
		var cell_array: Array = saved.get("cell", [Character.spawn_cell().x, Character.spawn_cell().y])
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
	house.rev = Economy.house_rev
	Couple.apply_answer(result["data"])
	await Parcel.refresh()  # La semilla de los obstáculos es la del servidor.
	GameServer.start_realtime()
	history.refresh()
	EventBus.toast.emit("Volvió la conexión: tu partida está al día.")
	_autosave_timer.start()


## ¿Dos casas (como diccionarios) son iguales? Se comparan como texto, después
## de pasar las dos por JSON (así los números quedan del mismo tipo).
static func _same_house(a: Dictionary, b: Dictionary) -> bool:
	var levels_a: Variant = JSON.parse_string(JSON.stringify(a.get("levels", [])))
	var levels_b: Variant = JSON.parse_string(JSON.stringify(b.get("levels", [])))
	return JSON.stringify(levels_a, "", true) == JSON.stringify(levels_b, "", true)


# --- Casa compartida (Fase 5): ponerse al día ---

## La pareja cambió algo (aviso del servidor con la versión nueva).
func _on_home_remote_changed(notice: Dictionary) -> void:
	if int(notice.get("rev", 0)) > house.rev or notice.get("kind", "") in ["approved", "revert"]:
		_sync_pending = true


## ¿La casa está al día con el servidor? Si mi último pedido fue lo único
## que cambió (la versión subió 1), ya está; si no, se pregunta.
func _check_home_sync() -> void:
	if not Economy.server_mode or not GameServer.online or not GameServer.game_loaded:
		return
	if Economy.busy or _syncing or Economy.now() < _sync_retry_at:
		return
	if _builder.has_draft():
		return  # Con una propuesta a la vista, se pone al día al cerrarla.
	if not _sync_pending and house.rev == Economy.house_rev:
		return
	if not _sync_pending and Economy.own_rev == Economy.house_rev and house.rev == Economy.house_rev - 1:
		house.rev = Economy.house_rev
		return
	_sync_home()


## Pide la casa al servidor y aplica solo lo que cambió.
func _sync_home() -> void:
	_syncing = true
	_sync_pending = false
	var result: Dictionary = await GameServer.call_rpc("home_load", {})
	_syncing = false
	if not result["ok"] or not result["data"].get("ok", false):
		_sync_retry_at = Economy.now() + 5
		_sync_pending = true
		return
	var data: Dictionary = result["data"]
	var server_house: Variant = JSON.parse_string(str(data.get("house", ""))) if str(data.get("house", "")) != "" else {}
	if not server_house is Dictionary:
		server_house = {}
	var writes := CoupleState.diff_writes(house.to_dict(), server_house)
	if not writes.is_empty():
		_builder.cancel_pending()
		_builder.select_object("")
		house.apply(writes)
		house.next_id = maxi(house.next_id, int(server_house.get("next_id", 1)))
		_character.on_house_changed()
		if partner_character != null:
			partner_character.on_house_changed()
		_autosave_timer.start()
	house.rev = int(CoupleState.normalize_home(data.get("home", {}))["rev"])
	if not Economy.busy and data.get("state") is Dictionary:
		Economy.apply_server_state(data["state"])
		house.rev = Economy.house_rev
	Couple.apply_answer({"home": data.get("home", {})})
	history.refresh()


## Se mudaron juntos o se separaron: la casa es otra. Se carga entera.
func _on_home_reload_requested() -> void:
	if not Economy.server_mode or not GameServer.online:
		return
	while Economy.busy:
		await get_tree().process_frame
	SaveSystem.save_game()
	var result: Dictionary = await GameServer.call_rpc("game_load", {})
	if not result["ok"]:
		return
	var merged := CloudSync.merge(GameState.to_dict(), result["data"], GameServer.user_id(), GameServer.username())
	_builder.cancel_pending()
	_builder.select_object("")
	house.from_dict(merged["house"])
	Economy.apply_server_state(result["data"])
	house.rev = Economy.house_rev
	Couple.apply_answer(result["data"])
	# En otra casa, el personaje entra por el frente.
	_character.place_at(0, Character.spawn_cell())
	_character.reset_after_build()
	_update_partner_character()
	history.refresh()
	_autosave_timer.start()


## En la casa compartida aparece el personaje de la pareja (con su aspecto,
## nombre y rasgos). Si se separan, se va.
func _update_partner_character() -> void:
	var wanted := Economy.server_mode and Couple.shared() and not Couple.partner.is_empty()
	if not wanted:
		if partner_character != null:
			partner_character.queue_free()
			partner_character = null
			_character.companion = null
			_partner_saved_unix = -1
		return
	var saved: Dictionary = Couple.partner.get("character", {})
	var saved_unix := int(saved.get("saved_unix", 0))
	if partner_character != null and saved_unix == _partner_saved_unix:
		return
	var partner_data := CharacterData.create_default()
	partner_data.name = Couple.partner_name()
	if not saved.is_empty():
		partner_data.from_dict(saved.get("data", {}))
	if partner_character == null:
		partner_character = Character.new()
		partner_character.name = "PartnerCharacter"
		partner_character.is_partner = true
		_house_view.add_child(partner_character)
		var cell_array: Array = saved.get("cell", [Character.spawn_cell().x + 1, Character.spawn_cell().y])
		partner_character.level = int(saved.get("level", 0))
		partner_character.cell = Vector2i(int(cell_array[0]), int(cell_array[1]))
		partner_character.setup(partner_data, house, nav, _house_view)
		partner_character.reset_after_build()  # Por si su lugar ya no está libre.
		partner_character.companion = _character
		_character.companion = partner_character
		partner_character.follow_intention(Couple.partner_online, Couple.partner_intention)
	else:
		# Cambió de look en su teléfono.
		partner_character.data.name = partner_data.name
		partner_character.data.appearance = partner_data.appearance
		partner_character.data.traits = partner_data.traits
		partner_character.refresh_look()
	_partner_saved_unix = saved_unix


func _on_partner_presence_changed(online: bool, intention: Dictionary) -> void:
	if partner_character != null:
		partner_character.follow_intention(online, intention)


## Cierra la sesión: guarda, sube lo que falte a la nube y vuelve a la
## pantalla de entrada. La partida queda en el teléfono.
func _on_logout_requested() -> void:
	SaveSystem.save_game()
	if GameServer.online:
		await GameServer.upload_cloud()
	GameServer.logout()
	Couple.clear()
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
	# Una propuesta a la vista no se guarda: se guarda la casa de verdad.
	GameState.house = _builder.house_without_draft().to_dict() if _builder.has_draft() else house.to_dict()
	GameState.character = _character.to_dict()
	GameState.clock = {"minutes": GameClock.minutes}


# --- Propuesta de la pareja (Pulido 1) ---

## Ver en la casa la propuesta de la pareja (Menú → Casa → Ver).
func _on_proposal_review_requested(request_id: int) -> void:
	if mode != "build":
		set_mode("build")
		if mode != "build":
			return
	var result: Dictionary = await Couple.get_request(request_id)
	if not result["ok"]:
		return
	_builder.show_review(result["request"], result["writes"])
	EventBus.toast.emit("Así quedaría la propuesta de %s." % str(result["request"].get("by_name", "")))


## Aprobar o rechazar la propuesta que se está viendo.
func _on_proposal_answer_requested(approve: bool) -> void:
	var request := _builder.review_request()
	if request.is_empty():
		return
	_builder.close_review()
	await Couple.answer_request(int(request.get("id", 0)), approve)
	_sync_pending = true
