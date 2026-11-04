class_name TemplatePlacer
extends Node
## Colocar una plantilla de casa (Pulido 5E): se elige, se mueve sobre el lote y
## se ve una silueta tipo holograma (verde si cabe, roja si no). Al confirmar,
## las escrituras entran por el constructor (plan y factura, servidor incluido).
##
## Cómo se maneja: un dedo (o el mouse) mueve la silueta; dos dedos mueven la
## cámara como siempre. Botones «Colocar» y «Cancelar» (en la PC: Enter y Esc).
## No guarda nada ni toca dinero: solo mira (HouseTemplate.check) y le pasa
## las escrituras a HouseBuilder.place_template.

const COLOR_OK := Color(0.25, 1.0, 0.5, 0.42)
const COLOR_BAD := Color(1.0, 0.28, 0.25, 0.42)
const WALL_THICKNESS := 0.16

var active := false
var template: Dictionary = {}
## Esquina (celda) donde está la plantilla ahora.
var offset := Vector2i.ZERO
## Resultado de la última revisión (HouseTemplate.check).
var last_check: Dictionary = {}

var _builder: HouseBuilder
var _house: HouseData
var _view: Node3D
var _camera: CameraRig
var _hologram: MeshInstance3D
var _material: StandardMaterial3D
var _layer: CanvasLayer
var _panel: PanelContainer
var _label: Label
var _confirm_button: Button
var _touches: Dictionary = {}
var _busy := false


func setup(builder: HouseBuilder, house: HouseData, view: Node3D, camera: CameraRig) -> void:
	_builder = builder
	_house = house
	_view = view
	_camera = camera
	_build_ui()
	EventBus.template_place_requested.connect(request_place)
	EventBus.game_mode_changed.connect(func(mode: String) -> void:
		if mode != "build":
			cancel())


## Pedido de la interfaz: coloca la plantilla guardada con ese id.
func request_place(template_id: String) -> void:
	var found := HouseTemplates.find(template_id)
	if found.is_empty():
		EventBus.toast.emit("Esa plantilla ya no existe.")
		return
	if _builder != null and not _builder.active:
		EventBus.game_mode_change_requested.emit("build")
		if not _builder.active:
			return  # Main explicó por qué no se pudo (obras sin confirmar, sin conexión...).
	start(found)


## Empieza a colocar `new_template` (el centro de la cámara es el punto de partida).
func start(new_template: Dictionary) -> bool:
	if new_template.is_empty() or (new_template.get("pieces", []) as Array).is_empty():
		return false
	cancel()
	template = new_template
	_builder.select_item("")
	_make_hologram()
	active = true
	var focus := _view.to_local(_camera.global_position)
	move_to_cell(Vector2i(floori(focus.x), floori(focus.z)))
	_panel.visible = true
	_layer.visible = true
	_camera.single_finger_pan = false
	EventBus.build_hint.emit("Plantilla «%s»: arrastrá para moverla. Verde = cabe, rojo = no." % str(template.get("name", "")))
	return true


## Cancela sin construir nada.
func cancel() -> void:
	if not active:
		return
	active = false
	_touches.clear()
	if _hologram != null:
		_hologram.queue_free()
		_hologram = null
	_panel.visible = false
	_layer.visible = false
	if _builder != null:
		_builder.select_item("")  # Vuelve a calcular el paneo de la cámara.


## Pone la plantilla con su CENTRO en esa celda (se mantiene cerca del lote).
func move_to_cell(cell: Vector2i) -> void:
	var size := _template_size()
	var corner := cell - size / 2
	corner = corner.clamp(Vector2i(-size.x + 1, -size.y + 1), HouseGrid.LOT_SIZE - Vector2i.ONE)
	set_offset(corner)


func set_offset(new_offset: Vector2i) -> void:
	offset = new_offset
	if _hologram != null:
		_hologram.position = Vector3(offset.x, 0.0, offset.y)
	refresh()


## Vuelve a revisar si cabe (también después de cambios en la casa).
func refresh() -> void:
	if not active:
		return
	last_check = HouseTemplate.check(_house, template, offset)
	var valid: bool = last_check["valid"]
	_material.albedo_color = COLOR_OK if valid else COLOR_BAD
	if valid:
		_label.text = "«%s» cabe aquí · cuesta $%d" % [str(template.get("name", "")), int(last_check["cost"])]
	else:
		_label.text = HouseTemplate.reason_text(last_check["reason"])
	_confirm_button.disabled = not valid or _busy


## Confirma: la plantilla pasa al plan (o se construye). Devuelve true si salió bien.
func confirm() -> bool:
	if not active or _busy:
		return false
	refresh()
	if not last_check["valid"]:
		EventBus.build_hint.emit(HouseTemplate.reason_text(last_check["reason"]))
		return false
	_busy = true
	_confirm_button.disabled = true
	var ok: bool = await _builder.place_template(last_check["writes"])
	_busy = false
	if ok:
		cancel()  # La obra ya quedó en el plan: se cierra el modo de colocar.
	else:
		refresh()
	return ok


func _template_size() -> Vector2i:
	var size: Array = template.get("size", [1, 1])
	return Vector2i(maxi(1, int(size[0])), maxi(1, int(size[1])))


