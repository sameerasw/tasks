import SwiftUI

struct TaskListTab: View {
    let list: TaskList
    let tasksService: TasksService
    @ObservedObject var auth: AuthenticationManager
    @State private var tasks: [TaskItem] = []
    @Binding var alertMessage: String
    @Binding var showingAlert: Bool

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
            Task {
                do {
                    let token = try await auth.getValidAccessToken()
                    let items = try await tasksService.listTasks(accessToken: token, tasklistId: list.id)
                    DispatchQueue.main.async {
                        self.tasks = items
                    }
                } catch {
                    let msg = "Failed to load tasks: \(error)"
                    print(msg)
                    alertMessage = msg
                    showingAlert = true
                }
            }
        }
    }
}
