import XCTest
import Combine
@testable import VirtualRunningCompanion

final class UserRepositoryTests: XCTestCase {
    
    var persistenceController: PersistenceController!
    var userRepository: UserRepository!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        persistenceController = PersistenceController(inMemory: true)
        userRepository = UserRepository(persistenceController: persistenceController)
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        userRepository = nil
        persistenceController = nil
        super.tearDown()
    }
    
    func testSaveUser() {
        let user = User(username: "testuser", email: "test@example.com")
        let expectation = XCTestExpectation(description: "Save user")
        
        userRepository.save(user)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Save failed: \(error)")
                    }
                },
                receiveValue: { savedUser in
                    XCTAssertEqual(savedUser.id, user.id)
                    XCTAssertEqual(savedUser.username, user.username)
                    XCTAssertEqual(savedUser.email, user.email)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testFetchUserById() {
        let user = User(username: "fetchtest", email: "fetch@example.com")
        let expectation = XCTestExpectation(description: "Fetch user by ID")
        
        userRepository.save(user)
            .flatMap { savedUser in
                self.userRepository.fetch(by: savedUser.id)
            }
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Fetch failed: \(error)")
                    }
                },
                receiveValue: { fetchedUser in
                    XCTAssertNotNil(fetchedUser)
                    XCTAssertEqual(fetchedUser?.username, user.username)
                    XCTAssertEqual(fetchedUser?.email, user.email)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testFetchNonexistentUser() {
        let nonexistentId = UUID()
        let expectation = XCTestExpectation(description: "Fetch nonexistent user")
        
        userRepository.fetch(by: nonexistentId)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Fetch failed: \(error)")
                    }
                },
                receiveValue: { user in
                    XCTAssertNil(user)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testFetchAllUsers() {
        let users = [
            User(username: "user1", email: "user1@example.com"),
            User(username: "user2", email: "user2@example.com"),
            User(username: "user3", email: "user3@example.com")
        ]
        
        let expectation = XCTestExpectation(description: "Fetch all users")
        
        let savePublishers = users.map { userRepository.save($0) }
        
        Publishers.MergeMany(savePublishers)
            .collect()
            .flatMap { _ in
                self.userRepository.fetchAll()
            }
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Fetch all failed: \(error)")
                    }
                },
                receiveValue: { fetchedUsers in
                    XCTAssertEqual(fetchedUsers.count, users.count)
                    
                    let usernames = Set(fetchedUsers.map { $0.username })
                    let expectedUsernames = Set(users.map { $0.username })
                    XCTAssertEqual(usernames, expectedUsernames)
                    
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testUpdateUser() {
        let user = User(username: "originalname", email: "original@example.com")
        let expectation = XCTestExpectation(description: "Update user")
        
        userRepository.save(user)
            .flatMap { savedUser in
                let updatedUser = User(
                    id: savedUser.id,
                    username: "updatedname",
                    email: "updated@example.com",
                    profileImageURL: savedUser.profileImageURL,
                    createdAt: savedUser.createdAt
                )
                return self.userRepository.update(updatedUser)
            }
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Update failed: \(error)")
                    }
                },
                receiveValue: { updatedUser in
                    XCTAssertEqual(updatedUser.username, "updatedname")
                    XCTAssertEqual(updatedUser.email, "updated@example.com")
                    XCTAssertEqual(updatedUser.id, user.id)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testDeleteUser() {
        let user = User(username: "deletetest", email: "delete@example.com")
        let expectation = XCTestExpectation(description: "Delete user")
        
        userRepository.save(user)
            .flatMap { savedUser in
                self.userRepository.delete(by: savedUser.id)
            }
            .flatMap { _ in
                self.userRepository.fetch(by: user.id)
            }
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Delete operation failed: \(error)")
                    }
                },
                receiveValue: { deletedUser in
                    XCTAssertNil(deletedUser)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 5.0)
    }
}