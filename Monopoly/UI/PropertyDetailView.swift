import SwiftUI

struct PropertyDetailView: View {
    let propertyID: UUID
    @ObservedObject var model: GameSessionModel
    @State private var isConfirmingRent = false

    var body: some View {
        Group {
            if let state = model.gameState,
               let property = state.properties.first(where: { $0.id == propertyID }) {
                List {
                    Section {
                        PropertyPhotoView(property: property)
                            .frame(height: 210)
                            .listRowInsets(EdgeInsets())
                    } footer: {
                        if let credit = PropertyPhotos.credit(for: property.name) {
                            Text("\(credit.caption) · \(credit.author) · \(credit.license)")
                                .font(.app(.caption2))
                        }
                    }

                    Section("Estado") {
                        LabeledContent(property.ownership.count > 1 ? "Administra" : "Dueño", value: ownerName(for: property, state: state))
                        LabeledContent("Precio", value: currency(property.purchasePrice))
                        if model.canSeeLevel(of: property) {
                            LabeledContent("Renta actual", value: currency(currentRent(for: property, in: state)))
                            LabeledContent("Nivel", value: "\(property.constructionLevel) de \(Property.maximumLevel)")
                        } else {
                            LabeledContent("Renta actual", value: "Secreta")
                            LabeledContent("Nivel", value: "Secreto")
                        }
                        LabeledContent("Hipotecada", value: property.isMortgaged ? "Sí" : "No")
                        if property.isMortgaged {
                            LabeledContent("Valor de hipoteca", value: currency(property.mortgageValue))
                        }
                    }

                    let rentEffects = GameRules.rentEffects(on: property.id, in: state)
                    if !rentEffects.isEmpty {
                        Section {
                            ForEach(rentEffects) { effect in
                                if let source = BoardEventText.source(of: effect) {
                                    LabeledContent(
                                        source,
                                        value: "\(BoardEventText.rentChange(effect)) · \(BoardEventText.remaining(effect, round: state.round))"
                                    )
                                }
                            }
                        } header: {
                            Text("Eventos y cartas que afectan la renta")
                        } footer: {
                            Text("La renta actual ya los incluye. Si queda negativa, los dueños le pagan esa cantidad a quien cae.")
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

                    if let localPlayerID = model.localPlayerID {
                        coverageSection(for: property, localPlayerID: localPlayerID, state: state)
                    }

                    if let localPlayerID = model.localPlayerID,
                       let localPlayer = state.players.first(where: { $0.id == localPlayerID }) {
                        if localPlayer.status != .active {
                            Section {
                                Text("Este jugador está en bancarrota y ya no puede realizar acciones.")
                                    .foregroundStyle(.secondary)
                            }
                        } else if property.ownerID == nil {
                            // Buying outright lives in the toolbar.
                            Section {
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
                                let bankruptcyWarning = model.rentBankruptcyWarning(propertyID: property.id)
                                let due = rentDue(for: property, by: localPlayerID, in: state)
                                if model.canSeeLevel(of: property), bankruptcyWarning == nil {
                                    Button("\(rentActionTitle(due)) de renta") {
                                        model.payRent(propertyID: property.id)
                                    }
                                    .buttonStyle(.borderedProminent)
                                } else {
                                    // A secret level's amount would give it away, so it only shows
                                    // once the player actually goes to pay; a rent that bankrupts
                                    // them asks first too.
                                    Button(model.canSeeLevel(of: property) ? "\(rentActionTitle(due)) de renta" : "Pagar renta") {
                                        isConfirmingRent = true
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .confirmationDialog(
                                        "Renta de \(property.name)",
                                        isPresented: $isConfirmingRent,
                                        titleVisibility: .visible
                                    ) {
                                        if bankruptcyWarning != nil {
                                            Button("\(rentActionTitle(due)) y quebrar", role: .destructive) {
                                                model.payRent(propertyID: property.id)
                                            }
                                        } else {
                                            Button(rentActionTitle(due)) {
                                                model.payRent(propertyID: property.id)
                                            }
                                        }
                                        Button("Cancelar", role: .cancel) {}
                                    } message: {
                                        if let bankruptcyWarning {
                                            Text(bankruptcyWarning)
                                        } else if due < 0 {
                                            Text("La renta está en negativo: los dueños te pagan a ti.")
                                        }
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
                            ownPropertyActions(for: property, localPlayerID: localPlayerID, state: state)
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
        .toolbar {
            if canBuy {
                ToolbarItem(placement: .primaryAction) {
                    Button("Comprar") {
                        model.buy(propertyID: propertyID)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.blue)
                    .disabled(!model.isLocalPlayersTurn)
                }
            }
        }
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
    }

    /// Leveling up and down lives with the rent QR, on the property's other tab.
    @ViewBuilder
    private func ownPropertyActions(for property: Property, localPlayerID: UUID, state: GameState) -> some View {
        Section {
            if property.isMortgaged {
                Button("Deshipotecar") {
                    model.unmortgage(propertyID: property.id)
                }
                .buttonStyle(.borderedProminent)
            } else if property.constructionLevel == 0 {
                Button("Hipotecar") {
                    model.mortgage(propertyID: property.id)
                }
                .buttonStyle(.bordered)
            }
        } header: {
            Text("Acciones")
        } footer: {
            if !property.isMortgaged, property.constructionLevel > 0 {
                Text("Para hipotecarla, primero baja su nivel a 0 desde Cobrar renta.")
            }
        }
    }

    /// Shares taken or given up for covering a level-up, for the two players involved.
    @ViewBuilder
    private func coverageSection(for property: Property, localPlayerID: UUID, state: GameState) -> some View {
        let coverages = state.shareCoverages.filter {
            $0.propertyID == property.id && ($0.payerID == localPlayerID || $0.coveredPlayerID == localPlayerID)
        }
        if !coverages.isEmpty {
            Section {
                ForEach(coverages) { coverage in
                    if coverage.coveredPlayerID == localPlayerID {
                        let payerStillHolds = property.shares(of: coverage.payerID) >= coverage.shares
                        Button("Recuperar \(percentage(coverage.shares)) de \(state.playerName(coverage.payerID)) por \(currency(coverage.amount))") {
                            model.buyBackShares(coverageID: coverage.id)
                        }
                        .buttonStyle(.bordered)
                        .disabled(!payerStillHolds)
                        if !payerStillHolds {
                            Text("\(state.playerName(coverage.payerID)) ya no tiene esas acciones.")
                                .font(.app(.footnote))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        LabeledContent(
                            "\(state.playerName(coverage.coveredPlayerID)) puede recuperar \(percentage(coverage.shares))",
                            value: "por \(currency(coverage.amount))"
                        )
                    }
                }
            } header: {
                Text("Acciones por subir de nivel")
            } footer: {
                Text("Quien no pudo pagar su parte de una subida de nivel puede recuperar las acciones que cedió en cualquier momento, devolviendo lo que se pagó por él.")
            }
        }
    }

    @ViewBuilder
    private var turnFooter: some View {
        if !model.isLocalPlayersTurn, let currentPlayer = model.currentPlayer {
            Text("Solo en tu turno. Ahora juega \(currentPlayer.name).")
        }
    }

    /// An unowned property, while the local player is still in the game.
    private var canBuy: Bool {
        guard let state = model.gameState,
              let property = state.properties.first(where: { $0.id == propertyID }),
              let localPlayer = state.players.first(where: { $0.id == model.localPlayerID }) else {
            return false
        }
        return property.ownerID == nil && localPlayer.status == .active
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

    /// A negative rent goes the other way: the owners pay whoever lands there.
    private func rentActionTitle(_ due: Int) -> String {
        due < 0 ? "Cobrar \(currency(-due))" : "Pagar \(currency(due))"
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
        amount < 0 ? "−$\(-amount)" : "$\(amount)"
    }
}
