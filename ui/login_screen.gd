extends Control
## Pantalla de entrada (Fase 4): la cuenta del servidor, antes de jugar.
##
## - Con sesión recordada: entra sola, sin pedir la contraseña.
## - Sin sesión: usuario + contraseña → "Entrar" o "Crear cuenta".
## - Sin servidor (fuera de casa): si ya hay cuenta, se puede jugar sin
##   conexión con la partida del teléfono. La primera vez hay que estar en la
##   red de casa para crear la cuenta.
##
## Al entrar se carga la partida de la cuenta (game_load; si es nueva, se
## importa la del teléfono), se une con la local (CloudSync) y se abre el juego.
## Desde la Fase 4B, con cuenta el servidor manda en el dinero y la casa
## (Economy.use_server): sin conexión se puede vivir pero no construir.

const MAIN_SCENE := "res://scenes/main.tscn"

@onready var _status_label: Label = %StatusLabel
@onready var _form: Control = %Form
@onready var _user_edit: LineEdit = %UserEdit
@onready var _password_edit: LineEdit = %PasswordEdit
@onready var _login_button: Button = %LoginButton
@onready var _register_button: Button = %RegisterButton
@onready var _error_label: Label = %ErrorLabel
@onready var _retry_box: Control = %RetryBox
@onready var _retry_button: Button = %RetryButton
@onready var _offline_button: Button = %OfflineButton
@onready var _server_label: Label = %ServerLabel

## true mientras se espera al servidor (los botones no hacen nada).
var _busy := false


func _ready() -> void:
	_password_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PASSWORD
	_login_button.pressed.connect(_on_login_pressed.bind(false))
	_register_button.pressed.connect(_on_login_pressed.bind(true))
	_password_edit.text_submitted.connect(func(_text: String) -> void: _on_login_pressed(false))
	_retry_button.pressed.connect(_on_retry_pressed)
	_offline_button.pressed.connect(_enter_game)
	_server_label.text = "Servidor: " + GameServer.address_text()

	GameServer.start()
	if GameServer.has_session():
		_connect_with_session()
	else:
		_show_form("Entrá con tu cuenta o creá una nueva.")


func _connect_with_session() -> void:
	_show_waiting("Entrando como %s…" % GameServer.username())
	var result: Dictionary = await GameServer.resume()
	if result["ok"]:
		await _load_and_enter()
	else:
		_show_failure(result)


func _on_login_pressed(create: bool) -> void:
	if _busy:
		return
	var user := _user_edit.text.strip_edges().to_lower()
	var password := _password_edit.text
	var problem := GameServer.check_credentials(user, password)
	if problem != "":
		_show_form("Revisá los datos.", problem)
		return
	_show_waiting("Creando la cuenta…" if create else "Entrando…")
	var result: Dictionary
	if create:
		result = await GameServer.register(user, password)
	else:
		result = await GameServer.login(user, password)
	_password_edit.text = ""  # La contraseña no se queda en la pantalla.
	if result["ok"]:
		await _load_and_enter()
	else:
		_show_form("No se pudo entrar.", result["error"])


func _on_retry_pressed() -> void:
	if _busy:
		return
	if GameServer.has_session():
		_connect_with_session()
	else:
		_show_form("Entrá con tu cuenta o creá una nueva.")


## Trae la partida de la cuenta, la une con la del teléfono y abre el juego.
func _load_and_enter() -> void:
	_show_waiting("Cargando tu partida…")
	var user_id := GameServer.user_id()
	var local := _local_state_for(user_id)
	var result: Dictionary = await GameServer.load_game(local)
	if not result["ok"]:
		_show_failure(result)
		return
	GameServer.game_loaded = true
	GameState.from_dict(CloudSync.merge(local, result["data"], user_id, GameServer.username()))
	Economy.from_dict(GameState.economy)
	Economy.use_server(true)
	Economy.apply_server_state(result["data"])
	Couple.apply_answer(result["data"])
	GameServer.start_realtime()
	SaveSystem.save_game()
	_enter_game()


## La partida del teléfono que le toca a esta cuenta. Si la que está guardada
## es de otra cuenta, se aparta (no se pierde) y se usa la de esta, si había.
func _local_state_for(user_id: String) -> Dictionary:
	var owner: String = GameState.account.get("user_id", "")
	if owner == "" or owner == user_id:
		return GameState.to_dict()
	SaveSystem.stash_for_account(owner)
	return SaveSystem.load_account_stash(user_id)


## Abre el juego. Con cuenta (aunque sea sin conexión) manda el servidor.
func _enter_game() -> void:
	Economy.use_server(GameServer.has_session())
	get_tree().change_scene_to_file(MAIN_SCENE)


# --- Qué se muestra ---

func _show_waiting(text: String) -> void:
	_busy = true
	_status_label.text = text
	_form.hide()
	_error_label.hide()
	_retry_box.hide()


func _show_form(status: String, error := "") -> void:
	_busy = false
	_status_label.text = status
	_form.show()
	_retry_box.hide()
	_error_label.text = error
	_error_label.visible = error != ""
	if GameServer.username() != "":
		_user_edit.text = GameServer.username()


func _show_failure(result: Dictionary) -> void:
	if result.get("auth_lost", false) or not GameServer.has_session():
		_show_form("Entrá con tu cuenta.", result["error"])
		_retry_box.visible = result.get("offline", false)
		_offline_button.hide()
		return
	_busy = false
	_form.hide()
	_retry_box.show()
	_offline_button.show()
	_error_label.text = result["error"]
	_error_label.show()
	if result.get("offline", false):
		_status_label.text = "Sin conexión con el servidor.\nPodés jugar sin conexión: tu partida se guarda en el teléfono."
	else:
		_status_label.text = "Hubo un problema al cargar tu partida."
