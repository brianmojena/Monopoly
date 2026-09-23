# Reglas del Juego — Monopoly Ultimate Banking

Este documento describe las reglas de Monopoly en su edición **Ultimate Banking** que la app debe implementar. Es la referencia de negocio para cualquier lógica de banca, propiedades, turnos y dinero. Ante cualquier duda de comportamiento del sistema, este documento manda sobre la intuición general de "cómo se juega Monopoly clásico" — Ultimate Banking tiene diferencias deliberadas frente al Monopoly de tablero con billetes de papel.

> Modos de juego: este documento describe el modo **Monopoly Classic**. El modo **Monopolife** (gana quien tiene más felicidad, con roles secretos y Tarjetas de Vida) usa todas estas reglas más los cambios de [`MONOPOLIFE_RULES.md`](./MONOPOLIFE_RULES.md), que mandan sobre este documento cuando la partida es Monopolife.

> Nota de alcance: la app reemplaza **solo la banca digital** (el lector/tarjetas del dispositivo físico Ultimate Banking). El tablero, los dados, las fichas y las cartas de Suerte/Caja de Comunidad se siguen usando físicamente en la mesa. La app es responsable de dinero, propiedades, hipotecas, rentas, construcciones y del estado financiero de cada jugador.

## 1. Diferencias clave frente al Monopoly clásico

- **Sin dinero en papel**: todo el dinero es digital, gestionado por la app (originalmente por el dispositivo lector de tarjetas).
- **Niveles de renta pagados, no automáticos**: a diferencia de Ultimate Banking (donde el valor sube solo con que alguien caiga y pague renta), en esta app una propiedad solo sube de nivel —y cobra más renta— cuando su administrador **paga** para subirla. Caer o pagar renta nunca sube el nivel por sí solo (ver sección 4.2).
- **Sin colas en el banco**: cualquier jugador puede pagar/cobrar en cualquier momento sin esperar turno de "banquero humano", porque la banca es el sistema.
- **Tarjeta de banco por jugador**: cada jugador tiene una cuenta individual (equivalente a la tarjeta física), con saldo visible solo para sí mismo y para la banca (host).
- **Sin Casillas de Servicios Públicos (Utilities) con dados**: en Ultimate Banking, Electricidad y Agua funcionan como propiedades normales con renta fija/escalable, no como en el clásico (renta = múltiplo de los dados).
- **Eventos de "Bono en Casa" (Home Bonus / evento aleatorio de banco)**: el dispositivo Ultimate Banking ocasionalmente entrega bonos aleatorios a un jugador al azar en cada turno. Es un feature configurable (ver reglas opcionales).

> Estas diferencias deben confirmarse contra la caja/manual físico específico que posee el usuario si hay ambigüedad; este documento es la mejor reconstrucción de esas reglas y debe tratarse como la fuente canónica del proyecto una vez validada.

## 2. Configuración inicial

- Cada jugador recibe un saldo inicial estándar (definido en configuración de partida, valor por defecto histórico: 15,000 en la unidad de moneda del juego para Ultimate Banking, ajustable).
- Se define el número de jugadores (2–6 recomendado, ver reglas de proyecto para límites técnicos).
- Se elige quién es el dispositivo **host/banca** (ver `PROJECT_RULES.md`).
- **Sala de espera**: el host abre la sala y cada jugador se une desde su iPhone escribiendo su propio nombre. El host puede añadir jugadores sin teléfono, que juegan desde el iPhone del host (el host cambia entre ellos con "Jugando como" y la app lo cambia sola cuando les toca).
- **Orden de turno**: el orden de la sala; por defecto el de llegada, y el host puede reordenarlo (ej. según los dados físicos) antes de iniciar.

## 3. Turnos y movimiento

- La partida lleva **rondas y turnos**: empieza en la ronda 1 con el primer jugador de la sala. El jugador en turno pulsa "Terminar turno" y el turno pasa al siguiente jugador activo (los que están en bancarrota se saltan). Al volver al primero empieza una nueva ronda.
- El host puede pasar el turno de otro jugador (ej. si se olvida o se desconecta). Si el jugador en turno se declara en bancarrota, el turno pasa automáticamente.
- **Solo en tu turno**: comprar, pagar renta, pagar impuestos, cobrar salario, subastas y pedir préstamos de tarjeta.
- **En cualquier momento**: hipotecar y deshipotecar, construir y vender construcciones, intercambios, pagar a otros jugadores (ej. cartas que obligan a todos a pagarte), pagar la tarjeta y declararse en bancarrota.

