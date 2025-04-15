import Foundation
import SwiftUI
import AVFoundation
import UserNotifications

/// Manages batch export operations for multiple formats in the background
@MainActor
public class BatchExportManager: ObservableObject {
    // MARK: - Types
    
    /// Represents a single export job in the batch
    public struct ExportJob: Identifiable, Equatable {
        public let id = UUID()
        public let format: ExportFormat
        public let configuration: VideoExporter.ExportConfiguration
        public var progress: Float = 0.0
        public var status: ExportStatus = .queued
        public var outputURL: URL?
        public var error: Error?
        
        public enum ExportStatus: Equatable {
            case queued
            case inProgress
            case completed
            case failed
            case cancelled
            
            public var displayName: String {
                switch self {
                case .queued: return "Queued"
                case .inProgress: return "In Progress"
                case .completed: return "Completed"
                case .failed: return "Failed"
                case .cancelled: return "Cancelled"
                }
            }
            
            public var systemImage: String {
                switch self {
                case .queued: return "hourglass"
                case .inProgress: return "arrow.clockwise"
                case .completed: return "checkmark.circle"
                case .failed: return "exclamationmark.triangle"
                case .cancelled: return "xmark.circle"
                }
            }
        }
        
        public static func == (lhs: ExportJob, rhs: ExportJob) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    // MARK: - Properties
    
    /// All export jobs in the queue
    @Published public private(set) var exportJobs: [ExportJob] = []
    
    /// Whether the manager is currently processing jobs
    @Published public private(set) var isProcessing = false
    
    /// Number of background jobs currently running
    @Published public private(set) var activeJobCount = 0
    
    /// Maximum number of concurrent export jobs
    public var maxConcurrentJobs = 2
    
    /// The asset to export
    private var asset: AVAsset?
    
    /// Background queue for processing exports
    private let backgroundQueue = DispatchQueue(label: "com.motionstoryline.batchexport", qos: .userInitiated)
    
    /// Completion handler to call when all jobs are finished
    private var allJobsCompletionHandler: (() -> Void)?
    
    // MARK: - Public Methods
    
    /// Creates a new batch export manager with the specified asset
    public init(asset: AVAsset? = nil) {
        self.asset = asset
    }
    
    /// Sets the asset to be exported
    public func setAsset(_ asset: AVAsset) {
        self.asset = asset
    }
    
    /// Adds a new export job to the queue
    public func addJob(format: ExportFormat, configuration: VideoExporter.ExportConfiguration) {
        let job = ExportJob(format: format, configuration: configuration)
        exportJobs.append(job)
    }
    
    /// Removes a job from the queue
    public func removeJob(withID id: UUID) {
        exportJobs.removeAll { $0.id == id }
    }
    
    /// Clears all jobs from the queue
    public func clearAllJobs() {
        exportJobs.removeAll()
    }
    
    /// Clears all completed and failed jobs
    public func clearFinishedJobs() {
        exportJobs.removeAll { $0.status == .completed || $0.status == .failed || $0.status == .cancelled }
    }
    
    /// Starts processing all queued jobs
    public func startProcessing(completion: (() -> Void)? = nil) {
        guard !isProcessing else { return }
        guard !exportJobs.isEmpty else {
            completion?()
            return
        }
        
        guard let asset = asset else {
            // Mark all jobs as failed if we don't have an asset
            for index in exportJobs.indices where exportJobs[index].status == .queued {
                exportJobs[index].status = .failed
                exportJobs[index].error = NSError(
                    domain: "BatchExportManager",
                    code: 100,
                    userInfo: [NSLocalizedDescriptionKey: "No asset provided for export"]
                )
            }
            return
        }
        
        isProcessing = true
        allJobsCompletionHandler = completion
        
        // Start background processing
        Task { @MainActor in
            await processNextJobs()
        }
    }
    
    /// Cancels all queued and in-progress jobs
    public func cancelAllJobs() {
        for index in exportJobs.indices {
            if exportJobs[index].status == .queued || exportJobs[index].status == .inProgress {
                exportJobs[index].status = .cancelled
            }
        }
        
        isProcessing = false
        activeJobCount = 0
        allJobsCompletionHandler?()
        allJobsCompletionHandler = nil
    }
    
    // MARK: - Private Methods
    
    /// Processes the next jobs in the queue, up to maxConcurrentJobs
    private func processNextJobs() async {
        guard isProcessing else { return }
        
        let queuedJobs = exportJobs.indices.filter { exportJobs[$0].status == .queued }
        if queuedJobs.isEmpty && activeJobCount == 0 {
            // All jobs are complete
            isProcessing = false
            allJobsCompletionHandler?()
            allJobsCompletionHandler = nil
            return
        }
        
        // Start as many jobs as we can up to maxConcurrentJobs
        let availableSlots = maxConcurrentJobs - activeJobCount
        let jobsToStart = queuedJobs.prefix(availableSlots)
        
        for index in jobsToStart {
            activeJobCount += 1
            startJob(at: index)
        }
    }
    
