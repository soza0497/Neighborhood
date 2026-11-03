class_name HouseBuilder
extends Node3D
## Modo construir: herramientas, gestos y vista previa ("fantasma").
##
## Va como hijo de la HouseView, así usa las mismas coordenadas que la casa.
##
## Cómo funciona un gesto:
##   1. Apretar (dedo o clic izquierdo): empieza.
##   2. Arrastrar: se calcula qué se haría y se muestra en verde (se puede)
##      o rojo (no se puede).
##   3. Soltar: lo verde se aplica como UN paso de deshacer.
##   Si aparece un segundo dedo, el gesto se cancela (es para la cámara).

enum Tool { NONE, FOUNDATION, FLOOR, WALL, ROOM, ROOF, OPENING, OBJECT, PAINT, MOVE, WINDOW_JOIN }

## Qué herramienta usa cada tipo ("kind") de objeto del catálogo.
const KIND_TO_TOOL := {
	"foundation": Tool.FOUNDATION,
	"floor": Tool.FLOOR,
	"wall": Tool.WALL,
	"room": Tool.ROOM,
	"roof": Tool.ROOF,
	"door": Tool.OPENING,
	"window": Tool.OPENING,
	"stairs": Tool.OBJECT,
	"furniture": Tool.OBJECT,
	"paint": Tool.PAINT,
}

## Herramienta "mano" (mover muebles): no está en el catálogo.
const MOVE_TOOL_ID := "move"
## Herramienta para unir o separar ventanas vecinas: tampoco está en el catálogo.
const WINDOW_JOIN_TOOL_ID := "window_join"

## Clave provisional para algo nuevo; al soltar se cambia por un id real.
const NEW_KEY := "__new__"

const HINTS := {
	Tool.NONE: "Elegí una pieza en la barra de abajo.",
	Tool.FOUNDATION: "Arrastrá para marcar el terreno de la casa (cimientos).",
	Tool.FLOOR: "Arrastrá sobre los cimientos para poner piso.",
	Tool.WALL: "Arrastrá de esquina a esquina para levantar una pared.",
	Tool.ROOM: "Arrastrá un rectángulo: pone piso y paredes de una vez.",
	Tool.ROOF: "Arrastrá un rectángulo sobre la casa para techarla.",
	Tool.OPENING: "Tocá una pared para ponerla.",
	Tool.OBJECT: "Arrastrá hasta su lugar y soltá. «Girar» lo rota.",
	Tool.PAINT: "Tocá o arrastrá sobre paredes y pisos para pintarlos.",
	Tool.MOVE: "Tocá un mueble para elegirlo; arrastralo para moverlo.",
	Tool.WINDOW_JOIN: "Tocá una ventana para unirla o separarla de sus vecinas iguales.",
}

## Herramientas de arrastre (rectángulo o línea). Al soltar NO se aplican:
## queda una selección con dos manijas (círculos) que se pueden mover, y se
## aplica con el botón Confirmar. Así el dedo no tapa lo que se construye.
const HANDLE_TOOLS := [Tool.FOUNDATION, Tool.FLOOR, Tool.WALL, Tool.ROOM, Tool.ROOF]
## A cuántos píxeles de una manija cuenta como tocarla.
const HANDLE_PICK_DISTANCE := 70.0

## Herramientas donde todo el gesto se aplica entero o nada.
const ALL_OR_NOTHING := [Tool.ROOF, Tool.OPENING, Tool.OBJECT, Tool.MOVE, Tool.WINDOW_JOIN]

var house: HouseData
var history: UndoHistory
var view: HouseView
var camera: CameraRig

## true en modo construir.
var active := false
## Nivel (piso) donde se construye. 0 = planta baja.
var level := 0
var tool := Tool.NONE
## Objeto del catálogo elegido (vacío si la herramienta es NONE o MOVE).
var item: Dictionary = {}
## Modo borrar: las herramientas quitan en vez de poner.
var erase_mode := false
## Giro (0..3) para el próximo mueble que se coloque.
var place_rotation := 0
## Mueble elegido con la mano ("" = ninguno).
var selected_key := ""

# --- Estado del gesto ---
var _pressing := false
## Dedos apoyados ahora (número de dedo → true), y el que empezó el gesto.
var _touches: Dictionary = {}
var _stroke_index := -1
## Esquinas del rectángulo (celdas) o puntas de la línea (vértices).
var _start_cell := Vector2i.ZERO
var _start_vertex := Vector2i.ZERO
var _end_cell := Vector2i.ZERO
var _end_vertex := Vector2i.ZERO
## Hay una selección esperando Confirmar.
var _awaiting_confirm := false
## Manija que se está arrastrando: 0 = inicio, 1 = fin, -1 = ninguna.
var _drag_handle := -1
## El dedo empezó fuera del lote: ese dedo mueve la cámara.
var _camera_takeover := false
var _last_screen_pos := Vector2.ZERO
## Mueble que se está arrastrando con la mano, y dónde se agarró.
var _moving_key := ""
var _grab_offset := Vector2i.ZERO
## Lo que se va pintando en un mismo gesto: "capa|clave" → true.
var _paint_targets: Dictionary = {}
## Escrituras que se aplicarían al soltar, y las que no se pueden.
var _pending_ok: Array = []
var _pending_blocked: Array = []

