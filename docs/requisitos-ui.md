# Neighborhood — Requisitos de diseño de interfaz (UI/UX)

Documento para quien diseñe la interfaz del juego. Tú eres la diseñadora; el
cliente (el dueño del proyecto) da feedback, y el código lo escribe otra
persona. **No se pide arte 3D** (muebles, casas, personajes): solo interfaz.
Fecha: 2026-11-03. Versión del juego que se usó para este mapa: 0.9.0.

---

## 1. Qué es el juego (en un minuto)
Un juego móvil **caricaturesco** (personajes chibi, colores alegres, estilo
anime/toon). La persona **construye su casa**, vive en ella con un personaje,
la **comparte con su pareja**, monta un **restaurante** y, más adelante, forma
parte de un **barrio** con otras familias. Se juega en **Android, primero**,
con **una sola mano o dos pulgares**. Se ve la casa desde arriba, como una
maqueta que se puede girar.

**Tono de la interfaz:** amable, colorida, redondeada, clara. Que se entienda
sin leer. Nada de "pantalla de contabilidad".

## 2. Reglas que no se negocian
1. **No copiar otros juegos.** Existen simuladores de vida conocidos (por
   ejemplo Los Sims, Animal Crossing, Tomodachi Life, inZOI) y el cliente no
   quiere parecerse a ninguno. Se puede **estudiar** cómo resuelven problemas
   de usabilidad, pero **no** copiar: ni su iconografía, ni sus formas
   (por ejemplo el rombo verde sobre la cabeza), ni los mismos nombres de
   menús, ni la misma distribución de barras. Las ideas de *funcionalidad*
   no se protegen, pero el *diseño* sí. Si dudás, cambialo.
2. **Todo con íconos, poco texto.** El texto ayuda, no explica.
3. **Pantalla casi vacía** mientras se juega: lo que no se usa, se esconde.
4. **Que se pueda tocar con el pulgar** (zona inferior y los costados) y que
   nada importante quede tapado por el dedo.
5. **Respetar el área segura** del teléfono (notch, esquinas redondeadas,
   barra de gestos). Nada puede quedar cortado en ninguna pantalla.
6. **Nada castiga por desconectarse.** Nunca avisos de "¡vuelve ya!".

## 3. Pantallas de teléfono a considerar
Diseñar para estos tamaños (en píxeles, orientación **horizontal** primero;
la vertical se evalúa después):
| Dispositivo | Tamaño |
|---|---|
| Teléfono normal | 2400 × 1080 |
| Teléfono corto | 1920 × 1080 |
| Tableta (opcional) | 2560 × 1600 |

Áreas táctiles mínimas: **48 × 48 dp** (unos 9 mm). Texto mínimo legible:
**14 sp** en mensajes, **18 sp** en botones. Contraste suficiente sobre un
fondo que cambia (la casa se ve detrás): usar fondos oscuros translúcidos
(como ahora) o bordes.

## 4. Mapa completo de lo que hay hoy (0.9.0)
Cada fila es una pantalla, menú o elemento. "Existe" = ya está en el juego con
un diseño **provisional** hecho por el programador (feo a propósito: es lo que
se quiere mejorar).

### 4.1 Entrada y comienzo
| # | Pantalla | Qué tiene | Estado |
|---|---|---|---|
| E1 | **Inicio de sesión / crear cuenta** | usuario, contraseña, botones "Entrar" y "Crear cuenta", "Jugar sin conexión", mensaje de error, indicador de conexión | existe |
| E2 | **Creación de personaje** (primera vez) | nombre, peinado, ojos, boca, color de piel, pelo, ropa, vista previa que gira, "Listo" | **nueva: hay que diseñarla** |
| E3 | **Menú principal / pantalla de carga** | logo, "Continuar", ajustes | falta |

