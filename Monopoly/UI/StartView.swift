import SwiftUI

struct StartView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var savedGame: SavedGame?
    @State private var isConfirmingDiscard = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    brandHeader

                    VStack(alignment: .leading, spacing: 14) {
                        Text(savedGame == nil ? "Empieza una partida" : "Tu partida")
                            .font(.title2.weight(.bold))

                        if let savedGame {
                            savedGameCard(savedGame)
                        }

                        if savedGame == nil {
                            hostLink(title: "Alojar partida")
                        } else {
                            hostLink(title: "Alojar partida nueva")
                        }

                        joinLink
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

    private var brandHeader: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.14))
                        .frame(width: 52, height: 52)

                    Image(systemName: "building.2.crop.circle")
                        .font(.system(size: 27, weight: .semibold))
                }

                Spacer()

                Text("BANCA DIGITAL")
                    .font(.caption2.weight(.bold))
                    .tracking(1.4)
                    .foregroundStyle(.white.opacity(0.75))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Monopoly")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.75)

                Text("Banca local para tu partida")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.84))
            }

            boardStripe
        }
        .foregroundStyle(.white)
        .padding(24)
        .background(
            LinearGradient(
                colors: [brandGreen, brandGreen.opacity(0.78)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: brandGreen.opacity(0.22), radius: 18, y: 10)
    }

    private var boardStripe: some View {
        HStack(spacing: 4) {
            stripeTile(boardRed)
            stripeTile(boardGold)
            stripeTile(.white.opacity(0.88))
            stripeTile(boardGold)
            stripeTile(boardRed)
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

    private func hostLink(title: String) -> some View {
        NavigationLink {
            HostSetupView()
        } label: {
            HStack(spacing: 15) {
                actionIcon(systemName: "antenna.radiowaves.left.and.right", color: .white)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)

                    Text("Configura la banca y empieza a jugar")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.78))
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.white.opacity(0.72))
            }
            .foregroundStyle(.white)
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [boardRed, boardRed.opacity(0.82)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
            .shadow(color: boardRed.opacity(0.2), radius: 12, y: 7)
        }
        .buttonStyle(.plain)
    }

    private var joinLink: some View {
        NavigationLink {
            JoinView()
        } label: {
            HStack(spacing: 15) {
                actionIcon(systemName: "person.2.fill", color: brandGreen)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Unirse a partida")
                        .font(.headline)

                    Text("Conéctate a una sala cercana")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(brandGreen.opacity(0.24), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func actionIcon(systemName: String, color: Color) -> some View {
        Image(systemName: systemName)
            .font(.title3.weight(.semibold))
            .foregroundStyle(color)
            .frame(width: 42, height: 42)
            .background(.white.opacity(colorScheme == .dark ? 0.14 : 0.2), in: Circle())
    }

    private func savedGameCard(_ savedGame: SavedGame) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(boardGold)
                    .frame(width: 42, height: 42)
                    .background(boardGold.opacity(0.16), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Partida guardada")
                        .font(.headline)

                    Text("Lista para continuar")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Text(summary(of: savedGame))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineSpacing(2)

            NavigationLink {
                ResumeHostView(savedGame: savedGame)
            } label: {
                HStack {
                    Label("Continuar partida", systemImage: "play.fill")
                        .font(.headline)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(boardGreen, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)

            Button("Descartar partida guardada", role: .destructive) {
                isConfirmingDiscard = true
            }
            .font(.footnote.weight(.semibold))
            .frame(maxWidth: .infinity)
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(boardGold.opacity(0.58), lineWidth: 1.5)
        }
        .shadow(color: boardGold.opacity(0.12), radius: 14, y: 7)
    }

    private func summary(of savedGame: SavedGame) -> String {
        let names = savedGame.state.players.map(\.name).joined(separator: ", ")
        let date = savedGame.savedAt.formatted(date: .abbreviated, time: .shortened)
        return "Ronda \(savedGame.state.round) · \(names)\nGuardada \(date)"
    }

    private var screenBackground: some View {
        ZStack {
            Color(.systemGroupedBackground)

            Circle()
                .fill(boardRed.opacity(colorScheme == .dark ? 0.08 : 0.045))
                .frame(width: 260)
                .blur(radius: 8)
                .offset(x: 170, y: -300)

            Circle()
                .fill(brandGreen.opacity(colorScheme == .dark ? 0.1 : 0.05))
                .frame(width: 220)
                .blur(radius: 12)
                .offset(x: -180, y: 360)
        }
        .ignoresSafeArea()
    }

    private var brandGreen: Color {
        colorScheme == .dark
            ? Color(red: 0.12, green: 0.28, blue: 0.22)
            : Color(red: 0.08, green: 0.32, blue: 0.22)
    }

    private var boardGreen: Color {
        colorScheme == .dark
            ? Color(red: 0.18, green: 0.42, blue: 0.31)
            : Color(red: 0.1, green: 0.38, blue: 0.25)
    }

    private var boardRed: Color {
        colorScheme == .dark
            ? Color(red: 0.68, green: 0.12, blue: 0.15)
            : Color(red: 0.72, green: 0.08, blue: 0.11)
    }

    private var boardGold: Color {
        colorScheme == .dark
            ? Color(red: 0.96, green: 0.72, blue: 0.29)
            : Color(red: 0.74, green: 0.49, blue: 0.08)
    }
}

#Preview {
    StartView()
}
