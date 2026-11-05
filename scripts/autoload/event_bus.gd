extends Node
## Tablero de anuncios global.
##
## Los sistemas del juego no se llaman directamente entre sí: uno "anuncia"
## algo aquí (emite una señal) y quien esté interesado lo escucha.
## Ejemplo: EventBus.game_saved.connect(_on_game_saved)
##
## Cada fase agregará sus propias señales. Mantenelas agrupadas por tema.

# Godot avisa de señales "sin usar" porque se emiten desde otros archivos.
@warning_ignore_start("unused_signal")

# --- Guardado ---
## Se emite justo antes de escribir el archivo: cada sistema debe copiar su
## estado actual dentro de GameState en este momento.
signal game_saving
## Resultado de un guardado (true = salió bien).
signal game_saved(success: bool)
## Se emite después de cargar la partida en GameState.
signal game_loaded

# --- Catálogo ---
## El catálogo terminó de leer sus archivos de datos.
signal catalog_loaded(item_count: int)

# --- Cámara ---
## Alguien (por ejemplo, un botón de la interfaz) pide centrar la cámara.
signal camera_reset_requested
## Pulido 1: la brújula pide centrar la cámara en el personaje (y su piso).
signal camera_focus_character_requested

# --- Modos de juego ---
## La interfaz pide cambiar de modo: "build" (construir) o "live" (vivir).
signal game_mode_change_requested(mode: String)
## El modo cambió.
signal game_mode_changed(mode: String)

# --- Constructor (la interfaz pide → la escena principal hace) ---
## Se eligió una pieza del catálogo ("" = ninguna, "move" = la mano).
signal build_item_selected(item_id: String)
signal build_erase_toggled(enabled: bool)
signal build_rotate_requested
signal build_delete_requested
## Subir (+1) o bajar (-1) de piso.
signal build_level_change_requested(delta: int)
## Pasar a la siguiente vista de paredes (completa → sin techo → bajas).
signal view_mode_cycle_requested
## Pulido 1: ir a un piso (la maqueta de pisos), y los íconos de la vista.
signal build_level_set_requested(level: int)
signal view_roofs_toggle_requested
signal view_walls_toggle_requested
signal build_confirm_requested
signal build_cancel_requested
signal undo_requested
signal redo_requested

# --- Constructor (avisos para la interfaz) ---
## Texto de ayuda para mostrar arriba.
signal build_hint(text: String)
signal build_level_changed(level: int)
## Hay (o no) una selección esperando Confirmar.
signal build_pending_changed(has_pending: bool)
## Hay (o no) un mueble elegido con la mano.
signal build_selection_changed(has_selection: bool)
## Cambió la vista de paredes (ver HouseView.ViewMode).
signal view_mode_changed(mode: int)
## Lo mismo, como los dos íconos: techos visibles y paredes bajas.
signal view_changed(show_roofs: bool, low_walls: bool)
## Para habilitar los botones de deshacer y rehacer.
signal history_changed(can_undo: bool, can_redo: bool)

