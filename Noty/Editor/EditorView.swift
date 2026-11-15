import NotyCanvas
import NotyCore
import PhotosUI
import SwiftUI

/// Screen 3: the notebook editor: a docked two-row bar above a continuous page.
struct EditorView: View {
    let package: NotebookPackage
    /// Closes the editor; by default it dismisses the full-screen cover.
    var onClose: (() -> Void)?
    /// Page to open at, e.g. from a search result.
    var initialPage: Int?

    @State private var audio: NotebookAudio
    @State private var isShowingMicrophoneAlert = false

    init(package: NotebookPackage, onClose: (() -> Void)? = nil, initialPage: Int? = nil) {
        self.package = package
        self.onClose = onClose
        self.initialPage = initialPage
        _audio = State(initialValue: NotebookAudio(package: package))
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(LibraryStore.self) private var store
    @Environment(PaletteStore.self) private var palettes
    @State private var model = EditorModel()
    @State private var title = ""
    @State private var isFocusMode = false
    @State private var isShowingPages = false
    @State private var isShowingPalettes = false
    @State private var sharedPDF: SharedFile?
    @State private var imageSource: ImageSource?
    @State private var photoItem: PhotosPickerItem?
    @State private var isShowingPaper = false
    /// Locked notebooks stay covered until Face ID or the passcode (ADR-0012).
    @State private var isUnlocked = false
    @State private var isLocked = false

    var body: some View {
        // The bar is docked above the page, never over it: nothing covers the
        // paper and the page does not move when a tool changes.
        VStack(spacing: 0) {
            if !isFocusMode {
                EditorToolbar(
                    model: model,
                    title: title,
                    audio: audio,
                    onClose: close,
                    onShowPages: showPages,
                    onShowPalettes: { isShowingPalettes = true },
                    onExport: exportPDF,
                    onFocusMode: { isFocusMode = true },
                    onInsertImage: { imageSource = $0 },
                    onShowPaper: { isShowingPaper = true },
                    onRecord: startRecording
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            NotebookCanvas(package: package, model: model)
                .ignoresSafeArea(edges: isFocusMode ? .all : [.bottom, .horizontal])
        }
        .background(Color(uiColor: .secondarySystemBackground).ignoresSafeArea())
        .overlay(alignment: .topTrailing) {
            if isFocusMode {
                Button("Exit Focus Mode", systemImage: "arrow.down.right.and.arrow.up.left") {
                    isFocusMode = false
                }
                .labelStyle(.iconOnly)
                .font(.title3)
                .frame(width: 48, height: 48)
                .contentShape(.circle)
                .glassEffect(.regular.interactive(), in: .circle)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .transition(.opacity)
            }
        }
        .overlay(alignment: .bottom) {
            if audio.isBusy {
                AudioBar(audio: audio)
                    .padding(.bottom, 20)
            }
        }
        .animation(.snappy, value: audio.isBusy)
        .onChange(of: audio.playbackDate) { _, date in model.playbackDate = date }
        .alert("Microphone Access", isPresented: $isShowingMicrophoneAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("To record, allow Noty to use the microphone in the iPad's Settings › Apps › Noty.")
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
            model.initialPage = initialPage
            model.onSeek = { [audio] date in audio.seek(toDate: date) }
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

    private func startRecording() {
        Task {
            guard await audio.requestPermission() else {
                isShowingMicrophoneAlert = true
                return
            }
            do {
                try audio.startRecording()
            } catch {
                isShowingMicrophoneAlert = true
            }
        }
    }

    private func showPages() {
        model.save()
        isShowingPages = true
    }

    private func exportPDF() {
        model.save()
        sharedPDF = (try? PageRenderer.exportPDFForSharing(of: package)).map { SharedFile(url: $0) }
    }

    private func close() {
        audio.stopRecording()
        audio.stopPlayback()
        model.save()
        let package = package
        // Keep a PDF copy inside the notebook, readable without Noty (ADR-0004),
        // except for locked notebooks (ADR-0012).
        if (try? package.readManifest().isLocked) != true {
            Task.detached(priority: .utility) {
                try? PageRenderer.exportPDF(of: package, to: package.snapshotURL)
                // Read the handwriting of changed pages, for search (ORG-8).
                try? await TextIndexer.update(package)
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

/// The editor bar (ADR-0007, ADR-0021), docked at the top in two rows:
/// commands and tools above, the options of the current tool below.
/// Everything is one tap away and every target is at least 44 pt.
struct EditorToolbar: View {
    @Bindable var model: EditorModel
    let title: String
    let audio: NotebookAudio
    let onClose: () -> Void
    let onShowPages: () -> Void
    let onShowPalettes: () -> Void
    let onExport: () -> Void
    let onFocusMode: () -> Void
    let onInsertImage: (ImageSource) -> Void
    let onShowPaper: () -> Void
    let onRecord: () -> Void

    @Environment(PaletteStore.self) private var palettes
    @State private var isEditingWidth = false

    var body: some View {
        VStack(spacing: 0) {
            // Narrow windows first drop the title, then let the tools scroll.
            ViewThatFits(in: .horizontal) {
                commandRow(showsTitle: true, scrollsTools: false)
                commandRow(showsTitle: false, scrollsTools: false)
                commandRow(showsTitle: false, scrollsTools: true)
            }
            .frame(height: 52)
            Divider()
            ViewThatFits(in: .horizontal) {
                optionsRow
                ScrollView(.horizontal, showsIndicators: false) { optionsRow }
            }
            .frame(height: 50)
            Divider()
        }
        .background(Color(uiColor: .systemBackground))
    }

    // MARK: - Row 1: commands and tools

    private func commandRow(showsTitle: Bool, scrollsTools: Bool) -> some View {
        HStack(spacing: 2) {
            BarButton(title: "Library", systemImage: "chevron.left", action: onClose)
            pagesButton(showsTitle: showsTitle)
            Spacer(minLength: 8)
            if scrollsTools {
                ScrollView(.horizontal, showsIndicators: false) { tools }
            } else {
                tools
            }
            Spacer(minLength: 8)
            BarButton(title: "Undo", systemImage: "arrow.uturn.backward", action: model.undo)
            BarButton(title: "Redo", systemImage: "arrow.uturn.forward", action: model.redo)
            BarButton(title: "Record Audio", systemImage: audio.isRecording ? "mic.fill" : "mic", action: onRecord)
                .foregroundStyle(audio.isRecording ? Color.red : Color.primary)
                .disabled(audio.isRecording)
            moreMenu
        }
        .padding(.horizontal, 8)
    }

    /// Notebook title and page counter; opens the page manager.
    private func pagesButton(showsTitle: Bool) -> some View {
        Button(action: onShowPages) {
            HStack(spacing: 8) {
                if showsTitle {
                    Text(title)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .frame(maxWidth: 220, alignment: .leading)
                        .fixedSize(horizontal: true, vertical: false)
                }
                Text(verbatim: "\(model.currentPage) / \(model.pageCount)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
            .padding(.horizontal, 10)
            .frame(height: 44)
        }
        .buttonStyle(BarButtonStyle())
        .accessibilityLabel(Text("Pages"))
        .accessibilityValue(Text(verbatim: "\(model.currentPage) / \(model.pageCount)"))
    }

    private var tools: some View {
        HStack(spacing: 2) {
            ForEach(ToolKind.allCases) { tool in
                Button {
                    model.tool = tool
                } label: {
                    Image(systemName: tool.symbolName)
                        .font(.system(size: 20, weight: .medium))
                        .frame(width: 48, height: 44)
                }
                .buttonStyle(BarButtonStyle(isSelected: model.tool == tool))
                .accessibilityLabel(tool.title)
                .accessibilityAddTraits(model.tool == tool ? .isSelected : [])
            }
        }
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
            if !audio.recordings.isEmpty {
                Divider()
                Menu {
                    RecordingsMenu(audio: audio)
                } label: {
                    Label("Recordings", systemImage: "waveform")
                }
            }
            Divider()
            Button("Palettes", systemImage: "paintpalette", action: onShowPalettes)
            Button("Focus Mode", systemImage: "arrow.up.left.and.arrow.down.right", action: onFocusMode)
            Divider()
            Button("Export PDF", systemImage: "square.and.arrow.up", action: onExport)
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 20, weight: .medium))
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .tint(.primary)
        .accessibilityLabel(Text("More"))
    }

    // MARK: - Row 2: options of the current tool

    @ViewBuilder
    private var optionsRow: some View {
        HStack(spacing: 6) {
            switch model.tool {
            case .pen, .pencil, .highlighter:
                widths(for: model.tool)
                separator
                colors
                separator
                rulerButton
            case .eraser:
                Picker("Eraser", selection: $model.eraserMode) {
                    Text("Partial").tag(EraserMode.partial)
                    Text("Whole Stroke").tag(EraserMode.stroke)
                }
                .pickerStyle(.segmented)
                .frame(width: 300)
            case .lasso:
                Text("Circle what you wrote to select it, then drag it to move it.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            case .text:
                colors
                separator
                HStack(spacing: 8) {
                    InsertImageButtons(onInsert: onInsertImage)
                }
                .buttonStyle(.bordered)
                .tint(.primary)
            }
        }
        .padding(.horizontal, 12)
        .frame(maxHeight: .infinity)
    }

    private var separator: some View {
        Divider()
            .frame(height: 26)
            .padding(.horizontal, 6)
    }

    /// The three preferred widths (STR-6). Tapping the selected one adjusts it.
    private func widths(for tool: ToolKind) -> some View {
        let presets = model.widthPresets[tool] ?? []
        let selected = model.widthIndex[tool] ?? 0
        return HStack(spacing: 2) {
            ForEach(presets.indices, id: \.self) { index in
                Button {
                    if index == selected {
                        isEditingWidth = true
                    } else {
                        model.widthIndex[tool] = index
                    }
                } label: {
                    Circle()
                        .fill(Color(uiColor: model.color).opacity(tool == .highlighter ? 0.5 : 1))
                        .frame(width: WidthPopover.dotSize(presets[index], tool: tool), height: WidthPopover.dotSize(presets[index], tool: tool))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(BarButtonStyle(isHighlighted: index == selected))
                .accessibilityLabel(Text("Width"))
                .accessibilityValue(Text(verbatim: "\(index + 1)"))
                .accessibilityAddTraits(index == selected ? .isSelected : [])
            }
        }
        .popover(isPresented: $isEditingWidth) {
            WidthPopover(model: model, tool: tool)
                .presentationCompactAdaptation(.popover)
        }
    }

    private var colors: some View {
        HStack(spacing: 0) {
            ForEach(model.palette.indices, id: \.self) { index in
                Button {
                    model.colorIndex = index
                } label: {
                    Circle()
                        .fill(Color(uiColor: model.palette[index]))
                        .frame(width: 28, height: 28)
                        .overlay { Circle().strokeBorder(Color.primary.opacity(0.15), lineWidth: 1) }
                        .padding(4)
                        .overlay {
                            Circle().strokeBorder(Color.primary, lineWidth: model.colorIndex == index ? 2.5 : 0)
                        }
                        .frame(width: 44, height: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Color \(index + 1)"))
                .accessibilityAddTraits(model.colorIndex == index ? .isSelected : [])
            }
        }
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

    /// The ruler is a switch, not a tool: it stays on while you write (STR-4).
    private var rulerButton: some View {
        Button {
            model.isRulerActive.toggle()
        } label: {
            Image(systemName: "ruler")
                .font(.system(size: 19, weight: .medium))
                .frame(width: 48, height: 44)
        }
        .buttonStyle(BarButtonStyle(isSelected: model.isRulerActive))
        .accessibilityLabel(Text("Ruler"))
        .accessibilityAddTraits(model.isRulerActive ? .isSelected : [])
    }
}

/// An icon button of the editor bar, with a full 44 pt target.
struct BarButton: View {
    let title: LocalizedStringKey
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 19, weight: .medium))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(BarButtonStyle())
        .accessibilityLabel(Text(title))
    }
}

/// Bar buttons react on the whole target and show clearly which one is on.
struct BarButtonStyle: ButtonStyle {
    /// Filled with the accent color: the current tool.
    var isSelected = false
    /// Softly tinted: the current width.
    var isHighlighted = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isSelected ? AnyShapeStyle(Color.white) : AnyShapeStyle(.foreground))
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(fill(isPressed: configuration.isPressed))
                    .padding(.vertical, 3)
                    .padding(.horizontal, 2)
            }
            .contentShape(.rect)
            .opacity(configuration.isPressed && isSelected ? 0.8 : 1)
    }

    private func fill(isPressed: Bool) -> Color {
        if isSelected { return .accentColor }
        if isPressed { return Color.primary.opacity(0.16) }
        return Color.primary.opacity(isHighlighted ? 0.1 : 0)
    }
}

/// Adjusts the selected width preset of an inking tool (STR-6).
struct WidthPopover: View {
    @Bindable var model: EditorModel
    let tool: ToolKind

    var body: some View {
        let index = model.widthIndex[tool] ?? 0
        let width = model.widthPresets[tool]?[index] ?? Self.range(for: tool).lowerBound
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Width")
                    .font(.headline)
                Spacer()
                Text(verbatim: Double(width).formatted(.number.precision(.fractionLength(1))))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Capsule()
                .fill(Color(uiColor: model.color).opacity(tool == .highlighter ? 0.5 : 1))
                .frame(height: min(width, 40))
                .frame(height: 40)
            Slider(value: widthBinding(index: index), in: Self.range(for: tool))
        }
        .padding(20)
        .frame(width: 280)
    }

    static func range(for tool: ToolKind) -> ClosedRange<CGFloat> {
        tool == .highlighter ? 5...40 : 0.5...12
    }

    static func dotSize(_ width: CGFloat, tool: ToolKind) -> CGFloat {
        let range = range(for: tool)
        let normalized = (min(max(width, range.lowerBound), range.upperBound) - range.lowerBound) / (range.upperBound - range.lowerBound)
        return 5 + normalized * 23
    }

    private func widthBinding(index: Int) -> Binding<CGFloat> {
        Binding {
            model.widthPresets[tool]?[index] ?? Self.range(for: tool).lowerBound
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
