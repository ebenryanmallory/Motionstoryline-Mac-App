import Foundation
@preconcurrency import AVFoundation
import os.log

/// Service responsible for composing audio tracks with video assets
class CanvasAudioRenderer: @unchecked Sendable {
    // Logger for debugging
    private static let logger = OSLog(subsystem: "com.app.Motion-Storyline", category: "CanvasAudioRenderer")
    
    // MARK: - Initialization
    
    /// Initialize the audio renderer
    init() {}
    
    // MARK: - Public Methods
    
    /// Compose audio tracks with a video asset
    /// - Parameters:
    ///   - videoAsset: The video asset to add audio to
    ///   - audioLayers: Array of audio layers to include
    ///   - videoDuration: Duration of the video
    /// - Returns: A new asset with audio composition
    func composeAudio(with videoAsset: AVAsset, audioLayers: [AudioLayer], videoDuration: Double) async throws -> AVAsset {
        // Create a mutable composition
        let composition = AVMutableComposition()
        
        // Add the video track from the original asset
        let videoTracks = try await videoAsset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else {
            throw NSError(domain: "MotionStoryline", code: 110, userInfo: [NSLocalizedDescriptionKey: "No video track found in video asset"])
        }
        
        // Create a video composition track
        let compositionVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        // Insert the video track into the composition
        let videoDurationCMTime = CMTime(seconds: videoDuration, preferredTimescale: 600)
        let videoTimeRange = CMTimeRange(start: .zero, duration: videoDurationCMTime)
        
        try? compositionVideoTrack?.insertTimeRange(videoTimeRange, of: videoTrack, at: .zero)
        
        // Add audio tracks from audio layers
        os_log("=== PROCESSING AUDIO LAYERS FOR COMPOSITION ===", log: CanvasAudioRenderer.logger, type: .info)
        
        var actuallyAddedTracks = 0
        for (index, audioLayer) in audioLayers.enumerated() {
            os_log("Processing audio layer %d: %{public}@", log: CanvasAudioRenderer.logger, type: .info, index, audioLayer.name)
            
            // Skip muted audio layers
            if audioLayer.isMuted {
                os_log("  -> SKIPPING: Audio layer %d is muted", log: CanvasAudioRenderer.logger, type: .info, index)
                continue
            }
            
            // Create audio asset from the layer's URL
            let audioAsset = AVAsset(url: audioLayer.assetURL)
            
            // Load audio tracks
            let audioTracks = try await audioAsset.loadTracks(withMediaType: .audio)
            guard let audioTrack = audioTracks.first else {
                os_log("  -> ERROR: No audio track found in audio layer at URL: %{public}@", log: CanvasAudioRenderer.logger, type: .error, audioLayer.assetURL.path)
                continue
            }
            
            os_log("  -> Found %d audio tracks in asset", log: CanvasAudioRenderer.logger, type: .info, audioTracks.count)
            
            // Create a composition audio track
            let compositionAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            
            guard let compositionTrack = compositionAudioTrack else {
                os_log("  -> ERROR: Failed to create composition audio track for layer %d", log: CanvasAudioRenderer.logger, type: .error, index)
                continue
            }
            
            // Calculate the time range for this audio layer
            let audioStartTime = CMTime(seconds: audioLayer.startTime, preferredTimescale: 600)
            let calculatedDuration = min(audioLayer.duration, videoDuration - audioLayer.startTime)
            let audioLayerDuration = CMTime(seconds: calculatedDuration, preferredTimescale: 600)
            let audioTimeRange = CMTimeRange(start: .zero, duration: audioLayerDuration)
            
            os_log("  -> Audio timing for layer %d:", log: CanvasAudioRenderer.logger, type: .info, index)
            os_log("     Start time: %.3f seconds", log: CanvasAudioRenderer.logger, type: .info, audioLayer.startTime)
            os_log("     Original duration: %.3f seconds", log: CanvasAudioRenderer.logger, type: .info, audioLayer.duration)
            os_log("     Calculated duration: %.3f seconds", log: CanvasAudioRenderer.logger, type: .info, calculatedDuration)
            os_log("     Video duration: %.3f seconds", log: CanvasAudioRenderer.logger, type: .info, videoDuration)
            os_log("     Track ID: %d", log: CanvasAudioRenderer.logger, type: .info, compositionTrack.trackID)
            
            // Insert the audio track into the composition
            do {
                try compositionTrack.insertTimeRange(audioTimeRange, of: audioTrack, at: audioStartTime)
                actuallyAddedTracks += 1
                os_log("  -> SUCCESS: Added audio layer %d to composition track %d", log: CanvasAudioRenderer.logger, type: .info, index, compositionTrack.trackID)
                os_log("     Final position: start=%.3f, duration=%.3f", log: CanvasAudioRenderer.logger, type: .info, audioLayer.startTime, calculatedDuration)
            } catch {
                os_log("  -> ERROR: Failed to insert audio layer %d: %{public}@", log: CanvasAudioRenderer.logger, type: .error, index, error.localizedDescription)
            }
        }
        
        os_log("=== AUDIO COMPOSITION SUMMARY ===", log: CanvasAudioRenderer.logger, type: .info)
        os_log("Total audio layers processed: %d", log: CanvasAudioRenderer.logger, type: .info, audioLayers.count)
        os_log("Tracks actually added to composition: %d", log: CanvasAudioRenderer.logger, type: .info, actuallyAddedTracks)
        
        let finalAudioTracks = try await composition.loadTracks(withMediaType: .audio)
        os_log("Final composition audio tracks: %d", log: CanvasAudioRenderer.logger, type: .info, finalAudioTracks.count)
        
        if actuallyAddedTracks == 0 {
            os_log("WARNING: No audio tracks were added to the composition!", log: CanvasAudioRenderer.logger, type: .error)
        }
        
        // Create an audio mix to apply volume settings
        let audioMix = try await createAudioMix(for: audioLayers, in: composition)
        
        // Export the composition to a temporary file
        return try await exportComposition(composition, audioMix: audioMix, videoAsset: videoAsset)
    }
    
