import SwiftUI

struct GameBoardView: View {
    @ObservedObject var model: GameSessionModel
    @State private var amountAction: AmountAction?
    @State private var isShowingRole = false
    @State private var isShowingRules = false
    @State private var isConfirmingFreeParking = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        Group {
            if let state = model.gameState, state.monopolife?.isFinished == true {
                FinalRankingView(state: state)
            } else if let state = model.gameState {
                ScrollView {
                    VStack(spacing: 18) {
                        if model.role == .client, !model.isHostConnected {
                            connectionBanner
                        }

                        balanceCard(state)

                        if let pending = model.localPendingLifeCard, model.presentedLifeCard == nil {
                            pendingLifeCardBanner(pending)
                        }

                        if isLocalPlayerActive(in: state) {
                            actionsGrid(state)
                        }

                        if let profile = model.localProfile {
                            HappinessSection(model: model, profile: profile, isShowingRole: $isShowingRole)
                        }

                        playersCard(state)
                        propertiesCard(state)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity)
                }
                .background(backdrop)
            } else {
                ProgressView("Cargando partida…")
            }
        }
        .foregroundStyle(Lux.textPrimary)
        .tint(Lux.gold)
        .preferredColorScheme(.dark)
        .navigationTitle("Partida")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Lux.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
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

