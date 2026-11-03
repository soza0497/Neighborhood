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
- **Centrar** vuelve la cámara al inicio. La cámara y la casa se guardan solas.

## Construir (modo Construir)

1. Abajo elegí una **categoría** y una **pieza**. Arriba aparece qué hacer.
2. Arrastrá sobre el lote: se ve en **verde** lo que se puede poner y en
   **rojo** lo que no. Muebles, puertas, ventanas y pintura se aplican al
   soltar. Cimientos, pisos, paredes, cuartos y techos quedan **esperando**:
   aparecen dos círculos (manijas) que podés arrastrar para ajustar, y se
   aplican con **Confirmar** (en la PC, Enter; Cancelar o Escape descarta).
3. Tocar **fuera de la parcela** siempre mueve la cámara, aunque haya una
   pieza elegida. La parcela mide 32 × 32 m: cabe más de una construcción.
4. Orden lógico: **Cimientos** → **Cuarto** (o Piso + Pared) → **Puertas y
   ventanas** → **Muebles** → **Pintura** → **Techo**.
5. **Subir / Bajar** (izquierda) cambia de piso. Arriba, el piso va sobre
   otro piso o junto a una pared de abajo (sirve para balcones). La
   **Escalera** se pone en la planta baja.
6. Dos ventanas iguales una al lado de la otra se unen solas en una ventana
   larga. Con **Unir / separar** (en Puertas y ventanas) se tocan para separarlas o volver a unirlas.
7. **Borrar** (abajo a la derecha): la pieza elegida pasa a quitar en vez de poner.
8. Muebles: **Mover (mano)** toca un mueble para elegirlo, arrastralo para
   moverlo; **Girar** y **Quitar** actúan sobre el elegido.
9. **Deshacer / Rehacer** arriba (en la PC también Ctrl+Z / Ctrl+Y).
10. **Vista** (solo afecta al piso actual; los de abajo se ven completos y los de arriba no se dibujan) cambia entre: completa (con techo), sin techo, paredes bajas.
11. Tocar otra vez la pieza elegida la suelta (vuelve el dedo a mover la cámara).
12. **Vivir** vuelve al modo vivir (el juego arranca ahí).

## Vivir (modo Vivir)

- Tu personaje vive solo: cuando tiene hambre, sueño, está sucio o aburrido,
  busca un mueble que lo ayude (refrigeradora, cocina, cama, ducha, tele...).
- A la izquierda: sus necesidades (Comida, Energía, Limpieza, Diversión), su
  ánimo y qué está haciendo. Arriba: el reloj del juego y la velocidad
  (**x1**, x3, x10). A x1, 1 segundo real = 1 minuto del juego.
- **Tocá un mueble** para darle una orden (por ejemplo, "Ver tele").
- **Menú** (arriba): **Personaje** cambia nombre, colores y hasta 2 rasgos
  (Cocinero, Perezoso, Gamer...); **Diario** muestra lo que hizo y cómo se
  sentía, con caritas; **Opciones** muestra u oculta FPS y ayudas.
- **Subir / Bajar** también funciona en Vivir: se ve solo hasta ese piso.
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

La primera revisa las reglas de construcción y el deshacer; la segunda, las
necesidades, la IA y los caminos; la tercera, precios, niveles, obras, empleos
y la migración del guardado; la cuarta, el cliente del servidor (sin red). Deben terminar con
`PRUEBAS: N pasaron, 0 fallaron`. (`tests/visual_demo.tscn`,
`tests/character_demo.tscn` y `tests/economy_demo.tscn` arman casas de ejemplo y sacan capturas, pero
**pisan la partida guardada**. `tests/server_demo.tscn`,
`tests/economy_server_demo.tscn` y `tests/login_demo.tscn` prueban contra el
servidor de verdad: ver `docs/servidor.md`.)

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
| `scripts/` | Código. `autoload/` = sistemas siempre presentes; `house/` = la casa, el constructor y los caminos; `character/` = el personaje y su IA |
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
  opciones a la nube, avisar "sigo jugando").
- **SaveSystem**: guarda/carga `GameState` en `user://save.json` (con copia de
  respaldo y migración de versiones viejas)
  (en la PC: `~/.local/share/godot/app_userdata/Neighborhood/`).
