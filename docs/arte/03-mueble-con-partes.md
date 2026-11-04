# Guía 03 — Muebles con partes: mesa, cama y estantería

**Objetivo:** modelar tres muebles más grandes que la silla, repitiendo piezas
con **modificadores** (Mirror, Array, Bevel), ordenando todo en **colecciones**
con nombres claros, reusando materiales y pasando una **lista de revisión**
antes de exportar.

**Resultado final:** `table_basic.glb`, `bed_basic.glb` y
`bookshelf_basic.glb` en `assets/models/`, enlazados en el catálogo y vistos en
el juego.

**Tiempo estimado:** 4 a 6 horas (una por mueble).

**Antes de empezar:** hacé la [guía 02](02-primera-silla.md): acá no se repite
cómo exportar ni cómo conectar el catálogo; se resume y se cita el paso.

> Lo marcado «(a confirmar en tu versión)» no se pudo verificar para Blender
> 5.2. Modificadores: <https://docs.blender.org/manual/en/5.2/modeling/modifiers/index.html>

---

## Parte A — Las ideas nuevas

### Modificadores: qué son y los tres que vamos a usar

Un **modificador** hace un trabajo sobre tu objeto **sin tocar la malla
original**: lo podés ajustar o sacar cuando quieras. Se agregan en la pestaña
**Modifiers (Modificadores)** (llave inglesa) con **Add Modifier (Añadir
modificador)**.

| Modificador | Dónde está | Para qué | Ejemplo de hoy |
| --- | --- | --- | --- |
| **Mirror (Espejo)** | Add Modifier > Generate | Crea el reflejo del objeto respecto de su origen | Las 4 patas desde **una sola** |
| **Array (Matriz)** | Add Modifier > Generate | Repite el objeto a distancias iguales | Los 5 estantes desde **uno solo** |
| **Bevel (Bisel)** | Add Modifier > Generate | Redondea esquinas | Todas las piezas |

**Regla de orden:** el **Bevel va siempre último** en la lista (los modificadores
se calculan de arriba hacia abajo; se pueden reordenar arrastrando el agarre
`⋮⋮` del encabezado).

**En la exportación:** con la opción **Apply Modifiers (Aplicar
modificadores)** marcada (guía 02, paso 60), el `.glb` sale **con** las patas
ya duplicadas. No hace falta «aplicar» cada modificador a mano.

### El pivote cuando hay varias piezas

Si el mueble tiene **varios objetos** (tablero, patas…), el juego mide la caja
de **todo** el conjunto y su centro tiene que quedar sobre el **origen del
mundo** (0, 0, 0), con el piso en z = 0. Por eso en esta guía **modelamos
directamente alrededor del origen del mundo**: es lo que cumple «pivote en el
centro de la base».

### Colecciones y nombres

- Una **colección** es una carpeta en el Outliner. Una por mueble:
  `table_basic`, `bed_basic`, `bookshelf_basic`.
- **Objetos con nombres claros** en inglés: `tabletop`, `leg`, `mattress`,
  `headboard`, `shelf`, `side_panel`. Después de un mes vas a agradecerlo.

---

## Parte B — La mesa (`table_basic`)

El catálogo pide `footprint` **[2, 1]** (2 celdas de largo en X y 1 de fondo) y
`height` **0,78 m**. Tu mesa: **1,86 × 0,86 × 0,78 m**.

1. **Archivo nuevo:** `File > New > General`. Guardá con `Ctrl + S` como
   `mueble_mesa.blend`. Prendé **Statistics** en Overlays (guía 02, paso 3).
2. **Crear la colección:** en el **Outliner**, clic derecho sobre
   **Collection** > **New Collection**; doble clic en el nombre nuevo y
   renombrala `table_basic`. *(O seleccioná el cubo, `M`, **+ New Collection**,
   nombre `table_basic`.)*
3. **El tablero:** seleccioná el cubo por defecto (`F2` > `tabletop`). En `N` >
   Item: **Dimensions** X `1.86`, Y `0.86`, Z `0.06`; **Location** X `0`, Y
   `0`, **Z `0.75`**. Luego **`Ctrl + A` > Scale**. *(Si el cubo no quedó dentro
   de `table_basic`, arrastralo allí en el Outliner o apretá `M` > `table_basic`.)*
