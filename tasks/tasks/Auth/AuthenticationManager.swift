import Foundation
import AuthenticationServices
import SwiftUI
import Combine

@MainActor
final class AuthenticationManager: ObservableObject {
    enum AuthError: Error {
        case invalidAuthURL
        case missingCode
        case tokenRequestFailed(String)
    }

    @Published var isSignedIn: Bool = false
    @Published var email: String? = nil

    private var currentSession: ASWebAuthenticationSession?
    private let tokenExpiryKey = "google_oauth_token_expiry"
    private let keychainService = "com.sameerasandakelum.tasks.google"
    private let accessAccount = "google_access_token"
    private let refreshAccount = "google_refresh_token"

    init() {
        // consider signed in if an access token or refresh token exists
        let hasAccess = KeychainHelper.shared.read(service: keychainService, account: accessAccount) != nil
        let hasRefresh = KeychainHelper.shared.read(service: keychainService, account: refreshAccount) != nil
        self.isSignedIn = hasAccess || hasRefresh
    }

    func signIn() async throws {
        // Construct the authorization URL
        var components = URLComponents(string: GoogleAuthConfig.authEndpoint)
        let scope = GoogleAuthConfig.scopes.joined(separator: " ")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: GoogleAuthConfig.clientID),
            URLQueryItem(name: "redirect_uri", value: GoogleAuthConfig.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]

        guard let authURL = components?.url else { throw AuthError.invalidAuthURL }

        let callbackScheme = URL(string: GoogleAuthConfig.redirectURI)?.scheme
        guard let scheme = callbackScheme else { throw AuthError.invalidAuthURL }

        // ASWebAuthenticationSession must be started from main thread
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            // guard to ensure we resume the continuation exactly once
            var didComplete = false
            func resumeOnce(_ result: Result<Void, Error>) {
                // ensure resume happens on main to avoid races
                DispatchQueue.main.async {
                    guard !didComplete else { return }
                    didComplete = true
                    switch result {
                    case .success:
                        continuation.resume()
                    case .failure(let err):
                        continuation.resume(throwing: err)
                    }
                }
            }

            self.currentSession = ASWebAuthenticationSession(url: authURL, callbackURLScheme: scheme) { callbackURL, error in
                print("[Auth] ASWebAuthenticationSession callback invoked. callbackURL=\(String(describing: callbackURL)), error=\(String(describing: error))")
                if let error = error {
                    print("[Auth] session error: \(error)")
                    resumeOnce(.failure(error))
                    return
                }

                guard let callbackURL = callbackURL else {
                    print("[Auth] callbackURL was nil")
                    resumeOnce(.failure(AuthError.missingCode))
                    return
                }

                let urlComponents = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)
                let code = urlComponents?.queryItems?.first(where: { $0.name == "code" })?.value
                print("[Auth] parsed callback URL components: \(String(describing: urlComponents)), code=\(String(describing: code))")
                guard let codeUnwrapped = code else {
                    resumeOnce(.failure(AuthError.missingCode))
                    return
                }

