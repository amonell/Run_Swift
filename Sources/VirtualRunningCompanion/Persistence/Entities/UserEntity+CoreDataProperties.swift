import CoreData
import Foundation

extension UserEntity {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<UserEntity> {
        return NSFetchRequest<UserEntity>(entityName: "UserEntity")
    }
    
    @NSManaged public var id: UUID?
    @NSManaged public var username: String?
    @NSManaged public var email: String?
    @NSManaged public var profileImageURL: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var friends: NSSet?
    @NSManaged public var runSessions: NSSet?
}