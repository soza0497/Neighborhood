# Guías de arte — el mapa

> **Estado de estas guías:** escritas sin tener Blender ni Krita instalados y
> **sin poder abrir los manuales oficiales** desde la sesión donde se
> escribieron (solo se pudieron ver fragmentos de búsqueda). Lo que no se pudo
> confirmar para Blender 5.2 / Krita 6 está marcado con
> **«(a confirmar en tu versión)»**. Si algo no coincide con lo que ves en
> pantalla, **creele a tu pantalla**, anotá la diferencia y pasásela al asesor
> para corregir la guía.

## ¿Para qué sirven estas guías?

Vos vas a hacer el arte del juego (muebles, un cuarto, más adelante el
personaje y los íconos) y nunca usaste Blender ni Krita. Estas guías te llevan
de la mano, desde instalar el programa hasta **ver tu mueble dentro del juego**.
No hace falta saber nada de antemano. Cada paso es **una sola acción** (un clic
o una tecla) y te dice qué deberías ver después.

## El orden para aprender

```
01 Instalar y primer vistazo   ──►  02 Primera silla  ──►  03 Mueble con partes
        (Blender)                      (Blender → juego)        (Blender)
                                                                    │
  04 Krita: colores y paleta  ─────(en paralelo, cuando quieras)────┤
  05 Íconos SVG               ─────(en paralelo, cuando quieras)────┤
                                                                    ▼
                              06 Cuarto de prueba (todo junto, en el teléfono)
                                                                    │
                                                                    ▼
                              07 Personaje: primeros pasos (lo más difícil, al final)

  08 Problemas comunes y atajos  →  consultala SIEMPRE que algo salga raro
```

| Guía | Programa | Qué te llevás | Tiempo estimado* |
| --- | --- | --- | --- |
| [01 Instalar y primer vistazo](01-instalar-y-primer-vistazo.md) | Blender | Blender instalado y configurado; sabés moverte, seleccionar, mover/rotar/escalar, deshacer y guardar | 2–3 h |
| [02 Primera silla](02-primera-silla.md) | Blender → Godot | Una silla `.glb` que se ve en el juego | 3–5 h |
| [03 Mueble con partes](03-mueble-con-partes.md) | Blender | Una mesa, una cama y una estantería; lista de revisión antes de exportar | 4–6 h |
| [04 Krita: colores y paleta](04-krita-colores-y-paleta.md) | Krita | Paleta de colores probada; bocetos de referencia | 2–3 h |
| [05 Íconos SVG](05-iconos-svg.md) | Inkscape (recomendado) | Un ícono propio de 64×64 px dentro del juego | 2–3 h |
| [06 Cuarto de prueba](06-cuarto-de-prueba.md) | Blender + juego | Un dormitorio con 5–6 muebles tuyos, visto en el teléfono y medido en FPS | 6–10 h |
| [07 Personaje: primeros pasos](07-personaje-primeros-pasos.md) | Blender | Entender el esqueleto y una ruta de aprendizaje | 1–2 h de lectura; semanas de práctica |
| [08 Problemas comunes y atajos](08-problemas-comunes.md) | — | Arreglos y una hoja de atajos de una página | consulta |

\* Tiempos para alguien que nunca usó el programa y sigue cada paso con calma.
**Total para llegar al cuarto de prueba (guías 01 a 06): unas 20 a 30 horas**,
conviene repartidas en 2 a 4 semanas, de a una o dos horas por día. Aprender
cansa: es mejor una hora por día que un sábado entero. El personaje (07) suma
**meses** y se deja para el final.

## Qué se hace en cada programa

| Tarea | Programa | Por qué |
| --- | --- | --- |
| Modelar muebles y objetos 3D, ponerles material, exportar `.glb` | **Blender** | Es el programa 3D; lo que sale va directo al juego |
| Esqueleto y animaciones del personaje | **Blender** | Mismo programa |
| Elegir y probar la paleta de colores, bocetar ideas y referencias | **Krita** | Es de dibujo; ideal para probar colores y hacer dibujos de referencia |
| Íconos de la interfaz (SVG) | **Inkscape** (recomendado) o, con limitaciones, Krita | Los íconos son vectores; ver la guía 05 para las razones |
| Ver las piezas, medir FPS, pegar el nombre del modelo en el catálogo | **Godot** (el juego) | Es donde se ve el resultado real |

## Cómo se conecta con el juego (lo esencial en 8 líneas)

1. Modelás en Blender: **1 celda = 1 metro**, la pieza apoyada en el piso y
   centrada (pivote en el centro de la base).
2. Cada color es un **material con nombre** de la paleta: `wood`, `cloth_red`…
   (la lista está en `data/palette.json`).
