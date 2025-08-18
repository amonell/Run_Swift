import XCTest
@testable import VirtualRunningCompanion

final class UserTests: XCTestCase {
    
    func testUserInitialization() {
        let user = User(username: "testuser", email: "test@example.com")
        
        XCTAssertEqual(user.username, "testuser")
        XCTAssertEqual(user.email, "test@example.com")
        XCTAssertNil(user.profileImageURL)
        XCTAssertNotNil(user.id)
        XCTAssertNotNil(user.createdAt)
    }
    
    func testUserValidation_ValidUser() {
        let user = User(username: "validuser", email: "valid@example.com")
        
        XCTAssertNoThrow(try user.validate())
    }
    
    func testUserValidation_EmptyUsername() {
        let user = User(username: "", email: "test@example.com")
        
        XCTAssertThrowsError(try user.validate()) { error in
            XCTAssertEqual(error as? ValidationError, .emptyUsername)
        }
    }
    
    func testUserValidation_WhitespaceUsername() {
        let user = User(username: "   ", email: "test@example.com")
        
        XCTAssertThrowsError(try user.validate()) { error in
            XCTAssertEqual(error as? ValidationError, .emptyUsername)
        }
    }
    
    func testUserValidation_UsernameTooShort() {
        let user = User(username: "ab", email: "test@example.com")
        
        XCTAssertThrowsError(try user.validate()) { error in
            XCTAssertEqual(error as? ValidationError, .usernameTooShort)
        }
    }
    
    func testUserValidation_UsernameTooLong() {
        let longUsername = String(repeating: "a", count: 31)
        let user = User(username: longUsername, email: "test@example.com")
        
        XCTAssertThrowsError(try user.validate()) { error in
            XCTAssertEqual(error as? ValidationError, .usernameTooLong)
        }
    }
    
    func testUserValidation_InvalidUsernameCharacters() {
        let user = User(username: "user@name", email: "test@example.com")
        
        XCTAssertThrowsError(try user.validate()) { error in
            XCTAssertEqual(error as? ValidationError, .invalidUsernameCharacters)
        }
    }
    
    func testUserValidation_ValidUsernameCharacters() {
        let validUsernames = ["user123", "user_name", "user-name", "User123"]
        
        for username in validUsernames {
            let user = User(username: username, email: "test@example.com")
            XCTAssertNoThrow(try user.validate(), "Username '\(username)' should be valid")
        }
    }
    
    func testUserValidation_InvalidEmail() {
        let invalidEmails = ["invalid", "invalid@", "@example.com", "invalid.email", "invalid@.com"]
        
        for email in invalidEmails {
            let user = User(username: "testuser", email: email)
            XCTAssertThrowsError(try user.validate(), "Email '\(email)' should be invalid") { error in
                XCTAssertEqual(error as? ValidationError, .invalidEmail)
            }
        }
    }
    
    func testUserValidation_ValidEmail() {
        let validEmails = ["test@example.com", "user.name@domain.co.uk", "user+tag@example.org"]
        
        for email in validEmails {
            let user = User(username: "testuser", email: email)
            XCTAssertNoThrow(try user.validate(), "Email '\(email)' should be valid")
        }
    }
    
    func testUserCodable() throws {
        let originalUser = User(username: "testuser", email: "test@example.com", profileImageURL: "https://example.com/image.jpg")
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(originalUser)
        let decodedUser = try decoder.decode(User.self, from: data)
        
        XCTAssertEqual(originalUser, decodedUser)
    }
    
    func testUserEquality() {
        let user1 = User(id: UUID(), username: "testuser", email: "test@example.com")
        let user2 = User(id: user1.id, username: "testuser", email: "test@example.com", createdAt: user1.createdAt)
        let user3 = User(username: "differentuser", email: "test@example.com")
        
        XCTAssertEqual(user1, user2)
        XCTAssertNotEqual(user1, user3)
    }
}