# --- Nodos 3D de ayuda ---
var _grid: MeshInstance3D
var _cursor: MeshInstance3D
var _ghost: Node3D
var _selection_marker: MeshInstance3D
var _handles: Array[MeshInstance3D] = []
## Piezas reales escondidas mientras se ve el fantasma que las reemplaza.
var _hidden_nodes: Array[Node3D] = []


func _ready() -> void:
	_create_helpers()
	set_active(false)


## Conecta el constructor con la casa, su historial, su vista y la cámara.
func setup(new_house: HouseData, new_history: UndoHistory, new_view: HouseView, new_camera: CameraRig) -> void:
	house = new_house
	history = new_history
	view = new_view
	camera = new_camera
	house.piece_changed.connect(_on_piece_changed)
	house.reloaded.connect(func(): select_object(""))


# --- Lo que pide la interfaz ---

## Entra o sale del modo construir.
func set_active(value: bool) -> void:
	active = value
	_touches.clear()
	_cancel_gesture()
	_grid.visible = active
	_cursor.visible = false
	if not active:
		select_item("")
	_update_camera_pan()


## Elige una pieza del catálogo por id ("" = ninguna, "move" = la mano).
func select_item(item_id: String) -> void:
	_cancel_gesture()
	select_object("")
	if item_id == MOVE_TOOL_ID:
		item = {}
		tool = Tool.MOVE
	elif item_id == WINDOW_JOIN_TOOL_ID:
		item = {}
		tool = Tool.WINDOW_JOIN
	else:
		item = Catalog.get_item(item_id)
		tool = KIND_TO_TOOL.get(item.get("kind", ""), Tool.NONE)
		# Una pieza bloqueada por nivel no se puede elegir.
		if not item.is_empty() and not Economy.is_unlocked(item_id):
			EventBus.build_hint.emit("%s se desbloquea en el nivel %d." % [item["name"], Catalog.unlock_level(item_id)])
			item = {}
			tool = Tool.NONE
			_update_camera_pan()
			return
	place_rotation = 0
	_cursor.visible = false
	_update_camera_pan()
	_show_tool_hint()


func set_erase_mode(value: bool) -> void:
	erase_mode = value
	_cancel_gesture()
	_show_tool_hint()


## Cambia de nivel (piso). Devuelve el nivel que quedó.
func set_level(new_level: int) -> int:
	level = clampi(new_level, 0, HouseGrid.MAX_LEVELS - 1)
	_cancel_gesture()
	select_object("")
	_grid.position.y = HouseGrid.level_y(level) + 0.03
	return level


## Botón "Girar": gira el mueble elegido, o el que se va a colocar.
func rotate_object() -> void:
	if selected_key != "":
		var value: Dictionary = house.get_piece(level, "objects", selected_key).duplicate(true)
		value["rot"] = (int(value.get("rot", 0)) + 1) % 4
		var check := _check(_object_writes(selected_key, value))
		if check["blocked"].is_empty():
			_apply(check["ok"])
		else:
			EventBus.build_hint.emit("No hay lugar para girarlo aquí.")
	elif tool == Tool.OBJECT:
		place_rotation = (place_rotation + 1) % 4
		EventBus.build_hint.emit("Girado. Arrastrá para colocarlo.")


## Botón "Quitar": borra el mueble elegido.
func delete_selected() -> void:
	if selected_key == "":
		return
	if _apply([HouseData.write(level, "objects", selected_key, null)]):
		EventBus.build_hint.emit("Quitaste el mueble.")
	select_object("")


## Botón "Confirmar": aplica la selección que estaba esperando.
func confirm_pending() -> void:
	if not _awaiting_confirm:
		return
	var ok := _pending_ok
	var blocked := _pending_blocked
	# Si no alcanza el dinero, la selección se conserva para ajustarla.
	var money_change: int = Economy.quote(house, ok)["money"]
	if not Economy.can_change(money_change):
		EventBus.build_hint.emit("Te faltan $%d. Achicá la selección o cancelá." % (-money_change - Economy.money))
		return
	_cancel_gesture()
	_commit(ok, blocked)


## Botón "Cancelar": descarta la selección que estaba esperando.
func cancel_pending() -> void:
	if _awaiting_confirm:
		_cancel_gesture()
		_show_tool_hint()


