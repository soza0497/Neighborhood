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
## Para habilitar los botones de deshacer y rehacer.
signal history_changed(can_undo: bool, can_redo: bool)

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
