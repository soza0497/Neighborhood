class_name CharacterAnimator
extends Node
## Ganchos de animación del personaje.
##
## El personaje solo dice play("walk"), play("sleep"), etc. Hoy esas
## animaciones son movimientos simples hechos con código sobre la figura
## provisional. En la Fase 7, si el modelo .glb trae un AnimationPlayer con
## animaciones de esos mismos nombres, se usan esas en vez de estas.

## Animaciones que el juego puede pedir.
const ANIMATIONS := ["idle", "walk", "sleep", "sit", "cook", "eat", "shower", "use"]

## La figura que se mueve (el nodo "Body" de CharacterLook).
var body: Node3D
## Si el modelo final trae animaciones, se ponen aquí.
var animation_player: AnimationPlayer
var current := "idle"
var _time := 0.0


## Cambia de animación. Si el nombre no existe, usa "idle".
func play(anim: String) -> void:
	if not anim in ANIMATIONS:
		anim = "idle"
	current = anim
	if animation_player != null and animation_player.has_animation(anim):
		animation_player.play(anim)


func _process(delta: float) -> void:
	if body == null or (animation_player != null and animation_player.has_animation(current)):
		return
	_time += delta
	# Se parte de la pose neutra y cada animación la modifica un poco.
	body.position = Vector3.ZERO
	body.rotation = Vector3.ZERO
	body.scale = Vector3.ONE
	match current:
		"idle":
			body.position.y = sin(_time * 2.0) * 0.015
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
