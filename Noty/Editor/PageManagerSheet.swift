import NotyCanvas
import NotyCore
import SwiftUI

/// Screen 4: page thumbnails to jump to, reorder, duplicate and delete (PAG-4).
struct PageManagerSheet: View {
    let package: NotebookPackage
    @Bindable var model: EditorModel

    @Environment(\.dismiss) private var dismiss
    @State private var manifest: NotebookManifest?
    @State private var deleting: Int?

    /// The editor saves before showing this sheet, so thumbnails are up to date.
    init(package: NotebookPackage, model: EditorModel) {
        self.package = package
        self.model = model
        _manifest = State(initialValue: try? package.readManifest())
    }

    private let columns = [GridItem(.adaptive(minimum: 130, maximum: 170), spacing: 24, alignment: .top)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 28) {
                    ForEach(Array(model.pageIDs.enumerated()), id: \.element) { index, pageID in
                        cell(index: index, pageID: pageID)
                    }
                }
                .padding(24)
            }
            .navigationTitle("Pages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Add Page", systemImage: "plus") {
                        model.addPageAtEnd()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark", role: .confirm) { dismiss() }
                }
            }
            .confirmationDialog(
                "Delete page \((deleting ?? 0) + 1)?",
                isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                titleVisibility: .visible
            ) {
                Button("Delete Page", role: .destructive) {
                    if let deleting {
                        model.deletePage(at: deleting)
                    }
                }
            }
        }
    }

    private func cell(index: Int, pageID: UUID) -> some View {
        Button {
            model.scrollToPage(index)
            dismiss()
        } label: {
            VStack(spacing: 8) {
                PageThumbnail(package: package, manifest: manifest, pageID: pageID)
                    .overlay {
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(Color.accentColor, lineWidth: model.currentPage == index + 1 ? 3 : 0)
                    }
                Text(verbatim: "\(index + 1)")
                    .font(.callout.monospacedDigit())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .systemGlass(model.currentPage == index + 1 ? .regular.tint(.accentColor.opacity(0.3)) : .regular, in: .capsule)
            }
        }
        .buttonStyle(.plain)
        .draggable(pageID.uuidString)
        .dropDestination(for: String.self) { items, _ in
            guard let id = items.first.flatMap(UUID.init(uuidString:)),
                  let source = model.pageIDs.firstIndex(of: id) else { return false }
            model.movePage(from: source, to: index)
            return true
        }
        .contextMenu {
            Button("Insert Page After", systemImage: "plus.rectangle.portrait") {
                model.insertPage(after: index)
            }
            Button("Duplicate", systemImage: "plus.square.on.square") {
                model.duplicatePage(at: index)
            }
            Button("Move Earlier", systemImage: "arrow.left") {
                model.movePage(from: index, to: index - 1)
            }
            .disabled(index == 0)
            Button("Move Later", systemImage: "arrow.right") {
                model.movePage(from: index, to: index + 1)
            }
            .disabled(index == model.pageCount - 1)
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive) {
                deleting = index
            }
        }
    }
}

/// A page rendered off the main thread.
struct PageThumbnail: View {
    let package: NotebookPackage
    let manifest: NotebookManifest?
    let pageID: UUID

    @State private var image: UIImage?

    var body: some View {
        let size = PageGeometry.size(for: manifest?.orientation ?? .portrait)
        Rectangle()
            .fill(.white)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                }
            }
            .aspectRatio(size.width / size.height, contentMode: .fit)
            .clipShape(.rect(cornerRadius: 4))
            .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
            .task(id: pageID) {
                guard let manifest else { return }
                let package = package
                image = await Task.detached(priority: .userInitiated) {
                    PageRenderer.thumbnail(of: pageID, in: package, manifest: manifest, width: 170)
                }.value
            }
    }
}
