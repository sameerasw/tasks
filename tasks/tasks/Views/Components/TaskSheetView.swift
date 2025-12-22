import SwiftUI

struct TaskSheetView: View {
    @State private var taskItem: TaskItem? // nil if creating
    let listId: String
    let viewModel: TaskListViewModel
    let auth: AuthenticationManager
    @Environment(\.dismiss) private var dismiss

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isEditing = false
    
    // Draft states for editing/creating
    @State private var draftTitle = ""
    @State private var draftNotes = ""
    @State private var draftDue: Date? = nil
    @State private var draftStatus = "needsAction"
    @State private var isSaving = false
    @FocusState private var titleIsFocused: Bool

    init(task: TaskItem?, listId: String, viewModel: TaskListViewModel, auth: AuthenticationManager) {
        _taskItem = State(initialValue: task)
        self.listId = listId
        self.viewModel = viewModel
        self.auth = auth
        _isEditing = State(initialValue: task == nil)
    }

    var body: some View {
            ZStack {
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                    .ignoresSafeArea()

                if let error = errorMessage {
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
                            if isEditing {
                                TaskEditorView(
                                    title: $draftTitle,
                                    notes: $draftNotes,
                                    dueDate: $draftDue,
                                    status: $draftStatus,
                                    showStatus: taskItem != nil, // Only show status toggle when editing existing
                                    isFocused: $titleIsFocused
                                )
                            } else if let task = taskItem {
                                TaskDetailDisplayView(taskItem: task)
                            }
                        }
                        .padding(24)
                    }
                    .padding(0)
                    .disabled(isSaving)
                }
            }
            .navigationTitle(taskItem == nil ? "New Task" : (isEditing ? "Edit Task" : "Task Details"))
            .onAppear {
                if taskItem == nil {
                    titleIsFocused = true
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    if isEditing {
                        Button(taskItem == nil ? "Create" : "Save", systemImage: taskItem == nil ? "plus.circle" : "square.and.arrow.down") {
                            Task { await saveChanges() }
                        }
                        .disabled(isSaving || draftTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                        .buttonStyle(.glassProminent)
                        .controlSize(.large)
                    } else {
                        Button("Done", systemImage: "checkmark.circle") {
                            dismiss()
                        }
                        .buttonStyle(.glassProminent)
                        .controlSize(.large)
                    }
                }

                ToolbarItem(placement: .destructiveAction) {
                    if isEditing {
                        Button("Cancel", systemImage: "xmark.circle") {
                            if taskItem == nil {
                                dismiss()
                            } else {
                                cancelEditing()
                            }
                        }
                        .disabled(isSaving)
                        .buttonStyle(.glass)
                        .controlSize(.large)
                    } else {
                        if isLoading {
                            ProgressView()
                                .controlSize(.small)
                                .padding(.horizontal, 8)
                        } else {
                            Button("Edit", systemImage: "pencil") {
                                startEditing()
                            }
                            .buttonStyle(.glass)
                            .controlSize(.large)
                        }
                    }
                }
            }
        .onAppear {
            if taskItem != nil {
                Task { await fetchDetails() }
            }
        }
        .frame(minWidth: 450, minHeight: 500)
    }

    private func startEditing() {
        guard let task = taskItem else { return }
        draftTitle = task.title ?? ""
        draftNotes = task.notes ?? ""
        draftDue = task.due?.toDate()
        draftStatus = task.status ?? "needsAction"
        isEditing = true
    }

    private func cancelEditing() {
        isEditing = false
    }

    private func saveChanges() async {
        isSaving = true
        errorMessage = nil
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let dueStr = draftDue.map { formatter.string(from: $0) }
        
        do {
            if let task = taskItem {
                // Update existing
                let updatedTask = TaskItem(
                    id: task.id,
                    title: draftTitle,
                    notes: draftNotes,
                    status: draftStatus,
                    due: dueStr,
                    completed: task.completed,
                    updated: nil,
                    deleted: task.deleted,
                    hidden: task.hidden,
                    links: task.links,
                    webViewLink: task.webViewLink,
                    parent: task.parent,
                    position: task.position,
                    selfLink: task.selfLink,
                    etag: task.etag,
                    assignmentInfo: task.assignmentInfo
                )
                let result = try await viewModel.updateTask(updatedTask, listId: listId, auth: auth)
                await MainActor.run {
                    self.taskItem = result
                    self.isEditing = false
                    self.isSaving = false
                }
            } else {
                // Create new
                try await viewModel.createTask(
                    title: draftTitle,
                    notes: draftNotes.isEmpty ? nil : draftNotes,
                    due: dueStr,
                    listId: listId,
                    auth: auth
                )
                await MainActor.run {
                    self.isSaving = false
                    dismiss()
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to save: \(error.localizedDescription)"
                self.isSaving = false
            }
        }
    }

    private func fetchDetails() async {
        guard let task = taskItem else { return }
        isLoading = true
        errorMessage = nil
        do {
            let updatedTask = try await viewModel.fetchTaskDetails(listId: listId, taskId: task.id, auth: auth)
            await MainActor.run {
                self.taskItem = updatedTask
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
