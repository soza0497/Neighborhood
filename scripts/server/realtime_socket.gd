class_name RealtimeSocket
extends Node
## Conexión en TIEMPO REAL con el servidor (Nakama), por WebSocket (Fase 5).
##
## Es un cliente propio y chico, como el de la API REST (ver DECISIONES.md,
## "Tiempo real"). Usa el WebSocketPeer que trae Godot. Sirve para:
##   - Estar "conectado" a la vista de la pareja (presencia) y mandarle mi
##     estado: la INTENCIÓN de mi personaje ("cocinando, desde las 14:02").
##     Se mandan estados, no movimientos (VISION.md).
##   - Recibir avisos del servidor al instante (la pareja movió un mueble,
##     pidió permiso, aceptó la invitación...).
##
## Protocolo de Nakama (JSON): cada mensaje es un "sobre" con una sola clave
## que dice qué es, por ejemplo {"cid": "3", "status_update": {"status": "…"}}.
## "cid" numera los pedidos que esperan respuesta. Lo que llega solo:
##   {"notifications": {"notifications": [...]}}          avisos
##   {"status_presence_event": {"joins": [...], "leaves": [...]}}  presencia
##
## Si se corta, vuelve a conectar solo (espera cada vez un poco más, hasta
## RECONNECT_MAX segundos). Quien lo usa (GameServer) le da el pase (token).

## Se conectó o se desconectó.
signal connection_changed(connected: bool)
## Llegó un aviso del servidor. `content` ya viene como diccionario.
signal notification_received(code: int, subject: String, content: Dictionary)
## Cambió la presencia de alguien que sigo: `online` y su estado (texto).
signal presence_changed(user_id: String, online: bool, status: String)

const RECONNECT_MIN := 2.0
const RECONNECT_MAX := 30.0
## Si el pedido de conexión no termina en este tiempo, se reintenta.
const CONNECT_TIMEOUT := 10.0

## Dirección del servidor sin el esquema ("192.168.100.177:7350").
var host_port := ""
var use_ssl := false
## Devuelve el token actual (lo pone GameServer). Puede ser "" si no hay sesión.
var token_provider: Callable
## true = se quiere estar conectado (si se corta, se reconecta).
var wanted := false
var connected := false

var _peer: WebSocketPeer
var _next_cid := 1
var _retry_in := 0.0
var _backoff := RECONNECT_MIN
var _connecting_for := 0.0
## A quiénes sigo (ids) y mi último estado (se vuelven a mandar al reconectar).
var _following: Array = []
var _status := ""
var _status_sent := ""
## Presencias de los que sigo: id → {sesión → estado}. Alguien puede estar
## conectado desde dos teléfonos.
var _presences: Dictionary = {}


## Empieza (o deja de intentar) estar conectado.
func set_wanted(value: bool) -> void:
	wanted = value
	if not wanted:
		close()
	else:
		_retry_in = 0.0


func close() -> void:
	if _peer != null:
		_peer.close()
		_peer = null
	_set_connected(false)


## Seguir a estos jugadores (por id): avisa cuando se conectan, se van o
## cambian su estado. Reemplaza la lista anterior.
func follow(user_ids: Array) -> void:
	var removed: Array = _following.filter(func(id: String) -> bool: return not id in user_ids)
	_following = user_ids.duplicate()
	for id in removed:
		if _presences.has(id):
			_presences.erase(id)
			presence_changed.emit(id, false, "")
	if connected:
		if not removed.is_empty():
			_send({"status_unfollow": {"user_ids": removed}})
		if not _following.is_empty():
			_send({"status_follow": {"user_ids": _following}})


## Mi estado (lo ven quienes me siguen). Se manda al estar conectado.
func update_status(status: String) -> void:
	_status = status
	if connected and _status != _status_sent:
		_status_sent = _status
		_send({"status_update": {"status": _status}})


func is_online(user_id: String) -> bool:
	return not (_presences.get(user_id, {}) as Dictionary).is_empty()


## Último estado conocido de alguien que sigo ("" si no está o no mandó).
func status_of(user_id: String) -> String:
	var sessions: Dictionary = _presences.get(user_id, {})
	if sessions.is_empty():
		return ""
	return str(sessions.values().back())


