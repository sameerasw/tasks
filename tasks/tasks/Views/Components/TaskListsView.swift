import SwiftUI

struct TaskListsView: View {
    @ObservedObject var viewModel: ContentViewModel
    @EnvironmentObject var auth: AuthenticationManager

    var body: some View {
        let selectionBinding = Binding<String?>(get: { viewModel.selectedListId }, set: { newValue in
            Task { @MainActor in await Task.yield(); viewModel.selectedListId = newValue }
        })

        NavigationSplitView {
            List(selection: selectionBinding) {
                ForEach(viewModel.taskLists) { list in
                    Text(list.title ?? "(no title)")
                        .tag(list.id)
                        .onTapGesture {
                            Task { @MainActor in await Task.yield(); viewModel.selectedListId = list.id }
                        }
                }
            }
            .listStyle(.sidebar)
        } detail: {
            if let selectedId = viewModel.selectedListId, let list = viewModel.taskLists.first(where: { $0.id == selectedId }) {
                TaskListTab(list: list, repository: viewModel.repository, auth: auth, alertMessage: $viewModel.alertMessage, showingAlert: $viewModel.showingAlert)
                    .id(list.id)
            } else if let first = viewModel.taskLists.first {
                // fallback to first list when selection is nil
                TaskListTab(list: first, repository: viewModel.repository, auth: auth, alertMessage: $viewModel.alertMessage, showingAlert: $viewModel.showingAlert)
                    .id(first.id)
            } else {
                Text("No lists available").foregroundColor(.secondary)
            }
        }
        .frame(minHeight: 240)
    }
}
