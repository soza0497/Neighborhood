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
