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

## Progresión y economía local (Fase 3)

- **Dinero inicial $3000** (también para las partidas viejas migradas). Se
  gana trabajando; no hay otra fuente. Todo precio sale de `catalog.json`.
- **Cobros por "diferencia"**: poner algo nuevo paga su precio; pintar y
  mover es gratis; cambiar de pieza paga solo la diferencia; borrar o bajar
  de valor **devuelve el 50 %** (`resale_percent`). Una pared suma el precio
  de su puerta o ventana y el techo cuesta **por celda cubierta**.
- **Deshacer devuelve exactamente lo que se pagó** y rehacer lo vuelve a
  cobrar (cada paso guarda su cambio de dinero). Si el dinero ya se gastó y no
  alcanza para deshacer un borrado, se avisa y no se deshace.
- **Experiencia solo por "primera vez" y por trabajar**: construir un tipo de
  pieza por primera vez da 10 % de su precio (mínimo 5); un turno da la
  experiencia de su empleo. Deshacer/rehacer no la repiten (no se puede
  "farmear" poniendo y quitando).
- **Niveles** (0, 100, 250, 500, 900, 1400 de experiencia) y piezas
  bloqueadas por `unlock_level`. Las ya colocadas no se quitan si algo se
  bloquea. En las partidas viejas, lo ya construido cuenta como descubierto.
- **Obras con temporizador solo para muebles, escaleras y techos**
  (`build_seconds`). Paredes y pisos son instantáneos para que armar un cuarto
  no sea eterno. El tiempo es **hora real** (Unix) y sigue corriendo con el
  juego cerrado. Una obra no se puede usar hasta terminar (el personaje la
  ignora, las escaleras no conectan).
- **Acelerador = monedas** (6 por minuto real que falta, mínimo 1); "acelerar
  todo" juntas las obras. No hay moneda aparte: VISION dice que hay una sola.
  El mismo precio sirve para acelerar la respuesta de un currículum.
- **Empleos**: 3 ofertas por nivel (Repartidor, Cajero, Oficinista; se editan
  en `jobs.json`). Respuesta a los 5, 10 o 30 minutos **reales**. Si se cumple
  el nivel, siempre te contratan (la espera ya es el costo). El primer turno
  es al día siguiente.
- **Turno**: a su hora, el personaje camina hasta la acera y desaparece hasta
  terminar; el sueldo se cobra al volver. El día del juego solo avanza en
  modo Vivir (en Construir el tiempo se detiene).
- **"Nada castiga por desconectarse"**: un turno a medias al cerrar se cobra al
  volver, y por cada día del juego sin conectarse (tope: 3) se paga un turno
  completo.
- **Guardado robusto (formato 2)**: `SaveMigrations` convierte versiones
  viejas paso a paso (1 → 2 agrega la economía); antes de migrar se copia la
  partida vieja (`save.pre_migration.json`); cada guardado conserva el
  anterior (`save.json.bak`) y, si el principal se daña, se usa ese.
- **Todavía sin servidor**: el dinero vive en el teléfono. En la Fase 4 pasa
  al servidor; por eso todo cambio de dinero pasa por `Economy.add_money()`
  y todo precio sale del catálogo, listo para validarse allá.

## Cuentas y servidor (Fase 4) — decidido el 2026-11-03; 4A hecha, 4B pendiente

Decisiones del dueño:
- **Sin servidor (fuera de casa): se puede Vivir, no Construir.** Construir,
  cobrar el trabajo, mandar currículos y acelerar esperan a reconectar. El
  botón Construir avisa "Sin conexión al servidor".
- **Red: Nakama publicado en 192.168.100.177:7350 (solo la red de casa)** y
  también en 127.0.0.1:7350. La consola de administración (7351) solo en
  127.0.0.1. La base de datos no se publica. Ojo: la IP de la PC no tiene
  reserva DHCP en el router y podría cambiar (la dirección del servidor va en
  un archivo de configuración del juego, fácil de cambiar).
