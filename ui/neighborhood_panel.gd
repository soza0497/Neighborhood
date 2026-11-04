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


func open() -> void:
	_rebuild()
	show()


func _rebuild() -> void:
	PanelRows.clear(_content)
	_title.text = "Barrio"
	_status_label.text = "Las casas de los vecinos se ven por dentro, solo para mirar."
	_build_privacy()
	_build_visits()


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
