import SwiftUI
import AVFoundation
import Accelerate

/// A view that displays an audio waveform visualization
public struct AudioWaveformView: View {
    private let audioURL: URL
    private let waveformColor: Color
    private let backgroundColor: Color
    private let lineWidth: CGFloat
    private let showRuler: Bool
    private let showPlaybackControls: Bool
    
    @State private var samples: [Float] = []
    @State private var isLoading: Bool = true
    @State private var error: Error? = nil
    
    // Audio playback controls
    @State private var isPlaying: Bool = false
    @State private var audioPlayer: AVPlayer?
    @State private var currentTime: Double = 0
    @State private var audioDuration: Double = 0
    @State private var timeObserver: Any?
    
    public init(
        audioURL: URL,
        waveformColor: Color = .blue,
        backgroundColor: Color = Color(NSColor.controlBackgroundColor).opacity(0.3),
        lineWidth: CGFloat = 1.5,
        showRuler: Bool = true,
        showPlaybackControls: Bool = false
    ) {
        self.audioURL = audioURL
        self.waveformColor = waveformColor
        self.backgroundColor = backgroundColor
        self.lineWidth = lineWidth
        self.showRuler = showRuler
        self.showPlaybackControls = showPlaybackControls
    }
    
    public var body: some View {
        ZStack {
            // Background
            backgroundColor
                .cornerRadius(4)
            
            if isLoading {
                ProgressView()
                    .scaleEffect(0.7)
            } else if let error = error {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title)
                        .foregroundColor(.orange)
                    Text("Failed to load waveform")
                        .font(.caption)
                    Text(error.localizedDescription)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else {
                // Waveform visualization
                AudioWaveformShape(samples: samples)
                    .stroke(waveformColor, lineWidth: lineWidth)
                    .frame(maxHeight: .infinity)
                
                // Ruler ticks if enabled
                if showRuler {
                    GeometryReader { geometry in
                        RulerTickMarks(width: geometry.size.width)
                            .stroke(Color.gray.opacity(0.5), lineWidth: 0.5)
                            .frame(height: 10)
                            .position(x: geometry.size.width/2, y: geometry.size.height - 5)
                    }
                }
                
                // Playback controls overlay if enabled
                if showPlaybackControls {
                    GeometryReader { geometry in
                        VStack {
                            Spacer()
                            
                            ZStack {
                                // Semi-transparent background for controls
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(Color.black.opacity(0.2))
                                    .frame(width: 120, height: 30)
                                
                                HStack(spacing: 16) {
                                    // Play/pause button
                                    Button(action: {
                                        togglePlayback()
                                    }) {
                                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                            .foregroundColor(.white)
                                            .font(.system(size: 16, weight: .bold))
                                    }
                                    .buttonStyle(.plain)
                                    .help(isPlaying ? "Pause" : "Play")
                                    
                                    // Reset button
                                    Button(action: {
                                        resetPlayback()
                                    }) {
                                        Image(systemName: "backward.end.fill")
                                            .foregroundColor(.white)
                                            .font(.system(size: 16, weight: .bold))
                                    }
                                    .buttonStyle(.plain)
                                    .help("Reset to beginning")
                                }
                            }
                            .frame(width: 120, height: 30)
                            .position(x: geometry.size.width / 2, y: geometry.size.height - 20)
                        }
                    }
                }
            }
        }
        .task {
            await loadAudioSamples()
            if showPlaybackControls {
                setupAudioPlayer()
            }
        }
        .onDisappear {
            if showPlaybackControls {
                cleanupAudioPlayer()
            }
        }
    }
    
    // MARK: - Audio Playback Methods
    
