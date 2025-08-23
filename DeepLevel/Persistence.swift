//
//  Persistence.swift
//  DeepLevel
//
//  Created by Jeffrey Kunzelman on 8/21/25.
//

import CoreData

/// Manages Core Data persistence with CloudKit integration for the DeepLevel app.
struct PersistenceController {
    /// Shared singleton instance for app-wide Core Data access.
    static let shared = PersistenceController()

    /// Preview instance with in-memory store and sample data for SwiftUI previews.
    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        for _ in 0..<10 {
            let newItem = GamePlayItem(context: viewContext)
            newItem.timestamp = Date()
        }
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    /// The CloudKit-enabled Core Data container managing the data model.
    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "DeepLevel")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { (_, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
