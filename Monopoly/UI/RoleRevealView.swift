import SwiftUI

/// Shows each player on this device their secret role with the roulette, one after
/// another. On the host, players without a phone get a "pass the phone" screen first
/// so nobody else sees their role.
struct RoleRevealView: View {
    @ObservedObject var model: GameSessionModel
    @State private var readyPlayerID: UUID?

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            if let player = model.pendingRoleReveals.first,
               let role = model.gameState?.monopolife?.profiles[player.id]?.role {
                if player.id == model.ownPlayerID || model.role == .client || readyPlayerID == player.id {
                    RoleRouletteView(playerName: player.name, role: role) {
                        model.acknowledgeRole(for: player.id)
                    }
                    .id(player.id)
                } else {
                    passPhoneView(to: player)
                }
            }
        }
    }

    private func passPhoneView(to player: Player) -> some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "iphone.and.arrow.forward")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("Pasa el teléfono a \(player.name)")
                .font(.system(.title, design: .rounded, weight: .bold))
                .multilineTextAlignment(.center)
            Text("Su rol es secreto. Que nadie más mire la pantalla.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button {
                readyPlayerID = player.id
            } label: {
                Text("Soy \(player.name)")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
    }
}

struct RoleRouletteView: View {
    let playerName: String
    let role: LifeRole
    let onAcknowledge: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rotation: Double = 0
    @State private var isRevealed = false

    private static let spinDuration = 4.2

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if isRevealed {
                    Text("\(playerName), tu rol es…")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    RoleCardView(role: role)
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                    Button {
                        onAcknowledge()
                    } label: {
                        Text("¡Entendido!")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(role.color)
                } else {
                    Text("Monopolife")
                        .font(.system(.largeTitle, design: .rounded, weight: .black))
                    Text("Girando la ruleta de \(playerName)…")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    wheel
                        .padding(.top, 8)
                }
            }
            .padding(24)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .sensoryFeedback(.success, trigger: isRevealed)
        .task {
            await spin()
        }
    }

    private var wheel: some View {
        ZStack(alignment: .top) {
            RouletteWheel()
                .rotationEffect(.degrees(rotation))
                .shadow(color: .black.opacity(0.18), radius: 12, y: 6)

            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 34))
                .foregroundStyle(.primary)
                .shadow(radius: 2)
                .offset(y: -18)
        }
        .frame(maxWidth: 340)
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel("Ruleta de roles")
    }

    private func spin() async {
        guard !reduceMotion else {
            isRevealed = true
            return
        }

        // Segment `index` is centered `index * 60 + 30` degrees clockwise from the
        // top; turning the wheel by the rest of the circle brings it under the pointer.
        let segment = 360.0 / Double(LifeRole.allCases.count)
        let index = Double(LifeRole.allCases.firstIndex(of: role) ?? 0)
        let target = 360.0 * 6 - (index * segment + segment / 2)
        withAnimation(.timingCurve(0.1, 0.75, 0.2, 1, duration: Self.spinDuration)) {
            rotation = target
        }
        try? await Task.sleep(for: .seconds(Self.spinDuration + 0.4))
        withAnimation(.spring(duration: 0.5)) {
            isRevealed = true
        }
    }
}

private struct RouletteWheel: View {
    private let roles = LifeRole.allCases

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let segment = 360.0 / Double(roles.count)

            ZStack {
                ForEach(Array(roles.enumerated()), id: \.element) { index, role in
                    WheelSegment(
                        start: .degrees(Double(index) * segment - 90),
                        end: .degrees(Double(index + 1) * segment - 90)
                    )
                    .fill(role.color.gradient)

                    VStack(spacing: 2) {
                        Text(role.definition.emoji)
                            .font(.system(size: size * 0.11))
                        Text(role.definition.name)
                            .font(.system(size: size * 0.045, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .frame(width: size * 0.3)
                    .offset(y: -size * 0.3)
                    .rotationEffect(.degrees(Double(index) * segment + segment / 2))
                }

                Circle()
                    .stroke(.white, lineWidth: 5)
                Circle()
                    .fill(.white)
                    .frame(width: size * 0.16)
                    .overlay {
                        Text("😊")
                            .font(.system(size: size * 0.08))
                    }
            }
            .frame(width: size, height: size)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private struct WheelSegment: Shape {
    let start: Angle
    let end: Angle

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        path.move(to: center)
        path.addArc(center: center, radius: min(rect.width, rect.height) / 2, startAngle: start, endAngle: end, clockwise: false)
        path.closeSubpath()
        return path
    }
}

#Preview {
    RoleRouletteView(playerName: "Ana", role: .globetrotter) {}
}