### 4.2 Mientras se juega (HUD)
| # | Elemento | Qué muestra | Estado |
|---|---|---|---|
| H1 | **Barra superior izquierda** | dinero, nivel y barra de experiencia | existe |
| H2 | **Ánimo** | carita + palabra ("Feliz", "Desanimado"); al tocar: tarjeta con 4 necesidades (comida, energía, limpieza, diversión) y por qué está así | existe |
| H3 | **Deshacer / Rehacer** | dos botones | existe |
| H4 | **Hogar / Ir a casa** | botón de casa | existe |
| H5 | **Menú hamburguesa** | abre el menú lateral (ver 4.3) | existe |
| H6 | **Velocidad** | x1 / x2 / x5 | existe |
| H7 | **Mapa 3D de pisos (maqueta)** | casa chiquita translúcida con los pisos, punto parpadeante del personaje, flechas para subir/bajar y girar, nombre del piso | existe; **le pedimos cambios** |
| H8 | **Brújula / centrar** | vuelve la cámara al personaje | existe |
| H9 | **Ángulo de cámara** | botón (y un control nuevo tipo palanca: ver 5.4) | existe/nuevo |
| H10 | **Techo sí/no y paredes altas/bajas** | dos íconos | existe |
| H11 | **Avisos (toasts)** | mensajes cortos arriba ("Quedó previsto…") | existe |
| H12 | **Indicador de pareja** | punto de color + nombre | existe |
| H13 | **Burbujas sobre el personaje** | qué está haciendo o necesitando | existe |

### 4.3 Menú lateral (hamburguesa)
Hoy abre una lista: **Info** (versión, FPS, conectado, hora, caja de la casa,
interruptor del contorno), **Pareja**, **Casa**, **Restaurante**,
**Empleos**, **Diario**, **Sonido**, **Cerrar sesión**. Hay que decidir el
orden, qué es ícono y qué es texto, y si algunos pasan a otro lugar.

### 4.4 Modo construir y comprar
| # | Elemento | Qué tiene | Estado |
|---|---|---|---|
| C1 | **Selector de modo (barra de abajo)** | tres herramientas: Tienda, Obra, Borrar | existe |
| C2 | **Tienda** | pestañas ("Recomendado ★", Muebles, Electrodomésticos, Electrónica, Plantas, Adornos, Restaurante), tarjetas con color, nombre y precio | existe |
| C3 | **Colocar mueble** | marca en el suelo (verde si cabe, rojo si no), girar 45°, mover con flechas, confirmar/cancelar | existe; **se pide rotar al colocar** |
| C4 | **Obra → Construir** | cimientos, pisos, paredes, puertas, ventanas, techos, escaleras, pilares, pintura | existe |
| C5 | **Obra → Modificar** | tocar algo: mover, rotar, pintar, borrar; puntitos de unión de ventanas | existe |
| C6 | **Obra → Borrar** | selección múltiple, "Borrar N cosas · te devuelven $X" | existe |
| C7 | **Pintura** | paleta de colores, flechas izquierda/derecha para la pared vecina | existe |
| C8 | **Agregar piso / sótano** | botones separados con advertencias | existe |
| C9 | **Plan y factura** | vista previa que brilla, lista de lo que cuesta, "Factura" | existe |
| C10 | **"Lo que falta"** | lista de problemas (sin apoyo, sin acceso) con piezas en rojo | existe |
| C11 | **Cuartos** | asignar tipo de cuarto (cocina, dormitorio, baño…) y dormitorio principal | **nuevo: hay que diseñarlo** |
| C12 | **Servicios y entregas** | llamar camión de entrega, ambulancia, limpieza de obstáculos; lista de pendientes con tiempo; "Abrir todas las cajas" | existe |

### 4.5 Paneles (ventanas sobre el juego)
| # | Panel | Qué tiene | Estado |
|---|---|---|---|
| P1 | **Pareja** | invitar, aceptar, casarse, estado de conexión, billeteras, "unir ingresos" | existe |
| P2 | **Casa compartida** | caja común, aportar, propuestas de remodelación con "Aprobar / Rechazar" y vista previa | existe |
| P3 | **Empleos** | ofertas, currículos con espera, "Ir a trabajar" | existe |
| P4 | **Restaurante** | ganancias, recoger dinero, estado, botón del minijuego | existe |
| P5 | **Minijuego "Servicio"** | completar órdenes en 1:30, puntaje | existe |
| P6 | **Diario / Info del personaje** | rasgos, necesidades, historial | existe |
| P7 | **Ajustes** | sonido, contorno (efecto visual) sí/no, mostrar FPS, cerrar sesión | parcial |

