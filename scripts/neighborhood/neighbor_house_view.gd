class_name NeighborHouseView
extends Node3D
## La casa de un vecino en 3D (Fase 8A/8B).
##
## Por defecto se ve la SILUETA: pocas cajas y el techo (barato para el
## teléfono, hay ~23 casas). Al visitarla, `set_interior(true)` arma la casa
## completa con HouseView (las mismas piezas del catálogo que la tuya) en modo
## solo ver: sin techo y con las paredes bajas para mirar adentro. Nada se puede
## tocar: esta casa no tiene constructor ni historial.

var lot_id := ""
var family := ""
var size := Vector2.ZERO
var interior_on := false

var _design: Dictionary = {}
## Todo lo de la casa va aquí adentro, corrido para que (0,0) sea su esquina.
var _inner: Node3D
var _silhouette: Node3D
var _view: HouseView
var _sign: Label3D


## Arma la silueta de la casa del lote `new_lot_id` y la pone en su lugar.
func setup(new_lot_id: String) -> void:
	lot_id = new_lot_id
	name = "House_" + lot_id
	_design = NeighborhoodMap.design(lot_id)
	family = NeighborhoodMap.family_name(lot_id)
	var placed := NeighborhoodMap.placement(lot_id)
	size = placed["size"]
	position = placed["center"]
	rotation.y = placed["rot_y"]
	_inner = Node3D.new()
	_inner.name = "Inner"
	_inner.position = Vector3(-size.x / 2.0, 0.0, -size.y / 2.0)
	add_child(_inner)
	_silhouette = _build_silhouette()
	_inner.add_child(_silhouette)
	_build_sign()


func design() -> Dictionary:
	return _design


## Cartel con el nombre de la familia (siempre mira a la cámara).
func _build_sign() -> void:
	_sign = Label3D.new()
	_sign.name = "Sign"
	_sign.text = NeighborhoodMap.family_label(lot_id)
	_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sign.pixel_size = 0.012
	_sign.font_size = 56
	_sign.outline_size = 14
	_sign.modulate = Color("#ffffff")
	_sign.outline_modulate = Color("#2b2233")
	_sign.no_depth_test = true
	_sign.visible = false  # Pulido 6C: el nombre solo aparece al tocar la casa.
	# Encima del techo, sin girar con la casa (billboard) y sin quedar dado vuelta.
	_sign.position = Vector3(0.0, HouseGrid.WALL_HEIGHT + 3.4, 0.0)
	add_child(_sign)


## Muestra u oculta el cartel (el control del barrio lo apaga de lejos).
func set_sign_visible(value: bool) -> void:
	if _sign != null:
		_sign.visible = value


## Silueta: base, paredes, puerta, ventanas y techo, todo en cajas simples.
func _build_silhouette() -> Node3D:
	var root := Node3D.new()
	root.name = "Silhouette"
	var cols := float(_design["cols"])
	var rows := float(_design["rows"])
	var wall_color := Color.from_string(_design["wall_color"], Color.WHITE)
	var base_h := HouseGrid.FOUNDATION_HEIGHT
	var wall_h := HouseGrid.WALL_HEIGHT
	HousePieces.add_box(root, Vector3(cols / 2.0, base_h / 2.0, rows / 2.0), Vector3(cols + 0.1, base_h, rows + 0.1),
		Style.toon_material(Color("#b8a58c")))
	HousePieces.add_box(root, Vector3(cols / 2.0, base_h + wall_h / 2.0, rows / 2.0), Vector3(cols, wall_h, rows),
		Style.toon_material(wall_color))
	# Puerta y ventanas del frente (+Z); las demás ventanas se ven por dentro.
	var front := rows + 0.04
	var door_x := float(_design["door_col"]) + 0.5
	HousePieces.add_box(root, Vector3(door_x, base_h + 1.0, front), Vector3(0.9, 2.0, 0.1),
		Style.toon_material(Color("#8a5a3a")))
	var glass := Style.toon_material(Color("#a9d6f5"))
	for key in _design["windows"]:
		var vertex := HouseGrid.edge_vertex(key)
		if HouseGrid.is_edge_horizontal(key) and vertex.y == int(rows):
			HousePieces.add_box(root, Vector3(vertex.x + 0.5, base_h + 1.5, front), Vector3(1.0, 0.9, 0.1), glass)
	var roof_value := {"item": _design["roof_item"], "rect": [0, 0, int(cols), int(rows)], "color": _design["roof_color"]}
	var roof := HousePieces.build_roof(roof_value, wall_color)
	if roof != null:
		roof.position.y += base_h
		root.add_child(roof)
	return root


## Adentro sí (solo ver) o solo la silueta. Armar el interior cuesta, así que
## se arma al visitar y se desarma al irse.
func set_interior(on: bool) -> void:
	if on == interior_on:
		return
	interior_on = on
	if on:
		var data := NeighborHouseDesign.build_house_data(_design)
		_view = HouseView.new()
		_view.name = "Interior"
		_inner.add_child(_view)
		_view.setup(data)
		_view.set_top_visible_level(0)  # Sin pisos de arriba y sin techo.
		_view.set_view(false, true)     # Paredes bajas: se ve adentro.
		_view.set_process_unhandled_input(false)
	elif _view != null:
		_inner.remove_child(_view)
		_view.queue_free()
		_view = null
	_silhouette.visible = not on
