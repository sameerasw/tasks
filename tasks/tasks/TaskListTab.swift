import SwiftUI
import Combine

struct TaskListTab: View {
    let list: TaskList
    let repository: TasksRepository
    @ObservedObject var auth: AuthenticationManager
    @State private var tasks: [TaskItem] = []
    @Binding var alertMessage: String
    @Binding var showingAlert: Bool
    @State private var hasLoadedOnce = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(list.title ?? "(no title)")
                .font(.title)
                .padding([.top, .leading, .trailing])

            List {
                if tasks.isEmpty {
                    Text("No tasks loaded")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(tasks) { task in
                        TaskCard(task: task)
                            .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                completionSwipeButton(for: task)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                completionSwipeButton(for: task)
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    deleteTask(task)
                                } label: {
                                    Label("Delete Task", systemImage: "trash")
                                }
                            }
                            .listRowBackground(Color.clear)
                    }
                }
            }
            .listStyle(.inset)
        }
        .onAppear {
            loadTasks(policy: hasLoadedOnce ? .staleOnly : .startup)
            hasLoadedOnce = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .taskListDidChange)) { notification in
            guard let updatedListId = notification.object as? String, updatedListId == list.id else { return }
            Task {
                await loadCachedTasksOnly()
            }
        }
    }

    private func loadTasks(policy: RefreshPolicy) {
        Task {
            let cached = await repository.cachedTasks(for: list.id)
            await MainActor.run {
                self.tasks = cached
            }

            let signedIn = await MainActor.run { auth.isSignedIn }
            guard signedIn else { return }

            do {
                let token = try await auth.getValidAccessToken()
                let items = try await repository.loadTasks(accessToken: token, listId: list.id, policy: policy)
                await MainActor.run {
                    self.tasks = items
                }
            } catch {
                let msg = "Failed to load tasks: \(error)"
                print(msg)
                await MainActor.run {
                    alertMessage = msg
                    showingAlert = true
                }
            }
        }
    }

    private func loadCachedTasksOnly() async {
        let cached = await repository.cachedTasks(for: list.id)
        await MainActor.run {
            self.tasks = cached
        }
    }

    private func completionSwipeButton(for task: TaskItem) -> some View {
        let isCompleted = task.status == "completed"
        return Button {
            toggleCompletion(for: task)
        } label: {
            Label(isCompleted ? "Mark Undone" : "Mark Done", systemImage: isCompleted ? "arrow.uturn.backward.circle" : "checkmark.circle")
        }
        .tint(isCompleted ? .orange : .green)
    }

    private func toggleCompletion(for task: TaskItem) {
        Task {
            do {
                let token = try await auth.getValidAccessToken()
                let updated = try await repository.updateTaskStatus(accessToken: token, listId: list.id, taskId: task.id, isCompleted: task.status != "completed")
                await MainActor.run {
                    self.tasks = updated
                    NotificationCenter.default.post(name: .taskListDidChange, object: list.id)
                }
            } catch {
                let msg = "Failed to update task: \(error)"
                print(msg)
                await MainActor.run {
                    alertMessage = msg
                    showingAlert = true
                }
            }
        }
    }

    private func deleteTask(_ task: TaskItem) {
        Task {
            do {
                let token = try await auth.getValidAccessToken()
                let updated = try await repository.deleteTask(accessToken: token, listId: list.id, taskId: task.id)
                await MainActor.run {
                    self.tasks = updated
                    NotificationCenter.default.post(name: .taskListDidChange, object: list.id)
                }
            } catch {
                let msg = "Failed to delete task: \(error)"
                print(msg)
                await MainActor.run {
                    alertMessage = msg
                    showingAlert = true
                }
            }
        }
    }
}