### 4.6 Estados que casi nadie diseña (pero hay que pensarlos)
Cargando · sin conexión · error de servidor · "no alcanza el dinero" · lista
vacía (por ejemplo sin ofertas de empleo) · confirmar una acción que no se
puede deshacer · primera vez (tutorial / pistas) · pantalla cuando el teléfono
está en vertical.

## 5. Pedidos concretos del cliente (hay que resolverlos en el diseño)
1. **Rotar mientras se coloca.** Al comprar o elegir un mueble, se debe poder
   girarlo ahí mismo, antes de ponerlo. (Observación de la diseñadora.)
2. **Barras arriba y abajo** no deben salirse de la pantalla al abrir la
   tienda o elegir un mueble.
3. **La maqueta 3D de pisos:** la caja debe ser solo para la casa; las flechas
   (subir, bajar, girar) deben estar **fuera** de la caja y con un color
   parecido al de la caja. Se ven demasiado los bordes del fondo.
4. **Control de ángulo de cámara:** una **barra vertical en el costado
   derecho**, bajo el menú hamburguesa, con una **perilla en el centro**:
   arrastrar hacia abajo baja el ángulo, hacia arriba lo sube (hasta ver la
   casa desde el cielo), y al soltar **vuelve al centro** y el ángulo queda
   donde estaba. Proponer cómo se ve y cómo se siente.
5. **Techo:** que la cuadrícula suba a la altura de las paredes para poder
   elegir el techo sin cambiar el ángulo.
6. **Cuartos y "Recomendado":** reemplazar "Multiuso" por **"Recomendado"**
   (con ★ y el tipo de cuarto). El jugador elige el tipo de cada cuarto y
   cuál es el **dormitorio principal**.
7. **Creación de personaje:** muy básica pero agradable: peinado, ojos, boca,
   color de piel, pelo y ropa. Más adelante crecerá a "personalización total"
   (furro, lobo, robot…), así que diseñá pensando en que **entren más
   categorías** sin rehacer la pantalla.
8. Pensar **cuántas cosas caben** en el menú de Obra y cómo se agrupan, para
   que no sea una fila interminable.

## 6. Qué tiene que entregar la diseñadora

### Entregable A — Investigación (primero)
Una página o presentación con: referencias estudiadas (qué patrón resuelve
cada problema, no capturas para copiar), principios elegidos para este juego
y una **paleta** inicial.

### Entregable B — Sistema de diseño básico
- **Paleta** (colores principales, de estado y de las 4 necesidades; ahora:
  comida `#ff9f43`, energía `#feca57`, limpieza `#54a0ff`, diversión
  `#ff6b9d`).
- **Tipografía** (una fuente redondeada y legible, **con licencia libre**,
  por ejemplo de Google Fonts) y tamaños.
- **Componentes**: botón (normal/presionado/desactivado), botón de ícono,
  tarjeta de tienda, barra de progreso, ventana/panel, aviso, pestañas,
  interruptor, perilla/control deslizante.
- **Íconos**, todos del mismo estilo (ver sección 7).

### Entregable C — Pantallas
Diseño de las pantallas de la sección 4, **en este orden de prioridad**:
1. Juego principal (H1–H13) y menú de Obra/Tienda (C1–C6).
2. Creación de personaje (E2) y cuartos (C11).
3. Inicio de sesión (E1) y menú lateral (4.3).
4. Paneles (P1–P7) y servicios (C12).
5. Estados vacíos y errores (4.6).

Para cada pantalla: versión horizontal 2400×1080 (y 1920×1080 para ver
qué se corta). Marcar **zonas táctiles** y **qué se esconde** y cuándo.

### Entregable D — Prototipo (opcional)
Un prototipo navegable en Figma para recorrer: crear cuenta → crear
personaje → jugar → comprar un mueble → construir.

