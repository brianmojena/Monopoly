# Reglas del Modo Monopolife

Monopolife es un **segundo modo de juego** que se elige al crear la partida. Usa el mismo tablero, propiedades, precios, rentas, niveles, Mercado, inversiones y tarjetas de crédito que el modo **Monopoly Classic** (todo `GAME_RULES.md` sigue aplicando), salvo lo que este documento cambia explícitamente.

La diferencia central: **no gana quien tiene más dinero, sino quien tiene más felicidad**. El dinero es un medio, no el fin. Cada jugador recibe al azar un **rol secreto** que define qué le hace feliz y qué no, así cada partida se juega distinto.

> Todos los valores numéricos de este documento (puntos, montos, topes) son **placeholder** para la primera versión. Deben vivir en datos declarativos (una sola tabla por concepto) para poder ajustarlos tras las primeras partidas sin tocar lógica.

## 1. Selección de modo

- En la sala de espera, el host elige el modo: **Monopoly Classic** (por defecto, el juego actual sin cambios) o **Monopolife**.
- Los clientes ven en la sala qué modo está elegido. Las tarjetas de salas cercanas muestran el modo.
- Si el modo es Monopolife, el host elige también el **número de rondas** (por defecto 15; opciones 10, 15, 20, 25).
- El modo no se puede cambiar una vez iniciada la partida.
- En Monopolife cada jugador empieza con **$2,000** (en Classic, $1,500), salvo que el host cambie el saldo inicial o ponga una diferencia entre jugadores en la sala (`GAME_RULES.md`, sección 8.6): hay más margen para gastar en lo que a cada rol le hace feliz.

## 2. Felicidad

- Cada jugador tiene un contador de **puntos de felicidad** (entero, empieza en 0, nunca baja de 0).
- La felicidad cambia por: los **gustos y disgustos de su rol**, la renta (+10 o más cada vez que pagas) y el **rival** (sección 3), las **Tarjetas de Vida** (sección 5), la **cárcel** y la **bancarrota** (sección 6).
- **Cárcel**: ir a la cárcel (cuando el jugador lo marca con el botón "Cárcel", por la casilla, una carta o 3 dobles; sección 5 de `GAME_RULES.md`) resta **−3 a cualquier rol por igual**, y cada turno que empieza estando preso (1.er, 2.º y 3.er turno de cárcel, sección 5 de `GAME_RULES.md`) resta **−2 más**: quedarse los 3 turnos cuesta −9 en total. Salir de la cárcel (con dobles, pagando o al cumplir los 3 turnos) no cambia la felicidad; el turno en que sale con dobles o pagando ya contó si empezó preso. Por eso la tarjeta "Mala racha: a la cárcel" no tiene felicidad propia: el castigo llega al marcar la cárcel.
- Cada cambio queda en un **historial** (jugador, puntos, motivo, ronda) que el jugador puede consultar y que se usa en la pantalla final para mostrar de dónde salió la felicidad de cada uno.
- **Visibilidad**: cada jugador solo ve su propia felicidad y su propio historial. La felicidad de los demás se revela al final (ver sección 7). Mostrarla durante la partida delataría los roles.

## 3. Roles

### 3.1 Asignación
- Al iniciar la partida, el host asigna un rol al azar a cada jugador. Mientras haya roles sin usar no se repiten; con más jugadores que roles, se vuelve a sortear entre todos los roles.
- **Los roles son secretos**: cada jugador solo ve el suyo. Se revelan en la pantalla final.
- Al asignar, el 🦎 Camaleón recibe al azar su primera personalidad (secreta), y cada jugador recibe además su **rival** (sección 3.5).
- La asignación se muestra con una **ruleta** que aparece a la vez en la pantalla de todos los jugadores al empezar la partida (ver sección 4).

### 3.2 Principio de equilibrio
- Ningún rol debe tener ventaja: con cada rol jugando su mejor estrategia, todos deben ganar una proporción parecida de partidas.
- Cada rol tiene un **marcador propio que controla él mismo** (no depende de que otro jugador acepte un trato o un préstamo) y un **disgusto** que lo tensiona con el dinero o con sus gustos. Además **cada Tarjeta de Vida afecta distinto a cada rol** (sección 5).
- Ningún gusto se cobra por *contar* cosas baratas (ej. "+1 por subir de nivel" sin importar el costo): se paga según el dinero en juego, para que las propiedades baratas no sean un atajo.
- La renta (sección 3.4) da +10 a todos: es la fuente de felicidad común más grande y suaviza las diferencias entre roles.
- El mazo está equilibrado por rol: sumando lo que cada rol puede sacar del mazo completo (en las decisiones solo cuenta lo positivo, porque se puede pasar), todos los roles quedan dentro de ±2 puntos entre sí. Cualquier cambio a las tarjetas debe mantener esa regla.
- Los topes (por turno o por ronda) existen para que ningún rol pueda "farmear" puntos repitiendo una acción trivial.
- **Cómo se comprobó**: los valores se ajustaron con un simulador de partidas completas (dados, tablero de 40 casillas, las reglas reales de la app y bots que buscan la mejor estrategia de cada rol). Con 4 jugadores y 15 rondas, cada rol gana entre el 22% y el 28% de las partidas (lo justo sería el 25%). Antes de este rediseño iban del 12% (Social) al 39% (Consumista). Con 3, 5 o 6 jugadores la diferencia es algo mayor, porque el Ahorrador rinde más con pocos jugadores y el Social y el Emprendedor con muchos.

