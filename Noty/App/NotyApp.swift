import NotyCore
import SwiftUI

@main
struct NotyApp: App {
    @State private var store = LibraryStore()
    @State private var palettes = PaletteStore()
    @AppStorage(SettingsKey.appearance) private var appearance = Appearance.system

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environment(store)
                .environment(palettes)
                .preferredColorScheme(appearance.colorScheme)
        }

        // A notebook in its own window, for Split View and Stage Manager (UI-4).
        WindowGroup(for: URL.self) { $url in
            if let url {
                NotebookWindow(url: url)
                    .environment(store)
                    .environment(palettes)
                    .preferredColorScheme(appearance.colorScheme)
            }
        }
    }
}

/// The editor in a separate window; closing it closes the window.
struct NotebookWindow: View {
    let url: URL
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(LibraryStore.self) private var store

    var body: some View {
        EditorView(package: NotebookPackage(url: url), onClose: {
            store.notebookDidChange()
            dismissWindow()
        })
    }
}
