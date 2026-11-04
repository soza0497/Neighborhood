class_name ExteriorLod0
extends RefCounted
## LOD 0 (Isla 1A): la parcela completa, como hoy. Es la misma HouseView del juego
## (todas las piezas del catálogo, interior, muebles, contorno), con techos.


## La casa completa en un nodo cuyo origen es el centro de su huella, en el suelo.
static func build(house: HouseData, card: ExteriorCard) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Lod0"
	var box := card.bounds()
	var view := HouseView.new()
	view.name = "House"
	view.show_roofs = true   # Antes de setup: se arma una sola vez, con techos.
	view.position = Vector3(-(box.position.x + box.size.x / 2.0), 0.0, -(box.position.y + box.size.y / 2.0))
	holder.add_child(view)
	view.setup(house)
	view.set_process_unhandled_input(false)
	return holder
