import SwiftUI
import MapKit

struct HistoryView: View {
    @State private var runs: [RunSession] = []
    @State private var selectedTimeframe: TimeFrame = .all
    @State private var showingRunDetail = false
    @State private var selectedRun: RunSession?
    @State private var searchText = ""
    
    enum TimeFrame: String, CaseIterable {
        case week = "This Week"
        case month = "This Month"
        case year = "This Year"
        case all = "All Time"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Stats Summary
                statsSection
                
                // Time Frame Selector
                timeFrameSelector
                
                // Search Bar
                searchBar
                
                // Runs List
                runsListSection
            }
            .navigationTitle("History")
            .onAppear {
                loadRuns()
            }
            .sheet(isPresented: $showingRunDetail) {
                if let run = selectedRun {
                    RunDetailView(run: run)
                }
            }
        }
    }
    
    private var statsSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                StatCard(
                    title: "Total Runs",
                    value: "\(filteredRuns.count)",
                    icon: "figure.run",
                    color: .blue
                )
                
                StatCard(
                    title: "Total Distance",
                    value: formatTotalDistance(),
                    icon: "map",
                    color: .green
                )
                
                StatCard(
                    title: "Avg Pace",
                    value: formatAveragePace(),
                    icon: "speedometer",
                    color: .orange
                )
            }
            
            HStack(spacing: 20) {
                StatCard(
                    title: "Total Time",
                    value: formatTotalTime(),
                    icon: "clock",
                    color: .purple
                )
                
                StatCard(
                    title: "Best Pace",
                    value: formatBestPace(),
                    icon: "trophy",
                    color: .yellow
                )
                
                StatCard(
                    title: "Longest Run",
                    value: formatLongestRun(),
                    icon: "star",
                    color: .red
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    private var timeFrameSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(TimeFrame.allCases, id: \.self) { timeframe in
                    Button(action: { selectedTimeframe = timeframe }) {
                        Text(timeframe.rawValue)
                            .font(.subheadline)
                            .fontWeight(selectedTimeframe == timeframe ? .semibold : .regular)
                            .foregroundColor(selectedTimeframe == timeframe ? .white : .accentColor)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                selectedTimeframe == timeframe ? 
                                Color.accentColor : Color.accentColor.opacity(0.1)
                            )
                            .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search runs", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .padding(.horizontal)
    }
    
    private var runsListSection: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredRuns) { run in
                    RunHistoryCard(run: run) {
                        selectedRun = run
                        showingRunDetail = true
                    }
                }
                
                if filteredRuns.isEmpty {
                    Text("No runs found")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .padding()
        }
        .refreshable {
            await refreshRuns()
        }
    }
    
    private var filteredRuns: [RunSession] {
        let timeFilteredRuns = runs.filter { run in
            switch selectedTimeframe {
            case .week:
                return Calendar.current.isDate(run.startTime, equalTo: Date(), toGranularity: .weekOfYear)
            case .month:
                return Calendar.current.isDate(run.startTime, equalTo: Date(), toGranularity: .month)
            case .year:
                return Calendar.current.isDate(run.startTime, equalTo: Date(), toGranularity: .year)
            case .all:
                return true
            }
        }
        
        if searchText.isEmpty {
            return timeFilteredRuns.sorted { $0.startTime > $1.startTime }
        } else {
            return timeFilteredRuns.filter { run in
                // Search by run type or date
                let runTypeText = runTypeDisplayText(run.type)
                let dateText = DateFormatter.localizedString(from: run.startTime, dateStyle: .medium, timeStyle: .none)
                return runTypeText.localizedCaseInsensitiveContains(searchText) ||
                       dateText.localizedCaseInsensitiveContains(searchText)
            }.sorted { $0.startTime > $1.startTime }
        }
    }
    
    private func loadRuns() {
        // TODO: Load runs from service
        runs = []
    }
    
    private func refreshRuns() async {
        // TODO: Refresh runs data
    }
    
    private func formatTotalDistance() -> String {
        let totalMeters = filteredRuns.reduce(0) { $0 + $1.distance }
        let totalMiles = totalMeters * 0.000621371
        return String(format: "%.1f mi", totalMiles)
    }
    
    private func formatAveragePace() -> String {
        let validRuns = filteredRuns.filter { $0.averagePace > 0 }
        guard !validRuns.isEmpty else { return "--:--" }
        
        let avgPace = validRuns.reduce(0) { $0 + $1.averagePace } / Double(validRuns.count)
        let minutes = Int(avgPace)
        let seconds = Int((avgPace - Double(minutes)) * 60)
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func formatTotalTime() -> String {
        let totalTime = filteredRuns.compactMap { $0.duration }.reduce(0, +)
        let hours = Int(totalTime) / 3600
        let minutes = (Int(totalTime) % 3600) / 60
        return String(format: "%dh %dm", hours, minutes)
    }
    
    private func formatBestPace() -> String {
        let validRuns = filteredRuns.filter { $0.averagePace > 0 }
        guard let bestPace = validRuns.map({ $0.averagePace }).min() else { return "--:--" }
        
        let minutes = Int(bestPace)
        let seconds = Int((bestPace - Double(minutes)) * 60)
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func formatLongestRun() -> String {
        guard let longestDistance = filteredRuns.map({ $0.distance }).max() else { return "0.0 mi" }
        let miles = longestDistance * 0.000621371
        return String(format: "%.1f mi", miles)
    }
    
    private func runTypeDisplayText(_ runType: RunType) -> String {
        switch runType {
        case .solo:
            return "Solo Run"
        case .synchronized:
            return "Group Run"
        case .replay:
            return "Replay Run"
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

struct RunHistoryCard: View {
    let run: RunSession
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(runTypeDisplayText)
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text(formatDate(run.startTime))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        if run.isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "pause.circle.fill")
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                HStack(spacing: 20) {
                    MetricItem(
                        title: "Distance",
                        value: formatDistance(run.distance),
                        icon: "map"
                    )
                    
                    MetricItem(
                        title: "Pace",
                        value: formatPace(run.averagePace),
                        icon: "speedometer"
                    )
                    
                    if let duration = run.duration {
                        MetricItem(
                            title: "Time",
                            value: formatDuration(duration),
                            icon: "clock"
                        )
                    }
                }
                
                // Mini route preview
                if !run.route.isEmpty {
                    RoutePreview(route: run.route)
                        .frame(height: 60)
                        .cornerRadius(8)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var runTypeDisplayText: String {
        switch run.type {
        case .solo:
            return "Solo Run"
        case .synchronized:
            return "Group Run"
        case .replay:
            return "Replay Run"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDistance(_ distance: Double) -> String {
        let miles = distance * 0.000621371
        return String(format: "%.2f mi", miles)
    }
    
    private func formatPace(_ pace: Double) -> String {
        guard pace > 0 else { return "--:--" }
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        return String(format: "%d:%02d/mi", minutes, seconds)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

struct MetricItem: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct RoutePreview: View {
    let route: [CLLocationCoordinate2D]
    
    var body: some View {
        // Simple route visualization
        GeometryReader { geometry in
            Path { path in
                guard !route.isEmpty else { return }
                
                let bounds = calculateBounds()
                let scaleX = geometry.size.width / (bounds.maxLon - bounds.minLon)
                let scaleY = geometry.size.height / (bounds.maxLat - bounds.minLat)
                let scale = min(scaleX, scaleY) * 0.9 // Add some padding
                
                let centerX = geometry.size.width / 2
                let centerY = geometry.size.height / 2
                let routeCenterX = (bounds.maxLon + bounds.minLon) / 2
                let routeCenterY = (bounds.maxLat + bounds.minLat) / 2
                
                for (index, coordinate) in route.enumerated() {
                    let x = centerX + (coordinate.longitude - routeCenterX) * scale
                    let y = centerY - (coordinate.latitude - routeCenterY) * scale
                    
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(Color.accentColor, lineWidth: 2)
        }
        .background(Color(.systemGray5))
    }
    
    private func calculateBounds() -> (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
        guard !route.isEmpty else {
            return (0, 0, 0, 0)
        }
        
        let latitudes = route.map { $0.latitude }
        let longitudes = route.map { $0.longitude }
        
        return (
            minLat: latitudes.min() ?? 0,
            maxLat: latitudes.max() ?? 0,
            minLon: longitudes.min() ?? 0,
            maxLon: longitudes.max() ?? 0
        )
    }
}

struct RunDetailView: View {
    let run: RunSession
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Text(runTypeDisplayText)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text(formatDate(run.startTime))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Main Stats
                    HStack(spacing: 20) {
                        DetailStatCard(
                            title: "Distance",
                            value: formatDistance(run.distance),
                            color: .blue
                        )
                        
                        DetailStatCard(
                            title: "Pace",
                            value: formatPace(run.averagePace),
                            color: .green
                        )
                        
                        if let duration = run.duration {
                            DetailStatCard(
                                title: "Time",
                                value: formatDuration(duration),
                                color: .orange
                            )
                        }
                    }
                    
                    // Route Map
                    if !run.route.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Route")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            RoutePreview(route: run.route)
                                .frame(height: 200)
                                .cornerRadius(12)
                        }
                    }
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        Button(action: {}) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Replay This Run")
                            }
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .cornerRadius(12)
                        }
                        
                        Button(action: {}) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share Run")
                            }
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.accentColor)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Run Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var runTypeDisplayText: String {
        switch run.type {
        case .solo:
            return "Solo Run"
        case .synchronized:
            return "Group Run"
        case .replay:
            return "Replay Run"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDistance(_ distance: Double) -> String {
        let miles = distance * 0.000621371
        return String(format: "%.2f mi", miles)
    }
    
    private func formatPace(_ pace: Double) -> String {
        guard pace > 0 else { return "--:--" }
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        return String(format: "%d:%02d/mi", minutes, seconds)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

struct DetailStatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    HistoryView()
}