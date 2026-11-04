# Guía 01 — Instalar Blender y primer vistazo

**Objetivo:** tener Blender instalado y configurado en tu PC con CachyOS, y
saber lo mínimo para no perderte: moverte en 3D, seleccionar, mover, rotar,
escalar, deshacer y guardar.

**Resultado final:** un archivo `practica.blend` guardado, con un cubo que
movés, girás y escalás a voluntad, y la certeza de que podés volver atrás.

**Tiempo estimado:** 2 a 3 horas (la instalación son 10 minutos; el resto es
practicar).

> Recordatorio: lo marcado «(a confirmar en tu versión)» no se pudo verificar
> para Blender 5.2. Si tu pantalla dice otra cosa, creele a tu pantalla.
> Manual oficial: <https://docs.blender.org/manual/en/5.2/>

---

## Parte A — Instalar Blender

El orden de instalación de esta PC es: **primero pacman**, **después Flathub**
(nunca descargar scripts ni usar `curl | bash`).

### Antes de empezar: avisale al asesor

Instalar con pacman necesita **permisos de administrador**. En esta PC eso se
pide con **`pkexec`** (nunca con `sudo`). Aparece una ventanita pidiendo tu
contraseña. Además, **todo lo que se instala en el sistema se anota en la
bitácora** (`~/intranet/bitacora/`), y eso lo hace el asesor. Entonces:

> **Antes de instalar, avisale al asesor:** «Voy a instalar el paquete
> `blender` con pacman (versión 5.2.x)». Y **después de instalar**, pasale la
> fecha y la versión que te muestra el paso 4.

### Opción 1 (la preferida): pacman

1. **Abrí la terminal** (en CachyOS es *fish*; los comandos de abajo
   funcionan tal cual).
2. **Mirá qué versión hay** (esto no pide permisos, solo consulta):
   ```bash
   pacman -Si blender
   ```
   Buscá la línea **Version** (**Versión**). Debería empezar con `5.2`. Si
   dice otra cosa, avisale al asesor antes de seguir.
3. **Instalá** (esto sí pide permisos; se abre una ventana para tu contraseña):
   ```bash
   pkexec pacman -S blender
   ```
   Te va a preguntar `Proceed with installation? [Y/n]` (¿Continuar?). Escribí
   `y` y Enter. Descarga unos cientos de MB; puede tardar unos minutos.
   > Si dice `failed retrieving file ... 404` (o parecido), la lista local de
   > paquetes está vieja. **No** pruebes otros comandos de pacman por tu
   > cuenta: avisale al asesor, que actualiza el sistema entero de forma segura.
4. **Comprobá la versión instalada:**
   ```bash
   blender --version
   ```
   **Deberías ver** algo como `Blender 5.2.3` y más líneas de información.
   Pasale esa línea al asesor para la bitácora.

### Opción 2 (si la 1 no te sirve): Flathub

Flathub es la tienda de aplicaciones Flatpak. Se usa **solo si pacman no
funciona** (por ejemplo, si el paquete tiene un problema).

1. Instalar para tu usuario (no pide administrador):
   ```bash
   flatpak install --user flathub org.blender.Blender
   ```
   Confirmá con `y`. *(Si usás la instalación del sistema —sin `--user`—, ahí
   sí pide permisos, y por eso se usa `pkexec`; avisale al asesor.)*
2. Para abrirlo:
   ```bash
   flatpak run org.blender.Blender
   ```
   **Ojo con Flatpak:** corre «encerrado» y **puede que no vea tus carpetas**
   (por ejemplo la carpeta del proyecto). Si al guardar o exportar no ves la
   carpeta `Neighborhood`, avisale al asesor para darle permiso de acceso
   (a confirmar en tu versión). Con pacman este problema no existe, por eso es
   la opción preferida.

> **Si no te sale (instalación)**
> 1. *«error: target not found: blender»*: el nombre está mal escrito o la
>    lista de paquetes no está al día → avisale al asesor.
> 2. *La ventana de contraseña no aparece*: abrí la terminal otra vez y repetí
>    el comando; si sigue igual, avisale al asesor (puede faltar el agente de
>    `pkexec` en tu sesión).
> 3. *`blender: command not found`* tras instalar: cerrá y abrí la terminal; si
>    persiste, reiniciá la sesión.

---

## Parte B — Abrir Blender y configurarlo

5. **Abrí Blender:** desde el menú de aplicaciones (categoría Gráficos) o
   escribiendo `blender` en la terminal.
   **Deberías ver:** una ventana con una pantalla de bienvenida (*splash*) y,
   al lado, un cuadro de configuración rápida («Quick Setup»).
