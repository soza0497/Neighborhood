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

## Cuentas y servidor (Fase 4) — decidido el 2026-11-03; 4A y 4B hechas

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
  → **Decidido en la Fase 5: socket propio** (ver "Pareja y casa compartida").
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
  dos (Fase 5). → **Hecho en la Fase 5** (`neighborhood_house.lua`).
- Las pruebas locales siguen valiendo: la economía local queda como
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


### Fase 4B — decisiones de la implementación (2026-11-03)

- **Reglas en un archivo Lua aparte** (`neighborhood_rules.lua`), sin nada de
  Nakama: se prueban solas con `lua5.1` y el módulo `neighborhood.lua` solo
  lee, guarda y registra las RPC. Las cuentas son copia exacta de las de
  `economy.gd` (el teléfono las usa para MOSTRAR precios; si se cambia una
  regla, se cambia en los dos). La demo `economy_server_demo` compara los dos.
- **Guardado atómico**: cada pedido lee el estado (casa, progreso, empleo,
  historial y billetera) y guarda todo junto con `nk.multi_update` (storage +
  wallet en una sola transacción, con su historial `ledger`). Cada objeto se
  escribe "solo si nadie lo cambió desde que lo leí" (versión); si dos
  pedidos del mismo jugador chocan, el servidor reintenta solo (hasta 4).
- **Objetos nuevos**: `game/work` (empleo, currículum, turno en marcha, último
  turno, última vez visto) y `game/history` (pasos de deshacer, como texto
  JSON porque guardan "quitar" = null).
- **Historial**: hasta 100 pasos **y** como mucho ~400 KB (si un paso es enorme,
  por ejemplo cimientos en toda la parcela, se olvidan antes los más viejos).
  Acelerar no es un paso (no se "des-acelera"), igual que en la Fase 3.
- **El teléfono nunca pone la hora de una obra**: el `ready_at` que manda se
  descarta. Mover o pintar una obra conserva la suya; una pieza nueva (o de
  otro tipo) empieza la suya con la hora del servidor. El teléfono ajusta su
  reloj a la diferencia con el del servidor (`Economy.server_offset`).
- **Validación** (sin las reglas de apoyo, que siguen en el teléfono hasta la
  Fase 5): piezas que existen en el catálogo y del tipo correcto para su capa,
  claves y posiciones dentro de la parcela, cimientos solo abajo, colores
  `#hex`, campos desconocidos descartados, máximo 3000 escrituras por pedido,
  nivel de desbloqueo para lo que es NUEVO (lo ya puesto se puede pintar o
  mover aunque esté bloqueado). Quitar algo que no existe no devuelve nada.
- **Ids de objetos ("o12")** los sigue eligiendo el teléfono; el servidor
  revisa la forma y sube su contador (`next_id`) para que nunca se repitan.
- **Respuestas**: una regla que dice que no responde `{ok: false, error}`
  con el texto para el jugador (no un error HTTP) y el estado actual; así el
  teléfono siempre queda igual al servidor.
- **Un pedido por vez en el teléfono** (`Economy.busy`): mientras espera, los
  botones de deshacer, rehacer, confirmar y acelerar se apagan y otro toque
  avisa "Esperando al servidor…". El "sigo jugando" va por fuera (el
  servidor reintenta si choca).
- **Turnos (reglas x10)**: un turno se cobra si pasó su duración a x10 (un
  turno de 4 h = 24 s reales) con **2 s de margen** por la demora de la red, y
  se empieza como mucho uno cada 144 s. Si al cobrar todavía es temprano o no
  hay conexión, el teléfono reintenta solo y avisa cuando cobra.
