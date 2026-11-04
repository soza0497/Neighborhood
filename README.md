# Neighborhood

Juego móvil caricaturesco: construir tu casa, vivir en ella con un personaje
con IA, compartirla con tu pareja y formar un barrio con tu familia.
Hecho con **Godot 4.7.2** (GDScript).

- A dónde vamos: [`VISION.md`](VISION.md)
- En qué fase estamos: [`PROGRESO.md`](PROGRESO.md)
- Por qué se eligió cada cosa: [`DECISIONES.md`](DECISIONES.md)

## Abrir el proyecto

1. Abrí **Godot** desde el menú de aplicaciones.
2. En el Administrador de proyectos: **Importar** → elegí el archivo
   `project.godot` de esta carpeta → **Importar y editar**.
3. La próxima vez aparece en la lista: doble clic.

## Correr el juego en la PC

- Botón ▶ (arriba a la derecha) o tecla **F5**. Para cerrar: **F8** o cerrar la ventana.
- Cámara con mouse: **rueda apretada** (o clic izquierdo sin pieza elegida)
  mueve el mapa, **clic derecho** gira, **rueda** acerca/aleja.
- Cámara táctil: con 1 dedo se mueve el mapa **solo si no hay pieza elegida**;
  con 2 dedos siempre se mueve, pellizca y gira.
- La **brújula** (flechita, a la izquierda) apunta hacia tu personaje;
  tocarla centra la cámara en él. La cámara y la casa se guardan solas.

## La pantalla (Pulido 1)

Casi vacía, con íconos propios (dejando el mouse encima, en la PC, se ve qué
hace cada uno):

- **Arriba a la izquierda**: dinero y nivel; el **ánimo** (carita + palabra:
  tocalo para ver las necesidades con su barra y qué está afectando el
  ánimo; tocar afuera la cierra); tu pareja (punto + nombre); las obras.
- **Arriba a la derecha**: deshacer / rehacer (construir), velocidad **x1, x2,
  x5** (vivir), construir / vivir (casco o casita) y el **menú** (tres rayas).
- **A la izquierda**: el ícono del **techo** (tachado = sin techos), el de las
  **paredes** (altas o bajitas, siempre del piso que estás viendo), la
  **maqueta de pisos** (tocá un piso para ir: el actual va en naranja y el
  punto rosado es tu personaje) y la **brújula**.
- **Menú → Info**: FPS, versión, conexión, día y hora, caja de la casa y lo
  que hace tu pareja. Ahí está **Mostrar FPS en pantalla** para medir en el
  teléfono. Hasta **5 pisos**.

## Construir (constructor 2.0)

Abajo hay tres herramientas:

1. **Tienda** (bolsa): muebles, electrodomésticos, electrónica, plantas y
   adornos. Si la cámara mira un **cuarto** (área cerrada por paredes), la
   primera pestaña es **★ ese cuarto** (por ejemplo "★ Dormitorio") con lo
   que le va; nada está prohibido.
2. **Obra** (casco), con dos modos:
   - **Agregar** (+): cimientos, cuartos, paredes, pisos, puertas, ventanas,
     techos (de tejas o **plano de concreto**), escaleras (recta, **de
     caracol**, **metálica exterior**) y **pilares**. Arrastrá sobre el lote:
     verde se puede, rojo no. Cimientos, pisos, paredes, cuartos y techos
     esperan **Confirmar** (con dos círculos para ajustar). En un piso de
     arriba, el botón **Copiar contorno de abajo** pone la losa y las paredes
     de afuera de una vez.
   - **Modificar** (mano): **tocá un mueble** y aparecen flechas **N/S/E/O**,
     girar (de a 45°: 8 direcciones) y borrar. **Mantené presionado** un
     mueble para llevarlo con el dedo. Tocá una **pared, techo, piso o
     cimiento** para ver qué se le puede hacer (mover, pintar, borrar). Los
     **puntitos** entre dos ventanas son las junturas: tocalos para unirlas o
     separarlas. Abajo están los **colores**: elegí uno y **tocá una pared**:
     se pinta solo esa cara (adentro o afuera) y aparecen flechas para pintar
     la de al lado. **Mantené presionado** para pintar arrastrando (solo
     paredes si empezaste en pared, solo pisos si empezaste en piso).
