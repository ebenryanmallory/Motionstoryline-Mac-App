//
//  VideoExporterTests.swift
//  Motion StorylineTests
//
//  Created by rpf on 5/12/25.
//

import XCTest
import AVFoundation
@testable import Motion_Storyline

@available(macOS 10.15, *)
final class VideoExporterTests: XCTestCase {
    // MARK: - Properties
    
    var tempDirectoryURL: URL!
    var sampleVideoURL: URL!
    var videoExporter: VideoExporter?
    
    // MARK: - Setup & Teardown
    
    override func setUpWithError() throws {
        // Create a temporary directory for test files
        tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("VideoExporterTests_\(UUID().uuidString)")
        
        try FileManager.default.createDirectory(
            at: tempDirectoryURL,
            withIntermediateDirectories: true
        )
        
        // If testing with real files, we would set up a sample video here
        // For unit testing, we'll use a mock asset instead
        setUpMockAsset()
    }
    
    override func tearDownWithError() throws {
        // Clean up temporary directory
        if let tempDirectoryURL = tempDirectoryURL, FileManager.default.fileExists(atPath: tempDirectoryURL.path) {
            try FileManager.default.removeItem(at: tempDirectoryURL)
        }
        
        videoExporter = nil
    }
    
    // MARK: - Helper Methods
    
    private func setUpMockAsset() {
        // Create a simple AVAsset for testing purposes
        // For unit tests, we can create a simulated asset
        
        // 1. Create a temporary URL for our "test video"
        sampleVideoURL = tempDirectoryURL.appendingPathComponent("sample_video.mov")
        
        // 2. Create a test AVAsset
        // In a real implementation, we would create a real test file
        // For unit tests, we'll use a mock approach
        let asset = AVAsset(url: sampleVideoURL)
        
        // 3. Initialize exporter with this asset
        videoExporter = VideoExporter(asset: asset)
    }
    
    private func createMockExportConfiguration(format: ExportFormat) -> VideoExporter.ExportConfiguration {
        let outputURL = tempDirectoryURL.appendingPathComponent(
            "export_\(UUID().uuidString).\(format == .video ? "mp4" : "png")"
        )
        
        return VideoExporter.ExportConfiguration(
            format: format,
            width: 1920,
            height: 1080,
            frameRate: 30.0,
            bitrate: 8_000_000,
            proResProfile: nil,
            includeAudio: true,
            outputURL: outputURL
        )
    }
    
    // MARK: - Tests for Export Configuration
    
    func testExportConfigurationInitialization() {
        let outputURL = URL(fileURLWithPath: "/tmp/test.mp4")
        
        // Test the default initialization
        let config = VideoExporter.ExportConfiguration(
            width: 1920,
            height: 1080,
            outputURL: outputURL
        )
        
        XCTAssertEqual(config.format, .video)
        XCTAssertEqual(config.width, 1920)
        XCTAssertEqual(config.height, 1080)
        XCTAssertEqual(config.frameRate, 30.0)
        XCTAssertNil(config.bitrate)
        XCTAssertNil(config.proResProfile)
        XCTAssertTrue(config.includeAudio)
        XCTAssertEqual(config.outputURL, outputURL)
        XCTAssertNil(config.baseFilename)
        XCTAssertNil(config.imageQuality)
        XCTAssertNil(config.additionalSettings)
        
        // Test custom initialization
        let customConfig = VideoExporter.ExportConfiguration(
            format: .imageSequence(.png),
            width: 3840,
            height: 2160,
            frameRate: 60.0,
            bitrate: 20_000_000,
            proResProfile: .proRes422HQ,
            includeAudio: false,
            outputURL: outputURL,
            baseFilename: "frame",
            imageQuality: 0.9,
            additionalSettings: ["colorSpace": "sRGB"]
        )
        
        XCTAssertEqual(customConfig.format, .imageSequence(.png))
        XCTAssertEqual(customConfig.width, 3840)
        XCTAssertEqual(customConfig.height, 2160)
        XCTAssertEqual(customConfig.frameRate, 60.0)
        XCTAssertEqual(customConfig.bitrate, 20_000_000)
        XCTAssertEqual(customConfig.proResProfile, .proRes422HQ)
        XCTAssertFalse(customConfig.includeAudio)
        XCTAssertEqual(customConfig.outputURL, outputURL)
        XCTAssertEqual(customConfig.baseFilename, "frame")
        XCTAssertEqual(customConfig.imageQuality, 0.9)
        XCTAssertEqual(customConfig.additionalSettings?["colorSpace"], "sRGB")
    }
    
    func testProResProfileValues() {
        // Test avCodecKey values
        XCTAssertEqual(VideoExporter.ProResProfile.proRes422Proxy.avCodecKey, AVVideoCodecType.proRes422Proxy.rawValue)
        XCTAssertEqual(VideoExporter.ProResProfile.proRes422LT.avCodecKey, AVVideoCodecType.proRes422LT.rawValue)
        XCTAssertEqual(VideoExporter.ProResProfile.proRes422.avCodecKey, AVVideoCodecType.proRes422.rawValue)
        XCTAssertEqual(VideoExporter.ProResProfile.proRes422HQ.avCodecKey, AVVideoCodecType.proRes422HQ.rawValue)
        XCTAssertEqual(VideoExporter.ProResProfile.proRes4444.avCodecKey, AVVideoCodecType.proRes4444.rawValue)
        
        // For proRes4444XQ, it uses proRes4444 as base
        XCTAssertEqual(VideoExporter.ProResProfile.proRes4444XQ.avCodecKey, AVVideoCodecType.proRes4444.rawValue)
        
        // Test descriptions
        XCTAssertTrue(VideoExporter.ProResProfile.proRes422Proxy.description.contains("Proxy"))
        XCTAssertTrue(VideoExporter.ProResProfile.proRes422LT.description.contains("LT"))
        XCTAssertTrue(VideoExporter.ProResProfile.proRes422.description.contains("Standard"))
        XCTAssertTrue(VideoExporter.ProResProfile.proRes422HQ.description.contains("High Quality"))
        XCTAssertTrue(VideoExporter.ProResProfile.proRes4444.description.contains("Very High"))
        XCTAssertTrue(VideoExporter.ProResProfile.proRes4444XQ.description.contains("Maximum"))
    }
    
