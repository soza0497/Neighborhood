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
| `nakama/modules/neighborhood.lua` | El código del servidor (lo que hace `game_load`, `game_import`…) |
| `.env` | **Secretos** (contraseñas y llaves). No va a Git. No lo compartas |
| `db-data/` | Los datos de la base (las cuentas y partidas). No va a Git |

El servidor lee el **mismo** `data/catalog.json` del juego (solo lectura):
los precios están en un solo lugar.

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

## Reiniciar (por ejemplo, después de cambiar el código .lua)

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
  (dinero) y su **Storage**: `game/house` (la casa), `game/progress`
  (experiencia), `cloud/character` (personaje) y `cloud/settings` (opciones).
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
con `DEMO SERVIDOR: N pasaron, 0 fallaron`. La cuenta demo queda en el
servidor: se puede borrar desde la consola.

## Si algo falla

| Síntoma | Qué hacer |
|---|---|
| El juego dice "Sin conexión" en casa | `docker compose ps`; si no está `Up`, `docker compose up -d`. Si está `Up`, revisá la IP (arriba) |
| `docker compose ps` muestra `Restarting` | `docker compose logs nakama` y buscá `"level":"error"` |
| "Ese usuario ya existe" | Elegí otro nombre, o usá "Entrar" si la cuenta es tuya |
| Olvidaste la contraseña de una cuenta | Por ahora no hay "recuperar contraseña". No borres la cuenta (se pierde su partida del servidor): pedile a Claude que la cambie desde el servidor |
