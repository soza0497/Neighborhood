extends Node
## Economía local: dinero, experiencia y nivel, piezas descubiertas, obras
## con temporizador y empleo.
##
## Reglas del juego (ver VISION.md):
##   - Una sola moneda, que solo se gana jugando.
##   - Nada castiga por desconectarse: las obras y los currículos avanzan con
##     la hora REAL (siguen corriendo con el juego cerrado) y un turno de
##     trabajo se cobra aunque el juego se cierre a mitad.
##   - Los aceleradores solo sirven para saltarse esperas propias.
##
## Dos modos:
##   - Con cuenta (Fase 4B, el juego normal): el SERVIDOR manda. Cada cambio
##     de dinero se le pide con request() / request_*(), de a uno por vez
##     (`busy`), y lo que responde (dinero, experiencia, empleo) se copia aquí
##     con apply_server_state(). Sin conexión no se construye ni se cobra.
##   - Sin cuenta ("modo de prueba", solo para las pruebas automáticas y las
##     demos): todo se calcula aquí mismo, como en la Fase 3.
## Los precios se calculan igual en los dos (para mostrarlos); el servidor
## los vuelve a calcular con el mismo catalog.json y es el que decide.

## Piezas que tienen tiempo de construcción.
const TIMED_LAYERS := ["objects", "roofs"]
## Máximo de días del juego sin conectarse que se pagan de trabajo.
const MAX_OFFLINE_SHIFTS := 3
## Avisos del modo servidor.
const OFFLINE_TEXT := "Sin conexión al servidor"
const BUSY_TEXT := "Esperando al servidor…"
## Lo mismo que rules.DAY_AT_FASTEST en el servidor: un día del juego a x5
## (como mucho un turno cada 288 s reales).
const SERVER_SHIFT_GAP := 288

var money := SaveMigrations.STARTING_MONEY
var xp := 0
## Ids de piezas que ya se construyeron alguna vez (dan experiencia una vez).
var discovered: Dictionary = {}
## Empleo actual ("" = ninguno) y currículum enviado ("" = ninguno).
var job_id := ""
var applied_job := ""
## Hora real (segundos Unix) en que responden al currículum.
var resume_ready_at := 0
## Último día del juego en que empezó un turno, y si quedó sin cobrar.
var last_work_day := 0
var pending_pay := false

# --- Modo servidor (Fase 4B) ---
## true = el servidor manda (juego con cuenta). false = modo de prueba.
var server_mode := false
## true mientras se espera una respuesta del servidor (no se aceptan otros
## pedidos: evita los dobles toques).
var busy := false
## Diferencia entre la hora del servidor y la del teléfono (segundos).
var server_offset := 0
## Hora real del último turno empezado (el servidor deja uno cada 288 s).
var last_shift_unix := 0
## Lo que el servidor permite deshacer y rehacer (su historial manda).
var server_can_undo := false
var server_can_redo := false
## true mientras el personaje está en el trabajo (su turno se cobra al volver).
var working_now := false
## Ya se cobró lo pendiente al entrar (work_settle).
var settled := false

# --- Casa compartida (Fase 5): lo copia de cada respuesta del servidor ---
## Versión del hogar en el servidor (sube con cada cambio de cualquiera de
## los dos). La escena principal la compara con la de su casa.
var house_rev := 0
## true = vive en una casa compartida con su pareja.
var shared := false
## Caja de la casa común y "unir ingresos" (mi sueldo va a la caja).
var fund := 0
var pool_income := false
## Pedidos de aprobación esperando (de cualquiera de los dos).
var requests_count := 0
## Último house_rev que cambió SOLO por un pedido mío (subió exactamente 1
## mientras esperaba la respuesta). La escena principal lo usa para saber si
## su casa ya está al día o si la pareja cambió algo en el medio.
var own_rev := -1
var _rev_at_send := 0

var _timer := 0.0
## Hora en que se vuelve a preguntar por el currículum o por el turno sin cobrar.
var _resume_check_at := 0
var _pay_retry_at := 0
var _settling := false


func _ready() -> void:
	from_dict(GameState.economy)
	EventBus.game_saving.connect(_on_game_saving)
	_emit_changed.call_deferred()


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = 1.0
		_check_resume()
		if server_mode:
			_retry_pending_pay()


## Hora real en segundos (para obras y currículos). Con servidor, la hora
## del servidor (el reloj del teléfono puede estar corrido).
func now() -> int:
	return int(Time.get_unix_time_from_system()) + server_offset


# --- Dinero ---

