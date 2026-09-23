# 014 — Selector de modo de juego y estado base de Monopolife

## Contexto

Lee `CONTEXT.md`, `PROJECT_RULES.md`, `GAME_RULES.md` y **`MONOPOLIFE_RULES.md` completo** antes de empezar. Este prompt implementa las secciones **1, 2 (solo el contador y el historial), 3.1, 7** de `MONOPOLIFE_RULES.md`. Los gustos/disgustos de los roles (3.3), la ruleta (4), las Tarjetas de Vida (5) y la bancarrota de Monopolife (6) vienen en prompts siguientes: **no los implementes aquí**.

Es el primero de cuatro prompts (014–017). Deja la estructura lista para que los siguientes solo agreguen reglas y UI.

Revisa antes de tocar nada:
- `Monopoly/Domain/Models/GameState.swift` — decodificación tolerante con `decodeIfPresent` para partidas guardadas antiguas (así se añadió `rentInvestments`); sigue ese patrón.
- `Monopoly/Networking/Messages/Lobby.swift` — `makeGameState`.
- `Monopoly/Domain/Rules/GameRules.swift` — `advanceTurn` (donde se incrementa `round`) y `requireActivePlayer`.
- `Monopoly/Networking/Session/GameSession.swift` — `apply(_:submittedBy:isHost:in:)` y `publishRoomInfo`.
- `Monopoly/Networking/Messages/DiscoveredRoom.swift`, `Monopoly/UI/HostSetupView.swift`, `Monopoly/UI/JoinView.swift`, `Monopoly/UI/GameBoardView.swift`.

## Qué construir

### 1. Dominio
- `enum GameMode: String, Codable, CaseIterable { case classic, monopolife }`.
- `enum LifeRole: String, Codable, CaseIterable` con los 6 roles de `MONOPOLIFE_RULES.md` 3.3: `consumer`, `entrepreneur`, `saver`, `social`, `investor`, `globetrotter`. Solo el enum; sus reglas vienen en 015.
- `struct LifeProfile: Codable, Equatable` por jugador: `role: LifeRole`, `happiness: Int`, `hasAcknowledgedRole: Bool`. (015 y 017 le agregarán campos: déjalo preparado para decodificación tolerante.)
- `struct HappinessEvent: Codable, Equatable`: `playerID`, `delta: Int`, `reason` (enum `HappinessReason`, por ahora con casos genéricos que 015/017 ampliarán; incluye al menos un caso para cada fuente: rol, tarjeta, bancarrota), `round`.
- `struct MonopolifeState: Codable, Equatable`: `roundLimit: Int`, `profiles: [UUID: LifeProfile]`, `happinessLog: [HappinessEvent]`, `isFinished: Bool`.
- En `GameState`: `mode: GameMode` (default `.classic`) y `monopolife: MonopolifeState?` (nil en Classic). Partidas guardadas sin estos campos deben decodificar como Classic.
- **Nada de Classic cambia**: con `mode == .classic` todo el comportamiento y los tests actuales quedan idénticos.

### 2. Reglas (nuevo archivo `GameRules+Monopolife.swift`, sin `import SwiftUI`)
- `assignRoles(to playerIDs: [UUID], using generator: inout some RandomNumberGenerator) -> [UUID: LifeRole]`: sin repetir mientras queden roles sin usar; con más de 6 jugadores, se vuelve a sortear entre todos. El generador es inyectable para tests deterministas.
- `adjustHappiness(of:by:reason:in:)`: suma/resta, nunca deja la felicidad bajo 0, agrega el `HappinessEvent` al historial con el delta **realmente aplicado** (si estaba en 1 y resta 3, el evento registra −1). No hace nada en Classic. Es la única vía para cambiar felicidad; 015 y 017 la usarán.
- `acknowledgeRole(in:playerID:)`: marca `hasAcknowledgedRole`.
- Fin de partida: en `advanceTurn`, si el modo es Monopolife y la ronda que acaba de terminar es `roundLimit`, en vez de pasar a la ronda siguiente marca `isFinished = true` y `currentPlayerID = nil`. Deja un punto de extensión claro (ej. función `endOfRound(in:)` llamada justo antes de incrementar `round` o terminar) donde 015 aplicará los efectos de fin de ronda; aquí puede estar vacía.
- Con `isFinished == true`, `GameSession.apply` rechaza **cualquier** intent con un nuevo `GameRuleError.gameFinished`.
- `winners(in:) -> [UUID]`: más felicidad; empate → mayor patrimonio (`netWorth`); si sigue el empate, devuelve a todos los empatados.

