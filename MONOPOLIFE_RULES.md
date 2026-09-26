# Reglas del Modo Monopolife

Monopolife es un **segundo modo de juego** que se elige al crear la partida. Usa el mismo tablero, propiedades, precios, rentas, niveles, Mercado, inversiones y tarjetas de crédito que el modo **Monopoly Classic** (todo `GAME_RULES.md` sigue aplicando), salvo lo que este documento cambia explícitamente.

La diferencia central: **no gana quien tiene más dinero, sino quien tiene más felicidad**. El dinero es un medio, no el fin. Cada jugador recibe al azar un **rol secreto** que define qué le hace feliz y qué no, así cada partida se juega distinto.

> Todos los valores numéricos de este documento (puntos, montos, topes) son **placeholder** para la primera versión. Deben vivir en datos declarativos (una sola tabla por concepto) para poder ajustarlos tras las primeras partidas sin tocar lógica.

## 1. Selección de modo

- En la sala de espera, el host elige el modo: **Monopoly Classic** (por defecto, el juego actual sin cambios) o **Monopolife**.
- Los clientes ven en la sala qué modo está elegido. Las tarjetas de salas cercanas muestran el modo.
- Si el modo es Monopolife, el host elige también el **número de rondas** (por defecto 15; opciones 10, 15, 20, 25).
- El modo no se puede cambiar una vez iniciada la partida.

## 2. Felicidad

- Cada jugador tiene un contador de **puntos de felicidad** (entero, empieza en 0, nunca baja de 0).
- La felicidad cambia por: los **gustos y disgustos de su rol** y la renta de lujo y el **rival secreto** (sección 3), las **Tarjetas de Vida** (sección 5), la **cárcel** y la **bancarrota** (sección 6).
- **Cárcel**: ir a la cárcel (cuando el jugador lo marca con el botón "Cárcel", por la casilla, una carta o 3 dobles; sección 5 de `GAME_RULES.md`) resta **−3 a cualquier rol por igual**. Salir de la cárcel no cambia la felicidad. Por eso la tarjeta "Mala racha: a la cárcel" no tiene felicidad propia: el castigo llega al marcar la cárcel.
- Cada cambio queda en un **historial** (jugador, puntos, motivo, ronda) que el jugador puede consultar y que se usa en la pantalla final para mostrar de dónde salió la felicidad de cada uno.
- **Visibilidad**: cada jugador solo ve su propia felicidad y su propio historial. La felicidad de los demás se revela al final (ver sección 7). Mostrarla durante la partida delataría los roles.

## 3. Roles

### 3.1 Asignación
- Al iniciar la partida, el host asigna un rol al azar a cada jugador. Mientras haya roles sin usar no se repiten; con más jugadores que roles, se vuelve a sortear entre todos los roles.
- **Los roles son secretos**: cada jugador solo ve el suyo. Se revelan en la pantalla final.
- Al asignar, el 🦎 Camaleón recibe al azar su primera personalidad (secreta), y cada jugador recibe además su **rival secreto** (sección 3.5).
- La asignación se muestra con una **ruleta** que aparece a la vez en la pantalla de todos los jugadores al empezar la partida (ver sección 4).

### 3.2 Principio de equilibrio
- Ningún rol debe tener ventaja: todos se diseñan para ganar, en una partida típica, una cantidad parecida de felicidad por ronda (objetivo: ~4–6 puntos por ronda).
- Cada rol tiene **gustos** (suman) y un **disgusto** (resta) propios (tabla 3.3), y además **cada Tarjeta de Vida afecta distinto a cada rol** (sección 5): la misma tarjeta puede alegrar mucho a uno y molestar a otro.
- El mazo está equilibrado por rol: sumando lo que cada rol puede sacar del mazo completo (en las decisiones solo cuenta lo positivo, porque se puede pasar), todos los roles quedan dentro de ±2 puntos entre sí. Cualquier cambio a las tarjetas debe mantener esa regla.
- Los topes por ronda existen para que ningún rol pueda "farmear" puntos repitiendo una acción trivial.

### 3.3 Tabla de roles

