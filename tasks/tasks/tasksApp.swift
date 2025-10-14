//
//  tasksApp.swift
//  tasks
//
//  Created by Sameera Sandakelum on 2025-10-10.
//

import SwiftUI
import Combine

@main
struct tasksApp: App {
    @StateObject private var auth = AuthenticationManager()
    @StateObject private var dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            ContentView(repository: dependencies.repository)
                .environmentObject(auth)
        }
    }
}

private final class AppDependencies: ObservableObject {
    let repository = TasksRepository()
}
