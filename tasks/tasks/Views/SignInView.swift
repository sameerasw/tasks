import SwiftUI

struct SignInView: View {
    @EnvironmentObject var auth: AuthenticationManager
    @Environment(\.dismiss) private var dismiss

    @State private var customClientId: String = ""
    @State private var hideClientId: Bool = true
    @State private var showSaved: Bool = false

    private let keychainService = "com.sameerasandakelum.tasks.google"
    private let clientIDAccount = "google_client_id"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sign in with Google")
                .font(.title2)

            Text("Optionally provide your own Google OAuth Client ID. If provided, it will be stored securely in the Keychain and used for authentication instead of the embedded GOOGLE_CLIENT_ID.")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                if hideClientId {
                    SecureField("Custom Client ID (optional)", text: $customClientId)
                } else {
                    TextField("Custom Client ID (optional)", text: $customClientId)
                }
                Button(action: { hideClientId.toggle() }) {
                    Image(systemName: hideClientId ? "eye.slash" : "eye")
                }
                .help(hideClientId ? "Show" : "Hide")
            }

            HStack(spacing: 12) {
                Button("Save and Sign In") {
                    saveClientIdIfNeeded()
                    Task { do { try await auth.signIn(); dismiss() } catch { dismiss() } }
                }
                .keyboardShortcut(.defaultAction)

                Button("Just Sign In") {
                    Task { do { try await auth.signIn(); dismiss() } catch { dismiss() } }
                }

                Button("Cancel", role: .cancel) { dismiss() }
            }

            if showSaved {
                Text("Client ID saved securely.")
                    .font(.caption)
                    .foregroundColor(.green)
            }

            Spacer()
        }
        .padding()
        .frame(minWidth: 420, minHeight: 160)
    }

    private func saveClientIdIfNeeded() {
        let trimmed = customClientId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let _ = KeychainHelper.shared.save(Data(trimmed.utf8), service: keychainService, account: clientIDAccount)
        showSaved = true
    }
}

#Preview {
    SignInView()
        .environmentObject(AuthenticationManager())
}
