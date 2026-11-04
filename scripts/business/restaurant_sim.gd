class_name RestaurantSim
extends RefCounted
## El minijuego "Servicio" del restaurante (Fase 6), sin nada de pantalla.
##
## Es COPIA EXACTA de server/nakama/modules/neighborhood_business.lua: el
## teléfono lo usa para jugar en vivo y el servidor lo repite con los mismos
## toques para decidir cuánto se cobra (el teléfono nunca manda un puntaje).
## Si cambiás una regla aquí, cambiala allá; tests/test_business.gd y
## server/tests/test_rules.lua comparan los mismos números.
##
## Todo en números enteros (milisegundos desde que empezó el servicio) y con
## un generador de números al azar simple (Park-Miller), para que dé lo
## mismo en los dos lados.
##
## Uso:
##   var sim := RestaurantSim.new(Catalog.business["restaurant"]["service"], seed, seats)
##   sim.act(t, RestaurantSim.TAKE, 0)   # cada toque, con su hora
##   sim.advance(t)                      # cada cuadro, para que lleguen y se vayan clientes
##   sim.finish()                        # al final

const TAKE := 1    ## Tomar un ingrediente (número = cuál, desde 0)
const GRILL := 2   ## Tocar un lugar de la plancha
const SERVE := 3   ## Servir el plato a una mesa
const TRASH := 4   ## Tirar el plato

const _MOD := 2147483647
const _MUL := 16807
const _BIG := 1000000000000000

## Números del servicio (data/business.json → restaurant.service).
var svc: Dictionary = {}
## Clientes: [{arrive, order (Array de ingredientes), patience}].
var customers: Array = []
## Próximo cliente por llegar (índice en customers).
var next_customer := 0
## Mesas: null = libre, o {c (índice del cliente), deadline (ms)}.
var seats: Array = []
## Ingredientes en el plato (índices).
var plate: Array = []
## Plancha: null = libre, o {item, placed (ms)}.
var grill: Array = []
var coins := 0
var tips := 0
var served := 0
var lost := 0
var wrong := 0
var skipped := 0
var burned := 0
var trashed := 0
var streak := 0
var best_streak := 0
## Lo que pasó desde la última vez que la pantalla miró (para animar):
## [{type: "arrive"|"leave"|"skip"|"served"|"wrong"|"burned", seat?, coins?}].
var events: Array = []


func _init(service: Dictionary, seed_value: int, seat_count: int) -> void:
	svc = normalize_service(service)
	customers = make_customers(svc, seed_value)
	for s in maxi(1, mini(seat_count, int(svc["max_seats"]))):
		seats.append(null)
	for g in int(svc["grill_slots"]):
		grill.append(null)


## Los números del servicio como enteros (el JSON los da con coma).
static func normalize_service(service: Dictionary) -> Dictionary:
	var result := {}
	for key in service:
		var value: Variant = service[key]
		result[key] = int(value) if (value is float or value is int) else value
	var ingredients: Array = []
	for ing in service.get("ingredients", []):
		ingredients.append({"id": ing.get("id", ""), "name": ing.get("name", ""), "color": ing.get("color", "#ffffff"),
			"shape": ing.get("shape", "circle"), "hot": ing.get("hot", false) == true})
	result["ingredients"] = ingredients
	return result


# --- Números al azar (iguales en Lua) ---

static func new_rng_state(seed_value: int) -> int:
	var s := seed_value % _MOD
	if s <= 0:
		s += _MOD - 1
	return s


## La lista de clientes de una semilla (la misma que arma el servidor).
static func make_customers(service: Dictionary, seed_value: int) -> Array:
	var sim_rng := RestaurantSim._Rng.new(seed_value)
	var list: Array = []
	var t := int(service["first_arrival_ms"])
	var stop := int(service["duration_ms"]) - int(service["last_call_ms"])
	var kinds: int = service["ingredients"].size()
	while t < stop and kinds > 0:
		var phase := t / int(service["phase_ms"])
		var size_max := mini(2 + phase, int(service["plate_max"]))
		var size := 2 + sim_rng.next_int(size_max - 1)
		var order: Array = []
		for k in size:
			order.append(sim_rng.next_int(kinds))
		var patience := maxi(int(service["patience_ms"]) - phase * int(service["patience_drop_ms"]), 5000)
		list.append({"arrive": t, "order": order, "patience": patience})
		var gap := int(service["gap_min_ms"]) + sim_rng.next_int(int(service["gap_random_ms"]) + 1) \
			- phase * int(service["gap_drop_ms"])
		t += maxi(gap, 1000)
	return list