### 3. Lobby y red
- `Lobby`: `gameMode: GameMode = .classic` y `roundLimit: Int = 15` (opciones válidas 10, 15, 20, 25). Decodificación tolerante.
- `makeGameState`: si es Monopolife, crea `MonopolifeState` con los roles asignados por `assignRoles` (usa `SystemRandomNumberGenerator` aquí), felicidad 0 y `hasAcknowledgedRole = false`.
- Nuevo intent `acknowledgeRole(playerID:)`, permitido en cualquier momento (no requiere turno) y despachado en `GameSession`.
- `DiscoveredRoom`: nueva clave `mode` en la info de Bonjour (mantén la info pequeña, ej. `"c"`/`"l"`); si falta, Classic.

### 4. UI
- `HostSetupView`: sección "Modo de juego" con un `Picker` segmentado **Monopoly Classic / Monopolife**. Si es Monopolife, un picker de rondas (10/15/20/25) y una línea explicando "Gana quien tenga más felicidad. Cada jugador recibe un rol secreto."
- Vista de sala del cliente (`JoinView`): muestra el modo y las rondas elegidos, solo lectura.
- Tarjetas de sala cercana: muestra un badge con el modo.
- `GameBoardView` en Monopolife: muestra "Ronda X de N" y la felicidad **solo del jugador local** (o del jugador "Jugando como" en el iPhone del host). No muestres el rol ni la felicidad de otros.
- Pantalla final provisional cuando `isFinished`: lista de jugadores ordenada por felicidad con el ganador destacado y su rol revelado. (016 la rediseña; aquí basta una versión simple y funcional.)

## Fuera de alcance
- Gustos/disgustos de roles, efectos de fin de ronda (015).
- Ruleta y rediseño de la pantalla final (016). En este prompt, si `hasAcknowledgedRole == false`, basta con mostrar un alert/sheet simple con el nombre del rol y un botón "Entendido" que envía `acknowledgeRole`.
- Tarjetas de Vida (017). Bancarrota de Monopolife (015).
- No refactorices nada de Classic.

## Criterios de aceptación
1. Compila sin errores. `GameRules+Monopolife.swift` no importa SwiftUI.
2. Todos los tests existentes pasan sin modificarlos.
3. Nuevos tests en `MonopolyTests` (archivo nuevo `MonopolifeRulesTests.swift`):
   - Una partida guardada sin `mode`/`monopolife` decodifica como Classic.
   - `assignRoles` con 6 jugadores no repite roles; con 8, usa los 6 roles y repite solo 2; con generador sembrado el resultado es determinista.
   - `adjustHappiness` nunca deja la felicidad bajo 0 y registra el delta real; en Classic no hace nada.
   - Con `roundLimit = 2`, al terminar el último turno de la ronda 2 la partida queda `isFinished`, `currentPlayerID == nil` y `round` sigue en 2.
   - Con la partida terminada, cualquier intent se rechaza con `gameFinished`.
   - En Classic, `advanceTurn` nunca termina la partida.
   - `winners`: gana más felicidad; empate se rompe por patrimonio; empate total devuelve a ambos.
4. Manual: el host elige Monopolife y 10 rondas, el cliente lo ve en la sala y en la tarjeta de sala cercana; al iniciar, cada jugador ve su rol y confirma.
