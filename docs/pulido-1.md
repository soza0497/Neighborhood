# Pulido 1 — Interfaz limpia y constructor 2.0

Pedido del dueño (2026-11-03), después de jugar las Fases 1–5. Va **antes de
la Fase 6**. Se divide en dos sub-fases que se prueban por separado:
**P1A (interfaz)** y **P1B (constructor)**. Lo que es de más adelante está en
`VISION.md` ("Ideas del dueño para más adelante").

Reglas que siguen valiendo: todo con figuras simples (sin arte final), el
catálogo en `data/`, el dinero lo decide el servidor (lo que cambie reglas de
la casa se cambia también en `server/nakama/modules/neighborhood_house.lua` y
sus pruebas), y la partida guardada vieja se migra (formato v3 si hace falta).

---

## P1A — Interfaz limpia

Meta: la pantalla casi vacía; todo con **íconos** en vez de botones con texto
(íconos dibujados simples: SVG propios o Kenney CC0 "Game Icons").

### Barra de arriba
- **Dinero** (como ahora) y **ánimo**: un ícono de cara + una palabra
  ("Feliz", "Desanimado"…).
- Tocar el ánimo abre una tarjetita con las necesidades como **íconos con
  barra** (comida, energía, limpieza, diversión) y **qué está afectando el
  ánimo** (las emociones activas y su motivo). Tocar afuera la cierra.
- Se **quita** el recuadro de necesidades de la izquierda.
- Indicador de pareja: queda chico (punto de color + nombre), sin el texto
  largo.

### Menú lateral derecho → "Info"
Se mueven ahí: FPS, versión, "Conectado: …", día y hora, la caja de la casa
y el texto largo de la pareja. Nada de eso queda suelto en pantalla.
(Opción en Info: "Mostrar FPS" para medir en el teléfono.)

### Columna izquierda: pisos y vista
- **Mapa de pisos 3D**: una maqueta chica y semitransparente de la casa
  (solo contornos de paredes y losas de cada piso, sin muebles), vista desde
  el frente que da a la calle e inclinada para que se note el 3D. El piso
  actual resaltado y un **punto que parpadea** donde está el personaje.
  Tocar un piso de la maqueta = ir a ese piso. Reemplaza "Subir / Bajar /
  Planta baja".
- Encima de la maqueta, dos íconos:
  - **Techo**: normal = se ven los techos; tachado = sin techos.
  - **Paredes**: el ícono de la pared se ve alto o bajito según el modo
    (paredes altas / bajas). Siempre relativo al piso actual.
- **Centrar**: botón de flechita tipo brújula/navegador que apunta al
  personaje (reemplaza el botón "Centrar").

### Otros
- **Velocidades x1, x2, x5** (sin x10). Ojo: el servidor calcula los turnos
  de trabajo con "la velocidad más rápida": cambiar esa constante a x5 en
  `neighborhood_rules.lua`, sus pruebas y `GameClock.SPEEDS`. No puede dar
  ventaja.
- **Máximo 5 pisos** (`HouseGrid.MAX_LEVELS = 5`, también en el servidor).

---

## P1B — Constructor 2.0

### Menú de abajo: tres herramientas
Para no repetir el trío y los íconos de otro juego (ver
`docs/riesgos-legales-ea.md`), los nombres y el orden son propios:
1. **Tienda** (ícono bolsa): muebles, electrodomésticos, electrónica,
   plantas, adornos. Ordenada por lo que recomienda el cuarto (ver abajo).
2. **Obra** (ícono casco/martillo), con dos modos:
   - **Agregar**: cimientos, pisos, paredes, puertas, ventanas, techos,
     escaleras, pilares.
   - **Modificar**: tocar algo existente para moverlo, rotarlo, pintarlo o
     borrarlo.
3. **Borrar** (ícono basurero).

### Borrar
- Tocar algo lo **resalta** y pregunta "¿Borrar techo? Te devuelven $X".
- **Modo selección**: ir tocando varias cosas (todas resaltadas), un botón
  "Borrar N cosas · te devuelven $X" y confirmar.
- Devuelve parte del precio (la reventa del 50% de ahora). El cobertizo
  para guardar cosas es para más adelante.
- Los **techos** se tienen que poder borrar fácil (hoy cuesta mucho).

### Modificar
- **Tocar** un mueble: aparecen **flechas N / S / E / O** para correrlo de a
  una celda, más girar y borrar.
