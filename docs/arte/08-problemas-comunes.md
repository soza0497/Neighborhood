# Guía 08 — Problemas comunes y hoja de atajos

**Objetivo:** que cuando algo salga raro sepas **qué mirar primero** y cómo
arreglarlo, y tener los atajos principales de Blender y de Krita en una hoja.

**Cómo usarla:** buscá tu síntoma en la tabla, probá la causa más probable y
repetí la exportación. Si después de eso sigue mal, pasale al asesor el
**texto exacto del error** o una captura.

> Lo marcado «(a confirmar en tu versión)» no se pudo verificar para Blender
> 5.2 / Krita 6.

---

## Primero: cómo «se queja» el juego

El juego **nunca se rompe por un `.glb` malo**: si el archivo falta, está roto,
no tiene ninguna malla o «Usar modelos 3D» está apagado, **usa la figura simple
de siempre**. Eso significa que el síntoma más común de un `.glb` que el juego
rechaza es **que no ves ningún cambio**.

Mensajes que el asesor puede ver al revisar con
`ModelLoader.inspect("res://assets/models/<archivo>.glb")`:

| Mensaje | Qué significa |
| --- | --- |
| `no existe: …` | La ruta del catálogo no coincide con el archivo (nombre, mayúsculas, carpeta) |
| `no se pudo leer como modelo 3D: …` | El archivo no es un `.glb` válido (por ejemplo, se exportó otro formato) |
| `archivo roto (error N): …` | El `.glb` está dañado o incompleto |
| `no tiene ninguna malla: …` | Se exportó sin mallas (nada seleccionado, o solo cámara y luz) |
| aviso «el pivote no está en la base…» | El piso del modelo no está en z = 0 |
| aviso «el pivote no está en el centro de la base…» | El modelo está corrido del centro (más de 10 cm) |
| aviso «es enorme (… m)…» | Probablemente exportaste en centímetros: 1 celda = 1 m |
| aviso «el material … no está en data/palette.json» | El nombre del material no es de la paleta: se usa su color original |
| aviso «hay un material sin nombre…» | Un material sin nombre: no se pinta desde la paleta |

> **Truco importante:** si el juego ya probó un archivo y falló, **recuerda el
> fallo** hasta que **cerrés y volvás a abrir el juego**. Si arreglás el `.glb`
> y no cambia nada, reiniciá el juego antes de dudar.

---

## Tabla de problemas

### Tamaño y posición

| Síntoma | Causa más probable | Arreglo |
| --- | --- | --- |
| **Gigante** o **diminuto** | La escala no estaba aplicada, o trabajaste en otras unidades (cm, mm) | En Blender: **Scene > Units**: Metric, **Unit Scale 1.0**; seleccioná todo, `Ctrl + A` > **All Transforms**; revisá **Dimensions** (`N`); reexportá |
| **Más chico de lo que lo hiciste** | Se pasó más de un 5 % de la caja del catálogo (huella × alto) y el juego lo achicó | Rehacelo dentro de la caja (guía 03, checklist) |
| **Flota** o **hundido** en el piso | El origen no está en la base | Guía 02, Parte H: `Shift + C` + **Set Origin > Origin to 3D Cursor** (o base al piso con `Alt + G`); el punto más bajo en z = 0 |
| **Corrido** (no queda en el centro de la celda) | El conjunto no está centrado en el origen del mundo | Centrá las piezas alrededor de (0, 0), o ajustá con `model_offset` en el catálogo |
| **Mira para atrás** | El frente no estaba hacia −Y en Blender | Giralo 180° sobre Z (`R` `Z` `180`), `Ctrl + A` > Rotation, reexportá; o probá `model_rotation: 180` en el catálogo mientras |
| **Gira raro** al rotarlo en el juego | El origen no está en el centro de la base | Ídem pivote |

### Colores y materiales

| Síntoma | Causa más probable | Arreglo |
| --- | --- | --- |
| **Todo negro** | Normales al revés; o el visor en Solid sin color | **Overlays > Face Orientation**: tiene que ser azul. Rojo: Modo Edición, `A`, **Mesh > Normals > Recalculate Outside** (`Shift + N`) |
| **Todo blanco/gris** | Sin materiales, o materiales sin nombre | Asigná un material con nombre de paleta a cada parte |
| **Color distinto del que puse en Blender** | **Es lo normal**: el juego pinta por **nombre de material** con `data/palette.json` | Cambiá el color en el JSON, o el nombre del material |
| **Color raro/sin pintar** | El nombre del material no está en la paleta (error de tipeo, mayúsculas, espacio) | Renombrá exacto (`cloth_red`) o agregá el nombre nuevo a `data/palette.json` |
| **`wood.001`, `wood.002`** | Blender agrega números al duplicar | No molesta (el juego los ignora), pero mejor reusar el mismo material |
| **Sin materiales** (todo igual) | No se exportaron materiales | En la exportación: **Materials: Export** |
| **Se ven texturas o cuadritos** | Usaste una imagen en el material | Sacá los nodos de imagen: solo **Base Color** plano |
| **Parpadea** (dos colores peleando) | Dos caras en el mismo plano (z-fighting) | Metelas una dentro de la otra, o separalas 1 mm |

