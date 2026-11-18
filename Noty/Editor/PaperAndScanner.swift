import NotyCanvas
import NotyCore
import SwiftUI
import VisionKit

/// Changes paper style and color of the whole notebook (PAG-3, PAG-5).
struct PaperSheet: View {
    @Bindable var model: EditorModel
    @Environment(\.dismiss) private var dismiss
    @State private var style: PaperStyle
    @State private var color: PaperColor
    @State private var spacing: Double?

    init(model: EditorModel) {
        self.model = model
        _style = State(initialValue: model.paper)
        _color = State(initialValue: model.paperColor)
        _spacing = State(initialValue: model.paperSpacing)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    PaperStylePicker(style: $style, color: color, spacing: spacing)
                    if style != .blank {
                        PaperSpacingSlider(style: style, spacing: $spacing)
                    }
                    PaperColorPicker(color: $color)
                    Text("The new paper applies to every page. Your writing stays as it is.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(24)
            }
            .navigationTitle("Paper")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark", role: .confirm) {
                        model.setPaper(style, color: color, spacing: style == .blank ? nil : spacing)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onChange(of: style) { _, newStyle in
            // Lines and squares are measured differently: start from the default.
            spacing = newStyle == model.paper ? model.paperSpacing : PaperSpacing.defaultValue(for: newStyle)
        }
    }
}

/// The four paper styles as tappable previews.
struct PaperStylePicker: View {
    @Binding var style: PaperStyle
    var color: PaperColor = .white
    /// Spacing of the selected style; the others show their default.
    var spacing: Double?

    var body: some View {
        HStack(spacing: 14) {
            ForEach(PaperStyle.allCases, id: \.self) { option in
                Button {
                    style = option
                } label: {
                    VStack(spacing: 8) {
                        PaperPreview(style: option, color: color, spacing: option == style ? spacing : PaperSpacing.defaultValue(for: option))
                            .overlay {
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(Color.accentColor, lineWidth: style == option ? 3 : 0)
                            }
                        Text(option.title)
                            .font(.footnote)
                            .foregroundStyle(style == option ? .primary : .secondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(style == option ? .isSelected : [])
            }
        }
    }
}

struct PaperColorPicker: View {
    @Binding var color: PaperColor

    var body: some View {
        HStack(spacing: 16) {
            ForEach(PaperColor.allCases, id: \.self) { option in
                Button {
                    color = option
                } label: {
                    VStack(spacing: 6) {
                        Circle()
                            .fill(Color(uiColor: option.uiColor))
                            .frame(width: 36, height: 36)
                            .overlay { Circle().strokeBorder(.secondary.opacity(0.4), lineWidth: 1) }
                            .padding(4)
                            .overlay { Circle().strokeBorder(Color.accentColor, lineWidth: color == option ? 3 : 0) }
                        Text(option.title)
                            .font(.footnote)
                            .foregroundStyle(color == option ? .primary : .secondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(color == option ? .isSelected : [])
            }
        }
    }
}

extension PaperColor {
    var title: LocalizedStringKey {
        switch self {
        case .white: "White"
        case .ivory: "Ivory"
        case .gray: "Gray"
        }
    }
}

/// VisionKit's document scanner (STR-9); needs a camera, so not in the simulator.
struct DocumentScanner: UIViewControllerRepresentable {
    static var isSupported: Bool { VNDocumentCameraViewController.isSupported }

    let onScan: ([UIImage]) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    @MainActor final class Coordinator: NSObject, @preconcurrency VNDocumentCameraViewControllerDelegate {
        let parent: DocumentScanner

        init(parent: DocumentScanner) {
            self.parent = parent
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            parent.onScan((0..<scan.pageCount).map(scan.imageOfPage(at:)))
            parent.dismiss()
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.dismiss()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: any Error) {
            parent.dismiss()
        }
    }
}