- El movimiento de fichas y el lanzamiento de dados ocurren físicamente en la mesa; la app **no** gestiona el tablero.
- Al finalizar el movimiento de un jugador, este (o cualquier jugador) reporta a la app en qué casilla cayó, y la app resuelve las consecuencias financieras (pagar renta, comprar propiedad, pagar impuesto, etc.).
- Dobles (dados iguales): el jugador repite turno físicamente; no afecta a la app salvo para el conteo de "3 dobles seguidos → cárcel", que se gestiona como una acción manual reportada por los jugadores.

## 4. Propiedades

### 4.1 Compra
- Al caer en una propiedad sin dueño, el jugador puede comprarla al precio de listado actual de esa propiedad.
- Si el jugador decide no comprarla, se resuelve **subasta** entre todos los jugadores (regla oficial clásica, mantenida en Ultimate Banking).
- **Compra compartida**: en su turno, el jugador puede proponer comprarla entre varios, repartiendo el 100% en acciones de 10% (mínimo dos compradores, él incluido). Cada comprador paga la parte del precio de su %. Se compra cuando todos los compradores aceptan en el Mercado; si antes alguien la compra o se subasta, la propuesta desaparece.

### 4.2 Niveles de renta
- Cada propiedad tiene un **valor base** de compra y **5 niveles** de renta por encima del nivel 0 (sin mejorar).
- El nivel de una propiedad **nunca sube solo**: solo sube cuando su administrador (el accionista mayoritario, sección 4.7) paga el costo de subirlo, en cualquier momento (no requiere ser su turno). Caer en la propiedad y pagar renta no la mejora.
- La renta a cobrar es siempre la del nivel vigente de la propiedad, no la original de compra.
- Poseer un **color completo (monopolio)** duplica la renta base de las propiedades de ese color mientras estén en nivel 0 (regla heredada del clásico).

### 4.3 Subir de nivel (reemplaza casas/hoteles)
- Solo se puede empezar a subir de nivel sobre un **color completo** (monopolio).
- **Costo de subir un nivel**: un porcentaje del precio de compra de la propiedad, creciente por nivel:

| Nivel | Costo (% del precio de compra) |
|---|---|
| 1 | 50% |
| 2 | 75% |
| 3 | 100% |
| 4 | 150% |
| 5 | 200% |

  El costo de subir de nivel N-1 a N es ese porcentaje sobre el `purchasePrice` de la propiedad, redondeado hacia arriba. Estos porcentajes son placeholder, igual que el resto de valores de la sección 9.
- El costo se cobra al administrador **repartido entre todos los accionistas según su %** (igual que hipotecar/deshipotecar, sección 4.7): si algún accionista no puede pagar su parte, la mejora no se hace.
- **Nivel uniforme**: no se puede subir una propiedad dos niveles por encima de la más baja del mismo grupo de color (regla clásica de "even building", ahora aplicada a niveles en vez de casas).
- Bajar un nivel (vender la mejora) devuelve a los accionistas, repartida por su %, la mitad de lo que costó subir ese nivel.

### 4.4 Hipoteca
- Un jugador puede hipotecar una propiedad en nivel 0 para recibir efectivo inmediato (valor de hipoteca de la propiedad).
- Una propiedad hipotecada no genera renta hasta ser des-hipotecada.
- Des-hipotecar cuesta el valor de hipoteca + interés (porcentaje fijo, típicamente 10%).
- No se puede hipotecar una propiedad con nivel > 0; hay que bajarla a nivel 0 primero (sección 4.5).

### 4.5 Bajar de nivel
- Ver 4.3: bajar un nivel devuelve la mitad de lo que costó subirlo, repartido entre accionistas por su %, sujeto también a la regla de nivel uniforme al bajar.

### 4.6 Mercado (negociación entre jugadores)
- Reemplaza a los intercambios simples. Un **trato** es una lista de movimientos de dinero o acciones entre cualquier número de jugadores (ej. Ana da 30% de una calle a Luis, Luis paga $200 a Eva y Eva paga $150 a Ana).
- Quien lo propone lo acepta al proponerlo; el trato se ejecuta **cuando todos los participantes aceptan**. Cualquier participante puede rechazarlo, y eso lo retira para todos.
- **Ofertas abiertas**: un jugador publica lo que da y lo que pide (ej. "vendo 30% de X por $200") sin elegir contraparte; el primer jugador que la acepta se queda con el trato, que se ejecuta en ese momento.
- La ejecución es atómica (todo o nada) y se valida con el resultado neto: un jugador puede pagar con dinero que recibe en el mismo trato. Si en ese momento alguien ya no tiene el dinero o las acciones, el trato no se ejecuta y queda pendiente.
- Negociar se puede en cualquier momento, no solo en tu turno (salvo proponer una compra compartida).
- Las propiedades cambian de manos con sus construcciones y su estado de hipoteca.

