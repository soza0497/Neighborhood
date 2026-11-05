# Progreso

## ▶ PULIDO 6A (versión 0.13.0) — construcción y casa — rama `pulido-6a` (sale de `main`). **No se mergea, no se exporta APK.**

**Estado:** 6A completa (11 puntos), en 3 sub-fases con un push cada una. Spec: `docs/pulido-6.md` §6A. Decisiones en `DECISIONES.md` → «Pulido 6A».
**Todo el GDScript y Lua nuevo se escribió SIN ejecutar** (la nube no tiene Godot ni Lua): esperá errores de sintaxis o de tipos al primer arranque.

**Próximo paso (el desarrollador principal, en la PC con Godot):**
1. `godot --headless --path . --import` (registra las clases nuevas —`FurnitureQuickMenu`, `LongPressTip`, `BasementView`, `FoundationQueue`, `HouseMove`—, importa `dollar.svg`/`pencil.svg` y crea los `.uid` nuevos; commitearlos).
2. `godot --headless --path . res://tests/test_build6a.tscn` (**nueva**, ≈ 170 comprobaciones; si falla, copiame el «FALLÓ: …») y las de antes: `test_house`, `test_art`, `test_template` (se ajustaron 3), `test_camera`, `test_floor_map`, `test_dev_mode`, `test_economy`, `test_parcel`, `test_server`…
3. `lua5.1 server/tests/test_rules.lua` (**se agregaron ≈ 40 comprobaciones**: muebles afuera, excavación solo bajo la casa, mudar la casa) y `test_goals.lua`. Si Nakama corre, reiniciarlo: hay un RPC nuevo (`house_move`) y cambió `neighborhood_house.lua`.
4. Con ventana: `SHOT_DIR=docs/capturas godot --path . res://tests/polish6a_demo.tscn` (genera `p6a_*.png`, ~14 capturas; **todavía no existen**), `tests/ui_demo.tscn` y `tests/polish2a_demo.tscn` (se ajustaron a «Comprar», al botón Pintar y a confirmar «Agregar piso»).
5. Mirar a mano en el teléfono (cuando se exporte): la pared pintada de dos colores (¿se ve algún borde raro en las esquinas?), el cartelito al mantener un botón, el sótano oscuro con la guía, y la maqueta de pisos (ver «Pendientes»).

### Qué se hizo (por sub-fase)
- **6A-1** (pintura, íconos, contorno): pared = cuerpo neutro + dos láminas finas (cara A / cara B); el canto de arriba y las columnas quedan neutros. «Adentro / Afuera / Cara tocada»
  para pintar. Pared nueva hereda el color de la vecina en línea. **Pintar** es su botón (brocha) y «Modificar» se llama **Mover**. Comprar = dólar, Obra/Construir = lápiz. Título del
  menú sobre la barra. Cartelito con el nombre al **mantener presionado** cualquier botón con ícono. Brújula escondida al construir. Contorno **fino (defecto) / normal / apagado** en Info.
- **6A-2** (cuadrícula, afuera, mini menú, maqueta): cuadrícula solo en la valla (máscara en el shader); `outdoor: true` en mesa, plantas, lámpara, florero y banca nueva (+ pruebas Lua);
  mantener presionado un mueble (modo vivir) abre flechas y girar; maqueta: borde de arriba pared por pared.
- **6A-3** (sótano, cimientos, mudanza): agregar piso/sótano piden confirmar (solo en Construir); sótano solo bajo la casa (teléfono + servidor), fondo café oscuro, guía, efecto hueco;
  cimientos sobre obstáculos piden los servicios y se ponen solos (cola, gancho para 6B); mover la casa con costo (☰ → Casa), RPC `house_move`.

### ⚠ Qué quedó SIN correr (la nube no tiene Godot ni Lua; el brief prohíbe descargar binarios)
Nada de GDScript ni de Lua se ejecutó ni compiló; no hay capturas (`docs/capturas/p6a_*.png` se generan con la demo). Riesgos típicos al primer arranque: inferencia de tipos, nombres de la API,
`await` dentro de funciones estáticas (`LongPressTip`), el uniform `sampler2D` de `grid.gdshader`, y `match`/lambdas. `dollar.svg` y `pencil.svg` necesitan el paso de importar (sin él, esos botones salen sin ícono).

### Pendientes / errores conocidos de Pulido 6A
- **Maqueta (10):** sin la captura del dueño no se pudo ver el «hueco»; se corrigió la causa más probable (aristas de arriba por piso entero). Si sigue, mandame la captura.
- **Mover la casa compartida:** no se puede (el servidor y el teléfono lo rechazan); falta el flujo de aprobación de la pareja. Los tipos de cuarto se corren con la casa pero **no** vuelven con «Deshacer».
- **Cimientos sobre obstáculos:** si no alcanza la plata cuando el terreno queda libre, los cimientos esperan en la cola y se reintentan en el próximo cambio de la parcela. 6B puede reemplazar la llamada al servicio (señal `foundation_services_requested`).
- **Mini menú:** solo en modo vivir; no hay prueba con dedos reales. La banca de jardín no tiene acción «sentarse» (el personaje no sale afuera de la casa).
- **Brújula:** se esconde al construir; 6C la reubica (conflicto previsto en `ui/hud.gd` y `ui/build_bar.gd`; los demás archivos de 6A no se cruzan con `scripts/character/*`, `scripts/debug/*` ni la cámara).
- Demos viejas con coordenadas de antes (`polish2c_demo`: la excavación ahora exige casa arriba) pueden fallar; ajustar con `HouseGrid.home_origin()`.

## ▶ Guías de arte: escritas en la rama `guias-arte`, sin verificar con Blender instalado
Ocho guías para principiante total en `docs/arte/` (00 mapa, 01 instalar Blender, 02 primera silla, 03 muebles con
partes, 04 Krita y paleta, 05 íconos SVG con Inkscape, 06 cuarto de prueba, 07 personaje, 08 problemas y atajos), más
`docs/arte/paleta_neighborhood.gpl` (copia de `data/palette.json` para Krita) y `docs/arte/ejemplos/bed.svg`.
No se tocó código ni datos del juego. **No se mergeó a `main`.**

**Cómo se escribieron:** desde la sesión en la nube **no se pudo abrir `docs.blender.org` ni `docs.krita.org`** (el
dominio no resuelve en la red de la sesión; habría que permitirlos en la configuración de red). Solo se vieron fragmentos
de búsqueda web (confirmaron: exportador glTF en `File > Import/Export > glTF 2.0`, Emulate 3 Button Mouse / Emulate
Numpad en Preferences > Input, Apply Scale con `Ctrl + A`, Mirror/Array/Bevel bajo Generate, Blender 5.2 LTS publicado
en julio de 2026, exportar una capa vectorial de Krita a SVG de a una). El resto se escribió **de memoria de
Blender 4.x/Krita 5** y está marcado «(a confirmar en tu versión)». Lo del juego (escala, pivote, `model`, paleta, slots,
FPS en Menú → Info) sí se verificó leyendo el repo.

**Pasos que quedaron «(a confirmar en tu versión)»** (revisar con Blender 5.2.3 / Krita 6.0.4 / Inkscape instalados):
- **01:** cuadro de bienvenida (Quick Setup); pestañas de espacios de trabajo; estadísticas en la barra de estado;
  Recover > Auto Save; permisos de Flatpak sobre la carpeta del proyecto.
- **02:** Overlays > Statistics y «Triangles»; **Object > Shade Auto Smooth** y el modificador *Smooth by Angle*
  (ángulo 60°); **todo el panel de exportación glTF** (secciones Include/Transform/Data/Animation y nombres de casillas);
  cuántos triángulos da la silla (300–450 estimado); `Set Origin`; panel «Add Cylinder» (Vertices/Radius/Depth).
- **03:** si *Dimensions* incluye modificadores; herramienta Measure; `model_offset` (sentido de los ejes); presupuesto.
- **04:** (Krita, casi todo de Krita 5) diálogo New Document y perfil sRGB; nombres de presets de pincel; atajos de
  zoom/rotación; campo Hex; **Settings > Manage Resources > Import Resources** para la `.gpl` (o copiar a `palettes/`);
  Filter > Adjust > Desaturate; View > Show Grid; modo Multiply para simular los 3 tonos; Add > Image > Reference en Blender.
- **05:** (Inkscape 1.x) Document Properties (tamaño, fondo, cuadrícula), `#` y `%`, Plain SVG / Save a Copy;
  exportar vectores desde Krita 6.
- **06:** cono con Radius 1/2; «Mostrar FPS en pantalla» y «Contorno» en Menú → Info (el texto sale de `ui/hud.tscn`;
  **no se corrió el juego**); suma de ~3.000 triángulos por cuarto (orientativa, no oficial).
- **07:** Weight Paint/Pose Mode paso a paso, `Ctrl + P > With Automatic Weights`, exportar acciones (NLA/Fake User),
  casillas de Skinning/Animation del exportador, nombres de paquetes CC0 (Kenney/Quaternius), espejo con nombres `.L/.R`.
  **Decisión abierta con el asesor:** dónde queda el origen de las piezas de personaje respecto del hueso `head`
  (el ensamblador las pega con `BoneAttachment3D` al origen del hueso; con la posición de respaldo `[0, 1.0, 0]` es el centro de la cabeza).
- **08:** `Ctrl + B` (bisel de aristas), `I` fotogramas clave, atajos de Krita 6.

**Próximo paso:** el dueño hace las guías 01 → 02; con lo que no coincida con su pantalla se corrigen las guías (y
se quitan las marcas). Si se habilita `docs.blender.org`/`docs.krita.org` en la red de la nube, una sesión puede
verificar y limpiar las marcas sin necesidad del programa instalado.

## ▶ PULIDO 4 (versión 0.12.0) — rama `pulido-4` (sale de `main` 0.11.0). **No se mergea a `main`, no se exporta APK.**

**Próximo paso (el desarrollador principal, en la PC con Godot):** correr lo que en la nube **NO se pudo correr** (esta sesión no tenía
Godot ni Lua y el brief prohíbe bajar binarios; **nada de GDScript se ejecutó ni compiló**, solo se revisó a mano). En este orden:
1. `godot --headless --path . --import` (registra las clases nuevas, importa `assets/icons/dev.svg` y **crea los `.uid`** de los scripts nuevos:
   `hazard_map`, `hazard_view`, `dev_mode`, `dev_panel`, `test_dev_mode`; commitealos).
2. `godot --headless --path . res://tests/test_dev_mode.tscn` (**nueva**, ≈ 90 comprobaciones; si falla, copiame el «FALLÓ: …»).
3. Las pruebas de antes: `test_house` (158), `test_character` (34), `test_economy` (66), `test_server` (78), `test_couple` (46),
   `test_business` (46), `test_parcel` (55), `test_art` (≈90), `test_neighborhood`, y `lua5.1 server/tests/test_rules.lua` (322) +
   `test_goals.lua` (42). El servidor Lua **no se tocó**; en Godot se tocaron `character.gd`, `character_animator.gd`, `house_nav.gd`,
   `house_builder.gd`, `build_bar.gd`, `hud.gd`, `home_panel.gd`, `cloud_sync.gd`, `live_controller.gd` y `main.gd`, así que conviene correr todas.
