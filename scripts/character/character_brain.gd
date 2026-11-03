class_name CharacterBrain
## La "IA de prioridades": decide qué hacer según las necesidades.
##
## No es IA generativa. Cada mueble anuncia acciones ("dormir: +95 energía").
## A cada opción se le da un puntaje:
##   puntaje = Σ (lo que sube cada necesidad × qué tan urgente está)
##             × cuánto le gusta por sus rasgos
##             ÷ (1 + lo lejos que está)
## Luego se elige al azar entre las mejores (así no es un robot predecible).

## Debajo de este puntaje no vale la pena moverse: el personaje pasea.
const MIN_SCORE := 3.0
## Se elige al azar entre las opciones con al menos este % del mejor puntaje.
const TOP_SHARE := 0.75
## Cuánto pesa la distancia (por cada paso del camino).
const DISTANCE_WEIGHT := 0.04


## Qué tan urgente es subir una necesidad (0 = nada, 1 = muchísimo).
## La curva hace que una necesidad baja pese MUCHO más que una a medias.
static func urgency(value: float) -> float:
	var missing := clampf((100.0 - value) / 100.0, 0.0, 1.0)
	return missing * missing


## Puntaje de una acción para este personaje. `path_length` = pasos hasta el
## objeto.
static func score(data: CharacterData, action: Dictionary, path_length: int) -> float:
	var total := 0.0
	var gains: Dictionary = action.get("gains", {})
	for need in gains:
		var gain := float(gains[need])
		if gain > 0.0:
			# No se cuenta lo que "sobra" (subir de 90 a 190 no sirve).
			var useful := minf(gain, 100.0 - float(data.needs.get(need, 100.0)))
			total += useful * urgency(data.needs.get(need, 100.0))
		else:
			total += gain * 0.2  # Lo que baja resta un poco.
	if total <= 0.0:
		return 0.0
	return total * data.likes(action) / (1.0 + path_length * DISTANCE_WEIGHT)


## Elige entre opciones. Cada opción es un diccionario con al menos
## "action" (de actions.json) y "path_length". Devuelve la elegida o {}.
static func choose(data: CharacterData, options: Array, rng: RandomNumberGenerator) -> Dictionary:
	var best := 0.0
	for option in options:
		option["score"] = score(data, option["action"], option["path_length"])
		best = maxf(best, option["score"])
	if best < MIN_SCORE:
		return {}

	# Sorteo entre las mejores, con más chance para la de más puntaje.
	var finalists: Array = options.filter(func(o): return o["score"] >= best * TOP_SHARE)
	var total := 0.0
	for option in finalists:
		total += option["score"]
	var pick := rng.randf() * total
	for option in finalists:
		pick -= option["score"]
		if pick <= 0.0:
			return option
	return finalists[-1]
