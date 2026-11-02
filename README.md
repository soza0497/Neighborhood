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
- Controles con mouse:
  - **Clic izquierdo y arrastrar**: mover el mapa.
  - **Clic derecho y arrastrar**: girar.
  - **Rueda**: acercar / alejar.
- Controles táctiles (teléfono): 1 dedo mueve, 2 dedos pellizcan y giran.
- Botón **Centrar**: vuelve la cámara al inicio.
- La cámara se guarda al cerrar el juego: al volver a abrirlo queda donde la dejaste.

## Exportar a Android

La primera vez hay que instalar Java y el SDK de Android: guía paso a paso en
[`docs/android.md`](docs/android.md). Después:

- **Con cable:** botón de Android arriba a la derecha en Godot.
- **Sin cable:** Proyecto → Exportar… → Exportar proyecto → `build/neighborhood.apk`
  → pasarlo con LocalSend.

## Editar el catálogo

Los objetos (nombre, precio, tamaño, color) están en `data/catalog.json`.
Se puede abrir con cualquier editor de texto (Kate, VS Code). Reglas:
cada objeto lleva `id`, `name`, `category` y `price`; los `id` en inglés, sin
espacios y sin repetir. Si te equivocás, la consola de Godot (abajo, pestaña
"Salida") dice qué línea está mal.

## Carpetas

| Carpeta | Qué hay |
|---|---|
| `scenes/` | Escenas del mundo 3D (`main.tscn` es la que arranca) |
| `scripts/` | Código. `autoload/` = sistemas siempre presentes |
| `data/` | Datos editables (catálogo) |
| `ui/` | Interfaz (botones, textos) |
| `assets/` | Modelos, sonidos, texturas (vacía hasta la Fase 7) |
| `docs/` | Guías |

## Sistemas globales (autoloads)

Están siempre cargados y se usan desde cualquier script por su nombre:

- **EventBus**: señales globales; los sistemas se avisan cosas sin conocerse.
- **Catalog**: lee `data/catalog.json`. `Catalog.get_item("bed_basic")`.
- **GameState**: todos los datos de la partida que se guardan.
- **SaveSystem**: guarda/carga `GameState` en `user://save.json`
  (en la PC: `~/.local/share/godot/app_userdata/Neighborhood/`).
