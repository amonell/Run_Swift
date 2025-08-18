import XCTest
import Combine
import CoreLocation
@testable import VirtualRunningCompanion

class RunSessionManagerTests: XCTestCase {
    
    var runSessionManager: RunSessionManager!
    var mockLocationService: MockLocationTrackingService!
    var mockRepository: MockRunSessionRepository!
    var mockSyncService: MockRealTimeSyncService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockLocationService = MockLocationTrackingService()
        mockRepository = MockRunSessionRepository()
        mockSyncService = MockRealTimeSyncService()
        runSessionManager = RunSessionManager(
            locationService: mockLocationService,
            runSessionRepository: mockRepository,
            realTimeSyncService: mockSyncService
        )
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        runSessionManager = nil
        mockSyncService = nil
        mockRepository = nil
        mockLocationService = nil
        super.tearDown()
    }
    
    // MARK: - Start Run Tests
    
    func testStartSoloRun() {
        let expectation = XCTestExpectation(description: "Start solo run")
        let userId = UUID()
        
        runSessionManager.startRun(type: .solo, userId: userId)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Failed to start run: \(error)")
                    }
                },
                receiveValue: { session in
                    XCTAssertEqual(session.userId, userId)
                    XCTAssertEqual(session.type, .solo)
                    XCTAssertNil(session.endTime)
                    XCTAssertTrue(self.mockLocationService.isTracking)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testStartSynchronizedRun() {
        let expectation = XCTestExpectation(description: "Start synchronized run")
        let userId = UUID()
        let sessionId = "test-session-123"
        
        runSessionManager.startRun(type: .synchronized(sessionId: sessionId), userId: userId)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Failed to start synchronized run: \(error)")
                    }
                },
                receiveValue: { session in
                    XCTAssertEqual(session.userId, userId)
                    XCTAssertEqual(session.type, .synchronized(sessionId: sessionId))
                    XCTAssertTrue(self.mockLocationService.isTracking)
                    XCTAssertTrue(self.mockSyncService.joinSessionCalled)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testStartReplayRun() {
        let expectation = XCTestExpectation(description: "Start replay run")
        let userId = UUID()
        let originalRunId = UUID()
        
        runSessionManager.startRun(type: .replay(originalRunId: originalRunId), userId: userId)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Failed to start replay run: \(error)")
                    }
                },
                receiveValue: { session in
                    XCTAssertEqual(session.userId, userId)
                    XCTAssertEqual(session.type, .replay(originalRunId: originalRunId))
                    XCTAssertTrue(self.mockLocationService.isTracking)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testStartRunWhenAlreadyActive() {
        let expectation = XCTestExpectation(description: "Fail to start run when already active")
        let userId = UUID()
        
        // Start first run
        runSessionManager.startRun(type: .solo, userId: userId)
            .flatMap { _ in
                // Try to start second run
                self.runSessionManager.startRun(type: .solo, userId: userId)
            }
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTAssertTrue(error is RunSessionError)
                        if let runError = error as? RunSessionError,
                           case .sessionAlreadyActive = runError {
                            expectation.fulfill()
                        } else {
                            XCTFail("Expected sessionAlreadyActive error")
                        }
                    } else {
                        XCTFail("Expected failure when starting run while already active")
                    }
                },
                receiveValue: { _ in
                    XCTFail("Should not succeed when starting run while already active")
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Pause/Resume Tests
    
    func testPauseRun() {
        let expectation = XCTestExpectation(description: "Pause run")
        let userId = UUID()
        
        runSessionManager.startRun(type: .solo, userId: userId)
            .flatMap { _ in
                self.runSessionManager.pauseRun()
            }
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Failed to pause run: \(error)")
                    } else {
                        expectation.fulfill()
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
        
        // Verify state changes
        runSessionManager.sessionState
            .dropFirst() // Skip initial idle state
            .sink { state in
                if state == .paused {
                    // Additional verification can be done here
                }
            }
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testResumeRun() {
        let expectation = XCTestExpectation(description: "Resume run")
        let userId = UUID()
        
        runSessionManager.startRun(type: .solo, userId: userId)
            .flatMap { _ in
                self.runSessionManager.pauseRun()
            }
            .flatMap { _ in
                self.runSessionManager.resumeRun()
            }
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Failed to resume run: \(error)")
                    } else {
                        expectation.fulfill()
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testPauseRunWhenNotRunning() {
        let expectation = XCTestExpectation(description: "Fail to pause when not running")
        
        runSessionManager.pauseRun()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTAssertTrue(error is RunSessionError)
                        if let runError = error as? RunSessionError,
                           case .invalidStateTransition = runError {
                            expectation.fulfill()
                        } else {
                            XCTFail("Expected invalidStateTransition error")
                        }
                    } else {
                        XCTFail("Expected failure when pausing without active run")
                    }
                },
                receiveValue: { _ in
                    XCTFail("Should not succeed when pausing without active run")
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - End Run Tests
    
    func testEndRun() {
        let expectation = XCTestExpectation(description: "End run")
        let userId = UUID()
        
        // Simulate some location updates
        let location1 = CLLocation(latitude: 37.7749, longitude: -122.4194)
        let location2 = CLLocation(latitude: 37.7849, longitude: -122.4094)
        
        runSessionManager.startRun(type: .solo, userId: userId)
            .delay(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .handleEvents(receiveOutput: { _ in
                // Simulate location updates
                self.mockLocationService.simulateLocationUpdate(location1)
                self.mockLocationService.simulatePaceUpdate(5.0) // 5 min/km
            })
            .delay(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .handleEvents(receiveOutput: { _ in
                self.mockLocationService.simulateLocationUpdate(location2)
                self.mockLocationService.simulatePaceUpdate(4.8) // 4.8 min/km
            })
            .flatMap { _ in
                self.runSessionManager.endRun()
            }
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Failed to end run: \(error)")
                    }
                },
                receiveValue: { completedSession in
                    XCTAssertNotNil(completedSession.endTime)
                    XCTAssertTrue(completedSession.isCompleted)
                    XCTAssertGreaterThan(completedSession.distance, 0)
                    XCTAssertGreaterThan(completedSession.averagePace, 0)
                    XCTAssertFalse(self.mockLocationService.isTracking)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testEndRunWhenNotActive() {
        let expectation = XCTestExpectation(description: "Fail to end when not active")
        
        runSessionManager.endRun()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTAssertTrue(error is RunSessionError)
                        if let runError = error as? RunSessionError,
                           case .invalidStateTransition = runError {
                            expectation.fulfill()
                        } else {
                            XCTFail("Expected invalidStateTransition error")
                        }
                    } else {
                        XCTFail("Expected failure when ending without active run")
                    }
                },
                receiveValue: { _ in
                    XCTFail("Should not succeed when ending without active run")
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Session Recovery Tests
    
    func testRecoverSession() {
        let expectation = XCTestExpectation(description: "Recover session")
        let userId = UUID()
        
        // Create an incomplete session in the repository
        let incompleteSession = RunSession(
            userId: userId,
            startTime: Date().addingTimeInterval(-3600), // 1 hour ago
            endTime: nil, // Not completed
            distance: 1000,
            averagePace: 5.0,
            route: [LocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)],
            paceData: [PacePoint(timestamp: Date(), location: LocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), pace: 5.0, heartRate: nil)],
            type: .solo
        )
        
        mockRepository.sessions = [incompleteSession]
        
        runSessionManager.recoverSession()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Failed to recover session: \(error)")
                    }
                },
                receiveValue: { recoveredSession in
                    XCTAssertNotNil(recoveredSession)
                    XCTAssertEqual(recoveredSession?.id, incompleteSession.id)
                    XCTAssertFalse(recoveredSession?.isCompleted ?? true)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testRecoverSessionWhenNoneExists() {
        let expectation = XCTestExpectation(description: "No session to recover")
        
        // Repository has no incomplete sessions
        mockRepository.sessions = []
        
        runSessionManager.recoverSession()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Failed to check for recovery: \(error)")
                    }
                },
                receiveValue: { recoveredSession in
                    XCTAssertNil(recoveredSession)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - State Management Tests
    
    func testSessionStateTransitions() {
        let expectation = XCTestExpectation(description: "Session state transitions")
        let userId = UUID()
        var stateChanges: [RunSessionState] = []
        
        runSessionManager.sessionState
            .sink { state in
                stateChanges.append(state)
                if stateChanges.count == 4 { // idle -> starting -> running -> completed
                    XCTAssertEqual(stateChanges[0], .idle)
                    XCTAssertEqual(stateChanges[1], .starting)
                    XCTAssertEqual(stateChanges[2], .running)
                    XCTAssertEqual(stateChanges[3], .completed)
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        runSessionManager.startRun(type: .solo, userId: userId)
            .flatMap { _ in
                self.runSessionManager.endRun()
            }
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testCurrentSessionPublisher() {
        let expectation = XCTestExpectation(description: "Current session publisher")
        let userId = UUID()
        var sessionUpdates: [RunSession?] = []
        
        runSessionManager.currentSession
            .sink { session in
                sessionUpdates.append(session)
                if sessionUpdates.count == 3 { // nil -> session -> nil
                    XCTAssertNil(sessionUpdates[0])
                    XCTAssertNotNil(sessionUpdates[1])
                    XCTAssertNil(sessionUpdates[2])
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        runSessionManager.startRun(type: .solo, userId: userId)
            .flatMap { _ in
                self.runSessionManager.endRun()
            }
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 2.0)
    }
}

// MARK: - Mock Classes

class MockLocationTrackingService: LocationTrackingServiceProtocol {
    private let locationSubject = PassthroughSubject<CLLocation, Never>()
    private let paceSubject = PassthroughSubject<Double, Never>()
    private let authorizationSubject = CurrentValueSubject<CLAuthorizationStatus, Never>(.authorizedWhenInUse)
    
    private(set) var isTracking = false
    private var currentLocation: CLLocation?
    
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
        isTracking = true
    }
    
    func stopTracking() {
        isTracking = false
    }
    
    func getCurrentLocation() -> CLLocation? {
        return currentLocation
    }
    
    func simulateLocationUpdate(_ location: CLLocation) {
        currentLocation = location
        locationSubject.send(location)
    }
    
    func simulatePaceUpdate(_ pace: Double) {
        paceSubject.send(pace)
    }
}

class MockRunSessionRepository: RunSessionRepositoryProtocol {
    var sessions: [RunSession] = []
    var shouldFailSave = false
    var shouldFailFetch = false
    
    func save(_ runSession: RunSession) -> AnyPublisher<RunSession, Error> {
        if shouldFailSave {
            return Fail(error: NSError(domain: "MockError", code: 1, userInfo: nil))
                .eraseToAnyPublisher()
        }
        
        // Update existing or add new
        if let index = sessions.firstIndex(where: { $0.id == runSession.id }) {
            sessions[index] = runSession
        } else {
            sessions.append(runSession)
        }
        
        return Just(runSession)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func fetch(by id: UUID) -> AnyPublisher<RunSession?, Error> {
        if shouldFailFetch {
            return Fail(error: NSError(domain: "MockError", code: 1, userInfo: nil))
                .eraseToAnyPublisher()
        }
        
        let session = sessions.first { $0.id == id }
        return Just(session)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func fetchAll() -> AnyPublisher<[RunSession], Error> {
        if shouldFailFetch {
            return Fail(error: NSError(domain: "MockError", code: 1, userInfo: nil))
                .eraseToAnyPublisher()
        }
        
        return Just(sessions.sorted { $0.startTime > $1.startTime })
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func fetchByUser(userId: UUID) -> AnyPublisher<[RunSession], Error> {
        if shouldFailFetch {
            return Fail(error: NSError(domain: "MockError", code: 1, userInfo: nil))
                .eraseToAnyPublisher()
        }
        
        let userSessions = sessions.filter { $0.userId == userId }
        return Just(userSessions.sorted { $0.startTime > $1.startTime })
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func fetchRecent(limit: Int) -> AnyPublisher<[RunSession], Error> {
        if shouldFailFetch {
            return Fail(error: NSError(domain: "MockError", code: 1, userInfo: nil))
                .eraseToAnyPublisher()
        }
        
        let recentSessions = Array(sessions.sorted { $0.startTime > $1.startTime }.prefix(limit))
        return Just(recentSessions)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func delete(by id: UUID) -> AnyPublisher<Void, Error> {
        sessions.removeAll { $0.id == id }
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func update(_ runSession: RunSession) -> AnyPublisher<RunSession, Error> {
        return save(runSession)
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
        connectionStatusSubject.send(.connected)
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func leaveSession() -> AnyPublisher<Void, Error> {
        leaveSessionCalled = true
        connectionStatusSubject.send(.disconnected)
        sessionInfoSubject.send(nil)
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func sendPaceUpdate(pace: Double, location: CLLocation) -> AnyPublisher<Void, Error> {
        sendPaceUpdateCalled = true
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func isInSession() -> Bool {
        return sessionInfoSubject.value != nil
    }
    
    func getCurrentSessionId() -> String? {
        return sessionInfoSubject.value?.sessionId
    }
}