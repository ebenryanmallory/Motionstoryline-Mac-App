# Motion Storyline - TODO List

## Critical Issues

- [ ] Fix video rendering inconsistencies with canvas
  - [ ] Resolve element color discrepancies between canvas and exported video
  - [ ] Fix text rendering issue - text not appearing in exported videos
  - [ ] Verify whether animations are properly captured in video export
  - [ ] Implement comprehensive rendering tests to ensure canvas-export parity

## High Priority

- [ ] Optimize timeline performance with large number of keyframes
  - [ ] Implement virtualized rendering for timeline tracks
  - [ ] Optimize keyframe calculations for complex animations
  - [ ] Improve scrubbing performance on long timelines
- [ ] Update test files to match current API structure
  - **Issue**: AnimationControllerTests fails with "KeyframeTrack specialized with too few type parameters"
  - **Solution**: Update tests to use all three required type parameters for KeyframeTrack
- [x] Verify testing infrastructure works properly
  - Confirmed Xcode test runner correctly identifies and reports compilation issues
  - Test runner successfully provides detailed error messages for diagnosis

## Medium Priority

- [ ] Add resources handling for Assets.xcassets in Package.swift
- [ ] Create a CI workflow for automated builds and tests
- [ ] Expand animation capabilities
  - [ ] Add support for path animation
  - [ ] Implement animation presets (fade, slide, bounce, etc.)
  - [ ] Add support for audio synchronization
- [ ] Improve export functionality
  - [ ] Add batch export capability for multiple formats
  - [ ] Implement background processing for large exports

## Testing Plan

- [ ] Canvas-to-export rendering tests
  - [ ] Test color accuracy across various element types
  - [ ] Test text rendering in different fonts and sizes
  - [ ] Test animation playback in exported videos
  - [ ] Test complex compositions with multiple elements
- [ ] Performance tests
  - [ ] Test canvas rendering with various element counts
  - [ ] Test animation playback with complex animations
  - [ ] Test export times for different formats and complexities

## Accessibility and UX Improvements

- [ ] Test VoiceOver compatibility
- [ ] Test color contrast and readability
- [ ] Test UI scaling and responsiveness
- [ ] Implement keyboard shortcuts for animation timeline
  - [ ] Shortcut for adding keyframes
  - [ ] Shortcut for moving between keyframes
  - [ ] Shortcut for playback control
- [ ] Add haptic feedback for important interactions
  - [ ] When snapping to keyframes
  - [ ] When reaching the end of timeline
  - [ ] When completing export

## Future Enhancements

- [ ] Implement advanced animation features
  - [ ] Multi-track animation for complex sequences
  - [ ] Curve editor for fine-tuned easing control
  - [ ] Motion blur effects for realistic animation
  - [ ] Animation templates and presets
- [ ] Expand export capabilities
  - [ ] Web-optimized export formats (WebM, AVIF)
  - [ ] Lottie/JSON animation format support

## Documentation

- [ ] Document test coverage and requirements
- [ ] Create animation system documentation
  - [ ] Keyframe system architecture
  - [ ] Available animation properties
  - [ ] Easing function implementation
- [ ] Document video export options and best practices
  - [ ] ProRes export workflow
  - [ ] Image sequence export tutorial

## Known Issues to Address

1. AnimationControllerTests needs to be updated to match current KeyframeTrack API
2. Video rendering does not match canvas view
3. Text elements not appearing in exported videos
4. Element colors rendering incorrectly in exports
5. Uncertain animation capture in video exports
6. Assets.xcassets not properly handled in Package.swift
7. UI tests not compatible with SPM 