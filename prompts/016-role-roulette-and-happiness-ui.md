# 016 — Ruleta de roles, felicidad en pantalla y pantalla final

## Contexto

Lee `CONTEXT.md`, `PROJECT_RULES.md` y **`MONOPOLIFE_RULES.md`**, en particular las secciones **2 (visibilidad), 4 y 7**. Se construye sobre 014 y 015: los roles, sus textos (archivo de datos de roles), la felicidad, el historial y `acknowledgeRole` ya existen. Este prompt es **solo UI**: no toques reglas de dominio salvo lo mínimo para exponer datos ya existentes.

Revisa antes: `GameBoardView.swift`, `GameSessionModel.swift` (cómo se sabe el jugador local y el "Jugando como" del host, `hostControlledPlayerIDs`), `StartView.swift` (estilo visual actual, colores y soporte claro/oscuro) y la alerta/pantalla provisional de rol y la pantalla final provisional de 014.

## Qué construir

### 1. Ruleta de roles (reemplaza la alerta provisional de 014)
- Vista a pantalla completa `RoleRouletteView`: una rueda con los 6 roles (emoji + nombre, un color distinto por rol) que gira ~4 segundos con desaceleración suave (ease-out) y se detiene exactamente en el segmento del rol del jugador. Agrega una flecha/indicador fijo arriba y un feedback háptico ligero al detenerse.
- Al detenerse, revela la **tarjeta de rol**: emoji grande, nombre, descripción, gustos y disgusto (textos del archivo de datos de roles). Botón "¡Entendido!" → intent `acknowledgeRole`.
- Aparece automáticamente al recibir un estado de Monopolife donde el jugador local tiene `hasAcknowledgedRole == false`. Como el host transmite el estado inicial a todos a la vez, todas las ruletas arrancan juntas: no hace falta sincronizar relojes.
- iPhone del host con jugadores sin teléfono: primero la ruleta del host; luego, por cada jugador controlado por el host sin confirmar, una pantalla "Pasa el teléfono a {nombre}" con botón "Soy {nombre}" y después su ruleta. Tras terminar, vuelve al "Jugando como" normal.
- Respeta "Reducir movimiento" de accesibilidad: en ese caso, sin giro, revela la tarjeta directamente.

### 2. Felicidad durante la partida
- En `GameBoardView` (solo Monopolife), una cabecera con: felicidad del jugador local (ícono + número, con animación al cambiar), "Ronda X de N" y un botón "Mi rol" que abre la tarjeta de rol (solo del jugador local / "Jugando como").
- Cuando cambia la felicidad del jugador local, un toast breve: "+2 😊 Cobraste renta" / "−3 😞 Hipotecaste", con el texto del motivo (`HappinessReason`) tomado de los datos.
- Pantalla "Mi felicidad": historial del jugador local (más reciente primero), agrupable por ronda.
- **Nunca** muestres el rol ni la felicidad de otros jugadores durante la partida (tampoco en listas de jugadores, Mercado, etc.).

### 3. Pantalla final (reemplaza la provisional de 014)
- Al quedar `isFinished`, todos los dispositivos muestran: podio del ganador o ganadores (`winners`), ranking completo con felicidad, rol revelado (emoji + nombre) de cada jugador, y al tocar un jugador su desglose por motivo (suma de deltas del historial agrupados por `HappinessReason`, con rol / tarjetas / bancarrota). Las posesiones de Tarjetas de Vida (🚗 📺 🚚) se agregan a esta pantalla en 017.
- Botón para volver al inicio.

### 4. Estilo
- Coherente con el rediseño de `StartView` (prompt 010): mismos colores, tipografía y soporte claro/oscuro. Debe verse bien en pantallas pequeñas (iPhone SE).

## Fuera de alcance
- Reglas de felicidad, roles o fin de partida (ya hechas en 014/015).
- Tarjetas de Vida (017).

## Criterios de aceptación
1. Compila; todos los tests pasan.
2. Manual con 2 iPhones + 1 jugador sin teléfono en el host:
   - Al iniciar Monopolife, ambas ruletas giran a la vez y cada una se detiene en el rol correcto de su jugador (compara con el estado del host en debug).
   - El host ve luego "Pasa el teléfono a …" y la ruleta del jugador sin teléfono.
   - Si un cliente cierra la app antes de confirmar y vuelve a unirse, la ruleta se le muestra otra vez; si ya había confirmado, no.
   - Ningún dispositivo muestra rol ni felicidad de otro jugador durante la partida.
   - Al cobrar renta con el Emprendedor aparece el toast y sube el número; el historial lo registra.
   - Al terminar la última ronda todos ven la pantalla final con los roles revelados y el desglose.
3. Con "Reducir movimiento" activo, la ruleta no gira y muestra la tarjeta directamente.
