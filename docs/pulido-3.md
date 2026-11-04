# Pulido 3 — Ajustes después de probar el Pulido 2 (0.9.0)

Pedido del dueño (2026-11-03, noche), después de correr la versión 0.9.0 en la
PC con su pareja. Parte de la rama `pulido-2` (ya subida). Se divide en
**3A (parcela y camino)**, **3B (interfaz y personaje)** y **3C (estilo)**;
cada una termina en algo que se pueda probar. Versión final: **0.10.0**.
Reglas de siempre: todo con figuras simples, el catálogo en `data/`, el dinero
lo decide el servidor, la partida vieja se migra, y se anota en
`DECISIONES.md` y `PROGRESO.md`.

---

## 3A — Parcela, camino y obstáculos

El Pulido 2 hizo accesible casi todo el terreno verde y la casa quedó lejos de
la calle. Lo que se quiere:

- **Zona disponible desde el inicio = el doble de lo que era antes del
  Pulido 2 (unos 200×200 de la medida vieja en cada dirección), no todo el
  terreno.** Calculalo con la medida de la parcela de la Fase 1; si da
  distinto a 200, anotalo en `DECISIONES.md` y usá el doble. Máximo posible
  con desbloqueos: el triple. El resto del verde queda **fuera de límites**
  (visible, pero no accesible).
- **Vallas de madera** en los laterales de la zona disponible (reemplazables
  más adelante). Detrás de la valla de un lado, una **casa de vecino** simple
  y aleatoria (solo para ver su silueta o sombra; en el futuro serán los
  vecinos reales del barrio). No hace falta que se pueda visitar.
- **La casa va cerca de la calle** (no pegada, pero cerca) y **la parte de la
  parcela del inicio entre la casa y la calle queda LIBRE de obstáculos**
  (sin árboles ni piedras). Los obstáculos (árboles, rocas, lago) quedan en la
  zona que se desbloquea: se quitan con servicios como ya está hecho.
  Migración: la casa y los muebles de partidas viejas se **trasladan** para
  que sigan en el mismo lugar relativo a la calle; probalo con la partida
  guardada del dueño (sin modificar su archivo en las pruebas).
- **El personaje esquiva los obstáculos**: hoy se queda pegado a árboles y
  piedras. La navegación debe rodearlos (y regenerarse al limpiarlos). Prueba
  automática: el personaje llega a una celda del otro lado de un árbol.

## 3B — Interfaz y personaje

### Pantalla cortada
- Con la **tienda abierta y al seleccionar un mueble**, la barra de arriba y la
  de abajo se corren y quedan **fuera de los bordes** de la pantalla. Respetar
  siempre el área segura (`DisplayServer.get_display_safe_area()`) y que las
  barras no se salgan de la ventana en ningún tamaño; probar con ventanas de
  1920×1080, 1080×2400 (vertical) y 2400×1080.

### Colocar un mueble
- Al comprar o elegir un mueble de la Tienda, se puede **rotar en el
  momento** (botón de girar 45° y la flecha de girar ya existentes) **antes de
  confirmar**, no solo después con Modificar.

### Techos
- Al elegir la herramienta de techo, **la cuadrícula de selección sube a la
  altura de las paredes** del piso actual (como una rejilla flotante arriba),
  para poder tocar el área desde arriba sin que la pared tape y sin tener que
  mover la cámara a la vista aérea.

### Cámara: ángulo
- Se mantiene el botón actual, pero se agrega un **control táctil nuevo**:
  una barra vertical en el costado derecho, **debajo del menú de hamburguesa**,
  con una perilla en el centro. Arrastrar la perilla hacia abajo **baja el
  ángulo** de la cámara y hacia arriba lo **sube**, hasta la **vista aérea
  máxima** (de cielo, mirando la casa desde arriba). Al soltar, la perilla
  **vuelve sola al centro** y el ángulo se queda donde quedó. Funciona con
  mouse y con dedo. El botón viejo del ángulo se quita si el control nuevo lo
  reemplaza bien.

