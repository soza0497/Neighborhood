class_name BasementView
extends Node3D
## Pulido 6A (3): cómo se ve el sótano cuando se construye en él.
##
##  - Todo oscuro, café muy oscuro: el fondo de la pantalla y un "piso de tierra" grande
##    bajo el hoyo (el terreno de arriba se esconde, como antes).
##  - Una GUÍA de la casa de arriba: la silueta (celdas translúcidas) de lo que hay
##    encima, para saber dónde construir. Solo se puede excavar bajo la casa
##    (HouseRules, también lo revisa el servidor).
##  - El efecto hueco (las paredes del frente se esconden) lo hace HouseView.
##
## Vive dentro de la vista de la casa (mismas coordenadas). Sin datos propios: todo se
## recalcula de la casa cuando cambia.

## Cuántos metros se extiende el piso de tierra más allá del lote.
const EARTH_MARGIN := 40.0
## Opacidad de la guía.
const GUIDE_ALPHA := 0.32

var house: HouseData
var current_level := 0

var _earth: MeshInstance3D
var _guide: MeshInstance3D
var _dirty := true
var _saved_environment := {}


func _ready() -> void:
	name = "BasementView"
	visible = false


## Conecta con la casa (la guía se actualiza sola cuando cambia).
func setup(new_house: HouseData) -> void:
	house = new_house
	house.piece_changed.connect(func(_l: int, _layer: String, _k: String) -> void: _dirty = true)
	house.reloaded.connect(func() -> void: _dirty = true)


## El nivel que se está mirando cambió. Bajo tierra (nivel < 0) se muestra el fondo oscuro y la guía.
func show_level(level: int) -> void:
	current_level = level
	visible = level < 0
	_dirty = true
	if visible:
		_rebuild()


func _process(_delta: float) -> void:
	if visible and _dirty:
		_rebuild()


## Las celdas de la silueta guía para un sótano: lo que hay ENCIMA.
##  - Sótano 1: la huella de la casa (cimientos o piso de la planta baja y de arriba).
##  - Más abajo: lo excavado en el sótano de arriba.
static func guide_cells(target: HouseData, level: int) -> Array[Vector2i]:
	var cells := {}
	if level >= 0:
		return []
	if level == -1:
		for lvl in range(0, HouseGrid.MAX_LEVELS):
			for layer in ["foundation", "floors"]:
				for key in target.get_layer(lvl, layer):
					cells[key] = true
	else:
		for key in target.get_layer(level + 1, "excavation"):
			cells[key] = true
	var result: Array[Vector2i] = []
	for key in cells:
		result.append(HouseGrid.key_to_cell(key))
	return result


func _rebuild() -> void:
	_dirty = false
	if house == null:
		return
	var y := HouseGrid.level_y(current_level)
	# Piso de tierra: un plano grande, apenas debajo del suelo del sótano.
	if _earth == null:
		_earth = MeshInstance3D.new()
		_earth.name = "Earth"
		_earth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_earth)
		var plane := PlaneMesh.new()
		plane.size = Vector2(HouseGrid.LOT_SIZE) + Vector2.ONE * EARTH_MARGIN * 2.0
		_earth.mesh = plane
		_earth.material_override = HousePieces.material_no_outline(Style.color("basement_ground", Color("#3a281c")))
		_earth.position = Vector3(HouseGrid.LOT_SIZE.x / 2.0, 0.0, HouseGrid.LOT_SIZE.y / 2.0)
	_earth.position.y = y - 0.32
	# La guía: celdas translúcidas con un borde más claro (un solo mesh).
	if _guide == null:
		_guide = MeshInstance3D.new()
		_guide.name = "Guide"
		_guide.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_guide.material_override = mat
		add_child(_guide)
	var cells := guide_cells(house, current_level)
	_guide.mesh = _guide_mesh(cells)
	_guide.position = Vector3(0.0, y + 0.04, 0.0)


## Malla de la silueta: un cuadrito por celda y una línea fina en el contorno de la silueta.
func _guide_mesh(cells: Array[Vector2i]) -> Mesh:
	if cells.is_empty():
		return null
	var base := Style.color("basement_guide", Color("#ffd98a"))
	var fill := Color(base, GUIDE_ALPHA)
	var line := Color(base, 0.9)
	var cell_set := {}
	for cell in cells:
		cell_set[HouseGrid.cell_key(cell)] = true
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for cell in cells:
		var a := Vector2(cell)
		var b := Vector2(cell) + Vector2.ONE
		_quad(st, a, b, 0.0, fill)
		# Borde: en cada lado donde la celda vecina NO es parte de la silueta.
		if not cell_set.has(HouseGrid.cell_key(cell + Vector2i(0, -1))):
			_quad(st, Vector2(a.x, a.y), Vector2(b.x, a.y + 0.1), 0.01, line)
		if not cell_set.has(HouseGrid.cell_key(cell + Vector2i(1, 0))):
			_quad(st, Vector2(b.x - 0.1, a.y), Vector2(b.x, b.y), 0.01, line)
		if not cell_set.has(HouseGrid.cell_key(cell + Vector2i(0, 1))):
			_quad(st, Vector2(a.x, b.y - 0.1), Vector2(b.x, b.y), 0.01, line)
		if not cell_set.has(HouseGrid.cell_key(cell + Vector2i(-1, 0))):
			_quad(st, Vector2(a.x, a.y), Vector2(a.x + 0.1, b.y), 0.01, line)
	return st.commit()


static func _quad(st: SurfaceTool, from: Vector2, to: Vector2, y: float, color: Color) -> void:
	var p := [Vector3(from.x, y, from.y), Vector3(to.x, y, from.y), Vector3(to.x, y, to.y), Vector3(from.x, y, to.y)]
	for index in [0, 1, 2, 0, 2, 3]:
		st.set_color(color)
		st.add_vertex(p[index])


## Pone el fondo y la niebla de la escena: oscuros bajo tierra, normales arriba.
## `env` = el Environment de la escena (WorldEnvironment).
func apply_environment(env: Environment, underground: bool) -> void:
	if env == null:
		return
	if underground:
		if _saved_environment.is_empty():
			_saved_environment = {"bg": env.background_color, "fog": env.fog_enabled}
		env.background_color = Style.color("basement_bg", Color("#1d130d"))
		env.fog_enabled = false
	elif not _saved_environment.is_empty():
		env.background_color = _saved_environment["bg"]
		env.fog_enabled = _saved_environment["fog"]
		_saved_environment = {}
