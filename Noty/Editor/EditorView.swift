import NotyCanvas
import NotyCore
import PhotosUI
import SwiftUI

/// Screen 3: the notebook editor, with a floating Liquid Glass toolbar.
struct EditorView: View {
    let package: NotebookPackage
    /// Closes the editor; by default it dismisses the full-screen cover.
    var onClose: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(LibraryStore.self) private var store
    @Environment(PaletteStore.self) private var palettes
    @AppStorage(SettingsKey.toolbarPosition) private var position = ToolbarPosition.top
    @AppStorage(SettingsKey.floatingToolbarX) private var floatingX = 0.0
    @AppStorage(SettingsKey.floatingToolbarY) private var floatingY = 0.0
    @State private var model = EditorModel()
    @State private var title = ""
    @State private var isFocusMode = false
    @State private var isShowingPages = false
    @State private var isShowingPalettes = false
    @State private var sharedPDF: SharedFile?
    @State private var toolbarFrame = CGRect.zero
    @State private var imageSource: ImageSource?
    @State private var photoItem: PhotosPickerItem?
    @State private var isShowingPaper = false
    /// Locked notebooks stay covered until Face ID or the passcode (ADR-0012).
    @State private var isUnlocked = false
    @State private var isLocked = false
    @State private var dragOffset = CGSize.zero

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color(uiColor: .secondarySystemBackground)
                    .ignoresSafeArea()

                NotebookCanvas(package: package, model: model)
                    .padding(.leading, sideInset(for: .leading))
                    .padding(.trailing, sideInset(for: .trailing))
                    .ignoresSafeArea()

