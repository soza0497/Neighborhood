# Progreso

## Fase actual: 2 — Personaje y su IA (código listo; falta probar en el teléfono)

La Fase 1 tiene ajustes sin probar en el teléfono (ver abajo): probar las
dos fases juntas.

### Fase 2 — hecho (2026-11-03)
- Datos: `data/actions.json` (10 acciones), `data/traits.json` (6 rasgos),
  `data/character_options.json` (colores). Muebles con `actions` en el
  catálogo; nuevos: Televisor, Computadora, Librero.
- Reloj `GameClock` (autoload): x1/x3/x10, pausa en Construir.
- `scripts/character/`: `character_data.gd` (necesidades con mínimo),
  `character_brain.gd` (IA de prioridades), `character.gd` (estados, caminar,
  usar objetos, burbujas, intención), `character_look.gd` (chibi de
  cápsulas), `character_animator.gd` (ganchos de animación),
  `live_controller.gd` (tocar muebles en modo Vivir).
- `scripts/house/house_nav.gd`: caminos con paredes, puertas y escaleras;
  se rehace solo al construir.
- Interfaz: panel con necesidades, ánimo e intención; reloj y velocidad;
  menú de acciones de un mueble; editor de personaje (`ui/character_editor.*`).
- Guardado: personaje y reloj; al volver se descuenta el tiempo sin jugar.
- Pruebas: 27 nuevas (`tests/test_character.tscn`) + 44 de la casa, todas OK.
  Demo (`tests/character_demo.tscn`): con hambre cocina, con sueño duerme,
  obedece "ver tele".

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
- APK de depuración exportado sin errores (versión 0.1.0)### Prueba en el teléfono (2026-11-03)
- 60 FPS fijos con una casa de dos pisos. Le gustó ("se siente entretenido").
- Ajustes pedidos, ya hechos:
  1. Piso de arriba se puede poner primero (se apoya en paredes de abajo) +
     avisos que explican por qué algo sale rojo.
  2. La puerta llena todo su hueco (marco + hoja).
  3. Ventanas iguales seguidas se unen solas.
  4. Techo con grosor y paredes de remate en las puntas.
  5. Tocar fuera del lote mueve la cámara (no busca la celda más cercana).
  6. Cimientos/piso/pared/cuarto/techo: selección con manijas + Confirmar.
- Pruebas: 44 automáticas OK; demo: mouse real, fuera del lote y manijas OK.

### Falta para cerrar las Fases 1 y 2
1. [Dueño] Instalar el APK nuevo y probar los 6 ajustes de la Fase 1 y el
   personaje (checklist del chat).
2. [Claude] Corregir lo que salga; commit "Fases 1 y 2 cerradas".

### Próximo paso exacto
Instalar con `~/Android/Sdk/platform-tools/adb install -r build/neighborhood.apk`
(el APK ya está exportado) y probar. Después: Fase 3 (Sonnet alcanza).

### Pendientes anotados para más adelante
- Tutorial de primeros pasos (el dueño no adivinó "cuarto antes que piso").
- Mueble que se arrastra queda tapado por el dedo (podría ir más arriba).
- Interruptor para no unir ventanas, si hace falta.
- Personaje: si dos acciones del mismo mueble, o dos personajes, se cruzan
  (Fase 5), hará falta "reservar" el mueble.

.

### Preguntas abiertas para el dueño
- ¿Horizontal te parece bien? (ver DECISIONES.md, "Orientación").
- ¿Tu pareja usa Android o iPhone? (VISION.md)

## Fases siguientes
- Fase 3 — Progresión y economía local (conviene Sonnet).
