# 011 — Completar las 22 propiedades del tablero

## Contexto

Lee `CONTEXT.md`, `GAME_RULES.md` (sección 4, especialmente 4.2 y 9) y `PROJECT_RULES.md` (sección 4) antes de empezar.

`Monopoly/Domain/Data/PlaceholderProperties.swift` define la tabla declarativa de propiedades del tablero (`Property.swift` + `ColorGroup.swift`). Hoy solo tiene **14 de las 22 propiedades** del tablero: cubre `brown`, `lightBlue`, `pink`, `orange` y `red`, pero le faltan los grupos `yellow`, `green` y `darkBlue`.

Investigación ya hecha: Monopoly Ultimate Banking usa el mismo tablero y los mismos 22 nombres de propiedad que el Monopoly clásico de EE. UU. (confirmado por Hasbro/Monopoly Wiki/UltraBoardGames — la edición cambia la banca a un dispositivo electrónico con valores dinámicos, pero no cambia nombres, orden ni grupos de color del tablero). Los precios y rentas exactos de Ultimate Banking siguen sin validar contra la caja física de Brian (ver `GAME_RULES.md` sección 9), así que se mantienen como **placeholder** igual que las 14 ya existentes.

## Objetivo

Agregar las 8 propiedades faltantes a `PlaceholderProperties.all`, completando las 22 del tablero, siguiendo el mismo patrón de datos placeholder ya usado (precios/rentas del Monopoly clásico como base, igual que se hizo para las primeras 14).

## Propiedades a agregar (en este orden, tablero clásico de EE. UU.)

| Nombre | `colorGroup` | `purchasePrice` | `mortgageValue` | `baseRent` | `constructionCost` | `rentByConstructionLevel` |
|---|---|---|---|---|---|---|
| Atlantic Avenue | `.yellow` | 260 | 130 | 22 | 150 | [22, 110, 330, 800, 975, 1150] |
| Ventnor Avenue | `.yellow` | 260 | 130 | 22 | 150 | [22, 110, 330, 800, 975, 1150] |
| Marvin Gardens | `.yellow` | 280 | 140 | 24 | 150 | [24, 120, 360, 850, 1025, 1200] |
| Pacific Avenue | `.green` | 300 | 150 | 26 | 200 | [26, 130, 390, 900, 1100, 1275] |
| North Carolina Avenue | `.green` | 300 | 150 | 26 | 200 | [26, 130, 390, 900, 1100, 1275] |
| Pennsylvania Avenue | `.green` | 320 | 160 | 28 | 200 | [28, 150, 450, 1000, 1200, 1400] |
| Park Place | `.darkBlue` | 350 | 175 | 35 | 200 | [35, 175, 500, 1100, 1300, 1500] |
| Boardwalk | `.darkBlue` | 400 | 200 | 50 | 200 | [50, 200, 600, 1400, 1700, 2000] |

Estos valores son los del Monopoly clásico de EE. UU. y se usan como placeholder, igual que las 14 propiedades ya presentes en el archivo — no son los valores oficiales de Ultimate Banking hasta que se validen contra la caja física.

## Alcance

- Modificar únicamente `Monopoly/Domain/Data/PlaceholderProperties.swift`, agregando las 8 propiedades nuevas al arreglo `all`, manteniendo el orden del tablero (después de "Illinois Avenue").
- No tocar `Property.swift`, `ColorGroup.swift` ni ninguna lógica de `GameRules`.
- No agregar casillas que no sean propiedades (ferrocarriles, servicios públicos, Salida, Cárcel, impuestos, etc.) — quedan fuera de este prompt.
- Usar exactamente el mismo estilo de inicialización que las propiedades existentes en el archivo (mismo orden de parámetros, mismo formato de línea).

## Criterios de aceptación

1. Compila sin errores.
2. `PlaceholderProperties.all` tiene exactamente 22 elementos.
3. Los 8 grupos de `ColorGroup` (`brown`, `lightBlue`, `pink`, `orange`, `red`, `yellow`, `green`, `darkBlue`) están representados con la cantidad correcta de propiedades cada uno (2, 3, 3, 3, 3, 3, 3, 2 respectivamente).
4. Los valores usados son los de la tabla de este prompt, sin inventar cifras distintas.
5. Si existen tests que iteran sobre `PlaceholderProperties.all` (ej. validando monopolios por grupo), siguen pasando; no es necesario agregar tests nuevos solo por este cambio de datos.
