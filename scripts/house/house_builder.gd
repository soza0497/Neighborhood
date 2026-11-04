class_name HouseBuilder
extends Node3D
## Modo construir (Pulido 1: constructor 2.0): herramientas, gestos y vista
## previa ("fantasma").
##
## Va como hijo de la HouseView, así usa las mismas coordenadas que la casa.
##
## Herramientas (la barra de abajo las elige):
##   - Tienda y Obra › Agregar: la pieza elegida del catálogo. Las de arrastre
##     (cimientos, piso, pared, cuarto, techo) dejan una selección con dos
##     manijas que se aplica con Confirmar; puertas, ventanas y muebles se
##     ponen al soltar.
##   - Obra › Modificar (MODIFY): tocar un mueble lo elige (flechas N/S/E/O,
##     girar, borrar); MANTENER presionado lo levanta y sigue al dedo. Tocar o
##     mantener una pared, techo, piso o cimiento abre un menú (mover, pintar,
##     borrar). Las junturas entre ventanas se ven como puntitos: tocarlos une
##     o separa esas dos ventanas.
##   - Pintura (PAINT, desde Modificar): tocar pinta UNA cara de pared (o un
##     piso) y aparecen flechas para seguir con la pared de al lado; mantener
##     presionado pinta arrastrando, solo sobre lo que se empezó (paredes o pisos).
##   - Borrar (ERASE): tocar resalta y pregunta "¿Borrar techo? Te devuelven
##     $X". En modo selección se van tocando varias cosas. Mantener y
##     arrastrar elige un rectángulo (pisos, cimientos) o una línea (paredes).
##
## En Modificar, Pintura y Borrar, arrastrar sin mantener mueve la cámara.
##
## Casa compartida (Fase 5 → Pulido 1): un cambio estructural no se manda solo:
## se arma una PROPUESTA con todos los cambios (se ven en la casa), y se manda
## entera a la pareja, que la previsualiza y la aprueba o la rechaza.

enum Tool { NONE, FOUNDATION, FLOOR, WALL, ROOM, ROOF, OPENING, OBJECT, PAINT, MODIFY, ERASE, EXCAVATE, ROOMS }

## Qué herramienta usa cada tipo ("kind") de objeto del catálogo.
const KIND_TO_TOOL := {
	"foundation": Tool.FOUNDATION,
	"excavation": Tool.EXCAVATE,
	"floor": Tool.FLOOR,
	"wall": Tool.WALL,
	"room": Tool.ROOM,
	"roof": Tool.ROOF,
	"door": Tool.OPENING,
	"window": Tool.OPENING,
	"stairs": Tool.OBJECT,
	"pillar": Tool.OBJECT,
	"furniture": Tool.OBJECT,
	"paint": Tool.PAINT,
}

## Herramientas que no están en el catálogo.
const MODIFY_TOOL_ID := "modify"
const ERASE_TOOL_ID := "erase"
## Pulido 4A: herramienta «Cuartos» (dentro de Obra → Modificar): resalta los cuartos y
## al tocar uno abre el menú de su tipo.
const ROOMS_TOOL_ID := "rooms"

## Clave provisional para algo nuevo; al soltar se cambia por un id real.
const NEW_KEY := "__new__"
## Mantener presionado: cuánto tiempo, y cuánto se puede mover el dedo antes
## de que cuente como "arrastrar la cámara".
const LONG_PRESS_SECONDS := 0.45
const TAP_MOVE_PIXELS := 14.0
## A cuántos píxeles de un puntito de juntura cuenta como tocarlo.
const JOINT_PICK_PIXELS := 40.0
## Cardinales para las flechas: N = -Z, S = +Z, E = +X, O = -X.
const DIRECTIONS := {"N": Vector2i(0, -1), "S": Vector2i(0, 1), "E": Vector2i(1, 0), "O": Vector2i(-1, 0)}

const HINTS := {
	Tool.NONE: "Elegí Tienda u Obra (Construir, Modificar o Borrar).",
	Tool.FOUNDATION: "Arrastrá para marcar el terreno de la casa (cimientos).",
	Tool.FLOOR: "Arrastrá sobre los cimientos para poner piso.",
	Tool.EXCAVATE: "Arrastrá en un sótano para excavar (un servicio con costo y espera). Después van los cimientos.",
	Tool.WALL: "Arrastrá de esquina a esquina para levantar una pared.",
	Tool.ROOM: "Arrastrá un rectángulo: pone piso y paredes de una vez.",
	Tool.ROOF: "Arrastrá un rectángulo sobre la casa para techarla.",
	Tool.OPENING: "Tocá una pared para ponerla.",
	Tool.OBJECT: "Arrastrá hasta su lugar y soltá. El botón de girar la rota.",
	Tool.PAINT: "Tocá una pared o un piso para pintarlo. Mantené presionado para pintar arrastrando.",
	Tool.MODIFY: "Tocá algo para elegirlo. Mantené presionado un mueble para moverlo con el dedo.",
	Tool.ERASE: "Tocá lo que querés borrar.",
	Tool.ROOMS: "Tocá un cuarto resaltado para elegir qué es (cocina, dormitorio, baño…).",
}

## Herramientas de arrastre (rectángulo o línea). Al soltar NO se aplican:
## queda una selección con dos manijas (círculos) que se pueden mover, y se
## aplica con el botón Confirmar. Así el dedo no tapa lo que se construye.
const HANDLE_TOOLS := [Tool.FOUNDATION, Tool.EXCAVATE, Tool.FLOOR, Tool.WALL, Tool.ROOM, Tool.ROOF]
## Herramientas de "tocar o mantener" (arrastrar sin mantener = cámara).
const PRESS_TOOLS := [Tool.PAINT, Tool.MODIFY, Tool.ERASE, Tool.ROOMS]
## A cuántos píxeles de una manija cuenta como tocarla.
const HANDLE_PICK_DISTANCE := 70.0

## Herramientas donde todo el gesto se aplica entero o nada.
const ALL_OR_NOTHING := [Tool.ROOF, Tool.OPENING, Tool.OBJECT, Tool.MODIFY]

var house: HouseData
var history: UndoHistory
var view: HouseView
var camera: CameraRig

## true en modo construir.
var active := false
## Nivel (piso) donde se construye. 0 = planta baja.
var level := 0
var tool := Tool.NONE
## Objeto del catálogo elegido (vacío si la herramienta no es del catálogo).
var item: Dictionary = {}
## Giro para el próximo mueble que se coloque: cuartos de vuelta + diagonal.
var place_rotation := 0
var place_diag := false
## Lo elegido en Modificar: capa ("objects", "roofs", "walls") y clave.
var selected_layer := ""
var selected_key := ""
## Borrar: varias cosas a la vez (modo selección).
var erase_multi := false
## Color de pintura elegido (id del catálogo).
var paint_item_id := ""
## Pulido 2: construcción planificada. Lo que se agrega queda como "previsto"
## (brilla cada pocos segundos) hasta que se toca Factura → Confirmar. Se
## puede apagar (las pruebas viejas construyen de una).
var plan_enabled := true
## true mientras se confirma el plan (así no vuelve a quedar como plan).
var _plan_bypass := false

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
## Tocar o mantener: dónde y cuándo se apretó, si ya se movió (cámara) y si
## ya cuenta como "mantener presionado".
var _press_pos := Vector2.ZERO
var _press_msec := 0
var _moved := false
var _long_pressed := false
## Mueble que se está arrastrando, y dónde se agarró.
var _moving_key := ""
var _grab_offset := Vector2i.ZERO
## Pintura arrastrando: sobre qué se empezó ("walls" o "floors") y lo que se
## va pintando: "walls|clave|lado" o "floors|clave" → true.
var _paint_surface := ""
var _paint_targets: Dictionary = {}
## La última cara pintada con un toque (para las flechas): {edge, side}.
var _paint_face: Dictionary = {}
## Borrar: lo elegido. Cada entrada: {id, label, writes}.
var _erase_items: Array = []
## Borrar arrastrando (mantener): capa del rectángulo o la línea.
var _erase_rect_layer := ""
## Lo que se tocó para abrir el menú de una pieza.
var _context_target: Dictionary = {}
## Escrituras que se aplicarían al soltar, y las que no se pueden.
var _pending_ok: Array = []
var _pending_blocked: Array = []
## La selección que espera Confirmar no tiene manijas (borrar, copiar contorno).
var _pending_plain := false
## Pulido 3B: celda donde está "sostenido" un mueble antes de confirmarlo (para
## poder girarlo con el botón ANTES de ponerlo). NO_CELL = ninguno.
const NO_CELL := Vector2i(-100000, -100000)
var _held_cell := NO_CELL

# --- Propuesta en la casa compartida ---
## Pasos de la propuesta aplicados en la casa (para verlos): {writes, inverse}.
var _draft_steps: Array = []
## "own" = la estoy armando yo; "review" = estoy viendo la de mi pareja.
var _draft_mode := ""
## El pedido que se está previsualizando (modo "review").
var _review_request: Dictionary = {}

# --- Nodos 3D de ayuda ---
var _grid: MeshInstance3D
var _cursor: MeshInstance3D
var _ghost: Node3D
var _selection_marker: MeshInstance3D
## Pulido 4A: resalte de cuartos (herramienta «Cuartos»).
var _room_overlay: Node3D
var _handles: Array[MeshInstance3D] = []
var _joints: Node3D
## Vértice de cada puntito de juntura (en el mismo orden que sus nodos).
var _joint_vertices: Array[Vector2i] = []
var _joints_dirty := true
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
	house.reloaded.connect(func():
		select_object("")
		_joints_dirty = true)
	paint_item_id = _first_paint_id()
	EventBus.rooms_changed.connect(refresh_room_overlay)


