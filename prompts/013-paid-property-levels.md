# 013 — Niveles de renta pagados (reemplaza casas/hoteles)

## Contexto

Lee `CONTEXT.md`, `PROJECT_RULES.md` y `GAME_RULES.md` completo antes de empezar, en particular las secciones **4.2, 4.3, 4.4, 4.5, 4.7 y 8.1**, ya actualizadas para esta feature.

Cambio de regla de negocio: el sistema de casas/hotel (niveles 0–5, donde 4 son "casas" y el 5 es "hotel") se reemplaza por un concepto genérico de **5 niveles pagados**. Ya no hay distinción especial de "hotel"; solo nivel 0 (base) a nivel 5. El nivel de una propiedad **nunca sube solo** por caer o pagar renta — antes esto no estaba implementado en código de todas formas (confirma leyendo `GameRules.swift` función `collectRent`, no hay ningún incremento automático ahí), así que este prompt no tiene que "quitar" un auto-incremento existente, solo asegurarse de que nunca se agregue uno.

Revisa el código actual antes de tocar nada:
- `Monopoly/Domain/Models/Property.swift` — campos `constructionCost`, `constructionLevel`, `rentByConstructionLevel`.
- `Monopoly/Domain/Data/PlaceholderProperties.swift` — datos de las 22 propiedades.
- `Monopoly/Domain/Rules/GameRules.swift` — funciones `buildHouse`, `buildHotel`, `sellHouse`, `rentAmount`, `buildingContext`, `requireUniformConstruction`, `requireUniformConstructionAfterSelling`, `constructionResaleValue`, y la función de patrimonio/crédito que usa `constructionLevel * constructionCost` (sección 8.1).
- `Monopoly/Networking/Messages/GameIntent.swift` — intents `buildHouse`/`buildHotel`/`sellHouse` (o como se llamen).
- `Monopoly/UI/PropertyDetailView.swift` — botones de construir/vender construcción.

## Qué cambia

### 1. Modelo de datos (`Property.swift`)
- Elimina el campo `constructionCost` (único, fijo). El costo de subir un nivel ya no es un dato fijo por propiedad: se calcula como un **% del `purchasePrice`**, creciente por nivel, según la tabla de `GAME_RULES.md` sección 4.3:

  | Nivel | % de `purchasePrice` |
  |---|---|
  | 1 | 50% |
  | 2 | 75% |
  | 3 | 100% |
  | 4 | 150% |
  | 5 | 200% |

  Define esta tabla como una constante estática (ej. `Property.levelUpCostPercentages: [Int]` o en `GameRules`), no como dato por propiedad, ya que aplica igual a las 22.
- `constructionLevel` se mantiene (0–5), pero ya no distingue "hotel" en ningún punto del código o la UI — es simplemente "nivel 5".
- `rentByConstructionLevel` se mantiene tal cual (ya tiene 6 valores: nivel 0 a nivel 5) — no hace falta tocarlo.
- Actualiza `PlaceholderProperties.swift` quitando el argumento `constructionCost` de cada `Property(...)`.

### 2. Reglas (`GameRules.swift`)
- Reemplaza `buildHouse`/`buildHotel` (dos funciones con el caso especial de "4 casas → hotel") por una sola función `levelUp(in:propertyID:playerID:)` que:
  - Requiere monopolio de color (como `requireMonopoly` ya hace).
  - Requiere `constructionLevel < 5` (error si ya está en nivel máximo — reusa o renombra el `GameRuleError` que corresponda; ya no hace falta distinguir "tiene 4 casas" de "ya tiene hotel").
  - Calcula el costo del nivel siguiente con la tabla de porcentajes sobre `property.purchasePrice`, redondeado hacia arriba.
  - Sigue aplicando `requireUniformConstruction` (renómbrala si quieres a algo como `requireUniformLevel`, pero mantén la semántica: no subir más de 1 nivel por encima de la propiedad más baja del grupo de color).
  - Cobra el costo a los accionistas por su % con `chargeShareholders` (ya existe y reparte proporcionalmente, fallando si alguno no puede pagar su parte — mantener ese comportamiento).
  - Incrementa `constructionLevel` en 1.
