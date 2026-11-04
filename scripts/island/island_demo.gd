extends Node
## Demo de la isla (Isla 1A, prototipo de rendimiento y niveles de detalle).
##
##   godot --path . res://tests/island_demo.tscn
## (tests/island_demo.tscn solo instancia scenes/island/island_demo.tscn: el script vive en
## scripts/island/ porque la exportación a Android deja afuera la carpeta tests/ y así la
## demo también viaja en el APK: Menú → Info → «Herramientas de prueba» → «Prueba de isla».)
## Medición automática sin tocar nada (imprime la tabla y sale):
##   ISLAND_BENCH=1 SHOT_DIR=docs/capturas godot --path . res://tests/island_demo.tscn
##
## Teclas (en el teléfono, los botones de abajo hacen lo mismo):
##   0 1 2 3  fuerza ese nivel de detalle en todo     A  automático por distancia
##   O  contorno sí/no     H  sombras sí/no     M  humo del volcán     F  mostrar/ocultar números
##   F1  30 lotes    F2  60 lotes (estrés)    F3  100 casas en LOD 1 (estrés)    F4  100 casas en LOD 2
##   P  guarda una captura en SHOT_DIR (o user://)     B  mide y arma la tabla     Esc  volver
##   Flechas mueven la cámara · Q/E giran · + / - acercan y alejan (o mouse / dos dedos).
## No guarda nada del juego.

const RIG_SCENE := preload("res://scenes/camera_rig.tscn")

var _rig: CameraRig
var _world: IslandWorld
var _stress: IslandStress
var _sun: DirectionalLight3D
var _env: Environment
var _ui: CanvasLayer
var _label: Label
var _shot_dir := ""
var _shot_index := 0
var _lot_count := 30
var _mode := "isla"   # "isla" (lotes) o "grid" (casas en cuadrícula)
var _stat_timer := 0.0
var _busy := false
var _show_stats := true
var _smoke_on := true
var _result_panel: PanelContainer
var _result_label: Label


func _ready() -> void:
	_shot_dir = OS.get_environment("SHOT_DIR")
	if _shot_dir == "":
		_shot_dir = OS.get_user_data_dir()
	HouseGrid.LOT_SIZE = Vector2i(96, 96)
	NeighborhoodMap.reload()
	IslandData.reload()
	_build_environment()
	_rig = RIG_SCENE.instantiate()
	add_child(_rig)
	_rig.camera_node().current = true
	_rig.enter_island_view(IslandData.island_radius() + 80.0, 1250.0, 3000.0, 1.0)
	_build_ui()
	_build_island(30)
	_goto_preset(0)
	if OS.get_environment("ISLAND_BENCH") == "1":
		_auto_bench.call_deferred()


func _build_environment() -> void:
	_env = Environment.new()
	var holder := WorldEnvironment.new()
	holder.environment = _env
	add_child(holder)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-52.0, -30.0, 0.0)
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 140.0
	add_child(_sun)
	Style.apply_world(_sun, _env)
	# La niebla del juego (70-190 m) taparía la isla: aquí empieza lejos.
	_env.fog_depth_begin = 700.0
	_env.fog_depth_end = 2800.0


# --- Isla y estrés ---

func _clear_content() -> void:
	if _world != null:
		remove_child(_world)
		_world.queue_free()
		_world = null
	if _stress != null:
		remove_child(_stress)
		_stress.queue_free()
		_stress = null


## Isla con `count` lotes. Con más de los 30 del comienzo, todos los lotes tienen vecino.
func _build_island(count: int) -> void:
	_clear_content()
	_mode = "isla"
	_lot_count = count
	var lots: Array = []
	for l in IslandData.lots_for_count(count):
		var copy: Dictionary = (l as Dictionary).duplicate()
		if count > int(IslandData.rule("start_lots", 30)) and str(copy["state"]) != "player":
			copy["state"] = "npc"
		lots.append(copy)
	_world = IslandWorld.new()
	_world.name = "Island"
	add_child(_world)
	_world.setup(_rig.camera_node(), lots, {"smoke": _smoke_on})
	_world.refresh()
	_world.apply_pending(true)


func _build_grid(level: int) -> void:
	_clear_content()
	_mode = "grid"
	var cfg := IslandData.section("demo")
	_stress = IslandStress.new()
	_stress.name = "Stress"
	add_child(_stress)
	_stress.setup(int(cfg.get("stress_houses", 100)), float(cfg.get("stress_spacing", 52.0)))
	_stress.set_level(level)
	var extent := _stress.extent()
	_rig.fly_to(Vector3.ZERO, extent * 1.9, 0.0)
	_rig.set_pitch(-55.0)


