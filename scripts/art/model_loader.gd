class_name ModelLoader
## Cargador de modelos 3D (.glb) de la Fase 7 (preparación de arte).
##
## Regla de oro: NUNCA rompe el juego. Si el archivo no existe, está roto, no
## tiene mallas o el interruptor «Usar modelos» está apagado, devuelve null y
## quien lo llamó usa las figuras simples de siempre.
##
## Qué hace con un modelo:
##   1. Lo carga (escena ya importada por Godot, o el .glb leído al vuelo).
##   2. Lo mete en la caja de celdas que le toca (si se pasa, lo achica).
##   3. Pinta cada material CON NOMBRE (wood, cloth_red...) con el color de
##      data/palette.json y lo pasa al shader toon + contorno (Style).
## Convenciones del arte: docs/estilo.md.

const MODELS_DIR := "res://assets/models/"
## Cuánto se tolera que el modelo se pase de la caja antes de achicarlo (5 %).
const FIT_TOLERANCE := 1.05

## Interruptor «Usar modelos» (Menú → Info). Apagado = solo figuras simples.
static var enabled := true

# Plantillas ya leídas (ruta → Node3D fuera del árbol). Cada pedido recibe una copia.
static var _templates: Dictionary = {}
# Rutas que fallaron (ruta → motivo): no se reintenta ni se llena el registro de avisos.
static var _broken: Dictionary = {}
## Motivo del último fallo (para pruebas y para el que arma arte).
static var last_error := ""


## Prende o apaga el uso de modelos y avisa para que se rearme todo.
static func set_enabled(on: bool) -> void:
	if on == enabled:
		return
	enabled = on
	EventBus.models_toggled.emit(on)


## Olvida todo lo leído (después de cambiar un .glb con el juego abierto, o
## al terminar una prueba). Libera las plantillas.
static func clear_cache() -> void:
	for template in _templates.values():
		if is_instance_valid(template):
			template.free()
	_templates.clear()
	_broken.clear()
	last_error = ""


## Rutas que fallaron y por qué (ruta → motivo).
static func broken_models() -> Dictionary:
	return _broken.duplicate()


## ¿El archivo existe y se pudo leer como modelo? (no cuenta el interruptor)
static func is_loadable(path: String) -> bool:
	var model := _instantiate(path)
	if model == null:
		return false
	model.free()
	return true


## Modelo de una pieza del catálogo (campo "model") ya listo para agregar al
## árbol, o null si hay que usar las figuras simples.
##   box  = caja de celdas del objeto en metros (ancho X, alto Y, fondo Z).
## Campos opcionales del objeto (todos en data/catalog.json):
##   model_fit      "shrink" (por defecto: solo achica si se pasa de la caja),
##                  "stretch" (se estira a la caja, p. ej. escaleras) o "none".
##   model_pivot    "base" (por defecto: ya viene con el pivote en el centro de la
##                  base, como pide docs/estilo.md) o "auto" (se recoloca solo).
##   model_scale / model_offset / model_rotation   ajustes finos del dueño.
##   model_keep_materials   true = no pintar ni pasar a toon (casos raros).
##   model_colors   {"nombre_material": "#rrggbb"} solo para esta pieza.
static func load_for_item(item: Dictionary, box := Vector3.ZERO) -> Node3D:
	var path := str(item.get("model", ""))
	if path == "" or not enabled:
		return null
	var instance := _instantiate(path)
	if instance == null:
		return null
	var fit_holder := Node3D.new()
	fit_holder.name = "Fit"
	fit_holder.add_child(instance)
	fit_into_box(fit_holder, box, str(item.get("model_fit", "shrink")), str(item.get("model_pivot", "base")))

	var holder := Node3D.new()
	holder.name = "Model"
	holder.set_meta("model_path", path)
	holder.add_child(fit_holder)
	var model_scale: Variant = item.get("model_scale", 1.0)
	if model_scale is Array and model_scale.size() >= 3:
		holder.scale = Vector3(model_scale[0], model_scale[1], model_scale[2])
	else:
		holder.scale = Vector3.ONE * float(model_scale)
	var offset: Array = item.get("model_offset", [0, 0, 0])
	if offset.size() >= 3:
		holder.position = Vector3(offset[0], offset[1], offset[2])
	holder.rotation.y = deg_to_rad(float(item.get("model_rotation", 0)))
	if not item.get("model_keep_materials", false):
		apply_materials(holder, _parse_colors(item.get("model_colors", {})))
	return holder


