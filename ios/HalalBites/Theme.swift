import SwiftUI

enum Theme {
    // MARK: - Surfaces
    static let mapPaper   = Color(hex: 0xF4F1EC)
    static let mapPaper2  = Color(hex: 0xEAE6DF)
    static let mapWater   = Color(hex: 0xD8E3E8)
    static let mapPark    = Color(hex: 0xDCE4D6)
    static let mapStroke  = Color(hex: 0xC9C2B6)

    static let bg         = Color.white
    static let bgTint     = Color(hex: 0xF7F5F1)
    static let bgOverlay  = Color.white.opacity(0.78)

    // MARK: - Foreground
    static let fg1        = Color(hex: 0x14161A)
    static let fg2        = Color(hex: 0x4A4F57)
    static let fg3        = Color(hex: 0x8A8F97)
    static let fg4        = Color(hex: 0xB6BAC0)

    // MARK: - Strokes
    static let stroke1    = Color(hex: 0x14161A).opacity(0.08)
    static let stroke2    = Color(hex: 0x14161A).opacity(0.14)

    // MARK: - Pin Colors
    static let pinCertified = Color(hex: 0x1FB46B)
    static let pinFriendly  = Color(hex: 0x2D7DF6)
    static let pinPhoto     = Color(hex: 0xE66A2C)
    static let pinCultural  = Color(hex: 0x8E5BD9)
    static let pinSaved     = Color(hex: 0xE0356A)
    static let pinWarning   = Color(hex: 0xE5A828)

    static let brand      = Color(hex: 0x14161A)
    static let accent     = Color(hex: 0x1FB46B)

    // MARK: - Semantic
    static let success    = Color(hex: 0x1FB46B)
    static let info       = Color(hex: 0x2D7DF6)
    static let warning    = Color(hex: 0xE5A828)
    static let danger     = Color(hex: 0xE0356A)

    // MARK: - Radii
    static let rPill: CGFloat   = 999
    static let rCard: CGFloat   = 20
    static let rSheet: CGFloat  = 24
    static let rMd: CGFloat     = 14
    static let rSm: CGFloat     = 10

    // MARK: - Spacing (4-pt grid)
    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s5: CGFloat = 20
    static let s6: CGFloat = 24
    static let s7: CGFloat = 32
    static let s8: CGFloat = 48

    // MARK: - Type Sizes
    static let tDisplay: CGFloat = 34
    static let tH1: CGFloat      = 28
    static let tH2: CGFloat      = 22
    static let tH3: CGFloat      = 17
    static let tBody: CGFloat    = 15
    static let tSm: CGFloat      = 13
    static let tXs: CGFloat      = 11

    // MARK: - Pin Color Helper
    static func pinColor(for status: ZabihahHalalStatus) -> Color {
        switch status {
        case .zabiha, .fullyHalal: return pinCertified
        case .partiallyHalal: return pinFriendly
        }
    }

    static func pinColor(for level: HalalLevel) -> Color {
        switch level {
        case .halal: return pinCertified
        case .partiallyHalal: return pinFriendly
        case .vegetarian: return pinPhoto
        case .vegan: return pinCultural
        }
    }
}

// MARK: - Color Hex Init

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

// MARK: - Mono Font Helper

extension Font {
    static func mono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - Eyebrow Style

extension View {
    func eyebrowStyle() -> some View {
        self
            .font(.system(size: Theme.tXs, weight: .semibold))
            .foregroundStyle(Theme.fg3)
            .textCase(.uppercase)
            .tracking(0.8)
    }
}
