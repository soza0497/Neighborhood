class_name IslandLod
extends RefCounted
## Decide el nivel de detalle de cada lote según la distancia a la cámara (Isla 1A).
##
##   LOD 0 = tu parcela completa (HouseView, con interior)
##   LOD 1 = vecinos cercanos, solo exterior (desde la ficha exterior)
##   LOD 2 = una calle o zona: casas como bloques, mallas agrupadas
##   LOD 3 = nada por lote; de muy lejos se ve el mapa estilizado de toda la isla
##
## Para que no parpadee al estar justo en el límite hay HISTÉRESIS: un lote sube de
## nivel (se aleja) cuando pasa de distancia × (1 + h), y baja de nivel (se acerca)
## solo cuando está bajo distancia × (1 − h). Las distancias salen de data/island.json.
## El mapa de toda la isla usa dos distancias distintas para entrar y para salir.

## Metros (de la cámara al centro del lote) en que termina el LOD 0, 1 y 2.
var distances: Array[float] = [70.0, 230.0, 520.0]
var hysteresis := 0.12
## Distancia de la cámara al centro de la isla desde la que se muestra el mapa, y a la que se sale.
var map_enter := 1000.0
var map_exit := 880.0
## Cuántos lotes como máximo pueden estar en LOD 0 a la vez (los más cercanos).
var lod0_max := 3

## Nivel actual de cada lote: id → 0..3.
var levels: Dictionary = {}
var map_mode := false


## Arma el objeto con los números de data/island.json (sección "lod").
static func from_data() -> IslandLod:
	var lod := IslandLod.new()
	var cfg := IslandData.lod_config()
	var list: Array = cfg.get("distances", [70.0, 230.0, 520.0])
	lod.distances = [float(list[0]), float(list[1]), float(list[2])]
	lod.hysteresis = float(cfg.get("hysteresis", 0.12))
	var radius := IslandData.island_radius()
	lod.map_enter = radius * float(cfg.get("map_enter_radii", 2.9))
	lod.map_exit = radius * float(cfg.get("map_exit_radii", 2.5))
	lod.lod0_max = int(cfg.get("lod0_max", 3))
	return lod


## Nivel "en seco" (sin histéresis) para una distancia.
func raw_level(distance: float) -> int:
	var level := 0
	for limit in distances:
		if distance >= limit:
			level += 1
	return level


## Nivel de un lote a `distance` metros, sabiendo el que tenía antes (-1 = ninguno).
func level_for(distance: float, previous: int) -> int:
	if previous < 0:
		return raw_level(distance)
	var level := previous
	# Se aleja: sube de nivel solo si pasa el límite con margen.
	while level < distances.size() and distance > distances[level] * (1.0 + hysteresis):
		level += 1
	# Se acerca: baja de nivel solo si entra al límite con margen.
	while level > 0 and distance < distances[level - 1] * (1.0 - hysteresis):
		level -= 1
	return level


## ¿Se muestra el mapa de toda la isla? Entra pasado `map_enter` y sale bajo `map_exit`.
func map_for(distance_to_island: float, previous: bool) -> bool:
	if previous:
		return distance_to_island > map_exit
	return distance_to_island > map_enter


## Actualiza todos los lotes. `centers` = id → centro (Vector3). Devuelve los cambios:
## id → [nivel anterior, nivel nuevo]. Con el mapa activo todos pasan a LOD 3.
func update(camera_position: Vector3, centers: Dictionary) -> Dictionary:
	var changes: Dictionary = {}
	map_mode = map_for(camera_position.length(), map_mode)
	var lod0_candidates: Array = []
	var wanted: Dictionary = {}
	for id in centers:
		var d := camera_position.distance_to(centers[id])
		var level := level_for(d, int(levels.get(id, -1)))
		if map_mode:
			level = distances.size()
		wanted[id] = level
		if level == 0:
			lod0_candidates.append([d, id])
	# Solo los más cercanos se quedan en LOD 0; el resto baja a LOD 1.
	if lod0_candidates.size() > lod0_max:
		lod0_candidates.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		for i in range(lod0_max, lod0_candidates.size()):
			wanted[lod0_candidates[i][1]] = 1
	for id in wanted:
		var previous := int(levels.get(id, -1))
		if previous != int(wanted[id]):
			changes[id] = [previous, int(wanted[id])]
		levels[id] = wanted[id]
	return changes


func reset() -> void:
	levels.clear()
	map_mode = false
