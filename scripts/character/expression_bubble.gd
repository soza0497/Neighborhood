class_name ExpressionBubble
extends Sprite3D
## La nubecita de cómic sobre la cabeza (Pulido 6B): reemplaza los diálogos escritos. Muestra una
## carita o un símbolo (ExpressionArt) que aparece con un saltito y se va achicando al irse.
##
## Dos formas de usarla:
##   - show_expression("dizzy", 2.5): esa expresión, 2,5 segundos (0 = hasta que se la cambie o se la saque).
##   - say_event("action:sleep", rng): elige UNA de las expresiones de esa situación (data/expressions.json);
##     si ya está mostrando esa situación, no la cambia (así no parpadea).
## Mira siempre a la cámara. No es un nodo "inteligente": el personaje decide cuándo y qué.

## Id de la expresión que se ve ahora ("" si ninguna) y de la situación que la pidió.
var current := ""
var key := ""

var _timed := false
var _hold_until_msec := 0
var _tween: Tween
var _base_y := 0.0
var _clock := 0.0


func _init() -> void:
	name = "ExpressionBubble"
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	shaded = false
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	render_priority = 5
	var config := ExpressionArt.bubble_config()
	pixel_size = float(config.get("pixel_size", 0.0082))
	_base_y = float(config.get("height", 1.45))
	position.y = _base_y
	# La punta de la colita queda en el origen del nodo (arriba de la cabeza).
	var size := ExpressionArt.canvas_size()
	offset = Vector2(size.x / 2.0 - ExpressionArt.TAIL_TIP.x, ExpressionArt.TAIL_TIP.y - size.y / 2.0)
	visible = false
	set_process(false)


## Altura (m) a la que queda la colita. Los servicios la suben para que no tape al vehículo.
func set_height(meters: float) -> void:
	_base_y = meters
	position.y = meters


## Muestra una expresión por `seconds` segundos (0 = sin límite). Una id que no existe la saca.
func show_expression(id: String, seconds := 0.0) -> void:
	if not ExpressionArt.has_expression(id):
		clear()
		return
	var was_visible := visible and current != ""
	var changed := id != current
	current = id
	texture = ExpressionArt.texture(id)
	_timed = seconds > 0.0
	_hold_until_msec = Time.get_ticks_msec() + int(seconds * 1000.0)
	visible = true
	set_process(true)
	if changed or not was_visible:
		_pop()


## Elige una de las expresiones de una situación. Devuelve la id elegida ("" si no hay).
## Si esa situación ya se está mostrando y `force` es false, la deja como está.
func say_event(event: String, rng: RandomNumberGenerator, seconds := 0.0, force := false) -> String:
	var variants := ExpressionArt.event_variants(event)
	if variants.is_empty():
		clear()
		return ""
	if event == key and visible and not force:
		_timed = seconds > 0.0
		_hold_until_msec = Time.get_ticks_msec() + int(seconds * 1000.0)
		return current
	var id := str(variants[rng.randi() % variants.size()])
	show_expression(id, seconds)
	key = event
	return id


## ¿Hay una expresión con tiempo que todavía no se acabó? (el personaje no la pisa con otra)
func is_held() -> bool:
	return visible and _timed and Time.get_ticks_msec() < _hold_until_msec


func clear() -> void:
	current = ""
	key = ""
	_timed = false
	if not visible:
		return
	if _tween != null:
		_tween.kill()
	_tween = create_tween() if is_inside_tree() else null
	if _tween == null:
		visible = false
		return
	_tween.tween_property(self, "scale", Vector3.ONE * 0.2, 0.12)
	_tween.tween_callback(func() -> void:
		if current == "":
			visible = false
			set_process(false))


## Aparece con un saltito: crece de más y se acomoda.
func _pop() -> void:
	if _tween != null:
		_tween.kill()
	scale = Vector3.ONE * 0.2
	if not is_inside_tree():
		scale = Vector3.ONE
		return
	_tween = create_tween()
	var seconds := float(ExpressionArt.bubble_config().get("pop_seconds", 0.28))
	_tween.tween_property(self, "scale", Vector3.ONE, seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_clock += delta
	if visible:
		position.y = _base_y + sin(_clock * 3.0) * 0.025  # Flota despacito.
	if _timed and Time.get_ticks_msec() >= _hold_until_msec:
		clear()
