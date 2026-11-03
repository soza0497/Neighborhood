# Decisiones del proyecto

Cada decisión: qué se eligió, por qué, y qué costaría cambiarla.
Lo marcado **(pregunta)** necesita tu visto bueno antes de cambiarse.

## Motor y versión

- **Godot 4.7.2 stable**, el paquete `godot` de los repos de CachyOS
  (`4.7.2.stable.arch_linux`). **(pregunta)** No se cambia de versión sin
  preguntarte.
  - Riesgo conocido: como viene de pacman, una actualización del sistema
    puede subir Godot (por ejemplo a 4.7.3 o 4.8). Las plantillas de
    exportación tienen que ser de la **misma** versión exacta; si Godot se
    actualiza, hay que descargar las plantillas nuevas. Un salto 4.7 → 4.8
    se pregunta antes de abrir el proyecto con él. Si molesta, la salida es
    fijar el paquete en pacman (`IgnorePkg`), cambio de sistema aparte.
- **GDScript** (no C#): más simple, exporta a Android sin pasos extra.

## Pantalla y gráficos

- **Orientación horizontal** (`sensor_landscape`: gira sola entre las dos
  horizontales). Por qué: un constructor de casas y una vista aérea de barrio
  necesitan ancho; la barra inferior de categorías cabe mejor; los juegos de
  construir del estilo son horizontales. Cambiarla después obliga a rehacer la
  interfaz, así que conviene decidirlo ya: si preferís vertical, decímelo.
- **Resolución base 1280×720**, escalado `canvas_items` + `expand`: la
  interfaz se adapta a cualquier pantalla sin bandas negras.
- **Renderizador "Mobile"** (Vulkan), pensado por Godot para teléfonos.
  Si el teléfono no tiene Vulkan, Godot pasa solo al modo "Compatibility"
  (OpenGL). Se mide en la Fase 1–2 con una casa llena; cambiarlo es una línea
  en `project.godot`.
- **Cámara en perspectiva con lente cerrada (35°)**, inclinada 50° hacia
  abajo, en lugar de isométrica pura (ortográfica): se ve más "juguete" y el
  zoom por distancia se siente natural. Ajustable en `camera_rig.tscn`.
- **Unidad: 1 metro = 1 unidad de Godot.** Terreno de prueba de 44×44 m,
  la cámara no sale de ±20 m.

## Controles

- 1 dedo arrastra (se "agarra" el suelo), 2 dedos pellizcan para zoom y giran.
  Mouse: izquierdo arrastra, derecho gira, rueda hace zoom.
- La cámara usa `_unhandled_input`: los botones reciben el toque primero.
- Los eventos de mouse que Godot fabrica a partir de toques se ignoran en la
  cámara (si no, cada arrastre contaría doble).

## Datos y guardado

- **Catálogo en JSON** (`data/catalog.json`), no `.tres`. Por qué: se edita
  con cualquier editor de texto y, desde la Fase 4, el servidor (Nakama)
  puede leer **el mismo archivo** para validar precios. Godot lo valida al
  arrancar y avisa en la consola.
- **Guardado local en JSON** (`user://save.json`) con `format_version`.
  Se escribe a un `.tmp` y se renombra (no se corrompe si se corta a mitad).
  Se guarda al pasar a segundo plano en Android y al cerrar en la PC.
- Patrón de guardado: `SaveSystem` emite `EventBus.game_saving`; cada sistema
  copia su estado a `GameState`; luego se escribe. `GameState` solo guarda
  datos, no tiene lógica.

## Android

- **Exportación sin Gradle** (la normal de Godot). No necesita NDK ni CMake
  (~3 GB menos). Se activa Gradle solo si un plugin lo exige.
- **Solo arm64-v8a** (64 bits): todos los Android de gama media desde ~2017.
  APK más chico. Si un teléfono viejo de la familia no instala, se agrega
  `armeabi-v7a`.
- **Nombre de paquete `com.sozasanchez.neighborhood`**. Se puede cambiar
  libremente hasta publicar en la tienda; después ya no.
- **SDK de Android desde Android Studio (Flathub)**: Flathub va antes que el
  AUR en el orden de instalación de esta PC, y su gestor del SDK tiene
  ventanas. El Flatpak tiene acceso al home, así que el SDK queda en
  `~/Android/Sdk`, donde Godot lo busca.
- **JDK 17 de pacman** (`jdk17-openjdk`): la versión que recomienda Godot.
  El Java que trae Android Studio vive dentro del Flatpak y Godot no lo ve.

## Git

- Rama `main`. Se versionan los `.uid` que crea Godot (lo recomienda Godot
  4.4+); se ignoran `.godot/`, `build/` y los APK.

## Constructor de casas (Fase 1)

- **Cuadrícula de 1 × 1 m, lote de 12 × 12 celdas, 2 niveles** (planta baja
  + primer piso). Constantes en `scripts/house/house_grid.gd`: cambiar
  `MAX_LEVELS` o `LOT_SIZE` es una línea (las casas guardadas siguen sirviendo).
- **Paredes en los bordes entre celdas**, no dentro de las celdas. Las
  esquinas se tapan solas con una columna en cada vértice que toca una pared.
- **Cimientos obligatorios**: la planta baja va 30 cm sobre el pasto, y
  pisos y paredes de abajo se apoyan en cimientos. Así todas las alturas son
  fijas y simples. Arriba, el piso va sobre piso **o junto a una pared de
  abajo** (pedido del dueño: poner el piso primero; también permite balcones
  de una celda), y la pared sobre piso o pared.
- **Puertas y ventanas son parte de la pared** (campo `opening`), no piezas
  aparte: una pared tiene a lo sumo una. Si se borra la pared, se va con ella.
  La puerta llena todo el hueco (marco + hoja).
- **Ventanas iguales seguidas se unen solas** (la columna entre ellas se abre
  y el vidrio sigue). Para que queden separadas, se usa otra ventana o se
  deja una pared lisa en medio. Si hace falta un interruptor, se agrega.
- **Escalera = objeto de 1 × 3** que se pone abajo y abre el hueco en el piso
  de arriba (quita esas baldosas en el mismo paso de deshacer).
- **Techo a dos aguas sobre un rectángulo** que dibuja el jugador (no
  automático), con grosor y paredes de remate triangulares en las puntas
  (color de la pared de abajo) para que no quede hueco entre pared y techo. Un techo automático "inteligente" para formas en L es mucho
  trabajo; se puede agregar después si hace falta.
- **Datos = escrituras clave → valor** (`HouseData.apply`). Cada acción es una
  lista de escrituras y devuelve la lista inversa: con eso funciona deshacer, y
  en la Fase 5 se mandarán esas mismas escrituras a la pareja (permisos,
  aviso + deshacer, historial).
- **Reglas aparte** (`house_rules.gd`, sin nada 3D) para que en la Fase 4 el
  servidor pueda validar igual. Al borrar varias piezas juntas se simula el
  resultado: no se puede dejar nada "en el aire".
- **Borrar = modo** (botón Borrar) que invierte la herramienta elegida, en vez
  de una herramienta por cada cosa que se borra.
- **Pintura**: una pared se pinta entera (las dos caras del mismo color). Pintar
  cada cara por separado complica datos e interfaz; se agrega si se pide.
- **Gestos**: con una pieza elegida, 1 dedo construye y 2 dedos mueven la
  cámara. Sin pieza, con la mano en el vacío, o **empezando fuera del lote**,
  1 dedo mueve la cámara. Vista previa verde/roja mientras se arrastra.
- **Confirmar con botón** para las herramientas de arrastre (cimientos, piso,
  pared, cuarto, techo): al soltar queda una selección con dos manijas que se
  ajustan, y se aplica con Confirmar. Pedido del dueño: el dedo tapa lo que
  se construye. Muebles, puertas, ventanas y pintura siguen aplicándose al
  soltar (son un solo toque).
- **Guardado automático** 1 segundo después de cada cambio (además de al
  salir): Android puede cerrar la app sin aviso.
- **Se muestran precios** en la barra, pero todavía **no se cobra**: la
  moneda llega en la Fase 3.
- **Rendimiento**: cada pieza es una caja aparte (~400 llamadas de dibujo en
  una casa de ejemplo). Medido en el teléfono del dueño con una casa de dos
  pisos: **60 FPS fijos** (2026-11-03). Si más adelante baja, el arreglo es
  juntar pisos y paredes de cada nivel en una sola malla (cambio interno de
  `HouseView`, no toca datos).

## Riesgo legal frente a EA (ver `docs/riesgos-legales-ea.md`)

- **Mecánicas libres, expresión propia.** Se puede hacer un simulador de vida;
  no se copia nada de cómo se ve, suena o se llama The Sims.
- **Nombres prohibidos:** "Sim/Sims", "Simlish", "-ville", "WooHoo", "Life".
  Nada de rombo/cristal sobre la cabeza. No mencionar The Sims en la tienda.
- **Editor de personaje (Fase 2): deslizadores y opciones**, no tocar y
  arrastrar partes del cuerpo: EA tiene una patente activa (US 10,275,947,
  hasta ~2035) sobre eso.
- **Arte con IA (Fase 7):** referencias propias, nunca material de EA; guardar
  referencias y pedidos como prueba de creación independiente.
- **(pregunta)** Antes de publicar al público o cobrar: abogado de propiedad
  intelectual y búsqueda de marca del nombre definitivo.

## Personaje y su IA (Fase 2)

- **Necesidades: Comida, Energía, Limpieza, Diversión** (0 a 100, 100 =
  perfecto). El **ánimo** no es una necesidad aparte: es el promedio, con
  una palabra (Feliz / Bien / Más o menos / Decaído). Social llega con la
  pareja (Fase 5).
- **Nunca bajan de 10** jugando, y el tiempo sin jugar solo las baja hasta
  30 (principio "tranquilo" de VISION). Lo que esté por debajo no baja más.
- **Tiempo: 1 segundo real = 1 minuto del juego a x1** (un día = 24 min).
  Velocidades x1, x3, x10. El reloj se detiene en modo Construir. La
  intención guarda la **hora real** ("desde las 14:02"), que es la que
  verá la pareja en la Fase 5.
- **IA de prioridades (utility AI)**: puntaje = lo que sube cada necesidad ×
  urgencia (curva al cuadrado) × gusto por rasgos ÷ distancia. Se sortea
  entre las opciones de al menos 75 % del mejor puntaje. Si nada pasa de un
  mínimo, pasea. Pura lógica en `character_brain.gd` (el servidor podría
  usarla igual para el personaje "offline" de la Fase 5).
- **Los muebles anuncian acciones** con ids en `catalog.json` (`actions`); las
  acciones viven en `data/actions.json` (duración, cuánto sube cada
  necesidad, animación, burbuja). Los rasgos en `data/traits.json`.
- **Órdenes del jugador**: tocar un mueble en modo Vivir muestra sus
  acciones; la orden tiene prioridad sobre la IA. No estaba pedido
  explícitamente, pero sin esto el modo Vivir no tiene nada que tocar.
- **Caminos con AStar3D de Godot** sobre las celdas (con diagonales que no
  cortan esquinas); paredes bloquean, puertas no, ventanas sí. Las escaleras
  unen la planta baja con el primer piso. La red se rehace sola cuando la
  casa cambia. Al volver de Construir, si le pusieron algo encima al
  personaje, se lo mueve a la celda libre más cercana.
- **Editor con botones de opciones** (colores y rasgos), nada de arrastrar
  partes del cuerpo: evita la patente de EA (ver `docs/riesgos-legales-ea.md`).
- **Barras con colores propios** (naranja, amarillo, azul, rosado), no el
  verde→rojo de otros juegos.
- **Ganchos de animación**: el personaje pide `idle`, `walk`, `sleep`, `sit`,
  `cook`, `eat`, `shower`, `use`. Hoy son movimientos simples por código; si
  el modelo de la Fase 7 trae un AnimationPlayer con esos nombres, se usa.
- **El juego arranca en modo Vivir** (antes, Construir).
- **Un solo personaje por casa** por ahora; los datos (`CharacterData`) ya
  están separados de la escena, así en la Fase 5 se suma el de la pareja.

## Ajustes después de probar la Fase 2 (2026-11-03)

- **Parcela de 32 × 32 m** (antes, lote de 12 × 12), con calle y acera al
  frente (solo decorado por ahora). Es la extensión máxima del jugador; cabe
  más de una construcción (visión: casa + cobertizo + negocio). Las casas
  guardadas con el lote viejo se **centran solas** al cargar (primera
  migración de datos, `HouseData.from_dict`). Ampliar la parcela más
  adelante es cambiar `LOT_SIZE` (la migración ya centra).
- **Vista por piso**: "sin techo" y "paredes bajas" afectan solo al piso
  actual; los de abajo se ven completos (con sus techos) y los de arriba no
  se dibujan. Vale también en modo Vivir (Subir / Bajar visibles siempre).
- **Las puertas no se cortan** con "paredes bajas": se ven enteras para saber
  dónde están.
- **Ventanas**: se unen solas si son iguales y seguidas; cada ventana se puede
  marcar "separada" con la herramienta Unir / separar (campo `separate` de la
  pared). El vidrio ahora es un plano, no una caja: no queda línea en la unión.
- **Diario y emociones**: Feliz, Tranquilo, Cansado, Enojado (con hambre),
  Aburrido, Incómodo (sucio), Triste (dos o más necesidades bajas). Caritas
  **dibujadas por el juego** (no emojis del sistema: no se ven igual en todos
  los teléfonos y así el arte es propio). Solo en el diario, no en el panel.
  Se guardan las últimas 60 entradas.
- **Menú oculto** (botón Menú): Personaje, Diario y Opciones (FPS, ayudas).
  Las opciones se guardan en la partida (`settings`).
- **Barra de piezas**: se desliza arrastrando el dedo sobre los botones; si
  el dedo se movió, soltar no elige nada.
- **Panel del personaje de tamaño fijo**: la intención ocupa siempre 2
  líneas (lo que sobra termina en "…"), así el panel no salta.

