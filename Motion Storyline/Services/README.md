# Export Services Architecture

## Overview

The export system has been refactored to follow a modular design pattern that allows for code reuse between different export formats. This architecture separates concerns into three main components:

1. **FrameExporter**: Handles the extraction and saving of individual frames
2. **VideoExporter**: Manages video file creation and encoding
3. **ExportCoordinator**: Coordinates between the frame and video exporters
4. **BatchExportManager**: Manages exporting projects in multiple formats simultaneously

## File Locations

All export-related components are now located in the Services directory:

- **FrameExporter**: `Services/FrameExporter.swift`
- **VideoExporter**: `Services/VideoExporter.swift`
- **ExportCoordinator**: `Services/ExportCoordinator.swift`
- **BatchExportManager**: `Services/BatchExportManager.swift`

## Key Components

### FrameExporter

Responsible for extracting individual frames from an AVAsset and saving them to disk with various format options.

- Can export single frames at specific timestamps
- Can export sequences of frames for image sequence export or for intermediate steps in GIF/video export
- Handles different image formats (PNG, JPEG) with quality settings

### VideoExporter

Handles video export operations:

- Creation of video files with various codecs (H.264, ProRes)
- Audio/video synchronization and muxing
- Hardware acceleration when available
- Fallback encoding paths

### ExportCoordinator

The central coordinator that manages the export process:

- Provides a unified configuration interface for all export types
- Routes export requests to the appropriate specialized exporter
- Handles progress reporting and error management
- Enables code reuse by having image sequence exports power parts of video export

### BatchExportManager

Manages multiple export operations for batch exports:

- Handles queuing of multiple export jobs
- Tracks progress across all exports
- Provides aggregate results of all export operations

### UI Components

- **ExportModal**: User interface for configuring export settings
- **ExportProgressView**: Progress tracking and status reporting

## Workflow Examples

### Image Sequence Export:
1. User configures export in ExportModal
2. ExportModal creates an ExportCoordinator.ExportConfiguration
3. ExportProgressView initializes an ExportCoordinator with the configuration
4. ExportCoordinator uses FrameExporter to extract and save individual frames

### Video Export:
1. Same initial steps as image sequence
2. ExportCoordinator can optionally use FrameExporter to extract frames if needed
3. VideoExporter handles encoding frames into a video file

### Batch Export:
1. User configures multiple export formats
2. BatchExportManager queues each export configuration
3. Each format is processed sequentially using the appropriate exporters

## Benefits

- **Modularity**: Components are independent and can be tested separately
- **Code Reuse**: Image sequence logic can be used by both image and video exports
- **Maintainability**: Easier to add new export formats
- **Performance**: Can optimize each export path independently
- **Consistency**: All export-related services are organized in the same directory

## Future Improvements

- Enhance GIF export with optimized encoding
- Add more video codecs and format options
- Add parallel processing for batch exports 