4. Con ventana: `tests/polish3b_demo.tscn` (ahora cubre la herramienta Cuartos y el panel Casa; genera `p4a_herramienta_cuartos.png` y
   `p4a_casa_cuartos.png`; **esas capturas todavía no existen**; las viejas `p3b_lista_cuartos.png` ya no se genera) y `ui_demo.tscn`.

### 4A — Los cuartos salen de la columna izquierda (hecho, sin correr)
- La columna izquierda queda con techo, paredes y la maqueta de pisos (se quitó el botón «Cuartos» de `hud.gd`).
- **Obra → Cuartos** (ícono `room.svg`, junto a Construir · Modificar · Borrar): resalta los cuartos cerrados del piso con colores chatos
  (el dormitorio principal, más marcado); tocar uno abre el menú de tipo del Pulido 3B (cocina, dormitorio, baño, sala, estudio…, y
  principal/secundario). `HouseBuilder.Tool.ROOMS`, `HouseBuilder.ROOMS_TOOL_ID`, `refresh_room_overlay()`.
- **☰ → Casa**: lista de cuartos de todos los pisos con su tipo y «Cambiar tipo», y el interruptor «Mi casa se puede visitar».
- `polish3b_demo` y `ui_demo` actualizadas (ya no usan el botón viejo).

### 4B — Modo desarrollador (hecho, sin correr)
- **Info → «Modo desarrollador (probar situaciones)»**, apagado por defecto, en `GameState.settings["dev_mode"]`, **nunca al servidor**
  (`CloudSync.LOCAL_ONLY_SETTINGS`). Apagado no se ve ni se puede usar nada (prueba incluida).
- Ícono nuevo arriba (junto al menú) abre el **panel** (derecha, debajo de los botones, no tapa los controles): *Acción* (tocar mueble,
  puerta o suelo → ir, usarlo o accidente caerse/tropezar/quemarse), *Atención* (deslizador 0–1 + distraído/desorbitado/recién levantado),
  *Peligros* (tocar el suelo: charco/caliente/desnivel), *Estados* (comida, energía, limpieza, diversión, teletransportar, congelar IA,
  hora) y un **registro corto** (intención con su motivo + accidente forzado).
- Nuevo: `data/hazards.json`, `scripts/debug/{hazard_map,hazard_view,dev_mode}.gd`, `ui/dev_panel.{gd,tscn}`, `assets/icons/dev.svg`,
  `tests/test_dev_mode.{gd,tscn}`. El personaje expone `attention`, `force_action`, `force_accident(kind)` (+ `teleport_to`,
  `set_ai_frozen`, `last_reason`). `HouseNav.find_path(..., careful)` rodea peligros con atención alta.
- **Nada de dinero, experiencia ni propiedad** (prueba que lo revisa). Decisiones completas en `DECISIONES.md` → «Pulido 4B».

### Cómo probarlo en el teléfono (cuando se exporte el APK, que NO se hizo)
1. ☰ → Info → prendé **Modo desarrollador**: aparece un ícono de bicho arriba, a la izquierda del menú.
2. Tocalo: se abre el panel. **Peligros** → «Poner peligros (tocar el suelo)» con *Charco* y tocá 2–3 celdas del suelo (se ven placas azules).
3. **Atención** → «Desorbitado» (0,05). **Acción** → tocá un mueble lejano del otro lado del charco → «Ir hasta ahí»: el personaje pasa por el
   charco, se cae (burbuja ¡Ay! con ícono), llega la ambulancia. Repetí con «Atento (1.0)»: rodea el charco.
4. **Acción** → tocá la cocina → «Accidente en ese lugar» → «Quemarse»; tocá una puerta → «Caerse». «Tropezar» no llama a la ambulancia.
5. **Estados**: poné comida en 20; «Congelar la IA» (se queda quieto); «Teletransportar» y tocá el suelo; hora 19:00.
6. Apagá el modo: desaparecen ícono, panel y marcadores y el personaje vuelve a ser normal.

### Pendientes / errores conocidos de Pulido 4
- **Todo sin ejecutar** (ver arriba); esperá errores de sintaxis o de tipos al primer arranque. Sin capturas nuevas.
- Mientras el panel está abierto, los toques del mundo sirven al panel (no abren el menú de acciones del mueble); cerrá el panel para jugar normal.
- Los peligros no se guardan (son de la sesión). La pareja (personaje remoto) no se ve afectada por los peligros de tu pantalla de forma sincronizada.
- Si se cae desde un piso alto, el personaje baja a la planta baja (la ambulancia llega por la calle).
- `dev.svg` necesita el paso de importar; sin él el botón sale sin ícono hasta correr `--import`.
- Cambiar el ángulo de cámara/zoom mientras el panel está abierto funciona; elegir con dos dedos no (son gestos de cámara).
## ▶ Pulido 5 (versión 0.12.0) — en la nube, rama `pulido-5` (sale de `main` 0.11.0)

**No se mergea a `main`, no se exportó APK.** Otras sesiones trabajan en paralelo (`pulido-4`: botón de cuartos y panel de
desarrollador, toca `ui/hud.*`; `isla-1a`: la isla). Acá `ui/hud.*` se tocó lo mínimo (ver «Fusión» abajo).

**Próximo paso:** el desarrollador principal, **en la PC con Godot**, corre lo que en la nube **NO se pudo correr** (la nube no tenía
Godot ni Lua y el brief prohíbe descargar binarios): **todo el GDScript de este pulido está escrito sin ejecutarse** (ni compilado).
Hay que correr, en este orden:
1. `godot --headless --path . --import` (registra las clases nuevas: `HouseTemplate`, `HouseTemplates`, `TemplatePlacer`; crea los `.uid`
   de los scripts nuevos → commitearlos).
2. Pruebas **nuevas**: `tests/test_camera.tscn`, `tests/test_floor_map.tscn`, `tests/test_template.tscn`.
   Después las de siempre: `test_house` (158), `test_character` (34), `test_economy` (66), `test_server` (78), `test_couple` (46),
   `test_business` (46 + 7 nuevas del interruptor), `test_parcel` (55), `test_art`, `test_neighborhood` y
   `lua5.1 server/tests/test_rules.lua` (322; **no se tocó nada del servidor**) y `test_goals.lua`.
3. Demos con ventana (sacan capturas a `docs/capturas/` con `SHOT_DIR=docs/capturas`): `tests/polish5c_demo.tscn` (`p5c_*`),
   `tests/polish5e_demo.tscn` (`p5e_*`). `polish3b_demo` se ajustó (el ángulo ya no baja de −20°). Las capturas **todavía no existen**.
   La cámara (5B) y la maqueta (5D) conviene mirarlas a mano en la PC: `tests/polish3b_demo.tscn` + jugar un rato con el mouse.
4. Si algo falla, copiame el texto «FALLÓ: …».

### Qué se hizo
- **5A** `data/features.json` (`player_business: false`) esconde el restaurante: botón del ☰, categoría y muebles de la Tienda (y de
  «Recomendado»). Nada se borró; `test_business` prende el interruptor.
- **5B** `data/camera.json` (ángulo mínimo −20°, tope de velocidad por gesto/cuadro, amortiguación, zona muerta, margen y borde suave).
  Cámara baja: lado = desplazar, vertical = avanzar lento. Paneo proporcional a la distancia. Límite a la parcela usable + 3 m con borde
  suave (solo vista normal). `tests/test_camera.*`.
- **5C** Capa libre `Overlay` para ☰, Info, ánimo, menú de pieza y ventanitas (no empujan la interfaz); opacos y exclusivos; la barra del
  ángulo se esconde con un menú abierto y no pisa la Tienda; al construir se ocultan ánimo y necesidades. `tests/polish5c_demo.*`.
- **5D** Maqueta: 4 aristas de la losa plana + borde de arriba de las paredes de atrás sin techo; punto del personaje solo dentro de la
  casa, en su piso (apagado si se mira otro) y también al dormir. `tests/test_floor_map.*`.
- **5E** Plantillas de casa (☰ → Casa → «Plantillas de casa»): guardar con nombre, ver, renombrar, borrar y **Colocar** con holograma
  verde/rojo que entra por el plan y la factura (el servidor cobra y revisa con `build_apply`). Se guardan en la partida y en la nube con las
  opciones. `tests/test_template.*`, `tests/polish5e_demo.*`.

### Cómo probarlo en el teléfono (cuando se exporte)
1. ☰: ya no está «Restaurante»; Obra/Tienda: sin la pestaña Restaurante.
2. Bajá la perilla del ángulo al máximo: la cámara se frena en −20°. Con un dedo: de lado desplaza, arriba/abajo avanza lento (con un
   pequeño «aguante» antes de empezar). Alejate de la zona de tu terreno: la cámara frena suave en el borde. El barrio sigue libre.
3. Abrí el ☰ con la Tienda abierta: las barras de arriba y abajo no se mueven; el menú es opaco; al abrir Info, el ☰ se cierra.
   Al construir no se ve la carita del ánimo.
4. Maqueta: con techo liso se ven las 4 aristas de la losa. Salí de la casa al lote: el punto desaparece; mandá a dormir al personaje: el
   punto queda en la cama; subí de piso en la maqueta y mirá el punto apagado en el piso del personaje.
5. ☰ → Casa → «Plantillas»: escribí un nombre y «Guardar la casa». «Colocar»: mové la silueta con el dedo (verde = cabe); «Colocar» →
   Factura → se construye; «Deshacer» la saca de un golpe.

### Fusión con `pulido-4` / `isla-1a` (para quien una las ramas)
- `ui/hud.gd`: 5A (1 línea, `_restaurant_button.visible`), 5C (`_build_overlay`, `_float_control`, `_place_floating`, `_any_menu_open`,
  `_close_floating`; cambios en `_toggle_side_menu`, `_open_info`, `_open_popup`, `_on_game_mode_changed`, `_fit_to_screen`, `_process`) y
  5E (1 línea en `setup_house`). `ui/hud.tscn` NO se tocó. Si `pulido-4` mueve el botón de cuartos o agrega el panel de desarrollador,
  el panel nuevo debería abrirse con `_close_floating(...)` y agregarse a `_any_menu_open()` para ser exclusivo.
- `isla-1a`: si usa `CameraRig`, poner `lot_limit_enabled = false` mientras se está en la isla (y revisar `pitch_min_degrees`).
- `scripts/main.gd`: 4 líneas (crear el `TemplatePlacer`). `scripts/autoload/event_bus.gd`: 2 señales. `scripts/camera/camera_rig.gd`: reescrito el paneo.

### Pendientes / errores conocidos de Pulido 5
- **TODO el GDScript está sin ejecutar** (ver arriba): esperá errores de sintaxis/tipos al primer arranque. Capturas sin generar.
- **5D, bug «desaparece al dormir»:** no se pudo reproducir (sin Godot). Se quitó la dependencia de `character.visible`; si sigue pasando,
  mirar `Character.state` durante `sleep` y la posición del punto.
