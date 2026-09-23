import SwiftUI

struct TravelView: View {
    @ObservedObject var model: GameSessionModel

    @Environment(\.dismiss) private var dismiss
    @State private var route: TravelRoute = .nextSide

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Destino", selection: $route) {
                        ForEach(TravelRoute.allCases, id: \.self) { route in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(title(for: route))
                                    Text(detail(for: route))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("$\(route.fare)")
                                    .fontWeight(.semibold)
                                    .monospacedDigit()
                            }
                            .tag(route)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("¿A qué lado del tablero vas?")
                } footer: {
                    Text(footer)
                }

                if let balance {
                    Section {
                        LabeledContent("Tu saldo", value: "$\(balance)")
                    }
                }
            }
            .navigationTitle("Viajar")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Pagar $\(route.fare)") {
                        model.payTravel(route: route)
                        dismiss()
                    }
                    .disabled((balance ?? 0) < route.fare)
                }
            }
        }
    }

    private var balance: Int? {
        model.gameState?.players.first(where: { $0.id == model.localPlayerID })?.balance
    }

    private var footer: String {
        let movement = "Siempre hacia delante. Mueve tu ficha en el tablero; si pasas por la Salida, cobra tu salario como siempre."
        return model.isFreeParkingEnabled ? "\(movement) La tarifa va al bote de Free Parking." : movement
    }

    private func title(for route: TravelRoute) -> String {
        switch route {
        case .sameSide:
            return "Este mismo lado"
        case .nextSide:
            return "El lado siguiente"
        case .twoSidesAhead:
            return "Dos lados más adelante"
        case .threeSidesAhead:
            return "Tres lados más adelante"
        case .fullLap:
            return "Vuelta completa"
        }
    }

    private func detail(for route: TravelRoute) -> String {
        switch route {
        case .sameSide:
            return "Una casilla más adelante en tu lado"
        case .nextSide:
            return "Después de la próxima esquina"
        case .twoSidesAhead:
            return "Pasando dos esquinas"
        case .threeSidesAhead:
            return "Pasando tres esquinas"
        case .fullLap:
            return "Tu mismo lado, pero detrás de ti"
        }
    }
}
