import SwiftUI
import AVFoundation

/// A view that displays audio layers in the animation timeline
public struct AudioLayerTimelineView: View {
    @ObservedObject var audioLayerManager: AudioLayerManager
    @Binding var currentTime: Double
    @Binding var isPlaying: Bool
    let scale: Double
    @Binding var offset: Double
    let timelineDuration: Double
    
    @State private var selectedLayerId: UUID?
    @State private var showingLayerControls: Bool = false
    
    public init(
        audioLayerManager: AudioLayerManager,
        currentTime: Binding<Double>,
        isPlaying: Binding<Bool>,
        scale: Double,
        offset: Binding<Double>,
        timelineDuration: Double
    ) {
        self.audioLayerManager = audioLayerManager
        self._currentTime = currentTime
        self._isPlaying = isPlaying
        self.scale = scale
        self._offset = offset
        self.timelineDuration = timelineDuration
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header with controls
            headerView
            
            if audioLayerManager.audioLayers.isEmpty {
                emptyStateView
            } else {
                // Audio layers
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(audioLayerManager.audioLayers) { audioLayer in
                            audioLayerRow(audioLayer)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 300)
            }
        }
        .onChange(of: currentTime) { oldValue, newValue in
            audioLayerManager.seekToTime(newValue)
        }
        .onChange(of: isPlaying) { oldValue, newValue in
            if newValue {
                audioLayerManager.play()
            } else {
                audioLayerManager.pause()
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            Image(systemName: "waveform")
                .foregroundColor(.blue)
            
            Text("Audio Layers")
                .font(.headline)
            
            Spacer()
            
            Text("\(audioLayerManager.audioLayers.count) track\(audioLayerManager.audioLayers.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button(action: {
                withAnimation {
                    showingLayerControls.toggle()
                }
            }) {
                Image(systemName: showingLayerControls ? "chevron.up" : "chevron.down")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            
            Text("No Audio Layers")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Add audio files to the timeline using the Media Browser")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .padding()
    }
    
    private func audioLayerRow(_ audioLayer: AudioLayer) -> some View {
        VStack(spacing: 0) {
            // Layer header
            HStack {
                // Visibility toggle
                Button(action: {
                    var updatedLayer = audioLayer
                    updatedLayer.isVisible.toggle()
                    audioLayerManager.updateAudioLayer(updatedLayer)
                }) {
                    Image(systemName: audioLayer.isVisible ? "eye" : "eye.slash")
                        .foregroundColor(audioLayer.isVisible ? .blue : .gray)
                }
                .buttonStyle(.borderless)
                
                // Mute toggle
                Button(action: {
                    var updatedLayer = audioLayer
                    updatedLayer.isMuted.toggle()
                    audioLayerManager.updateAudioLayer(updatedLayer)
                }) {
                    Image(systemName: audioLayer.isMuted ? "speaker.slash" : "speaker.wave.2")
                        .foregroundColor(audioLayer.isMuted ? .red : .blue)
                }
                .buttonStyle(.borderless)
                
                Text(audioLayer.name)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Spacer()
                
                Text(formatDuration(audioLayer.duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Delete button
                Button(action: {
                    audioLayerManager.removeAudioLayer(withId: audioLayer.id)
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(selectedLayerId == audioLayer.id ? Color.blue.opacity(0.1) : Color.clear)
            .onTapGesture {
                selectedLayerId = selectedLayerId == audioLayer.id ? nil : audioLayer.id
            }
            
            // Timeline representation
            if audioLayer.isVisible {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        Rectangle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(height: 40)
                        
                        // Audio block representation
                        let startX = timeToPosition(audioLayer.startTime, width: geometry.size.width)
                        let endX = timeToPosition(audioLayer.startTime + audioLayer.duration, width: geometry.size.width)
                        let blockWidth = max(2, endX - startX)
                        
                        Rectangle()
                            .fill(audioLayer.waveformColor.opacity(0.6))
                            .frame(width: blockWidth, height: 36)
                            .position(x: startX + blockWidth/2, y: 20)
                            .overlay(
                                // Simple waveform representation
                                HStack(spacing: 1) {
                                    ForEach(0..<Int(blockWidth/3), id: \.self) { _ in
                                        Rectangle()
                                            .fill(audioLayer.waveformColor)
                                            .frame(width: 1, height: CGFloat.random(in: 8...28))
                                    }
                                }
                                .position(x: startX + blockWidth/2, y: 20)
                            )
                        
                        // Playhead
                        Rectangle()
                            .fill(Color.red)
                            .frame(width: 2, height: 40)
                            .position(x: timeToPosition(currentTime, width: geometry.size.width), y: 20)
                    }
                }
                .frame(height: 40)
                .contentShape(Rectangle())
                .onTapGesture { location in
                    // Allow seeking by clicking on the timeline
                    let newTime = positionToTime(location.x, width: NSScreen.main?.frame.width ?? 1920)
                    currentTime = max(0, min(timelineDuration, newTime))
                }
            }
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(4)
        .padding(.horizontal, 4)
    }
    
    // Convert time to position in the timeline
    private func timeToPosition(_ time: Double, width: CGFloat) -> CGFloat {
        return CGFloat(((time - offset) * scale / timelineDuration) * Double(width))
    }
    
    // Convert position to time in the timeline
    private func positionToTime(_ position: CGFloat, width: CGFloat) -> Double {
        return (Double(position) / Double(width)) * (timelineDuration / scale) + offset
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration) ?? "00:00"
    }
}

// MARK: - Preview
struct AudioLayerTimelineView_Previews: PreviewProvider {
    static var previews: some View {
        let audioLayerManager = AudioLayerManager()
        
        // Add sample audio layers
        let sampleLayer1 = AudioLayer(
            name: "Background Music",
            assetURL: URL(string: "file:///music.mp3")!,
            startTime: 0.0,
            duration: 120.0,
            waveformColor: .blue
        )
        
        let sampleLayer2 = AudioLayer(
            name: "Voice Over",
            assetURL: URL(string: "file:///voice.mp3")!,
            startTime: 30.0,
            duration: 45.0,
            waveformColor: .green
        )
        
        audioLayerManager.addAudioLayer(sampleLayer1)
        audioLayerManager.addAudioLayer(sampleLayer2)
        
        return AudioLayerTimelineView(
            audioLayerManager: audioLayerManager,
            currentTime: .constant(15.0),
            isPlaying: .constant(false),
            scale: 1.0,
            offset: .constant(0.0),
            timelineDuration: 150.0
        )
        .frame(height: 200)
        .padding()
    }
} 