- **Mantener presionado**: el mueble se levanta y sigue al dedo (con la
  marca separada del dedo, como ya se hizo).
- **Mantener presionado** una pared, techo o cimiento: menú con lo que se le
  puede hacer (mover, pintar, borrar).

### Muebles en 8 direcciones
Girar de a **45°** (8 orientaciones). Un mueble en diagonal ocupa las celdas
que toca su caja girada; no se puede encimar. (Lo diagonal es solo para
muebles; las paredes siguen en la cuadrícula.)

### Pintura
- **Cada pared tiene dos caras** (adentro y afuera, o cuarto A y cuarto B):
  se pinta solo la cara que se tocó. Migración: la pintura vieja pasa a las
  dos caras.
- **Tocar una vez**: pinta esa cara y aparecen flechas **izquierda /
  derecha** para pintar la siguiente pared pegada. Tocar afuera termina.
- **Mantener presionado**: una onda avisa que ahora se pinta arrastrando.
- **Lo que se empezó es lo que se pinta**: si se empezó en pared, solo
  paredes (el piso no se pinta aunque el dedo pase); si se empezó en piso,
  solo pisos.

### Ventanas unidas
Hoy la unión se guarda en una ventana y afecta a las vecinas, y no se sabe
cuál tiene la marca. Nuevo: la unión es de la **juntura** entre dos ventanas
vecinas. En modo Modificar, las junturas se ven como un puntito: tocarlo une
o separa esas dos. Lo que se ve es exactamente lo que hay guardado.
Migración desde lo de ahora.

### Techos
- **No se puede poner techo donde pasa una pared** del mismo nivel que lo
  atraviesa (choque feo).
- Nuevo techo **plano de concreto** (casa moderna), además del de dos aguas.

### Pisos, escaleras y soporte (lógica que entiende cualquiera)
- **Sin escalera no se sube**: un piso de arriba sin escalera que llegue
  queda marcado "sin acceso" (se puede construir, pero se avisa).
- Escaleras nuevas: **caracol** y **metálica exterior** (por fuera de la
  casa). La de emergencia con plataformas queda para más adelante.
- **Pilares**: pieza nueva. Una losa de arriba necesita paredes o pilares
  debajo cerca (las reglas de apoyo de hoy se amplían con pilares). Sirve
  para casas elevadas y puentes entre dos casas.
- **No se puede quitar** una pared o pilar que sostiene algo: "Esta pared
  sostiene el piso de arriba".
- **Lista de "lo que falta"**: un aviso con lo que está sin apoyo o sin
  acceso; las piezas con problema se pintan de **rojo**.
- **Construcción rápida**: botón "Copiar contorno de abajo": pone las
  paredes exteriores del piso de abajo en el piso actual, con su losa
  completa. Después el jugador arma los cuartos.

### Cuartos que el juego entiende
- Un área cerrada por paredes (con puertas) es un **cuarto**.
- Según los muebles que tiene, el juego le pone un tipo: dormitorio (cama),
  cocina (cocina/refri), baño (inodoro/ducha), sala (sofá/tele), estudio
  (escritorio)… Con mezcla: **multiuso**.
- La **Tienda recomienda** primero lo del tipo más probable del cuarto donde
  está la cámara/el personaje, y después lo del segundo tipo. **Nunca
  prohíbe nada**: una cama en la cocina se puede.
- Los tipos y qué mueble cuenta para cada uno van en un archivo de datos
  (`data/rooms.json`), editable.

### Casa compartida: remodelación con aprobación
Cuando la casa es de los dos y el otro está en línea: el que edita arma
**todos** sus cambios como una "propuesta"; la pareja la **previsualiza** y la
**aprueba o la rechaza** entera. Y al revés. (Amplía el "Pedir permiso" de la
Fase 5, que hoy va de a un cambio.)

---

## Cómo se prueba (para el dueño)
- P1A: la pantalla de juego muestra solo dinero, ánimo, la maqueta de pisos
  con sus dos íconos, la brújula, el menú y la velocidad. Tocar el ánimo abre
  las necesidades. Info muestra los FPS. Tocar el piso 2 en la maqueta sube.
- P1B: pintar una pared por dentro no pinta afuera; borrar un techo con
  confirmación; girar una silla en diagonal; no se puede quitar una pared que
  sostiene el segundo piso; copiar el contorno arma el piso 2; la Tienda en un
  cuarto con cama recomienda primero cosas de dormitorio.
