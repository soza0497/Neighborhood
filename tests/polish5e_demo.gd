extends Node
## Demostración del Pulido 5E (plantillas de casa / mudanza), con capturas.
##
##   godot --path . res://tests/polish5e_demo.tscn
## Capturas (p5e_*.png) a SHOT_DIR (o a user://). Partida local, sin servidor.
## Con servidor, colocar usa el mismo build_apply de siempre (lo revisa el servidor).

var _main: Node3D
var _hud: CanvasLayer
var _house: HouseData
var _builder: HouseBuilder
var _placer: TemplatePlacer
var _shot_dir := ""
var _passed := 0
var _failed := 0
var _shots: Array[String] = []


func _ready() -> void:
	_shot_dir = OS.get_environment("SHOT_DIR")
	if _shot_dir == "":
		_shot_dir = OS.get_user_data_dir()
	HouseGrid.LOT_SIZE = Vector2i(96, 96)
	HouseData.blocked_cells = {}
	HouseTemplates.autosave = false  # No tocar la partida de quien prueba.
	Economy.server_mode = false
	GameState.parcel = {"seed": 424242}
	GameState.settings = {}
	Parcel.setup_local({"seed": 424242})
	_main = preload("res://scenes/main.tscn").instantiate()
	add_child(_main)
	Economy.debug_unlock_all()
	_hud = _main.get_node("HUD")
	_house = _main.house
	_builder = _main.get_node("House/Builder")
	_placer = _main.get_node("House/TemplatePlacer")
	_run.call_deferred()


func _run() -> void:
	await _test_save_and_list()
	await _test_place_and_hologram()
	await _test_plan_and_undo()
	await _test_confirm_and_one_step_undo()
	print("\nDEMO PULIDO 5E: %d pasaron, %d fallaron · capturas: %s" % [_passed, _failed, ", ".join(_shots)])
	get_tree().quit(1 if _failed > 0 else 0)


func _origin() -> Vector2i:
	return HouseGrid.home_origin() + Vector2i(4, 4)


func _build_sample() -> void:
	var o := _origin()
	var far := o + Vector2i(7, 5)
	var writes: Array = []
	for c in HouseGrid.cells_in_rect(o, far):
		writes.append(HouseData.write(0, "foundation", HouseGrid.cell_key(c), {"item": "foundation_basic"}))
		writes.append(HouseData.write(0, "floors", HouseGrid.cell_key(c), {"item": "floor_basic", "color": "#f4d58d"}))
	for edge in HouseGrid.edges_around_rect(o, far):
		writes.append(HouseData.write(0, "walls", edge, {"item": "wall_basic", "color_a": "#cfe8ff"}))
	writes.append(HouseData.write(0, "walls", HouseGrid.edge_key(Vector2i(o.x + 3, far.y + 1), true), {"item": "wall_basic", "opening": "door_basic"}))
	writes.append(HouseData.write(0, "walls", HouseGrid.edge_key(Vector2i(o.x + 5, o.y), true), {"item": "wall_basic", "opening": "window_basic"}))
	writes.append(HouseData.write(0, "objects", "o2", {"item": "bed_basic", "cell": [o.x + 1, o.y + 1], "rot": 0}))
	writes.append(HouseData.write(0, "roofs", "o3", {"item": "roof_basic", "rect": [o.x, o.y, 8, 6]}))
	_house.from_dict({"lot_size": [96, 96], "format": 5})
	_house.next_id = 10
	_house.apply(writes)
	_main.get_node("House/Character").place_at(0, o + Vector2i(3, 3))
	_main.get_node("CameraRig").set_state({"x": 0.0, "z": 12.0, "yaw": 0.0, "distance": 40.0, "pitch": -60.0})


func _test_save_and_list() -> void:
	print("\n1) Guardar y ver la lista (panel «Casa»)")
	_build_sample()
	_main.set_mode("live")
	await _frames(6)
	var panel: Control = _hud.get_node("HomePanel")
	panel.open()
	await _frames(4)
	_check(panel.visible, "el panel de la casa se abre")
	panel._new_name = "Casita roja"
	panel._on_save_template()
	await _frames(3)
	var list := HouseTemplates.all()
	_check(list.size() == 1 and list[0]["name"] == "Casita roja", "se guardó «Casita roja»")
	var kinds_ok := true
	for piece in list[0]["pieces"]:
		if piece["y"] == "objects":
			kinds_ok = false  # La cama no viaja.
	_check(kinds_ok, "la plantilla no lleva la cama")
	panel._new_name = "Segunda"
	panel._on_save_template()
	panel._on_start_rename(list[0]["id"])
	await _frames(2)
	_check(panel._renaming_id == list[0]["id"], "se puede renombrar desde el panel")
	panel._on_cancel_rename()
	await _frames(2)
	await _shot("p5e_1_panel_plantillas.png")
	panel.hide()
	HouseTemplates.remove(HouseTemplates.all()[1]["id"])
	_check(HouseTemplates.all().size() == 1, "se puede borrar una")


