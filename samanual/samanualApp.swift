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
    let persistenceController = PersistenceController.shared
    
    init() {
            FirebaseApp.configure()
        }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
