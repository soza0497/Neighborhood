# Pulido 2 — pendientes (después de la Fase 6)

Lo que el dueño notó probando el APK 0.7.0 (2026-11-03). **No se empieza
todavía.** Orden decidido por el dueño:
1. Termina la Fase 6 (en la nube) y el dueño prueba su APK.
2. El dueño manda su feedback de la Fase 6.
3. Se juntan esta lista + ese feedback y se hace el Pulido 2.

---

## Errores (arreglar sí o sí)
- **Los techos no se pueden borrar.** Hay una porción de techo de una
  edición vieja que no se borra de ninguna forma.
- **El basurero** borra muebles, pero no las otras piezas (techos, paredes,
  cimientos…). Tiene que borrar todo, con resaltado y confirmación.
- **El menú hamburguesa no se cierra** si no se elige una opción (Personaje,
  Diario…). Tiene que cerrarse al tocarlo otra vez o tocar afuera.
- **Aparece un tercer piso** en una casa de dos. No tiene que existir un piso
  vacío "de regalo": ver "Agregar piso" abajo.

## Selector de pisos: el frente de la casa
Lo de ahora (maqueta vista de arriba con las paredes) **no** es lo pedido.
- Un **dibujo del frente de la casa**, como una foto de la fachada que da a
  la calle, un poco girado a la izquierda o derecha para que se note el 3D.
- Solo lo de afuera: contorno, **puerta y ventanas dibujadas**, techo. Nada
  del interior.
- Estilo figura geométrica **azul semitransparente** (tipo holograma, sin
  efectos).
- Cada piso con un **color distinto**; el piso actual resaltado y el punto
  que parpadea donde está el personaje. Tocar un piso = ir a ese piso.
- **Flechitas arriba / abajo** al lado, por si la casa es difícil de tocar.
- **Botoncitos para girar** la fachada (8 ángulos). El juego recuerda el
  último ángulo que eligió el jugador.

## Pisos: agregar, sótanos
- **"Agregar piso"** como opción aparte en Obra (no un piso vacío que aparece
  solo).
- Si todo el piso de arriba está tapado por techo, avisar: "Para agregar un
  piso tiene que haber una parte sin techo".
- **Sótanos: hasta 3 pisos hacia abajo** (5 para arriba ya está). Antes de
  los cimientos de un sótano hay que **excavar** (paso aparte, con su costo y
  tiempo).

## Herramientas de Obra
Tres modos con íconos claros:
- **Construir**: llave inglesa y martillo cruzados. Para agregar cosas nuevas.
- **Modificar**: cruz de flechas. Mover, girar, pintar lo que ya está.
- **Borrar**: basurero (que funcione con todo, ver Errores).

## Construcción planificada, con factura y entrega
- Lo que se agrega queda como **prevista**: se ve tal cual, pero **brilla**
  cada pocos segundos para que se sepa qué es nuevo.
- Al terminar, un **resumen tipo factura**: qué se agregó y cuánto cuesta.
  Confirmar → si vive con la pareja, ella aprueba (Fase 5 / Pulido 1) → corre
  el tiempo de espera.
- **Entrega**: llega un **camión** por la calle y un **repartidor** baja las
  cajas y deja **una caja en el lugar de cada cosa**. Animación graciosa: si
  trae 3–5 cajas apiladas, en la puerta se le inclinan y se le caen, y las
  lleva de a una.
- Botón **"Abrir todas las cajas"**. El personaje va a cada caja, la abre,
  sale **humo blanco**, el personaje **tose**, y aparece el mueble. Si no se
  le ordena, las abre cuando quiera (su IA).

## Servicios (personas y vehículos que llegan)
Modelos simples por ahora, animación simple; se mejoran en la Fase 7.
- **Ambulancia**: si el personaje se lastima, llega, lo revisan y lo curan.
- **Repartidor** con camión: compras (ver arriba).
- **Cuadrilla de limpieza de terreno** (jardineros / leñadores) y **vehículo
  pesado** (tractor o retroexcavadora) para árboles grandes, rocas, laguito.
- **Acceso**: si el trabajo necesita que el vehículo entre a la parcela y no
  hay camino libre hasta el lugar, el servicio avisa que no puede entrar. Si
  solo hace falta la persona, el personaje del jugador le abre la puerta.
  Así el jugador decide si deja paso para vehículos.

## Parcela más grande, que se gana limpiando
- La parcela crece **100% hacia cada lado** (el doble de ancho y de fondo
  hacia todos los lados).
- **Es del jugador desde el principio**, pero la parte nueva está llena de
  **árboles, rocas y un laguito** que bloquean construir ahí.
- Para limpiarla se contrata a los servicios de arriba (cuesta dinero y
  tiempo; el servidor cobra). No es "comprar terreno por cuadros".

## Entorno
- La parcela **del mismo color** que el resto del terreno (no más claro).
- El límite se nota por la **naturaleza**: bosque atrás y a los lados, o
  casas de vecinos atrás.
- **Niebla en los bordes** del mapa: que no se vea dónde termina la calle ni
  los costados azules.

## Cámara e interfaz
- Poder elegir el **ángulo vertical** de la cámara: desde **de frente** (casi
  horizontal) hasta **desde arriba** del todo, pasando por el de ahora.
- **Margen** entre los íconos y los bordes de arriba y abajo de la pantalla
  (los costados están bien). En el menú de construir, un poco menos.
- La interfaz todavía confunde ("uno se pierde rápido"): revisar los íconos
  y lo que hace cada botón. Los íconos de techo y paredes gustaron mucho:
  mantener ese estilo.

## Notas
- Ideas de vida diaria y eventos graciosos siguen en `VISION.md`.
- Choques legales con otros juegos: ver `docs/riesgos-legales-ea.md` y la
  sección "Otros juegos" que se agregue ahí.