    /// Starts processing a specific job
    private func startJob(at index: Int) {
        Task { @MainActor in
            guard let asset = self.asset else { return }
            
            // Mark as in progress
            exportJobs[index].status = .inProgress
            
            // Create an exporter
            let exporter = VideoExporter(asset: asset)
            
            // Get the configuration
            let configuration = exportJobs[index].configuration
            
            // Start the export
            await exporter.export(
                with: configuration,
                progressHandler: { [weak self] progress in
                    Task { @MainActor in
                        guard let self = self, index < self.exportJobs.count else { return }
                        self.exportJobs[index].progress = progress
                    }
                },
                completion: { [weak self] result in
                    Task { @MainActor in
                        guard let self = self, index < self.exportJobs.count else { return }
                        
                        switch result {
                        case .success(let url):
                            self.exportJobs[index].status = .completed
                            self.exportJobs[index].outputURL = url
                            
                            // Show a notification when complete
                            self.showExportCompletionNotification(
                                format: self.exportJobs[index].format,
                                url: url
                            )
                            
                        case .failure(let error):
                            self.exportJobs[index].status = .failed
                            self.exportJobs[index].error = error
                        }
                        
                        // Reduce active job count
                        self.activeJobCount -= 1
                        
                        // Process next jobs
                        await self.processNextJobs()
                    }
                }
            )
        }
    }
    
    /// Shows a notification when an export job completes
    private func showExportCompletionNotification(format: ExportFormat, url: URL) {
        let formatName: String
        switch format {
        case .video:
            formatName = "Video (MP4/MOV)"
        case .gif:
            formatName = "Animated GIF"
        case .imageSequence(let imageFormat):
            formatName = "\(imageFormat.rawValue.uppercased()) Image Sequence"
        case .projectFile:
            formatName = "Project File"
        case .batchExport:
            formatName = "Batch Export"
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Export Complete"
        content.body = "\(formatName) export completed: \(url.lastPathComponent)"
        content.sound = .default
        
        // Create a notification request
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        
        // Add request to notification center
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error showing notification: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - SwiftUI Views for Batch Export

/// A view that displays the batch export interface
public struct BatchExportView: View {
    @ObservedObject var manager: BatchExportManager
    @Environment(\.presentationMode) var presentationMode
    
    public init(manager: BatchExportManager) {
        self.manager = manager
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Batch Export")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            // Jobs list
            List {
                ForEach(manager.exportJobs) { job in
                    BatchExportJobRow(job: job)
                }
            }
            .listStyle(.inset)
            .frame(minHeight: 200)
            
            // Controls
            HStack {
                Button("Clear Finished") {
                    manager.clearFinishedJobs()
                }
                .disabled(manager.isProcessing || manager.exportJobs.filter { $0.status == .completed || $0.status == .failed || $0.status == .cancelled }.isEmpty)
                
                Spacer()
                
                if manager.isProcessing {
                    Button("Cancel All") {
                        manager.cancelAllJobs()
                    }
                    .foregroundColor(.red)
                } else {
                    Button("Start Export") {
                        manager.startProcessing()
                    }
                    .disabled(manager.exportJobs.filter { $0.status == .queued }.isEmpty)
                }
            }
        }
        .padding()
        .frame(width: 500, height: 400)
    }
}

/// A row that displays a single batch export job
struct BatchExportJobRow: View {
    let job: BatchExportManager.ExportJob
    
    var body: some View {
        HStack {
            Image(systemName: job.status.systemImage)
                .foregroundColor(statusColor)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(formatName)
                    .font(.headline)
                
                if job.status == .inProgress {
                    ProgressView(value: job.progress)
                        .progressViewStyle(.linear)
                        .frame(height: 6)
                } else if let error = job.error {
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Text(job.status.displayName)
                .foregroundColor(statusColor)
                .font(.caption)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }
    
    private var formatName: String {
        switch job.format {
        case .video:
            return "Video (MP4/MOV)"
        case .gif:
            return "Animated GIF"
        case .imageSequence(let format):
            return "\(format.rawValue.uppercased()) Image Sequence"
        case .projectFile:
            return "Project File"
        case .batchExport:
            return "Batch Export"
        }
    }
    
    private var statusColor: Color {
        switch job.status {
        case .queued:
            return .gray
        case .inProgress:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .red
        case .cancelled:
            return .orange
        }
    }
} 