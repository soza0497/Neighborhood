# Isla 1A — prototipo de rendimiento y niveles de detalle (LOD)

> Rama `isla-1a`. **No se mergea a `main` y no se exporta APK.** Todo es archivo nuevo
> (`scripts/island/`, `scenes/island/`, `data/island.json`, `tests/*island*`) salvo tres toques mínimos:
> `scripts/camera/camera_rig.gd` (modo isla, como el del barrio), `ui/hud.gd` (2 líneas: el botón escondido de Info)
> y `tools/make_island_data.py` (nuevo, opcional).
> Este documento es solo de este prototipo. El diseño general de la isla vive en `docs/isla.md` (del desarrollador principal,
> no se tocó). **Todo con figuras simples.**

> ⚠ **Nada de esto se pudo correr en la nube** (no hay Godot ni Lua; el brief prohíbe descargar binarios). El código está
> escrito con cuidado y revisado a mano, pero los errores de sintaxis aparecen al primer arranque. Lo único verificado con
> Python: `data/island.json` (válido, 60 lotes, sin encimarse, ninguno pisa calles ni sale de la isla). Ver «Qué quedó sin correr».

---

## 1. Qué se hizo (resumen)

| Pieza | Archivo | Para qué |
|---|---|---|
| Datos de la isla | `data/island.json` | 60 lotes (30 al empezar), zonas, calles, reglas, casas simuladas, distancias de LOD, colores, vistas de la demo. **Todo editable.** |
| Lectura de datos | `scripts/island/island_data.gd` (`IslandData`) | Funciones estáticas: lotes, esquinas, reglas, colores, azar determinista. |
| Ficha exterior | `exterior_card.gd` (`ExteriorCard`) | Resumen chico de una casa; se genera desde `HouseData` y se reconstruye. |
| Casas simuladas | `island_fake_houses.gd` (`IslandFakeHouses`) | Una casa determinista por lote (usa `NeighborHouseDesign` de la Fase 8). |
| Geometría y LODs | `exterior_geometry.gd`, `exterior_lod0/1/2.gd`, `island_map_lod3.gd` | Arman cada nivel de detalle desde la ficha. |
| Mallas y materiales | `island_mesh_kit.gd`, `island_materials.gd`, `assets/shaders/island_blocks.gdshader`, `island_map.gdshader` | Juntan piezas en una sola malla con color por vértice. |
| Escenario | `island_builder.gd` (`IslandBuilder`), `island_smoke.gd` | Suelo con zonas, calles, parque con lago, comercios, playa, muelle, volcán, árboles. |
| Decisión de LOD | `island_lod.gd` (`IslandLod`) | Nivel de cada lote por distancia, con histéresis. Lógica pura (se prueba sin escena). |
| La isla viva | `island_world.gd` (`IslandWorld`) | Aplica los niveles con presupuesto de armados por cuadro; streaming por radio. |
| Estrés y números | `island_stress.gd`, `island_stats.gd` | 100 casas juntas; conteo de dibujo estimado y real. |
| Demo | `scenes/island/island_demo.tscn` + `scripts/island/island_demo.gd` (y `tests/island_demo.tscn`, que la instancia) | FPS, botones, estrés, capturas, tabla. |
| Entrada en el teléfono | `island_test_entry.gd` + 2 líneas en `ui/hud.gd` | Menú → Info → «Herramientas de prueba» → «Prueba de isla». |
| Pruebas | `tests/test_island.tscn` | unas 100 comprobaciones sin ventana. |
| Generador de lotes (opcional) | `tools/make_island_data.py` | Rehace el reparto de lotes y valida. |

> **Por qué el script de la demo está en `scripts/island/` y no en `tests/`:** `export_presets.cfg` excluye `tests/*`
> del APK. Para que la demo viaje en el teléfono, el script y la escena viven en `scripts/island/` y `scenes/island/`;
> `tests/island_demo.tscn` solo la instancia (así el comando de siempre funciona).