## Marca un mueble como elegido ("" = ninguno).
func select_object(key: String) -> void:
	selected_key = key
	_update_selection_marker()
	EventBus.build_selection_changed.emit(selected_key != "")


# --- Entrada (toques y mouse) ---

func _unhandled_input(event: InputEvent) -> void:
	if not active or tool == Tool.NONE:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = true
			if _touches.size() == 1:
				_stroke_index = event.index
				_begin(event.position)
			else:
				_on_second_finger()  # Es un gesto de cámara.
		else:
			_touches.erase(event.index)
			if event.index == _stroke_index:
				_release()
	elif event is InputEventScreenDrag:
		# Solo cuenta el dedo que empezó el gesto.
		if _pressing and event.index == _stroke_index:
			_update(event.position)
	elif event is InputEventMouseButton or event is InputEventMouseMotion:
		# Los "clics" que Godot fabrica a partir de toques ya se manejaron arriba.
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_begin(event.position)
			else:
				_release()
		elif event is InputEventMouseMotion:
			if _pressing:
				_update(event.position)
			else:
				_hover(event.position)


func _unhandled_key_input(event: InputEvent) -> void:
	# En la PC: Enter confirma la selección y Escape la cancela.
	if not active or not _awaiting_confirm:
		return
	if event.is_action_pressed("ui_accept"):
		confirm_pending()
	elif event.is_action_pressed("ui_cancel"):
		cancel_pending()


## Empieza un gesto.
func _begin(screen_pos: Vector2) -> void:
	_cursor.visible = false
	_paint_targets.clear()

	# ¿Agarró una manija de la selección que espera confirmación?
	if _awaiting_confirm:
		var handle := _handle_at(screen_pos)
		if handle >= 0:
			_drag_handle = handle
			_pressing = true
			return

	if tool != Tool.MOVE and not _is_on_lot(screen_pos):
		# Fuera del lote, el dedo mueve la cámara (la selección se conserva).
		_camera_takeover = true
		_update_camera_pan()
		return

	if _awaiting_confirm:
		_cancel_gesture()  # Tocó otra parte del lote: selección nueva.

	if tool == Tool.MOVE:
		var key := _pick_object(screen_pos)
		select_object(key)
		if key == "" or erase_mode:
			if key != "" and erase_mode:
				delete_selected()
			return  # Tocó en el vacío: la cámara se mueve como siempre.
		_moving_key = key
		var anchor := HouseData.object_anchor(house.get_piece(level, "objects", key))
		_grab_offset = _cell_at(screen_pos, false) - anchor
		_update_camera_pan()

	_pressing = true
	_start_cell = _cell_at(screen_pos, true)
	_start_vertex = _vertex_at(screen_pos)
	_end_cell = _start_cell
	_end_vertex = _start_vertex
	_drag_handle = 1
	_update(screen_pos)


## El dedo o el mouse se movió durante el gesto.
func _update(screen_pos: Vector2) -> void:
	_last_screen_pos = screen_pos
	if tool in HANDLE_TOOLS and _pressing:
		if _drag_handle == 0:
			_start_cell = _cell_at(screen_pos, true)
			_start_vertex = _vertex_at(screen_pos)
		else:
			_end_cell = _cell_at(screen_pos, true)
			_end_vertex = _vertex_at(screen_pos)
		_update_handles()
	var writes := _erase_writes(screen_pos) if erase_mode and tool != Tool.WINDOW_JOIN else _place_writes(screen_pos)
	var check := _check(writes)
	_pending_ok = check["ok"]
	_pending_blocked = check["blocked"]
	if tool in HANDLE_TOOLS and _pressing:
		EventBus.build_cost_changed.emit(-Economy.quote(house, _pending_ok)["money"])
	_show_preview()


## Se levantó el dedo (o el botón del mouse).
func _release() -> void:
	if _camera_takeover:
		_camera_takeover = false
		_update_camera_pan()
	if _pressing:
		_finish()


## Termina el gesto: aplica lo que se podía, o deja la selección esperando.
func _finish() -> void:
	if tool in HANDLE_TOOLS:
		_pressing = false
		_drag_handle = -1
		if not _awaiting_confirm:
			_awaiting_confirm = true
			EventBus.build_pending_changed.emit(true)
		_update_handles()
		if _pending_blocked.is_empty():
			EventBus.build_hint.emit("Mové los círculos para ajustar y tocá «Confirmar».")
		else:
			EventBus.build_hint.emit(_blocked_hint() + " Lo rojo no se va a poner.")
		return

	var ok := _pending_ok
	var blocked := _pending_blocked
	_cancel_gesture()
	_commit(ok, blocked)


