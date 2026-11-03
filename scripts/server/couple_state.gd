class_name CoupleState
## La pareja y el hogar como los manda el servidor, y cómo se leen (Fase 5).
## Sin nada de red: solo diccionarios (así se puede probar sola).
##
## El servidor (Lua) manda las listas vacías como diccionarios vacíos ({}):
## aquí todo se "limpia" para que el resto del juego no tenga que cuidarlo.

## Estados de la relación (los del servidor) y cómo se muestran.
const STATUS_NAMES := {"single": "Sin pareja", "dating": "En pareja", "married": "Matrimonio"}
## Versión del formato del estado que se manda por el socket.
const STATUS_VERSION := 1
## Largo máximo del estado (Nakama no deja mandar textos enormes).
const MAX_STATUS_LENGTH := 480


## La relación (couple.summary del servidor), con todos los campos.
static func normalize_couple(raw: Variant) -> Dictionary:
	var c: Dictionary = raw if raw is Dictionary else {}
	var invites: Array = []
	for invite in CloudSync.as_array(c.get("invites_in")):
		if invite is Dictionary:
			invites.append({"from_id": str(invite.get("from_id", "")), "from_name": str(invite.get("from_name", ""))})
	var events: Array = []
	for e in CloudSync.as_array(c.get("events")):
		if e is Dictionary:
			events.append({"at": int(e.get("at", 0)), "text": str(e.get("text", ""))})
	return {
		"status": str(c.get("status", "single")),
		"partner_id": str(c.get("partner_id", "")),
		"partner_name": str(c.get("partner_name", "")),
		"since": int(c.get("since", 0)),
		"married_unix": int(c.get("married_unix", 0)),
		"shared": bool(c.get("shared", false)),
		"home_owner": str(c.get("home_owner", "")),
		"invite_to_name": str(c.get("invite_to_name", "")),
		"invites_in": invites,
		"proposal_kind": str(c.get("proposal_kind", "")),
		"proposal_by_me": bool(c.get("proposal_by_me", false)),
		"proposal_home_is_mine": bool(c.get("proposal_home_is_mine", false)),
		"events": events,
		"drama": bool(c.get("drama", false)),
		"family_mode": bool(c.get("family_mode", true)),
		"pool_income": bool(c.get("pool_income", false)),
		"partner_drama": bool(c.get("partner_drama", false)),
		"partner_pool_income": bool(c.get("partner_pool_income", false)),
		"drama_enabled": bool(c.get("drama_enabled", false)),
	}


## El hogar (home_summary del servidor): caja, pedidos e historial.
static func normalize_home(raw: Variant) -> Dictionary:
	var h: Dictionary = raw if raw is Dictionary else {}
	var requests: Array = []
	for r in CloudSync.as_array(h.get("requests")):
		if r is Dictionary:
			requests.append({"id": int(r.get("id", 0)), "by_me": bool(r.get("by_me", false)),
				"by_name": str(r.get("by_name", "")), "at": int(r.get("at", 0)), "text": str(r.get("text", "")),
				"cost": int(r.get("cost", 0))})
	var log: Array = []
	for e in CloudSync.as_array(h.get("log")):
		if e is Dictionary:
			log.append({"id": int(e.get("id", 0)), "rev": int(e.get("rev", 0)), "by_me": bool(e.get("by_me", false)),
				"by_name": str(e.get("by_name", "")), "at": int(e.get("at", 0)), "kind": str(e.get("kind", "")),
				"text": str(e.get("text", "")), "reverted": bool(e.get("reverted", false)),
				"can_revert": bool(e.get("can_revert", false))})
	return {
		"rev": int(h.get("rev", 0)),
		"shared": bool(h.get("shared", false)),
		"owner_id": str(h.get("owner_id", "")),
		"owner_is_me": bool(h.get("owner_is_me", true)),
		"fund": int(h.get("fund", 0)),
		"requests": requests,
		"log": log,
	}


## La pareja: nombre y su personaje (CharacterData.to_dict + nivel y celda,
## como Character.to_dict), o {} si no hay.
static func normalize_partner(raw: Variant) -> Dictionary:
	var p: Dictionary = raw if raw is Dictionary else {}
	if str(p.get("user_id", "")) == "":
		return {}
	var character: Variant = JSON.parse_string(str(p.get("character", ""))) if str(p.get("character", "")) != "" else {}
	return {
		"user_id": str(p["user_id"]),
		"username": str(p.get("username", "")),
		"character": character if character is Dictionary else {},
	}


