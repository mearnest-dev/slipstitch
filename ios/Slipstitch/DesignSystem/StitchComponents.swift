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

    @Environment(\.colorScheme) private var colorScheme

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
            // Tone the gradient down a touch on dark backgrounds (behind the
            // label, so the white text stays crisp).
            .background(
                ZStack {
                    StitchTheme.Color.brandGradient
                    SwiftUI.Color.black.opacity(colorScheme == .dark ? 0.12 : 0)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: StitchTheme.Radius.md, style: .continuous))
            // The purple glow reads as a halo on dark backgrounds — soften it.
            .shadow(color: StitchTheme.Color.brand.opacity(colorScheme == .dark ? 0.10 : 0.32),
                    radius: colorScheme == .dark ? 6 : 12, y: colorScheme == .dark ? 3 : 6)
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

/// Collapsible "Materials & details" section for project pages — replaces the
/// old chip rows. Collapsed by default; expands to labeled rows.
struct MaterialsDisclosure: View {
    struct Item: Identifiable {
        let label: String
        let value: String
        var id: String { label }
    }

    let items: [Item]
    @State private var expanded = false

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation(.snappy(duration: 0.2)) { expanded.toggle() }
                } label: {
                    HStack(spacing: StitchTheme.Spacing.sm) {
                        Image(systemName: "archivebox")
                            .font(.subheadline)
                            .foregroundStyle(StitchTheme.Color.accent)
                        Text("Materials & details")
                            .font(StitchTheme.Font.headline)
                            .foregroundStyle(StitchTheme.Color.textPrimary)
                        Text("\(items.count)")
                            .font(StitchTheme.Font.caption)
                            .foregroundStyle(StitchTheme.Color.textSecondary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(StitchTheme.Color.textSecondary)
                            .rotationEffect(.degrees(expanded ? 180 : 0))
                    }
                    .padding(StitchTheme.Spacing.md)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if expanded {
                    VStack(alignment: .leading, spacing: StitchTheme.Spacing.sm) {
                        ForEach(items) { item in
                            HStack(alignment: .firstTextBaseline) {
                                Text(item.label)
                                    .font(StitchTheme.Font.caption)
                                    .foregroundStyle(StitchTheme.Color.textSecondary)
                                    .frame(width: 80, alignment: .leading)
                                Text(item.value)
                                    .font(StitchTheme.Font.body)
                                    .foregroundStyle(StitchTheme.Color.textPrimary)
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .padding(.horizontal, StitchTheme.Spacing.md)
                    .padding(.bottom, StitchTheme.Spacing.md)
                    .transition(.opacity)
                }
            }
            .background(StitchTheme.Color.surfaceAlt)
            .clipShape(RoundedRectangle(cornerRadius: StitchTheme.Radius.md, style: .continuous))
        }
    }
}

extension MaterialsDisclosure {
    /// Standard item list for a project; skips empty fields.
    static func items(for project: Project) -> [Item] {
        var result: [Item] = []
        if let craft = project.craftType, !craft.isEmpty { result.append(Item(label: "Craft", value: craft)) }
        if let yarn = project.yarn, !yarn.isEmpty { result.append(Item(label: "Yarn", value: yarn)) }
        if let weight = project.yarnWeight, !weight.isEmpty { result.append(Item(label: "Weight", value: weight)) }
        if let hook = project.hookSize, !hook.isEmpty { result.append(Item(label: "Hook", value: hook)) }
        return result
    }
}

/// Horizontal row of tappable social-link chips (Instagram, Ravelry, …).
struct SocialLinksRow: View {
    let links: [String]

    var body: some View {
        if !links.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: StitchTheme.Spacing.sm) {
                    ForEach(links, id: \.self) { link in
                        if let url = URL(string: link) {
                            Link(destination: url) {
                                HStack(spacing: StitchTheme.Spacing.xs) {
                                    Image(systemName: Self.icon(for: link))
                                        .font(.caption)
                                    Text(Self.label(for: link))
                                        .font(StitchTheme.Font.caption)
                                }
                                .foregroundStyle(StitchTheme.Color.accent)
                                .padding(.horizontal, StitchTheme.Spacing.sm)
                                .padding(.vertical, StitchTheme.Spacing.xs)
                                .background(StitchTheme.Color.surfaceAlt)
                                .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
        }
    }

    static func icon(for link: String) -> String {
        let host = URL(string: link)?.host()?.lowercased() ?? link.lowercased()
        if host.contains("instagram") { return "camera" }
        if host.contains("tiktok") { return "music.note" }
        if host.contains("youtube") { return "play.rectangle" }
        if host.contains("pinterest") { return "pin" }
        if host.contains("ravelry") { return "circle.hexagongrid" }
        if host.contains("etsy") { return "bag" }
        return "link"
    }

    static func label(for link: String) -> String {
        guard let url = URL(string: link), let host = url.host() else { return link }
        let cleanHost = host.replacingOccurrences(of: "www.", with: "")
        // For profile-style URLs, the path is more informative than the host.
        let path = url.path(percentEncoded: false)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if !path.isEmpty && path.count <= 24 {
            return "\(cleanHost.components(separatedBy: ".").first ?? cleanHost)/\(path)"
        }
        return cleanHost
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
