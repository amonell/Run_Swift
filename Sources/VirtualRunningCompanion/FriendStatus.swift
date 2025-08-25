import Foundation

public enum FriendStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case accepted = "accepted"
    case blocked = "blocked"
    
    // MARK: - Display Properties
    
    var displayName: String {
        switch self {
        case .pending:
            return "Pending"
        case .accepted:
            return "Friends"
        case .blocked:
            return "Blocked"
        }
    }
    
    var canRunTogether: Bool {
        return self == .accepted
    }
    
    var canSendMessages: Bool {
        return self == .accepted
    }
    
    // MARK: - State Transitions
    
    func canTransitionTo(_ newStatus: FriendStatus) -> Bool {
        switch (self, newStatus) {
        case (.pending, .accepted), (.pending, .blocked):
            return true
        case (.accepted, .blocked):
            return true
        case (.blocked, .accepted):
            return true
        default:
            return false
        }
    }
}