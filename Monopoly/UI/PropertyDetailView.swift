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
                        LabeledContent(property.ownership.count > 1 ? "Administra" : "Dueño", value: ownerName(for: property, state: state))
                        LabeledContent("Precio", value: currency(property.purchasePrice))
                        LabeledContent("Renta actual", value: currency(currentRent(for: property, in: state)))
                        LabeledContent("Nivel", value: "\(property.constructionLevel) de \(Property.maximumLevel)")
                        LabeledContent("Hipotecada", value: property.isMortgaged ? "Sí" : "No")
                        if property.isMortgaged {
                            LabeledContent("Valor de hipoteca", value: currency(property.mortgageValue))
                        }
                    }

                    if property.ownership.count > 1 {
                        Section {
                            ForEach(property.ownership, id: \.playerID) { holding in
                                LabeledContent(state.playerName(holding.playerID), value: percentage(holding.shares))
                            }
                        } header: {
                            Text("Accionistas")
                        } footer: {
                            Text("La renta, los costos de subir o bajar de nivel, deshipotecar e hipotecar se reparten según el %. Quien tiene más % administra.")
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
                            Section {
                                Button("Comprar") {
                                    model.buy(propertyID: property.id)
                                }
                                .buttonStyle(.borderedProminent)

                                NavigationLink {
                                    SharedPurchaseView(propertyID: property.id, model: model)
                                } label: {
                                    Label("Comprar entre varios", systemImage: "person.2")
                                }

                                NavigationLink {
                                    AuctionView(propertyID: property.id, model: model)
                                } label: {
                                    Label("Iniciar subasta", systemImage: "hammer")
                                }
                            } header: {
                                Text("Acciones")
                            } footer: {
                                turnFooter
                            }
                            .disabled(!model.isLocalPlayersTurn)
                        } else if property.ownerID != localPlayerID {
                            Section {
                                Button("Pagar renta (\(currency(rentDue(for: property, by: localPlayerID, in: state))))") {
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
                            } header: {
                                Text("Acción")
                            } footer: {
                                if property.shares(of: localPlayerID) > 0 {
                                    Text("Tienes \(percentage(property.shares(of: localPlayerID))) de esta propiedad: solo pagas la parte de los demás accionistas.")
                                }
                                turnFooter
                            }
                            .disabled(!model.isLocalPlayersTurn)
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

                if property.constructionLevel < Property.maximumLevel {
                    let nextLevel = property.constructionLevel + 1
                    let cost = Property.levelUpCost(purchasePrice: property.purchasePrice, level: nextLevel)
                    Button("Subir de nivel a \(nextLevel) (\(currency(cost)))") {
                        model.levelUp(propertyID: property.id)
                    }
                    .buttonStyle(.borderedProminent)
                }

                if property.constructionLevel > 0 {
                    let levelCost = Property.levelUpCost(
                        purchasePrice: property.purchasePrice,
                        level: property.constructionLevel
                    )
                    Button("Bajar de nivel (devuelve \(currency(levelCost / 2)))") {
                        model.levelDown(propertyID: property.id)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    @ViewBuilder
    private var turnFooter: some View {
        if !model.isLocalPlayersTurn, let currentPlayer = model.currentPlayer {
            Text("Solo en tu turno. Ahora juega \(currentPlayer.name).")
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

    /// What the payer actually owes after leaving out their own shareholding, taken
    /// from the domain's rent rule so the split isn't duplicated here.
    private func rentDue(for property: Property, by payerID: UUID, in state: GameState) -> Int {
        (try? GameRules.collectRent(in: state, from: payerID, propertyID: property.id).amount)
            ?? currentRent(for: property, in: state)
    }

    private func currentRent(for property: Property, in state: GameState) -> Int {
        guard let ownerID = property.ownerID else {
            return property.baseRent
        }
        // Delegates to the domain's own rent calculation instead of keeping a
        // second copy of the monopoly-double/per-level formula here.
        return (try? GameRules.rentAmount(for: property, in: state, ownerID: ownerID)) ?? property.baseRent
    }

    private func currency(_ amount: Int) -> String {
        "$\(amount)"
    }
}
