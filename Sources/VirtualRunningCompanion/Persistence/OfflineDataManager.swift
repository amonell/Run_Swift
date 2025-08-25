import Foundation
import Combine
import CoreData

/// Manages offline data caching and synchronization
public class OfflineDataManager: ObservableObject {
    
    // MARK: - Properties
    
    private let persistenceController: PersistenceController
    private let userRepository: UserRepositoryProtocol
    private let runSessionRepository: RunSessionRepositoryProtocol
    private let friendRepository: FriendRepositoryProtocol
    
    @Published public var isOfflineMode: Bool = false
    @Published public var pendingSyncCount: Int = 0
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    public init(persistenceController: PersistenceController = .shared,
                userRepository: UserRepositoryProtocol? = nil,
                runSessionRepository: RunSessionRepositoryProtocol? = nil,
                friendRepository: FriendRepositoryProtocol? = nil) {
        self.persistenceController = persistenceController
        self.userRepository = userRepository ?? UserRepository(persistenceController: persistenceController)
        self.runSessionRepository = runSessionRepository ?? RunSessionRepository(persistenceController: persistenceController)
        self.friendRepository = friendRepository ?? FriendRepository(persistenceController: persistenceController)
        
        setupNetworkMonitoring()
        updatePendingSyncCount()
    }
    
    // MARK: - Offline Data Operations
    
    /// Cache run session data for offline access
    public func cacheRunSession(_ runSession: RunSession) -> AnyPublisher<Void, Error> {
        return runSessionRepository.save(runSession)
            .map { _ in () }
            .handleEvents(receiveOutput: { [weak self] _ in
                self?.updatePendingSyncCount()
            })
            .eraseToAnyPublisher()
    }
    
    /// Cache user data for offline access
    public func cacheUser(_ user: User) -> AnyPublisher<Void, Error> {
        return userRepository.save(user)
            .map { _ in () }
            .handleEvents(receiveOutput: { [weak self] _ in
                self?.updatePendingSyncCount()
            })
            .eraseToAnyPublisher()
    }
    
    /// Cache friend data for offline access
    public func cacheFriend(_ friend: Friend, for userId: UUID) -> AnyPublisher<Void, Error> {
        return friendRepository.save(friend, for: userId)
            .map { _ in () }
            .handleEvents(receiveOutput: { [weak self] _ in
                self?.updatePendingSyncCount()
            })
            .eraseToAnyPublisher()
    }
    
    /// Get cached run sessions for offline viewing
    public func getCachedRunSessions(for userId: UUID) -> AnyPublisher<[RunSession], Error> {
        return runSessionRepository.fetchByUser(userId: userId)
    }
    
    /// Get cached friends for offline viewing
    public func getCachedFriends(for userId: UUID) -> AnyPublisher<[Friend], Error> {
        return friendRepository.fetchAll(for: userId)
    }
    
    /// Get cached user data
    public func getCachedUser(by id: UUID) -> AnyPublisher<User?, Error> {
        return userRepository.fetch(by: id)
    }
    
    // MARK: - Sync Operations
    
    /// Mark data as needing sync when connectivity returns
    public func markForSync(_ item: SyncableItem) {
        persistenceController.performBackgroundTask { [weak self] context in
            let syncEntity = SyncQueueEntity(context: context)
            syncEntity.id = UUID()
            syncEntity.itemId = item.id
            syncEntity.itemType = item.type.rawValue
            syncEntity.operation = item.operation.rawValue
            syncEntity.createdAt = Date()
            syncEntity.data = item.data
            
            do {
                try context.save()
                DispatchQueue.main.async {
                    self?.updatePendingSyncCount()
                }
            } catch {
                print("Failed to mark item for sync: \(error)")
            }
        }
    }
    
