import SwiftUI
import QuartzCore

struct ScreenCapturePreviewView: NSViewRepresentable {
    var displayLayer: CALayer?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer = CALayer()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if let layer = displayLayer {
            layer.frame = nsView.bounds
            if nsView.layer !== layer {
                nsView.layer = layer
            }
        } else if nsView.layer == nil {
            nsView.wantsLayer = true
            nsView.layer = CALayer()
        }
        CATransaction.commit()
    }
}