    private func setupAudioPlayer() {
        let playerItem = AVPlayerItem(url: audioURL)
        audioPlayer = AVPlayer(playerItem: playerItem)
        
        // Get audio duration
        let asset = AVAsset(url: audioURL)
        Task {
            do {
                audioDuration = try await asset.load(.duration).seconds
            } catch {
                audioDuration = 0
            }
        }
        
        // Add time observer to sync audio with animation
        timeObserver = audioPlayer?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.01, preferredTimescale: 600), queue: .main) { time in
            guard isPlaying else { return }
            
            // Update current time from audio playback
            let seconds = time.seconds
            if seconds <= audioDuration {
                self.currentTime = seconds
            } else {
                // Stop if we've reached the end
                self.isPlaying = false
                resetPlayback()
            }
        }
    }
    
    private func cleanupAudioPlayer() {
        if let timeObserver = timeObserver {
            audioPlayer?.removeTimeObserver(timeObserver)
        }
        audioPlayer?.pause()
        audioPlayer = nil
        isPlaying = false
    }
    
    private func togglePlayback() {
        if isPlaying {
            audioPlayer?.pause()
            // Pause haptic feedback
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
        } else {
            // Make sure we're at the right position
            seekAudio(to: currentTime)
            audioPlayer?.play()
            // Play haptic feedback
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
        }
        isPlaying.toggle()
    }
    
    private func resetPlayback() {
        audioPlayer?.pause()
        isPlaying = false
        currentTime = 0
        seekAudio(to: 0)
    }
    
    private func seekAudio(to time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        audioPlayer?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }
    
    // MARK: - Audio Sample Loading
    
    private func loadAudioSamples() async {
        do {
            let asset = AVAsset(url: audioURL)
            let assetReader = try AVAssetReader(asset: asset)
            
            guard let audioTrack = try await asset.loadTracks(withMediaType: .audio).first else {
                throw NSError(domain: "AudioWaveformView", code: 1, userInfo: [NSLocalizedDescriptionKey: "No audio track found"])
            }
            
            // Configure the output settings for reading samples
            let outputSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false
            ]
            
            let readerOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: outputSettings)
            assetReader.add(readerOutput)
            
            // Start reading
            assetReader.startReading()
            
            // Collect all audio samples
            var sampleBuffer: [Float] = []
            
            // We'll downsample to a reasonable number of points (max 2000 for performance)
            let desiredNumberOfSamples = 2000
            
            while let nextBuffer = readerOutput.copyNextSampleBuffer(),
                  let blockBuffer = CMSampleBufferGetDataBuffer(nextBuffer) {
                
                // Get the buffer length
                var bufferLength: Int = 0
                var bufferPointer: UnsafeMutablePointer<Int8>?
                CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: &bufferLength, totalLengthOut: nil, dataPointerOut: &bufferPointer)
                
                // Number of samples in this buffer
                let floatCount = bufferLength / MemoryLayout<Float>.size
                
                // Convert buffer pointer to UnsafePointer<Float>
                if let floatPointer = bufferPointer?.withMemoryRebound(to: Float.self, capacity: floatCount, { $0 }) {
                    // Copy samples from buffer
                    let floats = Array(UnsafeBufferPointer(start: floatPointer, count: floatCount))
                    sampleBuffer.append(contentsOf: floats)
                }
                
                // Free the sample buffer
                CMSampleBufferInvalidate(nextBuffer)
            }
            
            // Downsample the audio samples
            let samples = downsample(sampleBuffer, targetCount: desiredNumberOfSamples)
            
            // Update the UI on the main thread
            await MainActor.run {
                self.samples = samples
                self.isLoading = false
            }
            
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
        }
    }
    
    private func downsample(_ samples: [Float], targetCount: Int) -> [Float] {
        guard !samples.isEmpty else { return [] }
        
        if samples.count <= targetCount {
            return samples
        }
        
        // Split samples into chunks and find the peak values in each chunk
        let chunkSize = samples.count / targetCount
        var result: [Float] = []
        
        // Process chunks in parallel for better performance
        let chunks = stride(from: 0, to: samples.count, by: chunkSize).map { start -> [Float] in
            let end = min(start + chunkSize, samples.count)
            let chunk = Array(samples[start..<end])
            
            // Find absolute peak in chunk
            var peak: Float = 0
            for sample in chunk {
                let absoluteSample = abs(sample)
                if absoluteSample > peak {
                    peak = absoluteSample
                }
            }
            
            return [peak]
        }
        
        // Flatten the chunks
        result = chunks.flatMap { $0 }
        
        // Ensure we have exactly the target count
        if result.count > targetCount {
            result = Array(result.prefix(targetCount))
        } else if result.count < targetCount {
            // Pad with zeros if needed
            result.append(contentsOf: Array(repeating: 0, count: targetCount - result.count))
        }
        
        return result
    }
}

/// Shape that draws the audio waveform
struct AudioWaveformShape: Shape {
    let samples: [Float]
    
    func path(in rect: CGRect) -> Path {
        guard !samples.isEmpty else {
            return Path()
        }
        
        var path = Path()
        let midY = rect.height / 2
        let sampleWidth = rect.width / CGFloat(samples.count)
        
        // Start at left side, middle height
        path.move(to: CGPoint(x: 0, y: midY))
        
        // Draw the waveform
        for (index, sample) in samples.enumerated() {
            let x = CGFloat(index) * sampleWidth
            let y = midY - CGFloat(sample) * (rect.height / 2)
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        // Complete the waveform by going back from right to left on the bottom half
        for (index, sample) in samples.enumerated().reversed() {
            let x = CGFloat(index) * sampleWidth
            let y = midY + CGFloat(sample) * (rect.height / 2)
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        // Close the path
        path.closeSubpath()
        
        return path
    }
}

/// Shape that draws tick marks for a ruler
struct RulerTickMarks: Shape {
    let width: CGFloat
    let tickCount: Int = 10
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let tickSpacing = width / CGFloat(tickCount)
        
        for i in 0...tickCount {
            let x = CGFloat(i) * tickSpacing
            let height = i % 5 == 0 ? rect.height : rect.height / 2
            
            path.move(to: CGPoint(x: x, y: rect.height - height))
            path.addLine(to: CGPoint(x: x, y: rect.height))
        }
        
        return path
    }
}

// MARK: - Preview
struct AudioWaveformView_Previews: PreviewProvider {
    static var previews: some View {
        // This preview will only work if the URL points to a valid audio file
        AudioWaveformView(audioURL: URL(string: "file:///nonexistent.mp3")!)
            .frame(height: 100)
            .padding()
    }
} 