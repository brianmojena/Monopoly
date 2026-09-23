import CoreImage.CIFilterBuiltins
import SwiftUI

#if os(iOS)
import AVFoundation
import UIKit
#endif

// MARK: - Collect: show a QR

/// Shows a QR code for another player to scan and pay: either rent for one of the
/// local player's properties, or a free payment to them.
struct CollectWithQRView: View {
    @ObservedObject var model: GameSessionModel

    private enum Kind: String, CaseIterable, Identifiable {
        case transfer
        case rent

        var id: String { rawValue }
    }

    @State private var kind: Kind = .transfer
    @State private var amountText = ""
    @State private var propertyID: UUID?
    @State private var receivedAmount: Int?

    var body: some View {
        Group {
            if let state = model.gameState, let player = localPlayer(in: state) {
                ScrollView {
                    VStack(spacing: 20) {
                        Picker("Cobrar", selection: $kind) {
                            Text("Pago").tag(Kind.transfer)
                            Text("Renta").tag(Kind.rent)
                        }
                        .pickerStyle(.segmented)

                        switch kind {
                        case .transfer:
                            transferOptions
                            qrCard(for: .transfer(recipientID: player.id, amount: amount), title: player.name, subtitle: amount.map { "Cobrar $\($0)" } ?? "Monto a elegir por quien paga")
                        case .rent:
                            rentContent(in: state, playerID: player.id)
                        }

                        if let receivedAmount {
                            Label("Recibiste $\(receivedAmount)", systemImage: "checkmark.circle.fill")
                                .font(.app(.headline))
                                .foregroundStyle(.green)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity)
                }
                .onChange(of: player.balance) { oldBalance, newBalance in
                    guard newBalance > oldBalance else { return }
                    withAnimation(.spring) {
                        receivedAmount = newBalance - oldBalance
                    }
                }
            } else {
                ProgressView("Cargando partida…")
            }
        }
        .navigationTitle("Cobrar con QR")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .sensoryFeedback(.success, trigger: receivedAmount)
    }

    private var transferOptions: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Monto (opcional)", text: $amountText)
#if os(iOS)
                .keyboardType(.numberPad)
#endif
                .textFieldStyle(.roundedBorder)
            Text("Si pones un monto, quien escanee pagará exactamente eso. Si lo dejas vacío, lo elige quien paga.")
                .font(.app(.footnote))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func rentContent(in state: GameState, playerID: UUID) -> some View {
        let properties = state.properties.filter { $0.shares(of: playerID) > 0 && !$0.isMortgaged }
        if properties.isEmpty {
            ContentUnavailableView(
                "Sin propiedades que cobren renta",
                systemImage: "house.slash",
                description: Text("Necesitas acciones en una propiedad sin hipotecar para cobrar renta con QR.")
            )
        } else {
            let selected = properties.first(where: { $0.id == propertyID }) ?? properties[0]
            Picker("Propiedad", selection: Binding(
                get: { selected.id },
                set: { propertyID = $0 }
            )) {
                ForEach(properties) { property in
                    Text(property.name).tag(property.id)
                }
            }
            .pickerStyle(.menu)

            qrCard(
                for: .rent(propertyID: selected.id),
                title: selected.name,
                subtitle: "Renta: \(rentText(for: selected, in: state))"
            )
        }
    }

    private func qrCard(for request: QRPaymentRequest, title: String, subtitle: String) -> some View {
        VStack(spacing: 14) {
            QRCodeImage(payload: request.payload)
                .frame(maxWidth: 280)
                .padding(16)
                .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            VStack(spacing: 4) {
                Text(title)
                    .font(.app(.title2, weight: .bold))
                Text(subtitle)
                    .font(.app(.headline))
                    .foregroundStyle(.secondary)
            }
            Text("Pide a quien paga que abra \"Pagar con QR\" y escanee este código.")
                .font(.app(.footnote))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var amount: Int? {
        guard let amount = Int(amountText), amount > 0 else {
            return nil
        }
        return amount
    }

    private func localPlayer(in state: GameState) -> Player? {
        state.players.first(where: { $0.id == model.localPlayerID })
    }

    private func rentText(for property: Property, in state: GameState) -> String {
        guard let ownerID = property.ownerID,
              let rent = try? GameRules.rentAmount(for: property, in: state, ownerID: ownerID) else {
            return "—"
        }
        return "$\(rent)"
    }
}

/// A QR code drawn with Core Image, kept crisp at any size.
struct QRCodeImage: View {
    let payload: String

    var body: some View {
        if let image = Self.makeImage(payload) {
            Image(decorative: image, scale: 1)
                .interpolation(.none)
                .resizable()
                .aspectRatio(1, contentMode: .fit)
                .accessibilityLabel("Código QR de pago")
        } else {
            Image(systemName: "qrcode")
                .resizable()
                .aspectRatio(1, contentMode: .fit)
        }
    }

    private static let context = CIContext()

    private static func makeImage(_ payload: String) -> CGImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else {
            return nil
        }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        return context.createCGImage(scaled, from: scaled.extent)
    }
}

// MARK: - Pay: scan a QR

struct PayWithQRView: View {
    @ObservedObject var model: GameSessionModel

    @Environment(\.dismiss) private var dismiss
    @State private var scanned: QRPaymentRequest?
    @State private var scanError: String?
    @State private var amountText = ""
    @State private var paidMessage: String?

    var body: some View {
        Group {
            if let state = model.gameState, let payerID = model.localPlayerID {
                VStack(spacing: 0) {
                    if let paidMessage {
                        paidView(paidMessage)
                    } else if let scanned {
                        confirmation(for: scanned.preview(in: state, payerID: payerID))
                    } else {
                        amountBar
                        scanner
                    }
                }
            } else {
                ProgressView("Cargando partida…")
            }
        }
        .navigationTitle("Pagar con QR")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .sensoryFeedback(.selection, trigger: scanned)
        .sensoryFeedback(.success, trigger: paidMessage) { _, message in
            message != nil
        }
    }

    /// For QR codes without an amount: typed before scanning, the payment still goes
    /// through the moment the code is read.
    private var amountBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "dollarsign.circle")
                .foregroundStyle(.secondary)
            TextField("Monto, si el QR no trae uno", text: $amountText)
#if os(iOS)
                .keyboardType(.numberPad)
#endif
        }
        .font(.app(.subheadline))
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }

    /// Pays right away when the QR says everything needed; otherwise shows why not,
    /// or asks for the amount.
    private func handleScan(_ request: QRPaymentRequest) {
        guard let state = model.gameState, let payerID = model.localPlayerID else {
            return
        }
        switch request.preview(in: state, payerID: payerID) {
        case let .success(.rent(propertyID, propertyName, amount)):
            model.payRent(propertyID: propertyID)
            paidMessage = "Pagaste $\(amount) de renta de \(propertyName)"
        case let .success(.transfer(recipientID, recipientName, fixedAmount)):
            guard let amount = fixedAmount ?? typedAmount else {
                scanned = request
                return
            }
            model.transfer(to: recipientID, amount: amount)
            paidMessage = "Pagaste $\(amount) a \(recipientName)"
        case .failure:
            scanned = request
        }
    }

    private func paidView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.app(size: 72))
                .foregroundStyle(.green)
            Text(message)
                .font(.app(.title3, weight: .bold))
                .multilineTextAlignment(.center)
            Spacer()
            Button {
                dismiss()
            } label: {
                Text("Listo")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Button("Pagar otro QR") {
                paidMessage = nil
                scanned = nil
                amountText = ""
            }
        }
        .padding(24)
    }

    @ViewBuilder
    private var scanner: some View {
#if os(iOS)
        ZStack(alignment: .bottom) {
            QRScannerView { code in
                guard let request = QRPaymentRequest(payload: code) else {
                    scanError = "Ese QR no es un cobro de Monopoly."
                    return
                }
                scanError = nil
                handleScan(request)
            } onFailure: { failure in
                scanError = failure.message
            }
            .ignoresSafeArea(edges: .bottom)

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.9), lineWidth: 3)
                .frame(width: 240, height: 240)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)

            Text(scanError ?? "Apunta al QR de quien cobra: el pago se hace solo")
                .font(.app(.subheadline, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: Capsule())
                .padding(.bottom, 32)
        }
