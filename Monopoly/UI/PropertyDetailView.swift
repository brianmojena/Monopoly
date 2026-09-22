import SwiftUI

struct PropertyDetailView: View {
    let propertyID: UUID
    @ObservedObject var model: GameSessionModel
    @State private var proximityPayment: ProximityPayment?

    var body: some View {
        Group {
            if let state = model.gameState,
               let property = state.properties.first(where: { $0.id == propertyID }) {
                List {
                    Section("Estado") {
                        LabeledContent("Dueño", value: ownerName(for: property, state: state))
                        LabeledContent("Precio", value: currency(property.purchasePrice))
                        LabeledContent("Renta actual", value: currency(currentRent(for: property, in: state)))
                        LabeledContent("Construcción", value: constructionDescription(for: property))
                        LabeledContent("Hipotecada", value: property.isMortgaged ? "Sí" : "No")
                        if property.isMortgaged {
                            LabeledContent("Valor de hipoteca", value: currency(property.mortgageValue))
                        }
                    }

                    if let localPlayerID = model.localPlayerID,
                       let localPlayer = state.players.first(where: { $0.id == localPlayerID }) {
                        if localPlayer.status != .active {
                            Section {
                                Text("Este jugador está en bancarrota y ya no puede realizar acciones.")
                                    .foregroundStyle(.secondary)
                            }
                        } else if property.ownerID == nil {
                            Section("Acciones") {
                                Button("Comprar") {
                                    model.buy(propertyID: property.id)
                                }
                                .buttonStyle(.borderedProminent)

                                NavigationLink {
                                    AuctionView(propertyID: property.id, model: model)
                                } label: {
                                    Label("Iniciar subasta", systemImage: "hammer")
                                }
                            }
                        } else if property.ownerID != localPlayerID {
                            Section("Acción") {
                                Button("Pagar renta") {
                                    model.payRent(propertyID: property.id)
                                }
                                .buttonStyle(.borderedProminent)

                                if model.isProximityPaymentEnabled {
                                    Button {
                                        proximityPayment = .rent(propertyID: property.id)
                                    } label: {
                                        Label("Pagar renta acercando iPhones", systemImage: "wave.3.right")
                                    }
                                }
                            }
                        } else {
                            ownPropertyActions(for: property)
                        }
                    }
                }
            } else {
                ProgressView("Cargando propiedad…")
            }
        }
        .navigationTitle(propertyName)
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .alert(
            "Acción rechazada",
            isPresented: Binding(
                get: { model.alertMessage != nil },
                set: { if !$0 { model.dismissAlert() } }
            )
        ) {
            Button("OK", role: .cancel) {
                model.dismissAlert()
            }
        } message: {
            Text(model.alertMessage ?? "Inténtalo de nuevo.")
        }
        .sheet(item: $proximityPayment) { payment in
            ProximityPaymentView(payment: payment, model: model)
        }
        .proximityReceiverBanner(model: model)
    }

    @ViewBuilder
    private func ownPropertyActions(for property: Property) -> some View {
        Section("Acciones") {
            if property.isMortgaged {
                Button("Deshipotecar") {
                    model.unmortgage(propertyID: property.id)
                }
                .buttonStyle(.borderedProminent)
            } else {
                if property.constructionLevel == 0 {
                    Button("Hipotecar") {
                        model.mortgage(propertyID: property.id)
                    }
                    .buttonStyle(.bordered)
                }

                if property.constructionLevel < 4 {
                    Button("Construir casa") {
                        model.buildHouse(propertyID: property.id)
                    }
                    .buttonStyle(.borderedProminent)
                } else if property.constructionLevel == 4 {
                    Button("Construir hotel") {
                        model.buildHotel(propertyID: property.id)
                    }
                    .buttonStyle(.borderedProminent)
                }

                if property.constructionLevel > 0 {
                    Button(property.constructionLevel == 5 ? "Vender hotel" : "Vender casa") {
                        model.sellHouse(propertyID: property.id)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var propertyName: String {
        model.gameState?.properties.first(where: { $0.id == propertyID })?.name ?? "Propiedad"
    }

    private func ownerName(for property: Property, state: GameState) -> String {
        guard let ownerID = property.ownerID,
              let owner = state.players.first(where: { $0.id == ownerID }) else {
            return "Sin dueño"
        }
        return owner.name
    }

    private func currentRent(for property: Property, in state: GameState) -> Int {
        guard let ownerID = property.ownerID else {
            return property.baseRent
        }
        // Delegates to the domain's own rent calculation instead of keeping a
        // second copy of the monopoly-double/per-level formula here.
        return (try? GameRules.rentAmount(for: property, in: state, ownerID: ownerID)) ?? property.baseRent
    }

    private func constructionDescription(for property: Property) -> String {
        switch property.constructionLevel {
        case 0:
            return "Sin construcciones"
        case 1...4:
            return "\(property.constructionLevel) casa(s)"
        default:
            return "Hotel"
        }
    }

    private func currency(_ amount: Int) -> String {
        "$\(amount)"
    }
}
