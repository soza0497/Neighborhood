# Guía 05 — Íconos para la interfaz (SVG)

**Objetivo:** dibujar un ícono propio de **64 × 64 px**, de **trazo blanco
redondeado**, igual a los de `assets/icons/`, guardarlo como **SVG** y dejarlo
listo para el juego.

**Resultado final:** un archivo `bed.svg` (o el que elijas) en
`assets/icons/`, que se ve nítido en un botón del juego.

**Tiempo estimado:** 2 a 3 horas (incluye instalar el programa).

---

## Parte A — Qué programa usar (y por qué)

Un **SVG** es un dibujo hecho de **líneas y curvas matemáticas** (vectores), no
de píxeles: se ve nítido a cualquier tamaño. Es el formato de los íconos del
juego (`assets/icons/*.svg`).

| Programa | Gratis en Linux | SVG | Veredicto |
| --- | --- | --- | --- |
| **Inkscape** | Sí (repositorios y Flathub) | **Es su formato natural** | **Recomendado** |
| **Krita** (capas vectoriales) | Ya instalado | Limitado: hay que exportar **una capa vectorial por vez** (según la documentación de Krita 4/5; a confirmar en Krita 6) y el tamaño en unidades puede salir distinto de lo esperado | Para bocetar la idea; no para el archivo final |

**Recomiendo Inkscape**, por estas razones:

1. **Está hecho para SVG:** lo que ves en pantalla es lo que queda en el archivo.
2. **Control exacto del trazo** (grosor, extremos redondeados, uniones
   redondeadas) en un solo panel, que es lo que define el estilo de los íconos.
3. **Medidas en píxeles y cuadrícula** con imán: todo cae en puntos exactos.
4. **Guarda «SVG simple»** (Plain SVG), sin datos de más, que el juego lee bien.
5. Hay documentación oficial gratuita: <https://inkscape.org/learn/>.

> Krita sirve para **probar la idea** del ícono a mano alzada (guía 04); el
> archivo final se dibuja en Inkscape.

### Instalar Inkscape (pacman primero, Flathub si no)

Igual que Blender (guía 01): pacman necesita **permisos de administrador con
`pkexec`** (nunca `sudo`), y **tenés que avisar al asesor para anotarlo en la
bitácora** (`~/intranet/bitacora/`).

1. **Avisale al asesor:** «Voy a instalar `inkscape` con pacman».
2. **Mirá la versión disponible:**
   ```bash
   pacman -Si inkscape
   ```
3. **Instalá** (pide tu contraseña en una ventana):
   ```bash
   pkexec pacman -S inkscape
   ```
   Confirmá con `y`. Si falla porque «no encuentra archivos» (404), la lista de
   paquetes está vieja: avisale al asesor, no pruebes otros comandos.
4. **Comprobá:**
   ```bash
   inkscape --version
   ```
   Pasale la versión al asesor para la bitácora.
5. **Plan B (Flathub)**, solo si pacman falla:
   ```bash
   flatpak install --user flathub org.inkscape.Inkscape
   ```
   Para abrirlo: `flatpak run org.inkscape.Inkscape`. *(El Flatpak puede no ver
   la carpeta del proyecto; si pasa, avisale al asesor.)*

> **Si no te sale (instalar)**
> 1. *`target not found`:* nombre mal escrito o lista vieja → avisale al
>    asesor.
> 2. *No aparece la ventana de contraseña:* repetí el comando; si sigue,
>    avisale.
> 3. *Instalé la versión Flatpak y no ve mis carpetas:* usá la de pacman o
>    pedile al asesor que otorgue el permiso.

*(Los nombres y atajos de Inkscape de abajo son los de la serie 1.x, a
confirmar en tu versión; no pude abrir el manual oficial al escribir esta
guía.)*

---

## Parte B — El estilo de los íconos del juego

