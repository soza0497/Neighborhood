extends Node
## Demostración del Pulido 3C (contorno sin costuras), con capturas «antes y después».
##
##   godot --path . res://tests/polish3c_demo.tscn
## Las capturas (p3c_*.png) van a SHOT_DIR (o a user://). Partida local.

var _main: Node3D
var _house: HouseData
var _view: HouseView
var _shot_dir := ""
var _passed := 0
var _failed := 0
var _shots: Array[String] = []
const O := Vector2i(40, 66)


func _ready() -> void:
	_shot_dir = OS.get_environment("SHOT_DIR")
	if _shot_dir == "":
		_shot_dir = OS.get_user_data_dir()
	HouseGrid.LOT_SIZE = Vector2i(96, 96)
	HouseData.blocked_cells = {}
	Economy.server_mode = false
	Parcel.setup_local({"seed": 424242})
	_main = preload("res://scenes/main.tscn").instantiate()
	add_child(_main)
	Economy.debug_unlock_all()
	_house = _main.house
	_view = _main.get_node("House")
	_run.call_deferred()


func _run() -> void:
	_build()
	_main.set_mode("live")
	_main._set_level(0)
	_main.get_node("HUD").visible = false
	await _frames(8)
	await _test_structure()
	await _test_seams()
	await _test_fps()
	print("\nDEMO PULIDO 3C: %d pasaron, %d fallaron · capturas: %s" % [_passed, _failed, ", ".join(_shots)])
	get_tree().quit(1 if _failed > 0 else 0)


func _build() -> void:
	_house.from_dict({"lot_size": [96, 96], "format": 5})
	_house.floor_count = 1
	var writes: Array = []
	for c in HouseGrid.cells_in_rect(O, O + Vector2i(11, 6)):
		writes.append(HouseData.write(0, "foundation", HouseGrid.cell_key(c), {"item": "foundation_basic"}))
		writes.append(HouseData.write(0, "floors", HouseGrid.cell_key(c), {"item": "floor_basic"}))
	for edge in HouseGrid.edges_around_rect(O, O + Vector2i(11, 6)):
		writes.append(HouseData.write(0, "walls", edge, {"item": "wall_basic"}))
	# Una puerta en el frente: parte la pared de adelante en dos tramos rectos.
	writes.append(HouseData.write(0, "walls", "h:%d,%d" % [O.x + 2, O.y + 7], {"item": "wall_basic", "opening": "door_basic"}))
	_house.next_id = 10
	_house.apply(writes)
	var rig: CameraRig = _main.get_node("CameraRig")
	rig.set_state({"x": 0.0, "z": 20.0, "yaw": 0.0, "distance": 22.0, "pitch": -28.0})


func _wall_nodes() -> Array:
	var result: Array = []
	for key in _house.get_layer(0, "walls"):
		result.append([key, _view.get_piece_node(0, "walls", key)])
	return result


func _first_material(node: Node) -> Material:
	for child in node.find_children("*", "MeshInstance3D", true, false):
		return (child as MeshInstance3D).material_override
	return null


func _test_structure() -> void:
	print("\n1) Una caja de contorno por pared, sin contorno entre tramos")
	var outlines := _view.get_level_container(0).get_node_or_null("WallOutlines")
	# Frente: a la izquierda de la puerta 2 tramos y a la derecha 9; atrás 1 pared de 12; costados 2 de 7.
	_check(outlines != null and outlines.get_child_count() == 5, "hay 5 cajas (pared de atrás, dos costados y dos tramos del frente partidos por la puerta): %d" % (outlines.get_child_count() if outlines != null else -1))
	var flat_ok := true
	var opening_ok := false
	for entry in _wall_nodes():
		var wall: Dictionary = _house.get_piece(0, "walls", entry[0])
		var material := _first_material(entry[1])
		if wall.get("opening", "") == "":
			if material == null or (material as ShaderMaterial).next_pass != null:
				flat_ok = false
		elif material != null and (material as ShaderMaterial).next_pass != null:
			opening_ok = true
	_check(flat_ok, "los tramos macizos no tienen contorno propio (no hay línea entre un tramo y otro)")
	_check(opening_ok, "los de la puerta conservan el suyo")
	var holder_material := (outlines.get_child(0) as MeshInstance3D).material_override as ShaderMaterial
	_check(holder_material.next_pass != null, "la caja de la pared lleva el contorno")
	Style.set_outline(false)
	await _frames(2)
	_check(holder_material.next_pass == null, "con «Contorno» apagado en Info, también se apaga (más rápido)")
	Style.set_outline(true)
	await _frames(2)
	# Cambiar una pared vuelve a armar las cajas: agregar un tramo suelto.
	_house.apply([HouseData.write(0, "walls", "v:%d,%d" % [O.x + 12, O.y + 1], {"item": "wall_basic"})])
	await _frames(3)
	outlines = _view.get_level_container(0).get_node_or_null("WallOutlines")
	_check(outlines.get_child_count() == 5, "una pared pegada al costado se suma a su tramo recto (%d cajas)" % outlines.get_child_count())
	_house.apply([HouseData.write(0, "walls", "v:%d,%d" % [O.x + 12, O.y + 1], null)])
	await _frames(3)