4. **Una pata:** `Shift + A` > **Mesh > Cube**, `F2` > `leg`. **Dimensions** X
   `0.07`, Y `0.07`, Z `0.72`; **Location** X `0.80`, Y `-0.35`, **Z `0.36`**.
   `Ctrl + A` > **Scale**. Asegurate de que esté en `table_basic`.
5. **El origen de la pata, en el origen del mundo** (lo necesita Mirror):
   `Shift + C` (cursor al centro) y, con `leg` elegida, **Object > Set Origin >
   Origin to 3D Cursor**. **Deberías ver** el puntito naranja en el piso, en el
   centro de la mesa, lejos de la pata.
6. **Modificador Mirror en la pata:** pestaña **Modifiers** > **Add Modifier >
   Generate > Mirror**. Marcá **Axis: X** y **Y** (los botones X e Y; **Z no**).
   **Deberías ver** que aparecen **las 4 patas** en las esquinas.
7. **Bevel en la pata:** **Add Modifier > Generate > Bevel**, **Width
   `0.008`**, **Segments `2`**. Comprobá que el Bevel quede **debajo** del
   Mirror en la lista.
8. **Bevel en el tablero:** seleccioná `tabletop` > **Add Modifier > Generate >
   Bevel**, **Width `0.015`**, **Segments `2`**.
9. **Materiales:** `tabletop` > pestaña **Material** > **New**, nombre
   **`wood_light`**, **Base Color** Hex **`E6B883`**. `leg` > **New** >
   **`wood`**, Hex **`C98F5A`**. *(Pasos 33–36 de la guía 02.)*
10. **Mirá el resultado:** vista **Material Preview**, `Numpad 1` (frente) y
    `Numpad 7` (arriba), con perspectiva/ortográfica `Numpad 5`.
11. **Suavizado:** seleccioná las dos piezas, **Object > Shade Auto Smooth**
    (a confirmar; si no existe, **Shade Smooth**) y, si aparece el modificador
    **Smooth by Angle**, **Angle** `60°` (guía 02, paso 52).

> **Si no te sale (mesa)**
> 1. *Mirror no refleja donde espero:* el origen de `leg` no está en (0,0,0).
>    Repetí el paso 5. Mirror siempre refleja respecto del **origen** del
>    objeto.
> 2. *Solo aparecen 2 patas:* te falta marcar el eje **Y** (o el **X**) en
>    Mirror.
> 3. *Las patas «flotan» o atraviesan el tablero:* revisá **Location Z** de la
>    pata (`0.36`) y su **Dimensions Z** (`0.72`): 0,36 ± 0,36 = de 0 a 0,72;
>    el tablero va de 0,72 a 0,78.

---

## Parte C — La cama (`bed_basic`)

El catálogo pide `footprint` **[1, 2]** (1 celda de ancho en X y 2 de largo en
Y) y `height` **0,55 m**. Tu cama: **0,92 × 1,92 × 0,55 m**, con la **cabecera
atrás** (+Y) y el pie adelante (−Y).

12. **Colección nueva:** en el Outliner, clic derecho en el espacio vacío >
    **New Collection** > `bed_basic`. **Escondé** la de la mesa con el
    **ojito**. *(Todo lo que agregues ahora tiene que estar dentro de
    `bed_basic`: hacé clic en ella antes de agregar para que sea la
    **activa**.)*
13. **Base (marco):** `Shift + A` > **Mesh > Cube**, `F2` > `frame`.
    **Dimensions** `0.92`, `1.76`, `0.18`; **Location** `0`, `0`, `0.19`
    (de 0,10 a 0,28 m). `Ctrl + A` > **Scale**.
14. **Colchón:** cubo nuevo > `mattress`. **Dimensions** `0.84`, `1.70`,
    `0.14`; **Location** `0`, `0`, `0.35` (de 0,28 a 0,42). `Ctrl + A` >
    **Scale**.
