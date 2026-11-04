class_name Character
extends Node3D
## Un personaje que vive en la casa: camina, elige qué hacer y lo hace.
##
## Va como hijo de la HouseView (usa las coordenadas de la casa).
##
## Estados:
##   IDLE    → espera un momento y "piensa" qué hacer (CharacterBrain).
##   WALKING → sigue un camino (HouseNav) hasta el objeto o a pasear.
##   ACTING  → usa el objeto: las necesidades suben, suena su animación.
##
## Su estado se puede resumir en una "intención" (get_intention), lo que se
## manda a la pareja para animar al personaje en su pantalla (Fase 5).
##
## Fase 5: el mismo script sirve para el personaje de la PAREJA en la casa
## compartida (`is_partner`). Ese no avisa a la interfaz, no va a trabajar
## con mi empleo y no se guarda:
##   - Con la pareja en línea (`remote_driven`), hace lo que dice su
##     intención: camina hasta el mismo mueble y hace la misma acción, o
##     pasea. Se mandan estados, no movimientos: lo que se ve es creíble, no
##     exacto.
##   - Con la pareja fuera de línea, vive con su propia IA (con sus
##     necesidades de la última vez que guardó), como mi personaje.

enum State { IDLE, WALKING, ACTING, WORKING, OPENING, HURT }

## Metros por segundo real a velocidad x1.
const WALK_SPEED := 1.6
## Minutos del juego que se queda quieto antes de pensar de nuevo.
const THINK_PAUSE := Vector2(2.0, 5.0)
## Hasta cuántas celdas se aleja cuando pasea sin nada que hacer.
const WANDER_RADIUS := 4
## Cada cuántos segundos reales avisa a la interfaz cómo están sus necesidades.
const NEEDS_REPORT_SECONDS := 0.5
## Dónde aparece un personaje nuevo: al frente de la parcela, en el pasto.
## (Pulido 2C: con la parcela de 96, aparece al frente de la ZONA DE LA CASA.)
static func spawn_cell() -> Vector2i:
	return HouseGrid.home_origin() + Vector2i(HouseGrid.HOME_ZONE / 2, HouseGrid.HOME_ZONE - 2)
## Por dónde sale (y vuelve) cuando va a trabajar: la acera, al frente.
## La acera: el borde de adelante de la parcela, en línea con la casa.
static func work_cell() -> Vector2i:
	return Vector2i(HouseGrid.LOT_SIZE.x / 2, HouseGrid.LOT_SIZE.y - 1)

var data: CharacterData
var house: HouseData
var nav: HouseNav
var view: HouseView

var state := State.IDLE
## Nivel y celda donde está parado (o adonde llega si camina).
var level := 0
var cell := spawn_cell()

## Lo que planea hacer: {action, level, key, spot, path} o {} si solo pasea.
var _plan: Dictionary = {}
## Orden del jugador pendiente (tiene prioridad sobre la IA).
var _order: Dictionary = {}
var _path := PackedVector3Array()
var _path_index := 0
var _idle_minutes := 0.0
var _act_minutes := 0.0
var _work_minutes := 0.0
## Desde cuándo (hora real, segundos Unix) hace lo que está haciendo.
var _since := 0
var _report_timer := 0.0
## Última emoción anotada en el diario.
var _last_emotion := ""
var _rng := RandomNumberGenerator.new()

var _body: Node3D
## Saco y maleta (solo mientras va o vuelve del trabajo).
var _work_props: Node3D
## Vuelve del trabajo: camina de la acera a la casa y al llegar "salta".
var _returning := false
## Pulido 2C: cajas por abrir (de la entrega) y el tiempo que tose al abrir una.
var _open_queue: Array = []
var _open_timer := 0.0
## Se lastimó (el ejemplo es una caída por una puerta al vacío): espera a la ambulancia.
var hurt := false

## Terminó de abrirle la puerta a un servicio (Pulido 2C).
signal gate_opened
var _animator: CharacterAnimator
var _bubble: Label3D

