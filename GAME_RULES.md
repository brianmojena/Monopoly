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
- Se determina orden de turno (esto ocurre fuera de la app, físicamente, salvo que se decida delegar en la app).

## 3. Turnos y movimiento

- El movimiento de fichas y el lanzamiento de dados ocurren físicamente en la mesa; la app **no** gestiona el tablero.
- Al finalizar el movimiento de un jugador, este (o cualquier jugador) reporta a la app en qué casilla cayó, y la app resuelve las consecuencias financieras (pagar renta, comprar propiedad, pagar impuesto, etc.).
- Dobles (dados iguales): el jugador repite turno físicamente; no afecta a la app salvo para el conteo de "3 dobles seguidos → cárcel", que se gestiona como una acción manual reportada por los jugadores.

## 4. Propiedades

### 4.1 Compra
- Al caer en una propiedad sin dueño, el jugador puede comprarla al precio de listado actual de esa propiedad.
- Si el jugador decide no comprarla, se resuelve **subasta** entre todos los jugadores (regla oficial clásica, mantenida en Ultimate Banking).

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

### 4.6 Intercambios (trades)
- Los jugadores pueden intercambiar propiedades, dinero y/o "cartas para salir de la cárcel" libremente entre sí, sujeto a aceptación mutua.
- La app debe registrar y ejecutar el intercambio de forma atómica (todo o nada) una vez ambas partes confirman.

## 5. Impuestos y casillas especiales

- **Impuesto sobre la Renta / Impuesto de Lujo**: montos fijos definidos en el tablero, se pagan a la banca (el dinero sale del juego, no va a Free Parking salvo house rule activada).
- **Ir a la Cárcel**: el jugador mueve su ficha físicamente a la cárcel; la app solo gestiona el pago de fianza si aplica.
- **Salir de la Cárcel**: pagando una fianza fija, usando una carta "Salir de la cárcel gratis", o sacando dobles (gestión física de dados).
- **Salida (Go)**: al pasar o caer en la casilla de Salida, el jugador cobra el monto de salario definido.
- **Suerte / Caja de Comunidad**: las cartas se manejan físicamente; cuando una carta tiene efecto monetario, el jugador reporta a la app para aplicar el efecto (cobrar/pagar).
- **Pago libre entre jugadores**: para efectos que obligan a pagar a otro jugador (ej. cartas "paga $50 a cada jugador"), un jugador puede transferir un monto positivo a otro jugador activo. Falla si el monto no es positivo, si no tiene saldo suficiente, si se paga a sí mismo o si alguno de los dos está en bancarrota.

## 6. Bancarrota

- Un jugador que no puede cubrir una deuda (renta, impuesto, etc.) ni liquidando propiedades/hipotecas debe declararse en bancarrota.
- Si la deuda es con otro jugador, todos sus activos (propiedades, dinero restante) pasan a ese jugador.
- Si la deuda es con la banca, todos sus activos vuelven a la banca (propiedades quedan disponibles para compra nuevamente a valor base).
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
- **Pago mínimo**: al cobrar el salario de GO se descuenta automáticamente el 25% de la deuda (redondeado hacia arriba). Si el efectivo (ya con el salario) no alcanza, se cobra todo lo que haya y el resto sigue como deuda; el saldo nunca queda negativo.
- **Pagos anticipados**: se puede pagar cualquier monto hasta el total de la deuda en cualquier momento.
- **Bancarrota**: la deuda de tarjeta se cancela; no pasa al acreedor.

La app debe permitir seleccionar estas reglas opcionales al crear una partida, y el estado resultante debe ser visible para todos los jugadores conectados antes de empezar.

## 9. Preguntas abiertas / a validar con el usuario

- Tabla exacta de precios, rentas y porcentaje de incremento de valor por Ultimate Banking (pendiente de contrastar contra la caja física o manual oficial).
- Monto exacto y frecuencia del evento "Bono en Casa".
- Tabla de costos de construcción por grupo de color.

Estas preguntas deben resolverse antes de escribir la tabla de datos de propiedades en el código; hasta entonces, usar valores de placeholder claramente marcados como tales.
