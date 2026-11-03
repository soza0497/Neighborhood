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

var name := "Alex"
## Colores: skin, hair, shirt, pants (texto "#rrggbb").
var appearance: Dictionary = {}
## Ids de rasgos (ver data/traits.json).
var traits: Array = []
var needs: Dictionary = {}


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
	var total := 0.0
	for need in NEEDS:
		total += needs[need]
	return total / NEEDS.size()


## Ánimo en palabras.
func mood_text() -> String:
	var value := mood()
	if value >= 75:
		return "Feliz"
	if value >= 55:
		return "Bien"
	if value >= 35:
		return "Más o menos"
	return "Decaído"


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
	}


func from_dict(data: Dictionary) -> void:
	name = data.get("name", name)
	appearance = data.get("appearance", appearance).duplicate()
	traits = data.get("traits", traits).duplicate()
	var saved_needs: Dictionary = data.get("needs", {})
	for need in NEEDS:
		needs[need] = clampf(float(saved_needs.get(need, needs[need])), NEED_FLOOR, 100.0)
