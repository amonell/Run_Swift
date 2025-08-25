import Foundation
#if canImport(CoreData)
import CoreData

extension RunSessionEntity {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<RunSessionEntity> {
        return NSFetchRequest<RunSessionEntity>(entityName: "RunSessionEntity")
    }
    
    @NSManaged public var id: UUID?
    @NSManaged public var userId: UUID?
    @NSManaged public var startTime: Date?
    @NSManaged public var endTime: Date?
    @NSManaged public var distance: Double
    @NSManaged public var averagePace: Double
    @NSManaged public var routeData: Data?
    @NSManaged public var pacePointsData: Data?
    @NSManaged public var typeData: Data?
    @NSManaged public var participantsData: Data?
    @NSManaged public var user: UserEntity?
}
#endif