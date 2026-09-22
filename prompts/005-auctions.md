# Prompt 005 — Subastas de propiedades

## Contexto

Continuamos sobre la capa de dominio ya existente (`Monopoly/Domain/`), construida en los prompts 001-004. La base actual implementa: compra, renta (base, doble por monopolio, por nivel de construcción), hipoteca/des-hipoteca, construcción y venta de casas/hoteles, bancarrota, impuestos, cobro de salario y trades atómicos entre jugadores — todo con tests pasando (38/38 a la fecha de este prompt).

**No rompas nada de lo existente.**

Antes de nada, lee (o relee) completos:
- `GAME_RULES.md` — en particular sección 4.1 (compra, donde se menciona la subasta) y sección 8 (reglas opcionales, donde ya existe la house rule `Sin subasta`)
- `PROJECT_RULES.md`
- El código existente en `Monopoly/Domain/` y sus tests en `MonopolyTests/GameRulesTests.swift`, para seguir el mismo estilo ya establecido: errores tipados con `GameRuleError`, funciones puras que devuelven nuevo `GameState`, el patrón `requireActivePlayer`, y el enum `HouseRule` (ya existe `HouseRule.noAuction` en `Domain/Models/HouseRule.swift` desde el prompt 001 — este prompt es el que finalmente le da uso).

## Regla de negocio a implementar

Cuando un jugador cae en una propiedad sin dueño y decide no comprarla (esa decisión de "no comprar" ya ocurre fuera de esta capa de dominio, es una acción del jugador reportada por UI/red — no la modeles aquí), se resuelve una **subasta** entre jugadores:

- Pueden pujar todos los jugadores activos de la partida, **incluido el jugador que decidió no comprarla originalmente** (regla clásica de Monopoly).
- Cada puja debe ser estrictamente mayor que la puja más alta actual (no se permite igualar).
- La subasta se cierra cuando se determina un ganador; en esta capa de dominio, la subasta se modela como una **lista ordenada de pujas ya recolectadas** (la mecánica de "quién puja cuándo, en qué orden, y cuándo se cierra" es responsabilidad de una capa superior — UI o red — fuera de esta tarea). Esta capa de dominio solo debe **validar y resolver** una lista de pujas ya completa.
- El ganador es quien hizo la puja más alta válida. Si no hubo ninguna puja (lista vacía), la propiedad queda sin dueño (nadie paga nada, no es un error).
- El ganador paga el monto de su puja (no el precio de listado de la propiedad) y recibe la propiedad, igual que en una compra normal.
- Si la house rule `HouseRule.noAuction` está activa en el `GameState`, la función de resolución de subasta debe fallar con un error tipado indicando que las subastas están desactivadas para esta partida — la capa superior debería usar directamente la regla "propiedad queda disponible para el siguiente jugador" en ese caso (no la implementes aquí, ya se describe en `GAME_RULES.md` sección 8, es responsabilidad de quien orqueste el turno).

## Alcance de esta tarea

Sigue siendo **solo capa de dominio**: nada de SwiftUI, nada de red, nada de persistencia en disco.

### 1. Modelo de puja

Crea un tipo (ej. `AuctionBid`, en `Domain/Models/`) que represente una puja individual: `playerID` y `amount`. Debe ser `Codable`, inmutable, siguiendo el estilo de `TradeOffer.swift`.

### 2. Función de resolución (`Domain/Rules/GameRules.swift`)

Implementa una función (ej. `resolveAuction`) que reciba el `GameState`, el `propertyID` en subasta, y un array ordenado de `[AuctionBid]` (en el orden en que se hicieron), y:

- Falla si `HouseRule.noAuction` está activa en `state.activeHouseRules` (o el nombre de campo que ya exista en `GameState` para las house rules activas — revísalo antes de asumir el nombre).
- Falla si la propiedad no existe.
- Falla si la propiedad **ya tiene dueño** (una subasta solo aplica a propiedades sin dueño).
- Valida cada puja en orden: cada una debe venir de un jugador que existe y está activo (`requireActivePlayer`), y debe ser **estrictamente mayor** que la puja válida más alta hasta ese momento (la primera puja solo necesita ser mayor que 0). Si una puja no es estrictamente mayor que la anterior más alta, o viene de un jugador inactivo/inexistente, trátalo como un **error de la lista completa** (falla toda la resolución, no ignores pujas inválidas silenciosamente) — así la capa superior sabe que debe corregir y reenviar la lista.
- Si la lista de pujas está vacía, no falla: devuelve el `GameState` sin cambios (la propiedad sigue sin dueño).
- Si hay pujas válidas, determina la más alta, verifica que ese jugador tenga saldo suficiente para pagarla (si no, falla con `insufficientFunds`, igual que en `buyProperty`), y transfiere el dinero y la propiedad exactamente igual que `buyProperty` (descuenta el balance, asigna `ownerID`, añade a `propertyIDs` del jugador).
- Sigue el mismo patrón de atomicidad que `executeTrade`: todas las validaciones ocurren antes de mutar cualquier copia del estado.

Añade a `GameRuleError` los casos nuevos que necesites (ej. `auctionsDisabled`, `propertyAlreadyOwned` ya existe y puedes reutilizarlo, `invalidBid` o similar para pujas que no superan la anterior).

### 3. Tests (XCTest)

Añade tests unitarios, como mínimo:
- Subasta exitosa con una sola puja: el jugador paga su puja y recibe la propiedad.
- Subasta exitosa con varias pujas crecientes: gana la más alta, esa persona paga exactamente su puja (no el precio de listado).
- Subasta con lista de pujas vacía: la propiedad queda sin dueño, sin error, sin cambios de balance.
- Subasta fallida porque una puja no supera a la anterior (ej. pujas [100, 80]) — y verifica que el `GameState` resultante en el error sea idéntico al original.
- Subasta fallida porque el ganador no tiene saldo suficiente para cubrir su propia puja.
- Subasta fallida porque la propiedad ya tiene dueño.
- Subasta fallida porque `HouseRule.noAuction` está activa.
- Subasta fallida porque una puja viene de un jugador inactivo (en bancarrota).
- El jugador que originalmente decidió no comprar puede participar y ganar la subasta (no hay ninguna exclusión especial para él — confírmalo con un test si tu diseño necesitara excluirlo explícitamente en algún punto, aunque no debería).

## Criterios de aceptación

1. El proyecto compila sin warnings nuevos usando el scheme `Monopoly` (`xcodebuild -project Monopoly.xcodeproj -scheme Monopoly -destination 'platform=iOS Simulator,name=iPhone 16' build test`).
2. Los 38 tests existentes siguen pasando, más todos los tests nuevos de este prompt.
3. Ningún archivo en `Domain/` importa `SwiftUI`.
4. No se toca `ContentView.swift` ni `MonopolyApp.swift`.
5. No se añade ninguna dependencia externa sin justificarlo en el resumen final.

## Al terminar

Entrega, íntegro y por escrito en tu respuesta, un resumen que indique:
- Qué archivos creaste o modificaste.
- Qué nombre de campo usó `GameState` para las house rules activas y cómo lo verificaste.
- Cómo decidiste tratar una lista de pujas inválida (fallar toda la resolución vs. ignorar pujas inválidas) y por qué.
- Cualquier ambigüedad de `GAME_RULES.md` que hayas resuelto por tu cuenta.
