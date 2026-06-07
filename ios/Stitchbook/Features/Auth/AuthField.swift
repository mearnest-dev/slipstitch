import SwiftUI

/// Labeled text field styled for the pastel auth forms. Supports secure entry,
/// keyboard/content-type hints, and an optional footnote.
struct AuthField: View {
    let title: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboard: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    var autocapitalize: Bool = true
    var footnote: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: StitchTheme.Spacing.xs) {
            Text(title)
                .font(StitchTheme.Font.caption)
                .foregroundStyle(StitchTheme.Color.textSecondary)

            Group {
                if isSecure {
                    SecureField("", text: $text)
                } else {
                    TextField("", text: $text)
                }
            }
            .font(StitchTheme.Font.body)
            .foregroundStyle(StitchTheme.Color.textPrimary)
            .keyboardType(keyboard)
            .textContentType(textContentType)
            .textInputAutocapitalization(autocapitalize ? .sentences : .never)
            .autocorrectionDisabled(!autocapitalize)
            .padding(.vertical, 12)
            .padding(.horizontal, StitchTheme.Spacing.md)
            .background(StitchTheme.Color.surfaceAlt)
            .clipShape(RoundedRectangle(cornerRadius: StitchTheme.Radius.sm, style: .continuous))

            if let footnote {
                Text(footnote)
                    .font(StitchTheme.Font.caption)
                    .foregroundStyle(StitchTheme.Color.textSecondary)
            }
        }
    }
}
