import SwiftUI

struct CanvasExportProgressView: View {
    @Binding var exportProgress: Double
    @Binding var isExporting: Bool // Used to control visibility and potentially cancel action
    var onCancel: () -> Void

    var body: some View {
        VStack(spacing: 15) {
            Text("Exporting Video")
                .font(.headline)

            ProgressView(value: exportProgress, total: 1.0) {
                Text(String(format: "%.0f %%", exportProgress * 100))
            }
            .progressViewStyle(LinearProgressViewStyle())
            .padding(.horizontal)
            
            Button("Cancel") {
                onCancel()
            }
            .keyboardShortcut(.cancelAction) // Allow Esc to cancel
        }
        .padding()
        .frame(width: 300, height: 120)
        .background(Material.regularMaterial) // Using system material for modern look
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }
}

#if DEBUG
struct CanvasExportProgressView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray.opacity(0.1).edgesIgnoringSafeArea(.all)
            CanvasExportProgressView(
                exportProgress: .constant(0.65),
                isExporting: .constant(true),
                onCancel: { print("Cancel tapped in preview") }
            )
        }
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
#endif
