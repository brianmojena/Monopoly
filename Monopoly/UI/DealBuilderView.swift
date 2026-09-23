import SwiftUI

struct DealBuilderView: View {
    enum Mode {
        case deal
        case openOffer
    }

    let mode: Mode
    @ObservedObject var model: GameSessionModel
    @Environment(\.dismiss) private var dismiss

    @State private var lines = [DraftTransfer()]

    var body: some View {
        Group {
            if let state = model.gameState, let localPlayerID = model.localPlayerID {
                Form {
                    Section {
                        Text(introText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
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
                        .disabled(buildTransfers(localPlayerID: localPlayerID) == nil)
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
                .font(.caption)
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

    private func buildTransfers(localPlayerID: UUID) -> [DealTransfer]? {
        var transfers: [DealTransfer] = []
        for line in lines {
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

    private func propose(localPlayerID: UUID) {
        guard let transfers = buildTransfers(localPlayerID: localPlayerID) else {
            return
        }
        model.proposeDeal(MarketDeal(proposerID: localPlayerID, transfers: transfers))
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
}