    // MARK: - Private Methods
    
    /// Create an audio mix with volume settings for the audio layers
    /// - Parameters:
    ///   - audioLayers: Array of audio layers with volume settings
    ///   - composition: The audio/video composition
    /// - Returns: An audio mix with volume parameters applied
    private func createAudioMix(for audioLayers: [AudioLayer], in composition: AVMutableComposition) async throws -> AVMutableAudioMix {
        let audioMix = AVMutableAudioMix()
        var audioMixInputParameters: [AVMutableAudioMixInputParameters] = []
        
        // Apply volume settings to each audio track
        os_log("=== APPLYING VOLUME SETTINGS ===", log: CanvasAudioRenderer.logger, type: .info)
        
        var volumeParametersApplied = 0
        var unmutedLayerIndex = 0
        
        for (index, audioLayer) in audioLayers.enumerated() {
            if audioLayer.isMuted {
                os_log("Skipping volume for muted layer %d", log: CanvasAudioRenderer.logger, type: .info, index)
                continue
            }
            
            // Find the corresponding composition track
            let audioTracks = try await composition.loadTracks(withMediaType: .audio)
            os_log("Looking for track for layer %d (unmuted index: %d), total tracks: %d", log: CanvasAudioRenderer.logger, type: .info, index, unmutedLayerIndex, audioTracks.count)
            
            if unmutedLayerIndex < audioTracks.count {
                let track = audioTracks[unmutedLayerIndex]
                let inputParameters = AVMutableAudioMixInputParameters(track: track)
                
                // Apply volume (convert from 0.0-1.0 to dB scale)
                let volumeLevel = Float(audioLayer.volume)
                inputParameters.setVolume(volumeLevel, at: .zero)
                
                audioMixInputParameters.append(inputParameters)
                volumeParametersApplied += 1
                
                os_log("Applied volume %.2f to audio layer %d (track ID: %d)", log: CanvasAudioRenderer.logger, type: .info, volumeLevel, index, track.trackID)
                unmutedLayerIndex += 1
            } else {
                os_log("ERROR: No composition track found for audio layer %d", log: CanvasAudioRenderer.logger, type: .error, index)
            }
        }
        
        os_log("Volume parameters applied: %d", log: CanvasAudioRenderer.logger, type: .info, volumeParametersApplied)
        
        audioMix.inputParameters = audioMixInputParameters
        return audioMix
    }
    
