import SwiftUI

struct TaskDetailView: View {
    @State private var task: TaskItem
    let listId: String
    let viewModel: TaskListViewModel
    let auth: AuthenticationManager
    @Environment(\.dismiss) private var dismiss

    @State private var isLoading = false
    @State private var errorMessage: String?

    init(task: TaskItem, listId: String, viewModel: TaskListViewModel, auth: AuthenticationManager) {
        _task = State(initialValue: task)
        self.listId = listId
        self.viewModel = viewModel
        self.auth = auth
    }

    var body: some View {
            ZStack {
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                    .ignoresSafeArea()

                if isLoading {
                    ProgressView("Loading details...")
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text(error)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task { await fetchDetails() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            headerSection
                            
                            VStack(spacing: 16) {
                                if let notes = task.notes, !notes.isEmpty {
                                    detailSection(title: "Notes", content: notes, icon: "note.text")
                                }
                                
                                if let due = task.due, let date = ISO8601DateFormatter().date(from: due) {
                                    detailSection(title: "Due Date", content: date.formatted(date: .long, time: .omitted), icon: "calendar")
                                }
                                
                                if let completed = task.completed, let date = ISO8601DateFormatter().date(from: completed) {
                                    detailSection(title: "Completed", content: date.formatted(date: .long, time: .shortened), icon: "checkmark.circle.fill", color: .green)
                                }
                                
                                statusSection
                            }
                        }
                        .padding(24)
                    }
                    .padding(0)
                }
            }
            .navigationTitle("Task Details")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .buttonStyle(.glassProminent)
                }
            }
            .onAppear {
                Task { await fetchDetails() }
            }
        .frame(minWidth: 450, minHeight: 500)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(task.title ?? "(No Title)")
                .font(.title)
                .fontWeight(.bold)
        }
    }

    private var statusSection: some View {
        HStack {
            Label(task.status == "completed" ? "Completed" : "In Progress", 
                  systemImage: task.status == "completed" ? "checkmark.circle.fill" : "circle")
                .foregroundColor(task.status == "completed" ? .green : .orange)
                .font(.headline)
            Spacer()
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }

    private func detailSection(title: String, content: String, icon: String, color: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
            }
            
            Text(content)
                .font(.body)
                .foregroundColor(color)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }

    private func fetchDetails() async {
        isLoading = true
        errorMessage = nil
        do {
            let updatedTask = try await viewModel.fetchTaskDetails(listId: listId, taskId: task.id, auth: auth)
            await MainActor.run {
                self.task = updatedTask
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to fetch full details: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}
