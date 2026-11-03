extends Control
## Diario del personaje: cómo se siente ahora y lo que hizo, con su carita.
## Se abre desde el menú. Es solo para mirar: no cambia nada del juego.

@onready var _face: MoodFace = %Face
@onready var _title: Label = %Title
@onready var _emotion_label: Label = %EmotionLabel
@onready var _entries: VBoxContainer = %Entries
@onready var _close_button: Button = %CloseButton


func _ready() -> void:
	visible = false
	_close_button.pressed.connect(hide)
	EventBus.journal_opened.connect(open)


func open(character_name: String, emotion: String, entries: Array) -> void:
	_title.text = "Diario de " + character_name
	_face.emotion = emotion
	_emotion_label.text = "Ahora: " + CharacterData.EMOTIONS.get(emotion, "")
	for child in _entries.get_children():
		child.queue_free()
	if entries.is_empty():
		var empty := Label.new()
		empty.text = "Todavía no hay nada anotado."
		_entries.add_child(empty)
	# Lo más nuevo arriba.
	for i in range(entries.size() - 1, -1, -1):
		_entries.add_child(_make_row(entries[i]))
	show()


func _make_row(entry: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var face := MoodFace.new()
	face.custom_minimum_size = Vector2(34, 34)
	face.emotion = entry.get("emotion", "calm")
	row.add_child(face)
	var when := Label.new()
	when.text = "Día %d · %s" % [int(entry.get("day", 1)), entry.get("time", "")]
	when.custom_minimum_size = Vector2(130, 0)
	when.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9))
	when.add_theme_font_size_override("font_size", 15)
	row.add_child(when)
	var text := Label.new()
	text.text = entry.get("text", "")
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_size_override("font_size", 17)
	row.add_child(text)
	return row