func _process(_delta: float) -> void:
	if active and _camera != null:
		_camera.single_finger_pan = false  # Un dedo mueve la silueta, no la cámara.


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
			if _touches.size() == 1:
				_move_to_screen(event.position)
		else:
			_touches.erase(event.index)
	elif event is InputEventScreenDrag:
		if _touches.has(event.index) and _touches.size() == 1:
			_move_to_screen(event.position)
		_touches[event.index] = event.position
	elif event is InputEventMouseButton or event is InputEventMouseMotion:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return  # Los «clics» que Godot fabrica a partir de toques ya se manejaron.
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				_move_to_screen(event.position)
		else:
			_move_to_screen(event.position)
	elif event.is_action_pressed("ui_accept"):
		confirm()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		cancel()
		get_viewport().set_input_as_handled()


func _move_to_screen(screen_pos: Vector2) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var origin := _view.to_local(cam.project_ray_origin(screen_pos))
	var direction := _view.global_transform.basis.inverse() * cam.project_ray_normal(screen_pos)
	var point: Variant = Plane(Vector3.UP, HouseGrid.level_y(0)).intersects_ray(origin, direction)
	if point == null:
		return
	var cell := Vector2i(floori(point.x), floori(point.z))
	if cell != offset + _template_size() / 2:
		move_to_cell(cell)


# --- La silueta ---

func _make_hologram() -> void:
	if _hologram != null:
		_hologram.queue_free()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for piece in template.get("pieces", []):
		_add_piece(st, int(piece["l"]), piece["y"], str(piece["k"]), piece["v"])
	_hologram = MeshInstance3D.new()
	_hologram.name = "TemplateHologram"
	_hologram.mesh = st.commit()
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.albedo_color = COLOR_OK
	_hologram.material_override = _material
	_hologram.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_view.add_child(_hologram)


## Cada pieza es una cajita simple (la silueta no necesita más).
func _add_piece(st: SurfaceTool, level: int, layer: String, key: String, value: Dictionary) -> void:
	var y := HouseGrid.level_y(level)
	match layer:
		"foundation":
			var c := HouseGrid.key_to_cell(key)
			_box(st, Vector3(c.x, y - HouseGrid.FOUNDATION_HEIGHT, c.y), Vector3(c.x + 1, y, c.y + 1))
		"floors":
			var f := HouseGrid.key_to_cell(key)
			_box(st, Vector3(f.x, y - 0.08, f.y), Vector3(f.x + 1, y, f.y + 1))
		"walls":
			var v := HouseGrid.edge_vertex(key)
			var half := WALL_THICKNESS / 2.0
			if HouseGrid.is_edge_horizontal(key):
				_box(st, Vector3(v.x, y, v.y - half), Vector3(v.x + 1, y + HouseGrid.WALL_HEIGHT, v.y + half))
			else:
				_box(st, Vector3(v.x - half, y, v.y), Vector3(v.x + half, y + HouseGrid.WALL_HEIGHT, v.y + 1))
		"objects":
			var box := HouseTemplate.piece_box("objects", key, value)
			var inset := 0.3 if Catalog.get_item(value.get("item", "")).get("kind", "") == "pillar" else 0.05
			_box(st, Vector3(box.position.x + inset, y, box.position.y + inset),
				Vector3(box.end.x - inset, y + HouseGrid.WALL_HEIGHT, box.end.y - inset))
		"roofs":
			var r := HouseData.roof_rect(value)
			var top := y + HouseGrid.WALL_HEIGHT
			_box(st, Vector3(r.position.x, top, r.position.y), Vector3(r.end.x, top + 0.2, r.end.y))


static func _box(st: SurfaceTool, lo: Vector3, hi: Vector3) -> void:
	var p := [
		Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, lo.y, hi.z), Vector3(lo.x, lo.y, hi.z),
		Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z),
	]
	for face in [[0, 1, 2, 3], [4, 7, 6, 5], [0, 4, 5, 1], [1, 5, 6, 2], [2, 6, 7, 3], [3, 7, 4, 0]]:
		for i in [0, 1, 2, 0, 2, 3]:
			st.add_vertex(p[face[i]])


# --- La barra de arriba ---

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 3
	_layer.visible = false
	add_child(_layer)
	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.offset_top = 96.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.17, 0.25, 1.0)
	style.set_corner_radius_all(18)
	style.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", style)
	_layer.add_child(_panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	_panel.add_child(rows)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 18)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.custom_minimum_size = Vector2(420, 0)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(_label)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	rows.add_child(buttons)
	_confirm_button = Button.new()
	_confirm_button.text = "Colocar"
	_confirm_button.custom_minimum_size = Vector2(170, 56)
	_confirm_button.add_theme_font_size_override("font_size", 19)
	_confirm_button.pressed.connect(confirm)
	buttons.add_child(_confirm_button)
	var cancel_button := Button.new()
	cancel_button.text = "Cancelar"
	cancel_button.custom_minimum_size = Vector2(170, 56)
	cancel_button.add_theme_font_size_override("font_size", 19)
	cancel_button.pressed.connect(cancel)
	buttons.add_child(cancel_button)
