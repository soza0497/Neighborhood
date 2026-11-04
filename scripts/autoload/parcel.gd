extends Node
## La parcela del jugador (Pulido 2C): obstáculos, limpieza y servicios.
##
## Con servidor, el que decide (y cobra) es el servidor: `parcel_load`,
## `parcel_clear_start` y `parcel_clear_finish` (neighborhood.lua). Sin cuenta
## (partida local) las mismas reglas corren acá con el dinero del teléfono.
##
## Los obstáculos se generan desde una semilla con ParcelRules (el servidor
## genera los mismos). Lo limpiado y lo "en camino" vive acá, y las celdas
## que siguen ocupadas se le pasan a HouseData.blocked_cells (así las reglas
## del constructor impiden poner nada encima).

## Cambió algo de la parcela (se redibuja y se revisa "lo que falta").
signal changed
## El servicio de un obstáculo llegó (pasó la espera): hay que mandarlo.
signal service_due(id: String)

var cfg: Dictionary = {}
var seed := 0
var obstacles: Array = []
## id → true
var cleared: Dictionary = {}
## id → {ready_at (segundos Unix), service}
var pending: Dictionary = {}
var count := 0

var _check_timer := 0.0
var _announced: Dictionary = {}


func _ready() -> void:
	cfg = ParcelRules.config()
	EventBus.game_loaded.connect(_on_game_loaded)
	EventBus.game_saving.connect(func() -> void: GameState.parcel = to_dict())
	# Pulido 3A: al subir de nivel se pueden abrir terrenos nuevos.
	EventBus.level_up.connect(func(_l: int, _n: Array) -> void: _rebuild())
	setup_local(GameState.parcel)


## Partida local (o sin servidor): semilla guardada o una fija.
func setup_local(saved: Dictionary) -> void:
	seed = int(saved.get("seed", ParcelRules.seed_from_text("local")))
	cleared = {}
	for id in saved.get("cleared", []):
		cleared[str(id)] = true
	pending = {}
	for id in saved.get("pending", {}):
		pending[str(id)] = saved["pending"][id]
	count = int(saved.get("count", cleared.size()))
	_rebuild()


func to_dict() -> Dictionary:
	return {"seed": seed, "cleared": cleared.keys(), "pending": pending, "count": count}


## Con servidor: se pide al entrar y se copia lo que dice.
func _on_game_loaded() -> void:
	_rebuild()  # El nivel (y con él la zona abierta) ya se cargó.
	if Economy.server_mode:
		refresh()


func refresh() -> void:
	if not Economy.server_mode or not GameServer.online:
		return
	var result: Dictionary = await GameServer.call_rpc("parcel_load", {})
	if result.get("ok", false) and result["data"].get("parcel") is Dictionary:
		apply_summary(result["data"]["parcel"])


## Copia lo que dijo el servidor (`parcel` en sus respuestas).
func apply_summary(summary: Dictionary) -> void:
	seed = int(summary.get("seed", seed))
	cleared = {}
	for id in summary.get("cleared", []):
		cleared[str(id)] = true
	pending = {}
	var raw: Variant = summary.get("pending", {})
	if raw is Dictionary:
		for id in raw:
			pending[str(id)] = {"ready_at": int(raw[id].get("ready_at", 0)), "service": str(raw[id].get("service", ""))}
	count = int(summary.get("count", cleared.size()))
	_rebuild()


## Zona usable hoy (Pulido 3A): lista de [x, z, ancho, fondo]. Depende del nivel.
func zone_rects() -> Array:
	return ParcelRules.zone_rects(cfg, Economy.level())


## Cuadro que envuelve toda la zona usable hoy (para vallas y cámara).
func zone_bounds() -> Rect2i:
	var rects := zone_rects()
	var bounds := Rect2i(rects[0][0], rects[0][1], rects[0][2], rects[0][3])
	for r in rects:
		bounds = bounds.merge(Rect2i(r[0], r[1], r[2], r[3]))
	return bounds


## Celdas bloqueadas hoy: obstáculos sin limpiar y zona todavía cerrada.
func blocked_now() -> Dictionary:
	return ParcelRules.blocked_cells(obstacles, cleared, ParcelRules.locked_cells(cfg, Economy.level()))


## Vuelve a leer la configuración (el tamaño de la parcela pudo cambiar).
func refresh_config() -> void:
	cfg = ParcelRules.config()
	_rebuild()


func _rebuild() -> void:
	cfg = ParcelRules.config()
	obstacles = ParcelRules.generate(cfg, seed)
	HouseData.blocked_cells = blocked_now()
	changed.emit()
	EventBus.parcel_changed.emit()


