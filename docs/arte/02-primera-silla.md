# Guía 02 — Tu primera silla (de Blender al juego)

**Objetivo:** modelar una silla simple con formas redondeadas, con las medidas
y el formato que el juego espera, exportarla como `.glb` y **verla dentro del
juego**.

**Resultado final:** el archivo `assets/models/chair_basic.glb`, enlazado desde
`data/catalog.json`, y tu silla puesta en una casa del juego.

**Tiempo estimado:** 3 a 5 horas la primera vez (las siguientes piezas serán
mucho más rápidas).

**Antes de empezar:** hacé la [guía 01](01-instalar-y-primer-vistazo.md).
Sabés orbitar, seleccionar, `G`/`R`/`S`, deshacer y guardar.

> Lo marcado «(a confirmar en tu versión)» no se pudo verificar para Blender
> 5.2. Manual oficial: <https://docs.blender.org/manual/en/5.2/>. El exportador
> glTF: <https://docs.blender.org/manual/en/5.2/addons/scene_gltf2.html>.

---

## Las reglas del juego (qué tiene que cumplir tu silla)

Salen de [`docs/estilo.md`](../estilo.md) (sección 8) y de `data/catalog.json`.

| Regla | Valor para la silla | Por qué |
| --- | --- | --- |
| Escala | **1 unidad de Blender = 1 metro**. 1 celda = 1 × 1 m | El juego usa metros |
| Caja del catálogo | `chair_basic`: `footprint` **[1, 1]** (1 × 1 celda) y `height` **0,9 m** | Si la pieza se pasa de la caja más de un 5 %, el juego la **achica**; si es menor, la deja como está |
| Tamaño de tu silla | **0,6 × 0,6 m de base y 0,9 m de alto** (cabe holgada en la celda) | Que no toque los muebles vecinos |
| Pivote (origen) | **Centro de la base**, a nivel del piso (z = 0) | Así el juego la apoya bien |
| Orientación | El **frente mira hacia −Y** en Blender (el respaldo queda atrás, en +Y) | Al exportar con «+Y Up» el frente pasa a +Z, que es lo que usa el juego |
| Materiales | Con **nombre** de la paleta (`wood`, `cloth_red`); solo «Base Color» | El juego pinta cada material por su nombre |
| Triángulos | **≤ 400** (mueble chico) | Un teléfono de gama media debe llegar a 30 FPS con muchos muebles |
| Normales | Hacia afuera; suavizadas en las curvas | El shader toon usa las normales |
| Contorno | **No se modela**: lo pone el juego | |

Tu silla (en Blender, con el frente hacia −Y):

```
 vista desde la derecha (Numpad 3): el frente (−Y) queda a la IZQUIERDA

        frente (−Y)                        atrás (+Y)
                         ┌─┐ z = 0,90
                         │ │ respaldo
          cojín  z=0,53  ├─┴────┐
          asiento        └─┬──┬─┘ z = 0,42
                           │  │ patas
   piso  z = 0  ───────────┴──┴──────

 vista desde arriba (Numpad 7): el frente (−Y) queda ABAJO

     y = +0,28  ┌───────────┐  respaldo (atrás)
                │  asiento  │
     y = −0,28  └───────────┘  frente
              x=−0,28   x=+0,28
```

---

## Parte A — Preparar el archivo

1. **Abrí Blender.** Si trae tu trabajo anterior, **File > New > General (Archivo
   > Nuevo > General)**. **Deberías ver** el cubo, la cámara y la luz.
2. **Revisá las unidades:** en el editor de **Propiedades** (abajo a la
   derecha) clic en la pestaña **Scene (Escena)** (icono de cono y esfera) >
   panel **Units (Unidades)**. Tiene que decir **Unit System: Metric
   (Métrico)**, **Unit Scale: 1.0**, **Length: Meters (Metros)**. Es lo normal;
   solo comprobalo.
3. **Mostrar las estadísticas:** en la cabecera del visor 3D, a la derecha,
   clic en el desplegable **Overlays** (dos círculos) y marcá **Statistics
   (Estadísticas)**. **Deberías ver** en la esquina del visor una lista con
   *Objects*, *Vertices*, *Edges*, *Faces* y **Triangles**. El número de
   **Triangles** es el que vamos a vigilar. *(Si no aparece ahí, también se
   puede activar con clic derecho en la barra de estado: a confirmar en tu
   versión.)*
