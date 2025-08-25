import Foundation

public enum ValidationError: Error, LocalizedError, Equatable {
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
        // User validation errors
        case .emptyUsername:
            return "Username cannot be empty"
        case .usernameTooShort:
            return "Username must be at least 3 characters long"
        case .usernameTooLong:
            return "Username cannot exceed 30 characters"
        case .invalidUsernameCharacters:
            return "Username can only contain letters, numbers, underscores, and hyphens"
        case .invalidEmail:
            return "Please enter a valid email address"
            
        // PacePoint validation errors
        case .invalidPace:
            return "Pace must be greater than 0"
        case .paceOutOfRange:
            return "Pace must be between 3 and 30 minutes per mile/km"
        case .invalidLocation:
            return "Invalid GPS coordinates"
        case .invalidHeartRate:
            return "Heart rate must be between 1 and 300 BPM"
            
        // RunSession validation errors
        case .negativeDistance:
            return "Distance cannot be negative"
        case .distanceTooLarge:
            return "Distance exceeds maximum allowed value"
        case .negativePace:
            return "Average pace cannot be negative"
        case .invalidTimeRange:
            return "End time must be after start time"
        case .runDurationTooLong:
            return "Run duration cannot exceed 24 hours"
        case .invalidRouteCoordinate:
            return "Route contains invalid GPS coordinates"
        case .synchronizedRunMissingParticipants:
            return "Synchronized runs must have at least one participant"
            
        // Friend validation errors
        case .negativeTotalRuns:
            return "Total runs cannot be negative"
        case .totalRunsTooHigh:
            return "Total runs exceeds reasonable limit"
        case .lastRunDateInFuture:
            return "Last run date cannot be in the future"
            
        // RunType validation errors
        case .emptySessionId:
            return "Session ID cannot be empty"
        case .sessionIdTooLong:
            return "Session ID is too long"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .emptyUsername, .usernameTooShort, .usernameTooLong, .invalidUsernameCharacters:
            return "Choose a username between 3-30 characters using only letters, numbers, underscores, and hyphens"
        case .invalidEmail:
            return "Enter an email in the format: example@domain.com"
        case .paceOutOfRange:
            return "Enter a realistic running pace between 3-30 minutes per mile/km"
        case .invalidHeartRate:
            return "Enter a heart rate between 1-300 BPM"
        case .distanceTooLarge:
            return "Distance should be reasonable for a single running session"
        case .runDurationTooLong:
            return "Consider splitting very long runs into multiple sessions"
        default:
            return nil
        }
    }
}