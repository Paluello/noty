import NotyCanvas
import SwiftUI

/// Screen 6: app-wide preferences.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.appearance) private var appearance = Appearance.system
    @AppStorage(SettingsKey.fingerDrawing) private var fingerDrawing = false
    @AppStorage(SettingsKey.autoNewPage) private var autoNewPage = true
    @AppStorage(SettingsKey.defaultEraser) private var defaultEraser = EraserMode.partial.rawValue
    @AppStorage(SettingsKey.toolbarPosition) private var toolbarPosition = ToolbarPosition.top
    @AppStorage(SettingsKey.pencilTapAction) private var pencilTap = PencilAction.system.rawValue
    @AppStorage(SettingsKey.pencilSqueezeAction) private var pencilSqueeze = PencilAction.system.rawValue
    @Environment(LibraryStore.self) private var store
    @State private var isExporting = false
    @State private var exportedArchive: SharedFile?

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
                    Picker("Double Tap", selection: $pencilTap) {
                        ForEach(PencilAction.allCases) { action in
                            Text(action.title).tag(action.rawValue)
                        }
                    }
                    Picker("Squeeze", selection: $pencilSqueeze) {
                        ForEach(PencilAction.allCases) { action in
                            Text(action.title).tag(action.rawValue)
                        }
                    }
                } header: {
                    Text(verbatim: "Apple Pencil")
                } footer: {
                    Text("Squeeze works with Apple Pencil Pro.")
                }

                Section("Toolbar") {
                    Picker("Position", selection: $toolbarPosition) {
                        ForEach(ToolbarPosition.allCases) { option in
                            Label(option.title, systemImage: option.symbolName).tag(option)
                        }
                    }
                }

                Section {
                    Button {
                        Task { await exportAll() }
                    } label: {
                        HStack {
                            Label("Export All", systemImage: "archivebox")
                            Spacer()
                            if isExporting {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isExporting)
                } header: {
                    Text("Storage")
                } footer: {
                    Text("Creates a zip with all your folders, every notebook and a PDF of each. Save it to Files, a NAS or another cloud as a backup.")
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
            .sheet(item: $exportedArchive) { file in
                ShareSheet(url: file.url)
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

    private func exportAll() async {
        isExporting = true
        defer { isExporting = false }
        if let url = await store.exportAll() {
            exportedArchive = SharedFile(url: url)
        }
    }
}
