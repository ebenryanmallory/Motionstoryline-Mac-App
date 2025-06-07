import AppKit
import Foundation
import UniformTypeIdentifiers

extension NSSavePanel {
    /// Creates a configured save panel for exporting content in the specified format
    /// - Parameters:
    ///   - format: The export format to configure the panel for
    ///   - defaultURL: Optional default URL to use
    /// - Returns: A configured NSSavePanel instance
    static func createExportSavePanel(for format: ExportFormat, defaultURL: URL? = nil) -> NSSavePanel {
        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        
        // Set appropriate title and prompt based on format
        savePanel.title = "Export Project"
        savePanel.prompt = "Export"
        
        // Configure allowed file types and default name based on format
        switch format {
        case .video:
            savePanel.allowedContentTypes = [UTType.mpeg4Movie]
            savePanel.nameFieldStringValue = defaultURL?.lastPathComponent ?? "Motion_Export.mp4"
        case .videoProRes(let profile):
            savePanel.allowedContentTypes = [UTType.quickTimeMovie]
            let profileSuffix = profile.rawValue.replacingOccurrences(of: " ", with: "_")
            savePanel.nameFieldStringValue = defaultURL?.lastPathComponent ?? "Motion_Export_\(profileSuffix).mov"
        case .gif:
            savePanel.allowedContentTypes = [UTType.gif]
            savePanel.nameFieldStringValue = defaultURL?.lastPathComponent ?? "Motion_Export.gif"
        case .imageSequence(let format):
            // For image sequences, we're selecting a directory
            savePanel.allowedContentTypes = []
            savePanel.directoryURL = defaultURL?.deletingLastPathComponent() ?? FileManager.default.homeDirectoryForCurrentUser
            savePanel.nameFieldStringValue = defaultURL?.lastPathComponent ?? "Motion_Export_Sequence"
        case .projectFile:
            savePanel.allowedContentTypes = [UTType.json]
            savePanel.nameFieldStringValue = defaultURL?.lastPathComponent ?? "Motion_Project.json"
        case .batchExport:
            // For batch export, we're selecting a directory
            savePanel.allowedContentTypes = []
            savePanel.directoryURL = defaultURL?.deletingLastPathComponent() ?? FileManager.default.homeDirectoryForCurrentUser
            savePanel.nameFieldStringValue = defaultURL?.lastPathComponent ?? "Motion_Exports"
        }
        
        return savePanel
    }
}

// Define UTType for compatibility
extension UTType {
    static let mpeg4Movie = UTType(filenameExtension: "mp4")!
    static let quickTimeMovie = UTType(filenameExtension: "mov")!
    static let gif = UTType(filenameExtension: "gif")!
    static let json = UTType(filenameExtension: "json")!
}
