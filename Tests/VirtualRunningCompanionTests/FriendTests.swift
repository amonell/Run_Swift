import XCTest
@testable import VirtualRunningCompanion

final class FriendTests: XCTestCase {
    
    func testFriendInitialization() {
        let user = User(username: "testuser", email: "test@example.com")
        let friend = Friend(user: user, status: .accepted, isOnline: true, totalRuns: 10)
        
        XCTAssertEqual(friend.user, user)
        XCTAssertEqual(friend.status, .accepted)
        XCTAssertTrue(friend.isOnline)
        XCTAssertEqual(friend.totalRuns, 10)
        XCTAssertNil(friend.lastRunDate)
        XCTAssertNotNil(friend.id)
    }
    
    func testFriendValidation_ValidFriend() {
        let user = User(username: "testuser", email: "test@example.com")
        let friend = Friend(user: user, status: .accepted, lastRunDate: Date(), totalRuns: 5)
        
        XCTAssertNoThrow(try friend.validate())
    }
    
    func testFriendValidation_InvalidUser() {
        let invalidUser = User(username: "", email: "invalid-email")
        let friend = Friend(user: invalidUser, status: .accepted)
        
        XCTAssertThrowsError(try friend.validate()) { error in
            XCTAssertEqual(error as? ValidationError, .emptyUsername)
        }
    }
    
    func testFriendValidation_NegativeTotalRuns() {
        let user = User(username: "testuser", email: "test@example.com")
        let friend = Friend(user: user, status: .accepted, totalRuns: -5)
        
        XCTAssertThrowsError(try friend.validate()) { error in
            XCTAssertEqual(error as? ValidationError, .negativeTotalRuns)
        }
    }
    
    func testFriendValidation_TotalRunsTooHigh() {
        let user = User(username: "testuser", email: "test@example.com")
        let friend = Friend(user: user, status: .accepted, totalRuns: 150000)
        
        XCTAssertThrowsError(try friend.validate()) { error in
            XCTAssertEqual(error as? ValidationError, .totalRunsTooHigh)
        }
    }
    
    func testFriendValidation_LastRunDateInFuture() {
        let user = User(username: "testuser", email: "test@example.com")
        let futureDate = Date().addingTimeInterval(86400) // Tomorrow
        let friend = Friend(user: user, status: .accepted, lastRunDate: futureDate, totalRuns: 0)
        
        XCTAssertThrowsError(try friend.validate()) { error in
            XCTAssertEqual(error as? ValidationError, .lastRunDateInFuture)
        }
    }
    
    func testFriendValidation_ValidTotalRuns() {
        let user = User(username: "testuser", email: "test@example.com")
        
        let validTotalRuns = [0, 1, 100, 1000, 50000]
        for totalRuns in validTotalRuns {
            let friend = Friend(user: user, status: .accepted, totalRuns: totalRuns)
            XCTAssertNoThrow(try friend.validate(), "Total runs \(totalRuns) should be valid")
        }
    }
    
    func testFriendValidation_NoLastRunDate() {
        let user = User(username: "testuser", email: "test@example.com")
        let friend = Friend(user: user, status: .accepted, lastRunDate: nil)
        
        XCTAssertNoThrow(try friend.validate())
    }
    
    func testFriendCodable() throws {
        let user = User(username: "testuser", email: "test@example.com")
        let lastRunDate = Date()
        let originalFriend = Friend(
            user: user,
            status: .accepted,
            isOnline: true,
            lastRunDate: lastRunDate,
            totalRuns: 25
        )
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(originalFriend)
        let decodedFriend = try decoder.decode(Friend.self, from: data)
        
        XCTAssertEqual(originalFriend, decodedFriend)
    }
    
    func testFriendCodable_NoLastRunDate() throws {
        let user = User(username: "testuser", email: "test@example.com")
        let originalFriend = Friend(
            user: user,
            status: .pending,
            isOnline: false,
            lastRunDate: nil,
            totalRuns: 0
        )
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(originalFriend)
        let decodedFriend = try decoder.decode(Friend.self, from: data)
        
        XCTAssertEqual(originalFriend, decodedFriend)
        XCTAssertNil(decodedFriend.lastRunDate)
    }
    
    func testFriendEquality() {
        let userId = UUID()
        let createdAt = Date()
        let user1 = User(id: userId, username: "testuser", email: "test@example.com", createdAt: createdAt)
        let user2 = User(id: userId, username: "testuser", email: "test@example.com", createdAt: createdAt)
        let user3 = User(username: "differentuser", email: "different@example.com")
        
        let friendId = UUID()
        let friend1 = Friend(id: friendId, user: user1, status: .accepted)
        let friend2 = Friend(id: friendId, user: user2, status: .accepted)
        let friend3 = Friend(user: user3, status: .accepted)
        
        XCTAssertEqual(friend1, friend2)
        XCTAssertNotEqual(friend1, friend3)
    }
}