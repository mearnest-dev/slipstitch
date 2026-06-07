import SwiftUI

/// Sheet to log a new progress entry on a project.
/// Note + optional row count + optional hours.
///
/// TODO(photo): photo attachment is intentionally not implemented here. Once the
/// shared media uploader lands, capture/pick an image, upload it to R2 to obtain
/// a `photoId`, and pass it through `JournalService.addLog(photoId:)`.
struct AddProgressView: View {
    let projectId: String
    var onAdded: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var note = ""
    @State private var includeRows = false
    @State private var rowCount = 1
    @State private var includeHours = false
    @State private var hoursText = ""

    @State private var isSaving = false
    @State private var errorMessage: String?

    private let service = JournalService()

    private var canSave: Bool {
        let hasNote = !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasRows = includeRows
        let hasHours = includeHours && (Double(hoursText) ?? 0) > 0
        return (hasNote || hasRows || hasHours) && !isSaving
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("What happened") {
                    TextEditor(text: $note)
                        .frame(minHeight: 120)
                        .overlay(alignment: .topLeading) {
                            if note.isEmpty {
                                Text("Today I worked on…")
                                    .font(StitchTheme.Font.body)
                                    .foregroundStyle(StitchTheme.Color.textSecondary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                                    .allowsHitTesting(false)
                            }
                        }
                }

                Section("Rows") {
                    Toggle("Log rows", isOn: $includeRows)
                    if includeRows {
                        Stepper("+\(rowCount) rows", value: $rowCount, in: 1...10000)
                    }
                }

                Section("Time") {
                    Toggle("Log hours", isOn: $includeHours)
                    if includeHours {
                        TextField("Hours (e.g. 1.5)", text: $hoursText)
                            .keyboardType(.decimalPad)
                    }
                }

                // TODO(photo): add a photo picker row here once the shared media
                // uploader is available (upload -> photoId -> addLog(photoId:)).

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(StitchTheme.Font.caption)
                            .foregroundStyle(StitchTheme.Color.accent)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(StitchTheme.Color.background)
            .navigationTitle("Add progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") { save() }
                            .disabled(!canSave)
                    }
                }
            }
        }
    }

    private func save() {
        errorMessage = nil
        isSaving = true
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let rows: Int? = includeRows ? rowCount : nil
        let hours: Double? = includeHours ? Double(hoursText) : nil
        Task {
            do {
                _ = try await service.addLog(
                    projectId: projectId,
                    note: trimmedNote.isEmpty ? nil : trimmedNote,
                    rowCount: rows,
                    hoursSpent: hours
                )
                onAdded()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }
}
