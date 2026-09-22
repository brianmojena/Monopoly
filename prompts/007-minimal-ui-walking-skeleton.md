# Prompt 007 — UI mínima en SwiftUI (walking skeleton host/cliente)

## Contexto

La capa de dominio (`Monopoly/Domain/`) y la capa de red (`Monopoly/Networking/`) están completas y probadas (53/53 tests). Revisa antes de empezar:
- `Monopoly/Networking/Session/GameSession.swift` — la clase que ya orquesta host/cliente, aplica intents vía `GameRules` y expone `gameState`, `onStateChanged`, `onIntentRejected`.
- `Monopoly/Networking/Transport/MultipeerGameTransport.swift` — la implementación real de transporte que debes instanciar desde la UI (nunca la de test).
- `Monopoly/Networking/Messages/GameIntent.swift` — los casos disponibles para enviar como cliente.
- `Monopoly/Domain/Data/PlaceholderProperties.swift` — el tablero placeholder que el host debe usar para crear la partida.
- `Monopoly/Domain/Models/Player.swift` y `GameState.swift`.
- `PROJECT_RULES.md` sección 3 (host-autoritativo, sin backend en la nube) y sección 4 (separación dominio/UI: la UI no debe reimplementar reglas, solo llamar a `GameSession`).

Lee también `GAME_RULES.md` y `CONTEXT.md` para tener presente el marco general, aunque esta tarea es puramente de interfaz.

## Objetivo de esta tarea (léelo con atención, el alcance está deliberadamente acotado)

El objetivo **no** es construir la UI completa del juego. Es construir el **walking skeleton** mínimo que demuestre, de forma interactiva y en dispositivos reales o simuladores distintos, que dominio + red + UI funcionan juntos de punta a punta: un dispositivo crea una partida (host), otro se conecta (cliente), y al menos **una acción de dominio** (comprar una propiedad) viaja del cliente al host, se valida con `GameRules`, y el resultado se sincroniza de vuelta a todos.

No implementes en este prompt: renta, hipoteca, construcción, trades, subastas, impuestos, ni bancarrota en la UI (sus funciones de dominio ya existen y funcionan, pero conectarlas a botones/pantallas es trabajo de un prompt futuro — no repitas ese trabajo aquí ni dejes UI a medias para ellas). Tampoco implementes gestión de turnos, movimiento en tablero, ni ninguna mecánica que no sea "crear/unirse a partida" + "comprar una propiedad sin dueño".

## Alcance de esta tarea

### 1. Limitación conocida a resolver: no hay forma de "unirse" dinámicamente

El dominio actual no tiene una función para añadir un jugador a una partida ya creada — `GameState.players` se define de una vez al construir el `GameState`. Como la app es multi-dispositivo con host-autoritativo (`PROJECT_RULES.md`), resuelve esto así para este prompt:

- En la pantalla de **host**, antes de empezar a alojar la partida, el host introduce los **nombres de todos los jugadores que van a participar** (incluido él mismo), uno por uno, en una lista simple (añadir/quitar nombres, mínimo 2 para poder empezar). Al pulsar "Iniciar partida", el host construye el `GameState` inicial con esos jugadores (saldo inicial: usa un valor placeholder razonable, ej. 1500, y decláralo claramente como placeholder en el código) y las propiedades de `PlaceholderProperties.all`, luego crea un `GameSession(transport: MultipeerGameTransport(...), role: .host, initialState: ...)`.
- En la pantalla de **cliente**, el jugador se conecta al host descubierto por la red local. Una vez recibe el primer snapshot del `GameState` (vía `onStateChanged`), se le muestra la lista de nombres de jugadores ya creados por el host, y debe **seleccionar cuál de esos nombres es él** (esto es una simplificación deliberada: no hay autenticación, es solo "elige tu nombre de la lista"). A partir de ahí, ese `playerID` seleccionado es con el que ese dispositivo enviará sus intents.
- No implementes edición/eliminación de jugadores después de iniciada la partida, ni validación de que dos clientes no seleccionen el mismo nombre — es una limitación conocida y aceptable para este walking skeleton; decláralo en tu resumen final.

### 2. Pantallas

Construye, en una carpeta nueva `Monopoly/UI/` (separada de `Domain/` y `Networking/`), como mínimo estas vistas SwiftUI:

- **`StartView`**: pantalla inicial con dos opciones claras: "Alojar partida" (host) y "Unirse a partida" (cliente). Reemplaza el contenido actual de `ContentView.swift` para que muestre `StartView` en vez del placeholder de "Hello, world!" — puedes modificar `ContentView.swift` esta vez (a diferencia de los prompts anteriores, esta tarea sí incluye UI, así que este archivo ya no está fuera de alcance).
- **`HostSetupView`**: la lista de nombres de jugadores a añadir/quitar descrita arriba, con botón "Iniciar partida" que crea el `GameState` y el `GameSession` de host, y navega a `GameBoardView`.
- **`JoinView`**: inicia el `MultipeerGameTransport` en modo cliente (`startBrowsing`), muestra el estado de "buscando partida…" y, cuando se conecta, espera el primer snapshot de estado y navega a una vista de selección de nombre (puede ser parte de esta misma vista o una nueva `SelectPlayerView`) antes de pasar a `GameBoardView`.
- **`GameBoardView`**: vista principal una vez conectado (como host o como cliente con jugador ya seleccionado). Debe mostrar:
  - Lista de todos los jugadores con su saldo actual (se actualiza reactivamente cuando `GameSession.onStateChanged` dispara — usa `@Observable`/`ObservableObject` según corresponda para que `GameSession` publique cambios de forma que SwiftUI pueda observarlos; revisa si `GameSession` ya es observable o si necesitas envolverlo o adaptarlo mínimamente desde la UI sin modificar `Networking/`).
  - Lista de todas las propiedades con su nombre, dueño actual (o "Sin dueño") y precio.
  - Para cada propiedad **sin dueño**, un botón "Comprar" visible únicamente para el jugador local (el jugador que este dispositivo tiene seleccionado como "yo"). Al pulsarlo:
    - Si el dispositivo es **cliente**: construye el `GameIntent.buyProperty`, y llama a `GameSession.submit(intent:playerID:)`.
    - Si el dispositivo es **host**: el host también debe poder comprar como si fuera un jugador más (es uno de los jugadores de la lista) — como el host aplica sus propios intents localmente sin pasar por red, decide cómo resolverlo (ej. el host también usa `submit`/una ruta equivalente que aplica el intent directamente vía `GameRules` y hace broadcast, sin necesidad de enviarse un mensaje de red a sí mismo) y documenta tu decisión.
  - Si una compra es rechazada (`GameSession.onIntentRejected`), muestra el error al usuario de forma simple (ej. una alerta con la descripción del `GameRuleError`).

### 3. Qué no construir todavía

- No implementes pantallas ni lógica para renta, hipoteca, construcción, trades, subastas, impuestos o bancarrota — sus botones/flujos son prompts futuros.
- No implementes reconexión automática si se pierde la conexión, ni manejo robusto de desconexión de peers — deja el comportamiento por defecto de `GameSession`/`MultipeerGameTransport` tal cual, sin añadir lógica nueva de recuperación.
- No dupliques ninguna validación de negocio en la UI (ej. no comprobar tú mismo si el jugador tiene saldo suficiente antes de mostrar el botón "Comprar" — deja que el rechazo, si ocurre, venga del dominio vía `onIntentRejected`; puedes deshabilitar el botón si es trivial hacerlo con datos ya disponibles, pero no es obligatorio en este prompt).

## Criterios de aceptación

1. El proyecto compila sin warnings nuevos usando el scheme `Monopoly` (`xcodebuild -project Monopoly.xcodeproj -scheme Monopoly -destination 'platform=iOS Simulator,name=iPhone 16' build test`).
2. Los 53 tests existentes siguen pasando sin modificarse (esta tarea no debería requerir tocar `Domain/` ni `Networking/`; si encuentras que sí hace falta un ajuste mínimo ahí, decláralo explícitamente en tu resumen y justifica por qué era imprescindible).
3. `Monopoly/UI/` es la única carpeta nueva de código de producto; `ContentView.swift` puede modificarse en este prompt (ver punto 2 de la sección de pantallas).
4. La app debe poder ejecutarse en el simulador de iOS y navegar manualmente: Start → Host (crear 2+ jugadores, iniciar) → ver el tablero. No es necesario que puedas probar tú mismo el flujo de dos dispositivos reales conectados por red (no tienes ese entorno), pero el código debe estar completo y ser razonablemente correcto para ese escenario — descríbelo en tu resumen para que se pruebe manualmente después.
5. No se añade ninguna dependencia externa sin justificarlo en el resumen final.

## Al terminar

Entrega, íntegro y por escrito en tu respuesta, un resumen que indique:
- Qué archivos creaste o modificaste, incluyendo si tocaste algo fuera de `UI/` y por qué.
- Cómo resolviste la selección de jugador en el cliente y cualquier limitación conocida que dejaste (ej. sin validación de nombres duplicados).
- Cómo el host aplica sus propias acciones (compra) sin pasar por la red, y por qué elegiste ese enfoque.
- Cómo verificaste (manualmente, en el simulador, con un solo dispositivo) que al menos el flujo de host funciona de punta a punta.
- Cualquier decisión de diseño de UI no especificada en el prompt que hayas tenido que tomar.