3. **Borrar** (basurero): tocá algo, se pone rojo y pregunta "¿Borrar el
   techo? Te devuelven $X". Con **modo selección** (cuadraditos, a la
   derecha) vas tocando varias cosas y las borrás todas juntas. Mantené
   presionado y arrastrá para elegir muchos pisos o paredes. Una pared o un
   pilar que **sostiene** algo de arriba no se puede borrar (te dice por qué).

Reglas que conviene saber:
- Arriba, el piso va sobre otro piso, junto a una pared de abajo o **cerca de
  un pilar** (a 2 celdas). Así se hacen balcones, casas elevadas y puentes.
- **Sin escalera no se sube**: un piso sin escalera que llegue queda "sin
  acceso". Arriba aparece **Falta: N** con la lista; lo que tiene problemas
  se ve en rojo.
- No se puede poner un techo donde lo atraviesa una pared (o un piso) del
  piso de arriba.
- Arrastrar sin mantener presionado (en Modificar y Borrar) mueve la cámara.
- **Deshacer / Rehacer** arriba (en la PC también Ctrl+Z / Ctrl+Y).

## Vivir

- Tu personaje vive solo: cuando tiene hambre, sueño, está sucio o aburrido,
  busca un mueble que lo ayude (refrigeradora, cocina, cama, ducha, tele...).
- Tocá el **ánimo** (arriba) para ver sus necesidades y qué está haciendo.
  Velocidad **x1, x2, x5**: a x1, 1 segundo real = 1 minuto del juego.
- **Tocá un mueble** para darle una orden (por ejemplo, "Ver tele").
- **Menú**: **Personaje** cambia nombre, colores y hasta 2 rasgos; **Diario**
  muestra lo que hizo y cómo se sentía; **Info** y **Mostrar ayudas**.
- La maqueta de pisos también funciona en Vivir: se ve solo hasta ese piso.
- En modo Construir el tiempo se detiene. Las necesidades nunca bajan de un
  mínimo, y si no jugás un tiempo, solo bajan un poco.

## Dinero, niveles, obras y empleos

- Arriba a la izquierda: tu **dinero**, tu **nivel** y la barra de experiencia.
  Empezás con $3000.
- **Construir cuesta**: cada pieza tiene su precio en la barra. Al soltar o
  confirmar, ves cuánto pagaste. Borrar piezas devuelve el 50 %. **Deshacer
  devuelve todo lo que pagaste** (si todavía te alcanza el dinero).
- **Piezas bloqueadas**: algunas dicen "Nivel 2" o "Nivel 3". La experiencia
  sale de construir **por primera vez** cada tipo de pieza y de trabajar.
- **Obras**: muebles, escaleras y techos tardan unos segundos o minutos
  (reales, siguen corriendo con el juego cerrado) y se ven en naranja
  transparente. El botón **Obras: N · Acelerar $X** arriba las termina todas.
- **Empleos** (Menú → Empleos): mandás un currículum, esperás la respuesta
  (5, 10 o 30 minutos reales; se puede acelerar con monedas) y te contratan.
  Cada día, a su hora, tu personaje sale a trabajar (desaparece unas horas)
  y cobra al volver. Si cerrás el juego, el turno igual se cobra.
- **Nada castiga por desconectarse**: mientras no jugás, el trabajo sigue
  pagando hasta 3 turnos y las obras y currículos avanzan solos.
- Para cambiar precios, niveles o sueldos: `data/catalog.json`
  (`price`, `unlock_level`, `build_seconds`), `data/jobs.json` y
  `data/progression.json`.

## Cuenta y servidor (Fase 4)

- Al abrir el juego aparece la **pantalla de entrada**: la primera vez,
  escribí un usuario (minúsculas, números o _) y una contraseña (mínimo 8) y
  tocá **Crear cuenta**. Después el teléfono recuerda la sesión y entra solo.
- La primera vez que una cuenta entra, se copia la partida del teléfono al
  servidor (casa, experiencia, piezas descubiertas, personaje y opciones). El
  dinero del servidor empieza en $3000.
- Arriba a la izquierda: **● Conectado: usuario** (verde) o **● Sin conexión**.
  Menú → **Cerrar sesión**.
- Desde la Fase 4B **el servidor manda en el dinero y la casa**: construir,
  deshacer, acelerar, mandar currículos y cobrar el trabajo se le piden a él
  (el juego espera su respuesta). **Fuera de casa** (sin conexión) se puede
  Vivir, pero **Construir queda apagado** ("Sin conexión al servidor").
