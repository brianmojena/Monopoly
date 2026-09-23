import SwiftUI

struct GameBoardView: View {
    @ObservedObject var model: GameSessionModel
    @State private var amountAction: AmountAction?
    @State private var isShowingRole = false
    @State private var isShowingRules = false
    @State private var isConfirmingFreeParking = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        Group {
            if let state = model.gameState, state.monopolife?.isFinished == true {
                FinalRankingView(state: state)
            } else if let state = model.gameState {
                ScrollView {
                    VStack(spacing: 20) {
                        if model.role == .client, !model.isHostConnected {
                            connectionBanner
                        }

                        balanceCard(state)

                        if let pending = model.localPendingLifeCard, model.presentedLifeCard == nil {
                            pendingLifeCardBanner(pending)
                        }

                        if let profile = model.localProfile {
                            HappinessSection(model: model, profile: profile, isShowingRole: $isShowingRole)
                        }

                        if isLocalPlayerActive(in: state) {
                            actionsGrid(state)
                        }

                        playersCard(state)
                        propertiesCard(state)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity)
                }
                .background(Color(.systemGroupedBackground).ignoresSafeArea())
            } else {
                ProgressView("Cargando partida…")
            }
        }
        .navigationTitle("Partida")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isShowingRules = true
                } label: {
                    Label("Cómo se juega", systemImage: "questionmark.circle")
                }
            }
        }
        .sheet(isPresented: $isShowingRules) {
            NavigationStack {
                RulesView(mode: model.gameState?.mode ?? .classic)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Cerrar") {
                                isShowingRules = false
                            }
                        }
                    }
            }
        }
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
        .confirmationDialog(
            "¿Cobrar el bote de Free Parking?",
            isPresented: $isConfirmingFreeParking,
            titleVisibility: .visible
        ) {
            Button("Cobrar \(currency(model.gameState?.freeParkingPot ?? 0))") {
                model.collectFreeParking()
            }
        } message: {
            Text("Solo si tu ficha cayó en Free Parking.")
        }
        .sheet(item: $amountAction) { action in
            switch action {
            case .tax:
                AmountInputView(title: action.title) { amount in
                    model.payTax(amount: amount)
                }
            case .salary:
                SalaryView(model: model)
            case .travel:
                TravelView(model: model)
            }
        }
        .proximityReceiverBanner(model: model)
        .monopolifeBanners(model: model)
        .sheet(isPresented: $isShowingRole) {
            if let role = model.localProfile?.role {
                RoleSheet(role: role)
            }
        }
        .sheet(item: $model.presentedLifeCard) { draw in
            LifeCardSheet(model: model, draw: draw)
        }
        .fullScreenCover(isPresented: Binding(
            get: { !model.pendingRoleReveals.isEmpty },
            set: { _ in }
        )) {
            RoleRevealView(model: model)
        }
    }

    // MARK: Balance

    private func balanceCard(_ state: GameState) -> some View {
        let player = localPlayer(in: state)

        return VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 8) {
                chip(roundTitle(state), systemImage: "arrow.triangle.2.circlepath")
                if model.isFreeParkingEnabled {
                    chip("Bote \(currency(state.freeParkingPot))", systemImage: "parkingsign.circle.fill")
                }
                Spacer()
                playerSwitcher
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(player.map { "Saldo de \($0.name)" } ?? "Saldo")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.8))
                Text(currency(player?.balance ?? 0))
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .contentTransition(.numericText(value: Double(player?.balance ?? 0)))
                    .animation(.spring, value: player?.balance)

                if let player, player.creditCardDebt > 0 {
                    Label("Deuda de tarjeta: \(currency(player.creditCardDebt))", systemImage: "creditcard")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.boardGold)
                }
                if player?.status == .bankrupt {
                    Label("En bancarrota", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }

            boardStripe

            turnControls
        }
        .foregroundStyle(.white)
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.bankGreen, Color.boardGreen],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: Color.bankGreen.opacity(0.25), radius: 16, y: 8)
    }

    @ViewBuilder
    private var playerSwitcher: some View {
        if model.controllablePlayers.count > 1 {
            Menu {
                Picker("Jugando como", selection: Binding(
                    get: { model.localPlayerID },
                    set: { playerID in
                        if let playerID {
                            model.selectPlayer(playerID)
                        }
                    }
                )) {
                    ForEach(model.controllablePlayers) { player in
                        Text(player.name).tag(Optional(player.id))
                    }
                }
            } label: {
                Label("Cambiar", systemImage: "person.2.fill")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.18), in: Capsule())
            }
        }
    }

    @ViewBuilder
    private var turnControls: some View {
        if let currentPlayer = model.currentPlayer {
            if model.isLocalPlayersTurn {
                Button {
                    model.endTurn()
                } label: {
                    HStack {
                        Label("Es tu turno", systemImage: "person.fill.checkmark")
                        Spacer()
                        Text("Terminar turno")
                        Image(systemName: "chevron.right")
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.bankGreen)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                HStack {
                    Label("Turno de \(currentPlayer.name)", systemImage: "hourglass")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    if model.role == .host {
                        Button("Pasar turno") {
                            model.skipTurn()
                        }
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.white.opacity(0.18), in: Capsule())
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private var boardStripe: some View {
        HStack(spacing: 4) {
            ForEach(ColorGroup.allCases, id: \.self) { group in
                Rectangle().fill(group.swatch)
            }
        }
        .frame(height: 6)
        .clipShape(Capsule())
        .accessibilityHidden(true)
    }

    private func chip(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.white.opacity(0.14), in: Capsule())
    }

    // MARK: Actions

    private func actionsGrid(_ state: GameState) -> some View {
        let isMyTurn = model.isLocalPlayersTurn

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Acciones")
                    .font(.title3.weight(.bold))
                Spacer()
                if !isMyTurn {
                    Text("\(Image(systemName: "lock.fill")) solo en tu turno")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            LazyVGrid(columns: columns, spacing: 12) {
                NavigationLink {
                    TransferView(model: model)
                } label: {
                    ActionTile(title: "Pagar", detail: "A un jugador", icon: "arrow.up.right", tint: .boardRed)
                }

                NavigationLink {
                    CollectWithQRView(model: model)
                } label: {
                    ActionTile(title: "Cobrar", detail: "Con QR", icon: "arrow.down.left", tint: .boardGreen)
                }

                tileButton(isEnabled: isMyTurn) {
                    amountAction = .salary
                } label: {
                    ActionTile(title: "GO", detail: "Cobrar salario", icon: "flag.checkered", tint: .blue, isLocked: !isMyTurn)
                }

                if model.isFreeParkingEnabled {
                    tileButton(isEnabled: isMyTurn && state.freeParkingPot > 0) {
                        isConfirmingFreeParking = true
                    } label: {
                        ActionTile(
                            title: "Free Parking",
                            detail: "Bote \(currency(state.freeParkingPot))",
                            icon: "parkingsign",
                            tint: .boardGold,
                            isLocked: !isMyTurn,
                            isHighlighted: state.freeParkingPot > 0
                        )
                    }
                }

                if model.isMonopolife {
                    tileButton(isEnabled: isMyTurn && model.localPendingLifeCard == nil) {
                        model.drawLifeCard()
                    } label: {
                        ActionTile(title: "Sacar tarjeta", detail: "Tarjeta de Vida", icon: "rectangle.stack.fill", tint: .orange, isLocked: !isMyTurn)
                    }
                }

                tileButton(isEnabled: isMyTurn) {
                    amountAction = .tax
                } label: {
                    ActionTile(title: "Impuesto", detail: "Pagar al banco", icon: "building.columns.fill", tint: .brown, isLocked: !isMyTurn)
                }

                tileButton(isEnabled: isMyTurn) {
                    amountAction = .travel
                } label: {
                    ActionTile(title: "Viajar", detail: "Desde $\(TravelRoute.sameSide.fare)", icon: "airplane", tint: .cyan, isLocked: !isMyTurn)
                }

                NavigationLink {
                    PayWithQRView(model: model)
                } label: {
                    ActionTile(title: "Pagar QR", detail: "Escanear", icon: "qrcode.viewfinder", tint: .teal)
                }

                NavigationLink {
                    MarketView(model: model)
                } label: {
                    ActionTile(
                        title: "Mercado",
                        detail: "Tratos",
                        icon: "chart.line.uptrend.xyaxis",
                        tint: .purple,
                        badge: model.dealsAwaitingLocalPlayer.count
                    )
                }

                if model.areCreditCardsEnabled {
                    NavigationLink {
                        CreditCardView(model: model)
                    } label: {
                        ActionTile(title: "Tarjeta", detail: "Crédito", icon: "creditcard.fill", tint: .indigo)
                    }
                }
            }
            .buttonStyle(.plain)

            NavigationLink {
                BankruptcyView(model: model)
            } label: {
                Label("Declararme en bancarrota", systemImage: "exclamationmark.triangle")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
            .buttonStyle(.plain)
        }
    }

    private func tileButton<TileLabel: View>(
        isEnabled: Bool,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> TileLabel
    ) -> some View {
        Button(action: action, label: label)
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.45)
    }

    private func pendingLifeCardBanner(_ pending: LifeCardDraw) -> some View {
        Button {
            model.presentedLifeCard = pending
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.title2)
                Text("Tienes una Tarjeta de Vida por decidir")
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.right")
            }
            .foregroundStyle(.white)
            .padding(16)
            .background(Color.orange.gradient, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var connectionBanner: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("Se perdió la conexión con el host. Esperando a que vuelva a abrir la partida…")
                .font(.subheadline)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.yellow.opacity(0.2), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: Players and properties

    private func playersCard(_ state: GameState) -> some View {
        BankCard(title: "Jugadores") {
            ForEach(Array(state.players.enumerated()), id: \.element.id) { index, player in
                if index > 0 {
                    Divider()
                }
                playerRow(player, state: state)
            }
        }
    }

    private func playerRow(_ player: Player, state: GameState) -> some View {
        let isCurrent = player.id == state.currentPlayerID

        return HStack(spacing: 12) {
            Text(String(player.name.prefix(1)).uppercased())
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(isCurrent ? Color.boardGold : Color.boardGreen, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(player.name)
                        .font(.body.weight(.semibold))
                        .strikethrough(player.status == .bankrupt)
                    if isCurrent {
                        Text("TURNO")
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(Color.boardGold)
                    }
                }
                if player.id == model.localPlayerID {
                    Text("Este dispositivo")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if player.status == .bankrupt {
                    Text("Bancarrota")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                if player.creditCardDebt > 0 {
                    Text("Deuda de tarjeta: \(currency(player.creditCardDebt))")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            Text(currency(player.balance))
                .font(.body.weight(.bold))
                .monospacedDigit()
        }
        .opacity(player.status == .bankrupt ? 0.6 : 1)
        .accessibilityElement(children: .combine)
    }

    private func propertiesCard(_ state: GameState) -> some View {
        BankCard(title: "Propiedades") {
            ForEach(Array(state.properties.enumerated()), id: \.element.id) { index, property in
                if index > 0 {
                    Divider()
                }
                propertyRow(property, state: state)
            }
        }
    }

    private func propertyRow(_ property: Property, state: GameState) -> some View {
        HStack(spacing: 12) {
            NavigationLink {
                PropertyDetailView(propertyID: property.id, model: model)
            } label: {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(property.colorGroup.swatch)
                        .frame(width: 6, height: 38)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(property.name)
                            .font(.subheadline.weight(.semibold))
                        Text(ownerName(for: property, state: state))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Text(currency(property.purchasePrice))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if property.ownerID == nil, isLocalPlayerActive(in: state), model.isLocalPlayersTurn {
                Button("Comprar") {
                    model.buy(propertyID: property.id)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.boardGreen)
                .controlSize(.small)
            }
        }
    }

    // MARK: Helpers

    private func localPlayer(in state: GameState) -> Player? {
        state.players.first(where: { $0.id == model.localPlayerID })
    }

    private func roundTitle(_ state: GameState) -> String {
        guard let roundLimit = state.monopolife?.roundLimit else {
            return "Ronda \(state.round)"
        }
        return "Ronda \(state.round) de \(roundLimit)"
    }

    private func ownerName(for property: Property, state: GameState) -> String {
        guard property.isOwned else {
            return "Sin dueño"
        }
        return property.ownership.count > 1
            ? "Accionistas: \(state.ownershipSummary(of: property))"
            : "Dueño: \(state.ownershipSummary(of: property))"
    }

    private func isLocalPlayerActive(in state: GameState) -> Bool {
        localPlayer(in: state)?.status == .active
    }

    private func currency(_ amount: Int) -> String {
        "$\(amount)"
    }
}

private struct ActionTile: View {
    let title: String
    var detail: String?
    let icon: String
    let tint: Color
    var badge = 0
    var isLocked = false
    var isHighlighted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(tint.gradient, in: RoundedRectangle(cornerRadius: 13, style: .continuous))

                Spacer(minLength: 0)

                if badge > 0 {
                    Text("\(badge)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.red, in: Capsule())
                } else if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                if let detail {
                    Text(detail)
                        .font(.caption2.weight(isHighlighted ? .bold : .regular))
                        .foregroundStyle(isHighlighted ? tint : .secondary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.75)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            if isHighlighted {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(tint.opacity(0.7), lineWidth: 2)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private enum AmountAction: String, Identifiable {
    case tax
    case salary
    case travel

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tax:
            return "Pagar impuesto"
        case .salary:
            return "Cobrar salario"
        case .travel:
            return "Viajar"
        }
    }
}

extension LifeCardDraw: Identifiable {
    var id: Int { sequence }
}
