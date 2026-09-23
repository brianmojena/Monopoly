# Contexto del Proyecto

Este documento da contexto de alto nivel para cualquier persona o agente (incluido Codex) que entre a este repositorio por primera vez. No define reglas normativas (eso está en `GAME_RULES.md` y `PROJECT_RULES.md`); da la foto general de **qué es esto y por qué existe**.

## Qué es esto

Una app iOS para jugar Monopoly, específicamente la edición física **Monopoly Ultimate Banking**. Esa edición viene con un dispositivo lector de tarjetas que actúa como banco digital, pero ese dispositivo tiene limitaciones molestas que arruinan la fluidez de la partida (lentitud, una sola unidad para gestionar todo el dinero, dependencia de un hardware propietario que puede fallar o perderse). Este proyecto reemplaza ese dispositivo físico por una app que cada jugador corre en su propio teléfono.

El tablero, las fichas, los dados y las cartas siguen siendo los físicos de la caja — la app es puramente la "banca".

## Por qué existe

El usuario (Brian) juega Monopoly Ultimate Banking con su grupo y el dispositivo bancario físico limita mucho la partida. La solución es tener cada jugador con su propio "banco" en el teléfono, sincronizados entre sí, sin depender del hardware original.

## Roles en este proyecto

- **Brian**: dueño del proyecto, jugador, quien toma las decisiones de producto y prioriza qué se construye.
- **Claude (yo)**: prompt engineer y mano derecha de Brian. Mi trabajo es transformar las decisiones de Brian en prompts claros y acotados para Codex, y revisar el código que Codex entrega antes de que se considere terminado. No escribo yo directamente la implementación salvo que Brian lo pida explícitamente.
- **Codex**: agente de código que implementa la app en Swift/SwiftUI a partir de los prompts que yo preparo.

## Estado actual del repositorio

- Repo git inicializado, rama `main`.
- Capa de dominio (`Monopoly/Domain`): modelo de propiedades con acciones de 10%, reglas de compra/renta/construcción/hipoteca/impuestos/bancarrota, tarjetas de crédito y el Mercado (tratos multi-jugador, ofertas abiertas, compras compartidas).
- Capa de red (`Monopoly/Networking`): host-autoritativo sobre MultipeerConnectivity, con `GameIntent`/`NetworkMessage`, sala de espera (`Lobby`), descubrimiento de salas cercanas como tarjetas (`DiscoveredRoom`) y reconexión de clientes.
- Persistencia (`Monopoly/Persistence`): `GameStore` guarda cada partida que aloja el host en Application Support tras cada cambio de estado; `JoinedGamesStore` recuerda las partidas a las que se unió un cliente; `AppSettings` guarda el nombre del jugador y otras preferencias. Inicio las muestra en "Partidas recientes".
- Navegación: `AppModel` es dueño de la partida activa y `ContentView` la muestra en lugar de Inicio (`ActiveGameView`); solo se sale con "Salir", y al reabrir la app vuelve a ella.
- UI (`Monopoly/UI`): pantallas de inicio, ajustes, host (`HostGameView`)/join, lobby, tablero, detalle de propiedad, Mercado (`MarketView`, `DealBuilderView`, `SharedPurchaseView`), tarjeta de crédito, pagos por proximidad, pagos por QR (`QRPaymentViews`, formato en `Networking/Messages/QRPaymentRequest.swift`).
- Modo **Monopolife** (`MONOPOLIFE_RULES.md`, prompts 014–017, implementado directamente por Claude a pedido de Brian): `GameMode` en sala y estado, roles secretos con ruleta (`RoleRevealView`), felicidad y su historial (`GameRules+Monopolife.swift`), Tarjetas de Vida (`Domain/Data/LifeCards.swift`), valores de roles en `Domain/Data/LifeRoles.swift` y pantalla final (`FinalRankingView`).
- **Niveles secretos** (house rule opcional, solo Classic, `GAME_RULES.md` 8.3): `HouseRule.hiddenPropertyLevels`; la UI oculta nivel y renta de propiedades donde el jugador local no tiene acciones (`GameSessionModel.canSeeLevel(of:)`).
- **Casillas de viaje** (tarifa por lados del tablero, `TravelRoute`) y **bote de Free Parking** opcional (`GameRules+FreeParking.swift`, `GAME_RULES.md` 8.2): impuestos, viajes e intereses van al bote.
- Tablero (`GameBoardView`) oscuro con acento dorado: saldo compacto y grid de acciones; colores en `UI/BankPalette.swift`.
- Tipografía: Inter (OFL) en `Monopoly/Fonts`, subset latino (~400 KB), registrada en `Monopoly-Info.plist` y aplicada con `Font.app(...)` (`UI/AppFont.swift`); no usar `.font(.headline)` y similares del sistema.
- Fotos de propiedades: postales antiguas de Atlantic City (Wikimedia Commons, dominio público / CC BY 2.0) en `Assets.xcassets/Properties` a 750×500 (~80 KB c/u); créditos en `UI/PropertyPhotos.swift`, visibles en el detalle y en "Cómo se juega".
- Eventos del tablero opcionales (`GAME_RULES.md` 8.3): catálogo en `Domain/Data/BoardEventCatalog.swift`, reglas en `GameRules+BoardEvents.swift` (sorteo con semilla guardada en el estado), vistas en `BoardEventViews.swift`.
- Tests unitarios (XCTest) en `MonopolyTests/` (`GameRulesTests`, `MonopolifeRulesTests`, `QRPaymentTests`, `FreeParkingTests`, `CreditTrustTests`, `BoardEventsTests`) cubriendo la capa de dominio.

