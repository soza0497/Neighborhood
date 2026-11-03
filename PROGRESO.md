# Progreso

## Fase actual: 5 — Pareja y casa compartida (en curso, sesión en la nube, rama `fase-5`)

### Fase 5 — avance (2026-11-03)
- 5A (servidor) y 5B (teléfono) hechas y probadas contra Nakama 3.41.0 en la
  nube: Lua 187/187, sin red 231/231, `couple_demo` 66/66 (dos cuentas a la
  vez), demos viejas OK. Falta 5C: el personaje de la pareja animado en la
  casa compartida y la documentación completa (abajo se completa al terminar).

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

### Fase 5 — próximo paso exacto
Cuando la Fase 4 esté probada: en una conversación nueva (**Opus, esfuerzo
alto**): "Leé CLAUDE.md, PROGRESO.md, DECISIONES.md y VISION.md y hacé la
Fase 5". Antes hace falta la respuesta a la pregunta abierta de VISION.md
(¿la pareja usa Android o iPhone?).

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
- Fase 5 — Pareja y casa compartida (**Opus, esfuerzo alto**).
