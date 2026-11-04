class_name CharacterData
extends RefCounted
## Datos de un personaje (sin nada 3D): nombre, apariencia, rasgos y
## necesidades. Se guarda en JSON y, desde la Fase 4, también en el servidor.
##
## Necesidades: de 0 (muy mal) a 100 (perfecto). Bajan con el tiempo y suben
## al hacer acciones. Principio del juego: NUNCA bajan de un mínimo
## (NEED_FLOOR), así desconectarse no causa desastres.

## Necesidades, en el orden en que se muestran.
const NEEDS := ["hunger", "energy", "hygiene", "fun"]
## Nombres para la interfaz.
const NEED_NAMES := {"hunger": "Comida", "energy": "Energía", "hygiene": "Limpieza", "fun": "Diversión"}
## Cuánto baja cada necesidad por hora del juego (antes de los rasgos).
const DECAY_PER_HOUR := {"hunger": 6.0, "energy": 4.0, "hygiene": 3.0, "fun": 5.0}
## Mínimo absoluto mientras se juega.
const NEED_FLOOR := 10.0
## Mínimo cuando el tiempo pasó sin jugar (más suave todavía).
const OFFLINE_FLOOR := 30.0
## Debajo de esto, la necesidad "se nota" (burbuja de aviso).
const LOW_NEED := 25.0
## Emociones (para el diario; no cambian cómo funciona el personaje).
const EMOTIONS := {
	"happy": "Feliz", "calm": "Tranquilo", "tired": "Cansado", "angry": "Enojado",
	"bored": "Aburrido", "uncomfortable": "Incómodo", "sad": "Triste",
}
## Qué emoción da cada necesidad cuando está baja.
const LOW_NEED_EMOTION := {"hunger": "angry", "energy": "tired", "fun": "bored", "hygiene": "uncomfortable"}
## Cuántas entradas guarda el diario (las más viejas se borran).
const JOURNAL_MAX := 60

var name := "Alex"
## Colores: skin, hair, shirt, pants (texto "#rrggbb") y piezas: hairstyle,
## eyes, mouth (ids de data/character_options.json).
var appearance: Dictionary = {}
## Ids de rasgos (ver data/traits.json).
var traits: Array = []
var needs: Dictionary = {}
## Diario: lo que hizo y cómo se sentía. Cada entrada es
## {day, time, text, emotion}. La más nueva va al final.
var journal: Array = []


func _init() -> void:
	for need in NEEDS:
		needs[need] = 80.0


## Personaje nuevo con los valores por defecto del editor.
static func create_default() -> CharacterData:
	var data := CharacterData.new()
	var defaults: Dictionary = Catalog.character_options.get("default", {})
	data.name = defaults.get("name", "Alex")
	for part in ["skin", "hair", "shirt", "pants"]:
		data.appearance[part] = defaults.get(part, "#ffffff")
	# Pulido 3B: piezas intercambiables (peinado, ojos, boca).
	for part in CharacterLook.DEFAULT_PIECES:
		data.appearance[part] = defaults.get(part, CharacterLook.DEFAULT_PIECES[part])
	data.traits = defaults.get("traits", []).duplicate()
	return data


## Hace pasar el tiempo: las necesidades bajan según los rasgos.
## `floor_value` es el mínimo hasta donde pueden bajar.
func decay(game_minutes: float, floor_value := NEED_FLOOR) -> void:
	for need in NEEDS:
		var amount: float = DECAY_PER_HOUR[need] * decay_multiplier(need) * game_minutes / 60.0
		var value: float = needs[need]
		# Si ya estaba debajo del mínimo (por ejemplo, offline), no baja más.
		if value > floor_value:
			needs[need] = maxf(value - amount, floor_value)


## Suma (o resta) a una necesidad, entre el mínimo y 100.
func add_need(need: String, amount: float) -> void:
	needs[need] = clampf(float(needs.get(need, 0.0)) + amount, NEED_FLOOR, 100.0)


## Cuánto más rápido (o lento) baja una necesidad por los rasgos.
func decay_multiplier(need: String) -> float:
	var result := 1.0
	for trait_id in traits:
		result *= float(Catalog.traits.get(trait_id, {}).get("decay", {}).get(need, 1.0))
	return result