func _process(_delta: float) -> void:
	# Mantener presionado: pasa el tiempo sin que el dedo se mueva.
	if _pressing and tool in PRESS_TOOLS and not _moved and not _long_pressed \
			and Time.get_ticks_msec() - _press_msec >= LONG_PRESS_SECONDS * 1000:
		_on_long_press(_press_pos)
	if _joints_dirty and active:
		_joints_dirty = false
		_update_joints()


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
	_joints_dirty = true
	_update_camera_pan()


## Elige una herramienta: una pieza del catálogo por id, "modify", "erase"
## o "" (ninguna).
func select_item(item_id: String) -> void:
	_erase_items.clear()
	_cancel_gesture()
	select_object("")
	_paint_face = {}
	EventBus.build_paint_arrows.emit(false)
	if item_id == MODIFY_TOOL_ID:
		item = {}
		tool = Tool.MODIFY
	elif item_id == ERASE_TOOL_ID:
		item = {}
		tool = Tool.ERASE
	elif item_id == ROOMS_TOOL_ID:
		item = {}
		tool = Tool.ROOMS
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
		if tool == Tool.PAINT:
			paint_item_id = item_id
	place_rotation = 0
	place_diag = false
	_cursor.visible = false
	_joints_dirty = true
	_sync_grid()
	_update_camera_pan()
	_show_tool_hint()
	refresh_room_overlay()


## Borrar: una cosa por vez, o varias (modo selección).
func set_erase_multi(value: bool) -> void:
	erase_multi = value
	if not value and _erase_items.size() > 1:
		_clear_erase()
	_show_tool_hint()


## Compatibilidad con la interfaz vieja (botón "Borrar"): pasa a la
## herramienta Borrar.
func set_erase_mode(value: bool) -> void:
	select_item(ERASE_TOOL_ID if value else "")


## Cambia de nivel (piso). Devuelve el nivel que quedó.
func set_level(new_level: int) -> int:
	# Solo se puede ir a pisos que existen (los construidos o los agregados).
	level = clampi(new_level, house.lowest_level(), house.floors_total() - 1)
	_erase_items.clear()
	_cancel_gesture()
	select_object("")
	_paint_face = {}
	EventBus.build_paint_arrows.emit(false)
	_sync_grid()
	_joints_dirty = true
	refresh_room_overlay()
	return level


## Altura de la rejilla y de lo que se toca para elegir celdas: la del piso, o
## (Pulido 3B) con el techo, la de lo ALTO de las paredes de este piso: la
## rejilla «flota» ahí para tocar el área desde arriba sin que la pared tape.
func pick_height() -> float:
	return HouseGrid.level_y(level) + (HouseGrid.WALL_HEIGHT if tool == Tool.ROOF else 0.0)


func _sync_grid() -> void:
	if _grid != null:
		_grid.position.y = pick_height() + 0.03


## "Agregar piso" (Obra): suma un piso arriba y lo muestra. Si no se puede
## (no hay una parte sin techo, no hay piso de abajo...), avisa por qué.
## Devuelve true si lo agregó.
func add_floor() -> bool:
	var problem := HouseRules.add_floor_problem(house)
	if problem != "":
		EventBus.build_hint.emit(problem)
		EventBus.toast.emit(problem)
		return false
	house.floor_count = house.floors_total() + 1
	EventBus.floors_changed.emit(house.floors_total())
	EventBus.build_level_set_requested.emit(house.floors_total() - 1)
	EventBus.build_hint.emit("Piso agregado. Construí ahí arriba.")
	return true


## «Agregar sótano» (Obra): suma un sótano abajo (hasta 3) y va a él.
func add_basement() -> bool:
	var problem := HouseRules.add_basement_problem(house)
	if problem != "":
		EventBus.build_hint.emit(problem)
		EventBus.toast.emit(problem)
		return false
	house.basement_count = -house.lowest_level() + 1
	EventBus.floors_changed.emit(house.floors_total())
	EventBus.build_level_set_requested.emit(house.lowest_level())
	EventBus.build_hint.emit("Sótano agregado. Excavá (Construir › Excavación) y después poné cimientos.")
	return true


## Botón de girar: gira lo elegido, o el mueble que se va a colocar. Los
## muebles van de a 45° (8 direcciones); escaleras y pilares de a 90°.
func rotate_object() -> void:
	if selected_layer == "objects" and selected_key != "":
		var value: Dictionary = house.get_piece(level, "objects", selected_key).duplicate(true)
		var next := next_orientation(value["item"], int(value.get("rot", 0)), value.get("diag", false))
		value["rot"] = next[0]
		if next[1]:
			value["diag"] = true
		else:
			value.erase("diag")
		var check := _check(_object_writes(selected_key, value))
		if check["blocked"].is_empty():
			await _apply(check["ok"])
		else:
			EventBus.build_hint.emit("No hay lugar para girarlo aquí.")
	elif tool == Tool.OBJECT:
		var next := next_orientation(item.get("id", ""), place_rotation, place_diag)
		place_rotation = next[0]
		place_diag = next[1]
		if _held_cell != NO_CELL:
			# Pulido 3B: el mueble sostenido se gira ahí mismo, antes de confirmar.
			var check := _check(_object_place_writes(_held_cell))
			_pending_ok = check["ok"]
			_pending_blocked = check["blocked"]
			_show_preview()
			EventBus.build_hint.emit("Girado (%d°). Confirmá con ✓ o tocá otro lugar." % HouseGrid.object_angle(place_rotation, place_diag))
			return
		EventBus.build_hint.emit("Girado (%d°). Arrastrá para colocarlo." % HouseGrid.object_angle(place_rotation, place_diag))


## El giro siguiente: [rot, diag]. Los muebles pasan por la diagonal.
static func next_orientation(item_id: String, rot: int, diag: bool) -> Array:
	if Catalog.get_item(item_id).get("kind", "") == "furniture":
		if not diag:
			return [rot, true]
		return [(rot + 1) % 4, false]
	return [(rot + 1) % 4, false]


## Botón de borrar lo elegido (en Modificar): pregunta antes.
func delete_selected() -> void:
	if selected_key == "":
		return
	var entry := _erase_entry({"level": level, "layer": selected_layer, "key": selected_key})
	select_object("")
	if entry.is_empty():
		return
	_erase_items = [entry]
	_ask_erase()


## Flechas N/S/E/O (Modificar): corre lo elegido una celda.
func nudge_selected(direction: String) -> void:
	if selected_key == "" or not DIRECTIONS.has(direction):
		return
	var step: Vector2i = DIRECTIONS[direction]
	var value: Dictionary = house.get_piece(level, selected_layer, selected_key).duplicate(true)
	var writes: Array = []
	match selected_layer:
		"objects":
			var anchor := HouseData.object_anchor(value) + step
			value["cell"] = [anchor.x, anchor.y]
			writes = _object_writes(selected_key, value)
		"roofs":
			var rect := HouseData.roof_rect(value)
			value["rect"] = [rect.position.x + step.x, rect.position.y + step.y, rect.size.x, rect.size.y]
			writes = [HouseData.write(level, "roofs", selected_key, value)]
		"walls":
			var new_key := HouseGrid.edge_key(HouseGrid.edge_vertex(selected_key) + step,
				HouseGrid.is_edge_horizontal(selected_key))
			if house.has_piece(level, "walls", new_key):
				EventBus.build_hint.emit("Ahí ya hay una pared.")
				return
			value.erase("join_end")
			writes = [HouseData.write(level, "walls", selected_key, null), HouseData.write(level, "walls", new_key, value)]
	var check := _check_move(writes)
	if not check["blocked"].is_empty():
		EventBus.build_hint.emit(_move_blocked_hint())
		return
	var layer := selected_layer
	var moved_key := selected_key if layer != "walls" else str(writes[1]["key"])
	if await _apply(check["ok"]):
		select_object(moved_key, layer)


## Botón "Confirmar": aplica la selección que estaba esperando.
func confirm_pending() -> void:
	if not _awaiting_confirm:
		return
	var ok := _pending_ok
	var blocked := _pending_blocked
	# Si no alcanza el dinero, la selección se conserva para ajustarla.
	var money_change: int = Economy.quote(house, ok)["money"]
	if not has_draft() and not Economy.can_change(money_change):
		EventBus.build_hint.emit("Te faltan $%d. Achicá la selección o cancelá." % (-money_change - Economy.money))
		return
	if not Economy.can_request():
		return  # Sin conexión o esperando: la selección se conserva.
	_cancel_gesture()
	_commit(ok, blocked)


## Botón "Cancelar": descarta la selección que estaba esperando.
func cancel_pending() -> void:
	_erase_items.clear()
	if _awaiting_confirm:
		_cancel_gesture()
		_show_tool_hint()


## Marca algo como elegido en Modificar ("" = nada).
func select_object(key: String, layer := "objects") -> void:
	selected_key = key
	selected_layer = layer if key != "" else ""
	_update_selection_marker()
	EventBus.build_selection_changed.emit(selected_key != "")


