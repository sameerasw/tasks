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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(auth)
        }
    }
}
