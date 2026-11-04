extends Node
## Ganchos de sonido (Pulido 2B).
##
## El juego pide sonidos por NOMBRE (Sound.play("build")); si en
## assets/audio/ hay un archivo con ese nombre (.ogg, .wav o .mp3) suena, y si
## no, no pasa nada. Así los sonidos se pueden ir agregando de a uno sin tocar
## código. Nombres que el juego pide hoy: build, cancel, coin, level_up, error,
## door, step, truck, box_open, cough, siren, car_pass.
##
## Volúmenes (Menú → Info): general, efectos y música; se guardan en la partida
## (GameState.settings: volume_master, volume_sfx, volume_music; 0 a 1).
## Si no hay ningún sonido, los controles igual funcionan (no hacen nada).

const AUDIO_DIR := "res://assets/audio/"
const EXTENSIONS := ["ogg", "wav", "mp3"]
const POOL_SIZE := 6
const BUS_SFX := "SFX"
const BUS_MUSIC := "Music"

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	for bus in [BUS_SFX, BUS_MUSIC]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var index := AudioServer.get_bus_count() - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, "Master")
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = BUS_SFX
		add_child(player)
		_pool.append(player)
	apply_volumes()
	# Ganchos: algunos eventos del juego piden su sonido solos.
	EventBus.level_up.connect(func(_level: int, _unlocked: Array) -> void: play("level_up"))
	EventBus.build_confirm_requested.connect(func() -> void: play("build"))
	EventBus.build_cancel_requested.connect(func() -> void: play("cancel"))
	EventBus.construction_accelerate_requested.connect(func() -> void: play("coin"))


## Suena `sound_name` si existe. Devuelve true si sonó.
func play(sound_name: String, volume_db := 0.0) -> bool:
	var stream := _stream(sound_name)
	if stream == null:
		return false
	var player := _pool[_next]
	_next = (_next + 1) % _pool.size()
	player.stream = stream
	player.volume_db = volume_db
	player.play()
	return true


## ¿Hay un archivo de sonido con ese nombre?
func has_sound(sound_name: String) -> bool:
	return _stream(sound_name) != null


func _stream(sound_name: String) -> AudioStream:
	if _streams.has(sound_name):
		return _streams[sound_name]
	var found: AudioStream = null
	for extension in EXTENSIONS:
		var path := "%s%s.%s" % [AUDIO_DIR, sound_name, extension]
		if ResourceLoader.exists(path):
			found = load(path)
			break
	_streams[sound_name] = found
	return found


## Volumen (0 a 1) de "master", "sfx" o "music".
func volume(kind: String) -> float:
	return clampf(float(GameState.settings.get("volume_" + kind, 1.0 if kind != "music" else 0.6)), 0.0, 1.0)


func set_volume(kind: String, value: float) -> void:
	GameState.settings["volume_" + kind] = clampf(value, 0.0, 1.0)
	apply_volumes()


## Pasa los volúmenes guardados a los buses de audio.
func apply_volumes() -> void:
	_set_bus("Master", volume("master"))
	_set_bus(BUS_SFX, volume("sfx"))
	_set_bus(BUS_MUSIC, volume("music"))


func _set_bus(bus: String, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, linear <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.001)))
