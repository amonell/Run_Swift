import Foundation
import CoreLocation
import Combine

/// Enum representing the current state of a run session
public enum RunSessionState: Equatable {
    case idle
    case starting
    case running
    case paused
    case ending
    case completed
    case error(String)
}

/// Protocol defining the run session manager interface
public protocol RunSessionManagerProtocol {
    func startRun(type: RunType, userId: UUID) -> AnyPublisher<RunSession, Error>
    func pauseRun() -> AnyPublisher<Void, Error>
    func resumeRun() -> AnyPublisher<Void, Error>
    func endRun() -> AnyPublisher<RunSession, Error>
    func recoverSession() -> AnyPublisher<RunSession?, Error>
    
    var currentSession: AnyPublisher<RunSession?, Never> { get }
    var sessionState: AnyPublisher<RunSessionState, Never> { get }
}

/// Manager responsible for run session lifecycle and state management
public class RunSessionManager: RunSessionManagerProtocol {
    
    // MARK: - Properties
    
    private let locationService: LocationTrackingServiceProtocol
    private let runSessionRepository: RunSessionRepositoryProtocol
    private let realTimeSyncService: RealTimeSyncServiceProtocol?
    
    private let currentSessionSubject = CurrentValueSubject<RunSession?, Never>(nil)
    private let sessionStateSubject = CurrentValueSubject<RunSessionState, Never>(.idle)
    
    private var cancellables = Set<AnyCancellable>()
    private var locationCancellable: AnyCancellable?
    private var paceCancellable: AnyCancellable?
    
    private var sessionStartTime: Date?
    private var pausedTime: Date?
    private var totalPausedDuration: TimeInterval = 0
    private var routePoints: [LocationCoordinate2D] = []
    private var pacePoints: [PacePoint] = []
    
    // MARK: - Publishers
    
    public var currentSession: AnyPublisher<RunSession?, Never> {
        currentSessionSubject.eraseToAnyPublisher()
    }
    
