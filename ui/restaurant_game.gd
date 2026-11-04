extends Control
## El minijuego del restaurante: "Servicio" (Fase 6). Dura 1:30.
##
## Llegan clientes a las mesas (arriba) con su pedido en un globito. Se arma
## el plato tocando los ingredientes (abajo): los fríos van directo al
## plato; los calientes (con llamita) van a la plancha, y hay que sacarlos
## cuando están a punto (brillan) antes de que se quemen. Después se toca al
## cliente para servirle. Si es lo que pidió (sin importar el orden) paga,
## con propina si fue rápido y extra por la racha; si no, se enoja un poco.
##
## Las reglas están en RestaurantSim (la misma copia que repite el
## servidor). Esta pantalla solo dibuja, recibe los toques y anota cada uno
## con su hora: eso es lo único que se manda al servidor.
##
## Todo se dibuja con figuras simples (círculos, cajas), sin arte final.

## Terminó (el panel del restaurante se vuelve a abrir).
signal closed

const COUNTDOWN_MS := 2400
const FLOAT_MS := 1100

const COLOR_WALL := Color("ffe7c2")
const COLOR_STRIPE := Color("ffd59a")
const COLOR_COUNTER := Color("c98b5a")
const COLOR_COUNTER_TOP := Color("e3a670")
const COLOR_INK := Color("3b2a20")
const COLOR_CARD := Color(1, 1, 1, 0.55)
const COLOR_GOOD := Color("4caf6a")
const COLOR_BAD := Color("e0564a")
const SKINS := [Color("f6d2b3"), Color("e0ac83"), Color("b97c55"), Color("8a5636"), Color("fbe3cf")]
const HAIRS := [Color("3b2a20"), Color("e0b040"), Color("a0452a"), Color("5c6b80"), Color("1f1a17"), Color("d98cb3")]
const SHIRTS := [Color("7fb3ff"), Color("78c49a"), Color("ff9db5"), Color("ffd966"), Color("c8b3ff"), Color("ff8f6b")]

var sim: RestaurantSim
var practice := false
var seats := 3
var seed_value := 0
## Toques anotados: [[t, código, número], ...] (lo que va al servidor).
var actions: Array = []

var _service: Dictionary = {}
var _start_ms := 0
var _running := false
var _done := false
var _floats: Array = []
var _shake := {}
var _last_action_t := -100000
var _rects := {}
var _result_panel: PanelContainer
var _result_label: Label
var _done_button: Button
var _font: Font


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font = ThemeDB.fallback_font
	_build_result_panel()
	resized.connect(_layout)
	EventBus.restaurant_service_requested.connect(start)


## Empieza un servicio: {seed, seats, practice}.
func start(info: Dictionary) -> void:
	_service = RestaurantSim.normalize_service(Restaurant.service_config())
	practice = bool(info.get("practice", false))
	seats = int(info.get("seats", 3))
	seed_value = int(info.get("seed", 1))
	sim = RestaurantSim.new(_service, seed_value, seats)
	actions = []
	_floats = []
	_shake = {}
	_last_action_t = -100000
	_done = false
	_running = true
	_start_ms = Time.get_ticks_msec() + COUNTDOWN_MS
	_result_panel.visible = false
	show()
	_layout()


## Milisegundos del servicio (negativo durante la cuenta regresiva).
func service_time() -> int:
	return Time.get_ticks_msec() - _start_ms


func _process(_delta: float) -> void:
	if not visible or sim == null:
		return
	var t := service_time()
	if _running and t >= 0:
		var end := int(_service["duration_ms"])
		sim.advance(mini(t, end))
		_take_events(mini(t, end))
		if t >= end:
			_finish()
	queue_redraw()


# --- Toques ---

func _gui_input(event: InputEvent) -> void:
	var pos := Vector2.ZERO
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
	else:
		return
	accept_event()
	tap(pos)


## Un toque en la pantalla (también lo usan las demos).
func tap(pos: Vector2) -> void:
	if not _running or _done:
		return
	var t := service_time()
	if t < 0 or t > int(_service["duration_ms"]):
		return
	for key in _rects:
		var rect: Rect2 = _rects[key]
		if rect.has_point(pos):
			var parts: PackedStringArray = key.split(":")
			var codes := {"take": RestaurantSim.TAKE, "grill": RestaurantSim.GRILL, "serve": RestaurantSim.SERVE,
				"trash": RestaurantSim.TRASH}
			if codes.has(parts[0]):
				do_action(codes[parts[0]], int(parts[1]), t)
				return