- **Pago offline con la hora del servidor**: el servidor anota "última vez
  visto" (al entrar, en cada turno y con un "sigo jugando" cada 5 min y al
  pasar a segundo plano). Al entrar (`work_settle`) paga un turno por cada día
  del juego a x1 (1440 s) desde entonces, tope 3. Si se corta la conexión con
  el juego abierto, al volver se cobra igual (antes del siguiente "sigo
  jugando").
- **Sin conexión, el personaje no sale a trabajar** (el servidor tiene que
  anotar el turno). Esos días se pagan al volver, como días sin jugar.
- **Al entrar con conexión manda el servidor** (casa, dinero, experiencia,
  descubierto, empleo). Del teléfono solo queda el día del juego del último
  turno (el reloj del juego es del teléfono). Con "Jugar sin conexión" se usa
  la última copia guardada en el teléfono; cuando vuelve la conexión con el
  juego abierto, se carga la partida del servidor como al entrar (con la
  re-sincronización 4A → 4B si todavía no se hizo) y recién ahí se puede
  construir.
- **Transición 4A → 4B hecha así**: `game_load` dice `house_source`; si es
  `"import"`, el teléfono vuelve a mandar su partida y `game_import` copia UNA
  vez más casa, experiencia, descubierto y empleo (si le alcanza el nivel),
  sin tocar el dinero, y marca la casa `"server"`. Probado con una cuenta "de
  la 4A" armada a mano en la base.
- **Importar** ahora también trae el empleo (si existe y alcanza el nivel) y
  limpia de la casa las piezas que no existen en el catálogo. Las cuentas
  nuevas empiezan con `source = "server"`.
- **Variable `NEIGHBORHOOD_SERVER`** (opcional): cambia la dirección del
  servidor sin tocar `data/server.json`, para probar en otra PC. En el
  teléfono no existe, así que no cambia nada.
- **Pruebas que cambiaron**: 3 comprobaciones de `test_server.gd` decían "con
  casa en el teléfono, manda el teléfono (4A)"; ahora dicen lo contrario
  (manda el servidor), que es lo que decidió el dueño para la 4B. Y la demo
  del servidor ya no espera la casa "idéntica" (el servidor la revisa y la
  completa con el segundo piso vacío).
- **Versión 0.5.0** del juego.

## Pareja y casa compartida (Fase 5) — 2026-11-03, sesión en la nube

Sub-fases (cada una con su commit, probada por separado):
- **5A — servidor**: reglas de apoyo, relación, casa compartida, caja (Lua,
  probado sin Nakama con `lua5.1`).
- **5B — teléfono**: tiempo real, Couple, paneles, ponerse al día (probado con
  `couple_demo`, dos cuentas a la vez contra Nakama).
- **5C — el personaje de la pareja** en mi pantalla, "unir ingresos" de punta
  a punta y documentación (`couple_live_demo`, con ventana y capturas).

### Tiempo real
- **Socket propio** (`RealtimeSocket`, con el `WebSocketPeer` que trae Godot) en
  vez del addon oficial `nakama-godot`. Por qué: el addon no tiene versión nueva
  desde marzo de 2024 (v3.4.0, revisado en la 4A) ni está probado con Godot 4.7;
  y del socket solo hacen falta 3 cosas (conectarse con el pase, seguir a la
  pareja, mandar mi estado y recibir avisos): ~250 líneas propias, comentadas,
  sin código de terceros, y probadas contra el Nakama de verdad. Cambiarlo por
  el addon más adelante es tocar solo `realtime_socket.gd`.
- **Mismo puerto 7350** (`/ws`): no hay que abrir ni publicar nada nuevo.
- **Estado = intención del personaje** (`Character.get_intention`, ~200 letras
  en JSON), con el "status" de Nakama: sirve a la vez de **indicador de en
  línea** (presencia) y de "qué hace". Se manda solo cuando cambia, como mucho
  cada 2 s. Se mandan estados, no movimientos (VISION). Cualquier cuenta del
  servidor podría seguir ese estado; para la familia no importa (anotado).
- **Los avisos solo dicen "algo cambió"** (notificaciones 101 relación, 103
  hogar, 104 pedidos), no guardados: el teléfono vuelve a preguntar
  (`couple_load`, `home_load`). La verdad está siempre en el servidor; si se
  pierde un aviso (sin conexión), al reconectar se pregunta todo de nuevo.
- **Ponerse al día con la casa**: el hogar tiene un número de versión (`rev`)
  que sube con cada cambio. Si mi pedido fue lo único que cambió (subió 1), ya
  estoy al día; si no, se pide la casa y se aplican **solo las piezas que
  cambiaron** (la vista 3D no se rehace entera).

### Relación
- Estados: **sin pareja → en pareja → matrimonio**; mudarse se puede desde "en
  pareja" (libertad). Textos neutros ("En pareja", "Matrimonio", "en línea"),
  sin suponer el género.
- Una invitación saliente por vez; hasta 10 recibidas. Si B ya me invitó,
  invitarlo es aceptar. Al formar pareja se limpian todas las invitaciones de
  los dos (también las que otros les mandaron).
- **Terminar la relación** está incluido aunque la fase no lo pide: sin eso,
  una prueba (o un error) deja a dos cuentas atadas para siempre. No necesita
  que el otro acepte. Reglas simples: la casa queda de su dueño, quien se mudó
  vuelve a **su casa de antes (quedó guardada, sin tocar)**, la caja se
  reparte en dos (la moneda impar, al dueño) y lo que se compró queda en la
  casa. Más adelante (drama, VISION) se puede discutir algo más fino.
- Cada uno guarda su **historial de relaciones** (últimos 30 hechos).
- **Drama y modo familiar: solo el interruptor.** Drama apagado y modo familiar
  prendido por defecto (todavía es pregunta abierta si juegan menores). Hay
  drama solo si los DOS lo permiten y ninguno tiene el modo familiar
  (`drama_enabled`). No hay nada que ocultar todavía.

### Casa compartida: permisos
- **Menor** (al instante, con aviso y "Deshacer" para el otro): mover, girar o
  pintar un mueble, pintar paredes y pisos, unir/separar ventanas, y **poner un
  mueble nuevo** (VISION no lo nombra; pedir permiso para cada silla sería
  pesado, y quien lo pone lo paga).
- **Estructural** (pedido + aprobación): cimientos, pisos, paredes, puertas,
  ventanas, techos, escaleras y **quitar cualquier cosa** ("vender"). Un
  cambio con una sola cosa estructural es todo estructural.
- Lo decide el **servidor** (`neighborhood_house.lua`); el teléfono tiene una
  copia (`HousePermissions`) solo para que el botón diga "Pedir permiso".
- Al **aprobar**, se construye como si lo hubiera hecho quien lo pidió: paga
  (caja + su billetera), gana su experiencia y le queda en su Deshacer. Se
  vuelve a revisar todo en ese momento (dinero, apoyo); si ya no se puede, el
  pedido queda para rechazarlo. Hasta 10 pedidos esperando. Quien pidió lo
  puede retirar.
- Deshacer mi propio cambio (aunque haya sido aprobado) no pide permiso: es
  volver atrás lo mío y devuelve lo exacto.

### Casa compartida: dinero
- **Billetera propia** de cada uno (la de Nakama, como en la 4B) y **caja de la
  casa** (vive en `game/home` del dueño de la casa).
- Lo que se construye se paga **primero con la caja**; lo que falta, con la
  billetera de quien construye. Lo que se **vende vuelve a la caja**. Acelerar
  obras, igual. Deshacer devuelve a cada uno lo que puso.
- **Aportar** es de ida (billetera → caja). No hay "retirar" de la caja: así no
  hace falta aprobar retiros; al separarse se reparte.
- **"Unir ingresos" es de cada uno**: "mi sueldo va a la caja" (también los
  turnos pagados por días sin jugar). Si los dos lo prenden, están unidos.

### Casa compartida: conflictos e historial
- Dos pedidos a la vez: el servidor guarda con control de versión y, si chocan,
  **reintenta con lo nuevo** (hasta 6): en los cambios menores gana la última
  escritura. Los `version check failed` del log de Nakama son esto, normales.
- **Deshacer no pisa lo del otro**: cada uno tiene su propio Deshacer (hasta
  100 pasos); si las piezas de ese paso cambiaron después (por la pareja), el
  paso se **descarta** con un aviso en vez de pisarlas (y no traba los pasos
  anteriores). Rehacer, igual.
- **Historial de la casa** (`game/home`, últimos 40): quién, cuándo y qué
  ("movió: Sofá", "puso: Pared lisa x2", "aprobado por…"). Los cambios menores
  guardan sus piezas (si son menos de 300) para poder **deshacerlos desde el
  historial o el aviso**: solo si nadie los tocó después, y el dinero vuelve a
  quien lo pagó (nunca a quien deshace).

### Reglas de apoyo en el servidor
- `neighborhood_house.lua` es copia de `house_rules.gd`/`house_grid.gd`, con los
  mismos casos de prueba. Diferencia: el servidor revisa el **resultado**
  (aplica todo a una copia y mira que cada pieza tocada y lo que se apoyaba en
  ella siga apoyado); así sirve igual para construir, deshacer, rehacer y
  deshacer lo del otro. Además una escalera "prohíbe" el piso de encima.
- Se revisan **después** del nivel y del dinero (avisos más útiles primero).
- Cambió una demo vieja: en `economy_server_demo` la cama estaba "en el aire"
  (sin piso debajo); ahora va girada sobre los dos pisos que se ponen.

### El personaje de la pareja
- El mismo `Character` en modo "pareja" (`is_partner`): no avisa a mi
  interfaz, no va a trabajar con MI empleo y no se guarda. Aparece solo
  viviendo juntos, con su nombre encima (rosado).
- **En línea**: hace lo que dice su intención (camina al mismo mueble y hace la
  misma acción hasta que cambie; si trabaja, sale por la acera; si pasea,
  pasea). **Fuera de línea**: vive con su propia IA y sus necesidades de la
  última vez que guardó ("creíble, no exacto").
- **Reserva simple**: un personaje no elige el mueble que está usando el otro
  (el pendiente anotado en la Fase 2). Si la pareja en línea usa el mismo
  mueble que el mío, igual va (es lo que hace en su teléfono).
- La necesidad **Social** (DECISIONES de la Fase 2 decía "llega con la pareja")
  **no se hizo**: la Fase 5 no la pide y necesita interacciones entre
  personajes. Queda en pendientes.

### Otros
- **Versión 0.6.0.**
- Un segundo `GameServer` (con `emits_events = false`) permite probar dos
  jugadores en un mismo programa (`couple_demo`, `couple_live_demo`).
- Las demos que abren la escena principal apartan la partida del jugador y la
  devuelven al terminar (la escena guarda sola).

## Pulido 1 — interfaz limpia y constructor 2.0 (2026-11-03)

Pedido del dueño en `docs/pulido-1.md`. Hecho en una sesión local (la PC del
dueño), rama `pulido-1`.

### P1A — interfaz
- **Íconos propios** en `assets/icons/*.svg` (42, dibujados a mano en SVG:
  trazo blanco redondeado; las necesidades con su color). No se usó Kenney:
  así no hay licencias que seguir y el estilo es uno solo. `ui/icons.gd`
  arma los botones con ícono; el texto queda como ayuda (tooltip en la PC).
- **Barra de arriba**: dinero + nivel (como antes) y el **ánimo**: carita
  propia (`MoodFace`) + palabra ("Feliz", "Bien", "Más o menos",
  "Desanimado"; antes "Decaído"). Tocarlo abre una tarjeta con las 4
  necesidades (ícono + barra), qué hace ahora y **qué afecta el ánimo**
  (`CharacterData.mood_factors`: necesidades bajas → su emoción y motivo;
  necesidades muy altas → "Comió bien", "Descansó"...). Tocar afuera la cierra.
- **Pareja** arriba: solo "● nombre" (rosado en línea, gris fuera). El texto
  largo (qué hace su personaje) pasó a **Info**.
- **Info** (Menú → Info): FPS, versión y guardado, conexión, día y hora, caja
  de la casa y la pareja. Opción **"Mostrar FPS en pantalla"** (apagada por
  defecto; la opción vieja `show_fps` se ignora, la nueva es
  `show_fps_overlay`).
- **Maqueta de pisos** (`ui/floor_map.gd`): un SubViewport con su propio mundo
  3D y cámara **ortográfica** (todos los pisos del mismo tamaño, fácil de
  encuadrar), desde la calle y girada 25° para que se note el 3D. Losas y
  paredes bajitas, el piso actual en naranja, los otros celestes
  transparentes, y uno vacío arriba para poder subir. Punto rosado que
  parpadea donde está el personaje. Se redibuja solo cuando la casa cambia.
  Reemplaza Subir / Bajar / Planta baja.
- **Techo** y **paredes**: dos íconos independientes. Ver los techos vuelve
  las paredes altas, y bajar las paredes esconde los techos (un techo sobre
  paredes bajas taparía todo). La vista vieja de 3 modos sigue existiendo por
  dentro (`HouseView.view_mode`) para las demos.
- **Brújula**: flecha de navegador que gira hacia el personaje (en la
  pantalla); tocarla centra la cámara en él y va a su piso.
- **Velocidades x1, x2, x5.** El servidor calcula los turnos con la velocidad
  más rápida: `FASTEST_SPEED = 5` y `DAY_AT_FASTEST = 288` s (antes 10 y 144).
  Un turno de 4 h dura ahora 48 s reales como mínimo (antes 24): **no da
  ventaja** (al revés: con x10 se cobraba más rápido). Probado en Lua (a los
  24 s ya no se cobra) y en `economy_server_demo` / `couple_demo`.
- **5 pisos** (`MAX_LEVELS = 5` en `house_grid.gd`, `neighborhood_house.lua` y
  `neighborhood_rules.lua`). Las casas guardadas con 2 se completan solas.
- Las demos contra el servidor se corrieron contra un **Nakama de prueba
  aparte** (127.0.0.1:7360, base en memoria, se borró al terminar) para no
  tocar el servidor ni las cuentas del dueño.

### P1B — constructor 2.0
- **Herramientas: Tienda (bolsa) · Obra (casco: Agregar + / Modificar mano) ·
  Borrar (basurero)**, en ese orden. Nada del trío ni de los íconos de otro
  juego. La barra vive en `ui/build_bar.gd`; los botones que sirven en cada
  momento (flechas, girar, borrar, copiar contorno, modo selección, flechas
  de pintura) van en una fila arriba a la derecha de la barra.
- **Tocar vs. mantener presionado** (0,45 s): en Modificar, Pintura y Borrar,
  arrastrar sin mantener mueve la cámara; mantener levanta el mueble, pinta
  arrastrando o elige un rectángulo para borrar. Tocar una pared, techo, piso
  o cimiento en Modificar abre su menú (también al mantener): pintar, mover
  (con las flechas), quitar la puerta/ventana, borrar.
- **Mover paredes y techos** con las flechas N/S/E/O (además de muebles). Una
  pared que sostiene algo no se puede correr.
- **Borrar**: siempre pregunta, con la reventa del 50 % de antes. Los techos
  se eligen tocándolos (con los techos a la vista). Tocar una pared con
  puerta o ventana quita primero la abertura. "Esta pared / Este pilar
  sostiene el piso de arriba" sale de `HouseRules.removal_reason`.
- **8 direcciones (45°)**: se guardan como antes (`rot` 0..3) más `diag: true`
  (45° más). Así las casas viejas no cambian y el servidor no necesita
  migración para esto. Solo los **muebles** van en diagonal (escaleras y
  pilares no). Un mueble en diagonal ocupa las celdas que toca su caja
  girada (90 % de su tamaño, 9 puntos de muestra por celda): misma cuenta
  exacta en `house_grid.gd` y en `neighborhood_house.lua` (con el mismo
  número para cos 45°). Una silla en diagonal ocupa 1 celda; una mesa 2×1, 4.
- **Pintura por cara**: `color_a` (cara norte/oeste) y `color_b` (sur/este).
  Las flechas siguen la pared "como quien camina pegado a ella": dobla en las
  esquinas de adentro y rodea las de afuera (`scripts/house/wall_faces.gd`).
  Pintar no cuesta y es cambio menor en la casa compartida.
- **Ventanas unidas**: la unión se guarda en la **juntura**, como `join_end`
  en la pared que TERMINA en ese vértice (cada juntura tiene un solo dueño:
  lo que se ve es lo que está guardado). Al poner una ventana igual al lado
  se une sola (como antes). En Modificar, cada juntura entre dos ventanas es
  un puntito (naranja = unidas) que se toca para unir o separar. No se usó
  una capa nueva de "junturas": habría que cambiar todo el formato del
  servidor para algo que cabe en la pared.
- **Formato de casa 3** (`HouseData.FORMAT`, campo `format` en la casa) y
  **guardado v3** (`SaveMigrations._v2_to_v3`): la pintura vieja pasa a las
  dos caras y las ventanas que se veían unidas quedan unidas en su juntura;
  la marca vieja `separate` desaparece. El servidor hace la misma conversión
  al leer una casa sin `format` (`rules.upgrade_legacy`). Solo se convierte
  una vez (si no, se volverían a unir ventanas que el jugador separó).
- **Techos**: no se puede poner un techo donde una pared del piso de arriba
  (o un piso de arriba) queda adentro de su rectángulo, y al revés: no se
  puede poner esa pared o piso sobre un techo. Interpretación de "pared del
  mismo nivel que lo atraviesa": las paredes que se ven a la altura del
  techo, o sea las del piso de arriba (las del mismo piso terminan justo
  debajo del techo y no chocan). **Techo plano de concreto** nuevo
  (`roof_style: flat`): losa con pretil bajito, mismo precio por celda.
- **Escaleras**: de caracol (2×2) y metálica exterior (1×3, `outdoor`: en la
  planta baja va sobre el pasto). La navegación ahora une TODOS los pisos con
  sus escaleras (antes solo la planta baja).
- **Pilares** (`kind: pillar`, 1×1, `outdoor`): un piso de arriba se apoya si
  hay un pilar de abajo a 2 celdas o menos (`PILLAR_REACH`). El pilar no se
  puede quitar si algo depende de él.
- **"Lo que falta"** (`HouseRules.problems`): pisos sin acceso (sin escalera
  terminada que llegue) y piezas sin apoyo (casas viejas o reglas nuevas).
  Solo en modo construir: arriba "Falta: N" con la lista, y las piezas con
  problema en rojo. Se recalcula como mucho cada 0,4 s.
- **Copiar contorno de abajo**: losa completa (menos el hueco de las
  escaleras) + paredes donde termina el piso de abajo, con el mismo tipo de
  pared. Queda esperando Confirmar (se ve el precio).
- **Cuartos** (`scripts/house/house_rooms.gd`, `data/rooms.json`): área de piso
  cerrada por paredes (las puertas cuentan como pared; un área de más de 400
  celdas o que se sale del piso sin pared no es cuarto). Cada mueble suma
  puntos a los tipos (dormitorio, cocina, baño, sala, estudio); si el segundo
  tiene al menos el 60 % del primero, es **multiuso**. El cuarto de la Tienda
  es el que está en el centro de la cámara (si no, el del personaje).
- **Catálogo**: categorías nuevas (Techos, Escaleras y pilares,
  Electrodomésticos, Electrónica, Plantas, Adornos) y piezas nuevas
  (escritorio, plantas, lámpara, florero, pilar, escaleras, techo plano).
- **Casa compartida: propuesta** (amplía el "Pedir permiso"). Lo estructural
  no se manda: se aplica en el teléfono como **propuesta** (se ve de verdad,
  con las reglas sobre todo lo anterior). Mientras hay propuesta, todo va a
  ella (también lo menor), Deshacer saca el último cambio, no se guarda en el
  archivo (se guarda la casa de verdad) y no se pone al día con el servidor.
  **Mandar** junta todo (lo último de cada lugar) en UN pedido (`build_apply`
  de siempre). La pareja la ve con **Menú → Casa → Ver** (RPC nueva
  `home_request`: las piezas del pedido) aplicada en su casa, con una barra
  "Aprobar / No / Cerrar". Para salir a Vivir hay que mandarla o
  descartarla. Se hizo así también con la pareja fuera de línea (la
  propuesta queda esperando, como los pedidos de la Fase 5).
- **Cámara por piso**: con 5 pisos la cámara sube a la altura del piso que se
  mira (`CameraRig.floor_height`), si no quedaba metida entre paredes.
- **Versión 0.7.0.**

## Restaurante (Fase 6) — 2026-11-04, sesión en la nube

Sub-fases: **6A — servidor** (reglas, simulación del minijuego, RPC y pruebas
en Lua) y **6B — teléfono** (simulación copia, panel, minijuego, pruebas y
demo con capturas).

### Dónde vive el restaurante en la parcela
- **Un edificio (o cuarto) aparte en la parcela, no "la casa marcada como
  negocio".** La parcela es de 32 × 32 y VISION dice que ahí caben la casa y
  un negocio al lado. El jugador arma el restaurante donde quiera (lo normal:
  un edificio aparte) con los muebles de la categoría nueva **Restaurante**
  de la Tienda: **Mostrador** ($250), **Plancha de restaurante** ($450, la
  plancha del minijuego), **Mesa de restaurante** ($120) y **Banquito** ($30).
- **Abrir = convertir la propiedad en negocio**: el servidor revisa que la
  casa tenga al menos 1 mostrador, 1 plancha y 1 mesa **terminados** (una obra
  en marcha no cuenta). Lo que pide está en `data/business.json` (`requires`).
- Por qué así y no "declarar zonas": declarar qué edificio es casa y cuál es
  negocio (VISION, "Parcela") es una herramienta nueva de dibujo y de datos
  que la fase no pide. Con esto el restaurante ya vive "al lado" y el día que
  existan zonas se le agrega su rectángulo sin cambiar el minijuego ni el
  servidor. El cuarto "Restaurante" de `rooms.json` hace que la Tienda
  recomiende lo de restaurante cuando la cámara mira ese edificio.
- **Cada mesa de restaurante es un lugar** para un cliente (hasta 3). Más
  mesas = más clientes a la vez (y más ingresos posibles), pero dentro del
  minijuego gana la habilidad: un servicio con 1 mesa es más tranquilo.
- Nivel 1 (todo desbloqueado de entrada): es el primer negocio y para la
  familia conviene probarlo ya. Cambiarlo es `unlock_level` en el catálogo.

### El minijuego: "Servicio" (1:30)
- Propio, sin copiar otro juego: arriba las **mesas** con clientes chibi y su
  pedido en un globito (2 a 4 ingredientes); abajo **6 ingredientes** (pan,
  lechuga, tomate, queso; **tortita** y **huevo** van a la **plancha**). Lo
  frío va directo al plato; lo caliente se cocina 2,5 s y hay que sacarlo en
  los 3 s siguientes, cuando **brilla** (después se **quema** y hay que
  tirarlo). Tocar al cliente le sirve el plato.
- **El orden del plato no importa** (con el dedo, pedir orden exacto frustra).
- Pago: $3 por ingrediente + **propina** (hasta $5, baja con la espera) +
  **racha** (+$1 por cada plato bien seguido, hasta +$4). Plato equivocado:
  el cliente pierde 5 s de paciencia y se corta la racha. Si se le acaba la
  paciencia, se va (sin multa). Si las mesas están llenas, el que llega sigue
  de largo.
- Se pone más difícil cada 30 s (pedidos más grandes, llegan más seguido,
  menos paciencia). Un jugador ordenado gana ~$200–250 por servicio; jugando
  normal, $100–200.
- Todo con figuras dibujadas por el juego (sin arte final). Nada de rombos
  ni íconos de otros juegos (`docs/riesgos-legales-ea.md`).

### Anti-trampa: el servidor repite el servicio
- El teléfono **nunca manda un puntaje**. Al empezar, el **servidor** elige
  una **semilla** y anota la hora (`service_start`). Con esa semilla, el
  teléfono y el servidor arman la misma lista de clientes.
- Al terminar, el teléfono manda **solo los toques**: `[t (ms), acción,
  número]`. El servidor (`service_finish`) revisa: que pasaron los 90 s
  (margen 3 s), máximo 400 toques, en orden, **no más rápidos que 70 ms**
  entre uno y otro, números válidos; y **repite el servicio** con
  `neighborhood_business.lua`. Paga lo que calcula él. Si algo no vale, el
  servicio se **anula** (no paga, queda anotado). Un servicio se cobra una sola
  vez; no se puede tener dos a la vez.
- Para que dé **exactamente** lo mismo en Lua y en GDScript: solo números
  enteros (ms) y un generador al azar simple (**Park-Miller**). Las pruebas
  de los dos lados comparan los mismos números (semilla 4242: 17 clientes,
  llegadas que suman 719677, etc.) y la demo compara el servidor real con el
  teléfono.
- Límite conocido: un programa que juegue "perfecto" a velocidad humana
  ganaría lo máximo, pero el **tope diario** acota eso (y es un juego en
  familia).

### Ingresos, topes y "nada castiga"
- **Tope diario del minijuego: $600** por jugador cada 24 h (desde la primera
  ganancia). Llegado el tope se puede seguir jugando, pero no paga ni da
  experiencia.
- **Caja del restaurante (clientes de paso)**: abierto, junta **$20 por hora
  hasta $160** (8 h), con la hora del servidor, aunque nadie entre: VISION
  dice "los negocios acumulan ganancias hasta un tope; nada se pierde por no
  entrar". Se cobra con "Cobrar caja". Llegado el tope deja de juntar (no
  se pierde lo juntado).
