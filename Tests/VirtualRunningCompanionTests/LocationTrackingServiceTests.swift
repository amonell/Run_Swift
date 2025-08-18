import XCTest
import CoreLocation
import Combine
@testable import VirtualRunningCompanion

final class LocationTrackingServiceTests: XCTestCase {
    
    var locationService: LocationTrackingService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        locationService = LocationTrackingService()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables.removeAll()
        locationService = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertFalse(locationService.isTracking)
        XCTAssertNil(locationService.getCurrentLocation())
    }
    
    // MARK: - Publisher Tests
    
    func testLocationUpdatesPublisher() {
        let expectation = XCTestExpectation(description: "Location updates publisher should be available")
        
        locationService.locationUpdates
            .sink { location in
                XCTAssertNotNil(location)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Simulate location update by calling the delegate method directly
        let testLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        locationService.locationManager(CLLocationManager(), didUpdateLocations: [testLocation])
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testPaceUpdatesPublisher() {
        let expectation = XCTestExpectation(description: "Pace updates publisher should emit values")
        
        locationService.paceUpdates
            .sink { pace in
                XCTAssertGreaterThan(pace, 0)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Simulate two location updates to trigger pace calculation
        let location1 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            timestamp: Date()
        )
        
        let location2 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7750, longitude: -122.4194),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            timestamp: Date().addingTimeInterval(30) // 30 seconds later
        )
        
        locationService.locationManager(CLLocationManager(), didUpdateLocations: [location1])
        locationService.locationManager(CLLocationManager(), didUpdateLocations: [location2])
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testAuthorizationStatusPublisher() {
        let expectation = XCTestExpectation(description: "Authorization status publisher should emit values")
        
        locationService.authorizationStatus
            .sink { status in
                XCTAssertNotNil(status)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Simulate authorization change
        locationService.locationManager(CLLocationManager(), didChangeAuthorization: .authorizedWhenInUse)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Location Filtering Tests
    
    func testLocationFiltering_OldLocation() {
        let expectation = XCTestExpectation(description: "Old locations should be filtered out")
        expectation.isInverted = true
        
        locationService.locationUpdates
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Create an old location (more than 5 seconds ago)
        let oldLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            timestamp: Date().addingTimeInterval(-10) // 10 seconds ago
        )
        
        locationService.locationManager(CLLocationManager(), didUpdateLocations: [oldLocation])
        
        wait(for: [expectation], timeout: 0.5)
    }
    
    func testLocationFiltering_InaccurateLocation() {
        let expectation = XCTestExpectation(description: "Inaccurate locations should be filtered out")
        expectation.isInverted = true
        
        locationService.locationUpdates
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Create an inaccurate location (horizontal accuracy > 50m)
        let inaccurateLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 0,
            horizontalAccuracy: 100, // Poor accuracy
            verticalAccuracy: 5,
            timestamp: Date()
        )
        
        locationService.locationManager(CLLocationManager(), didUpdateLocations: [inaccurateLocation])
        
        wait(for: [expectation], timeout: 0.5)
    }
    
    func testLocationFiltering_NegativeAccuracy() {
        let expectation = XCTestExpectation(description: "Locations with negative accuracy should be filtered out")
        expectation.isInverted = true
        
        locationService.locationUpdates
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Create a location with negative accuracy (invalid reading)
        let invalidLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 0,
            horizontalAccuracy: -1, // Invalid accuracy
            verticalAccuracy: 5,
            timestamp: Date()
        )
        
        locationService.locationManager(CLLocationManager(), didUpdateLocations: [invalidLocation])
        
        wait(for: [expectation], timeout: 0.5)
    }
    
    // MARK: - Pace Calculation Tests
    
    func testPaceCalculation_ValidMovement() {
        let expectation = XCTestExpectation(description: "Valid movement should produce reasonable pace")
        
        locationService.paceUpdates
            .sink { pace in
                // Expect pace between 2 and 20 minutes per km (reasonable running pace)
                XCTAssertGreaterThanOrEqual(pace, 2.0)
                XCTAssertLessThanOrEqual(pace, 20.0)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Simulate realistic running movement
        let startLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            timestamp: Date()
        )
        
        // Move approximately 100 meters in 30 seconds (12 km/h = 5 min/km pace)
        let endLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7758, longitude: -122.4194),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            timestamp: Date().addingTimeInterval(30)
        )
        
        locationService.locationManager(CLLocationManager(), didUpdateLocations: [startLocation])
        locationService.locationManager(CLLocationManager(), didUpdateLocations: [endLocation])
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testPaceCalculation_UnrealisticSpeed() {
        let expectation = XCTestExpectation(description: "Unrealistic speed should be filtered out")
        expectation.isInverted = true
        
        locationService.paceUpdates
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Simulate unrealistic movement (too fast - like driving)
        let startLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            timestamp: Date()
        )
        
        // Move 1km in 30 seconds (120 km/h = 0.5 min/km - unrealistic for running)
        let endLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7839, longitude: -122.4194),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            timestamp: Date().addingTimeInterval(30)
        )
        
        locationService.locationManager(CLLocationManager(), didUpdateLocations: [startLocation])
        locationService.locationManager(CLLocationManager(), didUpdateLocations: [endLocation])
        
        wait(for: [expectation], timeout: 0.5)
    }
    
    func testPaceCalculation_NoMovement() {
        let expectation = XCTestExpectation(description: "No movement should not produce pace updates")
        expectation.isInverted = true
        
        locationService.paceUpdates
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Simulate no movement (same location)
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            timestamp: Date()
        )
        
        locationService.locationManager(CLLocationManager(), didUpdateLocations: [location])
        locationService.locationManager(CLLocationManager(), didUpdateLocations: [location])
        
        wait(for: [expectation], timeout: 0.5)
    }
    
    // MARK: - Tracking State Tests
    
    func testStartTracking() {
        // Note: In a real test environment, we would need to mock CLLocationManager
        // For now, we test the basic state change
        XCTAssertFalse(locationService.isTracking)
        
        // This would normally start tracking if permissions are granted
        locationService.startTracking()
        
        // In a mocked environment, we would verify the tracking state
        // For now, we just ensure the method doesn't crash
        XCTAssertNotNil(locationService)
    }
    
    func testStopTracking() {
        locationService.stopTracking()
        XCTAssertFalse(locationService.isTracking)
        XCTAssertNil(locationService.getCurrentLocation())
    }
    
    // MARK: - Error Handling Tests
    
    func testLocationError_Denied() {
        let expectation = XCTestExpectation(description: "Location denied error should stop tracking")
        
        // Start tracking first
        locationService.startTracking()
        
        // Simulate location denied error
        let error = CLError(.denied)
        locationService.locationManager(CLLocationManager(), didFailWithError: error)
        
        // Verify tracking is stopped
        XCTAssertFalse(locationService.isTracking)
        expectation.fulfill()
        
        wait(for: [expectation], timeout: 0.5)
    }
    
    func testLocationError_Network() {
        // Simulate network error - should not stop tracking
        let error = CLError(.network)
        locationService.locationManager(CLLocationManager(), didFailWithError: error)
        
        // Tracking state should not change due to network error
        // (This test assumes tracking was not started, so it should remain false)
        XCTAssertFalse(locationService.isTracking)
    }
    
    // MARK: - Authorization Tests
    
    func testAuthorizationChange_WhenInUse() {
        let expectation = XCTestExpectation(description: "Authorization change should be published")
        
        locationService.authorizationStatus
            .sink { status in
                if status == .authorizedWhenInUse {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        locationService.locationManager(CLLocationManager(), didChangeAuthorization: .authorizedWhenInUse)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testAuthorizationChange_Always() {
        let expectation = XCTestExpectation(description: "Always authorization should be published")
        
        locationService.authorizationStatus
            .sink { status in
                if status == .authorizedAlways {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        locationService.locationManager(CLLocationManager(), didChangeAuthorization: .authorizedAlways)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testAuthorizationChange_Denied() {
        let expectation = XCTestExpectation(description: "Denied authorization should stop tracking")
        
        locationService.authorizationStatus
            .sink { status in
                if status == .denied {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        locationService.locationManager(CLLocationManager(), didChangeAuthorization: .denied)
        XCTAssertFalse(locationService.isTracking)
        
        wait(for: [expectation], timeout: 1.0)
    }
}