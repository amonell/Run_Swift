import Foundation
#if canImport(CoreLocation)
import CoreLocation
#endif
#if canImport(Combine)
import Combine
#endif

/// Protocol defining the location tracking service interface
#if canImport(Combine) && canImport(CoreLocation)
public protocol LocationTrackingServiceProtocol {
    func startTracking()
    func stopTracking()
    func getCurrentLocation() -> CLLocation?
    var locationUpdates: AnyPublisher<CLLocation, Never> { get }
    var paceUpdates: AnyPublisher<Double, Never> { get }
    var authorizationStatus: AnyPublisher<CLAuthorizationStatus, Never> { get }
    var isTracking: Bool { get }
}
#else
public protocol LocationTrackingServiceProtocol {
    func startTracking()
    func stopTracking()
    func getCurrentLocation() -> LocationCoordinate2D?
    var isTracking: Bool { get }
}
#endif

#if canImport(CoreLocation) && canImport(Combine)
/// Service responsible for GPS tracking, pace calculation, and location management
public class LocationTrackingService: NSObject, LocationTrackingServiceProtocol {
    
    // MARK: - Properties
    
    private let locationManager = CLLocationManager()
    private let locationSubject = PassthroughSubject<CLLocation, Never>()
    private let paceSubject = PassthroughSubject<Double, Never>()
    private let authorizationSubject = PassthroughSubject<CLAuthorizationStatus, Never>()
    
    private var previousLocation: CLLocation?
    private var previousTimestamp: Date?
    private var currentLocation: CLLocation?
    
    public private(set) var isTracking = false
    
    // MARK: - Publishers
    
    public var locationUpdates: AnyPublisher<CLLocation, Never> {
        locationSubject.eraseToAnyPublisher()
    }
    
    public var paceUpdates: AnyPublisher<Double, Never> {
        paceSubject.eraseToAnyPublisher()
    }
    
    public var authorizationStatus: AnyPublisher<CLAuthorizationStatus, Never> {
        authorizationSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    
    public override init() {
        super.init()
        setupLocationManager()
    }
    
    // MARK: - Private Setup
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5.0 // Update every 5 meters
        
        // Request permission if not already determined
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        
        // Emit current authorization status
        authorizationSubject.send(locationManager.authorizationStatus)
    }
    
    // MARK: - Public Methods
    
    public func startTracking() {
        guard !isTracking else { return }
        
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            isTracking = true
            locationManager.startUpdatingLocation()
            
            // Enable background location if authorized
            if locationManager.authorizationStatus == .authorizedAlways {
                locationManager.allowsBackgroundLocationUpdates = true
                locationManager.pausesLocationUpdatesAutomatically = false
            }
            
        case .denied, .restricted:
            // Handle permission denied case
            break
            
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
            
        @unknown default:
            break
        }
    }
    
    public func stopTracking() {
        guard isTracking else { return }
        
        isTracking = false
        locationManager.stopUpdatingLocation()
        locationManager.allowsBackgroundLocationUpdates = false
        
        // Reset tracking state
        previousLocation = nil
        previousTimestamp = nil
    }
    
    public func getCurrentLocation() -> CLLocation? {
        return currentLocation
    }
    
    // MARK: - Private Methods
    
    private func calculatePace(from previousLocation: CLLocation, to currentLocation: CLLocation, timeInterval: TimeInterval) -> Double {
        let distance = currentLocation.distance(from: previousLocation) // meters
        
        // Avoid division by zero and ensure minimum time interval
        guard timeInterval > 0.1, distance > 0 else { return 0.0 }
        
        // Calculate pace in minutes per kilometer
        let distanceInKm = distance / 1000.0
        let timeInMinutes = timeInterval / 60.0
        let pace = timeInMinutes / distanceInKm
        
        // Filter out unrealistic pace values (faster than 2 min/km or slower than 20 min/km)
        guard pace >= 2.0 && pace <= 20.0 else { return 0.0 }
        
        return pace
    }
    
    private func requestAlwaysAuthorization() {
        if locationManager.authorizationStatus == .authorizedWhenInUse {
            locationManager.requestAlwaysAuthorization()
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationTrackingService: CLLocationManagerDelegate {
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Filter out old or inaccurate locations
        guard location.timestamp.timeIntervalSinceNow > -5.0,
              location.horizontalAccuracy < 50.0,
              location.horizontalAccuracy > 0 else { return }
        
        currentLocation = location
        locationSubject.send(location)
        
        // Calculate pace if we have a previous location
        if let previousLoc = previousLocation,
           let previousTime = previousTimestamp {
            let timeInterval = location.timestamp.timeIntervalSince(previousTime)
            let pace = calculatePace(from: previousLoc, to: location, timeInterval: timeInterval)
            
            if pace > 0 {
                paceSubject.send(pace)
            }
        }
        
        // Update previous location and timestamp
        previousLocation = location
        previousTimestamp = location.timestamp
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Handle location errors
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                stopTracking()
            case .locationUnknown:
                // Continue trying to get location
                break
            case .network:
                // Network error, continue trying
                break
            default:
                break
            }
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationSubject.send(status)
        
        switch status {
        case .authorizedWhenInUse:
            // If tracking was requested, start it now
            if isTracking {
                locationManager.startUpdatingLocation()
            }
            
        case .authorizedAlways:
            // Enable background location updates
            if isTracking {
                locationManager.allowsBackgroundLocationUpdates = true
                locationManager.pausesLocationUpdatesAutomatically = false
                locationManager.startUpdatingLocation()
            }
            
        case .denied, .restricted:
            stopTracking()
            
        case .notDetermined:
            break
            
        @unknown default:
            break
        }
    }
}
#else
/// Stub implementation for platforms without CoreLocation
public class LocationTrackingService: LocationTrackingServiceProtocol {
    public private(set) var isTracking = false
    
    public func startTracking() {
        isTracking = true
    }
    
    public func stopTracking() {
        isTracking = false
    }
    
    public func getCurrentLocation() -> LocationCoordinate2D? {
        // Return a mock location for testing
        return LocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    }
}
#endif