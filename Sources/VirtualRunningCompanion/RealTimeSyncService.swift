import Foundation
import Combine
#if canImport(CoreLocation)
import CoreLocation
#endif

// MARK: - Type Alias for compatibility
typealias LocationCoordinate = LocationCoordinate2D

// MARK: - Friend Run Update Model
public struct FriendRunUpdate: Codable, Identifiable {
    public let id = UUID()
    let userId: String
    let pace: Double
    let location: LocationCoordinate2D
    let timestamp: Date
    let status: String
    
    private enum CodingKeys: String, CodingKey {
        case userId, pace, location, timestamp, status
    }
}

// MARK: - Session Info Model
public struct SessionInfo: Codable {
    let sessionId: String
    let participants: [String]
    let status: String
    let createdAt: Date
}

// MARK: - Real-Time Sync Service Protocol
public protocol RealTimeSyncServiceProtocol {
    var friendUpdates: AnyPublisher<[FriendRunUpdate], Never> { get }
    var connectionStatus: AnyPublisher<ConnectionStatus, Never> { get }
    var sessionInfo: AnyPublisher<SessionInfo?, Never> { get }
    
    func joinSession(sessionId: String, userId: String, friends: [User]) -> AnyPublisher<Void, Error>
    func leaveSession() -> AnyPublisher<Void, Error>
    func sendPaceUpdate(pace: Double, location: LocationCoordinate2D) -> AnyPublisher<Void, Error>
    func isInSession() -> Bool
    func getCurrentSessionId() -> String?
}

// MARK: - Real-Time Sync Service Implementation
public class RealTimeSyncService: RealTimeSyncServiceProtocol {
    private let webSocketClient: WebSocketClientProtocol
    private let serverURL: URL
    
    private let friendUpdatesSubject = CurrentValueSubject<[FriendRunUpdate], Never>([])
    private let sessionInfoSubject = CurrentValueSubject<SessionInfo?, Never>(nil)
    
    private var cancellables = Set<AnyCancellable>()
    private var currentUserId: String?
    private var currentSessionId: String?
    
    // MARK: - Published Properties
    
    var friendUpdates: AnyPublisher<[FriendRunUpdate], Never> {
        friendUpdatesSubject.eraseToAnyPublisher()
    }
    
    var connectionStatus: AnyPublisher<ConnectionStatus, Never> {
        webSocketClient.connectionStatus
    }
    
