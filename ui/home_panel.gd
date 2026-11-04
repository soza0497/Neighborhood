extends Control
## Panel de la casa (Fase 5): de quién es, la caja de la casa común,
## "unir ingresos", los pedidos de permiso (cambios estructurales) y el
## historial de cambios, con "Deshacer" para los cambios menores.
##
## Habla directo con Couple. Todo lo decide el servidor; mientras se espera
## su respuesta los botones no hacen nada, y sin conexión quedan apagados.

## Montos de los botones para aportar a la caja.
const CONTRIBUTIONS := [100, 500, 1000]

## Pulido 4A: la casa (la pone el HUD). Sirve para listar los cuartos.
var house: HouseData

@onready var _title: Label = %Title
@onready var _status_label: Label = %StatusLabel
@onready var _content: VBoxContainer = %Content
@onready var _close_button: Button = %CloseButton

## Pulido 5E: la casa (la pone el HUD) para guardar plantillas, y el estado de la lista.
var house: HouseData
var _new_name := ""
var _renaming_id := ""
var _delete_id := ""
var _template_note := ""


func _ready() -> void:
	visible = false
	_close_button.pressed.connect(hide)
	EventBus.home_panel_requested.connect(open)
	EventBus.rooms_changed.connect(_on_changed)
	EventBus.couple_changed.connect(_on_changed)
	EventBus.fund_changed.connect(func(_shared: bool, _fund: int) -> void: _on_changed())
	EventBus.server_status_changed.connect(func(_online: bool, _user: String) -> void: _on_changed())
	EventBus.server_busy_changed.connect(func(_busy: bool) -> void: _on_changed())
	EventBus.templates_changed.connect(_on_changed)


func open() -> void:
	_rebuild()
	show()
	Couple.refresh()


func _on_changed() -> void:
	if visible:
		_rebuild()


func _can_use() -> bool:
	return Economy.server_mode and GameServer.online and not Economy.busy


func _rebuild() -> void:
	PanelRows.clear(_content)
	var home := Couple.home
	var usable := _can_use()
	var partner := Couple.partner_name()
	if not Economy.server_mode:
		_status_label.text = "La casa compartida necesita una cuenta en el servidor."
	elif Couple.shared():
		_title.text = "Casa compartida"
		_status_label.text = "Viven juntos en %s. Mover, girar y pintar es al instante (a %s le llega un aviso y lo puede deshacer). Para remodelar (paredes, pisos, puertas, techos, escaleras, vender) se arma una propuesta con todos los cambios y se manda entera: la pareja la ve y la aprueba o no." % [
			"tu casa" if home["owner_is_me"] else "la casa de " + partner, partner]
	else:
		_title.text = "Tu casa"
		_status_label.text = "Cuando vivan juntos, aquí van la caja de la casa y los pedidos de permiso."
	if not GameServer.online and Economy.server_mode:
		_status_label.text += "\n" + Economy.OFFLINE_TEXT + "."

	_build_settings()
	if Couple.shared():
		_build_fund(usable)
	_build_requests(home, usable)
	_build_log(home, usable)
	_build_templates()


## Pulido 4A: «Casa» es también el lugar de los ajustes de la casa: cuartos con su
## tipo (tocar uno abre el menú para cambiarlo) y si se puede visitar.
func _build_settings() -> void:
	_content.add_child(PanelRows.title("Cuartos de la casa"))
	var any := false
	if house != null:
		for level in HouseGrid.level_range():
			var n := 0
			for room in HouseRooms.detect(house, level):
				any = true
				n += 1
				var text := "%s · Cuarto %d: %s%s" % [HouseGrid.level_name(level), n, room["name"],
					" ★ principal" if room.get("main", false) else ""]
				var first: Vector2i = HouseGrid.key_to_cell(room["cells"].keys()[0])
				_content.add_child(PanelRows.row([
					PanelRows.label(text, 16),
					PanelRows.button("Cambiar tipo", _on_room_change.bind(level, first), false, 150),
				]))
	if not any:
		_content.add_child(PanelRows.label("Todavía no hay cuartos cerrados. Un cuarto es un piso rodeado de paredes.", 15, Color(0.8, 0.9, 1)))
	_content.add_child(PanelRows.check("Mi casa se puede visitar", NeighborhoodMap.is_my_house_visitable(), _on_visitable_toggled))


