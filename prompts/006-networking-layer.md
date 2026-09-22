# Prompt 006 — Capa de red (MultipeerConnectivity, host-autoritativo)

## Contexto

La capa de dominio (`Monopoly/Domain/`) está funcionalmente completa: compra, renta, hipoteca, construcción, bancarrota, impuestos, trades y subastas, todo implementado como funciones puras sobre `GameState` con errores tipados (`GameRuleError`), con 47/47 tests pasando. Revisa esas funciones en `Monopoly/Domain/Rules/GameRules.swift` antes de empezar — son la lista completa de acciones que la capa de red debe poder transportar:

`buyProperty`, `resolveAuction`, `collectRent`, `payTax`, `collectSalary`, `buildHouse`, `buildHotel`, `sellHouse`, `mortgageProperty`, `unmortgageProperty`, `declareBankruptcy`, `executeTrade`.

(`canCoverDebt` es una consulta, no una acción que mute estado — no necesita transportarse como intent, se usa localmente antes de decidir si declarar bancarrota.)

Lee (o relee) completos antes de empezar:
- `PROJECT_RULES.md` sección 3 (arquitectura y decisión de red: MultipeerConnectivity, sin backend en la nube, host-autoritativo)
- `CONTEXT.md`
- `Monopoly/Domain/Rules/GameRules.swift` y sus modelos en `Monopoly/Domain/Models/` completos, para conocer las firmas exactas de cada función y qué parámetros necesita cada una.

**No modifiques nada dentro de `Domain/`** en este prompt — la capa de red debe consumir el dominio tal como está, sin tocar su lógica. Si encuentras que falta algo en el dominio para poder integrarlo (por ejemplo, algún tipo que no es `Codable`), decláralo en tu resumen final en vez de modificarlo tú mismo.

## Alcance de esta tarea

Construir la **capa de red** en una carpeta nueva `Networking/` dentro del target `Monopoly`, separada de `Domain/` y de la UI (que todavía no existe). Nada de SwiftUI en este prompt tampoco — es infraestructura, no vistas.

### 1. Por qué una abstracción de transporte

`MultipeerConnectivity` (MCSession, MCNearbyServiceAdvertiser, MCNearbyServiceBrowser) no se puede testear de forma fiable en XCTest sin dispositivos reales cercanos. Por eso, **todo el código de transporte debe estar detrás de un protocolo Swift** que puedas implementar dos veces: una vez con MultipeerConnectivity real, y otra con una versión en memoria para tests. La lógica de negocio de red (qué hacer con un mensaje recibido) debe depender del protocolo, nunca directamente de tipos de `MultipeerConnectivity`.

Estructura sugerida (ajusta nombres si tiene sentido, pero mantén esta separación de responsabilidades):

```
Networking/
  Transport/
    GameTransport.swift          -> protocolo de transporte (send, broadcast, callbacks de conexión/datos)
    MultipeerGameTransport.swift -> implementación real con MultipeerConnectivity
  Messages/
    GameIntent.swift             -> enum Codable que envuelve cada acción de dominio con sus parámetros
    NetworkMessage.swift         -> envelope Codable que se envía por la red (intent de cliente a host, snapshot de estado de host a todos, error de host a un cliente)
  Session/
    GameSession.swift            -> orquestador: rol host/cliente, aplica intents (si es host) o los envía (si es cliente), mantiene el GameState local
```

### 2. Protocolo de transporte (`GameTransport.swift`)

Define un protocolo con, como mínimo:
- Una forma de identificar peers (puedes envolver `MCPeerID` o definir tu propio `PeerID` — si envuelves `MCPeerID`, la implementación en memoria para tests necesitará su propio tipo equivalente conforme al mismo protocolo genérico o a un typealias; decide y documenta tu enfoque).
- `send(data: Data, to peer: PeerID) throws` — envío dirigido a un peer.
- `broadcast(data: Data) throws` — envío a todos los peers conectados.
- Un mecanismo de callback/closure para "datos recibidos de un peer" y para "peer conectado/desconectado" (no uses delegado obligatorio si un closure es más simple de testear).
- Métodos para empezar/detener el descubrimiento (`startHosting()`, `startBrowsing()`, `stop()`) — pueden ser no-ops en la implementación en memoria de test.

### 3. Mensajes (`Messages/`)

- `GameIntent`: enum `Codable` con un caso por cada función de dominio listada arriba, llevando los parámetros necesarios (IDs de jugador/propiedad, montos, `[AuctionBid]`, `TradeOffer`, `DebtCreditor`, etc. — usa los tipos ya existentes en `Domain/Models/`, no dupliques modelos).
- `NetworkMessage`: enum o struct `Codable` que representa lo que realmente viaja por la red. Como mínimo debe soportar:
  - Cliente → host: un `GameIntent` junto con el `playerID` de quien lo envía (para que el host sepa quién pide qué, sin confiar en que el intent lo traiga embebido de forma inconsistente).
  - Host → todos: un snapshot completo del `GameState` actualizado (broadcast tras aplicar un intent exitosamente).
  - Host → un cliente específico: un error indicando que su intent fue rechazado (usa una representación serializable de `GameRuleError` — revisa si ya es `Codable`; si no lo es, añade la conformidad en `Domain/Rules/GameRuleError.swift`, es el único cambio permitido dentro de `Domain/` en este prompt, y solo si hace falta).