## Un segundo dedo: deja de construir (la cámara toma el gesto), pero una
## selección que espera Confirmar se conserva.
func _on_second_finger() -> void:
	if _awaiting_confirm:
		_pressing = false
		_drag_handle = -1
	else:
		_cancel_gesture()


## Aplica las escrituras como un paso de deshacer y avisa qué pasó.
func _commit(ok: Array, blocked: Array) -> void:
	var applied := _apply(ok)
	if not applied:
		return  # _apply ya explicó por qué (no alcanza el dinero).
	if not blocked.is_empty():
		EventBus.build_hint.emit(_blocked_hint())
	elif not ok.is_empty():
		_show_tool_hint()


## Cobra (o devuelve) el dinero, aplica las escrituras como UN paso de
## deshacer y anota lo construido. Devuelve false si no alcanza el dinero.
func _apply(writes: Array) -> bool:
	if writes.is_empty():
		return true
	# Lo nuevo recibe su id definitivo ahora.
	for w in writes:
		if w["key"] == NEW_KEY:
			w["key"] = house.new_id()
	var quote := Economy.quote(house, writes)
	var money_change: int = quote["money"]
	if not Economy.can_change(money_change):
		EventBus.build_hint.emit("Te faltan $%d para construir esto." % (-money_change - Economy.money))
		return false
	history.commit(quote["writes"], money_change)
	Economy.record_build(quote["writes"])
	if money_change < 0:
		EventBus.build_hint.emit("Pagaste $%d." % -money_change)
	elif money_change > 0:
		EventBus.build_hint.emit("Te devolvieron $%d." % money_change)
	return true


## Mouse moviéndose sin apretar (solo en la PC): muestra dónde caería.
func _hover(screen_pos: Vector2) -> void:
	if _awaiting_confirm:
		return
	match tool:
		Tool.OBJECT, Tool.OPENING, Tool.WINDOW_JOIN:
			if not erase_mode or tool == Tool.WINDOW_JOIN:
				_update(screen_pos)
				return
		Tool.MOVE:
			return
	_clear_preview()
	var point: Variant = _point_on_level(screen_pos)
	if point == null:
		_cursor.visible = false
		return
	_cursor.visible = true
	if tool == Tool.WALL:
		var v := _vertex_at(screen_pos)
		_cursor.position = Vector3(v.x, HouseGrid.level_y(level) + 0.05, v.y)
		_cursor.scale = Vector3(0.3, 1, 0.3)
	else:
		var cell := _cell_at(screen_pos, false)
		_cursor.position = HouseGrid.cell_center(cell) + Vector3(0, HouseGrid.level_y(level) + 0.05, 0)
		_cursor.scale = Vector3.ONE


func _cancel_gesture() -> void:
	_pressing = false
	_drag_handle = -1
	if _awaiting_confirm:
		_awaiting_confirm = false
		EventBus.build_pending_changed.emit(false)
	_paint_targets.clear()
	_pending_ok = []
	_pending_blocked = []
	_moving_key = ""
	_clear_preview()
	_update_handles()
	_update_camera_pan()


# --- Qué hace cada herramienta ---

