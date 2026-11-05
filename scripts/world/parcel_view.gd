class_name ParcelView
extends Node3D
## Dibuja los obstáculos de la parcela (Pulido 2C): árboles, rocas, un laguito,
## tocones y maleza. Va como hijo de House (coordenadas = celdas de la casa).
##
## Árboles, maleza, tocones y rocas van con MultiMesh (cientos de obstáculos
## en pocas llamadas de dibujo: pensado para un Android de gama media); el
## laguito es un disco plano. Lo que se limpió desaparece. Todo con el estilo
## toon y los colores de la paleta (data/style.json).
##
## También sabe "agarrar" un obstáculo con un toque (pick).

## Alto aproximado de cada tipo (para tocarlo con el dedo).
const HEIGHTS := {"tree": 3.0, "rock": 1.3, "bush": 0.9, "stump": 0.55, "lake": 0.2}

var _nodes: Array[Node] = []
var _hash_seed := 0
## Pulido 6B: obstáculos elegidos para llamar al servicio (se marcan con un aro).
var _marked: Dictionary = {}
var _mark_nodes: Array[Node] = []


func _ready() -> void:
	Parcel.changed.connect(rebuild)
	rebuild()


## Borra y vuelve a dibujar todo lo que queda sin limpiar.
func rebuild() -> void:
	for node in _nodes:
		node.queue_free()
	_nodes.clear()
	var by_kind := {}
	var bounds := Parcel.zone_bounds()
	for o in Parcel.obstacles:
		if Parcel.cleared.has(o["id"]):
			continue
		# Pulido 3A: pasada la valla de los costados ya es el terreno del vecino.
		if o["x"] + o["w"] <= bounds.position.x or o["x"] >= bounds.end.x:
			continue
		if not by_kind.has(o["kind"]):
			by_kind[o["kind"]] = []
		by_kind[o["kind"]].append(o)
	_trees(by_kind.get("tree", []))
	_blobs("bush", by_kind.get("bush", []), SphereMesh.new(), Style.color("bush"), Vector3(0.5, 0.34, 0.5), 0.34)
	_blobs("stump", by_kind.get("stump", []), _cylinder(0.32, 0.36), Style.color("stump"), Vector3.ONE, 0.18)
	_blobs("rock", by_kind.get("rock", []), SphereMesh.new(), Style.color("rock"), Vector3(1.0, 0.7, 0.9), 0.5)
	_lakes(by_kind.get("lake", []))


func _cylinder(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.9
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 1
	return mesh


## Un número entre 0 y 1 que siempre es el mismo para un obstáculo (para
## variar tamaños y giros sin azar nuevo en cada dibujo).
func _jitter(o: Dictionary, salt: int) -> float:
	var h := hash("%s:%d" % [o["id"], salt])
	return float(absi(h) % 1000) / 1000.0


func _multimesh(node_name: String, mesh: Mesh, count: int, color: Color) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = count
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multi
	instance.material_override = Style.toon_material(color)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	_nodes.append(instance)
	return instance


func _trees(list: Array) -> void:
	if list.is_empty():
		return
	var trunk_mesh := _cylinder(0.2, 1.3)
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 0.95
	crown_mesh.height = 1.9
	crown_mesh.radial_segments = 8
	crown_mesh.rings = 4
	var trunks := _multimesh("ObstacleTrunks", trunk_mesh, list.size(), Style.color("trunk"))
	var crowns := _multimesh("ObstacleCrowns", crown_mesh, list.size(), Style.color("leaf"))
	for i in list.size():
		var o: Dictionary = list[i]
		var s := 0.85 + _jitter(o, 1) * 0.5
		var base := Vector3(o["x"] + 0.5 + (_jitter(o, 2) - 0.5) * 0.3, 0.0, o["z"] + 0.5 + (_jitter(o, 3) - 0.5) * 0.3)
		var basis := Basis().scaled(Vector3.ONE * s)
		trunks.multimesh.set_instance_transform(i, Transform3D(basis, base + Vector3(0, 0.65 * s, 0)))
		crowns.multimesh.set_instance_transform(i, Transform3D(basis, base + Vector3(0, 1.3 * s + 0.65 * s, 0)))


func _blobs(kind: String, list: Array, mesh: Mesh, color: Color, shape: Vector3, lift: float) -> void:
	if list.is_empty():
		return
	if mesh is SphereMesh:
		mesh.radial_segments = 8
		mesh.rings = 4
	var blobs := _multimesh("Obstacle_" + kind, mesh, list.size(), color)
	for i in list.size():
		var o: Dictionary = list[i]
		var s := 0.8 + _jitter(o, 1) * 0.45
		var size := Vector3(o["w"], 1.0, o["d"]) if kind == "rock" else Vector3.ONE
		var basis := Basis().rotated(Vector3.UP, _jitter(o, 4) * TAU).scaled(Vector3(shape.x * s * size.x, shape.y * s, shape.z * s * size.z))
		var center := Vector3(o["x"] + o["w"] / 2.0, lift * s, o["z"] + o["d"] / 2.0)
		blobs.multimesh.set_instance_transform(i, Transform3D(basis, center))


func _lakes(list: Array) -> void:
	for o in list:
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.5
		mesh.bottom_radius = 0.5
		mesh.height = 0.08
		mesh.radial_segments = 20
		mesh.rings = 1
		var instance := MeshInstance3D.new()
		instance.name = "Lake_" + o["id"]
		instance.mesh = mesh
		instance.scale = Vector3(o["w"], 1.0, o["d"])
		instance.position = Vector3(o["x"] + o["w"] / 2.0, 0.04, o["z"] + o["d"] / 2.0)
		instance.material_override = Style.toon_material(Style.color("water"))
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)
		_nodes.append(instance)


