# Reglas del Proyecto

Este documento define **cómo se construye** este proyecto: alcance técnico, arquitectura, convenciones y flujo de trabajo entre el usuario (Brian), yo (Claude, como prompt engineer / mano derecha) y el agente de código (Codex) que escribe la implementación. Es la referencia a seguir antes de escribir o revisar cualquier prompt de código.

## 1. Alcance del producto

- La app **no** reemplaza el tablero físico, los dados, las fichas ni las cartas de Monopoly. Reemplaza únicamente el **dispositivo lector bancario** de la edición Ultimate Banking: dinero, propiedades, hipotecas, construcciones y patrimonio de cada jugador.
- Los jugadores siguen jugando en una mesa física, con el tablero real delante, y usan la app en sus propios teléfonos como si fuera su "tarjeta bancaria".
- **Excepción en Monopolife**: en ese modo las cartas físicas de Suerte y Caja de Comunidad se reemplazan por **Tarjetas de Vida** que sortea la app (el host). Sigue sin digitalizarse el tablero, los dados ni las fichas: las tarjetas de movimiento solo indican a dónde mover la ficha física (ver `MONOPOLIFE_RULES.md` sección 5).
- Toda acción que en el juego físico ocurre sobre el tablero (mover fichas, sacar dados, robar cartas de Suerte/Comunidad) se reporta manualmente a la app por el jugador correspondiente; la app no intenta inferir ni validar el movimiento físico.

## 2. Jugadores y dispositivos

- **Multi-dispositivo**: cada jugador usa su propio teléfono/tablet. No hay modo "pasar el dispositivo".
- **Un dispositivo host = la banca**: quien crea la partida actúa como fuente de verdad del estado del juego (saldo de todos, propiedades, etc.). Los demás dispositivos son clientes que envían acciones al host y reciben el estado actualizado.
- Si el host se desconecta, la partida no puede continuar hasta que vuelva a conectarse (no hay migración de host en la v1; ver sección 8 de mejoras futuras).
- Rango soportado: 2 a 8 jugadores (el físico Ultimate Banking soporta hasta 4-6 según edición; validar contra la caja del usuario y ajustar el límite si hace falta).

## 3. Arquitectura y stack técnico

- **Plataforma**: iOS nativo, Swift + SwiftUI. Se parte del proyecto Xcode ya presente en el repo (`Monopoly.xcodeproj` / carpeta `Monopoly/`).
- **Conectividad multi-dispositivo**: red local, sin servidor externo ni cuentas en la nube. Usar el framework **MultipeerConnectivity** de Apple (descubrimiento vía Bluetooth/Wi-Fi local, sin necesidad de internet). Esto evita depender de infraestructura de backend y funciona bien para una partida presencial alrededor de una mesa.
- **Pagos por proximidad (opcional)**: iOS no permite NFC entre dos iPhone (Core NFC solo lee etiquetas y la emulación de tarjeta requiere un acuerdo comercial con Apple). Como alternativa, Brian aprobó usar **NearbyInteraction (UWB)** para "pagar acercando iPhones": los tokens de descubrimiento se intercambian por la misma sesión MultipeerConnectivity (el host reenvía las señales entre clientes) y la proximidad solo identifica al jugador que cobra; el pago en sí sigue siendo un `GameIntent` validado por el host. Se activa por partida desde la configuración del host y está **desactivado por defecto**; los botones de pago normales siempre siguen disponibles. Requiere iPhone 11 o posterior (excepto SE) en ambos jugadores.
- **Pagos por QR**: siempre disponibles (no requieren activarse ni hardware especial, solo la cámara). Quien cobra muestra un QR y quien paga lo escanea con la cámara (AVFoundation); el QR se genera con Core Image. El QR solo identifica **a quién o qué propiedad** se paga (y opcionalmente un monto fijo); el pago en sí sigue siendo el mismo `GameIntent` (`collectRent` o `transferMoney`) validado por el host, así que las reglas de turno, saldo y bancarrota no cambian. El formato del QR es `monopoly-pay:1:rent:<propertyID>` o `monopoly-pay:1:transfer:<playerID>:<monto o 0>`; un QR de otra partida no se reconoce porque sus IDs no existen en esta.
- **Modelo de red**: host-autoritativo. El host mantiene el estado canónico de la partida (`GameState`); los clientes envían **intenciones** (ej. "quiero pagar renta de $200 a Juan"), el host las valida y aplica, y retransmite el nuevo estado a todos los peers.
- **Persistencia**: el host guarda la partida en curso (`GameState` + qué jugadores juegan desde su iPhone) como JSON `Codable` en Application Support después de cada cambio de estado. Si el host cierra la app, al volver a abrirla puede "Continuar partida" desde la pantalla de inicio; los clientes que siguen con la app abierta se reconectan solos, y los que la cerraron vuelven a unirse con el mismo nombre para recuperar su jugador. Solo se guarda una partida; alojar una nueva la reemplaza. Los clientes no guardan nada: el host es la fuente de verdad.
- **Sin backend en la nube** en esta fase del proyecto. No usar Firebase, CloudKit u otro servicio remoto salvo que se decida explícitamente más adelante y se actualice este documento.