func _on_room_change(level: int, cell: Vector2i) -> void:
	hide()
	EventBus.room_menu_requested.emit(level, cell)


func _on_visitable_toggled(on: bool) -> void:
	NeighborhoodMap.set_my_house_visitable(on)
	EventBus.toast.emit("Tu casa %s." % ("se puede visitar" if on else "es privada"))


func _build_fund(usable: bool) -> void:
	_content.add_child(PanelRows.title("Caja de la casa: $ %d" % Economy.fund))
	_content.add_child(PanelRows.label("Lo que construyen en la casa se paga primero con la caja; si no alcanza, lo que falta sale de la billetera de quien construye. Lo que se vende vuelve a la caja.", 15, Color(0.8, 0.9, 1)))
	var buttons: Array = []
	for amount in CONTRIBUTIONS:
		buttons.append(PanelRows.button("Aportar $%d" % amount, _on_contribute.bind(amount),
			not usable or Economy.money < amount, 160))
	_content.add_child(PanelRows.row(buttons))
	var couple := Couple.couple
	_content.add_child(PanelRows.check("Unir ingresos: mi sueldo va a la caja", couple["pool_income"],
		_on_pool_toggled, not usable))
	_content.add_child(PanelRows.label("%s: %s" % [Couple.partner_name(),
		"su sueldo va a la caja" if couple["partner_pool_income"] else "su sueldo va a su billetera"], 15, Color(0.8, 0.8, 0.85)))


func _build_requests(home: Dictionary, usable: bool) -> void:
	var requests: Array = home["requests"]
	if requests.is_empty():
		return
	_content.add_child(PanelRows.title("Pedidos de permiso"))
	for request in requests:
		var cost_text := " ($%d)" % request["cost"] if request["cost"] > 0 else ""
		if request["by_me"]:
			_content.add_child(PanelRows.row([
				PanelRows.label("Pediste permiso para: %s%s. Esperando a %s." % [request["text"], cost_text, Couple.partner_name()]),
				PanelRows.button("Retirar", _on_cancel_request.bind(request["id"]), not usable, 130),
			]))
		else:
			# Fase 6: abrir o cerrar el restaurante no tiene piezas que "Ver".
			var row: Array = [PanelRows.label("%s propone: %s%s" % [request["by_name"], request["text"], cost_text])]
			if request.get("business", "") == "":
				row.append(PanelRows.button("Ver", _on_view_request.bind(request["id"]), not usable, 90))
			row.append(PanelRows.button("Aprobar", _on_answer_request.bind(request["id"], true), not usable, 130))
			row.append(PanelRows.button("No", _on_answer_request.bind(request["id"], false), not usable, 90))
			_content.add_child(PanelRows.row(row))


func _build_log(home: Dictionary, usable: bool) -> void:
	var log: Array = home["log"]
	if log.is_empty():
		return
	_content.add_child(PanelRows.title("Historial de la casa"))
	for entry in log:
		var who: String = "Vos" if entry["by_me"] else entry["by_name"]
		var text := "%s · %s — %s" % [PanelRows.time_text(entry["at"]), who, entry["text"]]
		if entry["reverted"]:
			text += " (deshecho)"
		var children: Array = [PanelRows.label(text, 15)]
		if entry["can_revert"] and not entry["by_me"]:
			children.append(PanelRows.button("Deshacer", _on_revert.bind(entry["id"]), not usable, 130))
		_content.add_child(PanelRows.row(children))


# --- Botones ---

func _on_contribute(amount: int) -> void:
	await Couple.contribute(amount)


func _on_pool_toggled(on: bool) -> void:
	await Couple.set_switch("pool_income", on)


func _on_answer_request(id: int, approve: bool) -> void:
	await Couple.answer_request(id, approve)
	Restaurant.refresh()  # Por si era abrir o cerrar el restaurante.


## Pulido 1: ver la propuesta en la casa antes de responder.
func _on_view_request(id: int) -> void:
	hide()
	EventBus.proposal_review_requested.emit(id)


