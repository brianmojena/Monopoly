import Combine
import Foundation
#if os(iOS)
import NearbyInteraction
#endif

enum ProximityCandidateStatus: Equatable {
    case waiting
    case ranging(distance: Float?)
    case declined
    case unavailable
}

struct ProximityIncomingRequest: Equatable {
    let sessionID: UUID
    let payerID: UUID
    var distance: Float?
}

#if os(iOS)
@MainActor
final class ProximityPaymentCoordinator: NSObject, ObservableObject {
    // Detects the other iPhone before they touch: bringing the tops of two iPhones
    // together (a few cm) starts iOS's NameDrop, which takes over the screen and
    // stops the payment. 25 cm is still clearly closer than phones lying around a
    // table, and a few readings in a row keep someone merely passing by from being
    // picked.
    static let tapDistance: Float = 0.25
    static let closeReadingsToDetect = 3

    @Published private(set) var candidates: [UUID: ProximityCandidateStatus] = [:]
    @Published private(set) var detectedPlayerID: UUID?
    @Published private(set) var incomingRequest: ProximityIncomingRequest?
    @Published private(set) var errorMessage: String?

    var sendSignal: ((ProximitySignal) -> Void)?

    private var localPlayerID: UUID?
    private var outgoingSessionID: UUID?
    private var outgoingSessions: [UUID: NISession] = [:]
    private var incomingSession: NISession?
    private var closeReadings: [UUID: Int] = [:]

    static var isSupported: Bool {
        NISession.deviceCapabilities.supportsPreciseDistanceMeasurement
    }

    var isSearching: Bool {
        outgoingSessionID != nil
    }

    func startPayment(from payerID: UUID, to candidateIDs: [UUID]) {
        stopPayment()
        errorMessage = nil

        guard Self.isSupported else {
            errorMessage = "Este iPhone no tiene chip UWB (iPhone 11 o posterior, excepto SE)."
            return
        }

        let sessionID = UUID()
        localPlayerID = payerID
        outgoingSessionID = sessionID

        for candidateID in candidateIDs {
            let session = makeSession()
            guard let token = session.discoveryToken.flatMap(Self.archive) else {
                session.invalidate()
                continue
            }

            outgoingSessions[candidateID] = session
            candidates[candidateID] = .waiting
            sendSignal?(ProximitySignal(
                sessionID: sessionID,
                kind: .invite,
                senderPlayerID: payerID,
                recipientPlayerID: candidateID,
                discoveryToken: token
            ))
        }
    }

    func stopPayment() {
        if let sessionID = outgoingSessionID, let payerID = localPlayerID {
            for candidateID in outgoingSessions.keys {
                sendSignal?(ProximitySignal(
                    sessionID: sessionID,
                    kind: .cancel,
                    senderPlayerID: payerID,
                    recipientPlayerID: candidateID
                ))
            }
        }

        outgoingSessions.values.forEach { $0.invalidate() }
        outgoingSessions.removeAll()
        outgoingSessionID = nil
        candidates.removeAll()
        closeReadings.removeAll()
        detectedPlayerID = nil
    }

    func resetDetection() {
        closeReadings.removeAll()
        detectedPlayerID = nil
    }

    func declineIncomingRequest() {
        guard let request = incomingRequest, let localPlayerID else {
            return
        }

        sendSignal?(ProximitySignal(
            sessionID: request.sessionID,
            kind: .decline,
            senderPlayerID: localPlayerID,
            recipientPlayerID: request.payerID
        ))
        endIncomingRequest()
    }

    func handle(_ signal: ProximitySignal, localPlayerID: UUID?) {
        guard let localPlayerID, signal.recipientPlayerID == localPlayerID else {
            return
        }
        self.localPlayerID = localPlayerID

        switch signal.kind {
        case .invite:
            acceptInvite(signal, localPlayerID: localPlayerID)
        case .cancel:
            if incomingRequest?.sessionID == signal.sessionID {
                endIncomingRequest()
            }
        case .accept:
            startRanging(with: signal)
        case .decline, .unsupported:
            guard signal.sessionID == outgoingSessionID,
                  let session = outgoingSessions.removeValue(forKey: signal.senderPlayerID) else {
                return
            }
            session.invalidate()
            candidates[signal.senderPlayerID] = signal.kind == .decline ? .declined : .unavailable
        }
    }

    private func acceptInvite(_ signal: ProximitySignal, localPlayerID: UUID) {
        endIncomingRequest()

        guard Self.isSupported else {
            sendSignal?(ProximitySignal(
                sessionID: signal.sessionID,
                kind: .unsupported,
                senderPlayerID: localPlayerID,
                recipientPlayerID: signal.senderPlayerID
            ))
            return
        }

        guard let peerToken = signal.discoveryToken.flatMap(Self.unarchive) else {
            return
        }

        let session = makeSession()
        guard let token = session.discoveryToken.flatMap(Self.archive) else {
            session.invalidate()
            return
        }

        incomingSession = session
        incomingRequest = ProximityIncomingRequest(sessionID: signal.sessionID, payerID: signal.senderPlayerID)
        session.run(NINearbyPeerConfiguration(peerToken: peerToken))
        sendSignal?(ProximitySignal(
            sessionID: signal.sessionID,
            kind: .accept,
            senderPlayerID: localPlayerID,
            recipientPlayerID: signal.senderPlayerID,
            discoveryToken: token
        ))
    }