## Escrituras para PONER según la herramienta y dónde está el dedo.
func _place_writes(screen_pos: Vector2) -> Array:
	var writes: Array = []
	var cell := _end_cell
	match tool:
		Tool.FOUNDATION:
			for c in HouseGrid.cells_in_rect(_start_cell, cell):
				_add_if_new(writes, 0, "foundation", HouseGrid.cell_key(c), {"item": item["id"]})
		Tool.FLOOR:
			for c in HouseGrid.cells_in_rect(_start_cell, cell):
				_add_if_new(writes, level, "floors", HouseGrid.cell_key(c), {"item": item["id"]})
		Tool.WALL:
			for edge in HouseGrid.edges_in_line(_start_vertex, _end_vertex):
				_add_wall(writes, edge, item["id"])
		Tool.ROOM:
			# Primero el piso y después las paredes (las de arriba se apoyan en él).
			for c in HouseGrid.cells_in_rect(_start_cell, cell):
				_add_if_new(writes, level, "floors", HouseGrid.cell_key(c), {"item": item.get("floor_item", "")})
			for edge in HouseGrid.edges_around_rect(_start_cell, cell):
				_add_wall(writes, edge, item.get("wall_item", ""))
		Tool.ROOF:
			var lo := Vector2i(mini(_start_cell.x, cell.x), mini(_start_cell.y, cell.y))
			var hi := Vector2i(maxi(_start_cell.x, cell.x), maxi(_start_cell.y, cell.y))
			var size := hi - lo + Vector2i.ONE
			writes.append(HouseData.write(level, "roofs", NEW_KEY,
				{"item": item["id"], "rect": [lo.x, lo.y, size.x, size.y]}))
		Tool.OPENING:
			var edge := _pick_wall(screen_pos)
			if edge != "":
				var wall: Dictionary = house.get_piece(level, "walls", edge).duplicate(true)
				if wall.get("opening", "") != item["id"]:
					wall["opening"] = item["id"]
					writes.append(HouseData.write(level, "walls", edge, wall))
		Tool.OBJECT:
			var anchor := _centered_anchor(_cell_at(screen_pos, false), place_rotation)
			writes.append_array(_object_writes(NEW_KEY,
				{"item": item["id"], "cell": [anchor.x, anchor.y], "rot": place_rotation}))
		Tool.MOVE:
			if _moving_key != "":
				var value: Dictionary = house.get_piece(level, "objects", _moving_key).duplicate(true)
				var anchor := _cell_at(screen_pos, false) - _grab_offset
				if anchor != HouseData.object_anchor(value):
					value["cell"] = [anchor.x, anchor.y]
					writes.append_array(_object_writes(_moving_key, value))
		Tool.WINDOW_JOIN:
			# Marca la ventana como "separada" (o le quita la marca).
			var edge := _pick_wall(screen_pos)
			if edge != "":
				var wall: Dictionary = house.get_piece(level, "walls", edge).duplicate(true)
				if Catalog.get_item(wall.get("opening", "")).get("kind", "") == "window":
					if wall.get("separate", false):
						wall.erase("separate")
					else:
						wall["separate"] = true
					writes.append(HouseData.write(level, "walls", edge, wall))
		Tool.PAINT:
			_collect_paint_target(screen_pos)
			for target in _paint_targets:
				var parts: PackedStringArray = target.split("|")
				var value: Dictionary = house.get_piece(level, parts[0], parts[1]).duplicate(true)
				value["color"] = item["color"]
				writes.append(HouseData.write(level, parts[0], parts[1], value))
	return writes


## Escrituras para QUITAR según la herramienta y dónde está el dedo.
func _erase_writes(screen_pos: Vector2) -> Array:
	var writes: Array = []
	var cell := _end_cell
	match tool:
		Tool.FOUNDATION:
			for c in HouseGrid.cells_in_rect(_start_cell, cell):
				_add_removal(writes, 0, "foundation", HouseGrid.cell_key(c))
		Tool.FLOOR:
			for c in HouseGrid.cells_in_rect(_start_cell, cell):
				_add_removal(writes, level, "floors", HouseGrid.cell_key(c))
		Tool.WALL:
			for edge in HouseGrid.edges_in_line(_start_vertex, _end_vertex):
				_add_removal(writes, level, "walls", edge)
		Tool.ROOM:
			for edge in HouseGrid.edges_around_rect(_start_cell, cell):
				_add_removal(writes, level, "walls", edge)
			for c in HouseGrid.cells_in_rect(_start_cell, cell):
				_add_removal(writes, level, "floors", HouseGrid.cell_key(c))
		Tool.ROOF:
			var area := Rect2i(_start_cell, Vector2i.ONE).merge(Rect2i(cell, Vector2i.ONE))
			for key in house.get_layer(level, "roofs"):
				if HouseData.roof_rect(house.get_piece(level, "roofs", key)).intersects(area):
					writes.append(HouseData.write(level, "roofs", key, null))
		Tool.OPENING:
			var edge := _pick_wall(screen_pos)
			if edge != "":
				var wall: Dictionary = house.get_piece(level, "walls", edge).duplicate(true)
				if wall.has("opening"):
					wall.erase("opening")
					writes.append(HouseData.write(level, "walls", edge, wall))
		Tool.OBJECT:
			var key := _pick_object(screen_pos)
			if key != "":
				writes.append(HouseData.write(level, "objects", key, null))
		Tool.PAINT:
			# Borrar pintura = volver al color original de la pieza.
			_collect_paint_target(screen_pos)
			for target in _paint_targets:
				var parts: PackedStringArray = target.split("|")
				var value: Dictionary = house.get_piece(level, parts[0], parts[1]).duplicate(true)
				if value.has("color"):
					value.erase("color")
					writes.append(HouseData.write(level, parts[0], parts[1], value))
	return writes


## Pone una pieza solo si no está ya igual (no repite trabajo).
func _add_if_new(writes: Array, lvl: int, layer: String, key: String, value: Dictionary) -> void:
	var current: Variant = house.get_piece(lvl, layer, key)
	if current == null or current["item"] != value["item"]:
		writes.append(HouseData.write(lvl, layer, key, value))


## Pone una pared. Si ya había otra de distinto tipo, conserva su puerta o ventana.
func _add_wall(writes: Array, edge: String, wall_item: String) -> void:
	var current: Variant = house.get_piece(level, "walls", edge)
	if current != null and current["item"] == wall_item:
		return
	var value := {"item": wall_item}
	if current != null and current.has("opening"):
		value["opening"] = current["opening"]
	writes.append(HouseData.write(level, "walls", edge, value))