6. **En el cuadro de bienvenida** (a confirmar en tu versión, es un cuadro con
   estas opciones o parecidas):
   - **Language (Idioma):** dejalo en **English**. *Razón:* esta guía, los
     manuales y casi todos los tutoriales usan los nombres en inglés. Más
     adelante, cuando ya te muevas con soltura, podés pasarlo a español (paso 9).
   - **Keymap:** *Blender* (la distribución por defecto).
   - **Select With (Seleccionar con):** **Left (Izquierdo)**. Así el clic
     izquierdo selecciona, como en casi todos los programas.
   - **Spacebar (Barra espaciadora):** **Play (Reproducir)**. Es lo normal.
   - Después clic en **Continue** (**Continuar**).
7. **Cerrá la pantalla de bienvenida** haciendo clic en una zona vacía fuera
   del cuadro. **Deberías ver** la pantalla de trabajo con un **cubo** gris en
   el centro, una **cámara** y una **luz** (esas dos aparecen como dibujitos
   de alambre).

### Preferencias importantes

8. **Abrí las preferencias:** menú **Edit > Preferences (Editar >
   Preferencias)**. Se abre una ventana nueva con una lista de secciones a la
   izquierda.
9. **Idioma** (opcional, mejor para más adelante): sección **Interface**
   (Interfaz) > panel **Translation** (Traducción) > **Language**. Para pasar
   a español elegí **Español (Spanish)**. Hay también casillas «Tooltips»
   (explicaciones al apoyar el mouse), «Interface» y «New Data» (nombres de
   objetos nuevos): para empezar conviene dejar activas solo **Tooltips**.
   *(Si te perdés con los nombres, esta guía muestra los dos idiomas.)*
10. **Emulación de mouse** (solo si no tenés mouse de tres botones, por
    ejemplo si usás **touchpad**): sección **Input** (Entrada) > panel
    **Mouse** (Ratón):
    - Activá **Emulate 3 Button Mouse (Emular ratón de 3 botones)**.
      Desde ahora `Alt + LMB` hace de botón del medio (MMB): `Alt + clic
      izquierdo y arrastrar` = **orbitar**.
    - **Efecto secundario conocido:** `Alt + clic` deja de servir para algunas
      funciones avanzadas. Para empezar no importa.
11. **Emular el teclado numérico** (si tu teclado **no tiene** teclado
    numérico, como en casi todas las notebooks): en esa misma sección
    **Input** > panel **Keyboard** (Teclado) activá **Emulate Numpad (Emular
    teclado numérico)**. Desde entonces las teclas `1`, `2`, `3`… de la fila
    de arriba hacen de `Numpad 1`, `Numpad 2`… (para las vistas, paso 25).
    *Desventaja:* los atajos de número normales (por ejemplo `1`, `2`, `3`
    para elegir vértice/arista/cara en modo edición) dejan de funcionar con
    esos números. Si tenés teclado numérico, **no lo actives**.
12. **Guardado automático:** sección **Save & Load** (Guardar y cargar) >
    panel **Auto Save** (Autoguardado): comprobá que esté **activado**
    (casilla marcada) y poné **Timer (Minutes)** (Temporizador (minutos)) en
    **2** (cada 2 minutos). *Autoguardado ≠ guardar:* sirve para rescatar tu
    trabajo si Blender se cierra de golpe, pero no reemplaza `Ctrl + S`. Los
    archivos de autoguardado se escriben en la carpeta temporal del sistema.
13. **Guardar las preferencias:** por defecto Blender las guarda solo al
    cerrar (casilla **Auto-Save Preferences**, abajo a la izquierda de la
    ventana de preferencias: dejala marcada). Cerrá la ventana de preferencias
    con la **X** de su esquina.

> **Si no te sale (configuración)**
> 1. *No encuentro «Emulate 3 Button Mouse»*: está en **Input**, no en
>    Interface. Usá la lupa de arriba (el buscador) y escribí «emulate».
> 2. *Cambié el idioma y no entiendo nada*: volvé a **Edit > Preferences >
>    Interface > Translation > Language** y elegí **English**.
> 3. *Después de emular el numpad no puedo elegir vértices con `1`*: es lo
>    esperado; usá los tres botoncitos de vértice, arista y cara que aparecen en la cabecera del visor cuando entrás en Modo Edición (guía 02).

---

## Parte C — La interfaz, pieza por pieza

Blender divide la pantalla en **áreas** (se llaman *Areas*) y cada área es un
**editor** (el 3D, la lista de objetos, las propiedades…). No hace falta
tocar los bordes todavía.

