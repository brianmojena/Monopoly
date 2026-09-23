import SwiftUI

struct GameBoardView: View {
    @ObservedObject var model: GameSessionModel
    @State private var amountAction: AmountAction?
    @State private var isShowingRole = false
    @State private var isShowingRules = false
    @State private var isConfirmingFreeParking = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)

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

                        balanceHeader(state)

                        if let pending = model.localPendingLifeCard, model.presentedLifeCard == nil {
                            pendingLifeCardBanner(pending)
                        }

                        if isLocalPlayerActive(in: state) {
                            actionsGrid(state)
                        }

                        if let boardEvents = state.boardEvents {
                            ActiveBoardEventsCard(events: boardEvents, state: state)
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
        .sheet(item: $model.presentedBoardEvent) { occurrence in
            if let state = model.gameState {
                BoardEventSheet(occurrence: occurrence, state: state)
            }
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

    private func balanceHeader(_ state: GameState) -> some View {
        let player = localPlayer(in: state)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(player?.name ?? "Jugador")
                        playerSwitcher
                    }
                    .font(.app(.subheadline, weight: .semibold))
                    .foregroundStyle(Lux.textSecondary)

                    Text(currency(player?.balance ?? 0))
                        .font(.app(size: 34, weight: .semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .contentTransition(.numericText(value: Double(player?.balance ?? 0)))
                        .animation(.spring, value: player?.balance)

                    if let player, player.creditCardDebt > 0 {
                        Text("Deuda de tarjeta \(currency(player.creditCardDebt))")
                            .font(.app(.caption, weight: .medium))
                            .foregroundStyle(Lux.down)
                    } else if player?.status == .bankrupt {
                        Text("En bancarrota")
                            .font(.app(.caption, weight: .medium))
                            .foregroundStyle(Lux.down)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    pill("Ronda \(roundValue(state))")
                    if model.isFreeParkingEnabled {
                        pill("Bote \(currency(state.freeParkingPot))", isGold: true)
                    }
                }
            }

            turnControls
        }
    }

    private func pill(_ text: String, isGold: Bool = false) -> some View {
        Text(text)
            .font(.app(.caption, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(isGold ? Lux.gold : Lux.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Lux.surface, in: Capsule())
            .overlay(Capsule().stroke(isGold ? Lux.gold.opacity(0.35) : Lux.hairline, lineWidth: 1))
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
                Image(systemName: "chevron.up.chevron.down")
                    .font(.app(.caption2, weight: .bold))
                    .foregroundStyle(Lux.gold)
                    .accessibilityLabel("Cambiar de jugador")
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
                            .frame(width: 7, height: 7)
                        Text("Es tu turno")
                        Spacer()
                        Text("Terminar turno")
                        Image(systemName: "arrow.right")
                    }
                    .font(.app(.subheadline, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(Lux.goldGradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Lux.textSecondary)
                    Text("Turno de \(currentPlayer.name)")
                        .font(.app(.subheadline, weight: .medium))
                    Spacer()
                    if model.role == .host {
                        Button("Pasar turno") {
                            model.skipTurn()
                        }
                        .font(.app(.caption, weight: .bold))
                        .foregroundStyle(Lux.gold)
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(Lux.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Lux.hairline, lineWidth: 1)
                }
            }
        }
    }

    // MARK: Actions

    private func actionsGrid(_ state: GameState) -> some View {
        let isMyTurn = model.isLocalPlayersTurn

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Acciones")
                    .font(.app(.title3, weight: .bold))
                Spacer()
                if !isMyTurn {
                    Text("\(Image(systemName: "lock.fill")) solo en tu turno")
                        .font(.app(.caption))
                        .foregroundStyle(Lux.textSecondary)
                }
            }

            LazyVGrid(columns: columns, spacing: 12) {
                NavigationLink {
                    PayWithQRView(model: model)
                } label: {
                    ActionTile(title: "Pagar", detail: "Escanear QR", icon: "arrow.up.right", tint: Lux.down)
                }

                NavigationLink {
                    CollectWithQRView(model: model)
                } label: {
                    ActionTile(title: "Cobrar", detail: "Mostrar mi QR", icon: "arrow.down.left", tint: Lux.up)
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
                            tint: Lux.gold,
                            isLocked: !isMyTurn,
                            highlightsDetail: state.freeParkingPot > 0
                        )
                    }
                }

                if model.isMonopolife {
                    tileButton(isEnabled: isMyTurn && model.localPendingLifeCard == nil) {
                        model.drawLifeCard()
                    } label: {
                        ActionTile(title: "Tarjeta de Vida", detail: "Suerte / Comunidad", icon: "suit.spade.fill", tint: .orange, isLocked: !isMyTurn)
                    }
                }

                tileButton(isEnabled: isMyTurn) {
                    amountAction = .travel
                } label: {
                    ActionTile(title: "Viajar", detail: "Desde \(currency(TravelRoute.sameSide.fare))", icon: "airplane", tint: .cyan, isLocked: !isMyTurn)
                }

                tileButton(isEnabled: isMyTurn) {
                    amountAction = .tax
                } label: {
                    ActionTile(title: "Impuesto", detail: "Pagar al banco", icon: "building.columns", tint: .purple, isLocked: !isMyTurn)
                }

                NavigationLink {
                    MarketView(model: model)
                } label: {
                    ActionTile(
                        title: "Mercado",
                        detail: "Tratos y acciones",
                        icon: "chart.line.uptrend.xyaxis",
                        tint: .indigo,
                        badge: model.dealsAwaitingLocalPlayer.count
                    )
                }

                if model.areCreditCardsEnabled {
                    NavigationLink {
                        CreditCardView(model: model)
                    } label: {
                        ActionTile(title: "Crédito", detail: "Préstamos", icon: "creditcard", tint: .pink)
                    }
                }
            }
            .buttonStyle(.plain)

            NavigationLink {
                BankruptcyView(model: model)
            } label: {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                    Text("Declararme en bancarrota")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.app(.caption, weight: .bold))
                }
                .font(.app(.footnote, weight: .semibold))
                .foregroundStyle(Lux.down.opacity(0.9))
                .padding(.horizontal, 4)
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
                    .font(.app(.subheadline, weight: .semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.app(.caption, weight: .bold))
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
                .font(.app(.footnote))
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
                .font(.app(.caption, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Lux.textSecondary)
                .frame(width: 16)

            Text(String(player.name.prefix(1)).uppercased())
                .font(.app(.subheadline, weight: .bold))
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
                        .font(.app(.subheadline, weight: .semibold))
                        .strikethrough(player.status == .bankrupt)
                    if player.id == model.localPlayerID {
                        Text("TÚ")
                            .font(.app(.caption2, weight: .heavy))
                            .foregroundStyle(Lux.gold)
                    }
                }
                Text(playerDetail(player, isCurrent: isCurrent))
                    .font(.app(.caption))
                    .foregroundStyle(player.status == .bankrupt || player.creditCardDebt > 0 ? Lux.down : Lux.textSecondary)
            }

            Spacer()

            Text(currency(player.balance))
                .font(.app(.subheadline, weight: .semibold))
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
                    PropertyPhotoView(property: property)
                        .frame(width: 58, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(property.colorGroup.swatch)
                                .frame(height: 3)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(property.name)
                            .font(.app(.subheadline, weight: .semibold))
                        Text(ownerName(for: property, state: state))
                            .font(.app(.caption))
                            .foregroundStyle(Lux.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(currency(property.purchasePrice))
                            .font(.app(.subheadline, weight: .semibold))
                            .monospacedDigit()
                        if property.isMortgaged {
                            Text("Hipotecada")
                                .font(.app(.caption2))
                                .foregroundStyle(Lux.down)
                        } else if property.constructionLevel > 0, model.canSeeLevel(of: property) {
                            Text("Nivel \(property.constructionLevel)")
                                .font(.app(.caption2))
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
                        .font(.app(.caption, weight: .bold))
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
    let detail: String
    let icon: String
    let tint: Color
    var badge = 0
    var isLocked = false
    var highlightsDetail = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Image(systemName: icon)
                    .font(.app(size: 20, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 44, height: 44)
                    .background(tint.opacity(0.12), in: Circle())

                Spacer(minLength: 0)

                if badge > 0 {
                    Text("\(badge)")
                        .font(.app(.caption2, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 6)
                        .frame(minWidth: 20, minHeight: 20)
                        .background(Lux.gold, in: Capsule())
                } else if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.app(.caption2))
                        .foregroundStyle(Lux.textSecondary)
                }
            }

            Spacer(minLength: 14)

            Text(title)
                .font(.app(.headline))
                .foregroundStyle(Lux.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(detail)
                .font(.app(.caption, weight: highlightsDetail ? .semibold : .regular))
                .monospacedDigit()
                .foregroundStyle(highlightsDetail ? Lux.gold : Lux.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.top, 2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
        .background(Lux.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Lux.hairline, lineWidth: 1)
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