- El servidor corre en esta PC con Docker: cómo arrancarlo, ver sus mensajes,
  entrar a su consola o cambiar la IP en [`docs/servidor.md`](docs/servidor.md).
  La dirección que usa el juego está en `data/server.json`.

## Pareja y casa compartida (Fase 5)

Todo pasa por el servidor: hace falta estar conectado (en la red de casa).

- **Menú → Pareja**: escribí el usuario de tu pareja y tocá **Invitar**. Le
  llega al instante; cuando acepta, son pareja. Desde ahí también: **Proponer
  casamiento**, **Vivir juntos en mi casa** o **Mudarme a su casa** (la otra
  persona acepta o dice que no), y **Terminar la relación** (tocar dos veces).
  Los interruptores **Permitir drama** y **Modo familiar** quedan preparados
  (todavía no hay drama en el juego).
- Arriba a la izquierda: **● nombre** (rosado = en línea). En **Menú → Info**:
  "en línea · cocinando (Cocina)".
  Viviendo juntos, el personaje de tu pareja aparece en la casa (con su nombre
  encima) y hace lo mismo que en su teléfono: si cocina, va a la cocina y
  cocina. Si está fuera de línea, vive solo con su IA.
- **Cambios menores** (mover, girar y pintar muebles, pintar paredes y pisos,
  poner un mueble nuevo, unir/separar ventanas): se hacen al instante. A la
  otra persona le aparece un aviso arriba con **Deshacer**.
- **Remodelar** (cimientos, pisos, paredes, puertas, ventanas, techos,
  escaleras, y quitar/vender cualquier cosa) se arma como **propuesta**: vas
  haciendo todos los cambios (se ven en tu casa y Deshacer saca el último),
  y arriba aparece **Mandar a (tu pareja)** o **Descartar**. Tu pareja, en
  **Menú → Casa → Ver**, la ve en su casa y la **aprueba o no entera**. Al
  aprobarla se construye y la paga quien la propuso. Y al revés.
- **Menú → Casa**: la **caja de la casa** (aportar $100, $500, $1000), **Unir
  ingresos** (tu sueldo va a la caja), los **pedidos de permiso** y el
  **historial** de la casa. Lo que se construye se paga primero con la caja; lo
  que falta, con tu billetera. Lo que se vende vuelve a la caja.
- Si los dos editan a la vez, en los cambios menores gana el último. Tu
  **Deshacer** nunca pisa lo que cambió tu pareja después (ese paso se
  descarta y te avisa).
- Al terminar: la casa queda de quien era, quien se había mudado vuelve a su
  casa de antes (quedó guardada), y la caja se reparte en dos.

## Restaurante (Fase 6)

Tu primer negocio. Todo lo de dinero lo decide el servidor (hace falta estar
conectado, en la red de casa).

- **Armarlo**: en tu parcela (lo normal, un edificio aparte al lado de la
  casa), **Construir → Tienda → Restaurante**: un **Mostrador**, una
  **Plancha de restaurante** y al menos una **Mesa de restaurante** (cada mesa
  es un cliente más a la vez, hasta 3). Los **Banquitos** son de adorno. La
  Tienda, mirando ese edificio, recomienda primero "★ Restaurante".
- **Menú → Restaurante**: dice qué le falta, **Abrir restaurante**, la **caja
  del restaurante** (junta sola $20 por hora, hasta $160, aunque no entres:
  **Cobrar caja**) y lo ganado hoy (tope **$600** cada 24 h).
- **Atender (1:30)**: el minijuego. Arriba llegan clientes con su pedido en
  un globito. Abajo tocás los ingredientes para armar el plato: pan, lechuga,
  tomate y queso van directo al plato; **tortita** y **huevo** (con llamita)
  van a la **plancha**: cuando brillan están a punto, tocalos para pasarlos
  al plato (si esperás demasiado se queman: tocalos para tirarlos). Después
  **tocá al cliente** para servirle. El orden no importa. Rápido = propina;
  bien seguido = racha. Equivocarse lo enoja un poco. **Tirar** vacía el
  plato.
- Al terminar, el teléfono manda **solo lo que tocaste**; el servidor repite
  el servicio y paga lo que calcula él. Si te quedás sin conexión justo al
  final, se cobra solo cuando vuelvas.
