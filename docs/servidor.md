# El servidor del juego (Nakama)

Desde la Fase 4, las cuentas viven en un **servidor** que corre en esta PC:
**Nakama** (un programa hecho para servidores de juegos) y su base de datos
(**PostgreSQL**, donde guarda todo). Los dos corren dentro de **Docker**, que
los mete en "contenedores": cajas aisladas que se arrancan y paran con un
comando.

| Contenedor | Qué es | Dónde se ve |
|---|---|---|
| `neighborhood-nakama` | El servidor del juego | Teléfonos: `192.168.100.177:7350` (solo red de casa). Consola: <http://127.0.0.1:7351> (solo esta PC) |
| `neighborhood-db` | Su base de datos | No se ve desde afuera: solo la usa Nakama |

Todo está en la carpeta `server/` del proyecto:

| Archivo | Qué hay |
|---|---|
| `docker-compose.yml` | La "receta" de los dos contenedores (puertos, carpetas) |
| `nakama/config.yml` | Configuración de Nakama (sin secretos) |
| `nakama/modules/neighborhood.lua` | El código del servidor: las funciones que llama el juego (`game_load`, `build_apply`…), y dónde guarda cada cosa |
| `nakama/modules/neighborhood_rules.lua` | Las **reglas** que decide el servidor (precios, obras, deshacer, empleos, turnos, caja de la casa, historial) |
| `nakama/modules/neighborhood_house.lua` | Fase 5: reglas de **apoyo** de la casa (nada en el aire) y qué cambio es menor o estructural |
| `nakama/modules/neighborhood_couple.lua` | Fase 5: la **relación** (invitar, aceptar, casarse, mudarse, terminar) |
| `nakama/modules/neighborhood_business.lua` | Fase 6: el **restaurante** y su minijuego (el servidor lo repite para saber cuánto pagar) |
| `tests/test_rules.lua` | Pruebas de esas reglas (sin Nakama, ver "Probar el servidor") |
| `.env` | **Secretos** (contraseñas y llaves). No va a Git. No lo compartas |
| `db-data/` | Los datos de la base (las cuentas y partidas). No va a Git |

El servidor lee el **mismo** `data/catalog.json` del juego (solo lectura),
y también `progression.json` (niveles), `jobs.json` (empleos) y, desde la
Fase 6, `business.json` (el restaurante): los precios están en un solo lugar.

## Qué decide el servidor (Fase 4B)

Desde la Fase 4B el servidor **manda en el dinero y la propiedad**. El
teléfono pide y espera la respuesta; si el servidor dice que no, no pasa nada
(y el juego muestra por qué). Si cambiás algo de `data/` (un precio, un
empleo), reiniciá Nakama para que lo lea.

| Lo que pide el juego | Qué hace el servidor |
|---|---|
| Construir, quitar, mover, pintar (`build_apply`) | Revisa que las piezas existan y estén desbloqueadas por nivel, cobra (o devuelve el 50 %), pone la hora de fin de obra con **su** reloj, da la experiencia de lo nuevo y guarda el paso de deshacer |
| Deshacer / rehacer (`build_undo`, `build_redo`) | Guarda hasta 100 pasos y devuelve **exactamente** lo cobrado |
| Acelerar obras (`build_accelerate`) | Cobra 6 monedas por minuto que falta y termina todas |
| Empleos (`job_apply`, `job_status`, `job_accelerate`, `job_quit`) | Currículum con espera en hora real; acelerar la respuesta cuesta igual que una obra |
| Turnos (`shift_start`, `shift_complete`) | Un turno se cobra si pasó al menos su duración a velocidad x5 (la más rápida desde el Pulido 1), y se empieza como mucho uno cada 288 s |
| Al entrar (`work_settle`) | Cobra el turno que quedó a medias y un turno por cada día del juego sin entrar (tope 3) |
| "Sigo jugando" (`game_heartbeat`) | Anota la hora, para no pagar como "días sin jugar" el tiempo que se jugó |

