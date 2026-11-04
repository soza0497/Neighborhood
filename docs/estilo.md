# Estilo visual — Neighborhood

Este archivo describe el **estilo** del juego y cómo se mete arte nuevo
(Pulido 2B + Fase 7, versión 0.11.0). **Todo lo que está acá se cambia en
archivos de datos, no en el código**, porque el dueño va a ir cambiando el arte
varias veces, pieza por pieza.

## 1. Idea
Dibujo animado tipo anime: **contorno oscuro y fino**, **sombras duras en 3
tonos** (sin degradés), colores alegres y una luz cálida. De frente tiene que
parecer 2D aunque sea 3D. Nada de personajes, logos ni diseños copiados de otros
juegos o series: el estilo (contorno + sombras planas) es libre, los diseños no.

## 2. Dónde se cambia cada cosa
| Qué | Dónde |
| --- | --- |
| Grosor y color del contorno, niebla y colores del **mundo** (pasto, calle, árboles) | `data/style.json` |
| **Tonos de las sombras** (2–3), luz del sol y ambiente, **colores de los materiales de los `.glb`** | `data/palette.json` (un solo lugar) |
| El shader de los tonos | `assets/shaders/toon.gdshader` |
| El shader del contorno (geometría invertida) | `assets/shaders/outline.gdshader` |
| El mundo: bosque, vecinos, calle, autos y gente | `data/world.json` |
| Cada pieza (color, tamaño, precio, modelo `.glb`) | `data/catalog.json` |
| Apagar el contorno (calidad) | Menú → Info → «Contorno» |
| Comparar con las figuras simples | Menú → Info → «Usar modelos 3D (arte)» |

## 3. Cómo funciona (para no perderse)
- Todos los materiales pasan por el autoload **`Style`** (`Style.toon_material`).
  Hay uno por color y se comparten (el teléfono trabaja menos).
- **Contorno por geometría invertida**: la malla se dibuja dos veces; la
  segunda, un poquito más grande y con las caras al revés, toda de un color
  (`next_pass`). El grosor es en **píxeles** (no cambia con el zoom). Se apaga
  sacando esa segunda pasada de todos los materiales.
- **Tonos** (en `data/palette.json` → `lighting.toon`): `tones` = cuánta luz recibe la sombra / el tono medio / la luz;
  `thresholds` = dónde cambia de uno a otro. Con 3 tonos queda «dibujado».
- Lo que no lleva contorno: el suelo, la calle y la acera (son planos grandes).

## 4. Paleta del mundo (valores de `data/style.json`)
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

## 5. Proporciones chibi
Medidas del personaje actual (cápsulas) que el arte final tiene que respetar para
que todo siga encajando en las casas, puertas y muebles:

| Parte | Medida |
| --- | --- |
| Alto total | **≈ 1,35 m** (pies en y = 0) |
| Cabeza | esfera de **0,6 m** de diámetro, centro a **1,0 m**: ≈ **45 %** del alto (muy grande, es lo chibi) |
| Cuerpo + piernas | de 0 a ≈ 0,75 m: cortos y redondos |
| Brazos | cortos, ≈ 0,36 m, pegados al torso |
| Ojos | grandes, bajos en la cara, separados; son lo que más expresa |
| Boca y nariz | mínimas (la boca es un trazo; la nariz puede no existir) |
| Manos y pies | redondeados, sin dedos separados (mitones) |
| Ancho | cabe en **una celda** (1 m) con holgura; pasa por una puerta de 0,9 m |

Reglas de forma: **todo redondeado** (sin aristas vivas, salvo muebles muy
rectos como una heladera, que igual llevan esquinas suaves), siluetas simples y
legibles de lejos (la cámara está arriba), y pocos polígonos.

## 6. Paleta de los modelos y la luz
- **Mundo**: tabla de la sección 4 (`data/style.json`).
- **Materiales de los modelos** (`data/palette.json` → `materials`): cada
  material con **nombre** dentro del `.glb` se pinta con el color de ese nombre.

| Nombre | Color | Para qué |
| --- | --- | --- |
| `wood` / `wood_dark` / `wood_light` | `#c98f5a` / `#8f5f3a` / `#e6b883` | madera: patas, marcos, mesas |
| `cloth_red` / `cloth_blue` / `cloth_green` / `cloth_yellow` / `cloth_pink` / `cloth_purple` / `cloth_white` | colores alegres | telas: sillas, sofás, cortinas, ropa |
| `metal` / `metal_dark` / `glass` | grises y celeste | electrodomésticos, herrajes, ventanas |
| `ceramic` / `plastic_white` / `stone` / `paint_white` | blancos y gris | baño, cocina, paredes |
| `leaf` / `soil` | verde y tierra | plantas |
| `skin` / `hair` / `eye` / `mouth` / `shirt` / `pants` / `shoe` | del personaje | el editor de personaje los pisa con lo elegido |

