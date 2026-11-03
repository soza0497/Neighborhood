# Progreso

## Fase actual: 3 — Progresión y economía local (código listo; falta probar en el teléfono)

Las Fases 1, 2 y 3 están sin probar en el teléfono con los últimos cambios:
probarlas juntas.

### Fase 3 — hecho (2026-11-03)
- Dinero: precios del catálogo, cobro al construir, reventa 50 %, deshacer
  que devuelve lo pagado (`economy.gd`, `undo_history.gd`).
- Niveles y experiencia (por primera vez de cada pieza y por trabajar),
  piezas bloqueadas con `unlock_level` (`data/progression.json`).
- Obras con temporizador (muebles, escaleras, techos) en hora real, con
  aspecto naranja transparente y botón "Acelerar".
- Empleos (`data/jobs.json`): currículum con espera, turnos que sacan al
  personaje a la acera, sueldo y experiencia; panel en Menú → Empleos.
- Nada castiga por desconectarse: turno a medias y días fuera se pagan (tope 3).
- Guardado formato 2: migraciones (`save_migrations.gd`), respaldo
  `save.json.bak` y copia antes de migrar.
- Interfaz: dinero, nivel y barra de experiencia; avisos; piezas bloqueadas;
  "Confirmar ($X)".
- Regla nueva en CLAUDE.md: revisar modelo y esfuerzo antes de cada fase.
- Pruebas: 66 de economía + 53 de la casa + 34 del personaje, todas OK.
  Demo `tests/economy_demo.tscn`: precios reales, bloqueo por nivel, obra,
  acelerar, empleos, y turno completo (sale, desaparece, cobra).

### Ajustes de la prueba de la Fase 2 (2026-11-03) — hechos, sin probar
1. Panel del personaje sin saltos; Personaje y Diario en un menú oculto.
2. Diario con lo que hizo y caritas de emociones (feliz, cansado, enojado...).
3. Barra de piezas que se desliza con el dedo.
4. Vistas solo del piso actual (también en Vivir); puertas enteras.
5. Ventanas: Unir / separar, y sin línea en la unión.
6. Parcela de 32 × 32 m con calle y acera; casas viejas se centran solas.
- Pruebas: 53 de la casa + 34 del personaje, todas OK. Demos OK.

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
1. [Dueño] Instalar el APK nuevo y probar las Fases 1, 2 y 3 (checklist del chat).
2. [Claude] Corregir lo que salga; commit "Fases 1 a 3 cerradas".

### Próximo paso exacto
Instalar con `~/Android/Sdk/platform-tools/adb install -r build/neighborhood.apk`
(el APK ya está exportado) y probar. Después: **Fase 4 (servidor Nakama): usar Opus con esfuerzo alto.**

### Pendientes anotados para más adelante
- Balance de la economía (precios, sueldos, niveles): se ajusta con lo que
  salga de jugar; todo está en `data/*.json`.
- Si hace falta probar rápido: un "truco" para dar dinero/nivel en el menú.
- Visión de la parcela (VISION.md): zonas casa/trabajo, varias casas,
  alquiler, muros, robos y seguridad del barrio.
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
- Fase 4 — Cuentas y servidor (**Opus, esfuerzo alto**).