### 4. Orquestador (`Session/GameSession.swift`)

Una clase (no struct, aquí sí tiene sentido por identidad y estado mutable de sesión) que:
- Se inicializa con un `GameTransport`, un rol (`.host` o `.client`), y (si es host) el `GameState` inicial de la partida.
- Expone el `GameState` actual de forma legible (ej. `@Published` si quieres facilitar la futura integración con SwiftUI, pero sin importar `SwiftUI` — `Combine`/`Observation` están bien).
- **Si es host**: al recibir un `NetworkMessage` con un intent de un cliente, lo despacha a la función correspondiente de `GameRules` con el `GameState` actual. Si la función tiene éxito, actualiza el estado local y hace `broadcast` de un mensaje con el nuevo `GameState` a todos los peers. Si falla, envía de vuelta (con `send`, no `broadcast`) un mensaje de error solo al peer que originó el intent.
- **Si es cliente**: al querer ejecutar una acción, construye el `GameIntent` correspondiente, lo envuelve en un `NetworkMessage` y lo envía (`send`) al host. Al recibir un `NetworkMessage` con un snapshot de estado, reemplaza su copia local del `GameState`. Al recibir un mensaje de error, lo expone de alguna forma consultable (ej. un closure `onIntentRejected: ((GameRuleError) -> Void)?` o similar).
- El host **no valida de más**: confía en que `GameRules` es la única fuente de validación (no dupliques reglas de negocio aquí).

### 5. Tests (XCTest)

Como la implementación real de `MultipeerConnectivity` no es testeable en CI, los tests deben usar una implementación en memoria del protocolo `GameTransport` (créala en el target de test o en un archivo de soporte, tu criterio). Cubre, como mínimo:

- Codificación/decodificación (`Codable` round-trip) de `GameIntent` para al menos 3 casos distintos (ej. `buyProperty`, `executeTrade`, `resolveAuction`) y de `NetworkMessage` en sus 3 variantes (intent de cliente, snapshot de host, error de host).
- Un `GameSession` en rol host que recibe un intent válido (ej. comprar una propiedad sin dueño) y termina emitiendo un `GameState` actualizado correctamente (usa la implementación en memoria conectando dos instancias de transporte para simular host+cliente, o inyecta directamente un mensaje si tu diseño de transporte lo permite sin peers reales conectados — documenta cuál enfoque usaste).
- Un `GameSession` host que recibe un intent inválido (ej. comprar una propiedad que ya tiene dueño) y responde con un error al remitente, **sin** mutar ni hacer broadcast del `GameState` a nadie.
- Un `GameSession` cliente que, al recibir un snapshot de estado del host, actualiza su copia local correctamente.
- Al menos un test de round-trip completo con dos `GameSession` (host y cliente) conectados a través de la implementación en memoria de `GameTransport`: el cliente envía un intent, el host lo procesa, y el cliente termina viendo el `GameState` actualizado.

## Criterios de aceptación

1. El proyecto compila sin warnings nuevos usando el scheme `Monopoly` (`xcodebuild -project Monopoly.xcodeproj -scheme Monopoly -destination 'platform=iOS Simulator,name=iPhone 16' build test`).
2. Los 47 tests existentes de `Domain/` siguen pasando sin modificarse (salvo, si hiciera falta, añadir `Codable` a `GameRuleError` — ver punto 3 de arriba).
3. Todos los tests nuevos de este prompt pasan.
4. Nada en `Networking/` importa `SwiftUI`.
5. No se toca `ContentView.swift` ni `MonopolyApp.swift`.
6. No se usa ningún framework de red externo — solo `MultipeerConnectivity` (framework de Apple, no requiere SPM) y `Foundation`. No añadas dependencias de terceros.
7. La lógica de negocio (qué acción se permite y con qué resultado) sigue viviendo exclusivamente en `Domain/` — `Networking/` solo transporta y despacha, no reimplementa reglas.

## Al terminar

Entrega, íntegro y por escrito en tu respuesta, un resumen que indique:
- Qué archivos creaste.
- Cómo modelaste la identidad de peer (`PeerID`) y cómo la implementación en memoria de test se conecta con el protocolo `GameTransport`.
- Si tuviste que tocar `Domain/Rules/GameRuleError.swift` para hacerlo `Codable`, y qué representación usaste para los casos con payload asociado (`UUID`, tuplas, etc.).
- Cómo decidiste simular la conexión host-cliente en los tests (dos transportes en memoria enlazados, inyección directa de mensajes, u otro enfoque).
- Cualquier decisión de diseño no especificada en el prompt que hayas tenido que tomar.
