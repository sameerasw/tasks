import SwiftUI

struct CompletionActionView: View {
    let isCompleted: Bool
    let action: () -> Void

    var body: some View {
        Button { action() } label: {
            Label(isCompleted ? "Mark Undone" : "Mark Done", systemImage: isCompleted ? "arrow.uturn.backward.circle" : "checkmark.circle")
        }
        .tint(isCompleted ? .orange : .green)
    }
}
