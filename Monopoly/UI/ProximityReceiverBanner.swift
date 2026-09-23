import SwiftUI

private struct ProximityReceiverBanner: ViewModifier {
    @ObservedObject var model: GameSessionModel
    @ObservedObject var proximity: ProximityPaymentCoordinator

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom) {
                if let request = proximity.incomingRequest {
                    banner(for: request)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.default, value: proximity.incomingRequest?.sessionID)
            .sensoryFeedback(.impact, trigger: proximity.incomingRequest?.sessionID) { _, sessionID in
                sessionID != nil
            }
    }

    private func banner(for request: ProximityIncomingRequest) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "wave.3.left")
                .font(.app(.title2))
                .foregroundStyle(.tint)
                .symbolEffect(.variableColor.iterative)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(payerName(request.payerID)) está pagando acercando iPhones")
                    .font(.app(.headline))
                Text(detail(for: request))
                    .font(.app(.subheadline))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer(minLength: 0)

            Button("Ignorar") {
                proximity.declineIncomingRequest()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private func detail(for request: ProximityIncomingRequest) -> String {
        guard let distance = request.distance else {
            return "Si te paga a ti, acerca tu iPhone al suyo · \(request.rangingState.description)"
        }
        return "Si te paga a ti, acerca tu iPhone al suyo · \(Int((distance * 100).rounded())) cm"
    }

    private func payerName(_ playerID: UUID) -> String {
        model.gameState?.players.first(where: { $0.id == playerID })?.name ?? "Un jugador"
    }
}

extension ProximityRangingState {
    // Shown while there is no distance yet, so a payment that never happens tells
    // which step of Nearby Interaction it is stuck on.
    var description: String {
        switch self {
        case .starting:
            return "Iniciando medición…"
        case .running:
            return "Midiendo, acércate"
        case .suspended:
            return "Medición en pausa"
        case let .timedOut(retries):
            return "Sin señal UWB, reintento \(retries)"
        case .peerEnded:
            return "El otro iPhone cortó la medición"
        case let .failed(code):
            return "Error de medición (\(code))"
        }
    }
}

extension View {
    func proximityReceiverBanner(model: GameSessionModel) -> some View {
        modifier(ProximityReceiverBanner(model: model, proximity: model.proximity))
    }
}