func _add_removal(writes: Array, lvl: int, layer: String, key: String) -> void:
	if house.has_piece(lvl, layer, key):
		writes.append(HouseData.write(lvl, layer, key, null))


## Escrituras para poner o mover un objeto. Una escalera además abre el
## hueco en el piso de arriba (quita esas baldosas).
func _object_writes(key: String, value: Dictionary) -> Array:
	var writes: Array = [HouseData.write(level, "objects", key, value)]
	var object_item := Catalog.get_item(value["item"])
	if object_item.get("kind", "") == "stairs":
		var cells := HouseGrid.object_cells(HouseData.item_footprint(object_item),
			HouseData.object_anchor(value), int(value.get("rot", 0)))
		for c in cells:
			_add_removal(writes, level + 1, "floors", HouseGrid.cell_key(c))
	return writes


## Celda de anclaje para que el objeto quede centrado bajo el dedo.
func _centered_anchor(cell: Vector2i, rot: int) -> Vector2i:
	var size := HouseGrid.rotated_size(HouseData.item_footprint(item), rot)
	return cell - (size - Vector2i.ONE) / 2


## Agrega a la lista de pintura lo que está bajo el dedo (pared o piso).
func _collect_paint_target(screen_pos: Vector2) -> void:
	var edge := _pick_wall(screen_pos, false)
	if edge != "":
		_paint_targets["walls|" + edge] = true
		return
	var point: Variant = _point_on_level(screen_pos)
	if point != null:
		var key := HouseGrid.cell_key(Vector2i(floori(point.x), floori(point.z)))
		if house.has_piece(level, "floors", key):
			_paint_targets["floors|" + key] = true


## Revisa las reglas. Devuelve {"ok": [...], "blocked": [...]}.
func _check(writes: Array) -> Dictionary:
	var adds: Array = []
	var removals: Array = []
	for w in writes:
		if w["value"] == null:
			removals.append(w)
		else:
			adds.append(w)
	var removal_check := HouseRules.check_removal(house, removals)
	var place_check := HouseRules.check_placement(house, adds)
	var ok: Array = place_check["ok"] + removal_check["ok"]
	var blocked: Array = place_check["blocked"] + removal_check["blocked"]

	if tool in ALL_OR_NOTHING and not erase_mode and not blocked.is_empty():
		return {"ok": [], "blocked": writes}
	return {"ok": ok, "blocked": blocked}


# --- Vista previa ---

func _show_preview() -> void:
	_clear_preview()
	_ghost.position.y = HouseGrid.level_y(level)
	for w in _pending_ok:
		_add_ghost(w, true)
	for w in _pending_blocked:
		_add_ghost(w, false)


func _add_ghost(w: Dictionary, valid: bool) -> void:
	var lvl: int = w["level"]
	var existing: Variant = house.get_piece(lvl, w["layer"], w["key"])
	var value: Variant = w["value"]
	# Al quitar algo, se muestra en rojo lo que se va.
	var removing: bool = value == null
	if removing:
		value = existing
	if value == null:
		return

	var node := view.make_piece(lvl, w["layer"], w["key"], value, true)
	if node == null:
		return
	if tool != Tool.PAINT or not valid:
		HousePieces.make_ghost(node, valid and not removing)
	node.position.y += HouseGrid.level_y(lvl) - HouseGrid.level_y(level)
	_ghost.add_child(node)

	# Si la pieza real ya existe, se esconde para que el fantasma la reemplace.
	if existing != null:
		var real := view.get_piece_node(lvl, w["layer"], w["key"])
		if real != null and real.visible:
			real.visible = false
			_hidden_nodes.append(real)


func _clear_preview() -> void:
	for child in _ghost.get_children():
		child.queue_free()
	for node in _hidden_nodes:
		if is_instance_valid(node):
			node.visible = true
	_hidden_nodes.clear()


func _update_selection_marker() -> void:
	var value: Variant = null
	if selected_key != "" and house != null:
		value = house.get_piece(level, "objects", selected_key)
	_selection_marker.visible = value != null
	if value == null:
		return
	var object_item := Catalog.get_item(value["item"])
	var size := HouseGrid.rotated_size(HouseData.item_footprint(object_item), int(value.get("rot", 0)))
	var anchor := HouseData.object_anchor(value)
	_selection_marker.position = Vector3(anchor.x + size.x / 2.0, HouseGrid.level_y(level) + 0.06, anchor.y + size.y / 2.0)
	_selection_marker.scale = Vector3(size.x + 0.15, 1, size.y + 0.15)


