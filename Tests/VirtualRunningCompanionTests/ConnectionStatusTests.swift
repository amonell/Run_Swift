import XCTest
@testable import VirtualRunningCompanion

final class ConnectionStatusTests: XCTestCase {
    
    func testConnectionStatusEquality() {
        XCTAssertEqual(ConnectionStatus.connected, ConnectionStatus.connected)
        XCTAssertEqual(ConnectionStatus.connecting, ConnectionStatus.connecting)
        XCTAssertEqual(ConnectionStatus.disconnected, ConnectionStatus.disconnected)
        XCTAssertEqual(ConnectionStatus.error("test"), ConnectionStatus.error("test"))
        
        XCTAssertNotEqual(ConnectionStatus.connected, ConnectionStatus.connecting)
        XCTAssertNotEqual(ConnectionStatus.error("error1"), ConnectionStatus.error("error2"))
    }
    
    func testConnectionStatusDisplayNames() {
        XCTAssertEqual(ConnectionStatus.connected.displayName, "Connected")
        XCTAssertEqual(ConnectionStatus.connecting.displayName, "Connecting...")
        XCTAssertEqual(ConnectionStatus.disconnected.displayName, "Disconnected")
        XCTAssertEqual(ConnectionStatus.error("Network timeout").displayName, "Error: Network timeout")
    }
    
    func testConnectionStatusIsConnected() {
        XCTAssertTrue(ConnectionStatus.connected.isConnected)
        XCTAssertFalse(ConnectionStatus.connecting.isConnected)
        XCTAssertFalse(ConnectionStatus.disconnected.isConnected)
        XCTAssertFalse(ConnectionStatus.error("test").isConnected)
    }
    
    func testConnectionStatusCanStartSynchronizedRun() {
        XCTAssertTrue(ConnectionStatus.connected.canStartSynchronizedRun)
        XCTAssertFalse(ConnectionStatus.connecting.canStartSynchronizedRun)
        XCTAssertFalse(ConnectionStatus.disconnected.canStartSynchronizedRun)
        XCTAssertFalse(ConnectionStatus.error("test").canStartSynchronizedRun)
    }
    
    func testConnectionStatusErrorMessage() {
        XCTAssertNil(ConnectionStatus.connected.errorMessage)
        XCTAssertNil(ConnectionStatus.connecting.errorMessage)
        XCTAssertNil(ConnectionStatus.disconnected.errorMessage)
        XCTAssertEqual(ConnectionStatus.error("Network timeout").errorMessage, "Network timeout")
    }
    
    func testConnectionStatusErrorFromError() {
        struct TestError: Error, LocalizedError {
            var errorDescription: String? { "Test error occurred" }
        }
        
        let testError = TestError()
        let connectionStatus = ConnectionStatus.error(from: testError)
        
        if case .error(let message) = connectionStatus {
            XCTAssertEqual(message, "Test error occurred")
        } else {
            XCTFail("Should create error status")
        }
    }
    
    func testConnectionStatusCodable_Connected() throws {
        let originalStatus = ConnectionStatus.connected
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(originalStatus)
        let decodedStatus = try decoder.decode(ConnectionStatus.self, from: data)
        
        XCTAssertEqual(originalStatus, decodedStatus)
    }
    
    func testConnectionStatusCodable_Connecting() throws {
        let originalStatus = ConnectionStatus.connecting
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(originalStatus)
        let decodedStatus = try decoder.decode(ConnectionStatus.self, from: data)
        
        XCTAssertEqual(originalStatus, decodedStatus)
    }
    
    func testConnectionStatusCodable_Disconnected() throws {
        let originalStatus = ConnectionStatus.disconnected
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(originalStatus)
        let decodedStatus = try decoder.decode(ConnectionStatus.self, from: data)
        
        XCTAssertEqual(originalStatus, decodedStatus)
    }
    
    func testConnectionStatusCodable_Error() throws {
        let errorMessage = "Network connection failed"
        let originalStatus = ConnectionStatus.error(errorMessage)
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(originalStatus)
        let decodedStatus = try decoder.decode(ConnectionStatus.self, from: data)
        
        XCTAssertEqual(originalStatus, decodedStatus)
        
        if case .error(let decodedMessage) = decodedStatus {
            XCTAssertEqual(decodedMessage, errorMessage)
        } else {
            XCTFail("Decoded status should be error")
        }
    }
    
    func testConnectionStatusJSONStructure_Connected() throws {
        let status = ConnectionStatus.connected
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        let data = try encoder.encode(status)
        let jsonString = String(data: data, encoding: .utf8)!
        
        XCTAssertTrue(jsonString.contains("\"type\" : \"connected\""))
    }
    
    func testConnectionStatusJSONStructure_Error() throws {
        let errorMessage = "Network timeout"
        let status = ConnectionStatus.error(errorMessage)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        let data = try encoder.encode(status)
        let jsonString = String(data: data, encoding: .utf8)!
        
        XCTAssertTrue(jsonString.contains("\"type\" : \"error\""))
        XCTAssertTrue(jsonString.contains("\"errorMessage\" : \"\(errorMessage)\""))
    }
}