### 3.3 Tabla de roles

Hay **6 roles**.

| Rol | Gustos (+) | Disgusto (−) |
|---|---|---|
| 🛍️ **Consumista** — le gusta gastar | Al terminar su turno: +1 por cada $70 que gastó desde su turno anterior (máx +5). Cuenta comprar propiedades (al banco, en subasta o compra compartida), subir de nivel (su parte), pagar renta, pagar viajes y comprar en Tarjetas de Vida. Bajar de nivel resta lo que le devuelven. | Terminar la ronda con más de $2,000 en efectivo: −2. |
| 🏢 **Emprendedor** — le gusta construir negocios y que la gente caiga en ellos | Cobrar renta: +1 por cada $75 que le pagan (máx +6 por ronda). Subir de nivel una propiedad que **administra**: +1 por cada $100 que paga (mínimo +1). | Hipotecar una propiedad que administra: −3. |
| 🐷 **Ahorrador** — le gusta ver crecer su cuenta | Al terminar su turno (cuando pulsa "Terminar turno"): +1 por cada $350 en efectivo (máx +4). Cobrar salario sin deuda de tarjeta: +2. | Pedir un préstamo de tarjeta de crédito: −4. |
| 🎉 **Social** — le gusta tratar con todos | Cada movimiento de dinero entre él y otro jugador: +3 (máx 3 por ronda). Cuenta pagarle o cobrarle renta, cerrar un trato del Mercado con él (incluidos cubrir la parte de un accionista al subir de nivel y recomprar esas acciones), o un pago libre de $50 o más, lo dé o lo reciba. | Desde la ronda 2: terminar una ronda sin ningún movimiento de dinero con otro jugador: −2. |
| ✈️ **Trotamundos** — le gusta viajar y conocer, no echar raíces | Cobrar salario en Salida: +5. Pagar un viaje en una casilla de viaje: +5. La primera vez que paga renta en cada grupo de color ("sello"): +4; al completar los 8 sellos: +8 extra. Volver a pagar renta en un grupo ya sellado: +1. | Comprar una propiedad al banco (compra directa, subasta o compra compartida) quedando con acciones en 3 o más propiedades: −2. Las dos primeras no le molestan. |
| 🦎 **Camaleón** — cambia de personalidad cada pocas rondas | Tiene los gustos de su **personalidad actual**: otro rol al azar entre Consumista, Emprendedor, Ahorrador, Social y Trotamundos. Al terminar cada 3 rondas (3, 6, 9…, salvo la última) cambia a otra personalidad distinta: +1 por cada cambio. | Los disgustos de su personalidad actual. |

Aclaraciones:
- "Al terminar la ronda" se evalúa para todos los jugadores cuando el último jugador de la ronda termina su turno (el momento en que `round` se incrementa).
- "Cobrar renta" / "pagar renta" se refiere a `collectRent` con monto > 0. Para el Emprendedor cuenta lo que le toca de la renta después de los cortes de inversiones (sección 4.8 de `GAME_RULES.md`); lo que se lleva un inversor no cuenta como renta cobrada para él.
- **Consumista**: el gasto se acumula en cualquier momento (también lo que paga por su parte cuando otro accionista sube de nivel) y se cuenta al terminar su turno; después vuelve a 0. No cuentan los impuestos, la fianza de la cárcel, los tratos del Mercado ni los pagos de préstamos: son obligaciones o intercambios, no gastos. Restar lo devuelto al bajar de nivel evita subir y bajar de nivel en bucle para sumar gasto.
- **Emprendedor**: la subida de nivel gratis de una carta del host o la renovación urbana no cuentan, porque nadie la paga. Si sube de nivel cubriendo la parte de otro accionista, cuenta todo lo que pagó.
- **Social**: cada movimiento cuenta aunque sea con el mismo jugador. En un pago de renta, cuentan quien paga y cada accionista que cobra. Un trato o un pago libre por menos de $50 no cuenta (un trato con acciones siempre cuenta). Puede regalar dinero para no quedarse solo, pero regalar lo deja atrás frente a su rival y más cerca de la bancarrota.
- **Camaleón**: las Tarjetas de Vida y el extra de lujo de la renta (3.4) le afectan como a su personalidad actual. Al cambiar de personalidad conserva su felicidad y sus sellos de Trotamundos. El cambio se sortea con una semilla guardada en la partida, así que es reproducible.
- **Roles eliminados**: el Inversionista, el Prestamista y el Minimalista existieron y se quitaron. El Inversionista (y el Emprendedor original, que sumaba +1 por cada propiedad con nivel) ganaba felicidad con lo mismo que da dinero y con subidas de nivel baratas. El Prestamista y la parte de tratos del Social original casi no sumaban porque dependían de que otro jugador aceptara. Una partida guardada sigue así: Inversionista → Emprendedor, Prestamista → Ahorrador, Minimalista → Social.

