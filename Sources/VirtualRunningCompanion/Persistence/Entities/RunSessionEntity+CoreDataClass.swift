import Foundation
import CoreData

@objc(RunSessionEntity)
public class RunSessionEntity: NSManagedObject {
    
    // MARK: - Convenience Initializer
    
    convenience init(context: NSManagedObjectContext, runSession: RunSession) {
        self.init(context: context)
        updateFromRunSession(runSession)
    }
    
    // MARK: - Conversion Methods
    
    func toRunSession() -> RunSession {
        let routeCoordinates = decodeRoute(from: routeData)
        let pacePoints = decodePaceData(from: pacePointsData)
        let runType = decodeRunType(from: typeData)
        let participantUUIDs = decodeParticipants(from: participantsData)
        
        return RunSession(
            id: id ?? UUID(),
            userId: userId ?? UUID(),
            startTime: startTime ?? Date(),
            endTime: endTime,
            distance: distance,
            averagePace: averagePace,
            route: routeCoordinates,
            paceData: pacePoints,
            type: runType,
            participants: participantUUIDs
        )
    }
    
    func updateFromRunSession(_ runSession: RunSession) {
        self.id = runSession.id
        self.userId = runSession.userId
        self.startTime = runSession.startTime
        self.endTime = runSession.endTime
        self.distance = runSession.distance
        self.averagePace = runSession.averagePace
        self.routeData = encodeRoute(runSession.route)
        self.pacePointsData = encodePaceData(runSession.paceData)
        self.typeData = encodeRunType(runSession.type)
        self.participantsData = encodeParticipants(runSession.participants)
    }
    
    // MARK: - Private Encoding/Decoding Methods
    
    private func encodeRoute(_ route: [LocationCoordinate2D]) -> Data? {
        return try? JSONEncoder().encode(route)
    }
    
    private func decodeRoute(from data: Data?) -> [LocationCoordinate2D] {
        guard let data = data else { return [] }
        return (try? JSONDecoder().decode([LocationCoordinate2D].self, from: data)) ?? []
    }
    
    private func encodePaceData(_ paceData: [PacePoint]) -> Data? {
        return try? JSONEncoder().encode(paceData)
    }
    
    private func decodePaceData(from data: Data?) -> [PacePoint] {
        guard let data = data else { return [] }
        return (try? JSONDecoder().decode([PacePoint].self, from: data)) ?? []
    }
    
    private func encodeRunType(_ runType: RunType) -> Data? {
        return try? JSONEncoder().encode(runType)
    }
    
    private func decodeRunType(from data: Data?) -> RunType {
        guard let data = data else { return .solo }
        return (try? JSONDecoder().decode(RunType.self, from: data)) ?? .solo
    }
    
    private func encodeParticipants(_ participants: [UUID]?) -> Data? {
        guard let participants = participants else { return nil }
        return try? JSONEncoder().encode(participants)
    }
    
    private func decodeParticipants(from data: Data?) -> [UUID]? {
        guard let data = data else { return nil }
        return try? JSONDecoder().decode([UUID].self, from: data)
    }
}