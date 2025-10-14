import SwiftUI

struct TaskListTab: View {
    let list: TaskList
    let repository: TasksRepository
    @ObservedObject var auth: AuthenticationManager
    @Binding var alertMessage: String
    @Binding var showingAlert: Bool
    @StateObject private var vm: TaskListViewModel
    @State private var hasLoadedOnce = false

    init(list: TaskList, repository: TasksRepository, auth: AuthenticationManager, alertMessage: Binding<String>, showingAlert: Binding<Bool>) {
        self.list = list
        self.repository = repository
        self.auth = auth
        self._alertMessage = alertMessage
        self._showingAlert = showingAlert
        _vm = StateObject(wrappedValue: TaskListViewModel(repository: repository))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(list.title ?? "(no title)")
                .font(.title)
                .padding([.top, .leading, .trailing])

            List {
                if vm.tasks.isEmpty {
                    Text("No tasks loaded").foregroundColor(.secondary)
                } else {
                    ForEach(vm.tasks) { task in
                        TaskCard(task: task)
                            .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                            .swipeActions(edge: .leading, allowsFullSwipe: true) { completionSwipeButton(for: task) }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) { completionSwipeButton(for: task) }
                            .contextMenu { Button(role: .destructive) { deleteTask(task) } label: { Label("Delete Task", systemImage: "trash") } }
                            .listRowBackground(Color.clear)
                    }
                }
            }
            .listStyle(.inset)
        }
        .onAppear {
            Task { await loadTasks(policy: hasLoadedOnce ? .staleOnly : .startup) }
            Task { @MainActor in await Task.yield(); hasLoadedOnce = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: .taskListDidChange)) { notification in
            guard let updatedListId = notification.object as? String, updatedListId == list.id else { return }
            Task { await vm.loadCachedTasks(for: list.id) }
        }
    }

    private func loadTasks(policy: RefreshPolicy) async {
        do {
            try await vm.loadTasks(for: list.id, policy: policy, auth: auth)
        } catch {
            Task { @MainActor in await Task.yield(); alertMessage = "Failed to load tasks: \(error)"; showingAlert = true }
        }
    }

    private func completionSwipeButton(for task: TaskItem) -> some View {
        let isCompleted = task.status == "completed"
        return Button { toggleCompletion(for: task) } label: { Label(isCompleted ? "Mark Undone" : "Mark Done", systemImage: isCompleted ? "arrow.uturn.backward.circle" : "checkmark.circle") }
            .tint(isCompleted ? .orange : .green)
    }

    private func toggleCompletion(for task: TaskItem) {
        Task {
            do { try await vm.updateStatus(for: task, listId: list.id, auth: auth) }
            catch { Task { @MainActor in await Task.yield(); alertMessage = "Failed to update task: \(error)"; showingAlert = true } }
        }
    }

    private func deleteTask(_ task: TaskItem) {
        Task {
            do { try await vm.delete(task: task, listId: list.id, auth: auth) }
            catch { Task { @MainActor in await Task.yield(); alertMessage = "Failed to delete task: \(error)"; showingAlert = true } }
        }
    }
}
