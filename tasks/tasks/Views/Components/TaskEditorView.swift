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
            // Title Section
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
            
            // Due Date Section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Due Date").font(.caption).foregroundColor(.secondary)
                    Spacer()
                    if dueDate != nil {
                        Button(role: .destructive) {
                            withAnimation { dueDate = nil }
                        } label: {
                            Label("Clear", systemImage: "xmark.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .help("Clear due date")
                    }
                }

                WrappingHStack(spacing: 8) {
                    DateShortcutButton(label: "Today", icon: "sun.max.fill", color: .orange) {
                        dueDate = Calendar.current.startOfDay(for: Date())
                    }
                    
                    DateShortcutButton(label: "Tomorrow", icon: "sunrise.fill", color: .blue) {
                        if let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) {
                            dueDate = Calendar.current.startOfDay(for: tomorrow)
                        }
                    }
                    
                    DateShortcutButton(label: "Next Week", icon: "calendar.badge.plus", color: .purple) {
                        if let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: Date()) {
                            dueDate = Calendar.current.startOfDay(for: nextWeek)
                        }
                    }
                    
                    DatePickerButton(dueDate: $dueDate)
                }
            }

            // Notes Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Notes (Optional)").font(.caption).foregroundColor(.secondary)
                TextEditor(text: $notes)
                    .textEditorStyle(.plain)
                    .frame(minHeight: 100)
                    .padding(8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
            }

            // Status Toggle
            if showStatus {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(isOn: Binding(get: { status == "completed" }, set: { status = $0 ? "completed" : "needsAction" })) {
                        Text("Mark as Completed")
                            .font(.body)
                    }
                    .toggleStyle(.checkbox)
                }
            }
        }
    }
}

// MARK: - Helper Components

struct DateShortcutButton: View {
    let label: String
    let icon: String
    let color: Color
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring()) { action() }
        }) {
            Label(label, systemImage: icon)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
        }
        .buttonStyle(.glassProminent)
        .onHover { isHovered = $0 }
        .tint(color.opacity(isHovered ? 0.2 : 0.1))
    }
}

struct DatePickerButton: View {
    @Binding var dueDate: Date?
    @State private var showDatePicker = false
    @State private var isHovered = false
    
    var body: some View {
        Button {
            showDatePicker.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                if let dueDate = dueDate {
                    Text(dueDate.formatted(date: .abbreviated, time: .omitted))
                        .fontWeight(.medium)
                } else {
                    Text("Pick Date...")
                }
            }
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(isHovered ? 0.2 : 0.1))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .popover(isPresented: $showDatePicker, arrowEdge: .bottom) {
            VStack(spacing: 0) {
                DatePicker(
                    "Pick a date",
                    selection: Binding(
                        get: { dueDate ?? Date() },
                        set: { dueDate = $0 }
                    ),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .padding(8)
                
                Divider()
                
                HStack {
                    Spacer()
                    Button("Done") {
                        showDatePicker = false
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .padding(8)
                }
                .background(Color(NSColor.windowBackgroundColor))
            }
            .frame(width: 200)
        }
    }
}

/// A simple wrapping horizontal stack for small components
struct WrappingHStack<Content: View>: View {
    let spacing: CGFloat
    let content: Content

    init(spacing: CGFloat = 8, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        // Using a Flow-like behavior using SwiftUI's Layout protocol if available,
        // but for compatibility and simplicity in this setup, we'll use an HStack
        // that allows the parent to handle layout, or a simple implementation.
        // In macOS apps, the width is usually sufficient for these 4 buttons.
        HStack(spacing: spacing) {
            content
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
