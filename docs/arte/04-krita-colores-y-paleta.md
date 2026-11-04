# Guía 04 — Krita: colores y paleta del juego

**Objetivo:** aprender lo básico de Krita (interfaz, documento, pincel, capas)
y usarlo para tres cosas del proyecto: **elegir y probar la paleta de colores**
del juego, **bocetar muebles y personajes de referencia**, y entender por qué
**no usamos texturas** (todavía).

**Resultado final:** tu paleta cargada en Krita, una hoja de prueba con
combinaciones de colores y un boceto de un mueble con vistas de frente, de
lado y de arriba.

**Tiempo estimado:** 2 a 3 horas.

**Programa:** Krita 6 (ya está instalada en tu PC). Documentación oficial:
<https://docs.krita.org/en/>. Podés hacer esta guía **en cualquier momento
después de la 01**; no depende de las guías 02 y 03.

> **Honestidad sobre esta guía:** se escribió sin poder abrir el manual de
> Krita 6, así que la mayoría de nombres de menús salen de Krita 5 (que Krita 6
> mantiene en casi todo). Lo dudoso está marcado **«(a confirmar en tu
> versión)»**. Creele a tu pantalla.

---

## Parte A — Conocer Krita

1. **Abrí Krita** desde el menú de aplicaciones (categoría Gráficos) o con
   `krita` en la terminal. **Deberías ver** una pantalla de bienvenida con
   enlaces «New File», «Open File» y archivos recientes.
2. **Comprobá la versión:** menú **Help > About Krita (Ayuda > Acerca de
   Krita)**. Debería decir 6.0.x.
3. **La interfaz, pieza por pieza** (aparece completa al abrir un documento):
   - **Barra de menús** (arriba): File, Edit, View, Image, Layer, Select,
     Filter, Tools, Settings, Window, Help.
   - **Caja de herramientas (Toolbox)**, columna de iconos a la **izquierda**:
     pincel, relleno, selecciones, formas, etc.
   - **Barra de herramientas** (arriba, bajo los menús): aquí está el
     **selector de preset de pincel**, el **tamaño** y la **opacidad**.
   - **Lienzo (canvas):** el centro, donde dibujás.
   - **Paneles acoplables (Dockers)**, a la **derecha**: **Layers (Capas)**,
     **Brush Presets (Ajustes de pincel)**, **Advanced Color Selector
     (Selector de color avanzado)**, **Palette (Paleta)**, **Tool Options
     (Opciones de herramienta)**. Se muestran u ocultan en **Settings > Dockers
     (Preferencias > Paneles)**.
   - **Barra de estado** (abajo): tamaño del documento y zoom.

> **Si no te sale (interfaz)**
> 1. *Falta un panel (por ejemplo Layers):* **Settings > Dockers >** y
>    marcá el que falta.
> 2. *Rompí el diseño:* **Window > Workspace (Ventana > Espacio de trabajo)**
>    tiene diseños prearmados (por ejemplo «Default»): elegí uno
>    (a confirmar en tu versión).
> 3. *Los menús están en inglés y quiero español:* **Settings > Switch
>    Application Language (Preferencias > Cambiar el idioma de la
>    aplicación)**; requiere reiniciar Krita. Esta guía usa los nombres en
>    inglés.

---

## Parte B — Primer documento, pincel y capas

4. **Nuevo documento:** `Ctrl + N` (**File > New (Archivo > Nuevo)**). Se abre
   **Create New Document (Crear nuevo documento)**.
5. En la lista de la izquierda elegí **Custom Document (Documento
   personalizado)** y poné: **Width (Ancho) `1600` px**, **Height (Alto)
   `1000` px**, **Resolution (Resolución) `72` ppi**. En **Color**: modelo
   **RGB/Alpha**, **8-bit integer/channel (8 bits enteros por canal)**,
   perfil **sRGB** (algo como «sRGB-elle-V2-srgbtrc»; a confirmar en tu
   versión). **Content (Contenido) > Background (Fondo):** blanco (o el color
   que prefieras). **Name (Nombre):** `pruebas`. Clic en **Create (Crear)**.
   **Deberías ver** una hoja blanca en el centro.
   > Para pantallas, 72 ppi alcanza: en el juego las dimensiones en píxeles
   > son lo que cuenta.
6. **Guardar:** `Ctrl + S`. Krita guarda en su formato **`.kra`** (conserva
   las capas). Elegí una carpeta tuya (por ejemplo `~/arte/neighborhood/krita/`),
   **no dentro de `assets/`**. *Ese formato no lo lee el juego; después se
   exporta a PNG si hace falta.*
