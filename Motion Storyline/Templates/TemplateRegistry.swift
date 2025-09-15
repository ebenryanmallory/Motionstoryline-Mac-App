import SwiftUI
import Foundation

/// Developer-friendly registry for built-in starter templates.
/// Keeps things simple: <=10 templates, all first-party.
struct TemplateRegistry {
    /// Known template identifiers used by UI cards and seeding
    enum TemplateID: String {
        case grid = "grid-template"
        case hero = "hero-template"
        case videoShowcase = "video-showcase-template"
    }

    /// Write the specified template's serialized .storyline content to the destination URL.
    /// If the template ID is unknown, throws an error.
    static func writeTemplate(id: String, to destinationURL: URL) throws {
        guard let template = TemplateID(rawValue: id) else {
            throw NSError(domain: "TemplateRegistry", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unknown template id: \(id)"])
        }

        let projectData: ProjectData
        switch template {
        case .grid:
            projectData = makeGridTemplate()
        case .hero:
            projectData = makeHeroTemplate()
        case .videoShowcase:
            projectData = makeVideoShowcaseTemplate()
        }

        // Ensure parent directory exists
        let parent = destinationURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)

        // Encode and write JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let data = try encoder.encode(projectData)
        try data.write(to: destinationURL, options: .atomic)
    }

    /// Minimal starter showing a visible difference: grid enabled, larger grid size,
    /// with a prominent title text and a light background rectangle.
    private static func makeGridTemplate() -> ProjectData {
        let canvasWidth: CGFloat = 1280
        let canvasHeight: CGFloat = 720

        // Background card for contrast
        let background = CanvasElement(
            type: .rectangle,
            position: CGPoint(x: canvasWidth/2, y: canvasHeight/2),
            size: CGSize(width: 960, height: 540),
            rotation: 0,
            opacity: 1.0,
            scale: 1.0,
            color: Color(red: 0.96, green: 0.97, blue: 0.98, opacity: 1.0),
            text: "",
            textAlignment: .leading,
            fontSize: 16.0,
            displayName: "Backdrop",
            isAspectRatioLocked: true
        )

        // Title text indicating this is the Grid Template
        let title = CanvasElement(
            type: .text,
            position: CGPoint(x: canvasWidth/2, y: canvasHeight/2 - 150),
            size: CGSize(width: 800, height: 60),
            rotation: 0,
            opacity: 1.0,
            scale: 1.0,
            color: Color(red: 0.10, green: 0.10, blue: 0.12, opacity: 1.0),
            text: "Grid Template Starter",
            textAlignment: .center,
            fontSize: 36.0,
            displayName: "Title",
            isAspectRatioLocked: true
        )

        // Accent ellipse to show shape variety
        let accent = CanvasElement(
            type: .ellipse,
            position: CGPoint(x: canvasWidth/2, y: canvasHeight/2 + 20),
            size: CGSize(width: 140, height: 140),
            rotation: 0,
            opacity: 1.0,
            scale: 1.0,
            color: Color(red: 0.20, green: 0.55, blue: 0.95, opacity: 1.0),
            text: "",
            textAlignment: .leading,
            fontSize: 16.0,
            displayName: "Accent",
            isAspectRatioLocked: true
        )

        let elements = [background, title, accent]

        // Enable grid with larger size so it’s obvious
        let prefs = CanvasPreferences(
            showGrid: true,
            gridSize: 40,
            gridColorR: 0.75,
            gridColorG: 0.75,
            gridColorB: 0.78,
            gridColorA: 1.0,
            canvasBgColorR: 1.0,
            canvasBgColorG: 1.0,
            canvasBgColorB: 1.0,
            canvasBgColorA: 1.0
        )

        return ProjectData(
            elements: elements,
            tracks: [],
            duration: 5.0,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            mediaAssets: [],
            audioLayers: [],
            canvasPreferences: prefs
        )
    }