## Hace una acción a la hora `t` (y la anota). Los toques más rápidos de lo
## que puede una persona (min_gap_ms) se ignoran: el servidor los rechazaría.
func do_action(code: int, arg: int, t: int) -> void:
	if t < _last_action_t + int(_service["min_gap_ms"]) or actions.size() >= int(_service["max_actions"]):
		return
	var before_plate := sim.plate.size()
	sim.act(t, code, arg)
	_last_action_t = t
	var action := [t, code, arg]
	actions.append(action)
	if not practice:
		Restaurant.record_action(action)
	if code == RestaurantSim.TAKE and sim.plate.size() == before_plate and not _service["ingredients"][arg]["hot"]:
		_shake["plate"] = Time.get_ticks_msec()
	_take_events(t)


func _take_events(_t: int) -> void:
	for e in sim.events:
		match e["type"]:
			"served":
				_float_text("+$%d" % int(e["coins"]), _seat_center(int(e["seat"])), COLOR_GOOD)
			"wrong":
				_float_text("¡Eso no pedí!", _seat_center(int(e["seat"])), COLOR_BAD)
				_shake["seat:%d" % int(e["seat"])] = Time.get_ticks_msec()
			"leave":
				_float_text("Se fue…", _seat_center(int(e["seat"])), Color("9a8070"))
			"burned":
				_float_text("¡Se quemó!", _rects.get("grill:0", Rect2()).get_center(), COLOR_BAD)
	sim.events.clear()


func _float_text(text: String, at: Vector2, color: Color) -> void:
	_floats.append({"text": text, "pos": at, "color": color, "born": Time.get_ticks_msec()})


func _seat_center(seat: int) -> Vector2:
	return _rects.get("serve:%d" % seat, Rect2()).get_center()


# --- Fin del servicio ---

func _finish() -> void:
	_running = false
	_done = true
	sim.finish()
	var local := sim.result()
	_result_label.text = _result_text(local, {})
	_result_panel.visible = true
	_done_button.disabled = not practice
	_done_button.text = "Listo" if practice else "Contando…"
	if practice:
		EventBus.restaurant_service_finished.emit(local.merged({"practice": true}))
		return
	var answer: Dictionary = await Restaurant.finish_service(actions)
	_result_label.text = _result_text(local, answer)
	_done_button.disabled = false
	_done_button.text = "Listo"
	EventBus.restaurant_service_finished.emit(answer)


func _result_text(local: Dictionary, answer: Dictionary) -> String:
	var lines: PackedStringArray = ["¡Fin del servicio!", ""]
	lines.append("Atendiste a %d de %d clientes" % [int(local["served"]), int(local["customers"])])
	if int(local["lost"]) + int(local["skipped"]) > 0:
		lines.append("Se fueron sin comer: %d" % (int(local["lost"]) + int(local["skipped"])))
	lines.append("Mejor racha: %d · Propinas: $%d" % [int(local["best_streak"]), int(local["tips"])])
	lines.append("")
	if practice:
		lines.append("Práctica: habrías ganado $%d (no se cobra)." % int(local["coins"]))
	elif answer.is_empty():
		lines.append("Ganaste $%d. El servidor lo está contando…" % int(local["coins"]))
	elif answer.get("pending", false):
		lines.append("Sin conexión: se cobra solo cuando vuelvas a conectarte.")
	elif not answer.get("valid", false):
		lines.append(str(answer.get("error_text", "No se cobró.")))
	else:
		var where := " a la caja de la casa" if answer.get("to_fund", false) else ""
		lines.append("Cobraste $%d%s." % [int(answer.get("pay", 0)), where])
		if answer.get("capped", false):
			lines.append("(Llegaste al tope de hoy: $%d.)" % int(answer.get("daily_cap", 0)))
	return "\n".join(lines)


func _build_result_panel() -> void:
	_result_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.17, 0.25, 0.96)
	style.set_corner_radius_all(20)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	_result_panel.add_theme_stylebox_override("panel", style)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 14)
	_result_panel.add_child(rows)
	_result_label = Label.new()
	_result_label.add_theme_font_size_override("font_size", 22)
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(_result_label)
	_done_button = Button.new()
	_done_button.custom_minimum_size = Vector2(220, 60)
	_done_button.add_theme_font_size_override("font_size", 22)
	_done_button.text = "Listo"
	_done_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_done_button.pressed.connect(_close)
	rows.add_child(_done_button)
	_result_panel.visible = false
	add_child(_result_panel)


