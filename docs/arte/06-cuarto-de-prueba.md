# Guía 06 — El cuarto de prueba

**Objetivo:** armar **un dormitorio con 6 muebles hechos por vos**, verlos
juntos en el juego y en tu teléfono, **medir los cuadros por segundo (FPS)** y
decidir con criterios claros si el camino de arte te gusta antes de hacer 40
modelos más. (Es «la prueba de arte» de `docs/guia-arte.md`, sección 6.)

**Resultado final:** un dormitorio completo en el juego con modelos tuyos, una
planilla de medidas, una nota de FPS y una decisión: *seguimos así* o *cambiamos
algo*.

**Tiempo estimado:** 6 a 10 horas (los tres muebles nuevos son lo que más
lleva).

**Antes de empezar:** tener hechas las guías [02](02-primera-silla.md) (silla)
y [03](03-mueble-con-partes.md) (cama y estantería).

> Lo marcado «(a confirmar en tu versión)» no se pudo verificar para Blender
> 5.2.

---

## Parte A — Los 6 muebles del dormitorio

Usamos piezas que **ya existen en el catálogo** (así no hace falta agregar
piezas nuevas al juego, solo el campo `model`).

| # | Mueble | `id` del catálogo | Huella (celdas) | Alto | Estado |
| --- | --- | --- | --- | --- | --- |
| 1 | Cama sencilla | `bed_basic` | 1 × 2 | 0,55 m | hecha (guía 03) |
| 2 | Estantería (librero) | `bookshelf_basic` | 1 × 1 | 1,7 m | hecha (guía 03) |
| 3 | Silla | `chair_basic` | 1 × 1 | 0,9 m | hecha (guía 02) |
| 4 | Escritorio | `desk_basic` | 2 × 1 | 0,75 m | **nueva** |
| 5 | Lámpara de pie | `lamp_floor` | 1 × 1 | 1,6 m | **nueva** |
| 6 | Planta en maceta | `plant_pot` | 1 × 1 | 0,9 m | **nueva** |

Podés cambiar la lista (por ejemplo, una mesa de luz en vez de la planta),
pero **elegí piezas existentes del catálogo** para no tocar el código.

### Receta de los tres muebles nuevos

Usá las técnicas de las guías 02 y 03 (cubos con dimensiones por `N`,
`Ctrl + A > Scale`, Mirror, Array, Bevel al final, materiales con nombre y
checklist). Medidas **sugeridas** (modelá alrededor del origen del mundo, con el
piso en z = 0 y el **frente hacia −Y**):

**4. Escritorio (`desk_basic`) — 1,86 × 0,86 × 0,75 m**
- `desktop`: cubo 1,86 × 0,86 × 0,05, Location Z `0.725`. Material `wood_light`.
- `leg`: cubo 0,07 × 0,07 × 0,70, Location (0,80, −0,35, 0,35), origen al
  origen del mundo, **Mirror X e Y**. Material `wood`.
- `drawer`: cubo 0,50 × 0,76 × 0,22, Location (0,60, 0, 0,59) (cajonera pegada
  bajo el tablero, a la derecha). Material `wood_dark`.
- Opcional: `knob` (tirador), cilindro chico, material `metal`.
- Bevel `Segments 2` al final en cada pieza.

**5. Lámpara de pie (`lamp_floor`) — Ø 0,40 × 1,60 m**
- `base`: **Add > Mesh > Cylinder**, Vertices `12`, Radius `0.18`, Depth
  `0.04`, Location Z `0.02`. Material `metal_dark`.
- `pole`: Cylinder, Vertices `8`, Radius `0.02`, Depth `1.35`, Location Z
  `0.715`. Material `metal`.
- `shade`: Cylinder, Vertices `12`, Radius `0.20`, Depth `0.25`, Location Z
  `1.475` (de 1,35 a 1,60). Material `cloth_yellow`. (Con **Add > Mesh >
  Cone** podés hacer una pantalla más ancha abajo que arriba; en el panel de
  la operación, **Radius 1** y **Radius 2**, a confirmar en tu versión.)
- Todo redondo: no hace falta bisel; sí **Shade Auto Smooth**.