    /// Simple hero-style title template: dark backdrop, bold centered title and subtitle,
    /// with an accent bar for visual interest. Grid disabled for a clean look.
    private static func makeHeroTemplate() -> ProjectData {
        let canvasWidth: CGFloat = 1280
        let canvasHeight: CGFloat = 720

        // Dark backdrop
        let backdrop = CanvasElement(
            type: .rectangle,
            position: CGPoint(x: canvasWidth/2, y: canvasHeight/2),
            size: CGSize(width: canvasWidth - 160, height: canvasHeight - 120),
            rotation: 0,
            opacity: 1.0,
            scale: 1.0,
            color: Color(red: 0.10, green: 0.12, blue: 0.16, opacity: 1.0),
            text: "",
            textAlignment: .leading,
            fontSize: 16.0,
            displayName: "Backdrop",
            isAspectRatioLocked: true
        )

        // Accent bar
        let accentBar = CanvasElement(
            type: .rectangle,
            position: CGPoint(x: canvasWidth/2, y: canvasHeight/2 - 120),
            size: CGSize(width: 200, height: 8),
            rotation: 0,
            opacity: 1.0,
            scale: 1.0,
            color: Color(red: 0.25, green: 0.60, blue: 0.98, opacity: 1.0),
            text: "",
            textAlignment: .leading,
            fontSize: 16.0,
            displayName: "Accent Bar",
            isAspectRatioLocked: true
        )

        // Title
        let title = CanvasElement(
            type: .text,
            position: CGPoint(x: canvasWidth/2, y: canvasHeight/2 - 60),
            size: CGSize(width: 900, height: 80),
            rotation: 0,
            opacity: 1.0,
            scale: 1.0,
            color: Color(red: 0.96, green: 0.97, blue: 0.99, opacity: 1.0),
            text: "Hero Title Template",
            textAlignment: .center,
            fontSize: 48.0,
            displayName: "Title",
            isAspectRatioLocked: true
        )

        // Subtitle
        let subtitle = CanvasElement(
            type: .text,
            position: CGPoint(x: canvasWidth/2, y: canvasHeight/2 + 10),
            size: CGSize(width: 900, height: 60),
            rotation: 0,
            opacity: 0.95,
            scale: 1.0,
            color: Color(red: 0.78, green: 0.82, blue: 0.88, opacity: 1.0),
            text: "A clean starting point for hero sections",
            textAlignment: .center,
            fontSize: 24.0,
            displayName: "Subtitle",
            isAspectRatioLocked: true
        )

        let elements = [backdrop, accentBar, title, subtitle]

        // Grid disabled for a clean hero look
        let prefs = CanvasPreferences(
            showGrid: false,
            gridSize: 20,
            gridColorR: 0.75,
            gridColorG: 0.75,
            gridColorB: 0.78,
            gridColorA: 1.0,
            canvasBgColorR: 1.0,
            canvasBgColorG: 1.0,
            canvasBgColorB: 1.0,
            canvasBgColorA: 1.0
        )

        return ProjectData(
            elements: elements,
            tracks: [],
            duration: 5.0,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            mediaAssets: [],
            audioLayers: [],
            canvasPreferences: prefs
        )
    }

