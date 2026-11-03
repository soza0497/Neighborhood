# Neighborhood — Instrucciones del proyecto

Juego móvil caricaturesco (personajes chibi, colores alegres, estilo "toon"):
construir tu casa, vivir en ella con un personaje con IA, compartirla con tu
pareja, montar negocios y formar parte de un barrio con tu familia.

**Antes de hacer cualquier cosa en cada sesión, leé `PROGRESO.md`,
`DECISIONES.md` y `VISION.md`.** `VISION.md` describe a dónde vamos: usalo
para que la base sea compatible, pero **no construyas nada que no pida la fase
actual**.

## 1. Tu rol

Sos el desarrollador principal. Yo soy el director del proyecto y estoy
aprendiendo a programar: tengo poco tiempo y quiero avanzar rápido. Vos
escribís el código, la estructura y la documentación; yo pruebo, decido y hago
lo que requiera mis manos (instalar programas, abrir el editor, probar en el
teléfono, crear cuentas).

## 2. Modo de trabajo (OBLIGATORIO)

1. **Fases largas.** Cada fase se trabaja de corrido y completa: creá todos
   los archivos, escenas, scripts y datos que necesita sin pedirme
   confirmación entre archivo y archivo.
2. **Solo te detenés cuando:**
   - necesitás una acción mía que no podés hacer vos (instalar, probar en el
     teléfono, crear una cuenta, descargar recursos), o
   - hay una decisión de diseño que cambia mucho el resultado y no se deshace
     fácil. Si la decisión es menor, tomá la opción más razonable, anotala en
     `DECISIONES.md` y seguí.
3. **Al terminar cada fase entregá:**
   - Resumen corto de lo que se hizo (máx. 10 líneas).
   - Checklist numerado de acciones para mí, paso a paso y para principiante
     (dónde hacer clic, qué comando correr y qué hace).
   - Cómo probar que la fase funciona (qué debería ver en pantalla).
   - Errores conocidos o pendientes.
4. **Memoria entre sesiones.** Mantené `PROGRESO.md` al día: fase actual, qué
   está hecho, qué falta y el próximo paso exacto. Mis sesiones tienen límite
   de uso: este archivo es lo que permite retomar sin perder contexto.
5. **Ahorro de tokens.** No vuelvas a imprimir archivos que no cambiaron. No
   expliques código línea por línea en el chat: los comentarios del código ya
   lo explican. Respuestas cortas y al grano.
6. **Para un principiante.** Comentarios del código en español, claros.
   Nombres de variables, funciones y archivos en inglés. Código simple y
   legible antes que ingenioso.
7. **Si algo falla**, diagnosticá y arreglá vos leyendo los errores; pedime
   ayuda solo si necesitás que yo vea algo en el editor o en el teléfono.
8. **Todo funciona sin arte final.** Figuras simples (cubos, cápsulas, colores
   planos) hasta la fase de arte.
9. **Git:** tenés permiso para hacer un commit (guardar una versión) al final
   de cada fase o sub-fase. Nada de subir a GitHub ni a ningún sitio sin que
   yo lo pida.

## 3. Reglas de esta PC (CachyOS)

Esta PC tiene reglas globales en `~/.claude/CLAUDE.md` e
`~/intranet/CLAUDE.md`. Las más importantes para este proyecto:

- **Instalar, por este orden:** pacman, Flathub, AUR revisado, AppImage
  oficial. Nunca `curl | bash`, nunca scripts descargados.
- **Permisos de administrador: `pkexec`, nunca `sudo`**, un solo comando
  sencillo por cada `pkexec`, rutas absolutas, y explicándome antes qué hace.
- La terminal es **fish**: la sintaxis de bash va envuelta en `bash -c '...'`.
- Todo lo que se instale en el sistema se anota en la bitácora
  (`~/intranet/bitacora/`, skill **bitacora**).
- **Docker se salta el cortafuegos.** Cuando montemos Nakama, sus puertos se
  publican en `127.0.0.1` salvo que yo autorice otra cosa. Para probar desde el
  celular en la red de casa, la IP de la PC es `192.168.100.177`.
- **Nunca abrir puertos del router ni túneles públicos.** Un servidor en
  internet es una decisión mía, aparte, y se pregunta antes.

## 4. Tecnología

- **Motor:** Godot 4, GDScript. Fijá la versión exacta en `DECISIONES.md` y no
  la cambies sin preguntarme.
- **Plataformas:** Android primero. iOS depende de una pregunta abierta en
  `VISION.md` (el teléfono de mi pareja).
- **Orientación** vertical u horizontal: proponé y anotá en `DECISIONES.md`.
- **Vista:** cámara isométrica/cenital 3D con controles táctiles (arrastrar
  para mover, pellizcar para zoom, dos dedos para rotar) y de mouse para probar
  en la PC. La misma cámara servirá después para ver el barrio desde arriba.
- **Catálogo** (muebles, piezas, precios, tiempos) en archivos de datos
  (`.tres` o JSON), no escritos dentro del código, para que yo pueda editarlos.
- **Servidor (desde la Fase 4):** Nakama, que tiene cliente oficial para
  Godot, salvo que propongas algo mejor con justificación.
- **Arte (Fase 7):** modelos `.glb` generados con IA (siempre desde imagen de
  referencia) o paquetes gratuitos (Kenney, CC0). Shader toon con contorno.

## 5. Fases

Ordenadas para que mi pareja y yo podamos jugar juntos lo antes posible.

