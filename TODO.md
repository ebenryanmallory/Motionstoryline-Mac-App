# Motion Storyline - TODO List

## Immediate Package and Build System Fixes

- [ ] Fix XCTest module import issue in SPM tests
  - **Issue**: Swift Package Manager cannot find the XCTest module when running tests
  - **Solution Options**:
    - Use Xcode directly for running tests instead of SPM
    - Create a separate test package that properly links against XCTest
    - Use conditional compilation for different test environments
- [ ] Fix duplicate conditional compilation blocks in preview macros (fixed in DesignToolbar.swift, needs to be applied to all files)
- [ ] Address code warnings about unused variables in DesignCanvas.swift:
  - Replace `if let elementId = selectedElementId` with `if let _ = selectedElementId` in arrow key handlers
  - Replace `if let startPos = drawStartPosition` with `if let _ = drawStartPosition`
  - Fix `project` variable in Motion_StorylineApp.swift
- [ ] Add resources handling for Assets.xcassets in Package.swift
- [ ] Create a CI workflow for automated builds and tests

## Unit Tests Implementation Plan

- [ ] Set up proper test infrastructure
  - Create a test helper file with common utilities
  - Set up mock data for testing
  - Ensure tests can run both in Xcode and via SPM
- [ ] Create Project model tests (started in ProjectTests.swift)
  - Complete serialization/deserialization tests
  - Add more edge case tests
- [ ] Create CanvasElement tests
  - Test element creation and manipulation
  - Test property updates
  - Test rendering calculations
- [ ] Create AnimationController tests
  - Test animation timing and playback
  - Test keyframe interpolation
  - Test animation state management
- [ ] Create utility function tests
  - Test color conversions
  - Test geometry calculations
  - Test file operations

## UI Tests Implementation Plan (Xcode-only)

*Note: UI tests should be run through Xcode, not SPM, due to XCUITest framework requirements*

- [ ] Create HomeView navigation tests
  - Test navigation to DesignCanvas
  - Test project creation flow
  - Test project selection
- [ ] Create DesignCanvas interaction tests
  - Test tool selection
  - Test element creation
  - Test element selection and manipulation
  - Test inspector panel interactions
- [ ] Create animation timeline tests
  - Test keyframe creation
  - Test playback controls
  - Test animation preview
- [ ] Create export functionality tests
  - Test export options
  - Test file format selection
  - Test export completion

## Performance Tests

- [ ] Create canvas rendering performance tests
  - Test with various numbers of elements
  - Test with complex shapes and paths
- [ ] Create animation playback performance tests
  - Test with various animation durations
  - Test with multiple animated properties
- [ ] Create file operation performance tests
  - Test project loading times
  - Test project saving times
  - Test export times for different formats

## Accessibility Tests

- [ ] Test keyboard navigation throughout the app
- [ ] Test VoiceOver compatibility
- [ ] Test color contrast and readability
- [ ] Test UI scaling and responsiveness

## Test Infrastructure Improvements

- [ ] Create mock objects for testing
  - Mock file system
  - Mock rendering engine
  - Mock animation controller
- [ ] Set up test data fixtures
  - Sample projects
  - Sample media assets
  - Sample animations
- [ ] Implement test helpers and utilities
  - UI interaction helpers
  - Assertion helpers
  - Test result reporters

## Documentation

- [ ] Document test coverage and requirements
- [ ] Create test plan documentation
- [ ] Document test data and fixtures
- [ ] Create testing guidelines for contributors

## Known Issues to Address

1. XCTest module not found when running tests via SPM
2. Duplicate conditional compilation blocks in preview macros
3. Unused variables causing warnings in DesignCanvas.swift
4. Assets.xcassets not properly handled in Package.swift
5. UI tests not compatible with SPM 