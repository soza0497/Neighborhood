class_name FoundationQueue
extends Node
## Pulido 6A (4): cimientos SOBRE obstáculos (árboles, rocas, laguitos, tocones, maleza).
##
## Antes, una celda con un obstáculo salía en rojo y «no se ponía». Ahora, al confirmar
## cimientos que cubren obstáculos:
##   1. Los cimientos de las celdas libres se construyen como siempre.
##   2. Por cada obstáculo cubierto se PIDE el servicio que lo retira (leñador, jardinero,
##      cuadrilla con vehículo… ver 6B). Nada de limpiar celda por celda: es una sola
##      confirmación para todo.
##   3. Los cimientos de esa zona quedan en esta cola y se colocan SOLOS cuando el
##      obstáculo ya fue retirado (cuando la parcela avisa que cambió).
##
## GANCHO PARA EL EQUIPO DE SERVICIOS (6B): al pedir los servicios se emite
## `EventBus.foundation_services_requested(obstacle_ids, writes)`. Por defecto esta clase
## llama sola al servicio de siempre (`Parcel.call_service`); si 6B quiere pedirlo con
## sus vehículos, pone `use_default_services = false` y escucha esa señal. Para avisar que
## un obstáculo ya no está, basta con que `Parcel.cleared` lo tenga y salte `Parcel.changed`
## (lo que ya pasa hoy al terminar el servicio): la cola lo detecta y coloca los cimientos.
##
## Lo pendiente se guarda en las opciones (`settings["pending_foundations"]`), solo en este
## teléfono (CloudSync.LOCAL_ONLY_SETTINGS).

## Se pidieron servicios para estos obstáculos (ids) por culpa de unos cimientos.
signal services_requested(obstacle_ids: Array)
## Cambió lo que espera en la cola.
signal queue_changed

const SETTINGS_KEY := "pending_foundations"

var house: HouseData
var builder: HouseBuilder
## false = alguien más (6B) atiende la señal EventBus.foundation_services_requested.
var use_default_services := true

## obstacle_id → lista de escrituras de cimientos {level, layer, key, value}.
var _queue: Dictionary = {}
var _placing := false


func setup(new_house: HouseData, new_builder: HouseBuilder) -> void:
	house = new_house
	builder = new_builder
	_load()
	if not Parcel.changed.is_connected(process_queue):
		Parcel.changed.connect(process_queue)
	process_queue.call_deferred()


# --- Lo puro (se prueba sin pantalla) ---

## Separa las escrituras bloqueadas de unos cimientos en las que se pueden resolver
## retirando un obstáculo y las imposibles (terreno todavía cerrado, fuera del lote…).
## `obstacle_of` = función (celda: Vector2i) → id del obstáculo ("" si no hay).
## Devuelve {"deferred": {id: [escrituras]}, "impossible": [escrituras]}.
static func split_blocked(blocked: Array, obstacle_of: Callable) -> Dictionary:
	var deferred := {}
	var impossible: Array = []
	for w in blocked:
		if w["layer"] != "foundation" or w["value"] == null or int(w["level"]) != 0:
			impossible.append(w)
			continue
		var id: String = str(obstacle_of.call(HouseGrid.key_to_cell(w["key"])))
		if id == "":
			impossible.append(w)
			continue
		if not deferred.has(id):
			deferred[id] = []
		deferred[id].append(w)
	return {"deferred": deferred, "impossible": impossible}


## Cuánto cuesta en total llamar los servicios de esos obstáculos (`cost_of` = id → plata).
static func total_service_cost(ids: Array, cost_of: Callable) -> int:
	var total := 0
	for id in ids:
		total += int(cost_of.call(str(id)))
	return total


## Las escrituras de la cola cuyos obstáculos ya fueron retirados, y los ids que quedan esperando.
## `is_cleared` = función (id) → bool. Devuelve {"ready": {id: [escrituras]}, "waiting": [ids]}.
static func ready_entries(queue: Dictionary, is_cleared: Callable) -> Dictionary:
	var ready := {}
	var waiting: Array = []
	for id in queue:
		if bool(is_cleared.call(str(id))):
			ready[id] = queue[id]
		else:
			waiting.append(id)
	return {"ready": ready, "waiting": waiting}


# --- Pedir servicios ---

## Cuántos obstáculos esperan que los retiren para poner cimientos.
func waiting_count() -> int:
	return _queue.size()


func waiting_ids() -> Array:
	return _queue.keys()


## Pide el servicio de cada obstáculo (`deferred` = lo que devuelve split_blocked) y deja los
## cimientos esperando. Devuelve {"requested": [ids], "failed": {id: motivo}}.
func request(deferred: Dictionary) -> Dictionary:
	var requested: Array = []
	var failed := {}
	for id in deferred:
		if not _queue.has(id):
			_queue[id] = []
		_queue[id].append_array(deferred[id])
		requested.append(id)
	_save()
	queue_changed.emit()
	if requested.is_empty():
		return {"requested": [], "failed": {}}
	var all_writes: Array = []
	for id in requested:
		all_writes.append_array(deferred[id])
	# El gancho: cualquiera puede atender el pedido (6B, con vehículos).
	EventBus.foundation_services_requested.emit(requested, all_writes)
	services_requested.emit(requested)
	if use_default_services:
		for id in requested:
			if Parcel.cleared.has(id) or Parcel.pending.has(id):
				continue  # Ya se limpió o ya viene en camino.
			var result: Dictionary = await Parcel.call_service(id, house)
			if not result["ok"]:
				failed[id] = str(result["error"])
				_queue.erase(id)
		_save()
		queue_changed.emit()
	return {"requested": requested, "failed": failed}


# --- Colocar los cimientos cuando el obstáculo ya no está ---

## Revisa la cola: lo que ya está libre se construye. Se llama sola cuando la parcela cambia.
func process_queue() -> void:
	if _placing or _queue.is_empty() or builder == null or house == null:
		return
	var found := ready_entries(_queue, func(id: String) -> bool: return Parcel.cleared.has(id))
	if found["ready"].is_empty():
		return
	_placing = true
	for id in found["ready"]:
		var writes: Array = []
		for w in found["ready"][id]:
			# Solo si la celda sigue libre de cimientos (el jugador pudo haber hecho otra cosa).
			if not house.has_piece(0, "foundation", w["key"]):
				writes.append(w.duplicate(true))
		var placed: bool = await builder.place_now(writes)
		if placed:
			_queue.erase(id)
			EventBus.toast.emit("Terreno libre: pusimos los cimientos de esa zona.")
		else:
			EventBus.toast.emit("El terreno ya está libre, pero no alcanzó para los cimientos. Reintentamos más tarde.")
	_save()
	queue_changed.emit()
	_placing = false


# --- Guardado (solo en este teléfono) ---

func _save() -> void:
	GameState.settings[SETTINGS_KEY] = _queue.duplicate(true)


func _load() -> void:
	_queue = {}
	var saved: Variant = GameState.settings.get(SETTINGS_KEY, {})
	if saved is Dictionary:
		for id in saved:
			if saved[id] is Array and not (saved[id] as Array).is_empty():
				_queue[str(id)] = saved[id]