# --- Fase 5: la pareja ---
## true = es el personaje de la pareja (ver arriba).
var is_partner := false
## true = lo maneja la intención que manda la pareja (en línea).
var remote_driven := false
## El otro personaje de la casa: no se eligen los muebles que está usando.
var companion: Character
var _name_tag: Label3D


func _ready() -> void:
	_rng.randomize()
	_animator = CharacterAnimator.new()
	add_child(_animator)
	_bubble = Label3D.new()
	_bubble.position.y = 1.65
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.no_depth_test = true
	_bubble.font_size = 56
	_bubble.outline_size = 14
	_bubble.pixel_size = 0.006
	_bubble.modulate = Color.WHITE
	_bubble.outline_modulate = Color(0.15, 0.2, 0.3)
	add_child(_bubble)


## Conecta el personaje con su casa y lo pone en su lugar.
func setup(new_data: CharacterData, new_house: HouseData, new_nav: HouseNav, new_view: HouseView) -> void:
	data = new_data
	house = new_house
	nav = new_nav
	view = new_view
	if is_partner and _name_tag == null:
		_name_tag = Label3D.new()
		_name_tag.position.y = 1.95  # Arriba de la burbuja.
		_name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_name_tag.no_depth_test = true
		_name_tag.font_size = 40
		_name_tag.outline_size = 10
		_name_tag.pixel_size = 0.006
		_name_tag.modulate = Color("#ffb3d1")
		_name_tag.outline_modulate = Color(0.15, 0.2, 0.3)
		add_child(_name_tag)
	if _name_tag != null:
		_name_tag.text = data.name
	refresh_look()
	place_at(level, cell)
	_set_idle()


## Vuelve a armar la figura (después de usar el editor).
func refresh_look() -> void:
	if _body != null:
		_body.queue_free()
	_work_props = null
	_body = CharacterLook.build(data.appearance)
	add_child(_body)
	_animator.body = _body
	if _name_tag != null:
		_name_tag.text = data.name


## Pone al personaje parado en una celda.
func place_at(new_level: int, new_cell: Vector2i) -> void:
	level = new_level
	cell = new_cell
	position = HouseGrid.cell_center(cell) + Vector3(0, nav.ground_y(level, cell), 0)


## Después de construir: cancela lo que hacía y, si le pusieron algo encima,
## lo mueve a la celda libre más cercana.
func reset_after_build() -> void:
	if state == State.WORKING:
		return  # Sigue en el trabajo; no está en la casa.
	_stop_action()
	if not nav.is_walkable(level, cell):
		var spot := nav.nearest_walkable(position)
		if spot.is_empty():
			spot = [0, spawn_cell()]
		place_at(spot[0], spot[1])
	else:
		place_at(level, cell)
	_set_idle()


## La casa cambió sin pasar por Construir (Fase 5: la pareja editó algo).
## Si el mueble que iba a usar cambió, o le pusieron algo encima, se
## reubica y vuelve a pensar; si no, sigue con lo suyo.
func on_house_changed() -> void:
	if state == State.WORKING or data == null:
		return
	var stale := not nav.is_walkable(level, cell) and state != State.ACTING
	if _plan.has("key"):
		var object: Variant = house.get_piece(_plan["level"], "objects", _plan["key"])
		stale = stale or object == null or _plan.get("anchor") != HouseData.object_anchor(object) \
			or HouseData.is_under_construction(object)
	if stale:
		reset_after_build()


## Orden del jugador: usar la acción `action_id` del objeto `key`.
func order(object_level: int, key: String, action_id: String) -> void:
	var action: Dictionary = Catalog.actions.get(action_id, {})
	if action.is_empty():
		return
	if state == State.WORKING:
		EventBus.toast.emit("%s está trabajando." % data.name)
		return
	var option := _option_for(object_level, key, action)
	if option.is_empty():
		_bubble.text = "No llego"
		return
	_stop_action()
	_order = option
	_idle_minutes = 0.0
	state = State.IDLE
	data.add_journal("Le pediste: " + action.get("name", "").to_lower())