## Menú de una pieza: la interfaz avisa qué opción se tocó.
func context_action(action: String) -> void:
	var target := _context_target
	_context_target = {}
	if target.is_empty():
		return
	match action:
		"move":
			select_object(target["key"], target["layer"])
			EventBus.build_hint.emit("Usá las flechas para correrlo.")
		"paint":
			select_item(paint_item_id)
			if target["layer"] == "walls":
				_paint_tap_face({"edge": target["key"], "side": target.get("side", "b")})
			else:
				_paint_now([{"layer": target["layer"], "key": target["key"]}])
		"room_type":
			EventBus.room_menu_requested.emit(level, HouseGrid.key_to_cell(target["key"]))
		"erase", "erase_opening":
			var entry := _erase_entry(target, action == "erase_opening")
			if not entry.is_empty():
				_erase_items = [entry]
				_ask_erase()


## Flechas de la pintura: pinta la pared de al lado (-1 = izquierda en la
## pantalla, +1 = derecha).
func paint_step(screen_dir: int) -> void:
	if _paint_face.is_empty():
		return
	var cam := get_viewport().get_camera_3d()
	var here := cam.unproject_position(to_global(WallFaces.face_center(_paint_face["edge"], _paint_face["side"])))
	var best: Dictionary = {}
	var best_x := INF
	for dir in [-1, 1]:
		var face := WallFaces.next_face(house, level, _paint_face["edge"], _paint_face["side"], dir)
		if face.is_empty():
			continue
		var x := cam.unproject_position(to_global(WallFaces.face_center(face["edge"], face["side"]))).x - here.x
		var score := x * screen_dir
		if best.is_empty() or -score < best_x:
			best = face
			best_x = -score
	if best.is_empty():
		EventBus.build_hint.emit("No hay más pared pegada para ese lado.")
		return
	_paint_tap_face(best)


## Un toque en una juntura (o la demo): une o separa esas dos ventanas.
func toggle_joint(vertex: Vector2i) -> void:
	var pair := HouseView.joint_walls(house, level, vertex)
	if pair.is_empty():
		return
	var first: Dictionary = house.get_piece(level, "walls", pair[0]).duplicate(true)
	var second: Dictionary = house.get_piece(level, "walls", pair[1])
	if first.get("join_end", false):
		first.erase("join_end")
		EventBus.build_hint.emit("Ventanas separadas.")
	elif first.get("opening", "") != second.get("opening", ""):
		EventBus.build_hint.emit("Solo se unen dos ventanas iguales.")
		return
	else:
		first["join_end"] = true
		EventBus.build_hint.emit("Ventanas unidas.")
	await _apply([HouseData.write(level, "walls", pair[0], first)])


## "Copiar contorno de abajo": pone las paredes de afuera del piso de abajo
## en este piso, con su losa completa (menos el hueco de las escaleras).
## Queda esperando Confirmar (se ve cuánto cuesta).
func copy_outline() -> void:
	if level == 0:
		EventBus.build_hint.emit("Subí a un piso de arriba para copiar el contorno de abajo.")
		return
	var writes := outline_writes(house, level)
	if writes.is_empty():
		EventBus.build_hint.emit("Abajo no hay piso para copiar (o ya está copiado).")
		return
	select_item("")
	_start_plain_pending(writes)
	EventBus.build_hint.emit("Así quedaría el contorno. Tocá «Confirmar» y después armá los cuartos.")


## Las escrituras de "copiar contorno": losa y paredes de afuera de abajo.
static func outline_writes(target: HouseData, to_level: int) -> Array:
	var below := to_level - 1
	var writes: Array = []
	var cells := {}
	for key in target.get_layer(below, "floors"):
		cells[key] = true
	for key in cells:
		var cell := HouseGrid.key_to_cell(key)
		if HouseRules.is_stairs_cell(target, below, cell) or target.has_piece(to_level, "floors", key):
			continue
		var floor_item: String = target.get_piece(below, "floors", key).get("item", "floor_basic")
		writes.append(HouseData.write(to_level, "floors", key, {"item": floor_item}))
	for key in cells:
		var cell := HouseGrid.key_to_cell(key)
		for edge in HouseGrid.cell_edges(cell):
			var both := HouseGrid.edge_cells(edge)
			var other: Vector2i = both[0] if both[1] == cell else both[1]
			if cells.has(HouseGrid.cell_key(other)) or target.has_piece(to_level, "walls", edge):
				continue
			var wall_item := "wall_basic"
			var below_wall: Variant = target.get_piece(below, "walls", edge)
			if below_wall != null:
				wall_item = below_wall["item"]
			var write := HouseData.write(to_level, "walls", edge, {"item": wall_item})
			if not write in writes:
				writes.append(write)
	return writes


## El cuarto que se está mirando (centro de la cámara) o, si no hay, el del
## personaje. {} si ninguno está en un cuarto cerrado.
func room_here(character_level := -1, character_cell := Vector2i(-1, -1)) -> Dictionary:
	if camera != null and view != null:
		var local := view.to_local(camera.global_position)
		var room := HouseRooms.room_at(house, level, Vector2i(floori(local.x), floori(local.z)))
		if not room.is_empty():
			return room
	if character_level == level:
		return HouseRooms.room_at(house, level, character_cell)
	return {}


# --- Propuesta (casa compartida) ---

## ¿Hay una propuesta aplicada en la casa (mía o de la pareja)?
func has_draft() -> bool:
	return _draft_mode != ""


func draft_mode() -> String:
	return _draft_mode


## Cuántos cambios tiene la propuesta y cuánto cuesta (lo que se va a pedir).
func draft_summary() -> Dictionary:
	var writes := draft_writes()
	return {"steps": _draft_steps.size(), "pieces": writes.size(),
		"cost": -int(Economy.quote(house_without_draft(), writes)["money"])}


## La casa como era antes de la propuesta (lo que se guarda en el teléfono).
func house_without_draft() -> HouseData:
	var copy := house.duplicate_data()
	for i in range(_draft_steps.size() - 1, -1, -1):
		copy.apply(_draft_steps[i]["inverse"])
	return copy


## Todas las piezas que cambia la propuesta, juntas (lo último de cada lugar).
func draft_writes() -> Array:
	var original := house_without_draft()
	var seen := {}
	var writes: Array = []
	for step in _draft_steps:
		for w in step["writes"]:
			var id := "%d|%s|%s" % [w["level"], w["layer"], w["key"]]
			if seen.has(id):
				continue
			seen[id] = true
			var now: Variant = house.get_piece(w["level"], w["layer"], w["key"])
			var before: Variant = original.get_piece(w["level"], w["layer"], w["key"])
			if JSON.stringify(now) != JSON.stringify(before):
				writes.append(HouseData.write(w["level"], w["layer"], w["key"], now))
	return writes


## Deshacer dentro de la propuesta: saca el último cambio.
func draft_undo() -> void:
	if not (_draft_mode == "own" or _draft_mode == "plan") or _draft_steps.is_empty():
		return
	var step: Dictionary = _draft_steps.pop_back()
	house.apply(step["inverse"])
	if _draft_steps.is_empty():
		_end_draft()
	else:
		_announce_draft()


## Saca la propuesta de la casa (sin mandarla).
func discard_draft() -> void:
	_cancel_gesture()
	select_object("")
	for i in range(_draft_steps.size() - 1, -1, -1):
		house.apply(_draft_steps[i]["inverse"])
	_end_draft()


## Manda la propuesta entera a la pareja (un solo pedido).
func send_draft() -> bool:
	if _draft_mode != "own" or not Economy.can_request():
		return false
	var writes := draft_writes()
	discard_draft()
	if writes.is_empty():
		return true
	EventBus.build_hint.emit(Economy.BUSY_TEXT)
	var result: Dictionary = await Economy.request("build_apply", {"writes": writes})
	if not result["ok"]:
		EventBus.build_hint.emit(result["error"])
		_add_to_draft(writes)  # Se vuelve a ver para corregirla.
		return false
	if result["data"].get("requested", false):
		EventBus.build_hint.emit("Le mandaste la propuesta a %s (%s)." % [Couple.partner_name(), str(result["data"].get("text", ""))])
		EventBus.toast.emit("Propuesta enviada a %s." % Couple.partner_name())
	else:
		history.apply_remote(CloudSync.writes_from_server(result["data"].get("writes", [])))
		_show_money_hint(int(result["data"].get("money_change", 0)))
	return true


## Ver la propuesta de la pareja en la casa (sin aprobarla todavía).
func show_review(request: Dictionary, writes: Array) -> void:
	if has_draft():
		discard_draft()
	_review_request = request
	_draft_mode = "review"
	_draft_steps = [{"writes": writes, "inverse": house.apply(writes)}]
	_joints_dirty = true
	_announce_draft()


## Deja de ver la propuesta de la pareja.
func close_review() -> void:
	if _draft_mode == "review":
		discard_draft()


func review_request() -> Dictionary:
	return _review_request


## ¿Estas escrituras van al plan? Solo lo que AGREGA piezas con una
## herramienta de poner (no mover, pintar ni borrar).
func _should_plan(writes: Array) -> bool:
	if not plan_enabled or _plan_bypass or not (_draft_mode == "" or _draft_mode == "plan"):
		return false
	if not tool in [Tool.FOUNDATION, Tool.EXCAVATE, Tool.FLOOR, Tool.WALL, Tool.ROOM, Tool.ROOF, Tool.OPENING, Tool.OBJECT]:
		return false
	for w in writes:
		if w["value"] == null:
			return false
	return true


