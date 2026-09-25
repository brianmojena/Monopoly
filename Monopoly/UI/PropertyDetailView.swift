import SwiftUI

struct PropertyDetailView: View {
    let propertyID: UUID
    @ObservedObject var model: GameSessionModel
    @State private var isConfirmingSecretRent = false

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
                            Text("La renta actual ya los incluye. Nunca baja de $0.")
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
                                if model.canSeeLevel(of: property) {
                                    Button("Pagar renta (\(currency(rentDue(for: property, by: localPlayerID, in: state))))") {
                                        model.payRent(propertyID: property.id)
                                    }
                                    .buttonStyle(.borderedProminent)
                                } else {
                                    // The amount gives the level away, so it only shows
                                    // once the player actually goes to pay.
                                    Button("Pagar renta") {
                                        isConfirmingSecretRent = true
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .confirmationDialog(
                                        "Renta de \(property.name)",
                                        isPresented: $isConfirmingSecretRent,
                                        titleVisibility: .visible
                                    ) {
                                        Button("Pagar \(currency(rentDue(for: property, by: localPlayerID, in: state)))") {
                                            model.payRent(propertyID: property.id)
                                        }
                                        Button("Cancelar", role: .cancel) {}
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

                            if property.shares(of: localPlayerID) > 0,
                               !property.isMortgaged,
                               property.constructionLevel < Property.maximumLevel {
                                Section {
                                    levelUpButton(for: property, localPlayerID: localPlayerID, state: state)
                                } header: {
                                    Text("Como accionista")
                                }
                            }
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

    @ViewBuilder
    private func ownPropertyActions(for property: Property, localPlayerID: UUID, state: GameState) -> some View {
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
                    levelUpButton(for: property, localPlayerID: localPlayerID, state: state)
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

    /// Any shareholder can level up; the plan shows whose part they would cover and
    /// how many shares they would take for it (GAME_RULES section 4.3).
    @ViewBuilder
    private func levelUpButton(for property: Property, localPlayerID: UUID, state: GameState) -> some View {
        let nextLevel = property.constructionLevel + 1
        let cost = Property.levelUpCost(purchasePrice: property.purchasePrice, level: nextLevel)
        Button("Subir de nivel a \(nextLevel) (\(currency(cost)))") {
            model.levelUp(propertyID: property.id)
        }
        .buttonStyle(.borderedProminent)

        if let plan = try? GameRules.levelUpPlan(in: state, propertyID: property.id, playerID: localPlayerID),
           !plan.coverages.isEmpty {
            ForEach(plan.coverages, id: \.playerID) { coverage in
                Text("\(state.playerName(coverage.playerID)) no puede pagar su parte (\(currency(coverage.amount))). La pagas tú y te llevas \(percentage(coverage.shares)) de sus acciones; puede recuperarlas devolviéndote ese dinero.")
                    .font(.app(.footnote))
                    .foregroundStyle(.secondary)
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
