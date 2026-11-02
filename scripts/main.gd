extends Node3D
## Escena principal. Por ahora solo conecta la cámara con el guardado:
## al arrancar pone la cámara donde quedó, y al guardar anota dónde está.

@onready var _camera_rig: CameraRig = $CameraRig


func _ready() -> void:
	# SaveSystem ya cargó la partida antes de que exista esta escena.
	if not GameState.camera.is_empty():
		_camera_rig.set_state(GameState.camera)
	EventBus.game_saving.connect(_on_game_saving)


func _on_game_saving() -> void:
	GameState.camera = _camera_rig.get_state()
