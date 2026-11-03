extends Control
## Panel de la pareja (Fase 5): invitar, aceptar, casarse, mudarse juntos,
## terminar, y los interruptores de drama y modo familiar.
##
## Habla directo con Couple (el panel solo muestra y pide). Todo lo decide el
## servidor; mientras se espera su respuesta los botones no hacen nada, y sin
## conexión quedan apagados. Se arma de nuevo cada vez que algo cambia.

@onready var _status_label: Label = %StatusLabel
@onready var _content: VBoxContainer = %Content
@onready var _close_button: Button = %CloseButton

var _invite_edit: LineEdit
## "Terminar la relación" pide tocar dos veces (no se deshace).
var _confirm_end := false


func _ready() -> void:
	visible = false
	_close_button.pressed.connect(hide)
	EventBus.couple_panel_requested.connect(open)
	EventBus.couple_changed.connect(_on_changed)
	EventBus.partner_presence_changed.connect(func(_online: bool, _intention: Dictionary) -> void: _refresh_status())
	EventBus.server_status_changed.connect(func(_online: bool, _user: String) -> void: _on_changed())
	EventBus.server_busy_changed.connect(func(_busy: bool) -> void: _on_changed())


func open() -> void:
	_confirm_end = false
	_rebuild()
	show()
	Couple.refresh()


func _on_changed() -> void:
	if visible:
		_rebuild()


## ¿Se puede pedir algo ahora? (conexión y nadie esperando)
func _can_use() -> bool:
	return Economy.server_mode and GameServer.online and not Economy.busy


func _refresh_status() -> void:
	var couple := Couple.couple
	var text := CoupleState.status_text(couple)
	if not Economy.server_mode:
		text = "La pareja necesita una cuenta en el servidor."
	elif not GameServer.online:
		text = Economy.OFFLINE_TEXT + ": la pareja espera a reconectar."
	elif Couple.in_couple():
		if Couple.partner_online:
			var intention := Couple.partner_intention
			text += "\n● %s está en línea" % Couple.partner_name()
			if not intention.is_empty():
				text += ": " + Character.intention_text(intention)
		else:
			text += "\n○ %s no está en línea." % Couple.partner_name()
	_status_label.text = text


func _rebuild() -> void:
	# Lo que se estaba escribiendo no se pierde al rearmar el panel.
	var typed := _invite_edit.text if is_instance_valid(_invite_edit) else ""
	_invite_edit = null
	PanelRows.clear(_content)
	_refresh_status()
	var couple := Couple.couple
	var usable := _can_use()
	if not Couple.in_couple():
		_build_single(couple, usable, typed)
	else:
		_build_couple(couple, usable)
	_build_history(couple)


## Sin pareja: invitar, y las invitaciones que llegaron.
func _build_single(couple: Dictionary, usable: bool, typed := "") -> void:
	if couple["invite_to_name"] != "":
		_content.add_child(PanelRows.row([
			PanelRows.label("Invitaste a %s. Cuando acepte, son pareja." % couple["invite_to_name"]),
			PanelRows.button("Retirar", _on_cancel_invite, not usable),
		]))
	else:
		_content.add_child(PanelRows.title("Invitar a alguien"))
		_invite_edit = LineEdit.new()
		_invite_edit.placeholder_text = "usuario de tu pareja"
		_invite_edit.custom_minimum_size = Vector2(320, 52)
		_invite_edit.add_theme_font_size_override("font_size", 18)
		_invite_edit.text = typed
		_invite_edit.text_submitted.connect(func(_text: String) -> void: _on_invite())
		_content.add_child(PanelRows.row([_invite_edit, PanelRows.button("Invitar", _on_invite, not usable)]))
	if not couple["invites_in"].is_empty():
		_content.add_child(PanelRows.title("Te invitaron"))
		for invite in couple["invites_in"]:
			_content.add_child(PanelRows.row([
				PanelRows.label("%s quiere ser tu pareja." % invite["from_name"]),
				PanelRows.button("Aceptar", _on_answer_invite.bind(invite["from_id"], true), not usable, 130),
				PanelRows.button("No", _on_answer_invite.bind(invite["from_id"], false), not usable, 90),
			]))