## 4. Estructura de datos (guía, no definitiva)

La tabla de datos del juego (propiedades, precios, rentas, grupos de color, costos de construcción) debe modelarse como datos declarativos (ej. un `.json` o structs `Codable` cargados desde un archivo), nunca hardcodeados dispersos en la lógica de UI o de red. Esto permite:
- Corregir valores sin tocar lógica de negocio.
- Reutilizar la tabla tanto en el host como en validaciones locales de UI (ej. mostrar precio antes de confirmar compra).

La lógica de reglas del juego (ver `GAME_RULES.md`) debe vivir en una capa de dominio separada de SwiftUI (sin `import SwiftUI` en esa capa), para poder testearla de forma aislada y para que Codex no mezcle lógica de negocio con vistas.

## 5. Flujo de trabajo: Brian, Claude (yo) y Codex

- **Brian** define objetivos, prioridades y decisiones de producto/negocio.
- **Yo (Claude)** actúo como prompt engineer: traduzco esas decisiones en prompts claros, acotados y verificables para Codex, y **reviso el código que Codex produce** contra `GAME_RULES.md` y este documento antes de darlo por bueno.
- **Codex** es quien escribe la implementación real (código Swift). No se le pide que tome decisiones de reglas de negocio por su cuenta: esas decisiones deben estar ya resueltas en `GAME_RULES.md`/`PROJECT_RULES.md` o explícitas en el prompt.
- Cada tarea que se le da a Codex debe:
  1. Referenciar la sección exacta de `GAME_RULES.md` o `PROJECT_RULES.md` aplicable.
  2. Tener criterios de aceptación explícitos y comprobables (compila, pasa tests, comportamiento X ante input Y).
  3. Evitar ambigüedad de alcance ("solo esto, no refactorices lo demás").
- Después de cada entrega de Codex, la revisión debe verificar:
  - Fidelidad a las reglas del juego (`GAME_RULES.md`).
  - Que la lógica de dominio esté separada de la UI.
  - Que no se introduzcan dependencias de red/nube fuera de MultipeerConnectivity (y NearbyInteraction para los pagos por proximidad) sin aprobación explícita de Brian.
  - Que el código compile y, cuando existan, los tests pasen.

## 6. Convenciones de código

- Swift + SwiftUI siguiendo convenciones estándar de Apple (naming camelCase, tipos en PascalCase).
- Sin comentarios explicativos de "qué hace" el código — el naming debe bastar. Comentarios solo para justificar decisiones no obvias (ej. por qué se eligió redondear rentas hacia arriba).
- Preferir `struct` + `Codable` para modelos de datos del juego; `class` solo donde se necesite identidad de referencia real (ej. gestor de conexión).
- Nombres de archivo y tipos en inglés (convención estándar de Apple/Swift); los documentos de reglas y la comunicación del proyecto pueden estar en español.

## 7. Testing

- La capa de dominio (reglas de negocio: compra, renta, hipoteca, bancarrota, etc.) debe tener tests unitarios (XCTest), dado que es la parte más sensible a errores silenciosos.
- La capa de red (MultipeerConnectivity) y la UI se validan manualmente en esta fase, salvo que el proyecto crezca lo suficiente para justificar mocks de red.

## 8. Fuera de alcance (por ahora)

Explícitamente **no** se construye en esta fase, salvo decisión posterior de Brian:
- Digitalización del tablero, dados o fichas (movimiento automático).
- Reconocimiento de cartas físicas de Suerte/Caja de Comunidad (en Monopolife se reemplazan por Tarjetas de Vida sorteadas en la app, no se reconocen las físicas).
- Multi-dispositivo por internet (fuera de red local).
- Migración de host si el host se desconecta a mitad de partida.
- Multi-partida simultánea / historial de partidas en la nube.

## 9. Fuente de verdad y cambios a estas reglas

- Si Brian cambia una decisión de producto o técnica durante el proyecto, este documento (y `GAME_RULES.md` si aplica) debe actualizarse **antes** de generar el siguiente prompt para Codex, no después.
- Ante conflicto entre lo que dice el código existente y estos documentos, estos documentos mandan salvo que Brian indique lo contrario explícitamente.
