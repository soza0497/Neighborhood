class_name IslandStress
extends Node3D
## Modo de estrés de las casas (Isla 1A): una cuadrícula de `count` casas (100) puestas
## todas cerca para ver el techo del LOD 1 (y compararlo con el LOD 2 agrupado).
## Usa las fichas de las casas simuladas de la isla, repetidas.

## Cuántas casas completas (LOD 0) se arman como máximo aquí: cada una es una HouseView entera.
const LOD0_LIMIT := 12

var count := 100
var spacing := 52.0
var level := 1

var _cards: Array = []
var _lots: Array = []
var _holder: Node3D


func setup(new_count: int, new_spacing: float) -> void:
	count = new_count
	spacing = new_spacing
	_lots = IslandData.all_lots()
	for l in _lots:
		_cards.append(IslandFakeHouses.card_for(l))
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	var plane := PlaneMesh.new()
	var extent := _columns() * spacing + 200.0
	plane.size = Vector2(extent, extent)
	ground.mesh = plane
	ground.material_override = Style.toon_material(IslandData.color("ground"), null, false)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)
	set_level(1)


func _columns() -> int:
	return int(ceil(sqrt(float(count))))


## Posición de la casa número `index` en la cuadrícula (centrada en el origen).
@warning_ignore("integer_division")
func position_of(index: int) -> Vector3:
	var cols := _columns()
	var offset := (cols - 1) / 2.0
	return Vector3((index % cols - offset) * spacing, 0.0, (index / cols - offset) * spacing)


## Radio que cubre la cuadrícula (para colocar la cámara).
func extent() -> float:
	return _columns() * spacing / 2.0


## Arma todas las casas en el nivel pedido (0 = completas, 1 = fachada, 2 = bloques en una malla).
func set_level(new_level: int) -> void:
	level = clampi(new_level, 0, 2)
	if _holder != null:
		remove_child(_holder)
		_holder.queue_free()
	_holder = Node3D.new()
	_holder.name = "Houses"
	add_child(_holder)
	var entries: Array = []
	for i in count:
		var l: Dictionary = _lots[i % _lots.size()]
		var card: ExteriorCard = _cards[i % _cards.size()]
		var xf := Transform3D(Basis.IDENTITY, position_of(i))
		if level == 2:
			entries.append({"card": card, "xf": xf})
		elif level == 0 and i < LOD0_LIMIT:
			var node := ExteriorLod0.build(IslandFakeHouses.house_for(l), card, _holder)
			node.transform = xf
		else:
			var node1 := ExteriorLod1.build(card)
			node1.transform = xf
			_holder.add_child(node1)
	if level == 2:
		var cluster := ExteriorLod2.build_cluster(entries, "Lod2_all")
		if cluster != null:
			_holder.add_child(cluster)
