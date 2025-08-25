import Foundation
import Combine
import CoreData

/// Core Data persistence controller for managing the local data stack
public class PersistenceController: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = PersistenceController()
    
    // MARK: - Preview Support
    
    public static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        
        // Add sample data for previews
        let sampleUser = UserEntity(context: context)
        sampleUser.id = UUID()
        sampleUser.username = "testuser"
        sampleUser.email = "test@example.com"
        sampleUser.createdAt = Date()
        
        do {
            try context.save()
        } catch {
            print("Preview data creation failed: \(error)")
        }
        
        return controller
    }()
    
    // MARK: - Core Data Stack
    
    public let container: NSPersistentContainer
    
    // MARK: - Initialization
    
    public init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "VirtualRunningCompanion")
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        // Configure persistent store
        container.persistentStoreDescriptions.first?.setOption(true as NSNumber, 
                                                               forKey: NSPersistentHistoryTrackingKey)
        container.persistentStoreDescriptions.first?.setOption(true as NSNumber, 
                                                               forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Core Data error: \(error), \(error.userInfo)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    // MARK: - Context Management
    
    public var viewContext: NSManagedObjectContext {
        return container.viewContext
    }
    
    public func newBackgroundContext() -> NSManagedObjectContext {
        return container.newBackgroundContext()
    }
    
    // MARK: - Save Operations
    
    public func save() {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Save error: \(error)")
            }
        }
    }
    
    public func saveContext(_ context: NSManagedObjectContext) {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Context save error: \(error)")
            }
        }
    }
    
    // MARK: - Batch Operations
    
    public func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        container.performBackgroundTask(block)
    }
    
    // MARK: - Data Migration Support
    
    public func migrateIfNeeded() {
        // This will be expanded when we add migration logic
        print("Checking for data migrations...")
    }
}