| Rol | Gustos (+) | Disgusto (−) |
|---|---|---|
| 🛍️ **Consumista** — le gusta gastar y vivir en lugares caros | Pagar renta: +1 por cada $100 pagados (máx +6 por pago), además de la visita de la sección 3.4. Subir de nivel una propiedad en la que tiene acciones: +2. | Al terminar la ronda con más de $1,500 en efectivo: −2 (el dinero guardado lo aburre). |
| 🏢 **Emprendedor** — le gusta construir negocios y que la gente caiga en ellos | Al terminar la ronda: +1 por cada propiedad que **administra** con nivel 1 o más (máx +4). Cada vez que recibe renta de otro jugador: +1 (máx 3 rentas puntuables por ronda). | Hipotecar una propiedad que administra: −3. Estancarse: si termina una ronda y lleva 3 o más rondas seguidas sin subir de nivel ninguna propiedad, −2 (se repite cada ronda hasta que suba una). |
| 🐷 **Ahorrador** — le gusta ver crecer su cuenta | Al terminar su turno (cuando pulsa "Terminar turno"): +1 por cada $300 en efectivo (máx +5). Cobrar salario sin deuda de tarjeta: +2. | Pedir un préstamo de tarjeta de crédito: −4. |
| 🎉 **Social** — le gusta negociar y compartir | Cada trato del Mercado ejecutado en el que participa: +3 (máx 2 tratos puntuables por ronda). Cuenta cualquier trato: compra compartida, inversión, oferta abierta, y también cubrir la parte de otro accionista al subir de nivel o recomprarle esas acciones (sección 4.3 de `GAME_RULES.md`). Solo es puntuable si mueve al menos $50 o al menos una acción. Pagarle o cobrarle renta a un jugador por primera vez en la ronda: +1 por cada jugador distinto. | Desde la ronda 3: terminar una ronda sin haber participado en ningún trato ejecutado: −1. |
| ✈️ **Trotamundos** — le gusta viajar y conocer, no echar raíces | Cobrar salario en Salida: +3. Pagar un viaje en una casilla de viaje: +3. La primera vez que paga renta en cada grupo de color ("sello"): +3; al completar los 8 sellos: +8 extra. Volver a pagar renta en un grupo ya sellado: +1. | Comprar una propiedad al banco (compra directa, subasta o compra compartida) quedando con acciones en 3 o más propiedades: −2. Las dos primeras no le molestan. |
| 🦎 **Camaleón** — cambia de personalidad cada pocas rondas | Tiene los gustos de su **personalidad actual**: otro rol al azar entre Consumista, Emprendedor, Ahorrador, Social, Trotamundos y Prestamista. Al terminar cada 3 rondas (3, 6, 9…, salvo la última) cambia a otra personalidad distinta: +2 por cada cambio. | Los disgustos de su personalidad actual. |
| 🦈 **Prestamista** — le gusta ser el banco de los demás | Prestar $100 o más a otro jugador con al menos 10% de interés (préstamo entre jugadores, sección 4.9 de `GAME_RULES.md`): +3 (máx 1 por ronda). Cada pago que recibe de un préstamo (cuota en Salida, % de rentas, plazo o pago anticipado): +1 (máx 2 por ronda). Que le terminen de pagar un préstamo: +3. Quedarse con la garantía de un préstamo sin pagar: +5. | Perdonar una deuda, o que su deudor quiebre sin que él se quede con una garantía: −3. |
| 🧘 **Minimalista** (próximamente: todavía no se reparte) — le gusta vivir con poco y compartir lo que tiene | Regalarle dinero a otro jugador («Pago libre entre jugadores», sección 5 de `GAME_RULES.md`): +1 por cada $100 regalados en la ronda (máx +3 por ronda). Terminar la ronda con acciones en 2 propiedades o menos y sin posesiones: +2. | Conseguir una posesión (carro, televisor o food truck, aceptando una Tarjeta de Vida): −3. |

