import SwiftUI
import AppKit

enum PreferencesTab: String, CaseIterable, Identifiable {
    case appearance = "Appearance"
    case export = "Export"
    case general = "General"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .appearance:
            return "paintbrush"
        case .export:
            return "square.and.arrow.up"
        case .general:
            return "gearshape"
        }
    }
}

struct PreferencesView: View {
    @StateObject private var viewModel = PreferencesViewModel()
    @State private var selectedTab: PreferencesTab = .appearance
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedTab) {
            ScrollView {
                AppearancePreferencesView(viewModel: viewModel)
                    .padding(20)
            }
            .tabItem {
                Label(PreferencesTab.appearance.rawValue, systemImage: PreferencesTab.appearance.icon)
            }
            .tag(PreferencesTab.appearance)
            
            ScrollView {
                ExportPreferencesView(viewModel: viewModel)
                    .padding(20)
            }
            .tabItem {
                Label(PreferencesTab.export.rawValue, systemImage: PreferencesTab.export.icon)
            }
            .tag(PreferencesTab.export)
            
            ScrollView {
                GeneralPreferencesView(viewModel: viewModel)
                    .padding(20)
            }
            .tabItem {
                Label(PreferencesTab.general.rawValue, systemImage: PreferencesTab.general.icon)
            }
            .tag(PreferencesTab.general)
            }
            .frame(width: 600, height: 450) // Keep frame on TabView or adjust for VStack

            Divider()

            HStack {
                Spacer()
                Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.defaultAction) // Allows Enter key to trigger it
            }
            .padding()
        }
    }
}

// MARK: - Appearance Preferences
struct AppearancePreferencesView: View {
    @ObservedObject var viewModel: PreferencesViewModel
    @EnvironmentObject private var appState: AppStateManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Appearance")
                .font(.title)
                .fontWeight(.semibold)
            
            GroupBox(label: Text("Theme")) {
                VStack(alignment: .leading, spacing: 15) {
                    Picker("Application Theme", selection: $viewModel.appearance) {
                        Text("System").tag(AppAppearance.system)
                        Text("Light").tag(AppAppearance.light)
                        Text("Dark").tag(AppAppearance.dark)
                    }
                    .pickerStyle(.inline)
                    .padding(.vertical, 5)
                    .onChange(of: viewModel.appearance) { oldValue, newValue in
                        appState.setAppearance(newValue)
                    }
                    
                    Divider()
                    
                    Toggle("Use accent color for UI elements", isOn: $viewModel.useAccentColor)
                        .padding(.vertical, 5)
                    
                    ColorPicker("Accent Color", selection: $viewModel.accentColor)
                        .disabled(!viewModel.useAccentColor)
                        .padding(.vertical, 5)
                }
                .padding()
            }
            
            GroupBox(label: Text("Canvas")) {
                VStack(alignment: .leading, spacing: 15) {
                    Toggle("Show grid by default", isOn: $viewModel.showGrid)
                        .padding(.vertical, 5)
                    
                    HStack {
                        Text("Grid size:")
                        Slider(value: $viewModel.gridSize, in: 8...64, step: 8)
                        Text("\(Int(viewModel.gridSize))")
                            .frame(width: 30)
                    }
                    .disabled(!viewModel.showGrid)
                    .padding(.vertical, 5)
                    
                    ColorPicker("Grid Color", selection: $viewModel.gridColor)
                        .disabled(!viewModel.showGrid)
                        .padding(.vertical, 5)
                    
                    Divider()
                    
                    ColorPicker("Canvas Background", selection: $viewModel.canvasBackgroundColor)
                        .padding(.vertical, 5)
                }
                .padding()
            }
            
            Spacer()
        }
    }
}

// MARK: - Export Preferences
struct ExportPreferencesView: View {
    @ObservedObject var viewModel: PreferencesViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Export")
                .font(.title)
                .fontWeight(.semibold)
            
