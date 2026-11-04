class_name ExteriorGeometry
extends RefCounted
## Geometría exterior de una casa a partir de su ficha (Isla 1A). La usan el LOD 1
## (fachada con puerta y ventanas) y el LOD 2 (bloques de color).
##
## El origen de la casa es el CENTRO de su huella, en el suelo; el frente mira a +Z.
## Todo se agrega a un IslandMeshKit (color por vértice, una sola malla).

const WINDOW_SIZE := Vector2(1.0, 0.9)
const DOOR_SIZE := Vector2(1.0, 2.0)
## Cuánto sobresale una puerta o ventana de la pared (para que no se mezcle con ella).
const PANEL_OFFSET := 0.04
const FOUNDATION_OVERHANG := 0.1


## Agrega la casa de `card` al acumulador, colocada con `xf` (el origen de `xf` es el
## centro de la huella). `detailed` = true: cimientos, puerta y ventanas (LOD 1);
## false: solo bloques de pisos y techo (LOD 2).
static func add_house(kit: IslandMeshKit, card: ExteriorCard, xf: Transform3D, detailed: bool) -> void:
	if card.is_empty():
		return
	var box := card.bounds()
	var center := Vector3(box.position.x + box.size.x / 2.0, 0.0, box.position.y + box.size.y / 2.0)
	var root := xf * Transform3D(Basis.IDENTITY, -center)
	var base := card.base_height
	var foundation_color := IslandData.color("foundation")
	# Cimientos (en el LOD 2 la planta baja baja hasta el suelo y listo).
	if detailed:
		for rect in card.floors[0]["fp"]:
			var size := Vector3(float(rect[2]) + FOUNDATION_OVERHANG * 2.0, base, float(rect[3]) + FOUNDATION_OVERHANG * 2.0)
			var at := Vector3(float(rect[0]) + float(rect[2]) / 2.0, base / 2.0, float(rect[1]) + float(rect[3]) / 2.0)
			kit.add_box(root * Transform3D(Basis.IDENTITY, at), size, foundation_color)
	# Pisos: una caja por rectángulo de la huella.
	var y := base if detailed else 0.0
	var level_y: Array[float] = []
	for level in card.floors.size():
		var f: Dictionary = card.floors[level]
		var h := float(f["h"]) + (0.0 if detailed or level > 0 else base)
		level_y.append(base + level * float(f["h"]))
		var color := card.wall_color(level)
		for rect in f["fp"]:
			var at := Vector3(float(rect[0]) + float(rect[2]) / 2.0, y + h / 2.0, float(rect[1]) + float(rect[3]) / 2.0)
			kit.add_box(root * Transform3D(Basis.IDENTITY, at), Vector3(float(rect[2]), h, float(rect[3])), color)
		y += h
	# Puerta y ventanas (solo LOD 1).
	if detailed:
		if not card.door.is_empty():
			var lv := int(card.door["lv"])
			_add_opening(kit, root, card, lv, int(card.door["e"]), level_y[lv], DOOR_SIZE, IslandData.color("door"))
		for level in card.floors.size():
			for code in card.floors[level]["w"]:
				_add_opening(kit, root, card, level, int(code), level_y[level] + 0.8, WINDOW_SIZE, IslandData.color("glass"))
	# Techos.
	for i in card.roofs.size():
		_add_roof(kit, root, card, i, level_y)


## Un panel (puerta o ventana) pegado a la pared de código `code` del piso `level`.
static func _add_opening(kit: IslandMeshKit, root: Transform3D, card: ExteriorCard, level: int, code: int,
		bottom_y: float, size: Vector2, color: Color) -> void:
	var key := ExteriorCard.edge_key_of(code)
	var vertex := HouseGrid.edge_vertex(key)
	var cells := card.cells_of(level)
	var center: Vector3
	var tangent: Vector3
	var normal: Vector3
	if HouseGrid.is_edge_horizontal(key):
		# Pared a lo largo de x. Si la celda de arriba (norte) es de la casa, la pared mira al sur (+Z).
		normal = Vector3.BACK if cells.has(HouseGrid.cell_key(vertex + Vector2i(0, -1))) else Vector3.FORWARD
		tangent = Vector3.RIGHT
		center = Vector3(vertex.x + 0.5, bottom_y + size.y / 2.0, vertex.y)
	else:
		normal = Vector3.RIGHT if cells.has(HouseGrid.cell_key(vertex + Vector2i(-1, 0))) else Vector3.LEFT
		tangent = Vector3.BACK
		center = Vector3(vertex.x, bottom_y + size.y / 2.0, vertex.y + 0.5)
	var c := center + normal * PANEL_OFFSET
	var t := tangent * size.x / 2.0
	var u := Vector3.UP * size.y / 2.0
	kit.add_quad(root * (c - t - u), root * (c + t - u), root * (c + t + u), root * (c - t + u),
		(root.basis * normal).normalized(), color)


## El techo número `index` de la ficha (a dos aguas o plano).
static func _add_roof(kit: IslandMeshKit, root: Transform3D, card: ExteriorCard, index: int, level_y: Array[float]) -> void:
	var roof: Dictionary = card.roofs[index]
	var rect: Array = roof["r"]
	var level := clampi(int(roof["lv"]), 0, card.floors.size() - 1)
	var top_y: float = level_y[level] + float(card.floors[level]["h"])
	var color := card.roof_color(index)
	var x := float(rect[0]) + float(rect[2]) / 2.0
	var z := float(rect[1]) + float(rect[3]) / 2.0
	if card.roof_is_flat(index):
		kit.add_box(root * Transform3D(Basis.IDENTITY, Vector3(x, top_y + 0.11, z)),
			Vector3(float(rect[2]) + 0.24, 0.22, float(rect[3]) + 0.24), color)
		return
	var along_x: bool = int(rect[2]) >= int(rect[3])
	var length := float(rect[2] if along_x else rect[3]) + HousePieces.ROOF_OVERHANG * 2.0
	var half := float(rect[3] if along_x else rect[2]) / 2.0
	var ridge := half * HousePieces.ROOF_SLOPE
	var width := (half + HousePieces.ROOF_OVERHANG) * 2.0
	var turn: Basis = Basis.IDENTITY if along_x else Basis(Vector3.UP, PI / 2.0)
	var at := Vector3(x, top_y - HousePieces.ROOF_OVERHANG * HousePieces.ROOF_SLOPE + HousePieces.ROOF_LIFT, z)
	kit.add_gable(root * Transform3D(turn, at), length, width, ridge, color, card.wall_color(level))
