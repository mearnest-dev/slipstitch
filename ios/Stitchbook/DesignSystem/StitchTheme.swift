import SwiftUI

/// Stitchbook's pastel design system. Soft, cozy, craft-forward.
/// All feature worktrees pull colors / fonts / spacing from here so the app
/// stays visually consistent.
enum StitchTheme {

    enum Color {
        // Brand (Stitchbook purple) — the functional accent. Reserved for CTAs,
        // active states, and brand moments; soft pastels carry the rest.
        static let brand      = SwiftUI.Color(hex: 0x8A43FE) // primary
        static let brandDeep  = SwiftUI.Color(hex: 0x5701E4) // color-500, pressed / gradient base
        static let brand700   = SwiftUI.Color(hex: 0x31017F)
        static let brand100   = SwiftUI.Color(hex: 0xD0B3FF) // lightest tint
        static let brandTint   = SwiftUI.Color(hex: 0xEDE3FF) // very soft brand wash for surfaces

        // Pastel supporting palette (placeholders, status chips, cozy accents)
        static let blush      = SwiftUI.Color(hex: 0xF7C8D8)
        static let mint       = SwiftUI.Color(hex: 0xC8E6D4)
        static let lavender   = SwiftUI.Color(hex: 0xD8CCF0)
        static let butter     = SwiftUI.Color(hex: 0xF7E6B0)
        static let sky        = SwiftUI.Color(hex: 0xBFE0F0)
        static let peach      = SwiftUI.Color(hex: 0xF7D6BF)

        static let accent     = brand     // tint / icons / links / CTA
        static let accentSoft  = brand100

        static let background  = SwiftUI.Color(hex: 0xFBFAFF) // soft lavender-white
        static let surface     = SwiftUI.Color.white
        static let surfaceAlt   = SwiftUI.Color(hex: 0xF4F0FB)

        static let textPrimary   = SwiftUI.Color(hex: 0x241B33) // near-brand ink
        static let textSecondary = SwiftUI.Color(hex: 0x8B82A0)
        static let divider       = SwiftUI.Color(hex: 0xECE7F4)

        /// Deterministic pastel for an id (e.g. project cover placeholder).
        static func pastel(for seed: String) -> SwiftUI.Color {
            let palette = [lavender, blush, mint, butter, sky, peach, brand100]
            let idx = abs(seed.hashValue) % palette.count
            return palette[idx]
        }

        /// Premium brand gradient for primary CTAs / hero moments.
        static var brandGradient: LinearGradient {
            LinearGradient(colors: [brand, brandDeep],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
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
