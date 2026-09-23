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
- Persistencia (`Monopoly/Persistence`): `GameStore` guarda la partida del host en Application Support tras cada cambio de estado; la app ofrece "Continuar partida" al reabrir.
- UI (`Monopoly/UI`): pantallas de inicio, host/join, lobby, tablero, detalle de propiedad, Mercado (`MarketView`, `DealBuilderView`, `SharedPurchaseView`), tarjeta de crédito y pagos por proximidad.
- Tests unitarios (XCTest) en `MonopolyTests/GameRulesTests.swift` cubriendo la capa de dominio.

## Documentos de referencia

- [`GAME_RULES.md`](./GAME_RULES.md): reglas del Monopoly Ultimate Banking que la app debe implementar (qué hace la banca digital).
- [`PROJECT_RULES.md`](./PROJECT_RULES.md): cómo se construye el proyecto (arquitectura, stack, convenciones, flujo Brian/Claude/Codex).

Cualquier prompt que se le dé a Codex debe asumir que quien lo lee no tiene memoria de conversaciones anteriores: debe poder entender la tarea leyendo estos tres documentos más el prompt específico.

## Decisiones ya tomadas (no reabrir sin que Brian lo pida)

- Multi-dispositivo, no "pasa y juega" en un solo teléfono.
- La app es solo banca digital, no digitaliza tablero/dados/fichas/cartas.
- iOS nativo con SwiftUI, sobre el proyecto Xcode ya existente.
- Conectividad por red local (MultipeerConnectivity), sin backend en la nube.
- Un dispositivo host actúa como banca/fuente de verdad; los demás son clientes.
- Pagos "acercando iPhones" como opción desactivada por defecto, implementados con NearbyInteraction (UWB) porque iOS no permite NFC entre iPhones (ver `PROJECT_RULES.md` sección 3).
- Se soportan reglas oficiales de Ultimate Banking por defecto, más un set de house rules opcionales configurables por partida (ver sección 8 de `GAME_RULES.md`).

## Pendientes conocidos

- Validar contra la caja/manual físico de Brian los valores exactos de: precios de propiedades, tabla de incremento de renta por uso, costos de construcción, monto del evento "Bono en Casa".
- Definir el límite exacto de jugadores soportado por la edición física que tiene Brian (2–8 es un rango provisional).
- No hay todavía backlog de features / roadmap detallado — se irá construyendo por iteraciones a medida que Brian priorice.