                Task {
                    do {
                        try await self.exchangeCodeForToken(code: codeUnwrapped)
                        resumeOnce(.success(()))
                    } catch {
                        resumeOnce(.failure(error))
                    }
                }
            }

            // Prefer ephemeral web browser session when available
            if #available(macOS 12.0, *) {
                self.currentSession?.prefersEphemeralWebBrowserSession = true
            }

            // On macOS, ASWebAuthenticationSession requires a presentation context provider
            if #available(macOS 10.15, *) {
                self.currentSession?.presentationContextProvider = AuthenticationPresentationContextProvider.shared
            }

            // start() returns false if the session couldn't be started synchronously
            let started = self.currentSession?.start() ?? false
            if !started {
                print("[Auth] ASWebAuthenticationSession.start() returned false")
                resumeOnce(.failure(AuthError.invalidAuthURL))
            } else {
                print("[Auth] ASWebAuthenticationSession started successfully")
            }
        }
    }

    private func exchangeCodeForToken(code: String) async throws {
        guard let url = URL(string: GoogleAuthConfig.tokenEndpoint) else { throw AuthError.invalidAuthURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let bodyParams: [String: String] = [
            "code": code,
            "client_id": GoogleAuthConfig.clientID,
            "redirect_uri": GoogleAuthConfig.redirectURI,
            "grant_type": "authorization_code"
        ]

        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)

        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw AuthError.tokenRequestFailed(msg)
        }

        let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        guard let accessToken = json?["access_token"] as? String else {
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw AuthError.tokenRequestFailed(msg)
        }

        // Save access token, refresh token and expiry
        if let refreshToken = json?["refresh_token"] as? String {
            let ok = KeychainHelper.shared.save(Data(refreshToken.utf8), service: keychainService, account: refreshAccount)
            print("[Auth] saved refresh token: \(ok)")
        } else {
            print("[Auth] no refresh token in response")
        }

        let ok2 = KeychainHelper.shared.save(Data(accessToken.utf8), service: keychainService, account: accessAccount)
        print("[Auth] saved access token: \(ok2)")

        if let expires = json?["expires_in"] as? Double {
            let expiryDate = Date().addingTimeInterval(expires)
            UserDefaults.standard.set(expiryDate.timeIntervalSince1970, forKey: tokenExpiryKey)
            print("[Auth] token expiry set to \(expiryDate)")
        } else {
            print("[Auth] no expiry in token response")
        }

        // Consider signed in now that we have a token stored
        DispatchQueue.main.async {
            self.isSignedIn = true
        }

        await fetchUserInfo(accessToken: accessToken)
    }

    // Refresh access token using stored refresh token
    private func refreshAccessToken() async throws -> String {
        guard let refreshData = KeychainHelper.shared.read(service: keychainService, account: refreshAccount),
              let refreshToken = String(data: refreshData, encoding: .utf8) else {
            throw AuthError.tokenRequestFailed("missing refresh token")
        }

        guard let url = URL(string: GoogleAuthConfig.tokenEndpoint) else { throw AuthError.invalidAuthURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let bodyParams: [String: String] = [
            "refresh_token": refreshToken,
            "client_id": GoogleAuthConfig.clientID,
            "grant_type": "refresh_token"
        ]

        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw AuthError.tokenRequestFailed(msg)
        }

        let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        guard let accessToken = json?["access_token"] as? String else {
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw AuthError.tokenRequestFailed(msg)
        }

        // store new access token and expiry
        let ok = KeychainHelper.shared.save(Data(accessToken.utf8), service: keychainService, account: accessAccount)
        print("[Auth] refreshed access token saved: \(ok)")
        if let expires = json?["expires_in"] as? Double {
            let expiryDate = Date().addingTimeInterval(expires)
            UserDefaults.standard.set(expiryDate.timeIntervalSince1970, forKey: tokenExpiryKey)
            print("[Auth] refreshed token expiry: \(expiryDate)")
        }

        return accessToken
    }

    // Public helper to obtain a valid access token (refreshing if necessary)
    func getValidAccessToken() async throws -> String {
        // try access token first
        if let accessData = KeychainHelper.shared.read(service: keychainService, account: accessAccount),
           let accessToken = String(data: accessData, encoding: .utf8) {
            // check expiry
            if let expiryTs = UserDefaults.standard.object(forKey: tokenExpiryKey) as? Double {
                let expiry = Date(timeIntervalSince1970: expiryTs)
                if Date() < expiry.addingTimeInterval(-30) { // 30s leeway
                    return accessToken
                }
            } else {
                return accessToken
            }
        }

        // otherwise refresh
        let newToken = try await refreshAccessToken()
        return newToken
    }

    private func fetchUserInfo(accessToken: String) async {
        // Simple call to get userinfo (optional). We'll call Google's userinfo endpoint.
        guard let url = URL(string: "https://www.googleapis.com/oauth2/v3/userinfo") else { return }

        var req = URLRequest(url: url)
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200 else { return }
            let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            DispatchQueue.main.async {
                self.email = json?["email"] as? String
                self.isSignedIn = true
            }
        } catch {
            DispatchQueue.main.async {
                self.isSignedIn = true // still consider signed in if token exists
            }
        }
    }

    func signOut() {
        UserDefaults.standard.removeObject(forKey: tokenExpiryKey)
        KeychainHelper.shared.delete(service: keychainService, account: accessAccount)
        KeychainHelper.shared.delete(service: keychainService, account: refreshAccount)
        Task { @MainActor in
            self.isSignedIn = false
            self.email = nil
        }
    }

    // Debug helpers
    func hasRefreshToken() -> Bool {
        KeychainHelper.shared.read(service: keychainService, account: refreshAccount) != nil
    }

    func tokenExpiryDate() -> Date? {
        guard let ts = UserDefaults.standard.object(forKey: tokenExpiryKey) as? Double else { return nil }
        return Date(timeIntervalSince1970: ts)
    }

    // Helper to get stored access token (reads Keychain)
    func accessToken() -> String? {
        guard let data = KeychainHelper.shared.read(service: keychainService, account: accessAccount) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
