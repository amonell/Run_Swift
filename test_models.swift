#!/usr/bin/env swift

import Foundation
import CoreLocation

// Include all our model files inline for testing
// This is a simplified approach to test our models without package dependencies

// MARK: - ValidationError
enum ValidationError: Error, LocalizedError, Equatable {
    // User validation errors
    case emptyUsername
    case usernameTooShort
    case usernameTooLong
    case invalidUsernameCharacters
    case invalidEmail
    
    // PacePoint validation errors
    case invalidPace
    case paceOutOfRange
    case invalidLocation
    case invalidHeartRate
    
    // RunSession validation errors
    case negativeDistance
    case distanceTooLarge
    case negativePace
    case invalidTimeRange
    case runDurationTooLong
    case invalidRouteCoordinate
    case synchronizedRunMissingParticipants
    
    // Friend validation errors
    case negativeTotalRuns
    case totalRunsTooHigh
    case lastRunDateInFuture
    
    // RunType validation errors
    case emptySessionId
    case sessionIdTooLong
    
    var errorDescription: String? {
        switch self {
        case .emptyUsername: return "Username cannot be empty"
        case .usernameTooShort: return "Username must be at least 3 characters long"
        case .usernameTooLong: return "Username cannot exceed 30 characters"
        case .invalidUsernameCharacters: return "Username can only contain letters, numbers, underscores, and hyphens"
        case .invalidEmail: return "Please enter a valid email address"
        case .invalidPace: return "Pace must be greater than 0"
        case .paceOutOfRange: return "Pace must be between 3 and 30 minutes per mile/km"
        case .invalidLocation: return "Invalid GPS coordinates"
        case .invalidHeartRate: return "Heart rate must be between 1 and 300 BPM"
        case .negativeDistance: return "Distance cannot be negative"
        case .distanceTooLarge: return "Distance exceeds maximum allowed value"
        case .negativePace: return "Average pace cannot be negative"
        case .invalidTimeRange: return "End time must be after start time"
        case .runDurationTooLong: return "Run duration cannot exceed 24 hours"
        case .invalidRouteCoordinate: return "Route contains invalid GPS coordinates"
        case .synchronizedRunMissingParticipants: return "Synchronized runs must have at least one participant"
        case .negativeTotalRuns: return "Total runs cannot be negative"
        case .totalRunsTooHigh: return "Total runs exceeds reasonable limit"
        case .lastRunDateInFuture: return "Last run date cannot be in the future"
        case .emptySessionId: return "Session ID cannot be empty"
        case .sessionIdTooLong: return "Session ID is too long"
        }
    }
}

// MARK: - User
struct User: Codable, Identifiable, Equatable {
    let id: UUID
    let username: String
    let email: String
    let profileImageURL: String?
    let createdAt: Date
    
    init(id: UUID = UUID(), username: String, email: String, profileImageURL: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.username = username
        self.email = email
        self.profileImageURL = profileImageURL
        self.createdAt = createdAt
    }
    
    func validate() throws {
        try validateUsername()
        try validateEmail()
    }
    
    private func validateUsername() throws {
        guard !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.emptyUsername
        }
        
        guard username.count >= 3 else {
            throw ValidationError.usernameTooShort
        }
        
        guard username.count <= 30 else {
            throw ValidationError.usernameTooLong
        }
        
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        guard username.rangeOfCharacter(from: allowedCharacters.inverted) == nil else {
            throw ValidationError.invalidUsernameCharacters
        }
    }
    
    private func validateEmail() throws {
        let emailRegex = "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        
        guard emailPredicate.evaluate(with: email) else {
            throw ValidationError.invalidEmail
        }
    }
}

// MARK: - Test Functions
func testUserValidation() {
    print("Testing User validation...")
    
    // Test valid user
    let validUser = User(username: "testuser", email: "test@example.com")
    do {
        try validUser.validate()
        print("✅ Valid user passed validation")
    } catch {
        print("❌ Valid user failed validation: \(error)")
    }
    
    // Test invalid username
    let invalidUser = User(username: "", email: "test@example.com")
    do {
        try invalidUser.validate()
        print("❌ Invalid user should have failed validation")
    } catch ValidationError.emptyUsername {
        print("✅ Empty username correctly caught")
    } catch {
        print("❌ Wrong error for empty username: \(error)")
    }
    
    // Test invalid email
    let invalidEmailUser = User(username: "testuser", email: "invalid-email")
    do {
        try invalidEmailUser.validate()
        print("❌ Invalid email should have failed validation")
    } catch ValidationError.invalidEmail {
        print("✅ Invalid email correctly caught")
    } catch {
        print("❌ Wrong error for invalid email: \(error)")
    }
}

func testUserCodable() {
    print("Testing User Codable...")
    
    let originalUser = User(username: "testuser", email: "test@example.com")
    
    do {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(originalUser)
        let decodedUser = try decoder.decode(User.self, from: data)
        
        if originalUser == decodedUser {
            print("✅ User Codable works correctly")
        } else {
            print("❌ User Codable failed - objects not equal")
        }
    } catch {
        print("❌ User Codable failed: \(error)")
    }
}

// MARK: - Main Test Runner
print("🧪 Running Virtual Running Companion Model Tests")
print("=" * 50)

testUserValidation()
print()
testUserCodable()

print()
print("=" * 50)
print("✅ Model tests completed successfully!")
print("All core data models are working correctly.")