    private func startRanging(with signal: ProximitySignal) {
        guard signal.sessionID == outgoingSessionID,
              let session = outgoingSessions[signal.senderPlayerID],
              let peerToken = signal.discoveryToken.flatMap(Self.unarchive) else {
            return
        }

        candidates[signal.senderPlayerID] = .ranging(distance: nil)
        session.run(NINearbyPeerConfiguration(peerToken: peerToken))
    }

    private func endIncomingRequest() {
        incomingSession?.invalidate()
        incomingSession = nil
        incomingRequest = nil
    }

    private func makeSession() -> NISession {
        let session = NISession()
        session.delegate = self
        session.delegateQueue = .main
        return session
    }

    private func candidateID(for session: NISession) -> UUID? {
        outgoingSessions.first(where: { $0.value === session })?.key
    }

    private func updateDistance(_ distance: Float?, for session: NISession) {
        if session === incomingSession {
            incomingRequest?.distance = distance
            return
        }

        guard let candidateID = candidateID(for: session) else {
            return
        }
        candidates[candidateID] = .ranging(distance: distance)
        if let distance, distance <= Self.tapDistance {
            closeReadings[candidateID, default: 0] += 1
        } else {
            closeReadings[candidateID] = 0
        }

        guard detectedPlayerID == nil else {
            return
        }
        let closest = candidates
            .compactMap { id, status -> (UUID, Float)? in
                guard case let .ranging(distance?) = status,
                      distance <= Self.tapDistance,
                      closeReadings[id, default: 0] >= Self.closeReadingsToDetect else {
                    return nil
                }
                return (id, distance)
            }
            .min { $0.1 < $1.1 }
        detectedPlayerID = closest?.0
    }

    private func sessionDidInvalidate(_ session: NISession, error: Error) {
        let permissionDenied = (error as? NIError)?.code == .userDidNotAllow

        if session === incomingSession {
            if let request = incomingRequest, let localPlayerID {
                sendSignal?(ProximitySignal(
                    sessionID: request.sessionID,
                    kind: .unsupported,
                    senderPlayerID: localPlayerID,
                    recipientPlayerID: request.payerID
                ))
            }
            incomingSession = nil
            incomingRequest = nil
        } else if let candidateID = candidateID(for: session) {
            outgoingSessions.removeValue(forKey: candidateID)
            candidates[candidateID] = .unavailable
        } else {
            return
        }

        if permissionDenied {
            errorMessage = "Permite el acceso a Interacción cercana en Ajustes > Privacidad y seguridad para pagar acercando iPhones."
        }
    }

    private static func archive(_ token: NIDiscoveryToken) -> Data? {
        try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
    }

    private static func unarchive(_ data: Data) -> NIDiscoveryToken? {
        try? NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: data)
    }
}

// NISession delivers these callbacks on `delegateQueue`, which is always `.main`.
extension ProximityPaymentCoordinator: NISessionDelegate {
    nonisolated func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        let distance = nearbyObjects.first?.distance
        MainActor.assumeIsolated {
            updateDistance(distance, for: session)
        }
    }

    nonisolated func session(
        _ session: NISession,
        didRemove nearbyObjects: [NINearbyObject],
        reason: NINearbyObject.RemovalReason
    ) {
        MainActor.assumeIsolated {
            updateDistance(nil, for: session)
        }
    }

    nonisolated func sessionSuspensionEnded(_ session: NISession) {
        MainActor.assumeIsolated {
            if let configuration = session.configuration {
                session.run(configuration)
            }
        }
    }

    nonisolated func session(_ session: NISession, didInvalidateWith error: Error) {
        MainActor.assumeIsolated {
            sessionDidInvalidate(session, error: error)
        }
    }
}
#else
// NearbyInteraction peer sessions only exist on iPhone; other platforms answer every
// invite as unsupported so the payer's screen can show it instead of waiting forever.
@MainActor
final class ProximityPaymentCoordinator: ObservableObject {
    @Published private(set) var candidates: [UUID: ProximityCandidateStatus] = [:]
    @Published private(set) var detectedPlayerID: UUID?
    @Published private(set) var incomingRequest: ProximityIncomingRequest?
    @Published private(set) var errorMessage: String?

    var sendSignal: ((ProximitySignal) -> Void)?

    static let tapDistance: Float = 0.25
    static let isSupported = false

    var isSearching: Bool {
        false
    }

    func startPayment(from payerID: UUID, to candidateIDs: [UUID]) {
        errorMessage = "Pagar acercando dispositivos solo está disponible en iPhone."
    }

    func stopPayment() {
    }

    func resetDetection() {
    }

    func declineIncomingRequest() {
    }

    func handle(_ signal: ProximitySignal, localPlayerID: UUID?) {
        guard let localPlayerID,
              signal.recipientPlayerID == localPlayerID,
              signal.kind == .invite else {
            return
        }

        sendSignal?(ProximitySignal(
            sessionID: signal.sessionID,
            kind: .unsupported,
            senderPlayerID: localPlayerID,
            recipientPlayerID: signal.senderPlayerID
        ))
    }
}
#endif
