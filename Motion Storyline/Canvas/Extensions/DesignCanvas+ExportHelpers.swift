import SwiftUI
import AVFoundation // For AVAsset, used by createExportCoordinator

extension DesignCanvas {
    // MARK: - Export Helpers

    /// Creates an ExportCoordinator configured with the current animation state
    func createExportCoordinator(asset: AVAsset) -> ExportCoordinator {
        return ExportCoordinator(
            asset: asset, 
            animationController: animationController,
            canvasElements: canvasElements,
            canvasSize: CGSize(width: canvasWidth, height: canvasHeight)
        )
    }
    
    /// Gets a snapshot of canvas elements with animations applied at a specific time
    func getElementsAtTime(_ time: Double) -> [CanvasElement] {
        // Ensure animationController and canvasElements are available from self (DesignCanvas instance)
        // self.canvasElements is implicitly copied when passed as an argument if it's a struct array.
        // AnimationHelpers.applyAnimations also makes a mutable copy internally.
        return AnimationHelpers.applyAnimations(
            toElements: self.canvasElements, 
            using: self.animationController,
            at: time
        )
    }
}
