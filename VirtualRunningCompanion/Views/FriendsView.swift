import SwiftUI

struct FriendsView: View {
    @State private var friends: [Friend] = []
    @State private var searchText = ""
    @State private var showingAddFriend = false
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                searchBar
                
                // Tab Selector
                tabSelector
                
                // Content
                TabView(selection: $selectedTab) {
                    friendsListView
                        .tag(0)
                    
                    onlineFriendsView
                        .tag(1)
                    
                    pendingRequestsView
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Friends")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddFriend = true }) {
                        Image(systemName: "person.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddFriend) {
                AddFriendView()
            }
            .onAppear {
                loadFriends()
            }
        }
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search friends", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .padding(.horizontal)
    }
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            TabButton(title: "All Friends", isSelected: selectedTab == 0) {
                selectedTab = 0
            }
            
            TabButton(title: "Online", isSelected: selectedTab == 1) {
                selectedTab = 1
            }
            
            TabButton(title: "Requests", isSelected: selectedTab == 2) {
                selectedTab = 2
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    private var friendsListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredFriends) { friend in
                    FriendCard(friend: friend) {
                        // TODO: Navigate to friend profile or start run
                    }
                }
            }
            .padding()
        }
        .refreshable {
            await refreshFriends()
        }
    }
    
    private var onlineFriendsView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(onlineFriends) { friend in
                    OnlineFriendCard(friend: friend) {
                        // TODO: Invite to run
                    }
                }
                
                if onlineFriends.isEmpty {
                    Text("No friends online")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .padding()
        }
        .refreshable {
            await refreshFriends()
        }
    }
    
    private var pendingRequestsView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(pendingRequests) { friend in
                    PendingRequestCard(friend: friend,
                                     onAccept: { acceptFriendRequest(friend) },
                                     onDecline: { declineFriendRequest(friend) })
                }
                
                if pendingRequests.isEmpty {
                    Text("No pending requests")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .padding()
        }
        .refreshable {
            await refreshFriends()
        }
    }
    
    private var filteredFriends: [Friend] {
        if searchText.isEmpty {
            return friends.filter { $0.status == .accepted }
        } else {
            return friends.filter { 
                $0.status == .accepted && 
                $0.user.username.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private var onlineFriends: [Friend] {
        friends.filter { $0.status == .accepted && $0.isOnline }
    }
    
    private var pendingRequests: [Friend] {
        friends.filter { $0.status == .pending }
    }
    
    private func loadFriends() {
        // TODO: Load friends from service
        // For now, using sample data
        friends = []
    }
    
    private func refreshFriends() async {
        // TODO: Refresh friends data
    }
    
    private func acceptFriendRequest(_ friend: Friend) {
        // TODO: Accept friend request
    }
    
    private func declineFriendRequest(_ friend: Friend) {
        // TODO: Decline friend request
    }
}

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    Rectangle()
                        .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
                        .cornerRadius(6)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct FriendCard: View {
    let friend: Friend
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Profile Picture Placeholder
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(String(friend.user.username.prefix(1)).uppercased())
                            .font(.title2)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(friend.user.username)
                            .font(.headline)
                        
                        if friend.isOnline {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                        }
                    }
                    
                    Text("\(friend.totalRuns) runs completed")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let lastRun = friend.lastRunDate {
                        Text("Last run: \(formatRelativeDate(lastRun))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(spacing: 8) {
                    Button(action: {}) {
                        Image(systemName: "message.fill")
                            .foregroundColor(.accentColor)
                    }
                    
                    Button(action: {}) {
                        Image(systemName: "figure.run")
                            .foregroundColor(.green)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct OnlineFriendCard: View {
    let friend: Friend
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.green)
                .frame(width: 50, height: 50)
                .overlay(
                    Text(String(friend.user.username.prefix(1)).uppercased())
                        .font(.title2)
                        
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(friend.user.username)
                    .font(.headline)
                    
                
                HStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    
                    Text("Online now")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
            }
            
            Spacer()
            
            Button(action: action) {
                HStack {
                    Image(systemName: "person.badge.plus")
                    Text("Invite to Run")
                }
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.accentColor)
                .cornerRadius(16)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct PendingRequestCard: View {
    let friend: Friend
    let onAccept: () -> Void
    let onDecline: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.orange)
                .frame(width: 50, height: 50)
                .overlay(
                    Text(String(friend.user.username.prefix(1)).uppercased())
                        .font(.title2)
                        
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(friend.user.username)
                    .font(.headline)
                    
                
                Text("Wants to be friends")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button(action: onDecline) {
                    Image(systemName: "xmark")
                        .foregroundColor(.red)
                        .padding(8)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Circle())
                }
                
                Button(action: onAccept) {
                    Image(systemName: "checkmark")
                        .foregroundColor(.green)
                        .padding(8)
                        .background(Color.green.opacity(0.1))
                        .clipShape(Circle())
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct AddFriendView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var searchResults: [User] = []
    @State private var isSearching = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search by username or email", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onSubmit {
                            searchUsers()
                        }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal)
                
                // Search Results
                if isSearching {
                    ProgressView("Searching...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if searchResults.isEmpty && !searchText.isEmpty {
                    Text("No users found")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(searchResults) { user in
                                UserSearchResultCard(user: user) {
                                    sendFriendRequest(to: user)
                                }
                            }
                        }
                        .padding()
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func searchUsers() {
        guard !searchText.isEmpty else { return }
        
        isSearching = true
        // TODO: Implement user search
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isSearching = false
            searchResults = [] // Would be populated with actual search results
        }
    }
    
    private func sendFriendRequest(to user: User) {
        // TODO: Send friend request
    }
}

struct UserSearchResultCard: View {
    let user: User
    let onAddFriend: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(user.username.prefix(1)).uppercased())
                        .font(.headline)
                        
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(user.username)
                    .font(.subheadline)
                    
                
                Text(user.email)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: onAddFriend) {
                Text("Add")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.accentColor)
                    .cornerRadius(16)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    FriendsView()
}