- **5E:** no se puede girar la plantilla; no hay prueba Lua nueva (el servidor ya revisa apoyo, lote, obstáculos, zona y nivel en
  `rules.build` → `check_support`, probado por `test_rules.lua`); el servidor NO prohíbe pisar piezas que ya existen (el cliente sí:
  «Choca con lo ya construido»); las plantillas viajan en las opciones (un solo objeto de nube: ~10 plantillas máx.).
- **5B:** los valores de `data/camera.json` son una primera estimación: hay que probarlos en el teléfono (¿el avance vertical es muy
  lento/rápido?, ¿−20° es buen mínimo?).
- Los pendientes de 0.11.0 siguen (demos con coordenadas viejas, FPS en teléfono, etc.).

## ▶ Isla 1A — prototipo de rendimiento y LOD (2026-11-04) — en la nube, rama `isla-1a` (sale de `main` 0.11.0)

**No se mergea a `main`, no se exporta APK.** Todo es archivo nuevo (`scripts/island/`, `scenes/island/`, `data/island.json`, `tests/test_island.*`,
`tests/island_demo.tscn`, `docs/isla-prototipo.md`); fuera de eso solo `camera_rig.gd` (modo isla) y 2 líneas de `ui/hud.gd` (botón escondido en Info). El diseño
general es de `docs/isla.md` (del desarrollador principal; no se tocó). Detalle, cómo medir en el teléfono y mis recomendaciones: **`docs/isla-prototipo.md`**.

- Hecho: datos de la isla (60 lotes, 30 al empezar), `ExteriorCard` (ficha exterior serializable), LOD 0-3 (HouseView / fachada / bloques agrupados por zona / mapa),
  `IslandLod` con histéresis, escenario (parque con lago, comercios decorados, playa, muelle, volcán con humo opcional, vegetación en MultiMesh por trozos),
  demo con FPS, botones de LOD, contorno/sombras, estrés (60 lotes, 100 casas) y tabla, pruebas sin ventana y entrada «Herramientas de prueba → Prueba de isla» en Info.

**Próximo paso (el desarrollador principal, en la PC con Godot):**
1. `godot --headless --path . --import` (registra las clases nuevas y crea los `.uid` de los scripts nuevos; commitealos) y arreglar lo que falle al compilar.
2. `godot --headless --path . res://tests/test_island.tscn` (unas 100 comprobaciones; copiame el «FALLÓ: …» si algo falla; los presupuestos de dibujo son estimaciones mías).
3. Correr todas las pruebas de antes (Godot y `lua5.1 server/tests/test_rules.lua`): no se tocó nada existente, pero hay que confirmarlo.
4. Con ventana: `godot --path . res://tests/island_demo.tscn` (mirar que se vea la isla y que los botones LOD 0/1/2/3 cambien lo que se ve) y la tabla:
   `ISLAND_BENCH=1 SHOT_DIR=docs/capturas godot --path . res://tests/island_demo.tscn`.
5. Si todo anda: exportar un APK de prueba y que el dueño mida en el teléfono (`docs/isla-prototipo.md`, §7) y ajustar `data/island.json`. Después decidir la unión con `docs/isla.md`.

### ⚠ Qué quedó SIN correr (la nube no tenía Godot ni Lua; el brief prohíbe descargar binarios)
Nada de GDScript se ejecutó ni se compiló (ni los 2 shaders nuevos). Lo único verificado con Python: `data/island.json` (válido; 60 lotes sin encimarse, sin pisar calles ni salir de la isla;
mismas reglas que la prueba). Riesgos típicos al primer arranque: inferencia de tipos con `Variant`, algún método de la API, `HouseView` armado dentro de `IslandWorld` (LOD 0).
No hay capturas (se generan con la demo). Los `.uid` de los scripts nuevos no están en el repo: Godot los crea al importar.

## ▶ ESTADO ACTUAL (2026-11-04) — versión 0.11.0, todo unido en `main`
Pulido 2, Pulido 3, Fase 7 (arte) y Fase 8 (barrio) están unidos y **verificados en la PC**: pruebas de Godot y de
Lua en verde (Lua 322 + metas 42), Nakama con los 7 módulos, cuenta nueva completa contra el servidor real
(`login_demo` 18/18). APK 0.11.0 en `build/neighborhood.apk`.

**Pendientes de verificación (próximo paso):**
1. Seis demos con servidor usan coordenadas de la parcela vieja y fallan: `server_demo`, `economy_server_demo`,
   `parcel_server_demo`, `couple_demo`, `couple_live_demo`, `restaurant_demo` (usar `HouseGrid.home_origin()`).
   Confirmar que no esconden un error real en pareja o restaurante. También `polish2a_demo` (1) y `polish2c_demo` (2).
2. El dueño prueba el APK 0.11.0 en el teléfono y mide los FPS (contorno sí/no, barrio con vecinos).
3. Detalle visual: al crear el personaje se ve el panel del login detrás del editor.
4. Decidir si los muebles con modelo se pueden pintar (hoy ignoran el color) y el tamaño de la zona inicial (64×64).

Las notas de abajo son el detalle de cada fase.

## ▶ Fase 7 — preparación de arte y estilo (versión 0.11.0) — en la nube, rama `fase-7` (sale de `pulido-3`)

**No se mergea a `main`, no se exporta APK.** Otra sesión hace la Fase 8 (barrio) en paralelo: aquí se tocó lo mínimo
en archivos de casas/parcelas/mundo (nada de eso) y casi todo es archivo nuevo.

**Próximo paso:** el desarrollador principal, **en la PC con Godot**, corre lo que en la nube **NO se pudo correr** (ver abajo)
y, si todo está bien, decide la unión a `main`. Después: empezar a hacer arte real (Blender) siguiendo `docs/estilo.md`, sección 11.

### ⚠ Qué quedó SIN correr (la nube de esta sesión no tenía Godot ni Lua)
Como el brief pide no descargar binarios externos, **nada de GDScript se ejecutó**: ni siquiera se compiló. Se escribió con cuidado, pero
puede haber errores de sintaxis o de API al primer arranque. Lo único verificado fue lo hecho con Python: los `.glb` (cabecera, límites,
orientación de las caras, nombres de materiales) y los JSON (válidos). **Hay que correr, en este orden:**
1. `godot --headless --path . --import` (importa los `.glb` nuevos y registra las clases nuevas; crea los `.uid` de los scripts nuevos).
2. `godot --headless --path . res://tests/test_art.tscn` (**nueva**, ≈ 90 comprobaciones; si falla, copiame el texto «FALLÓ: …»).
3. Todas las pruebas de antes: `test_house` (esperado 158), `test_character` (34), `test_economy` (66), `test_server` (78), `test_couple` (46),
   `test_business` (46), `test_parcel` (55) y `lua5.1 server/tests/test_rules.lua` (322; no se tocó nada del servidor).
4. Con ventana: `tests/art_demo.tscn` (genera `docs/capturas/art_1_con_modelos.png`, `art_2_respaldos.png`, `art_3_recoloreo.png`; **esas capturas
   todavía no existen**) y las demos de antes (`polish2b_demo` se ajustó: la silla ahora trae modelo).
Los `.uid` de los scripts nuevos no están en el repo: Godot los crea al importar (paso 1); commitealos.

### Fase 7 — qué se hizo
- **`docs/estilo.md` completo**: proporciones chibi, paleta, reglas para IA (solo referencias del dueño o CC0; nunca arte de otros juegos),
  convenciones de importación (escala, pivote, orientación, nombres, materiales con nombre, presupuesto de triángulos) y guía de Blender → juego.
- **`ModelLoader`** (`scripts/art/model_loader.gd`): campo `model` del catálogo → `.glb` en `assets/models/`. Nunca rompe (falta, roto, sin mallas o apagado
  → figura simple). Respeta la caja de celdas (achica si se pasa), `model_fit/pivot/scale/offset/rotation/colors`. Sirve para **muebles, escaleras,
  pilares, puertas y ventanas**. Techos no (se arman a medida). `ModelLoader.inspect(ruta)` avisa de pivote, escala y materiales mal.
- **Paleta y luz en un solo lugar**: `data/palette.json` (colores por nombre de material + tonos de sombra + luz). Se movieron ahí `toon` y `light` de `style.json`.
- **Personaje modular**: `data/character_slots.json` (esqueleto, 9 slots, ganchos de animación con nombres alternativos) y `CharacterAssembler`
  (pieza `.glb` por slot con respaldo a las figuras simples; `CharacterAnimator.bind_model` usa el `AnimationPlayer` del `.glb` si existe).
- **Ejemplos**: `tools/make_sample_models.py` (Python, sin Blender) generó `chair.glb`, `table.glb` y `character/hair_round.glb`
  (formas redondeadas, ≤ 304 triángulos, materiales `wood`, `cloth_red`, `wood_light`, `hair`). `chair_basic` y `table_basic` ya los usan.
- **Info → «Usar modelos 3D (arte)»**: apaga/prende y la casa y los personajes se arman de nuevo. Se guarda en la partida (`use_models`).
- Versión **0.11.0** en `project.godot` y `export_presets.cfg` (sin exportar).

### Fase 7 — cómo probarlo en el teléfono (cuando se exporte el APK, que NO se hizo)
1. Tienda → Silla o Mesa de comedor → colocalas: se ven redondeadas, con tela roja y madera (los `.glb` de ejemplo).
2. Menú → Info → apagá «Usar modelos 3D (arte)»: vuelven las cajas de antes; prendelo y vuelven las redondeadas.
3. Cambiá un color en `data/palette.json` (p. ej. `wood`) y mirá que cambie en todas las piezas de madera.
4. Medí los 30 FPS con el interruptor prendido y apagado.

### Pendientes / errores conocidos de la Fase 7
- Todo lo de «SIN correr». Capturas de la demo sin generar.
- Los modelos ignoran el color con el que se pinta un mueble (`piece_color`); se manejan con `model_colors` o la paleta. Decidir si se quiere pintar muebles con modelo.
- Techos con modelo y ropa deformable sobre esqueleto real: no hay (ver `docs/estilo.md`, sección 12).
- Un `.glb` crudo (sin importar) solo se lee en la PC; en el APK viaja el importado (abrir el proyecto en el editor antes de exportar).

## ▶ Fase 8 — Barrio (versión 0.11.0) — en la nube, rama `fase-8` (sale de `pulido-3`)

**No se mergea a `main`, no se exporta APK.** Otra sesión hace la Fase 7 (arte) en `fase-7`: acá no se tocó el
catálogo ni el cargador de modelos; todo lo nuevo está en `scripts/neighborhood/`, `data/neighborhood.json`,
`ui/neighborhood_panel.*`, `tests/*neighborhood*` y (8D) un módulo Lua nuevo.

**ATENCIÓN — nada de esto se pudo correr:** el entorno de la nube de esta sesión NO tiene Godot ni Lua y el
brief prohíbe descargar binarios. Todo el código de la Fase 8 está escrito **sin ejecutarlo**: puede tener errores
de sintaxis o de lógica. Lo primero que hay que hacer en la PC es correr las pruebas (lista abajo) y arreglar lo que salga.

- **8A barrio y calles: escrito (sin correr)** — `data/neighborhood.json` (24 lotes: tu parcela, 10 casas en tu fila,
  12 enfrente y una plazoleta), casas de vecinos deterministas con piezas del catálogo, acera de enfrente, farolas,
  árboles de acera. La casa detrás de la valla ES la del lote vecino del mapa (reemplaza la «casa al azar» del Pulido 3A).
