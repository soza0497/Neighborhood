# Neighborhood — Visión del juego

> Nombre provisional. Este documento describe **a dónde queremos llegar**.
> NO es una lista de tareas: lo que se construye y cuándo está en `CLAUDE.md`
> (sección Fases). Sirve para que cada decisión técnica de hoy sea compatible
> con lo que viene después. **No construyas nada de aquí que no pida la fase
> actual.**

## Para quién es

Para mí, mi pareja y mi familia. Si a más gente le gusta, genial, pero no es
el objetivo. No buscamos ganar dinero: buscamos un juego **tranquilo,
cooperativo y vivo**, para compartir metas en común (lo que en su día tuvo
Clash of Clans con las guerras de clanes, pero sin guerras).

## Principios (no se negocian)

1. **Tranquilo.** No castiga por desconectarse: las necesidades del personaje
   bajan hasta un mínimo, nunca hasta un desastre; los negocios acumulan
   ganancias hasta un tope; nada se pierde por no entrar.
2. **Nada de anuncios invasivos, ni ofertas agresivas, ni cajas sorpresa.**
3. **Nada de pagar para ganar.** Quien juega gratis puede tener todo lo que
   tiene quien paga; solo tarda un poco más.
4. **Regla de los minijuegos:** se gana con habilidad, no con nivel ni con
   dinero. Un jugador de nivel 1 le puede ganar a uno de nivel 700.000. Si
   las estadísticas del personaje dan acceso a un evento, dentro del
   minijuego todos compiten igualados.
5. **Libertad.** Las relaciones no dependen del género del personaje.
6. **Multijugador asíncrono.** No se ve a nadie en tiempo real; se ve una
   *representación* de lo que hace (ver "Cómo se ve a los demás").
7. **Apariencia propia.** No copiar nada de The Sims, EA ni del juego de mesa
   de la vida: ni nombres, ni logotipos, ni el rombo, ni idioma inventado, ni
   interfaz, ni sonidos, ni chistes o animaciones icónicos. Las mecánicas son
   libres; la expresión debe ser nuestra.

## Economía

- **Una sola moneda del juego, que solo se gana jugando.** Nunca se compra con
  dinero real ni se cambia por dinero real. El servidor es la autoridad sobre
  dinero y propiedad.
- **Decoraciones por temporada de retos:** cada mes salen decoraciones nuevas.
  Jugando 30–40 minutos al día se completan en una o dos semanas. Se pueden
  comprar con dinero real para tenerlas ya, pero son solo adorno: no dan
  ingresos ni ventaja.
- **Aceleradores:** sirven para saltarse esperas del progreso propio (una
  construcción, el tiempo de respuesta a un currículum). **Nunca** dentro de
  minijuegos, eventos ni competencias.
- **Las metas del barrio se miden por participación** (minijuegos jugados,
  retos completados), no por dinero generado, para que el acelerador no se
  convierta en ventaja.
- Monetización real: **opcional y al final**. Para jugar en familia no hace
  falta (se puede instalar por la prueba interna de Google Play).

## Vida del personaje

- Necesidades (hambre, energía, limpieza, ánimo, diversión) y rasgos de
  personalidad (ordenado, cocinero, perezoso, sociable, deportista, gamer…).
  La IA es un sistema de prioridades, no IA generativa.
- **Trabajo:** hay ofertas de empleo; el personaje manda currículos y espera
  respuesta (5, 10, 30 minutos…). Se puede acelerar.
- **Decisiones con consecuencias**, al estilo de un juego de mesa sobre la
  vida: gastar o ahorrar, tener hijos, cambiar de trabajo. (Hijos y etapas de
  la vida: muy adelante.)

## Relaciones y drama

- Noviazgo, matrimonio, casa compartida, separación. Sin restricciones de
  género.
- Cada personaje guarda un **historial de relaciones** con los demás.
- **Drama permitido:** un jugador puede decidir (por acción suya, no de la IA)
  que su personaje sea infiel. Se ve con escenas propias y caricaturescas
  (ej. un carro recoge al personaje y sube un corazón). Quien lo vea puede
  avisar al afectado.
- Contenido íntimo: solo insinuado, tono caricaturesco y propio (no copiar
  animaciones de otros juegos).
- **Interruptores obligatorios:** cada jugador puede apagar el drama en su
  relación, y existe un **modo familiar** que lo oculta todo.