15. **Almohada:** cubo nuevo > `pillow`. **Dimensions** `0.50`, `0.30`,
    `0.10`; **Location** `0`, `0.65`, `0.47` (de 0,42 a 0,52, cerca de la
    cabecera). `Ctrl + A` > **Scale**.
16. **Cabecera:** cubo nuevo > `headboard`. **Dimensions** `0.92`, `0.08`,
    `0.45`; **Location** `0`, `0.92`, `0.325` (de 0,10 a 0,55). `Ctrl + A` >
    **Scale**.
17. **Pie de cama:** cubo nuevo > `footboard`. **Dimensions** `0.92`, `0.08`,
    `0.28`; **Location** `0`, `-0.92`, `0.24` (de 0,10 a 0,38). `Ctrl + A` >
    **Scale**.
18. **Una pata y Mirror:** cubo nuevo > `foot`. **Dimensions** `0.08`, `0.08`,
    `0.10`; **Location** `0.40`, `-0.80`, `0.05`. `Ctrl + A` > **Scale**.
    `Shift + C` > **Set Origin > Origin to 3D Cursor** > **Mirror** con
    **Axis X** e **Y**. **Deberías ver** 4 patitas bajo el marco.
19. **Bevel** (Add Modifier > Generate > Bevel) en cada pieza: `Segments 2`,
    **Width**: `frame` `0.012`; `mattress` `0.025` (blando); `pillow` `0.03`
    (muy blando); `headboard`/`footboard` `0.012`; `foot` `0.006`.
    *Cuidado:* el bisel no puede ser más grande que la mitad de la pieza más
    fina; si se ve raro, bajá el ancho.
20. **Materiales:** `mattress` > New > **`cloth_blue`** (Hex `6FB7FF`);
    `pillow` > New > **`cloth_white`** (Hex `F2F2F2`); `frame`, `headboard`,
    `footboard` y `foot`: New en uno > **`wood`** (Hex `C98F5A`) y en los demás
    **Browse Material** (icono de esfera con flecha) > `wood`.
21. **Suavizado** como en el paso 11.
22. **Mirá desde todos lados:** vistas `Numpad 1`, `3`, `7`. La cabecera tiene
    que estar **atrás** (+Y). *Recordá: en Blender, el frente es −Y.*

> **Si no te sale (cama)**
> 1. *Un objeto está en otra colección:* en el Outliner arrastralo a
>    `bed_basic` (o `M`).
> 2. *El bisel «se come» la almohada:* reducí **Width** a `0.02`.
> 3. *La cama sobresale de 0,92 × 1,92:* mirá **Dimensions** de cada pieza y
>    comprobá que ninguna se pase; cabecera y pie van a `y = ±0.92` con grosor
>    0,08 (de 0,88 a 0,96).

---

## Parte D — La estantería (`bookshelf_basic`)

El catálogo pide 1 × 1 celda y `height` **1,7 m**. Tu estantería: **0,90 × 0,40
× 1,70 m**.

> **Aviso de colocación:** el juego coloca la pieza **centrada** en su celda.
> Una estantería de 0,40 m de fondo queda con huecos adelante y atrás.
> Para pegarla a la pared, se usa en el catálogo un ajuste fino `model_offset`
> (en metros; por ejemplo `[0, 0, -0.25]`); el sentido exacto de los ejes
> (a confirmar en tu versión) se prueba en el juego. Es un detalle para la guía 06.

23. **Colección** `bookshelf_basic` (como en el paso 12); escondé las demás.
24. **Un lateral:** cubo > `side_panel`. **Dimensions** `0.04`, `0.40`,
    `1.70`; **Location** **X `0.43`**, `0`, `0.85`. `Ctrl + A` > **Scale**.
25. **Mirror para el otro lateral:** `Shift + C` > **Origin to 3D Cursor** >
    **Mirror** con **Axis X** solamente. **Deberías ver** los dos laterales.
26. **El fondo:** cubo > `back_panel`. **Dimensions** `0.90`, `0.02`, `1.70`;
    **Location** `0`, `0.19`, `0.85`. `Ctrl + A` > **Scale**.
