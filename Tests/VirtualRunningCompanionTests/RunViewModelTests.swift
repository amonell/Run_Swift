import XCTest
import Combine
import CoreLocation
@testable import VirtualRunningCompanion

@MainActor
final class RunViewModelTests: XCTestCase {
    var viewModel: RunViewModel!
    var mockLocationService: MockLocationTrackingService!
    var mockSyncService: MockRealTimeSyncService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockLocationService = MockLocationTrackingService()
        mockSyncService = MockRealTimeSyncService()
        viewModel = RunViewModel(locationService: mockLocationService, syncService: mockSyncService)
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        viewModel = nil
        mockSyncService = nil
        mockLocationService = nil
        super.tearDown()
    }
    
    func testInitialState() {
        XCTAssertFalse(viewModel.isRunning)
        XCTAssertFalse(viewModel.isPaused)
        XCTAssertEqual(viewModel.currentPace, 0)
        XCTAssertEqual(viewModel.currentDistance, 0)
        XCTAssertEqual(viewModel.elapsedTime, 0)
        XCTAssertTrue(viewModel.route.isEmpty)
        XCTAssertTrue(viewModel.friends.isEmpty)
        XCTAssertFalse(viewModel.isInSyncSession)
        XCTAssertTrue(viewModel.audioFeedbackEnabled)
    }
    
    func testStartRun() {
        viewModel.startRun()
        
        XCTAssertTrue(viewModel.isRunning)
        XCTAssertFalse(viewModel.isPaused)
        XCTAssertTrue(mockLocationService.startTrackingCalled)
    }
    
    func testPauseRun() {
        viewModel.startRun()
        viewModel.pauseRun()
        
        XCTAssertTrue(viewModel.isRunning)
        XCTAssertTrue(viewModel.isPaused)
    }
    
    func testResumeRun() {
        viewModel.startRun()
        viewModel.pauseRun()
        viewModel.resumeRun()
        
        XCTAssertTrue(viewModel.isRunning)
        XCTAssertFalse(viewModel.isPaused)
    }
    
    func testStopRun() {
        viewModel.startRun()
        viewModel.stopRun()
        
        XCTAssertFalse(viewModel.isRunning)
        XCTAssertFalse(viewModel.isPaused)
        XCTAssertTrue(mockLocationService.stopTrackingCalled)
    }
    
    func testLocationUpdate() {
        let expectation = XCTestExpectation(description: "Location update")
        
        viewModel.startRun()
        
        // Simulate location update
        let location = CLLocation(latitude: 37.7749, longitude: -122.4194)
        mockLocationService.simulateLocationUpdate(location)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(self.viewModel.currentLocation?.coordinate.latitude, location.coordinate.latitude)
            XCTAssertEqual(self.viewModel.currentLocation?.coordinate.longitude, location.coordinate.longitude)
            XCTAssertEqual(self.viewModel.route.count, 1)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testPaceUpdate() {
        let expectation = XCTestExpectation(description: "Pace update")
        
        viewModel.startRun()
        
        // Simulate pace update
        let pace = 6.5
        mockLocationService.simulatePaceUpdate(pace)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(self.viewModel.currentPace, pace)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testPaceColorCalculation() {
        // Test different pace scenarios
        viewModel.currentPace = 0
        XCTAssertEqual(viewModel.paceColor, .gray)
        
        viewModel.currentPace = 4.5
        XCTAssertEqual(viewModel.paceColor, .green)
        
        viewModel.currentPace = 6.0
        XCTAssertEqual(viewModel.paceColor, .yellow)
        
        viewModel.currentPace = 8.0
        XCTAssertEqual(viewModel.paceColor, .red)
    }
    
    func testSyncSessionPaceColor() {
        viewModel.isInSyncSession = true
        viewModel.targetPace = 6.0
        
        // Test pace within target range
        viewModel.currentPace = 6.2
        XCTAssertEqual(viewModel.paceColor, .green)
        
        // Test pace slightly off target
        viewModel.currentPace = 6.8
        XCTAssertEqual(viewModel.paceColor, .yellow)
        
        // Test pace significantly off target
        viewModel.currentPace = 7.5
        XCTAssertEqual(viewModel.paceColor, .red)
    }
    
    func testFormatting() {
        // Test pace formatting
        XCTAssertEqual(viewModel.formatPace(0), "--:--")
        XCTAssertEqual(viewModel.formatPace(6.5), "6:30")
        XCTAssertEqual(viewModel.formatPace(7.25), "7:15")
        
        // Test distance formatting
        XCTAssertEqual(viewModel.formatDistance(1000), "1.00 km")
        XCTAssertEqual(viewModel.formatDistance(2500), "2.50 km")
        
        // Test time formatting
        XCTAssertEqual(viewModel.formatTime(90), "1:30")
        XCTAssertEqual(viewModel.formatTime(3661), "1:01:01")
    }
    
    func testAveragePaceCalculation() {
        viewModel.elapsedTime = 600 // 10 minutes
        viewModel.currentDistance = 1500 // 1.5 km
        
        let expectedPace = (600 / 60.0) / 1.5 // 10 minutes / 1.5 km = 6.67 min/km
        XCTAssertEqual(viewModel.averagePace, expectedPace, accuracy: 0.01)
    }
    
    func testCalorieEstimation() {
        viewModel.currentDistance = 2000 // 2 km
        
        let expectedCalories = Int(2.0 * 65) // 2 km * 65 calories/km
        XCTAssertEqual(viewModel.estimatedCalories, expectedCalories)
    }
    
    func testEmergencyStop() {
        viewModel.emergencyStop()
        
        XCTAssertTrue(viewModel.showEmergencyAlert)
    }
    
    func testConfirmEmergencyStop() {
        viewModel.startRun()
        viewModel.confirmEmergencyStop()
        
        XCTAssertFalse(viewModel.isRunning)
        XCTAssertFalse(viewModel.showEmergencyAlert)
        XCTAssertTrue(mockLocationService.stopTrackingCalled)
    }
}

// MARK: - Mock Services

class MockLocationTrackingService: LocationTrackingServiceProtocol {
    private let locationSubject = PassthroughSubject<CLLocation, Never>()
    private let paceSubject = PassthroughSubject<Double, Never>()
    private let authorizationSubject = PassthroughSubject<CLAuthorizationStatus, Never>()
    
    var startTrackingCalled = false
    var stopTrackingCalled = false
    var isTracking = false
    
    var locationUpdates: AnyPublisher<CLLocation, Never> {
        locationSubject.eraseToAnyPublisher()
    }
    
    var paceUpdates: AnyPublisher<Double, Never> {
        paceSubject.eraseToAnyPublisher()
    }
    
    var authorizationStatus: AnyPublisher<CLAuthorizationStatus, Never> {
        authorizationSubject.eraseToAnyPublisher()
    }
    
    func startTracking() {
        startTrackingCalled = true
        isTracking = true
    }
    
    func stopTracking() {
        stopTrackingCalled = true
        isTracking = false
    }
    
    func getCurrentLocation() -> CLLocation? {
        return nil
    }
    
    func simulateLocationUpdate(_ location: CLLocation) {
        locationSubject.send(location)
    }
    
    func simulatePaceUpdate(_ pace: Double) {
        paceSubject.send(pace)
    }
}

class MockRealTimeSyncService: RealTimeSyncServiceProtocol {
    private let friendUpdatesSubject = CurrentValueSubject<[FriendRunUpdate], Never>([])
    private let connectionStatusSubject = CurrentValueSubject<ConnectionStatus, Never>(.disconnected)
    private let sessionInfoSubject = CurrentValueSubject<SessionInfo?, Never>(nil)
    
    var joinSessionCalled = false
    var leaveSessionCalled = false
    var sendPaceUpdateCalled = false
    
    var friendUpdates: AnyPublisher<[FriendRunUpdate], Never> {
        friendUpdatesSubject.eraseToAnyPublisher()
    }
    
    var connectionStatus: AnyPublisher<ConnectionStatus, Never> {
        connectionStatusSubject.eraseToAnyPublisher()
    }
    
    var sessionInfo: AnyPublisher<SessionInfo?, Never> {
        sessionInfoSubject.eraseToAnyPublisher()
    }
    
    func joinSession(sessionId: String, userId: String, friends: [User]) -> AnyPublisher<Void, Error> {
        joinSessionCalled = true
        return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    func leaveSession() -> AnyPublisher<Void, Error> {
        leaveSessionCalled = true
        return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    func sendPaceUpdate(pace: Double, location: CLLocation) -> AnyPublisher<Void, Error> {
        sendPaceUpdateCalled = true
        return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    func isInSession() -> Bool {
        return false
    }
    
    func getCurrentSessionId() -> String? {
        return nil
    }
}