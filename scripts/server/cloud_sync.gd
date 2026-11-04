class_name CloudSync
## Qué se manda a la nube y cómo se une con la partida del teléfono.
## Sin nada de red: solo diccionarios (así se puede probar sola).
##
## Reglas (ver DECISIONES.md, "Cuentas y servidor"):
##   - La primera vez que una cuenta entra, se importa la partida del teléfono
##     (casa, experiencia, lo descubierto, empleo, personaje y opciones).
##   - Desde la Fase 4B la casa y la economía las manda el SERVIDOR: al entrar
##     con conexión, siempre gana lo del servidor (dinero, casa, experiencia,
##     empleo). Del teléfono solo queda el día del último turno (el reloj del
##     juego es del teléfono).
##   - Personaje: gana el guardado más nuevo (teléfono o nube).
##   - Opciones: las del teléfono, salvo que no tenga o sean de otra cuenta.

const CLOUD_COLLECTION := "cloud"
## Permisos del storage de Nakama: 1 = solo el dueño.
const OWNER_ONLY := 1


## Pulido 4B: opciones que son SOLO de este teléfono y nunca viajan al servidor (el modo
## desarrollador). Si un día se agrega otra, va acá.
const LOCAL_ONLY_SETTINGS := ["dev_mode"]


## Las opciones sin las que son solo locales (lo único que se sube al servidor).
static func public_settings(settings: Dictionary) -> Dictionary:
	var result := settings.duplicate(true)
	for key in LOCAL_ONLY_SETTINGS:
		result.erase(key)
	return result


## Lo que se manda a game_import (casa, personaje y opciones como texto JSON).
static func import_payload(state: Dictionary) -> Dictionary:
	var economy: Dictionary = state.get("economy", {})
	return {
		"house": _to_text(state.get("house", {})),
		"xp": int(economy.get("xp", 0)),
		"discovered": as_array(economy.get("discovered", [])),
		"job_id": str((economy.get("job", {}) as Dictionary).get("job_id", "")),
		"character": _to_text(state.get("character", {})),
		"settings": _to_text(public_settings(state.get("settings", {}))),
	}


## Une la partida del teléfono (`local`, como GameState.to_dict()) con lo que
## devolvió game_load. Devuelve la partida nueva (para GameState.from_dict).
static func merge(local: Dictionary, server: Dictionary, user_id: String, username: String) -> Dictionary:
	var owner: String = local.get("account", {}).get("user_id", "")
	var same_account := owner == "" or owner == user_id
	var result: Dictionary = local.duplicate(true) if same_account else {}

	# Casa y economía: las del servidor (Fase 4B).
	var local_economy: Dictionary = result.get("economy", {})
	result["house"] = _from_text(server.get("house", ""))
	result["economy"] = economy_from_server(server, local_economy)

	var cloud_character := _from_text(server.get("character", ""))
	var local_character: Dictionary = result.get("character", {})
	if not cloud_character.is_empty() and (local_character.is_empty()
			or int(cloud_character.get("saved_unix", 0)) > int(local_character.get("saved_unix", 0))):
		result["character"] = cloud_character

	var cloud_settings := public_settings(_from_text(server.get("settings", "")))
	if not cloud_settings.is_empty() and (result.get("settings", {}) as Dictionary).is_empty():
		result["settings"] = cloud_settings

	result["account"] = {"user_id": user_id, "username": username}
	return result


## Objetos de storage que el teléfono sube: personaje y opciones.
## Formato del valor: {"json": texto, "saved_unix": hora}.
static func cloud_objects(state: Dictionary) -> Array:
	var objects: Array = []
	var character: Dictionary = state.get("character", {})
	if not character.is_empty():
		objects.append(_object("character", character, int(character.get("saved_unix", 0))))
	var settings := public_settings(state.get("settings", {}))
	if not settings.is_empty():
		# Las opciones no usan la hora (gana el teléfono), así el valor no
		# cambia si no cambian y no se vuelven a subir.
		objects.append(_object("settings", settings, 0))
	return objects


## La economía (como Economy.to_dict) a partir del resumen que manda el
## servidor ("state" de cada respuesta, o game_load). `local_economy` aporta
## lo que el servidor no sabe: el día del juego del último turno.
static func economy_from_server(server: Dictionary, local_economy := {}) -> Dictionary:
	var job: Dictionary = server.get("job", {}) if server.get("job") is Dictionary else {}
	var local_job: Dictionary = local_economy.get("job", {})
	return {
		"money": int(server.get("money", SaveMigrations.STARTING_MONEY)),
		"xp": int(server.get("xp", 0)),
		"discovered": as_array(server.get("discovered", [])),
		"job": {
			"job_id": str(job.get("job_id", "")),
			"applied_job": str(job.get("applied_job", "")),
			"resume_ready_at": int(job.get("resume_ready_at", 0)),
			"pending_pay": bool(job.get("shift_active", false)),
			"last_shift_unix": int(job.get("last_shift_unix", 0)),
			"last_work_day": int(local_job.get("last_work_day", 0)),
		},
	}


## Escrituras de la casa que devuelve el servidor, listas para
## HouseData.apply: el nivel como entero y "value" siempre presente (Lua no
## manda el null de "quitar", y una lista vacía llega como {}).
static func writes_from_server(writes: Variant) -> Array:
	var result: Array = []
	for w in as_array(writes):
		if not w is Dictionary:
			continue
		var value: Variant = w.get("value")
		result.append(HouseData.write(int(w.get("level", 0)), str(w.get("layer", "")), str(w.get("key", "")),
			value if value is Dictionary else null))
	return result


## El servidor (Lua) devuelve una lista vacía como diccionario vacío ({}).
static func as_array(value: Variant) -> Array:
	return value if value is Array else []


static func _object(key: String, data: Dictionary, saved_unix: int) -> Dictionary:
	return {
		"collection": CLOUD_COLLECTION,
		"key": key,
		"value": JSON.stringify({"json": JSON.stringify(data), "saved_unix": saved_unix}),
		"permission_read": OWNER_ONLY,
		"permission_write": OWNER_ONLY,
	}


static func _to_text(data: Dictionary) -> String:
	return "" if data.is_empty() else JSON.stringify(data)


static func _from_text(text: Variant) -> Dictionary:
	if not text is String or text == "":
		return {}
	var data: Variant = JSON.parse_string(text)
	return data if data is Dictionary else {}