## Pareja y casa compartida (Fase 5)

El servidor también manda en la **pareja** y la **casa compartida**:

| Lo que pide el juego | Qué hace el servidor |
|---|---|
| Invitar, aceptar, casarse, mudarse, terminar (`couple_invite`, `couple_answer`, `couple_propose`, `couple_respond`, `couple_end`…) | Revisa que se pueda (una invitación por vez, no a alguien en pareja…), guarda la relación de los dos juntos y avisa al otro al instante |
| Construir en la casa compartida (`build_apply`) | Si es un cambio **menor** (mover, girar, pintar, mueble nuevo) lo hace y avisa; si es **estructural** (paredes, pisos, puertas, techos, escaleras, vender) lo guarda como **pedido**. Desde el Pulido 1 el teléfono junta toda una remodelación en una **propuesta** y la manda en un solo pedido; la pareja la ve con `home_request` (las piezas del pedido) antes de aprobarla |
| Aprobar o rechazar (`home_answer`) | Al aprobar, construye como si lo hubiera hecho quien lo pidió (paga la caja y su billetera) |
| Deshacer lo de la pareja (`home_revert`) | Solo cambios menores que nadie tocó después; el dinero vuelve a quien lo pagó |
| Aportar a la caja (`home_contribute`), "unir ingresos" (`couple_switches`) | La caja vive en el hogar de la casa; con "unir ingresos" el sueldo va a la caja |
| Siempre | Revisa las **reglas de apoyo**: nada queda en el aire (también al deshacer) |

Dónde se guarda (además de lo de la Fase 4): `game/relation` (la relación de
cada uno) y `game/home` (el hogar de cada casa: caja, pedidos, historial y
quién vive). Viviendo juntos, los dos usan la casa (`game/house`) y el hogar
del **dueño de la casa**; la casa del otro queda guardada sin tocar y vuelve
si se separan. Todo esto se ve en la consola (Accounts → la cuenta → Storage).

**Tiempo real**: el juego abre además un **WebSocket** con Nakama (la
dirección `/ws` del mismo puerto **7350**; no hace falta abrir nada nuevo). Por
ahí llegan los avisos al instante (la pareja movió algo, pidió permiso…) y se
ve si la pareja está en línea y qué hace su personaje (se manda solo un
"estado" corto, no los movimientos). Ojo: ese estado lo puede ver cualquier
cuenta del servidor que lo pida; para la familia no es un problema.

**Sin conexión** (fuera de casa) se puede **Vivir**, pero **no Construir**:
el botón queda apagado y avisa "Sin conexión al servidor". El personaje
tampoco sale a trabajar; al volver a casa, el servidor paga los días que
faltaron (tope 3).

## Restaurante (Fase 6)

| Lo que pide el juego | Qué hace el servidor |
|---|---|
| Ver el restaurante (`restaurant_load`) | Qué le falta (cuenta los muebles **terminados** de la casa), cuántas mesas, la caja que juntó solo y el tope de hoy |
| Abrir / cerrar (`restaurant_open`, `restaurant_close`) | Revisa que tenga mostrador, plancha y mesa. En la casa compartida es un **pedido** que la pareja aprueba (Menú → Casa) |
| Cobrar la caja (`restaurant_collect`) | Paga lo que juntó solo ($20 por hora con **su** reloj, hasta $160). En la casa compartida va a la caja de la casa |
| Empezar un servicio (`service_start`) | Elige la **semilla** (de ahí salen los clientes) y anota la hora. Uno por vez |
| Terminar un servicio (`service_finish`) | Recibe **solo los toques** del jugador. Revisa que pasaron los 90 s, que los toques sean posibles para una persona (no más de 400, no más rápido que 70 ms) y **repite el servicio** él mismo: paga lo que calcula, con tope de **$600 cada 24 h**. Si algo no vale, lo anula sin pagar |