func _goto_preset(index: int) -> void:
	var presets: Array = IslandData.section("demo").get("presets", [])
	if presets.is_empty() or _mode != "isla":
		return
	var preset: Dictionary = presets[clampi(index, 0, presets.size() - 1)]
	var focus := Vector3.ZERO
	var key := str(preset.get("focus", "center"))
	if key == "player":
		for l in _world.lots:
			if str(l["state"]) == "player":
				focus = IslandData.lot_center(l)
	elif key != "center":
		var l := IslandData.lot(key)
		if not l.is_empty():
			focus = IslandData.lot_center(l)
	_rig.rotation_degrees.y = float(preset.get("yaw", 0.0))
	_rig.set_pitch(float(preset.get("pitch", -50.0)))
	_rig.fly_to(focus, float(preset.get("distance", 100.0)), 0.0)
	_world.refresh()


# --- Interfaz ---

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.14, 0.72)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	panel.position = Vector2(8, 8)
	_ui.add_child(panel)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 16)
	panel.add_child(_label)
	_build_result_panel()
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", style)
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = 8
	bar.offset_right = -8
	bar.offset_bottom = -8
	bar.offset_top = -120
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_ui.add_child(bar)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	bar.add_child(flow)
	for entry in [
		["LOD 0", func() -> void: _force(0)], ["LOD 1", func() -> void: _force(1)], ["LOD 2", func() -> void: _force(2)],
		["LOD 3", func() -> void: _force(3)], ["Auto", func() -> void: _force(-1)],
		["Contorno", func() -> void: _toggle_outline()], ["Sombras", func() -> void: _toggle_shadows()],
		["Humo", func() -> void: _toggle_smoke()], ["Números", func() -> void: _show_stats = not _show_stats],
		["30 lotes", func() -> void: _build_island(30)], ["60 lotes", func() -> void: _build_island(60)],
		["100 casas L1", func() -> void: _build_grid(1)], ["100 casas L2", func() -> void: _build_grid(2)],
		["Calle", func() -> void: _goto_preset(0)], ["Barrio", func() -> void: _goto_preset(1)], ["Isla", func() -> void: _goto_preset(2)],
		["Captura", func() -> void: _save_shot("manual")], ["Medir", func() -> void: _run_benchmark()],
		["Volver", func() -> void: _back()],
	]:
		var button := Button.new()
		button.text = entry[0]
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(0, 40)
		button.add_theme_font_size_override("font_size", 16)
		button.pressed.connect(entry[1])
		flow.add_child(button)


## Panel con el resultado de la medición (en el teléfono no hay consola: se lee acá y se saca una captura).
func _build_result_panel() -> void:
	_result_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.14, 0.92)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(12)
	_result_panel.add_theme_stylebox_override("panel", style)
	_result_panel.anchor_right = 1.0
	_result_panel.anchor_bottom = 1.0
	_result_panel.offset_left = 12
	_result_panel.offset_top = 12
	_result_panel.offset_right = -12
	_result_panel.offset_bottom = -12
	_result_panel.visible = false
	_ui.add_child(_result_panel)
	var column := VBoxContainer.new()
	_result_panel.add_child(column)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_result_label = Label.new()
	_result_label.add_theme_font_size_override("font_size", 15)
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_result_label)
	var close := Button.new()
	close.text = "Cerrar"
	close.custom_minimum_size = Vector2(0, 44)
	close.pressed.connect(func() -> void: _result_panel.visible = false)
	column.add_child(close)


func _force(level: int) -> void:
	if _mode == "grid":
		if level >= 0 and level <= 2:
			_stress.set_level(level)
		return
	_world.set_forced_level(level)
	_world.apply_pending(true)


func _toggle_outline() -> void:
	Style.set_outline(not Style.outline_enabled)
	IslandMaterials.sync_outline()


func _toggle_shadows() -> void:
	_sun.shadow_enabled = not _sun.shadow_enabled


func _toggle_smoke() -> void:
	_smoke_on = not _smoke_on
	if _world != null:
		_world.set_smoke_visible(_smoke_on)


