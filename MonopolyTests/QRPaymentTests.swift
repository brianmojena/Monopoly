import XCTest
@testable import Monopoly

final class QRPaymentTests: XCTestCase {
    private let ana = Player(name: "Ana", balance: 500)
    private let luis = Player(name: "Luis", balance: 500)

    private func street(owner: UUID?, rent: Int = 50, mortgaged: Bool = false) -> Property {
        Property(
            name: "Boardwalk",
            colorGroup: .darkBlue,
            purchasePrice: 400,
            mortgageValue: 200,
            baseRent: rent,
            ownerID: owner,
            isMortgaged: mortgaged
        )
    }

    // MARK: Payload

    func testPayloadsRoundTrip() {
        let requests: [QRPaymentRequest] = [
            .rent(propertyID: UUID()),
            .transfer(recipientID: UUID(), amount: 150),
            .transfer(recipientID: UUID(), amount: nil)
        ]
        for request in requests {
            XCTAssertEqual(QRPaymentRequest(payload: request.payload), request)
        }
    }

    func testForeignOrMalformedPayloadsAreRejected() {
        let id = UUID().uuidString
        for payload in [
            "https://example.com",
            "monopoly-pay:2:rent:\(id)",
            "monopoly-pay:1:rent:not-a-uuid",
            "monopoly-pay:1:rent:\(id):extra",
            "monopoly-pay:1:transfer:\(id)",
            "monopoly-pay:1:transfer:\(id):-5",
            "monopoly-pay:1:steal:\(id)"
        ] {
            XCTAssertNil(QRPaymentRequest(payload: payload), payload)
        }
    }

    // MARK: Transfers

    func testTransferPreviewNamesTheRecipient() {
        let state = GameState(players: [ana, luis], properties: [])

        let preview = QRPaymentRequest.transfer(recipientID: luis.id, amount: 80).preview(in: state, payerID: ana.id)

        XCTAssertEqual(preview, .success(.transfer(recipientID: luis.id, recipientName: "Luis", amount: 80)))
    }

    func testTransferToYourselfOrAnUnknownOrBankruptPlayerFails() {
        var bankruptLuis = luis
        bankruptLuis.status = .bankrupt
        let state = GameState(players: [ana, bankruptLuis], properties: [])

        XCTAssertEqual(QRPaymentRequest.transfer(recipientID: ana.id, amount: nil).preview(in: state, payerID: ana.id), .failure(.ownQRCode))
        XCTAssertEqual(QRPaymentRequest.transfer(recipientID: UUID(), amount: nil).preview(in: state, payerID: ana.id), .failure(.notFromThisGame))
        XCTAssertEqual(
            QRPaymentRequest.transfer(recipientID: luis.id, amount: nil).preview(in: state, payerID: ana.id),
            .failure(.recipientNotActive(name: "Luis"))
        )
    }

    // MARK: Rent

    func testRentPreviewShowsWhatThePayerOwes() {
        let property = street(owner: luis.id)
        let state = GameState(players: [ana, luis], properties: [property], currentPlayerID: ana.id)

        let preview = QRPaymentRequest.rent(propertyID: property.id).preview(in: state, payerID: ana.id)

        XCTAssertEqual(preview, .success(.rent(propertyID: property.id, propertyName: "Boardwalk", amount: 50)))
    }

    func testRentPreviewOnlyChargesOtherShareholdersPortion() {
        var property = street(owner: luis.id, rent: 100)
        property.ownership = [PropertyShare(playerID: luis.id, shares: 7), PropertyShare(playerID: ana.id, shares: 3)]
        let state = GameState(players: [ana, luis], properties: [property], currentPlayerID: ana.id)

        let preview = QRPaymentRequest.rent(propertyID: property.id).preview(in: state, payerID: ana.id)

        XCTAssertEqual(preview, .success(.rent(propertyID: property.id, propertyName: "Boardwalk", amount: 70)))
    }

    func testRentPreviewProblems() {
        let unowned = street(owner: nil)
        let mortgaged = street(owner: luis.id, mortgaged: true)
        let own = street(owner: ana.id)
        let expensive = street(owner: luis.id, rent: 900)
        let state = GameState(players: [ana, luis], properties: [unowned, mortgaged, own, expensive], currentPlayerID: ana.id)

        XCTAssertEqual(QRPaymentRequest.rent(propertyID: UUID()).preview(in: state, payerID: ana.id), .failure(.notFromThisGame))
        XCTAssertEqual(QRPaymentRequest.rent(propertyID: unowned.id).preview(in: state, payerID: ana.id), .failure(.propertyHasNoOwner(name: "Boardwalk")))
        XCTAssertEqual(QRPaymentRequest.rent(propertyID: mortgaged.id).preview(in: state, payerID: ana.id), .failure(.propertyIsMortgaged(name: "Boardwalk")))
        XCTAssertEqual(QRPaymentRequest.rent(propertyID: own.id).preview(in: state, payerID: ana.id), .failure(.nothingToPay(name: "Boardwalk")))
        XCTAssertEqual(
            QRPaymentRequest.rent(propertyID: expensive.id).preview(in: state, payerID: ana.id),
            .failure(.insufficientFunds(required: 900, available: 500))
        )
    }

    func testRentOnlyOnYourTurn() {
        let property = street(owner: luis.id)
        let state = GameState(players: [ana, luis], properties: [property], currentPlayerID: luis.id)

        XCTAssertEqual(QRPaymentRequest.rent(propertyID: property.id).preview(in: state, payerID: ana.id), .failure(.notYourTurn))
    }
}