## Modelo suelto por ruta (personaje, accesorios...). null si no se puede.
static func load_path(path: String, box := Vector3.ZERO, overrides := {}) -> Node3D:
	return load_for_item({"model": path, "model_colors": overrides}, box)


# --- Caja de celdas -------------------------------------------------------

## Mete `holder` (con el modelo adentro) en la caja. Ver `load_for_item`.
static func fit_into_box(holder: Node3D, box: Vector3, fit := "shrink", pivot := "base") -> void:
	var bounds := bounds_of(holder)
	if bounds.size.length() < 0.0001:
		return
	var factor := Vector3.ONE
	if box.x > 0.0 and box.y > 0.0 and box.z > 0.0 and fit != "none":
		var ratio := Vector3(box.x / maxf(bounds.size.x, 0.0001), box.y / maxf(bounds.size.y, 0.0001), box.z / maxf(bounds.size.z, 0.0001))
		if fit == "stretch":
			factor = ratio
		else:
			var smallest := minf(ratio.x, minf(ratio.y, ratio.z))
			if smallest < 1.0 / FIT_TOLERANCE:
				factor = Vector3.ONE * smallest
	holder.scale = factor
	if pivot == "auto":
		# Centro de la base en el origen: x/z al medio, y mínima en 0.
		var base_center := Vector3(bounds.position.x + bounds.size.x / 2.0, bounds.position.y, bounds.position.z + bounds.size.z / 2.0)
		holder.position = -base_center * factor


