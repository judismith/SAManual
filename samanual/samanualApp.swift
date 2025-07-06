//
//  samanualApp.swift
//  samanual
//
//  Created by Judi Smith on 7/6/25.
//

import SwiftUI

@main
struct samanualApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
