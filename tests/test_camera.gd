extends Node
## Pruebas de la cámara (Pulido 5B), sin pantalla ni red.
##
##   godot --headless --path . res://tests/test_camera.tscn
##
## Mira: ángulo mínimo desde data/camera.json, controles de cámara baja (lados,
## avance lento con zona muerta), velocidad proporcional a la distancia con
## topes, y el límite suave a la parcela usable (solo en la vista normal).

var _passed := 0
var _failed := 0
var _rig: CameraRig


func _ready() -> void:
	HouseGrid.LOT_SIZE = Vector2i(96, 96)
	HouseData.blocked_cells = {}
	_test_statics()
	await _make_rig()
	_test_pitch_limit()
	_test_low_pitch_controls()
	_test_speed_by_distance()
	_test_lot_limit()
	_test_neighborhood_keeps_limits()
	print("\nPRUEBAS: %d pasaron, %d fallaron" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _check(condition: bool, description: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		print("FALLÓ: ", description)


## Una cámara armada a mano (la misma estructura que scenes/camera_rig.tscn).
func _make_rig() -> void:
	_rig = CameraRig.new()
	var pitch := Node3D.new()
	pitch.name = "Pitch"
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	pitch.add_child(cam)
	_rig.add_child(pitch)
	add_child(_rig)
	await get_tree().process_frame
	_rig.set_process(false)  # Las pruebas gastan el movimiento a mano (flush_pending).


func _test_statics() -> void:
	print("1) Funciones puras")
	_check(CameraRig.cap_length(Vector3(10, 0, 0), 3.0).is_equal_approx(Vector3(3, 0, 0)), "cap_length recorta al tope")
	_check(CameraRig.cap_length(Vector3(1, 0, 0), 3.0).is_equal_approx(Vector3(1, 0, 0)), "cap_length no toca lo chico")
	_check(is_equal_approx(CameraRig.dead_zone(10.0, 14.0), 0.0), "zona muerta: 10 px no cuentan")
	_check(is_equal_approx(CameraRig.dead_zone(-30.0, 14.0), -16.0), "zona muerta: -30 px cuentan -16")
	var rect := Rect2(-10, -10, 20, 20)
	var free := CameraRig.soft_limit_step(Vector2(0, 0), Vector2(1, 1), rect, 6.0)
	_check(free.is_equal_approx(Vector2(1, 1)), "lejos del borde no frena")
	var near := CameraRig.soft_limit_step(Vector2(8, 0), Vector2(1, 0), rect, 6.0)
	_check(near.x > 0.0 and near.x < 0.6, "cerca del borde frena (%.2f)" % near.x)
	var edge := CameraRig.soft_limit_step(Vector2(10, 0), Vector2(1, 0), rect, 6.0)
	_check(is_equal_approx(edge.x, 0.0), "en el borde no avanza")
	var away := CameraRig.soft_limit_step(Vector2(10, 0), Vector2(-1, 0), rect, 6.0)
	_check(is_equal_approx(away.x, -1.0), "alejarse del borde no frena")
	var cfg := CameraRig.load_config()
	_check(float(cfg["pitch_min_degrees"]) < -5.0 and float(cfg["pitch_min_degrees"]) > -45.0, "data/camera.json define el ángulo mínimo")


func _test_pitch_limit() -> void:
	print("\n2) Límite de inclinación")
	var minimum := float(_rig.config["pitch_min_degrees"])
	_rig.set_pitch(-1.0)
	_check(is_equal_approx(_rig.pitch_degrees, minimum), "pedir casi horizontal queda en %.0f°" % minimum)
	_rig.step_pitch(-500.0)
	_check(is_equal_approx(_rig.pitch_degrees, minimum), "bajar más con la perilla no pasa del mínimo")
	_rig.set_pitch(-200.0)
	_check(is_equal_approx(_rig.pitch_degrees, float(_rig.config["pitch_max_degrees"])), "desde arriba tiene su tope")
	for preset in CameraRig.PITCH_PRESETS:
		_check(preset <= minimum + 0.001, "el preset %.0f° respeta el mínimo" % preset)
	_rig.set_pitch(-50.0)
	_check(not _rig.is_low_pitch(), "a -50° los controles son los normales")
	_rig.set_pitch(minimum)
	_check(_rig.is_low_pitch(), "al mínimo los controles son los de cámara baja")


func _test_low_pitch_controls() -> void:
	print("\n3) Controles con la cámara baja")
	_rig.set_pitch(float(_rig.config["pitch_min_degrees"]))
	_rig.lot_limit_enabled = false
	_rig.rotation_degrees.y = 0.0
	_rig.set_state({"x": 0.0, "z": 0.0, "yaw": 0.0, "distance": 10.0, "pitch": _rig.pitch_degrees})
	_rig.rotation_degrees.y = 0.0
	# Un gesto vertical chico (dentro de la zona muerta): no avanza.
	_rig._drag_y = 0.0
	_rig._pan(Vector2(500, 500), Vector2(500, 496))
	_rig.flush_pending()
	_check(absf(_rig.position.z) < 0.001, "4 px verticales (zona muerta): no se mueve (z=%.3f)" % _rig.position.z)
	# Un gesto vertical grande: avanza, pero despacio.
	_rig._drag_y = 0.0
	var before_z := _rig.position.z
	for i in 10:
		_rig._pan(Vector2(500, 500 - i * 20), Vector2(500, 500 - (i + 1) * 20))  # 200 px hacia arriba
	_rig.flush_pending()
	var forward := absf(_rig.position.z - before_z)
	_check(forward > 0.0, "un gesto vertical grande sí avanza (%.2f m)" % forward)
	var grab := 200.0 * _rig.meters_per_pixel()
	_check(forward <= grab, "no avanza más que «agarrar el suelo»: %.2f m contra %.2f m" % [forward, grab])
	_check(forward > grab * 0.5, "pero tampoco se arrastra (Pulido 6C): %.2f m" % forward)
	# Lateral: se mueve a los lados y es mucho más controlable.
	_rig.position = Vector3.ZERO
	_rig._pan(Vector2(500, 500), Vector2(600, 500))
	_rig.flush_pending()
	_check(_rig.position.x < -0.05 and absf(_rig.position.z) < 0.001, "un dedo a la derecha desplaza la cámara a la izquierda (%.2f)" % _rig.position.x)
	# Aunque el dedo salte muchísimo, el tope por gesto manda.
	_rig.position = Vector3.ZERO
	_rig._pan(Vector2(100, 500), Vector2(1900, 500))
	_rig.flush_pending()
	_check(absf(_rig.position.x) <= float(_rig.config["pan_cap"]) * _rig.current_distance() + 0.001, "un salto enorme del dedo queda dentro del tope (%.2f m)" % _rig.position.x)
	# Respeta el giro de la cámara: con 90° el «lado» va por Z.
	_rig.position = Vector3.ZERO
	_rig.rotation_degrees.y = 90.0
	_rig._pan(Vector2(500, 500), Vector2(560, 500))
	_rig.flush_pending()
	_check(absf(_rig.position.z) > 0.02 and absf(_rig.position.x) < 0.001, "el desplazamiento sigue el giro de la cámara")
	_rig.rotation_degrees.y = 0.0
	_rig.lot_limit_enabled = true


func _test_speed_by_distance() -> void:
	print("\n4) Velocidad proporcional a la distancia")
	_rig.lot_limit_enabled = false
	_rig.set_pitch(float(_rig.config["pitch_min_degrees"]))
	var moved := {}
	for d in [6.0, 24.0]:
		_rig.set_state({"x": 0.0, "z": 0.0, "yaw": 0.0, "distance": d, "pitch": _rig.pitch_degrees})
		_rig.rotation_degrees.y = 0.0
		_rig._pan(Vector2(500, 500), Vector2(530, 500))
		_rig.flush_pending()
		moved[d] = absf(_rig.position.x)
	_check(moved[24.0] > moved[6.0] * 3.0, "4 veces más lejos, ~4 veces más rápido (%.2f vs %.2f)" % [moved[24.0], moved[6.0]])
	# Tope por cuadro: un solo cuadro nunca mueve más que frame_cap × distancia.
	_rig.set_state({"x": 0.0, "z": 0.0, "yaw": 0.0, "distance": 10.0, "pitch": _rig.pitch_degrees})
	_rig.queue_move(Vector3(1000, 0, 0))
	_rig.step_pending(1.0)
	_check(_rig.position.x <= float(_rig.config["frame_cap"]) * 10.0 + 0.001, "un cuadro no pasa del tope (%.2f m)" % _rig.position.x)
	_rig.flush_pending()  # Lo que quedó pendiente no debe colarse en la prueba siguiente.
	# Amortiguación: con un cuadro corto se mueve solo una parte de lo pendiente.
	_rig.set_state({"x": 0.0, "z": 0.0, "yaw": 0.0, "distance": 20.0, "pitch": _rig.pitch_degrees})
	_rig.queue_move(Vector3(1, 0, 0))
	_rig.step_pending(1.0 / 120.0)
	_check(_rig.position.x > 0.0 and _rig.position.x < 1.0, "amortiguado: una parte por cuadro (%.2f)" % _rig.position.x)
	_rig.flush_pending()
	_check(is_equal_approx(_rig.position.x, 1.0) or absf(_rig.position.x - 1.0) < 0.01, "al final llega a donde iba (%.3f)" % _rig.position.x)
	# Vista normal (agarrar el suelo): también con tope por gesto.
	_rig.set_pitch(-50.0)
	_rig.set_state({"x": 0.0, "z": 0.0, "yaw": 0.0, "distance": 10.0, "pitch": -50.0})
	_rig.queue_move(Vector3(0, 0, 500))
	_rig.flush_pending()
	_check(absf(_rig.position.z) <= float(_rig.config["pending_cap"]) * 10.0 + 0.01, "en vista normal también hay tope (%.2f m)" % _rig.position.z)
	_rig.lot_limit_enabled = true


func _test_lot_limit() -> void:
	print("\n5) Límite a la parcela usable (vista normal)")
	_rig.lot_limit_enabled = true
	_rig.set_pitch(-50.0)
	var rect := _rig.limit_rect()
	var map_half := _rig.bounds_half_size
	_check(rect.size.x <= map_half * 2.0 + 0.01 and rect.size.y <= map_half * 2.0 + 0.01, "el límite cabe dentro del mapa")
	var usable_cells := Parcel.zone_bounds()
	var origin := Vector2(HouseGrid.LOT_SIZE) / 2.0
	var expected_left := float(usable_cells.position.x) - origin.x - float(_rig.config["lot_margin"])
	_check(rect.position.x >= expected_left - 0.01, "el borde izquierdo sale de la zona usable + margen (%.1f)" % rect.position.x)
	# La zona de arranque no es toda la parcela: hay parte del mapa fuera del límite.
	var full := Vector2(HouseGrid.LOT_SIZE)
	_check(rect.size.x < full.x or rect.size.y < full.y - 0.01, "la cámara no puede ir a todo el lote (%.0f x %.0f)" % [rect.size.x, rect.size.y])
	# Empujar muy fuerte hacia un lado nunca pasa del borde.
	_rig.set_state({"x": 0.0, "z": 0.0, "yaw": 0.0, "distance": 20.0, "pitch": -50.0})
	for i in 200:
		_rig.queue_move(Vector3(-100, 0, -100))
		_rig.step_pending(1.0 / 60.0)
	_check(_rig.position.x >= rect.position.x - 0.001 and _rig.position.z >= rect.position.y - 0.001, "no sale del límite (%.1f, %.1f)" % [_rig.position.x, _rig.position.z])
	# Frena de a poco: a media distancia del borde el paso ya es menor que lejos del borde.
	_rig.set_state({"x": rect.get_center().x, "z": rect.get_center().y, "yaw": 0.0, "distance": 20.0, "pitch": -50.0})
	var far_step := CameraRig.soft_limit_step(Vector2(rect.get_center().x, rect.get_center().y), Vector2(0.5, 0), rect, 6.0).x
	var near_step := CameraRig.soft_limit_step(Vector2(rect.end.x - 2.0, rect.get_center().y), Vector2(0.5, 0), rect, 6.0).x
	_check(near_step < far_step * 0.6, "el borde suave frena antes de llegar (%.2f contra %.2f)" % [near_step, far_step])
	# set_state y focus_on también respetan el límite.
	_rig.set_state({"x": 9999.0, "z": 9999.0, "yaw": 0.0, "distance": 20.0, "pitch": -50.0})
	_check(_rig.position.x <= rect.end.x + 0.001 and _rig.position.z <= rect.end.y + 0.001, "un estado guardado fuera del límite se corrige")
	_rig.focus_on(Vector3(-9999.0, 0.0, 0.0))
	_check(_rig.position.x >= rect.position.x - 0.001, "centrar la cámara en algo lejano respeta el límite")


func _test_neighborhood_keeps_limits() -> void:
	print("\n6) Barrio y visitas conservan sus límites")
	var normal := _rig.limit_rect()
	_rig.enter_neighborhood_view()
	var wide := _rig.limit_rect()
	_check(not _rig.lot_limit_enabled and _rig.in_neighborhood_view(), "en el barrio no rige el límite de la parcela")
	_check(wide.size.x > normal.size.x * 2.0 and is_equal_approx(wide.size.x, CameraRig.NEIGHBORHOOD_BOUNDS * 2.0), "en el barrio vale el cuadro grande de siempre (%.0f)" % wide.size.x)
	_rig.exit_neighborhood_view()
	_check(_rig.lot_limit_enabled and _rig.limit_rect().is_equal_approx(normal), "al volver a casa vuelve el límite de la parcela")
