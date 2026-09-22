# Prompt 009 — UI de trades, subastas y bancarrota

## Contexto

La UI ya cubre compra, renta, hipoteca, construcción, venta de construcciones, impuestos y salario (prompts 007-008), todo conectado de punta a punta con 53/53 tests pasando. Revisa antes de empezar:
- `Monopoly/UI/GameSessionModel.swift` — ya tiene el patrón establecido: cada acción construye un `GameIntent` y lo despacha vía el método privado `send(_:)` (que a su vez elige `submitLocal` u `submit` según el rol). Sigue exactamente este patrón para las nuevas acciones.
- `Monopoly/UI/GameBoardView.swift` y `Monopoly/UI/PropertyDetailView.swift` — para mantener el mismo estilo visual y de navegación ya establecido.
- `Monopoly/Domain/Models/TradeOffer.swift`, `AuctionBid.swift`, `Debt.swift` (incluye `DebtCreditor`) — los tipos exactos que necesitas construir desde la UI.
- `Monopoly/Domain/Rules/GameRules.swift` — revisa las firmas de `executeTrade`, `resolveAuction`, `canCoverDebt` y `declareBankruptcy`.
- `Monopoly/Networking/Messages/GameIntent.swift` — casos `executeTrade`, `resolveAuction`, `declareBankruptcy` ya existen.
- `PROJECT_RULES.md` secciones 3-4.

**No toques `Domain/` ni `Networking/`** salvo que sea estrictamente imprescindible — si lo es, decláralo y justifícalo explícitamente en tu resumen (como ya se hizo, justificadamente, en el prompt 007 con `GameSession.submitLocal`).

## Alcance de esta tarea

Conecta estos tres flujos, cada uno en su propia sección de la interfaz:

### 1. Trades (intercambios entre jugadores)

Añade una pantalla (ej. `TradeView`) accesible desde `GameBoardView` (ej. un botón "Proponer intercambio"). Debe permitir al jugador local:
- Elegir el jugador con quien intercambiar (de la lista de jugadores activos, excluyéndose a sí mismo).
- Seleccionar cero o más propiedades **propias** para ofrecer, y un monto de dinero a ofrecer (puede ser 0).
- Seleccionar cero o más propiedades **del otro jugador** para pedir a cambio, y un monto de dinero a pedir (puede ser 0).
- Un botón "Proponer" que construye un `TradeOffer` (con `fromPlayerID` = jugador local) y lo envía como `GameIntent.executeTrade`.

Ten en cuenta que `executeTrade` en el dominio **no implementa un flujo de "proponer y esperar aceptación del otro jugador"** — ejecuta el intercambio inmediatamente si es válido (esto ya se decidió así en el prompt 004: la lógica de "proponer y esperar aceptación" es responsabilidad de la capa superior). Para este prompt, **no implementes tampoco** un mecanismo real de aceptación/rechazo por el otro jugador — eso requeriría un intent nuevo de "propuesta pendiente" que no existe en el dominio, y está fuera de alcance. En su lugar:
- Dejar claro en la UI (con texto visible, ej. un aviso antes del botón "Proponer") que esta acción **ejecuta el intercambio de inmediato** si es válido — no es una propuesta negociable todavía, es una limitación conocida a documentar en tu resumen, no a resolver aquí.

### 2. Subastas

Añade una pantalla (ej. `AuctionView`) accesible para una propiedad **sin dueño** (puede lanzarse desde `PropertyDetailView`, con un botón nuevo "Iniciar subasta" visible cuando `property.ownerID == nil`, en vez de o además de "Comprar" — decide y documenta cómo conviven ambas opciones en la UI, ya que hoy "Comprar" ya existe para propiedades sin dueño).

