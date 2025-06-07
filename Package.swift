// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MotionStoryline",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MotionStoryline", targets: ["MotionStoryline"])
    ],
    dependencies: [
        .package(url: "https://github.com/clerk/clerk-ios", from: "0.1.0")
    ],
    targets: [
        .executableTarget(
            name: "MotionStoryline",
            dependencies: [
                .product(name: "Clerk", package: "clerk-ios")
            ],
            path: "Motion Storyline",
            exclude: [
                // Exclude entitlements as they're build configuration files
                "Motion_Storyline.entitlements"
            ],
            resources: [
                // Use a specific copying rule for asset catalogs to preserve their structure
                .copy("Assets.xcassets"),
                .process("Preview Content"),
                // Include documentation files
                .process("ARCHITECTURE.md"),
                .process("Services/README.md"),
                // Include configuration files
                .process("Config/Config.plist"),
                .process("Config/Config.plist.template")
            ]
        ),
        .testTarget(
            name: "MotionStorylineTests",
            dependencies: ["MotionStoryline"],
            path: "Motion StorylineTests"
        ),
        .testTarget(
            name: "MotionStorylineUITests",
            dependencies: ["MotionStoryline"],
            path: "Motion StorylineUITests"
        )
    ]
)

#if canImport(PackagePlugin)
import PackagePlugin

@main
struct TestCommand: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) async throws {
        print("Running tests for MotionStoryline...")
        
        // Parse command-line arguments to determine which tests to run
        var testType = "project" // Default to running project tests only
        var verbose = false
        
        for (index, arg) in arguments.enumerated() {
            if arg == "--type" && index + 1 < arguments.count {
                testType = arguments[index + 1]
            } else if arg == "--verbose" {
                verbose = true
            }
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        
        // Configure the test command based on the requested test type
        switch testType {
        case "unit":
            print("Running unit tests only...")
            process.arguments = [
                "xcodebuild", "test",
                "-scheme", "Motion Storyline",
                "-destination", "platform=macOS",
                "-only-testing:Motion\\ StorylineTests/ProjectTests"
            ]
        case "ui":
            print("Running UI tests only...")
            process.arguments = [
                "xcodebuild", "test",
                "-scheme", "Motion Storyline",
                "-destination", "platform=macOS",
                "-only-testing:Motion\\ StorylineUITests/Motion_StorylineUITests/testLaunchPerformance"
            ]
        case "all":
            print("Running all essential tests...")
            process.arguments = [
                "xcodebuild", "test",
                "-scheme", "Motion Storyline",
                "-destination", "platform=macOS",
                "-only-testing:Motion\\ StorylineTests/ProjectTests",
                "-only-testing:Motion\\ StorylineUITests/Motion_StorylineUITests/testLaunchPerformance"
            ]
        default:
            print("Running Project model tests only...")
            process.arguments = [
                "xcodebuild", "test",
                "-scheme", "Motion Storyline",
                "-destination", "platform=macOS",
                "-only-testing:Motion\\ StorylineTests/ProjectTests"
            ]
        }
        
        // Add verbose output if requested
        if verbose {
            process.arguments?.append(contentsOf: ["-verbose"])
        }
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus == 0 {
            print("Tests completed successfully!")
        } else {
            print("Tests failed with status: \(process.terminationStatus)")
        }
    }
}
#endif 