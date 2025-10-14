import SwiftUI

struct AppHeaderView: View {
    let systemImage: String
    let title: String?

    init(systemImage: String = "checkmark.circle", title: String? = nil) {
        self.systemImage = systemImage
        self.title = title
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .resizable()
                .frame(width: 64, height: 64)
                .foregroundColor(.accentColor)

            if let title {
                Text(title)
                    .font(.largeTitle)
                    .fontWeight(.semibold)
            }
        }
    }
}