- Si se corta la conexión o se cierra el juego **en medio de un servicio**,
  los toques quedan guardados en la partida (`GameState.restaurant`) y se
  mandan solos al volver; el servidor los acepta **hasta 24 h** después.
- Sin conexión (o "Jugar sin conexión") se puede **Practicar**: el mismo
  juego, sin cobrar.
- Experiencia: 1 por cliente atendido (solo si el servicio pagó algo).

### Casa compartida (reglas de la Fase 5)
- El restaurante es del **hogar** (`game/home` del dueño de la casa,
  campo `business`): viviendo juntos, es de los dos y los dos pueden atender.
- **Abrir o cerrar** el restaurante es cambio **estructural** ("convertir en
  negocio", VISION): queda como **pedido** que la pareja aprueba en Menú →
  Casa (sin botón "Ver": no tiene piezas).
- Lo que junta solo (caja del restaurante) va a la **caja de la casa**.
- Lo del minijuego es el trabajo de cada uno: a su **billetera**, o a la caja
  con **"unir ingresos"**. Cada uno tiene su propio tope diario.
- Si se separan, el restaurante queda con la casa (con su dueño).

### Técnica
- Reglas en `server/nakama/modules/neighborhood_business.lua` (sin Nakama,
  se prueban con `lua5.1`), copia en `scripts/business/restaurant_sim.gd`.
  Lo de cada jugador en `game/business` (servicio en marcha, tope del día,
  récord); el negocio en `game/home.business`.
- RPC nuevas: `restaurant_load`, `restaurant_open`, `restaurant_close`,
  `restaurant_collect`, `service_start`, `service_finish`.
- Autoload nuevo `Restaurant` (habla con el servidor); pantalla
  `ui/restaurant_game.gd` (todo dibujado con `_draw`, un solo nodo: liviano
  para el teléfono); panel `ui/restaurant_panel.gd` (Menú → Restaurante).
- `tests/restaurant_bot.gd`: jugador automático **solo para pruebas y demos**.
- **Versión 0.8.0.**


## Pulido 2A — errores y claridad (2026-11-04, nube, rama `pulido-2`)

Decisiones menores tomadas por el desarrollador (el dueño no las pidió una por una):

### Techos y pisos
- **Causa real del techo "trabado"**: el selector de pisos ofrecía solo "lo
  construido + 1", y un techo (o un mueble) en un piso más alto quedaba en un
  piso al que no se podía ir; además un techo roto (sin medidas o fuera de la
  parcela) no se podía tocar. Arreglo: **todo piso que tiene algo (en cualquier
  capa, incluidos techos) existe** (`HouseData.floors_total`), y **al cargar se
  sacan los techos rotos** (`HouseData.repair`, y lo mismo en el servidor,
  `rules.repair_house`). Prueba que lo reproduce: `test_house.gd`
  `_test_pulido2_roofs_and_floors` y la demo `polish2a_demo` (techo en el piso 3).
- Los techos del piso de abajo también se pueden tocar desde el piso actual
  (se ven desde ahí).
- **No hay piso "de regalo"**: la cantidad de pisos = el más alto con algo, o
  los que se agregan con **Agregar piso** (Obra). `floor_count` se guarda en
  la casa del teléfono; el servidor no lo guarda (un piso agregado y vacío se
  pierde al recargar desde el servidor: no pasa nada, no tiene nada).
- **Agregar piso** pide algo construido en el piso de arriba y una parte sin
  techo (el techo no sostiene nada). Mensajes en `HouseRules.add_floor_problem`.

### Basurero
- **Borra TODO** (techo, pared, cimiento, piso, mueble). Si algo se apoyaba solo
  en la pieza, se borra **con ella en cascada** (`HouseRules.removal_closure`):
  la pregunta lo dice ("¿Borrar la pared y 1 pieza que se apoya?"), todo se ve
  en rojo y hay que confirmar. Ya no hay "no se puede borrar, tiene algo
  encima". El servidor no cambia: ya revisa el pedido entero (`check_batch`).
  Mover con las flechas sigue sin permitir lo que deja algo en el aire.

### Interfaz
- **Obra** tiene tres modos con ícono: **Construir** (llave y martillo),
  **Modificar** (cruz de flechas) y **Borrar** (basurero). "Borrar" ya no es una
  herramienta aparte de la barra. **Agregar piso** es un botón al lado de los modos.
- **Menú hamburguesa**: el mismo botón lo abre y lo cierra, y tocar afuera lo cierra
  (comparte el velo transparente de la tarjeta del ánimo).
- **Márgenes**: arriba 34 px, abajo 22 px (en el menú de construir se siente
  un poco menos); los costados siguen en 16.
- **Cámara**: 5 inclinaciones (`CameraRig.PITCH_PRESETS`: de frente −8°, baja
  −25°, normal −50° [la de antes], alta −70°, desde arriba −89°). Un botón
  (ícono de ángulo, a la izquierda) las recorre; se guarda con la cámara.
- **Selector de pisos de frente** (`ui/floor_map.gd`, reemplaza la maqueta
  vista desde arriba): holograma azul semitransparente, solo paredes de afuera
  con puerta y ventanas dibujadas (las que miran hacia la cámara), techo, un color
  por piso, punto parpadeante del personaje, flechas arriba/abajo y botones para
  girar de a 45° (8 ángulos; se recuerda en `settings.floor_front_angle`).
  Colores, grosor y alto se cambian en las constantes de la clase.

### Construcción planificada y factura
- En **Construir/Tienda**, lo que se agrega **no se paga ni se pone de una**: queda
  como **plan** (se ve tal cual, un poco transparente, y **brilla 0,8 s cada
  3 s**). Aparece arriba "Obra prevista: N pasos · $X" con **Factura** y
  **Descartar**; Deshacer saca el último paso del plan.
- **Factura** = lista agrupada por pieza, total y espera. **Confirmar** quita lo
  previsto y construye de verdad con el flujo de siempre (cobra, temporizador,
  y en pareja pide la aprobación de la Fase 5). Si falta plata o no hay conexión,
  el plan queda como estaba.
- Mover, pintar y borrar siguen siendo inmediatos (no son "agregar"). No se puede
  pasar a Vivir con un plan abierto (hay que confirmar o descartar).
- En casa compartida, un cambio estructural convierte el plan en la
  **propuesta** de siempre (misma barra, misma aprobación).
- `HouseBuilder.plan_enabled` lo apaga (las demos viejas construyen de una).
- La **entrega con camión** de lo comprado va en 2C.

### Técnica
- Íconos nuevos en `assets/icons/` (build_tools, move, add_floor, invoice,
  camera_angle, truck, sound). Señales nuevas en `EventBus`.
- Versión **0.9.0** (`project.godot` y `export_presets.cfg`, código 9).
