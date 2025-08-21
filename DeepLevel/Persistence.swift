//
//  Persistence.swift
//  DeepLevel
//
//  Created by Jeffrey Kunzelman on 8/21/25.
//

import CoreData

/// Manages Core Data persistence with CloudKit integration for the DeepLevel app.
///
/// Provides centralized access to the Core Data stack with CloudKit synchronization
/// capabilities. Includes both production and preview configurations for development
/// and testing scenarios.
///
/// - Since: 1.0.0
struct PersistenceController {
    /// Shared singleton instance for app-wide Core Data access.
    static let shared = PersistenceController()

    /// Preview instance with in-memory store and sample data for SwiftUI previews.
    ///
    /// Creates a temporary persistence controller with mock data for use in
    /// SwiftUI previews and testing scenarios without affecting persistent storage.
    ///
    /// - Returns: A configured persistence controller with sample data
    /// - Warning: This method creates sample data and uses fatalError for unhandled errors
    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        for _ in 0..<10 {
            let newItem = Item(context: viewContext)
            newItem.timestamp = Date()
        }
        do {
            try viewContext.save()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    /// The CloudKit-enabled Core Data container managing the data model.
    let container: NSPersistentCloudKitContainer

    /// Creates a new persistence controller with optional in-memory configuration.
    ///
    /// Initializes the Core Data stack with CloudKit integration. Can be configured
    /// for in-memory operation for testing purposes or persistent storage for
    /// production use.
    ///
    /// - Parameter inMemory: Whether to use in-memory storage instead of persistent files
    /// - Warning: Uses fatalError for unhandled Core Data loading errors
    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "DeepLevel")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
