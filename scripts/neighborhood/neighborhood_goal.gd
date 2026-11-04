class_name NeighborhoodGoal
extends RefCounted
## Meta del barrio por participación (Fase 8D), del lado del teléfono.
##
## Con cuenta (modo servidor) el que cuenta y acredita es el SERVIDOR
## (neighborhood_goals.lua: `goal_load` y `goal_claim`); acá solo se guarda lo
## último que dijo. Sin cuenta (partida local) las mismas reglas corren acá, con
## los mismos números. Los dos leen la meta de data/neighborhood.json ("goal").
##
## Principios (VISION.md): se mide participación, no dinero; sin fecha límite ni
## castigo; la recompensa es chica y opcional.

const SECONDS_PER_DAY := 86400

## Quién da la casa del jugador (HouseData). Lo pone el controlador del barrio.
static var house_provider := Callable()
## Lo último que dijo el servidor.
static var _server_summary: Dictionary = {}


static func config() -> Dictionary:
	var raw: Dictionary = NeighborhoodMap.data().get("goal", {})
	var neighbors: Dictionary = raw.get("neighbors", {})
	var reward: Dictionary = raw.get("reward", {})
	var per_min := maxi(0, int(neighbors.get("per_day_min", 1)))
	return {
		"id": str(raw.get("id", "plants_together")),
		"name": str(raw.get("name", "Meta del barrio")),
		"target": maxi(1, int(raw.get("target", 50))),
		"categories": raw.get("categories", []),
		"daily_cap": maxi(0, int(raw.get("daily_cap", 10))),
		"share": clampf(float(neighbors.get("share", 0.6)), 0.0, 1.0),
		"per_min": per_min,
		"per_max": maxi(per_min, int(neighbors.get("per_day_max", 3))),
		"salt": int(neighbors.get("salt", 5)),
		"reward_money": maxi(0, int(reward.get("money", 0))),
		"reward_xp": maxi(0, int(reward.get("xp", 0))),
	}


# --- Las reglas (copia exacta de neighborhood_goals.lua) ---

static func day_of(now: int) -> int:
	return int(floor(float(now) / SECONDS_PER_DAY))


## Piezas terminadas de la casa que cuentan (por categoría del catálogo).
static func count_items(cfg: Dictionary, house: HouseData, now: int) -> int:
	var total := 0
	for level in house.levels:
		for key in level["objects"]:
			var value: Dictionary = level["objects"][key]
			var item := Catalog.get_item(value.get("item", ""))
			if item.get("category", "") in cfg["categories"] and int(value.get("ready_at", 0)) <= now:
				total += 1
	return total


## Lo que aportan los vecinos simulados `days` días después de empezar.
static func neighbors_progress(cfg: Dictionary, days: int) -> int:
	var cap := int(floor(float(cfg["target"]) * float(cfg["share"])))
	var span: int = int(cfg["per_max"]) - int(cfg["per_min"]) + 1
	var total := 0
	for day in range(1, maxi(0, days) + 1):
		total += int(cfg["per_min"]) + ((day * 7 + int(cfg["salt"])) % span)
		if total >= cap:
			return cap
	return mini(total, cap)


static func new_record(cfg: Dictionary) -> Dictionary:
	return {"goal": cfg["id"], "started_day": -1, "mine": 0, "credited": 0, "day": -1, "today": 0, "claimed": false}


## Pone al día el registro con `counted` piezas. Devuelve lo acreditado.
static func update(cfg: Dictionary, record: Dictionary, now: int, counted: int) -> int:
	var day := day_of(now)
	if int(record["started_day"]) < 0:
		record["started_day"] = day
	if int(record["day"]) != day:
		record["day"] = day
		record["today"] = 0
	var pending := maxi(0, counted - int(record["credited"]))
	var room := maxi(0, int(cfg["daily_cap"]) - int(record["today"]))
	var gained := mini(pending, room)
	if gained > 0:
		record["credited"] += gained
		record["mine"] += gained
		record["today"] += gained
	return gained