### Forma

| Síntoma | Causa más probable | Arreglo |
| --- | --- | --- |
| **Agujeros** o caras que faltan | Normales invertidas o cara borrada | Face Orientation (rojo) y recalcular; revisá en Modo Edición |
| **Se ve «arrugado»** | Suavizado mal | **Shade Auto Smooth** (a confirmar) con ángulo 60°, o **Shade Smooth** |
| **Esquinas duras** | Faltó el bisel, o se «aplicó» sin quererlo | Agregá **Bevel** (último modificador) |
| **Faltan las patas** (o piezas hechas con Mirror/Array) | Exportaste sin **Apply Modifiers** | Marcá **Apply Modifiers** al exportar |
| **Sale solo una parte del mueble** | No seleccionaste todas las piezas | Clic derecho en la colección > **Select Objects**, exportar con **Selected Objects** |
| **Sale con cámara y luz** | No limitaste la exportación | **Selected Objects** marcado; sin cámaras ni luces |

### El archivo que «el juego rechaza» (no se ve nada nuevo)

| Síntoma | Causa más probable | Arreglo |
| --- | --- | --- |
| Sigo viendo la **caja simple** | «Usar modelos 3D (arte)» apagado | **Menú → Info → «Usar modelos 3D (arte)»** |
| Idem | El nombre/ruta del catálogo no coincide letra por letra con el archivo | Revisá `res://assets/models/xxx.glb` contra la carpeta (minúsculas, guion bajo) |
| Idem | Godot no terminó de **importar** el archivo | Abrí el proyecto en Godot y esperá a que se complete (barra de abajo a la derecha) |
| Idem | El juego ya había fallado con ese archivo | **Cerrá y reabrí el juego** |
| Idem | Archivo de otro formato (`.gltf`, `.blend`) | Exportá como **glTF Binary (.glb)** |
| El juego no abre / texto rojo en Godot | **JSON mal** en `data/catalog.json` (coma o comilla) | `python3 -m json.tool data/catalog.json > /dev/null` te dice la línea; corregí |
| El archivo se exportó pero pesa 0 KB o casi | Nada seleccionado, o falló la exportación | Reexportá con las piezas seleccionadas |
| No encuentro la carpeta del proyecto al exportar (Flatpak) | Flatpak no ve tus carpetas | Usá la versión de pacman o pedile al asesor el permiso; o exportá a otra carpeta y copiá el archivo |

### Rendimiento

| Síntoma | Causa más probable | Arreglo |
| --- | --- | --- |
| **Menos de 30 FPS** en el teléfono | Demasiados triángulos, contorno costoso, muchas piezas | Medí con la tabla de la guía 06; bajá segmentos de bisel, vértices de cilindros y detalles; avisá al asesor |
| Blender va lento | Demasiados cortes/subdivisión, o gráfica integrada | Trabajá con **Segments** bajos y apagá lo que no necesitás |

### Blender y Krita en sí

| Síntoma | Causa más probable | Arreglo |
| --- | --- | --- |
| Un atajo no hace nada | El mouse no está sobre el editor correcto | Pasá el mouse sobre el **visor 3D** (Blender) o el **lienzo** (Krita) |
| Los números `1 2 3` no eligen vértice/arista/cara | Activaste **Emulate Numpad** | Usá los botones de la cabecera, o desactivá esa preferencia |
| Se cerró Blender sin guardar | — | **File > Recover > Auto Save** (a confirmar); mirá también el archivo `.blend1` |
| Cambié el idioma y no entiendo nada | — | **Edit > Preferences > Interface > Translation > Language > English** |
| Krita: «el pincel no pinta» | Capa oculta/bloqueada o color igual al fondo | Revisá el ojito y el candado de la capa |
| Inkscape: no veo el trazo blanco | Fondo blanco | Poné el fondo oscuro en Document Properties |

---

## Hoja de atajos de Blender (una página)

*Con el mouse sobre el visor 3D, teclado normal y mouse de 3 botones.
`MMB` = rueda apretada. Con touchpad: Preferencias > Input > Emulate 3 Button
Mouse (entonces `Alt + LMB` = MMB).*