## Cómo se ve a los demás (pieza central del multijugador)

- Cada teléfono envía al servidor un **estado o intención** muy pequeño:
  *"Sofía: paseando al perro, en el parque, desde las 14:02"*.
- Los demás teléfonos reciben ese estado y **animan localmente** al personaje.
  No se sincronizan movimientos, solo estados y eventos.
- Si el jugador está desconectado, su personaje sigue con su IA de
  necesidades: lo que ve el visitante es **creíble, no exacto**.
- **Eventos visibles:** ciertas escenas tienen lugar y duración en el
  servidor; quien mire esa zona en ese rato las ve.
- Indicador de "conectado" en cada jugador.
- Se sincronizan datos: muebles, dinero, propiedad, relaciones, eventos.

## Casa compartida

- Cambios menores (mover, rotar, pintar): al instante, con aviso y opción de
  deshacer para el otro.
- Cambios estructurales (paredes, pisos, vender, convertir en negocio,
  demoler): solicitud y aprobación del copropietario.
- Billetera propia; aporte a la casa común; opción "unir ingresos".

## Negocios

- Convertir una propiedad en alquiler, alojamiento temporal, restaurante u
  oficina.
- Cada negocio trae **sus minijuegos**: en el restaurante se completan
  órdenes, y eso genera dinero.
- Bonos para quien visita o trabaja en el negocio de otro.

## Parcela (lo que es de cada jugador)

- Cada jugador tiene una **parcela grande** con una extensión máxima, no un
  lote justo para una casa. Ahí cabe lo que quiera: la casa, un cobertizo, la
  zona del perro, una cancha, o **dos casas** (una para alquilar a otro
  jugador o a un personaje de la IA) y un negocio al lado.
- Para eso hará falta **declarar zonas**: qué edificio es "mi casa" (donde
  vive y descansa el personaje) y cuál es zona de trabajo o de alquiler.
- La parcela da a una **calle con acera**. El jugador decide si pone muros,
  rejas o nada al frente.
- **Seguridad (más adelante):** puede haber robos; cómo enfrentarlos lo
  decide **el barrio entero** (por ejemplo, con el alcalde y sus propuestas).
- El barrio se podrá modificar un poco para acomodar las parcelas a la calle.

## Barrios

- Barrios de 20–30 casas (por ejemplo, toda la familia). Un menú para visitar
  cualquier casa ("¿Qué casa querés visitar?").
- **Vista aérea en diagonal, con rotación**, donde se ven caminar los
  personajes del barrio y sus interacciones. No hay primera persona.
- **Metas del barrio** con recompensas según la participación de cada uno.
- **Competencias entre barrios** y **eventos** (carreras, maratones, retos de
  videojuegos) a los que se entra según las condiciones del personaje.
- **Alcalde:** cada cierto tiempo hay elecciones; los candidatos publican
  propuestas, se vota, y el ganador elige de un **menú cerrado** los
  modificadores del mes (ej. "+10 % para restaurantes", "reto de calles").

## Ideas del dueño para más adelante (2026-11-03)

Anotadas para no perderlas; **ninguna entra hasta que el dueño la elija como
fase**. Lo de interfaz y constructor que va ya está en `docs/pulido-1.md`.

### Muebles base + variantes ("skins")
- Pocos **muebles base** con su función (silla, silla alta, banquito, mesa,
  escritorio, cama, sofá…) y muchas **variantes visuales** de cada uno. Lo
  nuevo que salga cada temporada es casi solo arte; el funcionamiento es el
  mismo. Conviene definir este modelo de datos **antes de la Fase 7 (arte)**.
- **Juegos** (mesa con sillas) más baratos que por separado; las sillas se
  pueden quitar después.
- Categorías: plantas, adornos, electrónica (tele, consolas), electro-
  domésticos, muebles, escritorios.
- **Superficies con lugares fijos**: un escritorio o mesa tiene posiciones
  predefinidas (con capacidad) donde se pone una PC, parlantes, un adorno…
  El jugador elige el lugar; nunca atraviesa paredes. Cada mueble dice qué
  puede llevar encima (una PC no va sobre la cocina).
- La **PC sobre el escritorio** habilita trabajo remoto: ganar en internet,
  invertir, hacer de streamer (empleos nuevos).

