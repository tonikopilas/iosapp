import SwiftUI

/// Every pitch class gets a hue by its position on the circle of fifths, so related chords look related.
/// Colors are specified in OKLCH (as in the design) and rendered in Display P3.
struct Palette {
    var mono = false

    func hue(_ pc: Int) -> Double {
        mono ? 12 : Double(((Theory.fifths.firstIndex(of: m12(pc)) ?? 0) * 30 + 10) % 360)
    }

    /// Vivid note color.
    func col(_ pc: Int, _ l: Double = 0.64, _ c: Double = 0.19, _ a: Double = 1) -> Color {
        .oklch(l, c, hue(pc), a)
    }

    /// Pale card tint.
    func tint(_ pc: Int) -> Color { .oklch(0.925, 0.05, hue(pc)) }

    /// Readable ink on a tint.
    func tintFg(_ pc: Int) -> Color { .oklch(0.42, 0.13, hue(pc)) }
}

extension Color {
    static let ink = Color(hex: 0x16151A)
    static let paper = Color(hex: 0xF4F1EE)
    static let paperDeep = Color(hex: 0xE6E1DC)
    static let paperPress = Color(hex: 0xDAD3CD)
    static let paperLine = Color(hex: 0xD6CFC8)
    static let paperDash = Color(hex: 0xD3CCC6)
    static let inlay = Color(hex: 0xE3DDD7)
    static let muted = Color(hex: 0x8A8590)
    static let mutedDeep = Color(hex: 0x57525C)
    static let mutedLight = Color(hex: 0xA8A2AE)
    static let outline = Color(hex: 0xC9C1BA)
    static let accent = Color(hex: 0xFF3B5C)
    static let accentHover = Color(hex: 0xFF5270)
    static let stage = Color(hex: 0x08080B)

    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }

    /// OKLCH → Display P3 (clipped).
    static func oklch(_ l: Double, _ c: Double, _ h: Double, _ alpha: Double = 1) -> Color {
        let hr = h * .pi / 180
        let a = c * cos(hr), b = c * sin(hr)
        let l_ = l + 0.3963377774 * a + 0.2158037573 * b
        let m_ = l - 0.1055613458 * a - 0.0638541728 * b
        let s_ = l - 0.0894841775 * a - 1.2914855480 * b
        let L = l_ * l_ * l_, M = m_ * m_ * m_, S = s_ * s_ * s_
        // Linear sRGB
        let r = 4.0767416621 * L - 3.3077115913 * M + 0.2309699292 * S
        let g = -1.2684380046 * L + 2.6097574011 * M - 0.3413193965 * S
        let bl = -0.0041960863 * L - 0.7034186147 * M + 1.7076147010 * S
        // Linear sRGB → linear Display P3
        let pr = 0.8224621 * r + 0.1775380 * g
        let pg = 0.0331941 * r + 0.9668058 * g
        let pb = 0.0170827 * r + 0.0723974 * g + 0.9105199 * bl
        func encode(_ x: Double) -> Double {
            let v = min(1, max(0, x))
            return v <= 0.0031308 ? 12.92 * v : 1.055 * pow(v, 1 / 2.4) - 0.055
        }
        return Color(.displayP3, red: encode(pr), green: encode(pg), blue: encode(pb), opacity: alpha)
    }
}