---

## 2. El diseño, en datos (`data/island.json`)

Coordenadas en **metros**. `(0, 0)` = centro del parque, `+Z` = sur (avenida y muelle), `-Z` = norte (volcán de fondo).

```
            norte (-Z)   ·  volcán de fondo (fuera de la isla)
                 │
   Calle del Faro ── PARQUE (r 34: lago, glorieta, plaza) ── Calle del Sol
                 │   anillo de comercios (r 37-47, decorados y apagados)
                 │   calle circular r1 (r 52)  → anillo A (8 lotes, S/M, dan al parque)
                 │   calle circular r2 (r 112) → anillo B (16 lotes, S/M/L)
                 │   calle circular r3 (r 193) → anillo C (28 lotes, S/M)
                 │   calle circular r4 (r 256, solo el sur) → anillo D (8 lotes junto a la playa)
            sur (+Z)   Avenida del Muelle → playa ancha → muelle (90 m al mar)
```

* **60 lotes**: 42 S (32×32), 10 M (48×48), 8 L (64×64). `start: true` en 30 (anillos A y B enteros y los 6 del C más
  cercanos a la avenida); los otros 30 son `future` (terreno cerrado, marcador violeta). De los 30 del comienzo: 1 `player`
  (la parcela S regalada), 20 `npc` (vecinos simulados) y 9 `free` (terreno verde con marcador rosa).
* **Reglas** (`rules`): tamaños, `start_lots`, `max_lots`, `max_lots_per_player` (3), `gift_size`, `max_pieces_per_lot`
  (S 700, M 1500, L 2600), precios base por tamaño × factor de anillo × factor premium (`price` de cada lote ya calculado).
* **Zonas** (`zones`): parque (lago, plaza, glorieta, bancas), comercios (`active: false` = solo decorados), playa
  (sombrillas, palmeras), muelle, volcán (cono simple; `smoke.enabled` = humo opcional).
* **Calles** (`streets`): 4 radiales (ángulo: `x = cos`, `z = sin`; 90 = sur) y 4 circulares (con `arc` para las parciales).
* **Casas simuladas** (`houses`): rangos de celdas y de pisos por tamaño de lote, probabilidad de forma en L, de techo plano
  y de pisos de arriba más chicos.
* **LOD** (`lod`): distancias, histéresis, cuántos armados por cuadro, vegetación. Ver §4.
* **Colores** (`colors`): toda la paleta de la isla. Los nombres de lugares son genéricos (ver `docs/riesgos-legales-ea.md`, sección «Isla 1A»).

Para mover un lote basta con cambiar `center` o `yaw` en el JSON; `tests/test_island.tscn` avisa si se encima, pisa una calle
o se sale de la isla. `python3 tools/make_island_data.py` rehace todo el reparto (y sobrescribe `data/island.json`: úsalo
solo si no editaste el JSON a mano).

**Lo que me desvié del diseño** (para decidir con el desarrollador principal):
* Los lotes **L** quedan en los anillos B y D (exteriores). No entran en el anillo A (pegado al parque) porque su fondo de
  64 m chocaría con la calle circular r2. «Junto al parque» lo cubre el anillo A con lotes M/S de precio premium (`premium: ["park"]`).
  «Junto a la playa» = anillo D. «Junto al lago» no existe: el lago está dentro del parque, detrás de los comercios.
* Con calles radiales de 4 (cruz) caben 60 lotes con radio de isla **352 m** (diámetro de 700 m). Con 6 radiales caben menos.
  Si se quiere una isla más chica, hay que bajar la cantidad de lotes o usar solo S/M.

---

## 3. La ficha exterior (`ExteriorCard`)