### El personaje usa lo que tiene enfrente
- Posturas: de pie, sentado, acostado.
- Desde el sofá o la cama ve la tele **si la tiene enfrente** y sin pared en
  medio (si está atrás, no). Agarra el control, puede dormirse con la tele
  prendida o apagarla.
- En la mesa come de lo que hay servido.

### Eventos graciosos (la idea son las risas, que se compartan)
- Una **puerta al vacío** en un piso alto: el personaje se cae, queda
  golpeado (estrellitas o pajaritos sobre la cabeza), se enoja, y **aprende**
  después de 3–4 veces. Si está "mareado", se vuelve a caer.
- Llega una **ambulancia** con dos personajes chibi y se lo lleva.
- **Nunca se pierde progreso** y por ahora **no hay muertes**.
- Baño: en el inodoro saca el celular, un libro o lee la etiqueta del champú.
- Piso mojado en la ducha o un balde derramado: se resbala (animación
  graciosa), va por el trapeador; si lo mandás a otra cosa puede olvidarse y
  volver a caerse, o verlo y rodearlo.

**Cuidado con The Sims** (ver `docs/riesgos-legales-ea.md`): la vida
cotidiana con humor es un género, no es de nadie. Pero hay dos ideas de esta
lista que son marca de la casa de The Sims y conviene **no** hacer así:
1. **La Muerte como personaje que aparece** (y la escena graciosa con ella).
2. **El pixelado** para tapar en el baño o la ducha. Mejor algo propio: una
   cortina, vapor, una toalla, o la cámara que mira para otro lado.

### Casa compartida
- Remodelación como **propuesta completa** que la pareja previsualiza y
  aprueba: ya pasó a `docs/pulido-1.md`.

### Más adelante todavía
- **Cobertizo / almacén** para guardar lo que se quita y reusarlo sin volver
  a comprarlo.
- Escalera de emergencia con plataformas (estilo edificios de EE. UU.).

## Preguntas abiertas

- ¿Mi pareja usa Android o iPhone? (si es iPhone, iOS deja de ser "después")
- ¿Van a jugar menores de edad en la familia? (decide si el modo familiar va
  desde el principio)
- Nombre definitivo del juego.


## Restaurante: personal y sueldos (diseño, anotado en el Pulido 2B — NO se implementó)

Hoy el restaurante gana **solo** (ingreso automático calculado por el servidor
por tiempo) y el minijuego "Servicio" es un reto opcional con premio extra.
**Contratar personal y pagar sueldos se deja para una fase propia.** Diseño:

- **Administrador**: un rol que el dueño puede nombrar (un jugador o un NPC).
  El administrador reparte turnos y, si está, el restaurante **no depende de
  que el dueño entre a jugar** (hoy tampoco depende).
- **Empleados**: pueden ser **NPC** (personajes con IA, de los que ya tiene el
  juego) o **jugadores** (la pareja, familiares del barrio). Cada uno ocupa un
  puesto (mesero, cocinero, cajero) y cada puesto sube lo que gana el
  restaurante por hora y cuántas mesas atiende.
- **Sueldos**: salen de la **caja del restaurante** (no de la nada). Un sueldo
  es una cuenta por hora/turno que el **servidor** calcula y paga; si la caja
  no alcanza, el empleado se **va a casa sin cobrar ese turno** (nunca se deja
  la deuda: nada castiga por desconectarse, y no hay números negativos).
- **Cuidado con los ciclos de dinero infinito** (regla de diseño):
  1. El dinero que paga un negocio tiene que **salir de algo real** (clientes
     de paso con tope por hora) y el sueldo **siempre es menor** que lo que
     aporta el puesto, pero nunca crea dinero.
  2. Un jugador que es empleado de **su propio** restaurante no cobra sueldo
     *y* ganancia por el mismo turno (una sola vez).
  3. Dos jugadores que se contratan **entre sí** no pueden sacar más de lo que
     entra: los sueldos cuentan para un tope diario por jugador (como el tope
     del minijuego, hoy $600).
  4. Todo se calcula en el servidor y deja **historial** (quién pagó a quién y
     por qué turno) para poder auditarlo.
- **Trabajar en un restaurante ajeno** ya existe como empleo común (Mesero,
  Cocinero en `data/jobs.json`): no hace falta tener uno propio.