func _on_piece_changed(changed_level: int, layer: String, key: String) -> void:
	# Si el mueble elegido se movió o desapareció (por ejemplo, al deshacer).
	if layer == "objects" and changed_level == level and key == selected_key:
		if house.has_piece(level, layer, key):
			_update_selection_marker()
		else:
			select_object("")


# --- Ayudantes: de la pantalla a la cuadrícula ---

## Rayo desde la cámara, en coordenadas de la casa: [origen, dirección].
func _ray(screen_pos: Vector2) -> Array:
	var cam := get_viewport().get_camera_3d()
	var origin := to_local(cam.project_ray_origin(screen_pos))
	var direction := global_transform.basis.inverse() * cam.project_ray_normal(screen_pos)
	return [origin, direction]


## Punto del piso del nivel actual bajo la pantalla (o null).
func _point_on_level(screen_pos: Vector2) -> Variant:
	var ray := _ray(screen_pos)
	return Plane(Vector3.UP, HouseGrid.level_y(level)).intersects_ray(ray[0], ray[1])


## Celda bajo la pantalla. `clamp_to_lot` la mantiene dentro del lote
## (útil al arrastrar rectángulos hasta el borde).
func _cell_at(screen_pos: Vector2, clamp_to_lot: bool) -> Vector2i:
	var point: Variant = _point_on_level(screen_pos)
	if point == null:
		return _start_cell
	var cell := Vector2i(floori(point.x), floori(point.z))
	if clamp_to_lot:
		cell = cell.clamp(Vector2i.ZERO, HouseGrid.LOT_SIZE - Vector2i.ONE)
	return cell


## ¿El punto de la pantalla cae sobre el lote (con medio metro de margen)?
func _is_on_lot(screen_pos: Vector2) -> bool:
	var point: Variant = _point_on_level(screen_pos)
	if point == null:
		return false
	return point.x > -0.5 and point.z > -0.5 \
		and point.x < HouseGrid.LOT_SIZE.x + 0.5 and point.z < HouseGrid.LOT_SIZE.y + 0.5


## Manija bajo la pantalla: 0 = inicio, 1 = fin, -1 = ninguna.
func _handle_at(screen_pos: Vector2) -> int:
	var cam := get_viewport().get_camera_3d()
	var best := -1
	var best_dist := HANDLE_PICK_DISTANCE
	for i in _handles.size():
		if not _handles[i].visible:
			continue
		var dist := cam.unproject_position(_handles[i].global_position).distance_to(screen_pos)
		if dist < best_dist:
			best_dist = dist
			best = i
	return best


## Pone las manijas en las esquinas (o puntas) de la selección.
func _update_handles() -> void:
	var shown := tool in HANDLE_TOOLS and (_pressing or _awaiting_confirm)
	var y := HouseGrid.level_y(level) + 0.12
	for i in _handles.size():
		_handles[i].visible = shown
		if not shown:
			continue
		if tool == Tool.WALL:
			var v := _start_vertex if i == 0 else _end_vertex
			_handles[i].position = Vector3(v.x, y, v.y)
		else:
			var c := _start_cell if i == 0 else _end_cell
			_handles[i].position = HouseGrid.cell_center(c) + Vector3(0, y, 0)


## Esquina de la cuadrícula más cercana a la pantalla.
func _vertex_at(screen_pos: Vector2) -> Vector2i:
	var point: Variant = _point_on_level(screen_pos)
	if point == null:
		return _start_vertex
	return Vector2i(roundi(point.x), roundi(point.z)).clamp(Vector2i.ZERO, HouseGrid.LOT_SIZE)


## Pared bajo la pantalla ("" si no hay). Primero prueba si el rayo choca con
## una pared; si no, busca la pared más cercana al punto del piso.
func _pick_wall(screen_pos: Vector2, use_nearby := true) -> String:
	var ray := _ray(screen_pos)
	var best_key := ""
	var best_dist := INF
	var h := view.wall_height(level)
	var t := HouseGrid.WALL_THICKNESS
	var base := HouseGrid.level_y(level)
	for key in house.get_layer(level, "walls"):
		var center := HouseGrid.edge_center(key)
		var size := Vector3(1, h, t) if HouseGrid.is_edge_horizontal(key) else Vector3(t, h, 1)
		var box := AABB(Vector3(center.x - size.x / 2.0, base, center.z - size.z / 2.0), size)
		var hit: Variant = box.intersects_ray(ray[0], ray[1])
		if hit != null and ray[0].distance_to(hit) < best_dist:
			best_dist = ray[0].distance_to(hit)
			best_key = key
	if best_key != "" or not use_nearby:
		return best_key

	var point: Variant = _point_on_level(screen_pos)
	if point == null:
		return ""
	var cell := Vector2i(floori(point.x), floori(point.z))
	best_dist = 0.4  # Distancia máxima para "agarrar" una pared.
	for edge in HouseGrid.cell_edges(cell):
		var c := HouseGrid.edge_center(edge)
		var dist := absf(point.z - c.z) if HouseGrid.is_edge_horizontal(edge) else absf(point.x - c.x)
		if house.has_piece(level, "walls", edge) and dist < best_dist:
			best_dist = dist
			best_key = edge
	return best_key