func _add_to_draft(writes: Array, mode := "own") -> void:
	# Un plan que se vuelve propuesta (cambio estructural en pareja) queda "own".
	_draft_mode = "own" if (mode == "own" or _draft_mode == "own") else "plan"
	var inverse := house.apply(writes)
	_draft_steps.append({"writes": writes, "inverse": inverse})
	_announce_draft()


func _end_draft() -> void:
	_draft_steps.clear()
	_draft_mode = ""
	_review_request = {}
	view.set_planned({})
	EventBus.proposal_changed.emit("", {})


func _announce_draft() -> void:
	_mark_planned()
	EventBus.proposal_changed.emit(_draft_mode, draft_summary())


## Le dice a la vista qué piezas están previstas (para que brillen).
func _mark_planned() -> void:
	var ids := {}
	if _draft_mode == "plan":
		for w in draft_writes():
			ids["%d|%s|%s" % [w["level"], w["layer"], w["key"]]] = true
	view.set_planned(ids)


# --- Plan y factura (Pulido 2) ---

## La factura del plan: {lines: [{name, qty, cost}], total, seconds}.
## `total` es lo que se paga (negativo = te devuelven). `seconds` es la
## espera hasta que termina la obra más larga.
func plan_invoice() -> Dictionary:
	var writes := draft_writes()
	var original := house_without_draft()
	var quote := Economy.quote(original, writes)
	var grouped := {}
	var longest := 0
	for w in quote["writes"]:
		var value: Variant = w["value"]
		if value == null:
			continue
		var old: Variant = original.get_piece(w["level"], w["layer"], w["key"])
		var piece_name: String = Catalog.get_item(value.get("item", "")).get("name", _piece_name(w["layer"], value))
		var line: Dictionary = grouped.get(piece_name, {"name": piece_name, "qty": 0, "cost": 0})
		line["qty"] += 1
		line["cost"] += -Economy.change_for(w["layer"], old, value)
		grouped[piece_name] = line
		longest = maxi(longest, int(value.get("ready_at", 0)) - Economy.now())
	return {"lines": grouped.values(), "total": -int(quote["money"]), "seconds": longest}


## Factura aceptada: se saca lo previsto y se construye de verdad (cobra,
## pone el temporizador y, en pareja, pide la aprobación). Si no se puede
## (falta plata, sin conexión), el plan vuelve a quedar previsto.
func confirm_plan() -> bool:
	if _draft_mode != "plan" or not Economy.can_request():
		return false
	var writes := draft_writes()
	var money_change: int = Economy.quote(house_without_draft(), writes)["money"]
	if not Economy.can_change(money_change):
		EventBus.build_hint.emit("Te faltan $%d para esta factura. Sacá algo del plan." % (-money_change - Economy.money))
		return false
	discard_draft()
	_plan_bypass = true
	var applied: bool = await _apply(writes)
	_plan_bypass = false
	if not applied:
		_add_to_draft(writes, "plan")
	return applied


# --- Plantillas de casa (Pulido 5E) ---

## Coloca una plantilla que ya se revisó (HouseTemplate.check). Entra por el MISMO
## camino que cualquier obra: va al plan (se paga en la factura) y, en la casa
## compartida, a la propuesta; sin plan, se cobra en el momento. Con servidor lo
## cobra y lo revisa el servidor (build_apply), y es UN solo paso de deshacer.
## Devuelve true si quedó en el plan o se construyó.
func place_template(writes: Array) -> bool:
	if writes.is_empty():
		return false
	if _draft_mode == "review":
		EventBus.build_hint.emit("Estás viendo la propuesta de tu pareja: cerrala para construir.")
		return false
	if not Economy.can_request():
		return false
	HouseTemplate.claim_ids(house, writes)
	if not needs_approval(writes) and plan_enabled and not _plan_bypass and (_draft_mode == "" or _draft_mode == "plan"):
		_add_to_draft(writes, "plan")
		EventBus.build_hint.emit("La plantilla quedó prevista. Tocá «Factura» para construirla (o deshacé para sacarla).")
		return true
	return await _apply(writes)


# --- Entrada (toques y mouse) ---

func _unhandled_input(event: InputEvent) -> void:
	if not active or tool == Tool.NONE and not _awaiting_confirm:
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
	if _awaiting_confirm and tool in HANDLE_TOOLS and not _pending_plain:
		var handle := _handle_at(screen_pos)
		if handle >= 0:
			_drag_handle = handle
			_pressing = true
			return

	if tool == Tool.NONE:
		return  # Sin herramienta, el dedo mueve la cámara.

	if tool in PRESS_TOOLS:
		# Tocar o mantener: se decide al soltar (o al pasar el tiempo).
		_pressing = true
		_press_pos = screen_pos
		_press_msec = Time.get_ticks_msec()
		_moved = false
		_long_pressed = false
		_last_screen_pos = screen_pos
		_update_camera_pan()
		return

	if not _is_on_lot(screen_pos):
		# Fuera del lote, el dedo mueve la cámara (la selección se conserva).
		_camera_takeover = true
		_update_camera_pan()
		return

	if _awaiting_confirm:
		_cancel_gesture()  # Tocó otra parte del lote: selección nueva.

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
	if tool in PRESS_TOOLS and _drag_handle < 0:
		if not _long_pressed:
			if screen_pos.distance_to(_press_pos) > TAP_MOVE_PIXELS:
				_moved = true  # Es la cámara la que se mueve.
			return
		_update_long_drag(screen_pos)
		return
	if tool in HANDLE_TOOLS and _pressing:
		if _drag_handle == 0:
			_start_cell = _cell_at(screen_pos, true)
			_start_vertex = _vertex_at(screen_pos)
		else:
			_end_cell = _cell_at(screen_pos, true)
			_end_vertex = _vertex_at(screen_pos)
		_update_handles()
	var check := _check(_place_writes(screen_pos))
	_pending_ok = check["ok"]
	_pending_blocked = check["blocked"]
	if tool in HANDLE_TOOLS and _pressing:
		_announce_cost()
	_show_preview()


## Se levantó el dedo (o el botón del mouse).
func _release() -> void:
	if _camera_takeover:
		_camera_takeover = false
		_update_camera_pan()
	if not _pressing:
		return
	if tool in PRESS_TOOLS and _drag_handle < 0:
		_pressing = false
		if _long_pressed:
			_finish_long_drag()
		elif not _moved:
			_on_tap(_press_pos)
		_long_pressed = false
		_update_camera_pan()
		return
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
		_announce_cost()
		if _pending_blocked.is_empty():
			EventBus.build_hint.emit("Mové los círculos para ajustar y tocá «Confirmar».")
		else:
			EventBus.build_hint.emit(_blocked_hint() + " Lo rojo no se va a poner.")
		return

	# Pulido 3B: un mueble (o escalera, pilar) NO se pone al soltar: queda
	# sostenido con su fantasma para poder girarlo con el botón de 45° y recién
	# se pone con Confirmar. Tocar en otro lugar lo cambia de sitio.
	if tool == Tool.OBJECT and not (_pending_ok.is_empty() and _pending_blocked.is_empty()):
		_held_cell = _cell_at(_last_screen_pos, false)
		_pressing = false
		_drag_handle = -1
		_awaiting_confirm = true
		_pending_plain = true
		EventBus.build_pending_changed.emit(true)
		_announce_cost()
		EventBus.build_hint.emit("Girá con el botón (45°), tocá otro lugar para moverlo y confirmá con ✓." \
			if _pending_blocked.is_empty() else _blocked_hint())
		_show_preview()
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
		_long_pressed = false
		_update_camera_pan()
	else:
		_cancel_gesture()


# --- Tocar y mantener (Modificar, Pintura, Borrar) ---

func _on_tap(screen_pos: Vector2) -> void:
	match tool:
		Tool.MODIFY:
			var joint := _joint_at(screen_pos)
			if joint != Vector2i(-1, -1):
				toggle_joint(joint)
				return
			var target := _pick_any(screen_pos)
			if target.is_empty():
				select_object("")
				_show_tool_hint()
			elif target["layer"] == "objects":
				select_object(target["key"])
				EventBus.build_hint.emit("Flechas para correrlo, girar o borrar. Mantené presionado para llevarlo con el dedo.")
			else:
				_open_context_menu(target)
		Tool.PAINT:
			var face := _pick_wall_face(screen_pos)
			if not face.is_empty():
				_paint_tap_face(face)
				return
			var floor_key := _pick_floor(screen_pos)
			if floor_key != "":
				_paint_face = {}
				EventBus.build_paint_arrows.emit(false)
				_paint_now([{"layer": "floors", "key": floor_key}])
		Tool.ROOMS:
			var cell := room_cell_at(screen_pos)
			if cell == NO_CELL:
				EventBus.build_hint.emit("Ahí no hay un cuarto cerrado. Tocá uno de los resaltados.")
			else:
				EventBus.room_menu_requested.emit(level, cell)
		Tool.ERASE:
			var target := _pick_any(screen_pos)
			if target.is_empty():
				if not erase_multi:
					_clear_erase()
				return
			var entry := _erase_entry(target)
			if entry.is_empty():
				return
			var existing := _erase_items.filter(func(e): return e["id"] == entry["id"])
			if erase_multi:
				if not existing.is_empty():
					_erase_items.erase(existing[0])
				else:
					_erase_items.append(entry)
			else:
				_erase_items = [entry]
			if _erase_items.is_empty():
				_clear_erase()
			else:
				_ask_erase()


