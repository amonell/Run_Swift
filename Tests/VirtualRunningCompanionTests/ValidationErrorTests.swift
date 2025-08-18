import XCTest
@testable import VirtualRunningCompanion

final class ValidationErrorTests: XCTestCase {
    
    func testValidationErrorEquality() {
        XCTAssertEqual(ValidationError.emptyUsername, ValidationError.emptyUsername)
        XCTAssertEqual(ValidationError.invalidEmail, ValidationError.invalidEmail)
        XCTAssertNotEqual(ValidationError.emptyUsername, ValidationError.invalidEmail)
    }
    
    func testUserValidationErrorDescriptions() {
        XCTAssertEqual(ValidationError.emptyUsername.errorDescription, "Username cannot be empty")
        XCTAssertEqual(ValidationError.usernameTooShort.errorDescription, "Username must be at least 3 characters long")
        XCTAssertEqual(ValidationError.usernameTooLong.errorDescription, "Username cannot exceed 30 characters")
        XCTAssertEqual(ValidationError.invalidUsernameCharacters.errorDescription, "Username can only contain letters, numbers, underscores, and hyphens")
        XCTAssertEqual(ValidationError.invalidEmail.errorDescription, "Please enter a valid email address")
    }
    
    func testPacePointValidationErrorDescriptions() {
        XCTAssertEqual(ValidationError.invalidPace.errorDescription, "Pace must be greater than 0")
        XCTAssertEqual(ValidationError.paceOutOfRange.errorDescription, "Pace must be between 3 and 30 minutes per mile/km")
        XCTAssertEqual(ValidationError.invalidLocation.errorDescription, "Invalid GPS coordinates")
        XCTAssertEqual(ValidationError.invalidHeartRate.errorDescription, "Heart rate must be between 1 and 300 BPM")
    }
    
    func testRunSessionValidationErrorDescriptions() {
        XCTAssertEqual(ValidationError.negativeDistance.errorDescription, "Distance cannot be negative")
        XCTAssertEqual(ValidationError.distanceTooLarge.errorDescription, "Distance exceeds maximum allowed value")
        XCTAssertEqual(ValidationError.negativePace.errorDescription, "Average pace cannot be negative")
        XCTAssertEqual(ValidationError.invalidTimeRange.errorDescription, "End time must be after start time")
        XCTAssertEqual(ValidationError.runDurationTooLong.errorDescription, "Run duration cannot exceed 24 hours")
        XCTAssertEqual(ValidationError.invalidRouteCoordinate.errorDescription, "Route contains invalid GPS coordinates")
        XCTAssertEqual(ValidationError.synchronizedRunMissingParticipants.errorDescription, "Synchronized runs must have at least one participant")
    }
    
    func testFriendValidationErrorDescriptions() {
        XCTAssertEqual(ValidationError.negativeTotalRuns.errorDescription, "Total runs cannot be negative")
        XCTAssertEqual(ValidationError.totalRunsTooHigh.errorDescription, "Total runs exceeds reasonable limit")
        XCTAssertEqual(ValidationError.lastRunDateInFuture.errorDescription, "Last run date cannot be in the future")
    }
    
    func testRunTypeValidationErrorDescriptions() {
        XCTAssertEqual(ValidationError.emptySessionId.errorDescription, "Session ID cannot be empty")
        XCTAssertEqual(ValidationError.sessionIdTooLong.errorDescription, "Session ID is too long")
    }
    
    func testValidationErrorRecoverySuggestions() {
        XCTAssertEqual(ValidationError.emptyUsername.recoverySuggestion, "Choose a username between 3-30 characters using only letters, numbers, underscores, and hyphens")
        XCTAssertEqual(ValidationError.usernameTooShort.recoverySuggestion, "Choose a username between 3-30 characters using only letters, numbers, underscores, and hyphens")
        XCTAssertEqual(ValidationError.usernameTooLong.recoverySuggestion, "Choose a username between 3-30 characters using only letters, numbers, underscores, and hyphens")
        XCTAssertEqual(ValidationError.invalidUsernameCharacters.recoverySuggestion, "Choose a username between 3-30 characters using only letters, numbers, underscores, and hyphens")
        
        XCTAssertEqual(ValidationError.invalidEmail.recoverySuggestion, "Enter an email in the format: example@domain.com")
        XCTAssertEqual(ValidationError.paceOutOfRange.recoverySuggestion, "Enter a realistic running pace between 3-30 minutes per mile/km")
        XCTAssertEqual(ValidationError.invalidHeartRate.recoverySuggestion, "Enter a heart rate between 1-300 BPM")
        XCTAssertEqual(ValidationError.distanceTooLarge.recoverySuggestion, "Distance should be reasonable for a single running session")
        XCTAssertEqual(ValidationError.runDurationTooLong.recoverySuggestion, "Consider splitting very long runs into multiple sessions")
    }
    
    func testValidationErrorNoRecoverySuggestion() {
        let errorsWithoutSuggestions: [ValidationError] = [
            .invalidPace,
            .invalidLocation,
            .negativeDistance,
            .negativePace,
            .invalidTimeRange,
            .invalidRouteCoordinate,
            .synchronizedRunMissingParticipants,
            .negativeTotalRuns,
            .totalRunsTooHigh,
            .lastRunDateInFuture,
            .emptySessionId,
            .sessionIdTooLong
        ]
        
        for error in errorsWithoutSuggestions {
            XCTAssertNil(error.recoverySuggestion, "Error \(error) should not have recovery suggestion")
        }
    }
    
    func testValidationErrorLocalizedError() {
        let error: Error = ValidationError.emptyUsername
        let localizedError = error as? LocalizedError
        
        XCTAssertNotNil(localizedError)
        XCTAssertEqual(localizedError?.errorDescription, "Username cannot be empty")
    }
    
    func testAllValidationErrorsHaveDescriptions() {
        let allErrors: [ValidationError] = [
            .emptyUsername, .usernameTooShort, .usernameTooLong, .invalidUsernameCharacters, .invalidEmail,
            .invalidPace, .paceOutOfRange, .invalidLocation, .invalidHeartRate,
            .negativeDistance, .distanceTooLarge, .negativePace, .invalidTimeRange, .runDurationTooLong,
            .invalidRouteCoordinate, .synchronizedRunMissingParticipants,
            .negativeTotalRuns, .totalRunsTooHigh, .lastRunDateInFuture,
            .emptySessionId, .sessionIdTooLong
        ]
        
        for error in allErrors {
            XCTAssertNotNil(error.errorDescription, "Error \(error) should have error description")
            XCTAssertFalse(error.errorDescription!.isEmpty, "Error description for \(error) should not be empty")
        }
    }
}