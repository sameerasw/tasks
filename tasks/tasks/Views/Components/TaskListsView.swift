import SwiftUI

struct TaskListsView: View {
    @ObservedObject var viewModel: ContentViewModel
    @EnvironmentObject var auth: AuthenticationManager

    var body: some View {
        let selectionBinding = Binding<String?>(get: { viewModel.selectedListId }, set: { newValue in
            Task { @MainActor in await Task.yield(); viewModel.selectedListId = newValue }
        })

        TabView(selection: selectionBinding) {
            ForEach(viewModel.taskLists) { list in
                TaskListTab(list: list, repository: viewModel.repository, auth: auth, alertMessage: $viewModel.alertMessage, showingAlert: $viewModel.showingAlert)
                    .tabItem { Text(list.title ?? "(no title)") }
                    .tag(Optional(list.id))
            }
        }
        .tabViewStyle(.automatic)
        .frame(minHeight: 240)
    }
}
