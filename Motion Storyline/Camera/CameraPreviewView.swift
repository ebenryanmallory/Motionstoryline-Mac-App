import SwiftUI
import AVFoundation

struct CameraPreviewView: NSViewRepresentable {
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer = CALayer() // Ensure there's a base layer
        
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        guard let previewLayer = previewLayer else {
            // If no preview layer, ensure we have a clean base layer
            if nsView.layer == nil {
                nsView.wantsLayer = true
                nsView.layer = CALayer()
            }
            return
        }
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        // Update the frame
        previewLayer.frame = nsView.bounds
        
        // Only replace the layer if needed
        if nsView.layer != previewLayer {
            // First ensure the view wants a layer
            nsView.wantsLayer = true
            
            // Then safely assign the preview layer
            nsView.layer = previewLayer
        }
        
        CATransaction.commit()
    }
} 