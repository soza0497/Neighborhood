# Guía 07 — El personaje chibi: primeros pasos

**Objetivo:** entender qué es un **esqueleto (armature)**, cómo se arma un
personaje con **partes intercambiables sobre un solo esqueleto**, y tener una
**ruta de aprendizaje en pasos pequeños** con enlaces oficiales. **No es un
tutorial completo de rigging** (eso llevaría un curso entero): es el mapa para
que no te pierdas.

**Resultado final:** una ruta clara de 6 etapas, una lista de qué mirar en
personajes gratis (CC0) para aprender cómo están hechos, y una idea realista de
cuánto falta.

**Tiempo estimado:** 1 a 2 horas para leer y mirar un personaje de ejemplo;
**semanas a meses** para recorrer la ruta.

---

## El aviso honesto (leelo primero)

**El personaje es lo más difícil de todo el arte del juego, y se deja para el
final.** Un mueble es una forma quieta. Un personaje necesita: un modelo bien
hecho, un **esqueleto**, **pesos** (cuánto se mueve cada parte de la piel con
cada hueso), **animaciones** (idle, caminar, dormir, cocinar…) y que además las
**partes se puedan cambiar** (pelo, orejas, cola, ropa). Cada una de esas cosas
es un tema grande.

Por eso:

1. **Primero** hacé las guías 01 a 06 (muebles y cuarto de prueba). Lo que
   aprendas ahí lo usás en el personaje.
2. **No te frustres** si el rigging no sale a la primera: es normal que lleve
   varios intentos. Los profesionales también empiezan mirando personajes ya
   armados.
3. **Mientras tanto el juego ya funciona**: usa un personaje provisional (cápsula
   + cabeza grande) y el sistema de piezas ya está hecho. Cuando tengas un
   personaje propio, entra pieza por pieza, sin romper nada.
4. Hay atajos (generar el modelo con IA desde **tu** imagen de referencia, o
   partir de un paquete **CC0**), pero igual hay que **limpiarlo y ponerle el
   esqueleto del juego**. Ver `docs/guia-arte.md`, sección 3, con sus
   advertencias de licencia.

> Lo marcado «(a confirmar en tu versión)» no se pudo verificar para Blender
> 5.2. Manual de rigging y animación (inglés):
> <https://docs.blender.org/manual/en/5.2/animation/index.html>

---

## Parte A — Las ideas básicas

| Palabra | Qué es, en simple |
| --- | --- |
| **Armature (esqueleto)** | Un objeto de Blender hecho de **huesos** conectados, como un esqueleto de verdad |
| **Bone (hueso)** | Una pieza del esqueleto; tiene un **inicio** (articulación) y una **punta** |
| **Jerarquía (parenting)** | Los huesos se heredan: si girás la cadera, se mueve toda la pierna |
| **Skinning (enlazado de la piel)** | Unir la malla al esqueleto para que la malla siga a los huesos |
| **Weights (pesos)** | Un número de 0 a 1 por vértice y por hueso: cuánto lo mueve ese hueso. Se pintan en **Weight Paint (Pintura de pesos)** |
| **Pose** | Una posición del esqueleto (por ejemplo, brazo levantado) |
| **Keyframe (fotograma clave)** | Una pose guardada en un momento; Blender rellena lo de entremedio |
| **Action (acción)** | Una animación completa (por ejemplo `walk`) guardada con nombre |

Blender **no inventa** el movimiento: vos ponés poses clave y él las une.

### Por qué un solo esqueleto para todos

Si todos los personajes (el tuyo, el de tu pareja, un lobo, un robot) usan **el
mismo esqueleto con los mismos nombres de hueso**, **una animación sirve para
todos** y las piezas se intercambian. Por eso el juego define **un esqueleto
único** en `data/character_slots.json`:

```
skeleton: root, hips, spine, chest, neck, head,
          arm_l, hand_l, arm_r, hand_r,
          leg_l, foot_l, leg_r, foot_r, tail
```

Quince huesos, en inglés y minúsculas. (La jerarquía sugerida: `root` > `hips`
> `spine` > `chest` > `neck` > `head`; de `chest` salen `arm_l`/`arm_r` > `hand_*`;
de `hips` salen `leg_l`/`leg_r` > `foot_*` y la `tail`. A confirmar con el
asesor antes de armarla.) **Los nombres exactos mandan**: el juego los busca por
nombre.