func _back() -> void:
	get_tree().change_scene_to_file(str(ProjectSettings.get_setting("application/run/main_scene")))


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if _busy or key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_0: _force(0)
		KEY_1: _force(1)
		KEY_2: _force(2)
		KEY_3: _force(3)
		KEY_A: _force(-1)
		KEY_O: _toggle_outline()
		KEY_H: _toggle_shadows()
		KEY_M: _toggle_smoke()
		KEY_F: _show_stats = not _show_stats
		KEY_F1: _build_island(30)
		KEY_F2: _build_island(60)
		KEY_F3: _build_grid(1)
		KEY_F4: _build_grid(2)
		KEY_P: _save_shot("manual")
		KEY_B: _run_benchmark()
		KEY_ESCAPE: _back()


func _process(delta: float) -> void:
	_move_camera(delta)
	_stat_timer += delta
	if _stat_timer >= 0.25:
		_stat_timer = 0.0
		_label.get_parent().visible = _show_stats and not _busy
		_label.text = _stats_text()


## Flechas, Q/E y +/- (para probar en la PC; en el teléfono se usan los dedos).
func _move_camera(delta: float) -> void:
	if _busy:
		return
	var direction := Vector3.ZERO
	if Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1.0
	if Input.is_key_pressed(KEY_UP):
		direction.z -= 1.0
	if Input.is_key_pressed(KEY_DOWN):
		direction.z += 1.0
	if direction != Vector3.ZERO:
		var speed := maxf(20.0, _rig.current_distance() * 0.9)
		_rig.focus_on(_rig.position + _rig.basis * direction.normalized() * speed * delta)
	if Input.is_key_pressed(KEY_Q):
		_rig.rotation_degrees.y += 60.0 * delta
	if Input.is_key_pressed(KEY_E):
		_rig.rotation_degrees.y -= 60.0 * delta
	var zoom := 0.0
	if Input.is_key_pressed(KEY_EQUAL) or Input.is_key_pressed(KEY_KP_ADD):
		zoom -= 1.0
	if Input.is_key_pressed(KEY_MINUS) or Input.is_key_pressed(KEY_KP_SUBTRACT):
		zoom += 1.0
	if zoom != 0.0:
		_rig.fly_to(_rig.position, _rig.current_distance() * (1.0 + zoom * 1.4 * delta), 0.0)


func _root_for_stats() -> Node:
	return _world if _world != null else _stress


func _stats_text() -> String:
	var info := IslandStats.rendering()
	var estimate := IslandStats.estimate(_root_for_stats())
	var lines: Array[String] = []
	lines.append("FPS %d · %s" % [Engine.get_frames_per_second(), _mode_text()])
	lines.append("Dibujo (motor): %d llamadas · %s triángulos" % [info["draws"], _thousands(int(info["triangles"]))])
	lines.append("Dibujo (estimado de la isla): %d llamadas · %s triángulos" % [estimate["draws"], _thousands(int(estimate["triangles"]))])
	if _world != null:
		var counts := _world.shown_counts()
		lines.append("Casas: LOD0 %d · LOD1 %d · LOD2 %d · LOD3 %d · esperando %d" % [counts[0], counts[1], counts[2], counts[3], _world.pending_count()])
		lines.append("Vegetación: %d/%d trozos, %d árboles · mapa: %s" % [_world.visible_chunk_count(), _world.chunk_count(), _world.tree_count, "sí" if _world.map_visible() else "no"])
	lines.append("Contorno: %s · Sombras: %s · Cámara a %d m" % ["sí" if Style.outline_enabled else "no", "sí" if _sun.shadow_enabled else "no", int(_rig.camera_node().global_position.length())])
	return "\n".join(lines)


func _mode_text() -> String:
	if _mode == "grid":
		return "estrés: %d casas en LOD %d" % [_stress.count, _stress.level]
	var forced := "automático" if _world.forced_level < 0 else "LOD %d forzado" % _world.forced_level
	return "%d lotes · %s" % [_lot_count, forced]


static func _thousands(value: int) -> String:
	return "%.1fk" % (value / 1000.0) if value >= 1000 else str(value)


# --- Capturas ---

func _save_shot(tag: String) -> void:
	_shot_index += 1
	var file_name := "isla_%s_%02d.png" % [tag, _shot_index]
	var path := _shot_dir.path_join(file_name)
	get_viewport().get_texture().get_image().save_png(path)
	print("Captura guardada: ", path)


# --- Medición ---

func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


