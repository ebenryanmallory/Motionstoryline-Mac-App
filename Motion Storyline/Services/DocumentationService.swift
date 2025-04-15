import Foundation

// Service for accessing documentation content
class DocumentationService {
    static let shared = DocumentationService()
    
    enum DocumentationType: String, CaseIterable {
        case keyboardShortcuts
        case voiceOverCompatibility
        case voiceOverTestingChecklist
        
        var title: String {
            switch self {
            case .keyboardShortcuts:
                return "Keyboard Shortcuts"
            case .voiceOverCompatibility:
                return "VoiceOver Compatibility"
            case .voiceOverTestingChecklist:
                return "VoiceOver Testing Checklist"
            }
        }
        
        var iconName: String {
            switch self {
            case .keyboardShortcuts:
                return "keyboard"
            case .voiceOverCompatibility:
                return "ear"
            case .voiceOverTestingChecklist:
                return "checklist"
            }
        }
        
        var helpText: String {
            switch self {
            case .keyboardShortcuts:
                return "View keyboard shortcuts for Motion Storyline"
            case .voiceOverCompatibility:
                return "Learn about VoiceOver compatibility features"
            case .voiceOverTestingChecklist:
                return "Checklist for testing VoiceOver compatibility"
            }
        }
    }
    
    // Get documentation content for a specific type
    func getDocumentation(type: DocumentationType) -> String {
        switch type {
        case .keyboardShortcuts:
            return keyboardShortcutsContent
        case .voiceOverCompatibility:
            return voiceOverCompatibilityContent
        case .voiceOverTestingChecklist:
            return voiceOverTestingChecklistContent
        }
    }
    
    // Get all available documentation types
    func getAllDocumentationTypes() -> [DocumentationType] {
        return DocumentationType.allCases
    }
    
    // MARK: - Hardcoded Documentation Content
    
    private let keyboardShortcutsContent = """
MOTION STORYLINE KEYBOARD SHORTCUTS

TIMELINE NAVIGATION AND KEYFRAME CONTROL
-----------------------------------------
P                    Play/Pause animation
←                    Move backward by 0.1 seconds
→                    Move forward by 0.1 seconds
K                    Add keyframe at current time
Delete or Backspace  Delete selected keyframe
Tab                  Jump to next keyframe
Shift+Tab            Jump to previous keyframe
Home                 Go to beginning of timeline (0:00)
End                  Go to end of timeline

GENERAL APPLICATION SHORTCUTS
-----------------------------------------
⌘N                   New Project
⌘S                   Save Project
⌘O                   Open Project
⌘+                   Zoom In
⌘-                   Zoom Out
⌘0                   Reset Zoom to 100%
⌘/                   Show Keyboard Shortcuts Help

TIMELINE EDITOR CONTROLS
-----------------------------------------
R                    Reset animation to beginning
⌘A                   Center content in viewport
Space                Pan canvas with mouse (click and drag)
"""
    