            GroupBox(label: Text("Video Export Defaults")) {
                VStack(alignment: .leading, spacing: 15) {
                    Picker("Default Format", selection: $viewModel.defaultVideoFormat) {
                        Text("MP4 (H.264)").tag(VideoFormat.mp4)
                        Text("ProRes 422").tag(VideoFormat.proRes422)
                        Text("ProRes 422 HQ").tag(VideoFormat.proRes422HQ)
                        Text("ProRes 4444").tag(VideoFormat.proRes4444)
                    }
                    .pickerStyle(.inline)
                    .padding(.vertical, 5)
                    
                    HStack {
                        Text("Default Frame Rate:")
                        Picker("", selection: $viewModel.defaultFrameRate) {
                            Text("24 fps").tag(24)
                            Text("30 fps").tag(30)
                            Text("60 fps").tag(60)
                        }
                        .frame(width: 100)
                    }
                    .padding(.vertical, 5)
                    
                    Toggle("Include alpha channel (when supported)", isOn: $viewModel.includeAlphaChannel)
                        .padding(.vertical, 5)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Default Export Location")
                            .font(.headline)
                        
                        HStack {
                            TextField("", text: $viewModel.exportLocation)
                                .disabled(true)
                            
                            Button("Browse...") {
                                viewModel.selectExportLocation()
                            }
                        }
                    }
                    .padding(.vertical, 5)
                }
                .padding()
            }
            
            GroupBox(label: Text("Image Export Defaults")) {
                VStack(alignment: .leading, spacing: 15) {
                    Picker("Default Format", selection: $viewModel.defaultImageFormat) {
                        Text("PNG").tag(PreferenceImageFormat.png)
                        Text("JPEG").tag(PreferenceImageFormat.jpeg)
                        Text("TIFF").tag(PreferenceImageFormat.tiff)
                    }
                    .pickerStyle(.inline)
                    .padding(.vertical, 5)
                    
                    HStack {
                        Text("JPEG Quality:")
                        Slider(value: $viewModel.jpegQuality, in: 0...1)
                        Text("\(Int(viewModel.jpegQuality * 100))%")
                            .frame(width: 50)
                    }
                    .disabled(viewModel.defaultImageFormat != .jpeg)
                    .padding(.vertical, 5)
                }
                .padding()
            }
            
            Spacer()
        }
    }
}

// MARK: - General Preferences
struct GeneralPreferencesView: View {
    @ObservedObject var viewModel: PreferencesViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("General")
                .font(.title)
                .fontWeight(.semibold)
            
            GroupBox(label: Text("Application")) {
                VStack(alignment: .leading, spacing: 15) {
                    Toggle("Restore previous session on startup", isOn: $viewModel.restorePreviousSession)
                        .padding(.vertical, 5)
                    
                    Toggle("Auto-save projects", isOn: $viewModel.autoSaveProjects)
                        .padding(.vertical, 5)
                    
                    HStack {
                        Text("Auto-save interval:")
                        Picker("", selection: $viewModel.autoSaveInterval) {
                            Text("1 minute").tag(1)
                            Text("5 minutes").tag(5)
                            Text("10 minutes").tag(10)
                            Text("15 minutes").tag(15)
                            Text("30 minutes").tag(30)
                        }
                        .frame(width: 150)
                    }
                    .disabled(!viewModel.autoSaveProjects)
                    .padding(.vertical, 5)
                    
                    Divider()
                    
                    Toggle("Check for updates automatically", isOn: $viewModel.checkForUpdates)
                        .padding(.vertical, 5)
                }
                .padding()
            }
            
            GroupBox(label: Text("Performance")) {
                VStack(alignment: .leading, spacing: 15) {
                    Toggle("Enable hardware acceleration", isOn: $viewModel.enableHardwareAcceleration)
                        .padding(.vertical, 5)
                    
                    HStack {
                        Text("Timeline Cache Size:")
                        Slider(value: $viewModel.timelineCacheSize, in: 100...2000, step: 100)
                        Text("\(Int(viewModel.timelineCacheSize)) MB")
                            .frame(width: 80)
                    }
                    .padding(.vertical, 5)
                    
                    Button("Clear Cache") {
                        viewModel.clearCache()
                    }
                    .padding(.vertical, 5)
                }
                .padding()
            }
            
            Spacer()
        }
    }
}

#Preview {
    PreferencesView()
        .environmentObject(AppStateManager())
} 