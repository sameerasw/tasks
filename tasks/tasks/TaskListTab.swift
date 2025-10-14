import SwiftUI

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
                .padding(.top)

            if tasks.isEmpty {
                Text("No tasks loaded")
                    .foregroundColor(.secondary)
            }

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(tasks) { t in
                        TaskCard(task: t)
                            .padding([.leading, .trailing])
                    }
                }
                .padding(.bottom)
            }
        }
        .padding()
        .onAppear {
            loadTasks(policy: hasLoadedOnce ? .staleOnly : .startup)
            hasLoadedOnce = true
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
}
