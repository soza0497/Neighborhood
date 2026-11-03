extends Node
## Guarda y carga la partida en un archivo local (JSON).
##
## `user://` es una carpeta privada del juego:
## - En la PC: ~/.local/share/godot/app_userdata/Neighborhood/
## - En Android: la carpeta interna de la app (no se ve sin permisos).
##
## Se guarda solo al salir o al mandar el juego a segundo plano.

const SAVE_PATH := "user://save.json"
const TEMP_PATH := "user://save.json.tmp"
## Copia del guardado anterior: si el archivo principal se daña, se usa esta.
const BACKUP_PATH := "user://save.json.bak"
## Copia de una partida vieja, antes de convertirla a un formato nuevo.
const PRE_MIGRATION_PATH := "user://save.pre_migration.json"

## Versión del formato del archivo. Subila cuando cambie la forma de los
## datos guardados (la Fase 3 agrega migraciones de versiones viejas).
const FORMAT_VERSION := 2


func _ready() -> void:
	load_game()


func _notification(what: int) -> void:
	# Android avisa con PAUSED cuando el juego pasa a segundo plano (puede que
	# el sistema lo cierre después sin más aviso). En la PC, al cerrar la ventana.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Guarda la partida. Devuelve true si salió bien.
func save_game() -> bool:
	EventBus.game_saving.emit()

	var data := {
		"format_version": FORMAT_VERSION,
		"saved_at": Time.get_datetime_string_from_system(true),
		"state": GameState.to_dict(),
	}

	# Primero se escribe un archivo temporal y después se renombra: si el
	# teléfono se apaga a mitad de camino, el guardado anterior queda intacto.
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Guardado: no se pudo escribir (%s)" % error_string(FileAccess.get_open_error()))
		EventBus.game_saved.emit(false)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

	# El guardado bueno anterior se conserva como respaldo.
	if has_save():
		DirAccess.copy_absolute(SAVE_PATH, BACKUP_PATH)

	var err := DirAccess.rename_absolute(TEMP_PATH, SAVE_PATH)
	if err != OK:
		push_error("Guardado: no se pudo reemplazar el archivo (%s)" % error_string(err))
		EventBus.game_saved.emit(false)
		return false

	EventBus.game_saved.emit(true)
	return true


## Carga la partida en GameState. Si no hay archivo, empieza una nueva.
## Si el archivo está dañado, prueba con la copia de respaldo.
func load_game() -> bool:
	if not has_save():
		GameState.reset()
		return false

	var data := _read_file(SAVE_PATH)
	if data.is_empty():
		push_error("Carga: el archivo de guardado está dañado; se prueba con el respaldo")
		data = _read_file(BACKUP_PATH)
	if data.is_empty():
		push_error("Carga: no hay respaldo que sirva; se empieza de cero")
		GameState.reset()
		return false

	var version: int = data.get("format_version", 0)
	if version > FORMAT_VERSION:
		push_error("Carga: el guardado es de una versión más nueva del juego (%d)" % version)
		GameState.reset()
		return false
	if version < FORMAT_VERSION:
		# Antes de convertirla, se guarda una copia de la partida vieja.
		DirAccess.copy_absolute(SAVE_PATH, PRE_MIGRATION_PATH)
		data = SaveMigrations.migrate(data, FORMAT_VERSION)

	GameState.from_dict(data.get("state", {}))
	EventBus.game_loaded.emit()
	return true


## Fase 4: si en este teléfono entra otra cuenta, la partida de la anterior
## se aparta en su propio archivo (no se pisa) y vuelve si esa cuenta entra.
func account_save_path(user_id: String) -> String:
	return "user://save.account_%s.json" % user_id.validate_filename()


## Aparta la partida actual (del archivo) como la de `user_id`.
func stash_for_account(user_id: String) -> void:
	if has_save() and user_id != "":
		DirAccess.copy_absolute(SAVE_PATH, account_save_path(user_id))


## La partida apartada de `user_id` (como GameState.to_dict()), o {} si no hay.
func load_account_stash(user_id: String) -> Dictionary:
	var data := _read_file(account_save_path(user_id))
	if data.is_empty() or int(data.get("format_version", 0)) > FORMAT_VERSION:
		return {}
	if int(data.get("format_version", 0)) < FORMAT_VERSION:
		data = SaveMigrations.migrate(data, FORMAT_VERSION)
	return data.get("state", {})


## Lee un archivo de guardado. Devuelve {} si no existe o está dañado.
func _read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		return {}
	return json.data
