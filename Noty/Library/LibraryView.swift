import NotyCore
import SwiftUI

enum SidebarSelection: Hashable {
    case folder(URL)
    case trash
}

/// Home screen: folder tree on the side, folder contents as a grid (screen 1).
struct LibraryView: View {
    @Environment(LibraryStore.self) private var store
    /// The folder (or the Trash) chosen in the sidebar: the root of the detail column.
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
            switch selection ?? .folder(store.root) {
            case .trash:
                NavigationStack {
                    TrashView()
                }
            case .folder(let folder):
                // A new stack per sidebar folder: the split view resets the detail
                // stack whenever the sidebar selection changes.
                NavigationStack(path: $path) {
                    FolderGridView(folder: folder, path: $path)
                        .navigationDestination(for: URL.self) { subfolder in
                            FolderGridView(folder: subfolder, path: $path)
                        }
                }
                .id(folder)
            }
        }
        .onChange(of: selection) { path = [] }
        .environment(\.openNotebook) { url in openNotebook = SharedFile(url: url) }
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
