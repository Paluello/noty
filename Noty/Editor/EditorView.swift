import NotyCanvas
import NotyCore
import SwiftUI

/// Screen 3: the notebook editor, with a floating Liquid Glass toolbar.
struct EditorView: View {
    let package: NotebookPackage

    @Environment(\.dismiss) private var dismiss
    @Environment(PaletteStore.self) private var palettes
    @State private var model = EditorModel()
    @State private var title = ""
    @State private var isFocusMode = false
    @State private var isShowingPages = false
    @State private var isShowingPalettes = false
    @State private var sharedPDF: SharedFile?
    @State private var toolbarBottom: CGFloat = 0

    var body: some View {
        ZStack(alignment: .top) {
            Color(uiColor: .secondarySystemBackground)
                .ignoresSafeArea()

            NotebookCanvas(package: package, model: model)
                .ignoresSafeArea()

            if isFocusMode {
                HStack {
                    Spacer()
                    Button("Exit Focus Mode", systemImage: "arrow.down.right.and.arrow.up.left") {
                        withAnimation(.snappy) { isFocusMode = false }
                    }
                    .labelStyle(.iconOnly)
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .glassEffect(.regular.interactive(), in: .circle)
                }
                .padding(.horizontal, 16)
                .transition(.move(edge: .top).combined(with: .opacity))
            } else {
                EditorToolbar(
                    model: model,
                    onClose: close,
                    onShowPages: showPages,
                    onShowPalettes: { isShowingPalettes = true },
                    onExport: exportPDF,
                    onFocusMode: { withAnimation(.snappy) { isFocusMode = true } }
                )
                .padding(.horizontal, 16)
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxY } action: { toolbarBottom = $0 }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .overlay(alignment: .bottomLeading) {
            if !isFocusMode {
                pageIndicator
            }
        }
        .statusBarHidden(isFocusMode)
        .onChange(of: toolbarBottom) { updateInset() }
        .onChange(of: isFocusMode) { updateInset() }
        .onChange(of: palettes.selectedColors, initial: true) { _, colors in
            model.palette = colors
        }
        .onChange(of: model.tool) { EditorPreferences.save(from: model) }
        .onChange(of: model.colorIndex) { EditorPreferences.save(from: model) }
        .onChange(of: model.widthIndex) { EditorPreferences.save(from: model) }
        .onChange(of: model.widthPresets) { EditorPreferences.save(from: model) }
        .onChange(of: model.revision) { title = (try? package.readManifest().title) ?? title }
        .onAppear {
            EditorPreferences.load(into: model)
            title = (try? package.readManifest().title) ?? ""
        }
        .sheet(isPresented: $isShowingPages) {
            PageManagerSheet(package: package, model: model)
        }
        .sheet(isPresented: $isShowingPalettes) {
            NavigationStack { PaletteListView() }
        }
        .sheet(item: $sharedPDF) { file in
            ShareSheet(url: file.url)
        }
    }

    private var pageIndicator: some View {
        Button(action: showPages) {
            HStack(spacing: 8) {
                Text(title)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Text(verbatim: "\(model.currentPage) / \(model.pageCount)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
        .padding(20)
        .accessibilityLabel(Text("Pages"))
    }

    private func showPages() {
        model.save()
        isShowingPages = true
    }

    private func updateInset() {
        model.topContentInset = isFocusMode ? 24 : toolbarBottom + 12
    }

    private func exportPDF() {
        model.save()
        sharedPDF = (try? PageRenderer.exportPDFForSharing(of: package)).map(SharedFile.init(url:))
    }

    private func close() {
        model.save()
        let package = package
        // Keep a PDF copy inside the notebook, readable without Noty (ADR-0004).
        Task.detached(priority: .utility) {
            try? PageRenderer.exportPDF(of: package, to: package.snapshotURL)
        }
        dismiss()
    }
}

/// The floating toolbar: back, tools, palette, undo/redo and more (ADR-0007).
struct EditorToolbar: View {
    @Bindable var model: EditorModel
    let onClose: () -> Void
    let onShowPages: () -> Void
    let onShowPalettes: () -> Void
    let onExport: () -> Void
    let onFocusMode: () -> Void

    @Environment(PaletteStore.self) private var palettes
    @State private var optionsTool: ToolKind?
    @State private var lastInkingTool = ToolKind.pen
    @Namespace private var selection

    var body: some View {
        GlassEffectContainer(spacing: 16) {
            HStack(spacing: 12) {
                Button("Library", systemImage: "chevron.left", action: onClose)
                    .labelStyle(.iconOnly)
                    .frame(width: 48, height: 48)
                    .glassEffect(.regular.interactive(), in: .circle)

                tools
                colors

                Spacer(minLength: 0)

                HStack(spacing: 2) {
                    Button("Undo", systemImage: "arrow.uturn.backward", action: model.undo)
                        .frame(width: 44, height: 48)
                    Button("Redo", systemImage: "arrow.uturn.forward", action: model.redo)
                        .frame(width: 44, height: 48)
                }
                .labelStyle(.iconOnly)
                .padding(.horizontal, 4)
                .glassEffect(.regular.interactive(), in: .capsule)

                Menu {
                    Button("Pages", systemImage: "square.grid.2x2", action: onShowPages)
                    Button("Add Page", systemImage: "plus.rectangle.portrait", action: model.addPageAtEnd)
                    Divider()
                    Button("Palettes", systemImage: "paintpalette", action: onShowPalettes)
                    Button("Focus Mode", systemImage: "arrow.up.left.and.arrow.down.right", action: onFocusMode)
                    Divider()
                    Button("Export PDF", systemImage: "square.and.arrow.up", action: onExport)
                } label: {
                    Label("More", systemImage: "ellipsis")
                        .labelStyle(.iconOnly)
                        .frame(width: 48, height: 48)
                }
                .glassEffect(.regular.interactive(), in: .circle)
            }
            .font(.title3)
        }
        .tint(.primary)
    }

    private var tools: some View {
        HStack(spacing: 0) {
            ForEach(ToolKind.allCases) { tool in
                Button {
                    select(tool)
                } label: {
                    Image(systemName: tool.symbolName)
                        .symbolVariant(model.tool == tool ? .fill : .none)
                        .foregroundStyle(model.tool == tool ? Color.accentColor : .primary)
                        .frame(width: 46, height: 48)
                        .background {
                            if model.tool == tool {
                                Capsule()
                                    .fill(Color.accentColor.opacity(0.16))
                                    .padding(.vertical, 6)
                                    .matchedGeometryEffect(id: "tool", in: selection)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tool.title)
                .popover(isPresented: Binding(get: { optionsTool == tool }, set: { if !$0 { optionsTool = nil } })) {
                    ToolOptionsView(model: model, tool: tool)
                        .presentationCompactAdaptation(.popover)
                }
            }
        }
        .padding(.horizontal, 4)
        .glassEffect(.regular.interactive(), in: .capsule)
        .animation(.snappy(duration: 0.25), value: model.tool)
    }

    private var colors: some View {
        HStack(spacing: 6) {
            ForEach(model.palette.indices, id: \.self) { index in
                Button {
                    model.colorIndex = index
                    if !model.tool.isInking {
                        model.tool = lastInkingTool
                    }
                } label: {
                    Circle()
                        .fill(Color(uiColor: model.palette[index]))
                        .frame(width: 24, height: 24)
                        .overlay { Circle().strokeBorder(.white.opacity(0.5), lineWidth: 1) }
                        .padding(3)
                        .overlay {
                            Circle()
                                .strokeBorder(Color.primary, lineWidth: model.colorIndex == index && model.tool.isInking ? 2 : 0)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Color \(index + 1)"))
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 48)
        .glassEffect(.regular.interactive(), in: .capsule)
        .contextMenu {
            ForEach(palettes.palettes) { palette in
                Button {
                    palettes.selectedID = palette.id
                } label: {
                    if palette.id == palettes.selectedID {
                        Label(palette.displayName, systemImage: "checkmark")
                    } else {
                        Text(palette.displayName)
                    }
                }
            }
            Divider()
            Button("Manage Palettes…", systemImage: "paintpalette", action: onShowPalettes)
        }
    }

    private func select(_ tool: ToolKind) {
        if model.tool == tool {
            // Tapping the current tool shows its options (screen 3).
            if tool != .lasso {
                optionsTool = tool
            }
        } else {
            model.tool = tool
        }
        if tool.isInking {
            lastInkingTool = tool
        }
    }
}

/// Popover for the current tool: three preferred widths, or the eraser mode.
struct ToolOptionsView: View {
    @Bindable var model: EditorModel
    let tool: ToolKind

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(tool.title)
                .font(.headline)
            if tool == .eraser {
                Picker("Eraser", selection: $model.eraserMode) {
                    Text("Partial").tag(EraserMode.partial)
                    Text("Whole Stroke").tag(EraserMode.stroke)
                }
                .pickerStyle(.segmented)
            } else if tool.isInking {
                let presets = model.widthPresets[tool] ?? []
                let selected = model.widthIndex[tool] ?? 0
                HStack(spacing: 14) {
                    ForEach(presets.indices, id: \.self) { index in
                        Button {
                            model.widthIndex[tool] = index
                        } label: {
                            Circle()
                                .fill(Color(uiColor: model.color).opacity(tool == .highlighter ? 0.5 : 1))
                                .frame(width: dotSize(presets[index]), height: dotSize(presets[index]))
                                .frame(width: 52, height: 52)
                                .glassEffect(index == selected ? .regular.tint(.accentColor.opacity(0.25)).interactive() : .regular.interactive(), in: .circle)
                        }
                        .buttonStyle(.plain)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Width")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Slider(value: widthBinding(index: selected), in: range)
                }
            }
        }
        .padding(20)
        .frame(width: 260)
    }

    private var range: ClosedRange<CGFloat> {
        tool == .highlighter ? 5...40 : 0.5...12
    }

    private func dotSize(_ width: CGFloat) -> CGFloat {
        let normalized = (width - range.lowerBound) / (range.upperBound - range.lowerBound)
        return 6 + normalized * 26
    }

    private func widthBinding(index: Int) -> Binding<CGFloat> {
        Binding {
            model.widthPresets[tool]?[index] ?? range.lowerBound
        } set: { newValue in
            model.widthPresets[tool]?[index] = (newValue * 2).rounded() / 2
        }
    }
}

extension ToolKind {
    var title: LocalizedStringKey {
        switch self {
        case .pen: "Pen"
        case .pencil: "Pencil"
        case .highlighter: "Highlighter"
        case .eraser: "Eraser"
        case .lasso: "Lasso"
        }
    }
}
