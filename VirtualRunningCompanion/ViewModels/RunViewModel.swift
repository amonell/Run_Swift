import Foundation
import SwiftUI
import Combine
import CoreLocation
import AVFoundation

@MainActor
public class RunViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isRunning = false
    @Published var isPaused = false
    @Published var currentPace: Double = 0
    @Published var currentDistance: Double = 0
    @Published var elapsedTime: TimeInterval = 0
    @Published var currentLocation: CLLocation?
    @Published var route: [CLLocationCoordinate2D] = []
    @Published var friends: [FriendRunUpdate] = []
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var isInSyncSession = false
    @Published var targetPace: Double = 0
    @Published var paceDeviation: Double = 0
    @Published var audioFeedbackEnabled = true
    @Published var showEmergencyAlert = false
    
    // MARK: - Services
    private let locationService: LocationTrackingServiceProtocol
    private let syncService: RealTimeSyncServiceProtocol
    private let audioEngine = AVAudioEngine()
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var runTimer: Timer?
    private var currentRunSession: RunSession?
    private var lastPaceAnnouncement: Date = Date()
    private var lastMilestoneAnnouncement: Double = 0
    
    // MARK: - Computed Properties
    var averagePace: Double {
        guard elapsedTime > 0 && currentDistance > 0 else { return 0 }
        let kilometers = currentDistance / 1000.0
        return (elapsedTime / 60.0) / kilometers
    }
    
    var estimatedCalories: Int {
        // Simple calorie estimation based on distance and average weight
        let kilometers = currentDistance / 1000.0
        return Int(kilometers * 65) // Rough estimate: 65 calories per km
    }
    
    var paceColor: Color {
        if currentPace == 0 { return .gray }
        
        if isInSyncSession && targetPace > 0 {
            let deviation = abs(currentPace - targetPace)
            if deviation < 0.5 { return .green }
            if deviation < 1.0 { return .yellow }
            return .red
        } else {
            if currentPace < 5 { return .green }
            if currentPace < 7 { return .yellow }
            return .red
        }
    }
    
    // MARK: - Initialization
    public init(locationService: LocationTrackingServiceProtocol, syncService: RealTimeSyncServiceProtocol) {
        self.locationService = locationService
        self.syncService = syncService
        
        setupBindings()
        setupAudioSession()
    }
    
    // MARK: - Public Methods
    
    func startRun(type: RunType = .solo, targetPace: Double = 0) {
        guard !isRunning else { return }
        
        self.targetPace = targetPace
        isRunning = true
        isPaused = false
        elapsedTime = 0
        currentDistance = 0
        route.removeAll()
        
        // Start location tracking
        locationService.startTracking()
        
        // Start timer
        startRunTimer()
        
        // Join sync session if needed
        if case .synchronized(let sessionId) = type {
            joinSyncSession(sessionId: sessionId)
        }
        
        // Create run session
        currentRunSession = RunSession(
            id: UUID(),
            userId: UUID(), // This would come from user service
            startTime: Date(),
            endTime: nil,
            distance: 0,
            averagePace: 0,
            route: [],
            paceData: [],
            type: type,
            participants: []
        )
        
        announceRunStart()
    }
    
    func pauseRun() {
        guard isRunning && !isPaused else { return }
        
        isPaused = true
        stopRunTimer()
        
        if audioFeedbackEnabled {
            speakText("Run paused")
        }
    }
    
    func resumeRun() {
        guard isRunning && isPaused else { return }
        
        isPaused = false
        startRunTimer()
        
        if audioFeedbackEnabled {
            speakText("Run resumed")
        }
    }
    
    func stopRun() {
        guard isRunning else { return }
        
        isRunning = false
        isPaused = false
        
        // Stop services
        locationService.stopTracking()
        stopRunTimer()
        
        // Leave sync session
        if isInSyncSession {
            leaveSyncSession()
        }
        
        // Finalize run session
        finalizeRunSession()
        
        announceRunComplete()
    }
    
    func emergencyStop() {
        showEmergencyAlert = true
    }
    
    func confirmEmergencyStop() {
        stopRun()
        
        // Send emergency location to emergency contacts
        if let location = currentLocation {
            sendEmergencyLocation(location)
        }
        
        showEmergencyAlert = false
    }
    
    func toggleAudioFeedback() {
        audioFeedbackEnabled.toggle()
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Location updates
        locationService.locationUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                self?.handleLocationUpdate(location)
            }
            .store(in: &cancellables)
        
        // Pace updates
        locationService.paceUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] pace in
                self?.handlePaceUpdate(pace)
            }
            .store(in: &cancellables)
        
        // Friend updates from sync service
        syncService.friendUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] updates in
                self?.friends = updates
            }
            .store(in: &cancellables)
        
        // Connection status
        syncService.connectionStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.connectionStatus = status
            }
            .store(in: &cancellables)
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    private func startRunTimer() {
        runTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.updateElapsedTime()
            }
        }
    }
    
    private func stopRunTimer() {
        runTimer?.invalidate()
        runTimer = nil
    }
    
    private func updateElapsedTime() {
        guard isRunning && !isPaused else { return }
        elapsedTime += 1
        
        // Check for milestone announcements
        checkForMilestoneAnnouncements()
    }
    
    private func handleLocationUpdate(_ location: CLLocation) {
        guard isRunning && !isPaused else { return }
        
        currentLocation = location
        route.append(location.coordinate)
        
        // Update distance
        if let previousLocation = route.count > 1 ? CLLocation(latitude: route[route.count - 2].latitude, longitude: route[route.count - 2].longitude) : nil {
            let distance = location.distance(from: previousLocation)
            currentDistance += distance
        }
        
        // Send location update to sync service if in session
        if isInSyncSession && currentPace > 0 {
            syncService.sendPaceUpdate(pace: currentPace, location: location)
                .sink(
                    receiveCompletion: { _ in },
                    receiveValue: { _ in }
                )
                .store(in: &cancellables)
        }
    }
    
    private func handlePaceUpdate(_ pace: Double) {
        guard isRunning && !isPaused else { return }
        
        currentPace = pace
        
        // Calculate pace deviation if in sync session
        if isInSyncSession && targetPace > 0 {
            paceDeviation = pace - targetPace
            providePaceFeedback()
        }
        
        // Provide general pace feedback
        providePaceGuidance()
    }
    
    private func joinSyncSession(sessionId: String) {
        syncService.joinSession(
            sessionId: sessionId,
            userId: "current-user-id", // This would come from user service
            friends: []
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    print("Failed to join sync session: \(error)")
                }
            },
            receiveValue: { [weak self] _ in
                self?.isInSyncSession = true
            }
        )
        .store(in: &cancellables)
    }
    
    private func leaveSyncSession() {
        syncService.leaveSession()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        print("Failed to leave sync session: \(error)")
                    }
                },
                receiveValue: { [weak self] _ in
                    self?.isInSyncSession = false
                }
            )
            .store(in: &cancellables)
    }
    
    private func providePaceFeedback() {
        guard audioFeedbackEnabled else { return }
        
        let now = Date()
        guard now.timeIntervalSince(lastPaceAnnouncement) > 30 else { return } // Limit to every 30 seconds
        
        if abs(paceDeviation) > 1.0 {
            let message = paceDeviation > 0 ? "Slow down a bit" : "Speed up a little"
            speakText(message)
            lastPaceAnnouncement = now
        } else if abs(paceDeviation) < 0.3 {
            speakText("Great pace, keep it up!")
            lastPaceAnnouncement = now
        }
    }
    
    private func providePaceGuidance() {
        guard audioFeedbackEnabled else { return }
        
        let now = Date()
        guard now.timeIntervalSince(lastPaceAnnouncement) > 60 else { return } // Every minute for general guidance
        
        let paceMinutes = Int(currentPace)
        let paceSeconds = Int((currentPace - Double(paceMinutes)) * 60)
        
        speakText("Current pace: \(paceMinutes) minutes \(paceSeconds) seconds per kilometer")
        lastPaceAnnouncement = now
    }
    
    private func checkForMilestoneAnnouncements() {
        guard audioFeedbackEnabled else { return }
        
        let kilometers = currentDistance / 1000.0
        let nextMilestone = floor(kilometers) + 1
        
        if kilometers >= nextMilestone && nextMilestone > lastMilestoneAnnouncement {
            let message = "You've completed \(Int(nextMilestone)) kilometer\(nextMilestone == 1 ? "" : "s")!"
            speakText(message)
            lastMilestoneAnnouncement = nextMilestone
        }
    }
    
    private func announceRunStart() {
        guard audioFeedbackEnabled else { return }
        speakText("Run started. Good luck!")
    }
    
    private func announceRunComplete() {
        guard audioFeedbackEnabled else { return }
        
        let kilometers = currentDistance / 1000.0
        let message = String(format: "Run complete! You covered %.2f kilometers in %@", kilometers, formatTime(elapsedTime))
        speakText(message)
    }
    
    private func speakText(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        utterance.volume = 0.8
        
        speechSynthesizer.speak(utterance)
    }
    
    private func finalizeRunSession() {
        guard var session = currentRunSession else { return }
        
        session.endTime = Date()
        session.distance = currentDistance
        session.averagePace = averagePace
        session.route = route
        
        // Save session (would integrate with persistence layer)
        // persistenceService.save(session)
        
        currentRunSession = nil
    }
    
    private func sendEmergencyLocation(_ location: CLLocation) {
        // This would integrate with emergency services or contacts
        print("Emergency location sent: \(location.coordinate)")
    }
    
    // MARK: - Formatting Helpers
    
    func formatPace(_ pace: Double) -> String {
        guard pace > 0 else { return "--:--" }
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    func formatDistance(_ distance: Double) -> String {
        let kilometers = distance / 1000.0
        return String(format: "%.2f km", kilometers)
    }
    
    func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}