    /// Video-focused template with a large 16:9 video placeholder, clear instructional text,
    /// and subtle decorative elements to frame the content.
    private static func makeVideoShowcaseTemplate() -> ProjectData {
        let canvasWidth: CGFloat = 1280
        let canvasHeight: CGFloat = 720

        // Subtle page background card
        let page = CanvasElement(
            type: .rectangle,
            position: CGPoint(x: canvasWidth/2, y: canvasHeight/2),
            size: CGSize(width: canvasWidth - 120, height: canvasHeight - 100),
            opacity: 1.0,
            scale: 1.0,
            color: Color(red: 0.97, green: 0.98, blue: 1.0, opacity: 1.0),
            displayName: "Page",
            isAspectRatioLocked: true
        )

        // Decorative corner ellipse
        let deco1 = CanvasElement(
            type: .ellipse,
            position: CGPoint(x: 160, y: 140),
            size: CGSize(width: 180, height: 180),
            rotation: 0,
            opacity: 0.15,
            scale: 1.0,
            color: Color(red: 0.25, green: 0.60, blue: 0.98, opacity: 1.0),
            text: "",
            textAlignment: .leading,
            fontSize: 16.0,
            displayName: "Accent Circle",
            isAspectRatioLocked: true
        )

        // Decorative bottom-right block
        let deco2 = CanvasElement(
            type: .rectangle,
            position: CGPoint(x: canvasWidth - 200, y: canvasHeight - 120),
            size: CGSize(width: 220, height: 80),
            rotation: -6,
            opacity: 0.12,
            scale: 1.0,
            color: Color(red: 0.10, green: 0.12, blue: 0.16, opacity: 1.0),
            text: "",
            textAlignment: .leading,
            fontSize: 16.0,
            displayName: "Accent Block",
            isAspectRatioLocked: true
        )

        // Header title
        let title = CanvasElement(
            type: .text,
            position: CGPoint(x: canvasWidth/2, y: 160),
            size: CGSize(width: 960, height: 64),
            rotation: 0,
            opacity: 1.0,
            scale: 1.0,
            color: Color(red: 0.10, green: 0.12, blue: 0.16, opacity: 1.0),
            text: "SaaS Video Showcase",
            textAlignment: .center,
            fontSize: 40.0,
            displayName: "Title",
            isAspectRatioLocked: true
        )

        // Subtitle / instruction line
        let subtitle = CanvasElement(
            type: .text,
            position: CGPoint(x: canvasWidth/2, y: 205),
            size: CGSize(width: 1000, height: 40),
            rotation: 0,
            opacity: 0.9,
            scale: 1.0,
            color: Color(red: 0.30, green: 0.34, blue: 0.40, opacity: 1.0),
            text: "Record your screen, then drop the file onto the placeholder below",
            textAlignment: .center,
            fontSize: 18.0,
            displayName: "Subtitle",
            isAspectRatioLocked: true
        )

        // Placeholder frame (subtle border effect via layered rectangles)
        let frameOuter = CanvasElement(
            type: .rectangle,
            position: CGPoint(x: canvasWidth/2, y: canvasHeight/2 + 40),
            size: CGSize(width: 1040, height: 600),
            rotation: 0,
            opacity: 1.0,
            scale: 1.0,
            color: Color(red: 0.90, green: 0.92, blue: 0.96, opacity: 1.0),
            text: "",
            textAlignment: .leading,
            fontSize: 16.0,
            displayName: "Placeholder Frame",
            isAspectRatioLocked: true
        )

        // Large 16:9 video placeholder (no URL yet)
        let videoPlaceholder = CanvasElement.video(
            at: CGPoint(x: canvasWidth/2, y: canvasHeight/2 + 40),
            assetURL: nil,
            displayName: "Screen Recording Placeholder",
            size: CGSize(width: 1024, height: 576),
            scale: 1.0
        )

        // Helper text inside/below placeholder
        let helper = CanvasElement(
            type: .text,
            position: CGPoint(x: canvasWidth/2, y: canvasHeight/2 + 320),
            size: CGSize(width: 1040, height: 40),
            rotation: 0,
            opacity: 0.85,
            scale: 1.0,
            color: Color(red: 0.25, green: 0.28, blue: 0.35, opacity: 1.0),
            text: "Tip: Select the video element and replace it with your recording",
            textAlignment: .center,
            fontSize: 16.0,
            displayName: "Tip",
            isAspectRatioLocked: true
        )

        let elements = [page, deco1, deco2, title, subtitle, frameOuter, videoPlaceholder, helper]

        let prefs = CanvasPreferences(
            showGrid: false,
            gridSize: 20,
            gridColorR: 0.75,
            gridColorG: 0.75,
            gridColorB: 0.78,
            gridColorA: 1.0,
            canvasBgColorR: 1.0,
            canvasBgColorG: 1.0,
            canvasBgColorB: 1.0,
            canvasBgColorA: 1.0
        )

        return ProjectData(
            elements: elements,
            tracks: [],
            duration: 6.0,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            mediaAssets: [],
            audioLayers: [],
            canvasPreferences: prefs
        )
    }
}