- Reemplaza `sellHouse` por `levelDown(in:propertyID:playerID:)` que:
  - Requiere `constructionLevel > 0`.
  - Sigue aplicando la regla de nivel uniforme al bajar (`requireUniformConstructionAfterSelling`, renombrable).
  - Devuelve a los accionistas, por `payShareholders`, la **mitad de lo que costó llegar a ese nivel** (no una fracción de un `constructionCost` fijo): usa la misma tabla de porcentajes sobre `purchasePrice` para el nivel que se está abandonando.
  - Decrementa `constructionLevel` en 1.
- `rentAmount` no necesita cambios (ya indexa `rentByConstructionLevel[constructionLevel]`).
- `mortgageProperty`/`unmortgageProperty` ya exigen `constructionLevel == 0` para hipotecar — no tocar esa lógica, solo confirmar que sigue siendo consistente.
- Actualiza la función que calcula patrimonio para crédito (sección 8.1 de `GAME_RULES.md`): en vez de `constructionLevel * constructionCost`, debe sumar el costo real pagado por cada nivel alcanzado (usa la misma tabla de porcentajes, sumando el costo de cada nivel de 1 hasta `constructionLevel`).
- Ajusta `GameRuleError` quitando/renombrando los casos específicos de "hotel" (`propertyAlreadyHasHotel`, `propertyMustHaveFourHouses`, `propertyHasMaximumHouses`, etc.) por errores genéricos de nivel (ej. `propertyAtMaximumLevel`), siguiendo el estilo ya usado en el archivo.

### 3. Red
- Renombra los intents `buildHouse`/`buildHotel`/`sellHouse` en `GameIntent.swift` a algo como `levelUp`/`levelDown` (un solo intent para subir, uno para bajar), actualizando el switch de `GameSession.swift` que los despacha.

### 4. UI
- En `PropertyDetailView.swift`: reemplaza los botones/textos de "construir casa"/"construir hotel"/"vender construcción" por "Subir de nivel" / "Bajar de nivel", mostrando el nivel actual (0–5) y el costo de subir el siguiente nivel calculado con la tabla de porcentajes. Quita cualquier texto o ícono que hable específicamente de "casas" u "hotel".
- Revisa `Monopoly/UI/GameBoardView.swift` y `Monopoly/UI/MarketDescriptions.swift` por si muestran el nivel de construcción en algún lado (ej. un ícono de casita) y actualízalos a la terminología de "nivel" si aplica.

## Fuera de alcance
- No cambiar el reparto de renta por accionistas (sección 4.7) ni el sistema de Mercado/inversiones — solo el costo y mecanismo de subir/bajar nivel.
- No agregar un stock limitado de "casas"/"hoteles" ni ninguna simulación de piezas físicas — nunca existió y no aplica al nuevo sistema.
- No tocar la regla de doble renta en monopolio a nivel 0 (`rentAmount` ya la implementa, se mantiene igual).

## Criterios de aceptación
1. Compila sin errores.
2. `MonopolyTests/GameRulesTests.swift`: actualiza los tests existentes que usaban `buildHouse`/`buildHotel`/`sellHouse` a los nuevos `levelUp`/`levelDown`, y agrega/ajusta tests para:
   - El costo de subir cada uno de los 5 niveles es el % correcto de `purchasePrice`, redondeado hacia arriba, y se cobra repartido entre accionistas.
   - No se puede subir de nivel sin monopolio de color.
   - No se puede subir un nivel más de 1 por encima del resto del grupo de color (regla uniforme), ni bajar dejando una diferencia mayor a 1.
   - No se puede subir de nivel 5 (máximo) ni bajar de nivel 0.
   - Bajar un nivel devuelve la mitad de lo que costó subirlo, repartido por %.
   - El patrimonio para crédito suma correctamente el costo pagado por los niveles alcanzados.
3. Ningún archivo de código ni de UI menciona "hotel" o "casas" en el contexto de este sistema (búscalo con grep antes de terminar).
4. `GameRules` sigue sin `import SwiftUI`.