4. **Guardá ya** el archivo con `Ctrl + S` como `silla.blend` en tu carpeta de
   arte (no en `assets/`).

> **Si no te sale (preparar)**
> 1. *No veo «Statistics»:* abrí el desplegable de **Overlays** (la flechita
>    al lado de los círculos) y buscá en la lista; puede estar debajo.
> 2. *Unit Scale no es 1.0:* escribí `1` en ese campo.
> 3. *Ya trabajé en el archivo y tiene cosas de más:* **File > New > General**
>    y empezá limpio.

---

## Parte B — El asiento (extrusión y loop cut)

Vamos a usar el cubo que ya está como asiento.

5. **Seleccioná el cubo** (clic sobre él) y, con el mouse sobre el visor,
   apretá **`F2`**: se abre un cuadrito para **renombrar**. Escribí `seat` y
   `Enter`. **Deberías ver** «seat» en el Outliner.
6. **Abrí la barra lateral** con **`N`** > pestaña **Item** > panel
   **Transform**. En **Dimensions (Dimensiones)** escribí **X `0.56`**, **Y
   `0.56`**, **Z `0.08`** (doble clic en cada campo, número, `Enter`). *Usá
   punto decimal.* **Deberías ver** el cubo aplastado como una tabla fina.
7. En **Location (Ubicación)** escribí **X `0`, Y `0`, Z `0.46`**. (El asiento
   va de 0,42 a 0,50 m de alto.)
8. **Aplicar la escala:** con el mouse sobre el visor, `Ctrl + A` > **Scale
   (Escala)**. **Deberías ver** en **Item > Scale** los tres valores en **1.000**
   (antes eran 0.28 / 0.28 / 0.04). *Esto es obligatorio: el juego espera
   escala 1.*
9. **Entrá al Modo Edición:** apretá **`Tab`** (mouse sobre el visor).
   **Deberías ver** el cubo con puntitos y aristas naranjas y, en la cabecera,
   **tres botoncitos** (vértice, arista, cara). Clic en el **tercero (cara)**.
   *(Con teclado numérico real también sirven `1`, `2` y `3` de la fila de
   arriba.)*
10. **Elegí la cara de arriba** con un clic. **Deberías ver** solo esa cara
    en naranja.
11. **Inset (hundir hacia adentro):** apretá **`I`**, escribí `0.05` y `Enter`.
    **Deberías ver** un cuadrado más chico dentro de la cara de arriba (queda
    un borde de 5 cm).
12. **Extrusión hacia arriba:** apretá **`E`**, escribí `0.03` y `Enter`.
    **Deberías ver** un «cojín» que sobresale 3 cm. *Extruir es «sacar» una
    cara del objeto y estirarla; es la herramienta principal del modelado.*
13. **Loop cut (corte en anillo):** apretá **`Ctrl + R`** y acercá el mouse a
    una arista **vertical** de un costado del asiento (una de las cortitas, de
    8 cm). **Deberías ver** una línea **rosada** que da la vuelta al costado.
    Hacé **un clic** para fijarla y luego **otro clic derecho** (o `Esc`):
    así queda **justo en el medio**. *(Con la rueda del mouse antes del primer
    clic se cambia la cantidad de cortes; dejá 1.)*
14. **Inflar el costado:** el anillo nuevo queda seleccionado. Apretá **`S`**,
    escribí `1.06` y `Enter`. **Deberías ver** el costado del asiento
    levemente panzón, como un almohadón. (El ancho llega a ~0,59 m: sigue
    entrando en la celda.)
15. **Salí del Modo Edición** con **`Tab`**.

> **Si no te sale (asiento)**
> 1. *`Ctrl + R` no muestra la línea rosada:* el mouse tiene que estar sobre el
>    objeto y estar en **Modo Edición**; acercalo a la arista.
> 2. *`E` mueve la cara hacia otro lado:* apretá `Esc`, deshacé con `Ctrl + Z`
>    y comprobá que **solo** esté elegida la cara de arriba (modo cara).
> 3. *Inset/extrusión «se van» muchísimo:* es porque no escribiste el número;
>    deshacé y repetí escribiendo el valor antes del `Enter`.

