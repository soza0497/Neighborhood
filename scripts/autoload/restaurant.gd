extends Node
## El restaurante del jugador (Fase 6), del lado del teléfono.
##
## El que decide es el servidor (neighborhood_business.lua): aquí solo se
## pide, se guarda lo que respondió (`summary`) y se avisa a la interfaz
## (EventBus.restaurant_changed). El minijuego se juega en
## ui/restaurant_game.gd con RestaurantSim; al terminar, este archivo manda
## los toques y el servidor dice cuánto se cobró.
##
## Sin conexión (o "Jugar sin conexión") se puede PRACTICAR: mismo juego,
## sin cobrar. Si la conexión se corta justo al terminar un servicio de
## verdad, los toques quedan guardados en la partida (GameState.restaurant)
## y se mandan solos al volver (el servidor los acepta hasta 24 h después).

## Último estado del servidor (ver business.summary en Lua): open, ready,
## missing, seats, passive, passive_cap, day_earned, cap_left, daily_cap,
## resets_in, services, best, active, shared. Vacío = todavía no se sabe.
var summary: Dictionary = {}
## Hay un servicio de verdad en juego ahora (empezado en el servidor).
var playing := false

var _sending := false
var _retry_timer := 0.0


func _ready() -> void:
	EventBus.server_status_changed.connect(_on_server_status)
	EventBus.game_loaded.connect(func(): summary = {})


## Un servicio sin cobrar se manda solo al volver la conexión (cada 10 s
## lo intenta, cuando el juego ya terminó de entrar con el servidor).
func _process(delta: float) -> void:
	_retry_timer -= delta
	if _retry_timer > 0.0:
		return
	_retry_timer = 10.0
	if has_pending() and not playing and not _sending and _online() and Economy.settled and not Economy.busy:
		send_pending(false)


## Los números del restaurante (data/business.json).
func config() -> Dictionary:
	return Catalog.business.get("restaurant", {})


func service_config() -> Dictionary:
	return config().get("service", {})


## ¿Está abierto? (lo último que dijo el servidor).
func is_open() -> bool:
	return bool(summary.get("open", false))


## Hay un servicio jugado que el servidor todavía no cobró.
func has_pending() -> bool:
	return not GameState.restaurant.get("actions", []).is_empty() or GameState.restaurant.has("started_unix")


## Copia el resumen que manda el servidor (las listas vacías llegan como {}).
static func normalize(data: Variant) -> Dictionary:
	var s: Dictionary = data if data is Dictionary else {}
	var result := {
		"open": bool(s.get("open", false)), "ready": bool(s.get("ready", false)), "missing": [],
		"seats": int(s.get("seats", 0)), "passive": int(s.get("passive", 0)),
		"passive_cap": int(s.get("passive_cap", 0)), "passive_per_hour": int(s.get("passive_per_hour", 0)),
		"day_earned": int(s.get("day_earned", 0)), "cap_left": int(s.get("cap_left", 0)),
		"daily_cap": int(s.get("daily_cap", 0)), "resets_in": int(s.get("resets_in", 0)),
		"services": int(s.get("services", 0)), "best": int(s.get("best", 0)), "total": int(s.get("total", 0)),
		"active": {}, "shared": bool(s.get("shared", false)),
	}
	var missing: Variant = s.get("missing", [])
	if missing is Array:
		for m in missing:
			result["missing"].append({"id": str(m.get("id", "")), "name": str(m.get("name", "")),
				"need": int(m.get("need", 1)), "have": int(m.get("have", 0))})
	var active: Variant = s.get("active")
	if active is Dictionary and not active.is_empty():
		result["active"] = {"seed": int(active.get("seed", 0)), "seats": int(active.get("seats", 0)),
			"started_unix": int(active.get("started_unix", 0)), "seconds_left": int(active.get("seconds_left", 0))}
	return result


## Texto de lo que falta ("Mostrador, Plancha de restaurante").
static func missing_text(missing: Array) -> String:
	var names: PackedStringArray = []
	for m in missing:
		names.append(m["name"])
	return ", ".join(names)


func _take_summary(data: Dictionary) -> void:
	if data.get("restaurant") is Dictionary:
		summary = normalize(data["restaurant"])
	EventBus.restaurant_changed.emit()


func _online() -> bool:
	return Economy.server_mode and GameServer.online


## Pregunta al servidor cómo está el restaurante (y manda un servicio
## pendiente, si quedó alguno).
func refresh() -> void:
	if not _online():
		EventBus.restaurant_changed.emit()
		return
	if has_pending() and not playing:
		await send_pending(false)
	if Economy.busy:
		return
	var result := await Economy.request("restaurant_load")
	if result["ok"]:
		_take_summary(result["data"])