## Documentos de referencia

- [`GAME_RULES.md`](./GAME_RULES.md): reglas del Monopoly Ultimate Banking que la app debe implementar (qué hace la banca digital).
- [`MONOPOLIFE_RULES.md`](./MONOPOLIFE_RULES.md): reglas del modo Monopolife (felicidad, roles secretos, ruleta, Tarjetas de Vida).
- [`PROJECT_RULES.md`](./PROJECT_RULES.md): cómo se construye el proyecto (arquitectura, stack, convenciones, flujo Brian/Claude/Codex).

Cualquier prompt que se le dé a Codex debe asumir que quien lo lee no tiene memoria de conversaciones anteriores: debe poder entender la tarea leyendo estos tres documentos más el prompt específico.

## Decisiones ya tomadas (no reabrir sin que Brian lo pida)

- Multi-dispositivo, no "pasa y juega" en un solo teléfono.
- La app es solo banca digital, no digitaliza tablero/dados/fichas/cartas.
- iOS nativo con SwiftUI, sobre el proyecto Xcode ya existente.
- Conectividad por red local (MultipeerConnectivity), sin backend en la nube.
- Un dispositivo host actúa como banca/fuente de verdad; los demás son clientes.
- Pagos "acercando iPhones" como opción desactivada por defecto, implementados con NearbyInteraction (UWB) porque iOS no permite NFC entre iPhones (ver `PROJECT_RULES.md` sección 3).
- Dos modos de juego elegidos por el host en la sala: **Monopoly Classic** (por defecto) y **Monopolife**. En Monopolife gana quien tiene más felicidad tras un número de rondas elegido por el host; los roles son secretos y se revelan al final; la bancarrota no elimina (castigo de felicidad + saldo de rescate); las Tarjetas de Vida reemplazan a Suerte/Caja de Comunidad.
- Se soportan reglas oficiales de Ultimate Banking por defecto, más un set de house rules opcionales configurables por partida (ver sección 8 de `GAME_RULES.md`).

## Pendientes conocidos

- Validar contra la caja/manual físico de Brian los valores exactos de: precios de propiedades, tabla de incremento de renta por uso, costos de construcción, monto del evento "Bono en Casa".
- Definir el límite exacto de jugadores soportado por la edición física que tiene Brian (2–8 es un rango provisional).
- Ajustar los valores de felicidad de roles y Tarjetas de Vida de Monopolife tras las primeras partidas (todos son placeholder).
- No hay todavía backlog de features / roadmap detallado — se irá construyendo por iteraciones a medida que Brian priorice.
