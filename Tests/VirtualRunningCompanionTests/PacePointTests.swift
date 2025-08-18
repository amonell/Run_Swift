import XCTest
@testable import VirtualRunningCompanion

final class PacePointTests: XCTestCase {
    
    func testPacePointInitialization() {
        let location = LocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let pacePoint = PacePoint(location: location, pace: 8.5, heartRate: 150)
        
        XCTAssertEqual(pacePoint.location.latitude, 37.7749, accuracy: 0.0001)
        XCTAssertEqual(pacePoint.location.longitude, -122.4194, accuracy: 0.0001)
        XCTAssertEqual(pacePoint.pace, 8.5)
        XCTAssertEqual(pacePoint.heartRate, 150)
        XCTAssertNotNil(pacePoint.timestamp)
    }
    
    func testPacePointValidation_ValidData() {
        let location = LocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let pacePoint = PacePoint(location: location, pace: 8.5, heartRate: 150)
        
        XCTAssertNoThrow(try pacePoint.validate())
    }
    
    func testPacePointValidation_InvalidPace() {
        let location = LocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let pacePoint = PacePoint(location: location, pace: 0, heartRate: 150)
        
        XCTAssertThrowsError(try pacePoint.validate()) { error in
            XCTAssertEqual(error as? ValidationError, .invalidPace)
        }
    }
    
    func testPacePointValidation_PaceOutOfRange() {
        let location = LocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        
        // Test pace too fast
        let fastPacePoint = PacePoint(location: location, pace: 2.0, heartRate: 150)
        XCTAssertThrowsError(try fastPacePoint.validate()) { error in
            XCTAssertEqual(error as? ValidationError, .paceOutOfRange)
        }
        
        // Test pace too slow
        let slowPacePoint = PacePoint(location: location, pace: 35.0, heartRate: 150)
        XCTAssertThrowsError(try slowPacePoint.validate()) { error in
            XCTAssertEqual(error as? ValidationError, .paceOutOfRange)
        }
    }
    
    func testPacePointValidation_ValidPaceRange() {
        let location = LocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        
        let validPaces = [3.0, 8.5, 15.0, 30.0]
        for pace in validPaces {
            let pacePoint = PacePoint(location: location, pace: pace, heartRate: 150)
            XCTAssertNoThrow(try pacePoint.validate(), "Pace \(pace) should be valid")
        }
    }
    
    func testPacePointValidation_InvalidLocation() {
        let invalidLocation = LocationCoordinate2D(latitude: 200, longitude: 200)
        let pacePoint = PacePoint(location: invalidLocation, pace: 8.5, heartRate: 150)
        
        XCTAssertThrowsError(try pacePoint.validate()) { error in
            XCTAssertEqual(error as? ValidationError, .invalidLocation)
        }
    }
    
    func testPacePointValidation_InvalidHeartRate() {
        let location = LocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        
        // Test negative heart rate
        let negativeHRPoint = PacePoint(location: location, pace: 8.5, heartRate: -10)
        XCTAssertThrowsError(try negativeHRPoint.validate()) { error in
            XCTAssertEqual(error as? ValidationError, .invalidHeartRate)
        }
        
        // Test heart rate too high
        let highHRPoint = PacePoint(location: location, pace: 8.5, heartRate: 350)
        XCTAssertThrowsError(try highHRPoint.validate()) { error in
            XCTAssertEqual(error as? ValidationError, .invalidHeartRate)
        }
    }
    
    func testPacePointValidation_ValidHeartRate() {
        let location = LocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        
        let validHeartRates = [60, 120, 180, 250, 300]
        for heartRate in validHeartRates {
            let pacePoint = PacePoint(location: location, pace: 8.5, heartRate: heartRate)
            XCTAssertNoThrow(try pacePoint.validate(), "Heart rate \(heartRate) should be valid")
        }
    }
    
    func testPacePointValidation_NoHeartRate() {
        let location = LocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let pacePoint = PacePoint(location: location, pace: 8.5, heartRate: nil)
        
        XCTAssertNoThrow(try pacePoint.validate())
    }
    
    func testPacePointCodable() throws {
        let location = LocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let originalPacePoint = PacePoint(location: location, pace: 8.5, heartRate: 150)
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(originalPacePoint)
        let decodedPacePoint = try decoder.decode(PacePoint.self, from: data)
        
        XCTAssertEqual(originalPacePoint, decodedPacePoint)
    }
    
    func testPacePointCodable_NoHeartRate() throws {
        let location = LocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let originalPacePoint = PacePoint(location: location, pace: 8.5, heartRate: nil)
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(originalPacePoint)
        let decodedPacePoint = try decoder.decode(PacePoint.self, from: data)
        
        XCTAssertEqual(originalPacePoint, decodedPacePoint)
        XCTAssertNil(decodedPacePoint.heartRate)
    }
    
    func testPacePointEquality() {
        let location1 = LocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let location2 = LocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let location3 = LocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        
        let timestamp = Date()
        let pacePoint1 = PacePoint(timestamp: timestamp, location: location1, pace: 8.5, heartRate: 150)
        let pacePoint2 = PacePoint(timestamp: timestamp, location: location2, pace: 8.5, heartRate: 150)
        let pacePoint3 = PacePoint(timestamp: timestamp, location: location3, pace: 8.5, heartRate: 150)
        
        XCTAssertEqual(pacePoint1, pacePoint2)
        XCTAssertNotEqual(pacePoint1, pacePoint3)
    }
}