**6. Planta en maceta (`plant_pot`) — Ø 0,45 × 0,90 m**
- `pot`: Cone o Cylinder, 10 vértices, Radius `0.20`, Depth `0.28`, Location Z
  `0.14`. Material `ceramic`.
- `soil`: cilindro de 10 vértices, Radius `0.18`, Depth `0.02`, Location Z
  `0.29`. Material `soil`.
- `leaf`: **Add > Mesh > UV Sphere** con Segments `8`, Rings `6`; en `N >
  Item` **Dimensions** `0.10 × 0.04 × 0.35`; rotá cada hoja un poco hacia afuera
  (`R` `Y` `20`) y ubicá 5–6 hojas alrededor del centro, entre z = 0,35 y 0,80.
  Material `leaf`. **Cuidá los triángulos** (cada esfera es más cara que un cubo:
  sumalos).

> **Si no te sale (muebles nuevos)**
> 1. *Se pasa de triángulos (guía 02, «Triángulos»):* bajá segmentos, usá
>    menos hojas, sacá biseles en piezas que casi no se ven.
> 2. *Las medidas no entran:* repasá el checklist de la guía 03.
> 3. *No sé por dónde empezar:* hacé primero el escritorio (es una mesa con
>    cajón).

---

## Parte B — Medir y anotar (la planilla)

Antes de exportar, medí **cada mueble** con `N > Item > Dimensions` (o la regla
Measure) y completá esta planilla (copiala en un archivo de texto):

| Mueble | Ancho X | Fondo Y | Alto Z | Cabe en la caja del catálogo | Triángulos | Presupuesto |
| --- | --- | --- | --- | --- | --- | --- |
| cama | | | | 1 × 2 × 0,55 | | ≤ 800 |
| librero | | | | 1 × 1 × 1,7 | | ≤ 1.200 |
| silla | | | | 1 × 1 × 0,9 | | ≤ 400 |
| escritorio | | | | 2 × 1 × 0,75 | | ≤ 800 |
| lámpara | | | | 1 × 1 × 1,6 | | ≤ 400 |
| planta | | | | 1 × 1 × 0,9 | | ≤ 400 |

**Regla:** una pieza **se puede pasar un 5 %** de la caja; más que eso, el
juego la **achica entera** (y deja de verse como la hiciste). Mejor que quede
algo más chica que la caja.

**Presupuesto total del cuarto:** sumá los triángulos de los 6 muebles: es lo
que el teléfono dibuja **además** de las paredes, el piso y el personaje. Si la
suma pasa de ~**3.000**, avisale al asesor: no es un límite oficial, pero ayuda
a explicar un bajón de FPS (a confirmar con tus mediciones).

### Medir bien con una persona de referencia

Para ver si «se siente» bien la escala, tené en cuenta estos números del
personaje (`docs/estilo.md` §5): **1,35 m de alto**, cabeza de 0,6 m, entra por
una puerta de 0,9 m. Una **cama de 0,55 m** le llega por arriba de la rodilla,
una **silla de 0,45 m de asiento** le queda cómoda. Si algo se ve «de
juguete» o «de gigantes» comparado con él, es un problema de escala, no de
gusto.

---

## Parte C — Exportar los seis y enchufarlos al catálogo

1. **Exportá cada mueble** como `.glb` a `assets/models/` con el nombre del `id`
   (guía 02, pasos 55–66): `bed_basic.glb`, `bookshelf_basic.glb`,
   `chair_basic.glb`, `desk_basic.glb`, `lamp_floor.glb`, `plant_pot.glb`.
2. **Catálogo:** en `data/catalog.json`, en la línea de cada pieza, el campo
   `"model": "res://assets/models/<id>.glb"` (guía 03, paso 35). Chequeá el
   JSON con `python3 -m json.tool data/catalog.json > /dev/null`.
3. **Abrí Godot** (importa todo solo) y **corré** con `F5`.
4. **Pedile al asesor** que corra `ModelLoader.inspect(...)` sobre los seis
   `.glb`. Devuelve para cada uno: **triángulos, materiales, tamaño y avisos**
   (pivote mal puesto, material que no está en la paleta, tamaño raro).
   Corregí lo que avise antes de seguir.