func _process(delta: float) -> void:
	if _peer == null:
		if wanted:
			_retry_in -= delta
			if _retry_in <= 0.0:
				_open()
		return
	_peer.poll()
	match _peer.get_ready_state():
		WebSocketPeer.STATE_CONNECTING:
			_connecting_for += delta
			if _connecting_for > CONNECT_TIMEOUT:
				_drop()
		WebSocketPeer.STATE_OPEN:
			if not connected:
				_on_open()
			while _peer != null and _peer.get_available_packet_count() > 0:
				_on_message(_peer.get_packet().get_string_from_utf8())
		WebSocketPeer.STATE_CLOSED:
			_drop()


func _open() -> void:
	var token: String = token_provider.call() if token_provider.is_valid() else ""
	if token == "" or host_port == "":
		_retry_in = _backoff
		return
	_peer = WebSocketPeer.new()
	# Nakama: status=true = aparecer "conectado" para quienes me siguen.
	var url := "%s://%s/ws?lang=es&status=true&token=%s" % ["wss" if use_ssl else "ws", host_port, token.uri_encode()]
	_connecting_for = 0.0
	if _peer.connect_to_url(url) != OK:
		_drop()


## Se cortó (o no se pudo conectar): se espera y se reintenta.
func _drop() -> void:
	if _peer != null:
		_peer.close()
	_peer = null
	_retry_in = _backoff
	_backoff = minf(_backoff * 2.0, RECONNECT_MAX)
	# Sin conexión no sé si los demás siguen conectados.
	for id in _presences.keys():
		_presences.erase(id)
		presence_changed.emit(id, false, "")
	_set_connected(false)


func _on_open() -> void:
	_backoff = RECONNECT_MIN
	_set_connected(true)
	_status_sent = ""
	if not _following.is_empty():
		_send({"status_follow": {"user_ids": _following}})
	if _status != "":
		update_status(_status)


func _set_connected(value: bool) -> void:
	if value != connected:
		connected = value
		connection_changed.emit(connected)


func _send(envelope: Dictionary) -> void:
	if _peer == null or _peer.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	envelope["cid"] = str(_next_cid)
	_next_cid += 1
	_peer.send_text(JSON.stringify(envelope))


## Un mensaje del servidor.
func _on_message(text: String) -> void:
	var envelope: Variant = JSON.parse_string(text)
	if not envelope is Dictionary:
		return
	handle_envelope(envelope)


## Procesa un sobre de Nakama (separado de la red para poder probarlo).
func handle_envelope(envelope: Dictionary) -> void:
	if envelope.has("error"):
		push_warning("Tiempo real: el servidor respondió un error: %s" % JSON.stringify(envelope["error"]))
	if envelope.get("notifications") is Dictionary:
		for n in envelope["notifications"].get("notifications", []):
			var content: Variant = JSON.parse_string(str(n.get("content", "{}")))
			notification_received.emit(int(n.get("code", 0)), str(n.get("subject", "")),
				content if content is Dictionary else {})
	# Respuesta a status_follow: quiénes de los que sigo ya están conectados.
	if envelope.get("status") is Dictionary:
		_apply_presences([], envelope["status"].get("presences", []))
	if envelope.get("status_presence_event") is Dictionary:
		var event: Dictionary = envelope["status_presence_event"]
		_apply_presences(event.get("leaves", []), event.get("joins", []))


## Aplica quién se fue y quién llegó, y avisa UNA vez por persona (al cambiar
## de estado llegan las dos cosas juntas: se va el estado viejo y entra el
## nuevo; no tiene que parecer que se desconectó).
func _apply_presences(leaves: Array, joins: Array) -> void:
	var touched: Array = []
	for p in leaves:
		var id := str(p.get("user_id", ""))
		if _presences.has(id):
			(_presences[id] as Dictionary).erase(str(p.get("session_id", "")))
			if not id in touched:
				touched.append(id)
	var last_status := {}
	for p in joins:
		var id := str(p.get("user_id", ""))
		if id == "" or not id in _following:
			continue
		var sessions: Dictionary = _presences.get(id, {})
		sessions[str(p.get("session_id", ""))] = str(p.get("status", ""))
		_presences[id] = sessions
		last_status[id] = str(p.get("status", ""))
		if not id in touched:
			touched.append(id)
	for id in touched:
		var sessions: Dictionary = _presences.get(id, {})
		if sessions.is_empty():
			_presences.erase(id)
			presence_changed.emit(id, false, "")
		else:
			presence_changed.emit(id, true, last_status.get(id, status_of(id)))
