# Prompt 002 — Construcción de casas/hoteles y doble renta por monopolio

## Contexto

Continuamos sobre la capa de dominio ya existente (`Monopoly/Domain/`), construida en el prompt 001 (`prompts/001-domain-layer-foundation.md`). Esa base ya implementa: compra de propiedades, cobro de renta fija, hipoteca y des-hipoteca — con tests pasando. **No rompas ese comportamiento existente**; esta tarea añade sobre lo ya construido, no lo reemplaza.

Antes de nada, lee (o relee) completos:
- `GAME_RULES.md` — en particular secciones 4.2 (renta) y 4.3 (construcción)
- `PROJECT_RULES.md`
- El código ya existente en `Monopoly/Domain/` y sus tests en `MonopolyTests/GameRulesTests.swift`, para entender los patrones ya establecidos (errores tipados con `GameRuleError`, funciones puras que devuelven nuevo `GameState`, etc.) y **seguir el mismo estilo**.

Seguimos usando los datos placeholder de `PlaceholderProperties.swift`. Si construir casas/hoteles requiere datos que ese archivo no tiene todavía (ej. costo de construcción por propiedad), añádelos ahí siguiendo el mismo formato y el mismo comentario de "placeholder, pendiente de validar".

## Alcance de esta tarea

Sigue siendo **solo capa de dominio**: nada de SwiftUI, nada de red, nada de persistencia en disco.

### 1. Doble renta por monopolio de color completo (`GAME_RULES.md` 4.2)

Modifica (o extiende) la función de cobro de renta para que:
- Si el jugador dueño de la propiedad posee **todas** las propiedades del mismo `ColorGroup`, y esa propiedad tiene **0 casas construidas**, la renta a cobrar es el **doble** de la renta base.
- Si la propiedad ya tiene casas/hotel (nivel de construcción > 0), se usa la renta correspondiente a ese nivel (ver punto 2) y el doble por monopolio ya no aplica (la regla clásica es que el doble solo aplica mientras el grupo está "sin construir").
- Si el jugador NO posee el grupo completo, la renta es la base normal (comportamiento ya existente, no cambia).

### 2. Construcción de casas y hoteles (`GAME_RULES.md` 4.3)

Añade a los datos de propiedades placeholder (`PlaceholderProperties.swift`) un **costo de construcción** por propiedad (o por grupo de color, tu elección, pero documenta cuál usaste) y una **tabla de renta por nivel de construcción** (0 casas, 1, 2, 3, 4 casas, hotel) — placeholder también, claramente marcado.

Implementa una función `buildHouse` (o nombre equivalente, sigue la convención de nombres ya usada en `GameRules.swift`) que:
- Solo permite construir si el jugador posee **todas** las propiedades del `ColorGroup` correspondiente (monopolio completo).
- Descuenta el costo de construcción del saldo del jugador.
- Incrementa el nivel de construcción de la propiedad en 1 (máximo nivel 4 = 4 casas).
- Aplica la **regla de construcción uniforme** (sección 4.3 de `GAME_RULES.md`): no se puede construir una casa en una propiedad si alguna otra propiedad del mismo grupo de color tiene **2 o más casas menos** que ella tras la construcción — en otras palabras, la diferencia de nivel de construcción entre propiedades del mismo grupo nunca puede ser mayor a 1.
- Falla (error tipado) si: el jugador no tiene el monopolio completo, no tiene saldo suficiente, la propiedad ya tiene el máximo de casas antes de hotel, la propiedad está hipotecada, o si viola la regla de construcción uniforme.

Añade también una función `buildHotel` (o gestiona el hotel como nivel 5 dentro de la misma función, tu criterio, pero debe quedar claro en el código) que:
- Solo permite construirlo si la propiedad ya tiene 4 casas.
- Sigue la misma regla de construcción uniforme (todas las propiedades del grupo deben tener 4 casas antes de que cualquiera pueda pasar a hotel, si interpretas la regla estrictamente; documenta tu interpretación en el resumen final si tienes dudas).
- Descuenta el costo correspondiente del saldo del jugador.

No implementes en este prompt: venta de construcciones de vuelta a la banca, ni el incremento dinámico del valor de propiedad por uso (siguen fuera de alcance, para un prompt futuro).

### 3. Tests (XCTest)

Añade tests unitarios, como mínimo:
- Renta se duplica correctamente cuando el dueño tiene el grupo de color completo y la propiedad no tiene casas.
- Renta NO se duplica si el dueño no tiene el grupo completo.
- Renta usa la tabla por nivel de construcción cuando la propiedad tiene casas/hotel (no el doble por monopolio).
- Construcción exitosa de una casa cuando el jugador tiene el monopolio completo.
- Construcción fallida cuando el jugador NO tiene el monopolio completo.
- Construcción fallida por saldo insuficiente.
- Construcción fallida por violar la regla de construcción uniforme (ej. intentar poner 2 casas en una propiedad cuando otra del mismo grupo tiene 0).
- Construcción de hotel exitosa cuando la propiedad ya tiene 4 casas.
- Construcción fallida en una propiedad hipotecada.

## Criterios de aceptación

1. El proyecto compila sin warnings nuevos, usando el scheme `Monopoly` (`xcodebuild -project Monopoly.xcodeproj -scheme Monopoly -destination 'platform=iOS Simulator,name=iPhone 16' build test` debe funcionar directamente, sin necesitar un scheme separado).
2. Todos los tests del prompt 001 siguen pasando (no se rompió nada existente) y todos los tests nuevos de este prompt pasan.
3. Ningún archivo en `Domain/` importa `SwiftUI`.
4. Los datos nuevos de construcción en `PlaceholderProperties.swift` están marcados como placeholder.
5. No se toca `ContentView.swift` ni `MonopolyApp.swift`.
6. No se añade ninguna dependencia externa sin justificarlo en el resumen final.

## Al terminar

Entrega (por escrito, en el propio repo o en tu respuesta, pero cópialo íntegro para dejar registro) un resumen que indique: qué archivos creaste o modificaste, cómo interpretaste la regla de construcción uniforme (en particular para el paso de 4 casas a hotel), qué estructura de datos elegiste para el costo de construcción (por propiedad vs. por grupo de color) y por qué, y cualquier ambigüedad de `GAME_RULES.md` que hayas resuelto por tu cuenta.
