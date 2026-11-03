extends Node
## Reloj del juego.
##
## A velocidad x1, 1 segundo real = 1 minuto del juego (un día dura 24 minutos
## reales). El reloj se detiene en modo construir y cuando está en pausa.
## Todo lo que depende del tiempo (necesidades, acciones) pregunta aquí cuántos
## minutos del juego pasaron, así la velocidad cambia todo junto.

## El reloj cambió de velocidad o de pausa.
signal speed_changed(speed: int)

## Velocidades posibles (el botón de la interfaz pasa de una a otra).
const SPEEDS := [1, 3, 10]
## Hora a la que empieza una partida nueva (en minutos: 8:00).
const START_MINUTES := 8 * 60

## Minutos del juego desde que empezó la partida.
var minutes := float(START_MINUTES)
var speed := 1
var paused := false


func _process(delta: float) -> void:
	minutes += game_minutes(delta)


## Cuántos minutos del juego equivalen a `delta` segundos reales ahora.
func game_minutes(delta: float) -> float:
	return 0.0 if paused else delta * speed


## Pasa a la siguiente velocidad (x1 → x3 → x10 → x1).
func cycle_speed() -> void:
	speed = SPEEDS[(SPEEDS.find(speed) + 1) % SPEEDS.size()]
	speed_changed.emit(speed)


func set_paused(value: bool) -> void:
	paused = value
	speed_changed.emit(speed)


## Día actual (empieza en 1).
func day() -> int:
	return int(minutes / 1440.0) + 1


## Hora del día como texto, por ejemplo "08:30".
func time_text() -> String:
	var in_day := int(minutes) % 1440
	return "%02d:%02d" % [in_day / 60, in_day % 60]
