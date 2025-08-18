import XCTest
import Combine
@testable import VirtualRunningCompanion

final class FriendServiceTests: XCTestCase {
    
    var friendService: FriendService!
    var mockFriendRepository: MockFriendRepository!
    var mockUserRepository: MockUserRepository!
    var mockWebSocketClient: MockWebSocketClient!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockFriendRepository = MockFriendRepository()
        mockUserRepository = MockUserRepository()
        mockWebSocketClient = MockWebSocketClient()
        friendService = FriendService(
            friendRepository: mockFriendRepository,
            userRepository: mockUserRepository,
            webSocketClient: mockWebSocketClient
        )
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        friendService = nil
        mockWebSocketClient = nil
        mockUserRepository = nil
        mockFriendRepository = nil
        super.tearDown()
    }
    
    // MARK: - User Search Tests
    
    func testSearchUsers_WithValidQuery_ReturnsUsers() {
        // Given
        let expectedUsers = [
            User(id: UUID(), username: "john_doe", email: "john@example.com"),
            User(id: UUID(), username: "jane_doe", email: "jane@example.com")
        ]
        mockUserRepository.searchUsersResult = .success(expectedUsers)
        
        let expectation = XCTestExpectation(description: "Search users")
        var receivedUsers: [User] = []
        
        // When
        friendService.searchUsers(query: "doe")
            .sink(
                receiveCompletion: { completion in
                    if case .failure = completion {
                        XCTFail("Expected success")
                    }
                    expectation.fulfill()
                },
                receiveValue: { users in
                    receivedUsers = users
                }
            )
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedUsers.count, 2)
        XCTAssertEqual(receivedUsers[0].username, "john_doe")
        XCTAssertEqual(receivedUsers[1].username, "jane_doe")
    }
    
    func testSearchUsers_WithEmptyQuery_ReturnsEmptyArray() {
        // Given
        let expectation = XCTestExpectation(description: "Search users with empty query")
        var receivedUsers: [User] = []
        
        // When
        friendService.searchUsers(query: "")
            .sink(
                receiveCompletion: { completion in
                    if case .failure = completion {
                        XCTFail("Expected success")
                    }
                    expectation.fulfill()
                },
                receiveValue: { users in
                    receivedUsers = users
                }
            )
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(receivedUsers.isEmpty)
    }
    
    // MARK: - Friend Request Tests
    
    func testSendFriendRequest_WithValidUser_CreatesRequest() {
        // Given
        let targetUserId = UUID()
        mockFriendRepository.fetchAllResult = .success([])
        
        let expectation = XCTestExpectation(description: "Send friend request")
        var receivedRequest: FriendRequest?
        
        // When
        friendService.sendFriendRequest(to: targetUserId)
            .sink(
                receiveCompletion: { completion in
                    if case .failure = completion {
                        XCTFail("Expected success")
                    }
                    expectation.fulfill()
                },
                receiveValue: { request in
                    receivedRequest = request
                }
            )
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(receivedRequest)
        XCTAssertEqual(receivedRequest?.toUserId, targetUserId)
        XCTAssertEqual(receivedRequest?.status, .pending)
    }
    
    func testSendFriendRequest_WhenAlreadyFriends_ReturnsError() {
        // Given
        let targetUserId = UUID()
        let existingFriend = Friend(
            user: User(id: targetUserId, username: "friend", email: "friend@example.com"),
            status: .accepted
        )
        mockFriendRepository.fetchAllResult = .success([existingFriend])
        
        let expectation = XCTestExpectation(description: "Send friend request to existing friend")
        var receivedError: Error?
        
        // When
        friendService.sendFriendRequest(to: targetUserId)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        receivedError = error
                    }
                    expectation.fulfill()
                },
                receiveValue: { _ in
                    XCTFail("Expected failure")
                }
            )
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(receivedError is FriendServiceError)
        XCTAssertEqual(receivedError as? FriendServiceError, .alreadyFriends)
    }
    
    func testAcceptFriendRequest_WithValidRequest_CreatesFriendship() {
        // Given
        let requestId = UUID()
        let fromUser = User(id: UUID(), username: "requester", email: "requester@example.com")
        
        // First send a request to have something to accept
        let request = FriendRequest(
            id: requestId,
            fromUserId: fromUser.id,
            toUserId: UUID(),
            fromUser: fromUser
        )
        
        // Simulate the request being in the service
        friendService.sendFriendRequest(to: UUID())
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)
        
        mockUserRepository.fetchResult = .success(User(id: UUID(), username: "current", email: "current@example.com"))
        mockFriendRepository.saveResult = .success(Friend(user: fromUser, status: .accepted))
        
        let expectation = XCTestExpectation(description: "Accept friend request")
        var receivedFriend: Friend?
        
        // When
        friendService.acceptFriendRequest(requestId: requestId)
            .sink(
                receiveCompletion: { completion in
                    if case .failure = completion {
                        XCTFail("Expected success")
                    }
                    expectation.fulfill()
                },
                receiveValue: { friend in
                    receivedFriend = friend
                }
            )
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(receivedFriend)
        XCTAssertEqual(receivedFriend?.status, .accepted)
    }
    
    func testDeclineFriendRequest_WithValidRequest_UpdatesRequestStatus() {
        // Given
        let requestId = UUID()
        
        let expectation = XCTestExpectation(description: "Decline friend request")
        var completed = false
        
        // When
        friendService.declineFriendRequest(requestId: requestId)
            .sink(
                receiveCompletion: { completion in
                    if case .failure = completion {
                        XCTFail("Expected success")
                    }
                    completed = true
                    expectation.fulfill()
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(completed)
    }
    
    // MARK: - Friend Management Tests
    
    func testGetFriends_ReturnsAcceptedFriends() {
        // Given
        let userId = UUID()
        let friends = [
            Friend(user: User(id: UUID(), username: "friend1", email: "friend1@example.com"), status: .accepted),
            Friend(user: User(id: UUID(), username: "friend2", email: "friend2@example.com"), status: .accepted)
        ]
        mockFriendRepository.fetchByStatusResult = .success(friends)
        
        let expectation = XCTestExpectation(description: "Get friends")
        var receivedFriends: [Friend] = []
        
        // When
        friendService.getFriends(for: userId)
            .sink(
                receiveCompletion: { completion in
                    if case .failure = completion {
                        XCTFail("Expected success")
                    }
                    expectation.fulfill()
                },
                receiveValue: { friends in
                    receivedFriends = friends
                }
            )
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedFriends.count, 2)
        XCTAssertEqual(receivedFriends[0].user.username, "friend1")
        XCTAssertEqual(receivedFriends[1].user.username, "friend2")
    }
    
    func testRemoveFriend_WithValidFriendId_DeletesFriend() {
        // Given
        let friendId = UUID()
        mockFriendRepository.deleteResult = .success(())
        
        let expectation = XCTestExpectation(description: "Remove friend")
        var completed = false
        
        // When
        friendService.removeFriend(friendId: friendId)
            .sink(
                receiveCompletion: { completion in
                    if case .failure = completion {
                        XCTFail("Expected success")
                    }
                    completed = true
                    expectation.fulfill()
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(completed)
        XCTAssertTrue(mockFriendRepository.deleteWasCalled)
    }
    
    func testBlockFriend_WithValidFriendId_UpdatesStatusToBlocked() {
        // Given
        let friendId = UUID()
        let friend = Friend(
            id: friendId,
            user: User(id: UUID(), username: "friend", email: "friend@example.com"),
            status: .accepted
        )
        mockFriendRepository.fetchResult = .success(friend)
        mockFriendRepository.updateResult = .success(Friend(
            id: friendId,
            user: friend.user,
            status: .blocked
        ))
        
        let expectation = XCTestExpectation(description: "Block friend")
        var receivedFriend: Friend?
        
        // When
        friendService.blockFriend(friendId: friendId)
            .sink(
                receiveCompletion: { completion in
                    if case .failure = completion {
                        XCTFail("Expected success")
                    }
                    expectation.fulfill()
                },
                receiveValue: { friend in
                    receivedFriend = friend
                }
            )
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(receivedFriend)
        XCTAssertEqual(receivedFriend?.status, .blocked)
    }
    
    func testUnblockFriend_WithValidFriendId_UpdatesStatusToAccepted() {
        // Given
        let friendId = UUID()
        let friend = Friend(
            id: friendId,
            user: User(id: UUID(), username: "friend", email: "friend@example.com"),
            status: .blocked
        )
        mockFriendRepository.fetchResult = .success(friend)
        mockFriendRepository.updateResult = .success(Friend(
            id: friendId,
            user: friend.user,
            status: .accepted
        ))
        
        let expectation = XCTestExpectation(description: "Unblock friend")
        var receivedFriend: Friend?
        
        // When
        friendService.unblockFriend(friendId: friendId)
            .sink(
                receiveCompletion: { completion in
                    if case .failure = completion {
                        XCTFail("Expected success")
                    }
                    expectation.fulfill()
                },
                receiveValue: { friend in
                    receivedFriend = friend
                }
            )
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(receivedFriend)
        XCTAssertEqual(receivedFriend?.status, .accepted)
    }
    
    // MARK: - Online Status Tests
    
    func testUpdateOnlineStatus_WithValidUserId_UpdatesStatus() {
        // Given
        let userId = UUID()
        
        let expectation = XCTestExpectation(description: "Update online status")
        var completed = false
        
        // When
        friendService.updateOnlineStatus(userId: userId, isOnline: true)
            .sink(
                receiveCompletion: { completion in
                    if case .failure = completion {
                        XCTFail("Expected success")
                    }
                    completed = true
                    expectation.fulfill()
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(completed)
    }
    
    func testGetOnlineFriends_ReturnsOnlyOnlineFriends() {
        // Given
        let userId = UUID()
        let friends = [
            Friend(user: User(id: UUID(), username: "friend1", email: "friend1@example.com"), 
                  status: .accepted, isOnline: true),
            Friend(user: User(id: UUID(), username: "friend2", email: "friend2@example.com"), 
                  status: .accepted, isOnline: false),
            Friend(user: User(id: UUID(), username: "friend3", email: "friend3@example.com"), 
                  status: .accepted, isOnline: true)
        ]
        mockFriendRepository.fetchByStatusResult = .success(friends)
        
        let expectation = XCTestExpectation(description: "Get online friends")
        var receivedFriends: [Friend] = []
        
        // When
        friendService.getOnlineFriends(for: userId)
            .sink(
                receiveCompletion: { completion in
                    if case .failure = completion {
                        XCTFail("Expected success")
                    }
                    expectation.fulfill()
                },
                receiveValue: { friends in
                    receivedFriends = friends
                }
            )
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedFriends.count, 2)
        XCTAssertTrue(receivedFriends.allSatisfy { $0.isOnline })
    }
}

// MARK: - Mock Friend Repository

class MockFriendRepository: FriendRepositoryProtocol {
    var saveResult: Result<Friend, Error> = .success(Friend(user: User(id: UUID(), username: "test", email: "test@example.com"), status: .accepted))
    var fetchResult: Result<Friend?, Error> = .success(nil)
    var fetchAllResult: Result<[Friend], Error> = .success([])
    var fetchByStatusResult: Result<[Friend], Error> = .success([])
    var deleteResult: Result<Void, Error> = .success(())
    var updateResult: Result<Friend, Error> = .success(Friend(user: User(id: UUID(), username: "test", email: "test@example.com"), status: .accepted))
    
    var deleteWasCalled = false
    
    func save(_ friend: Friend, for userId: UUID) -> AnyPublisher<Friend, Error> {
        return saveResult.publisher.eraseToAnyPublisher()
    }
    
    func fetch(by id: UUID) -> AnyPublisher<Friend?, Error> {
        return fetchResult.publisher.eraseToAnyPublisher()
    }
    
    func fetchAll(for userId: UUID) -> AnyPublisher<[Friend], Error> {
        return fetchAllResult.publisher.eraseToAnyPublisher()
    }
    
    func fetchByStatus(_ status: FriendStatus, for userId: UUID) -> AnyPublisher<[Friend], Error> {
        return fetchByStatusResult.publisher.eraseToAnyPublisher()
    }
    
    func delete(by id: UUID) -> AnyPublisher<Void, Error> {
        deleteWasCalled = true
        return deleteResult.publisher.eraseToAnyPublisher()
    }
    
    func update(_ friend: Friend) -> AnyPublisher<Friend, Error> {
        return updateResult.publisher.eraseToAnyPublisher()
    }
}

// MARK: - Mock User Repository

class MockUserRepository: UserRepositoryProtocol {
    var saveResult: Result<User, Error> = .success(User(id: UUID(), username: "test", email: "test@example.com"))
    var fetchResult: Result<User?, Error> = .success(nil)
    var fetchAllResult: Result<[User], Error> = .success([])
    var deleteResult: Result<Void, Error> = .success(())
    var updateResult: Result<User, Error> = .success(User(id: UUID(), username: "test", email: "test@example.com"))
    var searchUsersResult: Result<[User], Error> = .success([])
    
    func save(_ user: User) -> AnyPublisher<User, Error> {
        return saveResult.publisher.eraseToAnyPublisher()
    }
    
    func fetch(by id: UUID) -> AnyPublisher<User?, Error> {
        return fetchResult.publisher.eraseToAnyPublisher()
    }
    
    func fetchAll() -> AnyPublisher<[User], Error> {
        return fetchAllResult.publisher.eraseToAnyPublisher()
    }
    
    func delete(by id: UUID) -> AnyPublisher<Void, Error> {
        return deleteResult.publisher.eraseToAnyPublisher()
    }
    
    func update(_ user: User) -> AnyPublisher<User, Error> {
        return updateResult.publisher.eraseToAnyPublisher()
    }
    
    func searchUsers(query: String) -> AnyPublisher<[User], Error> {
        return searchUsersResult.publisher.eraseToAnyPublisher()
    }
}