# Pulido 6 (versión 0.13.0) — feedback del dueño sobre la 0.12.0

Probado en el teléfono el 2026-11-04. Se divide en tres áreas que tocan archivos distintos para poder
trabajarlas en paralelo (una rama por área). Reglas de siempre: figuras simples, datos en `data/`, dinero
decidido por el servidor, partida vieja migrada, pruebas Godot y Lua nuevas, demos con capturas.
Mantener los menús dentro del borde del teléfono (área segura) en TODOS los paneles.

## 6A. CONSTRUCCIÓN Y CASA (rama `pulido-6a`)
Archivos probables: `scripts/house/*`, `ui/build_bar.*`, `ui/home_panel.*`, catálogo.
1. **Pintura**: es el peor bug.
   - Pasa a ser su PROPIO botón en la barra de construcción (hoy está dentro de «mover»). Sale también en Tienda si hace falta.
   - La pared tiene cara interior y cara exterior: pintar una no pinta la otra, y sin franjas ni choques entre el color de adentro y el de afuera.
   - El grosor superior de la pared (el canto que se ve desde arriba) NO se pinta: usa el color neutro de la pared.
   - Al colocar una pared nueva, hereda el color que ya tenga el lado exterior (o el color elegido).
2. **Iconos y orientación**:
   - Comprar = símbolo de dólar (no bolsa). Modificar/Construir = lápiz (no la bandeja).
   - Al mantener presionado un botón sale un tooltip con su nombre. Además, un título arriba de la barra con el menú actual (Comprar, Construir, Mover, Pintar…).
   - El botón de centrar cámara no puede tapar la barra de construcción.
3. **Sótano y pisos nuevos**:
   - Agregar un piso o sótano NO ocurre con un toque suelto: va en el menú de construcción y pide confirmar.
   - El sótano se ve oscuro (café muy oscuro) con una GUÍA de la casa de arriba (silueta) para saber dónde construir, y solo se puede excavar bajo la casa.
   - Efecto hueco: se ven las paredes del fondo y NO las del frente (las que tapan la vista), para dar sensación de estar en un hoyo.
4. **Cimientos sobre obstáculos**: no queda «lo rojo no se pone». Al confirmar cimientos sobre árboles o rocas, se llama a los servicios para retirarlos (ver 6B) y los cimientos de esa zona se colocan solos al terminar. Nada de rellenar celda por celda.
5. **Cuadrícula** solo dentro de la valla (la parcela usable). Fuera de la valla no se dibuja (es la zona por desbloquear: se ve, no se cuadricula).
6. **Muebles afuera**: los objetos que lo permiten (mesa, banca, planta…) se pueden poner fuera de la casa, sobre el terreno. Paredes, ventanas y puertas siguen necesitando estructura. Marcarlo con un dato del catálogo (`outdoor: true`).
7. **Mantener presionado un mueble**: el juego elige el mueble más cercano al dedo y muestra un mini menú con flechas alrededor para mover (por la cuadrícula) y para rotar, sin entrar al menú de construcción.
8. **Mover la casa entera**: con un costo, a otra posición de la parcela (el material no se pierde). Comparte la lógica de plantilla (5E).
9. **Plantillas**: dejar donde están (en Casa) por ahora.
10. **Maqueta 3D de pisos**: en la esquina del segundo piso, sobre el techo del primero, sale un «hueco» que no existe en la casa real (ver captura del dueño). Buscar por qué y corregirlo.
11. **Contorno**: el dueño lo ve feo. Probar un contorno más fino y ofrecer el interruptor en Info (ya existe) con tres opciones: fino, normal, apagado.

## 6B. SERVICIOS, PERSONAJE Y ACCIDENTES (rama `pulido-6b`)
Archivos probables: `scripts/character/*`, `scripts/parcel/*` o servicios, `scripts/debug/*`, `ui/dev_panel.*`.
1. **Servicio de limpieza (leñador, etc.)**:
   - Llega EN VEHÍCULO desde un extremo del mapa, por su carril, y se estaciona junto a la acera frente a la parcela. No aparece de la nada.
   - Se baja, camina al obstáculo, trabaja; el árbol cae con animación (rueda un poco) y desaparece en cuanto termina el corte, no después de que él se va.
   - Piedra y lago: igual, con la máquina que corresponda. Varios obstáculos pedidos juntos: un mismo equipo los atiende uno tras otro; si son de tipos distintos llegan varios vehículos a la vez.
   - Los vehículos no se atraviesan: si ya hay uno estacionado, el siguiente busca otro lugar. Si vienen por la izquierda, usan su carril y se estacionan de su lado de la calle; si el lugar útil está al otro lado, no dar vuelta en U (se estacionan donde puedan).
   - La espera (cooldown) viene de `data/parcel.json`; mostrarla en el menú («llega en X s»).
