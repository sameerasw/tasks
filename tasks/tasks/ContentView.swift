//
//  ContentView.swift
//  tasks
//
//  Created by Sameera Sandakelum on 2025-10-10.
//

import SwiftUI
import Combine

struct ContentView: View {
    @EnvironmentObject var auth: AuthenticationManager
    let repository: TasksRepository

    @State private var taskLists: [TaskList] = []
    @State private var selectedListId: String? = nil
    @State private var loading = false
    @State private var alertMessage: String = ""
    @State private var showingAlert: Bool = false
    @State private var debugInfo: String = ""
    @State private var hasLoadedOnce = false
    @State private var refreshTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    @State private var refreshInProgress = false
    @State private var showingNewTaskSheet = false
    @State private var newTaskTitle = ""
    @FocusState private var newTaskFieldFocused: Bool

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .resizable()
                .frame(width: 64, height: 64)
                .foregroundColor(.accentColor)

            if loading {
                ProgressView()
            }

            if taskLists.isEmpty {
                Text("No task lists loaded")
                    .foregroundColor(.secondary)
            } else {
                TabView(selection: $selectedListId) {
                    ForEach(taskLists) { list in
                        TaskListTab(list: list, repository: repository, auth: auth, alertMessage: $alertMessage, showingAlert: $showingAlert)
                            .tabItem {
                                Text(list.title ?? "(no title)")
                            }
                            .tag(Optional(list.id))
                    }
                }
                .tabViewStyle(.automatic)
                .frame(minHeight: 240)
            }

