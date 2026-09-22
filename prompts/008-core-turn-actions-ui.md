# Prompt 008 — UI del ciclo básico de turno (renta, hipoteca, construcción, impuestos, salario)

## Contexto

El walking skeleton (prompt 007) ya funciona: host/cliente, roster de jugadores, tablero reactivo, y compra de propiedades conectada de punta a punta. Revisa antes de empezar:
- `Monopoly/UI/GameSessionModel.swift` — el `ObservableObject` que envuelve `GameSession`; ya tiene el patrón a seguir en `buy(propertyID:)`: construir un `GameIntent`, y despachar por `session.submitLocal` si el rol es host o `session.submit` si es cliente, capturando errores en `alertMessage`.
- `Monopoly/UI/GameBoardView.swift` — la vista principal; ya lista jugadores y propiedades con `propertyRow`.
- `Monopoly/Domain/Rules/GameRules.swift` — revisa las firmas exactas de `collectRent`, `mortgageProperty`, `unmortgageProperty`, `buildHouse`, `buildHotel`, `sellHouse`, `payTax`, `collectSalary`.
- `Monopoly/Networking/Messages/GameIntent.swift` — los casos ya existentes que envuelven cada una de esas funciones.
- `PROJECT_RULES.md` secciones 3-4.

**No toques `Domain/` ni `Networking/` en este prompt** — todas las funciones y los casos de `GameIntent` que necesitas ya existen. Si de verdad falta algo, decláralo en tu resumen en vez de modificar esas capas.

## Alcance de esta tarea

Conecta a la UI las siguientes acciones (y solo estas — trades, subastas y bancarrota quedan para un prompt futuro porque son flujos multi-jugador/fin-de-partida distintos, no los implementes aquí):

1. **Pagar renta**: cuando un jugador reporta que cayó en una propiedad con dueño (acción manual, como ya se describe en `GAME_RULES.md` — el jugador físico mueve su ficha y reporta el resultado a la app). Necesitas una forma de que el jugador local indique "caí en esta propiedad" para una propiedad **con dueño que no es él**, y que dispare `collectRent`.
2. **Hipotecar / des-hipotecar**: para una propiedad propia sin casas (hipotecar) o propia hipotecada (des-hipotecar).
3. **Construir casa / construir hotel**: para una propiedad propia con monopolio de color completo.
4. **Vender casa** (devolver una casa/hotel a la banca): para una propiedad propia con al menos una casa.
5. **Pagar impuesto**: acción libre en cualquier momento para el jugador local, con un monto que él mismo introduce (no hay casillas de tablero modeladas todavía, así que el monto es manual, tal como ya se resolvió en el dominio — revisa `payTax` en `GameRules.swift`, toma un `amount` como parámetro).
6. **Cobrar salario**: acción libre en cualquier momento para el jugador local, con un monto que él mismo introduce (mismo razonamiento que el impuesto; en el juego real este sería el monto fijo de "pasar por Salida", pero como no está modelado como constante todavía, pídelo como input, y considera añadir una constante local en la UI para el valor típico placeholder si quieres pre-rellenar el campo — decláralo si lo haces).

### Diseño de UI sugerido (ajusta si tiene sentido, pero mantén la separación de responsabilidades)

- Añade una **vista de detalle de propiedad** (ej. `PropertyDetailView`), navegable al tocar una propiedad en `GameBoardView` (envuelve la fila existente en un `NavigationLink` o similar). Esta vista debe mostrar el estado completo de la propiedad (dueño, nivel de construcción, si está hipotecada, renta actual) y los botones de acción que apliquen según el estado y quién es el jugador local:
  - Si la propiedad tiene dueño y **no es el jugador local**: botón "Pagar renta" (dispara `collectRent` con el jugador local como pagador).
  - Si la propiedad es del jugador local:
    - Si no está hipotecada y no tiene casas: botón "Hipotecar".
    - Si está hipotecada: botón "Deshipotecar".
    - Si no está hipotecada: botones "Construir casa" (si nivel < 4) y "Construir hotel" (si nivel == 4), y "Vender casa" (si nivel > 0) — no dupliques la validación de monopolio completo en la UI, deja que el rechazo venga del dominio vía `onIntentRejected` si el jugador no califica; puedes ocultar los botones de construcción cuando sea trivial determinar con los datos ya disponibles en el `GameState` local que el jugador no tiene el grupo completo, pero no es obligatorio.
- Añade una sección o vista simple (puede vivir directamente en `GameBoardView`, tu criterio) con dos acciones libres: "Pagar impuesto" y "Cobrar salario", cada una abriendo un input simple de monto (ej. `TextField` numérico + botón "Confirmar" en un `.sheet` o `.alert` con campo de texto) antes de disparar el intent correspondiente.

### `GameSessionModel`

Añade los métodos equivalentes a `buy(propertyID:)` para cada nueva acción (ej. `payRent(propertyID:)`, `mortgage(propertyID:)`, `unmortgage(propertyID:)`, `buildHouse(propertyID:)`, `buildHotel(propertyID:)`, `sellHouse(propertyID:)`, `payTax(amount:)`, `collectSalary(amount:)`). Para evitar repetir la misma rama `switch role { .host: submitLocal, .client: submit }` en cada uno, factoriza ese despacho en un método privado único (ej. `private func send(_ intent: GameIntent)`) y haz que todos los métodos públicos lo usen — esto es puro orden, no cambia el comportamiento.

## Criterios de aceptación

1. El proyecto compila sin warnings nuevos usando el scheme `Monopoly` (`xcodebuild -project Monopoly.xcodeproj -scheme Monopoly -destination 'platform=iOS Simulator,name=iPhone 16' build test`).
2. Los 53 tests existentes siguen pasando sin modificarse.
3. Solo se modifica/crea código dentro de `Monopoly/UI/` (más, si acaso, `GameBoardView.swift` para añadir la navegación a `PropertyDetailView`). No se toca `Domain/` ni `Networking/`.
4. Cada una de las 6 acciones del alcance está accesible desde la UI y usa el patrón ya establecido de `GameSessionModel` (intent → `submitLocal`/`submit` → error a `alertMessage` si se rechaza).
5. Ningún botón de acción es visible quebrando la regla básica de "solo el jugador local actúa por sí mismo" (ej. no debe poder pagar renta de un dueño hacia sí mismo, ni construir en una propiedad que no es suya — aunque el dominio ya lo rechazaría, la UI no debería ni mostrar la opción en los casos obviamente imposibles descritos arriba).
6. No se añade ninguna dependencia externa sin justificarlo en el resumen final.

## Al terminar

Entrega, íntegro y por escrito en tu respuesta, un resumen que indique:
- Qué archivos creaste o modificaste.
- Cómo resolviste el input de monto para impuesto/salario (sheet, alert con TextField, u otro enfoque) y por qué.
- Si añadiste alguna constante placeholder (ej. monto típico de salario) y dónde la dejaste documentada como tal.
- Cualquier decisión de diseño de UI no especificada en el prompt que hayas tenido que tomar.
- Cómo verificaste manualmente (en el simulador, un solo dispositivo como host) que al menos un par de estas acciones funcionan de punta a punta.