Dónde se guarda: `game/business` (de cada jugador: servicio en marcha, lo
ganado hoy, récord) y el campo `business` de `game/home` (el restaurante de
la casa). En el "Wallet Ledger" los cobros dicen `service_finish` o
`restaurant_collect`.

> Todos los comandos de abajo se escriben en la terminal (fish), **dentro de
> la carpeta `server/`**. Para entrar a esa carpeta:
>
> ```bash
> cd ~/Documentos/Proyectos/MadeWithAI/Neighborhood/server
> ```

## ¿Está andando?

```bash
docker compose ps
```

Tiene que mostrar los dos contenedores con `Up` y `(healthy)` ("sano").
Otra forma, sin entrar a la carpeta: abrí <http://127.0.0.1:7350/healthcheck>
en el navegador. Si responde `{}`, está bien.

## Arrancar

```bash
docker compose up -d
```

`up` crea y arranca los contenedores; `-d` los deja corriendo en segundo plano
(sin ocupar la terminal). Si ya estaban andando, no hace nada. Se reinician
solos si se caen, y arrancan solos con la PC (ver "Después de reiniciar la PC").

## Ver qué está pasando (logs)

```bash
docker compose logs -f nakama
```

Muestra lo que va diciendo Nakama, en vivo (`-f` = "seguir"). Para salir:
**Ctrl+C** (esto solo deja de mirar; el servidor sigue andando). Cada línea es
un JSON; las importantes dicen `"level":"error"`. Cuando alguien importa su
partida aparece `Partida importada`.

## Reiniciar (por ejemplo, después de cambiar el código .lua o algo de `data/`)

```bash
docker compose restart nakama
```

Las sesiones de los teléfonos **no se pierden** al reiniciar (comprobado).

## Entrar a la consola de administración

La consola es una página web para ver cuentas, partidas guardadas y
billeteras. Solo se abre desde esta PC.

1. Abrí <http://127.0.0.1:7351> en el navegador.
2. Usuario: **`dueno`**.
3. Contraseña: está en `.env`. Para verla (aparece solo en tu terminal):
   ```bash
   grep NAKAMA_CONSOLE_PASSWORD .env
   ```
   Copiá lo que va después del `=`. Conviene guardarla en Proton Pass.

Qué mirar:
- **Accounts** (cuentas): cada jugador. Al abrir una se ve su **Wallet**
  (dinero; la pestaña **Wallet Ledger** muestra cada movimiento con su motivo:
  `build_apply`, `shift_complete`…) y su **Storage**: `game/house` (la casa),
  `game/progress` (experiencia), `game/work` (empleo y turnos), `game/history`
  (pasos de deshacer), `game/relation` (la pareja), `game/home` (caja,
  pedidos e historial de la casa), `cloud/character` (personaje) y
  `cloud/settings` (opciones). Los `game/*` solo los escribe el servidor.
- Desde la cuenta se puede **borrar** (por ejemplo, las cuentas `demo_…` que
  crea `tests/server_demo.tscn` si quedara alguna).

## Cambiar la IP (si el router le da otra a la PC)

La IP `192.168.100.177` **no está reservada en el router**: podría cambiar. Si
el juego dice "Sin conexión" estando en casa:

1. Mirá la IP actual de la PC:
   ```bash
   ip -4 addr show eno1
   ```
   Es el número después de `inet` (sin el `/24`).
2. Cambiala en **dos** archivos (con Kate o VS Code):
   - `server/.env` → línea `LAN_IP=…`
   - `data/server.json` → línea `"host": "…"`
3. Volvé a crear el contenedor de Nakama con la IP nueva:
   ```bash
   docker compose up -d
   ```
4. Exportá el APK de nuevo e instalalo en los teléfonos (la IP va adentro).

La solución de fondo es **reservar la IP en el router** (ya está en los
pendientes de la bitácora): así no cambia nunca.

## Después de reiniciar la PC