Mirá un par de archivos de `assets/icons/` (por ejemplo `heart.svg`, `home.svg`,
`coin.svg`) con un editor de texto. Todos siguen estas reglas:

| Regla | Valor |
| --- | --- |
| Tamaño del lienzo | **64 × 64 px**, `viewBox="0 0 64 64"` |
| Trazo | **blanco `#ffffff`**, grosor **5 px** (algunos 4, 3 ó 2 para detalles) |
| Extremos y uniones | **redondeados** (`stroke-linecap="round"`, `stroke-linejoin="round"`) |
| Relleno | **ninguno** (`fill="none"`), salvo detalles de color en íconos de «necesidades» |
| Margen | el dibujo vive aprox. entre **8 y 56 px**; no toques los bordes |
| Detalle | nada más fino que 4 px: se ve en un botón de 64 px |
| Texto | **ninguno** (si usás texto, convertilo a trazos o el juego no lo ve) |
| Efectos | **ninguno**: sin sombras, difuminados ni degradés |

**Por qué blanco:** el juego dibuja un fondo oscuro redondeado detrás
(`Icons.setup` en `ui/icons.gd`), y el blanco resalta. Para un ícono de color
(como los de necesidades: `need_*.svg`), hablalo con el asesor.

---

## Parte C — Dibujar el ícono «cama» paso a paso

Vamos a dibujar una cama con **líneas rectas** y **un rectángulo redondeado**.

### Preparar la hoja

6. **Abrí Inkscape.** **File > New (Archivo > Nuevo)** (`Ctrl + N`).
   **Deberías ver** una hoja blanca (A4) vacía.
7. **Propiedades del documento:** **File > Document Properties (Archivo >
   Propiedades del documento)** (`Ctrl + Shift + D`).
8. **Tamaño de página:** unidades **px**; **Width (Ancho) `64`**, **Height
   (Alto) `64`**. **Scale (Escala) `1`** (es decir `viewBox` 0 0 64 64). *(En
   la 1.x, el panel se llama «Page»; a confirmar en tu versión.)*
   **Deberías ver** la hoja reducida a un cuadradito.
9. **Fondo oscuro para ver el blanco:** en el mismo diálogo, **Background
   (Fondo)** o **Checkerboard**: elegí un color oscuro (por ejemplo `#22304a`) y
   quitá la transparencia (a confirmar dónde está en tu versión). *Esto no
   afecta al archivo final.*
10. **Acercá la vista:** apretá **`5`** (zoom a la página) con el mouse sobre
    el lienzo. **Deberías ver** la hoja de 64 px llenando la ventana.
11. **Cuadrícula e imán:** en el mismo diálogo, pestaña/sección **Grids
    (Cuadrículas)** > **New** > **Rectangular grid**: **Spacing X** y **Y**
    **`4`** px. Prendé la cuadrícula con **`#`** y el **imán** (snapping) con
    **`%`**. *(Así cada punto cae en múltiplos de 4 y todo queda prolijo.)*

### Dibujar

12. **Herramienta Pluma (Pen / Bezier):** apretá **`B`**. En la barra de
    arriba de la herramienta, comprobá que el modo sea el de «caminos
    regulares» (**Regular Bezier path**).
13. **El cabecero:** hacé **clic** en `(12, 16)` (casi arriba a la izquierda) y
    luego **clic** en `(12, 48)`; apretá **`Enter`** para terminar. **Deberías
    ver** una línea vertical. *(Las coordenadas aparecen en la barra de
    estado/abajo al mover el mouse; con el imán, cuesta equivocarse.)*
14. **Base y pie:** nuevo trazo con la pluma: clic en `(12, 40)`, clic en
    `(52, 40)`, clic en `(52, 48)`, `Enter`. **Deberías ver** una «L» acostada
    que forma el colchón.
15. **La almohada:** herramienta **Rectángulo** (**`R`**) y arrastrá un
    cuadradito de `(20, 28)` a `(28, 36)`. En la barra de arriba, poné **Rx
    `3`** y **Ry `3`** para redondear las esquinas.
