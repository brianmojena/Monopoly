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
- La felicidad cambia por: los **gustos y disgustos de su rol** (sección 3), las **Tarjetas de Vida** (sección 5) y la **bancarrota** (sección 6).
- Cada cambio queda en un **historial** (jugador, puntos, motivo, ronda) que el jugador puede consultar y que se usa en la pantalla final para mostrar de dónde salió la felicidad de cada uno.
- **Visibilidad**: cada jugador solo ve su propia felicidad y su propio historial. La felicidad de los demás se revela al final (ver sección 7). Mostrarla durante la partida delataría los roles.

## 3. Roles

### 3.1 Asignación
- Al iniciar la partida, el host asigna un rol al azar a cada jugador. Mientras haya roles sin usar no se repiten; con más jugadores que roles, se vuelve a sortear entre todos los roles.
- **Los roles son secretos**: cada jugador solo ve el suyo. Se revelan en la pantalla final.
- La asignación se muestra con una **ruleta** que aparece a la vez en la pantalla de todos los jugadores al empezar la partida (ver sección 4).

### 3.2 Principio de equilibrio
- Ningún rol debe tener ventaja: todos se diseñan para ganar, en una partida típica, una cantidad parecida de felicidad por ronda (objetivo: ~4–6 puntos por ronda).
- Cada rol tiene **gustos** (suman) y un **disgusto** (resta) propios (tabla 3.3), y además **cada Tarjeta de Vida afecta distinto a cada rol** (sección 5): la misma tarjeta puede alegrar mucho a uno y molestar a otro.
- El mazo está equilibrado por rol: sumando lo que cada rol puede sacar del mazo completo (en las decisiones solo cuenta lo positivo, porque se puede pasar), todos los roles quedan dentro de ±2 puntos entre sí. Cualquier cambio a las tarjetas debe mantener esa regla.
- Los topes por ronda existen para que ningún rol pueda "farmear" puntos repitiendo una acción trivial.

### 3.3 Tabla de roles

| Rol | Gustos (+) | Disgusto (−) |
|---|---|---|
| 🛍️ **Consumista** — le gusta gastar y vivir en lugares caros | Pagar renta: +1 por cada $100 pagados (máx +6 por pago). Subir de nivel una propiedad en la que tiene acciones: +2. | Al terminar la ronda con más de $1,500 en efectivo: −2 (el dinero guardado lo aburre). |
| 🏢 **Emprendedor** — le gusta tener negocios y que la gente caiga en ellos | Al terminar la ronda: +1 por cada propiedad en la que tiene acciones (máx +5). Cada vez que recibe renta de otro jugador: +2. | Hipotecar una propiedad que administra: −3. |
| 🐷 **Ahorrador** — le gusta ver crecer su cuenta | Al terminar la ronda: +1 por cada $400 en efectivo (máx +5). Cobrar salario sin deuda de tarjeta: +1. | Pedir un préstamo de tarjeta de crédito: −4. |
| 🎉 **Social** — le gusta negociar y compartir | Cada trato del Mercado ejecutado en el que participa: +3 (máx 2 tratos puntuables por ronda). Cuenta cualquier trato: compra compartida, inversión, oferta abierta, y también cubrir la parte de otro accionista al subir de nivel o recomprarle esas acciones (sección 4.3 de `GAME_RULES.md`). Solo es puntuable si mueve al menos $50 o al menos una acción. | Terminar una ronda sin haber participado en ningún trato ejecutado: −1. |
| 📈 **Inversionista** — le gusta diversificar y cobrar sin trabajar | Crear una inversión (sección 4.8 de `GAME_RULES.md`) como inversor: +3. Cada vez que cobra el corte de una inversión: +1. Al terminar la ronda: +1 por cada grupo de color distinto en el que tiene acciones (máx +4). | Pagar un impuesto (incluido el evento del tablero "Revalúo de impuestos"): −2. |
| ✈️ **Trotamundos** — le gusta viajar y conocer, no echar raíces | Cobrar salario en Salida: +2. Pagar un viaje en una casilla de viaje: +2. La primera vez que paga renta en cada grupo de color ("sello"): +3; al completar los 8 sellos: +8 extra. | Comprar una propiedad al banco (compra directa, subasta o compra compartida): −2. |

Aclaraciones:
- "Al terminar la ronda" se evalúa para todos los jugadores cuando el último jugador de la ronda termina su turno (el momento en que `round` se incrementa).
- "Recibe renta" / "paga renta" se refiere a `collectRent` con monto > 0. Un cobro vía inversión cuenta como corte de inversión, no como renta recibida.
- Los gustos por acción se aplican a quien hace la acción: el accionista que sube de nivel (cualquiera puede, no solo el administrador), el administrador al hipotecar, cada comprador en una compra compartida.
- Cubrir la parte de un accionista al subir de nivel cuenta como un trato entre quien cubre y el cubierto (siempre mueve acciones, así que es puntuable); recomprar esas acciones también.
- "Revalúo de impuestos" cuenta como un solo impuesto por evento para cada accionista que pagó algo, aunque tenga acciones en varias propiedades del grupo.
- Las rentas de Ultimate Banking (sección 4.2.1 de `GAME_RULES.md`) empiezan en $70, por eso el Consumista cuenta cada $100 y no cada $50: con $50 casi cualquier renta le daba varios puntos.

