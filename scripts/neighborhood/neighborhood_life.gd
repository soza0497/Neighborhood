class_name NeighborhoodLife
extends Node3D
## Vida del barrio (Fase 8C): vecinos que caminan por las aceras, se saludan y
## entran a sus casas, y autos que circulan por la calle sin chocarse.
##
## Es SOLO local (animado en cada teléfono): no usa el servidor, no se guarda y
## no cuenta para nada. Los vecinos no son jugadores reales.
##
## Rendimiento (meta: 30 FPS en un Android de gama media):
##  - Hay pocos personajes (data/neighborhood.json, life.max_walkers) y, si los
##    cuadros por segundo bajan, se activan menos (_adapt).
##  - LOD simple según la distancia a la cámara: cerca = todo animado; medio =
##    se mueven pero sin animar el cuerpo; lejos = se esconden y su lógica corre
##    solo cada medio segundo.
##
## Rutas: sin HouseNav (el interior de las casas vecinas solo existe al visitar):
## rutas simples por puntos — puerta → acera → (cruce) → destino.
##
## Ganchos de animación por NOMBRE (CharacterAnimator): "idle", "walk", "wave".
## Ganchos de sonido por EVENTO (EventBus.neighborhood_sound): "greet", "door",
## "car_pass". Los archivos van en data/sounds/ (ver LEEME.txt).

const WALK_Y_SIDEWALK := 0.15
const LANE_OFFSET := 0.22  # Fracción del ancho de la calle.
const FAR_TICK := 0.5

var cfg: Dictionary = {}
var walkers: Array[Dictionary] = []
var cars: Array[Dictionary] = []
## Cuántos vecinos están activos ahora (baja si el teléfono va lento).
var active_limit := 0
## Para pruebas: posición de la cámara inventada (null = la cámara real).
var camera_override: Variant = null
## Contadores (para pruebas y para ver cómo anda).
var stats := {"greets": 0, "entered": 0, "left": 0, "car_passes": 0, "min_car_gap": 1000000.0}

var street_z := 54.0
var north_z := 49.25
var south_z := 58.75
var road_half := 3.5
var lane_length := 560.0

var _rng := RandomNumberGenerator.new()
var _greet_timer := 0.0
var _lod_timer := 0.0
var _adapt_timer := 0.0
var _slow_seconds := 0.0
var _sound_players: Array[AudioStreamPlayer3D] = []
var _sound_next := 0
var _streams: Dictionary = {}


func _ready() -> void:
	name = "Life"
	if not NeighborhoodMap.enabled():
		return
	cfg = NeighborhoodMap.data().get("life", {})
	_rng.seed = ("%d:life" % int(NeighborhoodMap.data().get("seed", 1))).hash()
	var street: Dictionary = NeighborhoodMap.data().get("streets", [{}])[0]
	street_z = NeighborhoodMap.street_z()
	road_half = float(street.get("road_width", 7.0)) / 2.0
	var side := float(street.get("sidewalk_width", 2.5))
	north_z = street_z - road_half - side / 2.0
	south_z = street_z + road_half + side / 2.0
	lane_length = float(street.get("to", 300)) - float(street.get("from", -300)) - 40.0
	for i in 4:
		var player := AudioStreamPlayer3D.new()
		player.bus = Sound.BUS_SFX
		add_child(player)
		_sound_players.append(player)
	EventBus.neighborhood_sound.connect(_play_sound)
	_spawn_walkers()
	_spawn_cars()
	active_limit = walkers.size()


func _process(delta: float) -> void:
	step(minf(delta, 0.25))
	_adapt(delta)


## Un paso de la simulación (lo llama _process; las pruebas lo llaman a mano).
func step(delta: float) -> void:
	_lod_timer -= delta
	if _lod_timer <= 0.0:
		_lod_timer = 0.5
		_update_lod()
	for i in walkers.size():
		var w := walkers[i]
		if i >= active_limit:
			_deactivate(w)
			continue
		_step_entity(w, delta, _step_walker)
	_greet_timer -= delta
	if _greet_timer <= 0.0:
		_greet_timer = 0.25
		_check_greetings()
	for c in cars:
		_step_entity(c, delta, _step_car)
	_track_car_gaps()


