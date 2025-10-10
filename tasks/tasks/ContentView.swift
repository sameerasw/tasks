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

            if auth.isSignedIn {
                Text("Signed in as \(auth.email ?? "Unknown")")
                    .font(.headline)

                HStack(spacing: 12) {
                    Button("Load Task Lists") {
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

                    Button("Auth Info") {
                        var info = "isSignedIn=\(auth.isSignedIn)\n"
                        info += "email=\(auth.email ?? "(nil)")\n"
                        info += "hasRefresh=\(auth.hasRefreshToken())\n"
                        if let exp = auth.tokenExpiryDate() { info += "expiry=\(exp)\n" } else { info += "expiry=(nil)\n" }
                        debugInfo = info
                    }

                    Button("Sign Out") {
                        auth.signOut()
                        taskLists = []
                        tasks = []
                    }
                    .keyboardShortcut(.defaultAction)
                }

                if loading {
                    ProgressView()
                }

                List(taskLists) { list in
                    VStack(alignment: .leading) {
                        Text(list.title ?? "(no title)")
                            .font(.headline)
                        Text(list.id)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .onTapGesture {
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

                if !tasks.isEmpty {
                    Divider()
                    Text("Tasks")
                        .font(.headline)
                    List(tasks) { t in
                        VStack(alignment: .leading) {
                            Text(t.title ?? "(no title)")
                            if let notes = t.notes { Text(notes).font(.caption).foregroundColor(.secondary) }
                        }
                    }
                    .frame(height: 200)
                }

                if !debugInfo.isEmpty {
                    Divider()
                    Text("Debug")
                        .font(.headline)
                    Text(debugInfo)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                }
            } else {
                Text("Not signed in")

                Button("Sign in with Google") {
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
                .keyboardShortcut("s", modifiers: [.command])
            }
        }
        .padding()
        .frame(minWidth: 320, minHeight: 240)
        .alert("Error", isPresented: $showingAlert, actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            Text(alertMessage)
        })
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthenticationManager())
}
