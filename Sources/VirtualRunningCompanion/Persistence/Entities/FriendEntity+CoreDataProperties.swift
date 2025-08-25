import Foundation
import CoreData

extension FriendEntity {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<FriendEntity> {
        return NSFetchRequest<FriendEntity>(entityName: "FriendEntity")
    }
    
    @NSManaged public var id: UUID?
    @NSManaged public var userData: Data?
    @NSManaged public var statusData: Data?
    @NSManaged public var isOnline: Bool
    @NSManaged public var lastRunDate: Date?
    @NSManaged public var totalRuns: Int32
    @NSManaged public var owner: UserEntity?
}