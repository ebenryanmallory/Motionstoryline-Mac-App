import XCTest
@testable import Motion_Storyline

final class ProjectTests: XCTestCase {
    
    func testProjectInitialization() {
        // Create a test project
        let projectName = "Test Project"
        let thumbnail = "design_thumbnail"
        let date = Date()
        
        let project = Project(
            name: projectName,
            thumbnail: thumbnail,
            lastModified: date
        )
        
        // Test basic properties
        XCTAssertEqual(project.name, projectName)
        XCTAssertEqual(project.thumbnail, thumbnail)
        XCTAssertEqual(project.lastModified, date)
        XCTAssertEqual(project.mediaAssets.count, 0)
        XCTAssertEqual(project.zoomLevel, 1.0)
        XCTAssertEqual(project.panOffsetX, 0.0)
        XCTAssertEqual(project.panOffsetY, 0.0)
    }
    
    func testAddMediaAsset() {
        // Create a test project
        var project = Project(
            name: "Test Project",
            thumbnail: "design_thumbnail",
            lastModified: Date(timeIntervalSince1970: 0) // Use a fixed date for testing
        )
        
        // Create a test media asset
        let assetName = "Test Asset"
        let assetType = MediaAsset.MediaType.image
        let assetURL = URL(string: "file:///test.png")!
        
        let asset = MediaAsset(
            name: assetName,
            type: assetType,
            url: assetURL
        )
        
        // Add the asset to the project
        project.addMediaAsset(asset)
        
        // Test that the asset was added
        XCTAssertEqual(project.mediaAssets.count, 1)
        XCTAssertEqual(project.mediaAssets[0].name, assetName)
        XCTAssertEqual(project.mediaAssets[0].type, assetType)
        XCTAssertEqual(project.mediaAssets[0].url, assetURL)
        
        // Test that the lastModified date was updated
        XCTAssertGreaterThan(project.lastModified, Date(timeIntervalSince1970: 0))
    }
    
    func testProjectEquality() {
        // Create two projects with the same ID
        let id = UUID()
        let project1 = Project(
            id: id,
            name: "Project 1",
            thumbnail: "design_thumbnail",
            lastModified: Date()
        )
        
        let project2 = Project(
            id: id,
            name: "Project 2", // Different name
            thumbnail: "prototype_thumbnail", // Different thumbnail
            lastModified: Date(timeIntervalSinceNow: -3600) // Different date
        )
        
        // Test that they are considered equal because they have the same ID
        XCTAssertEqual(project1, project2)
        
        // Create a project with a different ID
        let project3 = Project(
            name: "Project 1", // Same name as project1
            thumbnail: "design_thumbnail", // Same thumbnail as project1
            lastModified: project1.lastModified // Same date as project1
        )
        
        // Test that it's not equal to project1 because it has a different ID
        XCTAssertNotEqual(project1, project3)
    }
} 