    /// Export the composition with audio mix to a temporary file
    /// - Parameters:
    ///   - composition: The audio/video composition
    ///   - audioMix: The audio mix with volume settings
    ///   - videoAsset: The original video asset (for cleanup)
    /// - Returns: The final composed asset
    private func exportComposition(_ composition: AVMutableComposition, audioMix: AVMutableAudioMix, videoAsset: AVAsset) async throws -> AVAsset {
        // Export the composition to a temporary file
        let tempDirPath = NSTemporaryDirectory()
        let tempDir = URL(fileURLWithPath: tempDirPath)
        let composedVideoURL = tempDir.appendingPathComponent("composed_video_\(UUID().uuidString).mov")
        
        // Remove existing file if it exists
        if FileManager.default.fileExists(atPath: composedVideoURL.path) {
            try FileManager.default.removeItem(at: composedVideoURL)
        }
        
        // Create an export session
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw NSError(domain: "MotionStoryline", code: 111, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session for audio composition"])
        }
        
        exportSession.outputURL = composedVideoURL
        exportSession.outputFileType = .mov
        exportSession.audioMix = audioMix
        
        // Export the composition
        os_log("=== STARTING FINAL EXPORT WITH AUDIO ===", log: CanvasAudioRenderer.logger, type: .info)
        os_log("Export session output URL: %{public}@", log: CanvasAudioRenderer.logger, type: .info, composedVideoURL.absoluteString)
        os_log("Export session output file type: %{public}@", log: CanvasAudioRenderer.logger, type: .info, exportSession.outputFileType?.rawValue ?? "unknown")
        os_log("Export session has audio mix: %{public}@", log: CanvasAudioRenderer.logger, type: .info, exportSession.audioMix != nil ? "YES" : "NO")
        
        await exportSession.export()
        
        os_log("=== EXPORT COMPLETED ===", log: CanvasAudioRenderer.logger, type: .info)
        os_log("Export session status: %{public}@", log: CanvasAudioRenderer.logger, type: .info, String(describing: exportSession.status))
        
        // Check for export errors
        if exportSession.status == .failed {
            let errorMessage = exportSession.error?.localizedDescription ?? "Unknown export error"
            os_log("EXPORT FAILED: %{public}@", log: CanvasAudioRenderer.logger, type: .error, errorMessage)
            throw NSError(domain: "MotionStoryline", code: 112, userInfo: [NSLocalizedDescriptionKey: "Failed to export audio composition: \(errorMessage)"])
        }
        
        // Verify the composed file was created
        guard FileManager.default.fileExists(atPath: composedVideoURL.path) else {
            throw NSError(domain: "MotionStoryline", code: 113, userInfo: [NSLocalizedDescriptionKey: "Audio composition file was not created successfully"])
        }
        
        os_log("Successfully created audio composition at: %{public}@", log: CanvasAudioRenderer.logger, type: .info, composedVideoURL.path)
        
        // Verify the final composed asset
        let finalAsset = AVURLAsset(url: composedVideoURL)
        
        // Log final asset details
        do {
            let hasAudioTracks = try await finalAsset.loadTracks(withMediaType: .audio)
            let hasVideoTracks = try await finalAsset.loadTracks(withMediaType: .video)
            let finalDuration = try await finalAsset.load(.duration)
            
            os_log("=== FINAL ASSET VERIFICATION ===", log: CanvasAudioRenderer.logger, type: .info)
            os_log("Final asset has %d video tracks", log: CanvasAudioRenderer.logger, type: .info, hasVideoTracks.count)
            os_log("Final asset has %d audio tracks", log: CanvasAudioRenderer.logger, type: .info, hasAudioTracks.count)
            os_log("Final asset duration: %.3f seconds", log: CanvasAudioRenderer.logger, type: .info, finalDuration.seconds)
            
            if hasAudioTracks.isEmpty {
                os_log("WARNING: Final asset has no audio tracks - audio may not be included in export!", log: CanvasAudioRenderer.logger, type: .error)
            } else {
                os_log("SUCCESS: Final asset contains audio tracks - audio should be present in export", log: CanvasAudioRenderer.logger, type: .info)
            }
        } catch {
            os_log("Error verifying final asset: %{public}@", log: CanvasAudioRenderer.logger, type: .error, error.localizedDescription)
        }
        
        // Clean up the original video-only file
        if let urlAsset = videoAsset as? AVURLAsset {
            try? FileManager.default.removeItem(at: urlAsset.url)
        }
        
        // Return the composed asset
        return finalAsset
    }
}
