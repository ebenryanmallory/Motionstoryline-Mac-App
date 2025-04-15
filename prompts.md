# Prompting Keywords for Motion Storyline

When a user provides this document along with a single keyword, EXECUTE the corresponding commands immediately.

## build

When the user sends "@prompts.md build", Cursor should:

1. Run the Swift Package Manager build command:
```bash
swift build
```

This will build the project using the configuration in Package.swift.

## test

When the user sends "@prompts.md test", run the essential tests as specified in the README by executing this command:

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

## todo

When the user sends "@prompts.md todo", Cursor should:

1. Read the TODO.md file to assess the current prioritized task list
2. Select the highest priority task (either the first uncompleted item or most critical based on importance)
3. Present the selected task for implementation
4. After implementation, update the TODO.md file to:
   - Mark the task as completed [x]
   - Remove the task if fully resolved
   - Or modify the task into subtasks based on implementation results

This command helps maintain an organized workflow by systematically addressing the highest priority tasks in the project. 