- **8B vista aérea y visitas: escrito (sin correr)** — menú ☰ → «Barrio»: vista aérea (misma cámara; pellizcar y
  girar), lista «¿Qué casa querés visitar?» (solo ver, por dentro), botón «Volver a mi casa», interruptor
  «Mi casa se puede visitar» (apagado por defecto, se guarda en `GameState.settings["house_visitable"]`).
- **8C vida: escrito (sin correr)** — `NeighborhoodLife`: hasta 10 vecinos con la figura chibi que salen de su casa,
  caminan por las aceras, cruzan por los pasos (los autos frenan), se saludan (`wave`), van al parque o a casa de
  otro vecino y a veces entran; 4 autos de cajas que siguen al de adelante sin tocarse. Ganchos de animación por
  nombre (`idle`, `walk`, `wave`) y de sonido por evento (`EventBus.neighborhood_sound`; archivos futuros en
  `data/sounds/`, ver `LEEME.txt`). LOD por distancia y menos vecinos si los FPS bajan de 24.
- **8D metas del barrio: escrito (sin correr)** — meta «Plantar 50 plantas entre todos» (`data/neighborhood.json`,
  `goal`): módulo Lua `server/nakama/modules/neighborhood_goals.lua` + RPC `goal_load` / `goal_claim` registrados en
  `neighborhood.lua` (el servidor cuenta las plantas terminadas de tu casa, tope 10 por día, vecinos simulados
  deterministas con tope del 60 %, premio chico y opcional $150 + 30 XP, sin fecha límite). Copia local para partidas
  sin cuenta en `neighborhood_goal.gd` (mismos números). Panel «Barrio»: barra de la meta, tu aporte y «Retirar».

**Resumen (fase 8 completa en código, 0 líneas ejecutadas):** barrio de 24 lotes con calle, aceras, farolas, árboles y
plazoleta; 23 casas de vecinos generadas (apellido y diseño con piezas del catálogo, siempre iguales); la casa de detrás
de la valla es la del lote vecino; vista aérea con la misma cámara; visitar casas por dentro en modo solo ver y volver;
interruptor de privacidad; vecinos animados que caminan, se saludan y entran a sus casas; autos sin choques; LOD y
límite de personajes; ganchos de sonido; meta del barrio con módulo Lua. Versión 0.11.0 (`project.godot`, `export_presets.cfg`).

**Cómo probarlo en la PC / el teléfono (cuando se pueda correr):**
1. `godot --headless --path . res://tests/test_neighborhood.tscn` y `lua5.1 server/tests/test_goals.lua` → «0 fallaron».
   Después las pruebas viejas (`test_house`, `test_parcel`, `test_economy`, `test_server`, `test_couple`, `test_business`,
   `test_character` y `lua5.1 server/tests/test_rules.lua`): no deberían cambiar (solo se tocaron `main.gd`, `world_builder.gd`,
   `camera_rig.gd`, `event_bus.gd`, `hud.*` y `neighborhood.lua` con cambios chicos).
2. `docker compose restart nakama` en `server/` (módulo Lua nuevo + `neighborhood.json`).
3. Abrí el juego: mirá la valla de un costado (la casa de atrás ahora es del barrio) y la calle con farolas y vecinos.
4. ☰ → **Barrio**: «Vista aérea del barrio» (arrastrá, pellizcá, girá con dos dedos); elegí una casa de la lista:
   se ve por dentro (solo ver); **← Volver a mi casa**. Probá también con Esc en la PC.
5. En Barrio → **Privacidad**: «Mi casa se puede visitar» (apagado). **Meta del barrio**: poné plantas en tu casa (Tienda →
   Plantas), esperá que terminen la obra, abrí Barrio: sube tu aporte (máx. 10 por día).
6. Menú Info → Mostrar FPS: con la calle a la vista y los vecinos, medí los **30 FPS** en el teléfono (si baja, hay menos vecinos).
7. `tests/neighborhood_demo.tscn` con ventana (o `SHOT_DIR=docs/capturas xvfb-run ...`): saca `n8a_*`, `n8b_*`, `n8c_*`, `n8d_*`.

### Pendientes / errores conocidos de la Fase 8
- **TODO EL CÓDIGO ESTÁ SIN EJECUTAR** (sin Godot ni Lua en la nube): esperá errores de sintaxis o de tipos al primer arranque.
  No hay capturas en `docs/capturas/` (las genera la demo).
- Una sola calle; sin calle transversal ni giros de autos. Los vecinos no tocan tu parcela (caminan por aceras y lotes).
- «Entrar a casa» es desaparecer unos segundos: sin HouseNav dentro de las casas vecinas ni vecinos visibles al visitar.
- No se puede tocar una casa del mapa para visitarla (solo la lista). Los carteles de familia usan `Label3D` simples.
- La meta cuenta solo plantas (categoría `plants`); «usar servicios» y adornos quedan para sumar en `goal.categories`.
  La pareja no suma a la misma meta todavía (cada uno tiene la suya). Un solo barrio, una sola meta, sin ciclo nuevo.
- Sonidos: solo las señales; no hay archivos en `data/sounds/`.
- Si se quiere el interruptor de privacidad en el servidor (que la pareja o familia lo vea), falta una RPC.

**Próximo paso:** (1) en la PC: `godot --headless --path . res://tests/test_neighborhood.tscn` y arreglar errores;
(2) correr `tests/neighborhood_demo.tscn` con ventana y mirar las capturas `docs/capturas/n8*.png`.

## ▶ Pulido 3 (versión 0.10.0) — en la nube, rama `pulido-3` (sale de `pulido-2`)

Brief completo en `docs/pulido-3.md`. Tres sub-fases, un push a `pulido-3` al terminar cada una.
**No se mergea a `main`, no se exporta APK.** Estado:

- **3A parcela, camino y obstáculos: HECHO (2026-11-04)** — ver abajo.
- **3B interfaz y personaje: HECHO (2026-11-04)** — ver «Pulido 3B» abajo.
- **3C estilo (contorno sin costuras): HECHO (2026-11-04)** — ver «Pulido 3C» abajo.

**Próximo paso:** el desarrollador principal verifica en la PC (checklist al final de esta nota, «Cómo
probarlo»), corre las demos con Nakama que no se pudieron correr en la nube, y decide si se une
`pulido-3` a `main` y se exporta el APK 0.10.0 (nada de eso se hizo: el brief lo prohíbe).

### Pulido 3B — qué se hizo
- **Pantalla cortada**: arreglada la causa (la columna izquierda exigía altura y agrandaba toda la interfaz) y
  se respeta el **área segura** (`SafeArea`). Probado en 1920×1080, 1080×2400 y 2400×1080.
- **Mueble**: al soltar queda **sostenido** y se puede **girar 45°** antes de Confirmar.
- **Techo**: la rejilla **sube a la altura de las paredes** del piso.
- **Ángulo de cámara**: **barra vertical con perilla** a la derecha, debajo del menú (vuelve sola al centro;
  el botón viejo se quitó).
- **Maqueta de pisos**: flechas **fuera de la caja**, azul/verde translúcido, **sin aristas del fondo**.
- **Cuartos**: el jugador asigna el tipo (menú al tocar un cuarto o botón «Cuartos»), dormitorio **principal**
  (`HouseRooms.main_bedroom`), «Multiuso» eliminado → **«★ Recomendado»**. Se guarda en la partida.
- **Creación de personaje** al registrarse: nombre, 5 peinados, 4 ojos, 4 bocas, piel, pelo, ropa, con vista
  previa que gira; opciones en `data/character_options.json`.
- Pruebas: `test_house` **158**, `polish3b_demo` **52** (capturas `docs/capturas/p3b_*.png`).

### Pulido 3C — qué se hizo
- **Paredes continuas**: cajas de contorno por tramo recto, sin contorno entre tramos (costura 22 → 0 píxeles).
  `polish3c_demo` **10** (capturas `p3c_*.png`: antes y después).

### Pulido 3 — cómo probarlo en el teléfono
1. [Claude, después de verificar] Unir `pulido-3` a `main`, **reiniciar Nakama** (`docker compose restart nakama`
   en `server/`) y exportar el APK 0.10.0. Tu partida del Pulido 2 se migra sola (la casa se acerca a la calle).
2. **Parcela**: al abrir, tu casa está cerca de la calle, con vallas a los costados y casas de vecinos detrás.
   Solo se puede construir en 64 × 64 (lo demás se ve sombreado). Subí a nivel 4 y 6 para abrir más.
   Mirá que la franja entre la casa y la calle esté sin árboles. Mandá al personaje a caminar y mirá que
   rodee los árboles; limpiá uno y fijate que el camino se acorta.
3. **Pantalla**: abrí la Tienda y elegí un mueble; las barras de arriba y abajo no se salen. Probá girando el
   teléfono (vertical y horizontal).
4. **Mueble**: Tienda → cama → tocá el piso: queda sostenida; tocá el botón de girar (45° cada vez) y
   Confirmar (✓).
5. **Techo**: Obra → Construir → Techos: la rejilla flota arriba de las paredes; arrastrá el rectángulo.
6. **Ángulo**: arrastrá la perilla de la derecha hacia arriba (vista de cielo) y abajo; al soltar vuelve al centro.
7. **Maqueta de pisos**: flechas afuera de la caja, sin las líneas de atrás.
8. **Cuartos**: Obra → Modificar → tocá el piso de un cuarto → «Tipo de cuarto», o el botón de la etiqueta
   (izquierda). Elegí Dormitorio → ★ Principal. Abrí la Tienda dentro del cuarto: pestaña «★ Recomendado».
9. **Personaje**: cerrá sesión (menú) y creá una cuenta nueva: aparece la creación de personaje.
10. **Contorno**: mirá las paredes desde varios ángulos (sin rayitas). Menú → Info → Mostrar FPS: medí los 30
    FPS con una casa de dos pisos amueblada, con contorno encendido y apagado.

### Pulido 3 — verificación final (nube: Godot 4.7.2 con SHA-512 verificado, Lua 5.1 de apt)
Sin pantalla: casa **158**, personaje 34, economía 66, servidor 78, pareja 46, negocio 46, parcela **55**; Lua **322**.
Demos con xvfb (OpenGL): `ui_demo` **41**, `polish2a_demo` 46, `polish2b_demo` 43, `polish2c_demo` 49,
`polish3a_demo` **15**, `polish3b_demo` **52**, `polish3c_demo` **10**. Capturas en `docs/capturas/p3a_*`, `p3b_*`, `p3c_*`.
**No se corrieron** (necesitan Nakama real; en la nube no hay Docker): `server_demo`, `economy_server_demo`,
`couple_demo`, `couple_live_demo`, `login_demo`, `restaurant_demo`, `parcel_server_demo`. Las reglas del servidor
(zona, migración a formato 5) están cubiertas por las pruebas Lua. **Pendiente en la PC**: reiniciar Nakama y
correr esas demos (las de parcela y casa asumen la casa nueva cerca de la calle: `home_origin()` ya la sigue;
`parcel_server_demo` se adaptó a ciegas, sin poder correrla). Los **30 FPS** y el **área segura real** (muesca,
barra de gestos) solo se pueden medir en el teléfono.

