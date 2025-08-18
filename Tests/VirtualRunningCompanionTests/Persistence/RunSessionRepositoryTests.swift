import XCTest
import Combine
@testable import VirtualRunningCompanion

final class RunSessionRepositoryTests: XCTestCase {
    
    var persistenceController: PersistenceController!
    var runSessionRepository: RunSessionRepository!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        persistenceController = PersistenceController(inMemory: true)
        runSessionRepository = RunSessionRepository(persistenceController: persistenceController)
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        runSessionRepository = nil
        persistenceController = nil
        super.tearDown()
    }
    
    func testSaveRunSession() {
        let userId = UUID()
        let runSession = RunSession(
            userId: userId,
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600),
            distance: 5000,
            averagePace: 8.5,
            route: [
                LocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                LocationCoordinate2D(latitude: 37.7849, longitude: -122.4094)
            ],
            paceData: [
                PacePoint(timestamp: Date(), coordinate: LocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), pace: 8.0),
                PacePoint(timestamp: Date().addingTimeInterval(60), coordinate: LocationCoordinate2D(latitude: 37.7849, longitude: -122.4094), pace: 9.0)
            ],
            type: .solo
        )
        
        let expectation = XCTestExpectation(description: "Save run session")
        
        runSessionRepository.save(runSession)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Save failed: \(error)")
                    }
                },
                receiveValue: { savedSession in
                    XCTAssertEqual(savedSession.id, runSession.id)
                    XCTAssertEqual(savedSession.userId, runSession.userId)
                    XCTAssertEqual(savedSession.distance, runSession.distance)
                    XCTAssertEqual(savedSession.averagePace, runSession.averagePace)
                    XCTAssertEqual(savedSession.route.count, runSession.route.count)
                    XCTAssertEqual(savedSession.paceData.count, runSession.paceData.count)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testFetchRunSessionById() {
        let userId = UUID()
        let runSession = RunSession(
            userId: userId,
            startTime: Date(),
            distance: 3000,
            averagePace: 7.5,
            type: .solo
        )
        
        let expectation = XCTestExpectation(description: "Fetch run session by ID")
        
        runSessionRepository.save(runSession)
            .flatMap { savedSession in
                self.runSessionRepository.fetch(by: savedSession.id)
            }
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Fetch failed: \(error)")
                    }
                },
                receiveValue: { fetchedSession in
                    XCTAssertNotNil(fetchedSession)
                    XCTAssertEqual(fetchedSession?.userId, userId)
                    XCTAssertEqual(fetchedSession?.distance, 3000)
                    XCTAssertEqual(fetchedSession?.averagePace, 7.5)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testFetchRunSessionsByUser() {
        let userId = UUID()
        let otherUserId = UUID()
        
        let userSessions = [
            RunSession(userId: userId, distance: 1000, averagePace: 8.0, type: .solo),
            RunSession(userId: userId, distance: 2000, averagePace: 7.5, type: .solo),
            RunSession(userId: userId, distance: 3000, averagePace: 9.0, type: .solo)
        ]
        
        let otherUserSession = RunSession(userId: otherUserId, distance: 5000, averagePace: 6.0, type: .solo)
        
        let expectation = XCTestExpectation(description: "Fetch run sessions by user")
        
        let allSessions = userSessions + [otherUserSession]
        let savePublishers = allSessions.map { runSessionRepository.save($0) }
        
        Publishers.MergeMany(savePublishers)
            .collect()
            .flatMap { _ in
                self.runSessionRepository.fetchByUser(userId: userId)
            }
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Fetch by user failed: \(error)")
                    }
                },
                receiveValue: { fetchedSessions in
                    XCTAssertEqual(fetchedSessions.count, userSessions.count)
                    
                    for session in fetchedSessions {
                        XCTAssertEqual(session.userId, userId)
                    }
                    
                    // Check that sessions are sorted by start time (most recent first)
                    for i in 1..<fetchedSessions.count {
                        XCTAssertGreaterThanOrEqual(fetchedSessions[i-1].startTime, fetchedSessions[i].startTime)
                    }
                    
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testFetchRecentRunSessions() {
        let userId = UUID()
        let sessions = (0..<10).map { index in
            RunSession(
                userId: userId,
                startTime: Date().addingTimeInterval(TimeInterval(-index * 3600)), // Each session 1 hour apart
                distance: Double(1000 + index * 500),
                averagePace: 8.0,
                type: .solo
            )
        }
        
        let expectation = XCTestExpectation(description: "Fetch recent run sessions")
        
        let savePublishers = sessions.map { runSessionRepository.save($0) }
        
        Publishers.MergeMany(savePublishers)
            .collect()
            .flatMap { _ in
                self.runSessionRepository.fetchRecent(limit: 5)
            }
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Fetch recent failed: \(error)")
                    }
                },
                receiveValue: { recentSessions in
                    XCTAssertEqual(recentSessions.count, 5)
                    
                    // Check that sessions are sorted by start time (most recent first)
                    for i in 1..<recentSessions.count {
                        XCTAssertGreaterThanOrEqual(recentSessions[i-1].startTime, recentSessions[i].startTime)
                    }
                    
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testUpdateRunSession() {
        let userId = UUID()
        let runSession = RunSession(
            userId: userId,
            startTime: Date(),
            distance: 1000,
            averagePace: 8.0,
            type: .solo
        )
        
        let expectation = XCTestExpectation(description: "Update run session")
        
        runSessionRepository.save(runSession)
            .flatMap { savedSession in
                let updatedSession = RunSession(
                    id: savedSession.id,
                    userId: savedSession.userId,
                    startTime: savedSession.startTime,
                    endTime: Date(),
                    distance: 2000,
                    averagePace: 7.5,
                    route: savedSession.route,
                    paceData: savedSession.paceData,
                    type: savedSession.type,
                    participants: savedSession.participants
                )
                return self.runSessionRepository.update(updatedSession)
            }
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Update failed: \(error)")
                    }
                },
                receiveValue: { updatedSession in
                    XCTAssertEqual(updatedSession.distance, 2000)
                    XCTAssertEqual(updatedSession.averagePace, 7.5)
                    XCTAssertNotNil(updatedSession.endTime)
                    XCTAssertEqual(updatedSession.id, runSession.id)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testDeleteRunSession() {
        let userId = UUID()
        let runSession = RunSession(
            userId: userId,
            distance: 1000,
            averagePace: 8.0,
            type: .solo
        )
        
        let expectation = XCTestExpectation(description: "Delete run session")
        
        runSessionRepository.save(runSession)
            .flatMap { savedSession in
                self.runSessionRepository.delete(by: savedSession.id)
            }
            .flatMap { _ in
                self.runSessionRepository.fetch(by: runSession.id)
            }
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Delete operation failed: \(error)")
                    }
                },
                receiveValue: { deletedSession in
                    XCTAssertNil(deletedSession)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 5.0)
    }
}