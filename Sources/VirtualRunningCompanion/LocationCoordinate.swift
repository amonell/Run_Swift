import Foundation

// Linux-compatible replacement for CLLocationCoordinate2D
public struct LocationCoordinate2D: Codable, Equatable {
    public let latitude: Double
    public let longitude: Double
    
    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

// Helper function to validate coordinates (replacement for CLLocationCoordinate2DIsValid)
public func LocationCoordinate2DIsValid(_ coordinate: LocationCoordinate2D) -> Bool {
    return coordinate.latitude >= -90.0 && coordinate.latitude <= 90.0 &&
           coordinate.longitude >= -180.0 && coordinate.longitude <= 180.0
}