func _process(delta: float) -> void:
	if data == null:
		return
	var minutes := GameClock.game_minutes(delta)
	if minutes > 0.0:
		data.decay(minutes)
		# Si ya va camino al trabajo, no se vuelve a empezar. (La pareja va a
		# trabajar en SU teléfono: aquí solo se ve por su intención.)
		if not is_partner and state != State.WORKING and not hurt and not _plan.has("work") and Economy.shift_due():
			_go_to_work()
		match state:
			State.IDLE:
				_idle_minutes -= minutes
				if _idle_minutes <= 0.0:
					_think()
			State.WALKING:
				_walk(WALK_SPEED * delta * GameClock.speed)
			State.ACTING:
				_act(minutes)
			State.WORKING:
				if not is_partner:
					_work(minutes)
			State.OPENING:
				pass

	if state == State.OPENING:
		_open_timer -= delta
		if _open_timer <= 0.0:
			_next_box()

	# Si construyen en la planta baja, no se ve al personaje que está arriba.
	visible = (view == null or level <= view.top_visible_level) and state != State.WORKING

	_report_timer -= delta
	if _report_timer <= 0.0:
		_report_timer = NEEDS_REPORT_SECONDS
		_update_bubble()
		if not is_partner:
			_note_emotion()
			EventBus.character_needs_changed.emit(data.needs, data.mood_text())


# --- Pensar ---

## Elige qué hacer: primero las órdenes del jugador, si no, la IA.
func _think() -> void:
	if remote_driven:
		_wander()  # Lo que hace lo dice su intención; mientras, pasea.
		return
	if hurt:
		return
	# Pulido 2C: si hay cajas sin abrir, cuando quiere abre una (su IA).
	var delivery := _delivery()
	if delivery != null and delivery.dropped_count() > 0 and _order.is_empty() and _rng.randf() < 0.4:
		_open_queue = [delivery.dropped_boxes()[0]]
		_next_box()
		return
	# Pulido 2C: un piso alto con una puerta al vacío: a veces se asoma y se cae.
	if level > 0 and _order.is_empty() and _rng.randf() < 0.15:
		var door := _void_door_inside()
		if door != Vector2i(-1, -1):
			var path := nav.find_path(level, cell, level, door)
			if not path.is_empty() or door == cell:
				_go({"level": level, "spot": door, "path": path, "fall": true})
				return
	var choice := _order
	_order = {}
	if choice.is_empty():
		choice = CharacterBrain.choose(data, _gather_options(), _rng)
	if choice.is_empty():
		_wander()
	else:
		_go(choice)


## Todas las acciones que anuncian los objetos de la casa, con su camino.
func _gather_options() -> Array:
	var options: Array = []
	for object_level in HouseGrid.MAX_LEVELS:
		for key in house.get_layer(object_level, "objects"):
			var piece: Dictionary = house.get_piece(object_level, "objects", key)
			if HouseData.is_under_construction(piece):
				continue
			var item_id: String = piece["item"]
			# Lo que está usando el otro personaje no se elige (Fase 5).
			if companion != null and companion.using(object_level, key):
				continue
			# Lo que sigue en su caja no se puede usar (Pulido 2C).
			var delivery := _delivery()
			if delivery != null and delivery.is_boxed(object_level, key):
				continue
			for action in Catalog.get_item_actions(item_id):
				var option := _option_for(object_level, key, action)
				if not option.is_empty():
					options.append(option)
	return options


