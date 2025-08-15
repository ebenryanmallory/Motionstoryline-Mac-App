import Foundation
import SwiftUI
import AVFoundation

public struct ScreenCaptureOptions {
    public enum SourceSelection {
        case display(id: CGDirectDisplayID)
        case window(id: CGWindowID)
        case application(bundleIdentifier: String)
    }
    public var source: SourceSelection
    public var includeCursor: Bool
    public var highlightClicks: Bool
    public var framesPerSecond: Int
    public var includeMicrophone: Bool
    public init(
        source: SourceSelection,
        includeCursor: Bool = true,
        highlightClicks: Bool = false,
        framesPerSecond: Int = 30,
        includeMicrophone: Bool = true
    ) {
        self.source = source
        self.includeCursor = includeCursor
        self.highlightClicks = highlightClicks
        self.framesPerSecond = framesPerSecond
        self.includeMicrophone = includeMicrophone
    }
}

public protocol ScreenCaptureEngine: AnyObject {
    var previewLayer: CALayer? { get }
    var isRecording: Bool { get }
    func requestPermissionsIfNeeded(completion: @escaping (Bool) -> Void)
    func startRecording(options: ScreenCaptureOptions, outputURL: URL, completion: @escaping (Result<Void, Error>) -> Void)
    func stopRecording(completion: @escaping (Result<URL, Error>) -> Void)
}

public final class ScreenRecorderManager: ObservableObject {
    @Published public private(set) var isRecording: Bool = false
    @Published public private(set) var previewLayer: CALayer?
    @Published public private(set) var error: Error?

    private let engine: ScreenCaptureEngine
    private var currentOutputURL: URL?

    public init(engine: ScreenCaptureEngine? = nil) {
        if let engine = engine {
            self.engine = engine
        } else {
            #if canImport(ScreenCaptureKit)
            self.engine = ScreenCaptureKitRecorder()
            #else
            self.engine = AVCaptureScreenRecorder()
            #endif
        }
        self.previewLayer = self.engine.previewLayer
        self.isRecording = self.engine.isRecording
    }

    public func requestPermissions(completion: @escaping (Bool) -> Void) {
        engine.requestPermissionsIfNeeded { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    public func start(options: ScreenCaptureOptions, completion: @escaping (Result<URL, Error>) -> Void) {
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "screen_recording_\(Int(Date().timeIntervalSince1970)).mov"
        let outputURL = tempDir.appendingPathComponent(filename)
        currentOutputURL = outputURL
        engine.startRecording(options: options, outputURL: outputURL) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.isRecording = true
                    completion(.success(outputURL))
                case .failure(let error):
                    self?.error = error
                    completion(.failure(error))
                }
            }
        }
    }

    public func stop(completion: @escaping (Result<URL, Error>) -> Void) {
        engine.stopRecording { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let url):
                    self?.isRecording = false
                    completion(.success(url))
                case .failure(let error):
                    self?.error = error
                    completion(.failure(error))
                }
            }
        }
    }
}

