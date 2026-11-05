class_name DevMode
extends RefCounted
## Modo desarrollador (Pulido 4B): forzar situaciones para probarlas.
##
## Sirve para ver cómo reacciona el personaje cuando NO presta atención (más adelante
## tendrá estados como distraído, desorbitado o recién levantado en los que no esquiva
## peligros que normalmente esquivaría): cae por una puerta, pisa un charco, se quema.
##
## Reglas (si se cambian, anotarlo en DECISIONES.md):
##   - APAGADO por defecto. Mientras esté apagado no se ve nada y NINGUNA de estas
##     funciones hace algo (todas devuelven {ok: false}).
##   - El interruptor vive en GameState.settings["dev_mode"] (partida local). NUNCA viaja
##     al servidor (CloudSync.LOCAL_ONLY_SETTINGS lo saca de lo que se sube).
##   - NADA de dinero, experiencia ni propiedad: este archivo no toca Economy. Lo del
##     dinero lo decide el servidor y el modo desarrollador no puede alterarlo.
##   - El personaje solo expone `force_action`, `force_accident(kind)` y `attention`;
##     acá vive todo lo demás (necesidades, hora, teletransporte, peligros, registro).
##
## La interfaz está en ui/dev_panel.gd.

const SETTING := "dev_mode"
## Cuántas líneas guarda el registro corto.
const LOG_MAX := 8

## Lo último que pasó, para mostrar en pantalla (la más nueva al final).
static var _log: Array = []


static func is_enabled() -> bool:
	return bool(GameState.settings.get(SETTING, false))


## Prende o apaga el modo. Al apagarlo todo vuelve a lo normal: se quitan los peligros
## que se pusieron, el personaje recupera la atención y la IA, y se borra el registro.
static func set_enabled(on: bool, character: Character = null) -> void:
	if on == is_enabled():
		return
	if on:
		GameState.settings[SETTING] = true
	else:
		GameState.settings.erase(SETTING)  # No queda ni la clave en el archivo.
		HazardMap.clear()
		_log.clear()
		if character != null and is_instance_valid(character):
			character.attention = HazardMap.default_attention()
			character.set_ai_frozen(false)
	EventBus.dev_mode_changed.emit(on)


static func _fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}


static func _done(text: String) -> Dictionary:
	log_line(text)
	return {"ok": true, "reason": ""}


static func _guard(character: Character, needs_character := true) -> Dictionary:
	if not is_enabled():
		return _fail("el modo desarrollador está apagado")
	if needs_character and (character == null or not is_instance_valid(character) or character.data == null):
		return _fail("no hay personaje")
	return {}


# --- Registro corto ---

static func log_line(text: String) -> void:
	if not is_enabled():
		return
	_log.append("%s · %s" % [GameClock.time_text(), text])
	while _log.size() > LOG_MAX:
		_log.pop_front()
	EventBus.dev_log.emit(text)


static func recent_log() -> Array:
	return _log.duplicate()


# --- Forzar acciones y accidentes ---

## Que vaya hasta una celda, en ESE piso. Pulido 6B: si se pasa `point` (el lugar exacto que se
## tocó, en coordenadas de la casa), llega justo ahí y no al centro de la celda.
static func force_go(character: Character, level: int, cell: Vector2i, point := Vector3.INF) -> Dictionary:
	var blocked := _guard(character)
	if not blocked.is_empty():
		return blocked
	var spec := {"type": "go", "level": level, "cell": cell}
	if point != Vector3.INF:
		spec["point"] = point
	var result := character.force_action(spec)
	if result["ok"]:
		log_line("Forzado: ir hasta %s (atención %.2f)" % [_cell_text(level, cell), character.attention])
	return result


## Que use un objeto (la acción que ese objeto anuncia: dormir, cocinar…).
static func force_use(character: Character, level: int, key: String, action_id: String) -> Dictionary:
	var blocked := _guard(character)
	if not blocked.is_empty():
		return blocked
	var result := character.force_action({"type": "use", "level": level, "key": key, "action": action_id})
	if result["ok"]:
		log_line("Forzado: %s (atención %.2f)" % [str(Catalog.actions.get(action_id, {}).get("name", action_id)).to_lower(), character.attention])
	return result


