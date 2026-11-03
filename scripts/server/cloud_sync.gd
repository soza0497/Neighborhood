class_name CloudSync
## Qué se manda a la nube y cómo se une con la partida del teléfono.
## Sin nada de red: solo diccionarios (así se puede probar sola).
##
## Reglas de la Fase 4A (ver DECISIONES.md, "Cuentas y servidor"):
##   - La primera vez que una cuenta entra, se importa la partida del teléfono
##     (casa, experiencia, lo descubierto, personaje y opciones).
##   - Casa y economía: en la 4A el teléfono todavía manda (la 4B las pasa al
##     servidor). Se usa la copia del servidor solo si el teléfono no tiene
##     casa (por ejemplo, después de reinstalar) o si la partida del teléfono
##     es de otra cuenta.
##   - Personaje: gana el guardado más nuevo (teléfono o nube).
##   - Opciones: las del teléfono, salvo que no tenga o sean de otra cuenta.

const CLOUD_COLLECTION := "cloud"
## Permisos del storage de Nakama: 1 = solo el dueño.
const OWNER_ONLY := 1


## Lo que se manda a game_import (casa, personaje y opciones como texto JSON).
static func import_payload(state: Dictionary) -> Dictionary:
	var economy: Dictionary = state.get("economy", {})
	return {
		"house": _to_text(state.get("house", {})),
		"xp": int(economy.get("xp", 0)),
		"discovered": as_array(economy.get("discovered", [])),
		"character": _to_text(state.get("character", {})),
		"settings": _to_text(state.get("settings", {})),
	}


## Une la partida del teléfono (`local`, como GameState.to_dict()) con lo que
## devolvió game_load. Devuelve la partida nueva (para GameState.from_dict).
static func merge(local: Dictionary, server: Dictionary, user_id: String, username: String) -> Dictionary:
	var owner: String = local.get("account", {}).get("user_id", "")
	var same_account := owner == "" or owner == user_id
	var result: Dictionary = local.duplicate(true) if same_account else {}

	var local_house: Dictionary = result.get("house", {})
	if not same_account or local_house.is_empty():
		var server_house := _from_text(server.get("house", ""))
		if not server_house.is_empty() or not same_account:
			result["house"] = server_house
			result["economy"] = {
				"money": int(server.get("money", SaveMigrations.STARTING_MONEY)),
				"xp": int(server.get("xp", 0)),
				"discovered": as_array(server.get("discovered", [])),
				"job": {},
			}

	var cloud_character := _from_text(server.get("character", ""))
	var local_character: Dictionary = result.get("character", {})
	if not cloud_character.is_empty() and (local_character.is_empty()
			or int(cloud_character.get("saved_unix", 0)) > int(local_character.get("saved_unix", 0))):
		result["character"] = cloud_character

	var cloud_settings := _from_text(server.get("settings", ""))
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
	var settings: Dictionary = state.get("settings", {})
	if not settings.is_empty():
		# Las opciones no usan la hora (gana el teléfono), así el valor no
		# cambia si no cambian y no se vuelven a subir.
		objects.append(_object("settings", settings, 0))
	return objects


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