27. **Un estante:** cubo > `shelf`. **Dimensions** `0.82`, `0.36`, `0.04`;
    **Location** `0`, `-0.01`, `0.05`. `Ctrl + A` > **Scale**.
28. **Array para repetirlo:** **Add Modifier > Generate > Array**. Poné **Fit
    Type: Fixed Count**, **Count `5`**. **Desmarcá Relative Offset** y
    **marcá Constant Offset** con **Distance Z `0.4`** (X e Y en `0`).
    **Deberías ver** 5 estantes a 40 cm de distancia entre sí (de z = 0,05 a
    1,65).
29. **Bevel** en las tres piezas: `side_panel` y `shelf` con **Width `0.008`**,
    `back_panel` con `0.005`; **Segments 2** (o **1** si se pasa de
    triángulos). Siempre **debajo** de Mirror/Array.
30. **Materiales:** `side_panel`, `back_panel` y `shelf`: **`wood_dark`**
    (Hex `8F5F3A`) para los laterales y el fondo, **`wood`** para los estantes.
31. **Suavizado** (paso 11).

> **Si no te sale (estantería)**
> 1. *El Array apila los estantes pegados:* desmarcaste Relative Offset pero
>    no marcaste **Constant Offset**, o tiene la distancia en X en vez de Z.
> 2. *Aparece una sola copia:* **Count** estaba en 2 (valor por defecto) o
>    **Fit Type** en otra opción. Poné Fixed Count y 5.
> 3. *Los estantes se salen por arriba:* el último está en z = 0,05 + 4 × 0,4 =
>    1,65 (grosor 0,04 → llega a 1,67). Si te pasás de 1,7, bajá el Count.

---

## Parte E — Revisión antes de exportar (checklist)

**Hacela con cada mueble, siempre, antes de exportar.** Si algo falla, el
número entre corchetes te dice el problema típico en
[`08-problemas-comunes.md`](08-problemas-comunes.md).

| # | Revisá | Cómo | Qué tiene que dar |
| --- | --- | --- | --- |
| 1 | **Tamaño** | Vista `Numpad 7` y `Numpad 1` en ortográfica (`Numpad 5`); la grilla grande es de 1 m. `N` > Item > **Dimensions** de cada pieza | La caja total no se pasa de `footprint × height` del catálogo (mesa 2×1×0,78; cama 1×2×0,55; estante 1×1×1,7) |
| 2 | **Escala 1 y rotación 0** | `N` > Item, en **cada objeto**: Scale 1,1,1 y Rotation 0,0,0 | Si no, `Ctrl + A` > **All Transforms** [modelo gigante/diminuto] |
| 3 | **Piso en z = 0** | Vista frontal: las patas tocan la línea del piso | El punto más bajo en z = 0 [flota/hundido] |
| 4 | **Centrado en el origen del mundo** | Vista de arriba: el mueble cabe simétrico alrededor de la cruz del origen | Centro de la caja en x = 0, y = 0 |
| 5 | **Frente hacia −Y** | Vista `Numpad 1`: lo que ves es el frente | Respaldo/cabecera atrás (+Y) [mira al revés] |
| 6 | **Normales hacia afuera** | **Overlays > Face Orientation** | Todo **azul**, nada rojo [negro o manchado] |
| 7 | **Triángulos** | Statistics (`Triangles`) con **todas las piezas seleccionadas** | Mediano (mesa, cama) **≤ 800**; grande (estante) **≤ 1.200** |
| 8 | **Materiales con nombre** | Pestaña Material de cada pieza | Solo nombres de `data/palette.json`, en minúscula, sin `Material` ni `.001` evitable |
| 9 | **Colores planos** | Material: solo «Base Color» | Sin texturas ni nodos de imagen [sin material] |
| 10 | **Caras superpuestas** | Mirá de cerca las uniones | Las piezas se **meten** una dentro de otra; nada de caras que coincidan en el mismo plano (parpadean) |
| 11 | **Orden de modificadores** | Pestaña Modifiers | Bevel **último** |
| 12 | **Sin objetos de más** | Outliner | Nada suelto (cubos olvidados). La cámara y la luz no molestan si exportás con «Selected Objects» |
| 13 | **Nombre del archivo** | Al exportar | Inglés, minúsculas, `id` del catálogo: `bed_basic.glb` |