3. Exportás un `.glb` y lo guardás en `assets/models/` con nombre en inglés,
   minúsculas y guiones bajos (`bed_basic.glb`).
4. En `data/catalog.json`, en la línea de esa pieza, agregás
   `"model": "res://assets/models/bed_basic.glb"`.
5. Abrís Godot (importa el archivo solo) y corrés el juego con **F5**.
6. En el juego: **Menú → Info → «Usar modelos 3D (arte)»** prende y apaga tu
   modelo para compararlo con la figura simple.
7. **El contorno y las sombras duras los pone el juego**: vos solo modelás
   formas redondeadas con colores planos.
8. Si el archivo falta o está roto, el juego **no se rompe**: usa la figura
   simple de siempre. Podés equivocarte sin miedo.

Las reglas técnicas completas están en [`docs/estilo.md`](../estilo.md)
(secciones 8, 9 y 11). Estas guías están hechas para coincidir con ellas; si
alguna vez no coinciden, **manda `docs/estilo.md`**.

## Reglas de oro (valen para todas las guías)

- **Guardá seguido** (`Ctrl + S` en Blender y en Krita). Es el hábito que más
  disgustos evita.
- **Un cambio, una prueba.** Hacé una cosa, mirala en pantalla y recién ahí
  seguí.
- **Arte propio o CC0.** Nada de copiar personajes, objetos ni íconos de otros
  juegos o series. Si usás algo ajeno (un paquete gratis), anotá de dónde salió
  y su licencia en `assets/models/LICENCIAS.md`.
- **Nada de tutoriales piratas** ni cursos descargados de sitios dudosos. Hay
  material oficial gratis (enlazado en cada guía).
- **Lo que instales en la PC se anota** en la bitácora: avisale al asesor
  *antes* (ver guía 01).

## Cómo leer cada guía

- **Menús e interfaz:** el nombre en **inglés** (la interfaz por defecto) y, si
  existe, entre paréntesis el equivalente en español. Ejemplo:
  **File > Save (Archivo > Guardar)**. El signo `>` significa «dentro de».
- **Atajos:** entre comillas de código, por ejemplo `Ctrl + S`.
  - `LMB` = botón izquierdo del mouse, `RMB` = derecho, `MMB` = botón del
    medio (la rueda apretada).
  - `Numpad 1` = el **1 del teclado numérico** (el de la derecha del teclado).
- **«Si no te sale»:** al final de cada bloque, los 2–3 problemas más comunes.
- **Marcas:** «(a confirmar en tu versión)» = no pude verificarlo para esa
  versión.
- **Mouse:** las guías suponen un mouse de **tres botones** (izquierdo, derecho
  y rueda que se aprieta). Si tenés **touchpad** o un mouse sin rueda que se
  aprieta, la guía 01 explica cómo emularlo.

## Enlaces oficiales (para mirar cuando quieras)

- Manual de Blender 5.2 (inglés): <https://docs.blender.org/manual/en/5.2/>
  (también hay versión en español: cambiá `en` por `es` en la dirección; la
  traducción puede estar más atrasada). **Si un enlace de estas guías da error
  404, abrí esa página principal y usá el buscador**: las páginas cambian de
  lugar entre versiones.
- Documentación de Krita: <https://docs.krita.org/en/>
- Inkscape (tutoriales oficiales): <https://inkscape.org/learn/>
- Godot, importar escenas 3D (`.glb`):
  <https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/index.html>
- Paquetes gratis CC0 para aprender mirando: Kenney <https://kenney.nl/assets>
  y Quaternius <https://quaternius.com/> (verificá la licencia de cada paquete).

## Cuando termines cada guía

Avisale al asesor. Él puede: anotar la instalación en la bitácora, revisar tus
`.glb` con `ModelLoader.inspect` (mide triángulos, tamaño, pivote y materiales),
conectar un ícono nuevo en la interfaz, y corregir estas guías si algo no
coincidió con tu versión.

## Glosario del mapa

- **Blender:** programa gratis de 3D (modelar, animar, esqueletos).
- **Krita:** programa gratis de dibujo y pintura digital.
- **Inkscape:** programa gratis de dibujo vectorial (SVG).
- **`.glb`:** archivo de un modelo 3D (glTF binario) que el juego sabe leer.
- **Material:** el «color» (y cómo se ve) de una superficie. En este proyecto
  son colores planos con nombre.
- **Paleta:** la lista de colores permitidos del juego (`data/palette.json`).
- **Pivote / origen:** el punto de referencia del objeto; el juego lo pone en
  el piso, en el medio del mueble.
- **Celda:** un cuadradito de la cuadrícula de la casa; mide 1 × 1 metro.
