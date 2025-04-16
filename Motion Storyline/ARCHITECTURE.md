# DesignStudio - Design Tool Application

## Project Overview

DesignStudio is a macOS application built with SwiftUI that provides a Figma-like design experience. The application allows users to create, manage, and edit design projects with a professional interface that includes project management, design canvas, and inspector tools. It also features advanced animation capabilities with keyframe editing and timeline controls.

## Development Environment

- **Platform**: macOS
- **Development Tool**: Xcode (Version 16+)
- **Language**: Swift 5.9+
- **Framework**: SwiftUI
- **Target OS**: macOS 15.2+
- **Architecture**: MVVM (Model-View-ViewModel)

## UI Style Guide

DesignStudio follows a clean, modern UI design language inspired by professional design tools:

### Color Scheme
- **Background**: Light gray (`Color(NSColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1.0))`)
- **Header/Toolbar**: White (`Color.white`)
- **Accent**: Blue (`Color.blue`)
- **Borders**: Light gray (`Color(NSColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0))`)
- **Text**: Black (primary), Gray (secondary)

### Typography
- **Headers**: System font, semibold, various sizes
- **Body Text**: System font, regular
- **Labels**: System font, caption size for smaller elements

### UI Components
- **Cards**: Rounded corners (8pt), subtle shadows
- **Buttons**: Bordered prominent style for primary actions
- **Toolbars**: Clean, icon-based with tooltips
- **Panels**: Collapsible, with clear section headers

## Application Structure

The application follows a two-level navigation structure:
1. **Home View**: Project selection and management
2. **Design Canvas**: The main workspace for editing designs

### File Structure

```
Motion Storyline/
├── Motion_StorylineApp.swift    # Main app entry point
├── HomeView.swift               # Project selection view
├── DesignCanvas.swift           # Main design workspace
├── SidebarView.swift            # Left navigation sidebar
├── InspectorView.swift          # Properties and inspector panel
├── FooterView.swift             # Status bar at bottom of app
├── Animation/                   # Animation components
│   ├── AnimationController.swift         # Core animation logic
│   ├── TimelineView.swift                # Timeline UI
│   ├── KeyframeEditorView.swift          # Keyframe editing
│   ├── PropertyInspectorView.swift       # Animation properties
│   └── AnimatableProperty.swift          # Animatable property definition
├── Utilities/                   # Utility components
│   ├── VideoExporter.swift                # Video export functionality
│   └── MousePositionView.swift            # Mouse tracking
├── Common/                      # Shared components
│   └── ExportFormat.swift                 # Export format definitions
├── UI Components/               # Reusable UI elements
├── Canvas/                      # Canvas-related components
├── Info.plist                   # App configuration
├── Assets.xcassets/             # Images and resources
└── Preview Content/             # Preview assets
```

## Component Descriptions

### Motion_StorylineApp.swift
The main entry point for the application. It manages:
- App lifecycle
- Navigation between HomeView and DesignCanvas
- Project state management
- Recent projects persistence using AppStorage

### HomeView.swift
The landing page and project management interface:
- Project grid with cards for each design project
- Team management section
- Tab navigation for different project categories
- New project creation
- Integration with left and right sidebars
- Status footer

### DesignCanvas.swift
The main workspace for design editing:
- Canvas with zoom and pan capabilities
- Design tools (select, rectangle, ellipse, text, pen, hand)
- Layers panel for managing design elements
- Top navigation bar with menus
- Grid background with customizable visibility

### Animation Components

#### AnimationController.swift
Core animation engine that provides:
- Keyframe-based animation system
- Multiple interpolation methods (linear, ease-in, ease-out, etc.)
- Support for various animatable properties (position, size, opacity, color)
- Timeline synchronization

#### TimelineView.swift
Timeline interface for animation control:
- Timeline scrubbing
- Playback controls (play, pause, stop)
- Frame markers and time indicators
- Track visualization

#### KeyframeEditorView.swift
Interface for editing keyframes:
- Adding/removing keyframes
- Adjusting keyframe timing
- Setting easing functions
- Multi-property editing

### Utilities

#### VideoExporter.swift
Handles exporting animations to various formats:
- Multiple video formats with quality settings
- ProRes export options
- Image sequence export
- GIF generation
- Progress reporting and error handling

### SidebarView.swift
Left navigation sidebar providing:
- Main app navigation (Home, Projects, Tasks, Settings)
- Search functionality
- Dark mode toggle
- Quick access to create new projects

### InspectorView.swift
Properties and inspector panel:
- Collapsible interface
- Properties panel for adjusting element attributes
- Inspector panel for examining design details
- Form-based controls (sliders, color pickers, etc.)

### FooterView.swift
Status bar at the bottom of the application:
- Current status display
- Connection indicator
- Version information

## Data Models

### Project
Represents a design project with:
- Unique identifier
- Name
- Thumbnail reference
- Last modified date
- Codable conformance for persistence

## Key Features

1. **Project Management**
   - Create, open, and manage design projects
   - Recent projects tracking
   - Project templates

2. **Design Tools**
   - Basic shape creation (rectangle, ellipse)
   - Text tool
   - Selection and transformation
   - Hand tool for canvas navigation

3. **Animation System**
   - Keyframe-based animation
   - Timeline editor with playback controls
   - Multiple interpolation methods and easing functions
   - Property inspector for animation parameters

4. **Export Capabilities**
   - Video export with various quality options
   - ProRes export for professional workflows
   - Image sequence export
   - GIF generation

5. **Inspector**
   - Properties panel for adjusting element attributes
   - Transform controls (position, size, rotation)
   - Style controls (fill, stroke, effects)

6. **Navigation**
   - Multi-level navigation (projects → canvas)
   - Sidebar for app-level navigation
   - Tab-based filtering of projects

## Implementation Notes

- The app uses `@State` and `@Binding` for view state management
- `AppStorage` is used for persisting recent projects
- The UI is designed to be responsive with minimum size constraints 