func add_money(amount: int) -> void:
	money += amount
	_emit_changed()


## ¿Alcanza el dinero para un cambio (negativo = pago)? En la casa
## compartida también cuenta la caja (se paga primero con ella).
func can_change(money_change: int) -> bool:
	return money + (fund if shared else 0) + money_change >= 0


# --- Nivel y experiencia ---

func level() -> int:
	var table: Array = Catalog.progression.get("levels", [0])
	var result := 1
	for i in table.size():
		if xp >= int(table[i]):
			result = i + 1
	return result


func max_level() -> int:
	return Catalog.progression.get("levels", [0]).size()


## [experiencia dentro del nivel, experiencia que pide el nivel] para la barra.
func xp_progress() -> Vector2i:
	var table: Array = Catalog.progression.get("levels", [0])
	var current := level()
	if current >= table.size():
		return Vector2i(1, 1)
	var start := int(table[current - 1])
	return Vector2i(xp - start, int(table[current]) - start)


func add_xp(amount: int) -> void:
	_set_xp(xp + amount)


## Cambia la experiencia y, si sube de nivel, avisa qué se desbloqueó.
func _set_xp(new_xp: int) -> void:
	var before := level()
	xp = new_xp
	var after := level()
	if after > before:
		var unlocked: Array = []
		for item in Catalog.items.values():
			var needed := int(item.get("unlock_level", 1))
			if needed > before and needed <= after:
				unlocked.append(item["name"])
		EventBus.level_up.emit(after, unlocked)
		EventBus.toast.emit("¡Nivel %d!" % after + ("  Nuevo: " + ", ".join(unlocked) if not unlocked.is_empty() else ""))
	_emit_changed()


func is_unlocked(item_id: String) -> bool:
	return level() >= Catalog.unlock_level(item_id)


# --- Precios y obras ---

## Lo que vale una pieza ya colocada (para cobrar y devolver).
func piece_cost(layer: String, value: Variant) -> int:
	if value == null:
		return 0
	var cost := int(Catalog.get_item(value.get("item", "")).get("price", 0))
	match layer:
		"walls":
			cost += int(Catalog.get_item(value.get("opening", "")).get("price", 0))
		"roofs":
			var rect := HouseData.roof_rect(value)
			cost *= rect.size.x * rect.size.y
	return cost


## Cambio de dinero por pasar de `old` a `new` (negativo = se paga).
## Subir de valor se paga entero; bajar devuelve un % (reventa).
func change_for(layer: String, old: Variant, new: Variant) -> int:
	var difference := piece_cost(layer, new) - piece_cost(layer, old)
	if difference >= 0:
		return -difference
	return int(round(-difference * float(Catalog.progression.get("resale_percent", 50)) / 100.0))


## Calcula cuánto cuesta aplicar una lista de escrituras y les pone la hora
## en que terminan de construirse. No cambia nada todavía.
## Devuelve {"writes": escrituras listas, "money": cambio de dinero}.
func quote(house: HouseData, writes: Array) -> Dictionary:
	var total := 0
	var result: Array = []
	for w in writes:
		var old: Variant = house.get_piece(w["level"], w["layer"], w["key"])
		total += change_for(w["layer"], old, w["value"])
		var stamped: Dictionary = w.duplicate()
		var value: Variant = w["value"]
		if value != null and w["layer"] in TIMED_LAYERS:
			var seconds := int(Catalog.get_item(value["item"]).get("build_seconds", 0))
			var is_new: bool = old == null or old.get("item", "") != value["item"]
			if seconds > 0 and is_new:
				value = (value as Dictionary).duplicate(true)
				value["ready_at"] = now() + seconds
		stamped["value"] = value
		result.append(stamped)
	return {"writes": result, "money": total}


## Anota las piezas nuevas que se construyeron: la primera vez de cada tipo
## da experiencia (deshacer y rehacer no la repiten).
func record_build(writes: Array) -> void:
	var gained := 0
	for w in writes:
		var value: Variant = w["value"]
		if value == null:
			continue
		for item_id in [value.get("item", ""), value.get("opening", "")]:
			if item_id != "" and not discovered.has(item_id):
				discovered[item_id] = true
				var price := int(Catalog.get_item(item_id).get("price", 0))
				gained += maxi(int(Catalog.progression.get("discovery_xp_min", 5)),
					price * int(Catalog.progression.get("discovery_xp_percent", 10)) / 100)
	if gained > 0:
		add_xp(gained)


