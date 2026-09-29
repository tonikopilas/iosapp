import SwiftUI

extension Font {
    /// Onest, the display/UI face.
    static func onest(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        let name = switch weight {
        case .black: "Onest-Black"
        case .heavy: "Onest-ExtraBold"
        case .bold: "Onest-Bold"
        case .semibold: "Onest-SemiBold"
        case .medium: "Onest-Medium"
        default: "Onest-Regular"
        }
        return .custom(name, fixedSize: size)
    }

    /// JetBrains Mono, used for numerals, eyebrows and meta labels.
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        let name = switch weight {
        case .bold, .heavy, .black: "JetBrainsMono-Bold"
        case .medium, .regular: "JetBrainsMono-Medium"
        default: "JetBrainsMono-SemiBold"
        }
        return .custom(name, fixedSize: size)
    }
}

extension View {
    /// CSS-style letter-spacing in em.
    func em(_ value: CGFloat, _ size: CGFloat) -> some View { tracking(value * size) }

    /// Frosted translucent fill used for pills and buttons on the dark stage.
    func glass<S: Shape>(_ shape: S, tint: Color = .white.opacity(0.14)) -> some View {
        background {
            ZStack {
                shape.fill(.ultraThinMaterial)
                shape.fill(tint)
            }
            .environment(\.colorScheme, .dark)
        }
    }

    /// A focus ring like CSS `0 0 0 gap paper, 0 0 0 (gap+width) color`.
    func ring<S: InsettableShape>(_ shape: S, gap: CGFloat, width: CGFloat, color: Color, gapColor: Color = .paper, visible: Bool = true) -> some View {
        background {
            ZStack {
                shape.fill(color).padding(-(gap + width))
                shape.fill(gapColor).padding(-gap)
            }
            .opacity(visible ? 1 : 0)
        }
    }

    /// Scale animation for press states on custom buttons.
    func pressable(_ scale: CGFloat = 0.96) -> some View { buttonStyle(PressStyle(scale: scale)) }
}

struct PressStyle: ButtonStyle {
    var scale: CGFloat
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Bouncy spring approximating the design's cubic-bezier(.3,1.6,.5,1).
extension Animation {
    static let bounce = Animation.spring(response: 0.35, dampingFraction: 0.55)
    static let settle = Animation.spring(response: 0.4, dampingFraction: 0.82)
}

struct PlusIcon: View {
    var size: CGFloat
    var weight: CGFloat
    var body: some View {
        Path { p in
            p.move(to: CGPoint(x: 12, y: 5)); p.addLine(to: CGPoint(x: 12, y: 19))
            p.move(to: CGPoint(x: 5, y: 12)); p.addLine(to: CGPoint(x: 19, y: 12))
        }
        .stroke(style: StrokeStyle(lineWidth: weight, lineCap: .round))
        .frame(width: 24, height: 24)
        .scaleEffect(size / 24)
        .frame(width: size, height: size)
    }
}

struct PlayIcon: View {
    var size: CGFloat
    var body: some View {
        Path { p in
            p.move(to: CGPoint(x: 6, y: 3)); p.addLine(to: CGPoint(x: 20, y: 12))
            p.addLine(to: CGPoint(x: 6, y: 21)); p.closeSubpath()
        }
        .frame(width: 24, height: 24)
        .scaleEffect(size / 24)
        .frame(width: size, height: size)
    }
}

/// Light "card" used for sections and panels.
struct PaperCard<Content: View>: View {
    var radius: CGFloat = 26
    var padding: EdgeInsets = EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14)
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(Color.ink)
            .background(Color.paper, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 15, y: 10)
    }
}

struct Eyebrow: View {
    var text: String
    var size: CGFloat = 10.5
    var tracking: CGFloat = 0.08
    var color: Color = .muted
    var body: some View {
        Text(text).font(.mono(size)).em(tracking, size).foregroundStyle(color)
    }
}
