import XCTest
@testable import VirtualRunningCompanion

final class RunSessionTests: XCTestCase {
    
    func testRunSessionInitialization() {
        let userId = UUID()
        let runSession = RunSession(userId: userId, type: .solo)
        
        XCTAssertEqual(runSession.userId, userId)
        XCTAssertEqual(runSession.type, .solo)
        XCTAssertEqual(runSession.distance, 0)
        XCTAssertEqual(runSession.averagePace, 0)
        XCTAssertTrue(runSession.route.isEmpty)
        XCTAssertTrue(runSession.paceData.isEmpty)
        XCTAssertNil(runSession.endTime)
        XCTAssertNil(runSession.participants)
        XCTAssertNotNil(runSession.id)
        XCTAssertNotNil(runSession.startTime)
    }
    
    func testRunSessionComputedProperties() {
        let userId = UUID()
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(3600) // 1 hour later
        
        let runSession = RunSession(userId: userId, startTime: startTime, endTime: endTime, type: .solo)
        
        XCTAssertEqual(runSession.duration!, 3600, accuracy: 0.1)
        XCTAssertTrue(runSession.isCompleted)
        
        let incompleteSession = RunSession(userId: userId, type: .solo)
        XCTAssertNil(incompleteSession.duration)
        XCTAssertFalse(incompleteSession.isCompleted)
    }
    
    func testRunSessionValidation_ValidSession() {
        let userId = UUID()
        let location = LocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let pacePoint = PacePoint(location: location, pace: 8.5)
        
        let runSession = RunSession(
            userId: userId,
            distance: 5000,
            averagePace: 8.5,
            route: [location],
            paceData: [pacePoint],
            type: .solo
        )
        
        XCTAssertNoThrow(try runSession.validate())
    }
    
    func testRunSessionValidation_NegativeDistance() {
        let userId = UUID()
        let runSession = RunSession(userId: userId, distance: -100, type: .solo)
        
        XCTAssertThrowsError(try runSession.validate()) { error in
            XCTAssertEqual(error as? ValidationError, .negativeDistance)
        }
    }
    
    func testRunSessionValidation_DistanceTooLarge() {
        let userId = UUID()
        let runSession = RunSession(userId: userId, distance: 600000, type: .solo) // 600km
        
        XCTAssertThrowsError(try runSession.validate()) { error in
            XCTAssertEqual(error as? ValidationError, .distanceTooLarge)
        }
    }
    
    func testRunSessionValidation_NegativePace() {
        let userId = UUID()
        let runSession = RunSession(userId: userId, averagePace: -5.0, type: .solo)
        
        XCTAssertThrowsError(try runSession.validate()) { error in
            XCTAssertEqual(error as? ValidationError, .negativePace)
        }
    }
    
    func testRunSessionValidation_PaceOutOfRange() {
        let userId = UUID()
        
        // Test pace too fast
        let fastPaceSession = RunSession(userId: userId, averagePace: 2.0, type: .solo)
        XCTAssertThrowsError(try fastPaceSession.validate()) { error in
            XCTAssertEqual(error as? ValidationError, .paceOutOfRange)
        }
        
        // Test pace too slow
        let slowPaceSession = RunSession(userId: userId, averagePace: 35.0, type: .solo)
        XCTAssertThrowsError(try slowPaceSession.validate()) { error in
            XCTAssertEqual(error as? ValidationError, .paceOutOfRange)
        }
    }
    
    func testRunSessionValidation_InvalidTimeRange() {
        let userId = UUID()
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(-3600) // End before start
        
        let runSession = RunSession(userId: userId, startTime: startTime, endTime: endTime, type: .solo)
        
        XCTAssertThrowsError(try runSession.validate()) { error in
            XCTAssertEqual(error as? ValidationError, .invalidTimeRange)
        }
    }
    
    func testRunSessionValidation_RunDurationTooLong() {
        let userId = UUID()
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(25 * 60 * 60) // 25 hours
        
        let runSession = RunSession(userId: userId, startTime: startTime, endTime: endTime, type: .solo)
        
        XCTAssertThrowsError(try runSession.validate()) { error in
            XCTAssertEqual(error as? ValidationError, .runDurationTooLong)
        }
    }
    
    func testRunSessionValidation_InvalidRouteCoordinate() {
        let userId = UUID()
        let invalidLocation = LocationCoordinate2D(latitude: 200, longitude: 200)
        
        let runSession = RunSession(userId: userId, route: [invalidLocation], type: .solo)
        
        XCTAssertThrowsError(try runSession.validate()) { error in
            XCTAssertEqual(error as? ValidationError, .invalidRouteCoordinate)
        }
    }
    
    func testRunSessionValidation_InvalidPaceData() {
        let userId = UUID()
        let invalidLocation = LocationCoordinate2D(latitude: 200, longitude: 200)
        let invalidPacePoint = PacePoint(location: invalidLocation, pace: 8.5)
        
        let runSession = RunSession(userId: userId, paceData: [invalidPacePoint], type: .solo)
        
        XCTAssertThrowsError(try runSession.validate()) { error in
            XCTAssertEqual(error as? ValidationError, .invalidLocation)
        }
    }
    
    func testRunSessionValidation_SynchronizedRunMissingParticipants() {
        let userId = UUID()
        let runSession = RunSession(userId: userId, type: .synchronized(sessionId: "test-session"))
        
        XCTAssertThrowsError(try runSession.validate()) { error in
            XCTAssertEqual(error as? ValidationError, .synchronizedRunMissingParticipants)
        }
    }
    
    func testRunSessionValidation_SynchronizedRunWithParticipants() {
        let userId = UUID()
        let participants = [UUID(), UUID()]
        let runSession = RunSession(userId: userId, type: .synchronized(sessionId: "test-session"), participants: participants)
        
        XCTAssertNoThrow(try runSession.validate())
    }
    
    func testRunSessionCodable() throws {
        let userId = UUID()
        let location = LocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let pacePoint = PacePoint(location: location, pace: 8.5, heartRate: 150)
        
        let originalSession = RunSession(
            userId: userId,
            distance: 5000,
            averagePace: 8.5,
            route: [location],
            paceData: [pacePoint],
            type: .solo
        )
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(originalSession)
        let decodedSession = try decoder.decode(RunSession.self, from: data)
        
        XCTAssertEqual(originalSession, decodedSession)
    }
    
    func testRunSessionCodable_SynchronizedType() throws {
        let userId = UUID()
        let participants = [UUID(), UUID()]
        let originalSession = RunSession(
            userId: userId,
            type: .synchronized(sessionId: "test-session"),
            participants: participants
        )
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(originalSession)
        let decodedSession = try decoder.decode(RunSession.self, from: data)
        
        XCTAssertEqual(originalSession, decodedSession)
    }
    
    func testRunSessionCodable_ReplayType() throws {
        let userId = UUID()
        let originalRunId = UUID()
        let originalSession = RunSession(
            userId: userId,
            type: .replay(originalRunId: originalRunId)
        )
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(originalSession)
        let decodedSession = try decoder.decode(RunSession.self, from: data)
        
        XCTAssertEqual(originalSession, decodedSession)
    }
    
    func testRunSessionEquality() {
        let userId = UUID()
        let sessionId = UUID()
        let startTime = Date()
        
        let session1 = RunSession(id: sessionId, userId: userId, startTime: startTime, type: .solo)
        let session2 = RunSession(id: sessionId, userId: userId, startTime: startTime, type: .solo)
        let session3 = RunSession(userId: userId, type: .solo)
        
        XCTAssertEqual(session1, session2)
        XCTAssertNotEqual(session1, session3)
    }
}