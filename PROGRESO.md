# Progreso

## Fase actual: 6 — Primer negocio: restaurante (hecha y probada en la nube; falta probarla en la PC y en el teléfono)

**Próximo paso:** [Claude, cuando lo pidas] traer la rama `fase-6`, reiniciar
Nakama y correr las pruebas en la PC; después el dueño prueba el
restaurante en el teléfono (checklist de abajo). Siguen pendientes las
pruebas del Pulido 1 y de la Fase 5 en los teléfonos (más abajo).

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