**Fase 0 — Base del proyecto**
- Repositorio Git, carpetas (`scenes/`, `scripts/`, `data/`, `assets/`,
  `ui/`, `docs/`).
- Autoloads: `GameState`, `SaveSystem`, `EventBus`, `Catalog`.
- Escena principal con terreno y cámara (táctil y mouse).
- **Exportación a Android funcionando y probada en mi teléfono**, no solo
  explicada: qué piden la documentación oficial de Godot (SDK de Android, JDK,
  clave de depuración) y cómo se instala en CachyOS.
- `README.md` para principiante: abrir, correr y exportar.
- `PROGRESO.md` y `DECISIONES.md`.

**Fase 1 — Constructor de casas**
- Cuadrícula con resaltado de celda.
- Cimientos, pisos, paredes (esquinas automáticas), puertas, ventanas, techo.
- Segundo piso (cambiar de nivel, escaleras).
- Muebles: colocar, mover, rotar, eliminar, sin encimarse.
- Pintar paredes y pisos.
- Deshacer / rehacer.
- Interfaz táctil: barra inferior con categorías; modo construir / modo vivir.
- Guardar y cargar la casa (archivo local).

**Fase 2 — Personaje y su IA**
- Personaje chibi provisional (cápsula + cabeza grande).
- Navegación que se regenera al construir.
- Necesidades + rasgos + IA de prioridades que elige acciones.
- Objetos que "anuncian" acciones (cama → dormir, cocina → cocinar…).
- Burbujas o íconos sobre la cabeza.
- Editor de personaje básico.
- Ganchos para animaciones (idle, caminar, dormir, cocinar).
- **Diseñá el estado del personaje para que se pueda resumir en una
  "intención"** (ver `VISION.md`, "Cómo se ve a los demás"): lo vamos a
  necesitar en la Fase 5.

**Fase 3 — Progresión y economía local**
- Moneda y precios desde el catálogo.
- Construcción con temporizadores y aceleradores.
- Niveles y desbloqueos.
- Empleos: ofertas, currículos con tiempo de espera, ir a trabajar genera
  ingresos.
- Nada castiga por desconectarse (ver principios en `VISION.md`).
- Guardado robusto (versión de formato, migraciones simples).

**Fase 4 — Cuentas y servidor**
- Nakama local con Docker (puertos en `127.0.0.1`), guía paso a paso.
- Registro e inicio de sesión, guardado en la nube local.
- Dinero y propiedad pasan al servidor (servidor autoritativo).

**Fase 5 — Pareja y casa compartida**
- Invitar / aceptar relación, casarse, mudarse.
- Permisos: cambios menores con aviso + deshacer; estructurales con
  aprobación.
- Billeteras, aporte a la casa común, "unir ingresos".
- Sincronización de estados e intenciones (el personaje del otro se anima en
  mi pantalla según lo que está haciendo), indicador de conectado.
- Conflictos si los dos editan a la vez (historial + última escritura gana en
  cambios menores).

**Fase 6 — Primer negocio: restaurante**
- Convertir una propiedad en restaurante.
- **Un solo minijuego** de completar órdenes que genera dinero.
- Ingresos calculados en el servidor, con tope.

**Fase 7 — Arte y estilo**
- `docs/estilo.md`: proporciones chibi, paleta, reglas para generar con IA.
- Convenciones de importación (escala, pivote, orientación, nombres).
- Shader toon + contorno; iluminación alegre.
- Reemplazo de provisionales por `.glb` reales desde el catálogo.

**Fase 8 — Barrio**
- Barrio de 20–30 casas; menú para visitar casas.
- Vista aérea con rotación; personajes animados localmente.
- Metas del barrio medidas por participación.

**Después (cada una es su propia fase, en el orden que yo decida):**
alcalde y elecciones, eventos y competencias, más negocios, relaciones y
drama con sus interruptores, hijos y etapas de la vida, temporada de
decoraciones, iOS, y publicación en tiendas.

## 6. Criterios de calidad

- Fluido en un Android de gama media: **30 cuadros por segundo** con una casa
  de dos pisos amueblada, medido en mi teléfono.
- Nada de lógica de dinero confiada solo al teléfono desde la Fase 4.
- Cada fase termina con el juego jugable, aunque sea simple.
- Si una fase no cabe en una sesión, dividila en sub-fases (1A, 1B…); cada una
  termina en algo que se pueda probar.

## 7. Modelo

Conviene Opus para la Fase 0 (la base que todo hereda) y para las Fases 4 y 5
(servidor y sincronización). Para el resto alcanza Sonnet.

**Regla (pedida por el dueño, 2026-11-03):** antes de empezar cada fase o tarea
grande, revisá el modelo y el **esfuerzo** de la sesión (herramienta
`get_session` con `"self"`) y corregime en una línea si no corresponden:
- Opus donde alcanza Sonnet (o esfuerzo alto donde alcanza medio): avisame
  para bajar y ahorrar uso.
- Sonnet en una tarea compleja (diseño difícil, servidor, sincronización,
  bugs raros): avisame para pasar a Opus.
- Esfuerzo sugerido: **medio** para fases normales y ajustes; **alto** para
  diseño complejo o sincronización.
- Esperá a que cambie, salvo que yo diga "ignoralo".

## Primera instrucción

Leé este documento y `VISION.md`, creá `PROGRESO.md` y `DECISIONES.md`, y
ejecutá la Fase 0 completa. Al terminar, dame el checklist de acciones para mí.
