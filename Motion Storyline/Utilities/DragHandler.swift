import SwiftUI
import AppKit
import Combine

/// Handles drag operations for canvas elements
class DragHandler: ObservableObject {
    // Published properties for observing drag state
    @Published var isDragging: Bool = false
    @Published var draggedElementId: UUID?
    @Published var initialDragPosition: CGPoint?
    @Published var lastDragPosition: CGPoint?
    @Published var dragVelocity: CGPoint = .zero
    
    // State for calculating velocity
    private var lastUpdateTime: Date?
    private var lastPositions: [CGPoint] = []
    private let velocityCalculationWindow = 5 // Number of samples to consider
    
    // Grid settings that will be used for snap calculations
    private var gridSize: CGFloat = 20
    private var snapToGridEnabled: Bool = true
    
    init(gridSize: CGFloat = 20, snapToGridEnabled: Bool = true) {
        self.gridSize = gridSize
        self.snapToGridEnabled = snapToGridEnabled
    }
    
    /// Begin dragging an element
    func beginDrag(for elementId: UUID, at position: CGPoint) {
        draggedElementId = elementId
        initialDragPosition = position
        lastDragPosition = position
        lastUpdateTime = Date()
        lastPositions = []
        isDragging = true
    }
    
    /// End the current drag operation
    func endDrag() {
        draggedElementId = nil
        initialDragPosition = nil
        lastDragPosition = nil
        lastUpdateTime = nil
        isDragging = false
        
        // Reset velocity after sending one final update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.dragVelocity = .zero
        }
    }
    
    /// Updates element position during drag and calculates velocity
    /// - Parameters:
    ///   - position: Current drag position
    ///   - element: The element being dragged
    /// - Returns: The new position with grid snapping applied if enabled
    func handlePointDrag(position: CGPoint, for element: CanvasElement) -> CGPoint {
        guard let initialPosition = initialDragPosition else {
            return position
        }
        
        // Calculate the translation from the initial position
        let translationX = position.x - initialPosition.x
        let translationY = position.y - initialPosition.y
        
        // Apply the translation to the element's position
        var newPosition = CGPoint(
            x: element.position.x + translationX,
            y: element.position.y + translationY
        )
        
        // Apply snap to grid if enabled
        if snapToGridEnabled {
            newPosition.x = round(newPosition.x / gridSize) * gridSize
            newPosition.y = round(newPosition.y / gridSize) * gridSize
        }
        
        // Update last position and calculate velocity
        if let lastPosition = lastDragPosition {
            calculateVelocity(from: lastPosition, to: newPosition)
        }
        
        lastDragPosition = newPosition
        return newPosition
    }
    
    /// Update the grid settings
    func updateGridSettings(gridSize: CGFloat, snapToGridEnabled: Bool) {
        self.gridSize = gridSize
        self.snapToGridEnabled = snapToGridEnabled
    }
    
    /// Calculate velocity based on drag movement
    /// - Parameters:
    ///   - from: Previous position
    ///   - to: Current position
    private func calculateVelocity(from previousPosition: CGPoint, to currentPosition: CGPoint) {
        guard let lastTime = lastUpdateTime else { return }
        
        let now = Date()
        let timeInterval = now.timeIntervalSince(lastTime)
        
        if timeInterval > 0 {
            // Calculate instantaneous velocity
            let instantVelocityX = (currentPosition.x - previousPosition.x) / CGFloat(timeInterval)
            let instantVelocityY = (currentPosition.y - previousPosition.y) / CGFloat(timeInterval)
            
            let instantVelocity = CGPoint(x: instantVelocityX, y: instantVelocityY)
            
            // Add to the velocity history
            lastPositions.append(instantVelocity)
            if lastPositions.count > velocityCalculationWindow {
                lastPositions.removeFirst()
            }
            
            // Average the velocities for smoother results
            var totalX: CGFloat = 0
            var totalY: CGFloat = 0
            
            for velocity in lastPositions {
                totalX += velocity.x
                totalY += velocity.y
            }
            
            let averageVelocityX = totalX / CGFloat(lastPositions.count)
            let averageVelocityY = totalY / CGFloat(lastPositions.count)
            
            // Update the drag velocity
            dragVelocity = CGPoint(x: averageVelocityX, y: averageVelocityY)
        }
        
        lastUpdateTime = now
    }
    
    /// Calculates the deceleration of an element based on its current velocity
    /// - Parameters:
    ///   - initialVelocity: Starting velocity
    ///   - decelerationRate: Rate at which velocity decreases (0-1)
    /// - Returns: A future publisher that emits the decelerating velocity over time
    func calculateDeceleration(initialVelocity: CGPoint, decelerationRate: CGFloat = 0.95) -> AnyPublisher<CGPoint, Never> {
        let subject = PassthroughSubject<CGPoint, Never>()
        var currentVelocity = initialVelocity
        
        // Create a timer that updates the velocity with deceleration
        let timer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()
        
        return timer
            .map { _ in
                // Apply deceleration
                currentVelocity = CGPoint(
                    x: currentVelocity.x * decelerationRate,
                    y: currentVelocity.y * decelerationRate
                )
                
                // Check if velocity is small enough to consider stopped
                if abs(currentVelocity.x) < 0.1 && abs(currentVelocity.y) < 0.1 {
                    return CGPoint.zero
                }
                
                return currentVelocity
            }
            .prefix(while: { velocity in
                // Continue until velocity is essentially zero
                return abs(velocity.x) >= 0.1 || abs(velocity.y) >= 0.1
            })
            .eraseToAnyPublisher()
    }
} 