## Accidente forzado ("fall", "trip" o "burn"). Si se pasa una celda, primero lleva al
## personaje ahí (así se puede probar «quemarse» junto a la cocina).
static func force_accident(character: Character, kind: String, level := -100, cell := Vector2i(-100000, -100000)) -> Dictionary:
	var blocked := _guard(character)
	if not blocked.is_empty():
		return blocked
	if HazardMap.accident_info(kind).is_empty():
		return _fail("accidente desconocido")
	if character.hurt:
		return _fail("ya está lastimado (espera a la ambulancia)")
	if level != -100 and not character.teleport_to(level, cell):
		return _fail("no se puede llevar al personaje ahí")
	if not character.force_accident(kind):
		return _fail("ahora no se puede (¿está trabajando?)")
	return _done("Forzado: %s (%s)" % [str(HazardMap.accident_info(kind).get("name", kind)).to_lower(), _cell_text(character.level, character.cell)])


# --- Atención ---

static func set_attention(character: Character, value: float) -> Dictionary:
	var blocked := _guard(character)
	if not blocked.is_empty():
		return blocked
	character.attention = value
	return _done("Atención: %.2f (%s)" % [character.attention, "esquiva peligros" if HazardMap.is_careful(character.attention) else "NO esquiva peligros"])


## «distraído», «desorbitado», «recién levantado»: solo ponen un valor de atención
## (data/hazards.json, attention.presets). El juego los usará después con sus reglas.
static func apply_attention_preset(character: Character, preset_id: String) -> Dictionary:
	var blocked := _guard(character)
	if not blocked.is_empty():
		return blocked
	for preset in HazardMap.presets():
		if preset["id"] == preset_id:
			character.attention = HazardMap.preset_value(preset_id)
			return _done("Estado «%s»: atención %.2f" % [str(preset["name"]).to_lower(), character.attention])
	return _fail("estado desconocido")


# --- Peligros ---

static func add_hazard(level: int, cell: Vector2i, kind: String) -> Dictionary:
	var blocked := _guard(null, false)
	if not blocked.is_empty():
		return blocked
	if not HazardMap.add(level, cell, kind):
		return _fail("tipo de peligro desconocido")
	return _done("Peligro «%s» en %s" % [str(HazardMap.kind_info(kind).get("name", kind)).to_lower(), _cell_text(level, cell)])


static func remove_hazard(level: int, cell: Vector2i) -> Dictionary:
	var blocked := _guard(null, false)
	if not blocked.is_empty():
		return blocked
	if not HazardMap.remove(level, cell):
		return _fail("ahí no había un peligro")
	return _done("Peligro quitado de %s" % _cell_text(level, cell))


static func clear_hazards() -> Dictionary:
	var blocked := _guard(null, false)
	if not blocked.is_empty():
		return blocked
	HazardMap.clear()
	return _done("Se quitaron todos los peligros")


# --- Estados (necesidades, lugar, IA, hora) ---

## Pone una necesidad directamente (comida, energía, limpieza, diversión). Respeta el
## mínimo del juego (CharacterData.NEED_FLOOR).
static func set_need(character: Character, need: String, value: float) -> Dictionary:
	var blocked := _guard(character)
	if not blocked.is_empty():
		return blocked
	if not need in CharacterData.NEEDS:
		return _fail("esa necesidad no existe")
	character.data.needs[need] = clampf(value, CharacterData.NEED_FLOOR, 100.0)
	return _done("%s = %d" % [CharacterData.NEED_NAMES[need], int(character.data.needs[need])])


static func teleport(character: Character, level: int, cell: Vector2i) -> Dictionary:
	var blocked := _guard(character)
	if not blocked.is_empty():
		return blocked
	if not character.teleport_to(level, cell):
		return _fail("no se puede estar parado ahí")
	return _done("Teletransportado a %s" % _cell_text(level, cell))


static func set_frozen(character: Character, on: bool) -> Dictionary:
	var blocked := _guard(character)
	if not blocked.is_empty():
		return blocked
	character.set_ai_frozen(on)
	return _done("IA %s" % ("congelada (solo cumple lo que se fuerza)" if on else "reanudada"))


