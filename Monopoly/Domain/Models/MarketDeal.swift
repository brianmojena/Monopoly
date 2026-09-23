import Foundation

/// Who is on each side of a transfer. `taker` stands for whoever accepts an open
/// offer; it is replaced by that player when the deal is settled.
enum DealParty: Codable, Hashable {
    case player(UUID)
    case taker

    var playerID: UUID? {
        guard case let .player(playerID) = self else {
            return nil
        }
        return playerID
    }
}

enum DealAsset: Codable, Equatable {
    case money(Int)
    case shares(propertyID: UUID, count: Int)
}

struct DealTransfer: Codable, Equatable {
    var from: DealParty
    var to: DealParty
    var asset: DealAsset
}

/// Several players buying an unowned property from the bank together, each paying
/// the price in proportion to their shares.
struct SharedPurchase: Codable, Equatable {
    let propertyID: UUID
    let buyers: [PropertyShare]
}

struct MarketDeal: Identifiable, Codable, Equatable {
    let id: UUID
    let proposerID: UUID
    var transfers: [DealTransfer]
    var sharedPurchase: SharedPurchase?
    var acceptedBy: Set<UUID>

    init(
        id: UUID = UUID(),
        proposerID: UUID,
        transfers: [DealTransfer] = [],
        sharedPurchase: SharedPurchase? = nil,
        acceptedBy: Set<UUID> = []
    ) {
        self.id = id
        self.proposerID = proposerID
        self.transfers = transfers
        self.sharedPurchase = sharedPurchase
        self.acceptedBy = acceptedBy
    }

    var isOpenOffer: Bool {
        transfers.contains { $0.from == .taker || $0.to == .taker }
    }

    /// Everyone who must accept before the deal settles (the taker of an open offer
    /// accepts by taking it).
    var participantIDs: Set<UUID> {
        var ids: Set<UUID> = [proposerID]
        for transfer in transfers {
            if let from = transfer.from.playerID { ids.insert(from) }
            if let to = transfer.to.playerID { ids.insert(to) }
        }
        for buyer in sharedPurchase?.buyers ?? [] {
            ids.insert(buyer.playerID)
        }
        return ids
    }

    var pendingPlayerIDs: Set<UUID> {
        participantIDs.subtracting(acceptedBy)
    }

    func resolvingTaker(_ takerID: UUID) -> MarketDeal {
        var resolved = self
        resolved.transfers = transfers.map { transfer in
            DealTransfer(
                from: transfer.from == .taker ? .player(takerID) : transfer.from,
                to: transfer.to == .taker ? .player(takerID) : transfer.to,
                asset: transfer.asset
            )
        }
        return resolved
    }
}