16. **La manta:** pluma (`B`): clic en `(32, 40)`, `(32, 32)`, `(48, 32)`,
    `(52, 36)`, `(52, 40)` y `Enter`. **Deberías ver** una línea quebrada sobre
    la base.

### Estilo del trazo (lo más importante)

17. **Seleccioná todo:** herramienta **Selector** (**`S`** o la flecha) y
    `Ctrl + A` (**Edit > Select All**).
18. **Abrí el panel Relleno y borde:** **Object > Fill and Stroke (Objeto >
    Relleno y borde)** (`Ctrl + Shift + F`).
19. **Pestaña Fill (Relleno):** botón **X (No paint, sin pintura)**. **Deberías
    ver** que desaparece el relleno de la almohada.
20. **Pestaña Stroke paint (Pintura del borde):** **Flat color (Color
    plano)** y **RGBA `ffffffff`** (blanco opaco).
21. **Pestaña Stroke style (Estilo del borde):** **Width (Ancho) `5` px**,
    **Join (Unión): Round (redonda)**, **Cap (Remate): Round (redondo)**.
    **Deberías ver** una cama con trazo grueso y esquinas suaves, como los
    demás íconos.
22. **Convertir formas a trazos:** con todo seleccionado, **Path > Object to
    Path (Trayecto > Objeto a trayecto)** (`Shift + Ctrl + C`). Así el
    rectángulo pasa a ser un camino como el resto.
23. **Agrupar:** `Ctrl + G` (**Object > Group**). Un solo grupo ordenado.
24. **Centrado:** con el grupo seleccionado, **Object > Align and Distribute
    (Alinear y distribuir)** (`Shift + Ctrl + A`), **Relative to: Page**, y
    centrá horizontal y verticalmente. **Deberías ver** la cama centrada en la
    hoja, lejos de los bordes.

> **Si no te sale (dibujar)**
> 1. *No veo nada blanco:* el fondo de la hoja es blanco. Poné el color de
>    fondo oscuro (paso 9) o cambiá momentáneamente el trazo a negro.
> 2. *Los puntos no caen donde quiero:* el imán (`%`) está apagado o la
>    cuadrícula (`#`) no se creó (paso 11).
> 3. *Hice un desastre:* `Ctrl + Z` deshace; `Ctrl + Shift + Z` rehace.

---

## Parte D — Guardar como SVG para el juego

25. **Guardá primero tu archivo de trabajo** (con todas las funciones de
    Inkscape): **File > Save As (Guardar como)** (`Ctrl + Shift + S`), tipo
    **Inkscape SVG**, en tu carpeta de arte (`~/arte/neighborhood/iconos/bed.svg`).
    **Conservá este archivo**: es tu «maestro» para editar después.
26. **Guardá la copia para el juego:** **File > Save a Copy... (Guardar una
    copia)** (`Shift + Ctrl + Alt + S`), tipo **Plain SVG (SVG simple)**, nombre
    **`bed.svg`**, carpeta **`assets/icons/`** del proyecto.
    *(Plain SVG saca los datos propios de Inkscape y deja el archivo
    chiquito.)*
27. **Nombre del archivo:** **inglés, minúsculas, con guiones bajos**
    (`bed.svg`, `need_energy.svg`). Será el nombre que use el juego.
28. **Revisalo con un editor de texto** (Kate): tiene que decir algo como
    `width="64" height="64" viewBox="0 0 64 64"` y usar `stroke="#ffffff"`. No
    debe tener `<text>`, `<filter>` ni `<linearGradient>`. Podés comparar con
    [`ejemplos/bed.svg`](ejemplos/bed.svg) (es la cama ya hecha: el
    «resultado esperado»).
    - Si el tamaño sale en otras unidades (`width="17mm"`), repasá el paso 8.

