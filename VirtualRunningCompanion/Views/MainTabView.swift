import SwiftUI
import VirtualRunningCompanion

struct MainTabView: View {
    @State private var selectedTab = 0
    
    // Services
    private let locationService = LocationTrackingService()
    private let syncService = RealTimeSyncService(serverURL: URL(string: "wss://example.com/ws")!)
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .tag(0)
            
            RunView(locationService: locationService, syncService: syncService)
                .tabItem {
                    Image(systemName: "figure.run")
                    Text("Run")
                }
                .tag(1)
            
            FriendsView()
                .tabItem {
                    Image(systemName: "person.2.fill")
                    Text("Friends")
                }
                .tag(2)
            
            HistoryView()
                .tabItem {
                    Image(systemName: "clock.fill")
                    Text("History")
                }
                .tag(3)
        }
        .accentColor(.primary)
    }
}

#Preview {
    MainTabView()
}