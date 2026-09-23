import SwiftUI

struct MarketView: View {
    @ObservedObject var model: GameSessionModel

    var body: some View {
        Group {
            if let state = model.gameState, let localPlayerID = model.localPlayerID {
                List {
                    holdingsSection(state: state, localPlayerID: localPlayerID)
                    investmentsSection(state: state, localPlayerID: localPlayerID)

                    Section {
                        NavigationLink {
                            DealBuilderView(mode: .deal, model: model)
                        } label: {
                            Label("Nuevo trato", systemImage: "person.3.sequence")
                        }
                        NavigationLink {
                            DealBuilderView(mode: .openOffer, model: model)
                        } label: {
                            Label("Publicar oferta abierta", systemImage: "megaphone")
                        }
                    } header: {
                        Text("Negociar")
                    } footer: {
                        Text("Un trato puede mover dinero y acciones entre varios jugadores y se ejecuta cuando todos aceptan. Una oferta abierta se la queda el primero que la acepte.")
                    }

                    dealSection(
                        "Esperan tu respuesta",
                        deals: model.dealsAwaitingLocalPlayer,
                        state: state,
                        localPlayerID: localPlayerID
                    )
                    dealSection(
                        "Ofertas abiertas",
                        deals: state.marketDeals.filter { $0.isOpenOffer && $0.proposerID != localPlayerID },
                        state: state,
                        localPlayerID: localPlayerID
                    )
                    dealSection(
                        "Esperando a otros",
                        deals: state.marketDeals.filter {
                            $0.participantIDs.contains(localPlayerID) && !$0.pendingPlayerIDs.contains(localPlayerID)
                        },
                        state: state,
                        localPlayerID: localPlayerID
                    )
                }
            } else {
                ProgressView("Cargando partida…")
            }
        }
        .navigationTitle("Mercado")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
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
        .proximityReceiverBanner(model: model)
    }

    private func investmentsSection(state: GameState, localPlayerID: UUID) -> some View {
        let investments = state.rentInvestments.filter {
            $0.investorID == localPlayerID || $0.recipientID == localPlayerID
        }
        return Section("Inversiones activas") {
            if investments.isEmpty {
                Text("No participas en inversiones activas.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(investments) { investment in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(state.describe(investment))
                            .font(.subheadline)

                        HStack {
                            Text(investment.investorID == localPlayerID ? "Inversor" : "Receptor")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Proponer cancelación") {
                                model.proposeDeal(MarketDeal(
                                    proposerID: localPlayerID,
                                    cancelInvestment: investment
                                ))
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func holdingsSection(state: GameState, localPlayerID: UUID) -> some View {
        let holdings = state.properties.filter { $0.shares(of: localPlayerID) > 0 }
        return Section("Tus acciones") {
            if holdings.isEmpty {
                Text("Todavía no tienes acciones de ninguna propiedad.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(holdings) { property in
                    NavigationLink {
                        PropertyDetailView(propertyID: property.id, model: model)
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(property.name)
                                if property.ownership.count > 1 {
                                    Text(state.ownershipSummary(of: property))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text(percentage(property.shares(of: localPlayerID)))
                                    .fontWeight(.semibold)
                                if property.ownerID == localPlayerID {
                                    Text("Administras")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func dealSection(
        _ title: String,
        deals: [MarketDeal],
        state: GameState,
        localPlayerID: UUID
    ) -> some View {
        if !deals.isEmpty {
            Section(title) {
                ForEach(deals) { deal in
                    DealCard(deal: deal, state: state, localPlayerID: localPlayerID, model: model)
                }
            }
        }
    }
}

private struct DealCard: View {
    let deal: MarketDeal
    let state: GameState
    let localPlayerID: UUID
    @ObservedObject var model: GameSessionModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.headline)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                if let purchase = deal.sharedPurchase {
                    Text("Compra al banco de \(state.propertyName(purchase.propertyID))")
                        .font(.subheadline.weight(.medium))
                    ForEach(state.describe(purchase), id: \.self) { line in
                        Text("• \(line)")
                    }
                }
                if let investment = deal.proposedInvestment {
                    Text("• \(state.describe(investment))")
                }
                if let investment = deal.cancelInvestment {
                    Text("• Cancelar inversión: \(state.describe(investment))")
                }
                ForEach(Array(deal.transfers.enumerated()), id: \.offset) { _, transfer in
                    Text("• \(state.describe(transfer))")
                }
            }
            .font(.subheadline)

            if !deal.isOpenOffer {
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            actions
        }
        .padding(.vertical, 4)
    }

    private var title: String {
        if deal.isOpenOffer {
            return "Oferta de \(state.playerName(deal.proposerID))"
        }
        if deal.sharedPurchase != nil {
            return "Compra compartida"
        }
        if deal.proposedInvestment != nil {
            return "Inversión de renta"
        }
        if deal.cancelInvestment != nil {
            return "Cancelación de inversión"
        }
        return "Trato de \(state.playerName(deal.proposerID))"
    }

    private var icon: String {
        if deal.isOpenOffer {
            return "megaphone"
        }
        if deal.sharedPurchase != nil {
            return "house.and.flag"
        }
        return deal.proposedInvestment != nil || deal.cancelInvestment != nil
            ? "percent"
            : "arrow.triangle.swap"
    }

    private var statusText: String {
        let accepted = deal.acceptedBy.map(state.playerName).sorted().joined(separator: ", ")
        let pending = deal.pendingPlayerIDs.map(state.playerName).sorted().joined(separator: ", ")
        return pending.isEmpty ? "Aceptaron: \(accepted)" : "Aceptaron: \(accepted) · Faltan: \(pending)"
    }

    @ViewBuilder
    private var actions: some View {
        HStack {
            if deal.isOpenOffer {
                if deal.proposerID == localPlayerID {
                    Button("Retirar oferta", role: .destructive) {
                        model.rejectDeal(deal.id)
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("Aceptar oferta") {
                        model.acceptDeal(deal.id)
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if deal.pendingPlayerIDs.contains(localPlayerID) {
                Button("Aceptar") {
                    model.acceptDeal(deal.id)
                }
                .buttonStyle(.borderedProminent)
                Button("Rechazar", role: .destructive) {
                    model.rejectDeal(deal.id)
                }
                .buttonStyle(.bordered)
            } else {
                Button(deal.proposerID == localPlayerID ? "Retirar trato" : "Salirme del trato", role: .destructive) {
                    model.rejectDeal(deal.id)
                }
                .buttonStyle(.bordered)
            }
        }
    }
}