2. **Llamar al servicio desde «Eliminar»**: ya no sale el menú de servicios al tocar un árbol sin querer. Se elige en Eliminar, pudiendo marcar varios obstáculos y confirmar una sola vez.
3. **Ambulancia**: al volver el paramédico no debe atravesar postes de luz; la maniobra de salida usa la misma navegación que las demás (no retrocede por encima de objetos).
4. **Movimiento del personaje**: hoy se siente en 4 direcciones. Caminar en cualquier dirección con suavizado de giro (8+ direcciones).
5. **Charco**: que haga efecto (resbalar) cuando el piso es resbaloso, y también frente a la puerta si hay piso de adentro. Debe ser una regla por objeto.
6. **Accidentes por elemento**: cada elemento del catálogo declara sus posibles accidentes y condiciones (datos, no código). Ejemplos: puerta con piso a ambos lados = sin accidente; puerta con piso de un lado y vacío del otro = caída; charco = resbalón; sartén = quemadura.
7. **Puertas que se abren**: animación de abrir, siempre hacia el lado en que se colocó (un solo sentido). El personaje la usa al pasar.
8. **Modo desarrollador**:
   - «Ir hasta aquí»: respetar el piso y el punto que se toca (hoy siempre baja a planta baja).
   - Su menú flotante NO se ve al entrar al modo construir.
   - El panel nunca se sale de la pantalla (tamaño máximo = área segura, con scroll).
9. **Expresiones, no diálogos**: reemplazar los diálogos por una nubecita estilo cómic con expresiones y emoticonos; más variedad. Tono de «monigotes graciosos», no de gente real.
10. **Animación de caída**: pulirla (hoy se ve tosca).

## 6C. INTERFAZ Y CÁMARA (rama `pulido-6c`)
Archivos probables: `ui/hud.*`, `scripts/camera/*`, `scripts/neighborhood/*`.
1. **Botón de estado**: a veces no abre el pop-up (muestra el estado pero no responde). Encontrar la causa (probablemente otro control encima o desactivado) y corregirla.
2. **Panel de servicios** y cualquier otro: dentro del área segura siempre (se sale por la esquina superior izquierda).
3. **Botón de centrar cámara**: pasa arriba, junto a casa y paredes bajas. Tiene un solo botón con dos modos: LIBRE y SIGUIENDO al personaje. Si el personaje se va a trabajar, vuelve solo a libre.
4. **Cámara con ángulo bajo**: avanzar con un dedo se siente muy lento. Equilibrar: el paneo no debe caer tanto cuando el ángulo es bajo (mantener la lógica de distancia, subir el factor vertical).
5. **Menús**: aún se ve una «montañita» del botón de atrás sobresaliendo encima del menú abierto. Los menús abiertos tapan por completo lo que hay detrás.
6. **Nombres sobre las casas de los vecinos**: quitarlos. Al tocar una casa sale su nombre (y, más adelante, opciones).
7. **Info**: en «Herramientas de prueba» hay una prueba de rendimiento de la isla (ver abajo).

## ISLA (no entra en estas ramas; ver `docs/isla.md`)
Hallazgos de la prueba de rendimiento en el teléfono: 60 FPS estables salvo parpadeos al cambiar de LOD
(100 casas en LOD 1: baja a 15 un instante; LOD 2: a 38). Observaciones de diseño del dueño anotadas en
`docs/isla.md` §10 (parcelas no cuadradas, comprar desde un menú, zoom con 3 niveles tipo postal).
Bug de la demo: la opción «Medir» deja la interfaz rota y una parcela amarilla; corregir cuando se retome.

## Orden sugerido
6A y 6C primero (lo que más se nota al jugar), 6B después (es lo más grande). Las tres ramas parten de `main`
y se unen una por una; los conflictos previstos son `ui/hud.*`, `ui/build_bar.*` y PROGRESO/DECISIONES.