Aclaraciones:
- "Al terminar la ronda" se evalúa para todos los jugadores cuando el último jugador de la ronda termina su turno (el momento en que `round` se incrementa).
- "Recibe renta" / "paga renta" se refiere a `collectRent` con monto > 0. Lo que se lleva un inversor por una inversión no cuenta como renta recibida para él.
- Los gustos por acción se aplican a quien hace la acción: el accionista que sube de nivel (cualquiera puede, no solo el administrador), el administrador al hipotecar, cada comprador en una compra compartida.
- El estancamiento del Emprendedor cuenta las subidas de nivel que él mismo paga; la subida gratis de una carta del host o la renovación urbana no cuentan.
- Cubrir la parte de un accionista al subir de nivel cuenta como un trato entre quien cubre y el cubierto (siempre mueve acciones, así que es puntuable); recomprar esas acciones también.
- Las rentas de Ultimate Banking (sección 4.2.1 de `GAME_RULES.md`) empiezan en $70, por eso el Consumista cuenta cada $100 y no cada $50: con $50 casi cualquier renta le daba varios puntos.
- **Camaleón**: las Tarjetas de Vida y la renta de lujo (3.4) le afectan como a su personalidad actual. Al cambiar de personalidad conserva su felicidad y sus sellos de Trotamundos, pero la racha sin subir de nivel del Emprendedor vuelve a 0. El cambio se sortea con una semilla guardada en la partida, así que es reproducible.
- **Prestamista**: el mínimo de interés evita prestar y devolver en bucle sin costo. Solo cuentan los préstamos entre jugadores, no la tarjeta de crédito.
- **Minimalista**: está **desactivado (próximamente)**: sus reglas y su columna del mazo existen, pero la ruleta no lo reparte ni el Camaleón puede tomarlo; en las reglas de la app aparece marcado como «Próximamente». Pendiente: separar los regalos voluntarios de los pagos obligatorios entre jugadores, que hoy también cuentan. Solo cuentan las transferencias directas de dinero, no los pagos de renta, tratos del Mercado ni préstamos. Los puntos se cuentan sobre lo regalado en toda la ronda, así que tres regalos de $50 y uno de $150 suman +2.
- **Rol eliminado**: el Inversionista existió en la primera versión y se quitó porque, igual que el Emprendedor original, ganaba felicidad con lo mismo que da dinero en el Monopoly clásico. Una partida guardada con un Inversionista sigue como Emprendedor.

### 3.4 Salir por la ciudad (renta de lujo)

- **Todos los roles** ganan felicidad al pagar renta: es salir a disfrutar un lugar. Cuanto más lujoso el lugar, más felicidad.
- **Lujo** = lado del tablero donde está la propiedad (1 a 4, empezando desde Salida; el lado 4 es el más caro) + nivel de la propiedad (0 a 4). Va de 1 a 8.
- Puntos = lujo ÷ divisor del rol (redondeado hacia abajo), **mínimo +1**:

| Rol | Divisor | Lujo 1 | Lujo 4 | Lujo 8 |
|---|---|---|---|---|
| 🛍️ Consumista | 2 | +1 | +2 | +4 |
| ✈️ Trotamundos | 2 | +1 | +2 | +4 |
| 🎉 Social | 3 | +1 | +1 | +2 |
| 🏢 Emprendedor | 4 | +1 | +1 | +2 |
| 🐷 Ahorrador | 4 | +1 | +1 | +2 |
| 🦈 Prestamista | 4 | +1 | +1 | +2 |
| 🧘 Minimalista | 4 | +1 | +1 | +2 |

El 🦎 Camaleón usa el divisor de su personalidad actual.

- Se suma aparte de los gustos del rol (el Consumista cobra también su +1 por cada $100, y el Trotamundos su sello). En el historial aparece como "Saliste a un lugar".
- Una renta negativa (sección 4.2 de `GAME_RULES.md`) no cuenta: quien cae cobra en vez de pagar.

### 3.5 Rival secreto (todos los jugadores)

- No es un rol: es una mecánica para **todos**, sea cual sea su rol (el Rival existió como rol y pasó a ser esto; una partida guardada con un Rival sigue como Social).
- Al empezar, la app sienta a todos en un círculo al azar y a cada jugador le asigna como **rival** al siguiente. Así cada jugador tiene exactamente un rival y es el rival de exactamente otro jugador. Con un solo jugador no hay rivales.
- Es secreto: cada uno ve su rival en "Mi rol", pero nadie sabe quién lo tiene de rival. Se revela en la pantalla final.

| Qué pasa | Felicidad |
|---|---|
| Terminar la ronda con más patrimonio que tu rival (sección 7 de `GAME_RULES.md`) | +3 |
| Terminar la ronda con menos patrimonio que tu rival (con el mismo, nada) | −1 |
| Tu rival te paga renta | +3 |
| Le ganas una subasta a tu rival (si él también pujó) | +3 |
| Tu rival va a la cárcel o hipoteca una propiedad | +1 |
| Tu rival quiebra | +8 |

