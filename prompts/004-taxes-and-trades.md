# Prompt 004 — Impuestos y trades entre jugadores

## Contexto

Continuamos sobre la capa de dominio ya existente (`Monopoly/Domain/`), construida en los prompts 001, 002 y 003. La base actual implementa: compra, renta (base, doble por monopolio, por nivel de construcción), hipoteca/des-hipoteca, construcción y venta de casas/hoteles, y bancarrota (determinación y ejecución, hacia jugador y hacia banca) — todo con tests pasando (29/29 a la fecha de este prompt, incluida una corrección reciente en `constructionResaleValue` para que la liquidación de un hotel se calcule igual que la de las casas: `constructionLevel * constructionCost / 2`).

**No rompas nada de lo existente.**

Antes de nada, lee (o relee) completos:
- `GAME_RULES.md` — en particular sección 5 (impuestos y casillas especiales) y 4.6 (intercambios/trades)
- `PROJECT_RULES.md`
- El código existente en `Monopoly/Domain/` y sus tests en `MonopolyTests/GameRulesTests.swift`, para seguir el mismo estilo ya establecido: errores tipados con `GameRuleError`, funciones puras que devuelven nuevo `GameState`, el patrón `requireActivePlayer` ya usado para bloquear acciones de jugadores en bancarrota (debes aplicarlo también a las funciones nuevas de este prompt).

## Alcance de esta tarea

Sigue siendo **solo capa de dominio**: nada de SwiftUI, nada de red, nada de persistencia en disco.

### 1. Impuestos (`GAME_RULES.md` sección 5)

Implementa una función (ej. `payTax`) que:
- Descuenta de un jugador un monto fijo de impuesto (el monto se pasa como parámetro; no hace falta modelar "Impuesto sobre la Renta" vs "Impuesto de Lujo" como conceptos separados en el dominio, un monto genérico basta — documenta esta simplificación).
- El dinero sale del juego (no se acredita a nadie, ni siquiera a "la banca" como entidad, ya que no existe un balance de banca en el modelo actual).
- Falla (error tipado) si el jugador no tiene saldo suficiente. **No implementes en este prompt qué pasa si no puede pagar** (eso ya está cubierto por el flujo de bancarrota existente — determinación con `canCoverDebt` / ejecución con `declareBankruptcy`, que ya soportan una deuda hacia "la banca" vía `DebtCreditor`; reutilízalos, no dupliques lógica).
- Aplica `requireActivePlayer` igual que las demás funciones.

Implementa también una función para cobrar el salario de pasar/caer en la casilla de Salida (ej. `collectSalary`), que simplemente acredita un monto fijo al jugador (el dinero entra al juego desde la banca, sin necesidad de descontarlo de ningún otro balance).

### 2. Intercambios entre jugadores (`GAME_RULES.md` sección 4.6)

Modela una propuesta de intercambio (`TradeOffer` o nombre equivalente) que puede incluir, de cualquiera de los dos jugadores hacia el otro: cero o más propiedades, un monto de dinero (puede ser 0), y opcionalmente una o más "cartas para salir de la cárcel gratis" **si ya existe ese concepto en el modelo actual** — si no existe todavía (revisa `Player`/`GameState`), NO lo añadas en este prompt; es un concepto nuevo fuera de alcance, decláralo así en tu resumen y omite esa parte del intercambio.

Implementa una función (ej. `executeTrade`) que:
- Recibe una `TradeOffer` ya aceptada por ambas partes (la lógica de "proponer y esperar aceptación" es responsabilidad de una capa superior — UI o red — fuera de esta tarea; esta función solo ejecuta un trade que ya se asume mutuamente aceptado).
- Aplica el intercambio de forma **atómica**: o se transfieren todas las propiedades y dinero de ambos lados, o no se transfiere nada (si algo falla a mitad de camino, el `GameState` no debe quedar en un estado intermedio inconsistente — recuerda que las funciones ya existentes trabajan sobre copias inmutables de `GameState`, así que esto debería ser natural si sigues el mismo patrón, pero verifícalo con un test).
- Falla (error tipado) si: alguna de las propiedades ofrecidas no pertenece realmente al jugador que la ofrece, si algún jugador no tiene saldo suficiente para el monto de dinero que ofrece, o si algún jugador involucrado no está activo (`requireActivePlayer`).
- **No** valida "justicia" del intercambio (si es un mal trato para uno de los jugadores) — eso es decisión de los jugadores, no del dominio.
- Las propiedades transferidas mantienen su nivel de construcción y estado de hipoteca tal cual estaban (no hay razón para resetearlos en un trade, a diferencia de la bancarrota hacia la banca).

### 3. Tests (XCTest)

Añade tests unitarios, como mínimo:
- Pago de impuesto exitoso, descuenta el monto correctamente y el dinero no aparece en ningún otro balance.
- Pago de impuesto fallido por saldo insuficiente.
- Cobro de salario exitoso, acredita el monto correctamente.
- Intercambio exitoso de una propiedad por dinero entre dos jugadores, verificando balances y ownership final de ambos lados.
- Intercambio exitoso con propiedades en ambas direcciones simultáneamente.
- Intercambio fallido porque una propiedad ofrecida no pertenece al jugador que la ofrece — y verifica que el `GameState` resultante en caso de error sea idéntico al original (nada se transfirió parcialmente).
- Intercambio fallido por saldo insuficiente de dinero ofrecido.
- Intercambio fallido porque uno de los jugadores está en bancarrota/inactivo.
- Una propiedad hipotecada o con casas que se transfiere en un trade conserva su estado de hipoteca/construcción tras el intercambio.

## Criterios de aceptación

1. El proyecto compila sin warnings nuevos usando el scheme `Monopoly` (`xcodebuild -project Monopoly.xcodeproj -scheme Monopoly -destination 'platform=iOS Simulator,name=iPhone 16' build test`).
2. Los 29 tests existentes siguen pasando, más todos los tests nuevos de este prompt.
3. Ningún archivo en `Domain/` importa `SwiftUI`.
4. No se toca `ContentView.swift` ni `MonopolyApp.swift`.
5. No se añade ninguna dependencia externa sin justificarlo en el resumen final.

## Al terminar

Entrega, íntegro y por escrito en tu respuesta (no lo omitas — es la cuarta vez que se pide explícitamente), un resumen que indique:
- Qué archivos creaste o modificaste.
- Cómo modelaste `TradeOffer` y por qué.
- Si el modelo actual ya tenía o no el concepto de "carta para salir de la cárcel" y qué decidiste al respecto.
- Cómo garantizaste la atomicidad del trade (qué patrón usaste para evitar estados intermedios inconsistentes).
- Cualquier ambigüedad de `GAME_RULES.md` sección 4.6 o 5 que hayas resuelto por tu cuenta.