func _on_long_press(screen_pos: Vector2) -> void:
	_long_pressed = true
	match tool:
		Tool.ROOMS:
			# Nada que arrastrar: sigue siendo la cámara.
			_long_pressed = false
			_moved = true
			return
		Tool.MODIFY:
			var target := _pick_any(screen_pos)
			if target.is_empty():
				_long_pressed = false
				_moved = true  # Nada que hacer: que siga la cámara.
				return
			if target["layer"] == "objects":
				# Se levanta y sigue al dedo (la marca va separada del dedo).
				select_object(target["key"])
				_moving_key = target["key"]
				var anchor := HouseData.object_anchor(house.get_piece(level, "objects", _moving_key))
				_grab_offset = _cell_at(screen_pos, false) - anchor
				EventBus.build_hint.emit("Llevalo con el dedo y soltá donde va.")
			else:
				_long_pressed = false
				_moved = true
				_open_context_menu(target)
				return
		Tool.PAINT:
			var face := _pick_wall_face(screen_pos)
			_paint_surface = "walls" if not face.is_empty() else ("floors" if _pick_floor(screen_pos) != "" else "")
			if _paint_surface == "":
				_long_pressed = false
				_moved = true
				return
			_paint_face = {}
			EventBus.build_paint_arrows.emit(false)
			_ripple(screen_pos)
			EventBus.build_hint.emit("Pintando %s: arrastrá el dedo." % ("paredes" if _paint_surface == "walls" else "pisos"))
		Tool.ERASE:
			var target := _pick_any(screen_pos)
			if target.is_empty() or not target["layer"] in ["floors", "foundation", "walls"]:
				_long_pressed = false
				_moved = true
				return
			_erase_rect_layer = target["layer"]
			_start_cell = _cell_at(screen_pos, true)
			_start_vertex = _vertex_at(screen_pos)
			_ripple(screen_pos)
			EventBus.build_hint.emit("Arrastrá para elegir varias de una vez.")
	_update_camera_pan()
	_update_long_drag(screen_pos)


func _update_long_drag(screen_pos: Vector2) -> void:
	match tool:
		Tool.MODIFY:
			if _moving_key == "":
				return
			var value: Dictionary = house.get_piece(level, "objects", _moving_key).duplicate(true)
			var anchor := _cell_at(screen_pos, false) - _grab_offset
			var writes: Array = []
			if anchor != HouseData.object_anchor(value):
				value["cell"] = [anchor.x, anchor.y]
				writes = _object_writes(_moving_key, value)
			var check := _check(writes)
			_pending_ok = check["ok"]
			_pending_blocked = check["blocked"]
			_show_preview()
		Tool.PAINT:
			if _paint_surface == "walls":
				var face := _pick_wall_face(screen_pos)
				if not face.is_empty():
					_paint_targets["walls|%s|%s" % [face["edge"], face["side"]]] = true
			else:
				var floor_key := _pick_floor(screen_pos)
				if floor_key != "":
					_paint_targets["floors|" + floor_key] = true
			var check := _check(_paint_writes())
			_pending_ok = check["ok"]
			_pending_blocked = check["blocked"]
			_show_preview()
		Tool.ERASE:
			_end_cell = _cell_at(screen_pos, true)
			_end_vertex = _vertex_at(screen_pos)
			var writes: Array = []
			if _erase_rect_layer == "walls":
				for edge in HouseGrid.edges_in_line(_start_vertex, _end_vertex):
					_add_removal(writes, level, "walls", edge)
			else:
				for c in HouseGrid.cells_in_rect(_start_cell, _end_cell):
					_add_removal(writes, level if _erase_rect_layer == "floors" else 0, _erase_rect_layer, HouseGrid.cell_key(c))
			var check := HouseRules.check_removal(house, writes)
			_pending_ok = check["ok"]
			_pending_blocked = check["blocked"]
			_show_preview()


func _finish_long_drag() -> void:
	match tool:
		Tool.MODIFY:
			var ok := _pending_ok
			var blocked := _pending_blocked
			var key := _moving_key
			_moving_key = ""
			_clear_preview()
			_pending_ok = []
			_pending_blocked = []
			if not blocked.is_empty():
				EventBus.build_hint.emit(_blocked_hint())
			elif not ok.is_empty():
				await _apply(ok)
			select_object(key)
		Tool.PAINT:
			var ok := _pending_ok
			_paint_targets.clear()
			_paint_surface = ""
			_clear_preview()
			_pending_ok = []
			await _apply(ok)
			_show_tool_hint()
		Tool.ERASE:
			for w in _pending_ok:
				var entry := {"id": "%d|%s|%s" % [w["level"], w["layer"], w["key"]], "label": _piece_name(w["layer"]),
					"writes": [w]}
				if _erase_items.filter(func(e): return e["id"] == entry["id"]).is_empty():
					_erase_items.append(entry)
			if not _pending_blocked.is_empty():
				EventBus.toast.emit("Algunas no se pueden borrar: tienen algo encima.")
			_pending_ok = []
			_pending_blocked = []
			_clear_preview()
			if _erase_items.is_empty():
				_clear_erase()
			else:
				_ask_erase()


## Pinta una cara de pared con un toque y deja las flechas para seguir.
func _paint_tap_face(face: Dictionary) -> void:
	_paint_face = face
	_paint_now([{"layer": "walls", "key": face["edge"], "side": face["side"]}])
	EventBus.build_paint_arrows.emit(true)
	_update_selection_marker()


## Pinta ya (sin esperar Confirmar): pintar no cuesta.
func _paint_now(targets: Array) -> void:
	var color: String = Catalog.get_item(paint_item_id).get("color", "#ffffff")
	var writes: Array = []
	for t in targets:
		var value: Variant = house.get_piece(level, t["layer"], t["key"])
		if value == null:
			continue
		value = (value as Dictionary).duplicate(true)
		if t["layer"] == "walls":
			value["color_" + t.get("side", "b")] = color
		else:
			value["color"] = color
		writes.append(HouseData.write(level, t["layer"], t["key"], value))
	await _apply(writes)


## Escrituras de lo que se fue pintando arrastrando.
func _paint_writes() -> Array:
	var color: String = Catalog.get_item(paint_item_id).get("color", "#ffffff")
	var by_key := {}
	var writes: Array = []
	for target in _paint_targets:
		var parts: PackedStringArray = target.split("|")
		var id := parts[0] + "|" + parts[1]
		var value: Variant = by_key.get(id, house.get_piece(level, parts[0], parts[1]))
		if value == null:
			continue
		value = (value as Dictionary).duplicate(true)
		if parts[0] == "walls":
			value["color_" + parts[2]] = color
		else:
			value["color"] = color
		by_key[id] = value
	for id in by_key:
		var parts: PackedStringArray = id.split("|")
		writes.append(HouseData.write(level, parts[0], parts[1], by_key[id]))
	return writes


# --- Borrar ---

## Lo que se borra al tocar algo: {id, label, writes}. Una pared con puerta o
## ventana pierde primero la abertura. {} si no se puede (y avisa por qué).
func _erase_entry(target: Dictionary, opening_only := false) -> Dictionary:
	var lvl: int = target.get("level", level)
	var layer: String = target["layer"]
	var key: String = target["key"]
	var value: Variant = house.get_piece(lvl, layer, key)
	if value == null:
		return {}
	if layer == "walls" and (opening_only or value.has("opening")) and value.has("opening"):
		var wall: Dictionary = value.duplicate(true)
		var opening_name: String = Catalog.get_item(wall["opening"]).get("name", "abertura")
		wall.erase("opening")
		wall.erase("join_end")
		var writes: Array = [HouseData.write(lvl, layer, key, wall)]
		writes.append_array(_unjoin_previous(lvl, key))
		return {"id": "%d|%s|%s|opening" % [lvl, layer, key], "label": opening_name.to_lower(), "writes": writes}
	# Pulido 2: el basurero borra TODO. Lo que se apoyaba solo en la pieza
	# (paredes de un cimiento, el piso de arriba de una pared...) se borra
	# con ella: la pregunta lo dice y todo se ve en rojo.
	var closure := HouseRules.removal_closure(house, HouseData.write(lvl, layer, key, null))
	var removing := {}
	for c in closure:
		removing["%d|%s|%s" % [c["level"], c["layer"], c["key"]]] = true
	var writes: Array = closure.duplicate()
	for c in closure:
		if c["layer"] == "walls":
			var previous := HouseGrid.previous_in_line(c["key"])
			if not removing.has("%d|walls|%s" % [c["level"], previous]):
				writes.append_array(_unjoin_previous(c["level"], c["key"]))
	var label := _piece_name(layer, value)
	if closure.size() > 1:
		label += " y %d pieza%s que se apoya%s" % [closure.size() - 1, "" if closure.size() == 2 else "s", "" if closure.size() == 2 else "n"]
	return {"id": "%d|%s|%s" % [lvl, layer, key], "label": label, "writes": writes}


## Si la pared de antes estaba unida a esta, se separa (la juntura se va).
func _unjoin_previous(lvl: int, key: String) -> Array:
	var previous := HouseGrid.previous_in_line(key)
	var prev: Variant = house.get_piece(lvl, "walls", previous)
	if prev == null or not prev.get("join_end", false):
		return []
	var copy: Dictionary = prev.duplicate(true)
	copy.erase("join_end")
	return [HouseData.write(lvl, "walls", previous, copy)]


