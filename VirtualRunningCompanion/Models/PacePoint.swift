import Foundation
import CoreLocation

struct PacePoint: Codable, Equatable {
    let timestamp: Date
    let location: CLLocationCoordinate2D
    let pace: Double // minutes per mile/km
    let heartRate: Int?
    
    init(timestamp: Date = Date(), location: CLLocationCoordinate2D, pace: Double, heartRate: Int? = nil) {
        self.timestamp = timestamp
        self.location = location
        self.pace = pace
        self.heartRate = heartRate
    }
    
    // MARK: - Validation
    
    func validate() throws {
        try validatePace()
        try validateLocation()
        if let heartRate = heartRate {
            try validateHeartRate(heartRate)
        }
    }
    
    private func validatePace() throws {
        guard pace > 0 else {
            throw ValidationError.invalidPace
        }
        
        // Reasonable pace limits: 3 minutes/mile (extremely fast) to 30 minutes/mile (very slow walk)
        guard pace >= 3.0 && pace <= 30.0 else {
            throw ValidationError.paceOutOfRange
        }
    }
    
    private func validateLocation() throws {
        guard CLLocationCoordinate2DIsValid(location) else {
            throw ValidationError.invalidLocation
        }
    }
    
    private func validateHeartRate(_ heartRate: Int) throws {
        guard heartRate > 0 && heartRate <= 300 else {
            throw ValidationError.invalidHeartRate
        }
    }
}

// MARK: - Codable Implementation for CLLocationCoordinate2D
extension PacePoint {
    enum CodingKeys: String, CodingKey {
        case timestamp, location, pace, heartRate
    }
    
    enum LocationKeys: String, CodingKey {
        case latitude, longitude
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        pace = try container.decode(Double.self, forKey: .pace)
        heartRate = try container.decodeIfPresent(Int.self, forKey: .heartRate)
        
        let locationContainer = try container.nestedContainer(keyedBy: LocationKeys.self, forKey: .location)
        let latitude = try locationContainer.decode(Double.self, forKey: .latitude)
        let longitude = try locationContainer.decode(Double.self, forKey: .longitude)
        location = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(pace, forKey: .pace)
        try container.encodeIfPresent(heartRate, forKey: .heartRate)
        
        var locationContainer = container.nestedContainer(keyedBy: LocationKeys.self, forKey: .location)
        try locationContainer.encode(location.latitude, forKey: .latitude)
        try locationContainer.encode(location.longitude, forKey: .longitude)
    }
}