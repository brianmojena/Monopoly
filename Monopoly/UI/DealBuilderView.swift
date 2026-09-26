import SwiftUI

struct DealBuilderView: View {
    enum Mode: Equatable {
        case deal
        case openOffer
    }

    let mode: Mode
    @ObservedObject var model: GameSessionModel
    @Environment(\.dismiss) private var dismiss

    @State private var lines = [DraftTransfer()]
    @State private var investmentEnabled = false
    @State private var investmentRecipientID: UUID?
    @State private var investmentPropertyID: UUID?
    @State private var investmentAmountText = ""
    @State private var investmentPercentage = 10
    @State private var loan = DraftLoan()

    var body: some View {
        Group {
            if let state = model.gameState, let localPlayerID = model.localPlayerID {
                Form {
                    Section {
                        Text(introText)
                            .font(.app(.footnote))
                            .foregroundStyle(.secondary)
                    }

                    if case .deal = mode {
                        loanSection(state: state, localPlayerID: localPlayerID)
                        if !loan.isEnabled {
                            investmentSection(state: state, localPlayerID: localPlayerID)
                        }
                    }

                    ForEach($lines) { $line in
                        lineSection(line: $line, state: state, localPlayerID: localPlayerID)
                    }

                    Section {
                        Button {
                            lines.append(DraftTransfer())
                        } label: {
                            Label("Añadir movimiento", systemImage: "plus.circle")
                        }
                    }

                    Section {
                        Button(mode == .deal ? "Proponer trato" : "Publicar oferta") {
                            propose(localPlayerID: localPlayerID)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(draftDeal(localPlayerID: localPlayerID) == nil)
                    } footer: {
                        Text(mode == .deal
                             ? "Se ejecuta cuando todos los jugadores del trato lo acepten. Tú lo aceptas al proponerlo."
                             : "Se ejecuta en cuanto otro jugador la acepte.")
                    }
                }
            } else {
                ProgressView("Cargando partida…")
            }
        }
        .navigationTitle(mode == .deal ? "Nuevo trato" : "Oferta abierta")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }

    private var introText: String {
        switch mode {
        case .deal:
            return "Cada movimiento pasa dinero o acciones (en pasos de 10%) de un jugador a otro. Puedes incluir a tantos jugadores como quieras, por ejemplo: Ana da 30% de una calle a Luis, Luis paga $200 a Eva y Eva paga $150 a Ana."
        case .openOffer:
            return "Indica qué das y qué pides. Cualquier jugador puede aceptar la oferta y el trato se hace con él."
        }
    }

    @ViewBuilder
    private func lineSection(line: Binding<DraftTransfer>, state: GameState, localPlayerID: UUID) -> some View {
        Section {
            switch mode {
            case .deal:
                partyPicker("Da", selection: line.fromID, state: state)
                partyPicker("Recibe", selection: line.toID, state: state)
            case .openOffer:
                Picker("Dirección", selection: line.proposerGives) {
                    Text("Doy").tag(true)
                    Text("Pido").tag(false)
                }
                .pickerStyle(.segmented)
            }

            Picker("Qué", selection: line.isMoney) {
                Text("Dinero").tag(true)
                Text("Acciones").tag(false)
            }
            .pickerStyle(.segmented)

            if line.wrappedValue.isMoney {
                TextField("Monto", text: line.amountText)
#if os(iOS)
                    .keyboardType(.numberPad)
#endif
            } else {
                sharesEditor(line: line, state: state, localPlayerID: localPlayerID)
            }

            if lines.count > 1 {
                Button("Quitar movimiento", role: .destructive) {
                    let lineID = line.wrappedValue.id
                    lines.removeAll { $0.id == lineID }
                }
            }
        } header: {
            Text("Movimiento \((lines.firstIndex(where: { $0.id == line.wrappedValue.id }) ?? 0) + 1)")
        }
    }

    private func partyPicker(_ title: String, selection: Binding<UUID?>, state: GameState) -> some View {
        Picker(title, selection: selection) {
            Text("Elige jugador").tag(UUID?.none)
            ForEach(state.players.filter { $0.status == .active }) { player in
                Text(player.name).tag(Optional(player.id))
            }
        }
    }

    private func investmentSection(state: GameState, localPlayerID: UUID) -> some View {
        Section {
            Toggle("Incluir inversión de renta", isOn: $investmentEnabled)

            if investmentEnabled {
                Picker("Receptor", selection: $investmentRecipientID) {
                    Text("Elige jugador").tag(UUID?.none)
                    ForEach(state.players.filter { $0.status == .active && $0.id != localPlayerID }) { player in
                        Text(player.name).tag(Optional(player.id))
                    }
                }

                let properties = investmentProperties(state: state)
                Picker("Propiedad", selection: $investmentPropertyID) {
                    Text("Elige propiedad").tag(UUID?.none)
                    ForEach(properties) { property in
                        Text(property.name).tag(Optional(property.id))
                    }
                }

                TextField("Pago único", text: $investmentAmountText)
#if os(iOS)
                    .keyboardType(.numberPad)
#endif

                Stepper(value: $investmentPercentage, in: 1...100) {
                    Text("Parte de la renta: \(investmentPercentage)%")
                }

                if let property = properties.first(where: { $0.id == investmentPropertyID }) {
                    Text(state.ownershipSummary(of: property))
                        .font(.app(.caption))
                        .foregroundStyle(.secondary)
                }

                Text("El pago se añade automáticamente como parte del trato. La inversión dura hasta que ambos acuerden cancelarla.")
                    .font(.app(.caption))
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Inversión")
        }
    }

    private func loanSection(state: GameState, localPlayerID: UUID) -> some View {
        Section {
            Toggle("Incluir préstamo", isOn: $loan.isEnabled)

            if loan.isEnabled {
                Picker("Tú", selection: $loan.localPlayerLends) {
                    Text("Prestas").tag(true)
                    Text("Pides prestado").tag(false)
                }
                .pickerStyle(.segmented)

                Picker(loan.localPlayerLends ? "Le prestas a" : "Te presta", selection: $loan.otherPlayerID) {
                    Text("Elige jugador").tag(UUID?.none)
                    ForEach(state.players.filter { $0.status == .active && $0.id != localPlayerID }) { player in
                        Text(player.name).tag(Optional(player.id))
                    }
                }

                TextField("Monto prestado", text: $loan.principalText)
#if os(iOS)
                    .keyboardType(.numberPad)
#endif

                Stepper(value: $loan.interestPercentage, in: PlayerLoan.interestRange, step: 5) {
                    Text("Interés: \(loan.interestPercentage)%")
                }

                Toggle("Cuota en cada GO", isOn: $loan.hasGoPayment)
                if loan.hasGoPayment {
                    TextField("Cuota", text: $loan.goPaymentText)
#if os(iOS)
                        .keyboardType(.numberPad)
#endif
                }

                Toggle("% de sus rentas", isOn: $loan.hasRentPercentage)
                if loan.hasRentPercentage {
                    Stepper(value: $loan.rentPercentage, in: PlayerLoan.rentPercentageRange, step: 5) {
                        Text("\(loan.rentPercentage)% de lo que cobre de renta")
                    }
                }

                Toggle("Plazo", isOn: $loan.hasTerm)
                if loan.hasTerm {
                    Stepper(value: $loan.termRounds, in: 1...30) {
                        Text("\(loan.termRounds) \(loan.termRounds == 1 ? "ronda" : "rondas") (vence al final de la ronda \(state.round + loan.termRounds))")
                    }

                    Toggle("Garantía en acciones", isOn: $loan.hasCollateral)
                    if loan.hasCollateral {
                        collateralEditor(state: state, localPlayerID: localPlayerID)
                    }
                }

                if let draft = loan.makeLoan(localPlayerID: localPlayerID, round: state.round) {
                    Text("Devolverá $\(draft.totalDebt) en total.")
                        .font(.app(.subheadline, weight: .semibold))
                } else {
                    Text("Elige el jugador, el monto y al menos una forma de devolverlo: cuota en GO, % de rentas o plazo.")
                        .font(.app(.caption))
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Préstamo")
        } footer: {
            if loan.isEnabled {
                Text("El monto se paga al aceptarse el trato. Con plazo, al terminar la última ronda se cobra lo que falte; si no alcanza, quien presta se queda con la garantía o el préstamo queda vencido y cada GO paga todo lo que pueda. Se puede pagar antes, y quien presta puede perdonarlo.")
            }
        }
    }

    @ViewBuilder
    private func collateralEditor(state: GameState, localPlayerID: UUID) -> some View {
        let borrowerID = loan.localPlayerLends ? loan.otherPlayerID : localPlayerID
        let properties = borrowerID.map { id in state.properties.filter { $0.shares(of: id) > 0 } } ?? []
        Picker("Propiedad", selection: $loan.collateralPropertyID) {
            Text("Elige propiedad").tag(UUID?.none)
            ForEach(properties) { property in
                Text(property.name).tag(Optional(property.id))
            }
        }
        if let borrowerID, let property = properties.first(where: { $0.id == loan.collateralPropertyID }) {
            let free = property.shares(of: borrowerID)
                - GameRules.pledgedShares(of: borrowerID, in: property.id, state: state)
            let maximum = max(1, free)
            Stepper(value: $loan.collateralShares, in: 1...maximum) {
                Text("\(percentage(min(loan.collateralShares, maximum))) de \(percentage(max(0, free))) libre")
            }
        }
    }

    private func investmentProperties(state: GameState) -> [Property] {
        guard let recipientID = investmentRecipientID else {
            return []
        }
        return state.properties.filter { $0.shares(of: recipientID) > 0 }
    }

    @ViewBuilder
    private func sharesEditor(line binding: Binding<DraftTransfer>, state: GameState, localPlayerID: UUID) -> some View {
        let line = binding.wrappedValue
        let properties = availableProperties(for: line, state: state, localPlayerID: localPlayerID)
        Picker("Propiedad", selection: binding.propertyID) {
            Text("Elige propiedad").tag(UUID?.none)
            ForEach(properties) { property in
                Text(property.name).tag(Optional(property.id))
            }
        }

        if let property = properties.first(where: { $0.id == line.propertyID }) {
            let maximum = max(1, availableShares(of: property, for: line, localPlayerID: localPlayerID))
            Stepper(value: binding.shareCount, in: 1...maximum) {
                Text("\(percentage(min(line.shareCount, maximum))) de \(percentage(maximum)) disponible")
            }
            Text(state.ownershipSummary(of: property))
                .font(.app(.caption))
                .foregroundStyle(.secondary)
        }
    }

    /// Properties the giving side can hand over. For an open offer that asks for shares,
    /// any property with shares held by someone other than the proposer qualifies.
    private func availableProperties(for line: DraftTransfer, state: GameState, localPlayerID: UUID) -> [Property] {
        switch mode {
        case .deal:
            guard let fromID = line.fromID else {
                return []
            }
            return state.properties.filter { $0.shares(of: fromID) > 0 }
        case .openOffer:
            if line.proposerGives {
                return state.properties.filter { $0.shares(of: localPlayerID) > 0 }
            }
            return state.properties.filter {
                $0.isOwned && $0.shares(of: localPlayerID) < Property.totalShares
            }
        }
    }

    private func availableShares(of property: Property, for line: DraftTransfer, localPlayerID: UUID) -> Int {
        switch mode {
        case .deal:
            return line.fromID.map { property.shares(of: $0) } ?? 0
        case .openOffer:
            let mine = property.shares(of: localPlayerID)
            return line.proposerGives ? mine : Property.totalShares - mine
        }
    }

    private func buildTransfers(localPlayerID: UUID, skippingEmptyLines: Bool = false) -> [DealTransfer]? {
        var transfers: [DealTransfer] = []
        for line in lines {
            if skippingEmptyLines && line.isEmpty {
                continue
            }
            let asset: DealAsset
            if line.isMoney {
                guard let amount = Int(line.amountText), amount > 0 else {
                    return nil
                }
                asset = .money(amount)
            } else {
                guard let propertyID = line.propertyID else {
                    return nil
                }
                asset = .shares(propertyID: propertyID, count: line.shareCount)
            }

            switch mode {
            case .deal:
                guard let fromID = line.fromID, let toID = line.toID, fromID != toID else {
                    return nil
                }
                transfers.append(DealTransfer(from: .player(fromID), to: .player(toID), asset: asset))
            case .openOffer:
                let me = DealParty.player(localPlayerID)
                transfers.append(line.proposerGives
                    ? DealTransfer(from: me, to: .taker, asset: asset)
                    : DealTransfer(from: .taker, to: me, asset: asset))
            }
        }
        return transfers
    }

    private func draftDeal(localPlayerID: UUID) -> MarketDeal? {
        var transfers = buildTransfers(
            localPlayerID: localPlayerID,
            skippingEmptyLines: investmentEnabled || loan.isEnabled
        ) ?? []
        var proposedInvestment: RentInvestment?
        var proposedLoan: PlayerLoan?

        if loan.isEnabled {
            guard let round = model.gameState?.round,
                  let draft = loan.makeLoan(localPlayerID: localPlayerID, round: round) else {
                return nil
            }
            proposedLoan = draft
            transfers.append(DealTransfer(
                from: .player(draft.lenderID),
                to: .player(draft.borrowerID),
                asset: .money(draft.principal)
            ))
        } else if investmentEnabled {
            guard let recipientID = investmentRecipientID,
                  recipientID != localPlayerID,
                  let propertyID = investmentPropertyID,
                  let amount = Int(investmentAmountText),
                  amount > 0,
                  (1...100).contains(investmentPercentage) else {
                return nil
            }
            proposedInvestment = RentInvestment(
                investorID: localPlayerID,
                recipientID: recipientID,
                propertyID: propertyID,
                percentage: investmentPercentage
            )
            transfers.append(DealTransfer(
                from: .player(localPlayerID),
                to: .player(recipientID),
                asset: .money(amount)
            ))
        }

        guard !transfers.isEmpty else {
            return nil
        }
        return MarketDeal(
            proposerID: localPlayerID,
            transfers: transfers,
            proposedInvestment: proposedInvestment,
            proposedLoan: proposedLoan
        )
    }

    private func propose(localPlayerID: UUID) {
        guard let deal = draftDeal(localPlayerID: localPlayerID) else {
            return
        }
        model.proposeDeal(deal)
        dismiss()
    }
}

private struct DraftTransfer: Identifiable {
    let id = UUID()
    var fromID: UUID?
    var toID: UUID?
    var proposerGives = true
    var isMoney = true
    var amountText = ""
    var propertyID: UUID?
    var shareCount = 1

    var isEmpty: Bool {
        fromID == nil && toID == nil && amountText.isEmpty && propertyID == nil
    }
}

private struct DraftLoan {
    var isEnabled = false
    var localPlayerLends = true
    var otherPlayerID: UUID?
    var principalText = ""
    var interestPercentage = 10
    var hasGoPayment = true
    var goPaymentText = ""
    var hasRentPercentage = false
    var rentPercentage = 20
    var hasTerm = false
    var termRounds = 5
    var hasCollateral = false
    var collateralPropertyID: UUID?
    var collateralShares = 1

    /// The loan these choices describe, or nil while something is missing.
    func makeLoan(localPlayerID: UUID, round: Int) -> PlayerLoan? {
        guard let otherPlayerID, let principal = Int(principalText), principal > 0 else {
            return nil
        }
        var goPayment: Int?
        if hasGoPayment {
            guard let amount = Int(goPaymentText), amount > 0 else {
                return nil
            }
            goPayment = amount
        }
        var collateral: LoanCollateral?
        if hasTerm, hasCollateral {
            guard let collateralPropertyID else {
                return nil
            }
            collateral = LoanCollateral(propertyID: collateralPropertyID, shares: collateralShares)
        }
        let rent = hasRentPercentage ? rentPercentage : nil
        let dueRound = hasTerm ? round + termRounds : nil
        guard goPayment != nil || rent != nil || dueRound != nil else {
            return nil
        }
        return PlayerLoan(
            lenderID: localPlayerLends ? localPlayerID : otherPlayerID,
            borrowerID: localPlayerLends ? otherPlayerID : localPlayerID,
            principal: principal,
            interestPercentage: interestPercentage,
            goPayment: goPayment,
            rentPercentage: rent,
            dueRound: dueRound,
            collateral: collateral
        )
    }
}
