import NotyCanvas
import NotyCore
import SwiftUI

/// What a grid shows: a folder, or one of the smart lists in the sidebar (ORG-5).
enum GridSource: Hashable {
    case folder(URL)
    case favorites
    case recents
}

/// A grid of folders and notebooks (ORG-3), with search across the whole library (ORG-7).
struct FolderGridView: View {
    let source: GridSource
    @Binding var path: [URL]

    @Environment(LibraryStore.self) private var store
    @Environment(\.openNotebook) private var openNotebook
    @Environment(\.openWindow) private var openWindow
    @AppStorage(SettingsKey.sortOrder) private var sortOrder = SortOrder.modified

    @State private var query = ""
    @State private var isCreatingNotebook = false
    @State private var isCreatingFolder = false
    @State private var newFolderName = ""
    @State private var renaming: LibraryEntry?
    @State private var newName = ""
    @State private var moving: LibraryEntry?
    @State private var changingCover: LibraryEntry?
    @State private var sharedPDF: SharedFile?

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 32, alignment: .top)]

    private var isSearching: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }

    private var folder: URL? {
        if case .folder(let url) = source { url } else { nil }
    }

    private var items: [LibraryEntry] {
        if isSearching {
            return store.search(query, sortedBy: sortOrder)
        }
        switch source {
        case .folder(let url): return store.items(in: url, sortedBy: sortOrder)
        case .favorites: return store.favorites(sortedBy: sortOrder)
        case .recents: return store.recents()
        }
    }

    /// Outside a folder, tiles say where each item lives.
    private var showsLocation: Bool { isSearching || folder == nil }

    var body: some View {
        let items = items
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
        .navigationTitle(title)
        .searchable(text: $query, prompt: Text("Search notebooks and folders"))
        .toolbar { toolbar }
        .sheet(isPresented: $isCreatingNotebook) {
            NewNotebookSheet(folder: folder ?? store.root) { package in
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
                store.createFolder(named: newFolderName, in: folder ?? store.root)
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

    private var title: String {
        switch source {
        case .folder(let url): store.displayName(of: url)
        case .favorites: String(localized: "Favorites")
        case .recents: String(localized: "Recents")
        }
    }

    // MARK: - Tiles

    @ViewBuilder
    private func tile(for item: LibraryEntry) -> some View {
        let location = showsLocation ? store.location(of: item) : nil
        switch item {
        case .folder(let url):
            NavigationLink(value: url) {
                FolderTile(name: url.lastPathComponent, count: store.itemCount(in: url), location: location)
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
                NotebookTile(url: url, manifest: manifest, isFavorite: store.isFavorite(item), location: location)
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
        if case .notebook(let url, _) = item {
            Button("Open in New Window", systemImage: "macwindow.badge.plus") {
                store.markOpened(url)
                openWindow(value: url)
            }
            if store.isFavorite(item) {
                Button("Remove from Favorites", systemImage: "star.slash") {
                    store.toggleFavorite(item)
                }
            } else {
                Button("Add to Favorites", systemImage: "star") {
                    store.toggleFavorite(item)
                }
            }
            Divider()
        }
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
        if source != .recents {
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
        }
        if folder != nil {
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
    }

    @ViewBuilder
    private var emptyState: some View {
        if isSearching {
            ContentUnavailableView.search(text: query)
        } else {
            switch source {
            case .folder:
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
            case .favorites:
                ContentUnavailableView("No Favorites", systemImage: "star", description: Text("Touch and hold a notebook, then choose Add to Favorites."))
            case .recents:
                ContentUnavailableView("No Recent Notebooks", systemImage: "clock", description: Text("Notebooks you open appear here."))
            }
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
    var isFavorite = false
    var location: String?

    var body: some View {
        VStack(spacing: 10) {
            CoverView(cover: .existing(manifest.cover), notebookURL: url, title: manifest.title)
                .overlay(alignment: .topTrailing) {
                    if isFavorite {
                        Image(systemName: "star.fill")
                            .font(.footnote)
                            .foregroundStyle(.yellow)
                            .frame(width: 30, height: 30)
                            .glassEffect(.regular, in: .circle)
                            .padding(8)
                    }
                }
            VStack(spacing: 2) {
                if let location {
                    Text("in \(location)")
                        .lineLimit(1)
                }
                Text("\(manifest.pageIDs.count) pages")
                Text(manifest.modifiedAt, format: .relative(presentation: .named))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(manifest.title))
        .accessibilityValue(Text("\(manifest.pageIDs.count) pages"))
        .accessibilityHint(isFavorite ? Text("Favorite") : Text(verbatim: ""))
    }
}

struct FolderTile: View {
    let name: String
    let count: Int
    var location: String?

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

            VStack(spacing: 2) {
                if let location {
                    Text("in \(location)")
                        .lineLimit(1)
                }
                Text("\(count) items")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Folder \(name)"))
        .accessibilityValue(Text("\(count) items"))
    }
}
