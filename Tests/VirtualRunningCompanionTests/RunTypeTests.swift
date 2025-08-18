import XCTest
@testable import VirtualRunningCompanion

final class RunTypeTests: XCTestCase {
    
    func testRunTypeEquality() {
        let sessionId = "test-session-123"
        let originalRunId = UUID()
        
        XCTAssertEqual(RunType.solo, RunType.solo)
        XCTAssertEqual(RunType.synchronized(sessionId: sessionId), RunType.synchronized(sessionId: sessionId))
        XCTAssertEqual(RunType.replay(originalRunId: originalRunId), RunType.replay(originalRunId: originalRunId))
        
        XCTAssertNotEqual(RunType.solo, RunType.synchronized(sessionId: sessionId))
        XCTAssertNotEqual(RunType.synchronized(sessionId: "session1"), RunType.synchronized(sessionId: "session2"))
        XCTAssertNotEqual(RunType.replay(originalRunId: UUID()), RunType.replay(originalRunId: UUID()))
    }
    
    func testRunTypeValidation_Solo() {
        let runType = RunType.solo
        XCTAssertNoThrow(try runType.validate())
    }
    
    func testRunTypeValidation_ValidSynchronized() {
        let runType = RunType.synchronized(sessionId: "valid-session-id")
        XCTAssertNoThrow(try runType.validate())
    }
    
    func testRunTypeValidation_EmptySessionId() {
        let runType = RunType.synchronized(sessionId: "")
        
        XCTAssertThrowsError(try runType.validate()) { error in
            XCTAssertEqual(error as? ValidationError, .emptySessionId)
        }
    }
    
    func testRunTypeValidation_WhitespaceSessionId() {
        let runType = RunType.synchronized(sessionId: "   ")
        
        XCTAssertThrowsError(try runType.validate()) { error in
            XCTAssertEqual(error as? ValidationError, .emptySessionId)
        }
    }
    
    func testRunTypeValidation_SessionIdTooLong() {
        let longSessionId = String(repeating: "a", count: 101)
        let runType = RunType.synchronized(sessionId: longSessionId)
        
        XCTAssertThrowsError(try runType.validate()) { error in
            XCTAssertEqual(error as? ValidationError, .sessionIdTooLong)
        }
    }
    
    func testRunTypeValidation_ValidReplay() {
        let runType = RunType.replay(originalRunId: UUID())
        XCTAssertNoThrow(try runType.validate())
    }
    
    func testRunTypeCodable_Solo() throws {
        let originalRunType = RunType.solo
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(originalRunType)
        let decodedRunType = try decoder.decode(RunType.self, from: data)
        
        XCTAssertEqual(originalRunType, decodedRunType)
    }
    
    func testRunTypeCodable_Synchronized() throws {
        let sessionId = "test-session-123"
        let originalRunType = RunType.synchronized(sessionId: sessionId)
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(originalRunType)
        let decodedRunType = try decoder.decode(RunType.self, from: data)
        
        XCTAssertEqual(originalRunType, decodedRunType)
        
        if case .synchronized(let decodedSessionId) = decodedRunType {
            XCTAssertEqual(decodedSessionId, sessionId)
        } else {
            XCTFail("Decoded run type should be synchronized")
        }
    }
    
    func testRunTypeCodable_Replay() throws {
        let originalRunId = UUID()
        let originalRunType = RunType.replay(originalRunId: originalRunId)
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(originalRunType)
        let decodedRunType = try decoder.decode(RunType.self, from: data)
        
        XCTAssertEqual(originalRunType, decodedRunType)
        
        if case .replay(let decodedRunId) = decodedRunType {
            XCTAssertEqual(decodedRunId, originalRunId)
        } else {
            XCTFail("Decoded run type should be replay")
        }
    }
    
    func testRunTypeJSONStructure_Solo() throws {
        let runType = RunType.solo
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        let data = try encoder.encode(runType)
        let jsonString = String(data: data, encoding: .utf8)!
        
        XCTAssertTrue(jsonString.contains("\"type\" : \"solo\""))
    }
    
    func testRunTypeJSONStructure_Synchronized() throws {
        let sessionId = "test-session-123"
        let runType = RunType.synchronized(sessionId: sessionId)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        let data = try encoder.encode(runType)
        let jsonString = String(data: data, encoding: .utf8)!
        
        XCTAssertTrue(jsonString.contains("\"type\" : \"synchronized\""))
        XCTAssertTrue(jsonString.contains("\"sessionId\" : \"\(sessionId)\""))
    }
    
    func testRunTypeJSONStructure_Replay() throws {
        let originalRunId = UUID()
        let runType = RunType.replay(originalRunId: originalRunId)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        let data = try encoder.encode(runType)
        let jsonString = String(data: data, encoding: .utf8)!
        
        XCTAssertTrue(jsonString.contains("\"type\" : \"replay\""))
        XCTAssertTrue(jsonString.contains("\"originalRunId\""))
    }
}