## Cambia la hora del día: siempre hacia ADELANTE (la próxima vez que sea esa hora), para
## no confundir al reloj, los turnos ni las obras.
static func advance_to_hour(hour: int) -> Dictionary:
	var blocked := _guard(null, false)
	if not blocked.is_empty():
		return blocked
	var target := clampi(hour, 0, 23) * 60
	var now_in_day := int(GameClock.minutes) % 1440
	var delta := target - now_in_day
	if delta <= 0:
		delta += 1440
	GameClock.minutes += float(delta)
	return _done("Hora del día: %02d:00 (día %d)" % [clampi(hour, 0, 23), GameClock.day()])


# --- Qué se tocó en el mundo ---

## Qué hay bajo el dedo: un mueble ("object"), una puerta ("door") o el suelo ("floor").
## Devuelve {kind, level, cell, name, ...} o {} si no tocó nada de la casa.
static func pick_target(view: HouseView, nav: HouseNav, camera: Camera3D, screen_pos: Vector2) -> Dictionary:
	if view == null or camera == null or view.house == null:
		return {}
	var house := view.house
	var origin := view.to_local(camera.project_ray_origin(screen_pos))
	var direction := view.global_transform.basis.inverse() * camera.project_ray_normal(screen_pos)
	# 1) Un mueble (de arriba hacia abajo: lo de arriba tapa lo de abajo).
	for level in range(view.top_visible_level, -1, -1):
		var key := view.pick_object(origin, direction, level)
		if key != "":
			var piece: Dictionary = house.get_piece(level, "objects", key)
			var item := Catalog.get_item(piece["item"])
			var spots: Array = nav.object_spots(level, key) if nav != null else []
			return {"kind": "object", "level": level, "key": key, "item": piece["item"], "item_kind": item.get("kind", ""),
				"name": item.get("name", "Objeto"), "cell": spots[0] if not spots.is_empty() else HouseData.object_anchor(piece)}
	# 2) Una puerta (una caja fina sobre su borde).
	for level in range(view.top_visible_level, -1, -1):
		for edge in house.get_layer(level, "walls"):
			var wall: Dictionary = house.get_piece(level, "walls", edge)
			if Catalog.get_item(wall.get("opening", "")).get("kind", "") != "door":
				continue
			var center := HouseGrid.edge_center(edge)
			var size := Vector3(1.0, 2.0, 0.4) if HouseGrid.is_edge_horizontal(edge) else Vector3(0.4, 2.0, 1.0)
			var box := AABB(Vector3(center.x, HouseGrid.level_y(level), center.z) - Vector3(size.x / 2.0, 0.0, size.z / 2.0), size)
			if box.intersects_ray(origin, direction) != null:
				var sides := HouseGrid.edge_cells(edge)
				var side: Vector2i = sides[0]
				for candidate in sides:
					if nav != null and nav.is_walkable(level, candidate):
						side = candidate
						break
				return {"kind": "door", "level": level, "edge": edge, "name": "Puerta", "cell": side}
	return pick_floor(view, camera, screen_pos)


## Solo el suelo bajo el dedo: el primer piso (de arriba hacia abajo) que tiene piso en
## esa celda, o el suelo de afuera. {kind: "floor", level, cell, name, hazard} o {}.
static func pick_floor(view: HouseView, camera: Camera3D, screen_pos: Vector2) -> Dictionary:
	if view == null or camera == null or view.house == null:
		return {}
	var origin := view.to_local(camera.project_ray_origin(screen_pos))
	var direction := view.global_transform.basis.inverse() * camera.project_ray_normal(screen_pos)
	if absf(direction.y) < 0.0001:
		return {}
	for level in range(view.top_visible_level, -1, -1):
		var t := (HouseGrid.level_y(level) - origin.y) / direction.y
		if t <= 0.0:
			continue
		var point := origin + direction * t
		var cell := Vector2i(floori(point.x), floori(point.z))
		if not HouseGrid.is_cell_in_lot(cell):
			continue
		if level == 0 or view.house.has_piece(level, "floors", HouseGrid.cell_key(cell)):
			return {"kind": "floor", "level": level, "cell": cell, "name": "Suelo", "point": point,
				"hazard": HazardMap.kind_at(level, cell)}
	return {}


static func _cell_text(level: int, cell: Vector2i) -> String:
	return "%s (%d, %d)" % [HouseGrid.level_name(level).to_lower(), cell.x, cell.y]
