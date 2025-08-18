import Foundation
import CoreLocation

struct RunSession: Codable, Identifiable, Equatable {
    let id: UUID
    let userId: UUID
    let startTime: Date
    let endTime: Date?
    let distance: Double // in meters
    let averagePace: Double // minutes per mile/km
    let route: [CLLocationCoordinate2D]
    let paceData: [PacePoint]
    let type: RunType
    let participants: [UUID]?
    
    init(id: UUID = UUID(), userId: UUID, startTime: Date = Date(), endTime: Date? = nil, 
         distance: Double = 0, averagePace: Double = 0, route: [CLLocationCoordinate2D] = [], 
         paceData: [PacePoint] = [], type: RunType, participants: [UUID]? = nil) {
        self.id = id
        self.userId = userId
        self.startTime = startTime
        self.endTime = endTime
        self.distance = distance
        self.averagePace = averagePace
        self.route = route
        self.paceData = paceData
        self.type = type
        self.participants = participants
    }
    
    // MARK: - Computed Properties
    
    var duration: TimeInterval? {
        guard let endTime = endTime else { return nil }
        return endTime.timeIntervalSince(startTime)
    }
    
    var isCompleted: Bool {
        return endTime != nil
    }
    
    // MARK: - Validation
    
    func validate() throws {
        try validateDistance()
        try validatePace()
        try validateTimeRange()
        try validateRoute()
        try validatePaceData()
        try validateParticipants()
    }
    
    private func validateDistance() throws {
        guard distance >= 0 else {
            throw ValidationError.negativeDistance
        }
        
        // Maximum reasonable distance for a single run (500km/310 miles)
        guard distance <= 500000 else {
            throw ValidationError.distanceTooLarge
        }
    }
    
    private func validatePace() throws {
        guard averagePace >= 0 else {
            throw ValidationError.negativePace
        }
        
        if averagePace > 0 {
            guard averagePace >= 3.0 && averagePace <= 30.0 else {
                throw ValidationError.paceOutOfRange
            }
        }
    }
    
    private func validateTimeRange() throws {
        if let endTime = endTime {
            guard endTime >= startTime else {
                throw ValidationError.invalidTimeRange
            }
            
            // Maximum reasonable run duration (24 hours)
            let maxDuration: TimeInterval = 24 * 60 * 60
            guard endTime.timeIntervalSince(startTime) <= maxDuration else {
                throw ValidationError.runDurationTooLong
            }
        }
    }
    
    private func validateRoute() throws {
        for coordinate in route {
            guard CLLocationCoordinate2DIsValid(coordinate) else {
                throw ValidationError.invalidRouteCoordinate
            }
        }
    }
    
    private func validatePaceData() throws {
        for pacePoint in paceData {
            try pacePoint.validate()
        }
    }
    
    private func validateParticipants() throws {
        switch type {
        case .synchronized:
            guard let participants = participants, !participants.isEmpty else {
                throw ValidationError.synchronizedRunMissingParticipants
            }
        case .solo, .replay:
            // Solo and replay runs shouldn't have participants
            break
        }
    }
}/
/ MARK: - Codable Implementation for CLLocationCoordinate2D Array
extension RunSession {
    enum CodingKeys: String, CodingKey {
        case id, userId, startTime, endTime, distance, averagePace, route, paceData, type, participants
    }
    
    enum RouteKeys: String, CodingKey {
        case latitude, longitude
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        startTime = try container.decode(Date.self, forKey: .startTime)
        endTime = try container.decodeIfPresent(Date.self, forKey: .endTime)
        distance = try container.decode(Double.self, forKey: .distance)
        averagePace = try container.decode(Double.self, forKey: .averagePace)
        paceData = try container.decode([PacePoint].self, forKey: .paceData)
        type = try container.decode(RunType.self, forKey: .type)
        participants = try container.decodeIfPresent([UUID].self, forKey: .participants)
        
        // Decode route coordinates
        var routeContainer = try container.nestedUnkeyedContainer(forKey: .route)
        var decodedRoute: [CLLocationCoordinate2D] = []
        
        while !routeContainer.isAtEnd {
            let coordinateContainer = try routeContainer.nestedContainer(keyedBy: RouteKeys.self)
            let latitude = try coordinateContainer.decode(Double.self, forKey: .latitude)
            let longitude = try coordinateContainer.decode(Double.self, forKey: .longitude)
            decodedRoute.append(CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
        }
        route = decodedRoute
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(startTime, forKey: .startTime)
        try container.encodeIfPresent(endTime, forKey: .endTime)
        try container.encode(distance, forKey: .distance)
        try container.encode(averagePace, forKey: .averagePace)
        try container.encode(paceData, forKey: .paceData)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(participants, forKey: .participants)
        
        // Encode route coordinates
        var routeContainer = container.nestedUnkeyedContainer(forKey: .route)
        for coordinate in route {
            var coordinateContainer = routeContainer.nestedContainer(keyedBy: RouteKeys.self)
            try coordinateContainer.encode(coordinate.latitude, forKey: .latitude)
            try coordinateContainer.encode(coordinate.longitude, forKey: .longitude)
        }
    }
}