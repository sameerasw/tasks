import Foundation
import AuthenticationServices
import AppKit

final class AuthenticationPresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = AuthenticationPresentationContextProvider()

    private override init() { }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Return the key window if available, otherwise the first window
        if let window = NSApp.keyWindow { return window }
        return NSApp.windows.first ?? ASPresentationAnchor()
    }
}