## Cuántos píxeles oscuros (color del contorno) hay en una franja angosta
## sobre el cuerpo de una pared, justo en la juntura entre dos tramos.
func _dark_pixels_at_joint(label: String) -> int:
	var cam := get_viewport().get_camera_3d()
	var image := get_viewport().get_texture().get_image()
	var dark := 0
	var joint_x := float(O.x + 7)
	var z := float(O.y + 7) + HouseGrid.WALL_THICKNESS / 2.0 + 0.01
	var bottom: Vector3 = _main.get_node("House").to_global(Vector3(joint_x, 0.7, z))
	var top: Vector3 = _main.get_node("House").to_global(Vector3(joint_x, HouseGrid.WALL_HEIGHT - 0.5, z))
	var a := cam.unproject_position(bottom)
	var b := cam.unproject_position(top)
	for i in 41:
		var p := a.lerp(b, i / 40.0)
		for dx in range(-4, 5):
			var px := Vector2i(int(p.x) + dx, int(p.y))
			if px.x < 0 or px.y < 0 or px.x >= image.get_width() or px.y >= image.get_height():
				continue
			if image.get_pixelv(px).get_luminance() < 0.45:
				dark += 1
	return dark


func _test_seams() -> void:
	print("\n2) Costuras: antes y después, desde varios ángulos")
	var rig: CameraRig = _main.get_node("CameraRig")
	var angles := [[0.0, -28.0], [18.0, -20.0], [-35.0, -14.0], [60.0, -40.0]]
	var before_total := 0
	var after_total := 0
	for i in angles.size():
		rig.set_state({"x": 0.0, "z": 20.0, "yaw": angles[i][0], "distance": 22.0, "pitch": angles[i][1]})
		HouseView.seamless_outline = false
		_view.rebuild_all()
		await _frames(5)
		if i == 0:
			await _shot("p3c_1_antes_con_costuras.png")
		before_total += _dark_pixels_at_joint("antes")
		HouseView.seamless_outline = true
		_view.rebuild_all()
		await _frames(5)
		if i == 0:
			await _shot("p3c_2_despues_sin_costuras.png")
		after_total += _dark_pixels_at_joint("después")
	print("      píxeles oscuros en la juntura (4 ángulos): antes %d, después %d" % [before_total, after_total])
	_check(after_total <= before_total, "no hay más líneas que antes")
	_check(after_total == 0, "en la juntura de dos tramos NO queda ninguna línea oscura (%d píxeles)" % after_total)
	rig.set_state({"x": 0.0, "z": 20.0, "yaw": 25.0, "distance": 16.0, "pitch": -22.0})
	await _frames(4)
	await _shot("p3c_3_pared_continua.png")


func _test_fps() -> void:
	print("\n3) Rendimiento con contorno")
	HouseView.seamless_outline = false
	_view.rebuild_all()
	await _frames(4)
	var passes_before := _outline_passes()
	HouseView.seamless_outline = true
	_view.rebuild_all()
	await _frames(4)
	var passes_after := _outline_passes()
	print("      pasadas de contorno (llamadas de dibujo extra): antes %d, después %d" % [passes_before, passes_after])
	_check(passes_after < passes_before, "la pared completa pide MENOS pasadas de contorno que antes (%d → %d)" % [passes_before, passes_after])
	var rig: CameraRig = _main.get_node("CameraRig")
	rig.set_state({"x": 0.0, "z": 10.0, "yaw": 20.0, "distance": 40.0, "pitch": -40.0})
	var results := {}
	for outline in [true, false]:
		Style.set_outline(outline)
		await _frames(20)
		var start := Time.get_ticks_msec()
		await _frames(60)
		var ms := float(Time.get_ticks_msec() - start) / 60.0
		results[outline] = ms
	Style.set_outline(true)
	print("      cuadro: con contorno %.1f ms, sin contorno %.1f ms (en la nube, sin GPU: solo comparar)" % [results[true], results[false]])
	_check(results[true] <= results[false] * 1.35 + 2.0, "el contorno de la pared completa casi no suma tiempo por cuadro")


## Cuántas mallas de la casa llevan la pasada de contorno (cada una es una llamada de dibujo más).
func _outline_passes() -> int:
	var count := 0
	for node in _view.find_children("*", "MeshInstance3D", true, false):
		var material := (node as MeshInstance3D).material_override
		if material is ShaderMaterial and material.next_pass != null:
			count += 1
	return count


func _check(condition: bool, description: String) -> void:
	if condition:
		_passed += 1
		print("  OK     ", description)
	else:
		_failed += 1
		print("  FALLÓ  ", description)


func _shot(file_name: String) -> void:
	await _frames(3)
	get_viewport().get_texture().get_image().save_png(_shot_dir.path_join(file_name))
	_shots.append(file_name)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
