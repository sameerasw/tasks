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
    @StateObject private var viewModel: ContentViewModel
    @State private var refreshTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    @State private var showingNewTaskSheet = false
    @State private var newTaskTitle = ""
    @FocusState private var newTaskFieldFocused: Bool

    init(repository: TasksRepository) {
        _viewModel = StateObject(wrappedValue: ContentViewModel(repository: repository))
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .resizable()
                .frame(width: 64, height: 64)
                .foregroundColor(.accentColor)

            if viewModel.loading {
                ProgressView()
            }

            if viewModel.taskLists.isEmpty {
                Text("No task lists loaded")
                    .foregroundColor(.secondary)
            } else {
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

            if !viewModel.debugInfo.isEmpty {
                Divider()
                Text("Debug")
                    .font(.headline)
                Text(viewModel.debugInfo)
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
                Button { Task { viewModel.loading = true; await viewModel.refreshTaskLists(policy: .force, auth: auth) } } label: { Label("Load Task Lists", systemImage: "repeat") }

                Button { showingNewTaskSheet = true } label: { Label("New Task", systemImage: "plus") }
                    .disabled(viewModel.selectedListId == nil || !auth.isSignedIn)

                Menu {
                    if auth.isSignedIn {
                        Button("Auth Info") { showAuthInfo() }
                        Button("Sign Out") { signOut() }
                    } else {
                        Button("Sign in with Google") { signIn() }
                    }
                } label: {
                    if auth.isSignedIn { Label(auth.email ?? "Account", systemImage: "person.crop.circle") }
                    else { Label("Account", systemImage: "person.crop.circle") }
                }
            }
        }
        .alert("Error", isPresented: $viewModel.showingAlert, actions: { Button("OK", role: .cancel) {} }, message: { Text(viewModel.alertMessage) })
        .task {
            guard !viewModel.hasLoadedOnce else { return }
            viewModel.markLoadedOnce()
            await viewModel.loadCachedTaskLists()
            await viewModel.refreshTaskLists(policy: .startup, auth: auth)
        }
        .onReceive(refreshTimer) { _ in
            Task { await refreshIfNeededForTimer() }
        }
        .onChange(of: auth.isSignedIn) { _, current in
            if current {
                Task { await viewModel.loadCachedTaskLists(); await viewModel.refreshTaskLists(policy: .startup, auth: auth) }
            } else {
                viewModel.markSignedOut()
            }
        }
        .sheet(isPresented: $showingNewTaskSheet) {
            NewTaskSheet(title: $newTaskTitle, isFocused: $newTaskFieldFocused, onCreate: { title in
                Task { await viewModel.createTask(title: title, auth: auth); showingNewTaskSheet = false; newTaskTitle = "" }
            }, onCancel: {
                showingNewTaskSheet = false
                newTaskTitle = ""
            })
            .onDisappear { newTaskTitle = ""; newTaskFieldFocused = false }
        }
    }

    private func showAuthInfo() {
        var info = "isSignedIn=\(auth.isSignedIn)\n"
        info += "email=\(auth.email ?? "(nil)")\n"
        info += "hasRefresh=\(auth.hasRefreshToken())\n"
        if let exp = auth.tokenExpiryDate() { info += "expiry=\(exp)\n" } else { info += "expiry=(nil)\n" }
        viewModel.debugInfo = info
    }

    private func signIn() {
        Task {
            do { try await auth.signIn() }
            catch { Task { @MainActor in await Task.yield(); viewModel.alertMessage = "Sign in failed: \(error)"; viewModel.showingAlert = true } }
        }
    }

    private func signOut() {
        auth.signOut()
        viewModel.markSignedOut()
        Task { await viewModel.repository.clearAll() }
    }

    private func refreshIfNeededForTimer() async {
        let signedIn = auth.isSignedIn
        guard signedIn else { return }

        guard !viewModel.loading else { return }
        guard !viewModel.refreshInProgress else { return }

        let lastRefresh = await viewModel.repository.lastTaskListRefreshDate()
        let interval = viewModel.repository.refreshInterval

        let shouldRefresh: Bool
        if let lastRefresh { shouldRefresh = Date().timeIntervalSince(lastRefresh) >= interval } else { shouldRefresh = true }

        guard shouldRefresh else { return }

        await viewModel.refreshTaskLists(policy: .staleOnly, auth: auth)
    }
}

#Preview {
    ContentView(repository: TasksRepository())
        .environmentObject(AuthenticationManager())
}
