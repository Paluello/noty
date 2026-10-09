import NotyCanvas
import NotyCore
import SwiftUI

/// The contents of one folder: subfolders first, then notebooks (ORG-3).
struct FolderGridView: View {
    let folder: URL
    @Binding var path: [URL]

    @Environment(LibraryStore.self) private var store
    @Environment(\.openNotebook) private var openNotebook
    @AppStorage(SettingsKey.sortOrder) private var sortOrder = SortOrder.modified

    @State private var isCreatingNotebook = false
    @State private var isCreatingFolder = false
    @State private var newFolderName = ""
    @State private var renaming: LibraryEntry?
    @State private var newName = ""
    @State private var moving: LibraryEntry?
    @State private var changingCover: LibraryEntry?
    @State private var sharedPDF: SharedFile?

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 32, alignment: .top)]

    var body: some View {
        let items = store.items(in: folder, sortedBy: sortOrder)
        ScrollView {
            LazyVGrid(columns: columns, spacing: 36) {
                ForEach(items) { item in
                    tile(for: item)
                        .contextMenu { menu(for: item) }
                }
            }
            .padding(32)
        }
        .background { AmbientBackground() }
        .overlay {
            if items.isEmpty {
                emptyState
            }
        }
        .navigationTitle(store.displayName(of: folder))
        .toolbar { toolbar }
        .sheet(isPresented: $isCreatingNotebook) {
            NewNotebookSheet(folder: folder) { package in
                openNotebook(package.url)
            }
        }
        .sheet(item: $moving) { item in
            MoveSheet(item: item)
        }
        .sheet(item: $changingCover) { item in
            if case .notebook(let url, let manifest) = item {
                CoverSheet(notebookURL: url, manifest: manifest)
            }
        }
        .sheet(item: $sharedPDF) { file in
            ShareSheet(url: file.url)
        }
        .alert("New Folder", isPresented: $isCreatingFolder) {
            TextField("Name", text: $newFolderName)
            Button("Cancel", role: .cancel) {}
            Button("Create") {
                store.createFolder(named: newFolderName, in: folder)
            }
        }
        .alert("Rename", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $newName)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                if let renaming {
                    store.rename(renaming, to: newName)
                }
            }
        }
    }

    // MARK: - Tiles

    @ViewBuilder
    private func tile(for item: LibraryEntry) -> some View {
        switch item {
        case .folder(let url):
            NavigationLink(value: url) {
                FolderTile(name: url.lastPathComponent, count: store.itemCount(in: url))
            }
            .buttonStyle(.plain)
            .draggable(url)
            .dropDestination(for: URL.self) { urls, _ in
                for dropped in urls where dropped.standardizedFileURL != url.standardizedFileURL {
                    store.move(url: dropped, to: url)
                }
                return true
            }

        case .notebook(let url, let manifest):
            Button {
                openNotebook(url)
            } label: {
                NotebookTile(url: url, manifest: manifest)
            }
            .buttonStyle(.plain)
            .draggable(url) {
                CoverView(cover: .existing(manifest.cover), notebookURL: url, title: manifest.title)
                    .frame(width: 120)
            }
        }
    }

    @ViewBuilder
    private func menu(for item: LibraryEntry) -> some View {
        Button("Rename", systemImage: "pencil") {
            newName = item.name
            renaming = item
        }
        if case .notebook = item {
            Button("Cover", systemImage: "paintpalette") {
                changingCover = item
            }
        }
        Button("Move", systemImage: "folder") {
            moving = item
        }
        Button("Duplicate", systemImage: "plus.square.on.square") {
            store.duplicate(item)
        }
        if case .notebook(let url, _) = item {
            Button("Export PDF", systemImage: "square.and.arrow.up") {
                exportPDF(of: url)
            }
        }
        Divider()
        Button("Delete", systemImage: "trash", role: .destructive) {
            store.moveToTrash(item)
        }
    }

    // MARK: - Chrome

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Picker("Sort By", selection: $sortOrder) {
                    ForEach(SortOrder.allCases) { order in
                        Text(order.title).tag(order)
                    }
                }
            } label: {
                Label("Sort By", systemImage: "arrow.up.arrow.down")
            }
        }
        ToolbarSpacer(.fixed, placement: .primaryAction)
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button("New Notebook", systemImage: "book.closed") {
                    isCreatingNotebook = true
                }
                Button("New Folder", systemImage: "folder.badge.plus") {
                    newFolderName = ""
                    isCreatingFolder = true
                }
            } label: {
                Label("New", systemImage: "plus")
            }
            .buttonStyle(.glassProminent)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Notebooks", systemImage: "book.closed")
        } description: {
            Text("Create a notebook to start writing.")
        } actions: {
            Button("New Notebook") {
                isCreatingNotebook = true
            }
            .buttonStyle(.glassProminent)
        }
    }

    private func exportPDF(of url: URL) {
        do {
            sharedPDF = SharedFile(url: try PageRenderer.exportPDFForSharing(of: NotebookPackage(url: url)))
        } catch {
            store.errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Tiles

struct NotebookTile: View {
    let url: URL
    let manifest: NotebookManifest

    var body: some View {
        VStack(spacing: 10) {
            CoverView(cover: .existing(manifest.cover), notebookURL: url, title: manifest.title)
            VStack(spacing: 2) {
                Text("\(manifest.pageIDs.count) pages")
                Text(manifest.modifiedAt, format: .relative(presentation: .named))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .contentShape(.rect)
    }
}

struct FolderTile: View {
    let name: String
    let count: Int

    var body: some View {
        VStack(spacing: 10) {
            // A clear A4-shaped box sets the size, so folders line up with notebook covers.
            Color.clear
                .aspectRatio(PageGeometry.a4Width / PageGeometry.a4Height, contentMode: .fit)
                .overlay {
                    VStack(spacing: 14) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.tint)
                            .symbolRenderingMode(.hierarchical)
                        Text(name)
                            .font(.headline)
                            .lineLimit(3)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 14)
                    }
                }
                .glassEffect(.regular.tint(Color.accentColor.opacity(0.1)), in: .rect(cornerRadius: 22))

            Text("\(count) items")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .contentShape(.rect)
    }
}
