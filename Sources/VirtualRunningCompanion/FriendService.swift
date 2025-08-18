import Foundation
import Combine

// MARK: - Friend Request Model

public struct FriendRequest: Codable, Identifiable {
    public let id: UUID
    public let fromUserId: UUID
    public let toUserId: UUID
    public let fromUser: User
    public let status: FriendRequestStatus
    public let createdAt: Date
    public let respondedAt: Date?
    
    public init(id: UUID = UUID(), fromUserId: UUID, toUserId: UUID, fromUser: User, 
                status: FriendRequestStatus = .pending, createdAt: Date = Date(), respondedAt: Date? = nil) {
        self.id = id
        self.fromUserId = fromUserId
        self.toUserId = toUserId
        self.fromUser = fromUser
        self.status = status
        self.createdAt = createdAt
        self.respondedAt = respondedAt
    }
}

public enum FriendRequestStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case accepted = "accepted"
    case declined = "declined"
    case cancelled = "cancelled"
}

// MARK: - Friend Service Protocol

public protocol FriendServiceProtocol {
    func searchUsers(query: String) -> AnyPublisher<[User], Error>
    func sendFriendRequest(to userId: UUID) -> AnyPublisher<FriendRequest, Error>
    func acceptFriendRequest(requestId: UUID) -> AnyPublisher<Friend, Error>
    func declineFriendRequest(requestId: UUID) -> AnyPublisher<Void, Error>
    func cancelFriendRequest(requestId: UUID) -> AnyPublisher<Void, Error>
    func getFriends(for userId: UUID) -> AnyPublisher<[Friend], Error>
    func getFriendRequests(for userId: UUID) -> AnyPublisher<[FriendRequest], Error>
    func getSentFriendRequests(for userId: UUID) -> AnyPublisher<[FriendRequest], Error>
    func removeFriend(friendId: UUID) -> AnyPublisher<Void, Error>
    func blockFriend(friendId: UUID) -> AnyPublisher<Friend, Error>
    func unblockFriend(friendId: UUID) -> AnyPublisher<Friend, Error>
    func updateOnlineStatus(userId: UUID, isOnline: Bool) -> AnyPublisher<Void, Error>
    func getOnlineFriends(for userId: UUID) -> AnyPublisher<[Friend], Error>
}

// MARK: - Friend Service Implementation

public class FriendService: FriendServiceProtocol {
    
    private let friendRepository: FriendRepositoryProtocol
    private let userRepository: UserRepositoryProtocol
    private let webSocketClient: WebSocketClientProtocol?
    private var cancellables = Set<AnyCancellable>()
    
    // In-memory storage for friend requests (in a real app, this would be server-side)
    private var friendRequests: [FriendRequest] = []
    private let friendRequestsSubject = CurrentValueSubject<[FriendRequest], Never>([])
    
    // Online status tracking
    private var onlineUsers: Set<UUID> = []
    private let onlineUsersSubject = CurrentValueSubject<Set<UUID>, Never>([])
    
    public init(friendRepository: FriendRepositoryProtocol, 
                userRepository: UserRepositoryProtocol,
                webSocketClient: WebSocketClientProtocol? = nil) {
        self.friendRepository = friendRepository
        self.userRepository = userRepository
        self.webSocketClient = webSocketClient
        
        setupWebSocketListeners()
    }
    
    // MARK: - User Search
    
    public func searchUsers(query: String) -> AnyPublisher<[User], Error> {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return Just([])
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        // In a real implementation, this would search a server database
        // For now, we'll simulate with local user repository search
        return userRepository.searchUsers(query: query)
    }
    
    // MARK: - Friend Requests
    
