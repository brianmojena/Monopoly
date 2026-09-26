import SwiftUI

extension LifeRole {
    var color: Color {
        switch self {
        case .consumer:
            return Color(red: 0.87, green: 0.25, blue: 0.52)
        case .entrepreneur:
            return Color(red: 0.16, green: 0.42, blue: 0.82)
        case .saver:
            return Color(red: 0.13, green: 0.58, blue: 0.36)
        case .social:
            return Color(red: 0.93, green: 0.52, blue: 0.12)
        case .globetrotter:
            return Color(red: 0.08, green: 0.6, blue: 0.66)
        case .chameleon:
            return Color(red: 0.5, green: 0.7, blue: 0.1)
        case .lender:
            return Color(red: 0.36, green: 0.4, blue: 0.55)
        case .rival:
            return Color(red: 0.82, green: 0.16, blue: 0.2)
        case .minimalist:
            return Color(red: 0.62, green: 0.52, blue: 0.4)
        }
    }
}

extension HappinessReason {
    var title: String {
        switch self {
        case let .role(effect):
            return effect.description
        case let .lifeCard(cardID):
            return LifeCards.card(withID: cardID)?.title ?? "Tarjeta de Vida"
        case .bankruptcy:
            return "Bancarrota"
        case .rentVisit:
            return "Saliste a un lugar"
        case let .newDisguise(role):
            return "Ahora eres \(role.definition.emoji) \(role.definition.name)"
        }
    }

    /// Groups reasons for the final breakdown: each like or dislike, all cards
    /// together, and bankruptcy.
    var breakdownTitle: String {
        switch self {
        case let .role(effect):
            return effect.description
        case .lifeCard:
            return "Tarjetas de Vida"
        case .bankruptcy:
            return "Bancarrota"
        case .rentVisit:
            return "Salir por la ciudad"
        case .newDisguise:
            return "Cambios de personalidad"
        }
    }
}

func happinessText(_ delta: Int) -> String {
    delta > 0 ? "+\(delta)" : delta < 0 ? "−\(-delta)" : "0"
}

func happinessColor(_ delta: Int) -> Color {
    delta > 0 ? .green : delta < 0 ? .red : .secondary
}

/// A role's full description: what it likes and dislikes.
struct RoleCardView: View {
    let role: LifeRole
    /// The Chameleon's current personality.
    var disguise: LifeRole?
    /// Who the Rival is after.
    var targetName: String?

    private var definition: LifeRoleDefinition {
        role.definition
    }

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 8) {
                Text(definition.emoji)
                    .font(.app(size: 72))
                Text(definition.name)
                    .font(.app(.largeTitle, weight: .black))
                    .foregroundStyle(role.color)
                Text(definition.summary)
                    .font(.app(.headline))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                Label("Te hace feliz", systemImage: "face.smiling")
                    .font(.app(.subheadline, weight: .bold))
                    .foregroundStyle(.green)
                ForEach(definition.likes, id: \.self) { like in
                    Text("• \(like)")
                        .font(.app(.subheadline))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Label("No te gusta", systemImage: "cloud.rain")
                    .font(.app(.subheadline, weight: .bold))
                    .foregroundStyle(.red)
                    .padding(.top, 4)
                Text("• \(definition.dislike)")
                    .font(.app(.subheadline))
                    .fixedSize(horizontal: false, vertical: true)

                if let disguise {
                    disguiseSection(disguise)
                }

                if let targetName {
                    Label("Tu objetivo: \(targetName)", systemImage: "scope")
                        .font(.app(.subheadline, weight: .bold))
                        .foregroundStyle(role.color)
                        .padding(.top, 4)
                }

                Text("Cada Tarjeta de Vida te afecta distinto según tu rol. Tu rol es secreto: nadie más lo ve hasta el final.")
                    .font(.app(.footnote))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(role.color.opacity(0.5), lineWidth: 1.5)
            }
        }
    }

    private func disguiseSection(_ disguise: LifeRole) -> some View {
        let personality = disguise.definition
        return VStack(alignment: .leading, spacing: 8) {
            Divider()
            Text("Tu personalidad ahora: \(personality.emoji) \(personality.name)")
                .font(.app(.subheadline, weight: .bold))
                .foregroundStyle(disguise.color)
            ForEach(personality.likes, id: \.self) { like in
                Text("😊 \(like)")
                    .font(.app(.subheadline))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("😞 \(personality.dislike)")
                .font(.app(.subheadline))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }
}

struct RoleSheet: View {
    let role: LifeRole
    var disguise: LifeRole?
    var targetName: String?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                RoleCardView(role: role, disguise: disguise, targetName: targetName)
                    .padding(20)
            }
            .navigationTitle("Mi rol")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
        }
    }
}
