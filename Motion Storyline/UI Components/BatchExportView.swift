import SwiftUI
import AVFoundation

/// A view that shows the progress of a batch export operation and allows the user to start or cancel exports
public struct BatchExportView: View {
    @ObservedObject var manager: BatchExportManager
    @Environment(\.presentationMode) var presentationMode
    @State private var showingResultAlert = false
    @State private var resultMessage = ""
    @State private var isSuccess = false
    
    public init(manager: BatchExportManager) {
        self.manager = manager
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("Batch Export")
                .font(.headline)
            
            // Progress information
            if manager.isExporting {
                ProgressView(value: manager.progress, total: 1.0)
                    .progressViewStyle(.linear)
                    .padding(.horizontal)
                
                Text("Exporting \(manager.currentExportName) (\(manager.currentExportIndex + 1) of \(manager.totalExportCount))")
                    .foregroundColor(.secondary)
            } else {
                Text("Ready to start batch export")
                    .foregroundColor(.secondary)
            }
            
            // Action buttons
            HStack {
                Button("Cancel") {
                    if manager.isExporting {
                        manager.cancelBatchExport()
                    }
                    presentationMode.wrappedValue.dismiss()
                }
                
                Spacer()
                
                Button(manager.isExporting ? "Stop" : "Start Export") {
                    if manager.isExporting {
                        manager.cancelBatchExport()
                    } else {
                        Task {
                            await startExport()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(manager.isExporting && manager.totalExportCount == 0)
            }
        }
        .padding()
        .frame(width: 400, height: 200)
        .alert(isPresented: $showingResultAlert) {
            Alert(
                title: Text(isSuccess ? "Export Complete" : "Export Failed"),
                message: Text(resultMessage),
                dismissButton: .default(Text("OK")) {
                    if isSuccess {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            )
        }
    }
    
    // Start the batch export process
    private func startExport() async {
        let exportConfigurations = manager.getExportConfigurations()
        guard !exportConfigurations.isEmpty else {
            showExportResult(success: false, message: "No export jobs configured")
            return
        }
        
        do {
            let results = try await withCheckedThrowingContinuation { continuation in
                manager.startExportWithCallback { results in
                    continuation.resume(returning: results)
                }
            }
            
            // Show the summary of results
            let successCount = results.filter { $0.isSuccess }.count
            let failureCount = results.filter { $0.isFailure }.count
            
            var resultMessage = "Successfully exported \(successCount) of \(results.count) items."
            if failureCount > 0 {
                resultMessage += " \(failureCount) exports failed."
            }
            
            showExportResult(
                success: failureCount == 0,
                message: resultMessage
            )
        } catch {
            showExportResult(
                success: false,
                message: "Export failed with error: \(error.localizedDescription)"
            )
        }
    }
    
    // Show the export result alert
    private func showExportResult(success: Bool, message: String) {
        isSuccess = success
        resultMessage = message
        showingResultAlert = true
    }
}

// Result extension for simplified status checking
extension BatchExportManager.ExportResult {
    var isSuccess: Bool {
        if case .success = status {
            return true
        }
        return false
    }
    
    var isFailure: Bool {
        if case .failure = status {
            return true
        }
        return false
    }
}

#if !DISABLE_PREVIEWS
struct BatchExportView_Previews: PreviewProvider {
    static var previews: some View {
        BatchExportView(manager: BatchExportManager())
    }
}
#endif 