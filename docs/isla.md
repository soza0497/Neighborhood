# Isla — diseño del mundo compartido (borrador)

Decidido por el dueño el 2026-11-04. El barrio de la Fase 8 (una calle y
24 lotes) pasa a ser una **isla tropical** con un parque en el centro. Este
documento es el plan: qué es, cómo se reparten las parcelas, cómo se mantiene
fluido y en qué orden se construye. **Los negocios y casi todo lo de abajo de
«Más adelante» NO se construyen ahora.** Ahora se quiere la **carcasa**: el
mapa, las parcelas, la propiedad y los niveles de detalle (LOD), para seguir
puliendo la construcción de casas.

## 1. La idea
- Una **isla grande** con un **volcán de fondo** (escenario, no se construye
  encima), una **playa con muelle**, y en el centro un **parque circular** (lago,
  glorieta, juegos, plaza). Alrededor del parque, el **anillo de comercios**
  (por ahora decorado y apagado). Detrás, **anillos de parcelas** con calles
  radiales y una avenida principal hacia el muelle.
- **Zonas** a futuro: aguas termales y actividades en la falda del volcán, playa,
  muelle y puerto, parque. El muelle deja la puerta abierta a otros terrenos
  (desierto, viajes) más adelante: **la isla es solo el primer tipo de mapa**.
- Estilo tropical (palmeras, techos de teja, mar), distinto de ciudades
  estilo Nueva York o europeas.
- Cada **isla** reúne unas **30 familias** al empezar (se prevé hasta 50 o 60).
  Cuando una isla se llena, el servidor crea otra.
- **Cada familia puede tener hasta 3 parcelas**: la gratuita y **2 más** (decisión del
  dueño, 2026-11-04). Para 30 familias, la isla tiene unas **90 parcelas**.

## 2. Parcelas
### Tamaños (a medir, ver §6)
| Tipo | Tamaño (celdas) | Quién la tiene |
|---|---|---|
| **Chica (S)** | 32 × 32 | La que el juego regala al empezar |
| **Mediana (M)** | 48 × 48 | Se compra |
| **Grande (L / premium)** | 64 × 64 | Se compra; junto a la playa, el lago o el parque |

- **Hasta 3 parcelas** por jugador: la gratuita + 2 adicionales (no hace falta que sean contiguas).
- **Cada parcela tiene un uso**: **Hogar** (casa de la familia) o **Negocio** (granja, tienda, restaurante, etc.).
  En una parcela de **Hogar no puede haber un negocio**: a lo sumo algo muy chico y suelto (un carrito de
  helados, un puesto), nunca estructuras de negocio. Quien quiere un negocio compra **otra parcela** y la
  declara de Negocio. El uso lo guarda y lo valida el servidor.
- **Los negocios no son del jugador por ahora**: los de la isla vienen ya creados (genéricos o propios de
  la isla). El jugador **no** puede crear su propio restaurante todavía; la opción «Restaurante» se oculta
  del menú hasta que exista el sistema de negocios (ver `VISION.md`).
- El tamaño de la parcela inicial es el de la Fase 1 (32), no el 64×64 de hoy:
  es lo que el dueño pidió (parcelas chicas). Los obstáculos y los servicios del
  Pulido 2C (árboles, rocas, limpieza) se conservan **dentro** de la parcela
  para ampliar la zona usable por nivel.
- **Valor por ubicación**: el precio base sale del tipo de parcela y su anillo
  (cerca de la playa o del parque, más caras). Fórmula y tabla en
  `data/island.json`, no en el código.

### Cómo se consigue una parcela
1. **Primera vez**: al crear la cuenta y el personaje, el jugador elige
   **crear una parcela nueva** (el servidor le asigna una chica libre de una isla
   con lugar; el juego se la **regala**) o **unirse a una isla** (con el código
   o la invitación de su pareja o de un amigo). La pareja comparte parcela
   (Fase 5).
2. **Comprar** parcelas más grandes o mejor ubicadas con dinero del juego. La
   compra la decide **el servidor** (propiedad y precio).
3. **Vender / dejar**:
   - **Vender la parcela con la casa**: el servidor le paga el valor de la parcela
     más una parte del valor de las piezas (ya existe la reventa del 50 %). La
     parcela queda **libre** (con su marcador) para otro jugador.
   - **Llevarse los materiales**: se borra todo con la devolución actual y la
     parcela queda libre. (Una opción de «guardar en bodega» queda para más
     adelante.)
   - Primera versión: solo se vende **al sistema**. Mercado entre jugadores,
     más adelante, con límites de precio y espera (anti-trampas).
- Las parcelas libres se ven como **terreno verde con un marcador** (como en la
  imagen de referencia), nunca como casas ya hechas.
- **Vecinos simulados** ocupan lotes mientras no haya jugadores reales (ya
  existen en la Fase 8). Cuando llega un jugador real a una isla, **reemplaza a
  un vecino simulado** del lote que le toca.

### Plantilla de casa (mudanza)
- El jugador puede **guardar una plantilla** de su casa: solo la **estructura** (cimientos, pisos, paredes con
  puertas y ventanas, techos, escaleras, pilares). **Sin muebles ni objetos.**
- Para **mudarse** o repetir el diseño en otra parcela, elige la plantilla y, al colocarla, se ve una
  **silueta como un holograma** de cómo quedaría (verde si cabe, roja si no). Se cobra como construir (pasa por
  el mismo plan y factura del servidor).
- Se guardan en la cuenta (varias, con nombre).

## 3. Cómo se mantiene fluido (LOD)
Regla de oro: **solo tu parcela está «viva»** (completa y editable). Lo demás se
ve como una **postal del exterior**.

