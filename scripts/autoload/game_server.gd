extends Node
## Conexión con el servidor del juego (Nakama), por su API REST.
##
## Es un cliente propio y chico (pedidos HTTP) en vez del addon oficial: ver
## DECISIONES.md, "Cuentas y servidor". Lo que hace:
##   - Crear cuenta y entrar con usuario + contraseña.
##   - Recordar la sesión en user://session.json ("acceso único"): la próxima
##     vez entra solo. La contraseña NUNCA se guarda.
##   - Saber si hay conexión (EventBus.server_status_changed).
##   - Llamar funciones del servidor (RPC): game_load, game_import.
##   - Subir el personaje y las opciones a la nube después de guardar.
##
## No hace nada hasta que la pantalla de entrada llama a start(): así las
## pruebas y demos que no lo usan no hablan con el servidor.
##
## Cada pedido devuelve un diccionario:
##   {"ok": bool, "data": respuesta, "error": texto para el jugador,
##    "offline": true si no se pudo llegar al servidor, "code": código HTTP}

const CONFIG_PATH := "res://data/server.json"
## Las cuentas usan un correo "inventado" a partir del usuario: Nakama pide
## un correo para entrar con contraseña, pero el jugador solo ve su usuario.
const EMAIL_DOMAIN := "@neighborhood.local"
const MIN_PASSWORD_LENGTH := 8
## Usuario: 3 a 20 letras minúsculas, números o "_".
const USERNAME_PATTERN := "^[a-z0-9_]{3,20}$"
## Cada cuánto se revisa la conexión, y cada cuánto como mucho se sube a la nube.
const HEALTH_INTERVAL := 20.0
const UPLOAD_INTERVAL := 15.0
const OFFLINE_TEXT := "No se pudo conectar con el servidor. ¿Estás en la red de casa?"

## Dónde se recuerda la sesión (las demos usan otro archivo).
var session_path := "user://session.json"
## Dirección del servidor, por ejemplo "http://192.168.100.177:7350".
var base_url := ""
var server_key := ""
var timeout_seconds := 8.0
## Sesión actual (null = sin cuenta).
var session: ServerSession = null
var online := false
var active := false

var _health_timer := 0.0
var _upload_pending := false
var _uploading := false
var _last_upload_msec := -1000000
## Último valor subido de cada objeto (para no subir lo mismo dos veces).
var _uploaded_values: Dictionary = {}
var _status_known := false


func _ready() -> void:
	_load_config()
	_load_session()
	EventBus.game_saved.connect(_on_game_saved)


## Lo llama la pantalla de entrada: desde aquí se revisa la conexión y se sube
## a la nube.
func start() -> void:
	active = true
	_health_timer = 0.0


func _process(delta: float) -> void:
	if not active or session == null:
		return
	_health_timer -= delta
	if _health_timer <= 0.0:
		_health_timer = HEALTH_INTERVAL
		check_connection()
	if _upload_pending and online and not _uploading \
			and Time.get_ticks_msec() - _last_upload_msec >= UPLOAD_INTERVAL * 1000.0:
		upload_cloud()


func _notification(what: int) -> void:
	# Al pasar a segundo plano (SaveSystem ya guardó): subir lo que falte.
	if what == NOTIFICATION_APPLICATION_PAUSED and active and online and _upload_pending:
		upload_cloud()


# --- Cuenta ---

func has_session() -> bool:
	return session != null and session.is_valid()


func username() -> String:
	return session.username if session != null else ""


func user_id() -> String:
	return session.user_id if session != null else ""


## "192.168.100.177:7350" (para mostrar en pantalla).
func address_text() -> String:
	return base_url.trim_prefix("http://").trim_prefix("https://")


## Revisa usuario y contraseña antes de mandarlos. Devuelve el problema o "".
static func check_credentials(user: String, password: String) -> String:
	var regex := RegEx.create_from_string(USERNAME_PATTERN)
	if regex.search(user) == null:
		return "El usuario lleva de 3 a 20 letras minúsculas, números o _ (sin espacios ni tildes)."
	if password.length() < MIN_PASSWORD_LENGTH:
		return "La contraseña necesita al menos %d caracteres." % MIN_PASSWORD_LENGTH
	return ""


