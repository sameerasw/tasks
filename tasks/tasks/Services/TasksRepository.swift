import Foundation

enum RefreshPolicy: Sendable {
    case startup
    case staleOnly
    case force
}

actor TasksRepository {
    private let cache = TasksCache()
    private let service = TasksService()
    private let staleInterval: TimeInterval = 30 * 60

    func cachedTaskLists() async -> [TaskList] {
        let cached = await cache.cachedTaskLists()
        return cached?.value ?? []
    }

    func cachedTasks(for listId: String) async -> [TaskItem] {
        let cached = await cache.cachedTasks(for: listId)
        return cached?.value ?? []
    }

    func lastTaskListRefreshDate() async -> Date? {
        let cached = await cache.cachedTaskLists()
        return cached?.storedAt
    }

    func lastTasksRefreshDate(for listId: String) async -> Date? {
        let cached = await cache.cachedTasks(for: listId)
        return cached?.storedAt
    }

    var refreshInterval: TimeInterval { staleInterval }

    func loadTaskLists(accessToken: String, policy: RefreshPolicy) async throws -> [TaskList] {
        let cached = await cache.cachedTaskLists()
        let needsRefresh = shouldRefresh(since: cached?.storedAt, policy: policy)

        if !needsRefresh, let cachedLists = cached?.value {
            return cachedLists
        }

        do {
            let freshLists = try await service.listTaskLists(accessToken: accessToken)
            await cache.saveTaskLists(freshLists)
            return freshLists
        } catch {
            if let cachedLists = cached?.value, !cachedLists.isEmpty {
                return cachedLists
            }
            throw error
        }
    }

    func loadTasks(accessToken: String, listId: String, policy: RefreshPolicy) async throws -> [TaskItem] {
        let cached = await cache.cachedTasks(for: listId)
        let needsRefresh = shouldRefresh(since: cached?.storedAt, policy: policy)

        if !needsRefresh, let cachedTasks = cached?.value {
            return cachedTasks
        }

        do {
            let freshTasks = try await service.listTasks(accessToken: accessToken, tasklistId: listId)
            await cache.saveTasks(freshTasks, for: listId)
            return freshTasks
        } catch {
            if let cachedTasks = cached?.value {
                return cachedTasks
            }
            throw error
        }
    }

    func markTasksDirty(for listId: String) async {
    await cache.invalidateTasks(for: listId)
    }

    func clearAll() async {
    await cache.invalidateAll()
    }

    func updateTaskStatus(accessToken: String, listId: String, taskId: String, isCompleted: Bool) async throws -> [TaskItem] {
        let updated = try await service.updateTaskStatus(accessToken: accessToken, tasklistId: listId, taskId: taskId, isCompleted: isCompleted)
    var current = (await cache.cachedTasks(for: listId))?.value ?? []

        if let index = current.firstIndex(where: { $0.id == updated.id }) {
            current[index] = updated
        } else {
            current.insert(updated, at: 0)
        }

    await cache.saveTasks(current, for: listId)
        return current
    }

    func deleteTask(accessToken: String, listId: String, taskId: String) async throws -> [TaskItem] {
        try await service.deleteTask(accessToken: accessToken, tasklistId: listId, taskId: taskId)
    var current = (await cache.cachedTasks(for: listId))?.value ?? []
        current.removeAll { $0.id == taskId }
    await cache.saveTasks(current, for: listId)
        return current
    }

    func createTask(accessToken: String, listId: String, title: String) async throws -> [TaskItem] {
        let newTask = try await service.createTask(accessToken: accessToken, tasklistId: listId, title: title)
    var current = (await cache.cachedTasks(for: listId))?.value ?? []
        current.insert(newTask, at: 0)
        await cache.saveTasks(current, for: listId)
        return current
    }


    private func shouldRefresh(since date: Date?, policy: RefreshPolicy) -> Bool {
        switch policy {
        case .startup, .force:
            return true
        case .staleOnly:
            guard let date else { return true }
            return Date().timeIntervalSince(date) >= staleInterval
        }
    }
}
