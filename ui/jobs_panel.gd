extends Control
## Panel de empleos: ofertas, currículo enviado (con cuenta regresiva) y
## empleo actual. Habla directo con Economy (el panel solo muestra y pide).
##
## La lista de ofertas se arma al abrir y cuando algo cambia; el texto de
## estado y el botón de acelerar se actualizan cada segundo (así los botones
## de las ofertas no "saltan" justo cuando se los toca).

@onready var _status_label: Label = %StatusLabel
@onready var _offers: VBoxContainer = %Offers
@onready var _accelerate_button: Button = %AccelerateButton
@onready var _quit_button: Button = %QuitButton
@onready var _close_button: Button = %CloseButton

var _timer := 0.0


func _ready() -> void:
	visible = false
	_close_button.pressed.connect(hide)
	_accelerate_button.pressed.connect(_on_accelerate)
	_quit_button.pressed.connect(_on_quit)
	EventBus.jobs_requested.connect(open)
	EventBus.jobs_changed.connect(_on_changed)
	EventBus.level_up.connect(func(_level, _names): _on_changed())


func open() -> void:
	_rebuild_offers()
	_refresh_status()
	show()


func _process(delta: float) -> void:
	if not visible:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = 1.0
		_refresh_status()


func _on_changed() -> void:
	if visible:
		_rebuild_offers()
		_refresh_status()


func _on_accelerate() -> void:
	if not Economy.accelerate_resume():
		EventBus.toast.emit("No alcanza el dinero para acelerar.")
	_on_changed()


func _on_quit() -> void:
	Economy.quit_job()
	_on_changed()


## Texto de arriba, cuenta regresiva y botones de acelerar / renunciar.
func _refresh_status() -> void:
	var job := Economy.current_job()
	_accelerate_button.visible = false
	_quit_button.visible = false
	if not job.is_empty():
		_status_label.text = "Trabajás de %s: turno de %d h desde las %02d:00, $%d por turno." % [
			job["name"], int(job["shift_hours"]), int(job["start_hour"]), Economy.shift_pay(job)]
		_quit_button.visible = true
	elif Economy.applied_job != "":
		var left := Economy.resume_seconds_left()
		var applied: Dictionary = Catalog.jobs[Economy.applied_job]
		_status_label.text = "Esperando respuesta de %s: faltan %d:%02d" % [applied["name"], left / 60, left % 60]
		var cost := Economy.accelerate_cost(left)
		_accelerate_button.visible = true
		_accelerate_button.text = "Acelerar ($%d)" % cost
		_accelerate_button.disabled = not Economy.can_change(-cost)
	else:
		_status_label.text = "Sin empleo. Elegí una oferta y mandá tu currículum."


func _rebuild_offers() -> void:
	for child in _offers.get_children():
		child.queue_free()
	var jobs: Array = Catalog.jobs.values()
	jobs.sort_custom(func(a, b): return a["level"] < b["level"])
	for job in jobs:
		_offers.add_child(_make_offer(job))


func _make_offer(job: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var text := Label.new()
	text.text = "%s\n%s\n$%d por hora · turno de %d h · respuesta en %d min" % [
		job["name"], job.get("description", ""), int(job["pay_per_hour"]), int(job["shift_hours"]), int(job["resume_minutes"])]
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(430, 0)
	text.add_theme_font_size_override("font_size", 16)
	row.add_child(text)

	var button := Button.new()
	button.custom_minimum_size = Vector2(190, 56)
	button.add_theme_font_size_override("font_size", 17)
	if Economy.job_id == job["id"]:
		button.text = "Tu empleo"
		button.disabled = true
	elif Economy.level() < int(job["level"]):
		button.text = "Nivel %d" % int(job["level"])
		button.disabled = true
	elif Economy.applied_job != "":
		button.text = "Esperando…" if Economy.applied_job == job["id"] else "Ya enviaste uno"
		button.disabled = true
	else:
		button.text = "Mandar currículum"
		button.pressed.connect(_on_apply.bind(job["id"]))
	row.add_child(button)
	return row


func _on_apply(job_id: String) -> void:
	Economy.apply_for_job(job_id)
	_on_changed()