---

## Parte C — El respaldo

16. **Agregá otro cubo:** `Shift + A` > **Mesh > Cube (Malla > Cubo)** (con el
    mouse sobre el visor). Aparece en el cursor 3D (el origen, si hiciste
    `Shift + C` antes).
17. **`F2`**, renombralo `backrest` (respaldo).
18. **`N` > Item > Transform:** **Dimensions** X `0.56`, Y `0.06`, Z `0.42`.
    **Location** X `0`, **Y `0.25`**, Z `0.69`. (Va pegado al fondo, +Y, de
    0,48 a 0,90 m de alto.)
19. **`Ctrl + A` > Scale** para aplicar la escala. **Deberías ver** Scale 1,1,1.

---

## Parte D — Las cuatro patas (cilindros de pocos lados)

20. `Shift + A` > **Mesh > Cylinder (Malla > Cilindro)**.
21. **Enseguida** (antes de tocar nada más) abrí el panel **Add Cylinder
    (Añadir cilindro)** que aparece **abajo a la izquierda** del visor y
    ajustá: **Vertices (Vértices) `8`**, **Radius (Radio) `0.03`**, **Depth
    (Profundidad) `0.44`**, **Location (Ubicación)** X `0.25`, Y `-0.25`,
    Z `0.22`. *(Si el panel se cerró, deshacé con `Ctrl + Z` y agregá el
    cilindro de nuevo.)* **Deberías ver** un palito de 8 lados (en un
    octógono), de 0 a 0,44 m de alto. Pocos lados = pocos triángulos.
22. **`F2`** > `leg_1`.
23. **Duplicar la pata al otro lado:** con la pata elegida, **`Shift + D`**, luego
    **`X`**, escribí `-0.5`, `Enter`. **Deberías ver** una segunda pata en
    X = −0,25. Renombrala `leg_2` (`F2`).
24. **Las dos de atrás:** seleccioná las dos patas (clic en una y
    `Shift + clic` en la otra), **`Shift + D`**, **`Y`**, `0.5`, `Enter`. Ahora
    hay **4 patas**, dos adelante (y = −0,25) y dos atrás (y = +0,25).
25. **Revisá en vista de arriba** (`Numpad 7`): las cuatro patas en las
    esquinas y el respaldo detrás.
26. **Comprobá las alturas** en la vista lateral (`Numpad 3`): patas que llegan
    del piso hasta adentro del asiento, respaldo hasta 0,90 m.

> **Si no te sale (patas y respaldo)**
> 1. *El cilindro tiene 32 lados:* en el panel «Add Cylinder» cambiá **Vertices**
>    a 8. Si ya no está el panel, lo más fácil es deshacer (`Ctrl + Z`) y
>    agregar el cilindro de nuevo.
> 2. *`Shift + D` y se queda pegado al mouse:* confirmá con clic izquierdo o
>    escribí el número y `Enter`; `Esc` cancela el movimiento pero **deja la
>    copia en el mismo lugar** (deshacé con `Ctrl + Z` si no la querés).
> 3. *Una pata quedó en el lugar equivocado:* seleccionala y corregí
>    **Location** en `N > Item`.

---

## Parte E — Redondear con bisel (Bevel)

El **Bevel (Bisel)** achata las esquinas de 90° para que las formas se vean
suaves. Lo hacemos con un **modificador** (una operación que se puede ajustar
antes de «fijarla»).

27. **Seleccioná `seat`** (clic en el Outliner o en la pieza).
28. **Pestaña Modifiers:** en **Propiedades**, clic en la pestaña de la **llave
    inglesa azul**.
29. **Add Modifier (Añadir modificador) > Generate (Generar) > Bevel
    (Bisel)**. **Deberías ver** el cubo con las esquinas ya redondeadas.
30. **Ajustá el Bevel:** **Width (Ancho) `0.015`** (1,5 cm), **Segments
    (Segmentos) `2`**. *Limit Method (Método de límite): dejalo en **Angle
    (Ángulo)** (suele ser el valor por defecto).* **Deberías ver** esquinas
    suaves, sin deformar la forma.
