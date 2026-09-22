import SwiftUI

struct TradeView: View {
    @ObservedObject var model: GameSessionModel
    @Environment(\.dismiss) private var dismiss

    @State private var counterpartyID: UUID?
    @State private var offeredPropertyIDs = Set<UUID>()
    @State private var requestedPropertyIDs = Set<UUID>()
    @State private var offeredMoneyText = ""
    @State private var requestedMoneyText = ""

    var body: some View {
        Group {
            if let state = model.gameState,
               let localPlayerID = model.localPlayerID {
                Form {
                    Section("Jugador del intercambio") {
                        Picker("Intercambiar con", selection: counterpartySelection) {
                            Text("Selecciona un jugador").tag(Optional<UUID>.none)
                            ForEach(activePlayers(in: state, excluding: localPlayerID)) { player in
                                Text(player.name).tag(Optional(player.id))
                            }
                        }

                        if counterpartyID == nil {
                            Text("Selecciona un jugador para ver sus propiedades.")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section("Ofreces") {
                        propertyToggles(
                            properties: propertiesOwned(by: localPlayerID, in: state),
                            selectedIDs: $offeredPropertyIDs
                        )
                        amountField(title: "Dinero que ofreces", text: $offeredMoneyText)
                    }

                    if let counterpartyID {
                        Section("Pides a cambio") {
                            propertyToggles(
                                properties: propertiesOwned(by: counterpartyID, in: state),
                                selectedIDs: $requestedPropertyIDs
                            )
                            amountField(title: "Dinero que pides", text: $requestedMoneyText)
                        }
                    }

                    Section {
                        Text("Este intercambio se ejecutará inmediatamente si el dominio lo considera válido. Todavía no hay aceptación negociable del otro jugador.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Button("Proponer intercambio") {
                            proposeTrade(from: localPlayerID)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canPropose)
                    }
                }
            } else {
                ProgressView("Cargando partida…")
            }
        }
        .navigationTitle("Intercambio")
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
    }

    private var counterpartySelection: Binding<UUID?> {
        Binding(
            get: { counterpartyID },
            set: {
                counterpartyID = $0
                requestedPropertyIDs.removeAll()
            }
        )
    }

    private var canPropose: Bool {
        guard counterpartyID != nil,
              let offeredMoney = parseAmount(offeredMoneyText),
              let requestedMoney = parseAmount(requestedMoneyText) else {
            return false
        }
        return offeredMoney >= 0 && requestedMoney >= 0
    }

    @ViewBuilder
    private func propertyToggles(
        properties: [Property],
        selectedIDs: Binding<Set<UUID>>
    ) -> some View {
        if properties.isEmpty {
            Text("Ninguna propiedad disponible")
                .foregroundStyle(.secondary)
        } else {
            ForEach(properties) { property in
                Toggle(isOn: propertySelection(for: property.id, selectedIDs: selectedIDs)) {
                    HStack {
                        Text(property.name)
                        Spacer()
                        Text(currency(property.purchasePrice))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func amountField(title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
#if os(iOS)
            .keyboardType(.numberPad)
#endif
    }

    private func propertySelection(
        for propertyID: UUID,
        selectedIDs: Binding<Set<UUID>>
    ) -> Binding<Bool> {
        Binding(
            get: { selectedIDs.wrappedValue.contains(propertyID) },
            set: { isSelected in
                if isSelected {
                    selectedIDs.wrappedValue.insert(propertyID)
                } else {
                    selectedIDs.wrappedValue.remove(propertyID)
                }
            }
        )
    }

    private func proposeTrade(from localPlayerID: UUID) {
        guard let counterpartyID,
              let offeredMoney = parseAmount(offeredMoneyText),
              let requestedMoney = parseAmount(requestedMoneyText),
              offeredMoney >= 0,
              requestedMoney >= 0 else {
            return
        }

        let offer = TradeOffer(
            fromPlayerID: localPlayerID,
            toPlayerID: counterpartyID,
            offeredPropertyIDs: Array(offeredPropertyIDs),
            offeredMoney: offeredMoney,
            requestedPropertyIDs: Array(requestedPropertyIDs),
            requestedMoney: requestedMoney
        )
        model.executeTrade(offer: offer)
        dismiss()
    }

    private func activePlayers(in state: GameState, excluding playerID: UUID) -> [Player] {
        state.players.filter { $0.id != playerID && $0.status == .active }
    }

    private func propertiesOwned(by playerID: UUID, in state: GameState) -> [Property] {
        state.properties.filter { $0.ownerID == playerID }
    }

    private func parseAmount(_ text: String) -> Int? {
        text.isEmpty ? 0 : Int(text)
    }

    private func currency(_ amount: Int) -> String {
        "$\(amount)"
    }
}
