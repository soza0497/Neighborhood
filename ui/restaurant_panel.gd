extends Control
## Panel del restaurante (Menú → Restaurante, Fase 6): qué le falta, abrir o
## cerrar, la caja que junta solo, el tope de hoy y "Atender" (el minijuego).
## Habla con el autoload Restaurant (que pregunta al servidor); el panel
## solo muestra y pide.

@onready var _status_label: Label = %StatusLabel
@onready var _info_label: Label = %InfoLabel
@onready var _open_button: Button = %OpenButton
@onready var _collect_button: Button = %CollectButton
@onready var _serve_button: Button = %ServeButton
@onready var _practice_button: Button = %PracticeButton
@onready var _close_button: Button = %CloseButton

## La casa (la pasa el HUD): para saber qué falta sin conexión.
var house: HouseData
var _timer := 0.0


func _ready() -> void:
	visible = false
	_close_button.pressed.connect(hide)
	_open_button.pressed.connect(_on_open)
	_collect_button.pressed.connect(_on_collect)
	_serve_button.pressed.connect(_on_serve)
	_practice_button.pressed.connect(_on_practice)
	EventBus.restaurant_panel_requested.connect(open)
	EventBus.restaurant_changed.connect(_refresh)
	EventBus.server_status_changed.connect(func(_online, _user): _refresh())
	EventBus.server_busy_changed.connect(func(_busy): _refresh())


func open() -> void:
	_refresh()
	show()
	await Restaurant.refresh()


func _process(delta: float) -> void:
	if not visible:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = 5.0
		_refresh()


func _online() -> bool:
	return Economy.server_mode and GameServer.online


## Lo que falta según la casa del teléfono (sin conexión) o el servidor.
func _local_requirements() -> Dictionary:
	if house == null:
		return {"missing": [], "seats": 3}
	return RestaurantSim.requirements(Restaurant.config(), house, Economy.now())


func _refresh() -> void:
	if not is_node_ready():
		return
	var s := Restaurant.summary
	var local := _local_requirements()
	var can := _online() and not Economy.busy
	_open_button.visible = false
	_collect_button.visible = false
	_serve_button.visible = false
	if not _online():
		_status_label.text = Economy.OFFLINE_TEXT + ": el restaurante cobra con el servidor. Podés practicar."
		_info_label.text = _how_to(local["missing"])
	elif s.is_empty():
		_status_label.text = "Preguntando al servidor…"
		_info_label.text = ""
	elif not s["open"]:
		_open_button.visible = true
		_open_button.disabled = not can or not s["ready"]
		_open_button.text = "Pedir permiso para abrir" if s["shared"] else "Abrir restaurante"
		if s["ready"]:
			_status_label.text = "Cerrado. Ya tiene todo: abrilo y empezá a atender (%d mesa%s)." % [
				s["seats"], "" if s["seats"] == 1 else "s"]
		else:
			_status_label.text = "Cerrado. Le falta: %s." % Restaurant.missing_text(s["missing"])
		_info_label.text = _how_to(s["missing"])
	else:
		_open_button.visible = true
		_open_button.disabled = not can
		_open_button.text = "Pedir permiso para cerrar" if s["shared"] else "Cerrar restaurante"
		_serve_button.visible = true
		_serve_button.disabled = not can or not s["ready"]
		# Pulido 2B: la caja se cobra sola (el botón queda solo para apurarla).
		_collect_button.visible = s["passive"] > 0
		_collect_button.disabled = not can
		_collect_button.text = "Cobrar ya ($%d)" % s["passive"]
		_serve_button.text = "Reto: Servicio (1:30)"
		if s["ready"]:
			_status_label.text = "Abierto · %d mesa%s. Gana solo; el Reto: Servicio (1:30) da premio extra." % [
				s["seats"], "" if s["seats"] == 1 else "s"]
		else:
			_status_label.text = "Abierto, pero no atiende: le falta %s." % Restaurant.missing_text(s["missing"])
		var lines: PackedStringArray = []
		var where := "la caja de la casa" if s["shared"] else "tu billetera"
		lines.append("Ingreso automático: $%d por hora, hasta $%d (se cobra solo y va a %s). Ahora: $%d." % [
			s["passive_per_hour"], s["passive_cap"], where, s["passive"]])
		var today := "Hoy ganaste $%d de $%d con los servicios." % [s["day_earned"], s["daily_cap"]]
		if s["cap_left"] <= 0 and s["resets_in"] > 0:
			today += " Tope lleno: vuelve en %d h %d min." % [s["resets_in"] / 3600, (s["resets_in"] % 3600) / 60]
		lines.append(today)
		lines.append("Servicios: %d · Récord: $%d · Total ganado: $%d" % [s["services"], s["best"], s["total"]])
		if s["shared"] and Economy.pool_income:
			lines.append("Unís ingresos: lo de tus servicios va a la caja de la casa.")
		_info_label.text = "\n".join(lines)
	if Restaurant.has_pending() and not Restaurant.playing:
		_info_label.text += "\nHay un servicio sin cobrar: se manda solo al conectarse."


func _how_to(missing: Array) -> String:
	if missing.is_empty():
		return "Un restaurante necesita mostrador, plancha y al menos una mesa (cada mesa es un lugar más)."
	return ("Armalo en tu parcela (puede ser un edificio aparte): Construir → Tienda → Restaurante. "
		+ "Falta: %s. Cada mesa de restaurante es un lugar más (hasta 3)." % Restaurant.missing_text(missing))


func _on_open() -> void:
	await Restaurant.set_open(not Restaurant.is_open())
	_refresh()


func _on_collect() -> void:
	await Restaurant.collect()
	_refresh()


func _on_serve() -> void:
	var info := await Restaurant.start_service()
	if info.get("ok", false):
		hide()
		EventBus.restaurant_service_requested.emit(info)


func _on_practice() -> void:
	var seats := int(Restaurant.summary.get("seats", 0))
	if seats <= 0:
		seats = int(_local_requirements()["seats"])
	if seats <= 0:
		seats = 3  # Para practicar sin mesas todavía.
	hide()
	EventBus.restaurant_service_requested.emit(Restaurant.start_practice(seats))
