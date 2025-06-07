import Foundation
import SwiftUI
import AVFoundation

/// Manages the exporting of projects in multiple formats simultaneously
@MainActor // Added to ensure UI updates are on the main thread
@available(macOS 10.15, *)
public class BatchExportManager: ObservableObject {
    
    @Published public var progress: Float = 0.0
    @Published public var currentExportIndex: Int = 0
    @Published public var totalExportCount: Int = 0
    @Published public var currentExportName: String = ""
    @Published public var isExporting: Bool = false
    
    private var configurations: [VideoExporter.ExportConfiguration] = []
    private var asset: AVAsset?
    private var exportResults: [ExportResult] = []
    private var completionHandler: (([ExportResult]) -> Void)?
    
    /// Result of a single export operation
    public struct ExportResult {
        public let configuration: VideoExporter.ExportConfiguration
        public let status: ExportStatus
        public let outputURL: URL?
        public let error: Error?
        
        public enum ExportStatus {
            case success
            case failure
            case skipped
        }
    }
    
    public init() {}
    
    /// Start a batch export with multiple configurations
    /// - Parameters:
    ///   - configurations: Array of export configurations
    ///   - asset: The asset to export
    ///   - completion: Callback with results of all exports
    public func startBatchExport(
        configurations: [VideoExporter.ExportConfiguration],
        asset: AVAsset,
        completion: @escaping ([ExportResult]) -> Void
    ) {
        guard !configurations.isEmpty else {
            completion([])
            return
        }
        
        // Reset state
        self.configurations = configurations
        self.asset = asset
        self.completionHandler = completion
        self.exportResults = []
        self.currentExportIndex = 0
        self.totalExportCount = configurations.count
        self.isExporting = true
        
        // Start the first export
        processNextExport()
    }
    
    /// Cancel the batch export operation
    public func cancelBatchExport() {
        isExporting = false
        // Add cancellation logic
    }
    
    /// Process the next export in the queue
    private func processNextExport() {
        guard isExporting, currentExportIndex < configurations.count, let asset = asset else {
            // We're done, call completion handler
            finalizeBatchExport()
            return
        }
        
        let configuration = configurations[currentExportIndex]
        currentExportName = formatName(for: configuration)
        
        // Create an exporter for this configuration
        let exporter = VideoExporter(asset: asset)
        
        // Start the export
        Task {
            await exporter.export(
                with: configuration,
                progressHandler: { [weak self] progress in
                    DispatchQueue.main.async {
                        self?.progress = progress
                    }
                },
                completion: { [weak self] result in
                    guard let self = self else { return }
                    
                    // Record the result
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let url):
                            self.exportResults.append(ExportResult(
                                configuration: configuration,
                                status: .success,
                                outputURL: url,
                                error: nil
                            ))
                        case .failure(let error):
                            self.exportResults.append(ExportResult(
                                configuration: configuration,
                                status: .failure,
                                outputURL: nil,
                                error: error
                            ))
                        }
                        
                        // Move to the next export
                        self.currentExportIndex += 1
                        self.progress = 0.0
                        self.processNextExport()
                    }
                }
            )
        }
    }
    
    /// Call the completion handler with all results
    private func finalizeBatchExport() {
        isExporting = false
        completionHandler?(exportResults)
        
        // Reset state
        exportResults = []
        configurations = []
        asset = nil
        completionHandler = nil
    }
    
    /// Format a display name for the current export
    private func formatName(for configuration: VideoExporter.ExportConfiguration) -> String {
        switch configuration.format {
        case .video:
            // This case implies H.264 if proResProfile is nil
            if let profile = configuration.proResProfile {
                // This should ideally not happen if .videoProRes is used correctly
                return "ProRes \(String(describing: profile)) (Legacy Video Case)"
            } else {
                return "H.264 MP4 Video"
            }
        case .videoProRes(let profile):
             return "ProRes \(String(describing: profile))"
        case .gif:
            return "Animated GIF"
        case .imageSequence(let format):
            return "\(format.rawValue.uppercased()) Image Sequence"
        case .projectFile:
            return "Project File"
        case .batchExport:
            return "Batch Export"
        default:
            return "Unknown Format"
        }
    }
    
    // MARK: - Job Management
    
    /// Clear all jobs in the batch export queue
    public func clearAllJobs() {
        configurations = []
        totalExportCount = 0
        currentExportIndex = 0
        progress = 0.0
        isExporting = false
    }
    
    /// Set the asset to be used for all exports
    public func setAsset(_ newAsset: AVAsset) {
        asset = newAsset
    }
    
    /// Add a job to the batch export queue
    public func addJob(format: ExportFormat, configuration: VideoExporter.ExportConfiguration) {
        // Create a copy of the configuration with the specified format
        var configCopy = configuration
        configCopy.format = format
        
        // Add to the configurations array
        configurations.append(configCopy)
        totalExportCount = configurations.count
    }
    
    /// Get a copy of the current export configurations
    public func getExportConfigurations() -> [VideoExporter.ExportConfiguration] {
        return configurations
    }
    
    /// Start the export with a callback for results
    public func startExportWithCallback(_ completion: @escaping ([ExportResult]) -> Void) {
        guard let asset = asset, !configurations.isEmpty else {
            completion([])
            return
        }
        
        startBatchExport(configurations: configurations, asset: asset, completion: completion)
    }
} 