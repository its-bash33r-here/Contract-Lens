//
//  lawgptApp.swift
//  lawgpt
//
//  Created by Bash33r on 01/12/25.
//

import SwiftUI
import CoreData

@main
struct LawGPTApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    let persistenceController: PersistenceController
    private let themeManager: ThemeManager

    init() {
        print("🚀 Starting app initialization...")
        persistenceController = PersistenceController.shared
        themeManager = ThemeManager.shared
        print("✅ App initialization completed")
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(
                persistenceController: persistenceController,
                themeManager: themeManager
            )
        }
    }
}

// MARK: - App Root View

private struct AppRootView: View {
    let persistenceController: PersistenceController
    @ObservedObject var themeManager: ThemeManager

    var body: some View {
        NavigationStack {
            ContentView()
        }
        .environment(\.managedObjectContext, persistenceController.container.viewContext)
        .onAppear {
            let context = persistenceController.container.viewContext
            if context.persistentStoreCoordinator?.persistentStores.isEmpty == true {
                print("⚠️ Warning: Core Data stores haven't loaded yet")
            } else {
                print("✅ Core Data is ready")
            }
        }
        .environmentObject(themeManager)
        .environment(\.colorScheme, themeManager.currentTheme.colorScheme)
        .preferredColorScheme(themeManager.currentTheme.colorScheme)
    }
}