## Muestra lo elegido para borrar (en rojo) y pregunta.
func _ask_erase() -> void:
	var writes: Array = []
	for entry in _erase_items:
		writes.append_array(entry["writes"])
	_start_plain_pending(writes)
	var refund: int = Economy.quote(house, writes)["money"]
	var label := ""
	if _erase_items.size() == 1:
		label = "¿Borrar %s?" % _erase_items[0]["label"]
		EventBus.build_confirm_label.emit("Borrar · te devuelven $%d" % refund)
	else:
		label = "¿Borrar %d cosas?" % _erase_items.size()
		EventBus.build_confirm_label.emit("Borrar %d cosas · te devuelven $%d" % [_erase_items.size(), refund])
	EventBus.build_hint.emit("%s Te devuelven $%d." % [label, refund])


func _clear_erase() -> void:
	_erase_items.clear()
	if _awaiting_confirm:
		_cancel_gesture()
	_show_tool_hint()


## Deja unas escrituras esperando Confirmar, sin manijas.
func _start_plain_pending(writes: Array) -> void:
	_cancel_gesture()
	var adds: Array = writes.filter(func(w): return w["value"] != null)
	var check := _check(writes) if not adds.is_empty() else {"ok": writes, "blocked": []}
	_pending_ok = check["ok"]
	_pending_blocked = check["blocked"]
	_pending_plain = true
	_awaiting_confirm = true
	EventBus.build_pending_changed.emit(true)
	_announce_cost()
	_show_preview()


func _piece_name(layer: String, value: Variant = null) -> String:
	match layer:
		"roofs":
			return "el techo"
		"walls":
			return "la pared"
		"floors":
			return "el piso"
		"foundation":
			return "los cimientos"
		"objects":
			if value != null:
				return Catalog.get_item(value["item"]).get("name", "el mueble").to_lower()
			return "el mueble"
	return "eso"


# --- Menú de una pieza (Modificar) ---

func _open_context_menu(target: Dictionary) -> void:
	_context_target = target
	var value: Dictionary = house.get_piece(level, target["layer"], target["key"])
	var title: String = Catalog.get_item(value.get("item", "")).get("name", "Pieza")
	var options: Array = []
	match target["layer"]:
		"walls":
			options.append({"id": "paint", "text": "Pintar esta cara"})
			options.append({"id": "move", "text": "Mover"})
			if value.has("opening"):
				var opening_name: String = Catalog.get_item(value["opening"]).get("name", "abertura")
				options.append({"id": "erase_opening", "text": "Quitar %s" % opening_name.to_lower()})
			options.append({"id": "erase", "text": "Borrar pared"})
		"roofs":
			options.append({"id": "move", "text": "Mover"})
			options.append({"id": "erase", "text": "Borrar techo"})
		"floors":
			options.append({"id": "paint", "text": "Pintar"})
			# Pulido 3B: si el piso es de un cuarto cerrado, se le puede elegir el tipo.
			var room := HouseRooms.room_at(house, level, HouseGrid.key_to_cell(target["key"]))
			if not room.is_empty():
				options.append({"id": "room_type", "text": "Tipo de cuarto (%s)" % room["name"]})
			options.append({"id": "erase", "text": "Borrar piso"})
		"foundation":
			options.append({"id": "erase", "text": "Borrar cimientos"})
	EventBus.build_context_menu.emit(title, options)


# --- Aplicar ---

## Aplica las escrituras como un paso de deshacer y avisa qué pasó.
func _commit(ok: Array, blocked: Array) -> void:
	_erase_items.clear()
	var applied: bool = await _apply(ok)
	if not applied:
		return  # _apply ya explicó por qué (no alcanza el dinero, sin conexión...).
	if not blocked.is_empty():
		EventBus.build_hint.emit(_blocked_hint())
	elif not ok.is_empty() and not Economy.server_mode:
		_show_tool_hint()


## Cobra (o devuelve) el dinero, aplica las escrituras como UN paso de
## deshacer y anota lo construido. Devuelve false si no se pudo.
## Con servidor (Fase 4B) se le pide a él y se espera su respuesta: él cobra,
## pone la hora de las obras y guarda el paso de deshacer.
## En la casa compartida, lo estructural va a la propuesta.
func _apply(writes: Array) -> bool:
	if writes.is_empty():
		return true
	if _draft_mode == "review":
		EventBus.build_hint.emit("Estás viendo la propuesta de tu pareja: cerrala para construir.")
		return false
	if not Economy.can_request():
		return false
	# Lo nuevo recibe su id definitivo ahora.
	for w in writes:
		if w["key"] == NEW_KEY:
			w["key"] = house.new_id()
	if needs_approval(writes):
		_add_to_draft(writes)
		EventBus.build_hint.emit("Agregado a la propuesta. Cuando termines, mandala a %s." % Couple.partner_name())
		return true
	# Pulido 2: lo que se agrega queda previsto en un plan; se paga al confirmar la factura.
	if _should_plan(writes):
		_add_to_draft(writes, "plan")
		EventBus.build_hint.emit("Quedó previsto. Seguí agregando y, al terminar, tocá «Factura».")
		return true
	var quote := Economy.quote(house, writes)
	var money_change: int = quote["money"]
	if not Economy.can_change(money_change):
		EventBus.build_hint.emit("Te faltan $%d para construir esto." % (-money_change - Economy.money))
		return false
	if Economy.server_mode:
		return await _apply_on_server(writes)
	history.commit(quote["writes"], money_change)
	Economy.record_build(quote["writes"])
	_show_money_hint(money_change)
	return true


## Casa compartida: ¿este cambio va a la propuesta? Lo estructural sí (lo
## decide el servidor; esto es para avisar antes), y si ya hay una
## propuesta armándose, todo va ahí.
func needs_approval(writes: Array) -> bool:
	if not Economy.shared or writes.is_empty():
		return false
	return _draft_mode == "own" or not HousePermissions.is_minor(house, writes)


## Manda el cambio al servidor y aplica lo que él aceptó.
func _apply_on_server(writes: Array) -> bool:
	EventBus.build_hint.emit(Economy.BUSY_TEXT)
	var result: Dictionary = await Economy.request("build_apply", {"writes": writes})
	if not result["ok"]:
		EventBus.build_hint.emit(result["error"])
		return false
	if result["data"].get("requested", false):
		var text := "Le pediste permiso a %s (%s). Te avisamos cuando responda." % [
			Couple.partner_name(), str(result["data"].get("text", ""))]
		EventBus.build_hint.emit(text)
		EventBus.toast.emit("Pedido enviado a %s." % Couple.partner_name())
		return true
	history.apply_remote(CloudSync.writes_from_server(result["data"].get("writes", [])))
	_show_money_hint(int(result["data"].get("money_change", 0)))
	return true


func _show_money_hint(money_change: int) -> void:
	if money_change < 0:
		EventBus.build_hint.emit("Pagaste $%d." % -money_change)
	elif money_change > 0:
		EventBus.build_hint.emit("Te devolvieron $%d." % money_change)
	else:
		_show_tool_hint()


## Avisa cuánto cuesta lo que espera Confirmar (y si va a la propuesta).
func _announce_cost() -> void:
	EventBus.build_approval_changed.emit(needs_approval(_pending_ok))
	EventBus.build_cost_changed.emit(-Economy.quote(house, _pending_ok)["money"])


## Mouse moviéndose sin apretar (solo en la PC): muestra dónde caería.
func _hover(screen_pos: Vector2) -> void:
	if _awaiting_confirm or tool in PRESS_TOOLS:
		return
	match tool:
		Tool.OBJECT, Tool.OPENING:
			_update(screen_pos)
			return
	_clear_preview()
	var point: Variant = _point_on_level(screen_pos)
	if point == null:
		_cursor.visible = false
		return
	_cursor.visible = true
	if tool == Tool.WALL:
		var v := _vertex_at(screen_pos)
		_cursor.position = Vector3(v.x, pick_height() + 0.05, v.y)
		_cursor.scale = Vector3(0.3, 1, 0.3)
	else:
		var cell := _cell_at(screen_pos, false)
		_cursor.position = HouseGrid.cell_center(cell) + Vector3(0, pick_height() + 0.05, 0)
		_cursor.scale = Vector3.ONE


func _cancel_gesture() -> void:
	_pressing = false
	_drag_handle = -1
	_long_pressed = false
	if _awaiting_confirm:
		_awaiting_confirm = false
		EventBus.build_pending_changed.emit(false)
	_pending_plain = false
	_held_cell = NO_CELL
	_paint_targets.clear()
	_paint_surface = ""
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
			# Cimientos: en la planta baja o en un sótano (ya excavado).
			for c in HouseGrid.cells_in_rect(_start_cell, cell):
				_add_if_new(writes, mini(level, 0), "foundation", HouseGrid.cell_key(c), {"item": item["id"]})
		Tool.EXCAVATE:
			for c in HouseGrid.cells_in_rect(_start_cell, cell):
				_add_if_new(writes, level, "excavation", HouseGrid.cell_key(c), {"item": item["id"]})
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
					wall.erase("join_end")
					writes.append(HouseData.write(level, "walls", edge, wall))
					writes.append_array(_auto_join(edge, wall))
		Tool.OBJECT:
			writes.append_array(_object_place_writes(_cell_at(screen_pos, false)))
	return writes


## Las escrituras para poner el objeto elegido con su centro en `cell`.
func _object_place_writes(cell: Vector2i) -> Array:
	var anchor := _centered_anchor(cell, place_rotation)
	var value := {"item": item["id"], "cell": [anchor.x, anchor.y], "rot": place_rotation}
	if place_diag:
		value["diag"] = true
	return _object_writes(NEW_KEY, value)