#else
        ContentUnavailableView("Cámara no disponible", systemImage: "camera")
#endif
    }

    @ViewBuilder
    private func confirmation(for preview: Result<QRPaymentPreview, QRPaymentProblem>) -> some View {
        List {
            switch preview {
            case let .success(.rent(propertyID, propertyName, amount)):
                Section {
                    LabeledContent("Renta de", value: propertyName)
                    LabeledContent("A pagar", value: "$\(amount)")
                    Button {
                        model.payRent(propertyID: propertyID)
                        paidMessage = "Pagaste $\(amount) de renta de \(propertyName)"
                    } label: {
                        Text("Pagar $\(amount)")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                } header: {
                    Text("Pagar renta")
                }

            case let .success(.transfer(recipientID, recipientName, fixedAmount)):
                Section {
                    LabeledContent("Pagar a", value: recipientName)
                    if let fixedAmount {
                        LabeledContent("Monto", value: "$\(fixedAmount)")
                    } else {
                        TextField("Monto", text: $amountText)
#if os(iOS)
                            .keyboardType(.numberPad)
#endif
                    }
                    let amount = fixedAmount ?? typedAmount
                    Button {
                        if let amount {
                            model.transfer(to: recipientID, amount: amount)
                            paidMessage = "Pagaste $\(amount) a \(recipientName)"
                        }
                    } label: {
                        Text(amount.map { "Pagar $\($0)" } ?? "Pagar")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(amount == nil)
                } header: {
                    Text("Pago a un jugador")
                }

            case let .failure(problem):
                Section {
                    Label(problem.message, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button("Escanear otro QR") {
                    scanned = nil
                    amountText = ""
                }
            }
        }
    }

    private var typedAmount: Int? {
        guard let amount = Int(amountText), amount > 0 else {
            return nil
        }
        return amount
    }
}

#if os(iOS)
enum QRScannerFailure {
    case permissionDenied
    case cameraUnavailable

    var message: String {
        switch self {
        case .permissionDenied:
            return "Sin acceso a la cámara. Actívalo en Ajustes > Monopoly > Cámara."
        case .cameraUnavailable:
            return "No se pudo usar la cámara de este dispositivo."
        }
    }
}

struct QRScannerView: UIViewControllerRepresentable {
    let onCode: (String) -> Void
    let onFailure: (QRScannerFailure) -> Void

    func makeUIViewController(context: Context) -> QRScannerController {
        let controller = QRScannerController()
        controller.onCode = onCode
        controller.onFailure = onFailure
        return controller
    }

    func updateUIViewController(_ controller: QRScannerController, context: Context) {
        controller.onCode = onCode
        controller.onFailure = onFailure
    }
}

final class QRScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCode: ((String) -> Void)?
    var onFailure: ((QRScannerFailure) -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var lastCode: String?
    private var isConfigured = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configure()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor [weak self] in
                    granted ? self?.configure() : self?.onFailure?(.permissionDenied)
                }
            }
        default:
            onFailure?(.permissionDenied)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        lastCode = nil
        if isConfigured {
            startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        let session = session
        DispatchQueue.global(qos: .userInitiated).async {
            session.stopRunning()
        }
    }

    private func configure() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            onFailure?(.cameraUnavailable)
            return
        }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            onFailure?(.cameraUnavailable)
            return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        self.previewLayer = previewLayer
        isConfigured = true
        startRunning()
    }

    // startRunning blocks until the camera starts, so it runs off the main thread.
    private func startRunning() {
        let session = session
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    // Delivered on the main queue (see setMetadataObjectsDelegate above).
    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        let code = metadataObjects
            .compactMap { ($0 as? AVMetadataMachineReadableCodeObject)?.stringValue }
            .first
        MainActor.assumeIsolated {
            guard let code, code != lastCode else {
                return
            }
            lastCode = code
            onCode?(code)
        }
    }
}
#endif
