class_name SaveMigrations
## Migraciones del archivo de guardado: convierten una partida vieja al
## formato actual, un paso por versión (1 → 2, 2 → 3...).
##
## Para agregar una: subí SaveSystem.FORMAT_VERSION, escribí una función
## `_v<N>_to_<N+1>` y sumala a STEPS. Cada paso recibe y devuelve el
## diccionario completo del archivo (con "state" adentro).

## Dinero con el que empieza una partida (también el de las partidas viejas).
const STARTING_MONEY := 3000

## version de origen → función que la sube a la siguiente.
const STEPS := {1: "_v1_to_v2"}


## Sube `data` hasta la versión `target`. Devuelve el diccionario nuevo.
static func migrate(data: Dictionary, target: int) -> Dictionary:
	var version := int(data.get("format_version", 0))
	while version < target:
		if not STEPS.has(version):
			push_warning("Guardado: no hay migración desde la versión %d" % version)
			break
		data = Callable(SaveMigrations, STEPS[version]).call(data)
		version += 1
		data["format_version"] = version
	return data


## v1 → v2 (Fase 3): aparece la economía. Las casas construidas antes no se
## cobran: sus piezas cuentan como "descubiertas" (no dan experiencia) y el
## dinero arranca con el valor inicial.
static func _v1_to_v2(data: Dictionary) -> Dictionary:
	var state: Dictionary = data.get("state", {})
	var discovered := {}
	var house: Dictionary = state.get("house", {})
	for level in house.get("levels", []):
		for layer in level:
			for key in level[layer]:
				var item_id: String = level[layer][key].get("item", "")
				if item_id != "":
					discovered[item_id] = true
				var opening: String = level[layer][key].get("opening", "")
				if opening != "":
					discovered[opening] = true
	state["economy"] = {
		"money": STARTING_MONEY,
		"xp": 0,
		"discovered": discovered.keys(),
		"job": {},
	}
	data["state"] = state
	return data
