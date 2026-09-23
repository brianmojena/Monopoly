import SwiftUI

struct SettingsView: View {
    @AppStorage(AppSettings.Key.playerName) private var playerName = ""
    @AppStorage(AppSettings.Key.keepsScreenOn) private var keepsScreenOn = true

    var body: some View {
        Form {
            Section {
                TextField("Tu nombre", text: $playerName)
                    .submitLabel(.done)
            } header: {
                Text("Tu nombre")
            } footer: {
                Text("Se usa al alojar o unirte a una partida, y para volver a la tuya como el mismo jugador.")
            }

            Section {
                Toggle(isOn: $keepsScreenOn) {
                    Label("Mantener la pantalla encendida", systemImage: "sun.max")
                }
            } footer: {
                Text("Durante una partida. Si el iPhone se bloquea, se desconecta de los demás hasta que lo vuelvas a abrir.")
            }
        }
        .navigationTitle("Ajustes")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
