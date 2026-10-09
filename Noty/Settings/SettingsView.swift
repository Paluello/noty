import NotyCanvas
import SwiftUI

/// Screen 6: app-wide preferences.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.appearance) private var appearance = Appearance.system
    @AppStorage(SettingsKey.fingerDrawing) private var fingerDrawing = false
    @AppStorage(SettingsKey.autoNewPage) private var autoNewPage = true
    @AppStorage(SettingsKey.defaultEraser) private var defaultEraser = EraserMode.partial.rawValue

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $appearance) {
                        ForEach(Appearance.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text("Pages always stay light, like paper.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Toggle("Draw with Fingers", isOn: $fingerDrawing)
                    Toggle("Add Pages Automatically", isOn: $autoNewPage)
                    Picker("Eraser", selection: $defaultEraser) {
                        Text("Partial").tag(EraserMode.partial.rawValue)
                        Text("Whole Stroke").tag(EraserMode.stroke.rawValue)
                    }
                } header: {
                    Text("Writing")
                } footer: {
                    Text("With finger drawing off, only Apple Pencil writes and fingers scroll and zoom. Writing near the bottom of the last page adds a new one.")
                }

                Section {
                    NavigationLink {
                        PaletteListView()
                    } label: {
                        Label("Palettes", systemImage: "paintpalette")
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–")
                    LabeledContent("License", value: "GPL-3.0")
                    Text("Noty is free and open source. No accounts, no ads, no tracking.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark", role: .confirm) { dismiss() }
                }
            }
        }
    }
}