### Errores conocidos / pendientes de Pulido 3
- `login_demo` no se adaptó para la pantalla de creación de personaje (el flujo real: crear cuenta → creación
  → juego); probar a mano.
- Los tipos de cuarto no viajan al servidor (a propósito); con otro teléfono de la misma cuenta no se ven.
- Pared con puerta o ventana conserva el contorno por tramo (puede quedar una rayita en la juntura con el marco).
- Cámara: no se limita a la zona abierta (se puede mirar todo el terreno, solo no se puede pisar ni construir).

### Pulido 3A — qué se hizo
- **Zona disponible = el doble de la parcela original (32 → 64 × 64), pegada a la calle**;
  con niveles se abre hasta el triple (96 × 96: nivel 4 atrás, nivel 6 costados). Lo demás
  se ve (sombreado) pero no se pisa ni se construye (teléfono y servidor). `data/parcel.json`.
  (La «parcela original» es la de 32; la de la Fase 1 era de 12. Ver DECISIONES.)
- **Vallas de madera** en los costados de la zona y **una casa de vecino al azar** detrás de cada
  una (solo decoración). Siguen a la zona al abrirse terreno. `data/world.json`.
- **La casa va cerca de la calle** (a 6 celdas), la franja hasta la calle **sin obstáculos**.
  **Migración** (formato de casa 5, también en el servidor): casas, muebles, techos y
  personaje se corren 26 celdas hacia la calle. Probada con una copia de partida del Pulido 2
  (no se tocó ninguna partida real).
- **El personaje esquiva obstáculos**: la red de caminos se regenera al limpiar/abrir terreno y
  el camino rodea con aire árboles y rocas. Prueba: llega al otro lado de un árbol.
- Pruebas: `test_parcel` **55**, Lua **322**, demo nueva `polish3a_demo` **15** (capturas
  `docs/capturas/p3a_*.png`).

**Verificación 3A (nube: Godot 4.7.2 con SHA-512 verificado, Lua 5.1 de apt):** sin pantalla —
casa 150, personaje 34, economía 66, servidor 78, pareja 46, negocio 46, parcela 55; Lua 322.
Demos con xvfb: `ui_demo` 40, `polish2a_demo` 46, `polish2b_demo` 43, `polish2c_demo` 49 y
`polish3a_demo` 15. **No se corrieron** las demos que necesitan Nakama real (`server_demo`,
`economy_server_demo`, `couple_demo`, `couple_live_demo`, `login_demo`, `restaurant_demo`,
`parcel_server_demo`): en la nube no hay Docker ni Nakama; lo del servidor está cubierto por
las pruebas Lua. **Antes de usar el servidor: reiniciar Nakama** (`docker compose restart nakama`)
para que lea los módulos y `data/parcel.json` nuevos. Hay que correr esas demos en la PC.

## Fase actual: Pulido 2 (versión 0.9.0) — en la nube, rama `pulido-2`

Orden (lo pidió el dueño): **2A errores y claridad → 2B estilo y vida → 2C parcela,
servicios y entregas** (las tres listas). Cada sub-fase termina con pruebas en verde, commit y push
a `pulido-2`. Estado de cada una abajo.

### Pulido 2A — errores y claridad: HECHO (2026-11-04)
- **Techo "trabado"**: causa real encontrada y con prueba que la reproduce (un
  techo en un piso más alto que lo construido no tenía a dónde ir; o venía
  roto). Ahora todo piso con algo existe y lo roto se saca al cargar (teléfono
  y servidor). DECISIONES → "Pulido 2A".
- **Basurero**: borra TODO (techos, paredes, cimientos, pisos, muebles); lo que
  se apoyaba solo en la pieza cae con ella, todo en rojo y con confirmación.
- **Menú hamburguesa**: se cierra tocándolo otra vez o tocando afuera.
- **Sin piso fantasma**: **Agregar piso** es una opción aparte en Obra; avisa
  "Para agregar un piso tiene que haber una parte sin techo".
- **Selector de pisos de frente** (holograma azul, un color por piso, puerta y
  ventanas, punto parpadeante, flechas ↑↓ y girar de a 45°, recuerda el ángulo).
- **Obra** con tres modos con ícono: Construir (llave y martillo), Modificar
  (cruz de flechas) y Borrar (basurero).
- **Construcción planificada**: lo que agregás queda *previsto* y brilla cada
  3 s; **Factura** (qué se agrega, total, espera) → Confirmar → cobra y corre
  el tiempo (en pareja, antes aprueba ella). Descartar lo deshace.
- **Márgenes** arriba (34) y abajo (22) y **ángulo vertical de la cámara**
  (5 posiciones, botón a la izquierda).
- Pruebas: ver "Verificación" más abajo. Demo nueva `polish2a_demo` con capturas
  (`docs/capturas/p2a_*.png`).

### Pulido 2C — parcela, servicios y entregas: HECHO (2026-11-04) (más los sótanos, abajo)
- **Parcela de 96 × 96** (el doble hacia cada lado; la casa de antes queda en el centro y se
  migra sola, también en el servidor). Llena de **árboles, rocas, un laguito, tocones y
  maleza** (≈540, desde una semilla: teléfono y servidor generan **los mismos**) que
  **bloquean construir** hasta limpiarlos. Todo en `data/parcel.json`.
- **Limpiar**: tocás un obstáculo → «Llamar servicio» → **cobra el servidor** → espera real →
  llega el **jardinero / leñador** (el personaje va a abrirle la puerta) o la **cuadrilla con
  tractor / retroexcavadora** (necesita camino libre de 2 × 2 desde la calle; si no, «No puedo
  entrar»). Costos crecientes (× 1 + 0,02 por cada limpieza, tope × 3).
- **Servicios genéricos** (vehículo o persona, ruta, acceso, animación) y **ambulancia**:
  caída por una puerta al vacío de un piso alto → llega la ambulancia, lo curan (sin muerte
  ni pérdida de progreso).
- **Entrega de compras**: camión + repartidor, se le caen las cajas en la puerta, una caja en
  cada lugar, **«Abrir todas las cajas»** (humo blanco, tose) o las abre solo.
- Guardado **v4** (migración probada). Rendimiento: obstáculos en MultiMesh, red de caminos
  solo en la zona útil (≈100 ms para armarla).
- Pruebas nuevas: `test_parcel` (**40**), `polish2c_demo` y `parcel_server_demo` (**22**), y
  Lua **312** (los mismos obstáculos que el teléfono, caminos, costos, bloqueo al
  construir y migración de la parcela).

### Pulido 2C — verificación (nube: Godot 4.7.2, Nakama 3.41.0 + PostgreSQL 16 de prueba)
Sin red **460**: casa 150 (127 + 23 de sótanos), personaje 34, economía 66, servidor 78, pareja 46,
negocio 46 y parcela 40. Lua **312**. Demos: `server_demo` 24, `economy_server_demo` 39, `login_demo` 17,
`couple_demo` 78, `couple_live_demo` 12, `ui_demo` 40, `restaurant_demo` 32, `polish2a_demo` 46,
`polish2b_demo` 43, **`polish2c_demo` 49** y **`parcel_server_demo` 22**. Nakama reiniciado con los
módulos nuevos, sin errores. (Las demos que construyen en el servidor se adaptaron a la parcela de 96:
sus coordenadas pasaron a la zona del centro; si no, un obstáculo al azar podía bloquear una pieza.)

### Pulido 2C — cómo probarlo en el teléfono (para el dueño)
1. [Claude] Unir `pulido-2` a `main`, **reiniciar Nakama** (`docker compose restart nakama`
   en `server/`: lee `neighborhood_parcel.lua` y `data/parcel.json`; en los logs aparece
   «Parcela: 96 x 96 celdas») y exportar el APK 0.9.0. **Tu partida de 0.8.0 se migra sola**:
   la casa queda en el centro de la parcela nueva.
2. [Dueño] Instalar el APK. Al abrir: tu casa en el medio de una parcela enorme, con
   obstáculos alrededor (la zona de tu casa está libre).
3. Probá construir encima de un árbol: queda en rojo y dice «Ahí hay un obstáculo…».
4. Tocá una **maleza**: aparece qué servicio la limpia, cuánto cuesta y cuánto espera →
   **Llamar servicio** (cuesta $15 y tarda unos 20 s). Mirá: tu personaje va al portón de la
   calle, le abre y llega el jardinero; al terminar, la maleza desaparece y ya podés construir ahí.
5. Probá una **roca** (tractor) y el **laguito** (retroexcavadora). Para ver «no puede entrar»:
   cerrá con cimientos todo el frente de la parcela, llamá al servicio de una roca y esperá
   (aunque antes de llamar, la ventana ya avisa que no hay camino).
6. Comprá un mueble (Tienda). Cuando termine la obra llega el **camión**: al repartidor se le
   caen las cajas en la puerta y deja una en cada lugar. Tocá **Abrir todas las cajas**
   (abajo a la izquierda): el personaje las abre tosiendo entre humo. Si no tocás nada, a veces
   las abre solo.
7. **Ambulancia**: hacé un piso de arriba con una puerta que dé al vacío (sin balcón). En
   algún momento el personaje se asoma y se cae; llega la ambulancia y lo cura. Fijate que no
   perdés nada.
8. **FPS** (Menú → Info → Mostrar FPS) con la parcela completa, casa de dos pisos amueblada:
   meta 30+. Si baja, probá apagar el **contorno**; contame en cuántos FPS anda.
9. Decime si los precios de limpieza están bien (todo en `data/parcel.json`).

### Pulido 2C — pendientes y errores conocidos
- **No se midieron los FPS en un teléfono** (en la nube no hay GPU). Las obstrucciones y el
  bosque van en MultiMesh y la red de caminos se acotó a la zona útil, pero hay que verlo en el
  teléfono. Armar los caminos tarda ~100 ms en esta máquina; en el teléfono puede ser más.
- Las cajas y los servicios son **locales** (cada teléfono dibuja los suyos): con pareja, uno
  puede ver un camión y el otro no. El dinero y la limpieza sí son del servidor.
- Los servicios de limpieza solo se piden en **modo vivir** (o en construir sin herramienta).
- La ambulancia no se llama desde ningún lado más (no hay lesiones reales todavía).
- No se bajaron sonidos (ver 2B).

### Pulido 2C — sótanos: HECHO
- **Hasta 3 sótanos** (niveles −1 a −3; 5 pisos arriba). **Excavar antes de los cimientos**: pieza
  «Excavación (sótano)», $30 por celda y 90 s de espera; después cimientos, piso y paredes del
  sótano; escalera propia del sótano para llegar. **Obra → Agregar sótano**; el selector de frente
  y las flechas bajan hasta el sótano y el terreno se esconde bajo tierra.
- Niveles negativos en `HouseGrid`/`HouseData`, reglas de soporte en el juego **y en el servidor** (Lua),
  migración de las casas de 5 niveles. Pruebas: 23 nuevas en `test_house`, 12 Lua y la sección 7 de
  `polish2c_demo`.
