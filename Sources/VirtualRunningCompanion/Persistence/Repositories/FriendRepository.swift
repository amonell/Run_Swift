import Foundation
import Combine
import CoreData

// MARK: - Protocol

#if canImport(Combine)
public protocol FriendRepositoryProtocol {
    func save(_ friend: Friend, for userId: UUID) -> AnyPublisher<Friend, Error>
    func fetch(by id: UUID) -> AnyPublisher<Friend?, Error>
    func fetchAll(for userId: UUID) -> AnyPublisher<[Friend], Error>
    func fetchByStatus(_ status: FriendStatus, for userId: UUID) -> AnyPublisher<[Friend], Error>
    func delete(by id: UUID) -> AnyPublisher<Void, Error>
    func update(_ friend: Friend) -> AnyPublisher<Friend, Error>
}
#else
public protocol FriendRepositoryProtocol {
    func save(_ friend: Friend, for userId: UUID, completion: @escaping (Result<Friend, Error>) -> Void)
    func fetch(by id: UUID, completion: @escaping (Result<Friend?, Error>) -> Void)
    func fetchAll(for userId: UUID, completion: @escaping (Result<[Friend], Error>) -> Void)
    func fetchByStatus(_ status: FriendStatus, for userId: UUID, completion: @escaping (Result<[Friend], Error>) -> Void)
    func delete(by id: UUID, completion: @escaping (Result<Void, Error>) -> Void)
    func update(_ friend: Friend, completion: @escaping (Result<Friend, Error>) -> Void)
}
#endif

// MARK: - Implementation

public class FriendRepository: FriendRepositoryProtocol {
    
    private let persistenceController: PersistenceController
    
    public init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
    }
    
    public func save(_ friend: Friend, for userId: UUID) -> AnyPublisher<Friend, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.contextNotAvailable))
                return
            }
            
            self.persistenceController.performBackgroundTask { context in
                do {
                    // Find the user entity
                    let userFetchRequest: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
                    userFetchRequest.predicate = NSPredicate(format: "id == %@", userId as CVarArg)
                    
                    guard let userEntity = try context.fetch(userFetchRequest).first else {
                        DispatchQueue.main.async {
                            promise(.failure(RepositoryError.entityNotFound))
                        }
                        return
                    }
                    
                    // Check if friend already exists
                    let fetchRequest: NSFetchRequest<FriendEntity> = FriendEntity.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "id == %@ AND owner == %@", 
                                                       friend.id as CVarArg, userEntity)
                    
                    let existingFriends = try context.fetch(fetchRequest)
                    
                    let friendEntity: FriendEntity
                    if let existing = existingFriends.first {
                        friendEntity = existing
                        friendEntity.updateFromFriend(friend)
                    } else {
                        friendEntity = FriendEntity(context: context, friend: friend)
                        friendEntity.owner = userEntity
                    }
                    
                    try context.save()
                    
                    DispatchQueue.main.async {
                        if let savedFriend = friendEntity.toFriend() {
                            promise(.success(savedFriend))
                        } else {
                            promise(.failure(RepositoryError.saveFailed))
                        }
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
    
    public func fetch(by id: UUID) -> AnyPublisher<Friend?, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.contextNotAvailable))
                return
            }
            
            self.persistenceController.performBackgroundTask { context in
                do {
                    let fetchRequest: NSFetchRequest<FriendEntity> = FriendEntity.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                    fetchRequest.fetchLimit = 1
                    
                    let results = try context.fetch(fetchRequest)
                    let friend = results.first?.toFriend()
                    
                    DispatchQueue.main.async {
                        promise(.success(friend))
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
    
    public func fetchAll(for userId: UUID) -> AnyPublisher<[Friend], Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.contextNotAvailable))
                return
            }
            
            self.persistenceController.performBackgroundTask { context in
                do {
                    let fetchRequest: NSFetchRequest<FriendEntity> = FriendEntity.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "owner.id == %@", userId as CVarArg)
                    
                    let results = try context.fetch(fetchRequest)
                    let friends = results.compactMap { $0.toFriend() }
                    
                    DispatchQueue.main.async {
                        promise(.success(friends))
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
    
    public func fetchByStatus(_ status: FriendStatus, for userId: UUID) -> AnyPublisher<[Friend], Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.contextNotAvailable))
                return
            }
            
            self.persistenceController.performBackgroundTask { context in
                do {
                    let statusData = try JSONEncoder().encode(status)
                    
                    let fetchRequest: NSFetchRequest<FriendEntity> = FriendEntity.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "owner.id == %@ AND statusData == %@", 
                                                       userId as CVarArg, statusData as CVarArg)
                    
                    let results = try context.fetch(fetchRequest)
                    let friends = results.compactMap { $0.toFriend() }
                    
                    DispatchQueue.main.async {
                        promise(.success(friends))
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
    
    public func delete(by id: UUID) -> AnyPublisher<Void, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.contextNotAvailable))
                return
            }
            
            self.persistenceController.performBackgroundTask { context in
                do {
                    let fetchRequest: NSFetchRequest<FriendEntity> = FriendEntity.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                    
                    let results = try context.fetch(fetchRequest)
                    for entity in results {
                        context.delete(entity)
                    }
                    
                    try context.save()
                    
                    DispatchQueue.main.async {
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
    
    public func update(_ friend: Friend) -> AnyPublisher<Friend, Error> {
        // For update, we need to find the owner first
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.contextNotAvailable))
                return
            }
            
            self.persistenceController.performBackgroundTask { context in
                do {
                    let fetchRequest: NSFetchRequest<FriendEntity> = FriendEntity.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "id == %@", friend.id as CVarArg)
                    
                    guard let existingEntity = try context.fetch(fetchRequest).first else {
                        DispatchQueue.main.async {
                            promise(.failure(RepositoryError.entityNotFound))
                        }
                        return
                    }
                    
                    existingEntity.updateFromFriend(friend)
                    try context.save()
                    
                    DispatchQueue.main.async {
                        if let updatedFriend = existingEntity.toFriend() {
                            promise(.success(updatedFriend))
                        } else {
                            promise(.failure(RepositoryError.saveFailed))
                        }
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
}