- Como todos la tienen, no cambia el equilibrio entre roles. Estos puntos no dependen del rol, así que el Camaleón los recibe con cualquier personalidad. En el historial aparecen como "Vas por delante de tu rival", "Tu rival te pagó renta", etc.

## 4. Ruleta de roles

- Al iniciar una partida Monopolife, todos los dispositivos muestran a pantalla completa una ruleta con los 7 roles que se reparten (el Minimalista aún no). Gira unos segundos, se detiene en el rol del jugador y muestra su tarjeta de rol (nombre, descripción, gustos y disgusto) con un botón "¡Entendido!".
- El rol ya está decidido por el host antes de girar; la ruleta es solo la animación de la revelación. Como el host envía el estado inicial a todos a la vez, las ruletas giran prácticamente al mismo tiempo.
- Si un jugador no confirmó su rol (ej. cerró la app o se reconectó), la ruleta se le vuelve a mostrar hasta que confirme.
- **Jugadores sin teléfono** (controlados desde el iPhone del host): tras la ruleta del host, la app muestra "Pasa el teléfono a {nombre}" y luego la ruleta de ese jugador, uno por uno.
- Durante la partida, cada jugador puede volver a ver su tarjeta de rol desde el tablero.

## 5. Tarjetas de Vida

- En Monopolife **no se usan las cartas físicas de Suerte ni de Caja de Comunidad**. Al caer en una de esas casillas, el jugador (en su turno) pulsa "Sacar Tarjeta de Vida" en la app.
- **El host reparte la tarjeta**: al pulsar el botón, al host le aparece un aviso "Tarjeta de Vida para {nombre}" con dos opciones:
  - **Darle una tarjeta buena**: una tarjeta al azar que le dé felicidad a ese jugador según su rol secreto (o la personalidad actual del Camaleón). Sale de lo que queda en el mazo; si ahí no queda ninguna buena para él, sale de todo el mazo sin tocar lo que queda.
  - **Tarjeta al azar**: la siguiente del mazo, como siempre.
  El host puede cerrar el aviso con "Decidir luego" y reabrirlo desde el tablero. Mientras tanto, el jugador ve "Esperando a que el host reparta tu Tarjeta de Vida…" y no puede terminar su turno ni pedir otra. El host no ve qué rol tiene el jugador ni qué tarjeta le tocará: solo elige buena o al azar.
- El host baraja el mazo al iniciar la partida; se roba sin reemplazo y se vuelve a barajar cuando se acaba.
- **Felicidad según el rol**: cada tarjeta define cuánta felicidad da o quita **a cada rol** (el Camaleón usa la columna de su personalidad actual) (columnas de la tabla 5.1). Un carro nuevo encanta al Consumista y al Trotamundos, pero al Ahorrador le duele gastar; una pelea con un amigo destroza al Social y apenas afecta a los demás. La tarjeta que se muestra al jugador solo indica el efecto para **su** rol.
- Hay tarjetas buenas y malas: aproximadamente un tercio del mazo es mala suerte para todos, y muchas tarjetas buenas para unos son malas para otros.
- Tipos de tarjeta:
  - **Evento**: se aplica sola (dinero y/o felicidad).
  - **Decisión**: ofrece algo a cambio de dinero (ej. comprarte un carro). El jugador ve cuánta felicidad le daría (o quitaría) a su rol y elige aceptar o pasar. Si no le alcanza el dinero, solo puede pasar. Pasar no cambia nada. Mientras tenga una decisión pendiente no puede terminar su turno ni sacar otra tarjeta.
  - **Posesión**: afecta a quien tiene cierta posesión (ver 5.2). Si el jugador no la tiene, no pasa nada (ni dinero ni felicidad).
  - **Movimiento**: indica mover la ficha física (ej. "ve a Salida"); la app solo muestra la instrucción y aplica su felicidad. Los cobros que resulten (salario, renta) se reportan como siempre.
- Si una tarjeta obliga a pagar y el jugador no tiene suficiente efectivo, paga lo que tenga y el resto se ignora (las tarjetas nunca provocan bancarrota por sí solas). En "Tu cumpleaños", cada jugador paga lo que pueda hasta $20.

### 5.1 Mazo inicial (30 tarjetas, placeholder)