## Ventanas iguales seguidas se unen solas al ponerlas (como antes): la unión
## se guarda en la juntura (join_end de la pared que termina ahí). La
## primera escritura (`wall`) ya está en la lista; esto agrega el resto.
func _auto_join(edge: String, wall: Dictionary) -> Array:
	var extra: Array = []
	if Catalog.get_item(wall["opening"]).get("kind", "") != "window":
		_unjoin_previous_into(extra, edge)
		return extra
	var previous := HouseGrid.previous_in_line(edge)
	var prev: Variant = house.get_piece(level, "walls", previous)
	var start := HouseGrid.edge_vertex(edge)
	if prev != null and prev.get("opening", "") == wall["opening"] and _only_two_at(start, previous, edge):
		var copy: Dictionary = prev.duplicate(true)
		copy["join_end"] = true
		extra.append(HouseData.write(level, "walls", previous, copy))
	else:
		_unjoin_previous_into(extra, edge)
	var next := HouseGrid.next_in_line(edge)
	var nxt: Variant = house.get_piece(level, "walls", next)
	if nxt != null and nxt.get("opening", "") == wall["opening"] and _only_two_at(HouseGrid.edge_vertices(edge)[1], edge, next):
		wall["join_end"] = true
	return extra


func _unjoin_previous_into(writes: Array, edge: String) -> void:
	writes.append_array(_unjoin_previous(level, edge))


## ¿En ese vértice se juntan solo esas dos paredes?
func _only_two_at(vertex: Vector2i, a: String, b: String) -> bool:
	for edge in HouseGrid.vertex_edges(vertex):
		if edge != a and edge != b and house.has_piece(level, "walls", edge):
			return false
	return true


## Pone una pieza solo si no está ya igual (no repite trabajo).
func _add_if_new(writes: Array, lvl: int, layer: String, key: String, value: Dictionary) -> void:
	var current: Variant = house.get_piece(lvl, layer, key)
	if current == null or current["item"] != value["item"]:
		writes.append(HouseData.write(lvl, layer, key, value))


## Pone una pared. Si ya había otra de distinto tipo, conserva su puerta,
## ventana, unión y pintura.
func _add_wall(writes: Array, edge: String, wall_item: String) -> void:
	var current: Variant = house.get_piece(level, "walls", edge)
	if current != null and current["item"] == wall_item:
		return
	var value := {"item": wall_item}
	if current != null:
		for field in ["opening", "join_end", "color_a", "color_b"]:
			if current.has(field):
				value[field] = current[field]
	writes.append(HouseData.write(level, "walls", edge, value))


func _add_removal(writes: Array, lvl: int, layer: String, key: String) -> void:
	if house.has_piece(lvl, layer, key):
		writes.append(HouseData.write(lvl, layer, key, null))


## Escrituras para poner o mover un objeto. Una escalera además abre el
## hueco en el piso de arriba (quita esas baldosas).
func _object_writes(key: String, value: Dictionary) -> Array:
	var writes: Array = [HouseData.write(level, "objects", key, value)]
	if Catalog.get_item(value["item"]).get("kind", "") == "stairs":
		for c in HouseData.value_cells(value):
			_add_removal(writes, level + 1, "floors", HouseGrid.cell_key(c))
	return writes


## Celda de anclaje para que el objeto quede centrado bajo el dedo.
func _centered_anchor(cell: Vector2i, rot: int) -> Vector2i:
	var size := HouseGrid.rotated_size(HouseData.item_footprint(item), rot)
	return cell - (size - Vector2i.ONE) / 2


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

	if tool in ALL_OR_NOTHING and not blocked.is_empty():
		return {"ok": [], "blocked": writes}
	return {"ok": ok, "blocked": blocked}


## Mover (flechas): todo o nada, quitando lo viejo antes de poner lo nuevo.
func _check_move(writes: Array) -> Dictionary:
	var sim := house.duplicate_data()
	for w in writes:
		if w["value"] == null:
			var removal := HouseRules.check_removal(sim, [w])
			if not removal["blocked"].is_empty():
				return {"ok": [], "blocked": writes}
		elif not HouseRules.is_supported(sim, w["level"], w["layer"], w["key"], w["value"]):
			return {"ok": [], "blocked": writes}
		sim.apply([w])
	return {"ok": writes, "blocked": []}


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
	# Al quitar algo (o en Borrar), se muestra en rojo lo que se va.
	var removing: bool = value == null or tool == Tool.ERASE or _erase_items.size() > 0
	if value == null:
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


## Marca amarilla debajo de lo elegido (mueble, techo o pared), o de la cara
## pintada con las flechas.
func _update_selection_marker() -> void:
	_selection_marker.visible = false
	if house == null:
		return
	var y := HouseGrid.level_y(level) + 0.06
	if selected_key != "":
		var value: Variant = house.get_piece(level, selected_layer, selected_key)
		if value == null:
			return
		match selected_layer:
			"objects":
				var cells := HouseData.value_cells(value)
				var lo := cells[0]
				var hi := cells[0]
				for c in cells:
					lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
					hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
				var size := hi - lo + Vector2i.ONE
				_selection_marker.position = Vector3(lo.x + size.x / 2.0, y, lo.y + size.y / 2.0)
				_selection_marker.scale = Vector3(size.x + 0.15, 1, size.y + 0.15)
			"roofs":
				var rect := HouseData.roof_rect(value)
				_selection_marker.position = Vector3(rect.position.x + rect.size.x / 2.0, y, rect.position.y + rect.size.y / 2.0)
				_selection_marker.scale = Vector3(rect.size.x + 0.3, 1, rect.size.y + 0.3)
			"walls":
				var center := HouseGrid.edge_center(selected_key)
				_selection_marker.position = center + Vector3(0, y, 0)
				_selection_marker.scale = Vector3(1.1, 1, 0.4) if HouseGrid.is_edge_horizontal(selected_key) else Vector3(0.4, 1, 1.1)
		_selection_marker.visible = true
	elif not _paint_face.is_empty() and tool == Tool.PAINT:
		var center := WallFaces.face_center(_paint_face["edge"], _paint_face["side"])
		_selection_marker.position = center + Vector3(0, y, 0)
		_selection_marker.scale = Vector3(0.9, 1, 0.25) if HouseGrid.is_edge_horizontal(_paint_face["edge"]) else Vector3(0.25, 1, 0.9)
		_selection_marker.visible = true


## Pulido 4A: celda de cuarto cerrado bajo el dedo (NO_CELL si no hay).
func room_cell_at(screen_pos: Vector2) -> Vector2i:
	var point: Variant = _point_on_level(screen_pos)
	if point == null:
		return NO_CELL
	var cell := Vector2i(floori(point.x), floori(point.z))
	return cell if not HouseRooms.room_at(house, level, cell).is_empty() else NO_CELL


## Pulido 4A: con la herramienta «Cuartos» cada cuarto del piso se resalta con un color
## chato (el principal, más claro). Se esconde con cualquier otra herramienta.
func refresh_room_overlay() -> void:
	if _room_overlay == null:
		return
	for child in _room_overlay.get_children():
		child.queue_free()
	_room_overlay.visible = tool == Tool.ROOMS and house != null
	if not _room_overlay.visible:
		return
	var n := 0
	for room in HouseRooms.detect(house, level):
		var hue := fmod(0.08 + 0.17 * n, 1.0)
		var color := Color.from_hsv(hue, 0.55, 1.0, 0.5 if room.get("main", false) else 0.38)
		n += 1
		for key in room["cells"]:
			var cell := HouseGrid.key_to_cell(key)
			var mesh := PlaneMesh.new()
			mesh.size = Vector2(0.94, 0.94)
			var tile := _make_flat_marker("RoomTile", mesh, color)
			tile.visible = true
			tile.position = Vector3(cell.x + 0.5, HouseGrid.level_y(level) + 0.05, cell.y + 0.5)
			remove_child(tile)  # _make_flat_marker lo cuelga de acá; va dentro del resalte.
			_room_overlay.add_child(tile)


func _on_piece_changed(changed_level: int, layer: String, key: String) -> void:
	if layer == "walls":
		_joints_dirty = true
	if tool == Tool.ROOMS and layer in ["walls", "floors", "objects"]:
		refresh_room_overlay()
	# Si lo elegido se movió o desapareció (por ejemplo, al deshacer).
	if layer == selected_layer and changed_level == level and key == selected_key:
		if house.has_piece(level, layer, key):
			_update_selection_marker()
		else:
			select_object("")


## Una onda que avisa que ahora se pinta (o se elige) arrastrando.
func _ripple(screen_pos: Vector2) -> void:
	var point: Variant = _point_on_level(screen_pos)
	if point == null:
		return
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.42
	torus.outer_radius = 0.5
	ring.mesh = torus
	ring.material_override = HousePieces.transparent_material(Color(1, 1, 1, 0.8))
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = point + Vector3(0, 0.1, 0)
	add_child(ring)
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector3.ONE * 3.0, 0.45)
	tween.tween_callback(ring.queue_free)


# --- Junturas de ventanas (Modificar) ---