## Caja (en el espacio de `root`) que envuelve todas las mallas de un modelo.
static func bounds_of(root: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for mesh_node in _meshes_of(root):
		if mesh_node.mesh == null:
			continue
		var relative := _relative_transform(mesh_node, root)
		var box := relative * mesh_node.mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result


## Revisa un modelo y cuenta lo que importa al arte: triángulos, materiales,
## tamaño y avisos (pivote, escala, materiales sin nombre). Sirve a las pruebas
## y a quien arma arte (docs/estilo.md, «Cómo probar un .glb»).
static func inspect(path: String) -> Dictionary:
	var report := {"ok": false, "triangles": 0, "materials": [], "size": Vector3.ZERO, "warnings": [], "error": ""}
	var model := _instantiate(path)
	if model == null:
		report["error"] = last_error
		return report
	var warnings: Array = report["warnings"]
	var materials: Array = report["materials"]
	var triangles := 0
	for mesh_node in _meshes_of(model):
		if mesh_node.mesh == null:
			continue
		triangles += floori(mesh_node.mesh.get_faces().size() / 3.0)
		for surface in mesh_node.mesh.get_surface_count():
			var material_name := material_name_of(mesh_node.mesh.surface_get_material(surface))
			if not material_name in materials:
				materials.append(material_name)
	var bounds := bounds_of(model)
	report["ok"] = true
	report["triangles"] = triangles
	report["size"] = bounds.size
	if absf(bounds.position.y) > 0.02:
		warnings.append("el pivote no está en la base: el piso del modelo está a %.2f m del origen" % bounds.position.y)
	var center_x := bounds.position.x + bounds.size.x / 2.0
	var center_z := bounds.position.z + bounds.size.z / 2.0
	if absf(center_x) > 0.1 or absf(center_z) > 0.1:
		warnings.append("el pivote no está en el centro de la base (descentrado %.2f, %.2f m)" % [center_x, center_z])
	if bounds.size.length() > 12.0:
		warnings.append("es enorme (%.1f m): ¿exportaste en centímetros? 1 celda = 1 m" % bounds.size.length())
	for material_name in materials:
		if material_name == "":
			warnings.append("hay un material sin nombre: se pinta con su color tal cual, no desde la paleta")
		elif not Style.has_material_color(material_name):
			warnings.append("el material «%s» no está en data/palette.json (se usa su color original)" % material_name)
	model.free()
	return report


# --- Materiales con nombre y recoloreo ------------------------------------

## Nombre limpio de un material: sin el sufijo «.001» que agrega Blender.
static func material_name_of(material: Material) -> String:
	if material == null:
		return ""
	var material_name := material.resource_name
	var dot := material_name.rfind(".")
	if dot > 0 and material_name.substr(dot + 1).is_valid_int():
		material_name = material_name.substr(0, dot)
	return material_name.to_lower()


## Pasa todas las mallas del modelo a toon con contorno, pintando cada
## material con nombre desde la paleta (data/palette.json). `overrides` =
## {nombre: Color} para esta pieza (p. ej. el pelo de ESTE personaje).
## Se puede llamar de nuevo para recolorear (por ejemplo al cambiar la paleta):
## siempre parte del material original de la malla.
static func apply_materials(root: Node, overrides := {}) -> void:
	for mesh_node in _meshes_of(root):
		if mesh_node.mesh == null:
			continue
		for surface in mesh_node.mesh.get_surface_count():
			var source := mesh_node.mesh.surface_get_material(surface)
			var base := Color.WHITE
			var texture: Texture2D = null
			if source is BaseMaterial3D:
				base = source.albedo_color
				texture = source.albedo_texture
			var material_name := material_name_of(source)
			if overrides.has(material_name):
				base = overrides[material_name]
			elif Style.has_material_color(material_name):
				base = Style.material_color(material_name, base)
			mesh_node.set_surface_override_material(surface, Style.toon_material(base, texture))


# --- Lectura de archivos ---------------------------------------------------

## Copia nueva del modelo (o null). Lee el archivo una sola vez.
static func _instantiate(path: String) -> Node3D:
	if path == "" or _broken.has(path):
		last_error = str(_broken.get(path, ""))
		return null
	if not _templates.has(path):
		var template := _read(path)
		if template == null:
			_broken[path] = last_error
			return null
		_templates[path] = template
	var copy: Node = (_templates[path] as Node3D).duplicate()
	return copy as Node3D


## Lee el modelo: primero como escena ya importada por Godot (es lo que viaja
## en el APK), si no, el .glb crudo (sirve en la PC sin abrir el editor).
static func _read(path: String) -> Node3D:
	last_error = ""
	var root: Node = null
	if ResourceLoader.exists(path):
		var loaded: Variant = load(path)
		if loaded is PackedScene:
			root = (loaded as PackedScene).instantiate()
	elif path.get_extension().to_lower() == "glb" and FileAccess.file_exists(path):
		root = _read_raw_glb(path)
	else:
		last_error = "no existe: %s" % path
		return null
	if not root is Node3D:
		if root != null:
			root.free()
		if last_error == "":
			last_error = "no se pudo leer como modelo 3D: %s" % path
		return null
	var model: Node3D = root
	if _meshes_of(model).is_empty():
		model.free()
		last_error = "no tiene ninguna malla: %s" % path
		return null
	last_error = ""
	return model


static func _read_raw_glb(path: String) -> Node:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(path, state)
	if error != OK:
		last_error = "archivo roto (error %d): %s" % [error, path]
		return null
	var scene := document.generate_scene(state)
	if scene == null:
		last_error = "no se pudo armar la escena: %s" % path
	return scene


static func _meshes_of(root: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		result.append(root)
	for child in root.find_children("*", "MeshInstance3D", true, false):
		result.append(child as MeshInstance3D)
	return result


## Transformación de `node` respecto de `root` (sin usar el árbol de escena).
static func _relative_transform(node: Node3D, root: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != root:
		if current is Node3D:
			result = (current as Node3D).transform * result
		current = current.get_parent()
	return result


static func _parse_colors(source: Variant) -> Dictionary:
	var result := {}
	if source is Dictionary:
		for key in source:
			var value: Variant = source[key]
			result[str(key).to_lower()] = value if value is Color else Color.from_string(str(value), Color.MAGENTA)
	return result
