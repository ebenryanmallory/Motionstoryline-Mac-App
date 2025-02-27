import SwiftUI

struct FooterView: View {
    let version = "v1.0.0"
    @Binding var status: String
    
    var body: some View {
        HStack {
            // Left side status
            Text(status)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            Spacer()
            
            // Right side items
            HStack(spacing: 12) {
                // Connection status indicator
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                
                // Version
                Text(version)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .frame(height: 24)
        .padding(.horizontal, 10)
        .background(Color(NSColor.windowBackgroundColor))
        .border(Color(NSColor.separatorColor), width: 0.5)
    }
}

#Preview {
    FooterView(status: .constant("Ready"))
        .frame(width: 600)
} 