func register(user: String, password: String) -> Dictionary:
	return await _authenticate(user, password, true)


func login(user: String, password: String) -> Dictionary:
	return await _authenticate(user, password, false)


func _authenticate(user: String, password: String, create: bool) -> Dictionary:
	var problem := check_credentials(user, password)
	if problem != "":
		return _failure(problem)
	var path := "/v2/account/authenticate/email?create=%s" % ("true" if create else "false")
	if create:
		path += "&username=" + user.uri_encode()
	var result := await _request(HTTPClient.METHOD_POST, path,
		{"email": user + EMAIL_DOMAIN, "password": password}, _basic_auth())
	if result["ok"]:
		_set_session(ServerSession.from_tokens(result["data"].get("token", ""), result["data"].get("refresh_token", "")))
	elif result["code"] == 401:
		result["error"] = "Ese usuario ya existe y la contraseña no coincide." if create \
			else "Usuario o contraseña incorrectos."
	return result


## Entra con la sesión recordada (renueva el pase si hace falta).
func resume() -> Dictionary:
	if not has_session():
		return _failure("No hay sesión guardada.")
	return await _ensure_token()


## Cierra la sesión: el teléfono olvida la cuenta (la partida queda guardada).
func logout() -> void:
	session = null
	_uploaded_values.clear()
	_upload_pending = false
	if FileAccess.file_exists(session_path):
		DirAccess.remove_absolute(session_path)
	_emit_status()


# --- Partida en el servidor ---

## Carga la partida de la cuenta. Si la cuenta es nueva, primero importa
## `local_state` (como GameState.to_dict()). Devuelve lo de game_load.
func load_game(local_state: Dictionary) -> Dictionary:
	var result := await call_rpc("game_load", {})
	if result["ok"] and not result["data"].get("imported", false):
		result = await call_rpc("game_import", CloudSync.import_payload(local_state))
	return result


## Llama una función del servidor. `data` del resultado = lo que devolvió.
func call_rpc(id: String, payload: Dictionary) -> Dictionary:
	var token_result := await _ensure_token()
	if not token_result["ok"]:
		return token_result
	# Nakama recibe el contenido de una RPC como texto JSON dentro del JSON.
	var result := await _request(HTTPClient.METHOD_POST, "/v2/rpc/" + id, JSON.stringify(payload), _bearer_auth())
	if result["ok"]:
		var answer: Variant = JSON.parse_string(result["data"].get("payload", "{}"))
		result["data"] = answer if answer is Dictionary else {}
	return result


## Sube el personaje y las opciones (solo lo que cambió desde la última vez).
func upload_cloud(state := {}) -> Dictionary:
	if state.is_empty():
		state = GameState.to_dict()
	# Nunca se sube la partida de otra cuenta.
	if not has_session() or state.get("account", {}).get("user_id", "") != session.user_id:
		_upload_pending = false
		return _failure("La partida no es de esta cuenta.")
	var objects: Array = []
	for object in CloudSync.cloud_objects(state):
		if _uploaded_values.get(object["key"], "") != object["value"]:
			objects.append(object)
	_upload_pending = false
	if objects.is_empty():
		return {"ok": true, "data": {}, "error": "", "offline": false, "code": 200}
	_uploading = true
	_last_upload_msec = Time.get_ticks_msec()
	var result := await _ensure_token()
	if result["ok"]:
		result = await _request(HTTPClient.METHOD_PUT, "/v2/storage", {"objects": objects}, _bearer_auth())
	_uploading = false
	if result["ok"]:
		for object in objects:
			_uploaded_values[object["key"]] = object["value"]
	else:
		_upload_pending = true  # Se reintenta más tarde.
	return result


## ¿Responde el servidor? (no necesita sesión)
func check_connection() -> bool:
	var result := await _request(HTTPClient.METHOD_GET, "/healthcheck", null, "")
	return result["ok"]


func _on_game_saved(success: bool) -> void:
	if success and active:
		_upload_pending = true


# --- Sesión ---