            if !debugInfo.isEmpty {
                Divider()
                Text("Debug")
                    .font(.headline)
                Text(debugInfo)
                    .font(.system(.body, design: .monospaced))
                    .padding()
            } else {
                Text("Not signed in")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(minWidth: 320, minHeight: 240)
        .toolbar {
            ToolbarItemGroup {
                Button {
                    loadTaskLists()
                } label: {
                    Label("Load Task Lists", systemImage: "tray.full")
                }

                Button {
                    showingNewTaskSheet = true
                } label: {
                    Label("New Task", systemImage: "plus")
                }
                .disabled(selectedListId == nil || !auth.isSignedIn)

                Menu {
                    if auth.isSignedIn {
                        Button("Auth Info") {
                            showAuthInfo()
                        }
                        Button("Sign Out") {
                            signOut()
                        }
                    } else {
                        Button("Sign in with Google") {
                            signIn()
                        }
                    }
                } label: {
                    if auth.isSignedIn {
                        Label(auth.email ?? "Account", systemImage: "person.crop.circle")
                    } else {
                        Label("Account", systemImage: "person.crop.circle")
                    }
                }
            }
        }
        .alert("Error", isPresented: $showingAlert, actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            Text(alertMessage)
        })
        .task {
            guard !hasLoadedOnce else { return }
            await MainActor.run { hasLoadedOnce = true }
            await loadCachedTaskLists()
            await refreshTaskLists(policy: .startup)
        }
        .onReceive(refreshTimer) { _ in
            Task {
                await refreshIfNeededForTimer()
            }
        }
        .onChange(of: auth.isSignedIn) { previous, current in
            let signedIn = current
            if signedIn {
                Task {
                    await loadCachedTaskLists()
                    await refreshTaskLists(policy: .startup)
                }
            } else {
                taskLists = []
                selectedListId = nil
            }
        }
        .sheet(isPresented: $showingNewTaskSheet) {
            NewTaskSheet(title: $newTaskTitle, isFocused: $newTaskFieldFocused, onCreate: { title in
                createTask(with: title)
            }, onCancel: {
                showingNewTaskSheet = false
                newTaskTitle = ""
            })
            .onDisappear {
                newTaskTitle = ""
                newTaskFieldFocused = false
            }
        }
    }

    private func loadTaskLists() {
        Task {
            await MainActor.run { loading = true }
            await refreshTaskLists(policy: .force)
        }
    }

    private func showAuthInfo() {
        var info = "isSignedIn=\(auth.isSignedIn)\n"
        info += "email=\(auth.email ?? "(nil)")\n"
        info += "hasRefresh=\(auth.hasRefreshToken())\n"
        if let exp = auth.tokenExpiryDate() { info += "expiry=\(exp)\n" } else { info += "expiry=(nil)\n" }
        debugInfo = info
    }

    private func signIn() {
        Task {
            do {
                try await auth.signIn()
            } catch {
                let msg = "Sign in failed: \(error)"
                print(msg)
                alertMessage = msg
                showingAlert = true
            }
        }
    }

    private func signOut() {
        auth.signOut()
        taskLists = []
        selectedListId = nil
        Task {
            await repository.clearAll()
        }
    }

    private func loadCachedTaskLists() async {
        let cached = await repository.cachedTaskLists()
        await MainActor.run {
            self.taskLists = cached
            if selectedListId == nil {
                self.selectedListId = cached.first?.id
            } else if let current = selectedListId, !cached.contains(where: { $0.id == current }) {
                self.selectedListId = cached.first?.id
            }
        }
    }

    private func refreshTaskLists(policy: RefreshPolicy) async {
        await MainActor.run { refreshInProgress = true }
        let signedIn = await MainActor.run { auth.isSignedIn }
        guard signedIn else {
            await MainActor.run {
                loading = false
                refreshInProgress = false
            }
            return
        }

        do {
            let previousStamp = await repository.lastTaskListRefreshDate()
            let token = try await auth.getValidAccessToken()
            let lists = try await repository.loadTaskLists(accessToken: token, policy: policy)
            let latestStamp = await repository.lastTaskListRefreshDate()
            let didRefresh = latestStamp != previousStamp || previousStamp == nil

            await MainActor.run {
                self.taskLists = lists
                self.loading = false
                self.refreshInProgress = false
                if let current = selectedListId, lists.contains(where: { $0.id == current }) {
                    // keep selection
                } else {
                    self.selectedListId = lists.first?.id
                }
            }

            if didRefresh || policy == .startup || policy == .force {
                let repo = repository
                Task.detached(priority: .background) {
                    for list in lists {
                        do {
                            _ = try await repo.loadTasks(accessToken: token, listId: list.id, policy: .startup)
                        } catch {
                            print("[Cache] failed to warm tasks for list \(list.id): \(error)")
                        }
                    }
                }
            }
        } catch {
            let message = "Failed to load task lists: \(error)"
            print(message)
            await MainActor.run {
                loading = false
                alertMessage = message
                showingAlert = true
                refreshInProgress = false
            }
        }
    }

    private func refreshIfNeededForTimer() async {
        let signedIn = await MainActor.run { auth.isSignedIn }
        guard signedIn else { return }

        let currentlyLoading = await MainActor.run { loading }
        guard !currentlyLoading else { return }

        let running = await MainActor.run { refreshInProgress }
        guard !running else { return }

        let lastRefresh = await repository.lastTaskListRefreshDate()
        let interval = repository.refreshInterval

        let shouldRefresh: Bool
        if let lastRefresh {
            shouldRefresh = Date().timeIntervalSince(lastRefresh) >= interval
        } else {
            shouldRefresh = true
        }

        guard shouldRefresh else { return }

        await refreshTaskLists(policy: .staleOnly)
    }

    private func createTask(with title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let listId = selectedListId else { return }

        Task {
            do {
                let token = try await auth.getValidAccessToken()
                _ = try await repository.createTask(accessToken: token, listId: listId, title: trimmed)
                await MainActor.run {
                    NotificationCenter.default.post(name: .taskListDidChange, object: listId)
                    showingNewTaskSheet = false
                    newTaskTitle = ""
                }
            } catch {
                let message = "Failed to create task: \(error)"
                print(message)
                await MainActor.run {
                    alertMessage = message
                    showingAlert = true
                }
            }
        }
    }
}

#Preview {
    ContentView(repository: TasksRepository())
        .environmentObject(AuthenticationManager())
}

private struct NewTaskSheet: View {
    @Binding var title: String
    let isFocused: FocusState<Bool>.Binding
    let onCreate: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Task")
                .font(.headline)

            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)
                .focused(isFocused)
                .onAppear {
                    DispatchQueue.main.async {
                        isFocused.wrappedValue = true
                    }
                }

            HStack {
                Spacer()
                Button("Cancel") {
                    onCancel()
                }
                Button("Create") {
                    onCreate(title)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 320)
    }
}
