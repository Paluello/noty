import NotyCanvas
import SwiftUI

/// Screen 6: app-wide preferences.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.appearance) private var appearance = Appearance.system
    @AppStorage(SettingsKey.fingerDrawing) private var fingerDrawing = false
    @AppStorage(SettingsKey.autoNewPage) private var autoNewPage = true
    @AppStorage(SettingsKey.defaultEraser) private var defaultEraser = EraserMode.partial.rawValue
    @AppStorage(SettingsKey.pencilTapAction) private var pencilTap = PencilAction.system.rawValue
    @AppStorage(SettingsKey.pencilSqueezeAction) private var pencilSqueeze = PencilAction.system.rawValue
    @Environment(LibraryStore.self) private var store
    @AppStorage(SettingsKey.shapeRecognition) private var shapeRecognition = true
    @AppStorage(SettingsKey.appLock) private var appLock = false
    @State private var isChoosingFolder = false
    @State private var chosenFolder: URL?
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
                    Toggle("Recognize Shapes", isOn: $shapeRecognition)
                    Picker("Eraser", selection: $defaultEraser) {
                        Text("Partial").tag(EraserMode.partial.rawValue)
                        Text("Whole Stroke").tag(EraserMode.stroke.rawValue)
                    }
                } header: {
                    Text("Writing")
                } footer: {
                    Text("With finger drawing off, only Apple Pencil writes and fingers scroll and zoom. Writing near the bottom of the last page adds a new one. To draw a perfect line, circle or rectangle, hold the Pencil still at the end of the stroke.")
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

                Section {
                    LabeledContent("Library Location", value: store.locationName)
                    Button("Choose a Folder…", systemImage: "folder.badge.gearshape") {
                        isChoosingFolder = true
                    }
                    if store.usesChosenFolder {
                        Button("Use This iPad's Storage", systemImage: "ipad") {
                            store.useDeviceStorage()
                        }
                    }
                } header: {
                    Text("Sync")
                } footer: {
                    Text("Keep your notebooks in a folder of iCloud Drive, a NAS or another cloud to have them on every device. Noty asks whether to copy the current notebooks there.")
                }

                Section {
                    Toggle("Lock Noty with Face ID", isOn: Binding(get: { appLock }, set: { newValue in
                        Task {
                            // Turning it off needs the owner too.
                            if await Biometrics.authenticate(reason: String(localized: "Change the lock setting")) {
                                appLock = newValue
                            }
                        }
                    }))
                } header: {
                    Text("Privacy")
                } footer: {
                    if Biometrics.isAvailable {
                        Text("Single notebooks can be locked from their menu. Locking hides notebooks inside Noty; the files stay readable from the Files app.")
                    } else {
                        Text("Set a passcode in the iPad's Settings to use the lock.")
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

                Section("App Icon") {
                    AppIconPicker()
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

                #if ALTSTORE
                // Only in the AltStore build: App Store rules don't allow
                // donations outside in-app purchase.
                Section {
                    Link(destination: URL(string: "https://noty.paluello.me/#sostieni")!) {
                        Label("Support Noty", systemImage: "heart")
                    }
                } footer: {
                    Text("Donations cover the cost of bringing Noty to the App Store.")
                }
                #endif
            }
            .sheet(item: $exportedArchive) { file in
                ShareSheet(url: file.url)
            }
            .fileImporter(isPresented: $isChoosingFolder, allowedContentTypes: [.folder]) { result in
                if case .success(let url) = result {
                    chosenFolder = url
                }
            }
            .confirmationDialog(
                "Copy your notebooks to the new folder?",
                isPresented: Binding(get: { chosenFolder != nil }, set: { if !$0 { chosenFolder = nil } }),
                titleVisibility: .visible
            ) {
                Button("Copy Notebooks") {
                    if let chosenFolder { store.useFolder(chosenFolder, copyingCurrentLibrary: true) }
                }
                Button("Don't Copy") {
                    if let chosenFolder { store.useFolder(chosenFolder, copyingCurrentLibrary: false) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The notebooks on this iPad stay where they are.")
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