func _close() -> void:
	hide()
	sim = null
	closed.emit()
	EventBus.restaurant_panel_requested.emit()


# --- Dónde va cada cosa (para dibujar y para los toques) ---

func _layout() -> void:
	_rects.clear()
	var w := size.x
	var h := size.y
	if w <= 0 or sim == null:
		return
	# Mesas arriba.
	var card := Vector2(minf(280.0, w / 3.4), h * 0.40)
	var gap := 26.0
	var total := card.x * sim.seats.size() + gap * (sim.seats.size() - 1)
	for s in sim.seats.size():
		_rects["serve:%d" % s] = Rect2(Vector2((w - total) / 2 + s * (card.x + gap), h * 0.10), card)
	# Plancha (izquierda), plato (centro) y basura (derecha).
	var mid_y := h * 0.535
	var slot := Vector2(130, h * 0.17)
	for g in sim.grill.size():
		_rects["grill:%d" % g] = Rect2(Vector2(w * 0.06 + g * (slot.x + 14), mid_y), slot)
	_rects["plate"] = Rect2(Vector2(w * 0.5 - 95, mid_y - 6), Vector2(190, slot.y + 12))
	_rects["trash:0"] = Rect2(Vector2(w * 0.5 + 130, mid_y + 10), Vector2(96, slot.y - 20))
	# Ingredientes abajo.
	var count: int = _service["ingredients"].size()
	var bw := minf(170.0, (w - 40) / count - 12)
	var row := bw * count + 12 * (count - 1)
	for i in count:
		_rects["take:%d" % i] = Rect2(Vector2((w - row) / 2 + i * (bw + 12), h * 0.77), Vector2(bw, h * 0.2))
	var panel_size := Vector2(560, 0)
	_result_panel.custom_minimum_size = panel_size
	_result_panel.position = Vector2((w - panel_size.x) / 2, h * 0.16)


# --- Dibujo ---

func _draw() -> void:
	if sim == null:
		return
	if _rects.is_empty():
		_layout()
	var w := size.x
	var h := size.y
	var t := service_time()
	var now := Time.get_ticks_msec()
	# Salón: pared con rayas y mostrador de madera.
	draw_rect(Rect2(0, 0, w, h), COLOR_WALL)
	for x in range(0, int(w), 80):
		draw_rect(Rect2(x, 0, 40, h * 0.5), COLOR_STRIPE)
	draw_rect(Rect2(0, h * 0.5, w, h * 0.5), COLOR_COUNTER)
	draw_rect(Rect2(0, h * 0.5, w, 16), COLOR_COUNTER_TOP)
	_draw_header(t)
	for s in sim.seats.size():
		_draw_seat(s, t, now)
	for g in sim.grill.size():
		_draw_grill(g, t, now)
	_draw_plate(now)
	_draw_trash()
	for i in _service["ingredients"].size():
		_draw_ingredient_button(i)
	_draw_floats(now)
	if t < 0 and _running:
		var n := ceili(-t / 800.0)
		_draw_center_text("¡Abrimos!" if n <= 0 else str(n), Vector2(w / 2, h * 0.45), 96, COLOR_INK)


func _text(text: String, pos: Vector2, font_size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT,
		width := -1.0) -> void:
	draw_string(_font, pos, text, align, width, font_size, color)


