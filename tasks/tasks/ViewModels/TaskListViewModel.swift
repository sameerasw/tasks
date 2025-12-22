import Foundation
import Combine

@MainActor
final class TaskListViewModel: ObservableObject {
    @Published var tasks: [TaskItem] = []

    private let repository: TasksRepository

    init(repository: TasksRepository) {
        self.repository = repository
    }

    func loadCachedTasks(for listId: String) async {
        let cached = await repository.cachedTasks(for: listId)
        Task { @MainActor in await Task.yield(); tasks = cached }
    }

    func loadTasks(for listId: String, policy: RefreshPolicy, auth: AuthenticationManager) async throws {
    let cached = await repository.cachedTasks(for: listId)
    Task { @MainActor in await Task.yield(); tasks = cached }

        let signedIn = auth.isSignedIn
        guard signedIn else { return }

        let token = try await auth.getValidAccessToken()
        let items = try await repository.loadTasks(accessToken: token, listId: listId, policy: policy)
    Task { @MainActor in await Task.yield(); tasks = items }
    }

    func updateStatus(for task: TaskItem, listId: String, auth: AuthenticationManager) async throws {
        let token = try await auth.getValidAccessToken()
        let updated = try await repository.updateTaskStatus(accessToken: token, listId: listId, taskId: task.id, isCompleted: task.status != "completed")
        Task { @MainActor in await Task.yield(); tasks = updated }
        NotificationCenter.default.post(name: .taskListDidChange, object: listId)
    }

    func delete(task: TaskItem, listId: String, auth: AuthenticationManager) async throws {
        let token = try await auth.getValidAccessToken()
        let updated = try await repository.deleteTask(accessToken: token, listId: listId, taskId: task.id)
        Task { @MainActor in await Task.yield(); tasks = updated }
        NotificationCenter.default.post(name: .taskListDidChange, object: listId)
    }

    func fetchTaskDetails(listId: String, taskId: String, auth: AuthenticationManager) async throws -> TaskItem {
        let token = try await auth.getValidAccessToken()
        return try await repository.getTask(accessToken: token, listId: listId, taskId: taskId)
    }

    func updateTask(_ task: TaskItem, listId: String, auth: AuthenticationManager) async throws -> TaskItem {
        let token = try await auth.getValidAccessToken()
        let updated = try await repository.updateTask(accessToken: token, listId: listId, task: task)
        NotificationCenter.default.post(name: .taskListDidChange, object: listId)
        return updated
    }

    func createTask(title: String, notes: String?, due: String?, listId: String, auth: AuthenticationManager) async throws {
        let token = try await auth.getValidAccessToken()
        let updated = try await repository.createTask(accessToken: token, listId: listId, title: title, notes: notes, due: due)
        Task { @MainActor in await Task.yield(); tasks = updated }
        NotificationCenter.default.post(name: .taskListDidChange, object: listId)
    }
}
