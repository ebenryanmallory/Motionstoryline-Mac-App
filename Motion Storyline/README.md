# DesignStudio - Design Tool Application

## Project Overview

DesignStudio is a macOS application built with SwiftUI that provides a Figma-like design experience. The application allows users to create, manage, and edit design projects with a professional interface that includes project management, design canvas, and inspector tools.

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
├── RightSidebarView.swift       # Properties and inspector panel
├── FooterView.swift             # Status bar at bottom of app
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

### SidebarView.swift
Left navigation sidebar providing:
- Main app navigation (Home, Projects, Tasks, Settings)
- Search functionality
- Dark mode toggle
- Quick access to create new projects

### RightSidebarView.swift
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

3. **Inspector**
   - Properties panel for adjusting element attributes
   - Transform controls (position, size, rotation)
   - Style controls (fill, stroke, effects)

4. **Navigation**
   - Multi-level navigation (projects → canvas)
   - Sidebar for app-level navigation
   - Tab-based filtering of projects

## Implementation Notes

- The app uses `@State` and `@Binding` for view state management
- `AppStorage` is used for persisting recent projects
- The UI is designed to be responsive with minimum size constraints
- SwiftUI's `Canvas` is used for grid rendering
- Custom components are created for specialized UI elements

## Future Development Considerations

- Add undo/redo functionality
- Implement component libraries
- Add collaboration features
- Enhance export capabilities
- Add more design tools and effects
- Implement custom themes and styles

## System Requirements

- macOS 15.2 or later
- 4GB RAM minimum (8GB recommended)
- 1GB available disk space
- 1280x800 minimum screen resolution 