Un material que **no** está en la paleta conserva su color de Blender (el juego
avisa en `ModelLoader.inspect`). Se pueden agregar nombres nuevos al JSON sin
tocar código. Colores alegres, saturación media-alta, nada casi negro ni
casi blanco puro (el contorno oscuro hace el contraste).

**Iluminación y sombras duras**, todo en `data/palette.json` → `lighting`:
`toon.tones` = 3 valores (sombra, medio, luz). Para **2 tonos** repetí el
medio y la luz (`[0.5, 1.0, 1.0]`). `toon.thresholds` = dónde cambia de tono.
`light` = color y fuerza del sol, del ambiente y opacidad de las sombras.

## 7. Cómo generar arte con IA (reglas)
1. **Siempre desde una imagen de referencia del dueño** (un dibujo suyo, una foto
   de un objeto real) o desde **paquetes CC0** (Kenney, Quaternius y similares;
   anotá la fuente y la licencia en `assets/models/LICENCIAS.md`).
2. **Nunca** usar, copiar ni pedir «al estilo de» personajes, objetos o
   logos de otros juegos o series (Los Sims, Nintendo, Animal Crossing, etc.).
   El estilo (contorno + sombras planas + formas redondeadas) es libre; los diseños
   ajenos no. Si una salida se parece demasiado a algo conocido, se descarta.
3. Pedir siempre: «objeto aislado, vista 3/4, fondo liso, formas redondeadas,
   colores planos sin texturas ni sombras pintadas» y describir las partes con
   los **nombres de material** de la paleta (madera → `wood`, tela → `cloth_*`).
4. Lo que sale de una IA se **limpia en Blender** antes de usarse: bajar
   polígonos (Decimate), centrar el pivote, 1 celda = 1 m, nombrar materiales,
   un material por color plano. Nada de texturas fotográficas.
5. Revisar con `ModelLoader.inspect` (sección 9) antes de meterlo al juego.

## 8. Convenciones de importación (`.glb`)
| Tema | Regla |
| --- | --- |
| Formato | **`.glb`** (glTF binario), un archivo por pieza, sin luces ni cámaras |
| Carpeta | `assets/models/` (muebles y piezas) y `assets/models/character/` (personaje) |
| Nombres de archivo | **inglés, minúsculas, con guiones bajos**; igual al `id` del catálogo si se puede (`sofa_basic.glb`) |
| Escala | **1 unidad = 1 metro**; 1 celda = 1 × 1 m. Exportar con «Unit scale 1.0» |
| Pivote (origen) | **centro de la base** de la huella: x/z al medio, **y = 0 es el piso** |
| Orientación | Y hacia arriba; el **frente mira a +Z** (en Blender se exporta con «+Y Up» y el frente hacia **-Y**) |
| Caja | no debe pasarse de `footprint` × `height` del catálogo; si se pasa un 5 %, el juego lo achica parejo |
| Materiales | **con nombre**, en minúsculas: `wood`, `cloth_red`... (ver paleta). Blender agrega `.001` al duplicar: el juego lo ignora |
| Colores | **planos** (Principled BSDF con solo «Base Color»); sin texturas por ahora |
| Contorno | **lo pone el shader** (`Style`), no se modela. No hace falta casco invertido |
| Normales | suaves en las curvas (Shade Smooth); el sombreado toon las usa |
| Polígonos (triángulos) | mueble chico (silla, lámpara): **≤ 400** · mueble mediano (mesa, sofá, cama): **≤ 800** · grande (heladera, biblioteca): **≤ 1 200** · personaje completo: **≤ 3 000** · pieza suelta del personaje (pelo, cola): **≤ 500** |
| Huesos | los de `data/character_slots.json` → `skeleton` (sección 10) |

Las **animaciones** del personaje se llaman como los ganchos del juego: `idle`,
`walk`, `sleep`, `sit`, `cook`, `eat`, `shower`, `use`, `arrive`, `wave`,
`cough`, `hurt` (mayúsculas no importan; hay nombres alternativos en
`data/character_slots.json` → `animations`).

## 9. Cómo usar un modelo en el juego (el campo `model`)
Cualquier pieza del catálogo puede apuntar a un modelo:

```json
{ "id": "sofa_basic", "name": "Sofá", "model": "res://assets/models/sofa_basic.glb" }
```
Campos opcionales (todos en `data/catalog.json`):

| Campo | Qué hace |
| --- | --- |
| `model_fit` | `"shrink"` (por defecto: solo achica si se pasa de la caja), `"stretch"` (se estira a la caja: escaleras) o `"none"` |
| `model_pivot` | `"base"` (por defecto: confía en el pivote del archivo) o `"auto"` (lo recoloca solo: centro de la base en el origen) |
| `model_scale`, `model_offset`, `model_rotation` | ajuste fino (número o `[x,y,z]`; metros; grados) |
| `model_colors` | `{"cloth_red": "#00ff00"}` colores solo para esta pieza |
| `model_keep_materials` | `true` = no pintar ni pasar a toon (casos raros) |