## Generador aparte (para make_customers, que es estático).
class _Rng:
	var state := 1

	func _init(seed_value: int) -> void:
		state = RestaurantSim.new_rng_state(seed_value)

	func next_int(n: int) -> int:
		state = (state * RestaurantSim._MUL) % RestaurantSim._MOD
		return state % n


# --- La simulación ---

## La mesa que se vacía primero por falta de paciencia (-1 = ninguna).
func _next_leave() -> int:
	var best := _BIG
	var seat := -1
	for s in seats.size():
		var c: Variant = seats[s]
		if c != null and int(c["deadline"]) < best:
			best = int(c["deadline"])
			seat = s
	return seat


## Avanza el reloj hasta `t`: llegan clientes (a la primera mesa libre; si no
## hay, siguen de largo) y se van los que perdieron la paciencia.
func advance(t: int) -> void:
	while true:
		var arrive: int = int(customers[next_customer]["arrive"]) if next_customer < customers.size() else _BIG
		var leave_seat := _next_leave()
		var leave: int = int(seats[leave_seat]["deadline"]) if leave_seat >= 0 else _BIG
		if mini(arrive, leave) > t:
			return
		if leave <= arrive:
			seats[leave_seat] = null
			lost += 1
			streak = 0
			events.append({"type": "leave", "seat": leave_seat})
		else:
			var free := seats.find(null)
			if free >= 0:
				var c: Dictionary = customers[next_customer]
				seats[free] = {"c": next_customer, "deadline": int(c["arrive"]) + int(c["patience"])}
				events.append({"type": "arrive", "seat": free})
			else:
				skipped += 1
				events.append({"type": "skip"})
			next_customer += 1


static func _same_items(a: Array, order: Array) -> bool:
	if a.size() != order.size():
		return false
	var counts := {}
	for i in order:
		counts[i] = int(counts.get(i, 0)) + 1
	for i in a:
		if int(counts.get(i, 0)) == 0:
			return false
		counts[i] -= 1
	return true


## Un toque del jugador a la hora `t`. Lo que no tiene sentido no hace nada.
func act(t: int, code: int, arg: int) -> void:
	advance(t)
	match code:
		TAKE:
			var ing: Dictionary = svc["ingredients"][arg]
			if ing["hot"]:
				var free := grill.find(null)
				if free >= 0:
					grill[free] = {"item": arg, "placed": t}
			elif plate.size() < int(svc["plate_max"]):
				plate.append(arg)
		GRILL:
			var slot: Variant = grill[arg]
			if slot == null:
				return
			var elapsed: int = t - int(slot["placed"])
			if elapsed < int(svc["cook_ms"]):
				return
			elif elapsed <= int(svc["cook_ms"]) + int(svc["ready_ms"]):
				if plate.size() < int(svc["plate_max"]):
					plate.append(slot["item"])
					grill[arg] = null
			else:
				grill[arg] = null
				burned += 1
				events.append({"type": "burned"})
		SERVE:
			var seat: Variant = seats[arg]
			if seat == null or plate.is_empty():
				return
			var customer: Dictionary = customers[seat["c"]]
			if _same_items(plate, customer["order"]):
				var tip: int = int(svc["tip_max"]) * (int(seat["deadline"]) - t) / int(customer["patience"])
				streak += 1
				best_streak = maxi(best_streak, streak)
				var bonus := mini((streak - 1) * int(svc["streak_bonus"]), int(svc["streak_max_bonus"]))
				var pay: int = int(svc["coin_per_item"]) * plate.size() + tip + bonus
				coins += pay
				tips += tip + bonus
				served += 1
				seats[arg] = null
				events.append({"type": "served", "seat": arg, "coins": pay})
			else:
				seat["deadline"] = int(seat["deadline"]) - int(svc["wrong_penalty_ms"])
				wrong += 1
				streak = 0
				events.append({"type": "wrong", "seat": arg})
				if int(seat["deadline"]) <= t:
					seats[arg] = null
					lost += 1
					events.append({"type": "leave", "seat": arg})
			plate = []
		TRASH:
			if not plate.is_empty():
				trashed += 1
			plate = []