7. **Elegí el pincel:** apretá **`B`** (herramienta **Freehand Brush Tool
   (Pincel a mano alzada)**). En la barra de herramientas, abrí el **selector
   de presets** (el icono del pincel) y elegí uno de borde duro de nombre
   sencillo (en Krita 5 se llama algo como «Basic-… Size Opacity» o «Basic-1
   Pencil»; los nombres exactos pueden variar: a confirmar en tu versión).
   Dibujá un garabato en el lienzo. **Deberías ver** un trazo de color negro.
8. **Tamaño del pincel:** las teclas **`[`** y **`]`** lo achican y agrandan
   (también arrastrar con `Shift + clic izquierdo`). **Borrador:** apretá
   **`E`** para alternar entre pintar y borrar. **Deshacer:** `Ctrl + Z`;
   **rehacer:** `Ctrl + Shift + Z`.
9. **Moverte por el lienzo:** **desplazar** = mantené `Space` (barra
   espaciadora) y arrastrá con el mouse; **zoom** = rueda del mouse
   (o `Ctrl + Space` y arrastrar); **girar el lienzo** = `Shift + Space` y
   arrastrar. (Estos atajos son los de Krita 5; a confirmar en tu versión.)
10. **Capas:** en el panel **Layers**, el botón **`+`** agrega una **capa de
    pintura (Paint Layer)** nueva. Cada capa es una hoja transparente apilada.
    **Doble clic en el nombre** para renombrarla (`boceto`, `colores`…). El
    **ojito** la muestra u oculta; el **deslizador de opacidad** la hace más
    o menos transparente. Podés **arrastrar** capas para reordenarlas y borrar
    una con el **tachito**.
11. **Regla de oro de capas:** una capa para **cada cosa** (boceto, color,
    contorno). Si todo está en una sola, no se puede corregir.

> **Si no te sale (pincel y capas)**
> 1. *Dibujo y no pasa nada:* ¿hay una capa seleccionada y visible? ¿el
>    pincel está en **opacidad 100 %** y el color no es blanco sobre blanco?
> 2. *El trazo sale muy tembloroso:* en la barra de herramientas hay un ajuste
>    de **estabilizador (Stabilizer)** de la herramienta (en **Tool Options**);
>    subilo un poco.
> 3. *Borré sin querer:* `Ctrl + Z`, y mirá si quedó activado el modo borrador
>    (`E` lo alterna).

---

## Parte C — Los colores: elegir uno exacto

12. **Color de frente (Foreground):** el cuadro de color grande de la barra de
    herramientas / del panel del selector. Hacé clic en él: se abre **Select a
    Color (Seleccionar un color)**.
13. **Escribir un color exacto:** en esa ventana buscá el campo **Hex** (o el
    campo de texto de código con `#`) y escribí **`c98f5a`** (el de `wood`) +
    `Enter`. **Deberías ver** un marrón cálido. *(Si no lo ves, los campos
    pueden estar en una pestaña «HSV/RGB»: probá las pestañas; a confirmar en tu
    versión.)*
14. **Tomar un color de lo que ya pintaste:** mantené `Ctrl` y hacé clic sobre
    el lienzo: el color de frente pasa a ser ese. (Es el «gotero» temporal.)
15. **Selector avanzado:** el panel **Advanced Color Selector** tiene un
    cuadro/anillo de matices y una barra de luminosidad; pasá el mouse y clic
    para elegir.
16. **Atajo útil:** **clic derecho sobre el lienzo** abre una ruedita
    flotante («pop-up palette») con colores y presets, para elegir sin ir al
    panel (a confirmar en tu versión).

---

## Parte D — Cargar la paleta del juego en Krita

El juego guarda sus colores en **`data/palette.json`**, dentro del campo
`materials`. Krita no lee ese JSON, pero acá se incluye
**[`paleta_neighborhood.gpl`](paleta_neighborhood.gpl)** (una **paleta GIMP**,
formato que Krita entiende) con **todos los colores actuales**, con su nombre
(`wood`, `cloth_red`…).

> **Importante:** esa paleta es una **copia**. La verdad está en
> `data/palette.json`. Si cambiás un color en el JSON, hay que regenerar la
> `.gpl` (pedíselo al asesor) o editarla a mano.

17. **Abrí el gestor de recursos:** **Settings > Manage Resources...
    (Preferencias > Gestionar recursos...)**. Se abre una ventana.
18. Clic en **Import Resources (Importar recursos)** (nombre a confirmar) y
    elegí el archivo `docs/arte/paleta_neighborhood.gpl` de la carpeta del
    proyecto. **Deberías ver** que Krita avisa que importó. *(Alternativa: clic
    en **Open Resource Folder (Abrir carpeta de recursos)**, entrá a la
    subcarpeta `palettes` y copiá ahí el archivo `.gpl`; reiniciá Krita.)*
