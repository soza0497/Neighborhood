class_name PathSmoother
extends RefCounted
## Alisa un camino de la red de la casa (que va de celda en celda) para que el personaje
## camine en CUALQUIER dirección y no en zigzag de 4 u 8 direcciones (Pulido 6B).
##
## Idea: desde un punto se salta al punto MÁS LEJANO del camino al que se llega en línea recta
## sin chocar (el cuerpo con un poco de aire, sin cruzar paredes ni pisar peligros que el
## camino rodeaba). Las escaleras (cambios de altura) y las puertas (hay una pared en el
## borde) nunca se saltan: el camino pasa por donde estaba.
##
## La parte geométrica (`smooth`) no sabe nada de la casa: recibe una función `line_clear`
## que dice si la recta entre dos puntos está libre. Así se prueba sola.

## Distancia entre muestras al revisar una recta (metros).
const STEP := 0.25
## Aire a cada lado de la recta (la mitad del cuerpo y un poco más).
const BODY_RADIUS := 0.3


## `path` = puntos del camino; `line_clear` = Callable(a: Vector3, b: Vector3) -> bool.
static func smooth(path: PackedVector3Array, line_clear: Callable) -> PackedVector3Array:
	if path.size() <= 2:
		return path
	var result := PackedVector3Array()
	result.append(path[0])
	var anchor := 0
	while anchor < path.size() - 1:
		var furthest := anchor + 1
		for i in range(path.size() - 1, anchor + 1, -1):
			if absf(path[i].y - path[anchor].y) > 0.01:
				continue  # Las escaleras no se cortan.
			if _same_height(path, anchor, i) and line_clear.call(path[anchor], path[i]):
				furthest = i
				break
		result.append(path[furthest])
		anchor = furthest
	return result


## Todos los puntos entre uno y otro están a la misma altura (no hay una escalera en el medio).
static func _same_height(path: PackedVector3Array, from: int, to: int) -> bool:
	for i in range(from, to + 1):
		if absf(path[i].y - path[from].y) > 0.01:
			return false
	return true


## Puntos donde revisar una recta: cada STEP metros, con el cuerpo a los lados (±BODY_RADIUS).
static func samples(a: Vector3, b: Vector3) -> Array:
	var points: Array = []
	var flat := Vector2(b.x - a.x, b.z - a.z)
	var length := flat.length()
	var count := maxi(1, int(ceil(length / STEP)))
	var side := Vector2(-flat.y, flat.x).normalized() * BODY_RADIUS if length > 0.001 else Vector2.ZERO
	for i in count + 1:
		var t := float(i) / float(count)
		var center := Vector2(a.x, a.z).lerp(Vector2(b.x, b.z), t)
		points.append(center)
		points.append(center + side)
		points.append(center - side)
	return points
