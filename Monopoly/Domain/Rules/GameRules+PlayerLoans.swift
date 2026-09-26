import Foundation

// Loans between players (GAME_RULES section 4.9). A loan is proposed inside a Market
// deal and then repaid by its terms: a fixed payment at every GO, a cut of the rent
// the borrower collects, and whatever is left when its last round ends.
extension GameRules {
    // MARK: Proposing

    static func validateProposedLoan(_ loan: PlayerLoan, in deal: MarketDeal, state: GameState) throws {
        guard !deal.isOpenOffer,
              deal.proposedInvestment == nil,
              deal.cancelInvestment == nil,
              deal.sharedPurchase == nil,
              loan.lenderID != loan.borrowerID,
              deal.participantIDs == [loan.lenderID, loan.borrowerID],
              !state.playerLoans.contains(where: { $0.id == loan.id }) else {
            throw GameRuleError.invalidDeal
        }
        try requireActivePlayer(in: state, playerID: loan.lenderID)
        try requireActivePlayer(in: state, playerID: loan.borrowerID)

        guard loan.principal > 0,
              PlayerLoan.interestRange.contains(loan.interestPercentage),
              loan.remainingDebt == loan.totalDebt,
              !loan.isOverdue,
              loan.goPayment.map({ $0 > 0 }) ?? true,
              loan.rentPercentage.map(PlayerLoan.rentPercentageRange.contains) ?? true,
              loan.goPayment != nil || loan.rentPercentage != nil || loan.dueRound != nil else {
            throw GameRuleError.invalidLoanTerms
        }
        if let dueRound = loan.dueRound, dueRound < state.round {
            throw GameRuleError.invalidLoanTerms
        }

        if let collateral = loan.collateral {
            guard (1...Property.totalShares).contains(collateral.shares) else {
                throw GameRuleError.invalidLoanTerms
            }
            guard let property = state.properties.first(where: { $0.id == collateral.propertyID }) else {
                throw GameRuleError.propertyNotFound(collateral.propertyID)
            }
            let free = property.shares(of: loan.borrowerID)
                - pledgedShares(of: loan.borrowerID, in: collateral.propertyID, state: state)
            guard free >= collateral.shares else {
                throw GameRuleError.notEnoughShares(propertyID: collateral.propertyID, playerID: loan.borrowerID)
            }
        }

        // The lender hands over the principal as the deal's one money transfer between them.
        let principalTransfers = deal.transfers.filter {
            guard $0.from == .player(loan.lenderID), $0.to == .player(loan.borrowerID),
                  case .money = $0.asset else {
                return false
            }
            return true
        }
        guard principalTransfers.count == 1,
              principalTransfers[0].asset == .money(loan.principal) else {
            throw GameRuleError.invalidDeal
        }
    }

    /// Shares of `propertyID` that `playerID` pledged on the loans they owe.
    static func pledgedShares(of playerID: UUID, in propertyID: UUID, state: GameState) -> Int {
        state.playerLoans
            .filter { $0.borrowerID == playerID && $0.collateral?.propertyID == propertyID }
            .reduce(0) { $0 + ($1.collateral?.shares ?? 0) }
    }

    /// Pledged shares can't leave in a deal: after one settles, every player who gave
    /// shares must still hold what they pledged, the new loan's collateral included.
    static func requireCollateralHeld(
        afterSharesLeft departures: [(propertyID: UUID, playerID: UUID)],
        newLoan: PlayerLoan?,
        in state: GameState
    ) throws {
        var checks = departures
        if let loan = newLoan, let collateral = loan.collateral {
            checks.append((collateral.propertyID, loan.borrowerID))
        }
        for check in checks {
            let held = state.properties.first(where: { $0.id == check.propertyID })?.shares(of: check.playerID) ?? 0
            var pledged = pledgedShares(of: check.playerID, in: check.propertyID, state: state)
            if let loan = newLoan, loan.borrowerID == check.playerID, loan.collateral?.propertyID == check.propertyID {
                pledged += loan.collateral?.shares ?? 0
            }
            if held < pledged {
                throw GameRuleError.notEnoughShares(propertyID: check.propertyID, playerID: check.playerID)
            }
        }
    }