## Pasos de lejos: se acumula el tiempo y se avanza cada FAR_TICK segundos.
func _step_entity(e: Dictionary, delta: float, stepper: Callable) -> void:
	if e["lod"] >= 2:
		e["accum"] += delta
		if e["accum"] < FAR_TICK:
			return
		delta = e["accum"]
		e["accum"] = 0.0
	stepper.call(e, delta)


# --- Cámara y LOD ---

func _camera_point() -> Vector3:
	if camera_override != null:
		return camera_override
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera == null:
		return Vector3.ZERO
	return camera.global_position


## Cerca / medio / lejos según la distancia a la cámara.
func _update_lod() -> void:
	var cam := _camera_point()
	var near := float(cfg.get("lod_near", 45.0))
	var far := float(cfg.get("lod_far", 110.0))
	for e in walkers + cars:
		var node: Node3D = e["node"]
		var d := Vector2(node.position.x - cam.x, node.position.z - cam.z).length()
		var lod := 0 if d < near else (1 if d < far else 2)
		e["lod"] = lod
		if e.has("anim"):
			(e["anim"] as CharacterAnimator).set_process(lod == 0 and not e["hidden"])
			node.visible = lod < 2 and not e["hidden"]
		else:
			node.visible = lod < 2


## Si los cuadros por segundo bajan de min_fps durante unos segundos, hay un
## vecino activo menos (hasta min_walkers).
func _adapt(delta: float) -> void:
	_adapt_timer += delta
	if _adapt_timer < 1.0:
		return
	_adapt_timer = 0.0
	var fps := Engine.get_frames_per_second()
	if fps > 0 and fps < int(cfg.get("min_fps", 24)):
		_slow_seconds += 1.0
	else:
		_slow_seconds = 0.0
	if _slow_seconds >= float(cfg.get("slow_seconds_to_reduce", 3.0)) and active_limit > int(cfg.get("min_walkers", 3)):
		active_limit -= 1
		_slow_seconds = 0.0


func _deactivate(w: Dictionary) -> void:
	(w["node"] as Node3D).visible = false
	w["hidden"] = true
	if w["state"] != "inside":
		w["state"] = "inside"
		w["timer"] = 1.0e9


# --- Vecinos que caminan ---