Se genera desde un `HouseData` (`ExteriorCard.from_house(house)`) y **de ella se arman el LOD 1 y el LOD 2**. Pesa
cientos de bytes (la prueba exige 100–1500; calculo 300–900 para las casas de la isla, sin medir todavía) y se serializa a diccionario o JSON
(`to_dict()`, `to_json()`, `from_dict()`), listo para guardarla en el servidor más adelante.

```json
{"v":1,"b":0.3,
 "f":[{"fp":[[0,0,9,8]],"h":2.7,"wc":"f2e3c6","w":[ ...códigos de pared... ]}, {"fp":[[1,1,7,6]],"h":2.7,"wc":"dfe9f5","w":[...]}],
 "r":[{"lv":1,"r":[1,1,7,6],"s":"g","c":"e0675a"}],
 "d":{"lv":0,"e":4128}}
```

* **Por piso** (`f`): huella como lista de rectángulos `[x, z, ancho, fondo]` en celdas (una L = 2 rectángulos; si salen más de 8 se guarda
  su caja), alto de pared, color de pared (el que más se repite en el contorno) y las ventanas.
* **Techos** (`r`): nivel, rectángulo, estilo (`g` dos aguas, `f` plano) y color.
* **Puerta** (`d`): nivel y pared; `door_side()` dice el lado (`n/s/e/w`).
* **Códigos de pared**: un entero por pared (`edge_code`), así pesa poco. Admite coordenadas de −64 a 191.
* **No lleva**: muebles, cuartos, objetos del jardín, nada de adentro.
* **Reconstruir**: `to_house_data()` arma una casa mínima (cimientos, pisos, paredes del contorno con puerta y ventanas, techos).
  La prueba verifica `ficha → casa mínima → ficha` = misma forma, y también `ficha → JSON de texto → ficha`.

---

## 4. Los cuatro niveles de detalle

| Nivel | Qué se ve | Cómo se arma | Costo (por casa) | Contorno |
|---|---|---|---|---|
| **LOD 0** | Tu parcela completa: interior, muebles, todo | `HouseView` del juego (`ExteriorLod0`) | cientos de piezas (medir) | sí |
| **LOD 1** | Vecinos cercanos, solo exterior, piso a piso, puerta y ventanas | UNA malla con color por vértice desde la ficha (`ExteriorLod1`) | 1 malla, ≈ 100–250 triáng., **2 llamadas** (1 sin contorno) | sí (configurable) |
| **LOD 2** | Una calle o zona: cada casa son bloques con color y techo | TODAS las casas de una zona en UNA malla (`ExteriorLod2`, el `cluster` de cada lote) | ≈ 20–60 triáng.; **1 llamada por zona**, no por casa | **no** |
| **LOD 3** | Toda la isla como mapa estilizado | UN plano de malla baja, lotes coloreados (`IslandMapLod3`), sin luz | 1 llamada, < 2 mil triáng. | no |

* **Distancias** (de la cámara al centro del lote, en `lod.distances`): **70 / 230 / 520 m**. LOD 0 hasta 70 m, LOD 1 hasta 230,
  LOD 2 hasta 520, más allá LOD 3 (nada por lote). Con `lod0_max: 1` solo la casa más cercana puede ser LOD 0.
* **Mapa de toda la isla**: entra cuando la cámara está a más de `2.9 × radio` del centro (≈ 1020 m) y sale bajo `2.5 × radio` (≈ 880 m).
  Con el mapa, el detalle (suelo, casas, árboles) se esconde; quedan el mar y el volcán.
* **Histéresis** (`lod.hysteresis` = 0,12): un lote **sube** de nivel (se aleja) solo si pasa `distancia × 1,12`, y **baja** (se acerca) solo
  bajo `distancia × 0,88`. Así no parpadea al estar justo en el límite. La prueba oscila ±3 % alrededor del límite y exige 0 cambios.
