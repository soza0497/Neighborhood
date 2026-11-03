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
## Más adelante (Fase 4) el servidor será la autoridad del dinero; por eso
## todo cambio de dinero pasa por add_money() y todo precio sale del catálogo.

## Piezas que tienen tiempo de construcción.
const TIMED_LAYERS := ["objects", "roofs"]
## Máximo de días del juego sin conectarse que se pagan de trabajo.
const MAX_OFFLINE_SHIFTS := 3

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

var _timer := 0.0


func _ready() -> void:
	from_dict(GameState.economy)
	EventBus.game_saving.connect(_on_game_saving)
	_emit_changed.call_deferred()


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = 1.0
		_check_resume()


## Hora real en segundos (para obras y currículos).
func now() -> int:
	return int(Time.get_unix_time_from_system())


# --- Dinero ---

func add_money(amount: int) -> void:
	money += amount
	_emit_changed()


## ¿Alcanza el dinero para un cambio (negativo = pago)?
func can_change(money_change: int) -> bool:
	return money + money_change >= 0


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
	var before := level()
	xp += amount
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
	_emit_changed()


## Para las demos y pruebas: todo desbloqueado y con dinero de sobra.
func debug_unlock_all() -> void:
	money = 1000000
	xp = int(Catalog.progression.get("levels", [0])[-1])
	_emit_changed()


func _emit_changed() -> void:
	var progress := xp_progress()
	EventBus.economy_changed.emit(money, level(), progress.x, progress.y)


func _on_game_saving() -> void:
	GameState.economy = to_dict()
