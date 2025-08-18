import SwiftUI
import MapKit
import CoreLocation

struct RunView: View {
    @StateObject private var viewModel: RunViewModel
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var showingRunTypeSelection = false
    @State private var selectedRunType: RunType = .solo
    
    init(locationService: LocationTrackingServiceProtocol, syncService: RealTimeSyncServiceProtocol) {
        self._viewModel = StateObject(wrappedValue: RunViewModel(locationService: locationService, syncService: syncService))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Connection Status Bar
                if viewModel.isInSyncSession {
                    connectionStatusBar
                }
                
                // Map View
                mapSection
                
                // Metrics Section
                metricsSection
                
                // Friends Status (if applicable)
                if !viewModel.friends.isEmpty {
                    friendsStatusSection
                }
                
                // Control Buttons
                controlButtonsSection
            }
            .navigationTitle("Run")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: audioToggleButton)
            .sheet(isPresented: $showingRunTypeSelection) {
                RunTypeSelectionView(selectedType: $selectedRunType) {
                    viewModel.startRun(type: selectedRunType)
                }
            }
            .alert("Emergency Stop", isPresented: $viewModel.showEmergencyAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Confirm", role: .destructive) {
                    viewModel.confirmEmergencyStop()
                }
            } message: {
                Text("This will stop your run and send your location to emergency contacts. Are you sure?")
            }
            .onChange(of: viewModel.currentLocation) { location in
                if let location = location {
                    updateMapRegion(for: location)
                }
            }
        }
    }
    
    private var connectionStatusBar: some View {
        HStack {
            Circle()
                .fill(connectionStatusColor)
                .frame(width: 8, height: 8)
            
            Text(connectionStatusText)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            if viewModel.isInSyncSession {
                Text("Sync Session Active")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
    
    private var mapSection: some View {
        Map(coordinateRegion: $region, annotationItems: []) { _ in
            // Map annotations would go here
        }
        .frame(height: 300)
        .overlay(
            VStack {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Button(action: centerOnUser) {
                            Image(systemName: "location.fill")
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        
                        if viewModel.isRunning {
                            Button(action: { viewModel.toggleAudioFeedback() }) {
                                Image(systemName: viewModel.audioFeedbackEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                            }
                        }
                    }
                    .padding()
                }
                Spacer()
            }
        )
        .overlay(
            // Route overlay
            RouteOverlay(route: viewModel.route)
        )
    }
    
    private var metricsSection: some View {
        VStack(spacing: 16) {
            // Primary Metrics with enhanced pace display
            HStack(spacing: 20) {
                EnhancedPaceView(
                    currentPace: viewModel.currentPace,
                    targetPace: viewModel.targetPace,
                    deviation: viewModel.paceDeviation,
                    color: viewModel.paceColor,
                    isInSyncSession: viewModel.isInSyncSession
                )
                
                MetricView(
                    title: "Distance",
                    value: viewModel.formatDistance(viewModel.currentDistance),
                    color: .blue
                )
                
                MetricView(
                    title: "Time",
                    value: viewModel.formatTime(viewModel.elapsedTime),
                    color: .green
                )
            }
            
            // Secondary Metrics
            HStack(spacing: 20) {
                SecondaryMetricView(
                    title: "Avg Pace",
                    value: viewModel.formatPace(viewModel.averagePace)
                )
                
                SecondaryMetricView(
                    title: "Calories",
                    value: "\(viewModel.estimatedCalories)"
                )
                
                SecondaryMetricView(
                    title: "Heart Rate",
                    value: "-- bpm"
                )
            }
            
            // Pace deviation indicator for sync sessions
            if viewModel.isInSyncSession && viewModel.targetPace > 0 {
                paceDeviationIndicator
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    private var friendsStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Running with Friends")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(viewModel.friends.count) active")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.friends) { friendUpdate in
                        FriendRunStatusCard(friendUpdate: friendUpdate)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .background(Color(.systemBackground))
    }
    
    private var controlButtonsSection: some View {
        VStack(spacing: 16) {
            if !viewModel.isRunning {
                // Start Button
                Button(action: { showingRunTypeSelection = true }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start Run")
                    }
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(12)
                }
            } else {
                HStack(spacing: 16) {
                    // Pause/Resume Button
                    Button(action: {
                        if viewModel.isPaused {
                            viewModel.resumeRun()
                        } else {
                            viewModel.pauseRun()
                        }
                    }) {
                        HStack {
                            Image(systemName: viewModel.isPaused ? "play.fill" : "pause.fill")
                            Text(viewModel.isPaused ? "Resume" : "Pause")
                        }
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.isPaused ? Color.green : Color.orange)
                        .cornerRadius(12)
                    }
                    
                    // Stop Button
                    Button(action: { viewModel.stopRun() }) {
                        HStack {
                            Image(systemName: "stop.fill")
                            Text("Stop")
                        }
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(12)
                    }
                }
            }
            
            // Emergency Button
            Button(action: { viewModel.emergencyStop() }) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("Emergency Stop")
                }
                .font(.caption)
                .foregroundColor(.red)
            }
        }
        .padding()
    }
    
    private var connectionStatusColor: Color {
        switch viewModel.connectionStatus {
        case .connected:
            return .green
        case .connecting:
            return .yellow
        case .disconnected:
            return .red
        case .error:
            return .red
        }
    }
    
    private var connectionStatusText: String {
        switch viewModel.connectionStatus {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting..."
        case .disconnected:
            return "Disconnected"
        case .error(let message):
            return "Error: \(message)"
        }
    }
    
    private var audioToggleButton: some View {
        Button(action: { viewModel.toggleAudioFeedback() }) {
            Image(systemName: viewModel.audioFeedbackEnabled ? "speaker.wave.2" : "speaker.slash")
        }
    }
    
    private var paceDeviationIndicator: some View {
        VStack(spacing: 4) {
            Text("Pace Sync")
                .font(.caption)
                .fontWeight(.medium)
            
            HStack {
                Text("Target: \(viewModel.formatPace(viewModel.targetPace))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(abs(viewModel.paceDeviation) < 0.5 ? Color.green : abs(viewModel.paceDeviation) < 1.0 ? Color.yellow : Color.red)
                        .frame(width: 8, height: 8)
                    
                    Text(String(format: "%+.1f", viewModel.paceDeviation))
                        .font(.caption2)
                        .fontWeight(.medium)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray5))
        .cornerRadius(8)
    }
    
    private func centerOnUser() {
        if let location = viewModel.currentLocation {
            updateMapRegion(for: location)
        }
    }
    
    private func updateMapRegion(for location: CLLocation) {
        withAnimation(.easeInOut(duration: 0.5)) {
            region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
    }
}

struct MetricView: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct SecondaryMetricView: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct EnhancedPaceView: View {
    let currentPace: Double
    let targetPace: Double
    let deviation: Double
    let color: Color
    let isInSyncSession: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Text(formatPace(currentPace))
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                
                if isInSyncSession && targetPace > 0 {
                    Image(systemName: deviationIcon)
                        .foregroundColor(color)
                        .font(.caption)
                }
            }
            
            Text("Pace")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if isInSyncSession && targetPace > 0 {
                Text("Target: \(formatPace(targetPace))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var deviationIcon: String {
        if abs(deviation) < 0.3 {
            return "checkmark.circle.fill"
        } else if deviation > 0 {
            return "arrow.down.circle.fill"
        } else {
            return "arrow.up.circle.fill"
        }
    }
    
    private func formatPace(_ pace: Double) -> String {
        guard pace > 0 else { return "--:--" }
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct FriendRunStatusCard: View {
    let friendUpdate: FriendRunUpdate
    
    var body: some View {
        VStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(friendUpdate.userId.prefix(1)).uppercased())
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            Text(friendUpdate.userId)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
            
            Text(formatPace(friendUpdate.pace))
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(timeAgo)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .frame(width: 80)
    }
    
    private var statusColor: Color {
        let timeSinceUpdate = Date().timeIntervalSince(friendUpdate.timestamp)
        if timeSinceUpdate < 30 {
            return .green
        } else if timeSinceUpdate < 60 {
            return .yellow
        } else {
            return .red
        }
    }
    
    private var timeAgo: String {
        let timeSinceUpdate = Date().timeIntervalSince(friendUpdate.timestamp)
        if timeSinceUpdate < 60 {
            return "\(Int(timeSinceUpdate))s ago"
        } else {
            return "\(Int(timeSinceUpdate / 60))m ago"
        }
    }
    
    private func formatPace(_ pace: Double) -> String {
        guard pace > 0 else { return "--:--" }
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct RouteOverlay: View {
    let route: [CLLocationCoordinate2D]
    
    var body: some View {
        // This would be implemented with MapKit overlays in a real app
        // For now, just a placeholder
        EmptyView()
    }
}

struct RunTypeSelectionView: View {
    @Binding var selectedType: RunType
    let onStart: () -> Void
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Choose Run Type")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding()
                
                VStack(spacing: 16) {
                    RunTypeOption(
                        title: "Solo Run",
                        description: "Run by yourself with GPS tracking",
                        icon: "figure.run",
                        isSelected: selectedType == .solo
                    ) {
                        selectedType = .solo
                    }
                    
                    RunTypeOption(
                        title: "Synchronized Run",
                        description: "Run with friends at the same pace",
                        icon: "person.2.fill",
                        isSelected: false // Would check for synchronized type
                    ) {
                        // selectedType = .synchronized("session-id")
                    }
                    
                    RunTypeOption(
                        title: "Replay Run",
                        description: "Follow a previous run route and pace",
                        icon: "arrow.clockwise",
                        isSelected: false // Would check for replay type
                    ) {
                        // selectedType = .replay(UUID())
                    }
                }
                .padding()
                
                Spacer()
                
                Button("Start Run") {
                    onStart()
                    presentationMode.wrappedValue.dismiss()
                }
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .cornerRadius(12)
                .padding()
            }
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

struct RunTypeOption: View {
    let title: String
    let description: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .blue)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(isSelected ? Color.blue : Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    // Mock services for preview
    let mockLocationService = MockLocationService()
    let mockSyncService = MockSyncService()
    
    return RunView(locationService: mockLocationService, syncService: mockSyncService)
}

// Mock services for preview
class MockLocationService: LocationTrackingServiceProtocol {
    var locationUpdates: AnyPublisher<CLLocation, Never> = Empty().eraseToAnyPublisher()
    var paceUpdates: AnyPublisher<Double, Never> = Empty().eraseToAnyPublisher()
    var authorizationStatus: AnyPublisher<CLAuthorizationStatus, Never> = Just(.authorizedWhenInUse).eraseToAnyPublisher()
    var isTracking: Bool = false
    
    func startTracking() {}
    func stopTracking() {}
    func getCurrentLocation() -> CLLocation? { return nil }
}

class MockSyncService: RealTimeSyncServiceProtocol {
    var friendUpdates: AnyPublisher<[FriendRunUpdate], Never> = Just([]).eraseToAnyPublisher()
    var connectionStatus: AnyPublisher<ConnectionStatus, Never> = Just(.disconnected).eraseToAnyPublisher()
    var sessionInfo: AnyPublisher<SessionInfo?, Never> = Just(nil).eraseToAnyPublisher()
    
    func joinSession(sessionId: String, userId: String, friends: [User]) -> AnyPublisher<Void, Error> {
        return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    func leaveSession() -> AnyPublisher<Void, Error> {
        return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    func sendPaceUpdate(pace: Double, location: CLLocation) -> AnyPublisher<Void, Error> {
        return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    func isInSession() -> Bool { return false }
    func getCurrentSessionId() -> String? { return nil }
}