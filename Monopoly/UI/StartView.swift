import SwiftUI

struct StartView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(AppSettings.Key.playerName) private var playerName = ""
    @State private var recentGames: [RecentGame] = []
    @State private var gamePendingDeletion: RecentGame?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    brandHeader

                    if trimmedPlayerName.isEmpty {
                        nameCard
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Empieza una partida")
                            .font(.app(.title2, weight: .bold))

                        hostButton
                        joinLink
                        rulesLink
                    }

                    if !recentGames.isEmpty {
                        recentGamesSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(screenBackground)
            .navigationTitle("Inicio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("Ajustes", systemImage: "gearshape")
                    }
                }
            }
            .onAppear(perform: loadRecentGames)
            .confirmationDialog(
                deletionTitle,
                isPresented: Binding(
                    get: { gamePendingDeletion != nil },
                    set: { if !$0 { gamePendingDeletion = nil } }
                ),
                titleVisibility: .visible,
                presenting: gamePendingDeletion
            ) { game in
                Button(game.isHosted ? "Borrar partida" : "Quitar de la lista", role: .destructive) {
                    delete(game)
                }
            } message: { game in
                Text(game.isHosted
                    ? "Tu iPhone es la banca de esta partida: se pierde para todos y no se puede deshacer."
                    : "La partida sigue en el iPhone del host; solo desaparece de esta lista.")
            }
        }
    }

    private var trimmedPlayerName: String {
        playerName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var nameCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("¿Cómo te llamas?")
                .font(.app(.headline))
            TextField("Tu nombre", text: $playerName)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.done)
            Text("Se usa en todas tus partidas. Puedes cambiarlo en Ajustes.")
                .font(.app(.footnote))
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var brandHeader: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.14))
                        .frame(width: 52, height: 52)

                    Image(systemName: "building.2.crop.circle")
                        .font(.app(size: 27, weight: .semibold))
                }

                Spacer()

                Text("BANCA DIGITAL")
                    .font(.app(.caption2, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(.white.opacity(0.75))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Monopoly")
                    .font(.app(size: 44, weight: .black))
                    .minimumScaleFactor(0.75)

                Text("Banca local para tu partida")
                    .font(.app(.headline))
                    .foregroundStyle(.white.opacity(0.84))
            }

            boardStripe
        }
        .foregroundStyle(.white)
        .padding(24)
        .background(
            LinearGradient(
                colors: [Color.bankGreen, Color.bankGreen.opacity(0.78)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: Color.bankGreen.opacity(0.22), radius: 18, y: 10)
    }

    private var boardStripe: some View {
        HStack(spacing: 4) {
            stripeTile(Color.boardRed)
            stripeTile(Color.boardGold)
            stripeTile(.white.opacity(0.88))
            stripeTile(Color.boardGold)
            stripeTile(Color.boardRed)
        }
        .frame(height: 9)
        .clipShape(Capsule())
        .accessibilityHidden(true)
    }

    private func stripeTile(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(color)
            .frame(maxWidth: .infinity)
    }

    private var hostButton: some View {
        Button {
            appModel.hostNewGame()
        } label: {
            HStack(spacing: 15) {
                actionIcon(systemName: "antenna.radiowaves.left.and.right", color: .white)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Alojar partida")
                        .font(.app(.headline))

                    Text("Configura la banca y empieza a jugar")
                        .font(.app(.subheadline))
                        .foregroundStyle(.white.opacity(0.78))
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.app(.footnote, weight: .bold))
                    .foregroundStyle(.white.opacity(0.72))
            }
            .foregroundStyle(.white)
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [Color.boardRed, Color.boardRed.opacity(0.82)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
            .shadow(color: Color.boardRed.opacity(0.2), radius: 12, y: 7)
        }
        .buttonStyle(.plain)
    }

    private var joinLink: some View {
        NavigationLink {
            JoinView()
        } label: {
            HStack(spacing: 15) {
                actionIcon(systemName: "person.2.fill", color: Color.bankGreen)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Unirse a partida")
                        .font(.app(.headline))

                    Text("Conéctate a una sala cercana")
                        .font(.app(.subheadline))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.app(.footnote, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.bankGreen.opacity(0.24), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var rulesLink: some View {
        NavigationLink {
            RulesView()
        } label: {
            Label("Cómo se juega", systemImage: "book.fill")
                .font(.app(.subheadline, weight: .semibold))
                .foregroundStyle(Color.bankGreen)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func actionIcon(systemName: String, color: Color) -> some View {
        Image(systemName: systemName)
            .font(.app(.title3, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 42, height: 42)
            .background(.white.opacity(colorScheme == .dark ? 0.14 : 0.2), in: Circle())
    }

    // MARK: Recent games

    private var recentGamesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Partidas recientes")
                .font(.app(.title2, weight: .bold))

            ForEach(recentGames) { game in
                recentGameCard(game)
            }
        }
    }

    private func recentGameCard(_ game: RecentGame) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: game.isHosted ? "building.columns.fill" : "person.2.fill")
                    .font(.app(.title3, weight: .semibold))
                    .foregroundStyle(Color.boardGold)
                    .frame(width: 42, height: 42)
                    .background(Color.boardGold.opacity(0.16), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(game.title)
                        .font(.app(.headline))
                    Text(game.summary)
                        .font(.app(.subheadline))
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)
                }

                Spacer(minLength: 8)

                Menu {
                    Button(game.isHosted ? "Borrar partida" : "Quitar de la lista", systemImage: "trash", role: .destructive) {
                        gamePendingDeletion = game
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.app(.body, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Más opciones")
            }

            Button {
                open(game)
            } label: {
                HStack {
                    Label(game.isHosted ? "Continuar partida" : "Volver a entrar", systemImage: "play.fill")
                        .font(.app(.headline))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.app(.footnote, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(Color.boardGreen, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!game.isHosted && trimmedPlayerName.isEmpty)
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.boardGold.opacity(0.4), lineWidth: 1)
        }
    }

    private var deletionTitle: String {
        gamePendingDeletion?.isHosted == true ? "¿Borrar la partida?" : "¿Quitar la partida de la lista?"
    }

    private func loadRecentGames() {
        recentGames = RecentGame.load()
    }

    private func open(_ game: RecentGame) {
        switch game.kind {
        case let .hosted(savedGame):
            appModel.resume(savedGame)
        case let .joined(joinedGame):
            appModel.rejoin(joinedGame)
        }
    }

    private func delete(_ game: RecentGame) {
        switch game.kind {
        case .hosted:
            appModel.deleteSavedGame(roomID: game.id)
        case .joined:
            appModel.forgetJoinedGame(roomID: game.id)
        }
        loadRecentGames()
    }

    private var screenBackground: some View {
        ZStack {
            Color(.systemGroupedBackground)

            Circle()
                .fill(Color.boardRed.opacity(colorScheme == .dark ? 0.08 : 0.045))
                .frame(width: 260)
                .blur(radius: 8)
                .offset(x: 170, y: -300)

            Circle()
                .fill(Color.bankGreen.opacity(colorScheme == .dark ? 0.1 : 0.05))
                .frame(width: 220)
                .blur(radius: 12)
                .offset(x: -180, y: 360)
        }
        .ignoresSafeArea()
    }
}

#Preview {
    StartView()
        .environmentObject(AppModel())
}
