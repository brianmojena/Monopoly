import SwiftUI

struct StartView: View {
    @State private var savedGame: SavedGame?
    @State private var isConfirmingDiscard = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "building.2.crop.circle")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)

                VStack(spacing: 8) {
                    Text("Monopoly")
                        .font(.largeTitle.bold())
                    Text("Banca local para tu partida")
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    if let savedGame {
                        savedGameCard(savedGame)
                    }

                    if savedGame == nil {
                        hostLink(title: "Alojar partida")
                            .buttonStyle(.borderedProminent)
                    } else {
                        hostLink(title: "Alojar partida nueva")
                            .buttonStyle(.bordered)
                    }

                    NavigationLink {
                        JoinView()
                    } label: {
                        Label("Unirse a partida", systemImage: "arrow.down.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .controlSize(.large)
            }
            .padding(24)
            .navigationTitle("Inicio")
            .onAppear {
                savedGame = GameStore.shared.load()
            }
            .confirmationDialog(
                "¿Descartar la partida guardada?",
                isPresented: $isConfirmingDiscard,
                titleVisibility: .visible
            ) {
                Button("Descartar partida", role: .destructive) {
                    GameStore.shared.delete()
                    savedGame = nil
                }
            } message: {
                Text("No se puede deshacer.")
            }
        }
    }

    private func hostLink(title: String) -> some View {
        NavigationLink {
            HostSetupView()
        } label: {
            Label(title, systemImage: "antenna.radiowaves.left.and.right")
                .frame(maxWidth: .infinity)
        }
    }

    private func savedGameCard(_ savedGame: SavedGame) -> some View {
        VStack(spacing: 8) {
            NavigationLink {
                ResumeHostView(savedGame: savedGame)
            } label: {
                Label("Continuar partida", systemImage: "play.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Text(summary(of: savedGame))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Descartar partida guardada", role: .destructive) {
                isConfirmingDiscard = true
            }
            .font(.footnote)
        }
        .padding(.bottom, 8)
    }

    private func summary(of savedGame: SavedGame) -> String {
        let names = savedGame.state.players.map(\.name).joined(separator: ", ")
        let date = savedGame.savedAt.formatted(date: .abbreviated, time: .shortened)
        return "Ronda \(savedGame.state.round) · \(names)\nGuardada \(date)"
    }
}


#Preview {
    StartView()
}