Las columnas de emojis son la felicidad para cada rol: 🛍️ Consumista, 🏢 Emprendedor, 🐷 Ahorrador, 🎉 Social, ✈️ Trotamundos, 🦈 Prestamista, 🧘 Minimalista. El 🦎 Camaleón no tiene columna: usa la de su personalidad actual.

| # | Tarjeta | Tipo | Efecto | 🛍️ | 🏢 | 🐷 | 🎉 | ✈️ | 🦈 | 🧘 |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Cómprate un carro | Decisión | Paga $300 → obtienes 🚗 Carro | +7 | +3 | −2 | +3 | +6 | +1 | 0 |
| 2 | Televisor gigante | Decisión | Paga $200 → obtienes 📺 Televisor | +5 | +1 | −1 | +3 | 0 | 0 | 0 |
| 3 | Abres un food truck | Decisión | Paga $250 → obtienes 🚚 Food truck | +2 | +8 | 0 | +2 | +1 | +3 | 0 |
| 4 | Vacaciones en la playa | Decisión | Paga $250 | +3 | +1 | −2 | +3 | +8 | 0 | +4 |
| 5 | Organizas una fiesta | Decisión | Paga $150; además cada otro jugador activo +1 | +2 | +1 | −2 | +7 | +2 | 0 | +5 |
| 6 | Inviertes en una startup | Decisión | Paga $200 | 0 | +4 | +1 | +1 | 0 | +5 | 0 |
| 7 | Plan de pensiones | Decisión | Paga $150 | −1 | +1 | +7 | 0 | −1 | +5 | +3 |
| 8 | Ropa de marca | Decisión | Paga $100 | +3 | +1 | −2 | +2 | 0 | 0 | 0 |
| 9 | Se te rompe el carro | Posesión | Si tienes 🚗: pagas $150 de reparación. Si no: no pasa nada | −3 | −2 | −4 | −2 | −5 | −3 | −1 |
| 10 | Te roban el televisor | Posesión | Si tienes 📺: lo pierdes. Si no: no pasa nada | −5 | −1 | −2 | −2 | 0 | −2 | 0 |
| 11 | Inspección al food truck | Posesión | Si tienes 🚚: pagas $100 de multa. Si no: no pasa nada | −1 | −4 | −2 | −1 | −1 | −2 | −1 |
| 12 | Te enfermas | Evento | Pagas $100 | −3 | −3 | −3 | −3 | −3 | −3 | −3 |
| 13 | Multa de tránsito | Evento | Pagas $50 | −1 | −1 | −2 | −1 | −1 | −2 | −1 |
| 14 | Recorte de personal | Evento | Pagas $150 | −2 | −4 | −2 | −2 | −1 | −2 | −1 |
| 15 | La bolsa se desploma | Evento | Pagas $100 | −1 | −2 | −2 | −1 | 0 | −4 | 0 |
| 16 | Vuelo cancelado | Evento | Cobras $50 de compensación | −1 | −1 | +1 | −1 | −4 | +1 | −2 |
| 17 | Pelea con un amigo | Evento | — | −1 | −1 | −1 | −5 | −1 | −1 | −3 |
| 18 | Mala racha: a la cárcel | Movimiento | Mueve tu ficha a la cárcel (el −3 de la cárcel, sección 2) | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| 19 | Tu cumpleaños | Evento | Cada otro jugador activo te paga $20 | +2 | +2 | +2 | +5 | +2 | +2 | +4 |
| 20 | Bono de fin de año | Evento | Cobras $150 | +3 | +2 | +6 | +1 | +2 | +4 | +1 |
| 21 | Cliente importante | Evento | Cobras $100 | +1 | +5 | +2 | +1 | +1 | +3 | +1 |
| 22 | Dividendos | Evento | Cobras $20 por cada propiedad en la que tienes acciones (máx $200) | +1 | +2 | +3 | 0 | 0 | +4 | 0 |
| 23 | Viaje de mochilero | Movimiento | Avanza tu ficha a Salida (cobras salario como siempre) | 0 | +1 | +2 | +2 | +7 | 0 | +5 |
| 24 | Reencuentro con amigos | Evento | — | +2 | +1 | +1 | +5 | +3 | +1 | +5 |
| 25 | Black Friday | Evento | Pagas $50 | +3 | 0 | +1 | +1 | 0 | 0 | −2 |
| 26 | Un día perfecto | Evento | — | +3 | +3 | +3 | +3 | +3 | +3 | +3 |
| 27 | Devolución de impuestos | Evento | Cobras $100 | +1 | +2 | +5 | +1 | +1 | +4 | +1 |
| 28 | Boda en otro país | Evento | Pagas $100 | +1 | 0 | −2 | +4 | +6 | −1 | +4 |
| 29 | Cupones de descuento | Evento | Cobras $30 | +1 | 0 | +5 | 0 | 0 | +3 | +2 |
| 30 | Horas extra | Evento | Cobras $100 | +1 | +3 | +4 | −2 | −2 | +3 | −2 |