31. **Fijar el bisel («aplicarlo»):** en el encabezado del modificador, clic
    en la **flechita** (∨) > **Apply (Aplicar)**. El modificador desaparece y
    el redondeo queda en la malla. *(O con el mouse sobre el modificador,
    `Ctrl + A`.)*
32. **Hacé lo mismo con `backrest`**, pero con **Segments `1`** y **Width
    `0.012`** (es más delgado: ahorra triángulos). Después **Apply**.
    *Las patas ya son redondas, no llevan bisel.*

> **Si no te sale (bisel)**
> 1. *El bisel se ve gigante o raro:* te quedó una escala distinta de 1.
>    Deshacé, aplicá la escala (`Ctrl + A > Scale`) y repetí. **Siempre aplicá
>    la escala antes de biselar.**
> 2. *No encuentro «Bevel» en la lista:* está dentro de la categoría
>    **Generate**, no en *Deform*. Podés escribir «bevel» en el buscador del
>    menú.
> 3. *Mi pieza se ve «arrugada»:* hay normales raras; seguí con la parte H
>    (Face Orientation y suavizado).

---

## Parte F — Materiales planos con nombre

El juego pinta cada material **por su nombre**, con el color de
`data/palette.json`. Usaremos `cloth_red` (asiento) y `wood` (resto).

33. **Seleccioná `seat`**. En **Propiedades** clic en la pestaña **Material**
    (esfera con cuadros, abajo de todo en la columna).
34. Clic en **New (Nuevo)**. Aparece un material llamado «Material».
    **Deberías ver** el panel **Surface (Superficie)** con **Principled BSDF**.
35. **Renombralo:** doble clic en el nombre (arriba, donde dice «Material»),
    escribí **`cloth_red`** (todo en minúscula, con guion bajo) y `Enter`.
36. **Color:** en **Surface > Base Color (Color base)** clic en el cuadro de
    color. En el selector, pestaña/campo **Hex**, escribí **`E8645A`** y
    `Enter`. *(Es el color de `cloth_red` en `data/palette.json`. El juego
    igual lo pinta con la paleta; este color es solo para que lo veas.)*
    **No toques** Metallic, Roughness ni nada más: el juego solo usa el color.
37. **Seleccioná `backrest`** > pestaña **Material** > **New** > renombrá
    **`wood`** > **Base Color** Hex **`C98F5A`**.
38. **Seleccioná una pata** > **Material** > clic en el **icono de esfera
    con flecha** (Browse Material, «Explorar material», al lado del nombre) y
    elegí **`wood`** (el que ya existe). *Así reusás el mismo material.* Hacelo
    en las otras tres patas.
39. **Mirá los colores:** en la cabecera del visor, entre las cuatro
    bolitas de **Shading (Sombreado)**, elegí **Material Preview (Vista previa
    de material)** (la tercera). **Deberías ver** el asiento rojo y lo demás
    marrón. *(La primera vez puede tardar un momento en cargar.)*

> **Si no te sale (materiales)**
> 1. *Se llama `wood.001`:* no pasa nada, el juego ignora el `.001`. Pero mejor:
>    reusá el material existente (paso 38) en vez de crear otro.
> 2. *No veo color en el visor:* estás en modo **Solid**; pasá a **Material
>    Preview** (paso 39).
> 3. *El material no se nombra:* hacé doble clic **sobre el nombre** y escribí;
>    no sobre el icono.

---

## Parte G — Unir todo en una sola pieza

40. **Seleccioná todo:** mouse sobre el visor, **`A`**.
41. **Hacé activo el asiento:** `Shift + clic` sobre el asiento hasta que quede
    más claro que el resto (puede que debas hacer clic dos veces: una quita,
    otra agrega y deja «activo»). *El «activo» es el que manda al unir.*
42. **Unir:** **Object > Join (Objeto > Unir)** o `Ctrl + J`. **Deberías ver**
    en el Outliner **un solo objeto**.