## Prepara una opción: busca la celda de uso más cercana a la que se llega.
func _option_for(object_level: int, key: String, action: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	for spot in nav.object_spots(object_level, key):
		var path := PackedVector3Array()
		if object_level != level or spot != cell:
			path = nav.find_path(level, cell, object_level, spot)
			if path.is_empty():
				continue
		if best.is_empty() or path.size() < best["path_length"]:
			best = {"action": action, "level": object_level, "key": key, "spot": spot,
				"path": path, "path_length": path.size(),
				"anchor": HouseData.object_anchor(house.get_piece(object_level, "objects", key))}
	return best


## Pasea a una celda cercana al azar.
func _wander() -> void:
	for attempt in 6:
		var target := cell + Vector2i(_rng.randi_range(-WANDER_RADIUS, WANDER_RADIUS),
			_rng.randi_range(-WANDER_RADIUS, WANDER_RADIUS))
		if target == cell or not nav.is_walkable(level, target):
			continue
		var path := nav.find_path(level, cell, level, target)
		if not path.is_empty():
			_go({"level": level, "spot": target, "path": path})
			return
	_set_idle()


## Empieza a caminar hacia lo planeado.
func _go(option: Dictionary) -> void:
	_plan = option
	_path = option["path"]
	_path_index = 0
	state = State.WALKING
	_animator.play("walk")
	_mark_intention()


# --- Caminar ---

func _walk(distance: float) -> void:
	while distance > 0.0 and _path_index < _path.size():
		var target := _path[_path_index]
		var to_target := target - position
		var flat := Vector3(to_target.x, 0, to_target.z)
		if flat.length() > 0.01:
			rotation.y = atan2(flat.x, flat.z)
		if to_target.length() <= distance:
			position = target
			distance -= to_target.length()
			_path_index += 1
		else:
			position += to_target.normalized() * distance
			distance = 0.0
	if _path_index >= _path.size():
		_arrive()


func _arrive() -> void:
	level = _plan.get("level", level)
	cell = _plan.get("spot", cell)
	if _plan.has("work") and is_partner:
		_partner_arrive_at_work()
	elif _plan.has("work"):
		_start_work()
	elif _plan.has("return"):
		_arrive_home()
	elif _plan.has("box"):
		_start_open_box()
	elif _plan.has("gate"):
		_finish_gate()
	elif _plan.has("fall"):
		_fall_from_door()
	elif _plan.has("action"):
		_start_action()
	else:
		_set_idle()


# --- Hacer una acción ---

func _start_action() -> void:
	var action: Dictionary = _plan["action"]
	var object: Variant = house.get_piece(_plan["level"], "objects", _plan["key"])
	if object == null:
		_set_idle()  # El objeto ya no está.
		return
	var item := Catalog.get_item(object["item"])
	var size := HouseGrid.rotated_size(HouseData.item_footprint(item), int(object.get("rot", 0)))
	var anchor := HouseData.object_anchor(object)
	var center := Vector3(anchor.x + size.x / 2.0, HouseGrid.level_y(_plan["level"]), anchor.y + size.y / 2.0)

	if action.get("use_at", "spot") == "center":
		# Encima del objeto (cama, silla), mirando hacia donde mira el objeto.
		position = center + Vector3(0, float(action.get("seat_height", 0.4)), 0)
		rotation.y = -deg_to_rad(HouseGrid.object_angle(int(object.get("rot", 0)), object.get("diag", false)))
	else:
		# De pie junto al objeto, mirándolo.
		var look := center - position
		rotation.y = atan2(look.x, look.z)

	state = State.ACTING
	_act_minutes = 0.0
	_animator.play(action.get("anim", "idle"))
	_mark_intention()


func _act(minutes: float) -> void:
	if remote_driven:
		return  # Sigue con la acción hasta que la pareja haga otra cosa.
	var action: Dictionary = _plan["action"]
	var total := float(action.get("minutes", 30))
	_act_minutes += minutes
	var gains: Dictionary = action.get("gains", {})
	var all_full := true
	for need in gains:
		data.add_need(need, float(gains[need]) * minutes / total)
		if float(gains[need]) > 0.0 and data.needs[need] < 99.0:
			all_full = false
	if _act_minutes >= total or all_full:
		var object: Variant = house.get_piece(_plan["level"], "objects", _plan["key"])
		var object_name: String = Catalog.get_item(object["item"]).get("name", "") if object != null else ""
		data.add_journal("%s (%s)" % [action.get("done", action.get("name", "")), object_name])
		_stop_action()
		_set_idle()


## Termina lo que estaba haciendo y vuelve a pararse en su celda.
func _stop_action() -> void:
	if state == State.ACTING:
		place_at(level, cell)
	_plan = {}
	_path = PackedVector3Array()


func _set_idle() -> void:
	state = State.IDLE
	_plan = {}
	_idle_minutes = _rng.randf_range(THINK_PAUSE.x, THINK_PAUSE.y)
	_animator.play("idle")
	_mark_intention()


# --- Trabajo ---

## Es hora del turno: sale de la casa caminando hasta la acera.
func _go_to_work() -> void:
	_stop_action()
	_order = {}
	_show_work_props(true)
	var path := nav.find_path(level, cell, 0, work_cell())
	_go({"level": 0, "spot": work_cell(), "path": path, "work": true})


## Llegó a la acera: desaparece (está en el trabajo) hasta que termina el turno.
## Con servidor, el turno lo anota el servidor; si no responde, vuelve.
func _start_work() -> void:
	place_at(0, work_cell())
	# Se despide y desaparece del lote en una nubecita (utilería de mentira).
	if get_parent() != null:
		Fx.puff(get_parent(), position + Vector3(0, 0.6, 0), 10)
	_show_work_props(false)
	if not Economy.server_mode:
		Economy.start_shift()
	state = State.WORKING
	_work_minutes = 0.0
	data.add_journal("Se fue a trabajar (%s)" % Economy.current_job().get("name", ""))
	_animator.play("idle")
	_mark_intention()
	if Economy.server_mode:
		Economy.working_now = true
		var started: bool = await Economy.request_shift_start()
		if not started and state == State.WORKING:
			Economy.working_now = false
			data.add_journal("Hoy no pudo ir a trabajar")
			_set_idle()


func _work(minutes: float) -> void:
	var job := Economy.current_job()
	# Si renunció en medio del turno, vuelve sin cobrar.
	if not job.is_empty():
		_work_minutes += minutes
		if _work_minutes < float(job.get("shift_hours", 4)) * 60.0:
			return
		if Economy.server_mode:
			Economy.working_now = false
			_return_from_work()
			_collect_pay()
			return
		var pay := Economy.complete_shift()
		data.add_journal("Terminó el turno y cobró $%d" % pay)
		EventBus.toast.emit("%s cobró $%d del trabajo." % [data.name, pay])
	Economy.working_now = false
	_return_from_work()


## Vuelve a la casa: aparece en la acera con saco y maleta, camina hasta el
## pasto del frente y ahí "llega" (saltito y se le guardan las cosas).
func _return_from_work() -> void:
	place_at(0, work_cell())
	_show_work_props(true)
	var target := _front_door_cell()
	var path := nav.find_path(0, work_cell(), 0, target)
	if path.is_empty():
		_arrive_home()
		return
	_returning = true
	_go({"level": 0, "spot": target, "path": path, "return": true})


## La pareja sale al trabajo (se ve por su intención): mismo saco y maleta.
func _partner_go_to_work() -> void:
	_stop_action()
	_show_work_props(true)
	var path := nav.find_path(level, cell, 0, work_cell())
	_go({"level": 0, "spot": work_cell(), "path": path, "work": true})


func _partner_arrive_at_work() -> void:
	place_at(0, work_cell())
	if get_parent() != null:
		Fx.puff(get_parent(), position + Vector3(0, 0.6, 0), 10)
	_show_work_props(false)
	state = State.WORKING
	_animator.play("idle")


## Dónde "llega" de vuelta del trabajo: la celda de afuera junto a la puerta
## de la planta baja más cercana a la calle (o, si no hay puerta, el frente).
func _front_door_cell() -> Vector2i:
	var best := spawn_cell()
	var best_distance := 1 << 30
	for key in house.get_layer(0, "walls"):
		var wall: Dictionary = house.get_piece(0, "walls", key)
		if Catalog.get_item(wall.get("opening", "")).get("kind", "") != "door":
			continue
		for side in HouseGrid.edge_cells(key):
			if house.has_piece(0, "floors", HouseGrid.cell_key(side)):
				continue  # Es el lado de adentro.
			var distance := absi(side.x - work_cell().x) + absi(side.y - work_cell().y)
			if nav.is_walkable(0, side) and distance < best_distance:
				best_distance = distance
				best = side
	return best


# --- Pulido 2C: entrega, puerta del jardín, caída y ambulancia ---

func _delivery() -> Node:
	return get_tree().get_first_node_in_group("delivery") if is_inside_tree() else null


## «Abrir todas las cajas»: va a cada una, la abre (humo blanco), tose y sigue.
func open_all_boxes() -> void:
	var delivery := _delivery()
	if delivery == null or state == State.WORKING or hurt:
		return
	_stop_action()
	_order = {}
	_open_queue = delivery.dropped_boxes()
	_next_box()


## Orden de abrir UNA caja (el jugador la tocó).
func open_box_order(box_level: int, key: String) -> void:
	if state == State.WORKING or hurt:
		EventBus.toast.emit("%s no puede ahora." % data.name)
		return
	_stop_action()
	_order = {}
	_open_queue = [{"level": box_level, "key": key}]
	_next_box()


func _next_box() -> void:
	var delivery := _delivery()
	while not _open_queue.is_empty():
		var box: Dictionary = _open_queue.pop_front()
		if delivery == null or not delivery.is_boxed(box["level"], box["key"]):
			continue
		var spots := nav.object_spots(box["level"], box["key"])
		for spot in spots:
			var path := nav.find_path(level, cell, box["level"], spot)
			if path.is_empty() and not (level == box["level"] and spot == cell):
				continue
			_go({"level": box["level"], "spot": spot, "path": path, "box": box})
			return
		# No hay camino hasta esa caja: se abre igual (sin caminar) para no dejarla trabada.
		delivery.open_box(box["level"], box["key"])
	if state == State.OPENING or state == State.WALKING:
		_set_idle()


func _start_open_box() -> void:
	var box: Dictionary = _plan["box"]
	var delivery := _delivery()
	state = State.OPENING
	_open_timer = 1.8
	_animator.play("cough")
	_bubble.text = "¡Cof, cof!"
	_bubble.modulate = Color.WHITE
	_mark_intention()
	if delivery != null:
		delivery.open_box(box["level"], box["key"])
	Sound.play("cough")


## Va a la puerta de la calle y le abre al servicio (si está trabajando o
## lastimado, espera a estar libre; no más de `wait` segundos).
func go_open_gate(wait := 25.0) -> void:
	var waited := 0.0
	while (state == State.WORKING or hurt) and waited < wait:
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
	if state == State.WORKING or hurt:
		gate_opened.emit()  # No pudo: la puerta "se abre sola" (el portón queda abierto).
		return
	_stop_action()
	_order = {}
	var gate_cell := Vector2i(work_cell().x, work_cell().y - 1)
	var path := nav.find_path(level, cell, 0, gate_cell)
	if path.is_empty():
		gate_opened.emit()
		return
	_go({"level": 0, "spot": gate_cell, "path": path, "gate": true})


func _finish_gate() -> void:
	_bubble.text = "¡Adelante!"
	_animator.play("wave")
	gate_opened.emit()
	await get_tree().create_timer(1.4).timeout
	if state == State.WALKING or state == State.IDLE:
		_bubble.text = ""
		_set_idle()


## ¿Hay una puerta a un piso alto que da al vacío? Devuelve la celda de adentro
## junto a ella, o (-1, -1) si no hay.
func _void_door_inside() -> Vector2i:
	for key in house.get_layer(level, "walls"):
		var wall: Dictionary = house.get_piece(level, "walls", key)
		if Catalog.get_item(wall.get("opening", "")).get("kind", "") != "door":
			continue
		var sides := HouseGrid.edge_cells(key)
		var inside_a := house.has_piece(level, "floors", HouseGrid.cell_key(sides[0]))
		var inside_b := house.has_piece(level, "floors", HouseGrid.cell_key(sides[1]))
		if inside_a != inside_b:
			var inside: Vector2i = sides[0] if inside_a else sides[1]
			if nav.is_walkable(level, inside):
				return inside
	return Vector2i(-1, -1)


## Se asoma por la puerta al vacío y se cae: queda lastimado en el suelo de
## afuera (sin muerte ni pérdida de progreso) y llama a la ambulancia.
func _fall_from_door() -> void:
	var door := _void_door_inside()
	var ground := cell
	if door != Vector2i(-1, -1):
		for key in house.get_layer(level, "walls"):
			var wall: Dictionary = house.get_piece(level, "walls", key)
			if Catalog.get_item(wall.get("opening", "")).get("kind", "") != "door":
				continue
			for side in HouseGrid.edge_cells(key):
				if not house.has_piece(level, "floors", HouseGrid.cell_key(side)) and HouseGrid.is_cell_in_lot(side):
					ground = side
	fall_to(ground)


## La caída: baja al suelo de esa celda, se lastima y pide la ambulancia.
## (También se puede llamar directo: es el disparador de ejemplo.)
func fall_to(ground: Vector2i) -> void:
	_stop_action()
	hurt = true
	state = State.HURT
	level = 0
	cell = ground
	place_at(0, ground)
	data.add_need("energy", -15.0)
	data.add_journal("Se cayó por una puerta al vacío (¡ay!)")
	_animator.play("hurt")
	_bubble.text = "¡Ay!"
	_bubble.modulate = Color(1, 0.6, 0.5)
	EventBus.toast.emit("¡%s se cayó! Llamamos a la ambulancia." % data.name)
	EventBus.ambulance_requested.emit(self)


## La ambulancia lo revisó y lo curó.
func recover() -> void:
	hurt = false
	data.add_journal("La ambulancia lo revisó y lo curó")
	data.add_need("fun", 5.0)
	_bubble.text = "¡Gracias!"
	_bubble.modulate = Color.WHITE
	_set_idle()


func _arrive_home() -> void:
	_returning = false
	_show_work_props(false)
	_set_idle()
	_animator.play("arrive")
	_bubble.text = "¡Ya volví!"
	_bubble.modulate = Color.WHITE
	await get_tree().create_timer(1.6).timeout
	if state == State.IDLE and _animator.current == "arrive":
		_animator.play("idle")
		_bubble.text = ""


func _show_work_props(on: bool) -> void:
	if on and _work_props == null and _body != null:
		_work_props = CharacterLook.build_work_props()
		_body.add_child(_work_props)
	if _work_props != null:
		_work_props.visible = on


## Con servidor: pide el sueldo del turno (lo decide el servidor).
func _collect_pay() -> void:
	var pay: int = await Economy.request_shift_pay()
	if pay > 0:
		# Fase 5: con "unir ingresos", el sueldo va a la caja de la casa.
		var where := " (a la caja de la casa)" if Economy.shared and Economy.pool_income else ""
		data.add_journal("Terminó el turno y cobró $%d%s" % [pay, where])
		EventBus.toast.emit("%s cobró $%d del trabajo%s." % [data.name, pay, where])
	else:
		data.add_journal("Terminó el turno (se cobra cuando responda el servidor)")


# --- Burbuja, diario e intención ---

## Si cambió cómo se siente, lo anota en el diario.
func _note_emotion() -> void:
	var emotion := data.emotion()
	if emotion != _last_emotion:
		if _last_emotion != "":
			data.add_journal("Ahora se siente " + CharacterData.EMOTIONS[emotion].to_lower())
		_last_emotion = emotion


func _update_bubble() -> void:
	if state == State.ACTING:
		_bubble.text = _plan["action"].get("bubble", "")
		_bubble.modulate = Color.WHITE
		return
	var lowest := data.lowest_need()
	if data.needs[lowest] < CharacterData.LOW_NEED:
		_bubble.text = "¡%s!" % CharacterData.NEED_NAMES[lowest]
		_bubble.modulate = Color(1, 0.75, 0.4)
	else:
		_bubble.text = ""


## Resumen pequeño de lo que hace (para la interfaz y, en la Fase 5, para la
## pareja): quién, qué, dónde y desde cuándo.
func get_intention() -> Dictionary:
	var intention := {
		"character": data.name,
		"state": ["idle", "walking", "acting", "working", "idle", "idle"][state],
		"action": "",
		"verb": "paseando",
		"object": "",
		# Fase 5: qué mueble (clave y piso), para que la pareja anime a este
		# personaje en su pantalla junto al mismo mueble.
		"key": "",
		"object_level": 0,
		"level": level,
		"since": _since,
	}
	if _plan.has("action"):
		var object: Variant = house.get_piece(_plan["level"], "objects", _plan["key"])
		intention["action"] = _plan["action"]["id"]
		intention["key"] = _plan["key"]
		intention["object_level"] = _plan["level"]
		intention["verb"] = _plan["action"].get("verb", "")
		intention["object"] = Catalog.get_item(object["item"]).get("name", "") if object != null else ""
		if state == State.WALKING:
			intention["verb"] = "yendo a: " + _plan["action"].get("name", "").to_lower()
	elif state == State.WORKING or _plan.has("work"):
		intention["verb"] = "trabajando" if state == State.WORKING else "yendo a trabajar"
		intention["object"] = Economy.current_job().get("name", "")
	elif state == State.IDLE:
		intention["verb"] = "pensando qué hacer"
	return intention


## Texto de la intención, por ejemplo "Alex: cocinando (Cocina), desde las 14:02".
static func intention_text(intention: Dictionary) -> String:
	var text: String = "%s: %s" % [intention["character"], intention["verb"]]
	if intention["object"] != "":
		text += " (%s)" % intention["object"]
	if int(intention.get("since", 0)) <= 0:
		return text
	var since := Time.get_datetime_dict_from_unix_time(int(intention["since"]) + _utc_offset())
	return text + ", desde las %02d:%02d" % [since["hour"], since["minute"]]


static func _utc_offset() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60


func _mark_intention() -> void:
	_since = int(Time.get_unix_time_from_system())
	if not is_partner:
		EventBus.character_intention_changed.emit(get_intention())


# --- Fase 5: la pareja ---

## ¿Está usando (o yendo a usar) ese mueble?
func using(object_level: int, key: String) -> bool:
	return _plan.get("key", "") == key and int(_plan.get("level", -1)) == object_level


## La pareja se conectó, se desconectó o cambió lo que hace. Solo para el
## personaje de la pareja (`is_partner`).
func follow_intention(online: bool, intention: Dictionary) -> void:
	if data == null:
		return
	var was_working := state == State.WORKING
	remote_driven = online and not intention.is_empty()
	if not remote_driven:
		# Fuera de línea: sigue con su IA (lo que se ve es creíble, no exacto).
		if was_working:
			_return_from_work()
		return
	if intention.get("state", "") == "working":
		_stop_action()
		_show_work_props(false)
		state = State.WORKING
		_animator.play("idle")
		return
	if str(intention.get("verb", "")) == "yendo a trabajar":
		if not _plan.has("work"):
			_partner_go_to_work()
		return
	if was_working:
		_return_from_work()
	var key: String = intention.get("key", "")
	var object_level := int(intention.get("object_level", 0))
	var action: Dictionary = Catalog.actions.get(intention.get("action", ""), {})
	if key != "" and not action.is_empty() and house.has_piece(object_level, "objects", key):
		if using(object_level, key) and _plan.get("action", {}).get("id", "") == action.get("id", ""):
			return  # Ya está en eso.
		var option := _option_for(object_level, key, action)
		if not option.is_empty():
			_stop_action()
			_go(option)
			return
	# Sin mueble (pasea, piensa): deja lo que hacía y pasea por la casa.
	if state == State.ACTING or _plan.has("action"):
		_stop_action()
		_set_idle()


# --- Guardado ---

func to_dict() -> Dictionary:
	return {
		"data": data.to_dict(),
		"level": level,
		"cell": [cell.x, cell.y],
		"saved_unix": int(Time.get_unix_time_from_system()),
	}
