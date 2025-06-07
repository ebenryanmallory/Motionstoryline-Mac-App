import SwiftUI
import AVFoundation
import AppKit

/// A component that provides video frames at specific time positions for timeline synchronization
@MainActor
class VideoFrameProvider: ObservableObject {
    @Published var currentFrame: NSImage?
    @Published var isLoading: Bool = false
    
    private var asset: AVAsset?
    private var imageGenerator: AVAssetImageGenerator?
    private var videoDuration: TimeInterval = 0
    private var videoFrameRate: Float = 30.0
    
    /// Initialize with a video URL
    /// - Parameter videoURL: The URL of the video file
    func loadVideo(from videoURL: URL) async {
        isLoading = true
        
        do {
            let asset = AVAsset(url: videoURL)
            self.asset = asset
            
            // Load video properties
            let duration = try await asset.load(.duration)
            self.videoDuration = duration.seconds
            
            // Try to get frame rate from video tracks
            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            if let firstTrack = videoTracks.first {
                let nominalFrameRate = try await firstTrack.load(.nominalFrameRate)
                self.videoFrameRate = nominalFrameRate > 0 ? nominalFrameRate : 30.0
            }
            
            // Set up image generator
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            imageGenerator.requestedTimeToleranceBefore = .zero
            imageGenerator.requestedTimeToleranceAfter = .zero
            self.imageGenerator = imageGenerator
            
            // Generate initial frame at time 0
            await generateFrame(at: 0.0)
            
        } catch {
            print("Failed to load video: \(error)")
        }
        
        isLoading = false
    }
    
    /// Generate a frame at the specified time
    /// - Parameter time: The time position in seconds
    func generateFrame(at time: TimeInterval) async {
        guard let imageGenerator = imageGenerator,
              let _ = asset else { return }
        
        // Ensure time is within video bounds
        let clampedTime = max(0, min(time, videoDuration))
        let cmTime = CMTime(seconds: clampedTime, preferredTimescale: 600)
        
        do {
            let cgImage = try imageGenerator.copyCGImage(at: cmTime, actualTime: nil)
            let nsImage = NSImage(cgImage: cgImage, size: CGSize(width: cgImage.width, height: cgImage.height))
            
            await MainActor.run {
                self.currentFrame = nsImage
            }
        } catch {
            print("Failed to generate frame at time \(time): \(error)")
        }
    }
    
    /// Get the video duration
    var duration: TimeInterval {
        return videoDuration
    }
    
    /// Get the video frame rate
    var frameRate: Float {
        return videoFrameRate
    }
}

/// A SwiftUI view that displays video frames synchronized with timeline
struct VideoFrameView: View {
    let videoURL: URL
    let currentTime: TimeInterval
    let size: CGSize
    let opacity: Double
    
    @StateObject private var frameProvider = VideoFrameProvider()
    @State private var lastUpdateTime: TimeInterval = 0
    
    var body: some View {
        Group {
            if frameProvider.isLoading {
                ProgressView()
                    .frame(width: size.width, height: size.height)
            } else if let currentFrame = frameProvider.currentFrame {
                Image(nsImage: currentFrame)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .clipped()
            } else {
                // Fallback placeholder
                ZStack {
                    Rectangle()
                        .fill(Color(white: 0.5, opacity: 1.0).opacity(0.3))
                    Image(systemName: "film")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: min(size.width, size.height) * 0.5)
                        .foregroundColor(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0).opacity(0.7))
                }
                .frame(width: size.width, height: size.height)
            }
        }
        .opacity(opacity)
        .contentShape(Rectangle())
        .onAppear {
            Task {
                await frameProvider.loadVideo(from: videoURL)
            }
        }
        .onChange(of: currentTime) { oldTime, newTime in
            // Only update frame if time has changed significantly (avoid excessive updates)
            if abs(newTime - lastUpdateTime) > 0.033 { // ~30fps update rate
                lastUpdateTime = newTime
                Task {
                    await frameProvider.generateFrame(at: newTime)
                }
            }
        }
    }
} 