43. **`F2`** > renombralo **`chair_basic`** (igual que el `id` del catálogo).
44. **Verificá los materiales:** pestaña **Material**: deberían verse **dos
    ranuras**: `cloth_red` y `wood`. (Si ves `wood` repetido, no importa.)

> **Si no te sale (unir)**
> 1. *`Ctrl + J` no hace nada:* con el mouse sobre el visor y con **Objetos**
>    seleccionados (no estando en Modo Edición).
> 2. *Se perdió un color:* el activo (el último seleccionado) define el orden;
>    revisá las ranuras y asigná el material correcto en Modo Edición
>    (selección > **Assign (Asignar)**).
> 3. *Quedó una pata afuera:* `Ctrl + Z` y volvé a seleccionar **todo** con `A`.

---

## Parte H — Pivote, escala, normales y triángulos

### Pivote en el centro de la base

La silla ya está centrada en X e Y y apoyada en z = 0, pero el **origen** del
objeto (el puntito naranja) quedó en el asiento (z = 0,46) porque lo heredó del
asiento.

45. **Cursor 3D al origen del mundo:** `Shift + C` (mouse sobre el visor).
    *(Esto lleva el cursor 3D a (0, 0, 0) y encuadra todo.)*
46. Con `chair_basic` seleccionado: **Object > Set Origin > Origin to 3D
    Cursor (Objeto > Establecer origen > Origen al cursor 3D)**. **Deberías
    ver** el puntito naranja del origen **en el piso**, en el medio de la
    silla.
47. **Comprobá:** `N` > Item > **Location** = **0, 0, 0**; **Dimensions** ≈
    **0.59 × 0.56 × 0.90** (el ancho exacto depende de tu inflado).
    **Rotation** = 0, **Scale** = 1.

> **Para muebles no simétricos** (cama, estante), el centro de la base no es el
> origen del mundo: en **Modo Edición**, seleccioná **la cara de abajo**,
> `Shift + S` > **Cursor to Selected (Cursor a selección)**, volvé a Modo
> Objeto, **Origin to 3D Cursor** y por último **`Alt + G`** (limpia la
> ubicación y lleva el objeto al origen del mundo). Se usa en la guía 03.

### Aplicar transformaciones

48. **`Ctrl + A` > All Transforms (Todas las transformaciones)**. Con
    Location 0 y Scale 1 no cambia nada, pero es un hábito que evita
    sorpresas.

### Normales hacia afuera

49. En la cabecera del visor, **Overlays > Face Orientation (Orientación de
    caras)**. **Deberías ver** TODO el modelo en **azul**. El **rojo** significa
    cara «al revés».
50. **Si hay rojo:** **Modo Edición** (`Tab`), `A` para elegir todo y
    **Mesh > Normals > Recalculate Outside (Malla > Normales > Recalcular
    hacia afuera)** (atajo `Shift + N`). Volvé con `Tab`.
51. **Apagá Face Orientation** (la misma casilla) cuando termines: si queda
    prendida no se nota en el juego, pero te confunde.

### Suavizado

52. Con la silla seleccionada: **Object > Shade Auto Smooth (Objeto >
    Sombrear auto-suave)** (a confirmar en tu versión: así se llama en
    Blender 4.2; si no lo encontrás usá **Object > Shade Smooth**). **Deberías
    ver** las curvas suaves y las caras planas planas. Si agregó un
    modificador **Smooth by Angle**, abrilo en la pestaña **Modifiers** y
    poné **Angle (Ángulo) `60°`** (así las curvas del bisel quedan suaves y
    las tapas de las patas siguen duras).

### Triángulos

53. **Leé el número «Triangles»** de las estadísticas (con la silla elegida
    suele aparecer el de la selección y el total). **La meta es ≤ 400.**
    Con los valores de esta guía suele quedar **entre 300 y 450** (a
    confirmar en tu versión: depende de tus cortes).
54. **Si te pasás de 400:** (a) bajá **Segments** del bisel del asiento de 2
    a 1 (deshacé y repetí), (b) usá **6** vértices en las patas en vez de 8,
    (c) sacá el loop cut del paso 13. Cada cambio resta unas decenas.
    *Nota:* las caras de más de 3 lados cuentan como varios triángulos; el
    número «Triangles» ya lo tiene en cuenta.

