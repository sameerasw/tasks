import SwiftUI

struct TaskEditorView: View {
    @Binding var title: String
    @Binding var notes: String
    @Binding var dueDate: Date?
    @Binding var status: String
    var showStatus: Bool = true
    var isFocused: FocusState<Bool>.Binding? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Title").font(.caption).foregroundColor(.secondary)
                TextField("Task Title", text: $title)
                    .textFieldStyle(.plain)
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(10)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                    .ifLet(isFocused) { view, focused in
                        view.focused(focused)
                    }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                    Text("Due Date").font(.caption).foregroundColor(.secondary)

            HStack {
                DatePicker("Pick a date", selection: Binding(get: { dueDate ?? Date() }, set: { dueDate = $0 }), displayedComponents: .date)
                    .labelsHidden()
                Spacer()
                if dueDate != nil {
                    Button("Clear") { dueDate = nil }
                        .font(.caption)
                }
            }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Notes (Optional)").font(.caption).foregroundColor(.secondary)
                TextEditor(text: $notes)
                    .textEditorStyle(.plain)
                    .frame(minHeight: 100)
                    .padding(8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
            }

            if showStatus {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(isOn: Binding(get: { status == "completed" }, set: { status = $0 ? "completed" : "needsAction" })) {
                        Text("Mark as Completed")
                    }
                    .toggleStyle(.checkbox)
                }
            }
        }
    }
}

extension View {
    @ViewBuilder
    func ifLet<V, Transform: View>(_ value: V?, transform: (Self, V) -> Transform) -> some View {
        if let value = value {
            transform(self, value)
        } else {
            self
        }
    }
}