## Abrir o cerrar. En la casa compartida queda como pedido para la pareja.
func set_open(open: bool) -> bool:
	if not Economy.can_request():
		return false
	var result := await Economy.request("restaurant_open" if open else "restaurant_close")
	if not result["ok"]:
		EventBus.toast.emit(result["error"])
		return false
	var data: Dictionary = result["data"]
	_take_summary(data)
	if data.get("requested", false):
		EventBus.toast.emit("Le pediste permiso a tu pareja para %s." % data.get("text", ""))
	else:
		EventBus.toast.emit("¡Restaurante abierto!" if open else "Cerraste el restaurante.")
	return true


## Cobrar lo que juntó solo (clientes de paso).
func collect() -> int:
	if not Economy.can_request():
		return 0
	var result := await Economy.request("restaurant_collect")
	if not result["ok"]:
		EventBus.toast.emit(result["error"])
		return 0
	var data: Dictionary = result["data"]
	_take_summary(data)
	var coins := int(data.get("coins", 0))
	var where := " a la caja de la casa" if data.get("to_fund", false) else ""
	EventBus.toast.emit("Cobraste $%d del restaurante%s." % [coins, where])
	return coins


## Empieza un servicio de verdad: el servidor da la semilla y las mesas.
## Devuelve {ok, seed, seats, practice = false} o {ok = false}.
func start_service() -> Dictionary:
	if has_pending():
		await send_pending(false)
		if has_pending():
			EventBus.toast.emit("Todavía hay un servicio sin cobrar: esperá unos segundos.")
			return {"ok": false}
	if not Economy.can_request():
		return {"ok": false}
	var result := await Economy.request("service_start")
	if not result["ok"]:
		EventBus.toast.emit(result["error"])
		return {"ok": false}
	var data: Dictionary = result["data"]
	playing = true
	GameState.restaurant = {"started_unix": int(data.get("started_unix", 0)), "actions": []}
	return {"ok": true, "seed": int(data["seed"]), "seats": int(data["seats"]), "practice": false,
		"cap_left": int(data.get("cap_left", 0))}


## Una práctica (sin servidor, no cobra): semilla al azar.
func start_practice(seats: int) -> Dictionary:
	return {"ok": true, "seed": randi_range(1, 2147483646), "seats": clampi(seats, 1, 3), "practice": true}


## Terminó un servicio de verdad: manda los toques. Si no hay conexión,
## quedan guardados para mandarlos al volver. Devuelve la respuesta del
## servidor ({valid, coins, pay, capped, ...}) o {"pending": true}.
func finish_service(actions: Array) -> Dictionary:
	playing = false
	GameState.restaurant["actions"] = actions
	SaveSystem.save_game()
	return await send_pending()


## Guarda un toque mientras se juega (si el teléfono se apaga en medio, lo
## jugado se manda al volver y se cobra lo que se sirvió).
func record_action(action: Array) -> void:
	if playing:
		GameState.restaurant.get_or_add("actions", []).append(action)


## Manda el servicio guardado. El servidor puede decir "todavía no
## terminó" (si el reloj del teléfono va rápido): con `wait_if_early` se
## reintenta unos segundos; si no, queda para después.
func send_pending(wait_if_early := true) -> Dictionary:
	if _sending or playing or not has_pending():
		return {"pending": has_pending()}
	_sending = true
	var answer := {"pending": true}
	for attempt in 6:
		if not _online():
			break
		while Economy.busy:
			await get_tree().process_frame
		var result := await Economy.request("service_finish", {"actions": GameState.restaurant.get("actions", [])})
		if result.get("offline", false):
			break
		var data: Dictionary = result["data"]
		if not result["ok"] and data.get("reason", "") == "too_early":
			if not wait_if_early:
				break
			await get_tree().create_timer(clampf(float(data.get("seconds_left", 1)), 1.0, 4.0)).timeout
			continue
		# Respondió (cobró, lo anuló o ya no había servicio): listo.
		GameState.restaurant = {}
		SaveSystem.save_game()
		_take_summary(data)
		answer = data
		if not result["ok"]:
			answer = {"valid": false, "error_text": result["error"]}
		_announce(answer)
		break
	_sending = false
	return answer


func _announce(data: Dictionary) -> void:
	if not data.get("valid", false):
		EventBus.toast.emit(str(data.get("error_text", "El servicio no se cobró.")))
		return
	var where := " (a la caja de la casa)" if data.get("to_fund", false) else ""
	var text := "Servicio: cobraste $%d%s." % [int(data.get("pay", 0)), where]
	if data.get("capped", false):
		text += " Llegaste al tope de hoy."
	EventBus.toast.emit(text)


func _on_server_status(online: bool, _username: String) -> void:
	if online and has_pending() and Economy.server_mode:
		send_pending(false)