    private let voiceOverCompatibilityContent = """
VOICEOVER COMPATIBILITY TESTING FOR MOTION STORYLINE

OVERVIEW
-----------------------------------------
This guide outlines the process for testing Motion Storyline with macOS VoiceOver to ensure the application is accessible to users with visual impairments. VoiceOver is a screen reader built into macOS that allows users to navigate and interact with applications through spoken descriptions and keyboard commands.

PREREQUISITES
-----------------------------------------
• macOS with VoiceOver enabled (can be toggled with Command + F5)
• Motion Storyline application running
• Familiarity with basic VoiceOver commands

KEY VOICEOVER COMMANDS
-----------------------------------------
• VO refers to the VoiceOver modifier keys (Control + Option)
• VO + Space: Activate the selected item
• VO + Left/Right Arrow: Navigate between items
• VO + U: Use the item chooser
• VO + Command + H: Next heading
• VO + Shift + Command + H: Previous heading
• VO + Command + L: Next link/interactive element
• VO + Shift + Command + L: Previous link/interactive element

TESTING PROCESS
-----------------------------------------

1. GENERAL UI NAVIGATION
Verify that VoiceOver can navigate through all main UI elements and correctly announce:
• Buttons
• Text fields
• Dropdowns
• Tabs
• Modal dialogs
• Navigation areas

2. KEY SCREENS AND COMPONENTS TO TEST

HomeView:
• Project cards (verify each card is properly announced with project name and date)
• Tab navigation between Recent, All Projects, and Templates
• New Project button
• Search field
• User menu

New Project Dialog:
• Project type selection cards
• Text field for project name
• Cancel and Create buttons

DesignCanvas:
• Tool selection
• Canvas navigation
• Property inspectors
• Timeline controls
• Layer management

Media Browser:
• Media asset selection
• Import options
• File listing navigation

Export Options:
• Format selection
• Export setting controls
• Progress indicators

3. SPECIFIC ACCESSIBILITY CHECKS

Semantic Structure:
• Ensure headings are properly marked up for navigation
• Verify logical reading order of content
• Test landmark navigation (main content, navigation, etc.)

Form Controls:
• Verify all form fields have appropriate labels
• Check that error messages are announced
• Ensure dropdown menus are accessible

Images and Media:
• Verify all images have descriptive alt text
• Check that decorative images are marked as such
• Ensure media controls are accessible

Interactive Elements:
• Test drag and drop operations with VoiceOver
• Verify canvas element selection is announced
• Check that timeline scrubbing is accessible

Keyboard Navigation:
• Ensure all functionality is accessible via keyboard
• Verify focus indicators are visible
• Check that keyboard shortcuts work with VoiceOver

IMPLEMENTATION GUIDELINES
-----------------------------------------

Adding Accessibility Labels:
Add appropriate accessibility labels to UI components using SwiftUI's .accessibilityLabel() modifier.

Providing Hints:
Add hints for complex interactions using .accessibilityHint().

Grouping Related Elements:
Group related elements with .accessibilityElement(children: .combine).

Hiding Decorative Elements:
Hide purely decorative elements with .accessibilityHidden(true).
"""
    
    private let voiceOverTestingChecklistContent = """
VOICEOVER TESTING CHECKLIST FOR MOTION STORYLINE

This checklist should be used by QA testers to manually verify VoiceOver compatibility throughout the app. Complete each task and mark as Pass/Fail with notes.

SETUP INSTRUCTIONS
-----------------------------------------
1. Enable VoiceOver on your Mac: 
   • Press Command + F5 or 
   • Go to System Preferences > Accessibility > VoiceOver > Enable VoiceOver

2. Basic VoiceOver commands to use during testing:
   • VO = Control + Option (the VoiceOver modifier keys)
   • Navigate: VO + Right/Left Arrow
   • Activate: VO + Space
   • Read current item: VO + A
   • Jump to content: VO + U to open the item chooser

HOMEVIEW TESTING
-----------------------------------------
• Navigate through main header - VoiceOver should announce "DesignStudio" and header trait
• Navigate to search field - Should announce "Search files"
• Navigate to user menu - Should announce "User Menu" with hint "Access profile and settings"
• Navigate through tabs - Should announce each tab name with selected state
• Navigate through project cards - Should announce project name with hint to open
• Find and activate "New Project" button - Should announce "Create New Project" and open dialog when activated

NEW PROJECT DIALOG TESTING
-----------------------------------------
• Dialog header - Should announce "New Project" with header trait
• Project type selection - Should announce each project type with selected state
• Project name field - Should announce "Untitled Project" text field
• Cancel button - Should announce "Cancel" button
• Create button - Should announce "Create" button
• Dialog navigation - Should be able to navigate through all dialog elements

DESIGNCANVAS TESTING
-----------------------------------------
• Tool selection - Each tool should be properly announced with function
• Canvas navigation - Should announce elements on canvas
• Property inspector - Should announce property names and values
• Timeline controls - Should announce playback controls with function
• Keyframe markers - Should announce keyframe positions

KEYBOARD NAVIGATION TESTING
-----------------------------------------
• Tab navigation on HomeView - Focus should move logically through UI elements
• Escape key in dialogs - Should close dialog
• Shortcut keys - Should work with VoiceOver enabled
• Arrow keys - Should navigate as expected in timeline

ISSUE REPORTING
-----------------------------------------
For any failed tests, please document:

1. The specific element that failed
2. The expected announcement
3. The actual behavior observed 
4. Steps to reproduce
5. Screen recording if possible
6. macOS version and VoiceOver settings
"""
} 