### Mapa 3D de pisos (maqueta)
- **Las flechas (subir, bajar, girar) salen de la caja**: la caja queda solo
  para la casa en 3D, y las flechas van **fuera**, con un color más parecido al
  de la caja (azul/verde translúcido de la maqueta).
- **Aristas de atrás ocultas**: hoy se ven los bordes del fondo como en un
  cubo transparente y ensucia. Dibujar solo las aristas que dan al lado que se
  está mirando (las de las caras de frente), no las de la cara de atrás
  (probá: pintar las aristas con el depth test activado, o descartar las
  aristas cuya cara adyacente mira de espaldas a la cámara de la maqueta).

### Cuartos: el jugador los elige
- El juego sigue **recomendando** el tipo de cuarto por sus muebles, pero el
  **jugador puede asignar** a cada cuarto su tipo (cocina, dormitorio, baño,
  sala, estudio…). Tocar un cuarto (herramienta Modificar o el ícono de
  cuartos) → menú para elegir el tipo y, en el caso del dormitorio, si es el
  **principal** del personaje o uno **secundario**. Solo un principal.
  Lo que el jugador asigna **manda** sobre lo que el juego deduce. Se guarda
  en la partida (migración; en el servidor si el tipo de cuarto afecta algo
  que el servidor calcula; si no, solo en el guardado de la casa).
- **El nombre "Multiuso" desaparece.** En la Tienda, la pestaña con la
  estrellita pasa a llamarse **"Recomendado"** (con ★) y muestra los muebles
  del tipo del cuarto actual (por ejemplo ★ Dormitorio, si el cuarto está
  asignado así). Si el cuarto no tiene tipo, "Recomendado" muestra lo más
  común (sin decir "multiuso").
- Más adelante el personaje usará su dormitorio principal para dormir (no hace
  falta ahora, pero dejá el dato disponible: `Rooms.main_bedroom()` o similar).

### Creación de personaje al registrarse
- Después de **crear la cuenta** (primera vez), se abre una pantalla de
  **creación de personaje**, algo muy básico, con el editor existente
  (`ui/character_editor.tscn`) o uno nuevo: nombre, **peinado** (3–5
  opciones), **ojos**, **boca**, **color de piel**, color de pelo y color de
  ropa. Figuras simples (sin arte final) con vista previa que gira. Termina
  con "Listo" y entra al juego. Después se puede cambiar en el menú. Que cada
  opción sea un dato en `data/` (no escrito en el código) para que el arte
  futuro pueda reemplazarlas, y que el personaje se arme con **piezas
  intercambiables** (ver `VISION.md`, personalización total).

## 3C — Estilo

- **Contorno con costuras**: el contorno toon se arma por pieza, y como cada
  pared es un tramo individual, desde ciertos ángulos se ve el contorno
  **entre tramos** de una misma pared. Debe verse **una sola pared continua**:
  fusionar los tramos contiguos de la misma pared en una malla (o no dibujar
  contorno en las caras compartidas entre tramos vecinos del mismo tipo y
  altura). Medir que no baje de 30 FPS en el modo de contorno encendido (hay
  una opción para apagarlo en Info).

---

## Cómo se prueba (para el dueño)
- 3A: al abrir se ve la calle cerca de la casa y sin árboles al frente; hay
  vallas a los costados y una casa de vecino al fondo; el personaje rodea un
  árbol; no se puede salir de la zona; quitar obstáculos amplía la zona hasta
  el triple.
- 3B: tienda abierta con un mueble → las barras no se salen; rotar al
  colocar; el control de ángulo en el costado derecho; flechas del mapa afuera
  de la caja y sin aristas del fondo; "Recomendado" en vez de "Multiuso"; elegir
  dormitorio principal; crear cuenta nueva → pide crear el personaje.
- 3C: ver una pared larga desde un ángulo: sin líneas entre tramos.
