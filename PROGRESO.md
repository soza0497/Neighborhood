# Progreso

## Fase actual: 1 — Constructor de casas (código listo; falta probar en el teléfono)

### Fase 0 — cerrada (2026-11-03)
Base del proyecto, cámara, guardado, exportación a Android. APK probado en el
teléfono del dueño.

### Fase 1 — hecho (2026-11-03)
Todo en un solo tramo (1A + 1B + 1C):
- Datos de la casa (`scripts/house/house_data.gd`): capas por nivel, cambios
  como escrituras con inversa. Deshacer/rehacer (`undo_history.gd`, 100 pasos).
- Reglas de apoyo (`house_rules.gd`) y medidas de la cuadrícula (`house_grid.gd`).
- Vista 3D (`house_view.gd` + `house_pieces.gd`): cimientos, pisos, paredes con
  esquinas automáticas, puertas, ventanas, escaleras, muebles con formas
  provisionales, techos a dos aguas. Vistas: completa / sin techo / paredes bajas.
- Constructor (`house_builder.gd`): cuadrícula con resaltado, vista previa
  verde/roja, herramientas cimientos, piso, pared, cuarto, techo, puerta/ventana,
  muebles (colocar, mover, girar, quitar, sin encimarse ni atravesar paredes),
  pintura, modo borrar, cambio de nivel.
- Interfaz (`ui/hud.*`): barra inferior con categorías del catálogo, Girar,
  Quitar, Borrar; arriba Deshacer, Rehacer, Vista, Centrar, Construir/Vivir;
  Subir/Bajar piso.
- Casa guardada en `user://save.json` (sección `house`), autoguardado al editar.
- Catálogo: 29 piezas en 4 categorías.
- Pruebas: `tests/test_house.tscn` (41 pruebas, todas pasan) y
  `tests/visual_demo.tscn` (arma una casa, capturas, mouse real: OK).
- APK de depuración exportado sin errores (versión 0.1.0).

### Falta para cerrar la Fase 1
1. [Dueño] Instalar el APK nuevo y probar con el dedo (checklist del chat).
2. [Dueño] Contar los FPS con una casa de dos pisos amueblada (meta: 30).
3. [Claude] Corregir lo que salga; si los FPS no llegan, juntar mallas
   (ver DECISIONES, "Rendimiento").

### Próximo paso exacto
Con el teléfono conectado: exportar con
`godot --headless --path . --export-debug "Android" build/neighborhood.apk`
e instalar con `~/Android/Sdk/platform-tools/adb install -r build/neighborhood.apk`.

### Preguntas abiertas para el dueño
- ¿Horizontal te parece bien? (ver DECISIONES.md, "Orientación").
- ¿Tu pareja usa Android o iPhone? (VISION.md)

## Fases siguientes
- Fase 2 — Personaje y su IA (conviene Sonnet).
