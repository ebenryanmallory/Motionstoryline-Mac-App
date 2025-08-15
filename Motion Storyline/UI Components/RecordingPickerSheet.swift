import SwiftUI

struct RecordingPickerSheet: View {
    var onScreen: (_ includeMicrophone: Bool, _ countdown: Bool) -> Void
    var onCamera: (_ includeMicrophone: Bool, _ countdown: Bool) -> Void
    var onBoth: (_ includeMicrophone: Bool, _ countdown: Bool) -> Void
    @Binding var isPresented: Bool
    
    @EnvironmentObject private var preferences: PreferencesViewModel
    @State private var includeMicrophone = true
    @State private var countdown = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Start Recording").font(.title2).bold()
                Spacer()
                Button(action: { isPresented = false }) { Image(systemName: "xmark") }
            }
            Text("Choose what to record.").foregroundColor(.secondary)
            HStack(spacing: 12) {
                Button { onScreen(includeMicrophone, countdown); isPresented = false } label: { Label("Screen", systemImage: "display") }
                Button { onCamera(includeMicrophone, countdown); isPresented = false } label: { Label("Camera", systemImage: "camera") }
                Button { onBoth(includeMicrophone, countdown); isPresented = false } label: { Label("Both", systemImage: "rectangle.badge.person.crop") }
            }
            .buttonStyle(.borderedProminent)
            Divider()
            Toggle("Include microphone", isOn: $includeMicrophone)
            Toggle("3s countdown", isOn: $countdown)
            Spacer()
        }
        .padding()
        .frame(width: 420, height: 220)
        .onAppear {
            // Initialize state from preferences when the sheet appears
            includeMicrophone = preferences.defaultIncludeMicrophone
            countdown = preferences.defaultCountdown
        }
    }
}

