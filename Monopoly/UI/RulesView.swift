import SwiftUI

/// How to play, for players. Numbers come from the same data the rules use, so this
/// screen stays right when values are tuned.
struct RulesView: View {
    @State private var mode: GameMode
    @State private var expandedTopicIDs: Set<String> = ["setup", "goal"]

    init(mode: GameMode = .classic) {
        _mode = State(initialValue: mode)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Modo de juego", selection: $mode) {
                    Text("Monopoly Classic").tag(GameMode.classic)
                    Text("Monopolife").tag(GameMode.monopolife)
                }
                .pickerStyle(.segmented)

                intro

                ForEach(topics) { topic in
                    topicCard(topic)
                }

                if mode == .monopolife {
                    rolesCard
                    Button {
                        mode = .classic
                    } label: {
                        Label("Ver las reglas del Classic, que también aplican aquí", systemImage: "arrow.left.arrow.right")
                            .font(.app(.subheadline, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
                }

                NavigationLink {
                    PhotoCreditsView()
                } label: {
                    Label("Créditos de las fotos", systemImage: "photo.on.rectangle")
                        .font(.app(.footnote, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
            }
            .padding(20)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Cómo se juega")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .animation(.snappy, value: mode)
        .animation(.snappy, value: expandedTopicIDs)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(mode == .classic ? "Monopoly Classic" : "Monopolife")
                .font(.app(.title, weight: .black))
            Text(mode == .classic
                 ? "El Monopoly de siempre con banca digital: el tablero, los dados, las fichas y las cartas siguen siendo los de la caja, y cada jugador lleva su dinero y sus propiedades en su iPhone."
                 : "Aquí no gana quien tiene más dinero, sino quien tiene más felicidad. Cada jugador recibe un rol secreto que decide qué lo hace feliz, así que cada partida se juega distinto.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }

    private func topicCard(_ topic: RuleTopic) -> some View {
        let isExpanded = expandedTopicIDs.contains(topic.id)
        return VStack(alignment: .leading, spacing: 12) {
            Button {
                if isExpanded {
                    expandedTopicIDs.remove(topic.id)
                } else {
                    expandedTopicIDs.insert(topic.id)
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: topic.icon)
                        .font(.app(.title3, weight: .semibold))
                        .foregroundStyle(topic.color)
                        .frame(width: 40, height: 40)
                        .background(topic.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
                    Text(topic.title)
                        .font(.app(.headline))
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.app(.footnote, weight: .bold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(isExpanded ? "Ocultar" : "Mostrar")

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(topic.points, id: \.self) { point in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("•")
                                .foregroundStyle(topic.color)
                            Text(point)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .font(.app(.subheadline))
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var rolesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Los 6 roles", systemImage: "theatermasks")
                .font(.app(.headline))
            Text("Te toca uno al azar en la ruleta. Nadie más sabe cuál es hasta el final.")
                .font(.app(.subheadline))
                .foregroundStyle(.secondary)

            ForEach(LifeRole.allCases, id: \.self) { role in
                let definition = role.definition
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(definition.emoji)
                            .font(.app(.title2))
                        VStack(alignment: .leading, spacing: 0) {
                            Text(definition.name)
                                .font(.app(.headline))
                                .foregroundStyle(role.color)
                            Text(definition.summary)
                                .font(.app(.caption))
                                .foregroundStyle(.secondary)
                        }
                    }
                    ForEach(definition.likes, id: \.self) { like in
                        Text("😊 \(like)")
                            .font(.app(.subheadline))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text("😞 \(definition.dislike)")
                        .font(.app(.subheadline))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(role.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var topics: [RuleTopic] {
        mode == .classic ? RuleTopic.classic : RuleTopic.monopolife
    }
}

struct RuleTopic: Identifiable {
    let id: String
    let icon: String
    let color: Color
    let title: String
    let points: [String]
}

extension RuleTopic {
    private static var levelCosts: String {
        Property.levelUpCostPercentages.enumerated()
            .map { "nivel \($0.offset + 1): \($0.element)%" }
            .joined(separator: ", ")
    }

    private static var travelFares: String {
        "Cuesta $\(TravelRoute.sameSide.fare) en tu mismo lado, $\(TravelRoute.nextSide.fare) al lado siguiente, "
            + "$\(TravelRoute.twoSidesAhead.fare) dos lados más allá, $\(TravelRoute.threeSidesAhead.fare) tres lados más allá "
            + "y $\(TravelRoute.fullLap.fare) para dar la vuelta completa"
    }

    static let classic: [RuleTopic] = [
        RuleTopic(
            id: "setup", icon: "person.3.fill", color: .blue, title: "Preparar la partida",
            points: [
                "Uno aloja la partida con \"Alojar partida\" y hace de banca: su iPhone guarda la partida y valida cada pago.",
                "Los demás pulsan \"Unirse a partida\" en su iPhone y escriben su nombre. Hace falta estar en la misma Wi‑Fi o cerca con Bluetooth.",
                "Si alguien no tiene teléfono, el host lo añade y juega desde el iPhone del host (se cambia con \"Jugando como\").",
                "El host ordena los turnos (por ejemplo, según los dados) y elige el modo de juego y las reglas opcionales.",
                "Cada jugador empieza con $\(GameSessionModel.placeholderInitialBalance)."
            ]
        ),
        RuleTopic(
            id: "turn", icon: "dice.fill", color: .green, title: "Tu turno",
            points: [
                "Tiras los dados y mueves tu ficha en el tablero físico, como siempre. La app no mueve fichas: tú le dices qué pasó.",
                "Según la casilla: compras la propiedad, pagas renta, pagas un impuesto o cobras tu salario en la Salida: $200 al pasar, $400 si caes justo en ella.",
                "Casillas de viaje: pagas para mover tu ficha a cualquier casilla, siempre hacia delante. \(travelFares).",
                "Solo en tu turno: comprar, pagar renta, pagar impuestos, viajar, cobrar salario, cobrar el bote, subastas y pedir préstamos.",
                "En cualquier momento: pagar a otro jugador, negociar en el Mercado, hipotecar, subir o bajar de nivel, pagar la tarjeta y declararte en bancarrota.",
                "Cuando termines, pulsa \"Terminar turno\". El host puede pasar el turno de alguien que se olvidó."
            ]
        ),
        RuleTopic(
            id: "properties", icon: "house.fill", color: .orange, title: "Comprar propiedades",
            points: [
                "Al caer en una propiedad sin dueño puedes comprarla a su precio.",
                "Si no la quieres, se subasta entre todos y se la lleva la puja más alta.",
                "También puedes comprarla entre varios: cada uno paga según su %.",
                "Cada propiedad tiene 10 acciones de 10%. La renta se reparte entre los accionistas según su %, y quien tiene más % la administra."
            ]
        ),
        RuleTopic(
            id: "rent", icon: "banknote.fill", color: .mint, title: "Rentas y niveles",
            points: [
                "Si caes en una propiedad de otro, pagas su renta actual. Si tienes acciones de ella, solo pagas la parte de los demás.",
                "Puedes subir de nivel cualquier propiedad en la que tengas acciones para cobrar más, sin tener el grupo completo. Cuesta un % del precio: \(levelCosts).",
                "Cualquier accionista puede subir el nivel y el costo se reparte según el %. Si otro accionista no tiene para su parte, la pagas tú y te quedas con acciones suyas; él puede recuperarlas cuando quiera devolviéndote ese dinero.",
                "Bajar un nivel te devuelve la mitad de lo que costó."
            ]
        ),
        RuleTopic(
            id: "mortgage", icon: "building.columns.fill", color: .brown, title: "Hipotecas",
            points: [
                "Puedes hipotecar una propiedad en nivel 0 para recibir su valor de hipoteca al instante.",
                "Mientras está hipotecada no cobra renta.",
                "Deshipotecarla cuesta el valor de hipoteca más un 10%."
            ]
        ),
        RuleTopic(
            id: "market", icon: "chart.line.uptrend.xyaxis", color: .purple, title: "Mercado",
            points: [
                "Propón tratos con uno o varios jugadores: dinero, acciones de propiedades o ambas cosas.",
                "El trato se hace cuando todos los participantes aceptan. Si alguien lo rechaza, se cancela para todos.",
                "Ofertas abiertas: publicas lo que das y lo que pides, y el primero que acepta se queda con el trato.",
                "Inversiones: pagas una vez a otro jugador y a cambio te llevas un % de lo que él cobre de renta en una propiedad, hasta que ambos acuerden cancelarla."
            ]
        ),
        RuleTopic(
            id: "payments", icon: "qrcode", color: .teal, title: "Formas de pagar",
            points: [
                "Con QR: quien cobra pulsa \"Cobrar\" y muestra su QR (de una propiedad o de sí mismo, con monto opcional); quien paga pulsa \"Pagar\" y lo escanea: el pago se hace en cuanto se lee. Si el QR no trae monto, escríbelo antes de escanear.",
                "A mano: en la pantalla de escanear, pulsa \"Manual\" para elegir el jugador y el monto. Sirve para cartas que te obligan a pagarle a alguien.",
                "La renta también se paga desde la propiedad, en la lista."
            ]
        ),
        RuleTopic(
            id: "credit", icon: "creditcard.fill", color: .indigo, title: "Tarjeta de crédito",
            points: [
                "Si el host la activó, puedes pedir prestado hasta el \(GameRules.baseCreditLimitPercentage)% de tu patrimonio, menos lo que ya debas.",
                "Confianza de la banca: cada préstamo que terminas de pagar sube tu límite \(GameRules.creditTrustStepPercentage) puntos (hasta el \(GameRules.maximumCreditLimitPercentage)% de tu patrimonio). Cada vez que pasas por la Salida y no te alcanza para una cuota, lo baja \(GameRules.creditTrustStepPercentage) puntos. Aplazar una cuota no cuenta como fallo.",
                "Con \(GameRules.missedPaymentsBeforeCreditIsCut) fallos la banca deja de darte crédito para el resto de la partida.",
                "Solo puedes tener un préstamo a la vez. Cuando terminas de pagar uno, puedes tener hasta dos.",
                "El interés es un 10% fijo al pedir el préstamo.",
                "Eliges pagarlo en 1 a \(GameRules.maxCreditCardInstallments) cuotas, que se cobran cada vez que pasas por la Salida. Las cuotas que no uses se convierten en aplazamientos.",
                "Puedes adelantar pagos cuando quieras."
            ]
        ),
        RuleTopic(
            id: "board-events", icon: "tornado", color: .red, title: "Eventos del tablero",
            points: [
                "Regla opcional: el host elige en la sala si hay eventos y cada cuántas rondas: un número fijo (de \(BoardEventsState.intervalRange.lowerBound) a \(BoardEventsState.intervalRange.upperBound)) o al azar dentro de un rango, para que nadie sepa cuándo llega el siguiente.",
                "Al terminar esas rondas ocurre un evento al azar y todos lo ven a la vez. Afecta a un lado del tablero, a un grupo de color, a una propiedad o a todos.",
                "Los cambios de renta se suman a la renta normal (primero los %, luego los $) y la renta nunca baja de $0. Los ves en el tablero y en cada propiedad.",
                "Un evento nunca te lleva a la bancarrota: si no te alcanza para una reparación, pagas lo que tengas."
            ] + BoardEventCatalog.all.map { "\($0.emoji) \($0.title): \(BoardEventText.effect($0.effect).lowercasedFirst)." }
        ),
        RuleTopic(
            id: "free-parking", icon: "parkingsign.circle.fill", color: .cyan, title: "Bote de Free Parking",
            points: [
                "Regla opcional que activa el host.",
                "Los impuestos, los viajes, el 10% de interés de la tarjeta (a medida que se paga) y el 10% al deshipotecar van a un bote que todos ven en el tablero.",
                "Quien cae en Free Parking pulsa \"Caí en Free Parking\" en su turno y se lleva todo el bote.",
                "Las compras de propiedades y las subidas de nivel no van al bote."
            ]
        ),
        RuleTopic(
            id: "secret-levels", icon: "eye.slash.fill", color: .gray, title: "Niveles secretos",
            points: [
                "Regla opcional que activa el host.",
                "Todos siguen viendo el dinero de los demás, pero no el nivel ni la renta de sus propiedades.",
                "Sí ves el nivel de las propiedades en las que tienes acciones, aunque las administre otro.",
                "La renta de una propiedad ajena se descubre al ir a pagarla."
            ]
        ),
        RuleTopic(
            id: "bankruptcy", icon: "exclamationmark.triangle.fill", color: .red, title: "Bancarrota y fin de la partida",
            points: [
                "Si no puedes pagar una deuda ni vendiendo o hipotecando, te declaras en bancarrota.",
                "Si le debías a otro jugador, él se queda con tu dinero y tus acciones. Si le debías a la banca, tus propiedades vuelven al banco o a sus otros accionistas.",
                "Quedas eliminado de la partida.",
                "Gana el último jugador que no quiebre."
            ]
        )
    ]

    static let monopolife: [RuleTopic] = [
        RuleTopic(
            id: "goal", icon: "trophy.fill", color: .yellow, title: "Cómo se gana",
            points: [
                "El host elige cuántas rondas se juegan (\(MonopolifeState.roundLimitOptions.map(String.init).joined(separator: ", "))).",
                "Al terminar la última ronda la partida acaba sola y gana quien tenga más felicidad.",
                "Si hay empate, gana quien tenga más patrimonio. Si también empatan, comparten la victoria.",
                "El dinero sigue importando, pero solo como medio para ser feliz."
            ]
        ),
        RuleTopic(
            id: "roles", icon: "theatermasks.fill", color: .pink, title: "Roles secretos",
            points: [
                "Al empezar, una ruleta aparece a la vez en todos los iPhones y te asigna un rol.",
                "Tu rol decide qué te da felicidad y qué te la quita. Ningún rol es mejor que otro: solo se juegan distinto.",
                "Nadie más ve tu rol ni tu felicidad hasta el final. Puedes volver a ver tu rol con \"Mi rol\".",
                "Los jugadores sin teléfono ven su ruleta en el iPhone del host, que les pide que se lo pasen."
            ]
        ),
        RuleTopic(
            id: "happiness", icon: "face.smiling.inverse", color: .green, title: "Felicidad",
            points: [
                "Empiezas con 0 y nunca baja de 0.",
                "Sube o baja por lo que haces según tu rol (pagar renta, comprar, negociar, cobrar salario…), al terminar cada ronda y con las Tarjetas de Vida.",
                "Cada vez que cambia ves un aviso, y en \"Mi felicidad\" tienes el historial completo."
            ]
        ),
        RuleTopic(
            id: "cards", icon: "rectangle.stack.fill", color: .orange, title: "Tarjetas de Vida",
            points: [
                "No se usan las cartas físicas de Suerte ni de Caja de Comunidad. Al caer en esas casillas, en tu turno, pulsa \"Caí en Suerte / Caja de Comunidad\".",
                "El mazo tiene \(LifeCards.all.count) tarjetas. Cada una afecta distinto a cada rol: un carro nuevo encanta a unos y a otros les duele gastar.",
                "Eventos: se aplican solos. Decisiones: aceptas pagando o pasas; no puedes terminar el turno sin decidir.",
                "Posesiones: algunas compras te dan un carro, un televisor o un food truck. Después pueden salir tarjetas como \"Se te rompe el carro\" que solo afectan a quien lo tiene.",
                "Movimiento: te dicen a dónde mover tu ficha física.",
                "Una tarjeta nunca te lleva a la bancarrota: si no te alcanza, pagas lo que tengas."
            ]
        ),
        RuleTopic(
            id: "life-bankruptcy", icon: "arrow.uturn.backward.circle.fill", color: .red, title: "Bancarrota en Monopolife",
            points: [
                "No quedas eliminado.",
                "Pierdes tus propiedades como en el Classic y la mitad de tu felicidad.",
                "Recibes $\(LifeRoleValues.bankruptcyRescueBalance) de rescate y sigues jugando con tu mismo rol."
            ]
        ),
        RuleTopic(
            id: "end", icon: "flag.checkered", color: .blue, title: "Fin de la partida",
            points: [
                "Todos ven el ranking final con la felicidad y el rol de cada jugador.",
                "Toca a un jugador para ver de dónde salió su felicidad y qué posesiones tenía.",
                "Todo lo demás (turnos, compras, niveles, Mercado, pagos, tarjeta de crédito) funciona igual que en el Classic."
            ]
        )
    ]
}

#Preview {
    NavigationStack {
        RulesView(mode: .monopolife)
    }
}

private extension String {
    var lowercasedFirst: String {
        prefix(1).lowercased() + dropFirst()
    }
}
