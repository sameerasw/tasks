//
//  ContentView.swift
//  tasks
//
//  Created by Sameera Sandakelum on 2025-10-10.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var auth: AuthenticationManager
    @State private var taskLists: [TaskList] = []
    @State private var tasks: [TaskItem] = []
    @State private var loading = false
    private let tasksService = TasksService()
    @State private var alertMessage: String = ""
    @State private var showingAlert: Bool = false
    @State private var debugInfo: String = ""

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
                    TabView {
                        ForEach(taskLists) { list in
                            TaskListTab(list: list, tasksService: tasksService, auth: auth, alertMessage: $alertMessage, showingAlert: $showingAlert)
                                .tabItem {
                                    Text(list.title ?? "(no title)")
                                }
                                .tag(list.id)
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

                // Account menu: sign in / show auth info / sign out
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
    }

    private func loadTaskLists() {
        Task {
            loading = true
            do {
                let token = try await auth.getValidAccessToken()
                let lists = try await tasksService.listTaskLists(accessToken: token)
                DispatchQueue.main.async {
                    self.taskLists = lists
                    self.loading = false
                }
            } catch {
                let msg = "Failed to load task lists: \(error)"
                print(msg)
                loading = false
                alertMessage = msg
                showingAlert = true
            }
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
        tasks = []
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthenticationManager())
}

fileprivate struct TaskListTab: View {
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


fileprivate struct TaskCard: View {
    let task: TaskItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(task.title ?? "(no title)")
                    .font(.headline)
                Spacer()
                if task.status == "completed" {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }

            if let notes = task.notes, !notes.isEmpty {
                Text(notes)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }

            HStack {
                if let due = task.due, let date = ISO8601DateFormatter().date(from: due) {
                    Text(date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(NSColor.windowBackgroundColor)).shadow(radius: 1))
    }
}
