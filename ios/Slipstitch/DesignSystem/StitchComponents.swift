import SwiftUI

/// Reusable pastel building blocks. Feature worktrees compose these.

struct StitchCard<Content: View>: View {
    var padding: CGFloat = StitchTheme.Spacing.md
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(StitchTheme.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: StitchTheme.Radius.md, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}

struct StitchPrimaryButton: View {
    let title: String
    var icon: String? = nil
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: StitchTheme.Spacing.sm) {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    if let icon { Image(systemName: icon) }
                    Text(title)
                }
            }
            .font(StitchTheme.Font.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(StitchTheme.Color.brandGradient)
            .clipShape(RoundedRectangle(cornerRadius: StitchTheme.Radius.md, style: .continuous))
            .shadow(color: StitchTheme.Color.brand.opacity(0.32), radius: 12, y: 6)
        }
        .disabled(isLoading)
    }
}

struct StitchTag: View {
    let text: String
    var color: Color = StitchTheme.Color.lavender

    var body: some View {
        Text(text)
            .font(StitchTheme.Font.caption)
            .foregroundStyle(StitchTheme.Color.inkOnPastel)
            .padding(.horizontal, StitchTheme.Spacing.sm)
            .padding(.vertical, StitchTheme.Spacing.xs)
            .background(color)
            .clipShape(Capsule())
    }
}

/// Soft pastel placeholder shown while a remote image loads or is missing.
struct StitchImagePlaceholder: View {
    let seed: String
    var body: some View {
        StitchTheme.Color.pastel(for: seed).opacity(0.6)
            .overlay(Text("🧶").font(.title))
    }
}
