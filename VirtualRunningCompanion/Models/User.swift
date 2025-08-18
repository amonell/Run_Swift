import Foundation

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
        let emailRegex = "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        
        guard emailPredicate.evaluate(with: email) else {
            throw ValidationError.invalidEmail
        }
    }
}