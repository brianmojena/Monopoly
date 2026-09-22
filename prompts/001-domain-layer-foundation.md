# Prompt 001 — Fundación de la capa de dominio (con datos placeholder)

## Contexto

Estás trabajando en el repo de una app iOS (Swift + SwiftUI) que actúa como "banca digital" para Monopoly Ultimate Banking. El tablero, dados, fichas y cartas son físicos — esta app **solo** gestiona dinero, propiedades, hipotecas, construcciones y patrimonio de cada jugador.

Antes de leer nada más, lee estos tres documentos completos en la raíz del repo, son la fuente de verdad normativa de este proyecto:
- `GAME_RULES.md` (reglas del juego que hay que implementar)
- `PROJECT_RULES.md` (arquitectura y convenciones)
- `CONTEXT.md` (contexto general)

Todavía **no tenemos los valores reales** de precios/rentas/costos de construcción de la edición física (está marcado como pendiente en `GAME_RULES.md`, sección 9). Por eso esta tarea usa un set de datos **placeholder**, pequeño y claramente marcado como tal, solo para poder construir y probar la lógica. No hay que optimizar ni afinar esos números — se reemplazarán después por los reales.

## Alcance de esta tarea

Construir **únicamente la capa de dominio** (lógica de negocio pura, sin SwiftUI, sin red, sin persistencia en disco). Nada de UI todavía. Nada de MultipeerConnectivity todavía. Esto es intencional: primero la lógica de reglas correcta y testeada, luego se conecta a vistas y red en prompts posteriores.

### 1. Estructura de carpetas

Dentro del target `Monopoly`, crea un grupo/carpeta `Domain/` con esta organización (o similar, usa tu criterio de nombres de archivo siempre que la separación de responsabilidades se mantenga):

```
Domain/
  Models/       -> tipos de datos (Player, Property, ColorGroup, GameState, etc.)
  Rules/        -> lógica de negocio (compra, renta, hipoteca, construcción, bancarrota)
  Data/         -> el set de datos placeholder de propiedades del tablero
```

Ningún archivo dentro de `Domain/` debe importar `SwiftUI`.

### 2. Modelos (`Domain/Models/`)

Como mínimo, modela (usando `struct` + `Codable` salvo que haya una razón real para `class`):

- `Player`: id, nombre, saldo actual, lista de propiedades que posee, estado (activo/en bancarrota).
- `ColorGroup`: enum o struct que represente los grupos de color del tablero (ej. `.brown`, `.lightBlue`, ... incluye también los grupos especiales de Ultimate Banking si tu lectura de `GAME_RULES.md` los requiere, si no, usa los grupos clásicos como placeholder).
- `Property`: id, nombre, `ColorGroup`, precio base de compra, valor de hipoteca, renta base, nivel de construcción actual (0 = sin casas, 1-4 = casas, 5 = hotel), dueño (opcional), estado hipotecada (bool).
- `GameState`: lista de jugadores, lista de propiedades (el tablero completo), turno actual (solo como dato, no gestiona movimiento físico), reglas opcionales activas (usa un `Set<HouseRule>` o similar, mapeando la sección 8 de `GAME_RULES.md`).

### 3. Datos placeholder (`Domain/Data/`)

Crea un archivo con un set de **12-16 propiedades placeholder** que cubran al menos 4 grupos de color distintos, con valores de precio/renta/hipoteca claramente ficticios pero razonables en escala (ej. precios entre 60 y 400, como en el Monopoly clásico, para que las pruebas sean legibles). Marca en un comentario en la parte superior del archivo que estos son datos de prueba y deben reemplazarse cuando se validen los valores reales de la caja física.

### 4. Reglas de negocio (`Domain/Rules/`)

Implementa como funciones/métodos puros (dado un `GameState` + una acción, devuelven un nuevo `GameState` o un `Result`/error), cubriendo **exactamente** lo siguiente de `GAME_RULES.md` (no más, no menos — el resto de reglas del documento se implementan en prompts futuros):

- **Sección 4.1 Compra**: comprar una propiedad sin dueño, descontando el precio del saldo del comprador y asignándole la propiedad. Debe fallar (error tipado, no crash) si el jugador no tiene saldo suficiente o si la propiedad ya tiene dueño.
- **Sección 4.2 Renta**: cobrar renta de una propiedad con dueño a un jugador que cae en ella. Debe fallar si el jugador que paga no tiene saldo suficiente (por ahora, sin lógica de liquidar activos — eso es bancarrota, prompt futuro). Debe respetar que una propiedad hipotecada no genera renta.
- **Sección 4.4 Hipoteca**: hipotecar una propiedad propia sin casas (recibe el valor de hipoteca) y des-hipotecarla (paga valor de hipoteca + 10% de interés). Debe fallar si tiene casas construidas, si no es del jugador, o si el saldo no alcanza para des-hipotecar.

No implementes todavía: construcción de casas/hoteles, subastas, intercambios, bancarrota, impuestos, ni el incremento dinámico de valor de propiedad por uso (sección 4.2 de `GAME_RULES.md` menciona que la renta sube con cada pago — eso lo dejamos para un prompt posterior explícito; por ahora la renta cobrada es siempre el valor base fijo). Si tienes duda de si algo está en el alcance de este prompt, no lo implementes y dilo en tu resumen final.

### 5. Tests (XCTest)

Añade un test target (o usa el que ya exista) y cubre con tests unitarios, como mínimo:
- Compra exitosa de una propiedad sin dueño.
- Compra fallida por saldo insuficiente.
- Compra fallida por propiedad ya con dueño.
- Cobro de renta exitoso.
- Cobro de renta fallido por saldo insuficiente.
- Cobro de renta que no aplica porque la propiedad está hipotecada.
- Hipoteca exitosa de una propiedad.
- Fallo al hipotecar una propiedad con casas.
- Des-hipoteca exitosa con cálculo correcto del interés del 10%.
- Fallo al des-hipotecar por saldo insuficiente.

## Criterios de aceptación

1. El proyecto compila sin warnings nuevos.
2. Todos los tests unitarios listados arriba existen y pasan.
3. Ningún archivo en `Domain/` importa `SwiftUI`.
4. Los datos de propiedades están claramente marcados como placeholder (comentario visible).
5. No se toca `ContentView.swift` ni `MonopolyApp.swift` en este prompt — esta tarea es solo capa de dominio.
6. No se añade ninguna dependencia externa (SPM/CocoaPods) sin justificarlo explícitamente en el resumen final.

## Al terminar

Entrega un resumen breve que indique: qué archivos creaste, qué decisiones de diseño tomaste que no estaban explícitas en el prompt (ej. cómo modelaste el error de saldo insuficiente), y cualquier ambigüedad de `GAME_RULES.md` que hayas encontrado y resuelto por tu cuenta — para que se pueda revisar contra las reglas antes de seguir.
