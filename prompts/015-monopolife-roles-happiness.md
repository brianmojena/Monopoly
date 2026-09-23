# 015 — Gustos y disgustos de los roles, fin de ronda y bancarrota en Monopolife

## Contexto

Lee `CONTEXT.md`, `PROJECT_RULES.md`, `GAME_RULES.md` y **`MONOPOLIFE_RULES.md`**, en particular las secciones **2, 3.2, 3.3 y 6**. Este prompt se construye sobre 014 (ya existen `GameMode`, `LifeRole`, `LifeProfile`, `MonopolifeState`, `adjustHappiness` y el punto de extensión de fin de ronda en `advanceTurn`).

Revisa antes de tocar nada: `GameRules+Monopolife.swift`, `GameRules.swift` (`buyProperty`, `resolveAuction`, `collectRent`, `payTax`, `collectSalary`, `borrowOnCreditCard`, `levelUp`, `mortgageProperty`, `declareBankruptcy`, `advanceTurn`), `GameRules+Market.swift` (ejecución de tratos, compras compartidas, creación de inversiones) y los tests de 014.

## Qué construir

### 1. Roles como datos declarativos
- Un único archivo (ej. `Monopoly/Domain/Data/LifeRoles.swift`) con la definición de cada rol: nombre para mostrar, emoji, descripción, textos de gustos/disgusto y **todos los números** de la tabla 3.3 (puntos, umbrales, topes). Ningún número de felicidad puede aparecer fuera de ese archivo.
- La UI (016) tomará los textos de aquí, así que deben estar en español y listos para mostrar.

### 2. Eventos que disparan felicidad
- Define un enum de eventos de dominio (ej. `LifeTrigger`) que los rules emiten cuando `mode == .monopolife`, y una función que, dado el evento, aplica a cada jugador afectado el delta de su rol vía `adjustHappiness` con un `HappinessReason` específico (amplía el enum de 014: un caso por gusto/disgusto, para que la pantalla final pueda desglosar).
- Engancha los eventos en las funciones existentes, **después** de que el cambio de dinero/acciones sea exitoso, y solo en Monopolife:
  - `collectRent` (monto > 0): renta pagada por el pagador (monto y grupo de color) → Consumista y Trotamundos; renta recibida por cada accionista que cobró > 0 → Emprendedor; corte de inversión cobrado por cada inversor → Inversionista.
  - `buyProperty`, `resolveAuction` (ganador), compra compartida ejecutada (cada comprador) → Trotamundos.
  - `levelUp` (administrador) → Consumista. `mortgageProperty` (administrador) → Emprendedor.
  - `payTax` → Inversionista. `borrowOnCreditCard` → Ahorrador.
  - `collectSalary` → Trotamundos; Ahorrador si **antes** del cobro no tenía deuda de tarjeta.
  - Trato del Mercado ejecutado (incluye compra compartida, inversión y oferta abierta): cada participante → Social, si el trato mueve al menos $50 o al menos una acción (umbral en datos). Creación de inversión → Inversionista (el inversor).
- Estado por jugador que necesitan los roles (agrégalo a `LifeProfile` con decodificación tolerante): sellos de grupos de color del Trotamundos (`Set<ColorGroup>`), tratos puntuables en la ronda actual y si participó en algún trato en la ronda (Social). Se reinician al terminar la ronda.

### 3. Fin de ronda
- En el punto de extensión de 014, para cada jugador en Monopolife aplica los efectos "al terminar la ronda" de su rol: Consumista (efectivo > umbral), Emprendedor (propiedades con acciones), Ahorrador (efectivo), Social (sin tratos), Inversionista (grupos de color). Luego reinicia los contadores por ronda.
- Debe ejecutarse también al terminar la última ronda, antes de marcar `isFinished`.

### 4. Bancarrota en Monopolife (sección 6)
- `declareBankruptcy` en Monopolife: resuelve propiedades, dinero, tratos, inversiones y deuda exactamente igual que hoy, pero **no** pone `status = .bankrupt`: el jugador sigue activo, recibe $500 de rescate (en datos), conserva la mitad de su felicidad redondeada hacia abajo (registrada en el historial con un `HappinessReason` de bancarrota) y conserva rol y sellos.
- El turno no se salta: si era su turno, sigue siéndolo.
- En Classic no cambia nada.

## Fuera de alcance
- UI (016). Tarjetas de Vida (017).
- No cambies ninguna regla de dinero ni de Classic; los enganches solo agregan felicidad.

## Criterios de aceptación
1. Compila; todos los tests existentes pasan sin modificarlos.
2. En `MonopolifeRulesTests.swift`, al menos un test por gusto y por disgusto de cada rol de la tabla 3.3, incluyendo topes (ej. Consumista paga $400 de renta → +6, no +8; Social con 3 tratos en una ronda → solo 2 cuentan; trato de $10 sin acciones no cuenta).
3. Tests de que el mismo evento **no** da felicidad a un jugador con otro rol, y de que en Classic ningún evento cambia la felicidad ni el historial.
4. Trotamundos: pagar renta dos veces en el mismo color da +3 una sola vez; completar los 8 colores da el bonus.
5. Fin de ronda: se aplica una vez por ronda a todos, también en la última ronda antes de `isFinished`, y los contadores por ronda se reinician.
6. Bancarrota Monopolife: el jugador queda activo, con $500, con la mitad de la felicidad, sin propiedades (según acreedor), sin tratos/inversiones/deuda; si era su turno sigue siéndolo.
7. `grep` de números de felicidad fuera del archivo de datos de roles no encuentra ninguno en las reglas.
