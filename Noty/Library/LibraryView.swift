import NotyCore
import SwiftUI

/// The sections of the home screen: tabs at the top, or a sidebar (UI-1, UI-4).
enum LibraryTab: Hashable {
    case library
    case favorites
    case recents
    case folder(URL)
    case trash
    case search
}

/// Home screen. Like Apple Music on iPadOS 26: a Liquid Glass tab bar at the
/// top that turns into a sidebar (with folders and Trash) and back.
struct LibraryView: View {
    @Environment(LibraryStore.self) private var store
    @Environment(\.openWindow) private var openWindow
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab = LibraryTab.library
    /// Subfolders opened from the grid, below the selected tab.
    @State private var path: [URL] = []
    @State private var openNotebook: SharedFile?
    @State private var isShowingSettings = false

    var body: some View {
        @Bindable var store = store
        let folders = store.folderTree().children
        TabView(selection: $tab) {
            Tab("Library", systemImage: "books.vertical", value: LibraryTab.library) {
                grid(.folder(store.root))
            }
            Tab("Favorites", systemImage: "star", value: LibraryTab.favorites) {
                grid(.favorites)
            }
            Tab("Recents", systemImage: "clock", value: LibraryTab.recents) {
                grid(.recents)
            }

            // Folders and Trash live in the sidebar; the tab bar stays short.
            TabSection("Folders") {
                ForEach(folders) { folder in
                    Tab(folder.name, systemImage: "folder", value: LibraryTab.folder(folder.url)) {
                        grid(.folder(folder.url))
                    }
                }
            }
            .defaultVisibility(.hidden, for: .tabBar)

            Tab("Trash", systemImage: "trash", value: LibraryTab.trash) {
                NavigationStack {
                    TrashView()
                }
            }
            .defaultVisibility(.hidden, for: .tabBar)

            Tab(value: LibraryTab.search, role: .search) {
                grid(.search)
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabViewSidebarHeader {
            Text(verbatim: "Noty")
                .font(.largeTitle.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .tabViewSidebarBottomBar {
            Button("Settings", systemImage: "gearshape") {
                isShowingSettings = true
            }
            .buttonStyle(.glass)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onChange(of: tab) { path = [] }
        .environment(\.showSettings) { isShowingSettings = true }
        .environment(\.openNotebook) { url in open(url, inNewWindow: false) }
        .environment(\.openNotebookAtPage) { url, page in open(url, inNewWindow: false, page: page) }
        .environment(\.openNotebookInNewWindow) { url in open(url, inNewWindow: true) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.refresh()
            }
        }
        .task {
            await store.indexHandwritingInBackground()
        }
        .fullScreenCover(item: $openNotebook, onDismiss: store.notebookDidChange) { notebook in
            EditorView(package: NotebookPackage(url: notebook.url), initialPage: notebook.page)
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
        }
        .alert("Something went wrong", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    /// One navigation stack per tab: subfolders open inside it.
    private func grid(_ source: GridSource) -> some View {
        NavigationStack(path: $path) {
            FolderGridView(source: source, path: $path)
                .navigationDestination(for: URL.self) { subfolder in
                    FolderGridView(source: .folder(subfolder), path: $path)
                }
        }
        .id(source)
    }

    /// Opens a notebook here, or in its own window. If it is already open
    /// somewhere, brings that window forward instead.
    private func open(_ url: URL, inNewWindow: Bool, page: Int? = nil) {
        Task {
            // In iCloud Drive or on a NAS the files may still be downloading (ADR-0018).
            let package = NotebookPackage(url: url)
            do {
                try await Task.detached { try package.prepareForReading() }.value
            } catch {
                store.errorMessage = error.localizedDescription
                return
            }
            store.markOpened(url)
            if inNewWindow || store.openNotebooks.contains(Library.normalized(url)) {
                openWindow(value: url)
            } else {
                openNotebook = SharedFile(url: url, page: page)
            }
        }
    }
}
