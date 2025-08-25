#if canImport(CoreData)
import CoreData
#endif
import Foundation

@objc(UserEntity)
public class UserEntity: NSManagedObject {
    
    // MARK: - Convenience Initializer
    
    convenience init(context: NSManagedObjectContext, user: User) {
        self.init(context: context)
        self.id = user.id
        self.username = user.username
        self.email = user.email
        self.profileImageURL = user.profileImageURL
        self.createdAt = user.createdAt
    }
    
    // MARK: - Conversion Methods
    
    func toUser() -> User {
        return User(
            id: id ?? UUID(),
            username: username ?? "",
            email: email ?? "",
            profileImageURL: profileImageURL,
            createdAt: createdAt ?? Date()
        )
    }
    
    func updateFromUser(_ user: User) {
        self.id = user.id
        self.username = user.username
        self.email = user.email
        self.profileImageURL = user.profileImageURL
        self.createdAt = user.createdAt
    }
}