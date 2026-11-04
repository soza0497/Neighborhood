extends Control
## Panel «Barrio» (Fase 8B y 8D): la meta del barrio, la privacidad y la lista de
## casas para visitar («¿Qué casa querés visitar?»). Todo es local: no depende
## del servidor, salvo el aporte a la meta (que lo calcula el servidor si hay
## cuenta; ver NeighborhoodGoal).

@onready var _title: Label = %Title
@onready var _status_label: Label = %StatusLabel
@onready var _content: VBoxContainer = %Content
@onready var _close_button: Button = %CloseButton


func _ready() -> void:
	visible = false
	_close_button.pressed.connect(hide)
	EventBus.neighborhood_panel_requested.connect(open)
	EventBus.neighborhood_goal_changed.connect(_on_goal_changed)


func open() -> void:
	_rebuild()
	show()
	NeighborhoodGoal.refresh()  # Cuenta las plantas de la casa y vuelve a dibujar.


func _on_goal_changed() -> void:
	if visible:
		_rebuild()


func _rebuild() -> void:
	PanelRows.clear(_content)
	_title.text = "Barrio"
	_status_label.text = "Las casas de los vecinos se ven por dentro, solo para mirar."
	_build_goal()
	_build_privacy()
	_build_visits()


## Meta del barrio (Fase 8D): barra de todos y aporte propio.
func _build_goal() -> void:
	var goal := NeighborhoodGoal.summary()
	_content.add_child(PanelRows.title("Meta del barrio"))
	_content.add_child(PanelRows.label(str(goal["name"]), 18))
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = maxi(1, int(goal["target"]))
	bar.value = mini(int(goal["total"]), int(goal["target"]))
	bar.custom_minimum_size = Vector2(380, 26)
	bar.show_percentage = false
	_content.add_child(bar)
	_content.add_child(PanelRows.label("%d de %d · entre todos" % [goal["total"], goal["target"]], 16, Color(0.8, 0.9, 1)))
	_content.add_child(PanelRows.label("Tu aporte: %d (hoy %d de %d posibles) · Vecinos: %d" % [
		goal["mine"], goal["today"], goal["daily_cap"], goal["neighbors"]], 16, Color(0.8, 0.9, 1)))
	var reward: Dictionary = goal["reward"]
	if goal["completed"]:
		if goal["claimed"]:
			_content.add_child(PanelRows.label("¡Meta cumplida! Ya retiraste tu recompensa.", 17, Color(1, 0.88, 0.6)))
		elif int(goal["mine"]) > 0:
			_content.add_child(PanelRows.label("¡Meta cumplida! Tenés una recompensa chica para retirar (opcional).", 17, Color(1, 0.88, 0.6)))
			_content.add_child(PanelRows.button("Retirar $%d y %d XP" % [reward["money"], reward["xp"]], _on_claim, false, 240))
		else:
			_content.add_child(PanelRows.label("¡Meta cumplida por los vecinos! Para la próxima, sumá tu parte.", 17, Color(1, 0.88, 0.6)))
	else:
		_content.add_child(PanelRows.label("Sumás con las plantas de tu casa (terminadas). Sin apuro ni castigo: si un día no jugás, la meta espera. Premio chico al cumplirse: $%d y %d XP." % [
			reward["money"], reward["xp"]], 15, Color(0.8, 0.8, 0.85)))


## Privacidad: la casa propia solo se puede visitar si el jugador lo permite.
func _build_privacy() -> void:
	_content.add_child(PanelRows.title("Privacidad"))
	_content.add_child(PanelRows.check("Mi casa se puede visitar", NeighborhoodMap.is_my_house_visitable(), _on_privacy_toggled))
	_content.add_child(PanelRows.label("Apagado por defecto. Por ahora nadie puede entrar a tu casa; el interruptor queda guardado para cuando haya visitas.", 15, Color(0.8, 0.8, 0.85)))


func _build_visits() -> void:
	_content.add_child(PanelRows.title("¿Qué casa querés visitar?"))
	_content.add_child(PanelRows.button("Vista aérea del barrio", _on_aerial, false, 380))
	for entry in NeighborhoodMap.visit_list():
		var text: String = entry["label"]
		_content.add_child(PanelRows.button(text, _on_visit.bind(entry["id"]), false, 380))


func _on_privacy_toggled(on: bool) -> void:
	NeighborhoodMap.set_my_house_visitable(on)
	EventBus.toast.emit("Tu casa %s." % ("se puede visitar" if on else "es privada"))


func _on_aerial() -> void:
	hide()
	EventBus.neighborhood_aerial_requested.emit()


func _on_visit(target_id: String) -> void:
	hide()
	EventBus.neighborhood_visit_requested.emit(target_id)


func _on_claim() -> void:
	NeighborhoodGoal.claim_reward()