### Ajuste fino en el catálogo (solo si hace falta)

Si un mueble sale **un poco girado, corrido o grande** y no querés rehacer el
modelo, el catálogo permite campos opcionales por pieza (`docs/estilo.md`, §9):

| Campo | Para qué | Ejemplo |
| --- | --- | --- |
| `model_rotation` | Gira el modelo (grados) | `"model_rotation": 180` |
| `model_offset` | Lo desplaza (metros `[x, y, z]`) | `"model_offset": [0, 0, -0.25]` (para pegar el librero a la pared; el sentido exacto, a confirmar jugando) |
| `model_scale` | Lo agranda/achica | `"model_scale": 0.9` |
| `model_colors` | Cambia el color de un material solo en esta pieza | `"model_colors": {"cloth_blue": "#ff9db5"}` |

Es un parche. **Lo correcto es arreglar el modelo en Blender**; esto sirve
para probar rápido.

---

## Parte D — Verlos juntos en el juego

5. **Armá el cuarto:** en el juego, en **modo construir**, hacé un cuarto de
   unas **4 × 5 celdas** con piso, paredes, una puerta y una ventana. *(Si no
   sabés cómo, pedile al asesor que te prepare una casa de prueba o mirá el
   `README.md`.)*
6. **Poné los 6 muebles** desde la **Tienda** y acomodalos como un dormitorio
   real: cama contra la pared, escritorio y silla frente a la ventana, librero
   a un costado, lámpara junto a la cama, planta en una esquina.
7. **Cambiá de vista:** acercá, alejá y girá la cámara con dos dedos (o el
   mouse). Mirá **de arriba** (como se jugará): ¿se entiende qué es cada
   cosa solo por la silueta y el color?
8. **Compará con las figuras simples:** **Menú → Info → «Usar modelos 3D
   (arte)»**: apagado y prendido.
9. **Probá el contorno:** **Menú → Info → «Contorno»**: prendido y apagado.
   El contorno **lo pone el juego** (no se modela).
10. **Sacá capturas** (en la PC con la tecla de captura de pantalla de CachyOS
    o con tu teléfono) del cuarto desde 3 ángulos. Las vas a necesitar para
    la evaluación.

---

## Parte E — Verlos en el teléfono y medir los FPS

**Los FPS tienen que medirse en tu teléfono**, no en la PC (la meta es **30
cuadros por segundo** en un Android de gama media con una casa de dos pisos
amueblada, `CLAUDE.md` §6).

11. **Poner el juego con tus modelos en el teléfono:** hay que **exportar un
    APK nuevo** (los modelos viajan dentro). Pedile al asesor que lo exporte,
    o seguí `docs/android.md` (opción A: botón «Despliegue remoto» de Godot
    con cable USB; opción B: exportar el APK y pasarlo con LocalSend).
12. **Mostrar los FPS en pantalla:** **Menú → Info** y marcá **«Mostrar FPS en
    pantalla»**. Aparece un contador arriba (por ejemplo «30 FPS»).
13. **La medición (repetila 2 veces):**
    1. Poné la cámara **de lejos** (se ve todo el cuarto). Mirá el contador
       **10 segundos** y anotá el **mínimo** y el típico.
    2. Poné la cámara **cerca** (solo la cama). Anotá.
    3. **Mové la cámara** girando y acercando durante 15 segundos. Anotá el
       **mínimo**.
14. **Compará 4 combinaciones** y anotá en una tabla:

    | Condición | FPS lejos | FPS cerca | FPS moviendo |
    | --- | --- | --- | --- |
    | Modelos **prendidos**, contorno **prendido** | | | |
    | Modelos **prendidos**, contorno **apagado** | | | |
    | Modelos **apagados** (figuras simples), contorno prendido | | | |
    | Modelos **apagados**, contorno apagado | | | |

    Lo que importa: **el caso normal de juego (modelos y contorno prendidos)
    tiene que dar ≥ 30**. La diferencia con las figuras simples te dice **cuánto
    cuestan tus modelos**; la del contorno, cuánto cuesta ese estilo.