### 4.7 Acciones de propiedades
- Cada propiedad se divide en **10 acciones de 10%**. Al comprarla al banco o ganarla en subasta, el comprador recibe el 100%; luego puede vender o intercambiar acciones en el Mercado.
- **Renta**: se reparte entre los accionistas según su %. Si quien cae tiene acciones de esa propiedad, solo paga la parte de los demás. Los redondeos se reparten por mayor resto y, en empate, al accionista más antiguo.
- **Administración**: el accionista mayoritario (en empate, el más antiguo) administra la propiedad: sube y baja de nivel, hipoteca y deshipoteca. Los costos (subir de nivel, deshipotecar) se cobran a todos los accionistas según su %, y lo que se recibe (hipotecar, bajar de nivel) también se reparte según su %. Si un accionista no puede pagar su parte, la acción no se hace.
- **Monopolio de color**: cuenta para un jugador si es el administrador de todas las propiedades del grupo.
- **Patrimonio**: cada jugador suma solo la parte de su %.

### 4.8 Inversiones (renta compartida)
- Una **inversión** es un acuerdo entre dos jugadores atado a una propiedad concreta: el **inversor** paga una vez un monto fijo al **receptor**, y a cambio se lleva un **% de la parte de renta que el receptor cobre en esa propiedad** por tiempo indefinido, hasta que se cancele.
- Se crea como un trato del Mercado (sección 4.6): un `DealTransfer` de dinero del inversor al receptor, más la nueva inversión propuesta en el mismo trato. Se acepta y liquida igual que cualquier trato (todos los participantes deben aceptar).
- El % de la inversión se descuenta de lo que el receptor recibiría por esa propiedad según la sección 4.7 (reparto de renta por acciones): si al receptor le tocan $100 de renta de esa propiedad, y el inversor tiene 30%, el inversor recibe $30 y el receptor $70. El resto de accionistas de la propiedad no se ven afectados.
- Pueden coexistir varias inversiones sobre el mismo (receptor, propiedad); la suma de sus porcentajes no puede superar el 100% de la parte del receptor. Al calcular cada corte (y su redondeo), se procesan en el orden en que se aceptaron (la más antigua primero), igual que el criterio de antigüedad ya usado para accionistas en 4.7.
- Si el receptor deja de tener acciones de esa propiedad (las vende, las pierde en un trato o en bancarrota), la inversión no reparte nada mientras tanto; no se cancela sola.
- **Cancelación**: solo por acuerdo mutuo, como un trato del Mercado — cualquiera de los dos (inversor o receptor) propone cancelarla y se retira cuando el otro acepta.
- **Bankarrota**: si el inversor o el receptor entra en bancarrota, todas sus inversiones activas (como inversor o como receptor) se cancelan (igual que los tratos pendientes, sección 6).
- Una inversión no transfiere acciones de la propiedad ni cuenta para el patrimonio o el monopolio de color del inversor; solo redirige parte de una renta futura.

## 5. Impuestos y casillas especiales

- **Impuesto sobre la Renta / Impuesto de Lujo**: montos fijos definidos en el tablero, se pagan a la banca (el dinero sale del juego, no va a Free Parking salvo house rule activada).
- **Ir a la Cárcel**: el jugador mueve su ficha físicamente a la cárcel; la app solo gestiona el pago de fianza si aplica.
- **Salir de la Cárcel**: pagando una fianza fija, usando una carta "Salir de la cárcel gratis", o sacando dobles (gestión física de dados).
- **Salida (Go)**: al pasar o caer en la casilla de Salida, el jugador cobra el monto de salario definido.
- **Suerte / Caja de Comunidad**: las cartas se manejan físicamente; cuando una carta tiene efecto monetario, el jugador reporta a la app para aplicar el efecto (cobrar/pagar).
- **Pagar con QR** (renta o pago libre): quien cobra muestra en su iPhone un QR (de una propiedad en la que tiene acciones, para renta; o de sí mismo, con monto fijo opcional, para pago libre) y quien paga lo escanea y confirma. Es solo otra forma de elegir a quién o qué se paga: se aplican exactamente las mismas reglas que al pagar desde la lista (la renta solo en tu turno; el pago libre en cualquier momento).
- **Pago libre entre jugadores**: para efectos que obligan a pagar a otro jugador (ej. cartas "paga $50 a cada jugador"), un jugador puede transferir un monto positivo a otro jugador activo. Falla si el monto no es positivo, si no tiene saldo suficiente, si se paga a sí mismo o si alguno de los dos está en bancarrota.

## 6. Bancarrota

