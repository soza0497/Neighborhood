class_name IslandMaterials
extends RefCounted
## Materiales de la isla (Isla 1A). Pocos y compartidos:
##   blocks(true)  → toon con color por vértice y CONTORNO (LOD 0 y 1).
##   blocks(false) → lo mismo SIN contorno (LOD 2 en adelante: el contorno dibuja
##                   cada pieza dos veces y de lejos no se nota).
##   map()         → plano sin luz para el mapa estilizado (LOD 3).
## El contorno se pega como segunda pasada (la misma de Style) y sigue el
## interruptor «Contorno» de Info (Style.set_outline).

const BLOCKS_SHADER := preload("res://assets/shaders/island_blocks.gdshader")
const MAP_SHADER := preload("res://assets/shaders/island_map.gdshader")

static var _plain: ShaderMaterial
static var _outlined: ShaderMaterial
static var _map: ShaderMaterial
static var _hooked := false


static func blocks(outlined: bool) -> ShaderMaterial:
	_ensure()
	return _outlined if outlined else _plain


static func map() -> ShaderMaterial:
	_ensure()
	return _map


static func _ensure() -> void:
	if _plain != null:
		return
	var toon: Dictionary = Style.data.get("toon", {})
	var tones: Array = toon.get("tones", [0.62, 0.84, 1.0])
	var thresholds: Array = toon.get("thresholds", [0.28, 0.7])
	_plain = ShaderMaterial.new()
	_plain.shader = BLOCKS_SHADER
	_plain.set_shader_parameter("tones", Vector3(tones[0], tones[1], tones[2]))
	_plain.set_shader_parameter("thresholds", Vector2(thresholds[0], thresholds[1]))
	_outlined = _plain.duplicate() as ShaderMaterial
	_map = ShaderMaterial.new()
	_map.shader = MAP_SHADER
	if not _hooked:
		_hooked = true
		Style.outline_changed.connect(func(_on: bool) -> void: sync_outline())
	sync_outline()


## Pega o saca el contorno según Style.outline_enabled.
static func sync_outline() -> void:
	if _outlined == null:
		return
	# El material toon de cualquier color lleva la pasada de contorno de Style (o null).
	var reference := Style.toon_material(Color.WHITE, null, true)
	_outlined.next_pass = reference.next_pass