    /// Process pending sync items when connectivity is restored
    public func processPendingSync() -> AnyPublisher<Void, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(OfflineDataError.managerNotAvailable))
                return
            }
            
            self.persistenceController.performBackgroundTask { context in
                do {
                    let fetchRequest: NSFetchRequest<SyncQueueEntity> = SyncQueueEntity.fetchRequest()
                    let sortDescriptor = NSSortDescriptor(key: "createdAt", ascending: true)
                    fetchRequest.sortDescriptors = [sortDescriptor]
                    
                    let pendingItems = try context.fetch(fetchRequest)
                    
                    // Process each item (this would integrate with network sync service)
                    for item in pendingItems {
                        // Here you would call your network sync service
                        // For now, we'll just remove the item from queue
                        context.delete(item)
                    }
                    
                    try context.save()
                    
                    DispatchQueue.main.async {
                        self.updatePendingSyncCount()
                        promise(.success(()))
                    }
                } catch {
                    DispatchQueue.main.async {
                        promise(.failure(error))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// Clear all cached data (useful for logout or data reset)
    public func clearCache() -> AnyPublisher<Void, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(OfflineDataError.managerNotAvailable))
                return
            }
            
            self.persistenceController.performBackgroundTask { context in
                do {
                    // Clear all entities
                    let userRequest: NSFetchRequest<NSFetchRequestResult> = UserEntity.fetchRequest()
                    let deleteUsersRequest = NSBatchDeleteRequest(fetchRequest: userRequest)
                    try context.execute(deleteUsersRequest)
                    
                    let sessionRequest: NSFetchRequest<NSFetchRequestResult> = RunSessionEntity.fetchRequest()
                    let deleteSessionsRequest = NSBatchDeleteRequest(fetchRequest: sessionRequest)
                    try context.execute(deleteSessionsRequest)
                    
                    let friendRequest: NSFetchRequest<NSFetchRequestResult> = FriendEntity.fetchRequest()
                    let deleteFriendsRequest = NSBatchDeleteRequest(fetchRequest: friendRequest)
                    try context.execute(deleteFriendsRequest)
                    
                    let syncRequest: NSFetchRequest<NSFetchRequestResult> = SyncQueueEntity.fetchRequest()
                    let deleteSyncRequest = NSBatchDeleteRequest(fetchRequest: syncRequest)
                    try context.execute(deleteSyncRequest)
                    
                    try context.save()
                    
                    DispatchQueue.main.async {
                        self.updatePendingSyncCount()
                        promise(.success(()))
                    }
                } catch {
                    DispatchQueue.main.async {
                        promise(.failure(error))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Private Methods
    
    private func setupNetworkMonitoring() {
        // This would integrate with network reachability monitoring
        // For now, we'll simulate network state changes
        Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                // Check network connectivity and update offline mode
                self?.checkNetworkConnectivity()
            }
            .store(in: &cancellables)
    }
    
    private func checkNetworkConnectivity() {
        // This would use actual network reachability checking
        // For now, we'll assume we're online
        let wasOffline = isOfflineMode
        isOfflineMode = false // Simulate being online
        
        if wasOffline && !isOfflineMode {
            // We've come back online, process pending sync
            processPendingSync()
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            print("Sync processing failed: \(error)")
                        }
                    },
                    receiveValue: { _ in
                        print("Pending sync processed successfully")
                    }
                )
                .store(in: &cancellables)
        }
    }
    
    private func updatePendingSyncCount() {
        persistenceController.performBackgroundTask { [weak self] context in
            do {
                let fetchRequest: NSFetchRequest<SyncQueueEntity> = SyncQueueEntity.fetchRequest()
                let count = try context.count(for: fetchRequest)
                
                DispatchQueue.main.async {
                    self?.pendingSyncCount = count
                }
            } catch {
                print("Failed to update pending sync count: \(error)")
            }
        }
    }
}

// MARK: - Supporting Types

public struct SyncableItem {
    let id: UUID
    let type: SyncableItemType
    let operation: SyncOperation
    let data: Data?
}

public enum SyncableItemType: String, CaseIterable {
    case user = "user"
    case runSession = "runSession"
    case friend = "friend"
}

public enum SyncOperation: String, CaseIterable {
    case create = "create"
    case update = "update"
    case delete = "delete"
}

public enum OfflineDataError: Error, LocalizedError {
    case managerNotAvailable
    case syncFailed
    case cacheCorrupted
    
    public var errorDescription: String? {
        switch self {
        case .managerNotAvailable:
            return "Offline data manager is not available"
        case .syncFailed:
            return "Failed to sync offline data"
        case .cacheCorrupted:
            return "Cached data is corrupted"
        }
    }
}

// MARK: - Sync Queue Entity

@objc(SyncQueueEntity)
public class SyncQueueEntity: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var itemId: UUID?
    @NSManaged public var itemType: String?
    @NSManaged public var operation: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var data: Data?
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<SyncQueueEntity> {
        return NSFetchRequest<SyncQueueEntity>(entityName: "SyncQueueEntity")
    }
}