    // MARK: - Tests for Error Handling
    
    func testExportErrorDescriptions() {
        let testError = NSError(domain: "test", code: 123, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        
        // Test localized descriptions of all error cases
        XCTAssertTrue(VideoExporter.ExportError.invalidAsset.localizedDescription.contains("invalid"))
        XCTAssertTrue(VideoExporter.ExportError.exportSessionSetupFailed.localizedDescription.contains("set up"))
        XCTAssertTrue(VideoExporter.ExportError.exportFailed(testError).localizedDescription.contains("Test error"))
        XCTAssertTrue(VideoExporter.ExportError.cancelled.localizedDescription.contains("cancelled"))
        XCTAssertTrue(VideoExporter.ExportError.unsupportedFormat.localizedDescription.contains("not supported"))
        XCTAssertTrue(VideoExporter.ExportError.invalidExportSettings.localizedDescription.contains("invalid"))
        XCTAssertTrue(VideoExporter.ExportError.fileCreationFailed.localizedDescription.contains("Failed to create"))
    }
    
    // MARK: - Tests for Export Operations
    
    func testInvalidAssetExport() {
        // Expectations won't be fulfilled in this test since we're using a mock approach
        // In a real implementation with files, we would use expectations
        
        let expectation = XCTestExpectation(description: "Invalid asset export completion")
        let config = createMockExportConfiguration(format: .video)
        
        // We know our video exporter has an invalid asset (empty URL)
        // This should fail with invalidAsset error
        Task {
            await videoExporter?.export(with: config, progressHandler: { _ in }, completion: { result in
                switch result {
                case .success:
                    XCTFail("Export should have failed with invalid asset")
                case .failure(let error):
                    if case .invalidAsset = error {
                        // This is the expected error
                        expectation.fulfill()
                    } else {
                        XCTFail("Unexpected error: \(error.localizedDescription)")
                    }
                }
            })
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testUnsupportedFormatExport() {
        // Test exporting with an unsupported format (GIF)
        let expectation = XCTestExpectation(description: "Unsupported format export completion")
        let config = VideoExporter.ExportConfiguration(
            format: .gif,
            width: 1920,
            height: 1080,
            outputURL: tempDirectoryURL.appendingPathComponent("test.gif")
        )
        
        Task {
            await videoExporter?.export(with: config, completion: { result in
                switch result {
                case .success:
                    XCTFail("Export should have failed with unsupported format")
                case .failure(let error):
                    if case .unsupportedFormat = error {
                        // This is the expected error
                        expectation.fulfill()
                    } else {
                        XCTFail("Unexpected error: \(error.localizedDescription)")
                    }
                }
            })
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Integration Tests (Would require real files)
    
    /*
    // Note: These tests would require actual video files and would be 
    // more suitable for integration testing than unit testing
    
    func testVideoExport() async throws {
        guard let videoExporter = VideoExporter(url: realVideoFileURL) else {
            XCTFail("Could not create exporter")
            return
        }
        
        let outputURL = tempDirectoryURL.appendingPathComponent("export_test.mp4")
        let config = VideoExporter.ExportConfiguration(
            width: 1280,
            height: 720,
            outputURL: outputURL
        )
        
        let expectation = XCTestExpectation(description: "Video export")
        
        await videoExporter.export(with: config) { result in
            switch result {
            case .success(let url):
                XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
                let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
                let fileSize = attrs?[.size] as? UInt64 ?? 0
                XCTAssertGreaterThan(fileSize, 0, "Exported file should not be empty")
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Export failed: \(error.localizedDescription)")
            }
        }
        
        wait(for: [expectation], timeout: 30.0)
    }
    
    func testImageSequenceExport() async throws {
        guard let videoExporter = VideoExporter(url: realVideoFileURL) else {
            XCTFail("Could not create exporter")
            return
        }
        
        let outputURL = tempDirectoryURL.appendingPathComponent("image_sequence")
        try? FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
        
        let config = VideoExporter.ExportConfiguration(
            format: .imageSequence(.png),
            width: 1280,
            height: 720,
            frameRate: 30.0,
            outputURL: outputURL,
            baseFilename: "frame"
        )
        
        let expectation = XCTestExpectation(description: "Image sequence export")
        
        await videoExporter.export(with: config) { result in
            switch result {
            case .success(let url):
                XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
                
                // Check that at least some image files were created
                let contents = try? FileManager.default.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: nil
                )
                XCTAssertNotNil(contents)
                XCTAssertGreaterThan(contents?.count ?? 0, 0, "No images were exported")
                
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Export failed: \(error.localizedDescription)")
            }
        }
        
        wait(for: [expectation], timeout: 60.0)
    }
    */
} 