import NotyCore
import SwiftUI

/// Screen 2: name, paper, orientation and cover of a new notebook.
struct NewNotebookSheet: View {
    let folder: URL
    let onCreate: (NotebookPackage) -> Void

    @Environment(LibraryStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var paper = PaperStyle.lined
    @State private var paperColor = PaperColor.white
    @State private var paperSpacing = PaperSpacing.defaultValue(for: .lined)
    @State private var orientation = PageOrientation.portrait
    @State private var cover = CoverDraft.color(Int.random(in: 0..<Cover.colorCount))

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HStack(alignment: .bottom, spacing: 20) {
                        CoverView(cover: cover, title: displayTitle)
                            .frame(width: 150)
                        PaperPreview(style: paper, orientation: orientation, color: paperColor, spacing: paperSpacing)
                            .frame(width: orientation == .portrait ? 110 : 150)
                    }
                    .frame(maxWidth: .infinity)
                    .animation(.snappy, value: orientation)

                    TextField("Notebook name", text: $title, prompt: Text(defaultTitle))
                        .font(.title3)
                        .padding(14)
                        .glassEffect(.regular, in: .rect(cornerRadius: 16))

                    section("Paper") {
                        VStack(alignment: .leading, spacing: 16) {
                            PaperStylePicker(style: $paper, color: paperColor, spacing: paperSpacing)
                            if paper != .blank {
                                PaperSpacingSlider(style: paper, spacing: $paperSpacing)
                            }
                            PaperColorPicker(color: $paperColor)
                        }
                    }

                    section("Orientation") {
                        Picker("Orientation", selection: $orientation) {
                            Label("Portrait", systemImage: "rectangle.portrait").tag(PageOrientation.portrait)
                            Label("Landscape", systemImage: "rectangle").tag(PageOrientation.landscape)
                        }
                        .pickerStyle(.segmented)
                    }

                    section("Cover") {
                        CoverChooser(cover: $cover)
                    }
                }
                .padding(24)
            }
            .navigationTitle("New Notebook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create", systemImage: "checkmark", role: .confirm) { create() }
                }
            }
            .onChange(of: paper) { _, newPaper in
                paperSpacing = PaperSpacing.defaultValue(for: newPaper)
            }
        }
    }

    private var defaultTitle: String {
        String(localized: "Untitled – \(Date.now.formatted(.dateTime.day().month()))")
    }

    private var displayTitle: String {
        title.trimmingCharacters(in: .whitespaces).isEmpty ? defaultTitle : title
    }

    private func section(_ title: LocalizedStringKey, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content()
        }
    }

    private func create() {
        guard let package = store.createNotebook(title: displayTitle, in: folder, paper: paper, paperColor: paperColor, paperSpacing: paper == .blank ? nil : paperSpacing, orientation: orientation, cover: cover) else { return }
        dismiss()
        onCreate(package)
    }
}

/// Changes the cover of an existing notebook (ORG-9).
struct CoverSheet: View {
    let notebookURL: URL
    let manifest: NotebookManifest

    @Environment(LibraryStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var cover: CoverDraft

    init(notebookURL: URL, manifest: NotebookManifest) {
        self.notebookURL = notebookURL
        self.manifest = manifest
        _cover = State(initialValue: .existing(manifest.cover))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    CoverView(cover: cover, notebookURL: notebookURL, title: manifest.title)
                        .frame(width: 170)
                    CoverChooser(cover: $cover)
                }
                .padding(24)
            }
            .navigationTitle("Cover")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark", role: .confirm) {
                        store.setCover(cover, of: notebookURL)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Picks the destination folder for "Move" (flow F3).
struct MoveSheet: View {
    let item: LibraryEntry

    @Environment(LibraryStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let tree = store.folderTree()
        NavigationStack {
            List {
                row(for: tree.url, name: String(localized: "Library"), systemImage: "books.vertical")
                if let folders = tree.childrenOrNil {
                    OutlineGroup(folders, children: \.childrenOrNil) { node in
                        row(for: node.url, name: node.name, systemImage: "folder")
                    }
                }
            }
            .navigationTitle("Move “\(item.name)”")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark", role: .cancel) { dismiss() }
                }
            }
        }
    }

    private func row(for folder: URL, name: String, systemImage: String) -> some View {
        let isCurrent = folder.standardizedFileURL == item.url.deletingLastPathComponent().standardizedFileURL
        let isInsideItself = folder.standardizedFileURL.path().hasPrefix(item.url.standardizedFileURL.path())
        return Button {
            store.move(item, to: folder)
            dismiss()
        } label: {
            Label(name, systemImage: systemImage)
        }
        .disabled(isCurrent || isInsideItself)
    }
}

/// Deleted items, kept for 30 days (flow F9).
struct TrashView: View {
    @Environment(LibraryStore.self) private var store
    @State private var isConfirmingEmpty = false
    @State private var deleting: TrashedItem?

    var body: some View {
        let items = store.trashedItems()
        List {
            ForEach(items) { trashed in
                HStack(spacing: 16) {
                    Group {
                        switch trashed.item {
                        case .folder:
                            Image(systemName: "folder.fill")
                                .font(.largeTitle)
                                .foregroundStyle(.tint)
                        case .notebook(let url, let manifest):
                            CoverView(cover: .existing(manifest.cover), notebookURL: url, showsLabel: false)
                        }
                    }
                    .frame(width: 44)

                    VStack(alignment: .leading) {
                        Text(trashed.item.name)
                            .font(.headline)
                        Text("Deleted \(trashed.deletedAt, format: .relative(presentation: .named))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Restore") {
                        store.restore(trashed)
                    }
                    .buttonStyle(.glass)
                }
                .swipeActions {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        deleting = trashed
                    }
                    Button("Restore", systemImage: "arrow.uturn.backward") {
                        store.restore(trashed)
                    }
                    .tint(.accentColor)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background { AmbientBackground() }
        .overlay {
            if items.isEmpty {
                ContentUnavailableView("Trash Is Empty", systemImage: "trash", description: Text("Deleted notebooks stay here for 30 days."))
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !items.isEmpty {
                Text("Items are permanently deleted after 30 days.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .glassEffect(.regular, in: .capsule)
                    .padding(.bottom, 8)
            }
        }
        .navigationTitle("Trash")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Empty Trash", role: .destructive) {
                    isConfirmingEmpty = true
                }
                .disabled(items.isEmpty)
            }
        }
        .confirmationDialog("Delete all items in the Trash forever?", isPresented: $isConfirmingEmpty, titleVisibility: .visible) {
            Button("Empty Trash", role: .destructive) { store.emptyTrash() }
        }
        .confirmationDialog(
            "Delete “\(deleting?.item.name ?? "")” forever?",
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete Forever", role: .destructive) {
                if let deleting {
                    store.deleteForever(deleting)
                }
            }
        }
    }
}