* **Streaming por radio**: al llegar a LOD 3 se libera todo lo de la casa (LOD 0 y LOD 1); LOD 0 se libera al pasar a LOD 1 o más
  (lo más caro); el LOD 1 se conserva escondido en LOD 2 (volver es gratis). La vegetación va en **trozos** de 140 m (un
  `MultiMeshInstance3D` por trozo) que se muestran solo dentro de `vegetation_range` (320 m, con histéresis).
* **Presupuesto de armados**: como mucho `builds_per_frame` (2) casas armadas por cuadro; lo demás espera. Las mallas de zona se rearman
  solo cuando cambia quién está en ese nivel.
* **Contorno**: el contorno toon dibuja cada pieza dos veces. En LOD ≥ 2 el material (`IslandMaterials.blocks(false)`) no lleva la segunda
  pasada; el suelo, el escenario y los árboles tampoco. `lod.outline_max_level` (1) dice hasta qué nivel hay contorno: poné 0 y el LOD 1
  también sale sin contorno. El interruptor «Contorno» de Info (`Style.set_outline`) sigue mandando.
* **Sombras**: solo el LOD 0 (HouseView) proyecta; el resto está en `cast_shadow = OFF`. La demo tiene un botón «Sombras» para ver cuánto cuestan.
* **Vegetación repetida**: un solo modelo de árbol (tronco + dos conos, ≈ 32 triáng.) en `MultiMesh`: ≈ 280 árboles (con los 30 lotes del comienzo) entre calles, parque, jardines y palmeras.

---

## 5. La demo (`tests/island_demo.tscn`)

```bash
godot --path . res://tests/island_demo.tscn
```

* Cámara del juego (`CameraRig`) con un **modo isla** (`enter_island_view`: mismos gestos, límites más amplios, `near = 1`, `far = 3000`).
  Mouse: arrastrar mueve, clic derecho gira, rueda hace zoom. Dedos: 1 arrastra, 2 pellizcan y giran. Flechas, Q/E y +/− también.
* Panel arriba a la izquierda: **FPS**, llamadas de dibujo y triángulos **del motor** (`RenderingServer.get_rendering_info`) y **estimados** (cuenta lo
  visible en el árbol), cuántas casas hay en cada LOD, vegetación visible, mapa sí/no, contorno y sombras.
* Botones abajo (o teclas): **LOD 0/1/2/3** fuerzan ese nivel en todo (`0 1 2 3`), **Auto** (`A`), **Contorno** (`O`), **Sombras** (`H`), **Humo** (`M`),
  **Números** (`F`), **30 lotes** (`F1`), **60 lotes** (`F2`, estrés), **100 casas L1** (`F3`, el techo del LOD 1), **100 casas L2** (`F4`),
  vistas **Calle / Barrio / Isla**, **Captura** (`P`, a `SHOT_DIR` o a `user://`), **Medir** (`B`), **Volver** (`Esc`).
* **Medir** recorre 3 vistas × (LOD 0, 1, 2, 3 y automático) con 30 lotes, el automático con 60 lotes en 2 vistas y las 100 casas en LOD 1 y LOD 2.
  Por cada fila espera 40 cuadros y mide 2 s. Al final **imprime la tabla** (Markdown), la guarda en `isla_tabla.md` y la muestra en pantalla
  (para sacar captura en el teléfono). Sin interfaz y sin tocar nada:

  ```bash
  ISLAND_BENCH=1 SHOT_DIR=docs/capturas godot --path . res://tests/island_demo.tscn
  ```

> La demo no guarda nada del juego. La tabla de la PC **no vale para el teléfono**: sirve para comparar niveles entre sí y para encontrar
> errores. Los números que importan son los del teléfono (§7).

---

## 6. Pruebas

```bash
godot --headless --path . --import          # primera vez: registra las clases nuevas y crea los .uid
godot --headless --path . res://tests/test_island.tscn
```

