import SwiftUI

/// Compact avatar/profile button for authenticated users
/// Opens the user profile sheet on click.
struct AuthProfileButton: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @State private var showProfile = false

    var body: some View {
        Button(action: { showProfile = true }) {
            ZStack {
                Circle()
                    .fill(Color(NSColor.controlBackgroundColor))
                if let initials = initials {
                    Text(initials)
                        .font(.headline)
                        .foregroundColor(.primary)
                } else {
                    Image(systemName: "person.crop.circle")
                        .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(width: 36, height: 36)
        .sheet(isPresented: $showProfile) {
            UserProfileView()
                .environmentObject(authManager)
        }
        .help("View profile and sign out")
    }

    private var initials: String? {
        let first = authManager.user?.firstName?.first
        let last = authManager.user?.lastName?.first
        switch (first, last) {
        case let (f?, l?): return String([f, l])
        case let (f?, nil): return String(f)
        case let (nil, l?): return String(l)
        default: return nil
        }
    }
}

#if DEBUG
#Preview {
    AuthProfileButton()
        .environmentObject(AuthenticationManager())
}
#endif

