import SwiftUI

struct NewTaskSheet: View {
    @State private var title = ""
    @State private var notes = ""
    @State private var dueDate: Date = Date()
    @State private var hasDueDate = false
    let isFocused: FocusState<Bool>.Binding
    let onCreate: (String, String?, Date?) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("New Task")
                .font(.title2)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 8) {
                Text("Title").font(.caption).foregroundColor(.secondary)
                TextField("Task Title", text: $title)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                    .focused(isFocused)
                    .onAppear { DispatchQueue.main.async { isFocused.wrappedValue = true } }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Notes (Optional)").font(.caption).foregroundColor(.secondary)
                TextEditor(text: $notes)
                    .frame(height: 80)
                    .padding(8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
            }

            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: $hasDueDate) {
                    Text("Add Due Date").font(.caption).foregroundColor(.secondary)
                }
                .toggleStyle(.checkbox)
                
                if hasDueDate {
                    DatePicker("Pick a date", selection: $dueDate, displayedComponents: .date)
                        .labelsHidden()
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            HStack(spacing: 12) {
                Spacer()
                Button("Cancel") { onCancel() }
                    .buttonStyle(.plain)
                
                Button("Create") {
                    onCreate(title, notes.isEmpty ? nil : notes, hasDueDate ? dueDate : nil)
                }
                .buttonStyle(.glassProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400)
    }
}