    private var backdrop: some View {
        ZStack(alignment: .top) {
            Lux.background

            RadialGradient(
                colors: [Lux.gold.opacity(0.10), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 360
            )
            .frame(height: 420)
        }
        .ignoresSafeArea()
    }

    // MARK: Balance

    private func balanceCard(_ state: GameState) -> some View {
        let player = localPlayer(in: state)

        return VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("BANCA PRIVADA")
                        .font(.caption2.weight(.bold))
                        .tracking(2.4)
                        .foregroundStyle(Lux.goldGradient)
                    Text(player?.name ?? "Jugador")
                        .font(.system(.title3, design: .serif, weight: .semibold))
                }
                Spacer()
                playerSwitcher
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Saldo disponible")
                    .font(.footnote)
                    .foregroundStyle(Lux.textSecondary)
                Text(currency(player?.balance ?? 0))
                    .font(.system(size: 46, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .contentTransition(.numericText(value: Double(player?.balance ?? 0)))
                    .animation(.spring, value: player?.balance)

                HStack(spacing: 8) {
                    if let player, player.creditCardDebt > 0 {
                        stat("Deuda", value: currency(player.creditCardDebt), color: Lux.down)
                    }
                    if player?.status == .bankrupt {
                        stat("Estado", value: "Bancarrota", color: Lux.down)
                    }
                }
            }

            HStack(spacing: 0) {
                metric("Ronda", value: roundValue(state))
                divider
                metric("Propiedades", value: "\(player.map { $0.propertyIDs.count } ?? 0)")
                if model.isFreeParkingEnabled {
                    divider
                    metric("Bote", value: currency(state.freeParkingPot), isGold: true)
                }
            }
            .padding(.vertical, 12)
            .background(Lux.elevated, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            turnControls
        }
        .padding(20)
        .background(Lux.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Lux.champagne.opacity(0.55), Lux.hairline, Lux.champagne.opacity(0.25)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
    }

    private func metric(_ title: String, value: String, isGold: Bool = false) -> some View {
        VStack(spacing: 3) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(1)
                .foregroundStyle(Lux.textSecondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(isGold ? Lux.gold : Lux.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(Lux.hairline)
            .frame(width: 1, height: 28)
    }

    private func stat(_ title: String, value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .foregroundStyle(Lux.textSecondary)
            Text(value)
                .foregroundStyle(color)
                .monospacedDigit()
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12), in: Capsule())
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
                HStack(spacing: 4) {
                    Text("Cambiar")
                    Image(systemName: "chevron.up.chevron.down")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Lux.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Lux.elevated, in: Capsule())
                .overlay(Capsule().stroke(Lux.hairline, lineWidth: 1))
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
                        Circle()
                            .fill(Lux.up)
                            .frame(width: 8, height: 8)
                        Text("Es tu turno")
                        Spacer()
                        Text("Terminar turno")
                        Image(systemName: "arrow.right")
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Lux.goldGradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Lux.textSecondary)
                    Text("Turno de \(currentPlayer.name)")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    if model.role == .host {
                        Button("Pasar turno") {
                            model.skipTurn()
                        }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Lux.gold)
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .background(Lux.elevated, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    // MARK: Actions

    private func actionsGrid(_ state: GameState) -> some View {
        let isMyTurn = model.isLocalPlayersTurn

        return BankCard(title: "Operaciones") {
            LazyVGrid(columns: columns, spacing: 18) {
                NavigationLink {
                    TransferView(model: model)
                } label: {
                    ActionTile(title: "Pagar", icon: "arrow.up.right")
                }

                NavigationLink {
                    CollectWithQRView(model: model)
                } label: {
                    ActionTile(title: "Cobrar", icon: "arrow.down.left")
                }

                tileButton(isEnabled: isMyTurn) {
                    amountAction = .salary
                } label: {
                    ActionTile(title: "GO", icon: "flag.checkered", isLocked: !isMyTurn)
                }

                if model.isFreeParkingEnabled {
                    tileButton(isEnabled: isMyTurn && state.freeParkingPot > 0) {
                        isConfirmingFreeParking = true
                    } label: {
                        ActionTile(
                            title: "Parking",
                            icon: "parkingsign",
                            detail: currency(state.freeParkingPot),
                            isLocked: !isMyTurn,
                            isFeatured: state.freeParkingPot > 0
                        )
                    }
                }

                if model.isMonopolife {
                    tileButton(isEnabled: isMyTurn && model.localPendingLifeCard == nil) {
                        model.drawLifeCard()
                    } label: {
                        ActionTile(title: "Tarjeta", icon: "suit.spade.fill", isLocked: !isMyTurn)
                    }
                }

                tileButton(isEnabled: isMyTurn) {
                    amountAction = .tax
                } label: {
                    ActionTile(title: "Impuesto", icon: "building.columns", isLocked: !isMyTurn)
                }

                tileButton(isEnabled: isMyTurn) {
                    amountAction = .travel
                } label: {
                    ActionTile(title: "Viajar", icon: "airplane", isLocked: !isMyTurn)
                }

                NavigationLink {
                    PayWithQRView(model: model)
                } label: {
                    ActionTile(title: "Escanear", icon: "qrcode.viewfinder")
                }

                NavigationLink {
                    MarketView(model: model)
                } label: {
                    ActionTile(title: "Mercado", icon: "chart.line.uptrend.xyaxis", badge: model.dealsAwaitingLocalPlayer.count)
                }

                if model.areCreditCardsEnabled {
                    NavigationLink {
                        CreditCardView(model: model)
                    } label: {
                        ActionTile(title: "Crédito", icon: "creditcard")
                    }
                }
            }
            .buttonStyle(.plain)

            Rectangle()
                .fill(Lux.hairline)
                .frame(height: 1)

            NavigationLink {
                BankruptcyView(model: model)
            } label: {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                    Text("Declararme en bancarrota")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Lux.down.opacity(0.9))
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
            .opacity(isEnabled ? 1 : 0.4)
    }

    private func pendingLifeCardBanner(_ pending: LifeCardDraw) -> some View {
        Button {
            model.presentedLifeCard = pending
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "suit.spade.fill")
                    .foregroundStyle(Lux.gold)
                Text("Tienes una Tarjeta de Vida por decidir")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Lux.textSecondary)
            }
            .padding(16)
            .background(Lux.gold.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Lux.gold.opacity(0.5), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var connectionBanner: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(Lux.gold)
            Text("Se perdió la conexión con el host. Esperando a que vuelva a abrir la partida…")
                .font(.footnote)
                .foregroundStyle(Lux.textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Lux.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Lux.gold.opacity(0.35), lineWidth: 1)
        }
    }

    // MARK: Players and properties

    private func playersCard(_ state: GameState) -> some View {
        BankCard(title: "Jugadores") {
            ForEach(Array(state.players.enumerated()), id: \.element.id) { index, player in
                if index > 0 {
                    Rectangle()
                        .fill(Lux.hairline)
                        .frame(height: 1)
                }
                playerRow(player, rank: index + 1, state: state)
            }
        }
    }

    private func playerRow(_ player: Player, rank: Int, state: GameState) -> some View {
        let isCurrent = player.id == state.currentPlayerID

        return HStack(spacing: 12) {
            Text("\(rank)")
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Lux.textSecondary)
                .frame(width: 16)

            Text(String(player.name.prefix(1)).uppercased())
                .font(.system(.subheadline, design: .serif, weight: .bold))
                .foregroundStyle(isCurrent ? .black : Lux.textPrimary)
                .frame(width: 34, height: 34)
                .background {
                    if isCurrent {
                        Circle().fill(Lux.goldGradient)
                    } else {
                        Circle().fill(Lux.elevated)
                    }
                }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(player.name)
                        .font(.subheadline.weight(.semibold))
                        .strikethrough(player.status == .bankrupt)
                    if player.id == model.localPlayerID {
                        Text("TÚ")
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(Lux.gold)
                    }
                }
                Text(playerDetail(player, isCurrent: isCurrent))
                    .font(.caption)
                    .foregroundStyle(player.status == .bankrupt || player.creditCardDebt > 0 ? Lux.down : Lux.textSecondary)
            }

            Spacer()

            Text(currency(player.balance))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
        .opacity(player.status == .bankrupt ? 0.5 : 1)
        .accessibilityElement(children: .combine)
    }