func _process(delta: float) -> void:
	_check_timer -= delta
	if _check_timer > 0.0:
		return
	_check_timer = 1.0
	var now := Economy.now()
	for id in pending:
		if int(pending[id]["ready_at"]) <= now and not _announced.has(id):
			_announced[id] = true
			service_due.emit(id)


## Revisa ya los servicios en camino (al abrir la escena).
func check_now() -> void:
	_announced.clear()
	_check_timer = 0.0


# --- Consultas ---

func obstacle(id: String) -> Dictionary:
	return ParcelRules.find(obstacles, id)


func definition(id: String) -> Dictionary:
	return cfg["obstacles"].get(obstacle(id).get("kind", ""), {})


## Lo que cuesta llamar hoy al servicio para ese obstáculo.
func cost_of(id: String) -> int:
	var o := obstacle(id)
	return ParcelRules.cost(cfg, o["kind"], count) if not o.is_empty() else 0


## Obstáculo que ocupa una celda ("" si ninguno).
func obstacle_at(cell: Vector2i) -> String:
	var id := str(HouseData.blocked_cells.get("%d,%d" % [cell.x, cell.y], ""))
	return "" if id == "zone" else id


## ¿Esa celda es de la zona todavía cerrada? (se ve, pero no se pisa)
func is_locked(cell: Vector2i) -> bool:
	return str(HouseData.blocked_cells.get("%d,%d" % [cell.x, cell.y], "")) == "zone"


## ¿Puede llegar el servicio? {ok, reason, path}. Se mira con la casa de hoy.
func access(id: String, house: HouseData) -> Dictionary:
	var o := obstacle(id)
	if o.is_empty():
		return {"ok": false, "reason": "Ese obstáculo no existe.", "path": []}
	var blocked := blocked_now()
	for cx in range(o["x"], o["x"] + o["w"]):
		for cz in range(o["z"], o["z"] + o["d"]):
			blocked.erase("%d,%d" % [cx, cz])
	var house_cells := {}
	for key in house.get_layer(0, "foundation"):
		house_cells[key] = true
	return ParcelRules.find_path(cfg, blocked, house_cells, o, str(definition(id).get("vehicle", "")) != "")


# --- Llamar al servicio ---

## Cobra y empieza la espera. Devuelve {ok, error}.
func call_service(id: String, house: HouseData) -> Dictionary:
	var o := obstacle(id)
	if o.is_empty() or cleared.has(id) or pending.has(id):
		return {"ok": false, "error": "Eso ya está en marcha o limpio."}
	if not ParcelRules.in_zone(zone_rects(), o["x"], o["z"], o["w"], o["d"]):
		return {"ok": false, "error": "Ese terreno todavía no es tuyo: se abre al subir de nivel."}
	var path := access(id, house)
	if not path["ok"]:
		return {"ok": false, "error": path["reason"]}
	var cost := cost_of(id)
	if Economy.server_mode:
		if not Economy.can_request():
			return {"ok": false, "error": Economy.OFFLINE_TEXT}
		var result: Dictionary = await Economy.request("parcel_clear_start", {"id": id})
		if not result["ok"]:
			return {"ok": false, "error": result["error"]}
		if result["data"].get("parcel") is Dictionary:
			apply_summary(result["data"]["parcel"])
		return {"ok": true, "error": ""}
	if Economy.money < cost:
		return {"ok": false, "error": "Te faltan $%d para llamar al servicio." % (cost - Economy.money)}
	Economy.add_money(-cost)
	pending[id] = {"ready_at": Economy.now() + int(definition(id)["seconds"]), "service": definition(id)["service"]}
	changed.emit()
	EventBus.parcel_changed.emit()
	return {"ok": true, "error": ""}


## El servicio llegó y terminó su trabajo: limpia. Devuelve
## {ok, blocked, reason}. Si el vehículo no puede entrar, sigue en camino.
func finish(id: String, house: HouseData) -> Dictionary:
	if not pending.has(id):
		return {"ok": false, "blocked": false, "reason": "No hay servicio en camino."}
	_announced.erase(id)
	if Economy.server_mode:
		var result: Dictionary = await Economy.request("parcel_clear_finish", {"id": id})
		if not result["ok"]:
			return {"ok": false, "blocked": false, "reason": result["error"]}
		var data: Dictionary = result["data"]
		if data.get("parcel") is Dictionary:
			apply_summary(data["parcel"])
		if data.get("blocked", false):
			return {"ok": false, "blocked": true, "reason": str(data.get("reason", ""))}
		return {"ok": true, "blocked": false, "reason": ""}
	var path := access(id, house)
	if not path["ok"]:
		return {"ok": false, "blocked": true, "reason": path["reason"]}
	var def := definition(id)
	pending.erase(id)
	cleared[id] = true
	count += 1
	Economy.add_xp(int(def.get("xp", 0)))
	_rebuild()
	return {"ok": true, "blocked": false, "reason": ""}