## Cuánto cuesta saltarse `seconds` segundos de espera.
func accelerate_cost(seconds: int) -> int:
	if seconds <= 0:
		return 0
	var per_minute := float(Catalog.progression.get("accelerate_coins_per_minute", 6))
	return maxi(1, int(ceil(seconds / 60.0 * per_minute)))


# --- Empleos ---

func current_job() -> Dictionary:
	return Catalog.jobs.get(job_id, {})


func shift_pay(job: Dictionary) -> int:
	return int(job.get("pay_per_hour", 0)) * int(job.get("shift_hours", 0))


func can_apply(job_to_apply: Dictionary) -> bool:
	return applied_job == "" and job_to_apply["id"] != job_id and level() >= int(job_to_apply.get("level", 1))


## Manda el currículum: la respuesta llega después de `resume_minutes` reales.
func apply_for_job(id: String) -> bool:
	var job: Dictionary = Catalog.jobs.get(id, {})
	if job.is_empty() or not can_apply(job):
		return false
	applied_job = id
	resume_ready_at = now() + int(job.get("resume_minutes", 5)) * 60
	EventBus.toast.emit("Currículum enviado: %s. Responden en %d min." % [job["name"], int(job.get("resume_minutes", 5))])
	EventBus.jobs_changed.emit()
	return true


func resume_seconds_left() -> int:
	return maxi(0, resume_ready_at - now()) if applied_job != "" else 0


## Paga para recibir la respuesta ya.
func accelerate_resume() -> bool:
	var cost := accelerate_cost(resume_seconds_left())
	if applied_job == "" or not can_change(-cost):
		return false
	add_money(-cost)
	resume_ready_at = 0
	_check_resume()
	return true


func quit_job() -> void:
	job_id = ""
	pending_pay = false
	EventBus.toast.emit("Dejaste tu empleo.")
	EventBus.jobs_changed.emit()


func _check_resume() -> void:
	if server_mode:
		# Con servidor, la respuesta la da el servidor (cuando ya es la hora).
		if applied_job != "" and now() >= resume_ready_at and now() >= _resume_check_at \
				and GameServer.online and not busy:
			_resume_check_at = now() + 10
			request("job_status")
		return
	if applied_job != "" and now() >= resume_ready_at:
		var job: Dictionary = Catalog.jobs[applied_job]
		job_id = applied_job
		applied_job = ""
		# El primer turno es al día siguiente, para no apurar a nadie.
		last_work_day = GameClock.day()
		EventBus.toast.emit("¡Te contrataron de %s! Primer turno mañana a las %02d:00." % [job["name"], int(job.get("start_hour", 9))])
		EventBus.jobs_changed.emit()


## ¿Toca empezar el turno? (hay empleo, hoy no se trabajó y ya es la hora)
func shift_due() -> bool:
	var job := current_job()
	if job.is_empty() or last_work_day >= GameClock.day():
		return false
	# Con servidor: hace falta conexión, no tener un turno sin cobrar y que
	# haya pasado el mínimo entre turnos.
	if server_mode and (not GameServer.online or pending_pay or now() < last_shift_unix + SERVER_SHIFT_GAP):
		return false
	return int(GameClock.minutes) % 1440 >= int(job.get("start_hour", 9)) * 60


func start_shift() -> void:
	last_work_day = GameClock.day()
	pending_pay = true


## Termina el turno: cobra el sueldo y suma experiencia. Devuelve lo cobrado.
func complete_shift() -> int:
	var job := current_job()
	if job.is_empty() or not pending_pay:
		return 0
	pending_pay = false
	var pay := shift_pay(job)
	add_money(pay)
	add_xp(int(job.get("xp_per_shift", 0)))
	return pay


## Un turno que quedó a medias al cerrar el juego se cobra al volver.
func settle_pending_shift() -> void:
	if pending_pay:
		var pay := complete_shift()
		EventBus.toast.emit("Cobraste el turno que quedó a medias: $%d" % pay)


## Pago por los días que pasaron sin jugar (un turno por día, con tope).
func simulate_offline(away_game_minutes: float) -> int:
	var job := current_job()
	if job.is_empty():
		return 0
	var shifts := mini(int(away_game_minutes / 1440.0), MAX_OFFLINE_SHIFTS)
	if shifts <= 0:
		return 0
	var pay := shift_pay(job) * shifts
	add_money(pay)
	add_xp(int(job.get("xp_per_shift", 0)) * shifts)
	EventBus.toast.emit("Mientras no estabas, trabajaste %d turno(s): $%d" % [shifts, pay])
	return pay


# --- Guardado ---

