extends Control
## Panel de la casa (Fase 5): de quién es, la caja de la casa común,
## "unir ingresos", los pedidos de permiso (cambios estructurales) y el
## historial de cambios, con "Deshacer" para los cambios menores.
##
## Habla directo con Couple. Todo lo decide el servidor; mientras se espera
## su respuesta los botones no hacen nada, y sin conexión quedan apagados.

## Montos de los botones para aportar a la caja.
const CONTRIBUTIONS := [100, 500, 1000]

@onready var _title: Label = %Title
@onready var _status_label: Label = %StatusLabel
@onready var _content: VBoxContainer = %Content
@onready var _close_button: Button = %CloseButton


func _ready() -> void:
	visible = false
	_close_button.pressed.connect(hide)
	EventBus.home_panel_requested.connect(open)
	EventBus.couple_changed.connect(_on_changed)
	EventBus.fund_changed.connect(func(_shared: bool, _fund: int) -> void: _on_changed())
	EventBus.server_status_changed.connect(func(_online: bool, _user: String) -> void: _on_changed())
	EventBus.server_busy_changed.connect(func(_busy: bool) -> void: _on_changed())


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

	if Couple.shared():
		_build_fund(usable)
	_build_requests(home, usable)
	_build_log(home, usable)


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
			_content.add_child(PanelRows.row([
				PanelRows.label("%s propone: %s%s" % [request["by_name"], request["text"], cost_text]),
				PanelRows.button("Ver", _on_view_request.bind(request["id"]), not usable, 90),
				PanelRows.button("Aprobar", _on_answer_request.bind(request["id"], true), not usable, 130),
				PanelRows.button("No", _on_answer_request.bind(request["id"], false), not usable, 90),
			]))


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


## Pulido 1: ver la propuesta en la casa antes de responder.
func _on_view_request(id: int) -> void:
	hide()
	EventBus.proposal_review_requested.emit(id)


func _on_cancel_request(id: int) -> void:
	await Couple.cancel_request(id)


func _on_revert(id: int) -> void:
	await Couple.revert(id)