func _spawn_walkers() -> void:
	var lots: Array = NeighborhoodMap.house_lots().duplicate()
	# Se barajan las casas con la semilla y las primeras reciben un vecino.
	for i in range(lots.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = lots[i]
		lots[i] = lots[j]
		lots[j] = tmp
	var count := mini(int(cfg.get("max_walkers", 10)), lots.size())
	var hairstyles: Array = Catalog.character_options.get("hairstyles", [])
	var eyes: Array = Catalog.character_options.get("eyes", [])
	var mouths: Array = Catalog.character_options.get("mouths", [])
	for i in count:
		var look_data := {
			"skin": _pick(cfg.get("skin", ["#f5c9a6"])), "hair": _pick(cfg.get("hair", ["#5a3a22"])),
			"shirt": _pick(cfg.get("shirt", ["#6fb7ff"])), "pants": _pick(cfg.get("pants", ["#3b4a5e"]))}
		if not hairstyles.is_empty():
			look_data["hairstyle"] = hairstyles[_rng.randi_range(0, hairstyles.size() - 1)]["id"]
		if not eyes.is_empty():
			look_data["eyes"] = eyes[_rng.randi_range(0, eyes.size() - 1)]["id"]
		if not mouths.is_empty():
			look_data["mouth"] = mouths[_rng.randi_range(0, mouths.size() - 1)]["id"]
		var look := CharacterLook.build(look_data)
		var node := Node3D.new()
		node.name = "Neighbor%d" % i
		node.add_child(look)
		node.scale = Vector3.ONE * 0.95
		node.visible = false
		add_child(node)
		var anim := CharacterAnimator.new()
		anim.body = look
		node.add_child(anim)
		var speed: Array = cfg.get("walker_speed", [0.9, 1.3])
		var home: String = lots[i]["id"]
		node.position = NeighborhoodMap.door_point(home)
		walkers.append({
			"node": node, "anim": anim, "home": home, "state": "inside", "hidden": true, "phase": "going",
			"timer": _rng.randf_range(1.0, 12.0), "speed": _rng.randf_range(speed[0], speed[1]),
			"points": [], "flags": [], "idx": 0, "crossing": false, "greet_cooldown": 0.0,
			"lod": 0, "accum": 0.0, "target": "", "target_kind": "", "stay": 0.0})


func _pick(list: Array) -> String:
	return str(list[_rng.randi_range(0, list.size() - 1)])


func _step_walker(w: Dictionary, delta: float) -> void:
	var node: Node3D = w["node"]
	w["greet_cooldown"] = maxf(0.0, w["greet_cooldown"] - delta)
	match w["state"]:
		"inside":
			w["timer"] -= delta
			if w["timer"] <= 0.0:
				_leave_home(w)
		"walk":
			_walk(w, delta)
		"greet", "stay":
			w["timer"] -= delta
			if w["timer"] <= 0.0:
				if w["state"] == "stay":
					_finish_stay(w)
				else:
					_set_state(w, "walk", "walk")
		"entering":
			w["timer"] -= delta
			if w["timer"] <= 0.0:
				_enter_building(w)
	node.position.y = WALK_Y_SIDEWALK if absf(node.position.z - street_z) < road_half + 2.6 else 0.0


func _set_state(w: Dictionary, state: String, animation: String) -> void:
	w["state"] = state
	(w["anim"] as CharacterAnimator).play(animation)


## Sale de su casa hacia un destino elegido al azar.
func _leave_home(w: Dictionary) -> void:
	var home: String = w["home"]
	var weights: Dictionary = cfg.get("target_weights", {"neighbor": 0.3, "park": 0.35, "stroll": 0.35})
	var roll := _rng.randf()
	var door := NeighborhoodMap.door_point(home, 1.0)
	var route: Dictionary
	w["phase"] = "going"
	if roll < float(weights.get("neighbor", 0.3)):
		var others := NeighborhoodMap.house_lots().filter(func(l: Dictionary) -> bool: return l["id"] != home)
		var target: String = others[_rng.randi_range(0, others.size() - 1)]["id"]
		w["target"] = target
		w["target_kind"] = "neighbor"
		route = route_lots(home, target)
	elif roll < float(weights.get("neighbor", 0.3)) + float(weights.get("park", 0.35)):
		w["target_kind"] = "park"
		route = route_to_park(home)
	else:
		w["target_kind"] = "stroll"
		var side_point := NeighborhoodMap.sidewalk_point(home)
		var spot := Vector3(side_point.x + _rng.randf_range(-45.0, 45.0), 0.0, side_point.z)
		route = _join([{"points": [door, side_point], "flags": [false, false]}, route_sidewalks(side_point, spot)])
	_start_route(w, route)
	var node: Node3D = w["node"]
	node.position = NeighborhoodMap.door_point(home, 0.3)
	w["hidden"] = false
	w["state"] = "walk"
	(w["anim"] as CharacterAnimator).play("walk")
	node.visible = w["lod"] < 2
	stats["left"] += 1
	EventBus.neighborhood_sound.emit("door", node.position)


func _start_route(w: Dictionary, route: Dictionary) -> void:
	w["points"] = route["points"]
	w["flags"] = route["flags"]
	w["idx"] = 0


func _walk(w: Dictionary, delta: float) -> void:
	var node: Node3D = w["node"]
	var points: Array = w["points"]
	if w["idx"] >= points.size():
		_arrive(w)
		return
	var target: Vector3 = points[w["idx"]]
	w["crossing"] = bool(w["flags"][w["idx"]])
	var to_target := Vector3(target.x - node.position.x, 0.0, target.z - node.position.z)
	var distance := to_target.length()
	var step_length: float = w["speed"] * delta
	if distance <= step_length:
		node.position.x = target.x
		node.position.z = target.z
		w["idx"] += 1
		w["crossing"] = false
		return
	var direction := to_target / distance
	node.position += direction * step_length
	node.rotation.y = atan2(direction.x, direction.z)


## Llegó al final de la ruta: según el plan, se queda un rato, entra o termina.
func _arrive(w: Dictionary) -> void:
	w["crossing"] = false
	if w["phase"] == "returning":
		_set_state(w, "entering", "idle")
		w["timer"] = 0.6
		w["building"] = w["home"]
		return
	match w["target_kind"]:
		"neighbor":
			# A veces entra a la casa del vecino; si no, lo saluda en la puerta y vuelve.
			if _rng.randf() < float(cfg.get("enter_house_chance", 0.25)):
				_set_state(w, "entering", "idle")
				w["timer"] = 0.6
				w["building"] = w["target"]
			else:
				_set_state(w, "stay", "wave")
				w["timer"] = 2.0
		"park":
			var seconds: Array = cfg.get("park_seconds", [6, 12])
			_set_state(w, "stay", "idle")
			w["timer"] = _rng.randf_range(seconds[0], seconds[1])
		_:
			_set_state(w, "stay", "idle")
			w["timer"] = 2.0


## Terminó de quedarse en el destino: vuelve a su casa.
func _finish_stay(w: Dictionary) -> void:
	_return_home(w)


func _return_home(w: Dictionary) -> void:
	var node: Node3D = w["node"]
	var home: String = w["home"]
	var side_point := NeighborhoodMap.sidewalk_point(home)
	var here := node.position
	var route: Dictionary
	if absf(here.z - street_z) > road_half + 3.0 and w["target_kind"] == "park":
		# Del parque a la acera de enfrente y de ahí a casa.
		var enter := Vector3(here.x, 0.0, south_z)
		route = _join([{"points": [enter], "flags": [false]}, route_sidewalks(enter, side_point),
			{"points": [NeighborhoodMap.door_point(home, 1.0)], "flags": [false]}])
	else:
		var from_side := Vector3(here.x, 0.0, north_z if here.z < street_z else south_z)
		route = _join([{"points": [from_side], "flags": [false]}, route_sidewalks(from_side, side_point),
			{"points": [NeighborhoodMap.door_point(home, 1.0)], "flags": [false]}])
	w["phase"] = "returning"
	_start_route(w, route)
	_set_state(w, "walk", "walk")
	w["hidden"] = false
	node.visible = w["lod"] < 2
	(w["anim"] as CharacterAnimator).set_process(w["lod"] == 0)


## Entra a una casa: desaparece un rato (adentro) y después sale de nuevo.
func _enter_building(w: Dictionary) -> void:
	var node: Node3D = w["node"]
	node.visible = false
	w["hidden"] = true
	EventBus.neighborhood_sound.emit("door", node.position)
	stats["entered"] += 1
	if w["building"] == w["home"]:
		var seconds: Array = cfg.get("stay_inside_seconds", [8, 25])
		w["state"] = "inside"
		w["timer"] = _rng.randf_range(seconds[0], seconds[1])
		(w["anim"] as CharacterAnimator).set_process(false)
	else:
		# Visita: adentro unos segundos y después vuelve a su casa.
		w["state"] = "stay"
		w["timer"] = _rng.randf_range(4.0, 9.0)
		w["building"] = ""
		node.visible = false


# --- Saludos ---

func _check_greetings() -> void:
	var greet_distance := float(cfg.get("greet_distance", 3.0))
	for i in walkers.size():
		var a := walkers[i]
		if a["state"] != "walk" or a["greet_cooldown"] > 0.0 or a["crossing"] or i >= active_limit:
			continue
		for j in range(i + 1, walkers.size()):
			var b := walkers[j]
			if b["state"] != "walk" or b["greet_cooldown"] > 0.0 or b["crossing"] or j >= active_limit:
				continue
			var na: Node3D = a["node"]
			var nb: Node3D = b["node"]
			if Vector2(na.position.x - nb.position.x, na.position.z - nb.position.z).length() > greet_distance:
				continue
			for pair in [[a, nb.position], [b, na.position]]:
				var w: Dictionary = pair[0]
				var other: Vector3 = pair[1]
				var node: Node3D = w["node"]
				node.rotation.y = atan2(other.x - node.position.x, other.z - node.position.z)
				_set_state(w, "greet", "wave")
				w["timer"] = float(cfg.get("greet_seconds", 1.6))
				w["greet_cooldown"] = float(cfg.get("greet_cooldown", 25.0))
			stats["greets"] += 1
			EventBus.neighborhood_sound.emit("greet", (na.position + nb.position) / 2.0)
			break


# --- Rutas por puntos ---
# Una ruta es {points: Array[Vector3], flags: Array[bool]}; flags[i] = el tramo
# que llega al punto i cruza la calle (los autos frenan).

func route_lots(from_lot: String, to_lot: String) -> Dictionary:
	var from_side := NeighborhoodMap.sidewalk_point(from_lot)
	var to_side := NeighborhoodMap.sidewalk_point(to_lot)
	return _join([
		{"points": [NeighborhoodMap.door_point(from_lot, 1.0), from_side], "flags": [false, false]},
		route_sidewalks(from_side, to_side),
		{"points": [NeighborhoodMap.door_point(to_lot, 1.0)], "flags": [false]}])


## Ruta hasta una banca de la plazoleta (siempre del lado sur de la calle).
func route_to_park(from_lot: String) -> Dictionary:
	var from_side := NeighborhoodMap.sidewalk_point(from_lot)
	var park := NeighborhoodMap.lot_rect("park")
	var benches := int(NeighborhoodMap.data().get("park", {}).get("benches", 4))
	var angle := TAU * _rng.randi_range(0, benches - 1) / benches + PI / 4.0
	var seat := Vector3(park.get_center().x + cos(angle) * 4.2, 0.0, park.get_center().y + sin(angle) * 4.2)
	var entry := Vector3(seat.x, 0.0, south_z)
	return _join([
		{"points": [NeighborhoodMap.door_point(from_lot, 1.0), from_side], "flags": [false, false]},
		route_sidewalks(from_side, entry),
		{"points": [seat], "flags": [false]}])


## De un punto de una acera a otro punto de una acera (cruzando si hace falta).
func route_sidewalks(a: Vector3, b: Vector3) -> Dictionary:
	var a_north := a.z < street_z
	var b_north := b.z < street_z
	if a_north == b_north:
		if is_equal_approx(a.z, b.z):
			return {"points": [b], "flags": [false]}
		return {"points": [Vector3(b.x, 0.0, a.z), b], "flags": [false, false]}
	var crossing_x := _nearest_crossing((a.x + b.x) / 2.0)
	var from_z := north_z if a_north else south_z
	var to_z := south_z if a_north else north_z
	return {
		"points": [Vector3(crossing_x, 0.0, from_z), Vector3(crossing_x, 0.0, to_z), Vector3(b.x, 0.0, to_z), b],
		"flags": [false, true, false, false]}


func _nearest_crossing(x: float) -> float:
	var best := 0.0
	var best_d := 1.0e9
	for c in cfg.get("crossings", [0]):
		var d := absf(float(c) - x)
		if d < best_d:
			best_d = d
			best = float(c)
	return best


## Une varias rutas en una (el primer punto repetido se saca).
func _join(routes: Array) -> Dictionary:
	var points: Array = []
	var flags: Array = []
	for r in routes:
		for i in r["points"].size():
			var p: Vector3 = r["points"][i]
			if not points.is_empty() and (points[-1] as Vector3).distance_to(p) < 0.05:
				continue
			points.append(p)
			flags.append(r["flags"][i])
	return {"points": points, "flags": flags}


# --- Autos ---

func _spawn_cars() -> void:
	var count := int(cfg.get("max_cars", 4))
	var colors: Array = cfg.get("car_colors", ["#e8605a"])
	var speed: Array = cfg.get("car_speed", [3.0, 5.0])
	var lanes := [1, -1]  # 1 = va hacia +X (carril norte), -1 = hacia -X (carril sur).
	var per_lane := int(ceil(count / 2.0))
	for i in count:
		var lane: int = lanes[i % 2]
		var index_in_lane := i / 2
		var node := _make_car(Color.from_string(colors[i % colors.size()], Color.RED))
		node.name = "Car%d" % i
		add_child(node)
		# Repartidos parejo a lo largo del carril, con un corrimiento al azar.
		var s := lane_length * (float(index_in_lane) + _rng.randf_range(0.0, 0.5)) / float(per_lane)
		var car := {
			"node": node, "lane": lane, "s": fmod(s, lane_length), "speed": _rng.randf_range(speed[0], speed[1]),
			"state": "drive", "lod": 0, "accum": 0.0, "passed": false}
		_place_car(car)
		cars.append(car)


func _lane_z(lane: int) -> float:
	# Carril de ida (+X) al norte de la línea central; el de vuelta, al sur.
	return street_z - lane * (road_half * 2.0 * LANE_OFFSET)


func _place_car(car: Dictionary) -> void:
	var node: Node3D = car["node"]
	var half := lane_length / 2.0
	var x: float = -half + float(car["s"]) if car["lane"] == 1 else half - float(car["s"])
	node.position = Vector3(x, 0.0, _lane_z(car["lane"]))
	node.rotation.y = PI / 2.0 if car["lane"] == 1 else -PI / 2.0


## Distancia (por delante, a lo largo del carril, en círculo) hasta el auto de
## adelante del mismo carril. 1e9 si va solo.
func _gap_ahead(car: Dictionary) -> float:
	var best := 1.0e9
	for other in cars:
		if other == car or other["lane"] != car["lane"]:
			continue
		var gap: float = fposmod(float(other["s"]) - float(car["s"]), lane_length)
		best = minf(best, gap)
	return best


func _step_car(car: Dictionary, delta: float) -> void:
	var min_gap := float(cfg.get("car_min_gap", 4.6))
	var slow_gap := float(cfg.get("car_slow_gap", 9.0))
	var gap := _gap_ahead(car)
	var speed: float = car["speed"]
	# Frena al acercarse al de adelante (y nunca avanza más de lo que deja libre).
	if gap < slow_gap:
		speed *= clampf((gap - min_gap) / (slow_gap - min_gap), 0.0, 1.0)
	if _pedestrian_ahead(car):
		speed = 0.0
	var advance := minf(speed * delta, maxf(0.0, gap - min_gap))
	car["s"] = fposmod(float(car["s"]) + advance, lane_length)
	_place_car(car)
	# Sonido cuando pasa cerca de la cámara (una vez por pasada).
	var node: Node3D = car["node"]
	var near := absf(node.position.x - _camera_point().x) < 12.0
	if near and not car["passed"]:
		car["passed"] = true
		stats["car_passes"] += 1
		EventBus.neighborhood_sound.emit("car_pass", node.position)
	elif not near:
		car["passed"] = false


## ¿Hay alguien cruzando la calle justo delante del auto?
func _pedestrian_ahead(car: Dictionary) -> bool:
	var node: Node3D = car["node"]
	for w in walkers:
		if not w["crossing"]:
			continue
		var x: float = (w["node"] as Node3D).position.x
		var ahead := (x - node.position.x) * float(car["lane"])
		if ahead > -1.5 and ahead < 7.0:
			return true
	return false


func _track_car_gaps() -> void:
	for car in cars:
		var gap := _gap_ahead(car)
		if gap < 1.0e8:
			stats["min_car_gap"] = minf(stats["min_car_gap"], gap)


## Un auto simple: caja, cabina, vidrio y cuatro ruedas. Mira hacia +Z.
func _make_car(color: Color) -> Node3D:
	var car := Node3D.new()
	HousePieces.add_box(car, Vector3(0, 0.55, 0), Vector3(1.7, 0.6, 3.6), Style.toon_material(color))
	HousePieces.add_box(car, Vector3(0, 1.1, -0.15), Vector3(1.5, 0.55, 1.9), Style.toon_material(color.lightened(0.25)))
	HousePieces.add_box(car, Vector3(0, 1.1, 0.8), Vector3(1.45, 0.4, 0.05), Style.toon_material(Color("#a9d6f5")))
	var wheel := CylinderMesh.new()
	wheel.top_radius = 0.3
	wheel.bottom_radius = 0.3
	wheel.height = 0.25
	wheel.radial_segments = 10
	var wheel_material := Style.toon_material(Color("#2b2b33"))
	for x in [-0.85, 0.85]:
		for z in [-1.1, 1.1]:
			var instance := MeshInstance3D.new()
			instance.mesh = wheel
			instance.material_override = wheel_material
			instance.rotation.z = PI / 2.0
			instance.position = Vector3(x, 0.3, z)
			car.add_child(instance)
	return car


# --- Sonido por evento ---

## Busca data/sounds/<nombre>.ogg|wav|mp3 (y si no, deja que Sound.play pruebe en
## assets/audio/). Sin archivos no pasa nada.
func _play_sound(event: String, position: Vector3) -> void:
	var sound_name: String = str(cfg.get("sounds", {}).get(event, event))
	var stream := _stream_for(sound_name)
	if stream != null and not _sound_players.is_empty():
		var player := _sound_players[_sound_next]
		_sound_next = (_sound_next + 1) % _sound_players.size()
		player.stream = stream
		player.position = position
		player.play()
	else:
		Sound.play(sound_name, -6.0)


func _stream_for(sound_name: String) -> AudioStream:
	if _streams.has(sound_name):
		return _streams[sound_name]
	var found: AudioStream = null
	for extension in Sound.EXTENSIONS:
		var path := "%s%s.%s" % [cfg.get("sound_dir", "res://data/sounds/"), sound_name, extension]
		if ResourceLoader.exists(path):
			found = load(path) as AudioStream
			break
	_streams[sound_name] = found
	return found
