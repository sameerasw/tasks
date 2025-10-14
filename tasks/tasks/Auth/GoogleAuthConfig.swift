import Foundation

enum GoogleAuthConfig {
    // Keychain storage details for an optional user-provided client ID
    private static var keychainService: String { "com.sameerasandakelum.tasks.google" }
    private static var clientIDAccount: String { "google_client_id" }

    // The OAuth 2.0 Client ID. If the user has supplied a custom client ID and
    // stored it in the keychain, prefer that. Otherwise fall back to the
    // GOOGLE_CLIENT_ID value from Info.plist (Secrets.xcconfig).
    static var clientID: String {
        // Try keychain first
        if let data = KeychainHelper.shared.read(service: keychainService, account: clientIDAccount),
           let kc = String(data: data, encoding: .utf8) {
            let trimmed = kc.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }

        // Fallback to Info.plist value
        let value = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CLIENT_ID") as? String
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        assert(!trimmed.isEmpty, "GOOGLE_CLIENT_ID is missing. Ensure Secrets.xcconfig is added to the build configuration and Info.plist contains $(GOOGLE_CLIENT_ID).")

        return trimmed
    }

    // The redirect URI you register in Google Cloud Console. For macOS apps you can use
    // a custom URL scheme such as com.example.tasks:/oauthredirect
    static var redirectURI: String { "sameerasw.tasks:/oauthredirect" }

    // tasks api
    static var scopes: [String] { ["https://www.googleapis.com/auth/tasks"] }

    static var authEndpoint: String { "https://accounts.google.com/o/oauth2/v2/auth" }
    static var tokenEndpoint: String { "https://oauth2.googleapis.com/token" }
}