                chrome
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: chromeAlignment)
            }
            .onChange(of: toolbarFrame) { updateInset(safeTop: proxy.safeAreaInsets.top) }
            .onChange(of: isFocusMode) { updateInset(safeTop: proxy.safeAreaInsets.top) }
            .onChange(of: position) { updateInset(safeTop: proxy.safeAreaInsets.top) }
            .onAppear { updateInset(safeTop: proxy.safeAreaInsets.top) }
        }
        .overlay(alignment: .bottomLeading) {
            if !isFocusMode {
                pageIndicator
            }
        }
        .overlay {
            if isLocked && !isUnlocked {
                ZStack {
                    Rectangle().fill(.regularMaterial).ignoresSafeArea()
                    ProgressView()
                }
            }
        }
        .task {
            isLocked = (try? package.readManifest().isLocked) ?? false
            guard isLocked else { return }
            isUnlocked = await Biometrics.authenticate(reason: String(localized: "Open the locked notebook"))
            if !isUnlocked {
                close()
            }
        }
        .animation(.snappy, value: position)
        .animation(.snappy, value: isFocusMode)
        .statusBarHidden(isFocusMode)
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
            store.openNotebooks.insert(Library.normalized(package.url))
        }
        .onDisappear {
            store.openNotebooks.remove(Library.normalized(package.url))
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
        .sheet(isPresented: $isShowingPaper) {
            PaperSheet(model: model)
        }
        .photosPicker(isPresented: imageSourceBinding(.photos), selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    model.insertImage(data)
                }
                photoItem = nil
            }
        }
        .fileImporter(isPresented: imageSourceBinding(.files), allowedContentTypes: [.image]) { result in
            guard case .success(let url) = result else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            if let data = try? Data(contentsOf: url) {
                model.insertImage(data)
            }
        }
        .fullScreenCover(isPresented: imageSourceBinding(.scanner)) {
            DocumentScanner { images in
                for image in images {
                    if let data = image.jpegData(compressionQuality: 0.9) {
                        model.insertImage(data)
                    }
                }
            }
            .ignoresSafeArea()
        }
    }

    private func imageSourceBinding(_ source: ImageSource) -> Binding<Bool> {
        Binding(get: { imageSource == source }, set: { if !$0 { imageSource = nil } })
    }

    // MARK: - Toolbar placement (UI-1)

    @ViewBuilder
    private var chrome: some View {
        if isFocusMode {
            Button("Exit Focus Mode", systemImage: "arrow.down.right.and.arrow.up.left") {
                isFocusMode = false
            }
            .labelStyle(.iconOnly)
            .font(.title3)
            .frame(width: 44, height: 44)
            .glassEffect(.regular.interactive(), in: .circle)
            .padding(.horizontal, 16)
            .transition(.opacity)
        } else {
            switch position {
            case .top:
                toolbar(axis: .horizontal)
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
            case .leading:
                toolbar(axis: .vertical)
                    .padding(.leading, 12)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            case .trailing:
                toolbar(axis: .vertical)
                    .padding(.trailing, 12)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            case .floating:
                HStack(spacing: 8) {
                    Image(systemName: "line.3.horizontal")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 48)
                        .contentShape(.rect)
                        .gesture(dragGesture)
                        .accessibilityLabel(Text("Move Toolbar"))
                    toolbar(axis: .horizontal, isCompact: true)
                }
                .padding(.leading, 10)
                .padding(.trailing, 4)
                .padding(.vertical, 4)
                .background(.thinMaterial.opacity(0.001), in: .capsule)
                .offset(x: floatingX + dragOffset.width, y: floatingY + dragOffset.height)
                .transition(.opacity)
            }
        }
    }

    private func toolbar(axis: Axis, isCompact: Bool = false) -> some View {
        EditorToolbar(
            model: model,
            axis: axis,
            isCompact: isCompact,
            position: $position,
            onClose: close,
            onShowPages: showPages,
            onShowPalettes: { isShowingPalettes = true },
            onExport: exportPDF,
            onFocusMode: { isFocusMode = true },
            onInsertImage: { imageSource = $0 },
            onShowPaper: { isShowingPaper = true }
        )
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { toolbarFrame = $0 }
    }

    private var chromeAlignment: Alignment {
        if isFocusMode { return .topTrailing }
        switch position {
        case .top, .floating: return .top
        case .leading: return .leading
        case .trailing: return .trailing
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { dragOffset = $0.translation }
            .onEnded { value in
                floatingX += value.translation.width
                floatingY += value.translation.height
                dragOffset = .zero
            }
    }

    /// Keeps pages clear of a toolbar docked on the side.
    private func sideInset(for edge: ToolbarPosition) -> CGFloat {
        guard !isFocusMode, position == edge else { return 0 }
        return toolbarFrame.width + 20
    }

    private func updateInset(safeTop: CGFloat) {
        if isFocusMode {
            model.topContentInset = 24
        } else if position == .top {
            model.topContentInset = toolbarFrame.maxY + 12
        } else {
            model.topContentInset = safeTop + 16
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
        .padding(.leading, sideInset(for: .leading))
        .accessibilityLabel(Text("Pages"))
        .accessibilityValue(Text(verbatim: "\(model.currentPage) / \(model.pageCount)"))
    }

    private func showPages() {
        model.save()
        isShowingPages = true
    }

    private func exportPDF() {
        model.save()
        sharedPDF = (try? PageRenderer.exportPDFForSharing(of: package)).map(SharedFile.init(url:))
    }

    private func close() {
        model.save()
        let package = package
        // Keep a PDF copy inside the notebook, readable without Noty (ADR-0004),
        // except for locked notebooks (ADR-0012).
        if (try? package.readManifest().isLocked) != true {
            Task.detached(priority: .utility) {
                try? PageRenderer.exportPDF(of: package, to: package.snapshotURL)
            }
        }
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }
}

/// Where an inserted image comes from (STR-9).
enum ImageSource {
    case photos, files, scanner
}

/// The floating toolbar: back, tools, palette, undo/redo and more (ADR-0007).
/// Horizontal at the top or floating, vertical when docked on a side.
struct EditorToolbar: View {
    @Bindable var model: EditorModel
    var axis: Axis = .horizontal
    var isCompact = false
    @Binding var position: ToolbarPosition
    let onClose: () -> Void
    let onShowPages: () -> Void
    let onShowPalettes: () -> Void
    let onExport: () -> Void
    let onFocusMode: () -> Void
    let onInsertImage: (ImageSource) -> Void
    let onShowPaper: () -> Void

    @Environment(PaletteStore.self) private var palettes
    @State private var optionsTool: ToolKind?
    @State private var lastInkingTool = ToolKind.pen
    @Namespace private var selection

    private var isVertical: Bool { axis == .vertical }

    private func stack(spacing: CGFloat) -> AnyLayout {
        isVertical ? AnyLayout(VStackLayout(spacing: spacing)) : AnyLayout(HStackLayout(spacing: spacing))
    }

    var body: some View {
        GlassEffectContainer(spacing: 16) {
            stack(spacing: 12).callAsFunction {
                Button("Library", systemImage: "chevron.left", action: onClose)
                    .labelStyle(.iconOnly)
                    .frame(width: 48, height: 48)
                    .glassEffect(.regular.interactive(), in: .circle)

                tools
                colors

                if !isVertical && !isCompact {
                    Spacer(minLength: 0)
                }

                stack(spacing: 2).callAsFunction {
                    Button("Undo", systemImage: "arrow.uturn.backward", action: model.undo)
                        .frame(width: 44, height: 44)
                    Button("Redo", systemImage: "arrow.uturn.forward", action: model.redo)
                        .frame(width: 44, height: 44)
                }
                .labelStyle(.iconOnly)
                .padding(4)
                .glassEffect(.regular.interactive(), in: .capsule)

                moreMenu
            }
            .font(.title3)
        }
        .tint(.primary)
    }

    private var moreMenu: some View {
        Menu {
            Button("Pages", systemImage: "square.grid.2x2", action: onShowPages)
            Button("Add Page", systemImage: "plus.rectangle.portrait", action: model.addPageAtEnd)
            Menu {
                InsertImageButtons(onInsert: onInsertImage)
            } label: {
                Label("Insert Image", systemImage: "photo.badge.plus")
            }
            Button("Paper", systemImage: "doc.richtext", action: onShowPaper)
            Divider()
            Button("Palettes", systemImage: "paintpalette", action: onShowPalettes)
            Picker(selection: $position) {
                ForEach(ToolbarPosition.allCases) { option in
                    Label(option.title, systemImage: option.symbolName).tag(option)
                }
            } label: {
                Label("Toolbar Position", systemImage: "rectangle.3.group")
            }
            .pickerStyle(.menu)
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

    private var tools: some View {
        stack(spacing: 0).callAsFunction {
            ForEach(ToolKind.allCases) { tool in
                Button {
                    select(tool)
                } label: {
                    Image(systemName: tool.symbolName)
                        .symbolVariant(model.tool == tool ? .fill : .none)
                        .foregroundStyle(model.tool == tool ? Color.accentColor : .primary)
                        .frame(width: 40, height: 44)
                        .background {
                            if model.tool == tool {
                                Capsule()
                                    .fill(Color.accentColor.opacity(0.16))
                                    .padding(4)
                                    .matchedGeometryEffect(id: "tool", in: selection)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tool.title)
                .accessibilityAddTraits(model.tool == tool ? .isSelected : [])
                .popover(isPresented: Binding(get: { optionsTool == tool }, set: { if !$0 { optionsTool = nil } })) {
                    ToolOptionsView(model: model, tool: tool) { source in
                        optionsTool = nil
                        onInsertImage(source)
                    }
                    .presentationCompactAdaptation(.popover)
                }
            }

            // The ruler is a switch, not a tool: it stays on while you write (STR-4).
            Button {
                model.isRulerActive.toggle()
            } label: {
                Image(systemName: "ruler")
                    .foregroundStyle(model.isRulerActive ? Color.accentColor : .primary)
                    .frame(width: 40, height: 44)
                    .background {
                        if model.isRulerActive {
                            Circle().fill(Color.accentColor.opacity(0.16)).padding(4)
                        }
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Ruler"))
            .accessibilityAddTraits(model.isRulerActive ? .isSelected : [])
        }
        .padding(4)
        .glassEffect(.regular.interactive(), in: .capsule)
        .animation(.snappy(duration: 0.25), value: model.tool)
    }

    @ViewBuilder
    private var colors: some View {
        let swatches = ForEach(model.palette.indices, id: \.self) { index in
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
                    .padding(2)
                    .overlay {
                        Circle()
                            .strokeBorder(Color.primary, lineWidth: model.colorIndex == index && model.tool.isInking ? 2 : 0)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Color \(index + 1)"))
            .accessibilityAddTraits(model.colorIndex == index ? .isSelected : [])
        }

        Group {
            if isVertical {
                // Two columns keep the side toolbar short enough for landscape.
                LazyVGrid(columns: [GridItem(.fixed(30), spacing: 4), GridItem(.fixed(30), spacing: 4)], spacing: 4) {
                    swatches
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 6)
            } else {
                HStack(spacing: 3) {
                    swatches
                }
                .padding(.horizontal, 10)
                .frame(height: 52)
            }
        }
        .glassEffect(.regular.interactive(), in: isVertical ? AnyShape(.rect(cornerRadius: 26)) : AnyShape(.capsule))
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
    var onInsertImage: (ImageSource) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(tool.title)
                .font(.headline)
            if tool == .text {
                Text("Tap the page to add a text box. Drag to move, use the corner to resize.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 4) {
                    InsertImageButtons(onInsert: onInsertImage)
                }
                .buttonStyle(.glass)
            } else if tool == .eraser {
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

/// Photo, file and (where there is a camera) document scanner.
struct InsertImageButtons: View {
    let onInsert: (ImageSource) -> Void

    var body: some View {
        Button("Photo", systemImage: "photo") { onInsert(.photos) }
        Button("File", systemImage: "folder") { onInsert(.files) }
        if DocumentScanner.isSupported {
            Button("Scan Document", systemImage: "doc.viewfinder") { onInsert(.scanner) }
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
        case .text: "Text and Images"
        }
    }
}
