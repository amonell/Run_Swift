import XCTest
@testable import VirtualRunningCompanion

final class FriendStatusTests: XCTestCase {
    
    func testFriendStatusRawValues() {
        XCTAssertEqual(FriendStatus.pending.rawValue, "pending")
        XCTAssertEqual(FriendStatus.accepted.rawValue, "accepted")
        XCTAssertEqual(FriendStatus.blocked.rawValue, "blocked")
    }
    
    func testFriendStatusDisplayNames() {
        XCTAssertEqual(FriendStatus.pending.displayName, "Pending")
        XCTAssertEqual(FriendStatus.accepted.displayName, "Friends")
        XCTAssertEqual(FriendStatus.blocked.displayName, "Blocked")
    }
    
    func testFriendStatusCanRunTogether() {
        XCTAssertFalse(FriendStatus.pending.canRunTogether)
        XCTAssertTrue(FriendStatus.accepted.canRunTogether)
        XCTAssertFalse(FriendStatus.blocked.canRunTogether)
    }
    
    func testFriendStatusCanSendMessages() {
        XCTAssertFalse(FriendStatus.pending.canSendMessages)
        XCTAssertTrue(FriendStatus.accepted.canSendMessages)
        XCTAssertFalse(FriendStatus.blocked.canSendMessages)
    }
    
    func testFriendStatusTransitions_FromPending() {
        let pending = FriendStatus.pending
        
        XCTAssertTrue(pending.canTransitionTo(.accepted))
        XCTAssertTrue(pending.canTransitionTo(.blocked))
        XCTAssertFalse(pending.canTransitionTo(.pending))
    }
    
    func testFriendStatusTransitions_FromAccepted() {
        let accepted = FriendStatus.accepted
        
        XCTAssertTrue(accepted.canTransitionTo(.blocked))
        XCTAssertFalse(accepted.canTransitionTo(.pending))
        XCTAssertFalse(accepted.canTransitionTo(.accepted))
    }
    
    func testFriendStatusTransitions_FromBlocked() {
        let blocked = FriendStatus.blocked
        
        XCTAssertTrue(blocked.canTransitionTo(.accepted))
        XCTAssertFalse(blocked.canTransitionTo(.pending))
        XCTAssertFalse(blocked.canTransitionTo(.blocked))
    }
    
    func testFriendStatusCodable() throws {
        let statuses: [FriendStatus] = [.pending, .accepted, .blocked]
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        for status in statuses {
            let data = try encoder.encode(status)
            let decodedStatus = try decoder.decode(FriendStatus.self, from: data)
            
            XCTAssertEqual(status, decodedStatus)
        }
    }
    
    func testFriendStatusCaseIterable() {
        let allCases = FriendStatus.allCases
        
        XCTAssertEqual(allCases.count, 3)
        XCTAssertTrue(allCases.contains(.pending))
        XCTAssertTrue(allCases.contains(.accepted))
        XCTAssertTrue(allCases.contains(.blocked))
    }
    
    func testFriendStatusFromRawValue() {
        XCTAssertEqual(FriendStatus(rawValue: "pending"), .pending)
        XCTAssertEqual(FriendStatus(rawValue: "accepted"), .accepted)
        XCTAssertEqual(FriendStatus(rawValue: "blocked"), .blocked)
        XCTAssertNil(FriendStatus(rawValue: "invalid"))
    }
    
    func testFriendStatusJSONSerialization() throws {
        let status = FriendStatus.accepted
        let encoder = JSONEncoder()
        
        let data = try encoder.encode(status)
        let jsonString = String(data: data, encoding: .utf8)!
        
        XCTAssertEqual(jsonString, "\"accepted\"")
    }
}