14. **Mirá arriba de todo: la barra superior (Topbar).** A la izquierda están
    los menús **File (Archivo)**, **Edit (Editar)**, **Render**, **Window
    (Ventana)**, **Help (Ayuda)**. Al centro, las **pestañas de espacios de
    trabajo** (*Workspaces*): **Layout**, **Modeling**, **Sculpting**, **UV
    Editing**, **Texture Paint**, **Shading**, **Animation**, **Rendering**,
    **Compositing**, **Geometry Nodes**, **Scripting**. Vas a trabajar casi
    siempre en **Layout**. (Las pestañas exactas pueden variar un poco en 5.2:
    a confirmar en tu versión.)
15. **El Visor 3D (3D Viewport)**, la zona grande del centro: es donde ves y
    tocás tu modelo. Arriba tiene su propia **cabecera** (*header*) con:
    - el **selector de modo**: dice **Object Mode (Modo Objeto)**; ahí también
      se elige **Edit Mode (Modo Edición)**;
    - los menús **View (Vista)**, **Select (Seleccionar)**, **Add (Añadir)**,
      **Object (Objeto)**;
    - a la derecha, los botones de **Overlays** (superposiciones) y de
      **Shading** (sombreado: las cuatro bolitas).
16. **La barra de herramientas (Toolbar)**, columna de iconos **a la
    izquierda** del visor 3D. Se muestra u oculta con `T`. La herramienta
    activa al empezar es **Select Box** (Seleccionar caja). Más abajo están
    **Move**, **Rotate**, **Scale** (Mover, Rotar, Escalar) y otras.
17. **La barra lateral (Sidebar)**, a la **derecha** dentro del visor 3D: se
    abre/cierra con `N`. Tiene pestañas verticales: **Item** (Elemento),
    **Tool** (Herramienta), **View** (Vista). En **Item > Transform** vas a
    leer y escribir **Location (Ubicación)**, **Rotation (Rotación)**,
    **Scale (Escala)** y **Dimensions (Dimensiones)** del objeto elegido.
    **Es la parte más importante para modelar con medidas.**
18. **El Outliner (Esquema)**, arriba a la derecha: la lista de todo lo que
    hay en la escena (Collection > Camera, Cube, Light). Sirve para elegir
    objetos por nombre, esconderlos (ojito) y ordenarlos en colecciones.
19. **El editor de Propiedades (Properties)**, abajo a la derecha: una columna
    de **pestañas con iconos** (Tool, Render, Output, View Layer, Scene,
    World, Object, **Modifiers**, Particles, Physics, Constraints, **Data**,
    **Material**…). Cambian según lo que tengas seleccionado. Las que más vas
    a usar: **Object** (naranja), **Modifiers** (llave inglesa azul) y
    **Material** (esfera con cuadros).
20. **La línea de tiempo (Timeline)**, abajo del todo: es para animación;
    ignorala por ahora. Y **la barra de estado (Status Bar)**, el renglón
    final: muestra ayudas de teclas y, con clic derecho, se puede activar
    **Scene Statistics (Estadísticas de escena)** (a confirmar en tu versión).
21. **Agrandar un área un momento:** pasá el mouse sobre el visor 3D y
    apretá `Ctrl + Space`. Vuelve igual con la misma combinación.

> **Si no te sale (interfaz)**
> 1. *Se me perdió una barra o un panel:* menú **Window > Workspaces / ...** o
>    `N` (barra lateral) y `T` (herramientas) para mostrarlas.
> 2. *Rompí el diseño de la pantalla:* **File > New > General** (Archivo >
>    Nuevo > General) lo deja como al inicio (pide guardar antes).
> 3. *Las pestañas de Propiedades están cortadas:* pasá el mouse encima y
>    girá la rueda: se desplazan.

---

## Parte D — Moverte en el espacio 3D

Mouse de tres botones: **MMB** es apretar la rueda sin girarla.
Con **touchpad**: activá **Emulate 3 Button Mouse** (paso 10) y usá `Alt`.

22. **Orbitar (girar la vista alrededor):** mantené apretado **MMB** y mové el
    mouse. *Touchpad:* `Alt + LMB` y arrastrar. *También:* arrastrá con el
    clic izquierdo sobre el **gizmo de ejes** (la bolita de colores con X, Y,
    Z, arriba a la derecha del visor). **Deberías ver** el cubo girar.