## 4. Ruleta de roles

- Al iniciar una partida Monopolife, todos los dispositivos muestran a pantalla completa una ruleta con los 6 roles. Gira unos segundos, se detiene en el rol del jugador y muestra su tarjeta de rol (nombre, descripción, gustos y disgusto) con un botón "¡Entendido!".
- El rol ya está decidido por el host antes de girar; la ruleta es solo la animación de la revelación. Como el host envía el estado inicial a todos a la vez, las ruletas giran prácticamente al mismo tiempo.
- Si un jugador no confirmó su rol (ej. cerró la app o se reconectó), la ruleta se le vuelve a mostrar hasta que confirme.
- **Jugadores sin teléfono** (controlados desde el iPhone del host): tras la ruleta del host, la app muestra "Pasa el teléfono a {nombre}" y luego la ruleta de ese jugador, uno por uno.
- Durante la partida, cada jugador puede volver a ver su tarjeta de rol desde el tablero.

## 5. Tarjetas de Vida

- En Monopolife **no se usan las cartas físicas de Suerte ni de Caja de Comunidad**. Al caer en una de esas casillas, el jugador (en su turno) pulsa "Sacar Tarjeta de Vida" en la app.
- El host baraja el mazo al iniciar la partida; se roba sin reemplazo y se vuelve a barajar cuando se acaba.
- **Felicidad según el rol**: cada tarjeta define cuánta felicidad da o quita **a cada uno de los 6 roles** (columnas de la tabla 5.1). Un carro nuevo encanta al Consumista y al Trotamundos, pero al Ahorrador le duele gastar; una pelea con un amigo destroza al Social y apenas afecta a los demás. La tarjeta que se muestra al jugador solo indica el efecto para **su** rol.
- Hay tarjetas buenas y malas: aproximadamente un tercio del mazo es mala suerte para todos, y muchas tarjetas buenas para unos son malas para otros.
- Tipos de tarjeta:
  - **Evento**: se aplica sola (dinero y/o felicidad).
  - **Decisión**: ofrece algo a cambio de dinero (ej. comprarte un carro). El jugador ve cuánta felicidad le daría (o quitaría) a su rol y elige aceptar o pasar. Si no le alcanza el dinero, solo puede pasar. Pasar no cambia nada. Mientras tenga una decisión pendiente no puede terminar su turno ni sacar otra tarjeta.
  - **Posesión**: afecta a quien tiene cierta posesión (ver 5.2). Si el jugador no la tiene, no pasa nada (ni dinero ni felicidad).
  - **Movimiento**: indica mover la ficha física (ej. "ve a Salida"); la app solo muestra la instrucción y aplica su felicidad. Los cobros que resulten (salario, renta) se reportan como siempre.
- Si una tarjeta obliga a pagar y el jugador no tiene suficiente efectivo, paga lo que tenga y el resto se ignora (las tarjetas nunca provocan bancarrota por sí solas). En "Tu cumpleaños", cada jugador paga lo que pueda hasta $20.

### 5.1 Mazo inicial (30 tarjetas, placeholder)

Las columnas de emojis son la felicidad para cada rol: 🛍️ Consumista, 🏢 Emprendedor, 🐷 Ahorrador, 🎉 Social, 📈 Inversionista, ✈️ Trotamundos.

