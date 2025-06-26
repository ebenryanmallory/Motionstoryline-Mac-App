import Foundation

struct ClerkConfig {
    private static let configPlist: [String: Any] = {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            print("Warning: Config.plist not found. Authentication will be unavailable.")
            return [:]
        }
        return plist
    }()
    
    static var publishableKey: String? {
        guard let key = configPlist["ClerkPublishableKey"] as? String,
              !key.isEmpty,
              key != "YOUR_CLERK_PUBLISHABLE_KEY_HERE" else {
            print("Warning: ClerkPublishableKey not configured in Config.plist. Authentication will be unavailable.")
            return nil
        }
        return key
    }
    
    static var environment: String {
        return configPlist["Environment"] as? String ?? "development"
    }
    
    static var apiBaseURL: String {
        return configPlist["APIBaseURL"] as? String ?? "https://api.clerk.dev"
    }
    
    // For development, you might want to use different keys for different environments
    static var currentPublishableKey: String {
        return publishableKey ?? "pk_test_placeholder_key_for_offline_mode"
    }
    
    // Check if authentication is properly configured
    static var isAuthenticationConfigured: Bool {
        return publishableKey != nil
    }
} 