- Cómo probarlo: Construir → **Obra** → **Agregar sótano** → ir al sótano (flecha ↓) → **Construir →
  Estructura → Excavación** (arrastrar) → confirmar → esperar 90 s (o acelerar) → **Cimientos** →
  piso y paredes. Para bajar: una **escalera** en el sótano.
- Pendiente: la retroexcavadora no se ve trabajando en la excavación (solo la espera de obra).

### Pulido 2B — estilo y vida: HECHO (2026-11-04)
- **Shader toon con contorno** (geometría invertida, grosor en píxeles, sombras
  duras en 3 tonos, luz cálida) en casa, muebles, personaje, vecinos, bosque y
  autos; suelo y calle sin contorno. **Todo editable en `data/style.json`** y los
  dos `.gdshader`. Menú → Info → **Contorno (calidad)** lo apaga. Primer
  `docs/estilo.md` con la paleta.
- **Cambio de arte sin tocar código**: una pieza del catálogo puede traer
  `model` (`.glb`) con respaldo a las figuras de ahora si no existe.
- **Entorno**: suelo de un solo color, **niebla** en los bordes (mismo color que
  el cielo), **bosque** atrás y a los costados (≈580 árboles en 3 llamadas de
  dibujo) y **7 casas de vecinos** atrás.
- **Trabajo como título**: sale por la puerta con **saco y maleta**, se despide con
  una nubecita y desaparece del lote; vuelve por la calle con otra animación
  (saltito). La pareja se ve igual por su intención.
- **Restaurante automático**: la caja se cobra sola (el servidor calcula por
  tiempo, al entrar y cada rato); el minijuego es un **Reto opcional** con
  premio extra; **Mesero** y **Cocinero** como empleos sin tener restaurante.
  Contratar personal/sueldos: solo diseño en `VISION.md`.
- **Vida**: autos y gente en la calle (solo local), reposo del personaje
  (respira, mira alrededor), hojitas que caen, humo blanco, ganchos de sonido con
  volúmenes en Info.
- Demo nueva `polish2b_demo` (43 comprobaciones, capturas `docs/capturas/p2b_*.png`)
  y 6 pruebas Lua nuevas (cobro automático).

### Pulido 2B — verificación (nube)
Sin red: casa 127, personaje 34, economía 66, servidor 78, pareja 46, negocio 46
= **397**. Lua **281** (275 + 6 nuevas del cobro automático y los empleos de
restaurante). Demos: `server_demo` 24, `login_demo` 17, `couple_demo` 78,
`couple_live_demo` 12, `ui_demo` 40, `restaurant_demo` 32, `polish2a_demo` 46 y
**`polish2b_demo` 43** (nueva). `economy_server_demo` 35/39 igual que en `main`
(ver 2A). Nakama reiniciado con los módulos nuevos, sin errores.

### Pulido 2B — cómo probarlo en el teléfono (para el dueño)
1. [Claude] Con la rama unida: reiniciar Nakama (`docker compose restart nakama`
   en `server/`: toma el cobro automático y los empleos nuevos) y exportar el APK.
2. [Dueño] Instalar el APK. Al abrir, el mundo se ve **dibujado**: contorno
   oscuro fino, sombras en 3 tonos.
3. Mirá el borde del mapa (alejá la cámara y bajala con el botón del ángulo):
   **no se ve dónde termina** la calle ni hay costados azules: hay niebla y
   **bosque**; atrás, **casas de vecinos**.
4. Por la calle pasan **autos y gente**; caen hojitas en el jardín.
5. **Menú → Info → Contorno (calidad)**: apagalo y fijate si sube el FPS (meta
   30+ con una casa de dos pisos amueblada). Ahí también están los **volúmenes**.
6. **Menú → Empleos**: probá **Mesero** o **Cocinero** (nivel 2 y 3). Cuando
   empiece el turno el personaje sale **con saco y maleta**, se despide con una
   nubecita y no está en la casa; al terminar vuelve caminando desde la calle.
7. **Menú → Restaurante** (con restaurante abierto): ahora dice «Ingreso
   automático» y se cobra solo («El restaurante te dio $X»); «Reto: Servicio»
   es el minijuego opcional con premio extra.
8. Con tu pareja: cuando uno sale a trabajar, el otro lo ve salir con saco y
   maleta y desaparecer.
9. **Pendiente tuyo (sonidos)**: si querés sonidos, bajá un paquete CC0 (por
   ejemplo Kenney «Interface Sounds» / «Impact Sounds»), copiá los `.ogg` a
   `assets/audio/` con los nombres `build`, `cancel`, `coin`, `level_up`,
   `error`, `door`, `step`, `truck`, `box_open`, `cough`, `siren`, `car_pass`, y
   anotá la licencia en `docs/`. No hay que tocar código.

### Pulido 2A — verificación (nube, Godot 4.7.2, Nakama 3.41.0 + PostgreSQL 16 de prueba)
Sin red: casa **127** (99 + 28 nuevas), personaje 34, economía 66, servidor 78,
pareja 46, negocio 46 = **397**. Lua **275** (273 + 2). Demos: `server_demo` 24,
`login_demo` 17, `couple_demo` 78, `couple_live_demo` 12, `ui_demo` 40,
`restaurant_demo` 32, **`polish2a_demo` 46** (nueva, capturas `docs/capturas/p2a_*.png`).
**Ojo:** `economy_server_demo` da 35/39 en esta máquina de la nube **también en
`main` sin ningún cambio** (se probó con un `git worktree` de `6e96076`): falla
el turno de trabajo con el reloj a x5 (depende de la velocidad de la máquina).
No es de esta tanda; en la PC del dueño pasaba 39/39. Verificar allá.

### Pulido 2A — cómo probarlo en el teléfono (para el dueño)
1. [Claude] Unir `pulido-2` a `main`, reiniciar Nakama (`docker compose restart
   nakama` en `server/`) y exportar el APK 0.9.0 (cuando lo pidas).
2. [Dueño] Instalar el APK.
3. Tocá **☰**: se abre. Tocá **☰** otra vez (o afuera): se cierra.
4. Los íconos de arriba y abajo tienen más aire; el botón del **ángulo** (a la
   izquierda, junto a techo y paredes) recorre 5 inclinaciones, de frente a
   desde arriba.
5. Construir → **Obra**: ahora hay **Construir / Modificar / Borrar** (íconos) y,
   al lado, **Agregar piso**.
6. Con la casa toda techada, **Agregar piso** dice "Para agregar un piso tiene
   que haber una parte sin techo". Sacá un pedazo de techo y probá de nuevo.
7. A la izquierda: el **frente de la casa** en azul. Tocá un piso para ir;
   usá ↑ ↓ y ← → (girar). Cerrá el juego y abrilo: recuerda el ángulo.
8. **Borrar**: probá techos (también viejos), paredes, pisos y cimientos. Si
   algo sostiene otra cosa, la pregunta lo dice y se pone todo en rojo.
9. **Construir** una pared o piso: queda *previsto* (brilla). Aparece arriba
   "Obra prevista" → **Factura**. Probá Seguir planeando, Descartar y
   Confirmar y construir (cobra y empieza la espera).
10. Si algún techo viejo seguía "trabado": al abrir esta versión debería
    poder borrarse; si no, avisame cuál era (piso y dónde).

## Fase actual: 6 — Primer negocio: restaurante (verificada en la PC; falta probarla en el teléfono)

**Fase 6 verificada en la PC (2026-11-04).** Rama `fase-6` unida a `main`.
Nakama reiniciado sin errores (45 piezas, 5 módulos). Sin red 369/369, Lua
273/273, demos: servidor 24, economía 39, entrada 17, pareja 78, pareja en
pantalla 12, interfaz 40, restaurante 32/32 (capturas revisadas). Partida del
dueño intacta. APK 0.8.0 en `build/neighborhood.apk`.

**Pendiente anotado (2026-11-03):** `docs/pulido-2.md` = lo que notó el dueño
con el APK 0.7.0 (techos que no se borran, basurero, menú que no se cierra,
selector de pisos con el frente de la casa, construcción con factura y
entrega, servicios, parcela más grande, sótanos, niebla, cámara). **Orden:**
Fase 6 (en la nube, rama `fase-6`) → el dueño prueba su APK y manda feedback
→ Pulido 2 = esta lista + ese feedback.

**Próximo paso (después del Pulido 2):** el dueño prueba el APK 0.9.0 en el teléfono (checklists de 2A, 2B y 2C) y manda su feedback. Después: **Pulido 2** (`docs/pulido-2.md`
+ ese feedback). Siguen pendientes las pruebas de la Fase 5 y del Pulido 1 en
los teléfonos.

### Fase 6 — hecho (2026-11-04, sesión en la nube, rama `fase-6`)
- **6A — servidor** (commit "Fase 6A"): `neighborhood_business.lua` (sin
  Nakama, probado con `lua5.1`): restaurante del hogar, qué le falta, caja que
  junta sola ($20/h hasta $160), servicio con **semilla del servidor**, revisión
  de toques y **el servidor repite el servicio** para saber cuánto pagar, tope
  de **$600 cada 24 h**. 6 RPC nuevas; abrir/cerrar en la casa compartida es un
  **pedido** que aprueba la pareja. Datos en `data/business.json`; muebles
  nuevos (Mostrador, Plancha de restaurante, Mesa de restaurante, Banquito,
  categoría "Restaurante" en la Tienda) y el cuarto "Restaurante" en `rooms.json`.
- **6B — teléfono**: `RestaurantSim` (copia exacta de la simulación),
  autoload `Restaurant`, **Menú → Restaurante** (abrir, cobrar caja, Atender,
  Practicar), el minijuego **"Servicio"** (1:30, táctil, figuras dibujadas),
  servicio sin cobrar guardado si se corta la conexión (se manda solo al
  volver), pedidos del restaurante en Menú → Casa (sin "Ver").
- Versión **0.8.0** (también en `export_presets.cfg`: el APK ya dice 0.8.0).
- Pruebas (en la nube: Godot 4.7.2, Nakama 3.41.0 + PostgreSQL 16 de prueba):
  sin red **369** (99 casa + 34 personaje + 66 economía + 78 servidor + 46
  pareja + **46 restaurante**), Lua **273** (214 + 59 nuevas), demo nueva
  **`restaurant_demo` 32/32** (con capturas `restaurante_1` a `_7` en
  `docs/capturas/`), y las demos de antes: `server_demo` 24/24, `economy_server_demo` 39/39,
  `login_demo` 17/17, `couple_demo` 78/78, `couple_live_demo` 12/12, `ui_demo` 40/40.
  No se exportó el APK (lo pidió así la tarea).

### Fase 6 — cómo probarlo en el teléfono (para el dueño)
1. [Claude] Traer la rama `fase-6` (o el `fase-6.bundle`), unirla a `main`,
   reiniciar Nakama (`docker compose restart nakama` en `server/`: tiene que
   leer el módulo nuevo y `business.json`; en los logs aparece
   "Restaurante: servicio de 90 s, tope diario $600"), correr las pruebas y
   exportar el APK 0.8.0.
2. [Dueño] Instalar el APK (como siempre).
3. Construir → **Tienda → Restaurante**: en tu parcela, al lado de la casa,
   armá un edificio (cimientos, piso, paredes, puerta) y poné un
   **Mostrador**, una **Plancha de restaurante** y 1 a 3 **Mesas de
   restaurante**. Con la cámara mirando ese edificio, la Tienda muestra
   primero "★ Restaurante".
