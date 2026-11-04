class_name IslandWorld
extends Node3D
## La isla viva (Isla 1A): arma el escenario (IslandBuilder), crea las casas simuladas y
## cambia el nivel de detalle de cada lote según la cámara (IslandLod).
##
## Qué existe en cada nivel (para cada casa):
##   LOD 0  HouseView completa (ExteriorLod0)             → se arma al acercarse, se libera al alejarse
##   LOD 1  fachada desde la ficha (ExteriorLod1)         → una malla por casa
##   LOD 2  bloques agrupados por zona (ExteriorLod2)     → una malla por zona (cluster del lote)
##   LOD 3  nada por lote; de muy lejos, el mapa (IslandMapLod3)
## Streaming por radio: lo que queda más lejos que el LOD 2 se libera; la vegetación va en
## trozos que se muestran solo dentro de `vegetation_range`.
##
## Cambios de nivel con presupuesto: como mucho `builds_per_frame` armados por cuadro,
## para que acercarse no trabe el teléfono.

signal level_changed(lot_id: String, from_level: int, to_level: int)

## Una casa simulada: su lote, su ficha y lo que está armado ahora.
class Slot:
	var lot: Dictionary = {}
	var id := ""
	var cluster := ""
	var card: ExteriorCard
	var xf := Transform3D.IDENTITY
	var center := Vector3.ZERO
	var shown := -1      # Nivel que se ve ahora (-1 = todavía nada).
	var target := 3      # Nivel al que tiene que llegar.
	var lod0: Node3D
	var lod1: MeshInstance3D

var lod: IslandLod
var lots: Array = []
var camera: Camera3D
## -1 = automático por distancia; 0, 1, 2 = ese nivel en todo; 3 = solo el mapa.
var forced_level := -1
## Cuánto tardó armar la isla (milisegundos): lo muestra la demo.
var setup_ms := 0
var tree_count := 0

var _slots: Dictionary = {}
var _clusters: Dictionary = {}
var _houses: Node3D
var _detail: Node3D
var _scenery: Node3D
var _map: MeshInstance3D
var _smoke: IslandSmoke
var _chunks: Array = []
var _chunk_visible: Array[bool] = []
var _timer := 0.0
var _map_on := false
var _builds_left := 0


## Arma la isla con esos lotes. `camera` es la que decide los niveles.
func setup(new_camera: Camera3D, lot_list: Array, options := {}) -> void:
	var started := Time.get_ticks_msec()
	camera = new_camera
	lots = lot_list
	lod = IslandLod.from_data()
	var built := IslandBuilder.build(lots, options)
	_scenery = built["scenery"]
	_detail = built["detail"]
	_smoke = built["smoke"]
	_chunks = built["tree_chunks"]
	tree_count = int(built["tree_count"])
	_chunk_visible.clear()
	for chunk in _chunks:
		_chunk_visible.append(true)
	add_child(_scenery)
	add_child(_detail)
	_houses = Node3D.new()
	_houses.name = "Houses"
	add_child(_houses)
	_map = IslandMapLod3.build(lots)
	_map.visible = false
	add_child(_map)
	for l in lots:
		var state := str(l.get("state", "npc"))
		if state != "npc" and state != "player":
			continue
		var slot := Slot.new()
		slot.lot = l
		slot.id = str(l["id"])
		slot.cluster = str(l.get("cluster", "all"))
		slot.card = IslandFakeHouses.card_for(l)
		slot.xf = IslandFakeHouses.house_transform(l, slot.card)
		slot.center = IslandData.lot_center(l)
		_slots[slot.id] = slot
	setup_ms = Time.get_ticks_msec() - started


func slot_count() -> int:
	return _slots.size()


## Cuántas casas se ven ahora en cada nivel: [LOD0, LOD1, LOD2, LOD3].
func shown_counts() -> Array[int]:
	var counts: Array[int] = [0, 0, 0, 0]
	for id in _slots:
		var slot: Slot = _slots[id]
		if slot.shown >= 0:
			counts[clampi(slot.shown, 0, 3)] += 1
	return counts


## Cuántas casas esperan para cambiar de nivel.
func pending_count() -> int:
	var count := 0
	for id in _slots:
		var slot: Slot = _slots[id]
		if slot.shown != slot.target:
			count += 1
	return count


func map_visible() -> bool:
	return _map_on


## Pone un nivel en todos los lotes (-1 = automático).
func set_forced_level(level: int) -> void:
	forced_level = clampi(level, -1, 3)
	refresh()


func set_smoke_visible(on: bool) -> void:
	if _smoke != null:
		_smoke.visible = on


func set_outline(on: bool) -> void:
	Style.set_outline(on)
	IslandMaterials.sync_outline()


## Nodos principales (para que la demo cuente cuadros y triángulos).
func detail_root() -> Node3D:
	return _detail


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= float(IslandData.lod_config().get("update_interval", 0.15)):
		_timer = 0.0
		refresh()
	apply_pending()


## Recalcula el nivel buscado de cada lote y el estado del mapa.
func refresh() -> void:
	if camera == null or lod == null:
		return
	var cam_pos := camera.global_position
	var centers: Dictionary = {}
	for id in _slots:
		centers[id] = (_slots[id] as Slot).center
	lod.update(cam_pos, centers)
	var map_target := lod.map_mode
	if forced_level >= 0:
		map_target = forced_level == 3
		for id in _slots:
			(_slots[id] as Slot).target = forced_level
	else:
		for id in _slots:
			(_slots[id] as Slot).target = int(lod.levels.get(id, 3))
	_set_map(map_target)
	_update_chunks(cam_pos)