En `AuctionView`:
- Permite ir añadiendo pujas: seleccionar un jugador (cualquiera, incluido el jugador local) y un monto, con un botón "Añadir puja" que las va acumulando en una lista visible, en el orden en que se añaden.
- Valida en la propia UI, de forma simple, que cada puja nueva sea estrictamente mayor que la última añadida (si no, deshabilita "Añadir puja" o muestra un aviso) — esto **sí** es razonable duplicarlo mínimamente en la UI porque mejora la experiencia antes de enviar nada por red, pero el dominio seguirá siendo quien realmente lo valide y rechace si algo se le escapa a la UI.
- Un botón "Cerrar subasta" que envía la lista completa de pujas como `GameIntent.resolveAuction(propertyID:bids:)`.
- Permite también "Cerrar subasta sin pujas" (lista vacía) para el caso de que nadie quiera pujar, dejando la propiedad sin dueño (revisa `GAME_RULES.md` sección 4.1 y `resolveAuction` en el dominio — una lista vacía no es un error).

### 3. Bankruptcy (bancarrota)

Añade una acción accesible desde `GameBoardView` (ej. un botón "Declararme en bancarrota" visible solo para el jugador local, o un menú de "Acciones del jugador" si prefieres agrupar ahí también impuesto/salario del prompt 008 — tu criterio de organización, pero no dupliques controles ya existentes).

Antes de declarar bancarrota, la UI debe pedir al jugador que indique **la deuda que no puede cubrir**: un monto y un acreedor (otro jugador de la lista, o "La banca"). Usa esto para:
- Consultar primero (de forma puramente local e informativa, sin enviarlo por red) usando el resultado que ya tengas disponible del `GameState` local si decides exponer `canCoverDebt` de alguna forma, **o simplemente deja que el jugador decida por su cuenta si declararse en bancarrota** — no es obligatorio llamar a `canCoverDebt` desde la UI, es una función de consulta que el dominio ya expone, pero conectarla es opcional en este prompt; si no la conectas, dilo en tu resumen y explica por qué.
- Construir un `Debt(amount:creditor:)` y enviar `GameIntent.declareBankruptcy(playerID: localPlayerID, creditor: debt.creditor)` — **nota**: revisa la firma exacta de `GameIntent.declareBankruptcy` y de `GameRules.declareBankruptcy`; si el monto de la deuda no es un parámetro que el dominio realmente necesite para ejecutar la bancarrota (la ejecución solo necesita saber a quién se le debe, no cuánto, según cómo se implementó en el prompt 003), no lo fuerces innecesariamente — usa el monto solo si hace falta.
- Mostrar una confirmación clara (ej. un `.confirmationDialog` o alerta) antes de ejecutar, dado que es una acción irreversible y de alto impacto (el jugador pierde todo).
- Tras una bancarrota exitosa, el jugador afectado debería dejar de poder actuar — revisa cómo `GameSessionModel`/las vistas existentes usan `player.status` (ya existe en el modelo `Player`) para, como mínimo, mostrar visualmente en `GameBoardView` qué jugadores están en bancarrota (ej. nombre tachado o con una etiqueta), sin necesidad de ocultarlos de la lista.

## Criterios de aceptación

1. El proyecto compila sin warnings nuevos usando el scheme `Monopoly` (`xcodebuild -project Monopoly.xcodeproj -scheme Monopoly -destination 'platform=iOS Simulator,name=iPhone 16' build test`).
2. Los 53 tests existentes siguen pasando sin modificarse.
3. Solo se modifica/crea código dentro de `Monopoly/UI/`, salvo un cambio estrictamente imprescindible y justificado en `Networking/`/`Domain/` (documentado en el resumen).
4. Los tres flujos (trade, subasta, bancarrota) son accesibles y usan el patrón `send(_:)` ya establecido en `GameSessionModel`.
5. La UI dis­tingue visualmente qué jugadores están en bancarrota (`player.status`).
6. No se añade ninguna dependencia externa sin justificarlo en el resumen final.

## Al terminar

Entrega, íntegro y por escrito en tu respuesta, un resumen que indique:
- Qué archivos creaste o modificaste.
- Cómo conviven los botones "Comprar" e "Iniciar subasta" en `PropertyDetailView` para una propiedad sin dueño.
- Si conectaste o no `canCoverDebt` a la UI antes de declarar bancarrota, y por qué.
- La limitación conocida y declarada de que un trade se ejecuta de inmediato (no hay negociación/aceptación real todavía).
- Cualquier decisión de diseño de UI no especificada en el prompt que hayas tenido que tomar.
- Cómo verificaste manualmente (en el simulador, como host) que al menos uno de estos tres flujos funciona de punta a punta.
