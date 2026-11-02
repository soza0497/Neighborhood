extends CanvasLayer
## Interfaz provisional de la Fase 0: muestra cuadros por segundo, datos de
## prueba y un botón para centrar la cámara.

@onready var _fps_label: Label = %FpsLabel
@onready var _info_label: Label = %InfoLabel
@onready var _center_button: Button = %CenterButton

var _catalog_count := 0
var _last_save_text := "sin guardar todavía"


func _ready() -> void:
	_center_button.pressed.connect(EventBus.camera_reset_requested.emit)
	EventBus.game_saved.connect(_on_game_saved)
	# El catálogo ya se cargó antes que esta escena (es un autoload).
	_catalog_count = Catalog.items.size()
	if SaveSystem.has_save():
		_last_save_text = "partida cargada"
	_update_info()


func _process(_delta: float) -> void:
	_fps_label.text = "%d FPS" % Engine.get_frames_per_second()


func _on_game_saved(success: bool) -> void:
	_last_save_text = "guardado OK" if success else "ERROR al guardar"
	_update_info()


func _update_info() -> void:
	_info_label.text = "Neighborhood %s · Catálogo: %d objetos · %s" % [
		ProjectSettings.get_setting("application/config/version"),
		_catalog_count,
		_last_save_text,
	]
