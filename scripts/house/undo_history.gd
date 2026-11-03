class_name UndoHistory
extends RefCounted
## Deshacer / rehacer para una casa.
##
## Cada acción del jugador (por ejemplo, arrastrar una pared de 5 tramos) se
## guarda como UN paso: la lista de escrituras que la hizo y la que la deshace.

## Cambió lo que se puede deshacer o rehacer (para habilitar los botones).
signal changed(can_undo: bool, can_redo: bool)
## Se aplicó un cambio (acción nueva, deshacer o rehacer).
signal house_edited

## Cuántos pasos se recuerdan como máximo.
const MAX_STEPS := 100

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


func can_undo() -> bool:
	return not _undo_steps.is_empty()


func can_redo() -> bool:
	return not _redo_steps.is_empty()


func undo() -> void:
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


## Olvida todo (por ejemplo, al cargar otra casa).
func clear() -> void:
	_undo_steps.clear()
	_redo_steps.clear()
	changed.emit(false, false)


func _notify() -> void:
	changed.emit(can_undo(), can_redo())
	house_edited.emit()
