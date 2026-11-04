class_name HouseTemplates
extends RefCounted
## Las plantillas guardadas en la cuenta (Pulido 5E): guardar, ver, renombrar y
## borrar. Viven en las opciones de la partida (`GameState.settings`), así que
## se guardan con la partida y, con cuenta, suben a la nube junto con el resto
## de las opciones (CloudSync). No hay ninguna regla de dinero acá: colocar una
## plantilla se cobra por el constructor y el servidor.

const SETTINGS_KEY := "house_templates"
## Cuántas plantillas puede tener una cuenta y qué tan grandes (para que las
## opciones de la nube no crezcan sin tope).
const MAX_TEMPLATES := 10
const MAX_PIECES := 1500
const MAX_NAME := 24
## Guardar la partida en cuanto cambia la lista (las pruebas lo apagan para no tocar tu partida).
static var autosave := true


## Todas, en el orden en que se guardaron. No modificar lo que devuelve.
static func all() -> Array:
	var list: Variant = GameState.settings.get(SETTINGS_KEY, [])
	return list if list is Array else []


static func find(id: String) -> Dictionary:
	for template in all():
		if template.get("id", "") == id:
			return template
	return {}


## Guarda la estructura de la casa como plantilla nueva.
## Devuelve {ok, error, template}.
static func save_house(house: HouseData, wanted_name: String) -> Dictionary:
	if all().size() >= MAX_TEMPLATES:
		return _fail("Ya tenés %d plantillas: borrá alguna para guardar otra." % MAX_TEMPLATES)
	var clean := clean_name(wanted_name)
	if clean == "":
		return _fail("Escribí un nombre para la plantilla.")
	var template := HouseTemplate.capture(house, unique_name(clean, ""))
	if template.is_empty():
		return _fail("La casa no tiene nada para guardar (cimientos, pisos, paredes, techos, escaleras o pilares).")
	if (template["pieces"] as Array).size() > MAX_PIECES:
		return _fail("La casa es demasiado grande para una plantilla (máximo %d piezas)." % MAX_PIECES)
	template["id"] = _new_id()
	var list := all().duplicate()
	list.append(template)
	_store(list)
	return {"ok": true, "error": "", "template": template}


## Le cambia el nombre. Devuelve {ok, error}.
static func rename(id: String, wanted_name: String) -> Dictionary:
	var clean := clean_name(wanted_name)
	if clean == "":
		return _fail("Escribí un nombre para la plantilla.")
	var list := all().duplicate()
	for template in list:
		if template.get("id", "") == id:
			template["name"] = unique_name(clean, id)
			_store(list)
			return {"ok": true, "error": ""}
	return _fail("Esa plantilla ya no existe.")


static func remove(id: String) -> bool:
	var list := all().filter(func(t) -> bool: return t.get("id", "") != id)
	if list.size() == all().size():
		return false
	_store(list)
	return true


## Nombre sin espacios de más y de largo razonable ("" si queda vacío).
static func clean_name(text: String) -> String:
	return text.strip_edges().left(MAX_NAME).strip_edges()


## Si el nombre ya existe (en otra plantilla), le agrega « (2)», « (3)»...
static func unique_name(wanted: String, own_id: String) -> String:
	var taken := {}
	for template in all():
		if template.get("id", "") != own_id:
			taken[str(template.get("name", "")).to_lower()] = true
	if not taken.has(wanted.to_lower()):
		return wanted
	var n := 2
	while taken.has(("%s (%d)" % [wanted, n]).to_lower()):
		n += 1
	return "%s (%d)" % [wanted, n]


static func _new_id() -> String:
	var id := ""
	while id == "" or not find(id).is_empty():
		id = "t%d%03d" % [int(Time.get_unix_time_from_system()), randi() % 1000]
	return id


static func _fail(text: String) -> Dictionary:
	return {"ok": false, "error": text, "template": {}}


## Guarda la lista, avisa a quien la muestre y pide guardar la partida.
static func _store(list: Array) -> void:
	GameState.settings[SETTINGS_KEY] = list
	EventBus.templates_changed.emit()
	if autosave:
		SaveSystem.save_game()
