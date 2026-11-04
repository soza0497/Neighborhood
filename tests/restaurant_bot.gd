class_name RestaurantBot
extends RefCounted
## Un jugador automático del minijuego del restaurante, SOLO para pruebas y
## demos (no se usa en el juego). Juega como una persona ordenada: atiende
## primero al que tiene menos paciencia, arma su plato y le sirve. Toca
## cada `step_ms` como mucho.

var step_ms := 350


## La próxima acción a la hora `t`: [código, número] o [] si no hace nada.
func next_action(sim: RestaurantSim, t: int) -> Array:
	sim.advance(t)
	var target := -1
	var best := 1 << 60
	for s in sim.seats.size():
		var seat: Variant = sim.seats[s]
		if seat != null and int(seat["deadline"]) < best:
			best = int(seat["deadline"])
			target = s
	if target < 0:
		return []
	var order: Array = sim.customers[sim.seats[target]["c"]]["order"]
	var needed := order.duplicate()
	for item in sim.plate:
		var i := needed.find(item)
		if i < 0:
			return [RestaurantSim.TRASH, 0]  # Hay algo que no va: a la basura.
		needed.remove_at(i)
	if needed.is_empty():
		return [RestaurantSim.SERVE, target]
	# De la plancha: lo que está a punto y hace falta; lo quemado, a tirar.
	for g in sim.grill.size():
		var state := sim.grill_state(g, t)
		if state == "burned":
			return [RestaurantSim.GRILL, g]
		if state == "ready" and needed.has(sim.grill[g]["item"]):
			return [RestaurantSim.GRILL, g]
	var ingredients: Array = sim.svc["ingredients"]
	for item in needed:
		if not ingredients[item]["hot"]:
			return [RestaurantSim.TAKE, item]
	# Calientes que faltan y todavía no están en la plancha.
	var on_grill: Array = []
	for slot in sim.grill:
		if slot != null:
			on_grill.append(slot["item"])
	for item in needed:
		var i := on_grill.find(item)
		if i >= 0:
			on_grill.remove_at(i)
		elif sim.grill.has(null):
			return [RestaurantSim.TAKE, item]
	return []


## Juega un servicio entero sin pantalla. Devuelve los toques.
func play(sim: RestaurantSim) -> Array:
	var actions: Array = []
	var t := 500
	var end := int(sim.svc["duration_ms"])
	while t <= end:
		var a := next_action(sim, t)
		if not a.is_empty():
			sim.act(t, a[0], a[1])
			actions.append([t, a[0], a[1]])
		t += step_ms
	sim.finish()
	return actions
