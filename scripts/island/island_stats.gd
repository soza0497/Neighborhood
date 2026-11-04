class_name IslandStats
extends RefCounted
## Números de dibujo de la isla (Isla 1A).
##
## Dos fuentes:
##   estimate(raíz)  → CUENTA lo visible en el árbol de nodos (sirve sin pantalla, en las pruebas):
##                     una llamada de dibujo por cada superficie y por cada pasada extra
##                     (el contorno es una segunda pasada), sin contar las sombras.
##   rendering()     → lo que de verdad dibujó el motor el último cuadro
##                     (RenderingServer.get_rendering_info); sin ventana da 0.
## En el teléfono vale lo segundo; lo primero sirve para comparar y para las pruebas.

static var _triangle_cache: Dictionary = {}


## Lo que dibujó el motor el último cuadro: {draws, triangles, objects}.
static func rendering() -> Dictionary:
	return {
		"draws": int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)),
		"triangles": int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)),
		"objects": int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)),
	}


## Cuenta los nodos visibles bajo `root`: {draws, triangles, meshes, multimeshes}.
static func estimate(root: Node) -> Dictionary:
	var result := {"draws": 0, "triangles": 0, "meshes": 0, "multimeshes": 0}
	_walk(root, result)
	return result


static func _walk(node: Node, result: Dictionary) -> void:
	if node is Node3D and not (node as Node3D).visible:
		return
	if node is MeshInstance3D:
		var instance := node as MeshInstance3D
		if instance.mesh != null:
			result["meshes"] = int(result["meshes"]) + 1
			_add_mesh(instance, instance.mesh, 1, result)
	elif node is MultiMeshInstance3D:
		var multi := node as MultiMeshInstance3D
		if multi.multimesh != null and multi.multimesh.mesh != null:
			result["multimeshes"] = int(result["multimeshes"]) + 1
			var count := multi.multimesh.visible_instance_count
			if count < 0:
				count = multi.multimesh.instance_count
			_add_mesh(multi, multi.multimesh.mesh, count, result)
	for child in node.get_children():
		_walk(child, result)


static func _add_mesh(node: GeometryInstance3D, mesh: Mesh, instances: int, result: Dictionary) -> void:
	for surface in mesh.get_surface_count():
		var material: Material = node.material_override
		if material == null and node is MeshInstance3D:
			material = (node as MeshInstance3D).get_surface_override_material(surface)
		if material == null:
			material = mesh.surface_get_material(surface)
		var passes := 1
		var chain := material
		while chain != null and chain.next_pass != null:
			passes += 1
			chain = chain.next_pass
		result["draws"] = int(result["draws"]) + passes
		result["triangles"] = int(result["triangles"]) + passes * instances * _surface_triangles(mesh, surface)


@warning_ignore("integer_division")
static func _surface_triangles(mesh: Mesh, surface: int) -> int:
	var key := "%d:%d" % [mesh.get_instance_id(), surface]
	if _triangle_cache.has(key):
		return _triangle_cache[key]
	var count := 0
	if mesh is ArrayMesh:
		var array_mesh := mesh as ArrayMesh
		var indices := array_mesh.surface_get_array_index_len(surface)
		count = (indices if indices > 0 else array_mesh.surface_get_array_len(surface)) / 3
	else:
		count = mesh.get_faces().size() / 3
	_triangle_cache[key] = count
	return count
