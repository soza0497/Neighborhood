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
const STEPS := {1: "_v1_to_v2", 2: "_v2_to_v3", 3: "_v3_to_v4"}


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


## v2 → v3 (Pulido 1): la pintura de cada pared pasa a sus dos caras y la
## unión de ventanas se guarda en la juntura (ver HouseData.upgrade_legacy).
## Los muebles no cambian: los de antes siguen derechos (sin "diag").
static func _v2_to_v3(data: Dictionary) -> Dictionary:
	var state: Dictionary = data.get("state", {})
	var house_dict: Dictionary = state.get("house", {})
	# Solo los niveles: lo demás (por ejemplo el tamaño de la parcela, que mueve
	# la casa al cargar) queda igual.
	if not house_dict.is_empty() and int(house_dict.get("format", 1)) < HouseData.LEGACY_FORMAT:
		HouseData.upgrade_legacy(house_dict.get("levels", []))
		house_dict["format"] = HouseData.LEGACY_FORMAT
		state["house"] = house_dict
	data["state"] = state
	return data


## v3 → v4 (Pulido 2C): la parcela crece 100 % hacia cada lado (de 32 a 96) y
## aparecen los obstáculos y los sótanos. La casa de antes NO se toca acá: al
## cargarla, HouseData.from_dict la centra sola según el tamaño de parcela
## con el que se guardó (lot_size), y el personaje se mueve igual. Lo único
## que se agrega es el estado nuevo, vacío (la parcela empieza sin limpiar).
static func _v3_to_v4(data: Dictionary) -> Dictionary:
	var state: Dictionary = data.get("state", {})
	if not state.has("parcel"):
		state["parcel"] = {}
	if not state.has("delivery"):
		state["delivery"] = {}
	var house_dict: Dictionary = state.get("house", {})
	if not house_dict.is_empty() and not house_dict.has("lot_size"):
		house_dict["lot_size"] = [12, 12]  # Las más viejas usaban 12 x 12.
		state["house"] = house_dict
	data["state"] = state
	return data