static func make_summary(cfg: Dictionary, record: Dictionary, now: int) -> Dictionary:
	var day := day_of(now)
	var started := int(record["started_day"])
	var days := maxi(0, day - started) if started >= 0 else 0
	var neighbors := neighbors_progress(cfg, days)
	var total := neighbors + int(record["mine"])
	return {
		"id": cfg["id"], "name": cfg["name"], "target": cfg["target"],
		"mine": int(record["mine"]), "today": int(record["today"]) if int(record["day"]) == day else 0,
		"daily_cap": cfg["daily_cap"], "neighbors": neighbors, "total": total,
		"completed": total >= int(cfg["target"]), "claimed": bool(record["claimed"]),
		"reward": {"money": cfg["reward_money"], "xp": cfg["reward_xp"]},
	}


# --- Uso desde la interfaz ---

static func _local_record(cfg: Dictionary) -> Dictionary:
	var saved: Variant = GameState.settings.get("neighborhood_goal", {})
	if saved is Dictionary and saved.get("goal", "") == cfg["id"]:
		return saved
	var record := new_record(cfg)
	GameState.settings["neighborhood_goal"] = record
	return record


## Lo que se muestra ahora (sin esperar al servidor).
static func summary() -> Dictionary:
	var cfg := config()
	if Economy.server_mode:
		if not _server_summary.is_empty():
			return _server_summary
		return make_summary(cfg, new_record(cfg), Economy.now())
	return make_summary(cfg, _local_record(cfg), Economy.now())


## Cuenta lo que hay en la casa y pone al día la meta. Avisa si sumó algo.
static func refresh() -> void:
	var cfg := config()
	if Economy.server_mode:
		if not GameServer.online:
			return
		var result: Dictionary = await Economy.request("goal_load")
		if result.get("ok", false) and result["data"].get("goal") is Dictionary:
			_server_summary = result["data"]["goal"]
			var gained := int(result["data"].get("gained", 0))
			if gained > 0:
				EventBus.toast.emit("¡Sumaste %d a la meta del barrio!" % gained)
			EventBus.neighborhood_goal_changed.emit()
		return
	if not house_provider.is_valid():
		return
	var house: HouseData = house_provider.call()
	var now := Economy.now()
	var record := _local_record(cfg)
	var gained := update(cfg, record, now, count_items(cfg, house, now))
	if gained > 0:
		EventBus.toast.emit("¡Sumaste %d a la meta del barrio!" % gained)
	EventBus.neighborhood_goal_changed.emit()


## Retira la recompensa (una sola vez, solo si se cumplió y se aportó algo).
static func claim_reward() -> void:
	var cfg := config()
	if Economy.server_mode:
		if not GameServer.online:
			EventBus.toast.emit(Economy.OFFLINE_TEXT)
			return
		var result: Dictionary = await Economy.request("goal_claim")
		if result.get("ok", false):
			_server_summary = result["data"].get("goal", _server_summary)
			EventBus.toast.emit("Recompensa del barrio: $%d" % int(result["data"].get("money_change", 0)))
		else:
			EventBus.toast.emit(str(result.get("error", "No se pudo retirar.")))
		EventBus.neighborhood_goal_changed.emit()
		return
	var record := _local_record(cfg)
	var s := make_summary(cfg, record, Economy.now())
	if not s["completed"] or record["claimed"] or int(record["mine"]) <= 0:
		EventBus.toast.emit("Todavía no se puede retirar la recompensa.")
		return
	record["claimed"] = true
	Economy.add_money(int(cfg["reward_money"]))
	Economy.add_xp(int(cfg["reward_xp"]))
	EventBus.toast.emit("Recompensa del barrio: $%d" % int(cfg["reward_money"]))
	EventBus.neighborhood_goal_changed.emit()