- Un jugador que no puede cubrir una deuda (renta, impuesto, etc.) ni liquidando propiedades/hipotecas debe declararse en bancarrota.
- Si la deuda es con otro jugador, todos sus activos (acciones de propiedades, dinero restante) pasan a ese jugador.
- Si la deuda es con la banca, el dinero sale del juego. Sus acciones de propiedades donde había otros accionistas se reparten entre ellos según su %; las propiedades que eran solo suyas vuelven a la banca (disponibles de nuevo a valor base, sin construcciones ni hipoteca).
- Los tratos pendientes del Mercado en los que participaba se cancelan, incluidas sus inversiones activas (sección 4.8).
- El jugador en bancarrota queda eliminado de la partida.

## 7. Fin de la partida

- La partida termina cuando solo queda un jugador solvente (regla estándar), o por acuerdo de los jugadores en un límite de tiempo/rondas configurado antes de iniciar.
- En caso de fin por tiempo, gana quien tenga mayor patrimonio neto (efectivo + valor actual de propiedades no hipotecadas + mitad del valor de construcciones − deuda de tarjeta de crédito).

## 8. Reglas opcionales / configurables (house rules)

Estas reglas están **desactivadas por defecto** (siguiendo las reglas oficiales) y pueden activarse al configurar una partida nueva:

| Regla opcional | Descripción |
|---|---|
| Free Parking Jackpot | El dinero de impuestos y pagos a la banca se acumula y se entrega al jugador que caiga en Free Parking. |
| Doble renta antes de construir | Ya es regla oficial en el clásico; aquí se deja explícito como toggle por si la edición Ultimate Banking no la incluye por defecto. |
| Sin subasta | Si un jugador no compra una propiedad, esta simplemente queda disponible para el siguiente jugador que caiga en ella, sin subasta. |
| Bono en Casa aleatorio | Activa el evento aleatorio de bono monetario que el dispositivo físico Ultimate Banking entrega ocasionalmente. |
| Saldo inicial personalizado | Permite definir un monto de dinero inicial distinto al valor por defecto. |
| Tarjetas de crédito | **Activada por defecto** en la configuración del host (decisión de Brian). Ver sección 8.1. |

### 8.1 Tarjetas de crédito

- **Patrimonio** (para crédito): efectivo + precio de cada propiedad no hipotecada + suma de lo que costó subir cada nivel ya alcanzado (sección 4.3) − deuda de tarjeta. Las propiedades hipotecadas cuentan 0.
- **Crédito disponible**: 50% del patrimonio menos la deuda de tarjeta actual. Restar la deuda evita encadenar préstamos, porque el efectivo prestado cuenta como patrimonio.
- **Interés**: 10% fijo en el momento de pedir el préstamo (pides $1000 → debes $1100). La deuda no crece con el tiempo.
- **Plazos**: al pedir un préstamo se eligen de 1 a 5 plazos. La deuda (con el interés) se divide entre esos plazos y en cada GO se cobra una cuota: lo que queda por pagar ÷ cuotas restantes, redondeado hacia arriba.
- **Aplazamientos**: cada préstamo tiene 5 − plazos elegidos aplazamientos (5 plazos → 0; 4 → 1; 1 → 4). Al cobrar el salario de GO el jugador puede aplazar la cuota de ese préstamo: ese GO no se cobra y la cuota pasa al final. No tiene recargo.
- **Cobro en GO**: primero se suma el salario y luego se cobra la cuota de cada préstamo no aplazado. Si el efectivo no alcanza, se cobra todo lo que haya y el resto sigue como deuda; en la última cuota, lo que quede se cobra completo en el siguiente GO. El saldo nunca queda negativo.
- **Varios préstamos**: se pueden tener varios a la vez, cada uno con sus propios plazos y aplazamientos. El límite de crédito cuenta la deuda de todos.
- **Pagos anticipados**: se puede pagar cualquier monto de un préstamo, hasta lo que queda por pagar, en cualquier momento. Reduce las cuotas restantes de ese préstamo.
- **Bancarrota**: la deuda de tarjeta se cancela; no pasa al acreedor.

La app debe permitir seleccionar estas reglas opcionales al crear una partida, y el estado resultante debe ser visible para todos los jugadores conectados antes de empezar.

## 9. Preguntas abiertas / a validar con el usuario

- Tabla exacta de precios y rentas base por propiedad (pendiente de contrastar contra la caja física o manual oficial).
- Monto exacto y frecuencia del evento "Bono en Casa".
- Porcentajes exactos del costo de subir de nivel por propiedad (sección 4.3); los valores actuales son placeholder.

Estas preguntas deben resolverse antes de escribir la tabla de datos de propiedades en el código; hasta entonces, usar valores de placeholder claramente marcados como tales.