### 3.4 Salir por la ciudad (renta)

- **Todos los roles** ganan felicidad al pagar renta: es salir a disfrutar un lugar. Da **+10**, más un extra según el lujo del lugar.
- **Lujo** = lado del tablero donde está la propiedad (1 a 4, empezando desde Salida; el lado 4 es el más caro) + nivel de la propiedad (0 a 4). Va de 1 a 8.
- Puntos = 10 + lujo ÷ divisor del rol (redondeado hacia abajo):

| Rol | Divisor | Lujo 1 | Lujo 4 | Lujo 8 |
|---|---|---|---|---|
| 🛍️ Consumista | 2 | +10 | +12 | +14 |
| ✈️ Trotamundos | 2 | +10 | +12 | +14 |
| 🎉 Social | 3 | +10 | +11 | +12 |
| 🏢 Emprendedor | 4 | +10 | +11 | +12 |
| 🐷 Ahorrador | 4 | +10 | +11 | +12 |

El 🦎 Camaleón usa el divisor de su personalidad actual.

- Se suma aparte de los gustos del rol (el Consumista cuenta además la renta como gasto, el Trotamundos su sello y el Social el movimiento de dinero). En el historial aparece como "Saliste a un lugar".
- Una renta negativa (sección 4.2 de `GAME_RULES.md`) no cuenta: quien cae cobra en vez de pagar.

### 3.5 Rival (todos los jugadores)

- No es un rol: es una mecánica para **todos**, sea cual sea su rol (el Rival existió como rol y pasó a ser esto; una partida guardada con un Rival sigue como Social).
- Los rivales son **directos y mutuos**: cada jugador es rival del que está sentado frente a él en el orden de turnos (el jugador *i* con el *i + N/2*). Con 4 jugadores: 1 ↔ 3 y 2 ↔ 4; con 6: 1 ↔ 4, 2 ↔ 5, 3 ↔ 6; con 2: 1 ↔ 2.
- Con un número impar de jugadores, el último queda sin pareja y tiene como rival al jugador 1, sin que sea mutuo (el jugador 1 sigue teniendo a su pareja como rival). Con un solo jugador no hay rivales.
- Cada uno ve su rival en "Mi rol", y se muestra también en la pantalla final.

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

- Al iniciar una partida Monopolife, todos los dispositivos muestran a pantalla completa una ruleta con los 6 roles. Gira unos segundos, se detiene en el rol del jugador y muestra su tarjeta de rol (nombre, descripción, gustos y disgusto) con un botón "¡Entendido!".
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

Las columnas de emojis son la felicidad para cada rol: 🛍️ Consumista, 🏢 Emprendedor, 🐷 Ahorrador, 🎉 Social, ✈️ Trotamundos. El 🦎 Camaleón no tiene columna: usa la de su personalidad actual.