    public var sessionState: AnyPublisher<RunSessionState, Never> {
        sessionStateSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    
    public init(
        locationService: LocationTrackingServiceProtocol,
        runSessionRepository: RunSessionRepositoryProtocol,
        realTimeSyncService: RealTimeSyncServiceProtocol? = nil
    ) {
        self.locationService = locationService
        self.runSessionRepository = runSessionRepository
        self.realTimeSyncService = realTimeSyncService
        
        setupLocationTracking()
    }
    
    // MARK: - Public Methods
    
    public func startRun(type: RunType, userId: UUID) -> AnyPublisher<RunSession, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RunSessionError.managerDeallocated))
                return
            }
            
            // Check if there's already an active session
            guard self.sessionStateSubject.value == .idle else {
                promise(.failure(RunSessionError.sessionAlreadyActive))
                return
            }
            
            self.sessionStateSubject.send(.starting)
            
            // Validate run type
            do {
                try type.validate()
            } catch {
                self.sessionStateSubject.send(.error(error.localizedDescription))
                promise(.failure(error))
                return
            }
            
            // Create new run session
            let newSession = RunSession(
                userId: userId,
                startTime: Date(),
                type: type
            )
            
            // Initialize session state
            self.sessionStartTime = newSession.startTime
            self.pausedTime = nil
            self.totalPausedDuration = 0
            self.routePoints = []
            self.pacePoints = []
            
            // Start location tracking
            self.locationService.startTracking()
            
            // Handle synchronized runs
            if case .synchronized(let sessionId) = type {
                self.joinSynchronizedSession(sessionId: sessionId, userId: userId)
            }
            
            // Save initial session
            self.runSessionRepository.save(newSession)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            self.sessionStateSubject.send(.error(error.localizedDescription))
                            promise(.failure(error))
                        }
                    },
                    receiveValue: { savedSession in
                        self.currentSessionSubject.send(savedSession)
                        self.sessionStateSubject.send(.running)
                        promise(.success(savedSession))
                    }
                )
                .store(in: &self.cancellables)
        }
        .eraseToAnyPublisher()
    }
    
    public func pauseRun() -> AnyPublisher<Void, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RunSessionError.managerDeallocated))
                return
            }
            
            guard self.sessionStateSubject.value == .running else {
                promise(.failure(RunSessionError.invalidStateTransition))
                return
            }
            
            self.pausedTime = Date()
            self.sessionStateSubject.send(.paused)
            
            // Stop location updates but keep the service ready
            self.locationCancellable?.cancel()
            self.paceCancellable?.cancel()
            
            // Save current state
            self.saveCurrentSession()
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            promise(.failure(error))
                        } else {
                            promise(.success(()))
                        }
                    },
                    receiveValue: { _ in }
                )
                .store(in: &self.cancellables)
        }
        .eraseToAnyPublisher()
    }
    
    public func resumeRun() -> AnyPublisher<Void, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RunSessionError.managerDeallocated))
                return
            }
            
            guard self.sessionStateSubject.value == .paused else {
                promise(.failure(RunSessionError.invalidStateTransition))
                return
            }
            
            // Calculate paused duration
            if let pausedTime = self.pausedTime {
                self.totalPausedDuration += Date().timeIntervalSince(pausedTime)
                self.pausedTime = nil
            }
            
            // Resume location tracking
            self.setupLocationTracking()
            self.sessionStateSubject.send(.running)
            
            promise(.success(()))
        }
        .eraseToAnyPublisher()
    }
    
    public func endRun() -> AnyPublisher<RunSession, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(RunSessionError.managerDeallocated))
                return
            }
            
            guard [.running, .paused].contains(self.sessionStateSubject.value) else {
                promise(.failure(RunSessionError.invalidStateTransition))
                return
            }
            
            self.sessionStateSubject.send(.ending)
            
            // Stop location tracking
            self.locationService.stopTracking()
            self.locationCancellable?.cancel()
            self.paceCancellable?.cancel()
            
            // Calculate final metrics
            guard let currentSession = self.currentSessionSubject.value,
                  let startTime = self.sessionStartTime else {
                promise(.failure(RunSessionError.noActiveSession))
                return
            }
            
            let endTime = Date()
            let totalDistance = self.calculateTotalDistance()
            let averagePace = self.calculateAveragePace(distance: totalDistance, duration: endTime.timeIntervalSince(startTime) - self.totalPausedDuration)
            
            // Create final session
            let completedSession = RunSession(
                id: currentSession.id,
                userId: currentSession.userId,
                startTime: startTime,
                endTime: endTime,
                distance: totalDistance,
                averagePace: averagePace,
                route: self.routePoints,
                paceData: self.pacePoints,
                type: currentSession.type,
                participants: currentSession.participants
            )
            
            // Save completed session
            self.runSessionRepository.save(completedSession)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            self.sessionStateSubject.send(.error(error.localizedDescription))
                            promise(.failure(error))
                        }
                    },
                    receiveValue: { savedSession in
                        self.currentSessionSubject.send(nil)
                        self.sessionStateSubject.send(.completed)
                        self.resetSessionState()
                        promise(.success(savedSession))
                    }
                )
                .store(in: &self.cancellables)
        }
        .eraseToAnyPublisher()
    }
    
    public func recoverSession() -> AnyPublisher<RunSession?, Error> {
        return runSessionRepository.fetchAll()
            .map { sessions in
                // Find the most recent incomplete session
                return sessions.first { !$0.isCompleted }
            }
            .handleEvents(receiveOutput: { [weak self] recoveredSession in
                if let session = recoveredSession {
                    self?.currentSessionSubject.send(session)
                    self?.sessionStateSubject.send(.paused) // Recovered sessions start as paused
                    self?.restoreSessionState(from: session)
                }
            })
            .eraseToAnyPublisher()
    }
    
    // MARK: - Private Methods
    
    private func setupLocationTracking() {
        locationCancellable = locationService.locationUpdates
            .sink { [weak self] location in
                self?.handleLocationUpdate(location)
            }
        
        paceCancellable = locationService.paceUpdates
            .sink { [weak self] pace in
                self?.handlePaceUpdate(pace, at: Date())
            }
    }
    
    private func handleLocationUpdate(_ location: CLLocation) {
        let coordinate = LocationCoordinate2D(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        routePoints.append(coordinate)
        
        // Send location update for synchronized runs
        if case .synchronized = currentSessionSubject.value?.type {
            realTimeSyncService?.sendPaceUpdate(pace: 0, location: location) // Pace will be updated separately
                .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
                .store(in: &cancellables)
        }
        
        // Auto-save session periodically (every 10 location updates)
        if routePoints.count % 10 == 0 {
            saveCurrentSession()
                .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
                .store(in: &cancellables)
        }
    }
    
    private func handlePaceUpdate(_ pace: Double, at timestamp: Date) {
        guard let location = locationService.getCurrentLocation() else { return }
        
        let pacePoint = PacePoint(
            timestamp: timestamp,
            location: LocationCoordinate2D(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            ),
            pace: pace,
            heartRate: nil // HealthKit integration would provide this
        )
        
        pacePoints.append(pacePoint)
        
        // Send pace update for synchronized runs
        if case .synchronized = currentSessionSubject.value?.type {
            realTimeSyncService?.sendPaceUpdate(pace: pace, location: location)
                .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
                .store(in: &cancellables)
        }
    }
    
    private func joinSynchronizedSession(sessionId: String, userId: UUID) {
        guard let currentSession = currentSessionSubject.value else { return }
        
        // Extract participant IDs if available
        let participants = currentSession.participants ?? []
        let friends = participants.compactMap { _ in
            // This would typically fetch User objects from the participants
            // For now, we'll use empty array as friends would come from FriendService
            return nil as User?
        }
        
        realTimeSyncService?.joinSession(sessionId: sessionId, userId: userId.uuidString, friends: friends)
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)
    }
    
    private func calculateTotalDistance() -> Double {
        guard routePoints.count > 1 else { return 0 }
        
        var totalDistance: Double = 0
        for i in 1..<routePoints.count {
            let previousPoint = routePoints[i-1]
            let currentPoint = routePoints[i]
            
            let previousLocation = CLLocation(
                latitude: previousPoint.latitude,
                longitude: previousPoint.longitude
            )
            let currentLocation = CLLocation(
                latitude: currentPoint.latitude,
                longitude: currentPoint.longitude
            )
            
            totalDistance += currentLocation.distance(from: previousLocation)
        }
        
        return totalDistance
    }
    
    private func calculateAveragePace(distance: Double, duration: TimeInterval) -> Double {
        guard distance > 0, duration > 0 else { return 0 }
        
        let distanceInKm = distance / 1000.0
        let durationInMinutes = duration / 60.0
        
        return durationInMinutes / distanceInKm // minutes per km
    }
    
    private func saveCurrentSession() -> AnyPublisher<RunSession, Error> {
        guard let currentSession = currentSessionSubject.value,
              let startTime = sessionStartTime else {
            return Fail(error: RunSessionError.noActiveSession)
                .eraseToAnyPublisher()
        }
        
        let totalDistance = calculateTotalDistance()
        let currentTime = Date()
        let runningDuration = currentTime.timeIntervalSince(startTime) - totalPausedDuration
        let averagePace = calculateAveragePace(distance: totalDistance, duration: runningDuration)
        
        let updatedSession = RunSession(
            id: currentSession.id,
            userId: currentSession.userId,
            startTime: startTime,
            endTime: nil, // Still running
            distance: totalDistance,
            averagePace: averagePace,
            route: routePoints,
            paceData: pacePoints,
            type: currentSession.type,
            participants: currentSession.participants
        )
        
        return runSessionRepository.save(updatedSession)
            .handleEvents(receiveOutput: { [weak self] savedSession in
                self?.currentSessionSubject.send(savedSession)
            })
            .eraseToAnyPublisher()
    }
    
    private func restoreSessionState(from session: RunSession) {
        sessionStartTime = session.startTime
        routePoints = session.route
        pacePoints = session.paceData
        totalPausedDuration = 0 // This would need to be calculated from pause/resume events
        pausedTime = nil
    }
    
    private func resetSessionState() {
        sessionStartTime = nil
        pausedTime = nil
        totalPausedDuration = 0
        routePoints = []
        pacePoints = []
        cancellables.removeAll()
    }
}

// MARK: - Error Types

public enum RunSessionError: Error, LocalizedError {
    case managerDeallocated
    case sessionAlreadyActive
    case noActiveSession
    case invalidStateTransition
    case locationServiceUnavailable
    case persistenceError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .managerDeallocated:
            return "Run session manager was deallocated"
        case .sessionAlreadyActive:
            return "A run session is already active"
        case .noActiveSession:
            return "No active run session found"
        case .invalidStateTransition:
            return "Invalid run session state transition"
        case .locationServiceUnavailable:
            return "Location service is not available"
        case .persistenceError(let error):
            return "Failed to save run session: \(error.localizedDescription)"
        }
    }
}