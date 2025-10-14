import SwiftUI

struct TaskListTab: View {
    let list: TaskList
    let repository: TasksRepository
    @ObservedObject var auth: AuthenticationManager
    @Binding var alertMessage: String
    @Binding var showingAlert: Bool
    @StateObject private var vm: TaskListViewModel
    @State private var hasLoadedOnce = false
    @State private var visibleTaskIDs: Set<String> = []

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

            List {
                if vm.tasks.isEmpty {
                    Text("No tasks loaded").foregroundColor(.secondary)
                } else {
                    ForEach(Array(vm.tasks.enumerated()), id: \.element.id) { pair in
                        let index = pair.offset
                        let task = pair.element
                        let isVisible = visibleTaskIDs.contains(task.id)

                        TaskCard(task: task)
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                CompletionActionView(isCompleted: task.status == "completed") { toggleCompletion(for: task) }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                CompletionActionView(isCompleted: task.status == "completed") { toggleCompletion(for: task) }
                            }
                            .contextMenu { Button(role: .destructive) { deleteTask(task) } label: { Label("Delete Task", systemImage: "trash") } }
                            .listRowBackground(Color.clear)
                            .opacity(isVisible ? 1 : 0)
                            .scaleEffect(isVisible ? 1 : 0.98)
                            .offset(x: isVisible ? 0 : 30)
                            .animation(.interactiveSpring(response: 0.45, dampingFraction: 0.75, blendDuration: 0.1).delay(Double(index) * 0.015), value: isVisible)
                    }
                }
            }
            .listStyle(.sidebar)
        }
        .onAppear {
            Task { await loadTasks(policy: hasLoadedOnce ? .staleOnly : .startup) }
            Task { @MainActor in await Task.yield(); hasLoadedOnce = true }
        }
        .onChange(of: vm.tasks.count) { _, _ in
            visibleTaskIDs.removeAll()
            Task { @MainActor in try? await Task.sleep(nanoseconds: 120_000_000); staggerInRows() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .taskListDidChange)) { notification in
            guard let updatedListId = notification.object as? String, updatedListId == list.id else { return }
            Task { await vm.loadCachedTasks(for: list.id) }
        }
    }

    private func staggerInRows() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 40_000_000)
            for (i, task) in vm.tasks.enumerated() {
                // stagger each row
                try? await Task.sleep(nanoseconds: UInt64(40_000_000 * i))
                withAnimation { _ = visibleTaskIDs.insert(task.id) }
            }
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
