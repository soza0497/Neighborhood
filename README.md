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
   **rojo** lo que no. Al soltar se aplica.
3. Orden lógico: **Cimientos** → **Cuarto** (o Piso + Pared) → **Puertas y
   ventanas** → **Muebles** → **Pintura** → **Techo**.
4. **Subir / Bajar** (izquierda) cambia de piso. Para el primer piso hace
   falta piso abajo; la **Escalera** se pone en la planta baja.
5. **Borrar** (abajo a la derecha): la pieza elegida pasa a quitar en vez de poner.
6. Muebles: **Mover (mano)** toca un mueble para elegirlo, arrastralo para
   moverlo; **Girar** y **Quitar** actúan sobre el elegido.
7. **Deshacer / Rehacer** arriba (en la PC también Ctrl+Z / Ctrl+Y).
8. **Vista** cambia entre: completa (con techo), sin techo, paredes bajas.
9. Tocar otra vez la pieza elegida la suelta (vuelve el dedo a mover la cámara).
10. **Vivir** oculta las herramientas (en la Fase 2 ahí vive el personaje).

## Pruebas automáticas

En la terminal, dentro de la carpeta del proyecto:

```bash
godot --headless --path . res://tests/test_house.tscn
```

Revisa las reglas de construcción y el deshacer. Debe terminar con
`PRUEBAS: N pasaron, 0 fallaron`. (`tests/visual_demo.tscn` arma una casa de
ejemplo y saca capturas, pero **pisa la partida guardada**.)

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
| `scenes/` | Escenas del mundo 3D (`main.tscn` es la que arranca) |
| `scripts/` | Código. `autoload/` = sistemas siempre presentes; `house/` = la casa y el constructor |
| `data/` | Datos editables (catálogo) |
| `ui/` | Interfaz (botones, textos) |
| `assets/` | Modelos, sonidos, texturas, shaders (casi vacía hasta la Fase 7) |
| `docs/` | Guías |
| `tests/` | Pruebas automáticas (no van en el APK) |

## Sistemas globales (autoloads)

Están siempre cargados y se usan desde cualquier script por su nombre:

- **EventBus**: señales globales; los sistemas se avisan cosas sin conocerse.
- **Catalog**: lee `data/catalog.json`. `Catalog.get_item("bed_basic")`.
- **GameState**: todos los datos de la partida que se guardan.
- **SaveSystem**: guarda/carga `GameState` en `user://save.json`
  (en la PC: `~/.local/share/godot/app_userdata/Neighborhood/`).
