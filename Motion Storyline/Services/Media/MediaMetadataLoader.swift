import Foundation
import AVFoundation
import AppKit

public actor MediaMetadataCache {
    private var dimensionCache: [URL: CGSize] = [:]

    public init() {}

    public func dimensions(for url: URL) -> CGSize? {
        return dimensionCache[url]
    }

    public func setDimensions(_ size: CGSize, for url: URL) {
        dimensionCache[url] = size
    }
}

public struct MediaMetadataLoader {
    public static let shared = MediaMetadataLoader()

    private let cache: MediaMetadataCache

    public init(cache: MediaMetadataCache = MediaMetadataCache()) {
        self.cache = cache
    }

    public func getDimensions(for url: URL, type: MediaAsset.MediaType) async throws -> CGSize? {
        if let cached = await cache.dimensions(for: url) {
            return cached
        }

        switch type {
        case .image:
            if let img = NSImage(contentsOf: url) {
                let size = img.size
                await cache.setDimensions(size, for: url)
                return size
            }
            return nil
        case .video, .cameraRecording:
            let size = try await getVideoDimensions(url: url)
            await cache.setDimensions(size, for: url)
            return size
        case .audio:
            return nil
        }
    }

    public func getVideoDimensions(url: URL) async throws -> CGSize {
        let asset = AVAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let track = tracks.first else {
            throw NSError(domain: "MediaMetadataLoader", code: 1, userInfo: [NSLocalizedDescriptionKey: "No video track found"])
        }

        async let naturalSize = track.load(.naturalSize)
        async let transform = track.load(.preferredTransform)
        let (ns, tx) = try await (naturalSize, transform)

        let applied = ns.applying(tx)
        return CGSize(width: abs(applied.width), height: abs(applied.height))
    }

    public func getDuration(url: URL) async throws -> TimeInterval {
        let asset = AVAsset(url: url)
        let duration = try await asset.load(.duration)
        return duration.seconds
    }
}