# --- Constructor 2.0 (Pulido 1) ---
## La interfaz pide: correr lo elegido (N, S, E, O), seguir pintando la pared
## de al lado (-1 izquierda, +1 derecha), elegir una opción del menú de una
## pieza, borrar varias cosas a la vez, y copiar el contorno de abajo.
signal build_nudge_requested(direction: String)
signal build_paint_step_requested(direction: int)
## Pulido 6A (1): qué cara pinta el toque: "touch", "inside" u "outside".
signal build_paint_scope_requested(scope: String)
signal build_context_action_requested(action: String)
signal build_erase_multi_toggled(enabled: bool)
signal build_copy_outline_requested
## El constructor avisa: mostrar u ocultar las flechas de la pintura.
signal build_paint_arrows(visible: bool)
## Texto del botón Confirmar (por ejemplo "Borrar · te devuelven $45").
signal build_confirm_label(text: String)
## Menú de una pieza (Modificar): título y opciones [{id, text}].
signal build_context_menu(title: String, options: Array)
## Lo que falta o está mal en la casa (HouseRules.problems).
signal house_problems_changed(problems: Array)
## Propuesta en la casa compartida: mode = "own" (la armo yo), "review" (veo
## la de mi pareja) o "" (ninguna); summary = {steps, pieces, cost}.
signal proposal_changed(mode: String, summary: Dictionary)
## Pulido 2: se agregó un piso (o cambió cuántos hay) y pedidos del plan.
signal floors_changed(total: int)
signal build_add_basement_requested
signal build_add_floor_requested
signal plan_confirm_requested
signal plan_discard_requested
## Pulido 2C: parcela, servicios y cajas.
signal parcel_changed
signal parcel_obstacle_tapped(id: String)
signal boxes_changed(dropped: int)
signal boxes_open_all_requested
signal box_tapped(level: int, key: String)
signal ambulance_requested(patient: Node3D)
## Pulido 2: el ángulo vertical de la cámara cambió (grados hacia abajo).
signal camera_pitch_requested(degrees: float)
## Pulido 3B: abrir el menú de tipo de un cuarto (el que tiene esa celda en ese nivel).
signal room_menu_requested(level: int, cell: Vector2i)
## Pulido 3B: cambió el tipo de algún cuarto (la Tienda actualiza «Recomendado»).
signal rooms_changed
## Pulido 3B: la barra del ángulo pide subir (+) o bajar (-) el ángulo esos grados.
signal camera_pitch_step_requested(degrees: float)
## La interfaz pide mandar o descartar mi propuesta, ver la de mi pareja (id
## del pedido) y responderla (aprobar o no) o cerrarla.
signal proposal_send_requested
signal proposal_discard_requested
signal proposal_review_requested(request_id: int)
signal proposal_answer_requested(approve: bool)
signal proposal_close_requested

# --- Personaje ---
## Cada medio segundo: necesidades (nombre → 0..100) y ánimo en palabras.
signal character_needs_changed(needs: Dictionary, mood_text: String)
## Cambió lo que hace el personaje (ver Character.get_intention).
signal character_intention_changed(intention: Dictionary)
## En modo vivir se tocó un mueble que ofrece acciones.
signal object_menu_requested(level: int, key: String, item_id: String)
## El jugador eligió una acción del menú de un mueble.
signal character_order_requested(level: int, key: String, action_id: String)
## La interfaz pide abrir el editor de personaje.
signal character_editor_requested
## Se abre el editor con los datos actuales (ver CharacterData.to_dict).
signal character_editor_opened(data: Dictionary)
## El editor terminó: nombre, apariencia y rasgos nuevos.
signal character_edit_finished(data: Dictionary)
## La interfaz pide abrir el diario.
signal journal_requested
## Se abre el diario: nombre, emoción actual y entradas (ver CharacterData.journal).
signal journal_opened(character_name: String, emotion: String, entries: Array)

# --- Economía y progreso ---
## Cambió el dinero, el nivel o la experiencia.
signal economy_changed(money: int, level: int, xp_in_level: int, xp_needed: int)
## Se subió de nivel; `unlocked_names` = piezas que se desbloquean.
signal level_up(level: int, unlocked_names: Array)
## Aviso corto para mostrar en pantalla (se apaga solo).
signal toast(text: String)
## Lo que cuesta la selección que espera Confirmar (negativo = se devuelve dinero).
signal build_cost_changed(cost: int)
## Fase 5: la selección que espera Confirmar necesita la aprobación de la
## pareja (casa compartida, cambio estructural).
signal build_approval_changed(needs_approval: bool)
## Obras en marcha: cuántas hay y cuánto cuesta acelerarlas todas.
signal construction_changed(count: int, accelerate_cost: int)
## El jugador pidió acelerar todas las obras.
signal construction_accelerate_requested
## La interfaz pide abrir el panel de empleos.
signal jobs_requested
## Cambió el empleo o el currículum (para refrescar el panel de empleos).
signal jobs_changed

