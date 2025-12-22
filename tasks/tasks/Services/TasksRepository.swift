import Foundation

enum RefreshPolicy: Sendable {
    case startup
    case staleOnly
    case force
}

final class TasksRepository {
    private let cache = TasksCache()
    private let service = TasksService()
    private let staleInterval: TimeInterval = 30 * 60

    private func cachedValue_getValue<T>(_ cached: CachedValue<T>?) async -> T? {
        await MainActor.run { cached?.value }
    }

    private func cachedValue_getStoredAt<T>(_ cached: CachedValue<T>?) async -> Date? {
        await MainActor.run { cached?.storedAt }
    }


    func cachedTaskLists() async -> [TaskList] {
        let cached = await cache.cachedTaskLists()
        return await cachedValue_getValue(cached) ?? []
    }

    func cachedTasks(for listId: String) async -> [TaskItem] {
        let cached = await cache.cachedTasks(for: listId)
        return await cachedValue_getValue(cached) ?? []
    }

    func lastTaskListRefreshDate() async -> Date? {
        let cached = await cache.cachedTaskLists()
        return await cachedValue_getStoredAt(cached)
    }

    func lastTasksRefreshDate(for listId: String) async -> Date? {
        let cached = await cache.cachedTasks(for: listId)
        return await cachedValue_getStoredAt(cached)
    }

    var refreshInterval: TimeInterval { staleInterval }

    func loadTaskLists(accessToken: String, policy: RefreshPolicy) async throws -> [TaskList] {
        let cached = await cache.cachedTaskLists()
        let lastDate = await cachedValue_getStoredAt(cached)
        let needsRefresh = shouldRefresh(since: lastDate, policy: policy)

        if !needsRefresh, let cachedLists = await cachedValue_getValue(cached) {
            return cachedLists
        }

        do {
            let freshLists = try await service.listTaskLists(accessToken: accessToken)
            await cache.saveTaskLists(freshLists)
            return freshLists
        } catch {
            if let cachedLists = await cachedValue_getValue(cached), !cachedLists.isEmpty {
                return cachedLists
            }
            throw error
        }
    }

    func loadTasks(accessToken: String, listId: String, policy: RefreshPolicy) async throws -> [TaskItem] {
        let cached = await cache.cachedTasks(for: listId)
        let lastDate = await cachedValue_getStoredAt(cached)
        let needsRefresh = shouldRefresh(since: lastDate, policy: policy)

        if !needsRefresh, let cachedTasks = await cachedValue_getValue(cached) {
            return cachedTasks
        }

        do {
            let freshTasks = try await service.listTasks(accessToken: accessToken, tasklistId: listId)
            await cache.saveTasks(freshTasks, for: listId)
            return freshTasks
        } catch {
            if let cachedTasks = await cachedValue_getValue(cached) {
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

        let cached = await cache.cachedTasks(for: listId)
        var current = await cachedValue_getValue(cached) ?? []

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

        let cached = await cache.cachedTasks(for: listId)
        var current = await cachedValue_getValue(cached) ?? []
        current.removeAll { $0.id == taskId }

        await cache.saveTasks(current, for: listId)
        return current
    }

    func createTask(accessToken: String, listId: String, title: String) async throws -> [TaskItem] {
        let newTask = try await service.createTask(accessToken: accessToken, tasklistId: listId, title: title)

        let cached = await cache.cachedTasks(for: listId)
        var current = await cachedValue_getValue(cached) ?? []
        current.insert(newTask, at: 0)

        await cache.saveTasks(current, for: listId)
        return current
    }

    public func getTask(accessToken: String, listId: String, taskId: String) async throws -> TaskItem {
        return try await service.getTask(accessToken: accessToken, tasklistId: listId, taskId: taskId)
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