> **Si no te sale (guardar)**
> 1. *No encuentro «Plain SVG»:* en el desplegable de tipos de archivo del
>    cuadro de guardado, buscá «Plain SVG (*.svg)».
> 2. *El archivo pesa mucho:* guardaste como «Inkscape SVG»; usá «Plain SVG».
> 3. *Se ve cortado en el juego:* el dibujo toca los bordes; dejá margen
>    (paso 24).

---

## Parte E — Meterlo al juego

El juego carga los íconos por su **nombre de archivo**: la función
`Icons.texture("bed")` abre `res://assets/icons/bed.svg`, y
`Icons.make_button("bed", "Cama")` arma el botón (`ui/icons.gd`). **Solo con
copiar el archivo el ícono todavía no aparece en pantalla**: hay que decidir
**en qué botón va** y conectarlo en el código. Eso lo hace el asesor.

29. **Con el SVG ya en `assets/icons/`, abrí el proyecto en Godot** (ver
    `README.md`). Godot lo **importa solo** y crea `bed.svg.import` al lado
    (es normal; se guarda en Git junto con el `.svg`).
30. **Mirá cómo se ve:** en el panel **FileSystem** de Godot, buscá
    `assets/icons/bed.svg` y hacé clic. **Deberías ver** la vista previa.
31. **Avisale al asesor** con tres datos: **nombre del archivo** (`bed`),
    **en qué botón o categoría** lo querés (por ejemplo «categoría Muebles
    de la tienda») y **el texto** que debe decir al apoyar el mouse.
32. **Probalo en el juego** con **`F5`**: el ícono tiene que verse **blanco y
    nítido** sobre el fondo oscuro, **sin bordes cortados**.

> **Si no te sale (juego)**
> 1. *Godot no muestra el ícono:* esperá a que termine de importar (abajo a la
>    derecha) o reabrí el proyecto.
> 2. *Se ve muy finito o borroso:* subí el grosor a 5 px (paso 21) y
>    revisá que el lienzo sea de 64 × 64 (paso 8).
> 3. *Aparece negro o invisible:* el trazo no es `#ffffff` (paso 20).

---

## Ejercicios para practicar

1. Dibujá un ícono de **silla** (`chair`), uno de **lámpara** (`lamp`) y uno de
   **planta** (`plant`). Mantené trazo 5 px y esquinas redondas.
2. Abrí `assets/icons/home.svg` en Inkscape (**File > Open**) y mirá cómo está
   hecho: ¿cuántos trazos? Imitalo para hacer un «garaje».
3. Hacé el mismo ícono con trazo de 4 px y de 5 px y compará cuál se lee
   mejor en una pantalla chica.
4. Pedile al asesor que te muestre tu ícono en el juego dentro del teléfono y
   fijate si se entiende **sin leer** el texto.
5. Dibujá una **familia de 6 íconos** (muebles, plantas, decoración, cocina,
   baño, dormitorio) con el mismo estilo y revisá que se vean «de la misma mano».

## Glosario

- **SVG:** dibujo hecho de líneas y curvas matemáticas; se ve nítido a
  cualquier tamaño.
- **Vector:** forma definida por puntos y curvas, no por píxeles.
- **Trazo (stroke):** el borde de una forma.
- **Relleno (fill):** el color del interior de una forma.
- **Remate (cap) / unión (join):** cómo terminan las puntas y cómo se
  juntan las esquinas de un trazo (redondeadas en este juego).
- **`viewBox`:** el «marco» interno del dibujo (aquí 0 0 64 64).
- **Cuadrícula e imán (grid / snap):** rejilla y atracción a sus puntos.
- **Plain SVG:** SVG limpio, sin datos propios del programa.
- **Maestro:** el archivo de trabajo que conservás para seguir editando.

Siguiente: [06 — Cuarto de prueba](06-cuarto-de-prueba.md).