func to_dict() -> Dictionary:
	return {
		"money": money,
		"xp": xp,
		"discovered": discovered.keys(),
		"job": {
			"job_id": job_id,
			"applied_job": applied_job,
			"resume_ready_at": resume_ready_at,
			"last_work_day": last_work_day,
			"pending_pay": pending_pay,
			"last_shift_unix": last_shift_unix,
		},
	}


func from_dict(data: Dictionary) -> void:
	money = int(data.get("money", SaveMigrations.STARTING_MONEY))
	xp = int(data.get("xp", 0))
	discovered.clear()
	for item_id in data.get("discovered", []):
		discovered[item_id] = true
	var job: Dictionary = data.get("job", {})
	job_id = job.get("job_id", "")
	applied_job = job.get("applied_job", "")
	resume_ready_at = int(job.get("resume_ready_at", 0))
	last_work_day = int(job.get("last_work_day", 0))
	pending_pay = job.get("pending_pay", false)
	last_shift_unix = int(job.get("last_shift_unix", 0))
	_emit_changed()


# --- Servidor (Fase 4B) ---

## Activa (o apaga) el modo servidor. Lo llama la pantalla de entrada.
func use_server(enabled: bool) -> void:
	server_mode = enabled
	busy = false
	settled = false
	working_now = false
	_resume_check_at = 0
	_pay_retry_at = 0
	if not enabled:
		server_offset = 0
		shared = false
		fund = 0
		house_rev = 0


## Pide algo al servidor y espera la respuesta. De a un pedido por vez.
## Devuelve {"ok", "error" (texto para el jugador), "data" (la respuesta),
## "offline", "busy"}. Si la respuesta trae el estado, se copia aquí.
func request(rpc_id: String, payload := {}) -> Dictionary:
	if busy:
		return {"ok": false, "error": BUSY_TEXT, "data": {}, "offline": false, "busy": true}
	_set_busy(true)
	_rev_at_send = house_rev
	var result: Dictionary = await GameServer.call_rpc(rpc_id, payload)
	_set_busy(false)
	result["busy"] = false
	if not result["ok"]:
		if result.get("offline", false):
			result["error"] = OFFLINE_TEXT
		return result
	var data: Dictionary = result["data"]
	if data.get("state") is Dictionary:
		apply_server_state(data["state"])
		if house_rev == _rev_at_send + 1:
			own_rev = house_rev
	if not data.get("ok", false):
		result["ok"] = false
		result["error"] = str(data.get("error", "El servidor no aceptó el cambio."))
	return result


## Copia lo que dice el servidor (dinero, experiencia, empleo...). Avisa si
## subió de nivel o si llegó la respuesta del currículum.
func apply_server_state(state: Dictionary) -> void:
	if state.has("server_unix"):
		server_offset = int(state["server_unix"]) - int(Time.get_unix_time_from_system())
	var economy := CloudSync.economy_from_server(state, to_dict())
	var job: Dictionary = economy["job"]
	var was_applied := applied_job
	money = economy["money"]
	discovered.clear()
	for item_id in economy["discovered"]:
		discovered[item_id] = true
	job_id = job["job_id"]
	applied_job = job["applied_job"]
	resume_ready_at = job["resume_ready_at"]
	pending_pay = job["pending_pay"]
	last_shift_unix = job["last_shift_unix"]
	server_can_undo = bool(state.get("can_undo", false))
	server_can_redo = bool(state.get("can_redo", false))
	house_rev = int(state.get("house_rev", house_rev))
	shared = bool(state.get("shared", false))
	fund = int(state.get("fund", 0))
	pool_income = bool(state.get("pool_income", false))
	requests_count = int(state.get("requests", 0))
	_set_xp(economy["xp"])
	_emit_changed()
	if was_applied != "" and applied_job == "" and job_id == was_applied:
		_announce_hired()
	EventBus.jobs_changed.emit()


func _announce_hired() -> void:
	var job := current_job()
	# El primer turno es al día siguiente, para no apurar a nadie.
	last_work_day = GameClock.day()
	EventBus.toast.emit("¡Te contrataron de %s! Primer turno mañana a las %02d:00." % [job.get("name", ""), int(job.get("start_hour", 9))])


func _set_busy(value: bool) -> void:
	busy = value
	EventBus.server_busy_changed.emit(busy)


## ¿Se puede pedir algo al servidor ahora? (con servidor: conexión y nadie
## esperando). Si no, avisa por qué y devuelve false.
func can_request() -> bool:
	if not server_mode:
		return true
	if not GameServer.online:
		EventBus.toast.emit(OFFLINE_TEXT)
		return false
	if busy:
		EventBus.toast.emit(BUSY_TEXT)
		return false
	return true