- Funciona en **muebles**, **escaleras** (caja = huella × alto del piso), **pilares**,
  **puertas** (reemplazan marco y hoja; caja = el hueco) y **ventanas** (reemplazan
  el marco; el vidrio sigue siendo el del juego).
- **Techos**: no (todavía). Su tamaño cambia con cada casa (se arman a medida),
  así que seguirán con la figura simple hasta que definamos piezas modulares.
- **Nunca se rompe**: si el archivo no existe, está roto, no tiene mallas o
  «Usar modelos» está apagado, se usa la figura simple de siempre.
- Al abrir el proyecto en el editor, Godot **importa** el `.glb` (crea un
  `.import`); eso es lo que viaja en el APK. En la PC el juego también lee el
  `.glb` crudo si todavía no se importó.
- **Revisar un modelo** (en la consola de Godot o un script):
  `print(ModelLoader.inspect("res://assets/models/sofa_basic.glb"))` →
  triángulos, materiales, tamaño y **avisos** (pivote mal puesto, material fuera
  de la paleta, tamaño absurdo).
- **Comparar** con las figuras simples: Menú → **Info** → «Usar modelos 3D».

## 10. Personaje modular
`data/character_slots.json` define **un solo esqueleto** (nombres de hueso) y los
**slots**: cuerpo base, cabeza, pelo, ojos, boca, orejas, cola, ropa y
accesorio. Cada opción de `data/character_options.json` (peinados, ojos, bocas)
o de las listas propias de cada slot puede traer `"model": "hair_round.glb"`
(relativo a `assets/models/character/`). Reglas:
- `CharacterAssembler` arma primero la figura simple y encima pone cada pieza
  `.glb` que cargue bien; esa pieza **esconde** las figuras simples que
  reemplaza (`hides`). La que falta se queda simple.
- Las piezas se pegan al hueso `attach` del cuerpo (si el modelo del cuerpo
  trae `Skeleton3D`) o a una posición fija. Hoy se soportan piezas **rígidas**
  (pelo, orejas, cola, accesorios) y un cuerpo completo con `Skeleton3D` y
  `AnimationPlayer`. La ropa **deformable** (skinning compartido) queda para
  cuando haya un esqueleto real.
- Los materiales `skin`, `hair`, `shirt`, `pants` se pintan con lo que el jugador
  eligió en el editor de personaje.
- Si el `.glb` del cuerpo trae `AnimationPlayer`, el juego usa sus animaciones
  (por nombre); las que falten siguen siendo las simples de `character_animator.gd`.

## 11. Guía para principiantes: de Blender al juego
1. **Modelar** en Blender con la cuadrícula en metros: una silla mide ≈ 0,5 × 0,5 m.
   Poné el objeto **apoyado en el piso (z = 0 en Blender)** y **centrado** en el
   origen. Usá formas redondeadas (Bevel, Subdivision bajo y después Apply).
2. **Materiales**: un material por color, con el **nombre** de la paleta
   (`wood`, `cloth_red`...). En «Material Properties» solo cambiás «Base Color».
3. **Aplicar transformaciones**: seleccioná todo → `Ctrl + A` → «All Transforms»
   (así la escala queda en 1 y el pivote donde está el origen).
4. **Exportar**: Archivo → Exportar → **glTF 2.0 (.glb/.gltf)**. Formato **glTF
   Binary (.glb)**, marcá «+Y Up», «Apply Modifiers», solo lo seleccionado
   («Selected Objects»), sin cámaras ni luces. Guardá en
   `assets/models/` con nombre en inglés y minúsculas: `sofa_basic.glb`.
5. **Abrir Godot** (esto importa el archivo). Si sale rojo en la pestaña
   «Importar», revisá que sea `.glb` y se vea la malla.
6. **Conectarlo**: en `data/catalog.json`, en la línea de tu pieza, agregá
   `"model": "res://assets/models/sofa_basic.glb"`.
7. **Probar**: correr el juego, Tienda → tu mueble → colocarlo. Probá girarlo.
   Menú → Info → «Usar modelos 3D» (apagar/prender) compara con la figura simple.
8. **Si algo sale mal**: ejecutá `ModelLoader.inspect(...)` (sección 9). Casos
   comunes: se ve **enorme o minúsculo** → exportaste con otra escala (paso 3);
   **flota o está hundido** → el origen no está en la base; **mira para atrás**
   → el frente tiene que ir a +Z; **color raro** → el nombre del material no
   está en la paleta (agregalo a `data/palette.json`).
9. **Ejemplos hechos**: `tools/make_sample_models.py` genera `chair.glb`,
   `table.glb` y `character/hair_round.glb` (sin Blender) con estas convenciones;
   abrilos en Blender para ver cómo quedan.

## 12. Pendiente
- Texturas pintadas a mano (Krita) y su resolución máxima (hoy: colores planos).
- Techos modulares con modelo propio.
- Ropa deformable sobre un esqueleto real compartido.
- Animaciones reales del personaje (hoy: ganchos por nombre + movimiento simple).
