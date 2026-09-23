# 010 — Rediseñar la pantalla de inicio (StartView)

## Contexto

Lee `CONTEXT.md`, `GAME_RULES.md` y `PROJECT_RULES.md` antes de empezar. Esta tarea es puramente visual/UI: no toca lógica de dominio, red ni persistencia.

`Monopoly/UI/StartView.swift` es la primera pantalla de la app: desde ahí el usuario aloja una partida nueva, continúa una guardada o se une a una existente. Hoy es un `VStack` genérico con un ícono SF Symbol, texto y botones apilados con estilos `.bordered`/`.borderedProminent` por defecto — visualmente no comunica que es una app de Monopoly ni tiene jerarquía o identidad propias.

## Objetivo

Rediseñar solo la capa visual de `StartView.swift` (y, si hace falta un componente reutilizable de tarjeta/botón, puede vivir en un archivo nuevo dentro de `Monopoly/UI/`) para que se vea pulida y con identidad de marca de Monopoly, sin cambiar ningún comportamiento, navegación ni lógica existente.

## Alcance

- No modificar `HostSetupView`, `JoinView`, `ResumeHostView`, `GameStore` ni ninguna lógica de `GameSessionModel`. Los `NavigationLink` y sus destinos deben seguir apuntando a las mismas vistas con las mismas responsabilidades.
- No cambiar el flujo condicional existente (mostrar `savedGameCard` cuando hay partida guardada, confirmación de descarte, etc.), solo su presentación.
- Se puede introducir una paleta de colores con identidad Monopoly (ej. rojo/verde/dorado del tablero clásico) definida como constantes o extensiones de `Color`, reutilizable si más pantallas quieren adoptarla después — pero en este prompt solo se aplica a `StartView`.
- Diseño debe funcionar en modo claro y oscuro (usar `Color` semánticos o `@Environment(\.colorScheme)` donde haga falta, no colores hardcodeados que rompan contraste).
- Debe verse bien tanto en iPhone chico (SE) como en modelos grandes; usar `ScrollView` si el contenido no cabe en pantallas pequeñas con Dynamic Type grande.
- Mejorar jerarquía visual: título/logo con más presencia, distinción clara entre la acción principal (alojar o continuar partida) y la secundaria (unirse), y la tarjeta de partida guardada con más peso visual (bordes, sombra o fondo diferenciado) en vez de texto plano.
- Los textos existentes en español se mantienen tal cual (mismos strings), salvo que agregues copy puramente decorativo (ej. un subtítulo), en cuyo caso debe mantenerse en español y consistente con el tono del resto de la app.

## Criterios de aceptación

1. Compila sin errores ni warnings nuevos.
2. `StartView` sigue exponiendo el mismo comportamiento: alojar partida nueva, continuar partida guardada, descartar partida guardada (con confirmación), unirse a partida — todos navegando a las mismas vistas de siempre.
3. El diseño es visualmente distinto al actual (no es solo mover paddings): tiene una paleta de color con identidad, tipografía con jerarquía clara y al menos un elemento visual propio de Monopoly (p. ej. franja de colores del tablero, ícono/ilustración temática, o textura sutil) en vez de solo un SF Symbol genérico.
4. Se ve correctamente en light y dark mode, y no rompe en iPhone SE (pantalla chica) ni con Dynamic Type grande (probar con "Accessibility XL" si es posible).
5. No se agregan dependencias externas (solo SwiftUI/SF Symbols nativos).
6. Si se crea un archivo nuevo para estilos/componentes compartidos, debe ubicarse en `Monopoly/UI/` y seguir las convenciones de nombres de `PROJECT_RULES.md` sección 6.