*Nota sobre nombres:* Blender tiene herramientas de espejo que reconocen
sufijos como `.L` y `.R`; tus huesos se llaman `arm_l` y `arm_r`. Para
simetrizar a mano conviene nombrarlos primero con el estilo de Blender y
**renombrar al final** con los nombres del juego (a confirmar en tu versión).

### Partes intercambiables (slots)

`data/character_slots.json` define nueve **slots** (huecos): **cuerpo base**,
**cabeza**, **pelo**, **ojos**, **boca**, **orejas**, **cola**, **ropa** y
**accesorio**. Cada uno tiene:

- un **hueso** donde se pega (`attach`): el pelo en `head`, la cola en
  `hips`, la ropa en `spine`;
- qué **figuras simples esconde** al cargarse (`hides`), así la pieza nueva
  reemplaza a la provisional;
- qué **materiales se pintan** con lo elegido por el jugador (`colors`): `skin`,
  `hair`, `shirt`, `pants`.

**Cómo se pega hoy:** una pieza `.glb` rígida (pelo, orejas, cola, accesorio) se
engancha al hueso `attach` del cuerpo, o a una posición fija si el cuerpo no
tiene esqueleto (para la cabeza, en `[0, 1.0, 0]`: el **centro de la cabeza**).
El ejemplo `assets/models/character/hair_round.glb` es una media esfera de
0,33 m de radio **centrada en el origen**, pensada para ir sobre la cabeza.
La **ropa deformable** (que se dobla con el cuerpo) todavía **no** está
soportada: queda para cuando haya un esqueleto real (`docs/estilo.md`, §10).

> **A acordar con el asesor cuando llegues a esa etapa:** dónde queda el
> **origen** de las piezas respecto del hueso `head` (en el centro de la cabeza o
> en la base del cuello), para que el pelo no quede flotando ni hundido.

### Presupuesto y proporciones (de `docs/estilo.md`)

- **Personaje completo ≤ 3.000 triángulos.** Pieza suelta (pelo, cola) ≤ 500.
- **Alto ≈ 1,35 m**, cabeza ≈ 45 % del alto (esfera de 0,6 m), ojos grandes,
  manos y pies redondeados, cabe en una celda y por una puerta de 0,9 m.
- Materiales con nombre de la paleta: `skin`, `hair`, `eye`, `mouth`, `shirt`,
  `pants`, `shoe`.
- Animaciones con los nombres de los ganchos: `idle`, `walk`, `sleep`, `sit`,
  `cook`, `eat`, `shower`, `use`, `arrive`, `wave`, `cough`, `hurt` (hay
  alternativas aceptadas en `character_slots.json` → `animations`).

---

## Parte B — Ruta de aprendizaje en 6 etapas

Cada etapa termina en algo que podés **ver y guardar**. No pases a la siguiente
hasta que la anterior te salga sin mirar la guía.

### Etapa 1 — Mirar cómo está hecho un personaje ya armado (1–2 horas)

**Meta:** reconocer las partes de un personaje en Blender sin tocar nada.