## Si el pase corto está por vencer, pide uno nuevo con el pase largo.
func _ensure_token() -> Dictionary:
	var now := int(Time.get_unix_time_from_system())
	if not has_session():
		return _failure("Hace falta entrar con una cuenta.")
	if session.refresh_expired(now):
		logout()
		return _failure("La sesión venció: entrá de nuevo.", {"auth_lost": true})
	if not session.token_expiring(now):
		return {"ok": true, "data": {}, "error": "", "offline": false, "code": 200}
	var result := await _request(HTTPClient.METHOD_POST, "/v2/account/session/refresh",
		{"token": session.refresh_token}, _basic_auth())
	if result["ok"]:
		session.update_tokens(result["data"].get("token", ""), result["data"].get("refresh_token", ""))
		_save_session()
	elif result["code"] == 401:
		logout()
		result["error"] = "La sesión ya no vale: entrá de nuevo."
		result["auth_lost"] = true
	return result


func _set_session(new_session: ServerSession) -> void:
	session = new_session
	_save_session()
	_emit_status()


func _save_session() -> void:
	var file := FileAccess.open(session_path, FileAccess.WRITE)
	if file == null:
		push_error("Servidor: no se pudo guardar la sesión")
		return
	file.store_string(JSON.stringify(session.to_dict()))


func _load_session() -> void:
	session = null
	if not FileAccess.file_exists(session_path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(session_path))
	if data is Dictionary:
		var loaded := ServerSession.from_dict(data)
		if loaded.is_valid():
			session = loaded


## Cambia el archivo de la sesión (para las demos) y la vuelve a leer.
func use_session_file(path: String) -> void:
	session_path = path
	_load_session()


func _load_config() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if not data is Dictionary:
		push_error("Servidor: no se pudo leer %s" % CONFIG_PATH)
		data = {}
	var scheme := "https" if data.get("use_ssl", false) else "http"
	base_url = "%s://%s:%d" % [scheme, data.get("host", "127.0.0.1"), int(data.get("port", 7350))]
	server_key = data.get("server_key", "")
	timeout_seconds = float(data.get("timeout_seconds", 8))


# --- Pedidos HTTP ---

func _basic_auth() -> String:
	return "Basic " + Marshalls.utf8_to_base64(server_key + ":")


func _bearer_auth() -> String:
	return "Bearer " + session.token


## Hace un pedido y espera la respuesta (con `await`).
func _request(method: int, path: String, body: Variant, auth: String) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = timeout_seconds
	add_child(http)
	var headers := PackedStringArray(["Content-Type: application/json", "Accept: application/json"])
	if auth != "":
		headers.append("Authorization: " + auth)
	var text := "" if body == null else JSON.stringify(body)
	if http.request(base_url + path, headers, method, text) != OK:
		http.queue_free()
		_set_online(false)
		return _failure(OFFLINE_TEXT, {"offline": true})
	# request_completed devuelve [resultado, código HTTP, encabezados, cuerpo].
	var response: Array = await http.request_completed
	http.queue_free()
	if response[0] != HTTPRequest.RESULT_SUCCESS:
		_set_online(false)
		return _failure(OFFLINE_TEXT, {"offline": true})
	_set_online(true)
	var code: int = response[1]
	var raw: PackedByteArray = response[3]
	var data: Variant = JSON.parse_string(raw.get_string_from_utf8()) if raw.size() > 0 else {}
	if not data is Dictionary:
		data = {}
	if code >= 200 and code < 300:
		return {"ok": true, "data": data, "error": "", "offline": false, "code": code}
	return _failure(error_text(code, str(data.get("message", ""))), {"code": code, "data": data})


## Texto para el jugador a partir del error del servidor.
static func error_text(code: int, message: String) -> String:
	match code:
		409:
			return "Ese usuario ya existe: elegí otro."
		404:
			return "No hay ninguna cuenta con ese usuario."
		401:
			return "Usuario o contraseña incorrectos."
		400:
			if message.contains("Password"):
				return "La contraseña necesita al menos %d caracteres." % MIN_PASSWORD_LENGTH
	return "El servidor respondió con un error (%d): %s" % [code, message]


func _failure(text: String, extra := {}) -> Dictionary:
	var result := {"ok": false, "data": {}, "error": text, "offline": false, "code": 0}
	result.merge(extra, true)
	return result


func _set_online(value: bool) -> void:
	if value != online or not _status_known:
		online = value
		_status_known = true
		_emit_status()


func _emit_status() -> void:
	EventBus.server_status_changed.emit(online, username())
