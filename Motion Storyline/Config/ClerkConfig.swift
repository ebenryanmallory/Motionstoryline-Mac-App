import Foundation

struct ClerkConfig {
    private static let configPlist: [String: Any] = {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            fatalError("Config.plist not found or invalid format")
        }
        return plist
    }()
    
    static var publishableKey: String {
        guard let key = configPlist["ClerkPublishableKey"] as? String,
              !key.isEmpty,
              key != "YOUR_CLERK_PUBLISHABLE_KEY_HERE" else {
            fatalError("ClerkPublishableKey not configured in Config.plist")
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
        return publishableKey
    }
} 