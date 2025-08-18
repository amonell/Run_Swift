import CoreData
import Foundation

@objc(FriendEntity)
public class FriendEntity: NSManagedObject {
    
    // MARK: - Convenience Initializer
    
    convenience init(context: NSManagedObjectContext, friend: Friend) {
        self.init(context: context)
        updateFromFriend(friend)
    }
    
    // MARK: - Conversion Methods
    
    func toFriend() -> Friend? {
        guard let userData = userData,
              let user = try? JSONDecoder().decode(User.self, from: userData),
              let friendStatus = decodeFriendStatus(from: statusData) else {
            return nil
        }
        
        return Friend(
            id: id ?? UUID(),
            user: user,
            status: friendStatus,
            isOnline: isOnline,
            lastRunDate: lastRunDate,
            totalRuns: Int(totalRuns)
        )
    }
    
    func updateFromFriend(_ friend: Friend) {
        self.id = friend.id
        self.userData = try? JSONEncoder().encode(friend.user)
        self.statusData = encodeFriendStatus(friend.status)
        self.isOnline = friend.isOnline
        self.lastRunDate = friend.lastRunDate
        self.totalRuns = Int32(friend.totalRuns)
    }
    
    // MARK: - Private Encoding/Decoding Methods
    
    private func encodeFriendStatus(_ status: FriendStatus) -> Data? {
        return try? JSONEncoder().encode(status)
    }
    
    private func decodeFriendStatus(from data: Data?) -> FriendStatus? {
        guard let data = data else { return nil }
        return try? JSONDecoder().decode(FriendStatus.self, from: data)
    }
}