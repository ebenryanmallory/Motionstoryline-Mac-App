import Foundation
import AVFoundation

final class AVCaptureScreenRecorder: NSObject, ScreenCaptureEngine {
    private var session: AVCaptureSession?
    private var movieOutput: AVCaptureMovieFileOutput?
    private var outputURL: URL?

    var previewLayer: CALayer? { nil } // Optional; can implement NSView preview later
    var isRecording: Bool { movieOutput?.isRecording ?? false }

    func requestPermissionsIfNeeded(completion: @escaping (Bool) -> Void) {
        // Mic permission only if including audio; screen capture permission handled by OS privacy dialog
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized, .denied, .restricted:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { _ in completion(true) }
        @unknown default:
            completion(true)
        }
    }

    func startRecording(options: ScreenCaptureOptions, outputURL: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        let session = AVCaptureSession()
        session.beginConfiguration()
        session.sessionPreset = .high
        let displayID: CGDirectDisplayID
        switch options.source {
        case .display(let id): displayID = id
        default: displayID = CGMainDisplayID()
        }
        guard let screenInput = AVCaptureScreenInput(displayID: displayID) else {
            return completion(.failure(NSError(domain: "ScreenCapture", code: -20, userInfo: [NSLocalizedDescriptionKey: "Unable to create screen input"])) )
        }
        screenInput.capturesCursor = options.includeCursor
        screenInput.capturesMouseClicks = options.highlightClicks
        screenInput.minFrameDuration = CMTime(value: 1, timescale: CMTimeScale(max(1, options.framesPerSecond)))
        if session.canAddInput(screenInput) { session.addInput(screenInput) }
        let movieOutput = AVCaptureMovieFileOutput()
        if session.canAddOutput(movieOutput) { session.addOutput(movieOutput) }
        session.commitConfiguration()
        self.session = session
        self.movieOutput = movieOutput
        self.outputURL = outputURL
        session.startRunning()
        movieOutput.startRecording(to: outputURL, recordingDelegate: self)
        completion(.success(()))
    }

    func stopRecording(completion: @escaping (Result<URL, Error>) -> Void) {
        guard let movieOutput else { return completion(.failure(NSError(domain: "ScreenCapture", code: -21))) }
        movieOutput.stopRecording()
        // Delegate callback will provide result
        self.stopCompletion = completion
    }

    private var stopCompletion: ((Result<URL, Error>) -> Void)?
}

extension AVCaptureScreenRecorder: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        session?.stopRunning()
        if let error = error {
            stopCompletion?(.failure(error))
        } else {
            stopCompletion?(.success(outputFileURL))
        }
        stopCompletion = nil
        movieOutput = nil
        session = nil
    }
}

