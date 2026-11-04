# Pulido 3 (versión 0.10.0) — brief

Feedback del dueño después de probar el Pulido 2 (0.9.0) en la PC. Se trabaja en la
rama `pulido-3` (sale de `pulido-2`), con un push al terminar cada sub-fase
(3A, 3B, 3C). Sin merge a `main`, sin exportar APK. Todo con figuras simples,
catálogo y datos en `data/`, el dinero lo decide el servidor (si cambian las reglas
de la casa, también `server/nakama/modules/` y sus pruebas), la partida vieja se
migra (no se toca la del dueño en pruebas). Pruebas: todas las existentes (Godot
y Lua) más nuevas; demos con capturas en `docs/capturas/`.

## 3A: PARCELA, CAMINO Y OBSTÁCULOS
El Pulido 2 hizo accesible casi todo el terreno verde y la casa quedó lejos de la
calle. Se quiere:
- La zona disponible desde el inicio = el DOBLE de la parcela original de la Fase 1
  (tomar la medida de la Fase 1; si da distinto a 200x200 anotarlo en DECISIONES y
  usar el doble) en cada dirección, NO todo el terreno. Máximo con desbloqueos: el
  triple. El resto del verde queda fuera de límites (visible pero no accesible).
- Vallas de madera en los laterales de la zona disponible (reemplazables a futuro).
  Detrás de la valla de un lado, una casa de vecino simple y aleatoria (solo para
  ver silueta/sombra; en el futuro serán los vecinos reales del barrio; no hace
  falta que se visite).
- La casa va CERCA de la calle (no pegada) y la parte de la parcela inicial entre la
  casa y la calle queda LIBRE de obstáculos (sin árboles/piedras). Los obstáculos
  (árboles, rocas, lago) quedan en la zona por desbloquear y se quitan con los
  servicios ya hechos. Migración: casas y muebles de partidas viejas se trasladan
  para quedar en el mismo lugar relativo a la calle. Probarlo con una copia de la
  partida del dueño.
- El personaje debe ESQUIVAR los obstáculos (hoy se queda pegado a árboles y
  piedras): la navegación los rodea y se regenera al limpiarlos. Prueba automática:
  el personaje llega a una celda del otro lado de un árbol.

## 3B: INTERFAZ Y PERSONAJE
- Pantalla cortada: con la tienda abierta y al seleccionar un mueble, las barras de
  arriba y abajo se corren fuera de los bordes. Respetar siempre el área segura
  (`DisplayServer.get_display_safe_area()`) y que no se salgan en ningún tamaño;
  probar con 1920x1080, 1080x2400 y 2400x1080.
- Colocar un mueble: al comprar/elegir de la Tienda, poder rotarlo en el momento
  (botón de girar 45°) ANTES de confirmar, no solo después con Modificar.
- Techos: al elegir la herramienta de techo, la cuadrícula de selección SUBE a la
  altura de las paredes del piso actual (rejilla flotante) para tocar el área desde
  arriba sin que la pared tape ni tener que subir la cámara.
- Cámara, ángulo: control táctil nuevo: barra vertical en el costado derecho, DEBAJO
  del menú hamburguesa, con una perilla al centro. Arrastrar hacia abajo baja el
  ángulo, hacia arriba lo sube hasta la vista aérea máxima (de cielo). Al soltar la
  perilla vuelve sola al centro y el ángulo se queda. Funciona con mouse y dedo. Si
  lo reemplaza bien, quitar el botón viejo del ángulo.
- Maqueta 3D de pisos: las flechas (subir, bajar, girar) salen de la caja: la caja
  es solo para la casa en 3D y las flechas van FUERA, con un color más parecido al
  de la caja (azul/verde translúcido). Ocultar las aristas del fondo (hoy se ven los
  bordes de atrás como en un cubo transparente): dibujar solo las aristas del lado
  que se mira (depth test activo o descartar aristas cuya cara adyacente mira de
  espaldas a la cámara de la maqueta).
- Cuartos elegidos por el jugador: el juego sigue recomendando el tipo por los
  muebles, pero el jugador puede ASIGNAR a cada cuarto su tipo (cocina, dormitorio,
  baño, sala, estudio…). Tocar un cuarto (Modificar o el ícono de cuartos) abre un
  menú para elegir tipo y, si es dormitorio, si es el PRINCIPAL del personaje o uno
  secundario (solo un principal). Lo asignado manda sobre lo deducido. Se guarda en
  la partida (migración; en servidor solo si afecta algo que el servidor calcula).
  Dejar disponible algo como `Rooms.main_bedroom()`. Desaparece el nombre
  "Multiuso": en la Tienda, la pestaña con ★ pasa a llamarse "Recomendado" (con ★ y
  el tipo del cuarto actual, ej. ★ Dormitorio); si el cuarto no tiene tipo, muestra
  lo más común sin decir "multiuso".
- Creación de personaje al registrarse: tras crear la cuenta (primera vez), pantalla
  de creación de personaje básica (usar/ampliar `ui/character_editor.tscn`): nombre,
  peinado (3–5), ojos, boca, color de piel, color de pelo y de ropa, con vista previa
  que gira y botón "Listo" que entra al juego. Se puede cambiar luego desde el menú.
  Las opciones son datos en `data/` (no en el código) y el personaje se arma con
  piezas intercambiables (ver VISION.md, personalización total).

## 3C: ESTILO
- Contorno con costuras: el contorno toon es por pieza y, como cada pared está hecha
  de tramos, desde ciertos ángulos se ven líneas ENTRE tramos de una misma pared.
  Debe verse una pared continua: fusionar tramos contiguos de la misma pared en una
  malla o no dibujar contorno en las caras compartidas entre tramos vecinos del
  mismo tipo y altura. Medir que con contorno encendido no se rompa el objetivo de
  30 FPS (hay opción para apagarlo en Info).

Al terminar: resumen de lo hecho, qué falta y cómo probarlo en el teléfono, en
`PROGRESO.md`.
