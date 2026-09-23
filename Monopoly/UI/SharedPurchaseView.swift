import SwiftUI

struct SharedPurchaseView: View {
    let propertyID: UUID
    @ObservedObject var model: GameSessionModel
    @Environment(\.dismiss) private var dismiss

    @State private var shares: [UUID: Int] = [:]

    var body: some View {
        Group {
            if let state = model.gameState,
               let localPlayerID = model.localPlayerID,
               let property = state.properties.first(where: { $0.id == propertyID }) {
                let buyers = buyers(in: state, localPlayerID: localPlayerID)
                let costs = GameRules.split(property.purchasePrice, among: buyers)
                Form {
                    Section {
                        ForEach(state.players.filter { $0.status == .active }) { player in
                            Stepper(value: shareBinding(for: player.id, localPlayerID: localPlayerID), in: 0...Property.totalShares) {
                                VStack(alignment: .leading) {
                                    Text(player.id == localPlayerID ? "\(player.name) (tú)" : player.name)
                                    Text(costText(for: player.id, costs: costs))
                                        .font(.app(.caption))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } header: {
                        Text("Precio $\(property.purchasePrice) · \(percentage(totalShares(localPlayerID: localPlayerID))) de 100%")
                    } footer: {
                        Text("Cada jugador paga la parte del precio que corresponde a su %. La compra se hace cuando todos los compradores aceptan en el Mercado. Quien tenga más % administra la propiedad.")
                    }

                    Section {
                        Button("Proponer compra compartida") {
                            propose(buyers: buyers, localPlayerID: localPlayerID)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!isValid(buyers: buyers, localPlayerID: localPlayerID))
                    } footer: {
                        if totalShares(localPlayerID: localPlayerID) != Property.totalShares {
                            Text("Reparte exactamente el 100% entre al menos dos jugadores, incluido tú.")
                        }
                    }
                }
                .navigationTitle(property.name)
            } else {
                ProgressView("Cargando propiedad…")
            }
        }
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }

    private func shareBinding(for playerID: UUID, localPlayerID: UUID) -> Binding<Int> {
        Binding(
            get: { currentShares(for: playerID, localPlayerID: localPlayerID) },
            set: { shares[playerID] = $0 }
        )
    }

    /// The proposer starts with 50% so the screen opens halfway to a valid split.
    private func currentShares(for playerID: UUID, localPlayerID: UUID) -> Int {
        shares[playerID] ?? (playerID == localPlayerID ? Property.totalShares / 2 : 0)
    }

    private func totalShares(localPlayerID: UUID) -> Int {
        guard let state = model.gameState else {
            return 0
        }
        return state.players.reduce(0) { $0 + currentShares(for: $1.id, localPlayerID: localPlayerID) }
    }

    private func buyers(in state: GameState, localPlayerID: UUID) -> [PropertyShare] {
        let proposerFirst = state.players.filter { $0.id == localPlayerID }
            + state.players.filter { $0.id != localPlayerID }
        return proposerFirst
            .filter { $0.status == .active }
            .map { PropertyShare(playerID: $0.id, shares: currentShares(for: $0.id, localPlayerID: localPlayerID)) }
            .filter { $0.shares > 0 }
    }

    private func isValid(buyers: [PropertyShare], localPlayerID: UUID) -> Bool {
        buyers.count >= 2
            && buyers.reduce(0, { $0 + $1.shares }) == Property.totalShares
            && buyers.contains(where: { $0.playerID == localPlayerID })
    }

    private func costText(for playerID: UUID, costs: [(playerID: UUID, amount: Int)]) -> String {
        guard let cost = costs.first(where: { $0.playerID == playerID })?.amount else {
            return "No participa"
        }
        return "Paga $\(cost)"
    }

    private func propose(buyers: [PropertyShare], localPlayerID: UUID) {
        model.proposeDeal(MarketDeal(
            proposerID: localPlayerID,
            sharedPurchase: SharedPurchase(propertyID: propertyID, buyers: buyers)
        ))
        dismiss()
    }
}
