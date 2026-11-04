# Estilo visual — Neighborhood

Este archivo describe el **estilo** del juego (Pulido 2B). Es una primera versión
con los números actuales; la Fase 7 (arte) lo va a completar con proporciones
chibi y reglas para generar con IA. **Todo lo que está acá se cambia en archivos
de datos, no en el código**, porque el dueño va a ir cambiando el arte varias
veces.

## 1. Idea
Dibujo animado tipo anime: **contorno oscuro y fino**, **sombras duras en 3
tonos** (sin degradés), colores alegres y una luz cálida. De frente tiene que
parecer 2D aunque sea 3D. Nada de personajes, logos ni diseños copiados de otros
juegos o series: el estilo (contorno + sombras planas) es libre, los diseños no.

## 2. Dónde se cambia cada cosa
| Qué | Dónde |
| --- | --- |
| Grosor y color del contorno, tonos de las sombras, luz, niebla, **paleta** | `data/style.json` |
| El shader de los tonos | `assets/shaders/toon.gdshader` |
| El shader del contorno (geometría invertida) | `assets/shaders/outline.gdshader` |
| El mundo: bosque, vecinos, calle, autos y gente | `data/world.json` |
| Cada pieza (color, tamaño, precio, modelo `.glb`) | `data/catalog.json` |
| Apagar el contorno (calidad) | Menú → Info → «Contorno» |

## 3. Cómo funciona (para no perderse)
- Todos los materiales pasan por el autoload **`Style`** (`Style.toon_material`).
  Hay uno por color y se comparten (el teléfono trabaja menos).
- **Contorno por geometría invertida**: la malla se dibuja dos veces; la
  segunda, un poquito más grande y con las caras al revés, toda de un color
  (`next_pass`). El grosor es en **píxeles** (no cambia con el zoom). Se apaga
  sacando esa segunda pasada de todos los materiales.
- **Tonos**: `tones` = cuánta luz recibe la sombra / el tono medio / la luz;
  `thresholds` = dónde cambia de uno a otro. Con 3 tonos queda «dibujado».
- Lo que no lleva contorno: el suelo, la calle y la acera (son planos grandes).

## 4. Paleta (valores de `data/style.json`)
| Nombre | Color | Uso |
| --- | --- | --- |
| `ground` | `#7fcf6c` | pasto (toda la parcela y el terreno: **un solo color**) |
| `road` / `road_line` | `#5d6470` / `#f7e38a` | calle y raya |
| `sidewalk` | `#d7d4c8` | acera |
| `trunk` / `leaf` / `leaf_dark` | `#946142` / `#58b85a` / `#3f9a4d` | árboles |
| `rock` / `water` / `stump` / `bush` | `#9aa0a8` / `#5fb8e8` / `#a9794f` / `#4aa65b` | obstáculos de la parcela (2C) |
| `sky` / `fog` | `#bfe6ff` | cielo y niebla (el mismo color: el borde del mapa se «disuelve») |
| `neighbor_wall` / `neighbor_roof` | `#f2e3c6` / `#d97a6c` | casas de vecinos |
| `suit` / `suitcase` | `#33384a` / `#8a5a3a` | saco y maleta del trabajo |
| `truck` / `van` / `ambulance` / `cross` | `#e8b04a` / `#f4f4f4` / `#f6f6f6` / `#e04b4b` | servicios (2C) |

Regla: los colores de piezas de la casa están en el catálogo; el mundo usa esta
paleta. Si se agrega un color nuevo al mundo, va primero acá.

## 5. Cambiar el arte sin tocar código (modelos `.glb`)
Cualquier pieza del catálogo puede apuntar a un modelo:

```json
{ "id": "sofa_basic", "name": "Sofá", "model": "res://assets/models/sofa.glb",
  "model_scale": 1.0, "model_offset": [0, 0, 0], "model_rotation": 0 }
```
- Si el archivo **no existe**, el juego usa las figuras simples de siempre (nunca
  se rompe). Podés ir reemplazando pieza por pieza.
- El modelo se pasa solo al estilo toon con contorno (`Style.toonify`), conservando
  su color y su textura. Si querés dejar los materiales del archivo tal cual:
  `"model_keep_materials": true`.
- **Convenciones de importación** (para Blender / Krita / lo que uses):
  - Unidades: **1 unidad = 1 metro**; 1 celda de la casa = 1 × 1 m.
  - **Origen (pivote)** en el **centro del piso** de la pieza (en la huella
    `footprint` del catálogo, abajo), eje **Y hacia arriba**.
  - El **frente** de la pieza mira hacia **+Z** (el juego la gira de a 90°/45°).
  - Un nombre de archivo por pieza, igual al `id` del catálogo (`sofa_basic.glb`).
  - Sin luces ni cámaras dentro del archivo.
  - Pocas caras: pensado para un Android de gama media (objetivo 30 cuadros por
    segundo con una casa de dos pisos amueblada).
- Probar un modelo: ponerlo en `assets/models/`, escribir su ruta en `model` y
  abrir el juego (no hay que cambiar ningún `.gd`).

## 6. Pendiente para la Fase 7
- Proporciones chibi (cabeza/cuerpo), guía de rostro y manos.
- Reglas para generar modelos con IA desde imagen de referencia.
- Texturas pintadas a mano (Krita) y su resolución máxima.
- Convención de animaciones del `.glb` (`idle`, `walk`, `sleep`, `sit`, `cook`,
  `eat`, `shower`, `use`, `arrive`, `wave`: los nombres que ya pide el juego).
