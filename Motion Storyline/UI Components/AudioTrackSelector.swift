import SwiftUI

/// A component that allows users to select which audio tracks to display in the timeline
public struct AudioTrackSelector: View {
    let mediaAssets: [MediaAsset]
    @Binding var selectedAudioTracks: Set<UUID>
    
    public init(mediaAssets: [MediaAsset], selectedAudioTracks: Binding<Set<UUID>>) {
        self.mediaAssets = mediaAssets
        self._selectedAudioTracks = selectedAudioTracks
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Audio Tracks")
                .font(.headline)
            
            if audioAssets.isEmpty {
                emptyStateView
            } else {
                audioTracksList
            }
        }
        .padding()
        .frame(minWidth: 250)
    }
    
    private var audioAssets: [MediaAsset] {
        return mediaAssets.filter { $0.type == .audio }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform")
                .font(.system(size: 24))
                .foregroundColor(.secondary)
                .padding(.bottom, 4)
            
            Text("No audio tracks available")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Import audio files using the Media Browser")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: {
                // This would typically be handled by the parent view
                // that would present the media browser
            }) {
                Text("Open Media Browser")
                    .font(.caption)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    private var audioTracksList: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(audioAssets) { asset in
                audioTrackRow(asset)
            }
        }
    }
    
    private func audioTrackRow(_ asset: MediaAsset) -> some View {
        HStack {
            Toggle(isOn: Binding(
                get: { selectedAudioTracks.contains(asset.id) },
                set: { newValue in
                    if newValue {
                        selectedAudioTracks.insert(asset.id)
                    } else {
                        selectedAudioTracks.remove(asset.id)
                    }
                }
            )) {
                HStack {
                    Image(systemName: "waveform")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    
                    Text(asset.name)
                        .font(.subheadline)
                        .lineLimit(1)
                    
                    if let duration = asset.duration {
                        Spacer()
                        Text(formatDuration(duration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .toggleStyle(.checkbox)
        }
        .padding(.vertical, 4)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Previews
struct AudioTrackSelector_Previews: PreviewProvider {
    static var previews: some View {
        // Sample media assets
        let assets: [MediaAsset] = [
            MediaAsset(
                name: "Background Music",
                type: .audio,
                url: URL(string: "file:///music.mp3")!,
                duration: 120.5
            ),
            MediaAsset(
                name: "Voice Over",
                type: .audio,
                url: URL(string: "file:///voice.mp3")!,
                duration: 45.2
            ),
            MediaAsset(
                name: "Sound Effects",
                type: .audio,
                url: URL(string: "file:///sfx.mp3")!,
                duration: 10.0
            )
        ]
        
        // Empty state
        VStack(spacing: 20) {
            AudioTrackSelector(
                mediaAssets: assets,
                selectedAudioTracks: .constant([assets[0].id])
            )
            .border(Color.gray, width: 0.5)
            
            AudioTrackSelector(
                mediaAssets: [],
                selectedAudioTracks: .constant([])
            )
            .border(Color.gray, width: 0.5)
        }
        .padding()
        .frame(width: 300)
    }
} 