import XCTest
import Combine
@testable import VirtualRunningCompanion

class WebSocketClientTests: XCTestCase {
    var webSocketClient: WebSocketClient!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        webSocketClient = WebSocketClient()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        webSocketClient?.disconnect()
        cancellables = nil
        webSocketClient = nil
        super.tearDown()
    }
    
    // MARK: - Connection Tests
    
    func testInitialConnectionStatus() {
        let expectation = XCTestExpectation(description: "Initial connection status is disconnected")
        
        webSocketClient.connectionStatus
            .first()
            .sink { status in
                XCTAssertEqual(status, .disconnected)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testIsConnectedInitiallyFalse() {
        XCTAssertFalse(webSocketClient.isConnected())
    }
    
    // MARK: - Message Encoding/Decoding Tests
    
    func testWebSocketMessageEncoding() {
        let joinData = JoinSessionData(
            sessionId: "test-session",
            userId: "test-user",
            friends: ["friend1", "friend2"]
        )
        
        do {
            let data = try JSONEncoder().encode(joinData)
            let message = WebSocketMessage(
                type: .joinSession,
                data: data,
                timestamp: Date()
            )
            
            // Test that message can be encoded
            let encodedMessage = try JSONEncoder().encode(message)
            XCTAssertFalse(encodedMessage.isEmpty)
            
            // Test that message can be decoded
            let decodedMessage = try JSONDecoder().decode(WebSocketMessage.self, from: encodedMessage)
            XCTAssertEqual(decodedMessage.type, .joinSession)
            
            // Test that data can be decoded back to original
            let decodedJoinData = try JSONDecoder().decode(JoinSessionData.self, from: decodedMessage.data)
            XCTAssertEqual(decodedJoinData.sessionId, "test-session")
            XCTAssertEqual(decodedJoinData.userId, "test-user")
            XCTAssertEqual(decodedJoinData.friends, ["friend1", "friend2"])
        } catch {
            XCTFail("Message encoding/decoding failed: \(error)")
        }
    }
    
    func testPaceUpdateDataEncoding() {
        let location = LocationCoordinate(latitude: 37.7749, longitude: -122.4194)
        let paceData = PaceUpdateData(
            userId: "test-user",
            sessionId: "test-session",
            pace: 6.5,
            location: location,
            timestamp: Date()
        )
        
        do {
            let data = try JSONEncoder().encode(paceData)
            let decodedData = try JSONDecoder().decode(PaceUpdateData.self, from: data)
            
            XCTAssertEqual(decodedData.userId, "test-user")
            XCTAssertEqual(decodedData.sessionId, "test-session")
            XCTAssertEqual(decodedData.pace, 6.5, accuracy: 0.01)
            XCTAssertEqual(decodedData.location.latitude, 37.7749, accuracy: 0.0001)
            XCTAssertEqual(decodedData.location.longitude, -122.4194, accuracy: 0.0001)
        } catch {
            XCTFail("PaceUpdateData encoding/decoding failed: \(error)")
        }
    }
    
    func testFriendUpdateDataEncoding() {
        let location = LocationCoordinate(latitude: 37.7749, longitude: -122.4194)
        let friendData = FriendUpdateData(
            userId: "friend-123",
            sessionId: "session-456",
            pace: 7.2,
            location: location,
            timestamp: Date(),
            status: "running"
        )
        
        do {
            let data = try JSONEncoder().encode(friendData)
            let decodedData = try JSONDecoder().decode(FriendUpdateData.self, from: data)
            
            XCTAssertEqual(decodedData.userId, "friend-123")
            XCTAssertEqual(decodedData.sessionId, "session-456")
            XCTAssertEqual(decodedData.pace, 7.2, accuracy: 0.01)
            XCTAssertEqual(decodedData.status, "running")
        } catch {
            XCTFail("FriendUpdateData encoding/decoding failed: \(error)")
        }
    }
    
    func testSessionStatusDataEncoding() {
        let statusData = SessionStatusData(
            sessionId: "session-789",
            participants: ["user1", "user2", "user3"],
            status: "active"
        )
        
        do {
            let data = try JSONEncoder().encode(statusData)
            let decodedData = try JSONDecoder().decode(SessionStatusData.self, from: data)
            
            XCTAssertEqual(decodedData.sessionId, "session-789")
            XCTAssertEqual(decodedData.participants, ["user1", "user2", "user3"])
            XCTAssertEqual(decodedData.status, "active")
        } catch {
            XCTFail("SessionStatusData encoding/decoding failed: \(error)")
        }
    }
    
    // MARK: - Message Type Tests
    
    func testMessageTypeRawValues() {
        XCTAssertEqual(WebSocketMessage.MessageType.joinSession.rawValue, "join_session")
        XCTAssertEqual(WebSocketMessage.MessageType.leaveSession.rawValue, "leave_session")
        XCTAssertEqual(WebSocketMessage.MessageType.paceUpdate.rawValue, "pace_update")
        XCTAssertEqual(WebSocketMessage.MessageType.friendUpdate.rawValue, "friend_update")
        XCTAssertEqual(WebSocketMessage.MessageType.sessionStatus.rawValue, "session_status")
        XCTAssertEqual(WebSocketMessage.MessageType.error.rawValue, "error")
        XCTAssertEqual(WebSocketMessage.MessageType.ping.rawValue, "ping")
        XCTAssertEqual(WebSocketMessage.MessageType.pong.rawValue, "pong")
    }
    
    func testMessageTypeDecoding() {
        let messageTypes: [WebSocketMessage.MessageType] = [
            .joinSession, .leaveSession, .paceUpdate, .friendUpdate,
            .sessionStatus, .error, .ping, .pong
        ]
        
        for messageType in messageTypes {
            do {
                let data = try JSONEncoder().encode(messageType)
                let decodedType = try JSONDecoder().decode(WebSocketMessage.MessageType.self, from: data)
                XCTAssertEqual(decodedType, messageType)
            } catch {
                XCTFail("Failed to encode/decode message type \(messageType): \(error)")
            }
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidMessageDecoding() {
        let invalidJSON = "{ invalid json }".data(using: .utf8)!
        
        XCTAssertThrowsError(try JSONDecoder().decode(WebSocketMessage.self, from: invalidJSON)) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }
    
    func testMissingFieldsDecoding() {
        let incompleteJSON = """
        {
            "type": "join_session",
            "timestamp": "2023-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!
        
        XCTAssertThrowsError(try JSONDecoder().decode(WebSocketMessage.self, from: incompleteJSON)) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }
    
    // MARK: - Data Model Validation Tests
    
    func testJoinSessionDataValidation() {
        let joinData = JoinSessionData(
            sessionId: "",
            userId: "",
            friends: []
        )
        
        // Should be able to encode empty values (validation happens at service level)
        XCTAssertNoThrow(try JSONEncoder().encode(joinData))
    }
    
    func testPaceUpdateDataValidation() {
        let location = LocationCoordinate(latitude: 0.0, longitude: 0.0)
        let paceData = PaceUpdateData(
            userId: "user",
            sessionId: "session",
            pace: -1.0, // Negative pace should be handled by service layer
            location: location,
            timestamp: Date()
        )
        
        XCTAssertNoThrow(try JSONEncoder().encode(paceData))
    }
    
    // MARK: - Performance Tests
    
    func testMessageEncodingPerformance() {
        let location = LocationCoordinate(latitude: 37.7749, longitude: -122.4194)
        let paceData = PaceUpdateData(
            userId: "test-user",
            sessionId: "test-session",
            pace: 6.5,
            location: location,
            timestamp: Date()
        )
        
        measure {
            for _ in 0..<1000 {
                do {
                    let data = try JSONEncoder().encode(paceData)
                    let message = WebSocketMessage(
                        type: .paceUpdate,
                        data: data,
                        timestamp: Date()
                    )
                    _ = try JSONEncoder().encode(message)
                } catch {
                    XCTFail("Encoding failed: \(error)")
                }
            }
        }
    }
    
    func testMessageDecodingPerformance() {
        let location = LocationCoordinate(latitude: 37.7749, longitude: -122.4194)
        let paceData = PaceUpdateData(
            userId: "test-user",
            sessionId: "test-session",
            pace: 6.5,
            location: location,
            timestamp: Date()
        )
        
        let data = try! JSONEncoder().encode(paceData)
        let message = WebSocketMessage(
            type: .paceUpdate,
            data: data,
            timestamp: Date()
        )
        let encodedMessage = try! JSONEncoder().encode(message)
        
        measure {
            for _ in 0..<1000 {
                do {
                    let decodedMessage = try JSONDecoder().decode(WebSocketMessage.self, from: encodedMessage)
                    _ = try JSONDecoder().decode(PaceUpdateData.self, from: decodedMessage.data)
                } catch {
                    XCTFail("Decoding failed: \(error)")
                }
            }
        }
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentMessageCreation() {
        let expectation = XCTestExpectation(description: "Concurrent message creation")
        expectation.expectedFulfillmentCount = 10
        
        let queue = DispatchQueue.global(qos: .userInitiated)
        
        for i in 0..<10 {
            queue.async {
                let location = LocationCoordinate(latitude: Double(i), longitude: Double(i))
                let paceData = PaceUpdateData(
                    userId: "user-\(i)",
                    sessionId: "session-\(i)",
                    pace: Double(i) + 5.0,
                    location: location,
                    timestamp: Date()
                )
                
                do {
                    let data = try JSONEncoder().encode(paceData)
                    let message = WebSocketMessage(
                        type: .paceUpdate,
                        data: data,
                        timestamp: Date()
                    )
                    _ = try JSONEncoder().encode(message)
                    expectation.fulfill()
                } catch {
                    XCTFail("Concurrent encoding failed: \(error)")
                }
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
}