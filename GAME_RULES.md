# Reglas del Juego — Monopoly Ultimate Banking

Este documento describe las reglas de Monopoly en su edición **Ultimate Banking** que la app debe implementar. Es la referencia de negocio para cualquier lógica de banca, propiedades, turnos y dinero. Ante cualquier duda de comportamiento del sistema, este documento manda sobre la intuición general de "cómo se juega Monopoly clásico" — Ultimate Banking tiene diferencias deliberadas frente al Monopoly de tablero con billetes de papel.

> Nota de alcance: la app reemplaza **solo la banca digital** (el lector/tarjetas del dispositivo físico Ultimate Banking). El tablero, los dados, las fichas y las cartas de Suerte/Caja de Comunidad se siguen usando físicamente en la mesa. La app es responsable de dinero, propiedades, hipotecas, rentas, construcciones y del estado financiero de cada jugador.

## 1. Diferencias clave frente al Monopoly clásico

- **Sin dinero en papel**: todo el dinero es digital, gestionado por la app (originalmente por el dispositivo lector de tarjetas).
- **Valores de propiedad dinámicos**: en Ultimate Banking, el valor de una propiedad **sube cada vez que se paga renta sobre ella**, no solo por construir casas/hoteles. Esto significa que el precio de compra, el valor de hipoteca y el monto de la renta no son fijos durante toda la partida como en el clásico: se recalculan con el uso.
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

### 4.2 Valor dinámico y renta
- Cada propiedad tiene un **valor base** de compra.
- Cada vez que un jugador paga renta en una propiedad, su valor (y por tanto su renta futura) **aumenta** según una tabla/porcentaje definido por la edición Ultimate Banking.
- La renta a cobrar es siempre la vigente en el momento del pago, no la original de compra.
- Poseer un **color completo (monopolio)** duplica la renta base de las propiedades de ese color mientras no tengan casas construidas (regla heredada del clásico).

### 4.3 Construcción (casas y hoteles)
- Solo se puede construir sobre un color completo.
- Construcción **uniforme**: no se puede construir una tercera casa en una propiedad de un color si las demás propiedades del mismo color tienen menos de dos casas (regla clásica de "even building").
- Costos de construcción varían por grupo de color, definidos en la tabla de datos de propiedades.
- Un hotel reemplaza 4 casas y consume el stock de casas devueltas a la "banca" (en digital, esto es solo contable, no hay límite físico de piezas salvo que se quiera simular).

### 4.4 Hipoteca
- Un jugador puede hipotecar una propiedad sin casas para recibir efectivo inmediato (valor de hipoteca de la propiedad).
- Una propiedad hipotecada no genera renta hasta ser des-hipotecada.
- Des-hipotecar cuesta el valor de hipoteca + interés (porcentaje fijo, típicamente 10%).
- No se puede hipotecar una propiedad con casas/hotel construidos; deben venderse las construcciones primero.

### 4.5 Venta de construcciones
- Las casas/hoteles pueden venderse de vuelta a la banca a mitad de su costo de construcción (regla clásica), sujeto también a la regla de construcción uniforme al vender.

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
- **Administración**: el accionista mayoritario (en empate, el más antiguo) administra la propiedad: construye, vende construcciones, hipoteca y deshipoteca. Los costos (construir, deshipotecar) se cobran a todos los accionistas según su %, y lo que se recibe (hipotecar, vender construcciones) también se reparte según su %. Si un accionista no puede pagar su parte, la acción no se hace.
- **Monopolio de color**: cuenta para un jugador si es el administrador de todas las propiedades del grupo.
- **Patrimonio**: cada jugador suma solo la parte de su %.

## 5. Impuestos y casillas especiales

- **Impuesto sobre la Renta / Impuesto de Lujo**: montos fijos definidos en el tablero, se pagan a la banca (el dinero sale del juego, no va a Free Parking salvo house rule activada).
- **Ir a la Cárcel**: el jugador mueve su ficha físicamente a la cárcel; la app solo gestiona el pago de fianza si aplica.
- **Salir de la Cárcel**: pagando una fianza fija, usando una carta "Salir de la cárcel gratis", o sacando dobles (gestión física de dados).
- **Salida (Go)**: al pasar o caer en la casilla de Salida, el jugador cobra el monto de salario definido.
- **Suerte / Caja de Comunidad**: las cartas se manejan físicamente; cuando una carta tiene efecto monetario, el jugador reporta a la app para aplicar el efecto (cobrar/pagar).
- **Pago libre entre jugadores**: para efectos que obligan a pagar a otro jugador (ej. cartas "paga $50 a cada jugador"), un jugador puede transferir un monto positivo a otro jugador activo. Falla si el monto no es positivo, si no tiene saldo suficiente, si se paga a sí mismo o si alguno de los dos está en bancarrota.

## 6. Bancarrota

- Un jugador que no puede cubrir una deuda (renta, impuesto, etc.) ni liquidando propiedades/hipotecas debe declararse en bancarrota.
- Si la deuda es con otro jugador, todos sus activos (acciones de propiedades, dinero restante) pasan a ese jugador.
- Si la deuda es con la banca, el dinero sale del juego. Sus acciones de propiedades donde había otros accionistas se reparten entre ellos según su %; las propiedades que eran solo suyas vuelven a la banca (disponibles de nuevo a valor base, sin construcciones ni hipoteca).
- Los tratos pendientes del Mercado en los que participaba se cancelan.
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

- **Patrimonio** (para crédito): efectivo + precio de cada propiedad no hipotecada + nivel de construcción × costo de construcción − deuda de tarjeta. Las propiedades hipotecadas cuentan 0.
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

- Tabla exacta de precios, rentas y porcentaje de incremento de valor por Ultimate Banking (pendiente de contrastar contra la caja física o manual oficial).
- Monto exacto y frecuencia del evento "Bono en Casa".
- Tabla de costos de construcción por grupo de color.

Estas preguntas deben resolverse antes de escribir la tabla de datos de propiedades en el código; hasta entonces, usar valores de placeholder claramente marcados como tales.
