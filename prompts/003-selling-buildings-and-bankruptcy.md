# Prompt 003 — Venta de construcciones y bancarrota

## Contexto

Continuamos sobre la capa de dominio ya existente (`Monopoly/Domain/`), construida en los prompts 001 y 002 (`prompts/001-domain-layer-foundation.md`, `prompts/002-buildings-and-monopoly-rent.md`). Esa base ya implementa: compra, renta (fija y doble por monopolio, y por nivel de construcción), hipoteca/des-hipoteca, y construcción de casas/hoteles con regla de construcción uniforme — todo con tests pasando (19/19 a la fecha de este prompt).

**No rompas nada de lo existente.** Esta tarea añade sobre lo ya construido.

Antes de nada, lee (o relee) completos:
- `GAME_RULES.md` — en particular secciones 4.5 (venta de construcciones) y 6 (bancarrota)
- `PROJECT_RULES.md`
- El código existente en `Monopoly/Domain/` y sus tests en `MonopolyTests/GameRulesTests.swift`, para seguir el mismo estilo ya establecido (errores tipados con `GameRuleError`, funciones puras que devuelven nuevo `GameState`, datos placeholder claramente marcados, regla de construcción uniforme ya implementada en el prompt 002).

## Alcance de esta tarea

Sigue siendo **solo capa de dominio**: nada de SwiftUI, nada de red, nada de persistencia en disco.

### 1. Venta de construcciones (`GAME_RULES.md` 4.5)

Implementa una función (sigue la convención de nombres ya usada, ej. `sellHouse` o equivalente) que:
- Permite a un jugador vender de vuelta a la banca una casa u hotel de una propiedad que posee.
- Acredita al jugador **la mitad** del costo de construcción de ese nivel (usa la misma tabla de costos de construcción del prompt 002; si vendes un hotel, decide y documenta si se acredita la mitad del costo del hotel o se revierte a 4 casas y se acredita la mitad de una casa — sigue la interpretación más simple y consistente con `GAME_RULES.md`, y explícala en tu resumen).
- Reduce el nivel de construcción de la propiedad en 1.
- Respeta la **regla de construcción uniforme** también al vender: no se puede vender una casa de una propiedad si eso deja su nivel más de 1 por debajo de otra propiedad del mismo grupo de color (la venta debe hacerse en el orden inverso a la construcción, igual que en el Monopoly clásico).
- Falla (error tipado) si: la propiedad no tiene construcciones que vender, la propiedad no es del jugador, o si viola la regla de construcción uniforme al vender.

No es necesario permitir hipotecar una propiedad con casas — esa regla ya existe (prompt 001: no se puede hipotecar con casas). Si el jugador quiere hipotecar una propiedad con casas, primero debe vender las construcciones con esta nueva función; no hace falta encadenar ambas operaciones automáticamente.

### 2. Bancarrota (`GAME_RULES.md` sección 6)

Implementa una función que determine y ejecute la bancarrota de un jugador:

- **Detección**: dado un `GameState`, un jugador y una deuda pendiente (monto + a quién se le debe: otro jugador o "la banca"), determina si el jugador puede cubrirla. Puede cubrirla si su saldo actual, sumado a lo que obtendría de hipotecar todas sus propiedades sin construcciones y vender todas sus construcciones al valor de reventa (mitad del costo), es suficiente. **No implementes en esta tarea la ejecución automática de esas ventas/hipotecas para intentar salvar al jugador** — eso requeriría decisiones de UI (qué vender primero) fuera del alcance de esta capa de dominio. Esta función solo debe determinar si, en el mejor de los casos, el jugador *podría* cubrir la deuda o no. Documenta esta limitación claramente en el código.
- **Ejecución de bancarrota**: una función separada que, dado un jugador ya determinado como insolvente, lo marca como en bancarrota (usa el campo de estado ya existente en `Player`, del prompt 001) y transfiere sus activos:
  - Si la deuda es con **otro jugador**: todas las propiedades del jugador en bancarrota (con su nivel de construcción intacto) y todo su saldo restante pasan al acreedor.
  - Si la deuda es con **la banca**: todas las propiedades del jugador en bancarrota vuelven a estar sin dueño (`ownerID = nil`), con su nivel de construcción reseteado a 0 (las casas/hoteles vuelven a la banca, sección 6 de `GAME_RULES.md`), y su saldo restante desaparece (no se transfiere a nadie).
  - En ambos casos, el jugador queda marcado como eliminado/en bancarrota y no debe poder realizar más acciones (compra, renta, construcción, etc.) — decide si esto se valida en cada función existente (ej. añadir un chequeo de "jugador activo" a las funciones de compra/renta/construcción ya existentes) o se documenta como responsabilidad de la capa que llame a estas funciones. Si lo dejas como responsabilidad de la capa superior, dilo explícitamente en tu resumen — no lo dejes ambiguo.

### 3. Tests (XCTest)

Añade tests unitarios, como mínimo:
- Venta exitosa de una casa, acreditando correctamente la mitad de su costo.
- Venta fallida por violar la regla de construcción uniforme (vender en orden incorrecto).
- Venta fallida cuando la propiedad no tiene construcciones.
- Venta fallida cuando la propiedad no es del jugador.
- Determinación de bancarrota: jugador que SÍ puede cubrir una deuda contando hipotecas/ventas potenciales.
- Determinación de bancarrota: jugador que NO puede cubrir una deuda ni liquidando todo.
- Ejecución de bancarrota hacia otro jugador: propiedades y saldo se transfieren correctamente al acreedor.
- Ejecución de bancarrota hacia la banca: propiedades quedan sin dueño y con nivel de construcción en 0, saldo desaparece.
- El jugador en bancarrota queda marcado con el estado correspondiente tras la ejecución.

## Criterios de aceptación

1. El proyecto compila sin warnings nuevos usando el scheme `Monopoly` (`xcodebuild -project Monopoly.xcodeproj -scheme Monopoly -destination 'platform=iOS Simulator,name=iPhone 16' build test`).
2. Todos los tests de los prompts 001 y 002 (19 tests) siguen pasando, y todos los tests nuevos de este prompt pasan.
3. Ningún archivo en `Domain/` importa `SwiftUI`.
4. No se toca `ContentView.swift` ni `MonopolyApp.swift`.
5. No se añade ninguna dependencia externa sin justificarlo en el resumen final.

## Al terminar

Entrega, íntegro y por escrito (en tu respuesta, para que quede registrado en esta conversación), un resumen que indique:
- Qué archivos creaste o modificaste.
- Cómo interpretaste la venta de un hotel (mitad del costo del hotel vs. revertir a 4 casas y vender una).
- Si decidiste validar "jugador activo/no en bancarrota" dentro de las funciones existentes o si lo dejaste como responsabilidad de la capa superior — sé explícito, esto afecta directamente al siguiente prompt.
- Cualquier ambigüedad de `GAME_RULES.md` sección 4.5 o 6 que hayas resuelto por tu cuenta.

No omitas este resumen — en los dos prompts anteriores no se entregó y tuvo que pedirse después.