- **Cuentas: usuario + contraseña, "acceso único"**: se entra una vez y el
  teléfono recuerda la sesión (token de renovación de larga duración guardado
  en user://, nunca la contraseña) hasta que se borren los datos de la app.
  Más adelante: SSO de otras apps (Nakama permite vincular Google/Apple).
- **Docker autorizado** para descargar `heroiclabs/nakama:3.41.0` (60 MB) y
  crear, arrancar y reiniciar SOLO `neighborhood-nakama` y `neighborhood-db`.
  La base usa la imagen `postgres:18` que ya estaba en la PC.

Decisiones técnicas (de Claude, cambiables):
- **Carpeta `server/` dentro del repo**: `docker-compose.yml`, `nakama/config.yml`,
  `nakama/modules/*.lua`; secretos en `server/.env` (fuera de Git, generados
  con `openssl rand -hex 16`); datos de Postgres en `server/db-data/` (fuera de
  Git). La carpeta `data/` del juego se monta de solo lectura en el servidor:
  **los precios se leen del mismo catalog.json**.
- **Código del servidor en Lua** (runtime de Nakama): no necesita compilar
  nada (TypeScript pide Node; Go pide compilar con la versión exacta).
- **Cliente propio y chico (HTTPRequest a la API REST de Nakama)** en vez del
  addon oficial: el addon `nakama-godot` no tiene versión nueva desde marzo de
  2024 (v3.4.0) y no está probado con Godot 4.7; para la Fase 4 alcanzan
  pocas llamadas (autenticar, renovar sesión, leer/escribir storage, RPC). En
  la Fase 5 (tiempo real) se evalúa de nuevo el addon o un socket propio.
- **El servidor manda en**: billetera (wallet de Nakama, con historial), casa
  (storage escrito solo por el servidor), experiencia, nivel, desbloqueos,
  obras (hora del servidor), empleos y turnos. El cliente sigue calculando
  precios solo para mostrarlos; el servidor los recalcula y decide.
- **Deshacer con servidor**: el servidor guarda los pasos (hasta 100) y
  deshace/rehace su propio último paso, devolviendo exactamente lo cobrado.
- **Turnos con velocidad x10**: el servidor no conoce el reloj del juego;
  acepta cobrar un turno si pasó al menos su duración a velocidad x10 (hora
  real) y como mucho un turno cada 144 s reales (un día a x10).
- **Primera conexión**: si la cuenta es nueva, se importa una sola vez la
  casa, la experiencia y lo descubierto de la partida local; el dinero
  empieza en el inicial ($3000).
- **Reglas de apoyo (pisos, paredes…)** siguen en el teléfono por ahora: no
  tocan dinero. Pasarlas al servidor queda para cuando se edite la casa entre
  dos (Fase 5).
- Las 153 pruebas locales siguen valiendo: la economía local queda como
  "modo de prueba" (sin cuenta), no se ofrece en la interfaz.

### Fase 4A — decisiones de la implementación (2026-11-03)

- **Usuario + contraseña sobre la cuenta "email" de Nakama**: Nakama pide un
  correo para entrar con contraseña, así que el juego usa uno inventado
  (`usuario@neighborhood.local`) y el jugador solo ve su usuario. Usuario: 3 a
  20 minúsculas, números o `_`; contraseña: mínimo 8 (lo exige Nakama). Si
  algún día hay correo real o SSO, se vincula a la misma cuenta.
- **Sesión**: token de 2 horas y token de renovación de 1 año. Comprobado: cada
  renovación da un token de renovación NUEVO con otro año, así que jugando no
  vence nunca; y las sesiones sobreviven a reiniciar Nakama. Se guardan en
  `user://session.json` (los dos tokens; nunca la contraseña).
- **Llave del cliente (`server_key`) pública**: `neighborhood-family`, en
  `server/nakama/config.yml` y `data/server.json`. No es secreta (viaja en el
  APK); lo secreto (llaves de sesión, base, consola) está en `server/.env`.
- **Dirección del servidor en `data/server.json`** (host, puerto, llave,
  espera máxima). Cambiar la IP = ese archivo + `LAN_IP` en `server/.env`.
- **Pantalla de entrada como escena principal** (`ui/login_screen.tscn`): con
  sesión recordada entra sola; sin servidor y con cuenta ofrece "Jugar sin
  conexión"; sin cuenta, la primera vez hay que estar en la red de casa.
  "Cerrar sesión" en el Menú.
- **Transición 4A → 4B**: en la 4A la casa y la economía **siguen mandando en
  el teléfono** (construir funciona como en la Fase 3); el servidor guarda la
  copia importada la primera vez. Se usa la del servidor solo si el teléfono no
  tiene casa (reinstalación) o la partida es de otra cuenta. **Al empezar la
  4B** hay que re-sincronizar una última vez casa, experiencia y descubierto
  (si `game/house.source == "import"`), para no perder lo construido durante
  las pruebas de la 4A; el dinero sí empieza en $3000 (ya está en la billetera).
- **Personaje y opciones en la nube** (`cloud/character`, `cloud/settings`, los
  escribe el teléfono): se suben después de guardar (como mucho cada 15 s) y al
  pasar a segundo plano. Personaje: gana el guardado más nuevo; opciones: las
  del teléfono, salvo que no tenga. Casa y progreso (`game/*`) solo los escribe
  el servidor (comprobado: el teléfono recibe "permission denied").
- **Casa, personaje y opciones viajan como texto JSON** dentro del objeto
  (`{"json": "...", "saved_unix": N}`): el JSON de Lua convierte una lista
  vacía en `{}` y la casa tiene capas vacías. En la 4B, el servidor que lea la
  casa tendrá que cuidar eso (o seguir guardándola como texto).
- **Otra cuenta en el mismo teléfono**: la partida de la anterior se aparta en
  `user://save.account_<id>.json` y vuelve si esa cuenta entra de nuevo.
- **PostgreSQL corre como el usuario del dueño (uid 1000)**: los archivos de
  `server/db-data/` son suyos (el respaldo los puede leer y se pueden borrar
  sin permisos de administrador). `server/` tiene `.gdignore`: Godot no lo
  mira ni lo mete en el APK.
- **Permiso INTERNET** agregado al APK (sin él Android corta la conexión). El
  HTTP sin cifrar funciona porque Godot usa sus propios sockets (las reglas de
  "cleartext" de Android son para el HTTP de Java). Sin comprobar en el teléfono.
- **Consola de Nakama: usuario `dueno`** (Nakama avisa si se llama `admin`).
- **Arranque con la PC**: los contenedores tienen `restart: unless-stopped`,
  pero Nakama se publica en la IP de la LAN y al arrancar la PC puede no estar
  lista (a AdGuard le pasaba). **(pregunta)** Si pasa, la solución es un
  servicio que espere la IP (como `adguard-arranque`), que es un cambio del
  sistema aparte.

