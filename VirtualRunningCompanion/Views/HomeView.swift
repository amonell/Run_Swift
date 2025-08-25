import SwiftUI
import VirtualRunningCompanion

struct HomeView: View {
    @State private var recentRuns: [RunSession] = []
    @State private var friendActivity: [Friend] = []
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Welcome Section
                    welcomeSection
                    
                    // Quick Start Options
                    quickStartSection
                    
                    // Recent Activity
                    recentActivitySection
                    
                    // Friend Activity
                    friendActivitySection
                }
                .padding()
            }
            .navigationTitle("Home")
            .refreshable {
                await refreshData()
            }
        }
    }
    
    private var welcomeSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "figure.run.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
            
            Text("Ready to Run!")
                .font(.title2)
                
            
            Text("Start a new run or connect with friends")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var quickStartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Start")
                .font(.headline)
                
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                QuickStartButton(
                    title: "Solo Run",
                    icon: "figure.run",
                    color: .blue
                ) {
                    // TODO: Start solo run
                }
                
                QuickStartButton(
                    title: "Run with Friends",
                    icon: "person.2.fill",
                    color: .green
                ) {
                    // TODO: Start synchronized run
                }
                
                QuickStartButton(
                    title: "Replay Run",
                    icon: "arrow.clockwise",
                    color: .orange
                ) {
                    // TODO: Start replay run
                }
                
                QuickStartButton(
                    title: "Browse History",
                    icon: "clock.fill",
                    color: .purple
                ) {
                    // TODO: Navigate to history
                }
            }
        }
    }
    
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Runs")
                    .font(.headline)
                    
                
                Spacer()
                
                Button("View All") {
                    // TODO: Navigate to history
                }
                .font(.caption)
                .foregroundColor(.accentColor)
            }
            
            if recentRuns.isEmpty {
                Text("No recent runs")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(recentRuns.prefix(3)) { run in
                        RecentRunCard(run: run)
                    }
                }
            }
        }
    }
    
    private var friendActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Friend Activity")
                    .font(.headline)
                    
                
                Spacer()
                
                Button("View All") {
                    // TODO: Navigate to friends
                }
                .font(.caption)
                .foregroundColor(.accentColor)
            }
            
            if friendActivity.isEmpty {
                Text("No friend activity")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(friendActivity.prefix(3)) { friend in
                        FriendActivityCard(friend: friend)
                    }
                }
            }
        }
    }
    
    private func refreshData() async {
        // TODO: Implement data refresh
        // This would typically fetch recent runs and friend activity from services
    }
}

struct QuickStartButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct RecentRunCard: View {
    let run: RunSession
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(runTypeText)
                    .font(.subheadline)
                    
                
                Text(formatDate(run.startTime))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatDistance(run.distance))
                    .font(.subheadline)
                    
                
                if run.averagePace > 0 {
                    Text(formatPace(run.averagePace))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private var runTypeText: String {
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
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDistance(_ distance: Double) -> String {
        let miles = distance * 0.000621371
        return String(format: "%.2f mi", miles)
    }
    
    private func formatPace(_ pace: Double) -> String {
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        return String(format: "%d:%02d/mi", minutes, seconds)
    }
}

struct FriendActivityCard: View {
    let friend: Friend
    
    var body: some View {
        HStack {
            Circle()
                .fill(friend.isOnline ? Color.green : Color.gray)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(friend.user.username)
                    .font(.subheadline)
                    
                
                Text(statusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("\(friend.totalRuns) runs")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private var statusText: String {
        if friend.isOnline {
            return "Online"
        } else if let lastRun = friend.lastRunDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return "Last run \(formatter.localizedString(for: lastRun, relativeTo: Date()))"
        } else {
            return "No recent runs"
        }
    }
}

#Preview {
    HomeView()
}