- **Practicar**: el mismo juego sin cobrar (sirve también sin conexión).
- Viviendo juntos: abrir o cerrar el restaurante pide permiso a tu pareja; lo
  que junta solo va a la caja de la casa; lo que ganás atendiendo va a tu
  billetera (o a la caja, con "Unir ingresos").
- Los números (precios del servicio, tiempos, topes, qué muebles pide) están
  en `data/business.json`. Si los cambiás, reiniciá Nakama: el servidor lee el
  mismo archivo.

## Pruebas automáticas

En la terminal, dentro de la carpeta del proyecto:

```bash
godot --headless --path . res://tests/test_house.tscn
```

```bash
godot --headless --path . res://tests/test_character.tscn
```

```bash
godot --headless --path . res://tests/test_economy.tscn
```

```bash
godot --headless --path . res://tests/test_server.tscn
```

```bash
godot --headless --path . res://tests/test_couple.tscn
```

```bash
godot --headless --path . res://tests/test_business.tscn
```

La primera revisa las reglas de construcción y el deshacer; la segunda, las
necesidades, la IA y los caminos; la tercera, precios, niveles, obras, empleos
y la migración del guardado; la cuarta, el cliente del servidor (sin red); la
quinta, la pareja y la casa compartida (sin red); la sexta, el restaurante y
su minijuego (que el teléfono cuente igual que el servidor). Deben terminar con
`PRUEBAS: N pasaron, 0 fallaron`. (`tests/ui_demo.tscn` prueba la interfaz
y el constructor nuevos con clics de verdad y saca capturas `ui_*.png`;
`tests/visual_demo.tscn`,
`tests/character_demo.tscn` y `tests/economy_demo.tscn` arman casas de ejemplo y sacan capturas, pero
**pisan la partida guardada**. `tests/server_demo.tscn`,
`tests/economy_server_demo.tscn`, `tests/login_demo.tscn`,
`tests/couple_demo.tscn`, `tests/couple_live_demo.tscn` y
`tests/restaurant_demo.tscn` (Fase 6, con capturas `restaurante_*.png`) prueban contra el
servidor de verdad: ver `docs/servidor.md`.)

**Pulido 2** (versión 0.9.0): `tests/polish2a_demo.tscn` (errores y claridad: menú,
techo trabado, basurero, Agregar piso, selector de frente, plan con factura;
capturas `p2a_*.png`) y `tests/polish2b_demo.tscn` (estilo toon, entorno, modelos
`.glb`, trabajo con saco y maleta, sonido; capturas `p2b_*.png`). Se corren con
ventana (`godot --path . res://tests/polish2a_demo.tscn`) o, sin pantalla, con
`xvfb-run`. Para cambiar el **estilo** (contorno, tonos, colores, niebla) editá
`data/style.json`; el **mundo** (bosque, vecinos, calle, autos) está en
`data/world.json`; cómo meter un **modelo `.glb`** nuevo: `docs/estilo.md`.

**Pulido 3** (versión 0.10.0; brief en `docs/pulido-3.md`): **3A** — la zona disponible empieza en 64 × 64
pegada a la calle (con niveles se abre hasta 96 × 96), con vallas de madera y vecinos a los costados; la casa
va cerca de la calle y el personaje esquiva árboles y rocas. Pruebas: `test_parcel.tscn` (sin pantalla),
`lua5.1 server/tests/test_rules.lua` y `tests/polish3a_demo.tscn` (con ventana; capturas `p3a_*.png`).
Los datos (zona, desbloqueos, casa) están en `data/parcel.json`; las vallas y vecinos, en `data/world.json`.
**3B** — área segura de la pantalla, mueble que se gira antes de confirmar, rejilla flotante del techo, barra del
ángulo de la cámara, maqueta de pisos sin aristas del fondo, tipo de cuarto elegido por el jugador (dormitorio
principal) y creación de personaje al registrarse (peinados, ojos y bocas en `data/character_options.json`).
Prueba: `tests/polish3b_demo.tscn` (con `xvfb-run -s "-screen 0 2560x2560x24"` para los tamaños de pantalla).
**3C** — paredes con contorno continuo: `tests/polish3c_demo.tscn`.

**2C — parcela de 96 × 96, servicios y sótanos:** `godot --headless --path . res://tests/test_parcel.tscn`
(reglas de la parcela, sin pantalla ni red), `tests/polish2c_demo.tscn` (con ventana: limpiar
obstáculos con jardinero / tractor, entrega con camión y cajas, ambulancia y sótanos; capturas
`p2c_*.png`) y `tests/parcel_server_demo.tscn` (contra el servidor de verdad). Los obstáculos, sus
precios y esperas están en `data/parcel.json` (**reiniciá Nakama si lo cambiás**).

