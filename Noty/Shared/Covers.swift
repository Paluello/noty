import NotyCore
import PhotosUI
import SwiftUI

/// A cover being chosen, before it is saved into the notebook.
enum CoverDraft: Equatable {
    case color(Int)
    /// A new JPEG image picked from Photos or Files.
    case image(Data)
    /// Keep the notebook's current cover.
    case existing(Cover)
}

/// The 12 built-in cover colors (ORG-9): cheerful, but readable under white text.
enum CoverPalette {
    static let colors: [Color] = [
        Color(red: 0.98, green: 0.42, blue: 0.42), // coral
        Color(red: 1.00, green: 0.62, blue: 0.26), // tangerine
        Color(red: 0.98, green: 0.78, blue: 0.20), // sunflower
        Color(red: 0.55, green: 0.80, blue: 0.35), // lime
        Color(red: 0.20, green: 0.70, blue: 0.55), // mint
        Color(red: 0.18, green: 0.68, blue: 0.84), // sky
        Color(red: 0.26, green: 0.47, blue: 0.93), // ocean
        Color(red: 0.45, green: 0.36, blue: 0.90), // indigo
        Color(red: 0.70, green: 0.40, blue: 0.90), // lavender
        Color(red: 0.95, green: 0.45, blue: 0.70), // bubblegum
        Color(red: 0.55, green: 0.42, blue: 0.35), // cocoa
        Color(red: 0.30, green: 0.33, blue: 0.40), // slate
    ]

    static func color(_ index: Int) -> Color {
        colors[((index % colors.count) + colors.count) % colors.count]
    }
}

/// Front of a notebook: a color or an image, a spine, and a glass label.
struct CoverView: View {
    let cover: CoverDraft
    var notebookURL: URL?
    var title: String?
    var showsLabel = true

    var body: some View {
        let shape = UnevenRoundedRectangle(topLeadingRadius: 6, bottomLeadingRadius: 6, bottomTrailingRadius: 16, topTrailingRadius: 16)
        background
            .overlay(alignment: .leading) { spine }
            .overlay(alignment: .bottom) {
                if showsLabel, let title, !title.isEmpty {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .systemGlass(.regular, in: .rect(cornerRadius: 12))
                        .padding(10)
                        .padding(.leading, 8)
                }
            }
            .clipShape(shape)
            .overlay { shape.strokeBorder(.white.opacity(0.18), lineWidth: 1) }
            .shadow(color: .black.opacity(0.18), radius: 10, y: 6)
            .aspectRatio(PageGeometry.a4Width / PageGeometry.a4Height, contentMode: .fit)
    }

    @ViewBuilder
    private var background: some View {
        switch cover {
        case .color(let index):
            gradient(CoverPalette.color(index))
        case .image(let data):
            image(UIImage(data: data))
        case .existing(.color(let index)):
            gradient(CoverPalette.color(index))
        case .existing(.image(let fileName)):
            image(notebookURL.flatMap { UIImage(contentsOfFile: NotebookPackage(url: $0).coverImageURL(fileName).path(percentEncoded: false)) })
        }
    }

    private func gradient(_ color: Color) -> some View {
        Rectangle()
            .fill(color.gradient)
            .overlay {
                LinearGradient(colors: [.white.opacity(0.22), .clear, .black.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
    }

    private func image(_ image: UIImage?) -> some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.2))
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipped()
    }

    private var spine: some View {
        HStack(spacing: 0) {
            Rectangle().fill(.black.opacity(0.18)).frame(width: 10)
            Rectangle().fill(.white.opacity(0.25)).frame(width: 1)
        }
    }
}

/// Picks a cover: 12 colors, a photo, or an image file.
struct CoverChooser: View {
    @Binding var cover: CoverDraft
    @State private var photoItem: PhotosPickerItem?
    @State private var isImportingFile = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
                ForEach(CoverPalette.colors.indices, id: \.self) { index in
                    Button {
                        cover = .color(index)
                    } label: {
                        Circle()
                            .fill(CoverPalette.colors[index].gradient)
                            .frame(width: 36, height: 36)
                            .overlay {
                                if isSelected(index) {
                                    Image(systemName: "checkmark")
                                        .font(.footnote.bold())
                                        .foregroundStyle(.white)
                                }
                            }
                            .padding(4)
                            .overlay { Circle().strokeBorder(Color.primary.opacity(isSelected(index) ? 0.6 : 0), lineWidth: 2) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Color \(index + 1)"))
                }
            }

            HStack {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label("Photo", systemImage: "photo.on.rectangle")
                }
                Button {
                    isImportingFile = true
                } label: {
                    Label("File", systemImage: "folder")
                }
            }
            .systemGlassButtonStyle()
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let jpeg = CoverImage.prepare(data) {
                    cover = .image(jpeg)
                }
                photoItem = nil
            }
        }
        .fileImporter(isPresented: $isImportingFile, allowedContentTypes: [.image]) { result in
            guard case .success(let url) = result else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            if let data = try? Data(contentsOf: url), let jpeg = CoverImage.prepare(data) {
                cover = .image(jpeg)
            }
        }
    }

    private func isSelected(_ index: Int) -> Bool {
        cover == .color(index) || cover == .existing(.color(index: index))
    }
}

enum CoverImage {
    /// Shrinks an image to at most 1200 px and encodes it as JPEG, to keep notebooks small.
    static func prepare(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let maxSide: CGFloat = 1200
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.85)
    }
}