4. Esperá la obra de la plancha (45 s) o acelerala.
5. **Menú → Restaurante** → **Abrir restaurante**. Tiene que decir "Abierto ·
   N mesas".
6. **Atender (1:30)**: cuenta 3-2-1 y llegan clientes. Tocá los
   ingredientes del globito; tortita y huevo van a la plancha: cuando
   brillan, tocalos. Tocá al cliente para servirle. Al final: "Cobraste $X"
   y el dinero de arriba sube eso.
7. Probá equivocarte (le servís otra cosa: "¡Eso no pedí!") y dejar quemar
   algo en la plancha (tocá para tirarlo).
8. Cerrá el juego en medio de un servicio y volvé a entrar a los 2 minutos:
   aparece "Servicio: cobraste $X" solo (lo que alcanzaste a servir).
9. **Practicar** con el wifi apagado: se juega igual, dice "Práctica".
10. Al otro día (o después de unas horas): Menú → Restaurante → **Cobrar
    caja** (lo que juntó solo, hasta $160).
11. [Con tu pareja, viviendo juntos] Cerrar el restaurante → dice "Le
    pediste permiso…"; en el otro teléfono Menú → Casa → **Aprobar**.
12. Medir los FPS durante el servicio (Menú → Info → Mostrar FPS). Meta: 30+.
13. Decime si el juego es muy fácil o muy difícil, y si la plata está bien:
    todo se cambia en `data/business.json`.
14. [Claude] Corregir lo que salga; commit "Fase 6 cerrada".

### Fase 6 — pendientes y errores conocidos
- El piso de color del restaurante de la demo se ve casi blanco con la luz
  (la baldosa es clara); es solo la demo.
- Los clientes del minijuego no aparecen en la casa 3D (solo en la pantalla
  del minijuego); el personaje no camina al mostrador al atender.
- "Declarar zonas" de la parcela (qué edificio es casa y cuál negocio) no se
  hizo: el restaurante es "los muebles de restaurante de la parcela"
  (DECISIONES, "Restaurante").
- Un programa que juegue perfecto a velocidad humana gana lo máximo por
  servicio; lo frena el tope diario.
- La caja del restaurante solo junta mientras está abierto; si se le saca un
  mueble necesario, sigue juntando pero no se puede cobrar hasta volver a
  ponerlo.
- El jugador automático de la demo atiende a casi todos: es más fácil que
  para una persona. Falta medir con gente de verdad (punto 13).

## Pulido 1 — interfaz limpia y constructor 2.0 (hecho y verificado en la PC; falta probarlo en el teléfono)

### Pulido 1 — hecho (2026-11-03, sesión local en la PC del dueño, rama `pulido-1`)
- **P1A — interfaz** (commit "Pulido 1A"): pantalla casi vacía con 42 íconos
  SVG propios (`assets/icons/`). Arriba dinero y **ánimo** (carita + palabra;
  tocarlo abre las necesidades con barra y qué afecta el ánimo). Pareja chica
  (● nombre). **Menú → Info** con FPS (y "Mostrar FPS en pantalla"), versión,
  conexión, día y hora, caja y pareja. A la izquierda: íconos de **techo** y
  **paredes**, la **maqueta 3D de pisos** (tocar = ir a ese piso; punto que
  parpadea = el personaje) y la **brújula**. Velocidades **x1, x2, x5** (en el
  juego y en el servidor, sin ventaja) y **5 pisos** (juego y servidor).
- **P1B — constructor 2.0**: **Tienda / Obra (Agregar · Modificar) / Borrar**.
  Borrar con resaltado y pregunta ("te devuelven $X"), **modo selección** y
  arrastrar para muchas. Modificar: flechas **N/S/E/O**, girar de a **45°**
  (8 direcciones, sin encimarse), mantener para llevar con el dedo, menú en
  paredes / techos / pisos / cimientos. **Pintura por cara** (tocar = una
  cara + flechas izquierda/derecha; mantener = pintar arrastrando solo paredes
  o solo pisos). **Unión de ventanas en la juntura** (puntito para unir o
  separar). **Techo plano de concreto**; techo bloqueado si lo atraviesa algo
  de arriba. Escaleras **de caracol** y **metálica exterior**; **pilares**;
  "Esta pared sostiene el piso de arriba"; **"Falta: N"** (sin acceso / sin
  apoyo, en rojo); **Copiar contorno de abajo**; **cuartos** con tipo según
  los muebles (`data/rooms.json`) y la Tienda que recomienda (★). **Casa
  compartida: propuesta** entera que la pareja ve en su casa y aprueba o no.
- Guardado **v3** (migración: pintura a las dos caras, ventanas unidas en la
  juntura) y la misma conversión en el servidor. Versión **0.7.0**.
- Pruebas (en la PC, Godot 4.7.2, contra un **Nakama 3.41.0 de prueba aparte**
  en 127.0.0.1:7360 con PostgreSQL 18 en memoria, para no tocar el servidor ni
  las cuentas del dueño; se borró al terminar): sin red **323 (99 casa + 34 personaje + 66 economía + 78 servidor + 46 pareja)**,
  Lua **214**, `server_demo` 24/24, `economy_server_demo`
  39/39, `login_demo` 17/17, `couple_demo` 78/78 (con la propuesta entera),
  `couple_live_demo` 12/12, y la demo nueva **`ui_demo` 40/40** (con
  capturas `ui_1` a `ui_11`, copiadas en `docs/capturas/`). No se exportó el APK (lo pidió así la sesión).

### Pulido 1 — verificado por la sesión principal (2026-11-03)
Unido a `main`. Nakama del dueño reiniciado sin errores (41 piezas). Sin red
323/323, Lua 214/214, `server_demo` 24/24, `economy_server_demo` 39/39,
`login_demo` 17/17, `couple_demo` 78/78, `couple_live_demo` 12/12, `ui_demo`
40/40 (capturas revisadas). Partida del dueño intacta. APK 0.7.0 exportado en
`build/neighborhood.apk`.

### Pulido 1 — cómo probarlo en el teléfono (para el dueño)
1. [Claude, cuando lo pidas] Unir la rama `pulido-1` a `main` y exportar el
   APK 0.7.0 (`build/neighborhood.apk`). **Ojo**: el Nakama de la PC lee los
   módulos de esta carpeta: hay que reiniciarlo (`docker compose restart
   nakama` en `server/`) para que tome x5, 5 pisos y las reglas nuevas.
2. [Dueño] Instalar el APK (como siempre: pasarlo al teléfono y tocarlo).
3. Al entrar: arriba solo se ve **dinero** y **ánimo** (carita + palabra), a la
   izquierda la **maqueta** de pisos con dos íconos encima y la **brújula**, y
   arriba a la derecha velocidad, casco y menú.
4. Tocá el **ánimo**: aparecen las 4 necesidades con su ícono y barra, y "Qué
   afecta el ánimo". Tocá afuera: se cierra.
5. **Menú → Info**: se ven los FPS. Prendé "Mostrar FPS en pantalla" y medí
   con una casa de dos pisos amueblada (meta: 30 o más).
6. Tocá el **casco** (construir). En la maqueta, tocá el piso de arriba: sube.
   Probá los íconos de techo (tachado) y paredes (alta / bajita).
7. **Obra → Modificar (mano)** → elegí un color → tocá una pared **por
   dentro**: se pinta solo esa cara (mirá por afuera: sigue igual). Usá las
   flechas para pintar la de al lado.
8. **Borrar** → tocá un techo (con los techos a la vista): se pone rojo y
   pregunta "¿Borrar el techo? Te devuelven $X". Confirmá.
9. **Tienda** → Silla → tocá el botón de girar una vez (45°) → ponela: queda
   en diagonal. Probá que no se puede encimar otra cosa.
10. **Borrar** → tocá una pared que tiene piso arriba apoyado solo en ella
    (un balcón): dice "Esta pared sostiene el piso de arriba".
11. En el piso 1 (sin nada), **Obra → Agregar** → **Copiar contorno de
    abajo** → Confirmar: se arma la losa y las paredes. Arriba aparece
    "Falta: 1" (sin acceso) hasta que pongas una escalera abajo.
12. Con la cámara sobre un cuarto con cama, **Tienda**: la primera pestaña es
    "★ Dormitorio" con camas primero.
13. [Con tu pareja, viviendo juntos] Poné una pared: queda como propuesta
    (arriba "Mandar a …"). Agregá otra y mandala. En el otro teléfono:
    **Menú → Casa → Ver** → se ve en la casa → **Aprobar**.
14. [Claude] Corregir lo que salga; commit "Pulido 1 cerrado".

### Pulido 1 — pendientes y errores conocidos
- Las piezas nuevas (escaleras, pilar, techo plano, plantas...) tienen formas
  provisionales (cajas), como todo hasta la Fase 7.
- Una escalera de caracol se camina como una recta (sube "en zigzag" por sus
  4 celdas); se ve bien, el recorrido es aproximado.
- "Mover" una pared con las flechas la corre de a una celda; si sostiene
  algo, no se puede (avisa).
- La onda de "pintar arrastrando" es un anillo blanco en el piso (simple).
- Si la pareja cambia algo mientras ves una propuesta, te pones al día al
  cerrarla (no antes).
- ~~`export_presets.cfg` sigue con versión "0.0.1"~~ (arreglado en la Fase 6:
  0.8.0, código 8).
- Los avisos de abajo del menú de arriba se apilan y a veces quedan dos a la
  vez ("Elegí Tienda, Obra o Borrar" + otro); visto en las capturas.

## Fase 5 — Pareja y casa compartida (verificada en la PC; falta probarla en dos teléfonos)

### Fase 5 — hecho (2026-11-03, sesión en la nube, rama `fase-5`)
- **5A — servidor** (`server/nakama/modules/`): reglas de apoyo de la casa en
  el servidor (`neighborhood_house.lua`, copia de `house_rules.gd`); relación
  (`neighborhood_couple.lua`: invitar, aceptar, en pareja, matrimonio, mudarse,
  terminar; interruptores de drama y modo familiar, preparados); casa
  compartida en `neighborhood_rules.lua` (caja, aportes, unir ingresos,
  historial, pedidos, deshacer lo del otro, deshacer que no pisa lo del otro).
  13 RPC nuevas y avisos en tiempo real (101/103/104).
- **5B — teléfono**: `RealtimeSocket` (WebSocket propio con Nakama: presencia,
  estado = intención del personaje, avisos, reconexión), autoload `Couple` +
  `CoupleState`, la casa se pone al día sola (solo lo que cambió), paneles
  **Menú → Pareja** y **Menú → Casa**, indicador "Pareja: X ● en línea ·
  cocinando", aviso con **Deshacer**, botón **Pedir permiso**.
- **5C — el personaje de la pareja** en la casa compartida: hace lo que dice
  su intención (camina al mueble y hace la acción) o, fuera de línea, vive con
  su IA; no usa el mueble que usa el otro. Sueldo a la caja con "unir ingresos".