func _draw_center_text(text: String, center: Vector2, font_size: int, color: Color) -> void:
	var text_size := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string_outline(_font, center - Vector2(text_size.x / 2, -font_size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT,
		-1, font_size, 8, Color.WHITE)
	draw_string(_font, center - Vector2(text_size.x / 2, -font_size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT,
		-1, font_size, color)


func _draw_header(t: int) -> void:
	var w := size.x
	var left := maxi(0, int(_service["duration_ms"]) - maxi(t, 0)) / 1000
	draw_rect(Rect2(0, 0, w, 54), Color(0.13, 0.17, 0.25, 0.9))
	_text("%d:%02d" % [left / 60, left % 60], Vector2(24, 40), 34, Color("ffe08a") if left > 10 else COLOR_BAD)
	_text("$ %d" % sim.coins, Vector2(w / 2 - 60, 40), 32, Color.WHITE)
	if sim.streak >= 2:
		_text("Racha x%d" % sim.streak, Vector2(w / 2 + 70, 38), 24, Color("ffb86b"))
	if practice:
		_text("PRÁCTICA", Vector2(w - 170, 38), 24, Color("9fd3ff"))


func _draw_seat(s: int, t: int, now: int) -> void:
	var rect: Rect2 = _rects["serve:%d" % s]
	var shake_at: int = _shake.get("seat:%d" % s, -10000)
	if now - shake_at < 300:
		rect.position.x += sin(now * 0.09) * 8
	draw_rect(rect, COLOR_CARD)
	var seat: Variant = sim.seats[s]
	var c: Dictionary = sim.customers[seat["c"]] if seat != null else {}
	var left := float(int(seat["deadline"]) - maxi(t, 0)) / float(c["patience"]) if seat != null else 1.0
	if seat != null:
		_draw_customer(int(seat["c"]), Vector2(rect.get_center().x, rect.position.y + rect.size.y * 0.6),
			rect.size.y * 0.17, clampf(left, 0.0, 1.0))
	# Mesa redonda (vista de costado) delante del cliente.
	var table_c := Vector2(rect.get_center().x, rect.end.y - 34)
	_draw_ellipse(table_c + Vector2(0, 8), Vector2(rect.size.x * 0.38, 22), Color("c98b5a"))
	_draw_ellipse(table_c, Vector2(rect.size.x * 0.38, 22), Color("f2c48d"))
	if seat == null:
		_text("Mesa libre", Vector2(rect.position.x, rect.get_center().y), 20, Color("9a8070"), HORIZONTAL_ALIGNMENT_CENTER,
			rect.size.x)
		return
	# Globo con el pedido.
	var order: Array = c["order"]
	var icon := 30.0
	var bubble := Rect2(Vector2(rect.get_center().x - (order.size() * icon * 1.1 + 18) / 2, rect.position.y + 6),
		Vector2(order.size() * icon * 1.1 + 18, icon * 2 + 10))
	draw_rect(bubble, Color.WHITE)
	draw_rect(bubble, COLOR_INK, false, 2.0)
	for k in order.size():
		var ing: Dictionary = _service["ingredients"][order[k]]
		draw_ingredient(self, ing, Vector2(bubble.position.x + 9 + icon * 0.55 + k * icon * 1.1, bubble.get_center().y),
			icon * 0.48, "fresh")
	# Paciencia: barra que se vacía (de verde a rojo).
	var bar := Rect2(Vector2(rect.position.x + 16, rect.end.y - 10), Vector2(rect.size.x - 32, 8))
	draw_rect(bar, Color(0, 0, 0, 0.2))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(left, 0, 1), bar.size.y)),
		COLOR_GOOD.lerp(COLOR_BAD, 1.0 - clampf(left, 0, 1)))


func _draw_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for k in 24:
		var a := TAU * k / 24.0
		pts.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	draw_colored_polygon(pts, color)


## Un cliente chibi: cuerpo chico, cabeza grande, cara según la paciencia.
func _draw_customer(index: int, center: Vector2, head: float, patience: float) -> void:
	var skin: Color = SKINS[(index * 3 + seed_value) % SKINS.size()]
	var hair: Color = HAIRS[(index * 5 + seed_value) % HAIRS.size()]
	var shirt: Color = SHIRTS[(index * 7 + seed_value) % SHIRTS.size()]
	draw_rect(Rect2(center + Vector2(-head * 0.75, head * 0.7), Vector2(head * 1.5, head * 1.1)), shirt)
	draw_circle(center, head, skin)
	draw_circle(center + Vector2(0, -head * 0.35), head * 0.85, hair)
	draw_circle(center + Vector2(0, head * 0.1), head * 0.82, skin)
	var eye_y := center.y + head * 0.05
	draw_circle(Vector2(center.x - head * 0.35, eye_y), head * 0.11, COLOR_INK)
	draw_circle(Vector2(center.x + head * 0.35, eye_y), head * 0.11, COLOR_INK)
	var mouth := center + Vector2(0, head * 0.45)
	if patience > 0.5:
		draw_arc(mouth, head * 0.25, 0.2, PI - 0.2, 10, COLOR_INK, 3.0)
	elif patience > 0.25:
		draw_line(mouth + Vector2(-head * 0.2, 0), mouth + Vector2(head * 0.2, 0), COLOR_INK, 3.0)
	else:
		draw_arc(mouth + Vector2(0, head * 0.2), head * 0.22, PI + 0.3, TAU - 0.3, 10, COLOR_INK, 3.0)
		draw_line(center + Vector2(-head * 0.5, -head * 0.2), center + Vector2(-head * 0.2, -head * 0.1), COLOR_INK, 3.0)
		draw_line(center + Vector2(head * 0.5, -head * 0.2), center + Vector2(head * 0.2, -head * 0.1), COLOR_INK, 3.0)


