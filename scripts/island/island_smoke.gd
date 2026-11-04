class_name IslandSmoke
extends Node3D
## Humo opcional del volcán (Isla 1A): unas bolitas grises que suben, crecen y se
## desvanecen en ciclo. Son pocas mallas chicas (sin partículas, que en el teléfono
## cuestan más). Se apaga con `visible = false` (y entonces ni se anima).

var puff_count := 7
var puff_radius := 20.0
var rise_height := 120.0
var color := Color(0.84, 0.81, 0.86)
## Segundos que tarda una bolita en subir y desaparecer.
var cycle_seconds := 14.0

var _puffs: Array[MeshInstance3D] = []
var _materials: Array[StandardMaterial3D] = []
var _time := 0.0


func _ready() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	for i in puff_count:
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.roughness = 1.0
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		_puffs.append(node)
		_materials.append(material)
	_update_puffs()


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	_update_puffs()


func _update_puffs() -> void:
	for i in _puffs.size():
		var t := fposmod(_time / cycle_seconds + float(i) / maxi(1, _puffs.size()), 1.0)
		var size := puff_radius * lerpf(0.5, 1.8, t)
		_puffs[i].position = Vector3(sin(float(i) * 2.3) * puff_radius * 0.4 * t, t * rise_height, cos(float(i) * 1.7) * puff_radius * 0.4 * t)
		_puffs[i].scale = Vector3(size, size * 0.8, size)
		var tint := color
		tint.a = (1.0 - t) * 0.75
		_materials[i].albedo_color = tint