    public func sendFriendRequest(to userId: UUID) -> AnyPublisher<FriendRequest, Error> {
        return getCurrentUser()
            .flatMap { [weak self] currentUser -> AnyPublisher<FriendRequest, Error> in
                guard let self = self else {
                    return Fail(error: FriendServiceError.serviceUnavailable)
                        .eraseToAnyPublisher()
                }
                
                // Check if request already exists
                let existingRequest = self.friendRequests.first { request in
                    (request.fromUserId == currentUser.id && request.toUserId == userId) ||
                    (request.fromUserId == userId && request.toUserId == currentUser.id)
                }
                
                if let existing = existingRequest {
                    return Fail(error: FriendServiceError.requestAlreadyExists)
                        .eraseToAnyPublisher()
                }
                
                // Check if already friends
                return self.friendRepository.fetchAll(for: currentUser.id)
                    .flatMap { friends -> AnyPublisher<FriendRequest, Error> in
                        let isAlreadyFriend = friends.contains { $0.user.id == userId }
                        if isAlreadyFriend {
                            return Fail(error: FriendServiceError.alreadyFriends)
                                .eraseToAnyPublisher()
                        }
                        
                        let friendRequest = FriendRequest(
                            fromUserId: currentUser.id,
                            toUserId: userId,
                            fromUser: currentUser
                        )
                        
                        self.friendRequests.append(friendRequest)
                        self.friendRequestsSubject.send(self.friendRequests)
                        
                        // Send notification via WebSocket if available
                        self.sendFriendRequestNotification(friendRequest)
                        
                        return Just(friendRequest)
                            .setFailureType(to: Error.self)
                            .eraseToAnyPublisher()
                    }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    public func acceptFriendRequest(requestId: UUID) -> AnyPublisher<Friend, Error> {
        guard let requestIndex = friendRequests.firstIndex(where: { $0.id == requestId }) else {
            return Fail(error: FriendServiceError.requestNotFound)
                .eraseToAnyPublisher()
        }
        
        var request = friendRequests[requestIndex]
        request = FriendRequest(
            id: request.id,
            fromUserId: request.fromUserId,
            toUserId: request.toUserId,
            fromUser: request.fromUser,
            status: .accepted,
            createdAt: request.createdAt,
            respondedAt: Date()
        )
        
        friendRequests[requestIndex] = request
        friendRequestsSubject.send(friendRequests)
        
        return getCurrentUser()
            .flatMap { [weak self] currentUser -> AnyPublisher<Friend, Error> in
                guard let self = self else {
                    return Fail(error: FriendServiceError.serviceUnavailable)
                        .eraseToAnyPublisher()
                }
                
                // Create friend relationship for both users
                let friend1 = Friend(
                    user: request.fromUser,
                    status: .accepted,
                    isOnline: self.onlineUsers.contains(request.fromUserId)
                )
                
                return self.userRepository.fetch(by: currentUser.id)
                    .compactMap { $0 }
                    .flatMap { currentUserData -> AnyPublisher<Friend, Error> in
                        let friend2 = Friend(
                            user: currentUserData,
                            status: .accepted,
                            isOnline: self.onlineUsers.contains(currentUser.id)
                        )
                        
                        // Save both friend relationships
                        let saveFriend1 = self.friendRepository.save(friend1, for: currentUser.id)
                        let saveFriend2 = self.friendRepository.save(friend2, for: request.fromUserId)
                        
                        return Publishers.Zip(saveFriend1, saveFriend2)
                            .map { $0.0 } // Return the first friend (from requester's perspective)
                            .eraseToAnyPublisher()
                    }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    public func declineFriendRequest(requestId: UUID) -> AnyPublisher<Void, Error> {
        guard let requestIndex = friendRequests.firstIndex(where: { $0.id == requestId }) else {
            return Fail(error: FriendServiceError.requestNotFound)
                .eraseToAnyPublisher()
        }
        
        var request = friendRequests[requestIndex]
        request = FriendRequest(
            id: request.id,
            fromUserId: request.fromUserId,
            toUserId: request.toUserId,
            fromUser: request.fromUser,
            status: .declined,
            createdAt: request.createdAt,
            respondedAt: Date()
        )
        
        friendRequests[requestIndex] = request
        friendRequestsSubject.send(friendRequests)
        
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    public func cancelFriendRequest(requestId: UUID) -> AnyPublisher<Void, Error> {
        guard let requestIndex = friendRequests.firstIndex(where: { $0.id == requestId }) else {
            return Fail(error: FriendServiceError.requestNotFound)
                .eraseToAnyPublisher()
        }
        
        friendRequests.remove(at: requestIndex)
        friendRequestsSubject.send(friendRequests)
        
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Friend Management
    
    public func getFriends(for userId: UUID) -> AnyPublisher<[Friend], Error> {
        return friendRepository.fetchByStatus(.accepted, for: userId)
            .map { [weak self] friends in
                guard let self = self else { return friends }
                
                // Update online status for friends
                return friends.map { friend in
                    Friend(
                        id: friend.id,
                        user: friend.user,
                        status: friend.status,
                        isOnline: self.onlineUsers.contains(friend.user.id),
                        lastRunDate: friend.lastRunDate,
                        totalRuns: friend.totalRuns
                    )
                }
            }
            .eraseToAnyPublisher()
    }
    
    public func getFriendRequests(for userId: UUID) -> AnyPublisher<[FriendRequest], Error> {
        let incomingRequests = friendRequests.filter { 
            $0.toUserId == userId && $0.status == .pending 
        }
        
        return Just(incomingRequests)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    public func getSentFriendRequests(for userId: UUID) -> AnyPublisher<[FriendRequest], Error> {
        let sentRequests = friendRequests.filter { 
            $0.fromUserId == userId && $0.status == .pending 
        }
        
        return Just(sentRequests)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    public func removeFriend(friendId: UUID) -> AnyPublisher<Void, Error> {
        return friendRepository.delete(by: friendId)
    }
    
    public func blockFriend(friendId: UUID) -> AnyPublisher<Friend, Error> {
        return friendRepository.fetch(by: friendId)
            .compactMap { $0 }
            .flatMap { [weak self] friend -> AnyPublisher<Friend, Error> in
                guard let self = self else {
                    return Fail(error: FriendServiceError.serviceUnavailable)
                        .eraseToAnyPublisher()
                }
                
                let blockedFriend = Friend(
                    id: friend.id,
                    user: friend.user,
                    status: .blocked,
                    isOnline: friend.isOnline,
                    lastRunDate: friend.lastRunDate,
                    totalRuns: friend.totalRuns
                )
                
                return self.friendRepository.update(blockedFriend)
            }
            .eraseToAnyPublisher()
    }
    
    public func unblockFriend(friendId: UUID) -> AnyPublisher<Friend, Error> {
        return friendRepository.fetch(by: friendId)
            .compactMap { $0 }
            .flatMap { [weak self] friend -> AnyPublisher<Friend, Error> in
                guard let self = self else {
                    return Fail(error: FriendServiceError.serviceUnavailable)
                        .eraseToAnyPublisher()
                }
                
                let unblockedFriend = Friend(
                    id: friend.id,
                    user: friend.user,
                    status: .accepted,
                    isOnline: friend.isOnline,
                    lastRunDate: friend.lastRunDate,
                    totalRuns: friend.totalRuns
                )
                
                return self.friendRepository.update(unblockedFriend)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Online Status
    
    public func updateOnlineStatus(userId: UUID, isOnline: Bool) -> AnyPublisher<Void, Error> {
        if isOnline {
            onlineUsers.insert(userId)
        } else {
            onlineUsers.remove(userId)
        }
        
        onlineUsersSubject.send(onlineUsers)
        
        // Broadcast status update via WebSocket
        broadcastOnlineStatusUpdate(userId: userId, isOnline: isOnline)
        
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    public func getOnlineFriends(for userId: UUID) -> AnyPublisher<[Friend], Error> {
        return getFriends(for: userId)
            .map { friends in
                friends.filter { $0.isOnline }
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Private Methods
    
    private func getCurrentUser() -> AnyPublisher<User, Error> {
        // In a real app, this would get the current authenticated user
        // For now, we'll create a mock current user
        let currentUser = User(
            id: UUID(),
            username: "currentUser",
            email: "current@example.com"
        )
        
        return Just(currentUser)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    private func setupWebSocketListeners() {
        webSocketClient?.messageReceived
            .sink { [weak self] message in
                self?.handleWebSocketMessage(message)
            }
            .store(in: &cancellables)
    }
    
    private func handleWebSocketMessage(_ message: WebSocketMessage) {
        switch message.type {
        case "friend_request":
            handleIncomingFriendRequest(message)
        case "online_status_update":
            handleOnlineStatusUpdate(message)
        default:
            break
        }
    }
    
    private func handleIncomingFriendRequest(_ message: WebSocketMessage) {
        // Handle incoming friend request from WebSocket
        // This would parse the message and add to friendRequests
    }
    
    private func handleOnlineStatusUpdate(_ message: WebSocketMessage) {
        // Handle online status updates from other users
        // This would update the onlineUsers set
    }
    
    private func sendFriendRequestNotification(_ request: FriendRequest) {
        guard let webSocketClient = webSocketClient else { return }
        
        let message = WebSocketMessage(
            type: "friend_request",
            data: try? JSONEncoder().encode(request)
        )
        
        webSocketClient.send(message: message)
    }
    
    private func broadcastOnlineStatusUpdate(userId: UUID, isOnline: Bool) {
        guard let webSocketClient = webSocketClient else { return }
        
        let statusUpdate = ["userId": userId.uuidString, "isOnline": isOnline]
        let message = WebSocketMessage(
            type: "online_status_update",
            data: try? JSONEncoder().encode(statusUpdate)
        )
        
        webSocketClient.send(message: message)
    }
}

// MARK: - Friend Service Errors

public enum FriendServiceError: Error, LocalizedError {
    case serviceUnavailable
    case requestAlreadyExists
    case requestNotFound
    case alreadyFriends
    case userNotFound
    case invalidRequest
    case networkError
    
    public var errorDescription: String? {
        switch self {
        case .serviceUnavailable:
            return "Friend service is currently unavailable"
        case .requestAlreadyExists:
            return "A friend request already exists between these users"
        case .requestNotFound:
            return "Friend request not found"
        case .alreadyFriends:
            return "Users are already friends"
        case .userNotFound:
            return "User not found"
        case .invalidRequest:
            return "Invalid friend request"
        case .networkError:
            return "Network error occurred"
        }
    }
}