    var sessionInfo: AnyPublisher<SessionInfo?, Never> {
        sessionInfoSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    
    public init(webSocketClient: WebSocketClientProtocol, serverURL: URL) {
        self.webSocketClient = webSocketClient
        self.serverURL = serverURL
        
        setupMessageHandling()
    }
    
    public convenience init(serverURL: URL) {
        self.init(webSocketClient: WebSocketClient(), serverURL: serverURL)
    }
    
    // MARK: - Public Methods
    
    public func joinSession(sessionId: String, userId: String, friends: [User]) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(SyncServiceError.serviceUnavailable))
                return
            }
            
            // Connect to WebSocket if not already connected
            if !self.webSocketClient.isConnected() {
                self.webSocketClient.connect(to: self.serverURL)
            }
            
            // Wait for connection before joining session
            self.connectionStatus
                .filter { $0 == .connected }
                .first()
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            promise(.failure(error))
                        }
                    },
                    receiveValue: { [weak self] _ in
                        self?.performJoinSession(sessionId: sessionId, userId: userId, friends: friends, promise: promise)
                    }
                )
                .store(in: &self.cancellables)
        }
        .eraseToAnyPublisher()
    }
    
    public func leaveSession() -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { [weak self] promise in
            guard let self = self,
                  let sessionId = self.currentSessionId,
                  let userId = self.currentUserId else {
                promise(.failure(SyncServiceError.notInSession))
                return
            }
            
            let leaveData = LeaveSessionData(sessionId: sessionId, userId: userId)
            
            do {
                let data = try JSONEncoder().encode(leaveData)
                let message = WebSocketMessage(
                    type: .leaveSession,
                    data: data,
                    timestamp: Date()
                )
                
                self.webSocketClient.send(message: message)
                
                // Clean up local state
                self.currentSessionId = nil
                self.currentUserId = nil
                self.sessionInfoSubject.send(nil)
                self.friendUpdatesSubject.send([])
                
                promise(.success(()))
            } catch {
                promise(.failure(SyncServiceError.encodingError(error)))
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func sendPaceUpdate(pace: Double, location: CLLocation) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { [weak self] promise in
            guard let self = self,
                  let sessionId = self.currentSessionId,
                  let userId = self.currentUserId else {
                promise(.failure(SyncServiceError.notInSession))
                return
            }
            
            guard self.webSocketClient.isConnected() else {
                promise(.failure(SyncServiceError.notConnected))
                return
            }
            
            let locationCoordinate = LocationCoordinate2D(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
            
            let paceData = PaceUpdateData(
                userId: userId,
                sessionId: sessionId,
                pace: pace,
                location: locationCoordinate,
                timestamp: Date()
            )
            
            do {
                let data = try JSONEncoder().encode(paceData)
                let message = WebSocketMessage(
                    type: .paceUpdate,
                    data: data,
                    timestamp: Date()
                )
                
                self.webSocketClient.send(message: message)
                promise(.success(()))
            } catch {
                promise(.failure(SyncServiceError.encodingError(error)))
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func isInSession() -> Bool {
        return currentSessionId != nil
    }
    
    public func getCurrentSessionId() -> String? {
        return currentSessionId
    }
    
    // MARK: - Private Methods
    
    private func setupMessageHandling() {
        webSocketClient.messageReceived
            .sink { [weak self] message in
                self?.handleReceivedMessage(message)
            }
            .store(in: &cancellables)
    }
    
    private func performJoinSession(sessionId: String, userId: String, friends: [User], promise: @escaping (Result<Void, Error>) -> Void) {
        let friendIds = friends.map { $0.id.uuidString }
        let joinData = JoinSessionData(
            sessionId: sessionId,
            userId: userId,
            friends: friendIds
        )
        
        do {
            let data = try JSONEncoder().encode(joinData)
            let message = WebSocketMessage(
                type: .joinSession,
                data: data,
                timestamp: Date()
            )
            
            webSocketClient.send(message: message)
            
            // Store session info
            currentSessionId = sessionId
            currentUserId = userId
            
            promise(.success(()))
        } catch {
            promise(.failure(SyncServiceError.encodingError(error)))
        }
    }
    
    private func handleReceivedMessage(_ message: WebSocketMessage) {
        switch message.type {
        case .friendUpdate:
            handleFriendUpdate(message)
        case .sessionStatus:
            handleSessionStatus(message)
        case .error:
            handleErrorMessage(message)
        default:
            break
        }
    }
    
    private func handleFriendUpdate(_ message: WebSocketMessage) {
        do {
            let friendUpdate = try JSONDecoder().decode(FriendUpdateData.self, from: message.data)
            
            let update = FriendRunUpdate(
                userId: friendUpdate.userId,
                pace: friendUpdate.pace,
                location: friendUpdate.location,
                timestamp: friendUpdate.timestamp,
                status: friendUpdate.status
            )
            
            // Update the friend updates array
            var currentUpdates = friendUpdatesSubject.value
            
            // Remove any existing update for this user
            currentUpdates.removeAll { $0.userId == update.userId }
            
            // Add the new update
            currentUpdates.append(update)
            
            // Sort by timestamp (most recent first)
            currentUpdates.sort { $0.timestamp > $1.timestamp }
            
            friendUpdatesSubject.send(currentUpdates)
        } catch {
            print("Failed to decode friend update: \(error)")
        }
    }
    
    private func handleSessionStatus(_ message: WebSocketMessage) {
        do {
            let statusData = try JSONDecoder().decode(SessionStatusData.self, from: message.data)
            
            let sessionInfo = SessionInfo(
                sessionId: statusData.sessionId,
                participants: statusData.participants,
                status: statusData.status,
                createdAt: Date()
            )
            
            sessionInfoSubject.send(sessionInfo)
        } catch {
            print("Failed to decode session status: \(error)")
        }
    }
    
    private func handleErrorMessage(_ message: WebSocketMessage) {
        if let errorString = String(data: message.data, encoding: .utf8) {
            print("Received error from server: \(errorString)")
        }
    }
}
#else
// Stub implementation for platforms without Combine
public class RealTimeSyncService: RealTimeSyncServiceProtocol {
    private var currentSessionId: String?
    
    public init(webSocketClient: WebSocketClientProtocol, serverURL: URL) {
        // Stub initialization
    }
    
    public func joinSession(sessionId: String, userId: String, friends: [User], completion: @escaping (Result<Void, Error>) -> Void) {
        currentSessionId = sessionId
        completion(.success(()))
    }
    
    public func leaveSession(completion: @escaping (Result<Void, Error>) -> Void) {
        currentSessionId = nil
        completion(.success(()))
    }
    
    public func sendPaceUpdate(pace: Double, location: LocationCoordinate2D, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.success(()))
    }
    
    public func isInSession() -> Bool {
        return currentSessionId != nil
    }
    
    public func getCurrentSessionId() -> String? {
        return currentSessionId
    }
}
#endif

// MARK: - Supporting Data Models

public struct LeaveSessionData: Codable {
    let sessionId: String
    let userId: String
}



// MARK: - Sync Service Errors

enum SyncServiceError: Error, LocalizedError {
    case serviceUnavailable
    case notInSession
    case notConnected
    case encodingError(Error)
    case sessionFull
    case invalidSession
    
    var errorDescription: String? {
        switch self {
        case .serviceUnavailable:
            return "Sync service is not available"
        case .notInSession:
            return "Not currently in a running session"
        case .notConnected:
            return "Not connected to sync server"
        case .encodingError(let error):
            return "Failed to encode data: \(error.localizedDescription)"
        case .sessionFull:
            return "Running session is full"
        case .invalidSession:
            return "Invalid session ID"
        }
    }
}