import SwiftUI

struct AppToolbar: ToolbarContent {
    let viewModel: ContentViewModel
    let auth: AuthenticationManager
    @Binding var showingNewTaskSheet: Bool
    let showAuthInfo: () -> Void
    let signIn: () -> Void
    let signOut: () -> Void
    let showAbout: () -> Void

    var body: some ToolbarContent {
        ToolbarItemGroup {


            if viewModel.loading {
                ProgressView()
                    .controlSize(.small)
                    .padding(.horizontal, 8)
            } else {
                Button { Task { viewModel.loading = true; await viewModel.refreshTaskLists(policy: .force, auth: auth) } } label: { Label("Load Task Lists", systemImage: "repeat") }
            }

            Button { showingNewTaskSheet = true } label: { Label("New Task", systemImage: "plus") }
                .disabled(viewModel.selectedListId == nil || !auth.isSignedIn)

            Menu {
                if auth.isSignedIn {
                    Button("Sign Out") { signOut() }
                } else {
                    Button("Sign in with Google") { signIn() }
                }

                Divider()
                Button("About") { showAbout() }
            } label: {
                if auth.isSignedIn { Label(auth.email ?? "Account", systemImage: "person.crop.circle") }
                else { Label("Account", systemImage: "person.crop.circle") }
            }
        }
    }
}
