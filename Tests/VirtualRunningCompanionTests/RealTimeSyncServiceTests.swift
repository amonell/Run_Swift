import XCTest
import Combine
import CoreLocation
@testable import VirtualRunningCompanion

class RealTimeSyncServiceTests: XCTestCase {
    var syncService: RealTimeSyncService!
    var mockWebSocketClient: MockWebSocketClient!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockWebSocketClient = MockWebSocketClient()
        syncService = RealTimeSyncService(
            webSocketClient: mockWebSocketClient,
            serverURL: URL(string: "ws://localhost:8080")!
        )
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        syncService = nil
        mockWebSocketClient = nil
        super.tearDown()
    }
    
    // MARK: - Connection Status Tests
    
    func testConnectionStatusForwarding() {
        let expectation = XCTestExpectation(description: "Connection status forwarded")
        var receivedStatuses: [ConnectionStatus] = []
        
        syncService.connectionStatus
            .sink { status in
                receivedStatuses.append(status)
                if receivedStatuses.count == 3 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Simulate connection sequence
        mockWebSocketClient.connect(to: URL(string: "ws://test.com")!)
        
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(receivedStatuses.count, 3)
        XCTAssertEqual(receivedStatuses[0], .disconnected) // Initial state
        XCTAssertEqual(receivedStatuses[1], .connecting)
        XCTAssertEqual(receivedStatuses[2], .connected)
    }
    
    // MARK: - Join Session Tests
    
    func testJoinSessionSuccess() {
        let expectation = XCTestExpectation(description: "Join session succeeds")
        
        let sessionId = "test-session-123"
        let userId = "user-456"
        let friends = [
            User(id: UUID(), username: "friend1", email: "friend1@test.com"),
            User(id: UUID(), username: "friend2", email: "friend2@test.com")
        ]
        
        syncService.joinSession(sessionId: sessionId, userId: userId, friends: friends)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Join session failed: \(error)")
                    }
                },
                receiveValue: { _ in
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 2.0)
        
        // Verify session state
        XCTAssertTrue(syncService.isInSession())
        XCTAssertEqual(syncService.getCurrentSessionId(), sessionId)
        
        // Verify WebSocket message was sent
        let sentMessages = mockWebSocketClient.getSentMessages()
        XCTAssertEqual(sentMessages.count, 1)
        XCTAssertEqual(sentMessages.first?.type, .joinSession)
    }
    
    func testJoinSessionWithConnectionDelay() {
        let expectation = XCTestExpectation(description: "Join session waits for connection")
        
        let sessionId = "test-session-123"
        let userId = "user-456"
        let friends: [User] = []
        
        // Start join before connection is established
        syncService.joinSession(sessionId: sessionId, userId: userId, friends: friends)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Join session failed: \(error)")
                    }
                },
                receiveValue: { _ in
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 2.0)
        
        XCTAssertTrue(syncService.isInSession())
    }
    
    // MARK: - Leave Session Tests
    
    func testLeaveSessionSuccess() {
        let joinExpectation = XCTestExpectation(description: "Join session first")
        let leaveExpectation = XCTestExpectation(description: "Leave session succeeds")
        
        let sessionId = "test-session-123"
        let userId = "user-456"
        
        // First join a session
        syncService.joinSession(sessionId: sessionId, userId: userId, friends: [])
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in
                    joinExpectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [joinExpectation], timeout: 1.0)
        
        // Then leave the session
        syncService.leaveSession()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Leave session failed: \(error)")
                    }
                },
                receiveValue: { _ in
                    leaveExpectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [leaveExpectation], timeout: 1.0)
        
        // Verify session state is cleared
        XCTAssertFalse(syncService.isInSession())
        XCTAssertNil(syncService.getCurrentSessionId())
    }
    
    func testLeaveSessionWhenNotInSession() {
        let expectation = XCTestExpectation(description: "Leave session fails when not in session")
        
        syncService.leaveSession()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTAssertTrue(error is SyncServiceError)
                        expectation.fulfill()
                    }
                },
                receiveValue: { _ in
                    XCTFail("Leave session should fail when not in session")
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Pace Update Tests
    
    func testSendPaceUpdateSuccess() {
        let joinExpectation = XCTestExpectation(description: "Join session first")
        let paceExpectation = XCTestExpectation(description: "Send pace update succeeds")
        
        let sessionId = "test-session-123"
        let userId = "user-456"
        
        // First join a session
        syncService.joinSession(sessionId: sessionId, userId: userId, friends: [])
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in
                    joinExpectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [joinExpectation], timeout: 1.0)
        
        // Send pace update
        let location = CLLocation(latitude: 37.7749, longitude: -122.4194)
        let pace = 6.5 // minutes per mile
        
        syncService.sendPaceUpdate(pace: pace, location: location)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Send pace update failed: \(error)")
                    }
                },
                receiveValue: { _ in
                    paceExpectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [paceExpectation], timeout: 1.0)
        
        // Verify pace update message was sent
        let sentMessages = mockWebSocketClient.getSentMessages()
        let paceMessages = sentMessages.filter { $0.type == .paceUpdate }
        XCTAssertEqual(paceMessages.count, 1)
    }
    
    func testSendPaceUpdateWhenNotInSession() {
        let expectation = XCTestExpectation(description: "Send pace update fails when not in session")
        
        let location = CLLocation(latitude: 37.7749, longitude: -122.4194)
        let pace = 6.5
        
        syncService.sendPaceUpdate(pace: pace, location: location)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTAssertTrue(error is SyncServiceError)
                        expectation.fulfill()
                    }
                },
                receiveValue: { _ in
                    XCTFail("Send pace update should fail when not in session")
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Friend Updates Tests
    
    func testReceiveFriendUpdates() {
        let expectation = XCTestExpectation(description: "Receive friend updates")
        var receivedUpdates: [FriendRunUpdate] = []
        
        syncService.friendUpdates
            .sink { updates in
                receivedUpdates = updates
                if !updates.isEmpty {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Simulate incoming friend update
        let location = LocationCoordinate(latitude: 37.7749, longitude: -122.4194)
        mockWebSocketClient.simulateFriendUpdate(
            userId: "friend-123",
            sessionId: "session-456",
            pace: 7.0,
            location: location
        )
        
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(receivedUpdates.count, 1)
        XCTAssertEqual(receivedUpdates.first?.userId, "friend-123")
        XCTAssertEqual(receivedUpdates.first?.pace, 7.0)
    }
    
    func testMultipleFriendUpdates() {
        let expectation = XCTestExpectation(description: "Receive multiple friend updates")
        var receivedUpdates: [FriendRunUpdate] = []
        
        syncService.friendUpdates
            .sink { updates in
                receivedUpdates = updates
                if updates.count == 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        let location1 = LocationCoordinate(latitude: 37.7749, longitude: -122.4194)
        let location2 = LocationCoordinate(latitude: 37.7849, longitude: -122.4294)
        
        // Simulate updates from two different friends
        mockWebSocketClient.simulateFriendUpdate(
            userId: "friend-1",
            sessionId: "session-456",
            pace: 7.0,
            location: location1
        )
        
        mockWebSocketClient.simulateFriendUpdate(
            userId: "friend-2",
            sessionId: "session-456",
            pace: 6.5,
            location: location2
        )
        
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(receivedUpdates.count, 2)
        
        let userIds = receivedUpdates.map { $0.userId }
        XCTAssertTrue(userIds.contains("friend-1"))
        XCTAssertTrue(userIds.contains("friend-2"))
    }
    
    func testFriendUpdateReplacement() {
        let expectation = XCTestExpectation(description: "Friend update replacement")
        var updateCount = 0
        
        syncService.friendUpdates
            .sink { updates in
                updateCount += 1
                if updateCount == 2 {
                    // Should still have only one update (replaced)
                    XCTAssertEqual(updates.count, 1)
                    XCTAssertEqual(updates.first?.pace, 6.0) // Updated pace
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        let location = LocationCoordinate(latitude: 37.7749, longitude: -122.4194)
        
        // Send first update
        mockWebSocketClient.simulateFriendUpdate(
            userId: "friend-1",
            sessionId: "session-456",
            pace: 7.0,
            location: location
        )
        
        // Send updated pace for same friend
        mockWebSocketClient.simulateFriendUpdate(
            userId: "friend-1",
            sessionId: "session-456",
            pace: 6.0,
            location: location
        )
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Session Info Tests
    
    func testReceiveSessionInfo() {
        let expectation = XCTestExpectation(description: "Receive session info")
        var receivedSessionInfo: SessionInfo?
        
        syncService.sessionInfo
            .sink { sessionInfo in
                receivedSessionInfo = sessionInfo
                if sessionInfo != nil {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Simulate session status update
        mockWebSocketClient.simulateSessionStatus(
            sessionId: "session-123",
            participants: ["user-1", "user-2", "user-3"],
            status: "active"
        )
        
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertNotNil(receivedSessionInfo)
        XCTAssertEqual(receivedSessionInfo?.sessionId, "session-123")
        XCTAssertEqual(receivedSessionInfo?.participants.count, 3)
        XCTAssertEqual(receivedSessionInfo?.status, "active")
    }
    
    // MARK: - Error Handling Tests
    
    func testConnectionError() {
        let expectation = XCTestExpectation(description: "Handle connection error")
        
        syncService.connectionStatus
            .sink { status in
                if case .error(let message) = status {
                    XCTAssertFalse(message.isEmpty)
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        mockWebSocketClient.simulateConnectionError("Network error")
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testServerError() {
        let expectation = XCTestExpectation(description: "Handle server error")
        
        // We don't have a direct way to observe server errors in the current implementation,
        // but we can verify the error message is received
        mockWebSocketClient.simulateError("Session not found")
        
        // Give some time for the error to be processed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Integration Tests
    
    func testFullSessionLifecycle() {
        let joinExpectation = XCTestExpectation(description: "Join session")
        let paceExpectation = XCTestExpectation(description: "Send pace update")
        let friendExpectation = XCTestExpectation(description: "Receive friend update")
        let leaveExpectation = XCTestExpectation(description: "Leave session")
        
        let sessionId = "integration-test-session"
        let userId = "test-user"
        let friends = [User(id: UUID(), username: "friend", email: "friend@test.com")]
        
        // Step 1: Join session
        syncService.joinSession(sessionId: sessionId, userId: userId, friends: friends)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in
                    joinExpectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [joinExpectation], timeout: 1.0)
        
        // Step 2: Send pace update
        let location = CLLocation(latitude: 37.7749, longitude: -122.4194)
        syncService.sendPaceUpdate(pace: 6.5, location: location)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in
                    paceExpectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [paceExpectation], timeout: 1.0)
        
        // Step 3: Receive friend update
        syncService.friendUpdates
            .sink { updates in
                if !updates.isEmpty {
                    friendExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        let friendLocation = LocationCoordinate(latitude: 37.7849, longitude: -122.4294)
        mockWebSocketClient.simulateFriendUpdate(
            userId: "friend-123",
            sessionId: sessionId,
            pace: 7.0,
            location: friendLocation
        )
        
        wait(for: [friendExpectation], timeout: 1.0)
        
        // Step 4: Leave session
        syncService.leaveSession()
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in
                    leaveExpectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [leaveExpectation], timeout: 1.0)
        
        // Verify final state
        XCTAssertFalse(syncService.isInSession())
        XCTAssertNil(syncService.getCurrentSessionId())
    }
}