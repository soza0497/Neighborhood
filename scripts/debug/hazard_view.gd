class_name HazardView
extends Node3D
## Marcadores chatos de color para las celdas peligrosas (Pulido 4B): azul = charco,
## naranja = caliente, amarillo = desnivel (colores en data/hazards.json).
## Solo se ven con el modo desarrollador prendido. Va como hijo de la HouseView.

const MARKER_SIZE := Vector3(0.9, 0.04, 0.9)

var _nav: HouseNav


func setup(nav: HouseNav) -> void:
	_nav = nav
	EventBus.hazards_changed.connect(_rebuild)
	EventBus.dev_mode_changed.connect(func(_on: bool) -> void: _rebuild())
	_rebuild()


## Vuelve a dibujar todos los marcadores.
func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	visible = DevMode.is_enabled()
	if not visible:
		return
	for hazard in HazardMap.all():
		var cell: Vector2i = hazard["cell"]
		var level: int = hazard["level"]
		var mesh := BoxMesh.new()
		mesh.size = MARKER_SIZE
		var marker := MeshInstance3D.new()
		marker.name = "Hazard_%s" % hazard["kind"]
		marker.mesh = mesh
		var color := HazardMap.color_of(hazard["kind"])
		color.a = 0.7
		marker.material_override = HousePieces.transparent_material(color)
		marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var y := _nav.ground_y(level, cell) if _nav != null else HouseGrid.level_y(level)
		marker.position = Vector3(cell.x + 0.5, y + MARKER_SIZE.y / 2.0 + 0.02, cell.y + 0.5)
		add_child(marker)
