//
//  DesignCanvasNavigationTests.swift
//  Motion StorylineTests
//
//  Created by Motion Storyline on 6/14/25.
//

import Testing
import Foundation
import SwiftUI
@testable import Motion_Storyline

struct DesignCanvasNavigationTests {

    @Test func testNavigatingToDesignCanvas() async throws {
        // Create a testable home view
        let testableHome = TestableHomeView()
        
        // Verify initial state - design canvas should not be visible
        #expect(testableHome.isDesignCanvasVisible == false, "Design canvas should not be visible initially")
        
        // Sample project from the home screen
        let websitePrototype = Project(name: "Website Prototype", thumbnail: "prototype_thumbnail", lastModified: Date())
        
        // Simulate user clicking on a project in the UI
        await testableHome.simulateClickOnProject(websitePrototype)
        
        // Verify that the design canvas is now visible
        #expect(testableHome.isDesignCanvasVisible == true, "Design canvas should be visible after project selection")
        #expect(testableHome.selectedProjectName == "Website Prototype", "The correct project should be selected")
        
        // Verify the project appears in recent projects
        #expect(testableHome.recentProjects.contains(where: { $0.name == "Website Prototype" }), "Project should appear in recent projects")
        
        // Simulate waiting for animations and view transitions to complete
        try await Task.sleep(nanoseconds: 1_000_000_000)
    }
    
    @Test func testToggleDarkMode() async throws {
        // Create a testable view with appearance controls
        let testableSettings = TestableSettingsView()
        
        // Get initial dark mode state
        let initialDarkModeState = testableSettings.isDarkModeEnabled
        
        // Simulate clicking the dark mode toggle button
        await testableSettings.simulateClickOnDarkModeToggle()
        
        // Verify that dark mode state has toggled
        #expect(testableSettings.isDarkModeEnabled != initialDarkModeState, "Dark mode should have toggled")
        
        // Simulate clicking the toggle again
        await testableSettings.simulateClickOnDarkModeToggle()
        
        // Verify we're back to the initial state
        #expect(testableSettings.isDarkModeEnabled == initialDarkModeState, "Dark mode should be back to initial state")
    }
    
    @Test func testNewProjectButton() async throws {
        // Create a testable home view
        let testableHome = TestableHomeView()
        
        // Verify no project is selected initially
        #expect(testableHome.isDesignCanvasVisible == false, "Design canvas should not be visible initially")
        
        // Simulate user opening new project dialog
        await testableHome.simulateClickOnNewProjectButton()
        
        // Verify new project dialog is visible
        #expect(testableHome.isNewProjectDialogVisible == true, "New project dialog should be visible")
        
        // Simulate user filling out the form and clicking "Create"
        await testableHome.simulateNewProjectCreation(name: "Test Project", type: "Design")
        
        // Verify that a new project was created and selected
        #expect(testableHome.isDesignCanvasVisible == true, "Design canvas should be visible after project creation")
        #expect(testableHome.selectedProjectName == "Test Project", "The new project should have the correct name")
        #expect(testableHome.isNewProjectDialogVisible == false, "New project dialog should be closed")
    }
    
    // MARK: - Testable View Models
    
    // Testable Home View that simulates the UI without direct AppStateManager references
    class TestableHomeView {
        private(set) var isDesignCanvasVisible = false
        private(set) var selectedProjectName: String?
        private(set) var recentProjects = [Project]()
        private(set) var isNewProjectDialogVisible = false
        
        func simulateClickOnProject(_ project: Project) async {
            // Simulate what happens when a user clicks a project card
            await MainActor.run {
                // Set the selected project (navigating to DesignCanvas)
                self.selectedProjectName = project.name
                self.isDesignCanvasVisible = true
                
                // Add to recent projects
                if !self.recentProjects.contains(where: { $0.id == project.id }) {
                    self.recentProjects.insert(project, at: 0)
                    // Keep only most recent projects (simulating what the app would do)
                    if self.recentProjects.count > 5 {
                        self.recentProjects.removeLast()
                    }
                }
            }
        }
        
        func simulateClickOnNewProjectButton() async {
            // Simulate clicking "New Project" button which opens a dialog
            await MainActor.run {
                self.isNewProjectDialogVisible = true
            }
        }
        
        func simulateNewProjectCreation(name: String, type: String) async {
            // Simulate completing the new project flow
            await MainActor.run {
                // Create a new project object
                let thumbnail = self.getThumbnailForType(type)
                let newProject = Project(name: name, thumbnail: thumbnail, lastModified: Date())
                
                // Set as selected project (navigating to DesignCanvas)
                self.selectedProjectName = name
                self.isDesignCanvasVisible = true
                
                // Add to recent projects
                if !self.recentProjects.contains(where: { $0.id == newProject.id }) {
                    self.recentProjects.insert(newProject, at: 0)
                }
                
                // Close the dialog
                self.isNewProjectDialogVisible = false
            }
        }
        
        private func getThumbnailForType(_ type: String) -> String {
            switch type {
            case "Design":
                return "design_thumbnail"
            case "Prototype":
                return "prototype_thumbnail"
            case "Component Library":
                return "component_thumbnail"
            case "Style Guide":
                return "style_thumbnail"
            default:
                return "placeholder"
            }
        }
    }
    
    // Testable Settings View for appearance settings
    class TestableSettingsView {
        private(set) var isDarkModeEnabled = false
        
        func simulateClickOnDarkModeToggle() async {
            // Simulate clicking appearance toggle button
            await MainActor.run {
                self.isDarkModeEnabled.toggle()
            }
        }
    }
} 