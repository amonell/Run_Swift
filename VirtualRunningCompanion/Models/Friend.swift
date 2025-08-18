import Foundation

struct Friend: Codable, Identifiable, Equatable {
    let id: UUID
    let user: User
    let status: FriendStatus
    let isOnline: Bool
    let lastRunDate: Date?
    let totalRuns: Int
    
    init(id: UUID = UUID(), user: User, status: FriendStatus, isOnline: Bool = false, 
         lastRunDate: Date? = nil, totalRuns: Int = 0) {
        self.id = id
        self.user = user
        self.status = status
        self.isOnline = isOnline
        self.lastRunDate = lastRunDate
        self.totalRuns = totalRuns
    }
    
    // MARK: - Validation
    
    func validate() throws {
        try user.validate()
        try validateTotalRuns()
        try validateLastRunDate()
    }
    
    private func validateTotalRuns() throws {
        guard totalRuns >= 0 else {
            throw ValidationError.negativeTotalRuns
        }
        
        // Reasonable upper limit for total runs
        guard totalRuns <= 100000 else {
            throw ValidationError.totalRunsTooHigh
        }
    }
    
    private func validateLastRunDate() throws {
        if let lastRunDate = lastRunDate {
            guard lastRunDate <= Date() else {
                throw ValidationError.lastRunDateInFuture
            }
        }
    }
}