| Acción | Atajo | Notas |
| --- | --- | --- |
| Orbitar / Panear / Zoom | `MMB` / `Shift + MMB` / rueda | |
| Vista frontal / derecha / arriba | `Numpad 1` / `3` / `7` | con `Ctrl`: opuesta |
| Perspectiva ↔ ortográfica | `Numpad 5` | |
| Encuadrar selección / todo | `Numpad .` / `Home` | |
| Seleccionar / sumar | `LMB` / `Shift + LMB` | |
| Todo / nada / invertir | `A` / `Alt + A` / `Ctrl + I` | |
| Mover / Rotar / Escalar | `G` / `R` / `S` | + eje `X` `Y` `Z` + número + `Enter` |
| Agregar objeto | `Shift + A` | |
| Duplicar | `Shift + D` | |
| Borrar | `X` o `Delete` | |
| Renombrar | `F2` | |
| Unir objetos | `Ctrl + J` | |
| Mover a colección | `M` | |
| Modo Objeto ↔ Edición | `Tab` | |
| Extruir / Inset | `E` / `I` | Modo Edición |
| Loop cut | `Ctrl + R` | Modo Edición; rueda = cantidad de cortes |
| Bisel de aristas | `Ctrl + B` | Modo Edición (a confirmar uso) |
| Recalcular normales | `Shift + N` | Modo Edición |
| Aplicar transformaciones | `Ctrl + A` | **Scale** / **All Transforms** |
| Limpiar posición / rotación / escala | `Alt + G` / `Alt + R` / `Alt + S` | |
| Cursor 3D al origen y encuadrar | `Shift + C` | |
| Menú de cursor / selección | `Shift + S` | |
| Barra lateral / herramientas | `N` / `T` | |
| Agrandar área | `Ctrl + Space` | |
| Deshacer / rehacer | `Ctrl + Z` / `Ctrl + Shift + Z` | |
| Guardar / guardar como | `Ctrl + S` / `Ctrl + Shift + S` | |
| Abrir / salir | `Ctrl + O` / `Ctrl + Q` | |
| Reproducir animación | `Space` | |
| Insertar fotograma clave | `I` | (a confirmar en tu versión) |

## Hoja de atajos de Krita (una página)

*Los de Krita 5; a confirmar en tu versión (Krita 6).*

| Acción | Atajo |
| --- | --- |
| Nuevo / abrir / guardar | `Ctrl + N` / `Ctrl + O` / `Ctrl + S` |
| Exportar | `Ctrl + Shift + E` |
| Deshacer / rehacer | `Ctrl + Z` / `Ctrl + Shift + Z` |
| Pincel / borrador (alternar) | `B` / `E` |
| Tamaño del pincel | `[` y `]` |
| Tomar color del lienzo | `Ctrl + clic` |
| Desplazar el lienzo | `Space` + arrastrar |
| Zoom | rueda del mouse |
| Girar el lienzo | `Shift + Space` + arrastrar |
| Quitar selección | `Ctrl + Shift + A` |
| Menú flotante de colores y pinceles | clic derecho en el lienzo |

## Atajos de Inkscape para los íconos

| Acción | Atajo |
| --- | --- |
| Selector / Pluma / Rectángulo / Elipse | `S` / `B` / `R` / `E` |
| Zoom a la página | `5` |
| Cuadrícula / imán | `#` / `%` |
| Relleno y borde | `Ctrl + Shift + F` |
| Propiedades del documento | `Ctrl + Shift + D` |
| Objeto a trayecto | `Shift + Ctrl + C` |
| Guardar copia (para el juego) | `Shift + Ctrl + Alt + S` |

---

## Ejercicios para practicar

1. **Rompé a propósito** una silla (escala 100, origen arriba, material
   `Material`) y mirá qué avisa `ModelLoader.inspect`; después arreglala con esta
   guía.
2. Hacé un `.glb` con el nombre equivocado en el catálogo y comprobá que el
   juego usa la figura simple.
3. Armá tu **propia lista de revisión** de 10 puntos, mezclando esta guía y el
   checklist de la guía 03, y pegala al lado del monitor.

## Glosario

- **Z-fighting:** parpadeo de dos caras que ocupan el mismo plano.
- **Normales:** hacia dónde «mira» cada cara; si miran al revés, se ve negro.
- **Face Orientation:** vista de Blender que pinta de azul las caras buenas y
  de rojo las que están al revés.
- **Pivote:** el origen del objeto.
- **Importar (Godot):** convertir el `.glb` a un recurso interno la primera
  vez que abrís el proyecto.
- **Figura simple:** el cubo/cápsula provisional que el juego usa cuando no
  hay modelo.

Volver al [mapa](00-mapa.md).
