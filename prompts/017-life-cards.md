# 017 — Tarjetas de Vida (solo Monopolife)

## Contexto

Lee `CONTEXT.md`, `PROJECT_RULES.md` (sección 1: la excepción de Monopolife sobre cartas) y **`MONOPOLIFE_RULES.md` secciones 3.2 y 5 completas**, incluida la tabla del mazo (5.1) y las posesiones (5.2). Se construye sobre 014–016: ya existen `MonopolifeState`, `LifeProfile`, `adjustHappiness`, los roles (`LifeRole` y su archivo de datos), los toasts de felicidad, la pantalla final y el estilo visual.

Punto clave de diseño: **cada tarjeta define la felicidad por separado para cada uno de los 6 roles** (una columna por rol en la tabla 5.1). No hay multiplicadores ni "afinidades": el valor que recibe un jugador es exactamente el de la columna de su rol, positivo, negativo o 0.

Revisa antes: `GameRules+Monopolife.swift`, el archivo de datos de roles, `GameRules.swift` (`requireTurn`, `endTurn`, `credit`), `GameIntent.swift`, `GameSession.swift`, `GameBoardView.swift` y la pantalla final de 016.

## Qué construir

### 1. Datos
- Archivo `Monopoly/Domain/Data/LifeCards.swift` con las 30 tarjetas de la tabla 5.1 como datos declarativos: id estable, título, texto, tipo (`event`, `decision`, `possession`, `movement`), efecto de dinero y **felicidad por rol** (ej. `[LifeRole: Int]`, con los 6 roles siempre presentes). Ningún monto ni punto de tarjeta fuera de este archivo.
- `enum LifePossession: String, Codable, CaseIterable { case car, television, foodTruck }` con emoji y nombre para mostrar.
- Modela el efecto para cubrir todos los casos de la tabla sin código especial por tarjeta: cobrar/pagar monto fijo; cobrar por cada propiedad con acciones con tope (Dividendos); cada otro jugador activo te paga (Cumpleaños); felicidad fija a cada otro jugador activo (Fiesta, +1 igual para todos, independiente del rol); decisión con costo y posesión opcional que se obtiene; tarjeta de posesión que requiere tener X y puede cobrar dinero y/o quitar la posesión; instrucción de movimiento (texto).

### 2. Estado y reglas
- En `LifeProfile`: `possessions: Set<LifePossession>`. En `MonopolifeState`: `lifeDeck: [LifeCardID]` (orden restante), `pendingLifeCard: PendingLifeCard?` (jugador + tarjeta, para decisiones) y la última tarjeta robada por jugador para mostrarla. Todo con decodificación tolerante.
- `makeGameState` en Monopolife baraja el mazo con un generador inyectable (tests deterministas).
- `drawLifeCard(in:playerID:using:)`: solo Monopolife, solo en su turno, falla si hay una decisión pendiente. Roba la primera del mazo; si está vacío, rebaraja las 30 antes.
  - **Evento / Movimiento**: aplica dinero y la felicidad de la columna del rol del jugador de inmediato.
  - **Posesión**: si el jugador tiene la posesión, aplica dinero, felicidad de su rol y, si la tarjeta lo indica, quita la posesión. Si no la tiene, no aplica nada (la tarjeta igual se consume y se muestra).
  - **Decisión**: queda en `pendingLifeCard`.
- `resolveLifeCardDecision(in:playerID:accept:)`: aceptar exige efectivo suficiente (si no, error); pasar nunca cambia nada. Aceptar cobra el costo, aplica la felicidad del rol (aunque sea negativa: el jugador la vio antes de aceptar) y agrega la posesión si la tarjeta da una (si ya la tenía, sigue teniendo una sola).
- Pagos: si una tarjeta de evento o posesión obliga a pagar más de lo que el jugador tiene, paga lo que tenga (nunca provoca bancarrota). En Cumpleaños, cada jugador paga lo que pueda hasta $20.
- `endTurn` en Monopolife falla con un error nuevo si el jugador tiene una decisión pendiente.
- Los cambios de felicidad usan `adjustHappiness` con un `HappinessReason` de tarjeta que incluye el id de la tarjeta, para el desglose final.
- En Classic, ambos intents se rechazan.

### 3. Red
- Intents `drawLifeCard(playerID:)` y `resolveLifeCardDecision(playerID:accept:)`, despachados en `GameSession`. El sorteo lo hace siempre el host.

### 4. UI
- En `GameBoardView` (solo Monopolife, en el turno del jugador): botón "Caí en Suerte / Caja de Comunidad" → envía `drawLifeCard`.
- Al robar, una carta animada (se voltea) con título, texto, efecto de dinero y **solo la felicidad para el rol del jugador**, con color verde/rojo/gris según sea positiva, negativa o 0 (nunca mostrar la tabla de los otros roles: delataría el rol).
  - Decisión: botones "Aceptar ($X, +N 😊)" / "Aceptar ($X, −N 😞)" y "Pasar". "Aceptar" deshabilitado si no le alcanza.
  - Posesión sin tenerla: "No tienes carro: te salvaste 😅".
  - Movimiento: instrucción destacada ("Mueve tu ficha a Salida").
- Los demás jugadores ven un aviso breve "{nombre} sacó una Tarjeta de Vida: {título}" (la tarjeta es pública; su efecto en felicidad no).
- "Mis posesiones" (🚗 📺 🚚) visibles solo para el jugador local junto a su felicidad. En la pantalla final de 016, mostrar las posesiones de cada jugador.
- Estilo coherente con 016.

## Fuera de alcance
- No cambies la tabla de roles ni la lógica de 015. No digitalices ninguna otra casilla del tablero. Las posesiones no se negocian en el Mercado ni cuentan para patrimonio.

## Criterios de aceptación
1. Compila; todos los tests pasan.
2. Tests nuevos:
   - El mazo tiene 30 tarjetas y cada una define felicidad para los 6 roles.
   - **Test de equilibrio**: para cada rol, la suma de su columna en todo el mazo (en decisiones solo cuenta si es positiva) queda dentro de ±2 de la de los demás roles (`MONOPOLIFE_RULES.md` 3.2). Este test debe fallar si alguien desequilibra el mazo.
   - Con generador sembrado el barajado es determinista; robar 30 veces entrega cada tarjeta una vez y la 31ª rebaraja.
   - La misma tarjeta da felicidad distinta según el rol (ej. "Cómprate un carro" aceptada: Consumista +7, Ahorrador −2; "Pelea con un amigo": Social −5, Consumista −1).
   - Cada tipo de efecto: evento con dinero y felicidad, Dividendos con tope, Cumpleaños con un jugador sin dinero suficiente, Fiesta da +1 a cada otro jugador activo, Movimiento aplica felicidad.
   - Posesiones: aceptar el carro lo agrega; "Se te rompe el carro" con carro cobra $150 y aplica felicidad, sin carro no cambia nada; "Te roban el televisor" quita la posesión; comprar dos veces deja una sola.
   - Decisión: queda pendiente; no se puede robar otra ni terminar turno; aceptar sin fondos falla; pasar no cambia nada; aceptar cobra y aplica felicidad (también negativa).
   - Pagar más de lo que se tiene deja el saldo en 0, no negativo.
   - Robar fuera de turno falla; en Classic ambos intents se rechazan.
3. Manual: como Consumista, sacar "Cómprate un carro" muestra "+7 😊", al aceptar aparece 🚗 en Mis posesiones; más tarde "Se te rompe el carro" cobra $150 y resta felicidad. Los demás solo ven el aviso con el título.