    // MARK: Repaying

    /// Moves up to `amount` from the borrower to the lender, never below a zero balance,
    /// and returns what was paid. Paid-off loans stay until `removePaidOffLoans`.
    @discardableResult
    private static func repay(loanAt index: Int, upTo amount: Int, in state: inout GameState) -> Int {
        let loan = state.playerLoans[index]
        let balance = state.players.first(where: { $0.id == loan.borrowerID })?.balance ?? 0
        let paid = min(amount, loan.remainingDebt, balance)
        guard paid > 0 else {
            return 0
        }
        credit(-paid, to: loan.borrowerID, in: &state)
        credit(paid, to: loan.lenderID, in: &state)
        state.playerLoans[index].remainingDebt -= paid
        applyLifeTrigger(
            .loanPaymentReceived(lenderID: loan.lenderID, paidOff: state.playerLoans[index].remainingDebt <= 0),
            in: &state
        )
        return paid
    }

    private static func removePaidOffLoans(in state: inout GameState) {
        state.playerLoans.removeAll { $0.remainingDebt <= 0 }
    }

    /// The borrower pays any part of a loan early.
    static func payPlayerLoan(
        in state: GameState,
        playerID: UUID,
        loanID: UUID,
        amount: Int
    ) throws -> GameState {
        try requireActivePlayer(in: state, playerID: playerID)
        guard let index = state.playerLoans.firstIndex(where: { $0.id == loanID && $0.borrowerID == playerID }) else {
            throw GameRuleError.playerLoanNotFound(loanID)
        }
        let loan = state.playerLoans[index]
        guard amount > 0, amount <= loan.remainingDebt else {
            throw GameRuleError.invalidAmount(amount)
        }
        let balance = state.players.first(where: { $0.id == playerID })?.balance ?? 0
        guard balance >= amount else {
            throw GameRuleError.insufficientFunds(playerID: playerID, required: amount, available: balance)
        }

        var updatedState = state
        repay(loanAt: index, upTo: amount, in: &updatedState)
        removePaidOffLoans(in: &updatedState)
        return updatedState
    }

    /// The lender cancels whatever is still owed.
    static func forgivePlayerLoan(in state: GameState, playerID: UUID, loanID: UUID) throws -> GameState {
        try requireActivePlayer(in: state, playerID: playerID)
        guard state.playerLoans.contains(where: { $0.id == loanID && $0.lenderID == playerID }) else {
            throw GameRuleError.playerLoanNotFound(loanID)
        }
        var updatedState = state
        updatedState.playerLoans.removeAll { $0.id == loanID }
        applyLifeTrigger(.loanLost(lenderID: playerID), in: &updatedState)
        return updatedState
    }

    /// Every loan the player owes takes its GO payment, oldest first, after the salary
    /// and the credit card installments.
    static func payPlayerLoansAtGo(for playerID: UUID, in state: inout GameState) {
        for index in state.playerLoans.indices where state.playerLoans[index].borrowerID == playerID {
            repay(loanAt: index, upTo: state.playerLoans[index].goPaymentDue, in: &state)
        }
        removePaidOffLoans(in: &state)
    }