15. **Detalles para medir bien:** usá el teléfono con el **cargador desconectado
    y con batería > 30 %** y **sin modo ahorro de energía** (ese modo baja los
    FPS por sí solo); cerrá otras apps; repetí con el teléfono «frío».

> **Si no te sale (teléfono y FPS)**
> 1. *No aparece «Mostrar FPS»:* está en **Menú → Info**, dentro del panel;
>    revisá todas las opciones del panel.
> 2. *Los modelos no están en el teléfono:* instalaste un APK viejo; exportá
>    uno nuevo (paso 11).
> 3. *Da menos de 30 FPS:* anotá el **mínimo** y los números de la tabla y
>    pasáselos al asesor: probamos bajar triángulos, el contorno y las
>    sombras. **No es un fracaso: es justo para lo que sirve la prueba.**

---

## Parte F — «Me gusta / no me gusta»: cómo decidir

Mirá el cuarto **con calma** (mejor otro día) y calificá cada punto de **1 (mal)
a 5 (muy bien)**. Podés pedirle a tu pareja que opine también.

| Criterio | Pregunta | 1–5 |
| --- | --- | --- |
| **Silueta desde arriba** | ¿Se entiende cada mueble de lejos sin leer el nombre? | |
| **Escala** | ¿Todo tiene un tamaño creíble respecto del personaje y las puertas? | |
| **Colores** | ¿Combinan entre sí y con la paleta? ¿Se distinguen en blanco y negro? | |
| **Formas redondeadas** | ¿Todos se ven «suaves» y de la misma familia? | |
| **Contorno y sombras** | ¿El estilo (contorno + 3 tonos) queda lindo sobre tus modelos? | |
| **Coherencia** | ¿Parecen hechos por la misma mano (mismo bisel, mismo nivel de detalle)? | |
| **Claridad de uso** | ¿La cama parece para dormir, la silla para sentarse? | |
| **Rendimiento** | ¿≥ 30 FPS en el teléfono en el caso normal? | sí / no |
| **Ganas de seguir** | ¿Tenés ganas de hacer 40 más así? | |

**Regla para decidir:**
- **Promedio ≥ 4 y FPS ≥ 30:** seguimos con este camino, y se hace el catálogo
  completo por tandas.
- **Entre 3 y 4, o FPS justos:** seguimos pero **ajustamos primero** lo peor
  puntuado (bisel, colores, escala o triángulos) y repetís la prueba.
- **Menos de 3:** paramos y cambiamos el camino con el asesor (otro estilo de
  formas, otro método, menos detalle) **antes** de gastar más meses.

Anotá en un archivo **qué cambiarías** y mostrale las capturas al asesor.

---

## Ejercicios para practicar

1. Cambiá **un solo color** en `data/palette.json` (por ejemplo `wood`) y
   comprobá en el juego que cambian **todas** las piezas de madera juntas.
2. Rehacé la **planta** con la mitad de las hojas y medí cuántos FPS ganás.
3. Armá el mismo cuarto **con otra distribución** y sacá tres capturas.
4. Poné la cama con `model_rotation` en 0, 90 y 180 y mirá cuál es la
   orientación correcta del modelo.
5. Hacé el cuarto solo con piezas de **dos colores de madera** y comparalo con
   la versión colorida: ¿cuál te gusta más?

## Glosario

- **FPS:** cuadros por segundo; mide la fluidez (la meta es 30).
- **Huella (footprint):** celdas que ocupa un mueble.
- **Presupuesto de triángulos:** cuántos triángulos como máximo debe tener
  una pieza para que el teléfono rinda.
- **Silueta:** el contorno de un objeto visto sin detalles.
- **Prueba de arte:** hacer un solo cuarto antes de hacer todo el catálogo, para
  validar el camino.
- **APK:** el archivo que se instala en un teléfono Android.
- **Despliegue remoto:** instalar el juego en el teléfono directo desde Godot
  con cable.

Siguiente: [07 — Personaje: primeros pasos](07-personaje-primeros-pasos.md).
