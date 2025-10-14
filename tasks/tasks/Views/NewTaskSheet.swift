import SwiftUI

struct NewTaskSheet: View {
    @Binding var title: String
    let isFocused: FocusState<Bool>.Binding
    let onCreate: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Task")
                .font(.headline)

            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)
                .focused(isFocused)
                .onAppear { DispatchQueue.main.async { isFocused.wrappedValue = true } }

            HStack {
                Spacer()
                Button("Cancel") { onCancel() }
                Button("Create") { onCreate(title) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 320)
    }
}
