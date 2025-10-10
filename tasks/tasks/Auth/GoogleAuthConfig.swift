import Foundation

enum GoogleAuthConfig {
    // Replace these with your OAuth 2.0 Client ID
    static var clientID: String {
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
