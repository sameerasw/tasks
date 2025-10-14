import SwiftUI

struct DebugPanelView: View {
    let debugInfo: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            Text("Debug")
                .font(.headline)
            Text(debugInfo)
                .font(.system(.body, design: .monospaced))
                .padding()
        }
    }
}
