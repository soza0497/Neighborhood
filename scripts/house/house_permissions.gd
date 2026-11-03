class_name HousePermissions
## Permisos de la casa compartida (Fase 5): qué cambio es "menor" y cuál es
## "estructural". Es copia exacta de write_kind / change_kind de
## server/nakama/modules/neighborhood_house.lua (el que decide es el
## servidor; el teléfono lo usa para avisar ANTES: "Pedir permiso").
##
##   Menor (al instante, con aviso y "Deshacer" para la pareja): mover, girar
##   o pintar un mueble, pintar paredes y pisos, unir/separar ventanas, poner
##   un mueble nuevo.
##   Estructural (pide aprobación): cimientos, pisos, paredes, puertas,
##   ventanas, techos, escaleras, y quitar (vender) cualquier cosa.

## Campos que no cambian qué es la pieza.
const COSMETIC_FIELDS := ["color", "separate", "ready_at"]


static func is_minor_write(house: HouseData, w: Dictionary) -> bool:
	var old: Variant = house.get_piece(w["level"], w["layer"], w["key"])
	var new: Variant = w["value"]
	if new == null:
		return old == null
	if old != null and old.get("item", "") == new.get("item", "") and _only_cosmetic(old, new):
		return true
	if w["layer"] == "objects":
		var item := Catalog.get_item(new.get("item", ""))
		return item.get("kind", "") == "furniture" and (old == null or old.get("item", "") == new.get("item", ""))
	return false


## Un cambio entero es menor solo si todas sus escrituras lo son.
static func is_minor(house: HouseData, writes: Array) -> bool:
	for w in writes:
		if not is_minor_write(house, w):
			return false
	return true


static func _only_cosmetic(old: Dictionary, new: Dictionary) -> bool:
	for key in new:
		if not key in COSMETIC_FIELDS and (not old.has(key) or not _same(old[key], new[key])):
			return false
	for key in old:
		if not key in COSMETIC_FIELDS and not new.has(key):
			return false
	return true


## Compara dos valores como texto JSON (los números pueden venir como
## enteros o como decimales).
static func _same(a: Variant, b: Variant) -> bool:
	return JSON.stringify(JSON.parse_string(JSON.stringify(a))) == JSON.stringify(JSON.parse_string(JSON.stringify(b)))
