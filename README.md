# Motion Storyline Mac App

## Swift Package Manager Setup

This project includes Swift Package Manager (SPM) support through the `Package.swift` file. This allows you to:

1. Build the project using the `swift build` command
2. Use the project as a dependency in other Swift packages
3. Manage dependencies more easily

## Features

### Animation System
- Keyframe-based animation with support for various interpolation methods
- Timeline editor with playback controls
- Property inspector for animation parameters
- Multiple easing functions (linear, ease-in, ease-out, cubic bezier, etc.)

### Export Capabilities
- Video export with various quality options via AVFoundation
- ProRes export for professional workflows
- Image sequence export (PNG, JPEG)
- Support for various export formats

## Build Instructions

To build the project using Swift Package Manager:

```bash
# Build the project
swift build
```

## Testing

The project includes focused unit and UI tests. You can run tests using xcodebuild.

### Using xcodebuild

You can run tests using xcodebuild:

```bash
# Run Project model tests
xcodebuild test -scheme "Motion Storyline" -destination "platform=macOS" -only-testing:Motion\ StorylineTests/ProjectTests

# Run UI launch performance tests
xcodebuild test -scheme "Motion Storyline" -destination "platform=macOS" -only-testing:Motion\ StorylineUITests/Motion_StorylineUITests/testLaunchPerformance

# Run all essential tests
xcodebuild test -scheme "Motion Storyline" -destination "platform=macOS" -only-testing:Motion\ StorylineTests/ProjectTests -only-testing:Motion\ StorylineUITests/Motion_StorylineUITests/testLaunchPerformance
```

### Test Coverage

The test suite focuses on the most valuable tests:

1. **Project Model Tests**:
   - `testProjectInitialization()`: Verifies proper initialization of Project objects with default values
   - `testAddMediaAsset()`: Tests adding media assets to a project and updating the lastModified date
   - `testProjectEquality()`: Validates Project equality comparison based on UUID

2. **UI Performance Tests**:
   - `testLaunchPerformance()`: Measures application launch performance (average launch time and consistency)

The empty placeholder tests and redundant launch tests have been removed from the test commands to focus on tests that provide meaningful information.

## Package Structure

The `Package.swift` file defines:

- **Name**: MotionStoryline
- **Platform**: macOS 14.0 or later (required for `onKeyPress` API)
- **Products**: A library named "MotionStoryline"
- **Targets**:
  - Main target: "MotionStoryline" (source code in "Motion Storyline" directory)
  - Test targets: "MotionStorylineTests" and "MotionStorylineUITests"

## Project Organization

The project is organized into several key directories:

- **Animation/**: Core animation components
  - `AnimationController.swift`: Keyframe animation engine
  - `TimelineView.swift`: Timeline interface
  - `KeyframeEditorView.swift`: Keyframe editing UI
  
- **Utilities/**: Helper classes
  - `VideoExporter.swift`: Export functionality for videos and image sequences
  
- **Common/**: Shared components and models
  - `ExportFormat.swift`: Export format definitions

## Handling SwiftUI Previews

SwiftUI previews are wrapped in conditional compilation blocks to make them compatible with Swift Package Manager builds:

```swift
#if !DISABLE_PREVIEWS
#Preview {
    YourView()
}
#endif
```

The `wrap_previews.sh` script can be used to automatically add these conditional compilation blocks to all Swift files in the project.

## Known Issues and Warnings

The build process may show some warnings about:

1. Unused variables (e.g., `elementId` in arrow key handlers)
2. Unused binding values (e.g., `project` in the main app)

These are minor issues that don't affect functionality but could be cleaned up in future updates.

## Adding Dependencies

To add a dependency to the project, modify the `dependencies` section in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/example/example-package.git", from: "1.0.0"),
],
```

Then add the dependency to the appropriate target:

```swift
.target(
    name: "MotionStoryline",
    dependencies: ["ExamplePackage"],
    // ...
)
``` 