1. Bajá un personaje gratis **CC0** (de uso libre) de **Kenney**
   (<https://kenney.nl/assets>) o **Quaternius** (<https://quaternius.com/>).
   Elegí uno **con esqueleto/animaciones** y en formato **glTF/glb** (el nombre
   exacto del paquete: a confirmar en la web). **Verificá la licencia en la
   página del paquete.** Si más adelante usás algo suyo en el juego, anotalo en
   `assets/models/LICENCIAS.md`.
2. Guardalo en una carpeta de trabajo **fuera del repositorio**, no en
   `assets/`.
3. En Blender: **File > Import > glTF 2.0 (.glb/.gltf)**.
4. Mirá, en este orden, y anotá lo que ves:
   - **Outliner:** ¿hay un objeto **Armature**? Abrilo (la flechita) para ver
     los **huesos** y su **jerarquía**. ¿Cuántos son? ¿Cómo se llaman?
   - **Propiedades > Object Data (icono verde de hombrecito/Armature):** pasá
     de **Pose Position** a **Rest Position** y viceversa para ver la pose de
     reposo.
   - La **pose de reposo**: ¿en T o en A (brazos abiertos)? Es la pose en la que
     se modela y se enlaza.
   - Seleccioná la malla > **Propiedades > Object Data > Vertex Groups (Grupos de
     vértices)**: hay **uno por hueso** (los pesos).
   - **Modo Weight Paint** (selector de modo del visor): ves en rojo lo que
     mueve el hueso elegido (clic en un hueso en modo Pose, con la malla
     activa; a confirmar el flujo exacto en tu versión).
   - **Animation workspace** (pestaña de arriba) > **Dope Sheet > Action Editor**:
     la lista de **animaciones** (`Idle`, `Walk`…) y sus fotogramas clave.
   - **Triángulos** (Statistics), **cantidad de materiales**, **escala** (¿mide
     1,8 m? el tuyo mide 1,35).
5. **Resultado:** una hoja con 8 observaciones (nº de huesos, nombres, pose de
   reposo, triángulos, materiales, animaciones…). Compará con lo que el juego
   necesita (arriba).

### Etapa 2 — Un esqueleto de 3 huesos en una «salchicha» (2–4 horas)

**Meta:** que un cilindro se doble con un hueso.

1. `Shift + A` > **Mesh > Cylinder**; con **Loop cuts** (`Ctrl + R`) agregale
   varios anillos a lo largo.
2. `Shift + A` > **Armature > Single Bone (Armadura > Hueso único)**.
3. **Modo Edición del esqueleto** (`Tab`), seleccioná la punta y extruí con
   **`E`** dos huesos más (cadena de 3). Renombralos con **`F2`**.
4. **Enlazar:** seleccioná primero la **malla**, después (`Shift + clic`) el
   **esqueleto**, y **`Ctrl + P` > With Automatic Weights (Con pesos
   automáticos)** (a confirmar el nombre exacto del menú).
5. **Pose Mode** (selector de modo): seleccioná un hueso, **`R`** y girá.
   **Deberías ver** el cilindro doblándose.
6. Mirá los **pesos** en Weight Paint y arreglá con el pincel si hace falta.

Referencias oficiales: manual de **Armatures**
(<https://docs.blender.org/manual/en/5.2/animation/armatures/index.html>) y de
**Weight Paint**
(<https://docs.blender.org/manual/en/5.2/sculpt_paint/weight_paint/index.html>).

### Etapa 3 — Tu primera animación (2–4 horas)

**Meta:** una acción `idle` de 1 segundo que se repite.

1. En **Pose Mode**, poné una pose y apretá **`I`** (insertar fotograma clave) en
   el cuadro 1. Cambiá al cuadro 24 (la línea de tiempo), otra pose,
   **`I`** otra vez; y volvé al cuadro 1 / copiá la primera pose al 48 para que
   sea un bucle.
2. En **Dope Sheet > Action Editor**, renombrá la acción a **`idle`**.
3. Reproducí con la **barra espaciadora**. **Deberías ver** el movimiento.
4. Repetí con una segunda acción (`walk` = ciclo de caminata de ~1 s). Una
   animación por **Action**; para que el exportador las lleve todas, hay que
   guardarlas (las acciones sin uso pueden perderse; usar el botón de **escudo/
   Fake User** o ponerlas en **NLA**: a confirmar en tu versión).

Referencias: manual de **Animation & Rigging**
(<https://docs.blender.org/manual/en/5.2/animation/index.html>). Para cursos
guiados, **Blender Studio** tiene entrenamiento oficial gratuito/de pago
(<https://studio.blender.org/training/>; a confirmar qué cursos hay hoy).

### Etapa 4 — Tu personaje base con el esqueleto del juego (semanas)

**Meta:** un cuerpo chibi simple que respeta las proporciones y tiene los 15
huesos del juego.

1. Modelá el cuerpo con las técnicas de las guías 02 y 03 (formas redondeadas,
   pocos triángulos, **≤ 3.000**), con materiales `skin`, `shirt`, `pants`,
   `shoe`.
2. Hacé el **esqueleto de 15 huesos** con los nombres de `character_slots.json`.
3. **Enlazá con pesos automáticos** y corregí a mano en Weight Paint.
4. Probá las poses extremas (brazos arriba, cadera girada, sentado).
5. Exportá un `.glb` de prueba **con esqueleto y la acción `idle`** (guía 02,
   con **Animation** activado y **Skinning** activado; a confirmar los nombres
   de esas casillas) y **pedile al asesor que lo pruebe** con
   `CharacterAssembler`. **Es la prueba más importante de toda la ruta.**

### Etapa 5 — Partes intercambiables (semanas)

**Meta:** pelo, orejas y cola como piezas aparte.

1. Primero **piezas rígidas** (pelo, orejas, cola, un sombrero): cada una es un
   modelo chico (≤ 500 triángulos) con el material `hair` o `skin`, hecho
   alrededor del **origen acordado** (ver la nota de arriba) y exportado a
   `assets/models/character/` (ej. `hair_round.glb`).
2. Enchufalas en `data/character_options.json` (campo `"model": "hair_round.glb"`)
   con ayuda del asesor.
3. **Ropa que se dobla (skinning compartido):** es lo último y todavía no está
   soportado por el juego; lo conversás con el asesor cuando llegues.

### Etapa 6 — Las animaciones de verdad (semanas)

**Meta:** `idle` y `walk` bien hechas primero; después `sit`, `sleep`, `cook`,
`eat`, `shower`, `use`, `arrive`, `wave`, `cough`, `hurt`. Cada una se llama
igual que el gancho del juego. Si una falta, el juego usa su movimiento simple:
**podés ir agregando una por una**.

---

## Qué mirar en un personaje CC0 (lista de chequeo para aprender)

| Mirá | Por qué importa |
| --- | --- |
| Cantidad de huesos (15 en el juego; los de paquetes suelen tener 20–65) | Más huesos = más complejo; empezamos con pocos |
| Nombres y jerarquía de huesos | Los nuestros están fijos en `character_slots.json` |
| Pose de reposo (T o A) | Es la pose en la que se modela y se enlaza |
| Vértices por grupo (pesos) | Se ve cómo reparte cada hueso el movimiento |
| Triángulos totales | Para comparar con el techo de 3.000 |
| Materiales (cuántos y cómo se llaman) | Nosotros: `skin`, `hair`, `shirt`, `pants`, `shoe`… |
| Cabeza/cara: ¿partes separadas o expresiones (shape keys)? | Para pensar ojos y bocas intercambiables |
| Lista de animaciones | Qué nombres usa y cuánto dura cada una |
| Escala y orientación | Nosotros: 1,35 m, mira a +Z al exportar |
| Licencia | CC0 se puede usar libremente; anotala igual en `LICENCIAS.md` |

---

## Ejercicios para practicar

1. Hacé la **Etapa 2** (la salchicha) y mandale una captura al asesor.
2. Importá **dos** personajes CC0 distintos y completá la lista de chequeo para
   cada uno. ¿En qué se parecen y en qué se diferencian?
3. Hacé una animación de **saludo (`wave`)** de 2 segundos en la salchicha o en
   el personaje que descargaste (solo para practicar; no se usa en el juego).
4. Modelá un **sombrero** simple (≤ 300 triángulos, material `shirt`) con el
   origen donde estaría el centro de la cabeza, y exportalo como pieza suelta.
5. Dibujá en Krita (guía 04) tu personaje de frente y de lado en **pose en A**,
   respetando las proporciones chibi.

## Glosario

- **Armature (esqueleto):** conjunto de huesos.
- **Bone (hueso):** pieza del esqueleto.
- **Rig / rigging:** armar el esqueleto y enlazarlo al modelo.
- **Skinning:** enlazar la malla a los huesos.
- **Weights (pesos):** cuánto afecta cada hueso a cada vértice.
- **Pose Mode (Modo Pose):** modo para mover huesos.
- **Keyframe (fotograma clave):** pose guardada en un instante.
- **Action (acción):** una animación con nombre.
- **Pose en T / en A:** brazos abiertos horizontales / hacia abajo en diagonal.
- **Slot:** hueco del personaje donde entra una pieza intercambiable.
- **CC0:** licencia que permite usar la obra libremente, sin pedir permiso.

Siguiente: [08 — Problemas comunes y atajos](08-problemas-comunes.md).
