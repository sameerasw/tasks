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
    @State private var showingSignInSheet = false
    @State private var showingAboutSheet = false
    @State private var newTaskTitle = ""
    @FocusState private var newTaskFieldFocused: Bool

    init(repository: TasksRepository) {
        _viewModel = StateObject(wrappedValue: ContentViewModel(repository: repository))
    }

    var body: some View {
        VStack(alignment: .center, spacing: 16) {

            if viewModel.loading { ProgressView() }

            if viewModel.taskLists.isEmpty {
                Text("└(=^‥^=)┐")
                    .foregroundColor(.secondary)
            } else {
                TaskListsView(viewModel: viewModel)
                    .environmentObject(auth)
            }
        }
        .frame(minWidth: 320, minHeight: 240)
    .toolbar { AppToolbar(viewModel: viewModel, auth: auth, showingNewTaskSheet: $showingNewTaskSheet, showAuthInfo: showAuthInfo, signIn: signIn, signOut: signOut, showAbout: { showingAboutSheet = true }) }
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
        .sheet(isPresented: $showingSignInSheet) {
            SignInView()
                .environmentObject(auth)
        }
        .sheet(isPresented: $showingAboutSheet) {
            AboutView {
                showingAboutSheet = false
            }
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
        // Present a sheet allowing the user to optionally provide a custom
        // client ID before initiating the sign-in flow.
        showingSignInSheet = true
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
