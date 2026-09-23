# 012 — Inversiones: pagar por un % de la renta de otro jugador

## Contexto

Lee `CONTEXT.md`, `PROJECT_RULES.md` y `GAME_RULES.md` completo antes de empezar, en particular las secciones **4.6, 4.7 y la nueva 4.8 "Inversiones (renta compartida)"**, y el punto actualizado de bancarrota en la sección 6. Esta feature ya está documentada como regla de negocio en `GAME_RULES.md`; este prompt es solo la implementación.

Revisa también el código existente del Mercado antes de tocar nada:
- `Monopoly/Domain/Models/MarketDeal.swift` — modelo de tratos (`DealTransfer`, `DealAsset`, `SharedPurchase`, `MarketDeal`).
- `Monopoly/Domain/Rules/GameRules+Market.swift` — `proposeDeal`, `acceptDeal`, `rejectDeal`, `settle`, `validateStructure`.
- `Monopoly/Domain/Rules/GameRules.swift` — donde vive el reparto de renta por acciones (sección 4.7 de `GAME_RULES.md`); busca la función que calcula/paga la renta al caer en una propiedad.
- `Monopoly/UI/MarketView.swift` y `Monopoly/UI/DealBuilderView.swift` — UI actual del Mercado.
- `Monopoly/Networking/Messages/GameIntent.swift` — intents que el cliente envía al host.

## Qué se implementa

Una **inversión** es un acuerdo entre dos jugadores atado a una propiedad: el inversor paga una vez un monto fijo al receptor, y a cambio se lleva un % de la parte de renta que el receptor cobre en esa propiedad, indefinidamente, hasta que se cancele por acuerdo mutuo. Ver `GAME_RULES.md` sección 4.8 para el detalle completo de la regla (porcentajes acumulables hasta 100%, qué pasa si el receptor pierde las acciones, cancelación, bancarrota).

## Alcance

### 1. Modelo de dominio
- Nuevo tipo `RentInvestment` (Codable, Equatable) con al menos: `id: UUID`, `investorID: UUID`, `recipientID: UUID`, `propertyID: UUID`, `percentage: Int` (1–100).
- `GameState` gana un arreglo `rentInvestments: [RentInvestment]` (revisa `Monopoly/Domain/Models/GameState.swift` para seguir su convención de nombres y de inicialización en `Codable`/memberwise init).
- Extiende `MarketDeal` para poder proponer una inversión como parte de un trato: agrega un campo opcional (ej. `proposedInvestment: RentInvestment?`, análogo a `sharedPurchase`) en vez de forzar la inversión a caber en `DealTransfer`/`DealAsset`. Actualiza `participantIDs` para incluir a `investorID`/`recipientID` cuando aplica.
- Necesitas también una forma de **proponer cancelar** una inversión existente. Evalúa el patrón más consistente con el código actual: puede ser reutilizar `MarketDeal` con un campo `cancelInvestmentID: UUID?` que requiere aceptación de ambas partes igual que cualquier trato, o un mecanismo paralelo — pero debe seguir el mismo ciclo propone/acepta/rechaza que ya tiene el Mercado, no uno nuevo.

