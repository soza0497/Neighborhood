# Guía de arte para el dueño

Borrador (2026-11-04). Es un punto de partida, no una regla: el arte va a
cambiar muchas veces hasta que te guste. La versión final de las reglas
técnicas va en `docs/estilo.md` (Fase 7), después de probar con piezas reales.

Lo que se dice de herramientas externas sale de búsquedas web (muchas son
blogs de las propias empresas). **Probá cada herramienta con una pieza tuya
antes de comprometerte**, y leé sus condiciones de uso comercial antes de
publicar.

---

## 1. El objetivo visual
Personajes y casas que **de frente parecen dibujados en 2D aunque sean 3D**
(la sensación de los juegos de anime). Se logra con tres cosas, ninguna es un
modelo complicado:
1. **Contorno** negro de grosor propio alrededor de todo (lo pone el shader,
   **no se modela**).
2. **Sombras duras** en 2 o 3 tonos, no degradados.
3. **Paleta fija** de colores alegres, y luz cálida.

Por eso el arte se puede hacer simple: **formas redondeadas, pocos polígonos,
colores planos**. El shader los une en un solo estilo. (El Pulido 2 deja el
shader hecho; en teléfono hay que medir los 30 FPS, porque el contorno por
geometría dibuja las piezas dos veces.)

## 2. Qué aprender y en qué orden (3 meses, sin apuro)
Blender (modelar) y Krita (colorear, íconos, texturas) son gratis y están en
los repositorios de CachyOS. Ejercicios, de fácil a difícil:
1. **Una caja bien hecha**: una silla, una mesa y una cama con bordes un poco
   redondeados (bisel) y **un material de color plano por pieza**.
2. **Un cuarto armado** con 8 o 10 de esas piezas, vistas en el juego.
3. **Un objeto con partes que se mueven o se quitan** (una mesa con y sin
   sillas).
4. **El personaje chibi** (lo más difícil: esqueleto y animaciones). Hacerlo
   al final, y mirar primero cómo están hechos los de los paquetes gratis.

Tip: no empieces por el personaje. Empezá por **muebles**: hay muchos, son
simples y con ellos se aprende todo el recorrido hasta verlos en el juego.

## 3. Herramientas

| Herramienta | Para qué | Costo | Ojo con |
|---|---|---|---|
| **Blender** | Modelar, esqueletos, animar, exportar `.glb` | Gratis | Curva de aprendizaje; es lo central |
| **Krita** | Colorear, texturas, íconos, ideas | Gratis | — |
| **Figma** | Diseñar la interfaz (pantallas, botones) | Gratis (plan básico) | Inspirarte sin copiar; los íconos se pasan a SVG |
| **VRoid Studio** | Crear personajes estilo anime con sliders | Gratis | Sus guías permiten uso comercial de lo que trae, pero revisá la licencia de lo que descargues de terceros. Los modelos suelen salir pesados (muchos polígonos y materiales) y hay que simplificarlos. Sale como VRM → se pasa por Blender → `.glb` |
| **Meshy / Tripo** | Convertir una imagen tuya en un modelo 3D, a veces con esqueleto | De pago (con plan gratis limitado) | Las guías los ponen como los más usados para juegos, con modo de pocos polígonos. **Usá siempre una imagen de referencia tuya** (nunca arte de otros juegos). Revisá si el plan que uses permite uso comercial. Hay que ajustarlos en Blender |
| **Hunyuan3D / TRELLIS 2** | Lo mismo, pero corriendo en tu propia PC | Gratis (código abierto) | Piden una buena tarjeta gráfica. Hunyuan3D tiene una licencia que excluye algunas regiones (UE, Reino Unido, Corea del Sur) según una de las fuentes; TRELLIS 2 se anuncia con licencia MIT |
| **Kenney / Quaternius** | Paquetes de modelos gratis (CC0, de libre uso) | Gratis | Sirven para rellenar, para probar y **para aprender cómo están hechos**. Verificá la licencia de cada paquete al bajarlo |

**"Chibi Maker":** no encontré una herramienta con ese nombre que pueda
recomendarte con seguridad. Si me pasás el enlace la reviso, sobre todo
**qué licencia tiene lo que exporta** y si sale en 3D o solo en imagen 2D:
muchos "makers" de avatares solo dan imágenes, y algunos prohíben usar lo
que sale en un juego.

**Reglas para generar con IA** (ya acordadas):
- Siempre a partir de **una imagen de referencia tuya** o de un paquete CC0.
- Nunca con personajes ni arte de otros juegos (Los Sims, Nintendo, Dragon
  Ball, One Piece, etc.).
- Todo modelo generado se **limpia y recolorea** con tu paleta en Blender.
  Un modelo crudo de IA casi nunca sirve directo para un teléfono.

## 4. Reglas técnicas provisorias (a confirmar con una pieza real)
- Formato `.glb`. Nombres en inglés y minúsculas (`chair_wood.glb`).
- **Escala:** 1 celda de la casa = 1 metro.
- **Pivote** (el punto de origen) en el centro de la base del mueble.
- **Colores:** un material plano por color, con nombre (`wood`, `cloth_red`),
  para poder recolorear desde el juego.
- **Pocos polígonos** (sugerencia, a medir en tu teléfono): muebles de unos
  cientos a pocos miles de triángulos; el personaje, unos pocos miles más.
  Cuanto más liviano, más fácil llegar a 30 FPS con una casa de dos pisos.
- **Nada de contorno modelado**: lo agrega el shader.
- El catálogo (`data/catalog.json`) apuntará a cada `.glb` con un campo
  `model`; si el archivo no existe, el juego usa las figuras simples de ahora.
  Así podés ir cambiando pieza por pieza sin romper nada.

## 5. Personalización total (tu idea de furro, lobo, robot...)
Para que cada jugador tenga su versión, el personaje se arma con **piezas
intercambiables** sobre **un solo esqueleto**: cuerpo base, cabeza, orejas,
cola, ropa, accesorios, disfraces. Se anima una sola vez y sirve para todos.
Hay que **modelar con ese esqueleto único desde el principio**, aunque las
piezas se agreguen después. Anotado también en `VISION.md`.

## 6. La prueba de arte (antes de hacer 40 modelos)
Un solo cuarto, por ejemplo un dormitorio con 5 o 6 muebles y un personaje,
hechos con tu arte y el shader, y **vistos en tu teléfono**. Si te gusta cómo
se ve y se mueve a 30 FPS, seguimos con el resto. Si no, cambiamos el camino
sin haber gastado meses.

## 7. Interfaz con Figma
- Podés diseñar pantallas y pasármelas como imagen o enlace. Las uso de guía.
- Inspirarte está bien; copiar la interfaz de otro juego, no.
- Los **íconos** se exportan como **SVG** (ya usamos SVG propios en
  `assets/icons/`) con colores planos y trazos redondeados.
