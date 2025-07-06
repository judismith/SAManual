//
//  samanualApp.swift
//  samanual
//
//  Created by Judi Smith on 7/6/25.
//

import SwiftUI
import Firebase

@main
struct samanualApp: App {
    
    // MARK: - Dependencies
    private let diContainer: DIContainer
    
    // MARK: - Initialization
    init() {
        // Configure Firebase
        FirebaseApp.configure()
        
        // Initialize DI Container
        let container = DefaultDIContainer()
        container.registerServices()
        
        self.diContainer = container
        
        // Print debug info in development
        #if DEBUG
        print("🚀 SAManual App Initialized")
        container.printDebugInfo()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.diContainer, diContainer)
        }
    }
}

// MARK: - Environment Key for DI Container
private struct DIContainerKey: EnvironmentKey {
    static let defaultValue: DIContainer = DefaultDIContainer()
}

extension EnvironmentValues {
    var diContainer: DIContainer {
        get { self[DIContainerKey.self] }
        set { self[DIContainerKey.self] = newValue }
    }
}