Docker arranca los contenedores solo. Pero si la PC todavía no tenía la IP de
la red de casa en ese momento, Nakama no puede "engancharse" a
`192.168.100.177` y queda parado (a AdGuard le pasaba lo mismo). Si el juego
dice "Sin conexión":

```bash
docker compose ps
```

Si `neighborhood-nakama` no está `Up`, arrancalo con `docker compose up -d`.

## Crear los secretos (solo si `.env` no existe, por ejemplo en otra PC)

```bash
bash -c 'umask 077; { for v in DB_PASSWORD NAKAMA_SESSION_KEY NAKAMA_REFRESH_KEY NAKAMA_HTTP_KEY NAKAMA_CONSOLE_PASSWORD NAKAMA_CONSOLE_SIGNING_KEY; do echo "$v=$(openssl rand -hex 16)"; done; echo "LAN_IP=192.168.100.177"; } > .env'
```

`openssl rand -hex 16` inventa 32 caracteres al azar; `umask 077` hace que
solo tu usuario pueda leer el archivo. **Ojo**: si cambiás `DB_PASSWORD`
después de crear la base, Nakama ya no entra a ella; si cambiás las llaves de
sesión, todos tienen que volver a entrar con su contraseña.

## Respaldo

Las partidas están en `server/db-data/`. Pika Backup copia tu carpeta personal,
así que la incluye, pero la copia "en caliente" de una base de datos no está
garantizada (sin comprobar). El script `respaldo-intranet` **no** la cubre.
Mientras el juego esté en pruebas no es grave; antes de jugar en serio
conviene sumar un volcado (`pg_dump`) al respaldo.

## Probar el servidor desde la PC

Con el servidor andando, en la carpeta del proyecto (no en `server/`):

```bash
godot --headless --path . res://tests/server_demo.tscn
```

Crea una cuenta `demo_…`, entra, importa una partida de ejemplo, sube un
personaje, renueva la sesión y simula quedarse sin conexión. Tiene que terminar
con `DEMO SERVIDOR: N pasaron, 0 fallaron`.

```bash
godot --headless --path . res://tests/economy_server_demo.tscn
```

La de la Fase 4B (tarda menos de un minuto): construye y compara el precio
del servidor con el del teléfono, prueba el bloqueo por nivel, la falta de
dinero, deshacer y rehacer, acelerar, mandar un currículum, un turno completo
hecho por el personaje (espera ~50 s), dos pedidos a la vez y que el teléfono
no pueda hacer trampa. Tiene que terminar con
`DEMO ECONOMÍA EN EL SERVIDOR: N pasaron, 0 fallaron`.

```bash
godot --headless --path . res://tests/couple_demo.tscn
```

La de la Fase 5, con **dos cuentas a la vez** (tarda menos de un minuto): A es
el juego de verdad y B un segundo "teléfono" dentro del mismo programa.
Invitar y aceptar, verse en línea y recibir lo que hace el personaje del otro,
casarse, mudarse, cambios menores con aviso y Deshacer, pedidos de permiso,
caja y "unir ingresos" (con un turno de verdad, ~25 s), los dos editando a la
vez, y separarse. Tiene que terminar con `DEMO PAREJA: N pasaron, 0 fallaron`.

```bash
godot --path . res://tests/couple_live_demo.tscn
```

La misma idea pero **con ventana**: se ve al personaje de B caminar a la
cocina y cocinar en la casa de A, el aviso con Deshacer y los paneles Pareja
y Casa. Guarda capturas `pareja_*.png` en
`~/.local/share/godot/app_userdata/Neighborhood/`. Tiene que terminar con
`DEMO PAREJA EN PANTALLA: N pasaron, 0 fallaron`.

```bash
godot --path . res://tests/restaurant_demo.tscn
```

La de la Fase 6, **con ventana** (tarda unos 2 minutos y medio): arma un
restaurante aparte en la parcela, compra la plancha, lo abre, juega un
servicio entero de 1:30 en la pantalla (lo juega un jugador automático) y
compara lo que contó el teléfono con lo que pagó el servidor; después una
segunda cuenta intenta hacer trampa (toques de robot y un puntaje inventado:
no cobra) y, viviendo juntos, cerrar el restaurante pide permiso. Guarda
capturas `restaurante_*.png`. Tiene que terminar con
`DEMO RESTAURANTE: N pasaron, 0 fallaron`.

