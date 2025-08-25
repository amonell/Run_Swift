import Foundation
import Combine
import CoreData

// MARK: - Protocol

#if canImport(Combine)
public protocol RunSessionRepositoryProtocol {
    func save(_ runSession: RunSession) -> AnyPublisher<RunSession, Error>
    func fetch(by id: UUID) -> AnyPublisher<RunSession?, Error>
    func fetchAll() -> AnyPublisher<[RunSession], Error>
    func fetchByUser(userId: UUID) -> AnyPublisher<[RunSession], Error>
    func fetchRecent(limit: Int) -> AnyPublisher<[RunSession], Error>
    func delete(by id: UUID) -> AnyPublisher<Void, Error>
    func update(_ runSession: RunSession) -> AnyPublisher<RunSession, Error>
}
#else
public protocol RunSessionRepositoryProtocol {
    func save(_ runSession: RunSession, completion: @escaping (Result<RunSession, Error>) -> Void)
    func fetch(by id: UUID, completion: @escaping (Result<RunSession?, Error>) -> Void)
    func fetchAll(completion: @escaping (Result<[RunSession], Error>) -> Void)
    func fetchByUser(userId: UUID, completion: @escaping (Result<[RunSession], Error>) -> Void)
    func fetchRecent(limit: Int, completion: @escaping (Result<[RunSession], Error>) -> Void)
    func delete(by id: UUID, completion: @escaping (Result<Void, Error>) -> Void)
    func update(_ runSession: RunSession, completion: @escaping (Result<RunSession, Error>) -> Void)
}
#endif

// MARK: - Implementation

public class RunSessionRepository: RunSessionRepositoryProtocol {
    
    private let persistenceController: PersistenceController
    
    public init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
    }
    
    public func save(_ runSession: RunSession) -> AnyPublisher<RunSession, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.contextNotAvailable))
                return
            }
            
            self.persistenceController.performBackgroundTask { context in
                do {
                    // Check if run session already exists
                    let fetchRequest: NSFetchRequest<RunSessionEntity> = RunSessionEntity.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "id == %@", runSession.id as CVarArg)
                    
                    let existingSessions = try context.fetch(fetchRequest)
                    
                    let sessionEntity: RunSessionEntity
                    if let existing = existingSessions.first {
                        sessionEntity = existing
                        sessionEntity.updateFromRunSession(runSession)
                    } else {
                        sessionEntity = RunSessionEntity(context: context, runSession: runSession)
                    }
                    
                    try context.save()
                    
                    DispatchQueue.main.async {
                        promise(.success(sessionEntity.toRunSession()))
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
    
    public func fetch(by id: UUID) -> AnyPublisher<RunSession?, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.contextNotAvailable))
                return
            }
            
            self.persistenceController.performBackgroundTask { context in
                do {
                    let fetchRequest: NSFetchRequest<RunSessionEntity> = RunSessionEntity.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                    fetchRequest.fetchLimit = 1
                    
                    let results = try context.fetch(fetchRequest)
                    let runSession = results.first?.toRunSession()
                    
                    DispatchQueue.main.async {
                        promise(.success(runSession))
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
    
    public func fetchAll() -> AnyPublisher<[RunSession], Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.contextNotAvailable))
                return
            }
            
            self.persistenceController.performBackgroundTask { context in
                do {
                    let fetchRequest: NSFetchRequest<RunSessionEntity> = RunSessionEntity.fetchRequest()
                    let sortDescriptor = NSSortDescriptor(key: "startTime", ascending: false)
                    fetchRequest.sortDescriptors = [sortDescriptor]
                    
                    let results = try context.fetch(fetchRequest)
                    let runSessions = results.map { $0.toRunSession() }
                    
                    DispatchQueue.main.async {
                        promise(.success(runSessions))
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
    
    public func fetchByUser(userId: UUID) -> AnyPublisher<[RunSession], Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.contextNotAvailable))
                return
            }
            
            self.persistenceController.performBackgroundTask { context in
                do {
                    let fetchRequest: NSFetchRequest<RunSessionEntity> = RunSessionEntity.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "userId == %@", userId as CVarArg)
                    let sortDescriptor = NSSortDescriptor(key: "startTime", ascending: false)
                    fetchRequest.sortDescriptors = [sortDescriptor]
                    
                    let results = try context.fetch(fetchRequest)
                    let runSessions = results.map { $0.toRunSession() }
                    
                    DispatchQueue.main.async {
                        promise(.success(runSessions))
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
    
    public func fetchRecent(limit: Int) -> AnyPublisher<[RunSession], Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RepositoryError.contextNotAvailable))
                return
            }
            
            self.persistenceController.performBackgroundTask { context in
                do {
                    let fetchRequest: NSFetchRequest<RunSessionEntity> = RunSessionEntity.fetchRequest()
                    let sortDescriptor = NSSortDescriptor(key: "startTime", ascending: false)
                    fetchRequest.sortDescriptors = [sortDescriptor]
                    fetchRequest.fetchLimit = limit
                    
                    let results = try context.fetch(fetchRequest)
                    let runSessions = results.map { $0.toRunSession() }
                    
                    DispatchQueue.main.async {
                        promise(.success(runSessions))
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
                    let fetchRequest: NSFetchRequest<RunSessionEntity> = RunSessionEntity.fetchRequest()
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
    
    public func update(_ runSession: RunSession) -> AnyPublisher<RunSession, Error> {
        return save(runSession) // Save handles both insert and update
    }
}