> **Si no te sale (revisión)**
> 1. *El origen no queda donde espero:* `Shift + C` primero, y recién después
>    **Origin to 3D Cursor**. Mirá que el cursor 3D (círculo rojo y blanco)
>    esté en el piso, en el centro.
> 2. *Se ve «negro» o con manchas de sombra raras:* revisá **Face
>    Orientation** (pasos 49 y 50).
> 3. *El suavizado no existe:* usá **Object > Shade Smooth**; es una opción
>    más simple con resultado parecido.

---

## Parte I — Exportar el `.glb`

55. **Seleccioná solo `chair_basic`** (clic en él; que sea lo único naranja).
56. Menú **File > Export > glTF 2.0 (.glb/.gltf) (Archivo > Exportar > glTF
    2.0)**. Se abre el explorador de archivos con un **panel de opciones a la
    derecha**. *(Los nombres de las secciones de abajo corresponden a Blender
    4.2 en adelante; en 5.2 puede variar la ubicación: a confirmar en tu
    versión.)*
57. **Format (Formato):** **glTF Binary (.glb)** (un solo archivo).
58. **Include (Incluir)** > **Limit to (Limitar a)**: marcá **Selected Objects
    (Objetos seleccionados)**. Dejá **desmarcado** *Cameras (Cámaras)* y
    *Punctual Lights (Luces puntuales)* si aparecen. **Custom Properties**:
    desmarcado.
59. **Transform (Transformación):** **+Y Up** **marcado**. *(Esto convierte el
    «arriba» de Blender (Z) al «arriba» del juego (Y), y deja el frente en +Z.)*
60. **Data > Mesh (Datos > Malla):**
    - **Apply Modifiers (Aplicar modificadores):** **marcado**.
    - **UVs:** déjalo como esté (no se usan texturas).
    - **Normals (Normales):** **marcado** (importante para el toon).
    - **Tangents**, **Vertex Color**, **Attributes**, **Loose Edges/Points**:
      desmarcados.
61. **Data > Material (Materiales):** **Materials: Export (Exportar)**.
    **Images:** si hay una lista, «Automatic» o «None» da igual (no hay
    texturas).
62. **Data > Compression (Compresión) / Draco:** **desmarcado**. *(Godot no lo
    necesita.)*
63. **Animation (Animación):** **desmarcado** (la silla no se anima).
64. **Ubicación y nombre:** navegá hasta la **carpeta del proyecto** (la que
    tiene `project.godot`) > `assets` > `models`. En **nombre de archivo**
    escribí **`chair_basic.glb`** (inglés, minúsculas, guion bajo).
65. Clic en **Export glTF 2.0 (Exportar glTF 2.0)**. **Deberías ver** que el
    archivo aparece en la carpeta `assets/models/`. Pesa unos pocos KB.
66. **Guardá el `.blend`** (`Ctrl + S`). *Blender recuerda las opciones de
    exportación para la próxima vez.*

> **Si no te sale (exportar)**
> 1. *No veo la opción «+Y Up»:* está en la sección **Transform**; si la
>    sección está plegada, hacé clic en el título para abrirla.
> 2. *Se exportó con cámara y luz:* repetí con **Selected Objects** marcado
>    y esos dos desmarcados.
> 3. *No encuentro la carpeta del proyecto (Flatpak):* ver guía 01 (permisos
>    de Flatpak); o exportá a otra carpeta y copiá el archivo con el
>    administrador de archivos.

---

## Parte J — Conectarlo al catálogo y verlo en el juego

El catálogo ya tiene una silla (`chair_basic`) que apunta al ejemplo
`chair.glb`. Ahora la vamos a apuntar a **tu** silla.

67. **Abrí `data/catalog.json`** con un editor de texto (Kate, VS Code).
68. **Buscá** (`Ctrl + F`) `chair_basic`. La línea termina así:
    ```json
    "model": "res://assets/models/chair.glb" },
    ```
69. **Cambiá solo** `chair.glb` por `chair_basic.glb`:
    ```json
    "model": "res://assets/models/chair_basic.glb" },
    ```
    **Cuidado con el JSON:** no borres comillas ni comas. Guardá.
    *(El archivo `chair.glb` de ejemplo no se toca; Git guarda todo, podés
    volver atrás.)*
