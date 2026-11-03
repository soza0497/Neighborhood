class_name UndoHistory
extends RefCounted
## Deshacer / rehacer para una casa.
##
## Cada acción del jugador (por ejemplo, arrastrar una pared de 5 tramos) se
## guarda como UN paso: la lista de escrituras que la hizo y la que la deshace.
##
## Con servidor (Fase 4B, `remote = true`) los pasos los guarda el SERVIDOR
## (hasta 100) y devuelve exactamente lo cobrado: aquí solo se aplica lo que
## él responde (apply_remote) y se pregunta a Economy si se puede deshacer.

## Cambió lo que se puede deshacer o rehacer (para habilitar los botones).
signal changed(can_undo: bool, can_redo: bool)
## Se aplicó un cambio (acción nueva, deshacer o rehacer).
signal house_edited

## Cuántos pasos se recuerdan como máximo.
const MAX_STEPS := 100

## true = deshacer y rehacer los decide el servidor.
var remote := false

var _house: HouseData
var _undo_steps: Array = []
var _redo_steps: Array = []


func _init(house: HouseData) -> void:
	_house = house


## Aplica una acción nueva. No hace nada si la lista está vacía.
## `money_change` = lo que cambió el dinero (negativo = se pagó): deshacer
## lo devuelve y rehacer lo vuelve a cobrar.
func commit(writes: Array, money_change := 0) -> void:
	if writes.is_empty():
		return
	var inverse := _house.apply(writes)
	_undo_steps.append({"do": writes, "undo": inverse, "money": money_change})
	Economy.add_money(money_change)
	if _undo_steps.size() > MAX_STEPS:
		_undo_steps.pop_front()
	_redo_steps.clear()
	_notify()


## Con servidor: aplica a la casa lo que el servidor ya aceptó (construir,
## deshacer o rehacer). Los botones se actualizan con lo que él dice.
func apply_remote(writes: Array) -> void:
	_house.apply(writes)
	_notify()


func can_undo() -> bool:
	if remote:
		return Economy.server_can_undo
	return not _undo_steps.is_empty()


func can_redo() -> bool:
	if remote:
		return Economy.server_can_redo
	return not _redo_steps.is_empty()


## Vuelve a avisar si se puede deshacer o rehacer (por ejemplo, al entrar).
func refresh() -> void:
	changed.emit(can_undo(), can_redo())


func undo() -> void:
	if remote:
		await _remote_step("build_undo")
		return
	if not can_undo():
		return
	var step: Dictionary = _undo_steps.back()
	# Si ya se gastó el dinero que había devuelto, no se puede deshacer.
	if not Economy.can_change(-int(step["money"])):
		EventBus.build_hint.emit("No alcanza el dinero para deshacer esto.")
		return
	_undo_steps.pop_back()
	_house.apply(step["undo"])
	Economy.add_money(-int(step["money"]))
	_redo_steps.append(step)
	_notify()


func redo() -> void:
	if remote:
		await _remote_step("build_redo")
		return
	if not can_redo():
		return
	var step: Dictionary = _redo_steps.back()
	if not Economy.can_change(int(step["money"])):
		EventBus.build_hint.emit("Te faltan $%d para rehacerlo." % (-int(step["money"]) - Economy.money))
		return
	_redo_steps.pop_back()
	_house.apply(step["do"])
	Economy.add_money(int(step["money"]))
	_undo_steps.append(step)
	_notify()


## Pide al servidor deshacer o rehacer y aplica lo que devuelve.
func _remote_step(rpc_id: String) -> void:
	if not Economy.can_request():
		return
	var result: Dictionary = await Economy.request(rpc_id)
	if result["ok"]:
		apply_remote(CloudSync.writes_from_server(result["data"].get("writes", [])))
		var money_change := int(result["data"].get("money_change", 0))
		if money_change > 0:
			EventBus.build_hint.emit("Te devolvieron $%d." % money_change)
		elif money_change < 0:
			EventBus.build_hint.emit("Pagaste $%d." % -money_change)
	else:
		EventBus.build_hint.emit(result["error"])
		refresh()


## Olvida todo (por ejemplo, al cargar otra casa).
func clear() -> void:
	_undo_steps.clear()
	_redo_steps.clear()
	changed.emit(false, false)


func _notify() -> void:
	changed.emit(can_undo(), can_redo())
	house_edited.emit()
