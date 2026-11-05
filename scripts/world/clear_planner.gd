class_name ClearPlanner
extends Node
## Llamar al servicio desde «Eliminar» (Pulido 6B).
##
## Con la herramienta Eliminar de la barra de construcción, tocar un árbol, una roca, la maleza…
## lo MARCA (con un aro). Se pueden marcar varios y se confirma UNA sola vez: el panel
## (ui/clear_panel.gd) muestra qué se llama, cuánto cuesta en total y cuándo llega cada uno.
## Fuera de Eliminar, tocar un obstáculo ya no abre ningún menú (antes salía sin querer).
##
## La plata la decide el servidor: acá solo se arma la lista y se llama a Parcel.call_services.
## Otras herramientas (por ejemplo cimientos sobre un árbol) pueden usar esa misma función.

## Cambió lo marcado (o su cotización).
signal changed

var builder: HouseBuilder
var parcel_view: ParcelView
var house: HouseData
## Ids marcados, en el orden en que se tocaron.
var selected: Array = []


func _ready() -> void:
	Parcel.changed.connect(_drop_invalid)


## ¿Está la herramienta Eliminar en uso?
func is_active() -> bool:
	return builder != null and builder.active and builder.tool == HouseBuilder.Tool.ERASE


func _process(_delta: float) -> void:
	# Al salir de Eliminar (o de construir) se descarta lo marcado.
	if not selected.is_empty() and not is_active():
		clear_selection()


## Tocó un obstáculo: lo marca o lo desmarca. Si ya viene un servicio, avisa cuánto falta (y si
## ya debería haber llegado pero no pudo entrar, lo reintenta). Devuelve {ok, reason}.
func toggle(id: String) -> Dictionary:
	var o := Parcel.obstacle(id)
	if o.is_empty() or Parcel.cleared.has(id):
		return {"ok": false, "reason": "Eso ya está limpio."}
	if Parcel.pending.has(id):
		var left := int(Parcel.pending[id]["ready_at"]) - Economy.now()
		if left > 0:
			EventBus.toast.emit("Ya viene el servicio: %s." % arrival_text(left))
			return {"ok": false, "reason": "pending"}
		EventBus.toast.emit("Reintentando el servicio…")
		Parcel.service_due.emit(id)
		return {"ok": false, "reason": "retry"}
	if selected.has(id):
		selected.erase(id)
	else:
		selected.append(id)
	_refresh()
	return {"ok": true, "reason": ""}


func clear_selection() -> void:
	if selected.is_empty():
		return
	selected.clear()
	_refresh()


func _drop_invalid() -> void:
	var before := selected.size()
	selected = selected.filter(func(id: Variant) -> bool: return not Parcel.cleared.has(str(id)) and not Parcel.pending.has(str(id)) and not Parcel.obstacle(str(id)).is_empty())
	if selected.size() != before:
		_refresh()


func _refresh() -> void:
	if parcel_view != null:
		parcel_view.set_marked(selected)
	changed.emit()


## Lo que costaría llamar a los marcados (Parcel.quote).
func quote() -> Dictionary:
	return Parcel.quote(selected, house)


## Líneas para mostrar, juntando los del mismo tipo: [{name, count, cost, seconds}].
func summary_lines() -> Array:
	var by_name: Dictionary = {}
	var lines: Array = []
	for item in quote()["items"]:
		var name_key := str(item["name"])
		if not by_name.has(name_key):
			var line := {"name": name_key, "count": 0, "cost": 0, "seconds": int(item["seconds"])}
			by_name[name_key] = line
			lines.append(line)
		by_name[name_key]["count"] += 1
		by_name[name_key]["cost"] += int(item["cost"])
	return lines


## Confirma: llama al servicio para todos los marcados de una vez. Devuelve el resultado de
## Parcel.call_services.
func confirm() -> Dictionary:
	if selected.is_empty():
		return {"ok": false, "called": [], "failed": [], "spent": 0, "error": "No marcaste nada."}
	var ids := selected.duplicate()
	var result: Dictionary = await Parcel.call_services(ids, house)
	selected.clear()
	_refresh()
	if result["ok"]:
		var count: int = result["called"].size()
		var text := "Viene el servicio (%d) · $%d." % [count, int(result["spent"])] if count > 1 else "Viene el servicio · $%d." % int(result["spent"])
		if not result["failed"].is_empty():
			text += " %d no se pudo." % result["failed"].size()
		EventBus.toast.emit(text)
	else:
		EventBus.toast.emit(str(result["error"]))
	return result


## «llega en 1 min 30 s» / «llega en 45 s».
static func arrival_text(seconds: int) -> String:
	seconds = maxi(seconds, 0)
	if seconds >= 60:
		var minutes := seconds / 60
		var rest := seconds % 60
		return "llega en %d min%s" % [minutes, " %d s" % rest if rest > 0 else ""]
	return "llega en %d s" % seconds
