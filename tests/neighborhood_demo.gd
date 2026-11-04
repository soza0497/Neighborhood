extends Node
## Demostración de la Fase 8 (barrio), con capturas.
##
##   godot --path . res://tests/neighborhood_demo.tscn
## Las capturas (n8*.png) van a SHOT_DIR (o a user://). Partida local, sin servidor.
## NO guarda nada en disco.

var _main: Node3D
var _ctrl: NeighborhoodController
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
	Economy.server_mode = false
	Economy.xp = 0
	GameState.parcel = {"seed": 424242}
	GameState.settings = {}
	Parcel.setup_local({"seed": 424242})
	NeighborhoodMap.reload()
	_main = preload("res://scenes/main.tscn").instantiate()
	add_child(_main)
	_ctrl = _main.get_node("NeighborhoodController")
	_run.call_deferred()


func _run() -> void:
	await _frames(10)
	await _test_8a()
	await _test_8b()
	await _test_8c()
	await _test_8d()
	await _test_privacy_saved()
	print("\nDEMO BARRIO: %d pasaron, %d fallaron · capturas: %s" % [_passed, _failed, ", ".join(_shots)])
	get_tree().quit(1 if _failed > 0 else 0)


func _rig() -> CameraRig:
	return _main.get_node("CameraRig")


func _test_8a() -> void:
	print("\n1) 8A: el barrio alrededor de tu parcela")
	var world: WorldBuilder = _main.get_node("World")
	var nb := world.neighborhood
	_check(nb != null and nb.houses.size() == NeighborhoodMap.house_lots().size(), "se dibujaron %d casas de vecinos" % nb.houses.size())
	_check(nb.lamp_positions.size() > 20 and nb.tree_positions.size() > 10, "farolas (%d) y árboles de acera (%d)" % [nb.lamp_positions.size(), nb.tree_positions.size()])
	# La casa que se ve detrás de la valla es la del lote vecino del mapa.
	var sides := NeighborhoodMap.side_lots()
	var side_house: NeighborHouseView = nb.house(sides["right"])
	var fence_x := float(Parcel.zone_bounds().end.x) - 48.0
	_check(side_house != null and side_house.position.x > fence_x, "la casa del lote vecino (%s, familia %s) está detrás de la valla derecha" % [sides["right"], side_house.family])
	_check(world.get_node("ZoneDecor").get_node_or_null("SideNeighbors") == null, "ya no hay casa de azar: sale del mapa")
	# Casa de frente, mirando a la derecha para ver la valla y la casa vecina.
	_rig().position = Vector3(40, 0, 20)
	_rig().rotation_degrees.y = 90.0
	await _shot("n8a_valla_vecino.png")
	_rig().position = Vector3(0, 0, 30)
	_rig().rotation_degrees.y = 0.0
	await _shot("n8a_calle_frente.png")


func _test_8b() -> void:
	print("\n2) 8B: vista aérea y visitas")
	var camera_before := _rig().get_state()
	_ctrl.enter_aerial()
	await _frames(200)
	_check(_ctrl.state == "aerial" and _main.mode == "visit", "vista aérea: el juego queda en modo solo ver")
	_check(not _main.get_node("HUD").visible, "la interfaz normal se esconde")
	_check(_rig().current_distance() > 100.0, "zoom lejano (%.0f m)" % _rig().current_distance())
	await _shot("n8b_aerea.png")
	_rig().rotation_degrees.y += 90.0
	await _shot("n8b_aerea_girada.png")
	# Visitar una casa vecina.
	var target := "n_r1"
	_ctrl.visit(target)
	await _frames(70)
	var nb: NeighborhoodBuilder = _main.get_node("World").neighborhood
	_check(_ctrl.state == "visit" and _ctrl.lot_id == target, "visita: estado y lote")
	_check(nb.house(target).interior_on, "la casa visitada se ve por dentro")
	_check(_main.mode == "visit", "modo solo ver: sin constructor ni personaje controlable")
	await _shot("n8b_visita_%s.png" % target)
	_ctrl.visit("s_03")
	await _frames(70)
	_check(not nb.house(target).interior_on and nb.house("s_03").interior_on, "al pasar a otra casa, la anterior vuelve a silueta")
	await _shot("n8b_visita_s_03.png")
	_ctrl.visit("park")
	await _frames(70)
	await _shot("n8b_plazoleta.png")
	_ctrl.return_home()
	await _frames(5)
	_check(_ctrl.state == "" and _main.mode == "live", "volver: modo vivir")
	_check(_main.get_node("HUD").visible, "la interfaz vuelve")
	_check(not nb.house("s_03").interior_on, "se desarma el interior")
	var camera_after := _rig().get_state()
	_check(absf(camera_after["x"] - camera_before["x"]) < 0.5 and absf(camera_after["distance"] - camera_before["distance"]) < 0.5,
		"la cámara queda como estaba")
	await _shot("n8b_vuelta.png")


func _test_8c() -> void:
	print("\n3) 8C: vida del barrio")
	var life: NeighborhoodLife = _main.get_node("World").neighborhood.life
	# Adelantamos el reloj para que los vecinos ya estén en la calle.
	for i in 900:
		life.step(0.1)
	var out := 0
	for w in life.walkers:
		if (w["node"] as Node3D).visible or not w["hidden"]:
			out += 1
	_check(out > 0, "hay vecinos afuera (%d) y autos (%d)" % [out, life.cars.size()])
	_ctrl.enter_aerial()
	await _frames(70)
	_rig().fly_to(Vector3(0, 0, 50), 45.0, 0.0)
	await _shot("n8c_vida_calle.png")
	var fps := Engine.get_frames_per_second()
	print("  FPS medidos en esta máquina (no cuenta como prueba del teléfono): %d" % fps)
	_ctrl.return_home()
	await _frames(5)


func _test_8d() -> void:
	print("\n4) 8D: meta del barrio por participación")
	GameState.settings.erase("neighborhood_goal")
	var writes: Array = []
	for i in 4:
		writes.append(HouseData.write(0, "objects", "plant%d" % i, {"item": "plant_pot", "cell": [40 + i * 2, 70], "rot": 0}))
	_main.house.apply(writes)
	_ctrl.panel.open()
	await _frames(10)
	var s := NeighborhoodGoal.summary()
	_check(s["mine"] == 4 and s["today"] == 4, "las 4 plantas de la casa suman a la meta (aporte %d)" % s["mine"])
	_check(s["total"] == s["mine"] + s["neighbors"] and not s["completed"], "total = vecinos simulados + yo; todavía no se cumple")
	await _shot("n8d_meta_panel.png")
	_ctrl.panel.hide()
	_main.house.apply([HouseData.write(0, "objects", "plant0", null)])
	NeighborhoodGoal.refresh()
	_check(NeighborhoodGoal.summary()["mine"] == 4, "sacar una planta no resta lo acreditado")
	GameState.settings.erase("neighborhood_goal")


func _test_privacy_saved() -> void:
	print("\n5) Privacidad: «Mi casa se puede visitar»")
	_check(not NeighborhoodMap.is_my_house_visitable(), "empieza apagado")
	NeighborhoodMap.set_my_house_visitable(true)
	var saved := GameState.to_dict()
	GameState.from_dict(saved)
	_check(NeighborhoodMap.is_my_house_visitable(), "se guarda en la partida")
	NeighborhoodMap.set_my_house_visitable(false)


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