| # | Tarjeta | Tipo | Efecto | 🛍️ | 🏢 | 🐷 | 🎉 | ✈️ |
|---|---|---|---|---|---|---|---|---|
| 1 | Cómprate un carro | Decisión | Paga $300 → obtienes 🚗 Carro | +7 | +3 | −2 | +3 | +6 |
| 2 | Televisor gigante | Decisión | Paga $200 → obtienes 📺 Televisor | +5 | +1 | −1 | +3 | 0 |
| 3 | Abres un food truck | Decisión | Paga $250 → obtienes 🚚 Food truck | +2 | +8 | 0 | +2 | +1 |
| 4 | Vacaciones en la playa | Decisión | Paga $250 | +3 | +1 | −2 | +3 | +8 |
| 5 | Organizas una fiesta | Decisión | Paga $150; además cada otro jugador activo +1 | +2 | +1 | −2 | +7 | +2 |
| 6 | Inviertes en una startup | Decisión | Paga $200 | 0 | +4 | +1 | +1 | 0 |
| 7 | Plan de pensiones | Decisión | Paga $150 | −1 | +1 | +7 | 0 | −1 |
| 8 | Ropa de marca | Decisión | Paga $100 | +3 | +1 | −2 | +2 | 0 |
| 9 | Se te rompe el carro | Posesión | Si tienes 🚗: pagas $150 de reparación. Si no: no pasa nada | −3 | −2 | −4 | −2 | −5 |
| 10 | Te roban el televisor | Posesión | Si tienes 📺: lo pierdes. Si no: no pasa nada | −5 | −1 | −2 | −2 | 0 |
| 11 | Inspección al food truck | Posesión | Si tienes 🚚: pagas $100 de multa. Si no: no pasa nada | −1 | −4 | −2 | −1 | −1 |
| 12 | Te enfermas | Evento | Pagas $100 | −3 | −3 | −3 | −3 | −3 |
| 13 | Multa de tránsito | Evento | Pagas $50 | −1 | −1 | −2 | −1 | −1 |
| 14 | Recorte de personal | Evento | Pagas $150 | −2 | −4 | −2 | −2 | −1 |
| 15 | La bolsa se desploma | Evento | Pagas $100 | −1 | −2 | −2 | −1 | 0 |
| 16 | Vuelo cancelado | Evento | Cobras $50 de compensación | −1 | −1 | +1 | −1 | −4 |
| 17 | Pelea con un amigo | Evento | — | −1 | −1 | −1 | −5 | −1 |
| 18 | Mala racha: a la cárcel | Movimiento | Mueve tu ficha a la cárcel (el −3 de la cárcel, sección 2) | 0 | 0 | 0 | 0 | 0 |
| 19 | Tu cumpleaños | Evento | Cada otro jugador activo te paga $20 | +2 | +2 | +2 | +5 | +2 |
| 20 | Bono de fin de año | Evento | Cobras $150 | +3 | +2 | +6 | +1 | +2 |
| 21 | Cliente importante | Evento | Cobras $100 | +1 | +5 | +2 | +1 | +1 |
| 22 | Dividendos | Evento | Cobras $20 por cada propiedad en la que tienes acciones (máx $200) | +1 | +2 | +3 | 0 | 0 |
| 23 | Viaje de mochilero | Movimiento | Avanza tu ficha a Salida (cobras salario como siempre) | 0 | +1 | +2 | +2 | +7 |
| 24 | Reencuentro con amigos | Evento | — | +2 | +1 | +1 | +5 | +3 |
| 25 | Black Friday | Evento | Pagas $50 | +3 | 0 | +1 | +1 | 0 |
| 26 | Un día perfecto | Evento | — | +3 | +3 | +3 | +3 | +3 |
| 27 | Devolución de impuestos | Evento | Cobras $100 | +1 | +2 | +5 | +1 | +1 |
| 28 | Boda en otro país | Evento | Pagas $100 | +1 | 0 | −2 | +4 | +6 |
| 29 | Cupones de descuento | Evento | Cobras $30 | +1 | 0 | +5 | 0 | 0 |
| 30 | Horas extra | Evento | Cobras $100 | +1 | +3 | +4 | −2 | −2 |

Suma de lo que cada rol puede sacar del mazo (decisiones solo si son positivas): Consumista 23, Emprendedor 22, Ahorrador 23, Social 24, Trotamundos 24. El Ahorrador tiene más tarjetas que le restan, pero son decisiones que puede pasar, y pasar le deja el dinero que suma en su fin de ronda.

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
- Pantalla final (todos los dispositivos): ranking con felicidad de todos, el rol de cada uno revelado (con la última personalidad del Camaleón y el rival de cada jugador) y el desglose de cada jugador por motivo (rol, tarjetas, bancarrota) y sus posesiones, para poder ajustar el equilibrio entre partidas.

## 8. Lo que no cambia

- Precios, rentas, niveles, hipotecas, Mercado, inversiones, préstamos entre jugadores, tarjetas de crédito, turnos, subastas, impuestos, casillas de viaje y la cobertura de acciones al subir de nivel funcionan exactamente como en `GAME_RULES.md`.
- Un préstamo entre jugadores es un trato del Mercado, así que cuenta para el Social como cualquier otro (si presta al menos $50). Los pagos del préstamo no tienen efecto de rol, y el disgusto del Ahorrador sigue siendo solo por préstamos de tarjeta.
- Las house rules siguen siendo configurables igual, con estas notas:
  - **Free Parking Jackpot**: igual que en Classic. Cobrar el bote no tiene efecto de rol (el dinero ya ayuda al Ahorrador en su fin de ronda).
  - **Eventos del tablero**: igual que en Classic, sin efecto de rol: solo mueven dinero, rentas o niveles. La renovación urbana no cuenta como subir de nivel.
  - **Cartas del host**: igual que en Classic. La subida de nivel gratis de "Avanza y sube de nivel" no cuenta para el Emprendedor ni como gasto del Consumista, porque nadie la paga.
  - **Niveles secretos**: solo existen en Classic.
