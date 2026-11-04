class_name SafeArea
## Área segura de la pantalla (Pulido 3B): muescas, esquinas redondeadas y
## barras del sistema del teléfono. La interfaz nunca se dibuja ahí.
##
## `DisplayServer.get_display_safe_area()` dice qué parte de la pantalla es
## segura (en píxeles reales). Acá se convierte a "unidades de la interfaz"
## (el juego escala la interfaz con stretch canvas_items/expand), que es lo que
## usan los márgenes de los controles.
##
## En la PC (ventana más chica que el monitor) no se aplica nada. Las pruebas
## pueden forzar un área con `override_rect` / `override_screen`.

## Solo para pruebas: un área segura inventada y el tamaño de pantalla donde
## "vive" (en píxeles reales). Rect2i() vacío = usar la del sistema.
static var override_rect := Rect2i()
static var override_screen := Vector2i.ZERO


## Márgenes (izquierda, arriba, derecha, abajo) en unidades de la interfaz que
## la pantalla pide dejar libres. `window` es la ventana del juego.
static func insets(window: Window) -> Vector4:
	var view: Vector2 = window.get_visible_rect().size
	var screen := override_screen
	var safe := override_rect
	if safe == Rect2i():
		if not (OS.has_feature("android") or OS.has_feature("ios")):
			return Vector4.ZERO
		safe = DisplayServer.get_display_safe_area()
		screen = DisplayServer.screen_get_size(window.current_screen)
	return from_rects(safe, screen, view)


## La cuenta pura (se prueba sin pantalla): `safe` y `screen` en píxeles reales,
## `view` = tamaño de la interfaz (viewport) en unidades de la interfaz.
static func from_rects(safe: Rect2i, screen: Vector2i, view: Vector2) -> Vector4:
	if screen.x <= 0 or screen.y <= 0 or safe.size.x <= 0 or safe.size.y <= 0:
		return Vector4.ZERO
	var sx := view.x / float(screen.x)
	var sy := view.y / float(screen.y)
	return Vector4(
		maxf(0.0, safe.position.x * sx),
		maxf(0.0, safe.position.y * sy),
		maxf(0.0, (screen.x - safe.end.x) * sx),
		maxf(0.0, (screen.y - safe.end.y) * sy))


## Margen final de cada borde: el normal de la interfaz, o el del área segura
## (más un respiro) si ese es mayor.
static func margins(base: Vector4, insets_now: Vector4, breath := 8.0) -> Vector4:
	return Vector4(
		maxf(base.x, insets_now.x + (breath if insets_now.x > 0.0 else 0.0)),
		maxf(base.y, insets_now.y + (breath if insets_now.y > 0.0 else 0.0)),
		maxf(base.z, insets_now.z + (breath if insets_now.z > 0.0 else 0.0)),
		maxf(base.w, insets_now.w + (breath if insets_now.w > 0.0 else 0.0)))
