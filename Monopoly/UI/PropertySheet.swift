import SwiftUI

/// What tapping a title card on the board opens: for the local player's own property, its
/// rent QR first with a tab over to its info; for any other, just the info.
struct PropertySheet: View {
    let propertyID: UUID
    @ObservedObject var model: GameSessionModel

    private enum Tab: Hashable {
        case rent
        case info
    }

    @Environment(\.dismiss) private var dismiss
    @State private var tab: Tab

    init(propertyID: UUID, model: GameSessionModel) {
        self.propertyID = propertyID
        self.model = model
        // Chosen once on opening, so buying the property from its info doesn't jump to its QR.
        let property = model.gameState?.properties.first(where: { $0.id == propertyID })
        let collectsRent = property.map { Self.isHeld($0, by: model) && !$0.isMortgaged } ?? false
        _tab = State(initialValue: collectsRent ? .rent : .info)
    }

    var body: some View {
        NavigationStack {
            Group {
                if isHeldLocally, tab == .rent {
                    RentQRView(model: model, propertyID: propertyID)
                } else {
                    PropertyDetailView(propertyID: propertyID, model: model)
                }
            }
            .navigationTitle(model.gameState?.properties.first(where: { $0.id == propertyID })?.name ?? "Propiedad")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
                if isHeldLocally {
                    ToolbarItem(placement: .principal) {
                        Picker("Vista", selection: $tab) {
                            Text("Cobrar").tag(Tab.rent)
                            Text("Info").tag(Tab.info)
                        }
                        .pickerStyle(.segmented)
                        .fixedSize()
                    }
                }
            }
        }
    }

    private var isHeldLocally: Bool {
        guard let property = model.gameState?.properties.first(where: { $0.id == propertyID }) else {
            return false
        }
        return Self.isHeld(property, by: model)
    }

    private static func isHeld(_ property: Property, by model: GameSessionModel) -> Bool {
        guard let localPlayerID = model.localPlayerID else {
            return false
        }
        return property.shares(of: localPlayerID) > 0
    }
}

// MARK: - Rent QR

/// One of the local player's properties' rent, laid out like a payment request in a
/// finance app: the amount up top, the QR to scan, whether it has been paid, and the
/// level controls that change what it charges at the bottom.
struct RentQRView: View {
    @ObservedObject var model: GameSessionModel
    let propertyID: UUID

    /// Money that just came in (positive) or went out (negative) for this rent.
    @State private var settledAmount: Int?
    /// The level last seen, so a level change's cost or refund doesn't read as rent.
    @State private var observedLevel: Int?