## Mide unos segundos: FPS, peor cuadro, llamadas de dibujo y triángulos (promedios).
func _measure() -> Dictionary:
	var cfg := IslandData.section("demo")
	await _frames(int(cfg.get("warmup_frames", 40)))
	var seconds := float(cfg.get("measure_seconds", 2.0))
	var start := Time.get_ticks_usec()
	var last := start
	var frames := 0
	var draws := 0
	var triangles := 0
	var worst_ms := 0.0
	while float(Time.get_ticks_usec() - start) < seconds * 1000000.0:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		worst_ms = maxf(worst_ms, float(now - last) / 1000.0)
		last = now
		var info := IslandStats.rendering()
		draws += int(info["draws"])
		triangles += int(info["triangles"])
		frames += 1
	var elapsed := float(Time.get_ticks_usec() - start) / 1000000.0
	var estimate := IslandStats.estimate(_root_for_stats())
	return {
		"fps": float(frames) / maxf(elapsed, 0.001), "worst_ms": worst_ms,
		"draws": draws / maxi(frames, 1), "triangles": triangles / maxi(frames, 1),
		"est_draws": estimate["draws"], "est_triangles": estimate["triangles"],
	}


func _run_benchmark() -> void:
	if _busy:
		return
	_busy = true
	_ui.visible = false
	var rows: Array = []
	var presets: Array = IslandData.section("demo").get("presets", [])
	# 1) La isla de 30 lotes: cada vista × cada nivel forzado y el automático.
	_build_island(30)
	for p in presets.size():
		for forced in [0, 1, 2, 3, -1]:
			_goto_preset(p)
			_world.set_forced_level(forced)
			_world.apply_pending(true)
			var result: Dictionary = await _measure()
			result["view"] = str(presets[p]["name"])
			result["mode"] = "30 lotes · " + ("auto" if forced < 0 else "LOD %d" % forced)
			rows.append(result)
			if forced == -1 or forced == 1:
				_save_shot("%s_%s" % [str(presets[p]["name"]), "auto" if forced < 0 else "lod%d" % forced])
	# 2) La isla completa: 60 lotes, automático, vista del barrio y de toda la isla.
	_build_island(60)
	for p in [1, 2]:
		_goto_preset(p)
		_world.set_forced_level(-1)
		_world.apply_pending(true)
		await _frames(5)
		_world.apply_pending(true)
		var result60: Dictionary = await _measure()
		result60["view"] = str(presets[p]["name"])
		result60["mode"] = "60 lotes · auto"
		rows.append(result60)
	# 3) 100 casas juntas: LOD 1 (el techo) y LOD 2 (agrupadas).
	for level in [1, 2]:
		_build_grid(level)
		var grid_result: Dictionary = await _measure()
		grid_result["view"] = "arriba"
		grid_result["mode"] = "100 casas · LOD %d" % level
		rows.append(grid_result)
		_save_shot("grid_lod%d" % level)
	_build_island(30)
	_goto_preset(0)
	_ui.visible = true
	_busy = false
	_print_table(rows)


func _print_table(rows: Array) -> void:
	var lines: Array[String] = []
	lines.append("| Vista | Modo | FPS | Peor cuadro (ms) | Llamadas de dibujo | Triángulos | Estimado (llamadas / triángulos) |")
	lines.append("|---|---|---:|---:|---:|---:|---:|")
	for r in rows:
		lines.append("| %s | %s | %.0f | %.1f | %d | %d | %d / %d |" % [r["view"], r["mode"], r["fps"], r["worst_ms"],
			r["draws"], r["triangles"], r["est_draws"], r["est_triangles"]])
	var text := "\n".join(lines)
	print("\nTABLA DE LA ISLA (%s, %s)\n%s\n" % [OS.get_name(), RenderingServer.get_video_adapter_name(), text])
	var file := FileAccess.open(_shot_dir.path_join("isla_tabla.md"), FileAccess.WRITE)
	if file != null:
		file.store_string(text + "\n")
		file.close()
	# Versión corta para leer en la pantalla del teléfono.
	var compact: Array[String] = ["RESULTADO (sacá una captura de esta pantalla)", "%s · %s" % [OS.get_name(), RenderingServer.get_video_adapter_name()], ""]
	for r in rows:
		compact.append("%s · %s: %.0f FPS (peor cuadro %.0f ms) · %d llamadas · %s triáng." % [r["view"], r["mode"], r["fps"], r["worst_ms"],
			r["draws"], _thousands(int(r["triangles"]))])
	compact.append("")
	compact.append("Tabla guardada en: " + _shot_dir.path_join("isla_tabla.md"))
	_result_label.text = "\n".join(compact)
	_result_panel.visible = true


func _auto_bench() -> void:
	await _frames(10)
	await _run_benchmark()
	get_tree().quit(0)
