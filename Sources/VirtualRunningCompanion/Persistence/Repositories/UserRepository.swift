import CoreData
import Foundation
import Combine

// MARK: - Protocol

public protocol UserRepositoryProtocol {
    func save(_ user: User) -> AnyPublisher<User, Error>
    func fetch(by id: UUID) -> AnyPublisher<User?, Error>
    func fetchAll() -> AnyPublisher<[User], Error>
    func delete(by id: UUID) -> AnyPublisher<Void, Error>
    func update(_ user: User) -> AnyPublisher<User, Error>
    func searchUsers(query: String) -> AnyPublisher<[User], Error>
}

// MARK: - Implementation

public class UserRepository: UserRepositoryProtocol {
    
    private let persistenceController: PersistenceController
    
    public init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
    }
    
    public func save(_ user: User) -> AnyPublisher<User, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.contextNotAvailable))
                return
            }
            
            self.persistenceController.performBackgroundTask { context in
                do {
                    // Check if user already exists
                    let fetchRequest: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "id == %@", user.id as CVarArg)
                    
                    let existingUsers = try context.fetch(fetchRequest)
                    
                    let userEntity: UserEntity
                    if let existing = existingUsers.first {
                        userEntity = existing
                        userEntity.updateFromUser(user)
                    } else {
                        userEntity = UserEntity(context: context, user: user)
                    }
                    
                    try context.save()
                    
                    DispatchQueue.main.async {
                        promise(.success(userEntity.toUser()))
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
    
    public func fetch(by id: UUID) -> AnyPublisher<User?, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.contextNotAvailable))
                return
            }
            
            self.persistenceController.performBackgroundTask { context in
                do {
                    let fetchRequest: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                    fetchRequest.fetchLimit = 1
                    
                    let results = try context.fetch(fetchRequest)
                    let user = results.first?.toUser()
                    
                    DispatchQueue.main.async {
                        promise(.success(user))
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
    
    public func fetchAll() -> AnyPublisher<[User], Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.contextNotAvailable))
                return
            }
            
            self.persistenceController.performBackgroundTask { context in
                do {
                    let fetchRequest: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
                    let results = try context.fetch(fetchRequest)
                    let users = results.map { $0.toUser() }
                    
                    DispatchQueue.main.async {
                        promise(.success(users))
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
                    let fetchRequest: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
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
    
    public func update(_ user: User) -> AnyPublisher<User, Error> {
        return save(user) // Save handles both insert and update
    }
    
    public func searchUsers(query: String) -> AnyPublisher<[User], Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.contextNotAvailable))
                return
            }
            
            let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedQuery.isEmpty else {
                promise(.success([]))
                return
            }
            
            self.persistenceController.performBackgroundTask { context in
                do {
                    let fetchRequest: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
                    
                    // Search by username or email (case-insensitive)
                    let usernamePredicate = NSPredicate(format: "username CONTAINS[cd] %@", trimmedQuery)
                    let emailPredicate = NSPredicate(format: "email CONTAINS[cd] %@", trimmedQuery)
                    fetchRequest.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [usernamePredicate, emailPredicate])
                    
                    // Limit results to prevent performance issues
                    fetchRequest.fetchLimit = 50
                    
                    let results = try context.fetch(fetchRequest)
                    let users = results.map { $0.toUser() }
                    
                    DispatchQueue.main.async {
                        promise(.success(users))
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

// MARK: - Repository Errors

public enum RepositoryError: Error, LocalizedError {
    case contextNotAvailable
    case entityNotFound
    case saveFailed
    case fetchFailed
    case deleteFailed
    
    public var errorDescription: String? {
        switch self {
        case .contextNotAvailable:
            return "Core Data context is not available"
        case .entityNotFound:
            return "Entity not found"
        case .saveFailed:
            return "Failed to save data"
        case .fetchFailed:
            return "Failed to fetch data"
        case .deleteFailed:
            return "Failed to delete data"
        }
    }
}