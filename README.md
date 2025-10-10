# tasks

Google tasks for macOS

## Authentication setup

This project includes a simple OAuth authentication flow for Google using
ASWebAuthenticationSession. To enable sign-in you must register OAuth 2.0
credentials in the Google Cloud Console and update the placeholders in
`Auth/GoogleAuthConfig.swift`:

- `clientID`: Replace `"YOUR_CLIENT_ID_HERE"` with your macOS app's client ID.
- `redirectURI`: Replace `"YOUR_REDIRECT_URI_HERE"` with the redirect URI you
  register in the console (for macOS apps you can use a custom scheme like
  `com.example.tasks:/oauthredirect`). Ensure the scheme matches exactly.

Scopes currently requested: `https://www.googleapis.com/auth/tasks`.

Quick steps:

1. Open Google Cloud Console > APIs & Services > Credentials.
2. Create an OAuth 2.0 Client ID. For macOS, choose "Desktop app" or configure
   an iOS/macOS client with a custom URL scheme.
3. Add the redirect URI you will use.
4. Copy the client ID and paste it into `Auth/GoogleAuthConfig.swift`.
5. Run the app and use the "Sign in with Google" button.

Note: This example stores the access token in UserDefaults for simplicity.
In production you should store tokens in the macOS Keychain and handle
refresh tokens properly.