## Mueble bajo la pantalla ("" si no hay).
func _pick_object(screen_pos: Vector2) -> String:
	var ray := _ray(screen_pos)
	return view.pick_object(ray[0], ray[1], level)


## Con un dedo: ¿la cámara se mueve o el dedo construye?
func _update_camera_pan() -> void:
	if camera == null:
		return
	camera.single_finger_pan = _camera_takeover or not active or tool == Tool.NONE \
		or (tool == Tool.MOVE and _moving_key == "")


## Explica por qué algo salió en rojo, según la herramienta y el piso.
func _blocked_hint() -> String:
	if erase_mode:
		return "Hay piezas que no se pueden borrar: tienen algo encima."
	var upstairs := level > 0
	match tool:
		Tool.FOUNDATION:
			return "Los cimientos van solo en la planta baja."
		Tool.FLOOR:
			if upstairs:
				return "Arriba, el piso necesita piso o una pared justo debajo."
			return "En la planta baja, el piso va sobre cimientos."
		Tool.WALL, Tool.ROOM:
			if upstairs:
				return "Arriba, las paredes van sobre piso o sobre otra pared."
			return "En la planta baja, las paredes van junto a cimientos."
		Tool.OPENING:
			return "Las puertas y ventanas van sobre una pared."
		Tool.WINDOW_JOIN:
			return "Tocá una ventana."
		Tool.ROOF:
			return "El techo tiene que quedar dentro del lote."
		Tool.OBJECT, Tool.MOVE:
			if item.get("kind", "") == "stairs":
				return "La escalera va en la planta baja, sobre piso y sin paredes en el medio."
			return "No entra: necesita piso libre y sin paredes en el medio."
	return "No se puede ahí."


func _show_tool_hint() -> void:
	if erase_mode and tool != Tool.NONE:
		EventBus.build_hint.emit("Modo borrar: arrastrá o tocá lo que querés quitar.")
	elif tool == Tool.OBJECT or tool == Tool.OPENING:
		EventBus.build_hint.emit("%s: %s" % [item.get("name", ""), HINTS[tool]])
	else:
		EventBus.build_hint.emit(HINTS[tool])


# --- Creación de los nodos de ayuda ---

func _create_helpers() -> void:
	# Cuadrícula sobre todo el lote.
	var plane := PlaneMesh.new()
	plane.size = Vector2(HouseGrid.LOT_SIZE)
	var grid_mat := ShaderMaterial.new()
	grid_mat.shader = preload("res://assets/shaders/grid.gdshader")
	grid_mat.set_shader_parameter("lot_size", Vector2(HouseGrid.LOT_SIZE))
	_grid = MeshInstance3D.new()
	_grid.name = "Grid"
	_grid.mesh = plane
	_grid.material_override = grid_mat
	_grid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_grid.position = Vector3(HouseGrid.LOT_SIZE.x / 2.0, HouseGrid.level_y(0) + 0.03, HouseGrid.LOT_SIZE.y / 2.0)
	add_child(_grid)

	# Resaltado de la celda bajo el mouse.
	var square := PlaneMesh.new()
	square.size = Vector2(0.92, 0.92)
	_cursor = _make_flat_marker("Cursor", square, Color(1, 1, 1, 0.45))

	# Marca debajo del mueble elegido.
	var marker := PlaneMesh.new()
	marker.size = Vector2.ONE
	_selection_marker = _make_flat_marker("SelectionMarker", marker, Color(1, 0.85, 0.2, 0.6))

	_ghost = Node3D.new()
	_ghost.name = "Ghost"
	add_child(_ghost)

	# Manijas de la selección: se ven siempre, aunque haya paredes delante.
	var disc := CylinderMesh.new()
	disc.top_radius = 0.4
	disc.bottom_radius = 0.4
	disc.height = 0.05
	for color in [Color(1, 1, 1), Color(1, 0.8, 0.1)]:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.no_depth_test = true
		mat.render_priority = 10
		var handle := MeshInstance3D.new()
		handle.mesh = disc
		handle.material_override = mat
		handle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		handle.visible = false
		add_child(handle)
		_handles.append(handle)


func _make_flat_marker(marker_name: String, mesh: Mesh, color: Color) -> MeshInstance3D:
	var marker := MeshInstance3D.new()
	marker.name = marker_name
	marker.mesh = mesh
	marker.material_override = HousePieces.transparent_material(color)
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.visible = false
	add_child(marker)
	return marker