## Termina el servicio (los que siguen sentados no cuentan).
func finish() -> void:
	advance(int(svc["duration_ms"]))


## Estado de un lugar de la plancha a la hora `t`: "empty", "cooking",
## "ready" o "burned" (para dibujarlo).
func grill_state(slot_index: int, t: int) -> String:
	var slot: Variant = grill[slot_index]
	if slot == null:
		return "empty"
	var elapsed: int = t - int(slot["placed"])
	if elapsed < int(svc["cook_ms"]):
		return "cooking"
	if elapsed <= int(svc["cook_ms"]) + int(svc["ready_ms"]):
		return "ready"
	return "burned"


## Resultado (los mismos campos que devuelve el servidor).
func result() -> Dictionary:
	return {"coins": coins, "tips": tips, "served": served, "lost": lost, "wrong": wrong, "skipped": skipped,
		"burned": burned, "trashed": trashed, "best_streak": best_streak, "customers": customers.size()}


## Revisa los toques como el servidor. "" = bien; si no, el motivo.
static func validate_actions(service: Dictionary, seat_count: int, actions: Array) -> String:
	if actions.size() > int(service["max_actions"]):
		return "demasiados toques"
	var limits := {TAKE: service["ingredients"].size(), GRILL: int(service["grill_slots"]),
		SERVE: maxi(1, mini(seat_count, int(service["max_seats"]))), TRASH: 1}
	var last := -1
	for i in actions.size():
		var a: Variant = actions[i]
		if not (a is Array) or a.size() < 3:
			return "acción %d inválida" % (i + 1)
		var t := int(a[0])
		var code := int(a[1])
		var arg := int(a[2])
		if t < 0 or t > int(service["duration_ms"]):
			return "acción %d fuera de tiempo" % (i + 1)
		if not limits.has(code) or arg < 0 or arg >= int(limits[code]):
			return "acción %d inválida" % (i + 1)
		if last >= 0 and t < last + int(service["min_gap_ms"]):
			return "toques demasiado rápidos"
		last = t
	return ""


## Repite un servicio entero (como el servidor). Devuelve el resultado, o
## {"invalid": motivo}.
static func replay(service: Dictionary, seed_value: int, seat_count: int, actions: Array) -> Dictionary:
	var clean := normalize_service(service)
	var why := validate_actions(clean, seat_count, actions)
	if why != "":
		return {"invalid": why}
	var sim := RestaurantSim.new(clean, seed_value, seat_count)
	for a in actions:
		sim.act(int(a[0]), int(a[1]), int(a[2]))
	sim.finish()
	return sim.result()


# --- El restaurante de la casa ---

## ¿Qué le falta a la casa para ser restaurante? (como el servidor: solo
## cuentan los muebles terminados). Devuelve {"missing": [{id, name, need,
## have}], "seats": mesas que dan lugar}.
static func requirements(restaurant: Dictionary, house: HouseData, now_unix: int) -> Dictionary:
	var counts := {}
	for level in house.levels.size():
		for value in house.get_layer(level, "objects").values():
			if value is Dictionary and value.has("item") and int(value.get("ready_at", 0)) <= now_unix:
				counts[value["item"]] = int(counts.get(value["item"], 0)) + 1
	var ids: Array = restaurant.get("requires", {}).keys()
	ids.sort()
	var missing: Array = []
	for id in ids:
		var need := int(restaurant["requires"][id])
		var have := int(counts.get(id, 0))
		if have < need:
			missing.append({"id": id, "name": Catalog.get_item(id).get("name", id), "need": need, "have": have})
	var max_seats := int(restaurant.get("service", {}).get("max_seats", 3))
	return {"missing": missing, "seats": mini(int(counts.get(restaurant.get("seats_item", ""), 0)), max_seats)}