70. **Comprobá que el JSON sigue bien** (en la terminal, parado en la carpeta
    del proyecto):
    ```bash
    python3 -m json.tool data/catalog.json > /dev/null
    ```
    **Si no imprime nada, está bien.** Si imprime un error con un número de
    línea, miralo y corregilo.
71. **Abrí el proyecto en Godot** (ver `README.md`: «Abrir el proyecto»).
    Godot **importa** `chair_basic.glb` solo (crea un archivo `.import` junto
    al `.glb`; es normal).
72. **Corré el juego** con **`F5`** y entrá a tu partida.
73. **Poné la silla:** **Tienda → Silla** → colocala en una casa. **Deberías
    ver** tu silla con asiento rojo y patas marrones, redondeada.
74. **Compará con la figura simple:** **Menú → Info → «Usar modelos 3D
    (arte)»**: apagado muestra la caja simple; prendido, tu silla.
75. **Girala** con el botón de rotar y mirala desde varios lados: el
    **respaldo tiene que quedar «atrás»** respecto de cómo la apuntás. Si queda
    adelante, ver `08-problemas-comunes.md` («Mira al revés»).

> **Si no te sale (juego)**
> 1. *Sigo viendo la caja simple:* ¿está prendido «Usar modelos 3D (arte)»?
>    ¿el nombre del archivo coincide letra por letra con el del catálogo?
>    ¿Godot terminó de importar (mirá abajo a la derecha)?
> 2. *Se ve muy chica o muy grande:* revisá las dimensiones (paso 47) y la
>    escala aplicada. Si es mayor que la caja, el juego la achica solo.
> 3. *Rojo en Godot o el juego no arranca:* revisá el JSON (paso 70). Pegale
>    el texto exacto del error al asesor.

### Pedile al asesor un chequeo técnico (recomendado)

El asesor puede correr `ModelLoader.inspect("res://assets/models/chair_basic.glb")`
en la consola de Godot, que dice **triángulos, materiales, tamaño** y **avisos**
(pivote mal puesto, material que no está en la paleta, tamaño absurdo). Es la
mejor forma de confirmar que cumplís todo.

---

## Ejercicios para practicar

1. **Silla más baja** (un taburete): sacá el respaldo y bajá las patas.
   Altura del catálogo `stool_restaurant` = 0,65 m.
2. **Otro color de tela:** cambiá el material del asiento a `cloth_blue`
   (**Hex** `6FB7FF`). Fijate que el nombre coincida con la paleta.
3. **Sin mirar la guía**, rehacé la silla en 30 minutos.
4. **Mirá el ejemplo** `assets/models/chair.glb` en Blender: **File > Import >
   glTF 2.0** y comparalo con la tuya (¿mismas medidas?).
5. **Cambiá a propósito** el pivote (muévelo arriba) y mirá en el juego qué
   pasa: así vas a reconocer el problema cuando te ocurra.

## Glosario

- **Mesh (malla):** la forma de un objeto, hecha de puntos, líneas y caras.
- **Vértice / arista / cara:** punto / línea entre dos puntos / superficie
  entre aristas.
- **Triángulo:** la unidad que mide el costo de dibujar; toda cara se divide en
  triángulos.
- **Extrusión (`E`):** sacar una cara hacia afuera para darle volumen.
- **Inset (`I`):** achicar una cara hacia adentro dentro de sí misma.
- **Loop cut (`Ctrl + R`):** agregar un anillo de aristas para tener más
  puntos donde modelar.
- **Bevel (bisel):** achatar o redondear esquinas.
- **Modificador:** operación ajustable que se puede aplicar después.
- **Material:** color y aspecto de una superficie; aquí, un color plano con
  nombre.
- **Origen / pivote:** el puntito del objeto desde el que se mide su
  posición.
- **Escala aplicada:** escala = 1 con el tamaño «cocinado» en la malla.
- **Normal:** la flecha invisible que dice hacia dónde mira una cara.
- **Exportar glTF:** guardar el modelo en el formato que Godot entiende.

Siguiente: [03 — Mueble con partes](03-mueble-con-partes.md).