## 7. Formato de entrega de los íconos y las imágenes
- **Íconos: SVG**, 64 × 64, **un solo color blanco (#FFFFFF)** con trazo
  redondeado (así el juego los tiñe de cualquier color). Hoy los íconos
  provisionales son de trazo grueso (`stroke-width 5`, puntas y uniones
  redondeadas). Ver `assets/icons/` para el estilo actual (son ejemplos, se
  pueden rehacer completos).
- Si un ícono necesita **dos colores** (por ejemplo la carita del ánimo),
  entregarlo como SVG a todo color y avisar.
- Nombres en **inglés, minúsculas y con guion bajo**: `shop.svg`,
  `roof_off.svg`.
- **Fondos y paneles:** PNG con transparencia o, mejor, **9-slice** (una
  imagen que se estira por el centro y no por las esquinas). Entregar a 2×.
- **Fuente:** `.ttf` u `.otf` con su archivo de licencia.
- **Figma:** compartir el archivo con permiso de lectura al cliente; usar
  estilos y componentes (no capturas sueltas).
- Cada ícono necesario está en la lista de pantallas; si falta uno, se agrega.

Tamaño del equipo: una sola persona programando. Lo que sea más simple de
hacer en el motor (Godot 4) se hace más rápido; si un efecto es difícil
(degradados complejos, desenfoques), avisar el costo.

## 8. Cómo trabajar (proceso sugerido, como si fuera un cliente real)
1. **Brief:** leer este documento y escribir de vuelta con tus palabras qué
   entendiste y qué dudas tenés (mandarlas por escrito antes de empezar).
2. **Investigación** (entregable A). Reunión corta para validar dirección.
3. **Sistema de diseño** (B) y **2 o 3 direcciones** de estilo para elegir.
4. **Pantallas** (C) en el orden de la sección 6; entrega por tandas con
   feedback entre cada una.
5. **Prueba en el teléfono**: ver las pantallas en el celular real a tamaño
   real (Figma Mirror o exportar a imagen). Muchas cosas "lindas" no se tocan
   bien.
6. **Entrega final** con archivos en los formatos de la sección 7 y una
   lista de qué se cambió respecto a lo anterior.

El diseño no se espera perfecto a la primera: se pide **buena
organización y razones**. Cada decisión debería poder explicarse con "esto
resuelve tal problema".

## 9. Por dónde empezar a investigar (diseño de interfaz para juegos)
Venís de interfaces web; los juegos cambian algunas reglas. Ideas:
- **Búsquedas útiles:** "mobile game UI design principles", "game HUD
  design", "thumb zone mobile games", "mobile game UX onboarding", "game UI
  icon design", "9-slice UI game", "safe area mobile game UI".
- **Sitios de referencia:** Game UI Database (gameuidatabase.com) para ver
  pantallas de muchos juegos por categoría; Interface In Game
  (interfaceingame.com); charlas de **GDC Vault** sobre UI/UX de juegos
  móviles (muchas son gratis); el canal de YouTube **Game Maker's Toolkit**.
- **Material oficial para móvil:** guías de **Material Design** (tamaños
  táctiles) y **Android Developers → Insets/Cutouts** (áreas seguras).
- **Mirar cómo resuelven** (pero sin copiar) juegos de construcción,
  cocina, gestión y "de pasar el tiempo" en móvil. Preguntas útiles al mirar
  cada uno: ¿qué tiene siempre en pantalla?, ¿qué esconde?, ¿cómo cambia de
  modo?, ¿cuántos toques cuesta comprar algo?, ¿cómo evita tapar la escena?
- **Íconos:** estudiá cómo hacer una familia consistente: misma grilla,
  mismo grosor de trazo, mismas esquinas. Herramientas: Figma (con
  *Iconify* o *Material Symbols* como referencia de grilla, **no para
  copiar**) y SVG exportado con trazos convertidos a contornos si hace falta.
- **Accesibilidad:** contraste (WCAG AA como mínimo), no usar solo el color
  para comunicar (agregar forma o ícono), texto no demasiado chico.
- **Probar con personas:** darle el prototipo a 2 o 3 personas sin
  explicarles nada y ver dónde dudan. Eso vale más que cualquier regla.
- **Cuidado legal:** guardá las referencias en una carpeta aparte, y cuando
  algo se parezca demasiado a una de ellas, cambialo antes de entregarlo.

## 10. Preguntas abiertas para decidir juntos
- ¿Horizontal solamente o también vertical? (Hoy: horizontal.)
- ¿La Tienda es una barra de abajo, un panel lateral o una ventana grande?
- ¿Cuántos toques como máximo para comprar y colocar un mueble?
- ¿Estilo de la interfaz: más "caricatura", más "papel" o más "cristal"?
- ¿Pestañas de la Tienda con ícono, con texto o ambos?
- ¿El menú lateral es una lista, una rejilla de íconos o un abanico?