## El obstáculo (sin limpiar) que toca un rayo en coordenadas de la casa
## ("" si ninguno). Se prueba contra la caja de cada uno: el más cercano gana.
func pick(origin: Vector3, direction: Vector3) -> String:
	var best := ""
	var best_distance := INF
	for o in Parcel.obstacles:
		if Parcel.cleared.has(o["id"]):
			continue
		var height: float = HEIGHTS.get(o["kind"], 1.0)
		var box := AABB(Vector3(o["x"], 0.0, o["z"]), Vector3(o["w"], height, o["d"]))
		var hit: Variant = box.intersects_ray(origin, direction)
		if hit != null and origin.distance_to(hit) < best_distance:
			best_distance = origin.distance_to(hit)
			best = o["id"]
	return best


# --- Pulido 6B: obstáculos elegidos y obstáculos que se van ---

## Marca con un aro los obstáculos elegidos en «Eliminar» (lista de ids).
func set_marked(ids: Array) -> void:
	_marked.clear()
	for id in ids:
		_marked[str(id)] = true
	for node in _mark_nodes:
		node.queue_free()
	_mark_nodes.clear()
	for id in _marked:
		var o := Parcel.obstacle(id)
		if o.is_empty() or Parcel.cleared.has(id):
			continue
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.5
		mesh.bottom_radius = 0.5
		mesh.height = 0.05
		mesh.radial_segments = 20
		mesh.rings = 1
		var ring := MeshInstance3D.new()
		ring.name = "Mark_" + id
		ring.mesh = mesh
		ring.scale = Vector3(maxf(float(o["w"]), 1.0) * 1.15, 1.0, maxf(float(o["d"]), 1.0) * 1.15)
		ring.position = Vector3(o["x"] + o["w"] / 2.0, 0.07, o["z"] + o["d"] / 2.0)
		ring.material_override = HousePieces.transparent_material(Color(1.0, 0.45, 0.35, 0.65))
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
		_mark_nodes.append(ring)


func marked_ids() -> Array:
	return _marked.keys()


## Cuántos aros hay dibujados (para pruebas).
func mark_count() -> int:
	return _mark_nodes.size()


## Un obstáculo que acaba de limpiarse se va con una animación (el árbol cae y rueda un poco,
## la roca se achica, el laguito se seca…). Se llama justo cuando termina el corte: el dibujo
## "de verdad" ya desapareció (Parcel.finish) y esta copia hace el final. Devuelve el nodo
## animado (para pruebas) o null.
func play_removal(o: Dictionary) -> Node3D:
	if o.is_empty():
		return null
	var cfg: Dictionary = VehicleSpace.data().get("removal", {})
	var ghost := Node3D.new()
	ghost.name = "Removal_" + str(o["id"])
	ghost.position = Vector3(o["x"] + o["w"] / 2.0, 0.0, o["z"] + o["d"] / 2.0)
	add_child(ghost)
	var kind := str(o["kind"])
	var color := Color(1, 1, 1, 0.85)
	match kind:
		"tree":
			_animate_tree_fall(ghost, o, cfg)
			color = Color(0.85, 0.8, 0.7, 0.8)
		"lake":
			var disc := CylinderMesh.new()
			disc.top_radius = 0.5
			disc.bottom_radius = 0.5
			disc.height = 0.08
			disc.radial_segments = 20
			disc.rings = 1
			var water := MeshInstance3D.new()
			water.mesh = disc
			water.scale = Vector3(o["w"], 1.0, o["d"])
			water.position.y = 0.04
			water.material_override = Style.toon_material(Style.color("water"))
			ghost.add_child(water)
			var tween := create_tween()
			tween.tween_property(ghost, "scale", Vector3(0.05, 0.05, 0.05), float(cfg.get("fade_seconds", 0.5)) * 2.0)
			tween.tween_callback(ghost.queue_free)
			color = Color(0.6, 0.8, 1.0, 0.8)
		_:
			var mesh: Mesh = SphereMesh.new()
			var shape := Vector3(0.5, 0.34, 0.5)
			var base_color := Style.color("bush")
			var lift := 0.34
			if kind == "rock":
				shape = Vector3(float(o["w"]) * 0.5, 0.7, float(o["d"]) * 0.45)
				base_color = Style.color("rock")
				lift = 0.5
			elif kind == "stump":
				mesh = _cylinder(0.32, 0.36)
				shape = Vector3.ONE
				base_color = Style.color("stump")
				lift = 0.18
			var blob := MeshInstance3D.new()
			blob.mesh = mesh
			blob.scale = shape * 2.0 if mesh is SphereMesh else shape
			blob.position.y = lift
			blob.material_override = Style.toon_material(base_color)
			ghost.add_child(blob)
			var shrink := create_tween()
			shrink.tween_property(ghost, "scale", Vector3(1.1, 0.8, 1.1), 0.15)
			shrink.tween_property(ghost, "scale", Vector3(0.05, 0.05, 0.05), float(cfg.get("fade_seconds", 0.5)))
			shrink.tween_callback(ghost.queue_free)
			color = Color(0.8, 0.8, 0.75, 0.8)
	Fx.puff(self, ghost.position + Vector3(0, 0.4, 0), 10, color)
	return ghost


