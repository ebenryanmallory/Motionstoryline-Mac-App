import SwiftUI
import AppKit

// A reusable component for displaying documentation overlays
struct InfoOverlayView: View {
    @Binding var isVisible: Bool
    let title: String
    let content: String
    let width: CGFloat
    let height: CGFloat
    
    init(isVisible: Binding<Bool>, title: String, content: String, width: CGFloat = 700, height: CGFloat = 600) {
        self._isVisible = isVisible
        self.title = title
        self.content = content
        self.width = width
        self.height = height
    }
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            if isVisible {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        isVisible = false
                    }
                    .transition(.opacity)
                
                // Overlay panel
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button(action: {
                            isVisible = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 20))
                        }
                        .buttonStyle(.plain)
                        .contentShape(Circle())
                        .help("Close")
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    
                    Divider()
                    
                    // Content area with scrolling
                    ScrollView {
                        Text(content)
                            .font(.system(.body, design: .monospaced))
                            .lineSpacing(5)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(width: width, height: height)
                .background(Color(NSColor.windowBackgroundColor))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isVisible)
    }
}

// For previewing purposes
struct InfoOverlayView_Previews: PreviewProvider {
    static var previews: some View {
        InfoOverlayView(
            isVisible: .constant(true),
            title: "Keyboard Shortcuts",
            content: """
            MOTION STORYLINE KEYBOARD SHORTCUTS
            
            TIMELINE NAVIGATION AND KEYFRAME CONTROL
            -----------------------------------------
            P                    Play/Pause animation
            ←                    Move backward by 0.1 seconds
            →                    Move forward by 0.1 seconds
            K                    Add keyframe at current time
            """
        )
    }
} 