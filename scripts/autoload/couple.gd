extends Node
## La pareja y la casa compartida (Fase 5), del lado del teléfono.
##
## Guarda lo último que dijo el servidor (la relación, la pareja y el hogar)
## y escucha la conexión en tiempo real:
##   - Presencia: si la pareja está conectada y qué hace su personaje (su
##     "intención", que llega como su estado). Avisa con
##     EventBus.partner_presence_changed.
##   - Avisos del servidor (la pareja movió algo, pidió permiso, aceptó...):
##     vuelve a preguntar lo que corresponda y avisa por EventBus.
##   - Manda la intención de MI personaje a la pareja (como mi estado), como
##     mucho una vez cada STATUS_INTERVAL segundos.
##
## Los pedidos (invitar, aceptar, aportar a la caja, aprobar...) pasan por
## Economy.request: de a uno por vez, y la respuesta trae el dinero al día.
## Las reglas las decide el servidor (neighborhood_couple.lua).

## Cada cuánto, como mucho, se manda la intención de mi personaje.
const STATUS_INTERVAL := 2.0
## Códigos de los avisos (los mismos que neighborhood.lua).
const NOTIFY_COUPLE := 101
const NOTIFY_HOME := 103
const NOTIFY_REQUESTS := 104

## La relación (CoupleState.normalize_couple).
var couple: Dictionary = CoupleState.normalize_couple({})
## La pareja: {user_id, username, character} o {}.
var partner: Dictionary = {}
## El hogar: caja, pedidos e historial (CoupleState.normalize_home).
var home: Dictionary = CoupleState.normalize_home({})
var partner_online := false
## Lo que hace el personaje de la pareja ({} = no se sabe).
var partner_intention: Dictionary = {}

var _my_intention: Dictionary = {}
var _status_dirty := false
var _status_timer := 0.0
var _refreshing := false


func _ready() -> void:
	GameServer.socket.notification_received.connect(_on_notification)
	GameServer.socket.presence_changed.connect(_on_presence_changed)
	GameServer.socket.connection_changed.connect(_on_socket_changed)
	EventBus.character_intention_changed.connect(_on_my_intention_changed)


func _process(delta: float) -> void:
	_status_timer -= delta
	if _status_dirty and _status_timer <= 0.0:
		_status_timer = STATUS_INTERVAL
		_status_dirty = false
		GameServer.socket.update_status(CoupleState.encode_status(_my_intention))


func in_couple() -> bool:
	return CoupleState.in_couple(couple)


func shared() -> bool:
	return couple.get("shared", false)


func partner_name() -> String:
	return couple.get("partner_name", "")


## Olvida todo (al cerrar sesión).
func clear() -> void:
	couple = CoupleState.normalize_couple({})
	partner = {}
	home = CoupleState.normalize_home({})
	partner_online = false
	partner_intention = {}
	GameServer.socket.follow([])
	EventBus.couple_changed.emit()


## Copia lo que respondió el servidor (game_load, couple_load o un pedido de
## pareja): {couple, partner, home}.
func apply_answer(data: Dictionary) -> void:
	if data.has("couple"):
		couple = CoupleState.normalize_couple(data["couple"])
	if data.has("partner"):
		partner = CoupleState.normalize_partner(data["partner"])
	if data.has("home"):
		home = CoupleState.normalize_home(data["home"])
	var partner_id: String = couple.get("partner_id", "")
	GameServer.socket.follow([partner_id] if partner_id != "" else [])
	if partner_id == "":
		_set_partner_presence(false, {})
	EventBus.couple_changed.emit()


## Vuelve a preguntar todo al servidor (sin bloquear los botones).
func refresh() -> void:
	if _refreshing or not GameServer.has_session():
		return
	_refreshing = true
	var result: Dictionary = await GameServer.call_rpc("couple_load", {})
	_refreshing = false
	if result["ok"]:
		apply_answer(result["data"])
		# El dinero también pudo cambiar (la pareja deshizo algo que pagué).
		if Economy.server_mode and not Economy.busy and result["data"].get("state") is Dictionary:
			Economy.apply_server_state(result["data"]["state"])


# --- Pedidos (cada uno espera al servidor) ---

func invite(username: String) -> Dictionary:
	return await _couple_request("couple_invite", {"username": username.strip_edges().to_lower()},
		"Invitación enviada a %s." % username.strip_edges().to_lower())


func cancel_invite() -> Dictionary:
	return await _couple_request("couple_cancel", {}, "Retiraste la invitación.")


func answer_invite(from_id: String, accept: bool) -> Dictionary:
	return await _couple_request("couple_answer", {"from_id": from_id, "accept": accept}, "")


## `kind` = "marry" o "move_in"; para mudarse, `home` = "mine" o "yours".
func propose(kind: String, home_choice := "") -> Dictionary:
	return await _couple_request("couple_propose", {"kind": kind, "home": home_choice},
		"Pedido enviado: %s tiene que responder." % partner_name())


func respond(accept: bool) -> Dictionary:
	return await _couple_request("couple_respond", {"accept": accept}, "")