23. **Acercar / alejar (zoom):** girá la **rueda** del mouse. *Touchpad:* dos
    dedos en pellizco, o `Ctrl + Alt + LMB` y arrastrar (con la emulación
    activa), o el botón de **lupa** del gizmo (arrastrándolo).
24. **Desplazar la vista (pan):** `Shift + MMB` y mover. *Touchpad:* `Shift +
    Alt + LMB`. También con el botón de **manito** del gizmo (arrastrándolo).
25. **Vistas rápidas** (con teclado numérico; sin él, activá *Emulate
    Numpad*): `Numpad 1` = vista **frontal**; `Numpad 3` = vista **derecha**;
    `Numpad 7` = vista **desde arriba**; `Ctrl + Numpad 1/3/7` = la vista
    opuesta (trasera/izquierda/desde abajo). Sin numpad ni emulación:
    **View > Viewpoint (Vista > Punto de vista)** o clic en las bolas **X,
    Y, Z** del gizmo.
26. **Perspectiva / Ortográfica:** `Numpad 5` alterna. *Perspectiva* se ve
    «natural» (lo lejano se achica); *Ortográfica* no deforma, ideal para
    medir y alinear. **Cuando modelás con medidas, usá ortográfica.**
27. **Encuadrar lo que elegiste:** `Numpad .` (punto del numpad) acerca la
    vista al objeto seleccionado (**View > Frame Selected**). `Home` encuadra
    **todo** (View > Frame All). Si te perdiste: `Home`.
28. **Practicá 5 minutos:** orbitá, acercá, paneá, pasá por las vistas 1, 3 y
    7 y volvé con `Home`.

> **Si no te sale (moverte)**
> 1. *El mouse no gira nada:* ¿la rueda se aprieta? Si no, emulación del paso
>    10. ¿Estás con el cursor **sobre el visor 3D**? Los atajos valen donde
>    está el mouse.
> 2. *Me alejé tanto que no veo nada:* `Home`.
> 3. *Las teclas del numpad no hacen nada:* ¿`Bloq Num` está encendido? Si no
>    tenés numpad, activá *Emulate Numpad* (paso 11).

---

## Parte E — Seleccionar, mover, rotar, escalar

La regla de oro: **Blender actúa sobre lo seleccionado, y el mouse tiene que
estar sobre el visor 3D.**

29. **Seleccionar:** clic izquierdo (`LMB`) sobre el cubo. **Deberías ver** un
    **contorno naranja** (seleccionado y activo: más claro). Desde el Outliner
    también se puede (clic en el nombre).
30. **Seleccionar varios:** `Shift + LMB` agrega (o quita) objetos. `A`
    selecciona **todo**; `Alt + A` **deselecciona todo**. Con la herramienta
    **Select Box** (la activa) arrastrar en zona vacía dibuja una caja de
    selección.
31. **Mover:** con el cubo elegido apretá **`G`** (de *Grab*, agarrar), movés
    el mouse, y **clic izquierdo para confirmar** o **`Esc` / clic derecho
    para cancelar**. **Mover solo en un eje:** después de `G` apretá `X`, `Y`
    o `Z` (por ejemplo `G` `Z` sube y baja). **Con número exacto:** `G`, `Z`,
    escribí `0.5`, `Enter` → sube exactamente 0,5 m.
32. **Rotar:** **`R`** (de *Rotate*). Igual: eje opcional (`R` `Z`), número
    exacto en grados (`R` `Z` `90` `Enter`) y clic para confirmar.
33. **Escalar:** **`S`** (de *Scale*). Mover el mouse agranda o achica;
    `S` `Z` `2` `Enter` lo estira al doble solo en altura.
    > **Aviso:** escalar con `S` cambia la **escala** del objeto, que más
    > adelante hay que «aplicar» (guía 02, `Ctrl + A`). Para modelar con
    > medidas preferimos escribir el tamaño en **Dimensions** (paso 17).
34. **Los gizmos de mano** (alternativa visual): en la barra de herramientas
    elegí **Move / Rotate / Scale** y aparecen flechas, aros o cubitos sobre el
    objeto para arrastrar con el mouse. Volvé a **Select Box** cuando termines.
35. **Escribir valores en la barra lateral:** `N` > pestaña **Item** >
    **Transform**. Tocá un campo (por ejemplo **Location Z**) con doble clic,
    escribí el número y `Enter`. **Dimensions** (X, Y, Z) muestra el tamaño
    real **en metros**.
36. **Agregar un objeto:** **Add > Mesh > Cube (Añadir > Malla > Cubo)** o
    `Shift + A` con el mouse sobre el visor. Aparece en la posición del
    **cursor 3D** (la mirita rojiblanca). **Borrar el seleccionado:** `X` o
    `Delete` (a veces pide confirmar). **Duplicar:** `Shift + D`, luego
    mover y clic.