19. **Abrí el panel de paleta:** **Settings > Dockers > Palette (Paleta)**.
    En su selector (arriba del panel) elegí **«Neighborhood (data/palette.json)»**.
    **Deberías ver** 26 cuadraditos de colores.
20. **Usar un color:** clic en un cuadradito → pasa a ser el color de frente.
    Pasá el mouse para ver el **nombre** del material (por ejemplo
    `cloth_red`). Con él pintá un rectángulo en tu lienzo.

### Agregar un color nuevo a la paleta del juego (el camino correcto)

1. En Krita, probá el color (parte E).
2. Cuando te guste, anotá su **código hexadecimal** (ej. `#ff9d4d`) y un
   **nombre** en inglés, minúsculas, con guion bajo (ej. `cloth_orange`).
3. Agregalo al final de `materials` en `data/palette.json`:
   ```json
   "cloth_orange": "#ff9d4d",
   ```
   (cuidado con las comas: todas las líneas llevan coma **menos la última**).
4. En Blender, nombrá el material **exactamente igual** (`cloth_orange`). El
   juego lo pinta con ese color. No hace falta tocar código.

### Reglas de color del estilo del juego (de `docs/estilo.md`)

- Colores **alegres, saturación media-alta**; nada casi negro ni casi blanco
  puro (el **contorno oscuro** da el contraste).
- Colores **planos**: sin degradés, sin sombras pintadas.
- Los **tonos de sombra** los pone el juego: 3 tonos, con valores 0,5 (sombra),
  0,78 (medio) y 1,0 (luz) (`lighting.toon.tones` en la paleta). El color
  que elegís es el de la **parte iluminada**; las partes en sombra salen más
  oscuras solas.

---

## Parte E — Probar combinaciones de colores

21. **Documento nuevo** (`Ctrl + N`): `1600 × 1000`, nombre `prueba_colores`.
22. **Un cuarto de muestra:** en una capa nueva (`+`), pintá con rectángulos
    de colores de la paleta: pared (`paint_white`), piso (`wood_light`), cama
    (`cloth_blue` y `cloth_white`), una planta (`leaf` y `soil`)…
    **Cómo hacer un rectángulo parejo:** herramienta **Rectangle Selection
    (Selección rectangular)** de la caja de herramientas, arrastrá sobre el
    lienzo y luego **Edit > Fill with Foreground Color (Editar > Rellenar con
    el color de frente)** (el atajo aparece al lado del nombre en el menú).
    Con **Select > Deselect (Seleccionar > Quitar selección)** (`Ctrl + Shift +
    A`) soltás la selección.
23. **Probar los 3 tonos de sombra:** creá una capa nueva sobre la de colores,
    ponele el modo de fusión **Multiply (Multiplicar)** (en el panel Layers,
    desplegable de modo que dice «Normal») y pintá en ella, con **grises**:
    `#808080` donde quieras la sombra fuerte (≈ 0,5), `#c7c7c7` en el tono
    medio (≈ 0,78) y dejá sin pintar lo iluminado (1,0). **Deberías ver** el
    cuarto con aspecto de «dibujo animado», más parecido al juego.
    *(Es una aproximación: el juego calcula la luz en otro espacio de color.)*
24. **Capa de contorno:** otra capa arriba, con un pincel **duro** y color
    `#2b2233` (parecido al contorno), y repasá los bordes con línea fina.
25. **Comprobá el contraste en blanco y negro:** **Filter > Adjust > Desaturate
    (Filtro > Ajustar > Desaturar)** (a confirmar el nombre) sobre una copia:
    si dos cosas importantes quedan del mismo gris, cuesta distinguirlas en el
    teléfono. Cambiá su luminosidad.
26. **Guardá** (`Ctrl + S`) y **exportá una imagen** (`Ctrl + Shift + E`,
    **File > Export**) a PNG para mostrársela al asesor.

> **Si no te sale (colores)**
> 1. *El color de la pantalla no coincide con el del juego:* es normal una
>    diferencia pequeña (cada pantalla muestra distinto). Lo que manda es el
>    **código hexadecimal** (`#c98f5a`), no cómo se ve en Krita.
> 2. *No encuentro la paleta cargada:* revisá el selector del panel
>    **Palette** (arriba), puede estar mostrando otra.
> 3. *El relleno «sangra» fuera de la figura:* la selección no era cerrada; con
>    la selección rectangular no pasa. Con el **balde (Fill Tool)** subí el
>    **Threshold (Umbral)** o cerrá los huecos.

---

## Parte F — Bocetos de referencia (mueble y personaje)

