class_name ExteriorLod1
extends RefCounted
## LOD 1 (Isla 1A): la casa de un vecino cercano, solo EXTERIOR, armada desde su ficha:
## cimientos, paredes piso a piso con sus colores, puerta, ventanas y techo.
## Sin interior, sin muebles y sin objetos del jardín.
##
## Es UNA sola malla con color por vértice y UN material con contorno: 2 llamadas de
## dibujo por casa (1 si se apaga el contorno).


## Acumulador con la casa (origen = centro de la huella, en el suelo).
static func build_kit(card: ExteriorCard) -> IslandMeshKit:
	var kit := IslandMeshKit.new()
	ExteriorGeometry.add_house(kit, card, Transform3D.IDENTITY, true)
	return kit


## La casa lista para poner en la escena (sin colocar: el que la pide la mueve).
## `outlined` = false la dibuja sin contorno (data/island.json → lod.outline_max_level = 0).
static func build(card: ExteriorCard, outlined := true) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = "Lod1"
	node.mesh = build_kit(card).build()
	node.material_override = IslandMaterials.blocks(outlined)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node