37. **Cursor 3D al centro:** `Shift + C` recentra el cursor 3D **y** encuadra
    todo. Los objetos nuevos aparecen donde está el cursor, así que si tus
    cubos salen «lejos», es por eso.

> **Si no te sale (mover/rotar/escalar)**
> 1. *`G` no hace nada:* ¿tenés algo seleccionado y el mouse sobre el visor
>    3D? Seleccioná con clic primero.
> 2. *Se mueve en direcciones raras:* limitá el eje con `X`, `Y` o `Z`; para
>    ver el eje en pantalla, mirá la línea de color que aparece.
> 3. *Cambié algo y no sé qué:* `Ctrl + Z` (paso 38).

---

## Parte F — Deshacer, guardar, salir

38. **Deshacer:** `Ctrl + Z`. **Rehacer:** `Ctrl + Shift + Z`. **Historial:**
    **Edit > Undo History (Editar > Historial de deshacer)** muestra la lista
    de pasos y te deja saltar a cualquiera.
39. **Guardar por primera vez:** `Ctrl + S`. Se abre el explorador de
    archivos de Blender. Elegí una carpeta (por ejemplo `~/arte/neighborhood/`,
    fuera del repositorio del juego si querés guardar tus `.blend` aparte;
    **conviene guardarlos en una carpeta tuya, no dentro de `assets/`**: los
    `.blend` son pesados y el juego solo lee `.glb`), escribí un nombre como
    `practica.blend` y apretá **Save As (Guardar como)** o `Enter`.
40. **Guardar de nuevo:** `Ctrl + S` otra vez; en adelante guarda sin
    preguntar. **Guardar una copia con otro nombre:** `Ctrl + Shift + S`.
    Blender, al guardar sobre un archivo existente, crea una copia de
    respaldo `practica.blend1` (versión anterior). Es normal; no la borres.
41. **Abrir un archivo:** `Ctrl + O`, o **File > Open Recent (Archivo > Abrir
    reciente)**. **Salir:** `Ctrl + Q`. Si olvidaste guardar, Blender
    pregunta.
42. **Recuperar el último autoguardado** si se cerró mal: **File > Recover >
    Auto Save... (Archivo > Recuperar > Autoguardado)** (a confirmar en tu
    versión).

> **Si no te sale (guardar)**
> 1. *No encuentro dónde se guardó:* **File > Open Recent** muestra la ruta al
>    pasar el mouse; o `Ctrl + O` y mirá la carpeta actual.
> 2. *Apreté `Ctrl + S` y no pasó nada:* el mouse tiene que estar sobre una
>    zona de Blender (no sobre otra ventana).
> 3. *Se me cerró Blender sin guardar:* **File > Recover > Auto Save**.

---

## Ejercicios para practicar

1. Agregá tres cubos con `Shift + A` y ponelos en fila usando `G` + eje + número
   (por ejemplo 3 m entre uno y otro).
2. Rotá uno 45° (`R` `Z` `45` `Enter`) y escalá otro al doble en una sola
   dirección (`S` `X` `2` `Enter`).
3. Mirá la escena desde la vista frontal, derecha y de arriba (con numpad o
   gizmo) y volvé con `Home`.
4. Hacé un destrozo a propósito y volvé al estado inicial con `Ctrl + Z` y con
   **Edit > Undo History**.
5. Guardá como `practica.blend`, cerrá Blender, abrilo desde **File > Open
   Recent** y comprobá que todo siga igual.

## Glosario

- **Visor 3D (3D Viewport):** la ventana donde ves el modelo.
- **Outliner (Esquema):** lista de objetos de la escena.
- **Propiedades (Properties):** panel con pestañas de ajustes del objeto
  elegido.
- **Barra lateral (Sidebar, `N`):** panel plegable con medidas exactas.
- **Gizmo:** ayuda visual con la que se arrastra con el mouse (ejes, flechas).
- **Orbitar / Panear / Zoom:** girar, desplazar y acercar la vista.
- **Objeto:** una cosa de la escena (cubo, cámara, luz).
- **Modo Objeto / Modo Edición:** en Objeto movés piezas enteras; en Edición
  tocás sus vértices, aristas y caras.
- **Cursor 3D:** punto de referencia donde nacen los objetos nuevos.
- **Perspectiva / Ortográfica:** vista con profundidad / vista plana sin
  deformación.

Siguiente: [02 — Primera silla](02-primera-silla.md).
