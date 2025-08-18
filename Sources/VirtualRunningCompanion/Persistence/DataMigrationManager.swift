import CoreData
import Foundation

/// Manages Core Data model migrations and versioning
public class DataMigrationManager {
    
    // MARK: - Properties
    
    private let modelName: String
    private let storeURL: URL
    
    // MARK: - Initialization
    
    public init(modelName: String = "VirtualRunningCompanion", storeURL: URL? = nil) {
        self.modelName = modelName
        self.storeURL = storeURL ?? DataMigrationManager.defaultStoreURL()
    }
    
    // MARK: - Migration Methods
    
    /// Check if migration is needed
    public func requiresMigration() -> Bool {
        guard let metadata = NSPersistentStoreCoordinator.metadata(at: storeURL) else {
            return false
        }
        
        return !currentModel().isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
    }
    
    /// Perform migration if needed
    public func migrateStoreIfNeeded() throws {
        guard requiresMigration() else {
            print("No migration required")
            return
        }
        
        print("Starting Core Data migration...")
        
        let sourceMetadata = NSPersistentStoreCoordinator.metadata(at: storeURL)!
        let sourceModel = try findSourceModel(for: sourceMetadata)
        let destinationModel = currentModel()
        
        try performMigration(from: sourceModel, to: destinationModel)
        
        print("Core Data migration completed successfully")
    }
    
    /// Get current model version
    public func currentModelVersion() -> String {
        return currentModel().versionIdentifiers.first ?? "Unknown"
    }
    
    // MARK: - Private Methods
    
    private func currentModel() -> NSManagedObjectModel {
        guard let modelURL = Bundle.main.url(forResource: modelName, withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Could not load current model")
        }
        return model
    }
    
    private func findSourceModel(for metadata: [String: Any]) -> NSManagedObjectModel {
        guard let modelURL = Bundle.main.url(forResource: modelName, withExtension: "momd") else {
            fatalError("Could not find model bundle")
        }
        
        guard let model = NSManagedObjectModel.mergedModel(from: [Bundle.main], 
                                                          forStoreMetadata: metadata) else {
            fatalError("Could not find source model for metadata")
        }
        
        return model
    }
    
    private func performMigration(from sourceModel: NSManagedObjectModel, 
                                to destinationModel: NSManagedObjectModel) throws {
        
        // Create mapping model
        guard let mappingModel = NSMappingModel(from: [Bundle.main], 
                                              forSourceModel: sourceModel, 
                                              destinationModel: destinationModel) else {
            throw MigrationError.mappingModelNotFound
        }
        
        // Create temporary store URL
        let tempStoreURL = storeURL.appendingPathExtension("temp")
        
        // Perform migration
        let migrationManager = NSMigrationManager(sourceModel: sourceModel, 
                                                destinationModel: destinationModel)
        
        try migrationManager.migrateStore(from: storeURL,
                                        sourceType: NSSQLiteStoreType,
                                        options: nil,
                                        with: mappingModel,
                                        toDestinationURL: tempStoreURL,
                                        destinationType: NSSQLiteStoreType,
                                        destinationOptions: nil)
        
        // Replace old store with migrated store
        let fileManager = FileManager.default
        
        // Remove old store files
        try removeStoreFiles(at: storeURL)
        
        // Move migrated store to original location
        try fileManager.moveItem(at: tempStoreURL, to: storeURL)
        
        // Move associated files
        let tempWALURL = tempStoreURL.appendingPathExtension("sqlite-wal")
        let tempSHMURL = tempStoreURL.appendingPathExtension("sqlite-shm")
        let walURL = storeURL.appendingPathExtension("sqlite-wal")
        let shmURL = storeURL.appendingPathExtension("sqlite-shm")
        
        if fileManager.fileExists(atPath: tempWALURL.path) {
            try fileManager.moveItem(at: tempWALURL, to: walURL)
        }
        
        if fileManager.fileExists(atPath: tempSHMURL.path) {
            try fileManager.moveItem(at: tempSHMURL, to: shmURL)
        }
    }
    
    private func removeStoreFiles(at storeURL: URL) throws {
        let fileManager = FileManager.default
        
        let storeFiles = [
            storeURL,
            storeURL.appendingPathExtension("sqlite-wal"),
            storeURL.appendingPathExtension("sqlite-shm")
        ]
        
        for file in storeFiles {
            if fileManager.fileExists(atPath: file.path) {
                try fileManager.removeItem(at: file)
            }
        }
    }
    
    private static func defaultStoreURL() -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, 
                                                         in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent("VirtualRunningCompanion.sqlite")
    }
}

// MARK: - Migration Errors

public enum MigrationError: Error, LocalizedError {
    case mappingModelNotFound
    case migrationFailed(String)
    case storeNotFound
    
    public var errorDescription: String? {
        switch self {
        case .mappingModelNotFound:
            return "Could not find mapping model for migration"
        case .migrationFailed(let reason):
            return "Migration failed: \(reason)"
        case .storeNotFound:
            return "Core Data store not found"
        }
    }
}

// MARK: - Migration Policy

/// Custom migration policy for complex data transformations
public class VirtualRunningCompanionMigrationPolicy: NSEntityMigrationPolicy {
    
    /// Example migration method for future use
    @objc func migrateUser(from sourceInstance: NSManagedObject, 
                          to destinationInstance: NSManagedObject, 
                          manager: NSMigrationManager) throws {
        
        // Copy basic attributes
        destinationInstance.setValue(sourceInstance.value(forKey: "id"), forKey: "id")
        destinationInstance.setValue(sourceInstance.value(forKey: "username"), forKey: "username")
        destinationInstance.setValue(sourceInstance.value(forKey: "email"), forKey: "email")
        destinationInstance.setValue(sourceInstance.value(forKey: "createdAt"), forKey: "createdAt")
        
        // Handle any complex transformations here
        if let profileImageURL = sourceInstance.value(forKey: "profileImageURL") as? String {
            // Example: migrate old URL format to new format
            let updatedURL = profileImageURL.replacingOccurrences(of: "http://", with: "https://")
            destinationInstance.setValue(updatedURL, forKey: "profileImageURL")
        }
    }
}