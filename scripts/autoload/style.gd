extends Node
## Estilo visual del juego (Pulido 2B): shader toon con contorno.
##
## Lee data/style.json (colores, tonos de las sombras, grosor del contorno,
## luz y niebla) y entrega los materiales a quien los pida:
##   Style.toon_material(color)  → material toon (uno por color, compartido)
##   Style.color("ground")       → color de la paleta
##   Style.material_color("wood")→ color de un material con nombre (data/palette.json)
##   Style.toonify(nodo)         → pasa los materiales de un modelo (.glb) a toon
##   Style.set_outline(false)    → apaga/prende el contorno (Menú → Info)
##
## El contorno es una segunda pasada ("next_pass") que se pega a cada material
## toon: apagarlo la saca de todos a la vez (más rápido en un teléfono lento).
## Todo el arte del juego pasa por acá: cuando el dueño cambie el estilo,
## cambia el JSON (o el shader), no el código.

const STYLE_PATH := "res://data/style.json"
## Fase 7: colores de los materiales con nombre de los .glb, tonos de las sombras
## y luz. Es el único lugar para ajustar esas tres cosas.
const PALETTE_PATH := "res://data/palette.json"
const TOON_SHADER := preload("res://assets/shaders/toon.gdshader")
const OUTLINE_SHADER := preload("res://assets/shaders/outline.gdshader")
const INVISIBLE_SHADER := preload("res://assets/shaders/invisible.gdshader")

## Se prendió o apagó el contorno.
signal outline_changed(enabled: bool)

var data: Dictionary = {}
var palette: Dictionary = {}
## Fase 7: colores por nombre de material (palette.json → "materials").
var materials: Dictionary = {}
var outline_enabled := true

var _outline_material: ShaderMaterial
var _cache: Dictionary = {}


func _ready() -> void:
	reload()


## Vuelve a leer el JSON (sirve para probar cambios sin cerrar el juego).
func reload() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(STYLE_PATH))
	data = parsed if parsed is Dictionary else {}
	palette = data.get("palette", {})
	# Fase 7: tonos y luz salen de palette.json (si falta, quedan los de style.json
	# o los valores de respaldo de más abajo).
	var palette_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PALETTE_PATH))
	var palette_file: Dictionary = palette_parsed if palette_parsed is Dictionary else {}
	materials = palette_file.get("materials", {})
	var lighting: Dictionary = palette_file.get("lighting", {})
	for section in ["toon", "light"]:
		if lighting.get(section) is Dictionary:
			data[section] = lighting[section]
	var outline: Dictionary = data.get("outline", {})
	outline_enabled = bool(outline.get("enabled", true))
	_outline_material = ShaderMaterial.new()
	_outline_material.shader = OUTLINE_SHADER
	_outline_material.set_shader_parameter("outline_color", Color.from_string(str(outline.get("color", "#2b2233")), Color.BLACK))
	_outline_material.set_shader_parameter("outline_px", float(outline.get("width_px", 2.2)))
	_cache.clear()


## Color de la paleta por nombre ("ground", "road"...).
func color(color_name: String, fallback := Color.MAGENTA) -> Color:
	return Color.from_string(str(palette.get(color_name, "")), fallback)


## ¿La paleta tiene un color para este nombre de material (wood, cloth_red...)?
func has_material_color(material_name: String) -> bool:
	return materials.has(material_name)


## Color de un material con nombre (data/palette.json). `fallback` si no está.
func material_color(material_name: String, fallback := Color.MAGENTA) -> Color:
	return Color.from_string(str(materials.get(material_name, "")), fallback)


## Material toon de un color (uno por color y textura, compartido).
## `outlined` = false para lo grande y plano (suelo, calle): sin contorno.
func toon_material(base: Color, texture: Texture2D = null, outlined := true) -> ShaderMaterial:
	var key := base.to_html() + ("o" if outlined else "n") + (str(texture.get_rid().get_id()) if texture != null else "")
	if _cache.has(key):
		return _cache[key]
	var toon: Dictionary = data.get("toon", {})
	var tones: Array = toon.get("tones", [0.62, 0.84, 1.0])
	var thresholds: Array = toon.get("thresholds", [0.28, 0.7])
	var mat := ShaderMaterial.new()
	mat.shader = TOON_SHADER
	mat.set_shader_parameter("albedo", base)
	mat.set_shader_parameter("tones", Vector3(tones[0], tones[1], tones[2]))
	mat.set_shader_parameter("thresholds", Vector2(thresholds[0], thresholds[1]))
	if texture != null:
		mat.set_shader_parameter("albedo_tex", texture)
	mat.next_pass = _outline_material if (outline_enabled and outlined) else null
	mat.set_meta("outlined", outlined)
	_cache[key] = mat
	return mat


## Pulido 3C: material que no se ve, solo lleva el contorno (ver invisible.gdshader).
## Se pone en una caja que envuelve toda una pared de varios tramos: el contorno
## sale UNA sola vez alrededor de la silueta, sin costuras entre los tramos.
## Se prende y apaga con el resto del contorno.
func outline_only_material() -> ShaderMaterial:
	if _cache.has("outline_only"):
		return _cache["outline_only"]
	var mat := ShaderMaterial.new()
	mat.shader = INVISIBLE_SHADER
	mat.next_pass = _outline_material if outline_enabled else null
	mat.set_meta("outlined", true)
	_cache["outline_only"] = mat
	return mat


## Prende o apaga el contorno en todos los materiales ya creados.
func set_outline(enabled: bool) -> void:
	if enabled == outline_enabled:
		return
	outline_enabled = enabled
	for mat in _cache.values():
		mat.next_pass = _outline_material if (enabled and mat.get_meta("outlined", true)) else null
	outline_changed.emit(enabled)


## Pasa todos los materiales de un modelo importado (.glb) al estilo toon,
## conservando su color y su textura. Así el arte nuevo se ve igual que el
## resto sin tocar nada en Blender.
func toonify(node: Node) -> void:
	# Fase 7: además pinta los materiales con nombre desde la paleta.
	ModelLoader.apply_materials(node)


## Luz y ambiente del mundo según el JSON (sol, ambiente, sombras, niebla).
func apply_world(sun: DirectionalLight3D, environment: Environment) -> void:
	var light: Dictionary = data.get("light", {})
	if sun != null:
		sun.light_color = Color.from_string(str(light.get("sun_color", "#fff4dc")), Color.WHITE)
		sun.light_energy = float(light.get("sun_energy", 1.15))
		sun.shadow_opacity = float(light.get("shadow_opacity", 0.55))
	if environment != null:
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = Color.from_string(str(light.get("ambient_color", "#e4ecff")), Color.WHITE)
		environment.ambient_light_energy = float(light.get("ambient_energy", 0.42))
		environment.background_mode = Environment.BG_COLOR
		environment.background_color = color("sky")
		var fog: Dictionary = data.get("fog", {})
		environment.fog_enabled = bool(fog.get("enabled", true))
		environment.fog_light_color = color("fog")
		environment.fog_mode = Environment.FOG_MODE_DEPTH
		environment.fog_depth_begin = float(fog.get("begin", 70.0))
		environment.fog_depth_end = float(fog.get("end", 190.0))
		environment.fog_depth_curve = 1.4
		environment.fog_sun_scatter = 0.0