| Nivel | Cuándo | Qué se carga |
|---|---|---|
| **LOD 0** | Tu parcela (o la que visitás) | Todo: piezas, muebles, personajes |
| **LOD 1** | Vecinos cercanos | Solo el **exterior**: paredes, techo, colores, puerta, piso a piso. Sin interior, sin muebles, sin objetos del jardín |
| **LOD 2** | Una calle o zona | Cada casa como **bloques simples** con su color y el tipo de techo (pocas mallas, agrupadas) |
| **LOD 3** | Vista de toda la isla | Un **mapa estilizado** (como una ilustración de la isla), no el 3D completo |

- **Ficha exterior** (`ExteriorCard`): cada casa genera, al guardarse, un resumen
  chico del exterior: forma por piso (huella), altura, tipo de techo, colores de
  paredes y techo, lado de la puerta. Pesa unos cientos de bytes. El servidor
  la guarda aparte para que **nadie descargue los muebles de otro jugador para
  ver su fachada** (privacidad y velocidad). LOD 1 y 2 se arman con la ficha.
- **Contorno toon apagado en LOD ≥ 2** (el contorno dibuja cada pieza dos
  veces).
- **Streaming por radio**: se carga lo que está cerca de la cámara y se
  descarga lo lejano. Vegetación repetida (palmeras, arbustos) con instancias
  agrupadas (`MultiMeshInstance3D`).
- **Límite de piezas por parcela** (regla de juego, a medir): evita megacasas
  desordenadas y protege los FPS.
- **Objetivo**: 30 FPS en un Android de gama media con la isla de 30 lotes,
  medido en el teléfono del dueño.

## 4. Datos (todo editable, nada escrito en el código)
`data/island.json` (nuevo; reemplaza y amplía `data/neighborhood.json`):
- Zonas: parque, anillo de comercios, anillos residenciales, playa, muelle,
  volcán (solo escenario).
- Calles: radiales y anillos como listas de puntos o arcos.
- Lotes: `id`, `ring`, `tier` (S/M/L), `center`, `size`, `facing`, `price`.
- Reglas: tamaños, precios base, multiplicadores por ubicación, tope de
  parcelas por jugador, límite de piezas.
Los lotes son **datos**: cambiar el diseño de la isla no cambia el código.

## 5. Servidor (Nakama)
Módulo nuevo `neighborhood_island.lua`: islas, lotes, dueños, asignación de la
parcela regalada, unirse por código, compra y venta, fichas exteriores. **La
propiedad y el dinero los decide el servidor**, como ya pasa con la casa.
Un jugador solo ve de los demás: nombre de la familia, ficha exterior y estado
«conectado»; **no** su dinero ni sus muebles.

## 6. Prueba técnica antes de construir (Isla 1A)
Antes de gastar tiempo en el diseño final: un **prototipo** con 30 lotes falsos
(casas generadas con el generador de la Fase 8), los 4 niveles de detalle y un
contador de FPS con modo de estrés (60 lotes). Sirve para **decidir**:
cuántas casas aguanta un Android de gama media, los límites del LOD y el tamaño
de parcela. **Si no se llega a 30 FPS, se cambian los tamaños y los límites
antes de seguir.**

## 7. Orden de trabajo
1. **Isla 1A – prototipo de rendimiento** (sin servidor).
2. **Isla 1B – datos y mapa**: `data/island.json`, calles circulares, parque,
   zonas, volcán de fondo y playa con figuras simples; migración desde el barrio
   actual de la Fase 8.
3. **Isla 1C – servidor**: islas, lotes, dueños, parcela regalada, unirse,
   compra y venta, fichas exteriores.
4. **Isla 1D – pulido**: LOD final, apagado del contorno, medición en el
   teléfono, ajuste de tamaños.
5. **Después, y NO ahora**: negocios en el anillo comercial, bancos, mercado
   entre jugadores, zonas (aguas termales, volcán), viajes y otros terrenos.

## 8. Cuidado legal (ver `docs/riesgos-legales-ea.md`)
- **The Sims 4: Island Living (Sulani)** ya tiene un archipiélago tropical con
  **volcán activo**, playas y lotes residenciales. **Isla tropical con volcán no
  es protegible por sí sola**, pero hay que **diferenciarse en lo que sí se
  protege**: nombres, personajes, íconos, diseños y la forma de jugar. Nada de
  «Sulani», nada de copiar sus lugares ni sus eventos del volcán (erupciones
  con rocas que incendian personajes, etc.).
- **Tomodachi Life: Living the Dream** (2026) y **Animal Crossing** son juegos de
  isla con vecinos. Se evita su mecánica propia (personajes tipo Mii, isla
  como espacio único de un solo jugador, calendarios de eventos iguales).
- **Heartopia** (juego móvil de vida con casas, parcelas y vecinos) ya tiene
  parcelas desbloqueables. Lo nuestro se diferencia en que **la isla es
  compartida por familias** y el mapa es un barrio ordenado en anillos.
- La imagen de referencia del dueño es **arte generado por IA**: sirve para
  la **distribución**, no como arte del juego (licencia incierta y estilo
  distinto).
- Nombres propios para la isla, el volcán y las zonas.

## 9. Preguntas abiertas
- ¿Tamaños finales de las parcelas (S/M/L)? Se deciden con la prueba 1A.
- ¿Cuántas piezas máximo por parcela?
- ¿La pareja comparte una sola parcela o cada uno puede tener la suya?
- ¿Qué pasa con una casa abandonada mucho tiempo (parcela que vuelve al pool)?
- ¿Nombre de la isla?
