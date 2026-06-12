import SwiftUI

/// Post-signup survey: what the user loves to see, and what they're planning
/// to make. Interests personalize the Discover feed; planned makes become
/// `planning` projects in their Journal so the app starts feeling lived-in.
struct OnboardingSurveyView: View {
    @EnvironmentObject private var session: SessionStore

    @State private var step = 0
    @State private var selectedInterests: Set<String> = []
    @State private var selectedMakes: Set<String> = []
    @State private var customMake = ""
    @State private var customMakes: [String] = []

    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private let service = ProfileService()

    private static let interestOptions = [
        "Amigurumi", "Granny squares", "Blankets & throws", "Wearables",
        "Hats & beanies", "Shawls & wraps", "Bags & purses", "Home decor",
        "Baby items", "Toys", "Kitchen & coasters", "Holiday makes",
    ]

    private static let makeOptions = [
        "A cozy blanket", "An amigurumi friend", "A beanie",
        "A granny square cardigan", "A market bag", "A baby gift",
        "A shawl", "Holiday ornaments",
    ]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: StitchTheme.Spacing.lg) {
                header

                ScrollView {
                    VStack(alignment: .leading, spacing: StitchTheme.Spacing.lg) {
                        if step == 0 {
                            interestsStep
                        } else {
                            makesStep
                        }
                    }
                    .padding(.horizontal, StitchTheme.Spacing.md)
                }

                footer
            }
            .padding(.top, StitchTheme.Spacing.lg)
            .background(StitchTheme.Color.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Skip") { submit(skip: true) }
                        .font(StitchTheme.Font.body)
                        .foregroundStyle(StitchTheme.Color.textSecondary)
                        .disabled(isSubmitting)
                }
            }
        }
    }

    // MARK: Header / footer

    private var header: some View {
        VStack(alignment: .leading, spacing: StitchTheme.Spacing.xs) {
            Text(step == 0 ? "What do you love to see?" : "What are you planning to make?")
                .font(StitchTheme.Font.largeTitle)
                .foregroundStyle(StitchTheme.Color.textPrimary)
            Text(step == 0
                 ? "Pick a few — your Discover feed will lean into them."
                 : "We'll tuck these into your Journal as planned makes.")
                .font(StitchTheme.Font.body)
                .foregroundStyle(StitchTheme.Color.textSecondary)
        }
        .padding(.horizontal, StitchTheme.Spacing.md)
    }

    private var footer: some View {
        VStack(spacing: StitchTheme.Spacing.sm) {
            if let errorMessage {
                Text(errorMessage)
                    .font(StitchTheme.Font.caption)
                    .foregroundStyle(.red)
            }
            StitchPrimaryButton(
                title: step == 0 ? "Next" : "Start making",
                icon: step == 0 ? nil : "sparkles",
                isLoading: isSubmitting
            ) {
                if step == 0 {
                    withAnimation { step = 1 }
                } else {
                    submit(skip: false)
                }
            }
            if step == 1 {
                Button("Back") { withAnimation { step = 0 } }
                    .font(StitchTheme.Font.body)
                    .foregroundStyle(StitchTheme.Color.textSecondary)
                    .disabled(isSubmitting)
            }
        }
        .padding(.horizontal, StitchTheme.Spacing.md)
        .padding(.bottom, StitchTheme.Spacing.md)
    }

    // MARK: Steps

    private var interestsStep: some View {
        SurveyChipGrid(
            options: Self.interestOptions,
            selected: $selectedInterests
        )
    }

    private var makesStep: some View {
        VStack(alignment: .leading, spacing: StitchTheme.Spacing.lg) {
            SurveyChipGrid(
                options: Self.makeOptions + customMakes,
                selected: $selectedMakes
            )

            HStack(spacing: StitchTheme.Spacing.sm) {
                TextField("Something else…", text: $customMake)
                    .font(StitchTheme.Font.body)
                    .foregroundStyle(StitchTheme.Color.textPrimary)
                    .padding(.horizontal, StitchTheme.Spacing.md)
                    .padding(.vertical, StitchTheme.Spacing.sm)
                    .background(StitchTheme.Color.surface)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(StitchTheme.Color.divider, lineWidth: 1))
                    .onSubmit(addCustomMake)
                Button(action: addCustomMake) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(StitchTheme.Color.accent)
                }
                .disabled(customMake.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func addCustomMake() {
        let make = customMake.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !make.isEmpty else { return }
        if !customMakes.contains(make) && !Self.makeOptions.contains(make) {
            customMakes.append(make)
        }
        selectedMakes.insert(make)
        customMake = ""
    }

    // MARK: Submit

    private func submit(skip: Bool) {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil
        let interests = skip ? [] : selectedInterests.sorted()
        let makes = skip ? [] : selectedMakes.sorted()
        Task {
            do {
                let updated = try await service.completeOnboarding(
                    interests: interests.map { $0.lowercased() },
                    planningToMake: makes
                )
                // RootView watches onboardingCompleted; this flips to the tabs.
                session.updateUser(updated)
            } catch {
                errorMessage = error.localizedDescription
                isSubmitting = false
            }
        }
    }
}

// MARK: - Chip grid

/// Wrapping multi-select capsule chips.
private struct SurveyChipGrid: View {
    let options: [String]
    @Binding var selected: Set<String>

    var body: some View {
        SurveyWrapLayout(spacing: StitchTheme.Spacing.sm) {
            ForEach(options, id: \.self) { option in
                chip(option)
            }
        }
    }

    private func chip(_ option: String) -> some View {
        let isOn = selected.contains(option)
        return Button {
            if isOn { selected.remove(option) } else { selected.insert(option) }
        } label: {
            Text(option)
                .font(StitchTheme.Font.body)
                .foregroundStyle(isOn ? .white : StitchTheme.Color.textPrimary)
                .padding(.horizontal, StitchTheme.Spacing.md)
                .padding(.vertical, StitchTheme.Spacing.sm)
                .background(
                    isOn
                        ? AnyShapeStyle(StitchTheme.Color.brandGradient)
                        : AnyShapeStyle(StitchTheme.Color.surface)
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(
                        isOn ? SwiftUI.Color.clear : StitchTheme.Color.divider,
                        lineWidth: 1
                    )
                )
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.15), value: isOn)
    }
}

/// Minimal wrapping layout (same approach as the chips wrap on the project
/// detail screen, kept private to this file).
private struct SurveyWrapLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                totalWidth = max(totalWidth, rowWidth - spacing)
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        totalWidth = max(totalWidth, rowWidth - spacing)
        return CGSize(width: min(totalWidth, maxWidth), height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
