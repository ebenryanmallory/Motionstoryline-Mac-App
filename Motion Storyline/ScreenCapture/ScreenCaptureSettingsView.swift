import SwiftUI

struct ScreenCaptureSettingsView: View {
    @State private var includeCursor = true
    @State private var highlightClicks = false
    @State private var framesPerSecond = 30

    var body: some View {
        Form {
            Toggle("Include cursor", isOn: $includeCursor)
            Toggle("Highlight clicks", isOn: $highlightClicks)
            Stepper("FPS: \(framesPerSecond)", value: $framesPerSecond, in: 15...60)
        }
        .padding()
        .frame(width: 300, height: 180)
    }
}

