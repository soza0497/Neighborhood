class_name CharacterAnimator
extends Node
## Ganchos de animación del personaje.
##
## El personaje solo dice play("walk"), play("sleep"), etc. Hoy esas
## animaciones son movimientos simples hechos con código sobre la figura
## provisional. En la Fase 7, si el modelo .glb trae un AnimationPlayer con
## animaciones de esos mismos nombres, se usan esas en vez de estas.

## Animaciones que el juego puede pedir.
const ANIMATIONS := ["idle", "walk", "sleep", "sit", "cook", "eat", "shower", "use", "arrive", "wave", "cough", "hurt", "fall", "trip", "burn"]

## La figura que se mueve (el nodo "Body" de CharacterLook).
var body: Node3D
## Si el modelo final trae animaciones, se ponen aquí.
var animation_player: AnimationPlayer
## Fase 7: nombre del gancho → nombre real en el AnimationPlayer del .glb
## (según "animations" de data/character_slots.json).
var _clip_names: Dictionary = {}
var current := "idle"
var _time := 0.0
## Pulido 4B: segundos desde el último play() (para fall y trip, que no se repiten en bucle).
var _time_since_play := 0.0


## Fase 7: busca un AnimationPlayer en el cuerpo armado (si algún .glb lo trae)
## y empareja los ganchos (idle, walk, sleep, cook...) con sus animaciones por nombre.
## Sin AnimationPlayer o sin ese nombre, sigue la animación simple de este archivo.
func bind_model(model: Node) -> void:
	animation_player = null
	_clip_names = {}
	if model == null:
		return
	var found := model.find_children("*", "AnimationPlayer", true, false)
	if found.is_empty():
		return
	animation_player = found[0] as AnimationPlayer
	# Mayúsculas y minúsculas no importan («Walk» de Blender = «walk»).
	var by_lowercase := {}
	for clip_name in animation_player.get_animation_list():
		by_lowercase[String(clip_name).to_lower()] = String(clip_name)
	var aliases: Dictionary = CharacterAssembler.config().get("animations", {})
	for hook in ANIMATIONS:
		var accepted: Array = aliases.get(hook, [hook])
		for clip in accepted:
			if by_lowercase.has(str(clip).to_lower()):
				_clip_names[hook] = by_lowercase[str(clip).to_lower()]
				break
	play(current)


## ¿Este gancho tiene una animación real del modelo?
func _has_clip(hook: String) -> bool:
	return animation_player != null and _clip_names.has(hook)


## Cambia de animación. Si el nombre no existe, usa "idle".
func play(anim: String) -> void:
	if not anim in ANIMATIONS:
		anim = "idle"
	current = anim
	_time_since_play = 0.0
	if _has_clip(anim):
		animation_player.play(_clip_names[anim])


func _process(delta: float) -> void:
	if body == null or _has_clip(current):
		return
	_time += delta
	_time_since_play += delta
	# Se parte de la pose neutra y cada animación la modifica un poco.
	body.position = Vector3.ZERO
	body.rotation = Vector3.ZERO
	body.scale = Vector3.ONE
	match current:
		"idle":
			# Respira, se balancea un poquito y de vez en cuando mira alrededor.
			body.position.y = sin(_time * 2.0) * 0.015
			body.scale = Vector3(1.0 + sin(_time * 2.0) * 0.012, 1.0 - sin(_time * 2.0) * 0.012, 1.0)
			body.rotation.z = sin(_time * 0.9) * 0.015
			var look_cycle := fmod(_time, 7.0)
			if look_cycle > 5.0:
				body.rotation.y = sin((look_cycle - 5.0) / 2.0 * PI) * 0.35
		"arrive":
			# Llega de trabajar: un saltito de alegría (rebota y se estira).
			body.position.y = absf(sin(_time * 8.0)) * 0.18
			body.scale = Vector3(1.0, 1.0 + absf(sin(_time * 8.0)) * 0.08, 1.0)
		"cough":
			# Tose: se dobla hacia adelante y tiembla.
			body.rotation.x = 0.25 + sin(_time * 22.0) * 0.08
			body.position.y = absf(sin(_time * 22.0)) * 0.03
		"hurt":
			# Acostado en el suelo, quejándose (nada grave).
			body.rotation.x = -PI / 2.0
			body.position = Vector3(0, 0.12, 0.3)
			body.scale.y = 1.0 + sin(_time * 3.0) * 0.015
		"fall":
			# Pulido 4B: cae de espaldas y queda tendido (gancho: si el modelo trae «fall», se usa).
			var fall_t := minf(_time_since_play * 3.0, 1.0)
			body.rotation.x = -PI / 2.0 * fall_t
			body.position = Vector3(0, 0.12 * fall_t, 0.3 * fall_t)
		"trip":
			# Pulido 4B: tropiezo: se inclina hacia adelante, se sacude y se endereza.
			var trip_t := minf(_time_since_play, 1.2)
			body.rotation.x = sin(trip_t / 1.2 * PI) * 0.55
			body.rotation.z = sin(_time * 22.0) * 0.05 * (1.2 - trip_t)
			body.position.y = absf(sin(trip_t / 1.2 * PI)) * 0.04
		"burn":
			# Pulido 4B: se quema: salta y sacude las manos (gancho: «burn» del modelo).
			body.position.y = absf(sin(_time * 14.0)) * 0.12
			body.rotation.z = sin(_time * 28.0) * 0.14
			body.rotation.x = 0.1
		"wave":
			# Se despide: se mece de lado a lado.
			body.rotation.z = sin(_time * 10.0) * 0.18
			body.position.y = absf(sin(_time * 5.0)) * 0.05
		"walk":
			body.position.y = absf(sin(_time * 9.0)) * 0.06
			body.rotation.z = sin(_time * 9.0) * 0.08
		"sleep":
			# Acostado boca arriba con la cabeza hacia atrás (la almohada).
			body.rotation.x = -PI / 2.0
			body.position = Vector3(0, 0.15, 0.35)
			body.scale.y = 1.0 + sin(_time * 1.5) * 0.02
		"sit":
			body.position.y = -0.3
		"cook", "use":
			body.rotation.y = sin(_time * 6.0) * 0.15
			body.position.y = absf(sin(_time * 6.0)) * 0.02
		"eat":
			body.rotation.x = absf(sin(_time * 5.0)) * 0.15
		"shower":
			body.rotation.y = sin(_time * 10.0) * 0.3
			body.position.y = absf(sin(_time * 5.0)) * 0.04