## Pone un puntito en cada juntura entre dos ventanas en línea del piso
## actual (naranja = unidas, blanco = separadas). Solo en Modificar.
func _update_joints() -> void:
	for child in _joints.get_children():
		_joints.remove_child(child)
		child.queue_free()
	_joint_vertices.clear()
	if not active or tool != Tool.MODIFY or house == null:
		return
	var seen := {}
	var sphere := SphereMesh.new()
	sphere.radius = 0.13
	sphere.height = 0.26
	for key in house.get_layer(level, "walls"):
		var vertex := HouseGrid.edge_vertices(key)[1]
		if seen.has(vertex):
			continue
		seen[vertex] = true
		var pair := HouseView.joint_walls(house, level, vertex)
		if pair.is_empty():
			continue
		var joined := not HouseView.joint_window(house, level, vertex).is_empty()
		var dot := MeshInstance3D.new()
		dot.mesh = sphere
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1, 0.6, 0.15) if joined else Color(1, 1, 1)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.no_depth_test = true
		mat.render_priority = 10
		dot.material_override = mat
		var height := minf(1.45, view.wall_height(level) - 0.1)
		dot.position = Vector3(vertex.x, HouseGrid.level_y(level) + height, vertex.y)
		_joints.add_child(dot)
		_joint_vertices.append(vertex)


## Juntura bajo la pantalla (o (-1, -1)).
func _joint_at(screen_pos: Vector2) -> Vector2i:
	var cam := get_viewport().get_camera_3d()
	var children := _joints.get_children()
	var best := Vector2i(-1, -1)
	var best_dist := JOINT_PICK_PIXELS
	for i in mini(children.size(), _joint_vertices.size()):
		var dist := cam.unproject_position(children[i].global_position).distance_to(screen_pos)
		if dist < best_dist:
			best_dist = dist
			best = _joint_vertices[i]
	return best


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
	return Plane(Vector3.UP, pick_height()).intersects_ray(ray[0], ray[1])


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
	var shown := tool in HANDLE_TOOLS and (_pressing or _awaiting_confirm) and not _pending_plain
	var y := pick_height() + 0.12
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
	var hit := _wall_hit(screen_pos)
	if not hit.is_empty() or not use_nearby:
		return hit.get("edge", "")
	var point: Variant = _point_on_level(screen_pos)
	if point == null:
		return ""
	var cell := Vector2i(floori(point.x), floori(point.z))
	var best_key := ""
	var best_dist := 0.4  # Distancia máxima para "agarrar" una pared.
	for edge in HouseGrid.cell_edges(cell):
		var c := HouseGrid.edge_center(edge)
		var dist := absf(point.z - c.z) if HouseGrid.is_edge_horizontal(edge) else absf(point.x - c.x)
		if house.has_piece(level, "walls", edge) and dist < best_dist:
			best_dist = dist
			best_key = edge
	return best_key


## La pared que choca con el rayo y dónde: {edge, point} o {}.
func _wall_hit(screen_pos: Vector2) -> Dictionary:
	var ray := _ray(screen_pos)
	var result := {}
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
			result = {"edge": key, "point": hit}
	return result


## La cara de pared bajo la pantalla: {edge, side} o {}. Es la cara del lado
## desde donde se la mira (la que choca primero con el rayo).
func _pick_wall_face(screen_pos: Vector2) -> Dictionary:
	var hit := _wall_hit(screen_pos)
	if hit.is_empty():
		return {}
	var edge: String = hit["edge"]
	var center := HouseGrid.edge_center(edge)
	var point: Vector3 = hit["point"]
	var side: String
	if HouseGrid.is_edge_horizontal(edge):
		side = "a" if point.z < center.z else "b"
	else:
		side = "a" if point.x < center.x else "b"
	return {"edge": edge, "side": side}


## Piso del nivel actual bajo la pantalla ("" si no hay).
func _pick_floor(screen_pos: Vector2) -> String:
	var point: Variant = _point_on_level(screen_pos)
	if point == null:
		return ""
	var key := HouseGrid.cell_key(Vector2i(floori(point.x), floori(point.z)))
	return key if house.has_piece(level, "floors", key) else ""


## Mueble bajo la pantalla ("" si no hay).
func _pick_object(screen_pos: Vector2) -> String:
	var ray := _ray(screen_pos)
	return view.pick_object(ray[0], ray[1], level)


## Lo que hay bajo el dedo, de arriba hacia abajo: techo (si se ven),
## mueble, pared, piso y cimientos. {level, layer, key, side?} o {}.
func _pick_any(screen_pos: Vector2) -> Dictionary:
	var ray := _ray(screen_pos)
	# Techos del piso actual y del de abajo (los de abajo se ven desde acá).
	for roof_level in [level, level - 1]:
		if roof_level < 0:
			continue
		var roof := view.pick_roof(ray[0], ray[1], roof_level)
		if roof != "":
			return {"level": roof_level, "layer": "roofs", "key": roof}
	var object_key := _pick_object(screen_pos)
	if object_key != "":
		return {"level": level, "layer": "objects", "key": object_key}
	var face := _pick_wall_face(screen_pos)
	if not face.is_empty():
		return {"level": level, "layer": "walls", "key": face["edge"], "side": face["side"]}
	var floor_key := _pick_floor(screen_pos)
	if floor_key != "":
		return {"level": level, "layer": "floors", "key": floor_key}
	if level == 0:
		var point: Variant = _point_on_level(screen_pos)
		if point != null:
			var key := HouseGrid.cell_key(Vector2i(floori(point.x), floori(point.z)))
			if house.has_piece(0, "foundation", key):
				return {"level": 0, "layer": "foundation", "key": key}
	return {}


## Con un dedo: ¿la cámara se mueve o el dedo construye?
func _update_camera_pan() -> void:
	if camera == null:
		return
	camera.single_finger_pan = _camera_takeover or not active or tool == Tool.NONE \
		or (tool in PRESS_TOOLS and not _long_pressed and _drag_handle < 0)


## Explica por qué algo salió en rojo, según la herramienta y el piso.
func _blocked_hint() -> String:
	# Pulido 2C: si lo rojo está sobre un obstáculo, se dice.
	for w in _pending_blocked:
		var cells: Array = []
		match w["layer"]:
			"foundation", "floors":
				cells = [HouseGrid.key_to_cell(w["key"])]
			"objects":
				if w["value"] != null:
					cells = HouseData.value_cells(w["value"])
			"roofs":
				if w["value"] != null:
					var rect := HouseData.roof_rect(w["value"])
					for x in range(rect.position.x, rect.end.x):
						for z in range(rect.position.y, rect.end.y):
							cells.append(Vector2i(x, z))
		for c in cells:
			if HouseRules.is_blocked(c):
				return "Ahí hay un obstáculo (árbol, roca, laguito...): tocalo y llamá al servicio para limpiarlo."
	var upstairs := level > 0
	match tool:
		Tool.EXCAVATE:
			return "Solo se excava en un sótano (Agregar sótano), de arriba hacia abajo, y no donde hay obstáculos."
		Tool.FOUNDATION:
			if level < 0:
				return "En un sótano, los cimientos van sobre un lugar ya excavado."
			return "Los cimientos van solo en la planta baja o en un sótano."
		Tool.FLOOR:
			if upstairs:
				return "Arriba, el piso necesita piso, una pared o un pilar cerca debajo (y no encima de un techo)."
			return "En la planta baja, el piso va sobre cimientos."
		Tool.WALL, Tool.ROOM:
			if upstairs:
				return "Arriba, las paredes van sobre piso o sobre otra pared (y no atravesando un techo)."
			return "En la planta baja, las paredes van junto a cimientos."
		Tool.OPENING:
			return "Las puertas y ventanas van sobre una pared."
		Tool.ROOF:
			var rect := Rect2i(Vector2i(mini(_start_cell.x, _end_cell.x), mini(_start_cell.y, _end_cell.y)),
				(_end_cell - _start_cell).abs() + Vector2i.ONE)
			var reason := HouseRules.roof_blocker(house, level, rect)
			return reason if reason != "" else "El techo tiene que quedar dentro del lote."
		Tool.OBJECT, Tool.MODIFY:
			if item.get("kind", "") == "stairs":
				return "La escalera va sobre piso, sin paredes en el medio y no en el último piso."
			return "No entra: necesita piso libre y sin paredes en el medio."
		Tool.ERASE:
			return "Hay piezas que no se pueden borrar: tienen algo encima."
	return "No se puede ahí."


func _move_blocked_hint() -> String:
	match selected_layer:
		"walls":
			return "La pared no se puede correr ahí (o sostiene algo de arriba)."
		"roofs":
			return "El techo no se puede correr ahí."
	return "No entra ahí."


func _show_tool_hint() -> void:
	if tool == Tool.OBJECT or tool == Tool.OPENING:
		EventBus.build_hint.emit("%s: %s" % [item.get("name", ""), HINTS[tool]])
	elif tool == Tool.ERASE and erase_multi:
		EventBus.build_hint.emit("Modo selección: tocá todo lo que querés borrar y después «Borrar».")
	else:
		EventBus.build_hint.emit(HINTS[tool])


func _first_paint_id() -> String:
	for paint in Catalog.get_items_in_category("paint"):
		return paint["id"]
	return ""


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

	# Marca debajo de lo elegido.
	var marker := PlaneMesh.new()
	marker.size = Vector2.ONE
	_selection_marker = _make_flat_marker("SelectionMarker", marker, Color(1, 0.85, 0.2, 0.6))

	_room_overlay = Node3D.new()
	_room_overlay.name = "RoomOverlay"
	_room_overlay.visible = false
	add_child(_room_overlay)

	_ghost = Node3D.new()
	_ghost.name = "Ghost"
	add_child(_ghost)

	_joints = Node3D.new()
	_joints.name = "Joints"
	add_child(_joints)

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