func _test_place_and_hologram() -> void:
	print("\n2) Colocar: silueta verde si cabe, roja si choca")
	var id: String = HouseTemplates.all()[0]["id"]
	# Se coloca con la casa original en pie: ahí choca. Más a la derecha cabe.
	_main.set_mode("build")
	await _frames(4)
	EventBus.template_place_requested.emit(id)
	await _frames(4)
	_check(_placer.active, "se activó el modo de colocar")
	_placer.set_offset(_origin() + Vector2i(2, 1))
	await _frames(3)
	_check(not _placer.last_check["valid"] and _placer.last_check["reason"] == "occupied", "encima de la casa: roja (ocupado)")
	await _shot("p5e_2_silueta_roja.png")
	_placer.set_offset(_origin() + Vector2i(14, 0))
	await _frames(3)
	_check(_placer.last_check["valid"], "al costado, en el lote libre: verde (%s)" % _placer.last_check.get("reason", ""))
	await _shot("p5e_3_silueta_verde.png")
	_placer.set_offset(Vector2i(-10, 10))
	await _frames(3)
	_check(not _placer.last_check["valid"], "fuera del lote: roja")
	_placer.cancel()
	await _frames(2)
	_check(not _placer.active, "cancelar sale del modo")
	_check(_house.get_layer(0, "walls").size() == _expected_walls(), "cancelar no construye nada")


func _expected_walls() -> int:
	return 2 * (8 + 6)


func _test_plan_and_undo() -> void:
	print("\n3) Entra por el plan y se saca de un solo paso")
	var id: String = HouseTemplates.all()[0]["id"]
	EventBus.template_place_requested.emit(id)
	await _frames(3)
	_placer.set_offset(_origin() + Vector2i(14, 0))
	await _frames(2)
	var money_before := Economy.money
	var ok: bool = await _placer.confirm()
	await _frames(3)
	_check(ok and _builder.draft_mode() == "plan", "quedó en el plan (sin pagar todavía)")
	_check(Economy.money == money_before, "todavía no se cobró")
	var invoice := _builder.plan_invoice()
	_check(int(invoice["total"]) > 0 and not (invoice["lines"] as Array).is_empty(), "la factura tiene líneas y total (%d)" % int(invoice["total"]))
	await _shot("p5e_4_plan.png")
	_check(_house.get_layer(0, "walls").size() == 2 * _expected_walls(), "las piezas se ven previstas en la casa")
	_builder.draft_undo()
	await _frames(2)
	_check(not _builder.has_draft() and _house.get_layer(0, "walls").size() == _expected_walls(), "deshacer saca TODA la plantilla de un solo paso")


func _test_confirm_and_one_step_undo() -> void:
	print("\n4) Confirmar la factura cobra y es un solo paso de deshacer")
	var id: String = HouseTemplates.all()[0]["id"]
	EventBus.template_place_requested.emit(id)
	await _frames(3)
	_placer.set_offset(_origin() + Vector2i(14, 0))
	await _frames(2)
	await _placer.confirm()
	await _frames(2)
	var cost: int = int(_builder.plan_invoice()["total"])
	var money_before := Economy.money
	var applied: bool = await _builder.confirm_plan()
	await _frames(3)
	_check(applied and not _builder.has_draft(), "la factura se confirmó")
	_check(Economy.money == money_before - cost, "se cobró lo de la factura ($%d)" % cost)
	_check(_house.get_layer(0, "walls").size() == 2 * _expected_walls(), "la casa nueva está construida")
	var furniture := 0
	for key in _house.get_layer(0, "objects"):
		furniture += 1
	_check(furniture == 1, "muebles: solo la cama de la casa original (la copia no trae)")
	var history: UndoHistory = _main.history
	history.undo()
	await _frames(3)
	_check(_house.get_layer(0, "walls").size() == _expected_walls(), "un solo «Deshacer» saca toda la copia")
	_check(Economy.money == money_before, "y devuelve lo que costó")
	await _shot("p5e_5_despues_de_deshacer.png")


func _check(condition: bool, description: String) -> void:
	if condition:
		_passed += 1
		print("  OK     ", description)
	else:
		_failed += 1
		print("  FALLÓ  ", description)


func _shot(file_name: String) -> void:
	await _frames(4)
	get_viewport().get_texture().get_image().save_png(_shot_dir.path_join(file_name))
	_shots.append(file_name)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
