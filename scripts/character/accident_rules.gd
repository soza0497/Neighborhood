class_name AccidentRules
extends RefCounted
## Accidentes por elemento (Pulido 6B): las reglas están en data/accidents.json, no en el código.
##
## Un elemento del catálogo (puerta, cocina…) o un tipo de peligro (charco…) lista los ids de
## sus reglas. Cada regla tiene un disparador (`on`), condiciones (`when`), el accidente y la
## probabilidad. Acá solo se EVALÚAN; quien decide qué hacer con el resultado es el personaje.
##
## El contexto (`ctx`) que se pasa: {house, level, cell, edge, attention, action}.

const DATA_PATH := "res://data/accidents.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if parsed is Dictionary:
			_data = parsed
		else:
			push_error("No se pudo leer %s" % DATA_PATH)
			_data = {"rules": {}}
	return _data


static func rule(id: String) -> Dictionary:
	return data().get("rules", {}).get(id, {})


static func rule_ids() -> Array:
	return data().get("rules", {}).keys()


## Ids de las reglas que declara un objeto del catálogo.
static func rules_for_item(item_id: String) -> Array:
	return Catalog.get_item(item_id).get("accidents", [])


## Ids de las reglas que declara un tipo de peligro (charco, calor, desnivel).
static func rules_for_hazard(kind: String) -> Array:
	return HazardMap.kind_info(kind).get("rules", [])


## La primera regla de `rule_ids` con ese disparador cuyas condiciones se cumplen.
## Devuelve {id, rule} o {} si ninguna.
static func first_match(rule_ids_to_check: Array, trigger: String, ctx: Dictionary) -> Dictionary:
	for raw_id in rule_ids_to_check:
		var id := str(raw_id)
		var candidate := rule(id)
		if candidate.is_empty() or str(candidate.get("on", "")) != trigger:
			continue
		if conditions_met(candidate, ctx):
			return {"id": id, "rule": candidate}
	return {}


## ¿Se cumplen TODAS las condiciones de la regla?
static func conditions_met(candidate: Dictionary, ctx: Dictionary) -> bool:
	var when: Dictionary = candidate.get("when", {})
	for condition in when:
		if not _condition(str(condition), when[condition], ctx):
			return false
	return true


## ¿Le toca el accidente esta vez? (la probabilidad `chance` de la regla)
static func rolls(candidate: Dictionary, rng: RandomNumberGenerator) -> bool:
	var chance := clampf(float(candidate.get("chance", 1.0)), 0.0, 1.0)
	return chance >= 1.0 or rng.randf() < chance


static func _condition(name: String, expected: Variant, ctx: Dictionary) -> bool:
	match name:
		"floor_slippery":
			return _floor_slippery(ctx) == bool(expected)
		"door_front_inside_floor":
			return _door_front_inside_floor(ctx) == bool(expected)
		"void_other_side":
			return _void_other_side(ctx) == bool(expected)
		"floor_sides":
			return _floor_sides(ctx) == int(expected)
		"attention_below":
			return float(ctx.get("attention", 1.0)) < float(expected)
		"action":
			return str(ctx.get("action", "")) == str(expected)
		"level_above":
			return int(ctx.get("level", 0)) > int(expected)
	return false  # Condición desconocida: no se cumple.


# --- Condiciones sobre la casa ---

static func _house(ctx: Dictionary) -> HouseData:
	return ctx.get("house") as HouseData


static func _has_floor(ctx: Dictionary, cell: Vector2i) -> bool:
	var house := _house(ctx)
	return house != null and house.has_piece(int(ctx.get("level", 0)), "floors", HouseGrid.cell_key(cell))


static func _floor_slippery(ctx: Dictionary) -> bool:
	var house := _house(ctx)
	if house == null or not ctx.has("cell"):
		return false
	var piece: Variant = house.get_piece(int(ctx.get("level", 0)), "floors", HouseGrid.cell_key(ctx["cell"]))
	return piece != null and bool(Catalog.get_item(str(piece.get("item", ""))).get("slippery", false))


## Cuántos de los dos lados del borde `edge` tienen piso.
static func _floor_sides(ctx: Dictionary) -> int:
	if not ctx.has("edge"):
		return -1
	var count := 0
	for side in HouseGrid.edge_cells(str(ctx["edge"])):
		if _has_floor(ctx, side):
			count += 1
	return count


## Piso alto con piso de un solo lado de la puerta: del otro lado hay vacío.
static func _void_other_side(ctx: Dictionary) -> bool:
	return int(ctx.get("level", 0)) > 0 and _floor_sides(ctx) == 1


## La celda está pegada a una puerta cuyo otro lado tiene piso de adentro.
static func _door_front_inside_floor(ctx: Dictionary) -> bool:
	var house := _house(ctx)
	if house == null or not ctx.has("cell"):
		return false
	var cell: Vector2i = ctx["cell"]
	var level := int(ctx.get("level", 0))
	for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var other: Vector2i = cell + step
		var edge := shared_edge(cell, other)
		var wall: Variant = house.get_piece(level, "walls", edge)
		if wall == null or Catalog.get_item(str(wall.get("opening", ""))).get("kind", "") != "door":
			continue
		if house.has_piece(level, "floors", HouseGrid.cell_key(other)):
			return true
	return false


## El borde que comparten dos celdas vecinas (la misma cuenta que usa HouseNav).
static func shared_edge(a: Vector2i, b: Vector2i) -> String:
	if a.x == b.x:
		return HouseGrid.edge_key(Vector2i(a.x, maxi(a.y, b.y)), true)
	return HouseGrid.edge_key(Vector2i(maxi(a.x, b.x), a.y), false)