```bash
godot --headless --path . res://tests/parcel_server_demo.tscn
```

La del **Pulido 2C**: la parcela de 96 × 96 contra el servidor. Una casa vieja
(parcela de 32) queda en el centro, el servidor genera los mismos obstáculos que
el teléfono, **no deja construir encima de un obstáculo**, y llamar al servicio de
limpieza **cobra el servidor** y tiene espera real (~25 s): terminar antes de
tiempo se rechaza, al pasar la espera limpia y da experiencia, y el lugar queda libre
para construir. Tiene que terminar con `DEMO PARCELA EN EL SERVIDOR: N pasaron, 0 fallaron`.

**RPC de la parcela (Pulido 2C):** `parcel_load` (semilla, obstáculos limpiados y servicios
en camino), `parcel_clear_start` (llamar al servicio: valida el acceso, **cobra** y guarda
la hora de llegada) y `parcel_clear_finish` (pasó la espera: revisa el acceso, limpia y da
experiencia; si el vehículo no puede entrar, responde `blocked` y el servicio sigue en
camino). Lo guardado va en `game/home.parcel`. Los precios, tiempos y la cantidad de cada
obstáculo están en `data/parcel.json` (**reiniciá Nakama si lo cambiás**). La **caja del
restaurante** (Pulido 2B) se cobra sola: al entrar (`work_settle`) y con `game_heartbeat`.

Ninguna de estas demos toca tu partida (la apartan y la devuelven).

Las cuentas demo quedan en el servidor: se pueden borrar desde la consola.

**Pruebas de las reglas sin servidor** (opcional): necesitan Lua 5.1, que no
viene instalado (en CachyOS es el paquete `lua51` de pacman; anotarlo en la
bitácora si se instala):

```bash
lua5.1 server/tests/test_rules.lua
```

Tiene que terminar con `PRUEBAS LUA: N pasaron, 0 fallaron`.

**Probar contra otro servidor sin tocar `data/server.json`**: la variable de
entorno `NEIGHBORHOOD_SERVER` cambia la dirección solo para ese comando (en
fish: `env NEIGHBORHOOD_SERVER=http://127.0.0.1:7350 godot --headless --path . res://tests/server_demo.tscn`).

## Si algo falla

| Síntoma | Qué hacer |
|---|---|
| El juego dice "Sin conexión" en casa | `docker compose ps`; si no está `Up`, `docker compose up -d`. Si está `Up`, revisá la IP (arriba) |
| `docker compose ps` muestra `Restarting` | `docker compose logs nakama` y buscá `"level":"error"` |
| "Ese usuario ya existe" | Elegí otro nombre, o usá "Entrar" si la cuenta es tuya |
| El juego dice "Esperando al servidor…" y no avanza | Espera como mucho 8 s (`timeout_seconds` en `data/server.json`); si pasa siempre, mirá los logs |
| Un cambio en el juego "rebota" con un aviso raro | `docker compose logs nakama` y buscá `"level":"error"` (los `version check failed` sueltos son normales: dos pedidos a la vez, el servidor reintenta solo) |
| La pareja no aparece "en línea" | Los dos tienen que estar en pareja y con el juego abierto y conectado. Si el teléfono estuvo en segundo plano, vuelve a conectarse solo en unos segundos |
| Un cambio de la pareja no aparece | Llega por el WebSocket; si se cortó, el juego se pone al día solo al reconectar. Abrir Menú → Casa también vuelve a preguntar |
| Olvidaste la contraseña de una cuenta | Por ahora no hay "recuperar contraseña". No borres la cuenta (se pierde su partida del servidor): pedile a Claude que la cambie desde el servidor |
