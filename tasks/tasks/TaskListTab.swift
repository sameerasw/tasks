import SwiftUI

struct TaskListTab: View {
    let list: TaskList
    let repository: TasksRepository
    @ObservedObject var auth: AuthenticationManager

    @StateObject private var vm: TaskListViewModel
    @State private var hasLoadedOnce = false
    @State private var visibleTaskIDs: Set<String> = []
    @State private var selectedTask: TaskItem?

    init(list: TaskList, repository: TasksRepository, auth: AuthenticationManager) {
        self.list = list
        self.repository = repository
        self.auth = auth

        _vm = StateObject(wrappedValue: TaskListViewModel(repository: repository))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            List {
                if vm.tasks.isEmpty {
                    Text("ʅ(°_°)ʃ  Nothing to see here").foregroundColor(.secondary)
                } else {
                    ForEach(Array(vm.tasks.enumerated()), id: \.element.id) { index, task in
                        TaskRowView(
                            task: task,
                            index: index,
                            isVisible: visibleTaskIDs.contains(task.id),
                            onTap: { selectedTask = task },
                            toggleCompletion: { toggleCompletion(for: task) },
                            deleteTask: { deleteTask(task) }
                        )
                    }
                }
            }
            .listStyle(.sidebar)
        }
        .sheet(item: $selectedTask) { task in
            TaskSheetView(task: task, listId: list.id, viewModel: vm, auth: auth)
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
                try? await Task.sleep(nanoseconds: UInt64(40_000_000 * i))
                withAnimation { _ = visibleTaskIDs.insert(task.id) }
            }
        }
    }

    private func loadTasks(policy: RefreshPolicy) async {
        do {
            try await vm.loadTasks(for: list.id, policy: policy, auth: auth)
        } catch {
            Task { @MainActor in await Task.yield() }
        }
    }

    private func toggleCompletion(for task: TaskItem) {
        Task {
            do { try await vm.updateStatus(for: task, listId: list.id, auth: auth) }
            catch { Task { @MainActor in await Task.yield() } }
        }
    }

    private func deleteTask(_ task: TaskItem) {
        Task {
            do { try await vm.delete(task: task, listId: list.id, auth: auth) }
            catch { Task { @MainActor in await Task.yield() } }
        }
    }
}

private struct TaskRowView: View {
    let task: TaskItem
    let index: Int
    let isVisible: Bool
    let onTap: () -> Void
    let toggleCompletion: () -> Void
    let deleteTask: () -> Void

    var body: some View {
        TaskCard(taskItem: task, onToggleCompletion: toggleCompletion)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                CompletionActionView(isCompleted: task.status == "completed", action: toggleCompletion)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                CompletionActionView(isCompleted: task.status == "completed", action: toggleCompletion)
            }
            .contextMenu {
                Button(role: .destructive, action: deleteTask) {
                    Label("Delete Task", systemImage: "trash")
                }
            }
            .listRowBackground(Color.clear)
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.98)
            .offset(x: isVisible ? 0 : 30)
            .animation(.interactiveSpring(response: 0.45, dampingFraction: 0.75, blendDuration: 0.1).delay(Double(index) * 0.015), value: isVisible)
    }
}