- Pruebas (en la nube, Nakama 3.41.0 + PostgreSQL 16): Lua **188** (80 + 108),
  sin red **277** (231 + 46 de `test_couple`), `server_demo` 24/24,
  `economy_server_demo` 39/39, `login_demo` 17/17, **`couple_demo` 69/69**
  (dos cuentas a la vez) y **`couple_live_demo` 12/12** (con ventana y capturas).
- Versión del juego 0.6.0. Docs: DECISIONES ("Pareja y casa compartida"),
  `docs/servidor.md`, README. No se exportó el APK (no hay SDK en la nube).

### Falta para cerrar la Fase 5
**En la PC: verificado (2026-11-03, sesión local).** Rama `fase-5` unida a
`main`. Nakama reiniciado sin errores (lee los 4 módulos y el catálogo).
Pruebas sin red 277/277, Lua 188/188, `server_demo` 24/24,
`economy_server_demo` 39/39, `login_demo` 17/17, `couple_demo` 69/69,
`couple_live_demo` 12/12 (capturas revisadas: B cocina, paneles bien). La
partida del dueño quedó intacta. APK 0.6.0 exportado en `build/neighborhood.apk`.

**En dos teléfonos** (o un teléfono y el juego en la PC con F5: sirven como
dos jugadores), en la red de casa, con dos cuentas:
5. Cuenta 1 → Menú → Pareja → invitar a la cuenta 2. En el otro aparece el
   aviso; aceptar. Arriba los dos ven "Pareja: … ● en línea".
6. Mientras uno cocina o duerme, el otro ve el texto ("cocinando (Cocina)").
   Cerrar el juego en uno: el otro lo ve "fuera de línea" en segundos.
7. Proponer casamiento y aceptar. Después "Vivir juntos en mi casa" y aceptar:
   el que se mudó ve la casa del otro; los dos ven los DOS personajes, y el de
   la pareja hace lo mismo que en su teléfono.
8. Cambio menor: uno mueve un mueble → al otro le aparece arriba "X movió:
   Sofá [Deshacer]"; tocar Deshacer lo devuelve.
9. Cambio estructural: uno pone una pared → el botón dice "Pedir permiso"; el
   otro va a Menú → Casa y aprueba (o no). Se construye en los dos.
10. Menú → Casa: aportar $100 a la caja; poner un mueble (sale de la caja);
    prender "Unir ingresos" y esperar un turno (el sueldo va a la caja).
11. Los dos mueven el mismo mueble casi a la vez: los dos teléfonos terminan
    iguales.
12. Con el wifi apagado en uno: se puede vivir, no construir; al volver se
    pone al día solo.
13. Terminar la relación: cada uno en su casa, la caja repartida.
14. Medir los FPS con los dos personajes en una casa de dos pisos (≥ 30).
15. [Claude] Corregir lo que salga; commit "Fase 5 cerrada"; unir a `main`.

### Preguntas para el dueño
- ¿Tu pareja usa Android o iPhone? (VISION). Si es iPhone, para probar ahora
  sirve el juego en la PC como segundo jugador.
- ¿Van a jugar menores? Por ahora el modo familiar viene prendido y el drama
  apagado.

### Pendientes nuevos (Fase 5)
- Si la pareja cambia su look, mi teléfono lo ve la próxima vez que pregunta
  (al abrir Pareja/Casa, al reconectar o con cualquier aviso), no al instante.
- La necesidad "Social" y que los dos personajes interactúen (charlar) no se
  hicieron: la fase no lo pedía.
- Un mueble nuevo es "cambio menor"; vender (quitar) es estructural. Si en la
  prueba molesta pedir permiso para quitar algo que uno mismo puso por error,
  se puede usar Deshacer (no pide permiso) o cambiar la regla.
- Cualquier cuenta del servidor podría ver el "estado" (qué hace el personaje)
  de otra si conoce su id: para la familia no importa.

## Fase anterior: 4 — Cuentas y servidor (4A y 4B hechas; falta probarlas en la PC del dueño y en el teléfono)

### Fase 4B — hecho (2026-11-03, en una sesión en la nube, rama `fase-4b`)
- **El servidor manda en el dinero y la propiedad.** Reglas en
  `server/nakama/modules/neighborhood_rules.lua` (sin Nakama, se prueban
  solas) y 13 RPC nuevas en `neighborhood.lua`: construir (`build_apply`:
  precio del mismo catalog.json, nivel, obra con la hora del servidor,
  experiencia), deshacer/rehacer (100 pasos, devuelve lo exacto), acelerar
  obras y currículos, empleos, turnos (reglas x10), pago al entrar (turno a
  medias + días sin jugar, tope 3) y "sigo jugando".
- Dinero en la **billetera de Nakama**; casa, progreso, empleo e historial en
  storage que solo escribe el servidor, todo guardado junto (`multi_update`).
- Transición 4A → 4B: las cuentas importadas en la 4A re-sincronizan UNA vez
  casa, experiencia, descubierto y empleo (el dinero queda en $3000).
- Cliente: `Economy` en "modo servidor" (un pedido por vez, sin dobles
  toques), `UndoHistory` remoto, `HouseBuilder` espera al servidor, el
  personaje anota y cobra sus turnos en el servidor, panel de empleos, HUD.
  **Sin conexión: Construir apagado** con el aviso "Sin conexión al
  servidor"; se sigue viviendo. La economía local queda como "modo de prueba".
- Pruebas: 53 casa + 34 personaje + 66 economía + **78 servidor** (sin red)
  + **80 de reglas en Lua**, todas OK. Contra un Nakama 3.41.0 de verdad (en
  la nube, con PostgreSQL 16): `server_demo` 24/24, **`economy_server_demo`
  39/39** (nueva: incluye un turno hecho por el personaje dentro del juego),
  `login_demo` 17/17 (con ventana: construir, deshacer y rehacer con el
  servidor; sin conexión no deja construir; al volver la conexión con el
  juego abierto, carga la partida del servidor y deja construir). Demos locales (economía,
  personaje, visual) OK. Re-sincronización 4A → 4B probada a mano.
- Versión del juego 0.5.0. Docs: `docs/servidor.md`, README, DECISIONES.

### Verificado en la PC del dueño (2026-11-03)
- Rama `fase-4b` traída desde `fase-4b.bundle` (la nube no tenía permiso de
  escritura en GitHub) y unida a `main`.
- Nakama reiniciado con su Docker (`postgres:18`): lee el catálogo (32 piezas,
  3 empleos, 6 niveles) y arranca sin errores.
- Pruebas: 231 sin red, todas OK. Contra el servidor real: `server_demo`
  24/24, `economy_server_demo` 39/39, `login_demo` 17/17.
- `login_demo` fallaba 2/17 en la PC: una carrera de la propia demo (un
  pedido del paso 2 contestaba tarde, ya en el paso 3 "sin servidor").
  Arreglado: la demo espera a que terminen los pedidos pendientes.
- APK 0.5.0 exportado.

### Falta para cerrar la Fase 4
1. [Dueño] Instalar el APK 0.5.0. Probar en la red de casa: al
   entrar, la casa de las pruebas de la 4A sigue ahí (re-sincronización) y el
   dinero es $3000; construir cobra; deshacer devuelve; acelerar; currículum;
   un turno; con el wifi apagado "Construir" queda apagado y se puede vivir;
   al volver el wifi, todo anda de nuevo.
4. [Dueño] En la consola (127.0.0.1:7351): la billetera de su cuenta y su
   "Wallet Ledger" muestran cada cobro.
5. [Claude] Corregir lo que salga; commit "Fase 4 cerrada".

### Fase 5
Hecha (arriba). La Fase 4 se prueba junto con la 5 en los teléfonos.

### Fase 4A — hecho (2026-11-03)
- Servidor en `server/` (Docker): `neighborhood-nakama` (Nakama 3.41.0) y
  `neighborhood-db` (PostgreSQL 18). Andando y comprobado: 7350 responde en
  127.0.0.1 y 192.168.100.177; la consola 7351 solo en 127.0.0.1; la base sin
  publicar. Secretos en `server/.env`, datos en `server/db-data/` (fuera de Git).
  El servidor lee el mismo `data/catalog.json`.
- Módulo Lua `neighborhood.lua`: RPC `game_load` y `game_import` (importación
  única: casa, experiencia, descubierto, personaje, opciones; dinero $3000 en la
  billetera de Nakama). Casa y progreso solo los escribe el servidor.
- Cliente propio `GameServer` (autoload, REST): crear cuenta / entrar con
  usuario y contraseña, sesión recordada (`user://session.json`, sin
  contraseña, se renueva sola), indicador "● Conectado / Sin conexión",
  subida de personaje y opciones a la nube, "Cerrar sesión" en el Menú.
  Dirección en `data/server.json`. Lógica pura en `ServerSession` y `CloudSync`.
- Pantalla de entrada (`ui/login_screen.tscn`, ahora es la escena que arranca)
  con "Jugar sin conexión" si no hay servidor.
- Pruebas: 53 casa + 34 personaje + 66 economía + **51 servidor** (sin red),
  todas OK. Demos contra el servidor real: `tests/server_demo.tscn` 24/24 y
  `tests/login_demo.tscn` 7/7 (con capturas).
- Guía `docs/servidor.md`. Bitácora del equipo actualizada. APK 0.4.0
  exportado (con permiso INTERNET).

### Falta para cerrar la 4A
1. [Dueño] Instalar el APK y probar en el teléfono, en la red de casa:
   crear cuenta, ver "Conectado", cerrar y abrir (entra solo), y con el wifi
   apagado ("Jugar sin conexión"). Se puede probar junto con la 4B (arriba).

### Fase 4 — plan original (2026-11-03)
- **4A — servidor y cuentas**: hecha (arriba).
- **4B — servidor autoritativo**: hecha (arriba).

### Fase 3 (estado anterior)

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
- Servidor: al reiniciar la PC, Nakama puede no engancharse a la IP de la LAN
  (como AdGuard); si pasa, un servicio que espere la IP (pregunta al dueño).
- Servidor: respaldo de `server/db-data` (volcado `pg_dump` en el respaldo)
  antes de jugar en serio. "Recuperar contraseña" no existe todavía.
- Servidor (4B): las reglas de apoyo de la casa (pisos, paredes "en el aire")
  siguen solo en el teléfono; pasan al servidor en la Fase 5 (edición entre dos).
- Servidor (4B): si la sesión se invalida con el juego abierto (por ejemplo,
  se borra la cuenta desde la consola), el juego no vuelve solo a la pantalla
  de entrada: cada pedido avisa "Hace falta entrar con una cuenta".
- Servidor (4B): sin conexión el personaje no sale a trabajar (el servidor
  tiene que anotar el turno); esos días se pagan al volver (tope 3).
- Android 16+ podría pedir permiso de "red local" para hablar con la PC: si el
  teléfono no conecta en casa, es lo primero a revisar.

.

### Preguntas abiertas para el dueño
- ¿Horizontal te parece bien? (ver DECISIONES.md, "Orientación").
- ¿Tu pareja usa Android o iPhone? (VISION.md)

## Fases siguientes
- Fase 7 — Arte y estilo (Sonnet alcanza). Antes: probar las Fases 5 y 6 y el
  Pulido 1 en los teléfonos.