Y las reglas del servidor (opcional, necesita Lua 5.1, ver `docs/servidor.md`):

```bash
lua5.1 server/tests/test_rules.lua
```

## Exportar a Android

La primera vez hay que instalar Java y el SDK de Android: guía paso a paso en
[`docs/android.md`](docs/android.md). Después:

- **Con cable:** botón de Android arriba a la derecha en Godot.
- **Sin cable:** Proyecto → Exportar… → Exportar proyecto → `build/neighborhood.apk`
  → pasarlo con LocalSend.

## Editar el catálogo

Las piezas (nombre, precio, tamaño, color) están en `data/catalog.json`.
Se puede abrir con cualquier editor de texto (Kate, VS Code). Reglas:
cada objeto lleva `id`, `name`, `category`, `kind` y `price`; los `id` en
inglés, sin espacios y sin repetir. `kind` dice qué herramienta usa (la lista
está en `_ayuda`, al principio del archivo). Para agregar un mueble, copiá uno
parecido y cambiale `id`, `name`, `footprint`, `height` y `color`. Si te equivocás, la consola de Godot (abajo, pestaña
"Salida") dice qué línea está mal.

## Carpetas

| Carpeta | Qué hay |
|---|---|
| `scenes/` | Escenas del mundo 3D (`main.tscn` = el juego; arranca después de `ui/login_screen.tscn`) |
| `scripts/` | Código. `autoload/` = sistemas siempre presentes; `house/` = la casa, el constructor y los caminos; `character/` = el personaje y su IA; `business/` = el restaurante y su minijuego (Fase 6) |
| `data/` | Datos editables: catálogo, acciones, rasgos, opciones del personaje |
| `ui/` | Interfaz (botones, textos) |
| `assets/` | Modelos, sonidos, texturas, shaders (casi vacía hasta la Fase 7) |
| `docs/` | Guías |
| `server/` | El servidor (Nakama con Docker); Godot no lo mira (`.gdignore`) |
| `tests/` | Pruebas automáticas (no van en el APK) |

## Sistemas globales (autoloads)

Están siempre cargados y se usan desde cualquier script por su nombre:

- **EventBus**: señales globales; los sistemas se avisan cosas sin conocerse.
- **Catalog**: lee `data/catalog.json` (piezas) y `actions.json`,
  `traits.json`, `character_options.json` (personaje). `Catalog.get_item("bed_basic")`.
- **GameClock**: el reloj del juego (velocidad, pausa, día y hora).
- **Economy**: dinero, experiencia, nivel, piezas descubiertas, obras con
  temporizador y empleo. Todo cambio de dinero pasa por aquí: con cuenta se
  lo pide al servidor (`Economy.request`); sin cuenta (solo las pruebas
  automáticas, "modo de prueba") lo calcula solo.
- **GameState**: todos los datos de la partida que se guardan.
- **GameServer**: la conexión con el servidor (cuenta, sesión recordada,
  indicador de conexión, llamar las funciones del servidor, subir personaje y
  opciones a la nube, avisar "sigo jugando"). Desde la Fase 5 también la
  conexión en tiempo real (`GameServer.socket`): avisos al instante y
  presencia de la pareja.
- **Restaurant** (Fase 6): el restaurante (abrir, cobrar la caja, empezar y
  cobrar un servicio con el servidor; guarda un servicio sin cobrar si se
  corta la conexión).
- **Couple** (Fase 5): la pareja y la casa compartida: relación, si la pareja
  está en línea y qué hace su personaje, caja, pedidos de permiso e historial.
- **SaveSystem**: guarda/carga `GameState` en `user://save.json` (con copia de
  respaldo y migración de versiones viejas)
  (en la PC: `~/.local/share/godot/app_userdata/Neighborhood/`).


**Fase 8** (versión 0.11.0, barrio): `tests/test_neighborhood.tscn` (sin pantalla: mapa, casas vecinas, vida, meta),
`lua5.1 server/tests/test_goals.lua` (meta del servidor) y `tests/neighborhood_demo.tscn` (con ventana; capturas
`n8*.png`). En el juego: menú ☰ → **Barrio** (vista aérea, visitar casas, privacidad, meta del barrio).