Comprueba (sin ventana): 60 lotes, 30 al comienzo, una parcela regalada; tamaños válidos (32/48/64); **ningún lote se encima** (con 1 m de aire),
**ninguno sale de la isla**, invade el parque ni pisa una calle radial o circular; todos miran al centro; la ficha de cada casa pasa por JSON y por
casa mínima y **da la misma forma**; pesa 100–1500 bytes; la puerta está en la fachada; las casas son distintas (1–3 pisos, L, techo plano o de tejas,
colores) y respetan el límite de piezas; LOD 2 siempre tiene menos triángulos que LOD 1; **el LOD correcto a cada distancia**; **histéresis** (sin parpadeo);
el mapa entra y sale a distancias distintas; la isla armada pone LOD 0/1/2 según la cámara; **presupuesto de dibujo estimado**: vista del barrio ≤ 150
llamadas, vista lejana (mapa) ≤ 16 llamadas y < 60 mil triángulos; la vegetación se muestra por radio; el modo de estrés (100 casas) y los límites de la cámara.

Las pruebas viejas no se tocaron. Siguen siendo las de siempre (`test_house` 158, `test_character` 34, `test_economy` 66, `test_server` 78, `test_couple` 46,
`test_business` 46, `test_parcel` 55, `test_art`, `test_neighborhood` y `lua5.1 server/tests/test_rules.lua` 322).

---

## 7. Qué medir en el teléfono (paso a paso)

**Antes:** el desarrollador principal exporta un APK desde la rama `isla-1a` (o de lo que la una a `main`). La demo viaja en el APK sin cambiar la escena principal.
Abrí el proyecto en el editor una vez antes de exportar (importa los shaders y escenas nuevos). Conviene medir con el teléfono sin cargador, sin ahorro de
batería y con el brillo normal; que se enfríe 5 minutos entre mediciones largas.

1. Abrí el juego e iniciá sesión como siempre.
2. Tocá ☰ (menú) → **Info**.
3. Prendé el interruptor **«Herramientas de prueba»**. Aparece el botón **«Prueba de isla (rendimiento)»**. Tocalo (guarda tu partida y abre la demo).
4. En la demo ya hay 30 lotes. Abajo están los botones; arriba a la izquierda, los números. Si no los ves, tocá **Números**.
5. **Medición automática (lo más fácil):** tocá **Medir**. La pantalla se queda sola ~1 minuto con las vistas cambiando. Al terminar aparece un cuadro con
   una línea por prueba. **Sacá una captura de pantalla** de ese cuadro (y mandásela al desarrollador principal). Tocá **Cerrar**.
6. **Medición a mano** (para entender qué pesa), con el botón **Auto** y la vista **Calle**: dejá 10 segundos y anotá `FPS`. Después:
   * **Contorno** (apagá y prendé): ¿cuántos FPS sube al apagarlo?
   * **Sombras** (apagá y prendé): ¿cuánto cuestan?
   * **LOD 0**, **LOD 1**, **LOD 2**, **LOD 3**: anotá FPS y llamadas con cada uno, en vista **Calle** y en vista **Isla**.
   * **100 casas L1** y **100 casas L2**: el techo del LOD 1 y lo que ahorra agrupar.
   * **60 lotes** (estrés), vista **Isla**.
7. **Movimiento real:** en automático, recorré con un dedo desde tu parcela hasta el muelle, acercando y alejando. Fijate si se ven **saltos** (tirones al
   armar una casa), **parpadeos** de casas al estar en el límite, y si el mapa de toda la isla entra y sale sin saltos.
8. Mirá si el teléfono se calienta o baja la velocidad después de 2–3 minutos seguidos.
9. Tocá **Volver** (vuelve al inicio del juego; tu partida estaba guardada).

**Cómo interpretar los números** (la meta del proyecto es 30 FPS en un Android de gama media):

