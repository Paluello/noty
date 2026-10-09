import SwiftUI

/// The editor's toolbar (ADR-0007): tools, the 8-color palette, undo/redo.
public struct EditorToolbar: View {
    @Bindable var model: EditorModel

    public init(model: EditorModel) {
        self.model = model
    }

    public var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 4) {
                ForEach(ToolKind.allCases) { tool in
                    Button {
                        model.tool = tool
                    } label: {
                        Image(systemName: tool.symbolName)
                            .font(.title3)
                            .frame(width: 40, height: 40)
                            .background(model.tool == tool ? Color.accentColor.opacity(0.15) : .clear, in: .rect(cornerRadius: 8))
                    }
                    .accessibilityLabel(Text(tool.rawValue.capitalized))
                }
            }

            if model.tool == .eraser {
                Picker("Eraser", selection: $model.eraserMode) {
                    Text("Partial").tag(EraserMode.partial)
                    Text("Whole stroke").tag(EraserMode.stroke)
                }
                .pickerStyle(.segmented)
                .fixedSize()
            } else {
                HStack(spacing: 8) {
                    ForEach(model.palette.indices, id: \.self) { index in
                        Button {
                            model.colorIndex = index
                        } label: {
                            Circle()
                                .fill(Color(uiColor: model.palette[index]))
                                .frame(width: 24, height: 24)
                                .overlay {
                                    Circle()
                                        .strokeBorder(Color.primary, lineWidth: model.colorIndex == index ? 2 : 0)
                                        .padding(-4)
                                }
                        }
                    }
                }
                .disabled(model.tool == .lasso)
            }

            Spacer()

            Button(action: model.undo) { Image(systemName: "arrow.uturn.backward") }
            Button(action: model.redo) { Image(systemName: "arrow.uturn.forward") }
            Button(action: model.addPage) { Image(systemName: "plus.rectangle.portrait") }

            Text(verbatim: "\(model.currentPage) / \(model.pageCount)")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .font(.title3)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }
}
