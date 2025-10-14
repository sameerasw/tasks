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

    func cachedTaskLists() -> [TaskList] {
        cache.cachedTaskLists()?.value ?? []
    }

    func cachedTasks(for listId: String) -> [TaskItem] {
        cache.cachedTasks(for: listId)?.value ?? []
    }

    func lastTaskListRefreshDate() -> Date? {
        cache.cachedTaskLists()?.storedAt
    }

    func lastTasksRefreshDate(for listId: String) -> Date? {
        cache.cachedTasks(for: listId)?.storedAt
    }

    var refreshInterval: TimeInterval { staleInterval }

    func loadTaskLists(accessToken: String, policy: RefreshPolicy) async throws -> [TaskList] {
        let cached = cache.cachedTaskLists()
        let needsRefresh = shouldRefresh(since: cached?.storedAt, policy: policy)

        if !needsRefresh, let cachedLists = cached?.value {
            return cachedLists
        }

        do {
            let freshLists = try await service.listTaskLists(accessToken: accessToken)
            cache.saveTaskLists(freshLists)
            return freshLists
        } catch {
            if let cachedLists = cached?.value, !cachedLists.isEmpty {
                return cachedLists
            }
            throw error
        }
    }

    func loadTasks(accessToken: String, listId: String, policy: RefreshPolicy) async throws -> [TaskItem] {
        let cached = cache.cachedTasks(for: listId)
        let needsRefresh = shouldRefresh(since: cached?.storedAt, policy: policy)

        if !needsRefresh, let cachedTasks = cached?.value {
            return cachedTasks
        }

        do {
            let freshTasks = try await service.listTasks(accessToken: accessToken, tasklistId: listId)
            cache.saveTasks(freshTasks, for: listId)
            return freshTasks
        } catch {
            if let cachedTasks = cached?.value {
                return cachedTasks
            }
            throw error
        }
    }

    func markTasksDirty(for listId: String) {
        cache.invalidateTasks(for: listId)
    }

    func clearAll() {
        cache.invalidateAll()
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
