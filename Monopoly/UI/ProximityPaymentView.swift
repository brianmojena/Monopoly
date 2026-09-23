import SwiftUI

enum ProximityPayment: Identifiable, Equatable {
    case rent(propertyID: UUID)
    case transfer(amount: Int)

    var id: String {
        switch self {
        case let .rent(propertyID):
            return "rent-\(propertyID)"
        case let .transfer(amount):
            return "transfer-\(amount)"
        }
    }
}

struct ProximityPaymentView: View {
    let payment: ProximityPayment
    let onPaid: () -> Void
    @ObservedObject var model: GameSessionModel
    @ObservedObject private var proximity: ProximityPaymentCoordinator
    @Environment(\.dismiss) private var dismiss

    init(payment: ProximityPayment, model: GameSessionModel, onPaid: @escaping () -> Void = {}) {
        self.payment = payment
        self.model = model
        self.onPaid = onPaid
        self.proximity = model.proximity
    }

    var body: some View {
        NavigationStack {
            Group {
                if let state = model.gameState,
                   let localPlayerID = model.localPlayerID {
                    content(details: details(in: state, localPlayerID: localPlayerID), state: state)
                } else {
                    ProgressView("Cargando partida…")
                }
            }
            .navigationTitle("Pagar acercando")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear(perform: start)
        .onDisappear {
            proximity.stopPayment()
        }
        .sensoryFeedback(.success, trigger: proximity.detectedPlayerID) { _, detected in
            detected != nil
        }
    }

    @ViewBuilder
    private func content(details: PaymentDetails, state: GameState) -> some View {
        if let errorMessage = proximity.errorMessage {
            ContentUnavailableView(
                "No se puede pagar acercando",
                systemImage: "wave.3.right.circle",
                description: Text(errorMessage)
            )
        } else if details.candidateIDs.isEmpty {
            ContentUnavailableView(
                "No hay a quién pagar",
                systemImage: "person.slash",
                description: Text("No hay otro jugador activo que pueda recibir este pago.")
            )
        } else {
            List {
                Section {
                    if let detectedID = proximity.detectedPlayerID {
                        detectedHeader(details: details, recipientName: playerName(detectedID, in: state), recipientID: detectedID)
                    } else {
                        searchingHeader(details: details, state: state)
                    }
                }
                .listRowBackground(Color.clear)

                Section {
                    ForEach(details.candidateIDs, id: \.self) { candidateID in
                        LabeledContent(playerName(candidateID, in: state)) {
                            Text(statusDescription(proximity.candidates[candidateID]))
                                .monospacedDigit()
                        }
                    }
                } header: {
                    Text("Jugadores")
                } footer: {
                    Text("El otro jugador debe tener la app abierta en la partida. Ambos iPhone necesitan chip UWB (iPhone 11 o posterior, excepto SE).")
                }
            }
        }
    }

    private func searchingHeader(details: PaymentDetails, state: GameState) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "wave.3.right")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
                .symbolEffect(.variableColor.iterative)
            Text(currency(details.amount))
                .font(.largeTitle.bold())
            Text(details.description)
                .foregroundStyle(.secondary)
            Text(instructions(for: details, in: state))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func detectedHeader(details: PaymentDetails, recipientName: String, recipientID: UUID) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            Text("iPhone de \(recipientName) detectado")
                .font(.headline)
            Text(details.description)
                .foregroundStyle(.secondary)

            Button {
                pay(to: recipientID, details: details)
            } label: {
                Text("Pagar \(currency(details.amount)) a \(recipientName)")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button("No es este jugador") {
                proximity.resetDetection()
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func start() {
        guard let state = model.gameState,
              let localPlayerID = model.localPlayerID else {
            return
        }

        let candidateIDs = details(in: state, localPlayerID: localPlayerID).candidateIDs
        guard !candidateIDs.isEmpty else {
            return
        }
        proximity.startPayment(from: localPlayerID, to: candidateIDs)
    }

    private func pay(to recipientID: UUID, details: PaymentDetails) {
        switch payment {
        case let .rent(propertyID):
            model.payRent(propertyID: propertyID)
        case let .transfer(amount):
            model.transfer(to: recipientID, amount: amount)
        }
        onPaid()
        dismiss()
    }

    private func details(in state: GameState, localPlayerID: UUID) -> PaymentDetails {
        let activeOthers = state.players
            .filter { $0.id != localPlayerID && $0.status == .active }
            .map(\.id)

        switch payment {
        case let .rent(propertyID):
            guard let property = state.properties.first(where: { $0.id == propertyID }),
                  let ownerID = property.ownerID else {
                return PaymentDetails(amount: 0, description: "Renta", candidateIDs: [])
            }
            // Taken from GameRules.collectRent, which already leaves out a mortgaged
            // property and the payer's own shareholding.
            let rent = (try? GameRules.collectRent(in: state, from: localPlayerID, propertyID: propertyID).amount)
                ?? (try? GameRules.rentAmount(for: property, in: state, ownerID: ownerID))
                ?? property.baseRent
            return PaymentDetails(
                amount: rent,
                description: "Renta de \(property.name)",
                candidateIDs: activeOthers.filter { $0 == ownerID }
            )
        case let .transfer(amount):
            return PaymentDetails(amount: amount, description: "Pago a otro jugador", candidateIDs: activeOthers)
        }
    }

    private func instructions(for details: PaymentDetails, in state: GameState) -> String {
        if details.candidateIDs.count == 1, let recipientID = details.candidateIDs.first {
            return "Acerca la parte de arriba de tu iPhone al iPhone de \(playerName(recipientID, in: state))."
        }
        return "Acerca la parte de arriba de tu iPhone al iPhone del jugador que cobra."
    }

    private func statusDescription(_ status: ProximityCandidateStatus?) -> String {
        switch status {
        case nil, .waiting:
            return "Esperando su iPhone…"
        case .ranging(distance: nil):
            return "Conectado, acércate"
        case let .ranging(distance?):
            return "\(Int((distance * 100).rounded())) cm"
        case .declined:
            return "Rechazó el pago"
        case .unavailable:
            return "Sin UWB o sin permiso"
        }
    }

    private func playerName(_ playerID: UUID, in state: GameState) -> String {
        state.players.first(where: { $0.id == playerID })?.name ?? "Jugador"
    }

    private func currency(_ amount: Int) -> String {
        "$\(amount)"
    }
}

private struct PaymentDetails {
    let amount: Int
    let description: String
    let candidateIDs: [UUID]
}