# --- Servidor (Fase 4) ---
## Cambió la conexión con el servidor. `username` = cuenta con la que se
## entró ("" si no hay sesión).
signal server_status_changed(online: bool, username: String)
## La interfaz pide cerrar la sesión de la cuenta.
signal logout_requested
## Se está esperando (o se dejó de esperar) una respuesta del servidor
## (Fase 4B): mientras tanto, los botones que cambian dinero no responden.
signal server_busy_changed(busy: bool)

# --- Pareja y casa compartida (Fase 5) ---
## Cambió la caja de la casa común (`shared` = viven juntos).
signal fund_changed(shared: bool, fund: int)
## Cambió la relación, la pareja o el hogar (leer Couple.couple / .home).
signal couple_changed
## La pareja se conectó o desconectó, o cambió lo que hace su personaje
## (`intention` como Character.get_intention; {} si no se sabe).
signal partner_presence_changed(online: bool, intention: Dictionary)
## La pareja cambió algo del hogar (aviso del servidor): {rev, entry_id,
## kind, text, by_name, can_revert}. La escena principal se pone al día.
signal home_remote_changed(notice: Dictionary)
## Hay que volver a cargar la casa entera (se mudaron juntos o se separaron).
signal home_reload_requested
## La interfaz pide abrir el panel de la pareja o el de la casa.
signal couple_panel_requested
signal home_panel_requested
## Pulido 5E: cambió la lista de plantillas de casa (guardar, renombrar o borrar).
signal templates_changed
## Pulido 5E: el jugador eligió una plantilla para colocar (id).
signal template_place_requested(template_id: String)
## Aviso con botón "Deshacer" (un cambio menor de la pareja): texto y la
## entrada del historial que se puede deshacer (0 = sin botón).
signal partner_notice(text: String, entry_id: int)


# --- Restaurante (Fase 6) ---
## La interfaz pide abrir el panel del restaurante.
signal restaurant_panel_requested
## Cambió el estado del restaurante (leer Restaurant.summary).
signal restaurant_changed
## Empieza el minijuego "Servicio": {seed, seats, practice}.
signal restaurant_service_requested(info: Dictionary)
## Terminó un servicio: el resultado (lo que contó el servidor, o la práctica).
signal restaurant_service_finished(result: Dictionary)

## Fase 7: se prendió o apagó «Usar modelos» (Info). Hay que rearmar casa y personaje.
signal models_toggled(enabled: bool)


# --- Barrio (Fase 8) ---
## La interfaz pide abrir el panel «Barrio» (menú hamburguesa).
signal neighborhood_panel_requested
## Visitar la casa de un lote del barrio (solo ver), ir a la vista aérea o volver.
signal neighborhood_visit_requested(lot_id: String)
signal neighborhood_aerial_requested
signal neighborhood_return_requested
## El estado de la vista del barrio cambió: "" (en mi casa), "aerial" o "visit".
signal neighborhood_state_changed(state: String, lot_id: String)
## Fase 8D: cambió la meta del barrio (leer NeighborhoodGoal.summary).
signal neighborhood_goal_changed
## Fase 8C: ganchos de sonido por evento. `event` es un nombre fijo (ver
## data/neighborhood.json, "sounds"); todavía no hay archivos de audio.
signal neighborhood_sound(event: String, position: Vector3)


# --- Modo desarrollador (Pulido 4B) ---
## Se prendió o apagó el modo desarrollador (Info). Solo cambia lo que se ve; no se manda al servidor.
signal dev_mode_changed(enabled: bool)
## Cambiaron las celdas peligrosas (HazardMap).
signal hazards_changed
## Al personaje le pasó un accidente: tipo (fall, trip, burn), nivel, celda y el motivo
## ("forzado por el modo desarrollador", "pisó un charco"…).
signal character_accident(kind: String, level: int, cell: Vector2i, reason: String)
## Una línea para el registro corto del modo desarrollador (qué decidió el personaje y por qué).
signal dev_log(text: String)