## El árbol: cae hacia un lado (siempre el mismo para el mismo árbol), rebota, rueda un poco y
## se achica hasta desaparecer.
func _animate_tree_fall(ghost: Node3D, o: Dictionary, cfg: Dictionary) -> void:
	var s := 0.85 + _jitter(o, 1) * 0.5
	var pivot := Node3D.new()
	pivot.name = "TreePivot"
	pivot.scale = Vector3.ONE * s
	ghost.add_child(pivot)
	var trunk := MeshInstance3D.new()
	trunk.mesh = _cylinder(0.2, 1.3)
	trunk.position.y = 0.65
	trunk.material_override = Style.toon_material(Style.color("trunk"))
	pivot.add_child(trunk)
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 0.95
	crown_mesh.height = 1.9
	crown_mesh.radial_segments = 8
	crown_mesh.rings = 4
	var crown := MeshInstance3D.new()
	crown.mesh = crown_mesh
	crown.position.y = 1.95
	crown.material_override = Style.toon_material(Style.color("leaf"))
	pivot.add_child(crown)
	# Hacia dónde cae: un ángulo fijo por árbol.
	var heading := _jitter(o, 5) * TAU
	var fall_axis := Vector3(cos(heading), 0.0, sin(heading))  # Dirección horizontal de la caída.
	var tilt_axis := Vector3.UP.cross(fall_axis).normalized()  # Eje alrededor del que se vuelca.
	var fall_seconds := float(cfg.get("tree_fall_seconds", 0.9))
	var roll_seconds := float(cfg.get("tree_roll_seconds", 0.7))
	var roll_distance := float(cfg.get("tree_roll_distance", 0.9))
	var fade_seconds := float(cfg.get("fade_seconds", 0.5))
	var base_position: Vector3 = ghost.position
	var tween := create_tween()
	# 1) Se vuelca: empieza lento y acelera (ease in).
	tween.tween_method(_tree_tilt.bind(pivot, tilt_axis, s), 0.0, PI / 2.0 - 0.1, fall_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# 2) Rebota un poquito al pegar contra el suelo.
	tween.tween_method(_tree_tilt.bind(pivot, tilt_axis, s), PI / 2.0 - 0.1, PI / 2.0 - 0.32, 0.12).set_trans(Tween.TRANS_SINE)
	tween.tween_method(_tree_tilt.bind(pivot, tilt_axis, s), PI / 2.0 - 0.32, PI / 2.0 - 0.05, 0.12).set_trans(Tween.TRANS_SINE)
	# 3) Rueda un poco por el pasto (se mueve y gira sobre su eje).
	tween.tween_method(_tree_roll.bind(ghost, pivot, base_position, fall_axis, tilt_axis, roll_distance, s), 0.0, 1.0, roll_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# 4) Se achica y desaparece.
	tween.tween_property(ghost, "scale", Vector3(0.05, 0.05, 0.05), fade_seconds)
	tween.tween_callback(ghost.queue_free)


## Inclina el árbol `angle` radianes alrededor de `axis` (conserva su tamaño `s`).
func _tree_tilt(angle: float, pivot: Node3D, axis: Vector3, s: float) -> void:
	if is_instance_valid(pivot):
		pivot.transform.basis = Basis(axis, angle) * Basis().scaled(Vector3.ONE * s)


## El árbol ya caído rueda: avanza `distance` en la dirección de la caída y gira sobre su eje.
func _tree_roll(progress: float, ghost: Node3D, pivot: Node3D, base_position: Vector3, fall_axis: Vector3,
		tilt_axis: Vector3, distance: float, s: float) -> void:
	if not is_instance_valid(ghost) or not is_instance_valid(pivot):
		return
	ghost.position = base_position + fall_axis * distance * progress
	pivot.transform.basis = Basis(fall_axis, progress * 1.6) * Basis(tilt_axis, PI / 2.0 - 0.05) * Basis().scaled(Vector3.ONE * s)