Suma de lo que cada rol puede sacar del mazo (decisiones solo si son positivas): Consumista 23, Emprendedor 22, Ahorrador 23, Social 24, Trotamundos 24, Prestamista 22, Minimalista 22. El Ahorrador tiene más tarjetas que le restan, pero son decisiones que puede pasar, y pasar le deja el dinero que suma en su fin de ronda.

### 5.2 Posesiones

- Algunas decisiones dan una **posesión**: 🚗 Carro, 📺 Televisor, 🚚 Food truck. Cada jugador tiene como máximo una de cada tipo.
- Las tarjetas de tipo Posesión solo afectan a quien la tiene (se rompe el carro, roban el televisor, inspección del food truck). Así, comprar cosas trae alegría ahora y riesgo después.
- Si el jugador ya tiene esa posesión y vuelve a sacar la tarjeta para comprarla, puede aceptarla igual (la cambia por una nueva): paga y recibe la felicidad, pero sigue teniendo una sola.
- "Te roban el televisor" quita la posesión; se puede volver a comprar con otra tarjeta.
- Las posesiones son visibles solo para su dueño durante la partida (delatan el rol) y se muestran en la pantalla final. No cuentan para el patrimonio ni se pueden negociar en el Mercado.

## 6. Bancarrota en Monopolife

- La bancarrota se declara igual que en Classic (`GAME_RULES.md` sección 6) y sus acciones de propiedades, dinero, tratos pendientes, inversiones y deuda de tarjeta se resuelven igual.
- **Diferencia**: el jugador **no queda eliminado**. Pierde la mitad de su felicidad (conserva la mitad redondeada hacia abajo), recibe un **saldo de rescate de $500** de la banca y sigue jugando en su turno normal.
- Conserva su rol, su historial y sus sellos (Trotamundos).

## 7. Fin de la partida

- La partida termina automáticamente cuando se completa la última ronda configurada (en el momento en que la ronda N terminaría y empezaría la N+1). Antes de terminar se aplican los efectos de "al terminar la ronda" de esa última ronda.
- Con la partida terminada ya no se acepta ninguna acción.
- **Gana quien tenga más felicidad.** Empate: gana el de mayor patrimonio (sección 7 de `GAME_RULES.md`); si sigue el empate, comparten la victoria.
- Pantalla final (todos los dispositivos): ranking con felicidad de todos, el rol de cada uno revelado (con la última personalidad del Camaleón y el rival secreto de cada jugador) y el desglose de cada jugador por motivo (rol, tarjetas, bancarrota) y sus posesiones, para poder ajustar el equilibrio entre partidas.

## 8. Lo que no cambia

- Precios, rentas, niveles, hipotecas, Mercado, inversiones, préstamos entre jugadores, tarjetas de crédito, turnos, subastas, impuestos, casillas de viaje y la cobertura de acciones al subir de nivel funcionan exactamente como en `GAME_RULES.md`.
- Un préstamo entre jugadores es un trato del Mercado, así que cuenta para el Social como cualquier otro (puntuable si presta al menos $50). Los pagos del préstamo no tienen efecto de rol, y el disgusto del Ahorrador sigue siendo solo por préstamos de tarjeta.
- Las house rules siguen siendo configurables igual, con estas notas:
  - **Free Parking Jackpot**: igual que en Classic. Cobrar el bote no tiene efecto de rol (el dinero ya ayuda al Ahorrador en su fin de ronda).
  - **Eventos del tablero**: igual que en Classic, sin efecto de rol: solo mueven dinero, rentas o niveles. La renovación urbana no cuenta como subir de nivel.
  - **Cartas del host**: igual que en Classic. La subida de nivel gratis de "Avanza y sube de nivel" no cuenta como subir de nivel para el Consumista, porque nadie la paga.
  - **Niveles secretos**: solo existen en Classic.