| Qué mirar | Bien | Dudoso | Mal | Si está mal… |
|---|---|---|---|---|
| FPS en **Calle / Auto** | ≥ 40 | 30–40 | < 30 | Probá primero **Sombras** apagadas, después **Contorno**. Si sube mucho, esa es la causa. |
| FPS en **Barrio / Auto** | ≥ 45 | 30–45 | < 30 | Bajar `distances[1]` (230 → 150) y `vegetation_range`; apagar el contorno del LOD 1 (`outline_max_level: 0`). |
| FPS en **Isla / Auto** | ≥ 55 | 40–55 | < 40 | Adelantar el mapa (`map_enter_radii`: 2,9 → 2,2) o bajar `distances[2]`. |
| **Llamadas de dibujo** (motor) | ≤ 250 | 250–400 | > 400 | Mirá quién las gasta: LOD 0 (cientos), LOD 1 con contorno (2 por casa), árboles visibles. |
| **Triángulos** | ≤ 150 mil | 150–300 mil | > 300 mil | LOD 1 con muchas casas cerca; bajar `distances[1]`. |
| **Peor cuadro** (ms) | ≤ 50 | 50–100 | > 100 | Tirones: bajar `builds_per_frame` a 1, o armar el LOD 0 solo cuando la cámara se detiene. |
| **100 casas L1** vs **L2** | — | — | L1 muy por debajo de L2 | Cuántas casas LOD 1 aguanta el teléfono = el `distances[1]` máximo razonable. |

Las llamadas y triángulos que muestra el motor incluyen la interfaz (≈ 20–40 llamadas); la tabla de **Medir** esconde la interfaz para medir solo lo 3D.
Con la ventana del editor (PC) esos números se mezclan con los del editor: medí con la demo en ventana propia (`godot --path .`), no dentro del editor.

---

## 8. Mis recomendaciones (sin medir; hay que confirmarlas en el teléfono)

**Presupuesto que espero** (mi punto de partida, no un dato): para 30 FPS en gama media, **≤ ~300 llamadas de dibujo y ≤ ~200 mil triángulos** por cuadro, con
sombras solo en lo cercano. Esta es la cuenta con los datos actuales (estimada contando nodos, sin correr):

| Cosa | Llamadas | Triángulos aprox. |
|---|---|---|
| Escenario fijo (suelo, detalles, marcadores, mar, volcán, humo 7 bolitas) | ≈ 12 | ≈ 6 mil |
| Vegetación visible (≈ 6–10 trozos de 140 m en 320 m de radio) | ≈ 6–10 | ≈ 5–10 mil |
| Cada casa LOD 1 (con contorno) | 2 | ≈ 100–250 (×2 por el contorno) |
| Cada zona LOD 2 | 1 (≈ 4–8 casas) | ≈ 150–400 (20–60 por casa) |
| Mapa LOD 3 | 1 | < 2 mil |
| **LOD 0** (tu parcela) | **cientos** (medir) | decenas de miles (medir) |

Por eso: **una casa en LOD 0** (`lod0_max: 1`), **LOD 1 limitado a unas 8–12 casas** y el resto agrupado. La pieza grande de la incógnita es el LOD 0:
es la `HouseView` del juego (una pieza por nodo). Si la tabla muestra que una sola casa ya gasta más de 150 llamadas, el siguiente trabajo (fuera de este
prototipo) es **fusionar mallas de la casa propia**, no tocar los LODs lejanos.

**Tamaños de parcela:**
* **S 32×32** (la regalada): bien. Cabe una casa de hasta 13×10 celdas con jardín (el generador usa hasta 2 pisos).
* **M 48×48**: bien para 3 pisos. **L 64×64**: **máximo 8 en toda la isla** (premium) y solo en los anillos exteriores; cada L en LOD 0/1 pesa más (hasta 3 pisos
  y huellas de hasta 28×18) y su malla de LOD 1 es la más grande.
* Recomiendo mantener `max_pieces_per_lot` (S 700 / M 1500 / L 2600) como tope duro: es lo que mantiene el LOD 0 en una cantidad de nodos razonable. Si el LOD 0 mide mal,
  bajarlo a S 400 / M 800 / L 1400 es lo primero.
