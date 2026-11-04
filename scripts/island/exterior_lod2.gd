class_name ExteriorLod2
extends RefCounted
## LOD 2 (Isla 1A): una calle o zona entera. Cada casa es un par de bloques con su
## color y el tipo de techo; todas las casas de la zona van juntas en UNA malla
## (una llamada de dibujo para toda la zona) y SIN contorno.


## Malla con todas las casas de `entries`: [{"card": ExteriorCard, "xf": Transform3D}],
## donde "xf" es la colocación de cada casa (origen = centro de su huella).
static func build_kit(entries: Array) -> IslandMeshKit:
	var kit := IslandMeshKit.new()
	for entry in entries:
		ExteriorGeometry.add_house(kit, entry["card"], entry["xf"], false)
	return kit


## La zona lista para la escena. Devuelve null si no hay casas.
static func build_cluster(entries: Array, node_name := "Lod2") -> MeshInstance3D:
	var mesh := build_kit(entries).build()
	if mesh == null:
		return null
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.material_override = IslandMaterials.blocks(false)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node