func _draw_grill(g: int, t: int, now: int) -> void:
	var rect: Rect2 = _rects["grill:%d" % g]
	draw_rect(rect, Color("4a4f57"))
	draw_rect(rect.grow(-8), Color("6b7280"))
	for k in 4:
		var y := rect.position.y + 16 + k * (rect.size.y - 32) / 3.0
		draw_line(Vector2(rect.position.x + 12, y), Vector2(rect.end.x - 12, y), Color("3a3f47"), 2.0)
	var slot: Variant = sim.grill[g]
	if slot == null:
		_text("Plancha", Vector2(rect.position.x, rect.end.y + 22), 16, COLOR_INK, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
		return
	var state := sim.grill_state(g, maxi(t, 0))
	var ing: Dictionary = _service["ingredients"][slot["item"]]
	var center := rect.get_center()
	if state == "ready":
		draw_circle(center, rect.size.x * 0.42 + sin(now * 0.012) * 4, Color(1, 0.85, 0.3, 0.55))
	draw_ingredient(self, ing, center, rect.size.y * 0.3, {"cooking": "raw", "ready": "fresh", "burned": "burned"}[state])
	var elapsed: int = maxi(t, 0) - int(slot["placed"])
	var label := "¡Listo!"
	var color := COLOR_GOOD
	if state == "cooking":
		label = "Cocinando…"
		color = Color("ff9f43")
		var part := clampf(float(elapsed) / float(_service["cook_ms"]), 0, 1)
		draw_arc(center, rect.size.y * 0.42, -PI / 2, -PI / 2 + TAU * part, 24, color, 5.0)
	elif state == "burned":
		label = "Quemado: tocá para tirar"
		color = COLOR_BAD
		for k in 3:
			draw_circle(center + Vector2(-14 + k * 14, -30 - fmod(now * 0.03 + k * 9, 24)), 9, Color(0.4, 0.4, 0.4, 0.5))
	_text(label, Vector2(rect.position.x - 20, rect.end.y + 22), 16, color, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x + 40)


func _draw_plate(now: int) -> void:
	var rect: Rect2 = _rects["plate"]
	var center := rect.get_center()
	var shake_at: int = _shake.get("plate", -10000)
	if now - shake_at < 250:
		center.x += sin(now * 0.1) * 6
	draw_circle(center + Vector2(0, 6), rect.size.y * 0.47, Color(0, 0, 0, 0.15))
	draw_circle(center, rect.size.y * 0.47, Color.WHITE)
	draw_circle(center, rect.size.y * 0.34, Color("eef2f5"))
	var n := sim.plate.size()
	for k in n:
		var angle := -PI / 2 + TAU * k / maxf(n, 1)
		var offset := Vector2(cos(angle), sin(angle)) * (rect.size.y * 0.18 if n > 1 else 0.0)
		draw_ingredient(self, _service["ingredients"][sim.plate[k]], center + offset, rect.size.y * 0.15, "fresh")
	_text("Plato (%d/%d)" % [n, int(_service["plate_max"])], Vector2(rect.position.x, rect.end.y + 16), 16, COLOR_INK,
		HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)


func _draw_trash() -> void:
	var rect: Rect2 = _rects["trash:0"]
	draw_rect(rect, Color("8a5a3b"))
	var c := rect.get_center()
	draw_rect(Rect2(c + Vector2(-22, -18), Vector2(44, 46)), Color("d8d2c4"))
	draw_rect(Rect2(c + Vector2(-28, -26), Vector2(56, 8)), Color("b9bec4"))
	_text("Tirar", Vector2(rect.position.x, rect.end.y + 18), 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)


func _draw_ingredient_button(i: int) -> void:
	var rect: Rect2 = _rects["take:%d" % i]
	var ing: Dictionary = _service["ingredients"][i]
	draw_rect(rect, Color("fff4dc"))
	draw_rect(rect, Color("8a5a3b"), false, 3.0)
	draw_ingredient(self, ing, rect.get_center() - Vector2(0, rect.size.y * 0.1), rect.size.y * 0.26, "fresh")
	_text(ing["name"], Vector2(rect.position.x, rect.end.y - 10), 18, COLOR_INK, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
	if ing["hot"]:
		# Llamita: va a la plancha.
		var f := rect.position + Vector2(rect.size.x - 22, 22)
		draw_colored_polygon(PackedVector2Array([f + Vector2(0, -14), f + Vector2(9, 6), f + Vector2(-9, 6)]), Color("ff7a3d"))
		draw_circle(f + Vector2(0, 4), 6, Color("ffd34d"))


func _draw_floats(now: int) -> void:
	var alive: Array = []
	for f in _floats:
		var age: int = now - int(f["born"])
		if age > FLOAT_MS:
			continue
		alive.append(f)
		var color: Color = f["color"]
		color.a = 1.0 - float(age) / FLOAT_MS
		_draw_center_text(f["text"], f["pos"] - Vector2(0, age * 0.06), 30, color)
	_floats = alive


## Dibuja un ingrediente con figuras simples. `look` = "fresh" (normal),
## "raw" (crudo, en la plancha) o "burned" (quemado).
static func draw_ingredient(canvas: CanvasItem, ing: Dictionary, center: Vector2, r: float, look: String) -> void:
	var color := Color(ing.get("color", "#ffffff"))
	if look == "raw":
		color = color.lerp(Color("f2a0a0"), 0.5)
	elif look == "burned":
		color = Color("3a2f2a")
	var ink := Color(0, 0, 0, 0.35)
	match ing.get("shape", "circle"):
		"square":
			canvas.draw_rect(Rect2(center - Vector2(r, r * 0.8), Vector2(r * 2, r * 1.6)), color)
			canvas.draw_rect(Rect2(center - Vector2(r, r * 0.8), Vector2(r * 2, r * 0.45)), color.lightened(0.25))
		"leaf":
			var pts := PackedVector2Array()
			for k in 16:
				var a := TAU * k / 16.0
				pts.append(center + Vector2(cos(a) * r, sin(a) * r * 0.6).rotated(-0.5))
			canvas.draw_colored_polygon(pts, color)
			canvas.draw_line(center + Vector2(-r * 0.8, 0).rotated(-0.5), center + Vector2(r * 0.8, 0).rotated(-0.5), ink, 2.0)
		"triangle":
			canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(-r, r * 0.7), center + Vector2(r, r * 0.7),
				center + Vector2(0, -r * 0.9)]), color)
			canvas.draw_circle(center + Vector2(-r * 0.2, r * 0.25), r * 0.14, color.darkened(0.2))
			canvas.draw_circle(center + Vector2(r * 0.3, r * 0.4), r * 0.1, color.darkened(0.2))
		"disc":
			var pts := PackedVector2Array()
			for k in 20:
				var a := TAU * k / 20.0
				pts.append(center + Vector2(cos(a) * r, sin(a) * r * 0.62))
			canvas.draw_colored_polygon(pts, color.darkened(0.25))
			for k in 20:
				pts[k] = pts[k] - Vector2(0, r * 0.12)
			canvas.draw_colored_polygon(pts, color)
		"egg":
			var pts := PackedVector2Array()
			for k in 20:
				var a := TAU * k / 20.0
				pts.append(center + Vector2(cos(a) * r * (1.0 + 0.12 * sin(a * 3)), sin(a) * r * 0.8))
			canvas.draw_colored_polygon(pts, color if look != "fresh" else Color("fffaf0"))
			canvas.draw_circle(center, r * 0.38, Color("ffc23d") if look != "burned" else Color("2a221f"))
		_:
			canvas.draw_circle(center, r, color)
			canvas.draw_circle(center + Vector2(-r * 0.35, -r * 0.35), r * 0.25, color.lightened(0.35))
			canvas.draw_line(center + Vector2(0, -r), center + Vector2(r * 0.3, -r * 1.3), Color("4caf6a"), 3.0)
