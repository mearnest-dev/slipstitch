import SwiftUI

/// Stitchbook's pastel design system. Soft, cozy, craft-forward.
/// All feature worktrees pull colors / fonts / spacing from here so the app
/// stays visually consistent.
enum StitchTheme {

    enum Color {
        // Pastel palette
        static let blush      = SwiftUI.Color(hex: 0xF7C8D8) // primary pink
        static let mint       = SwiftUI.Color(hex: 0xC8E6D4)
        static let lavender   = SwiftUI.Color(hex: 0xD8CCF0)
        static let butter     = SwiftUI.Color(hex: 0xF7E6B0)
        static let sky        = SwiftUI.Color(hex: 0xBFE0F0)
        static let peach      = SwiftUI.Color(hex: 0xF7D6BF)

        static let accent     = SwiftUI.Color(hex: 0xE89BB4) // slightly deeper blush for tint/CTA
        static let accentSoft  = blush

        static let background  = SwiftUI.Color(hex: 0xFFFBF7) // warm off-white
        static let surface     = SwiftUI.Color.white
        static let surfaceAlt   = SwiftUI.Color(hex: 0xFBF3EE)

        static let textPrimary   = SwiftUI.Color(hex: 0x4A3F44)
        static let textSecondary = SwiftUI.Color(hex: 0x9A8E92)
        static let divider       = SwiftUI.Color(hex: 0xEFE6E0)

        /// Deterministic pastel for an id (e.g. project cover placeholder).
        static func pastel(for seed: String) -> SwiftUI.Color {
            let palette = [blush, mint, lavender, butter, sky, peach]
            let idx = abs(seed.hashValue) % palette.count
            return palette[idx]
        }
    }

    enum Font {
        static let largeTitle = SwiftUI.Font.system(.largeTitle, design: .rounded).weight(.bold)
        static let title      = SwiftUI.Font.system(.title2, design: .rounded).weight(.semibold)
        static let headline   = SwiftUI.Font.system(.headline, design: .rounded)
        static let body       = SwiftUI.Font.system(.body, design: .rounded)
        static let caption    = SwiftUI.Font.system(.caption, design: .rounded)
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let pill: CGFloat = 999
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
