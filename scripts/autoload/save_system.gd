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

## Versión del formato del archivo. Subila cuando cambie la forma de los
## datos guardados (la Fase 3 agrega migraciones de versiones viejas).
const FORMAT_VERSION := 1


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

	var err := DirAccess.rename_absolute(TEMP_PATH, SAVE_PATH)
	if err != OK:
		push_error("Guardado: no se pudo reemplazar el archivo (%s)" % error_string(err))
		EventBus.game_saved.emit(false)
		return false

	EventBus.game_saved.emit(true)
	return true


## Carga la partida en GameState. Si no hay archivo, empieza una nueva.
func load_game() -> bool:
	if not has_save():
		GameState.reset()
		return false

	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(SAVE_PATH)) != OK:
		push_error("Carga: el archivo de guardado está dañado; se empieza de cero")
		GameState.reset()
		return false

	var data: Dictionary = json.data
	var version: int = data.get("format_version", 0)
	if version > FORMAT_VERSION:
		push_error("Carga: el guardado es de una versión más nueva del juego (%d)" % version)
		GameState.reset()
		return false

	GameState.from_dict(data.get("state", {}))
	EventBus.game_loaded.emit()
	return true
