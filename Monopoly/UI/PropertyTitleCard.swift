import SwiftUI

/// A property's title card as printed in Ultimate Banking: the color band with the five
/// rent levels on top, and the board number, name and price in gold on black leather.
struct PropertyTitleCard: View {
    static let size = CGSize(width: 128, height: 204)
    private static let bandHeight: CGFloat = 32
    /// Where the black face starts, below the band and its trim, so buttons laid over
    /// the card can sit on the face.
    static let faceTop = bandHeight + 4

    let property: Property
    /// The property's place in board order.
    let number: Int

    private let cornerRadius: CGFloat = 9

    var body: some View {
        VStack(spacing: 0) {
            levelBand

            Rectangle()
                .fill(Color.black)
                .frame(height: 2.5)
            Rectangle()
                .fill(TitleCardInk.goldGradient)
                .frame(height: 1.5)

            face
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background {
            LeatherBackground()
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
        .overlay {
            if property.isMortgaged {
                mortgagedBanner
            }
        }
        .shadow(color: .black.opacity(0.55), radius: 6, y: 3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    // MARK: Level band

    /// Ultimate Banking prints levels 1...5; the app counts them 0...4.
    private var printedLevel: Int {
        property.constructionLevel + 1
    }

    private var levelBand: some View {
        HStack(spacing: -2) {
            ForEach(1...5, id: \.self) { level in
                levelDiamond(level, isCurrent: level == printedLevel && !property.isMortgaged)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.bandHeight)
        .background {
            property.colorGroup.swatch
                .overlay {
                    LinearGradient(
                        colors: [.white.opacity(0.14), .clear, .black.opacity(0.14)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
        }
    }

    private func levelDiamond(_ level: Int, isCurrent: Bool) -> some View {
        let side: CGFloat = 26

        return ZStack {
            Diamond()
                .fill(isCurrent ? Color(white: 0.07) : property.colorGroup.swatch)
            Diamond()
                .stroke(isCurrent ? AnyShapeStyle(TitleCardInk.goldGradient) : AnyShapeStyle(levelInk.opacity(0.75)), lineWidth: 1.4)
            Text("\(level)")
                .font(.system(size: 11, weight: .bold).width(.condensed))
                .foregroundStyle(isCurrent ? AnyShapeStyle(TitleCardInk.goldGradient) : AnyShapeStyle(levelInk))
        }
        .frame(width: side, height: side)
        .zIndex(isCurrent ? 1 : 0)
    }

    /// Dark ink like the printed card, except on the dark swatches where it would vanish.
    private var levelInk: Color {
        switch property.colorGroup {
        case .brown, .green, .darkBlue:
            return .white.opacity(0.85)
        default:
            return .black.opacity(0.7)
        }
    }

    // MARK: Face

    private var face: some View {
        VStack(spacing: 0) {
            // Leaves room for the collect button in the top corner.
            Spacer(minLength: 26)

            numberCoin

            Text(property.name.uppercased())
                .font(.system(size: 15, weight: .bold).width(.condensed))
                .foregroundStyle(TitleCardInk.goldGradient)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .frame(height: 40)
                .padding(.horizontal, 8)
                .padding(.top, 8)

            Spacer(minLength: 6)

            MonopolyPrice(amount: property.purchasePrice)
                .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity)
    }

    private var numberCoin: some View {
        Text("\(number)")
            .font(.system(size: 15, weight: .heavy).width(.condensed))
            .monospacedDigit()
            .foregroundStyle(Color(white: 0.06))
            .frame(width: 30, height: 30)
            .background {
                Circle()
                    .fill(TitleCardInk.goldGradient)
                    .overlay {
                        Circle()
                            .stroke(Color.black.opacity(0.35), lineWidth: 1)
                            .padding(2.5)
                    }
            }
    }

    private var mortgagedBanner: some View {
        Text("HIPOTECADA")
            .font(.system(size: 13, weight: .heavy).width(.condensed))
            .tracking(1)
            .foregroundStyle(.white)
            .frame(width: Self.size.width * 1.3)
            .padding(.vertical, 5)
            .background(Lux.down.opacity(0.92))
            .rotationEffect(.degrees(-32))
            .frame(width: Self.size.width, height: Self.size.height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var accessibilityText: String {
        var parts = ["Propiedad \(number)", property.name, "nivel \(printedLevel)", "$\(property.purchasePrice)"]
        if property.isMortgaged {
            parts.append("hipotecada")
        }
        return parts.joined(separator: ", ")
    }
}

/// The small gold button laid over a title card's top corner to collect its rent by QR.
struct CollectRentChip: View {
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "qrcode")
                .font(.system(size: 9, weight: .bold))
            Text("COBRAR")
                .font(.system(size: 10, weight: .heavy).width(.condensed))
                .tracking(0.4)
        }
        .foregroundStyle(Color(white: 0.06))
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(TitleCardInk.goldGradient, in: Capsule())
        .overlay {
            Capsule()
                .stroke(Color.black.opacity(0.35), lineWidth: 0.5)
        }
        // A bigger tap area than the chip; it also insets it from the card's edges.
        .padding(6)
        .contentShape(Rectangle())
        .accessibilityLabel("Cobrar renta con QR")
    }
}

// MARK: - Pieces

private enum TitleCardInk {
    static let goldGradient = LinearGradient(
        colors: [
            Color(red: 1.0, green: 0.87, blue: 0.45),
            Color(red: 0.95, green: 0.74, blue: 0.2),
            Color(red: 0.8, green: 0.57, blue: 0.12)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}

/// The price with Ultimate Banking's M, which carries two bars across its middle.
private struct MonopolyPrice: View {
    let amount: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            Text("M")
                .overlay {
                    VStack(spacing: 2) {
                        Rectangle().frame(height: 1.8)
                        Rectangle().frame(height: 1.8)
                    }
                    .padding(.horizontal, -2)
                    .offset(y: 1)
                }
            Text("\(amount)")
                .monospacedDigit()
        }
        .font(.system(size: 26, weight: .bold).width(.condensed))
        .foregroundStyle(TitleCardInk.goldGradient)
    }
}

private struct Diamond: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
            path.closeSubpath()
        }
    }
}

/// Black leather: a soft sheen over fine grain. The grain uses a fixed seed so every
/// card looks the same and it doesn't shimmer on redraw.
private struct LeatherBackground: View {
    var body: some View {
        ZStack {
            Color(white: 0.055)

            RadialGradient(
                colors: [Color.white.opacity(0.07), .clear],
                center: UnitPoint(x: 0.35, y: 0.3),
                startRadius: 0,
                endRadius: 170
            )

            Canvas { context, size in
                var generator = SeededGenerator(seed: 0x4D4F_4E4F)
                for _ in 0..<520 {
                    let x = CGFloat.random(in: 0...size.width, using: &generator)
                    let y = CGFloat.random(in: 0...size.height, using: &generator)
                    let diameter = CGFloat.random(in: 0.6...1.8, using: &generator)
                    let isHighlight = Bool.random(using: &generator)
                    let dot = Path(ellipseIn: CGRect(x: x, y: y, width: diameter, height: diameter))
                    context.fill(dot, with: .color(isHighlight ? .white.opacity(0.045) : .black.opacity(0.35)))
                }
            }

            LinearGradient(
                colors: [.clear, .black.opacity(0.35)],
                startPoint: .center,
                endPoint: .bottom
            )
        }
    }
}

/// SplitMix64, enough for a repeatable texture.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}

#Preview {
    ScrollView(.horizontal) {
        HStack(spacing: 12) {
            PropertyTitleCard(property: PlaceholderProperties.all[13], number: 14)
            PropertyTitleCard(property: PlaceholderProperties.all[15], number: 16)
            PropertyTitleCard(property: PlaceholderProperties.all[18], number: 19)
            PropertyTitleCard(property: PlaceholderProperties.all[21], number: 22)
        }
        .padding()
    }
    .background(Lux.background)
}