func _on_cancel_request(id: int) -> void:
	await Couple.cancel_request(id)


func _on_revert(id: int) -> void:
	await Couple.revert(id)


# --- Plantillas de casa (Pulido 5E) ---

func _build_templates() -> void:
	var list := HouseTemplates.all()
	_content.add_child(PanelRows.title("Plantillas de casa (mudanza)"))
	_content.add_child(PanelRows.label(
		"Guardá la estructura de tu casa (cimientos, pisos, paredes con puertas y ventanas, techos, escaleras y pilares, con su pintura; sin muebles) para volver a construirla en otro lugar del lote. Tenés %d de %d." % [list.size(), HouseTemplates.MAX_TEMPLATES], 15, Color(0.8, 0.85, 0.95)))
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "Nombre de la plantilla"
	name_edit.text = _new_name
	name_edit.max_length = HouseTemplates.MAX_NAME
	name_edit.custom_minimum_size = Vector2(230, 52)
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.add_theme_font_size_override("font_size", 17)
	name_edit.text_changed.connect(func(text: String) -> void: _new_name = text)
	_content.add_child(PanelRows.row([name_edit,
		PanelRows.button("Guardar la casa", _on_save_template, house == null, 190)]))
	if _template_note != "":
		_content.add_child(PanelRows.label(_template_note, 15, Color(1, 0.88, 0.6)))
	var offline := Economy.server_mode and (not GameServer.online or Economy.busy)
	for template in list:
		var id: String = template.get("id", "")
		var size: Array = template.get("size", [0, 0])
		var pieces := (template.get("pieces", []) as Array).size()
		if id == _renaming_id:
			var edit := LineEdit.new()
			edit.text = str(template.get("name", ""))
			edit.max_length = HouseTemplates.MAX_NAME
			edit.custom_minimum_size = Vector2(230, 52)
			edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			edit.add_theme_font_size_override("font_size", 17)
			_content.add_child(PanelRows.row([edit,
				PanelRows.button("Listo", _on_rename_template.bind(id, edit), false, 110),
				PanelRows.button("Cancelar", _on_cancel_rename, false, 130)]))
			continue
		var info := "%s\n%d piezas · %d × %d celdas" % [str(template.get("name", "")), pieces, int(size[0]), int(size[1])]
		var delete_text := "¿Seguro?" if id == _delete_id else "Borrar"
		_content.add_child(PanelRows.row([PanelRows.label(info, 17),
			PanelRows.button("Colocar", _on_place_template.bind(id), offline or house == null, 130),
			PanelRows.button("Renombrar", _on_start_rename.bind(id), false, 140),
			PanelRows.button(delete_text, _on_delete_template.bind(id), false, 120)]))
	if list.is_empty():
		_content.add_child(PanelRows.label("Todavía no guardaste ninguna plantilla.", 15, Color(0.7, 0.75, 0.85)))


func _on_save_template() -> void:
	_delete_id = ""
	var result := HouseTemplates.save_house(house, _new_name)
	if result["ok"]:
		_new_name = ""
		_template_note = "Guardada: «%s»." % str(result["template"]["name"])
	else:
		_template_note = result["error"]
	_rebuild()  # El aviso se cambió después de guardar: se dibuja de nuevo.


func _on_place_template(id: String) -> void:
	_template_note = ""
	hide()
	EventBus.template_place_requested.emit(id)


func _on_start_rename(id: String) -> void:
	_renaming_id = id
	_delete_id = ""
	_rebuild()


func _on_cancel_rename() -> void:
	_renaming_id = ""
	_rebuild()


func _on_rename_template(id: String, edit: LineEdit) -> void:
	var result := HouseTemplates.rename(id, edit.text)
	_template_note = "" if result["ok"] else result["error"]
	if result["ok"]:
		_renaming_id = ""
	_rebuild()


## Borrar pide tocar dos veces (la segunda vez dice «¿Seguro?»).
func _on_delete_template(id: String) -> void:
	if _delete_id != id:
		_delete_id = id
		_rebuild()
		return
	_delete_id = ""
	HouseTemplates.remove(id)
	_template_note = "Plantilla borrada."
	_rebuild()
