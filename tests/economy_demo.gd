extends Node
## Demostración de la economía con precios reales: construye con dinero de
## verdad, muestra piezas bloqueadas, una obra con temporizador, el panel de
## empleos y los avisos. Saca capturas.
##
##   godot --path . res://tests/economy_demo.tscn
## Capturas en SHOT_DIR (o user://). OJO: pisa la partida guardada.

var _main: Node3D
var _builder: HouseBuilder
var _house: Node3D
var _camera: Camera3D
var _shot_dir := ""
const O := Vector2(10, 10)


func _ready() -> void:
	HouseGrid.use_test_lot()  # Estas pruebas arman casas en un lote de 32 (la parcela real, desde el Pulido 2C, es de 96).
	_shot_dir = OS.get_environment("SHOT_DIR")
	if _shot_dir == "":
		_shot_dir = OS.get_user_data_dir()
	_main = preload("res://scenes/main.tscn").instantiate()
	add_child(_main)
	_builder = _main.get_node("House/Builder")
	_builder.plan_enabled = false  # Estas pruebas construyen de una (sin plan ni factura).
	_house = _main.get_node("House")
	_camera = get_viewport().get_camera_3d()
	_run.call_deferred()


func _run() -> void:
	_main.house.clear()
	Economy.from_dict({})  # Partida nueva: dinero inicial, nivel 1.
	_main.set_mode("build")
	EventBus.camera_reset_requested.emit()
	await _frames(3)
	var start := Economy.money

	await _drag("foundation_basic", Vector2(2.5, 2.5), Vector2(7.5, 6.5))
	await _drag("room_basic", Vector2(2.5, 2.5), Vector2(7.5, 6.5))
	print("Cimientos + cuarto de 6x5: pagaste $%d, nivel %d, experiencia %d" % [start - Economy.money, Economy.level(), Economy.xp])

	# Una pieza bloqueada por nivel no se puede elegir.
	EventBus.build_item_selected.emit("stairs_basic")
	print("Escalera elegida a nivel 1: herramienta = %d (0 = ninguna) -> %s" % [_builder.tool, "OK" if _builder.tool == HouseBuilder.Tool.NONE else "FALLÓ"])

	# Un mueble con obra (30 s).
	var before := Economy.money
	await _drag("fridge_basic", Vector2(3.5, 3.5), Vector2(3.5, 3.5))
	print("Refrigeradora: pagaste $%d; obras pendientes: %d" % [before - Economy.money, _main.house.pending_construction().size()])
	await get_tree().create_timer(1.2).timeout
	EventBus.build_item_selected.emit("")
	_main.get_node("HUD/Root/Layout/BottomBar").visible = true
	await _shot("e1_obra.png")

	# Acelerar.
	before = Economy.money
	EventBus.construction_accelerate_requested.emit()
	await _frames(4)
	print("Acelerar: pagaste $%d; obras pendientes: %d" % [before - Economy.money, _main.house.pending_construction().size()])
	await _shot("e2_acelerada.png")

	# Empleos.
	EventBus.jobs_requested.emit()
	await _shot("e3_empleos.png")
	Economy.apply_for_job("courier")
	await get_tree().create_timer(1.2).timeout
	await _shot("e4_curriculum.png")
	_main.get_node("HUD/JobsPanel").hide()

	# Subir de nivel.
	Economy.add_xp(100)
	await _frames(4)
	await _shot("e5_nivel.png")

	# Turno de trabajo: el personaje sale a la acera, desaparece y cobra al volver.
	Catalog.jobs["courier"]["shift_hours"] = 1  # Turno corto para la demo.
	Economy.job_id = "courier"
	Economy.last_work_day = 0
	GameClock.minutes = 9 * 60 + 1.0
	_main.set_mode("live")
	GameClock.speed = 5
	var character: Character = _main.get_node("House/Character")
	var money_before := Economy.money
	var waited := 0.0
	while character.state != Character.State.WORKING and waited < 10.0:
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	print("Trabajo: personaje %s, visible = %s -> %s" % [
		character.get_intention()["verb"], character.visible,
		"OK" if character.state == Character.State.WORKING and not character.visible else "FALLÓ"])
	await _shot("e6_trabajando.png")
	waited = 0.0
	while character.state == Character.State.WORKING and waited < 20.0:
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	print("Turno cobrado: $%d (se esperaban 30), visible = %s -> %s" % [
		Economy.money - money_before, character.visible,
		"OK" if Economy.money - money_before == 30 and character.visible else "FALLÓ"])
	await _shot("e7_volvio.png")

	print("Dinero final: $%d · nivel %d" % [Economy.money, Economy.level()])
	get_tree().quit()


func _drag(item_id: String, from: Vector2, to: Vector2) -> void:
	EventBus.build_item_selected.emit(item_id)
	var start := _to_screen(from + O)
	var end := _to_screen(to + O)
	_builder._begin(start)
	for i in range(1, 5):
		_builder._update(start.lerp(end, i / 4.0))
	_builder._release()
	_builder.confirm_pending()
	await _frames(2)


func _to_screen(grid_pos: Vector2) -> Vector2:
	var local := Vector3(grid_pos.x, HouseGrid.level_y(_builder.level), grid_pos.y)
	return _camera.unproject_position(_house.to_global(local))


func _shot(file_name: String) -> void:
	await _frames(4)
	get_viewport().get_texture().get_image().save_png(_shot_dir.path_join(file_name))


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