## Cuánto le gusta al personaje una acción, según sus rasgos (1 = normal).
func likes(action: Dictionary) -> float:
	var result := 1.0
	for trait_id in traits:
		var trait_likes: Dictionary = Catalog.traits.get(trait_id, {}).get("likes", {})
		for tag in action.get("tags", []):
			result *= float(trait_likes.get(tag, 1.0))
	return result


## Ánimo general: promedio de las necesidades (0..100).
func mood() -> float:
	return mood_for(needs)


## Ánimo en palabras.
func mood_text() -> String:
	return mood_text_for(needs)


## Cómo se siente: una necesidad baja da su emoción (con hambre se enoja),
## dos o más lo ponen triste, y si todo va bien está feliz.
func emotion() -> String:
	return emotion_for(needs)


# Las mismas cuentas a partir de un diccionario de necesidades (así la
# interfaz las puede hacer con lo que le llega por EventBus).

static func mood_for(values: Dictionary) -> float:
	var total := 0.0
	for need in NEEDS:
		total += float(values.get(need, 0.0))
	return total / NEEDS.size()


static func mood_text_for(values: Dictionary) -> String:
	var value := mood_for(values)
	if value >= 75:
		return "Feliz"
	if value >= 55:
		return "Bien"
	if value >= 35:
		return "Más o menos"
	return "Desanimado"


static func emotion_for(values: Dictionary) -> String:
	var low: Array = NEEDS.filter(func(need): return float(values.get(need, 0.0)) < LOW_NEED)
	if low.size() >= 2:
		return "sad"
	if low.size() == 1:
		return LOW_NEED_EMOTION[low[0]]
	return "happy" if mood_for(values) >= 70.0 else "calm"


## Qué está afectando el ánimo (Pulido 1, tarjeta del ánimo): lista de
## {emotion, text}. Primero lo que lo baja (necesidades bajas), después lo
## que lo sube (necesidades muy bien cubiertas).
const LOW_NEED_REASONS := {
	"hunger": "Tiene hambre", "energy": "Está cansado", "hygiene": "Necesita bañarse", "fun": "Se aburre",
}
const HIGH_NEED_REASONS := {
	"hunger": "Comió bien", "energy": "Descansó", "hygiene": "Está limpio", "fun": "Se divirtió",
}
const HIGH_NEED := 80.0

static func mood_factors(values: Dictionary) -> Array:
	var result: Array = []
	for need in NEEDS:
		if float(values.get(need, 0.0)) < LOW_NEED:
			result.append({"emotion": LOW_NEED_EMOTION[need], "text": "%s (%s baja)" % [LOW_NEED_REASONS[need], NEED_NAMES[need].to_lower()]})
	for need in NEEDS:
		if float(values.get(need, 0.0)) >= HIGH_NEED:
			result.append({"emotion": "happy", "text": HIGH_NEED_REASONS[need]})
	if result.is_empty():
		result.append({"emotion": "calm", "text": "Nada especial: todo más o menos bien"})
	return result


## Anota algo en el diario, con la hora del juego y la emoción de ahora.
func add_journal(text: String) -> void:
	journal.append({"day": GameClock.day(), "time": GameClock.time_text(), "text": text, "emotion": emotion()})
	while journal.size() > JOURNAL_MAX:
		journal.pop_front()


## La necesidad más baja (para las burbujas de aviso).
func lowest_need() -> String:
	var lowest: String = NEEDS[0]
	for need in NEEDS:
		if needs[need] < needs[lowest]:
			lowest = need
	return lowest


func to_dict() -> Dictionary:
	return {
		"name": name,
		"appearance": appearance.duplicate(),
		"traits": traits.duplicate(),
		"needs": needs.duplicate(),
		"journal": journal.duplicate(true),
	}


func from_dict(data: Dictionary) -> void:
	name = data.get("name", name)
	appearance = data.get("appearance", appearance).duplicate()
	traits = data.get("traits", traits).duplicate()
	journal = data.get("journal", journal).duplicate(true)
	var saved_needs: Dictionary = data.get("needs", {})
	for need in NEEDS:
		needs[need] = clampf(float(saved_needs.get(need, needs[need])), NEED_FLOOR, 100.0)