| # | Tarjeta | Tipo | Efecto | 🛍️ | 🏢 | 🐷 | 🎉 | 📈 | ✈️ |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Cómprate un carro | Decisión | Paga $300 → obtienes 🚗 Carro | +7 | +3 | −2 | +3 | +1 | +6 |
| 2 | Televisor gigante | Decisión | Paga $200 → obtienes 📺 Televisor | +5 | +1 | −1 | +3 | +1 | 0 |
| 3 | Abres un food truck | Decisión | Paga $250 → obtienes 🚚 Food truck | +2 | +8 | 0 | +2 | +3 | +1 |
| 4 | Vacaciones en la playa | Decisión | Paga $250 | +3 | +1 | −2 | +3 | +1 | +8 |
| 5 | Organizas una fiesta | Decisión | Paga $150; además cada otro jugador activo +1 | +2 | +1 | −2 | +7 | +1 | +2 |
| 6 | Inviertes en una startup | Decisión | Paga $200 | 0 | +4 | +1 | +1 | +8 | 0 |
| 7 | Plan de pensiones | Decisión | Paga $150 | −1 | +1 | +7 | 0 | +4 | −1 |
| 8 | Ropa de marca | Decisión | Paga $100 | +3 | +1 | −2 | +2 | 0 | 0 |
| 9 | Se te rompe el carro | Posesión | Si tienes 🚗: pagas $150 de reparación. Si no: no pasa nada | −3 | −2 | −4 | −2 | −2 | −5 |
| 10 | Te roban el televisor | Posesión | Si tienes 📺: lo pierdes. Si no: no pasa nada | −5 | −1 | −2 | −2 | −1 | 0 |
| 11 | Inspección al food truck | Posesión | Si tienes 🚚: pagas $100 de multa. Si no: no pasa nada | −1 | −4 | −2 | −1 | −2 | −1 |
| 12 | Te enfermas | Evento | Pagas $100 | −3 | −3 | −3 | −3 | −3 | −3 |
| 13 | Multa de tránsito | Evento | Pagas $50 | −1 | −1 | −2 | −1 | −1 | −1 |
| 14 | Recorte de personal | Evento | Pagas $150 | −2 | −4 | −2 | −2 | −2 | −1 |
| 15 | La bolsa se desploma | Evento | Pagas $100 | −1 | −2 | −2 | −1 | −5 | 0 |
| 16 | Vuelo cancelado | Evento | Cobras $50 de compensación | −1 | −1 | +1 | −1 | 0 | −4 |
| 17 | Pelea con un amigo | Evento | — | −1 | −1 | −1 | −5 | −1 | −1 |
| 18 | Mala racha: a la cárcel | Movimiento | Mueve tu ficha a la cárcel | −2 | −2 | −2 | −3 | −2 | −3 |
| 19 | Tu cumpleaños | Evento | Cada otro jugador activo te paga $20 | +2 | +2 | +2 | +5 | +2 | +2 |
| 20 | Bono de fin de año | Evento | Cobras $150 | +3 | +2 | +6 | +1 | +2 | +2 |
| 21 | Cliente importante | Evento | Cobras $100 | +1 | +5 | +2 | +1 | +2 | +1 |
| 22 | Dividendos | Evento | Cobras $20 por cada propiedad en la que tienes acciones (máx $200) | +1 | +2 | +3 | 0 | +5 | 0 |
| 23 | Viaje de mochilero | Movimiento | Avanza tu ficha a Salida (cobras salario como siempre) | 0 | +1 | +2 | +2 | 0 | +7 |
| 24 | Reencuentro con amigos | Evento | — | +2 | +1 | +1 | +5 | +1 | +3 |
| 25 | Black Friday | Evento | Pagas $50 | +3 | 0 | +1 | +1 | 0 | 0 |
| 26 | Un día perfecto | Evento | — | +3 | +3 | +3 | +3 | +3 | +3 |
| 27 | Devolución de impuestos | Evento | Cobras $100 | +1 | +2 | +5 | +1 | +3 | +1 |
| 28 | Boda en otro país | Evento | Pagas $100 | +1 | 0 | −2 | +4 | 0 | +6 |
| 29 | Cupones de descuento | Evento | Cobras $30 | +1 | 0 | +5 | 0 | +1 | 0 |
| 30 | Horas extra | Evento | Cobras $100 | +1 | +3 | +4 | −2 | +1 | −2 |

Suma de lo que cada rol puede sacar del mazo (decisiones solo si son positivas): Consumista 21, Emprendedor 20, Ahorrador 21, Social 21, Inversionista 20, Trotamundos 21. El Ahorrador tiene más tarjetas que le restan, pero son decisiones que puede pasar, y pasar le deja el dinero que suma en su fin de ronda.

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
- Pantalla final (todos los dispositivos): ranking con felicidad de todos, el rol de cada uno revelado y el desglose de cada jugador por motivo (rol, tarjetas, bancarrota) y sus posesiones, para poder ajustar el equilibrio entre partidas.

## 8. Lo que no cambia

- Precios, rentas, niveles, hipotecas, Mercado, inversiones, tarjetas de crédito, turnos, subastas, impuestos, casillas de viaje y la cobertura de acciones al subir de nivel funcionan exactamente como en `GAME_RULES.md`.
- Las house rules siguen siendo configurables igual, con estas notas:
  - **Free Parking Jackpot**: igual que en Classic. Cobrar el bote no tiene efecto de rol (el dinero ya ayuda al Ahorrador en su fin de ronda).
  - **Eventos del tablero**: igual que en Classic. Solo "Revalúo de impuestos" tiene efecto de rol (Inversionista, tabla 3.3); el resto solo mueve dinero, rentas o niveles.
  - **Cartas del host**: igual que en Classic. La subida de nivel gratis de "Avanza y sube de nivel" no cuenta como subir de nivel para el Consumista, porque nadie la paga.
  - **Niveles secretos**: solo existen en Classic.