    /// Sends each loan's cut of rent the borrower just collected to its lender and
    /// returns what the borrower keeps. Every cut is taken from the same collected
    /// amount, oldest loan first, and never more than is left.
    static func takeLoanRentCuts(from collected: Int, collectedBy playerID: UUID, in state: inout GameState) -> Int {
        var kept = collected
        for index in state.playerLoans.indices {
            let loan = state.playerLoans[index]
            guard loan.borrowerID == playerID, let percentage = loan.rentPercentage else {
                continue
            }
            let cut = min(collected * percentage / 100, loan.remainingDebt, kept)
            guard cut > 0 else { continue }
            credit(cut, to: loan.lenderID, in: &state)
            state.playerLoans[index].remainingDebt -= cut
            kept -= cut
            applyLifeTrigger(
                .loanPaymentReceived(lenderID: loan.lenderID, paidOff: state.playerLoans[index].remainingDebt <= 0),
                in: &state
            )
        }
        removePaidOffLoans(in: &state)
        return kept
    }

    /// Loans whose last round just ended take what is left. Unpaid, the lender keeps the
    /// collateral and the rest is cancelled; without collateral the loan goes overdue.
    static func settleDueLoans(afterRound round: Int, in state: inout GameState) {
        var tookCollateral = false
        for index in state.playerLoans.indices {
            let loan = state.playerLoans[index]
            guard !loan.isOverdue, loan.dueRound == round else {
                continue
            }
            repay(loanAt: index, upTo: loan.remainingDebt, in: &state)
            guard state.playerLoans[index].remainingDebt > 0 else {
                continue
            }
            if takeCollateral(of: loan, in: &state) {
                state.playerLoans[index].remainingDebt = 0
                tookCollateral = true
                applyLifeTrigger(.collateralTaken(lenderID: loan.lenderID), in: &state)
            } else {
                state.playerLoans[index].isOverdue = true
            }
        }
        removePaidOffLoans(in: &state)
        if tookCollateral {
            reindexPropertyIDs(in: &state)
        }
    }

    /// Gives the lender the pledged shares the borrower still holds. Returns whether
    /// there were any.
    @discardableResult
    private static func takeCollateral(of loan: PlayerLoan, in state: inout GameState) -> Bool {
        guard let collateral = loan.collateral,
              let propertyIndex = state.properties.firstIndex(where: { $0.id == collateral.propertyID }) else {
            return false
        }
        let shares = min(collateral.shares, state.properties[propertyIndex].shares(of: loan.borrowerID))
        guard shares > 0 else {
            return false
        }
        state.properties[propertyIndex].removeShares(shares, from: loan.borrowerID)
        state.properties[propertyIndex].addShares(shares, to: loan.lenderID)
        return true
    }

    /// Shrinks each collateral to the shares its borrower still holds, after shares
    /// left them outside a deal (a covered level-up).
    static func clampLoanCollateral(in state: inout GameState) {
        for index in state.playerLoans.indices {
            guard let collateral = state.playerLoans[index].collateral else { continue }
            let held = state.properties.first(where: { $0.id == collateral.propertyID })?
                .shares(of: state.playerLoans[index].borrowerID) ?? 0
            let shares = min(collateral.shares, held)
            state.playerLoans[index].collateral = shares > 0
                ? LoanCollateral(propertyID: collateral.propertyID, shares: shares)
                : nil
        }
    }

    /// A bankrupt borrower's lenders take their collateral first; then every loan the
    /// player gave or owes is cancelled.
    static func cancelPlayerLoans(ofBankrupt playerID: UUID, in state: inout GameState) {
        for loan in state.playerLoans where loan.borrowerID == playerID {
            let trigger: LifeTrigger = takeCollateral(of: loan, in: &state)
                ? .collateralTaken(lenderID: loan.lenderID)
                : .loanLost(lenderID: loan.lenderID)
            applyLifeTrigger(trigger, in: &state)
        }
        state.playerLoans.removeAll { $0.lenderID == playerID || $0.borrowerID == playerID }
    }

    /// What the player is owed minus what they owe, for net worth.
    static func playerLoanBalance(of playerID: UUID, in state: GameState) -> Int {
        state.playerLoans.reduce(0) { total, loan in
            if loan.lenderID == playerID {
                return total + loan.remainingDebt
            }
            if loan.borrowerID == playerID {
                return total - loan.remainingDebt
            }
            return total
        }
    }
}
