import SwiftUI
import UserNotifications

/// Account-level settings: default comments on/off for new projects,
/// notifications, sign out, and account deletion.
struct SettingsView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var defaultCommentsEnabled = true
    @State private var notificationsEnabled = false
    @State private var activityVisible = true
    @State private var didSeed = false

    @State private var isSaving = false
    @State private var errorMessage: String?

    @State private var showDeleteConfirm = false
    @State private var deleteConfirmText = ""
    @State private var isDeleting = false

    private let service = ProfileService()

    var body: some View {
        Form {
            Section {
                Toggle("Allow comments on new projects", isOn: $defaultCommentsEnabled)
                    .tint(StitchTheme.Color.accent)
                    .onChange(of: defaultCommentsEnabled) { _, newValue in
                        guard didSeed else { return }
                        save(defaultComments: newValue)
                    }
            } header: {
                Text("Comments")
            } footer: {
                Text("New projects start with comments on or off. You can still change it per project.")
            }

            Section {
                Toggle("Enable notifications", isOn: $notificationsEnabled)
                    .tint(StitchTheme.Color.accent)
                    .onChange(of: notificationsEnabled) { _, newValue in
                        guard didSeed else { return }
                        if newValue {
                            requestNotificationPermission()
                        }
                        save(notifications: newValue)
                    }
            } header: {
                Text("Notifications")
            }

            Section {
                Toggle("Show activity on my profile", isOn: $activityVisible)
                    .tint(StitchTheme.Color.accent)
                    .onChange(of: activityVisible) { _, newValue in
                        guard didSeed else { return }
                        save(activity: newValue)
                    }
            } header: {
                Text("Privacy")
            } footer: {
                Text("When off, other people won't see the Activity tab on your profile (your recent comments, likes, and follows).")
            }

            Section {
                Button(role: .destructive) {
                    session.signOut()
                } label: {
                    Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                }

                Button(role: .destructive) {
                    deleteConfirmText = ""
                    showDeleteConfirm = true
                } label: {
                    if isDeleting {
                        HStack {
                            ProgressView()
                            Text("Deleting…")
                        }
                    } else {
                        Label("Delete account", systemImage: "trash")
                    }
                }
                .disabled(isDeleting)
            } header: {
                Text("Account")
            } footer: {
                Text("Deleting your account permanently removes your projects, photos, comments, collections, and followers. This can't be undone.")
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(StitchTheme.Font.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(StitchTheme.Color.background)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete your account?", isPresented: $showDeleteConfirm) {
            TextField("Type DELETE to confirm", text: $deleteConfirmText)
                .autocorrectionDisabled()
            Button("Cancel", role: .cancel) {}
            Button("Delete forever", role: .destructive) { deleteAccount() }
        } message: {
            Text("This permanently erases everything. Type DELETE to confirm.")
        }
        .onAppear {
            if !didSeed {
                defaultCommentsEnabled = session.currentUser?.defaultCommentsEnabled ?? true
                notificationsEnabled = session.currentUser?.notificationsEnabled ?? false
                activityVisible = session.currentUser?.activityVisible ?? true
                // Seed once, on the next runloop, so the initial assignments
                // above don't fire the onChange save handlers.
                DispatchQueue.main.async { didSeed = true }
            }
        }
    }

    // MARK: Actions

    private func save(defaultComments: Bool? = nil, notifications: Bool? = nil, activity: Bool? = nil) {
        errorMessage = nil
        Task {
            do {
                let updated = try await service.updateSettings(
                    defaultCommentsEnabled: defaultComments,
                    notificationsEnabled: notifications,
                    activityVisible: activity
                )
                session.updateUser(updated)
            } catch {
                errorMessage = error.localizedDescription
                // Revert the visible toggle to what the server still has.
                if defaultComments != nil {
                    defaultCommentsEnabled = session.currentUser?.defaultCommentsEnabled ?? true
                }
                if notifications != nil {
                    notificationsEnabled = session.currentUser?.notificationsEnabled ?? false
                }
                if activity != nil {
                    activityVisible = session.currentUser?.activityVisible ?? true
                }
            }
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            if !granted {
                DispatchQueue.main.async {
                    notificationsEnabled = false
                    errorMessage = "Notifications are blocked for Slipstitch in iOS Settings."
                }
            }
        }
    }

    private func deleteAccount() {
        guard deleteConfirmText.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == "DELETE" else {
            errorMessage = "Account not deleted — confirmation text didn't match."
            return
        }
        isDeleting = true
        errorMessage = nil
        Task {
            do {
                try await service.deleteAccount()
                session.signOut()
            } catch {
                errorMessage = error.localizedDescription
                isDeleting = false
            }
        }
    }
}
