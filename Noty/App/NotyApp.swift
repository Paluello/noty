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
    }
}