Los bocetos sirven para dos cosas: (1) **modelar mirando un dibujo** en
Blender; (2) darle a una IA una **imagen de referencia tuya**, como pide
`docs/estilo.md` (sección 7). **Nunca uses ni imites diseños de otros
juegos o series.**

27. **Documento nuevo** `1600 × 1000`, nombre `boceto_cama`.
28. **Guías de medida:** **View > Show Grid (Vista > Mostrar cuadrícula)** (nombre
    a confirmar). Para que el cálculo sea fácil: **100 píxeles = 25 cm** (400 px
    = 1 metro). Una cama de 0,92 × 1,92 m mide ≈ 370 × 770 px.
29. **Tres vistas en capas separadas:** `frente`, `lado`, `arriba`, alineadas
    (el alto en «frente» y «lado» coincide; el ancho en «frente» y «arriba»
    coincide). Es lo que Blender necesita.
30. **Dibujá formas simples y redondeadas:** pocas curvas, nada de detalles
    que no se puedan modelar con cubos y bisel.
31. **Anotá los materiales** al lado, con los nombres de la paleta:
    «patas: `wood`», «colchón: `cloth_blue`». Es lo mismo que le vas a pedir
    a la IA o a vos mismo en Blender.
32. **Para usarlo en Blender** (guía 01–02): exportá cada vista a PNG
    (`File > Export`) y, en Blender, vista frontal (`Numpad 1`), **Add > Image
    > Reference (Añadir > Imagen > Referencia)** y elegí el PNG (a confirmar el
    menú en tu versión). Se ve de fondo, sin entrar en el juego; no exportes
    la imagen al `.glb` (no se exporta si es referencia).
33. **Para pedírselo a una IA** (solo con tu imagen como base; reglas en
    `docs/estilo.md` §7): objeto aislado, vista 3/4, fondo liso, formas
    redondeadas, colores planos sin texturas ni sombras pintadas, con los
    nombres de material de la paleta. Lo que salga se limpia en Blender.

### Boceto de un personaje chibi (solo referencia)

Mirá las proporciones de `docs/estilo.md` §5: alto total ≈ 1,35 m, cabeza ≈
45 % del alto, ojos grandes y bajos, manos y pies redondeados. Dibujá **de frente
y de lado, con los brazos separados del cuerpo** (la «pose en A» o «pose en T»
sirve después para ponerle el esqueleto, ver guía 07).

---

## Parte G — Texturas: por ahora no

El estilo del juego usa **colores planos con nombre** (un material por color)
y **no usa texturas** (`docs/estilo.md` §8, «Colores planos»). Está anotado
como pendiente (§12: «Texturas pintadas a mano (Krita) y su resolución
máxima»). **No pintes texturas por ahora.** Cuando se decida:

- Pintar en Krita un PNG chico (por ejemplo **256 × 256**) y un modelo con
  **UV** (en Blender, espacio de trabajo **UV Editing**, `U` en Modo Edición >
  **Smart UV Project**, a confirmar).
- Probar en el teléfono el costo en FPS **antes** de seguir.

Si te entusiasma, hablalo primero con el asesor: cambia las reglas de arte.

---

## Ejercicios para practicar

1. Pintá los **26 colores** de la paleta en cuadros de una hoja, con su nombre
   al lado. Mirá cuáles se parecen demasiado entre sí.
2. Armá tres versiones del mismo cuarto con tres paletas distintas (cálida,
   fría, pastel) y mostrale las tres al asesor.
3. Dibujá **la mesa de la guía 03** de frente y de arriba, y modelála
   mirando tu boceto.
4. Probá `E` (borrador), `Ctrl + Z` y las capas con un dibujo libre de 10
   minutos para soltar la mano.
5. Proponé **tres colores nuevos** para la paleta (con nombre y código) y
   pasáselos al asesor.

## Glosario

- **Lienzo (canvas):** la hoja donde dibujás.
- **Capa:** hoja transparente apilada; permite corregir sin romper el resto.
- **Dockers (paneles):** ventanitas acoplables (capas, color, paleta…).
- **Paleta:** lista de colores guardados con nombre.
- **Hex / hexadecimal:** código de color tipo `#c98f5a` (rojo-verde-azul).
- **Preset de pincel:** pincel prearmado con su forma y comportamiento.
- **Multiply (Multiplicar):** modo que oscurece lo de abajo; sirve para sombras.
- **`.kra`:** formato propio de Krita (conserva capas). No lo lee el juego.
- **Pose en A / en T:** pose con los brazos separados, ideal para modelar y
  ponerle esqueleto.
- **UV:** «desplegado» de un modelo 3D en 2D para poder pintarle una imagen
  (textura).

Siguiente: [05 — Íconos en SVG](05-iconos-svg.md).
