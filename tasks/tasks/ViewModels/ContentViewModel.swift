import Foundation
import Combine

@MainActor
final class ContentViewModel: ObservableObject {
    @Published var taskLists: [TaskList] = []
    @Published var selectedListId: String? = nil
    @Published var loading = false
    @Published var alertMessage: String = ""
    @Published var showingAlert: Bool = false
    @Published var debugInfo: String = ""
    @Published var hasLoadedOnce = false
    @Published var refreshInProgress = false

    let repository: TasksRepository

    init(repository: TasksRepository) {
        self.repository = repository
    }

    func loadCachedTaskLists() async {
        let cached = await repository.cachedTaskLists()
        Task { @MainActor in
            await Task.yield()
            taskLists = cached
            if selectedListId == nil {
                selectedListId = cached.first?.id
            } else if let current = selectedListId, !cached.contains(where: { $0.id == current }) {
                selectedListId = cached.first?.id
            }
        }
    }

    func refreshTaskLists(policy: RefreshPolicy, auth: AuthenticationManager) async {
    Task { @MainActor in await Task.yield(); refreshInProgress = true }
        let signedIn = auth.isSignedIn
        guard signedIn else {
            Task { @MainActor in await Task.yield(); loading = false; refreshInProgress = false }
            return
        }

        do {
            let previousStamp = await repository.lastTaskListRefreshDate()
            let token = try await auth.getValidAccessToken()
            let lists = try await repository.loadTaskLists(accessToken: token, policy: policy)
            let latestStamp = await repository.lastTaskListRefreshDate()
            let didRefresh = latestStamp != previousStamp || previousStamp == nil

            Task { @MainActor in
                await Task.yield()
                taskLists = lists
                loading = false
                refreshInProgress = false
                if let current = selectedListId, lists.contains(where: { $0.id == current }) {
                } else {
                    selectedListId = lists.first?.id
                }
            }

            if didRefresh || policy == .startup || policy == .force {
                let repo = repository
                Task.detached(priority: .background) {
                    for list in lists {
                        do {
                            _ = try await repo.loadTasks(accessToken: token, listId: list.id, policy: .startup)
                        } catch {}
                    }
                }
            }
        } catch {
            Task { @MainActor in
                await Task.yield()
                loading = false
                alertMessage = "Failed to load task lists: \(error)"
                showingAlert = true
                refreshInProgress = false
            }
        }
    }

    func createTask(title: String, auth: AuthenticationManager) async {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let listId = selectedListId else { return }

        do {
            let token = try await auth.getValidAccessToken()
            _ = try await repository.createTask(accessToken: token, listId: listId, title: trimmed)
            NotificationCenter.default.post(name: .taskListDidChange, object: listId)
        } catch {
            Task { @MainActor in await Task.yield(); alertMessage = "Failed to create task: \(error)"; showingAlert = true }
        }
    }

    func markSignedOut() {
        Task { @MainActor in await Task.yield(); taskLists = []; selectedListId = nil }
    }

    func markLoadedOnce() {
        Task { @MainActor in await Task.yield(); hasLoadedOnce = true }
    }
}
