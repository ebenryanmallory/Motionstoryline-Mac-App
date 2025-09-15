import SwiftUI
import Clerk

struct AuthControls: View {
    // Use the app's AuthenticationManager rather than an Environment(\.clerk) key
    // since the Clerk SDK does not define an EnvironmentValues.clerk key.
    @EnvironmentObject private var authManager: AuthenticationManager
    private let clerk = Clerk.shared
    @State private var authIsPresented = false

    var body: some View {
        Group {
            if authManager.isAuthenticated || clerk.user != nil {
                AuthProfileButton()
                    .frame(width: 36, height: 36)
            } else {
                Button(action: { authIsPresented = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "person.crop.circle")
                        Text("Sign in")
                    }
                    .foregroundColor(.black)
                    .padding(8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Sign in")
            }
        }
        .sheet(isPresented: $authIsPresented) {
            AuthenticationView()
                .environmentObject(authManager)
        }
    }
}

#if DEBUG
#Preview {
    AuthControls()
        .environmentObject(AuthenticationManager())
}
#endif