static func in_couple(couple: Dictionary) -> bool:
	return couple.get("status", "single") in ["dating", "married"]


## Texto corto del estado de la relación, por ejemplo "En pareja con sofia".
static func status_text(couple: Dictionary) -> String:
	var status: String = couple.get("status", "single")
	if status == "single":
		if couple.get("invite_to_name", "") != "":
			return "Invitaste a %s: esperando respuesta." % couple["invite_to_name"]
		return "Sin pareja."
	var text := "%s con %s" % [STATUS_NAMES.get(status, status), couple.get("partner_name", "")]
	if couple.get("shared", false):
		text += " · viven juntos"
	return text + "."


## Texto del pedido pendiente dentro de la pareja ("" si no hay).
static func proposal_text(couple: Dictionary) -> String:
	var kind: String = couple.get("proposal_kind", "")
	var partner: String = couple.get("partner_name", "")
	if kind == "":
		return ""
	if couple.get("proposal_by_me", false):
		match kind:
			"marry":
				return "Le pediste casamiento a %s: esperando respuesta." % partner
			_:
				return "Propusiste vivir juntos (%s): esperando respuesta." % (
					"en tu casa" if couple.get("proposal_home_is_mine", false) else "en la casa de " + partner)
	match kind:
		"marry":
			return "%s te pidió casamiento." % partner
		_:
			if couple.get("proposal_home_is_mine", false):
				return "%s quiere mudarse a tu casa." % partner
			return "%s te invita a vivir en su casa." % partner


# --- Estado por el socket: la intención del personaje ---

## Lo que se manda a la pareja: la intención del personaje (ver
## Character.get_intention), en un texto JSON corto.
static func encode_status(intention: Dictionary) -> String:
	var compact := {"v": STATUS_VERSION}
	for key in ["character", "state", "action", "verb", "object", "key", "object_level", "level", "since"]:
		if intention.has(key):
			compact[key] = intention[key]
	var text := JSON.stringify(compact)
	if text.length() > MAX_STATUS_LENGTH:
		compact.erase("object")
		compact["verb"] = str(compact.get("verb", "")).left(40)
		text = JSON.stringify(compact)
	return text


## Lee el estado de la pareja. Devuelve {} si no es una intención válida
## (por ejemplo, recién conectada y todavía sin mandar nada).
static func decode_status(status: String) -> Dictionary:
	if status == "":
		return {}
	var data: Variant = JSON.parse_string(status)
	if not data is Dictionary or int(data.get("v", 0)) != STATUS_VERSION:
		return {}
	return {
		"character": str(data.get("character", "")),
		"state": str(data.get("state", "idle")),
		"action": str(data.get("action", "")),
		"verb": str(data.get("verb", "")),
		"object": str(data.get("object", "")),
		"key": str(data.get("key", "")),
		"object_level": int(data.get("object_level", 0)),
		"level": int(data.get("level", 0)),
		"since": int(data.get("since", 0)),
	}


# --- Casa: ponerse al día con lo que hizo la pareja ---

## Escrituras que convierten la casa `local` en `server` (las dos como
## HouseData.to_dict). Solo lo que cambió: así la vista 3D actualiza pieza
## por pieza. Las piezas se comparan como texto JSON (los números del
## servidor llegan como decimales).
static func diff_writes(local: Dictionary, server: Dictionary) -> Array:
	var writes: Array = []
	var local_levels: Array = local.get("levels", [])
	var server_levels: Array = server.get("levels", []) if server.get("levels") is Array else []
	for level in HouseGrid.MAX_LEVELS:
		var lv: Dictionary = local_levels[level] if level < local_levels.size() and local_levels[level] is Dictionary else {}
		var sv: Dictionary = server_levels[level] if level < server_levels.size() and server_levels[level] is Dictionary else {}
		for layer in HouseData.LAYERS:
			var a: Dictionary = lv.get(layer, {}) if lv.get(layer) is Dictionary else {}
			var b: Dictionary = sv.get(layer, {}) if sv.get(layer) is Dictionary else {}
			for key in b:
				if not a.has(key) or _as_text(a[key]) != _as_text(b[key]):
					writes.append(HouseData.write(level, layer, key, (b[key] as Dictionary).duplicate(true)))
			for key in a:
				if not b.has(key):
					writes.append(HouseData.write(level, layer, key, null))
	return writes


static func _as_text(value: Variant) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(value)), "", true)