    private func playerDetail(_ player: Player, isCurrent: Bool) -> String {
        if player.status == .bankrupt {
            return "Bancarrota"
        }
        if player.creditCardDebt > 0 {
            return "Deuda \(currency(player.creditCardDebt))"
        }
        return isCurrent ? "En turno" : "\(player.propertyIDs.count) propiedades"
    }

    private func propertiesCard(_ state: GameState) -> some View {
        BankCard(title: "Propiedades") {
            ForEach(Array(state.properties.enumerated()), id: \.element.id) { index, property in
                if index > 0 {
                    Rectangle()
                        .fill(Lux.hairline)
                        .frame(height: 1)
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
                    Circle()
                        .fill(property.colorGroup.swatch)
                        .frame(width: 8, height: 8)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(property.name)
                            .font(.subheadline.weight(.semibold))
                        Text(ownerName(for: property, state: state))
                            .font(.caption)
                            .foregroundStyle(Lux.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(currency(property.purchasePrice))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                        if property.isMortgaged {
                            Text("Hipotecada")
                                .font(.caption2)
                                .foregroundStyle(Lux.down)
                        } else if property.constructionLevel > 0 {
                            Text("Nivel \(property.constructionLevel)")
                                .font(.caption2)
                                .foregroundStyle(Lux.up)
                        }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if property.ownerID == nil, isLocalPlayerActive(in: state), model.isLocalPlayersTurn {
                Button {
                    model.buy(propertyID: property.id)
                } label: {
                    Text("Comprar")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Lux.gold, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Helpers

    private func localPlayer(in state: GameState) -> Player? {
        state.players.first(where: { $0.id == model.localPlayerID })
    }

    private func roundValue(_ state: GameState) -> String {
        guard let roundLimit = state.monopolife?.roundLimit else {
            return "\(state.round)"
        }
        return "\(state.round)/\(roundLimit)"
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

/// An exchange-style shortcut: a gold glyph on a dark tile with its name below.
private struct ActionTile: View {
    let title: String
    let icon: String
    var detail: String?
    var badge = 0
    var isLocked = false
    var isFeatured = false

    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(isFeatured ? AnyShapeStyle(Color.black) : AnyShapeStyle(Lux.goldGradient))
                .frame(width: 50, height: 50)
                .background {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(isFeatured ? AnyShapeStyle(Lux.goldGradient) : AnyShapeStyle(Lux.elevated))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(Lux.hairline, lineWidth: 1)
                }
                .overlay(alignment: .topTrailing) {
                    if badge > 0 {
                        Text("\(badge)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 5)
                            .frame(minWidth: 18, minHeight: 18)
                            .background(Lux.gold, in: Capsule())
                            .offset(x: 5, y: -5)
                    } else if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Lux.textSecondary)
                            .padding(4)
                            .background(Lux.surface, in: Circle())
                            .offset(x: 4, y: -4)
                    }
                }

            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(Lux.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            if let detail {
                Text(detail)
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Lux.gold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
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
