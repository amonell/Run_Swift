import Foundation

public struct User: Codable, Identifiable, Equatable {
    public let id: UUID
    public let username: String
    public let email: String
    public let profileImageURL: String?
    public let createdAt: Date
    
    public init(id: UUID = UUID(), username: String, email: String, profileImageURL: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.username = username
        self.email = email
        self.profileImageURL = profileImageURL
        self.createdAt = createdAt
    }
    
    // MARK: - Validation
    
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
        // Simple email validation for Linux compatibility
        guard email.contains("@") && email.contains(".") else {
            throw ValidationError.invalidEmail
        }
        
        let components = email.components(separatedBy: "@")
        guard components.count == 2,
              !components[0].isEmpty,
              !components[1].isEmpty,
              components[1].contains(".") else {
            throw ValidationError.invalidEmail
        }
        
        // Check that domain part doesn't start or end with dot
        let domain = components[1]
        guard !domain.hasPrefix(".") && !domain.hasSuffix(".") else {
            throw ValidationError.invalidEmail
        }
        
        // Check that there's at least one character after the last dot
        let domainParts = domain.components(separatedBy: ".")
        guard let lastPart = domainParts.last, !lastPart.isEmpty else {
            throw ValidationError.invalidEmail
        }
    }
}