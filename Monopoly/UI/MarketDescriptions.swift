import Foundation

extension GameState {
    func playerName(_ playerID: UUID) -> String {
        players.first(where: { $0.id == playerID })?.name ?? "Jugador"
    }

    func propertyName(_ propertyID: UUID) -> String {
        properties.first(where: { $0.id == propertyID })?.name ?? "Propiedad"
    }

    /// "Ana" for a sole owner, "Ana 60% · Luis 40%" for shareholders, or "Sin dueño".
    func ownershipSummary(of property: Property) -> String {
        guard property.isOwned else {
            return "Sin dueño"
        }
        guard property.ownership.count > 1 else {
            return playerName(property.ownership[0].playerID)
        }
        return property.ownership
            .map { "\(playerName($0.playerID)) \(percentage($0.shares))" }
            .joined(separator: " · ")
    }

    func partyName(_ party: DealParty) -> String {
        switch party {
        case let .player(playerID):
            return playerName(playerID)
        case .taker:
            return "Quien acepte"
        }
    }

    func describe(_ asset: DealAsset) -> String {
        switch asset {
        case let .money(amount):
            return "$\(amount)"
        case let .shares(propertyID, count):
            return "\(percentage(count)) de \(propertyName(propertyID))"
        }
    }

    func describe(_ transfer: DealTransfer) -> String {
        "\(partyName(transfer.from)) → \(partyName(transfer.to)): \(describe(transfer.asset))"
    }

    func describe(_ investment: RentInvestment) -> String {
        "\(playerName(investment.investorID)) invierte en \(propertyName(investment.propertyID)) de \(playerName(investment.recipientID)) por \(investment.percentage)% de su renta"
    }

    func describe(_ purchase: SharedPurchase) -> [String] {
        let price = properties.first(where: { $0.id == purchase.propertyID })?.purchasePrice ?? 0
        let costs = GameRules.split(price, among: purchase.buyers)
        return purchase.buyers.map { buyer in
            let cost = costs.first(where: { $0.playerID == buyer.playerID })?.amount ?? 0
            return "\(playerName(buyer.playerID)) compra \(percentage(buyer.shares)) por $\(cost)"
        }
    }
}

func percentage(_ shares: Int) -> String {
    "\(shares * 100 / Property.totalShares)%"
}
