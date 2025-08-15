import Foundation
import Combine

final class RecordingCoordinator: ObservableObject {
    enum Mode { case screenOnly, cameraOnly, both }

    @Published var mode: Mode = .screenOnly
    @Published var isRecording: Bool = false

    private let screenManager: ScreenRecorderManager
    private let cameraManager: CameraManager

    init(screenManager: ScreenRecorderManager = ScreenRecorderManager(), cameraManager: CameraManager = CameraManager()) {
        self.screenManager = screenManager
        self.cameraManager = cameraManager
    }

    func startScreen(options: ScreenCaptureOptions, completion: @escaping (Result<Void, Error>) -> Void) {
        screenManager.start(options: options) { result in
            switch result {
            case .success: self.isRecording = true; completion(.success(()))
            case .failure(let err): completion(.failure(err))
            }
        }
    }

    func stopScreen(completion: @escaping (Result<URL, Error>) -> Void) {
        screenManager.stop { result in
            self.isRecording = false
            completion(result)
        }
    }
}