func end_relation() -> Dictionary:
	return await _couple_request("couple_end", {}, "Terminaste la relación.")


## Interruptores: "drama", "family_mode", "pool_income".
func set_switch(name: String, value: bool) -> Dictionary:
	return await _couple_request("couple_switches", {name: value}, "")


func contribute(amount: int) -> Dictionary:
	var result := await _home_request("home_contribute", {"amount": amount})
	if result["ok"]:
		EventBus.toast.emit("Pusiste $%d en la caja de la casa." % amount)
	return result


func answer_request(id: int, approve: bool) -> Dictionary:
	var result := await _home_request("home_answer", {"id": id, "approve": approve})
	if result["ok"]:
		EventBus.toast.emit("Aprobado: ya está construido." if approve else "No lo aprobaste.")
		if approve:
			# La casa cambió: la escena principal se pone al día.
			EventBus.home_remote_changed.emit({"rev": Economy.house_rev, "kind": "approved", "text": ""})
	return result


## Pulido 1: un pedido con sus piezas, para previsualizarlo antes de
## responder. Devuelve {ok, request, writes} (writes listas para HouseData).
func get_request(id: int) -> Dictionary:
	var result := await _home_request("home_request", {"id": id})
	if not result["ok"]:
		return result
	var request: Dictionary = result["data"].get("request", {})
	var parsed: Variant = JSON.parse_string(str(request.get("writes_json", "[]")))
	return {"ok": true, "request": request, "writes": CloudSync.writes_from_server(parsed)}


func cancel_request(id: int) -> Dictionary:
	return await _home_request("home_cancel", {"id": id})


## Deshace un cambio menor del historial (normalmente, de la pareja).
func revert(entry_id: int) -> Dictionary:
	var result := await _home_request("home_revert", {"id": entry_id})
	if result["ok"]:
		EventBus.toast.emit("Listo: lo deshiciste.")
		EventBus.home_remote_changed.emit({"rev": Economy.house_rev, "kind": "revert", "text": ""})
	return result


func _couple_request(rpc_id: String, payload: Dictionary, done_text: String) -> Dictionary:
	if not Economy.can_request():
		return {"ok": false, "error": Economy.BUSY_TEXT}
	var result: Dictionary = await Economy.request(rpc_id, payload)
	var data: Dictionary = result.get("data", {})
	if data.has("couple"):
		apply_answer(data)
	if not result["ok"]:
		EventBus.toast.emit(result["error"])
		return result
	if done_text != "":
		EventBus.toast.emit(done_text)
	if data.get("home_changed", false):
		EventBus.home_reload_requested.emit()
	return result


func _home_request(rpc_id: String, payload: Dictionary) -> Dictionary:
	if not Economy.can_request():
		return {"ok": false, "error": Economy.BUSY_TEXT}
	var result: Dictionary = await Economy.request(rpc_id, payload)
	var data: Dictionary = result.get("data", {})
	if data.has("home"):
		home = CoupleState.normalize_home(data["home"])
		EventBus.couple_changed.emit()
	if not result["ok"]:
		EventBus.toast.emit(result["error"])
	else:
		refresh()
	return result


# --- Tiempo real ---

func _on_notification(code: int, _subject: String, content: Dictionary) -> void:
	var text := str(content.get("text", ""))
	match code:
		NOTIFY_COUPLE:
			if text != "":
				EventBus.toast.emit(text)
			if content.get("event", "") in ["moved_in", "ended"]:
				EventBus.home_reload_requested.emit()
			refresh()
		NOTIFY_HOME:
			EventBus.home_remote_changed.emit(content)
			var who := str(content.get("by_name", ""))
			# Aprobar o rechazar un pedido ya se avisa con su propio texto (104).
			if text != "" and who != "" and not content.get("kind", "") in ["approved", "rejected"]:
				var can_revert: bool = content.get("can_revert", false)
				EventBus.partner_notice.emit("%s %s" % [who, text], int(content.get("entry_id", 0)) if can_revert else 0)
			refresh()
		NOTIFY_REQUESTS:
			if text != "":
				EventBus.toast.emit(text)
			refresh()


func _on_presence_changed(user_id: String, online: bool, status: String) -> void:
	if user_id != couple.get("partner_id", ""):
		return
	var intention := CoupleState.decode_status(status) if online else {}
	# Si se conectó pero todavía no mandó qué hace, se mantiene lo último.
	if online and intention.is_empty():
		intention = partner_intention
	_set_partner_presence(online, intention)


func _set_partner_presence(online: bool, intention: Dictionary) -> void:
	partner_online = online
	partner_intention = intention
	EventBus.partner_presence_changed.emit(online, intention)


func _on_socket_changed(connected: bool) -> void:
	if connected:
		_status_dirty = not _my_intention.is_empty()
		refresh()  # Pudo pasar algo mientras no había conexión.


func _on_my_intention_changed(intention: Dictionary) -> void:
	_my_intention = intention
	_status_dirty = true
