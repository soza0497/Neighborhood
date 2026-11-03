extends Node
## Estado de la partida en memoria: todo lo que se guarda vive aquí.
##
## Regla: GameState solo GUARDA datos, no tiene lógica de juego.
## Cada sistema copia su estado aquí cuando oye EventBus.game_saving, y lo
## lee de aquí al arrancar. SaveSystem convierte esto en un archivo.
##
## Cada fase agregará sus secciones (casa, personaje, dinero...).

## Posición, giro y zoom de la cámara. Vacío = usar los valores por defecto.
var camera: Dictionary = {}
## La casa del jugador (ver HouseData.to_dict). Vacío = lote sin construir.
var house: Dictionary = {}


## Vuelve todo a una partida nueva.
func reset() -> void:
	camera = {}
	house = {}


## Convierte el estado en un diccionario simple que se puede escribir en JSON.
func to_dict() -> Dictionary:
	return {
		"camera": camera,
		"house": house,
	}


## Llena el estado a partir de un diccionario leído del archivo.
func from_dict(data: Dictionary) -> void:
	reset()
	camera = data.get("camera", {})
	house = data.get("house", {})