### 2. Reglas (`GameRules`)
- En `GameRules+Market.swift`: `validateStructure` debe validar una inversión propuesta igual que valida `sharedPurchase` hoy (porcentaje entre 1 y 100, inversor ≠ receptor, ambos jugadores activos, propiedad existente, y que la suma de porcentajes de inversiones ya activas sobre ese mismo (receptor, propiedad) más esta nueva no supere 100). `settle` debe aplicar el pago único del inversor al receptor (reusa el mecanismo de `moneyChanges` ya existente pasando un `DealTransfer` de dinero en el mismo trato) y agregar el `RentInvestment` a `state.rentInvestments` cuando el trato se liquida.
- Cancelación: al liquidarse (ambos aceptan), elimina el `RentInvestment` de `state.rentInvestments`.
- En el punto donde hoy se reparte la renta entre accionistas (sección 4.7 ya implementada): antes de acreditar la parte que le toca a cada accionista por una propiedad, revisa si ese accionista es `recipientID` de alguna `RentInvestment` activa sobre esa `propertyID`; si es así, descuenta el % correspondiente y acredítalo en cambio al `investorID`. Si hay varias inversiones sobre el mismo (receptor, propiedad), aplica los porcentajes sobre la parte original del receptor (no acumulativos entre sí, cada uno toma su % del monto base), y lo que quede después de todas las inversiones es lo que recibe el receptor.
- Bancarrota (`GameRules.swift`, lógica ya existente para bancarrota): cuando un jugador entra en bancarrota, elimina toda `RentInvestment` donde sea `investorID` o `recipientID`, igual que ya se hace con los tratos pendientes del Mercado.
- Agrega los `GameRuleError` que hagan falta (ej. porcentaje inválido, inversión no encontrada) siguiendo el estilo de `Monopoly/Domain/Rules/GameRuleError.swift`.

### 3. Red
- Revisa cómo `GameIntent` ya modela `proposeDeal`/`acceptDeal`/`rejectDeal` y si una inversión puede viajar como parte de un `MarketDeal` existente (probablemente sí, si sigues el punto 1) sin necesitar un intent nuevo. Si hace falta un intent nuevo para cancelar una inversión fuera del flujo de trato normal, decláralo ahí siguiendo la convención existente.

### 4. UI
- En `DealBuilderView.swift`: agrega la opción de incluir una inversión al armar un trato (elegir jugador receptor, propiedad del receptor, monto a pagar, % a retener), reusando en lo posible los componentes visuales ya usados para acciones/dinero.
- En `MarketView.swift`: muestra las inversiones activas donde el jugador actual participa (como inversor o receptor) con un botón para proponer cancelarlas, y muestra las inversiones propuestas pendientes de aceptación igual que los demás tratos.
- Revisa `Monopoly/UI/MarketDescriptions.swift` para generar el texto descriptivo de una inversión en un trato (ej. "Ana invierte $200 en la calle X de Luis por 30% de su renta"), siguiendo el mismo patrón que ya usa para describir tratos.
- Si `Monopoly/UI/PropertyDetailView.swift` muestra accionistas de una propiedad, considera si vale la pena indicar ahí que parte de la renta de algún accionista está comprometida con un inversor (opcional, solo si no complica el alcance).

## Fuera de alcance
- No cambiar el reparto de renta entre accionistas en sí (sección 4.7), solo interceptar la parte ya calculada de cada accionista.
- No tocar compras compartidas (`SharedPurchase`) más allá de lo necesario para que `MarketDeal` acomode el nuevo campo opcional.
- No implementar plazos, intereses ni vencimiento automático — la inversión es indefinida hasta cancelación mutua, como dice la regla.

## Criterios de aceptación
1. Compila sin errores.
2. Tests nuevos en `MonopolyTests/GameRulesTests.swift` cubriendo (siguiendo el estilo de los tests ya existentes para el Mercado):
   - Proponer y aceptar un trato con inversión transfiere el pago único y crea la `RentInvestment`.
   - Al cobrarse renta de la propiedad, el inversor recibe su % y el receptor el resto; el resto de accionistas no se ve afectado.
   - Varias inversiones sobre el mismo (receptor, propiedad) no pueden superar 100% combinado; proponer una que lo supere falla con el error correspondiente.
   - Cancelar una inversión requiere que ambas partes acepten y, tras cancelarse, la renta vuelve a ir completa al receptor.
   - La bancarrota del inversor o del receptor cancela sus inversiones activas.
3. `GameRules` sigue sin `import SwiftUI` (capa de dominio separada de la UI, `PROJECT_RULES.md` sección 4).
4. La UI permite de punta a punta: proponer una inversión desde `DealBuilderView`, aceptarla desde `MarketView` en otro dispositivo, ver el efecto la próxima vez que se cobre renta de esa propiedad, y cancelarla por acuerdo mutuo.