## Arma o desarma lo que falta, respetando el presupuesto de armados por cuadro.
## Devuelve true si no queda nada pendiente.
func apply_pending(unlimited := false) -> bool:
	_builds_left = 1000000 if unlimited else int(IslandData.lod_config().get("builds_per_frame", 2))
	var all_done := true
	for id in _slots:
		var slot: Slot = _slots[id]
		if slot.shown == slot.target:
			continue
		if not _apply_level(slot):
			all_done = false
	_flush_clusters()
	return all_done


## Lleva un lote a su nivel buscado. false = no hubo presupuesto de armado.
func _apply_level(slot: Slot) -> bool:
	var target := slot.target
	var before := slot.shown
	match target:
		0:
			if slot.lod0 == null:
				if _builds_left <= 0:
					return false
				_builds_left -= 1
				slot.lod0 = ExteriorLod0.build(IslandFakeHouses.house_for(slot.lot), slot.card, _houses)
				slot.lod0.transform = slot.xf
			_free_lod1(slot)
			_set_cluster_member(slot, false)
		1:
			if slot.lod1 == null:
				if _builds_left <= 0:
					return false
				_builds_left -= 1
				slot.lod1 = ExteriorLod1.build(slot.card, 1 <= int(IslandData.lod_config().get("outline_max_level", 1)))
				slot.lod1.transform = slot.xf
				_houses.add_child(slot.lod1)
			slot.lod1.visible = true
			_free_lod0(slot)
			_set_cluster_member(slot, false)
		2:
			_free_lod0(slot)
			if slot.lod1 != null:
				slot.lod1.visible = false   # Queda guardada: volver al LOD 1 es gratis.
			_set_cluster_member(slot, true)
		_:
			# LOD 3: se libera todo lo de esta casa (streaming por radio).
			_free_lod0(slot)
			_free_lod1(slot)
			_set_cluster_member(slot, false)
	slot.shown = target
	level_changed.emit(slot.id, before, target)
	return true


func _free_lod0(slot: Slot) -> void:
	if slot.lod0 != null:
		_drop(slot.lod0)
		slot.lod0 = null


func _free_lod1(slot: Slot) -> void:
	if slot.lod1 != null:
		_drop(slot.lod1)
		slot.lod1 = null


## Saca el nodo del árbol enseguida (así no se cuenta ni se dibuja) y lo libera.
func _drop(node: Node) -> void:
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.queue_free()


func _set_cluster_member(slot: Slot, member: bool) -> void:
	if not _clusters.has(slot.cluster):
		_clusters[slot.cluster] = {"members": {}, "node": null, "dirty": false}
	var cluster: Dictionary = _clusters[slot.cluster]
	var members: Dictionary = cluster["members"]
	if members.has(slot.id) != member:
		if member:
			members[slot.id] = true
		else:
			members.erase(slot.id)
		cluster["dirty"] = true


## Rearma la malla de cada zona cuyo grupo de casas cambió.
func _flush_clusters() -> void:
	for cluster_id in _clusters:
		var cluster: Dictionary = _clusters[cluster_id]
		if not bool(cluster["dirty"]):
			continue
		cluster["dirty"] = false
		if cluster["node"] != null:
			_drop(cluster["node"] as Node)
			cluster["node"] = null
		var entries: Array = []
		for member_id in cluster["members"]:
			var slot: Slot = _slots[member_id]
			entries.append({"card": slot.card, "xf": slot.xf})
		if entries.is_empty():
			continue
		var node := ExteriorLod2.build_cluster(entries, "Lod2_" + str(cluster_id))
		if node != null:
			_houses.add_child(node)
			cluster["node"] = node


## Muestra el mapa (y esconde el detalle de la isla) o al revés.
func _set_map(on: bool) -> void:
	if on == _map_on:
		return
	_map_on = on
	_map.visible = on
	_detail.visible = not on
	_houses.visible = not on


## Vegetación por trozos: solo dentro del radio, con histéresis.
func _update_chunks(cam_pos: Vector3) -> void:
	var cfg := IslandData.lod_config()
	var range_limit := float(cfg.get("vegetation_range", 320.0))
	var h := float(cfg.get("vegetation_hysteresis", 0.15))
	var chunk_size := float(cfg.get("vegetation_chunk", 140.0))
	for i in _chunks.size():
		var center: Vector3 = _chunks[i]["center"]
		# Distancia al borde cercano del trozo (aprox.), en el plano.
		var d := Vector2(cam_pos.x - center.x, cam_pos.z - center.z).length() - chunk_size * 0.7
		var now_visible := _chunk_visible[i]
		if now_visible and d > range_limit * (1.0 + h):
			now_visible = false
		elif not now_visible and d < range_limit * (1.0 - h):
			now_visible = true
		_chunk_visible[i] = now_visible
		(_chunks[i]["node"] as Node3D).visible = now_visible


## Cuántos trozos de vegetación se ven.
func visible_chunk_count() -> int:
	var count := 0
	for v in _chunk_visible:
		if v:
			count += 1
	return count


func chunk_count() -> int:
	return _chunks.size()
