import SwiftUI
import Foundation

// Simple Virtual Running Companion App
@main
struct VirtualRunningCompanionApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var isRunning = false
    @State private var distance = 0.0
    @State private var pace = 0.0
    @State private var duration = 0
    @State private var timer: Timer?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Header
                VStack {
                    Text("🏃‍♂️ Virtual Running Companion")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Your Personal Running Coach")
                        .font(.subtitle)
                        .foregroundColor(.secondary)
                }
                
                // Stats Display
                VStack(spacing: 20) {
                    HStack(spacing: 40) {
                        StatView(title: "Distance", value: String(format: "%.2f mi", distance), icon: "figure.run")
                        StatView(title: "Pace", value: String(format: "%.1f min/mi", pace), icon: "speedometer")
                    }
                    
                    StatView(title: "Duration", value: formatTime(duration), icon: "timer")
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(15)
                
                // Control Buttons
                VStack(spacing: 15) {
                    Button(action: toggleRun) {
                        HStack {
                            Image(systemName: isRunning ? "pause.fill" : "play.fill")
                            Text(isRunning ? "Pause Run" : "Start Run")
                        }
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isRunning ? Color.orange : Color.green)
                        .cornerRadius(12)
                    }
                    
                    if isRunning || distance > 0 {
                        Button(action: stopRun) {
                            HStack {
                                Image(systemName: "stop.fill")
                                Text("Stop Run")
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
                
                Spacer()
                
                // Features List
                VStack(alignment: .leading, spacing: 8) {
                    Text("Features:")
                        .font(.headline)
                    
                    FeatureRow(icon: "location.fill", text: "GPS Tracking")
                    FeatureRow(icon: "person.2.fill", text: "Run with Friends")
                    FeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Performance Analytics")
                    FeatureRow(icon: "heart.fill", text: "Health Integration")
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .padding()
            .navigationTitle("Running")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func toggleRun() {
        isRunning.toggle()
        
        if isRunning {
            startTimer()
        } else {
            stopTimer()
        }
    }
    
    private func stopRun() {
        isRunning = false
        stopTimer()
        
        // Reset stats
        distance = 0.0
        pace = 0.0
        duration = 0
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            duration += 1
            
            // Simulate running data
            let increment = Double.random(in: 0.01...0.03)
            distance += increment
            
            if duration > 0 {
                pace = Double(duration) / (distance * 60) // minutes per mile
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}

struct StatView: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 100)
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(text)
                .font(.body)
        }
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
