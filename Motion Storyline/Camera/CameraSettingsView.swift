import SwiftUI

struct CameraSettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Camera Settings")
                .font(.headline)
            
            Divider()
            
            // Camera selection (placeholder)
            Picker("Camera", selection: .constant(0)) {
                Text("FaceTime HD Camera").tag(0)
            }
            .pickerStyle(.menu)
            
            // Resolution selection (placeholder)
            Picker("Resolution", selection: .constant(0)) {
                Text("720p").tag(0)
                Text("1080p").tag(1)
            }
            .pickerStyle(.menu)
            
            Spacer()
            
            Button("Done") {
                presentationMode.wrappedValue.dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
} 