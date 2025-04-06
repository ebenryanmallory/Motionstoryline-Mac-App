# Prompting Keywords for Motion Storyline

When a user provides this document along with a single keyword, EXECUTE the corresponding commands immediately.

## build

When the user sends "@prompting.md build", Cursor should:

1. Run the Swift Package Manager build command:
```bash
swift build
```

This will build the project using the configuration in Package.swift.

## test

When the user sends "@prompting.md test", run the essential tests as specified in the README by executing this command:

```bash
xcodebuild test -scheme "Motion Storyline" -destination "platform=macOS" -only-testing:Motion\ StorylineTests/ProjectTests -only-testing:Motion\ StorylineUITests/Motion_StorylineUITests/testLaunchPerformance
```

This command runs the following test suites:

1. Project Model Tests:
   - testProjectInitialization()
   - testAddMediaAsset()
   - testProjectEquality()

2. UI Performance Tests:
   - testLaunchPerformance()

If the user wants to run only specific test groups, these commands are available:

- For Project model tests only:
```bash
xcodebuild test -scheme "Motion Storyline" -destination "platform=macOS" -only-testing:Motion\ StorylineTests/ProjectTests
```

- For UI launch performance tests only:
```bash
xcodebuild test -scheme "Motion Storyline" -destination "platform=macOS" -only-testing:Motion\ StorylineUITests/Motion_StorylineUITests/testLaunchPerformance
``` 