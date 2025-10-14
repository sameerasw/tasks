import SwiftUI
import AppKit

struct AboutView: View {
    let onClose: () -> Void

    private var appVersion: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        return [v, b].filter { !$0.isEmpty }.joined(separator: " (") + (b.isEmpty ? "" : ")")
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("Tasks")
                .font(.largeTitle)
                .bold()

            Text("Google Tasks unofficial macOS native client.")
                .multilineTextAlignment(.leading)
                .padding(.horizontal)

            Text("v\(appVersion)")
                .foregroundColor(.secondary)

            Image("avatar")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 100, height: 100)
                .clipShape(Circle())
                .padding()

            Text("Developed by sameerasw.com")
                .font(.headline)
                .multilineTextAlignment(.center)

            Text("With ❤️ from 🇱🇰")
                .font(.callout)


            Divider()

            HStack {
                Button(action: {
                    if let url = URL(string: "https://www.sameerasw.com") { NSWorkspace.shared.open(url) }
                }) { Label("My Website", systemImage: "link") }
                    .buttonStyle(.glass)
                    .controlSize(.large)

                Button(action: {
                    if let url = URL(string: "https://github.com/sameerasw") { NSWorkspace.shared.open(url) }
                }) { Label("GitHub", systemImage: "folder") }
                    .buttonStyle(.glass)
                    .controlSize(.large)

                Spacer()

                Button("OK", action: onClose)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
            }
        }
        .padding()
        .frame(width: 520, height: 420)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.windowBackgroundColor)))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 12)
    }
}

#Preview {
    AboutView(onClose: {})
}
