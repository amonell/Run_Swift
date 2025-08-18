import XCTest
import Combine
@testable import VirtualRunningCompanion

final class OfflineDataManagerTests: XCTestCase {
    
    var persistenceController: PersistenceController!
    var offlineDataManager: OfflineDataManager!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        persistenceController = PersistenceController(inMemory: true)
        offlineDataManager = OfflineDataManager(persistenceController: persistenceController)
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        offlineDataManager = nil
        persistenceController = nil
        super.tearDown()
    }
    
    func testCacheRunSession() {
        let userId = UUID()
        let runSession = RunSession(
            userId: userId,
            distance: 5000,
            averagePace: 8.0,
            type: .solo
        )
        
        let expectation = XCTestExpectation(description: "Cache run session")
        
        offlineDataManager.cacheRunSession(runSession)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Cache failed: \(error)")
                    }
                },
                receiveValue: { _ in
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testCacheUser() {
        let user = User(username: "cachetest", email: "cache@example.com")
        let expectation = XCTestExpectation(description: "Cache user")
        
        offlineDataManager.cacheUser(user)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Cache failed: \(error)")
                    }
                },
                receiveValue: { _ in
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testCacheFriend() {
        let user = User(username: "frienduser", email: "friend@example.com")
        let friend = Friend(user: user, status: .accepted, isOnline: true, totalRuns: 10)
        let userId = UUID()
        
        let expectation = XCTestExpectation(description: "Cache friend")
        
        // First cache the user, then the friend
        offlineDataManager.cacheUser(User(id: userId, username: "owner", email: "owner@example.com"))
            .flatMap { _ in
                self.offlineDataManager.cacheFriend(friend, for: userId)
            }
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Cache failed: \(error)")
                    }
                },
                receiveValue: { _ in
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testGetCachedRunSessions() {
        let userId = UUID()
        let runSessions = [
            RunSession(userId: userId, distance: 1000, averagePace: 8.0, type: .solo),
            RunSession(userId: userId, distance: 2000, averagePace: 7.5, type: .solo),
            RunSession(userId: userId, distance: 3000, averagePace: 9.0, type: .solo)
        ]
        
        let expectation = XCTestExpectation(description: "Get cached run sessions")
        
        let cachePublishers = runSessions.map { offlineDataManager.cacheRunSession($0) }
        
        Publishers.MergeMany(cachePublishers)
            .collect()
            .flatMap { _ in
                self.offlineDataManager.getCachedRunSessions(for: userId)
            }
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Get cached sessions failed: \(error)")
                    }
                },
                receiveValue: { cachedSessions in
                    XCTAssertEqual(cachedSessions.count, runSessions.count)
                    
                    for session in cachedSessions {
                        XCTAssertEqual(session.userId, userId)
                    }
                    
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testGetCachedFriends() {
        let userId = UUID()
        let user = User(id: userId, username: "owner", email: "owner@example.com")
        
        let friends = [
            Friend(user: User(username: "friend1", email: "friend1@example.com"), status: .accepted, isOnline: true),
            Friend(user: User(username: "friend2", email: "friend2@example.com"), status: .accepted, isOnline: false),
            Friend(user: User(username: "friend3", email: "friend3@example.com"), status: .pending, isOnline: false)
        ]
        
        let expectation = XCTestExpectation(description: "Get cached friends")
        
        offlineDataManager.cacheUser(user)
            .flatMap { _ in
                let cacheFriendPublishers = friends.map { self.offlineDataManager.cacheFriend($0, for: userId) }
                return Publishers.MergeMany(cacheFriendPublishers).collect()
            }
            .flatMap { _ in
                self.offlineDataManager.getCachedFriends(for: userId)
            }
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Get cached friends failed: \(error)")
                    }
                },
                receiveValue: { cachedFriends in
                    XCTAssertEqual(cachedFriends.count, friends.count)
                    
                    let cachedUsernames = Set(cachedFriends.map { $0.user.username })
                    let expectedUsernames = Set(friends.map { $0.user.username })
                    XCTAssertEqual(cachedUsernames, expectedUsernames)
                    
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testGetCachedUser() {
        let user = User(username: "cacheduser", email: "cached@example.com")
        let expectation = XCTestExpectation(description: "Get cached user")
        
        offlineDataManager.cacheUser(user)
            .flatMap { _ in
                self.offlineDataManager.getCachedUser(by: user.id)
            }
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Get cached user failed: \(error)")
                    }
                },
                receiveValue: { cachedUser in
                    XCTAssertNotNil(cachedUser)
                    XCTAssertEqual(cachedUser?.username, user.username)
                    XCTAssertEqual(cachedUser?.email, user.email)
                    XCTAssertEqual(cachedUser?.id, user.id)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testMarkForSync() {
        let syncItem = SyncableItem(
            id: UUID(),
            type: .runSession,
            operation: .create,
            data: Data()
        )
        
        let initialCount = offlineDataManager.pendingSyncCount
        
        offlineDataManager.markForSync(syncItem)
        
        // Give some time for the async operation to complete
        let expectation = XCTestExpectation(description: "Sync count updated")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            XCTAssertGreaterThan(self.offlineDataManager.pendingSyncCount, initialCount)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testProcessPendingSync() {
        let syncItem = SyncableItem(
            id: UUID(),
            type: .user,
            operation: .update,
            data: Data()
        )
        
        offlineDataManager.markForSync(syncItem)
        
        let expectation = XCTestExpectation(description: "Process pending sync")
        
        // Wait a bit for the mark operation to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.offlineDataManager.processPendingSync()
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            XCTFail("Process pending sync failed: \(error)")
                        }
                    },
                    receiveValue: { _ in
                        XCTAssertEqual(self.offlineDataManager.pendingSyncCount, 0)
                        expectation.fulfill()
                    }
                )
                .store(in: &self.cancellables)
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testClearCache() {
        let user = User(username: "cleartest", email: "clear@example.com")
        let runSession = RunSession(userId: user.id, distance: 1000, averagePace: 8.0, type: .solo)
        
        let expectation = XCTestExpectation(description: "Clear cache")
        
        offlineDataManager.cacheUser(user)
            .flatMap { _ in
                self.offlineDataManager.cacheRunSession(runSession)
            }
            .flatMap { _ in
                self.offlineDataManager.clearCache()
            }
            .flatMap { _ in
                self.offlineDataManager.getCachedUser(by: user.id)
            }
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Clear cache operation failed: \(error)")
                    }
                },
                receiveValue: { clearedUser in
                    XCTAssertNil(clearedUser)
                    XCTAssertEqual(self.offlineDataManager.pendingSyncCount, 0)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 10.0)
    }
}