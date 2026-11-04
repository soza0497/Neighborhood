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
## El personaje del jugador (ver Character.to_dict). Vacío = personaje nuevo.
var character: Dictionary = {}
## Reloj del juego: {"minutes": minutos desde el inicio}.
var clock: Dictionary = {}
## Dinero, experiencia, piezas descubiertas y empleo (ver Economy.to_dict).
var economy: Dictionary = {}
## Opciones del jugador (menú): {"show_fps": bool, "show_hints": bool}.
var settings: Dictionary = {}
## Cuenta del servidor a la que pertenece esta partida: {"user_id", "username"}.
## Vacío = partida de antes de la Fase 4 (todavía sin cuenta).
var account: Dictionary = {}
## Fase 6: un servicio del restaurante jugado que el servidor todavía no
## cobró (sin conexión al terminar): {"actions": [...], "started_unix"}.
var restaurant: Dictionary = {}
## Pulido 2C: la parcela (semilla, obstáculos limpiados, servicios en camino) en
## partidas SIN servidor, y las cajas de entrega sin abrir.
var parcel: Dictionary = {}
var delivery: Dictionary = {}


## Vuelve todo a una partida nueva.
func reset() -> void:
	camera = {}
	house = {}
	character = {}
	clock = {}
	economy = {}
	settings = {}
	account = {}
	restaurant = {}
	parcel = {}
	delivery = {}


## Convierte el estado en un diccionario simple que se puede escribir en JSON.
func to_dict() -> Dictionary:
	return {
		"camera": camera,
		"house": house,
		"character": character,
		"clock": clock,
		"economy": economy,
		"settings": settings,
		"account": account,
		"restaurant": restaurant,
		"parcel": parcel,
		"delivery": delivery,
	}


## Llena el estado a partir de un diccionario leído del archivo.
func from_dict(data: Dictionary) -> void:
	reset()
	camera = data.get("camera", {})
	house = data.get("house", {})
	character = data.get("character", {})
	clock = data.get("clock", {})
	economy = data.get("economy", {})
	settings = data.get("settings", {})
	account = data.get("account", {})
	restaurant = data.get("restaurant", {})
	parcel = data.get("parcel", {})
	delivery = data.get("delivery", {})
