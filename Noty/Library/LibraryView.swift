import NotyCore
import SwiftUI

enum SidebarSelection: Hashable {
    case folder(URL)
    case favorites
    case recents
    case trash
}

/// Home screen: folder tree on the side, folder contents as a grid (screen 1).
struct LibraryView: View {
    @Environment(LibraryStore.self) private var store
    @Environment(\.openWindow) private var openWindow
    @Environment(\.scenePhase) private var scenePhase
    /// The folder or list chosen in the sidebar: the root of the detail column.
    @State private var selection: SidebarSelection?
    /// Subfolders opened from the grid, below the selected folder.
    @State private var path: [URL] = []
    @State private var openNotebook: SharedFile?
    @State private var isShowingSettings = false

    var body: some View {
        @Bindable var store = store
        NavigationSplitView {
            sidebar
        } detail: {
            detail(for: selection ?? .folder(store.root))
        }
        .onChange(of: selection) { path = [] }
        .environment(\.openNotebook) { url in open(url, inNewWindow: false) }
        .environment(\.openNotebookInNewWindow) { url in open(url, inNewWindow: true) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.refresh()
            }
        }
        .fullScreenCover(item: $openNotebook, onDismiss: store.notebookDidChange) { notebook in
            EditorView(package: NotebookPackage(url: notebook.url))
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

    @ViewBuilder
    private func detail(for selection: SidebarSelection) -> some View {
        switch selection {
        case .trash:
            NavigationStack {
                TrashView()
            }
        case .folder(let folder):
            grid(.folder(folder))
        case .favorites:
            grid(.favorites)
        case .recents:
            grid(.recents)
        }
    }

    /// A new stack per sidebar item: the split view resets the detail stack
    /// whenever the sidebar selection changes.
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
    private func open(_ url: URL, inNewWindow: Bool) {
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
                openNotebook = SharedFile(url: url)
            }
        }
    }

    private var sidebar: some View {
        let tree = store.folderTree()
        return List(selection: $selection) {
            Section {
                Label("Library", systemImage: "books.vertical")
                    .dropDestination(for: URL.self) { urls, _ in
                        urls.forEach { store.move(url: $0, to: store.root) }
                        return true
                    }
                    .tag(SidebarSelection.folder(store.root))
                Label("Favorites", systemImage: "star")
                    .tag(SidebarSelection.favorites)
                Label("Recents", systemImage: "clock")
                    .tag(SidebarSelection.recents)
            }
            if let folders = tree.childrenOrNil {
                Section("Folders") {
                    OutlineGroup(folders, children: \.childrenOrNil) { node in
                        Label(node.name, systemImage: "folder")
                            .dropDestination(for: URL.self) { urls, _ in
                                urls.forEach { store.move(url: $0, to: node.url) }
                                return true
                            }
                            .tag(SidebarSelection.folder(node.url))
                    }
                }
            }
            Section {
                Label("Trash", systemImage: "trash")
                    .tag(SidebarSelection.trash)
            }
        }
        .navigationTitle("Noty")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Settings", systemImage: "gearshape") {
                    isShowingSettings = true
                }
            }
        }
    }
}