## En pareja: pedidos (casarse, mudarse), interruptores y terminar.
func _build_couple(couple: Dictionary, usable: bool) -> void:
	var proposal := CoupleState.proposal_text(couple)
	if proposal != "":
		var buttons: Array = [PanelRows.label(proposal)]
		if couple["proposal_by_me"]:
			buttons.append(PanelRows.button("Retirar", _on_respond.bind(false), not usable, 130))
		else:
			buttons.append(PanelRows.button("Aceptar", _on_respond.bind(true), not usable, 130))
			buttons.append(PanelRows.button("No", _on_respond.bind(false), not usable, 90))
		_content.add_child(PanelRows.row(buttons))
	else:
		var actions: Array = []
		if couple["status"] == "dating":
			actions.append(PanelRows.button("Proponer casamiento", _on_propose.bind("marry", ""), not usable, 220))
		if not couple["shared"]:
			actions.append(PanelRows.button("Vivir juntos en mi casa", _on_propose.bind("move_in", "mine"), not usable, 240))
			actions.append(PanelRows.button("Mudarme a su casa", _on_propose.bind("move_in", "yours"), not usable, 200))
		if not actions.is_empty():
			_content.add_child(PanelRows.title("Pedirle a %s" % couple["partner_name"]))
			_content.add_child(PanelRows.row(actions))
		if couple["shared"]:
			_content.add_child(PanelRows.label("Viven juntos: la caja de la casa, los pedidos de permiso y el historial están en Menú → Casa.", 16, Color(0.8, 0.9, 1)))

	_content.add_child(PanelRows.title("Interruptores"))
	_content.add_child(PanelRows.check("Permitir drama en nuestra relación", couple["drama"],
		_on_switch.bind("drama"), not usable))
	var drama_note := "Todavía no hay drama en el juego. Cuando lo haya, solo pasa si los dos lo permiten y nadie tiene el modo familiar."
	if couple["partner_drama"]:
		drama_note += " (%s lo permite.)" % couple["partner_name"]
	_content.add_child(PanelRows.label(drama_note, 15, Color(0.8, 0.8, 0.85)))
	_content.add_child(PanelRows.check("Modo familiar (oculta todo el drama)", couple["family_mode"],
		_on_switch.bind("family_mode"), not usable))

	var end_text := "¿Seguro? Tocá de nuevo" if _confirm_end else "Terminar la relación"
	_content.add_child(PanelRows.row([
		PanelRows.label("Terminar no necesita que %s acepte. Si viven juntos, la casa queda de quien era y la caja se reparte en dos." % couple["partner_name"], 15, Color(0.8, 0.8, 0.85)),
		PanelRows.button(end_text, _on_end, not usable, 240),
	]))


func _build_history(couple: Dictionary) -> void:
	var events: Array = couple["events"]
	if events.is_empty():
		return
	_content.add_child(PanelRows.title("Historial de relaciones"))
	for i in range(events.size() - 1, maxi(-1, events.size() - 7), -1):
		_content.add_child(PanelRows.label("%s · %s" % [PanelRows.time_text(events[i]["at"]), events[i]["text"]], 15))


# --- Botones ---

func _on_invite() -> void:
	if _invite_edit == null or _invite_edit.text.strip_edges() == "":
		EventBus.toast.emit("Escribí el usuario de tu pareja.")
		return
	await Couple.invite(_invite_edit.text)


func _on_cancel_invite() -> void:
	await Couple.cancel_invite()


func _on_answer_invite(from_id: String, accept: bool) -> void:
	await Couple.answer_invite(from_id, accept)


func _on_propose(kind: String, home: String) -> void:
	await Couple.propose(kind, home)


func _on_respond(accept: bool) -> void:
	await Couple.respond(accept)


func _on_switch(on: bool, switch_name: String) -> void:
	await Couple.set_switch(switch_name, on)


func _on_end() -> void:
	if not _confirm_end:
		_confirm_end = true
		_rebuild()
		return
	_confirm_end = false
	await Couple.end_relation()