    var body: some View {
        Group {
            if let state = model.gameState,
               let property = state.properties.first(where: { $0.id == propertyID }),
               let player = state.players.first(where: { $0.id == model.localPlayerID }) {
                if property.isMortgaged {
                    ContentUnavailableView(
                        "Propiedad hipotecada",
                        systemImage: "house.slash",
                        description: Text("Una propiedad hipotecada no cobra renta. Deshipotécala desde Info.")
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 28) {
                            amountHeader(for: property, playerID: player.id, in: state)
                            qrCard(for: property)
                            paymentStatus(rentIsNegative: rentAmount(for: property, in: state) < 0)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .frame(maxWidth: 520)
                        .frame(maxWidth: .infinity)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .safeAreaInset(edge: .bottom) {
                        levelControls(for: property, playerID: player.id, in: state)
                    }
                    .onAppear {
                        observedLevel = property.constructionLevel
                    }
                    .onChange(of: player.balance) { oldBalance, newBalance in
                        defer { observedLevel = property.constructionLevel }
                        guard observedLevel == property.constructionLevel else { return }
                        // A positive rent comes in; a negative one goes out to whoever landed.
                        let change = newBalance - oldBalance
                        let rentIsNegative = rentAmount(for: property, in: state) < 0
                        guard rentIsNegative ? change < 0 : change > 0 else { return }
                        withAnimation(.spring) {
                            settledAmount = change
                        }
                    }
                    .sensoryFeedback(trigger: property.constructionLevel) { oldLevel, newLevel in
                        newLevel > oldLevel ? .increase : .decrease
                    }
                }
            } else {
                ProgressView("Cargando partida…")
            }
        }
        .sensoryFeedback(.success, trigger: settledAmount)
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

    // MARK: Amount

    private func amountHeader(for property: Property, playerID: UUID, in state: GameState) -> some View {
        let rent = rentAmount(for: property, in: state)
        let shares = property.shares(of: playerID)
        let myPart = abs(rent) * shares / Property.totalShares

        return VStack(spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(property.colorGroup.swatch)
                    .frame(width: 8, height: 8)
                Text("\(rent < 0 ? "RENTA NEGATIVA" : "RENTA") · NIVEL \(property.constructionLevel)")
            }
            .font(.app(.caption, weight: .semibold))
            .tracking(1.4)
            .foregroundStyle(Lux.textSecondary)

            Text(currency(rent))
                .font(.app(size: 56, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(rent < 0 ? Lux.down : Lux.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText(value: Double(rent)))
                .animation(.spring, value: rent)

            Group {
                if rent < 0 {
                    Text(shares < Property.totalShares
                         ? "Te toca pagar \(currency(myPart)) a quien caiga. Sube de nivel para volver a cobrar."
                         : "Pagas \(currency(-rent)) a quien caiga. Sube de nivel para volver a cobrar.")
                } else if shares < Property.totalShares {
                    Text("Te toca \(currency(myPart)) · tienes el \(percentage(shares))")
                }
            }
            .font(.app(.footnote, weight: .medium))
            .monospacedDigit()
            .foregroundStyle(Lux.textSecondary)
            .multilineTextAlignment(.center)

            rentBreakdown(for: property, in: state)
                .padding(.top, 8)
        }
        .accessibilityElement(children: .combine)
    }

    /// Why the rent is what it is: the level's rent, then each board event or host card
    /// on it, so a rent that looks off explains itself.
    @ViewBuilder
    private func rentBreakdown(for property: Property, in state: GameState) -> some View {
        let effects = GameRules.rentEffects(on: property.id, in: state)
        if !effects.isEmpty, let levelRent = try? GameRules.levelRent(for: property) {
            VStack(spacing: 6) {
                breakdownChip(
                    amount: currency(levelRent),
                    label: "Renta del nivel \(property.constructionLevel)",
                    tint: Lux.textPrimary
                )
                ForEach(effects) { effect in
                    let isCut = (effect.flat != 0 ? effect.flat : effect.percent) < 0
                    breakdownChip(
                        amount: BoardEventText.rentChange(effect),
                        label: [BoardEventText.source(of: effect), BoardEventText.remaining(effect, round: state.round)]
                            .compactMap { $0 }
                            .joined(separator: " · "),
                        tint: isCut ? Lux.down : Lux.up
                    )
                }
            }
        }
    }

    private func breakdownChip(amount: String, label: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Text(amount)
                .font(.app(.footnote, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(tint)
            Text(label)
                .font(.app(.footnote))
                .foregroundStyle(Lux.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: Capsule())
    }

    // MARK: QR

    private func qrCard(for property: Property) -> some View {
        VStack(spacing: 14) {
            QRCodeImage(payload: QRPaymentRequest.rent(propertyID: property.id).payload)
                .frame(maxWidth: 230)

            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(property.colorGroup.swatch)
                    .frame(width: 14, height: 4)
                Text(property.name)
                    .font(.app(.subheadline, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(Color(white: 0.1))
        }
        .padding(22)
        .background(.white, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
    }

    private func paymentStatus(rentIsNegative: Bool) -> some View {
        VStack(spacing: 10) {
            Group {
                if let settledAmount {
                    Label(
                        settledAmount < 0 ? "Pagaste \(currency(-settledAmount))" : "Recibiste \(currency(settledAmount))",
                        systemImage: "checkmark.circle.fill"
                    )
                    .foregroundStyle(settledAmount < 0 ? Lux.textPrimary : Lux.up)
                    .transition(.scale.combined(with: .opacity))
                } else {
                    Label(rentIsNegative ? "Esperando a quien caiga" : "Esperando el pago", systemImage: "wave.3.right")
                        .symbolEffect(.variableColor.iterative, options: .repeat(.continuous))
                        .foregroundStyle(Lux.textSecondary)
                }
            }
            .font(.app(.subheadline, weight: .semibold))
            .monospacedDigit()
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: Capsule())

            Text(rentIsNegative
                 ? "Quien cae escanea el código con «Pagar con QR» y recibe tu pago."
                 : "Quien paga abre «Pagar con QR» y escanea el código.")
                .font(.app(.footnote))
                .foregroundStyle(Lux.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: Levels

    /// Any shareholder can level up; only whoever manages the property levels it down.
    @ViewBuilder
    private func levelControls(for property: Property, playerID: UUID, in state: GameState) -> some View {
        let canLevelUp = property.constructionLevel < Property.maximumLevel
        let canLevelDown = property.ownerID == playerID && property.constructionLevel > 0

        if canLevelUp || canLevelDown {
            VStack(spacing: 10) {
                if canLevelUp {
                    levelUpCoverageNotes(for: property, playerID: playerID, in: state)
                }

                GlassEffectContainer(spacing: 12) {
                    HStack(spacing: 12) {
                        if canLevelDown {
                            let levelCost = Property.levelUpCost(
                                purchasePrice: property.purchasePrice,
                                level: property.constructionLevel
                            )
                            Button {
                                model.levelDown(propertyID: property.id)
                            } label: {
                                levelButtonLabel("Bajar nivel", detail: "Devuelve \(currency(levelCost / 2))", systemImage: "arrow.down")
                            }
                        }

                        if canLevelUp {
                            let nextLevel = property.constructionLevel + 1
                            let cost = Property.levelUpCost(purchasePrice: property.purchasePrice, level: nextLevel)
                            Button {
                                model.levelUp(propertyID: property.id)
                            } label: {
                                levelButtonLabel("Subir a nivel \(nextLevel)", detail: "Cuesta \(currency(cost))", systemImage: "arrow.up")
                            }
                        }
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 4)
            .frame(maxWidth: 520)
        }
    }

    private func levelButtonLabel(_ title: String, detail: String, systemImage: String) -> some View {
        VStack(spacing: 2) {
            Label(title, systemImage: systemImage)
                .font(.app(.subheadline, weight: .semibold))
            Text(detail)
                .font(.app(.caption))
                .monospacedDigit()
                .foregroundStyle(Lux.textSecondary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
    }

    /// Whose part the local player would cover on leveling up, and the shares they would
    /// take for it (GAME_RULES section 4.3).
    @ViewBuilder
    private func levelUpCoverageNotes(for property: Property, playerID: UUID, in state: GameState) -> some View {
        if let plan = try? GameRules.levelUpPlan(in: state, propertyID: property.id, playerID: playerID),
           !plan.coverages.isEmpty {
            ForEach(plan.coverages, id: \.playerID) { coverage in
                Text("\(state.playerName(coverage.playerID)) no puede pagar su parte (\(currency(coverage.amount))). Si subes de nivel la pagas tú y te llevas \(percentage(coverage.shares)) de sus acciones; puede recuperarlas devolviéndote ese dinero.")
                    .font(.app(.footnote))
                    .foregroundStyle(Lux.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: Helpers

    private func rentAmount(for property: Property, in state: GameState) -> Int {
        guard let ownerID = property.ownerID else {
            return property.baseRent
        }
        return (try? GameRules.rentAmount(for: property, in: state, ownerID: ownerID)) ?? property.baseRent
    }

    private func currency(_ amount: Int) -> String {
        amount < 0 ? "−$\(-amount)" : "$\(amount)"
    }
}