Para **medir** con precisión: la **herramienta Measure (Medir)** de la barra de
herramientas (icono de regla; a confirmar su ubicación en tu versión) dibuja una
línea con la distancia en metros. También podés leer **Dimensions**: con
modificadores activos, ese número suele mostrar la caja **ya con los
modificadores** (a confirmar en tu versión).

---

## Parte F — Exportar y verlos en el juego

32. **Mostrar solo un mueble:** con el ojito, dejá visible solo esa colección.
33. **Seleccionar todas sus piezas:** clic derecho sobre la colección en el
    Outliner > **Select Objects (Seleccionar objetos)**. **Deberías ver** todo
    el mueble en naranja.
34. **Exportar:** **File > Export > glTF 2.0** con **las mismas opciones de la
    guía 02, pasos 57–63** (Format **glTF Binary**; Include **Selected
    Objects**; Transform **+Y Up**; Data > Mesh **Apply Modifiers**; sin
    Animation). Nombre: **`table_basic.glb`**, **`bed_basic.glb`** o
    **`bookshelf_basic.glb`**, en `assets/models/`.
35. **Catálogo:** en `data/catalog.json`, en la línea de cada pieza, agregá
    `"model": "res://assets/models/table_basic.glb"` (ya existe en la mesa con
    el ejemplo `table.glb`: solo cambiás el nombre). Para `bed_basic` y
    `bookshelf_basic`, agregá el campo **antes de la llave de cierre `}`**, con
    una **coma** al final del campo anterior:
    ```json
    "actions": ["sleep"], "model": "res://assets/models/bed_basic.glb" },
    ```
    Comprobá el JSON: `python3 -m json.tool data/catalog.json > /dev/null`
    (sin salida = bien).
36. **Probalos en el juego** (guía 02, pasos 71–75): Tienda → la pieza,
    y alternar **Menú → Info → «Usar modelos 3D (arte)»**.

> **Si no te sale (exportar)**
> 1. *Sale solo una parte:* seleccioná **todas** las piezas (paso 33).
> 2. *Las patas espejadas no aparecen:* en la exportación, **Apply Modifiers**
>    tiene que estar marcado.
> 3. *Error de JSON:* falta o sobra una coma o una comilla en el catálogo.

---

## Ejercicios para practicar

1. **Escritorio** (`desk_basic`, 2×1 celdas, 0,75 m de alto): usá lo de la mesa
   con un cajón (un cubo extra con otro color).
2. **Sofá** (`sofa_basic`, 2×1, 0,8 m): asiento, respaldo y dos apoyabrazos
   (Mirror en X).
3. **Estantería con libros:** un cubo `book` de 0,05 × 0,2 × 0,28 con Array
   (Count 8, Constant Offset X `0.06`) y un material `cloth_green`; después otro
   color en otro estante.
4. **Cama doble** (`bed_double`, 2×2): reusá la cama cambiando solo
   Dimensions y apilando dos almohadas con Array.
5. **Revisión cruzada:** pasale el checklist a un mueble que ya hiciste y
   encontrá al menos un error.

## Glosario

- **Modificador:** operación ajustable que no cambia la malla original.
- **Mirror:** copia reflejada respecto del origen del objeto.
- **Array:** copias repetidas a distancias iguales.
- **Bevel:** redondeo de esquinas.
- **Colección:** carpeta del Outliner para ordenar objetos.
- **Material compartido:** varios objetos usan el mismo material.
- **Constant Offset:** distancia fija entre copias de un Array.
- **Caras coincidentes:** dos caras en el mismo plano; parpadean (z-fighting).
- **Huella (footprint):** cuántas celdas ocupa un mueble (ancho × fondo).

Siguiente: [04 — Krita: colores y paleta](04-krita-colores-y-paleta.md).