* Hasta 3 parcelas por jugador (`max_lots_per_player`): como solo UNA es LOD 0, las otras dos se ven como LOD 1 aunque sean tuyas, salvo que estés en ellas.
* 30 lotes al comienzo caben en un radio de ~260 m; los 30 de expansión duplican el área. Si el teléfono pide menos, la isla puede abrirse por anillos
  (el anillo C y D entran al ampliar).

**Distancias de LOD (valores actuales y cuándo moverlos):**

| Distancia | Actual | Mover si… |
|---|---|---|
| LOD 0 → 1 | 70 m | Casi nunca: el LOD 0 se decide más por `lod0_max` (1) que por la distancia. |
| LOD 1 → 2 | 230 m | **La más importante.** Si FPS en Barrio < 30 o 100 casas L1 va mal → 150 m. Si sobra margen → 300 m. |
| LOD 2 → 3 | 520 m | Si el LOD 2 se ve bien y sobra margen, subirla; baja si la vista Isla pesa. |
| Mapa de toda la isla | 2,9 × radio (≈ 1020 m) | Adelantarlo (2,2) si la vista Isla pesa; atrasarlo si se nota el cambio. |
| Vegetación | 320 m | Es lo más barato de recortar: 200 m casi no se nota con niebla. |

**Siguientes pasos probables** (no se hicieron: no los pide esta fase):
* Medir en el teléfono y ajustar `data/island.json` con la tabla anterior.
* Dibujar el LOD 1 con las cosas reales (techo con modelo `.glb`, colores del jugador) desde la ficha guardada en el servidor.
* Fusionar las mallas de la casa propia (LOD 0) si resulta cara.
* Cuando el servidor guarde la ficha de cada casa (`to_dict()`), los vecinos reales reemplazan a los simulados con `IslandFakeHouses.card_for` ← ficha del servidor.
* Calles con tráfico, vida en la isla (la `NeighborhoodLife` de la Fase 8 no se conectó).

---

## 9. Qué quedó SIN correr

* **Todo GDScript**: no se ejecutó ni se compiló. Probable: errores de sintaxis/tipos al primer arranque (por ejemplo inferencia `:=` con valores `Variant`),
  nombres mal escritos, o algún método de API distinto en Godot 4.7. **Lo primero:** `godot --headless --path . --import` y `godot --headless --path . res://tests/test_island.tscn`;
  copiá el texto «FALLÓ: …» o el primer error rojo.
* Los dos shaders nuevos (`island_blocks.gdshader`, `island_map.gdshader`) tampoco se compilaron.
* `HouseView` dentro de `IslandWorld` (LOD 0) y en la prueba: se arma con el mismo patrón que `NeighborHouseView.set_interior`, pero no se corrió.
* Los presupuestos de la prueba (`≤ 150`, `≤ 16`, `< 60 mil`) son **estimaciones mías**: si la prueba falla por poco, ajustalos en el test, no en el código.
* Capturas: ninguna (no hay ventana). Se generan con la demo (`SHOT_DIR=docs/capturas`).
* Lo verificado con Python: `data/island.json` (válido, lotes sin encimarse/sin pisar calles/dentro de la isla con las mismas reglas que la prueba).

## 10. Cambios fuera de los archivos nuevos (para revisar en el merge)

* `scripts/camera/camera_rig.gd`: `enter_island_view`, `exit_island_view`, `in_island_view`, `camera_node` (todo nuevo, igual que el modo barrio; no cambia nada existente).
* `ui/hud.gd`: 2 líneas en `_build_info_extras` que llaman a `IslandTestEntry.add_to`. Para sacar la entrada del teléfono, borrar esas 2 líneas.
* `PROGRESO.md` (nota arriba), `DECISIONES.md` (sección corta) y `docs/riesgos-legales-ea.md` (sección «Isla 1A», dudas de la isla).