# --- Pedidos que sirven en los dos modos (servidor o prueba) ---

## Manda el currículum. Devuelve true si se mandó.
func request_apply(id: String) -> bool:
	if not server_mode:
		return apply_for_job(id)
	var result := await request("job_apply", {"job_id": id})
	if not result["ok"]:
		EventBus.toast.emit(result["error"])
		return false
	var job: Dictionary = Catalog.jobs.get(id, {})
	EventBus.toast.emit("Currículum enviado: %s. Responden en %d min." % [job.get("name", ""), int(job.get("resume_minutes", 5))])
	return true


## Paga para que respondan ya al currículum.
func request_accelerate_resume() -> bool:
	if not server_mode:
		return accelerate_resume()
	var result := await request("job_accelerate")
	if not result["ok"]:
		EventBus.toast.emit(result["error"])
	return result["ok"]


func request_quit() -> bool:
	if not server_mode:
		quit_job()
		return true
	var result := await request("job_quit")
	if result["ok"]:
		EventBus.toast.emit("Dejaste tu empleo.")
	else:
		EventBus.toast.emit(result["error"])
	return result["ok"]


## El personaje llegó a la acera: empieza el turno. Devuelve false si el
## servidor no lo dejó (por ejemplo, sin conexión); ese día ya no lo intenta.
func request_shift_start() -> bool:
	if not server_mode:
		start_shift()
		return true
	last_work_day = GameClock.day()
	var result := await request("shift_start")
	if not result["ok"]:
		EventBus.toast.emit("Hoy no pudo ir a trabajar: " + result["error"])
	return result["ok"]


## Terminó el turno: lo cobra. Devuelve lo cobrado (0 si no se pudo; con
## servidor se reintenta solo más tarde y avisa al cobrarlo).
func request_shift_pay() -> int:
	if not server_mode:
		return complete_shift()
	var result := await request("shift_complete")
	if result["ok"]:
		return int(result["data"].get("pay", 0))
	_pay_retry_at = now() + maxi(5, int(result["data"].get("seconds_left", 15)))
	return 0


## Al entrar al juego: cobra el turno que quedó a medias y los días sin
## jugar (tope 3). `away_minutes` solo se usa en el modo de prueba: con
## servidor, el servidor mide el tiempo con su propia hora.
func request_settle(away_minutes: float) -> void:
	if not server_mode:
		settle_pending_shift()
		simulate_offline(away_minutes)
		return
	if not GameServer.online or _settling:
		return  # Se cobra al reconectar.
	_settling = true
	while busy:
		await get_tree().process_frame
	var result := await request("work_settle")
	_settling = false
	if not result["ok"]:
		return
	settled = true
	GameServer.heartbeat_enabled = true
	var data: Dictionary = result["data"]
	var where := " (a la caja de la casa)" if data.get("to_fund", false) else ""
	if int(data.get("pending_pay", 0)) > 0:
		EventBus.toast.emit("Cobraste el turno que quedó a medias: $%d%s" % [int(data["pending_pay"]), where])
	if int(data.get("offline_shifts", 0)) > 0:
		EventBus.toast.emit("Mientras no estabas, trabajaste %d turno(s): $%d%s" % [int(data["offline_shifts"]), int(data["offline_pay"]), where])
	if data.has("pending_seconds_left"):
		_pay_retry_at = now() + int(data["pending_seconds_left"])


## Un turno que el servidor todavía no pagó (se cortó la conexión, o se
## cerró el juego en medio): se vuelve a intentar cobrarlo.
func _retry_pending_pay() -> void:
	if not pending_pay or working_now or busy or not GameServer.online or now() < _pay_retry_at:
		return
	_pay_retry_at = now() + 15
	var pay := await request_shift_pay()
	if pay > 0:
		EventBus.toast.emit("Cobraste el turno que quedó pendiente: $%d" % pay)


## Para las demos y pruebas: todo desbloqueado y con dinero de sobra.
func debug_unlock_all() -> void:
	money = 1000000
	xp = int(Catalog.progression.get("levels", [0])[-1])
	_emit_changed()


func _emit_changed() -> void:
	var progress := xp_progress()
	EventBus.economy_changed.emit(money, level(), progress.x, progress.y)
	EventBus.fund_changed.emit(shared, fund)


func _on_game_saving() -> void:
	GameState.economy = to_dict()
