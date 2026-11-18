import NotyCore
import PencilKit
import SwiftUI
import UIKit
import os

private let log = Logger(subsystem: "io.github.paluello.noty", category: "canvas")

/// The ink of the whole notebook. With the Text tool it hands touches to the
/// text boxes and images underneath (ADR-0014).
final class InkCanvasView: PKCanvasView {
    weak var elementContainer: UIView?
    var routesTouchesToElements = false

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if routesTouchesToElements, let container = elementContainer,
           let hit = container.hitTest(convert(point, to: container), with: event), hit !== container {
            return hit
        }
        return super.hitTest(point, with: event)
    }
}

/// Shows a notebook as a continuous vertical stack of A4 pages (ADR-0006).
///
/// One `PKCanvasView` holds the ink of every page and is itself the scroll
/// view (ADR-0020): PencilKit draws, scrolls and zooms natively, so strokes
/// appear without delay and are re-rendered sharp at any zoom. The paper and
/// the text/image layers sit in an underlay that follows the zoom.
/// On disk every page keeps its own drawing (ADR-0004): the ink is split by
/// page when saving, about a second after the last stroke.
public final class NotebookCanvasViewController: UIViewController {
    static let saveDelay: Duration = .seconds(1)
    /// Writing below this distance from the bottom of the last page adds a new page.
    static let autoNewPageThreshold: CGFloat = 120
    /// Zoom range, relative to the page fitting the screen width: zooming
    /// out below the fit shows the page smaller, centered on the desk.
    static let minimumZoom: CGFloat = 0.3
    static let maximumZoom: CGFloat = 5
    /// Text boxes are rasterized at most at this scale.
    static let maximumElementScale: CGFloat = 10

    let package: NotebookPackage
    private(set) var manifest: NotebookManifest
    let model: EditorModel

    private let canvas = InkCanvasView()
    private let underlay = UIView()
    private let paperView = PaperView()
    private var elementLayers: [Int: ElementLayerView] = [:]
    // Playback (AUD-2): the real drawing, while the canvas shows a dimmed copy.
    private var playbackDate: Date?
    private var originalDrawing: PKDrawing?
    private var dimmedCount: Int?
    private let seekTap = UITapGestureRecognizer()
    /// Stroke count when the Pencil touched down, to recognize only new strokes.
    private var strokeCountAtToolStart: Int?
    private var isUsingTool = false
    // Saving: which pages changed since the last write.
    private var inkIsDirty = false
    private var touchedPages: Set<Int> = []
    private var savedSignatures: [Int] = []
    /// Pages whose file could not be read: never overwritten with nothing.
    private var unreadablePages: Set<UUID> = []
    private var saveTask: Task<Void, Never>?
    private var isLoadingDrawing = false
    private var appliedToolKey: String?
    private var lastLayoutWidth: CGFloat = 0

    private var pageSize: CGSize {
        let size = PageGeometry.size(for: manifest.orientation)
        return CGSize(width: size.width, height: size.height)
    }

    private var pageCount: Int { manifest.pageIDs.count }

    /// Size of all the pages, in page points (zoom 1).
    private var stackSize: CGSize {
        CGSize(width: pageSize.width, height: pageSize.height * CGFloat(pageCount))
    }

    public init(package: NotebookPackage, model: EditorModel) throws {
        self.package = package
        self.manifest = try package.readManifest()
        self.model = model
        super.init(nibName: nil, bundle: nil)
        model.canvasController = self
        model.pageIDs = manifest.pageIDs
        model.paper = manifest.paper
        model.paperColor = manifest.paperColor
        model.paperSpacing = manifest.paperSpacing
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    // MARK: - View lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        canvas.frame = view.bounds
        canvas.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.delegate = self
        canvas.contentInsetAdjustmentBehavior = .never
        canvas.showsHorizontalScrollIndicator = false
        canvas.alwaysBounceVertical = true
        // Pages are always light, even in dark mode (UI-3); otherwise PencilKit
        // inverts ink colors and black strokes turn white.
        canvas.overrideUserInterfaceStyle = .light
        view.addSubview(canvas)

        // The underlay scales around its top-left corner, like the ink.
        underlay.layer.anchorPoint = .zero
        underlay.isUserInteractionEnabled = false
        underlay.addSubview(paperView)
        canvas.insertSubview(underlay, at: 0)
        canvas.elementContainer = underlay

        loadInk()
        layoutPages()
        applySettings()

        let touch = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        let undoTap = UITapGestureRecognizer(target: self, action: #selector(undo))
        undoTap.numberOfTouchesRequired = 2
        undoTap.allowedTouchTypes = touch
        let redoTap = UITapGestureRecognizer(target: self, action: #selector(redo))
        redoTap.numberOfTouchesRequired = 3
        redoTap.allowedTouchTypes = touch
        canvas.addGestureRecognizer(undoTap)
        canvas.addGestureRecognizer(redoTap)
        seekTap.addTarget(self, action: #selector(handleSeekTap))
        seekTap.isEnabled = false
        canvas.addGestureRecognizer(seekTap)

        let pencilInteraction = UIPencilInteraction(delegate: self)
        view.addInteraction(pencilInteraction)

        NotificationCenter.default.addObserver(
            self, selector: #selector(saveNow),
            name: UIApplication.didEnterBackgroundNotification, object: nil
        )
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applyInsets()
        let width = view.bounds.width
        guard width > 0, pageSize.width > 0, width != lastLayoutWidth else { return }
        let isFirstLayout = lastLayoutWidth == 0
        let page = model.currentPage - 1
        lastLayoutWidth = width

        // Fit the page width to the screen; zoom in from there.
        let fit = width / pageSize.width
        canvas.minimumZoomScale = fit * Self.minimumZoom
        canvas.maximumZoomScale = fit * Self.maximumZoom
        canvas.zoomScale = fit
        updateContentSize()
        if isFirstLayout, let initialPage = model.initialPage {
            scrollToPage(initialPage, animated: false)
            model.initialPage = nil
        } else if isFirstLayout {
            canvas.contentOffset = CGPoint(x: -canvas.contentInset.left, y: -canvas.contentInset.top)
        } else {
            scrollToPage(page, animated: false)
        }
        updateElementScale()
        updateVisiblePages()
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        saveNow()
    }

    // MARK: - Layout

    /// Frame of a page in the underlay, in page points.
    private func frameForPage(at index: Int) -> CGRect {
        CGRect(x: 0, y: CGFloat(index) * pageSize.height, width: pageSize.width, height: pageSize.height)
    }

    /// Lays out the paper for the current page list.
    private func layoutPages() {
        underlay.bounds = CGRect(origin: .zero, size: stackSize)
        underlay.center = .zero
        paperView.frame = underlay.bounds
        paperView.update(PaperConfiguration(
            style: manifest.paper, color: manifest.paperColor, spacing: manifest.paperSpacing.map { CGFloat($0) },
            pageSize: pageSize, pageCount: pageCount
        ))
        updateContentSize()
    }

    private func updateContentSize() {
        let zoom = canvas.zoomScale
        let size = CGSize(width: stackSize.width * zoom, height: stackSize.height * zoom)
        if abs(canvas.contentSize.width - size.width) > 0.5 || abs(canvas.contentSize.height - size.height) > 0.5 {
            canvas.contentSize = size
        }
        updateUnderlayZoom()
        applyInsets()
    }

    private func updateUnderlayZoom() {
        let zoom = canvas.zoomScale
        underlay.transform = CGAffineTransform(scaleX: zoom, y: zoom)
    }

    /// Height of the editor bar floating over the top of the canvas (ADR-0023).
    /// The first page starts below it; while scrolling, pages pass under it.
    var chromeInset: CGFloat = 0 {
        didSet {
            guard chromeInset != oldValue, isViewLoaded else { return }
            applyInsets()
        }
    }

    /// Below the fit zoom the pages are narrower than the screen: the side
    /// insets keep them centered instead of pinned to the left edge.
    private func applyInsets() {
        let zoom = canvas.zoomScale
        let width = stackSize.width * zoom
        let height = stackSize.height * zoom
        let chromeTop = view.safeAreaInsets.top + chromeInset
        let bottom = view.safeAreaInsets.bottom + 80
        let side = max(0, (canvas.bounds.width - width) / 2).rounded(.down)
        let centering = max(0, (canvas.bounds.height - chromeTop - bottom - height) / 2).rounded(.down)
        let insets = UIEdgeInsets(top: chromeTop + centering, left: side, bottom: bottom, right: side)
        let old = canvas.contentInset
        guard old != insets else { return }
        // At the top of the notebook, stay at the top when the bar appears or hides.
        let wasAtTop = canvas.contentOffset.y <= -old.top + 1
        canvas.contentInset = insets
        canvas.verticalScrollIndicatorInsets = UIEdgeInsets(top: chromeTop, left: 0, bottom: bottom, right: 0)
        if wasAtTop, !canvas.isTracking, !canvas.isZooming {
            canvas.contentOffset.y = -insets.top
        }
    }

    /// Text boxes are re-rendered at the current zoom so they stay sharp;
    /// the ink and the paper take care of themselves.
    private func updateElementScale() {
        for layer in elementLayers.values {
            setContentScale(elementScale, on: layer)
        }
    }

    private var elementScale: CGFloat {
        let screenScale = view.window?.screen.scale ?? traitCollection.displayScale
        return min(screenScale * max(canvas.zoomScale, 1), Self.maximumElementScale)
    }

    private func setContentScale(_ scale: CGFloat, on view: UIView) {
        view.contentScaleFactor = scale
        for subview in view.subviews {
            setContentScale(scale, on: subview)
        }
    }

    // MARK: - Visible pages

    /// Pages on screen right now.
    private var visiblePages: ClosedRange<Int>? {
        let zoom = canvas.zoomScale
        guard pageCount > 0, zoom > 0, pageSize.height > 0 else { return nil }
        let top = canvas.contentOffset.y / zoom
        let bottom = (canvas.contentOffset.y + canvas.bounds.height) / zoom
        let first = min(max(Int((top / pageSize.height).rounded(.down)), 0), pageCount - 1)
        let last = min(max(Int((bottom / pageSize.height).rounded(.down)), first), pageCount - 1)
        return first...last
    }

    private func updateVisiblePages() {
        guard let visible = visiblePages else { return }
        let wanted = max(0, visible.lowerBound - 1)...min(pageCount - 1, visible.upperBound + 1)

        for index in elementLayers.keys where !wanted.contains(index) {
            detachElementLayer(from: index)
        }
        for index in wanted where elementLayers[index] == nil {
            attachElementLayer(to: index)
        }

        let zoom = canvas.zoomScale
        let middle = (canvas.contentOffset.y + canvas.bounds.height / 2) / zoom
        let page = min(max(Int((middle / pageSize.height).rounded(.down)), 0), pageCount - 1) + 1
        if model.currentPage != page {
            model.currentPage = page
        }
    }

    /// Text boxes and images sit between the paper and the ink (ADR-0014).
    private func attachElementLayer(to index: Int) {
        let layer = ElementLayerView(pageID: manifest.pageIDs[index], package: package, frame: frameForPage(at: index))
        layer.onChange = { [weak self] in self?.scheduleSave() }
        layer.isEditable = model.tool == .text
        layer.textColorHex = model.color.hex
        layer.textFontSize = model.textFontSize
        layer.onSelectText = { [weak self, weak layer] size in
            guard let self, let layer else { return }
            self.textSelectionChanged(in: layer, size: size)
        }
        underlay.addSubview(layer)
        setContentScale(elementScale, on: layer)
        elementLayers[index] = layer
    }

    private func detachElementLayer(from index: Int) {
        guard let layer = elementLayers.removeValue(forKey: index) else { return }
        layer.endEditing(true)
        layer.save()
        layer.removeFromSuperview()
        updateTextSelection()
    }

    /// One text box at a time: selecting one deselects the others, and the bar
    /// shows the size of the selected box.
    private func textSelectionChanged(in layer: ElementLayerView, size: Double?) {
        if size != nil {
            for other in elementLayers.values where other !== layer {
                other.clearSelection()
            }
        }
        if let size, model.textFontSize != size {
            model.textFontSize = size
        }
        updateTextSelection(size != nil)
    }

    private func updateTextSelection(_ isSelectedHere: Bool = false) {
        let isSelected = isSelectedHere || elementLayers.values.contains { $0.selectedTextSize != nil }
        if model.isTextSelected != isSelected {
            model.isTextSelected = isSelected
        }
    }

    func toggleList(_ style: TextListStyle) {
        for layer in elementLayers.values where layer.toggleList(style) {
            return
        }
    }

    // MARK: - Ink: one drawing on screen, one file per page

    private func pageOffset(_ index: Int) -> CGAffineTransform {
        CGAffineTransform(translationX: 0, y: CGFloat(index) * pageSize.height)
    }

    /// Reads every page and stacks the drawings into the canvas.
    private func loadInk() {
        var strokes: [PKStroke] = []
        unreadablePages = []
        for (index, id) in manifest.pageIDs.enumerated() {
            do {
                guard let data = try package.readPage(id) else { continue }
                let drawing = try PKDrawing(data: data)
                strokes.append(contentsOf: drawing.transformed(using: pageOffset(index)).strokes)
            } catch {
                log.error("Failed to load page \(index): \(error)")
                unreadablePages.insert(id)
            }
        }
        let drawing = PKDrawing(strokes: strokes)
        setDrawing(drawing)
        savedSignatures = splitByPage(drawing).map { Self.signature(of: $0) }
        inkIsDirty = false
        touchedPages = []
        originalDrawing = nil
        dimmedCount = nil
        dimFutureInk()
    }

    /// Changes the canvas content without marking it as edited.
    private func setDrawing(_ drawing: PKDrawing) {
        isLoadingDrawing = true
        canvas.drawing = drawing
        isLoadingDrawing = false
    }

    /// Strokes of each page, still in canvas coordinates. A stroke belongs to
    /// the page that contains its middle.
    private func splitByPage(_ drawing: PKDrawing) -> [[PKStroke]] {
        var pages = Array(repeating: [PKStroke](), count: pageCount)
        guard pageCount > 0, pageSize.height > 0 else { return pages }
        for stroke in drawing.strokes {
            let bounds = stroke.renderBounds
            let middle = bounds.isNull || !bounds.midY.isFinite ? 0 : bounds.midY
            let index = min(max(Int((middle / pageSize.height).rounded(.down)), 0), pageCount - 1)
            pages[index].append(stroke)
        }
        return pages
    }

    /// Cheap fingerprint of a page's ink, to write only the pages that changed.
    private static func signature(of strokes: [PKStroke]) -> Int {
        var hasher = Hasher()
        hasher.combine(strokes.count)
        for stroke in strokes {
            let bounds = stroke.renderBounds
            hasher.combine(stroke.path.creationDate)
            hasher.combine(stroke.path.count)
            hasher.combine(bounds.origin.x)
            hasher.combine(bounds.origin.y)
            hasher.combine(bounds.size.width)
            hasher.combine(bounds.size.height)
            hasher.combine(stroke.ink.inkType.rawValue)
            hasher.combine(stroke.ink.color)
            if let mask = stroke.mask {
                let maskBounds = mask.bounds
                hasher.combine(maskBounds.origin.x)
                hasher.combine(maskBounds.origin.y)
                hasher.combine(maskBounds.size.width)
                hasher.combine(maskBounds.size.height)
            }
        }
        return hasher.finalize()
    }

    /// Writes the pages whose ink changed. Returns `true` if a file was written.
    private func saveInk() -> Bool {
        // During playback the canvas shows a dimmed copy: nothing to save.
        guard inkIsDirty, playbackDate == nil else { return false }
        let pages = splitByPage(canvas.drawing)
        var wrote = false
        var failed = false
        for (index, strokes) in pages.enumerated() {
            let signature = Self.signature(of: strokes)
            let changed = !savedSignatures.indices.contains(index) || savedSignatures[index] != signature
            guard changed || touchedPages.contains(index) else { continue }
            let id = manifest.pageIDs[index]
            if strokes.isEmpty, unreadablePages.contains(id) { continue }
            let data = PKDrawing(strokes: strokes).transformed(using: pageOffset(index).inverted()).dataRepresentation()
            do {
                // A page that was on screen but did not really change keeps its file.
                if !changed, try package.readPage(id) == data { continue }
                try package.writePage(id, data: data)
                unreadablePages.remove(id)
                if savedSignatures.indices.contains(index) {
                    savedSignatures[index] = signature
                }
                wrote = true
            } catch {
                log.error("Failed to save page \(index): \(error)")
                failed = true
            }
        }
        if !failed {
            inkIsDirty = false
            touchedPages = []
        }
        return wrote
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: Self.saveDelay)
            guard !Task.isCancelled, let self else { return }
            if self.isUsingTool {
                // Never save in the middle of a stroke: it would make the ink stutter.
                self.scheduleSave()
            } else {
                self.saveNow()
            }
        }
    }

    @objc func saveNow() {
        saveTask?.cancel()
        let dirtyLayers = elementLayers.values.filter(\.isDirty)
        let wroteInk = saveInk()
        guard wroteInk || !dirtyLayers.isEmpty else { return }
        dirtyLayers.forEach { $0.save() }
        manifest.modifiedAt = .now
        writeManifest()
    }

    private func writeManifest() {
        do {
            try package.writeManifest(manifest)
        } catch {
            log.error("Failed to save manifest: \(error)")
        }
        model.pageIDs = manifest.pageIDs
        model.revision += 1
    }

    // MARK: - Settings

    /// Applies the tool and the input rules of the model to the canvas (ADR-0008):
    /// - Pencil only: the Pencil writes, one finger scrolls, two fingers zoom;
    /// - fingers write too: two fingers scroll;
    /// - Text tool or listening: nothing writes, one finger scrolls.
    func applySettings() {
        guard isViewLoaded else { return }
        let isTextTool = model.tool == .text
        let inkIsLive = !isTextTool && playbackDate == nil

        // Setting the same tool again would interrupt a stroke in progress.
        let toolKey = model.toolKey
        if toolKey != appliedToolKey {
            appliedToolKey = toolKey
            canvas.tool = model.pkTool
        }
        let policy: PKCanvasViewDrawingPolicy = inkIsLive ? model.drawingPolicy : .pencilOnly
        if canvas.drawingPolicy != policy {
            canvas.drawingPolicy = policy
        }
        if canvas.drawingGestureRecognizer.isEnabled != inkIsLive {
            canvas.drawingGestureRecognizer.isEnabled = inkIsLive
        }
        if canvas.isRulerActive != model.isRulerActive {
            canvas.isRulerActive = model.isRulerActive
        }

        // With the Text tool the ink lets touches through to the text boxes.
        canvas.routesTouchesToElements = isTextTool
        underlay.isUserInteractionEnabled = isTextTool
        for layer in elementLayers.values {
            if layer.isEditable != isTextTool {
                layer.isEditable = isTextTool
            }
            layer.textColorHex = model.color.hex
            layer.textFontSize = model.textFontSize
        }
    }

    // MARK: - Commands

    @objc func undo() { canvas.undoManager?.undo() }
    @objc func redo() { canvas.undoManager?.redo() }

    func scrollToPage(_ index: Int, animated: Bool) {
        guard index >= 0, index < pageCount else { return }
        let top = -canvas.contentInset.top
        let maxOffset = max(canvas.contentSize.height - canvas.bounds.height + canvas.contentInset.bottom, top)
        let y = min(max(frameForPage(at: index).minY * canvas.zoomScale, top), maxOffset)
        canvas.setContentOffset(CGPoint(x: canvas.contentOffset.x, y: y), animated: animated)
        if !animated {
            updateVisiblePages()
        }
    }

    // MARK: - Playback (AUD-2)

    /// Dims the ink written after `date`; `nil` ends playback and restores the pages.
    func updatePlayback(_ date: Date?) {
        guard date != playbackDate else { return }
        if playbackDate == nil {
            saveNow()
            // Undo must not bring back strokes into the dimmed copy.
            canvas.undoManager?.removeAllActions()
        }
        playbackDate = date
        seekTap.isEnabled = date != nil
        if date == nil {
            if let originalDrawing {
                setDrawing(originalDrawing)
            }
            originalDrawing = nil
            dimmedCount = nil
        } else {
            dimFutureInk()
        }
        applySettings()
    }

    private func dimFutureInk() {
        guard let date = playbackDate else { return }
        let original = originalDrawing ?? canvas.drawing
        originalDrawing = original
        let future = original.strokes.filter { $0.path.creationDate > date }.count
        guard dimmedCount != future else { return }
        dimmedCount = future
        var dimmed = original
        dimmed.strokes = original.strokes.map { stroke in
            guard stroke.path.creationDate > date else { return stroke }
            var copy = stroke
            copy.ink = PKInk(stroke.ink.inkType, color: stroke.ink.color.withAlphaComponent(0.15))
            return copy
        }
        setDrawing(dimmed)
    }

    /// During playback, tapping a stroke jumps to when it was written.
    @objc private func handleSeekTap(_ gesture: UITapGestureRecognizer) {
        let zoom = canvas.zoomScale
        guard zoom > 0 else { return }
        let location = gesture.location(in: canvas)
        let point = CGPoint(x: location.x / zoom, y: location.y / zoom)
        let drawing = originalDrawing ?? canvas.drawing
        let hit = drawing.strokes.last { $0.renderBounds.insetBy(dx: -12, dy: -12).contains(point) }
        if let hit {
            model.onSeek?(hit.path.creationDate)
        }
    }

    /// Adds an image to the page in the middle of the screen (STR-9).
    func insertImage(_ data: Data) {
        guard let image = UIImage(data: data), let jpeg = Self.prepareImage(image) else { return }
        let index = min(max(model.currentPage - 1, 0), pageCount - 1)
        if elementLayers[index] == nil {
            attachElementLayer(to: index)
        }
        do {
            let fileName = try package.writeAsset(jpeg, fileExtension: "jpg")
            elementLayers[index]?.addImage(fileName: fileName, size: image.size)
            saveNow()
        } catch {
            log.error("Failed to insert image: \(error)")
        }
    }

    /// Shrinks big photos to at most 2000 px, so notebooks stay light.
    private static func prepareImage(_ image: UIImage) -> Data? {
        let maxSide: CGFloat = 2000
        let pixelSize = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        let scale = min(1, maxSide / max(pixelSize.width, pixelSize.height))
        let size = CGSize(width: pixelSize.width * scale, height: pixelSize.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }.jpegData(compressionQuality: 0.85)
    }

    /// Changes the paper of every page (PAG-5).
    func setPaper(_ style: PaperStyle, color: PaperColor, spacing: Double?) {
        guard style != manifest.paper || color != manifest.paperColor || spacing != manifest.paperSpacing else { return }
        saveNow()
        manifest.paper = style
        manifest.paperColor = color
        manifest.paperSpacing = spacing
        model.paper = style
        model.paperColor = color
        model.paperSpacing = spacing
        manifest.modifiedAt = .now
        writeManifest()
        layoutPages()
    }

    /// Rebuilds the canvas after the page list changed (PAG-4).
    private func reloadPages() {
        for index in Array(elementLayers.keys) {
            detachElementLayer(from: index)
        }
        loadInk()
        canvas.undoManager?.removeAllActions()
        layoutPages()
        updateVisiblePages()
    }

    private func changePages(_ change: (inout [UUID]) throws -> Void) {
        saveNow()
        do {
            try change(&manifest.pageIDs)
        } catch {
            log.error("Failed to change pages: \(error)")
        }
        manifest.modifiedAt = .now
        writeManifest()
        reloadPages()
    }

    func insertPage(at index: Int, scrollToIt: Bool) {
        let index = min(max(index, 0), manifest.pageIDs.count)
        if index == manifest.pageIDs.count {
            // Appending keeps the ink, the undo history and the stroke in progress.
            manifest.pageIDs.append(UUID())
            savedSignatures.append(Self.signature(of: []))
            manifest.modifiedAt = .now
            writeManifest()
            layoutPages()
            updateVisiblePages()
        } else {
            changePages { $0.insert(UUID(), at: index) }
        }
        if scrollToIt {
            scrollToPage(index, animated: true)
        }
    }

    func duplicatePage(at index: Int) {
        guard manifest.pageIDs.indices.contains(index) else { return }
        changePages { ids in
            let copy = UUID()
            try package.copyPage(ids[index], to: copy)
            ids.insert(copy, at: index + 1)
        }
    }

    func deletePage(at index: Int) {
        guard manifest.pageIDs.indices.contains(index) else { return }
        changePages { ids in
            let removed = ids.remove(at: index)
            try package.deletePage(removed)
            // A notebook always has at least one page.
            if ids.isEmpty {
                ids.append(UUID())
            }
        }
    }

    func movePage(from source: Int, to destination: Int) {
        guard manifest.pageIDs.indices.contains(source), source != destination else { return }
        changePages { ids in
            let id = ids.remove(at: source)
            ids.insert(id, at: min(max(destination, 0), ids.count))
        }
    }
}

// MARK: - Shape recognition (STR-7, ADR-0013)

extension NotebookCanvasViewController {
    /// After a stroke, if the Pencil was held still at its end, replaces the
    /// stroke with the clean shape it resembles.
    func recognizeShape() {
        let countBefore = strokeCountAtToolStart ?? canvas.drawing.strokes.count
        strokeCountAtToolStart = nil
        // Only the stroke just written: a gesture that added nothing must not
        // reshape an older stroke.
        guard model.shapeRecognition, model.tool.isInking, canvas.drawing.strokes.count > countBefore,
              let stroke = canvas.drawing.strokes.last
        else { return }
        let points = Array(stroke.path)
        let locations = points.map(\.location)
        let liftTime = Date.now.timeIntervalSince(stroke.path.creationDate)
        guard let hold = ShapeRecognizer.holdStart(locations: locations, times: points.map(\.timeOffset), liftTime: liftTime),
              let shape = ShapeRecognizer.recognize(Array(locations[..<hold]))
        else { return }

        let template = points[hold / 2]
        let newPoints = ShapeRecognizer.points(for: shape).enumerated().map { index, location in
            PKStrokePoint(
                location: location,
                timeOffset: TimeInterval(index) * 0.004,
                size: template.size,
                opacity: template.opacity,
                force: template.force,
                azimuth: template.azimuth,
                altitude: template.altitude
            )
        }
        let path = PKStrokePath(controlPoints: newPoints, creationDate: stroke.path.creationDate)
        var drawing = canvas.drawing
        drawing.strokes[drawing.strokes.count - 1] = PKStroke(ink: stroke.ink, path: path, transform: stroke.transform, mask: stroke.mask)
        canvas.drawing = drawing
    }
}

// MARK: - UIPencilInteractionDelegate

extension NotebookCanvasViewController: UIPencilInteractionDelegate {
    public func pencilInteraction(_ interaction: UIPencilInteraction, didReceiveTap tap: UIPencilInteraction.Tap) {
        model.handlePencilTap()
    }

    public func pencilInteraction(_ interaction: UIPencilInteraction, didReceiveSqueeze squeeze: UIPencilInteraction.Squeeze) {
        if squeeze.phase == .ended {
            model.handlePencilSqueeze()
        }
    }
}

// MARK: - PKCanvasViewDelegate (and its scroll view)

extension NotebookCanvasViewController: PKCanvasViewDelegate {
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateVisiblePages()
    }

    public func scrollViewDidZoom(_ scrollView: UIScrollView) {
        updateUnderlayZoom()
        applyInsets()
    }

    public func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        updateContentSize()
        updateElementScale()
        updateVisiblePages()
    }

    public func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
        isUsingTool = true
        strokeCountAtToolStart = canvasView.drawing.strokes.count
    }

    public func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
        isUsingTool = false
        recognizeShape()
    }

    public func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        guard !isLoadingDrawing else { return }
        inkIsDirty = true
        // The change is where the user is working; the fingerprints catch the rest.
        if let visible = visiblePages {
            touchedPages.formUnion(visible)
        }
        scheduleSave()

        let bounds = canvasView.drawing.bounds
        if model.autoNewPage, !bounds.isNull, !bounds.isEmpty,
           bounds.maxY > stackSize.height - Self.autoNewPageThreshold {
            insertPage(at: pageCount, scrollToIt: false)
        }
    }
}

// MARK: - SwiftUI

/// SwiftUI wrapper around `NotebookCanvasViewController`.
public struct NotebookCanvas: UIViewControllerRepresentable {
    let package: NotebookPackage
    let model: EditorModel
    /// Space taken at the top by the floating editor bar (ADR-0023).
    let topInset: CGFloat

    public init(package: NotebookPackage, model: EditorModel, topInset: CGFloat = 0) {
        self.package = package
        self.model = model
        self.topInset = topInset
    }

    public func makeUIViewController(context: Context) -> UIViewController {
        do {
            let controller = try NotebookCanvasViewController(package: package, model: model)
            controller.chromeInset = topInset
            return controller
        } catch {
            log.error("Failed to open notebook: \(error)")
            return UIHostingController(rootView: Text(verbatim: "⚠︎"))
        }
    }

    public func updateUIViewController(_ controller: UIViewController, context: Context) {
        guard let controller = controller as? NotebookCanvasViewController else { return }
        // Reading the model here makes SwiftUI call this again when a setting changes.
        _ = model.toolKey
        _ = model.isRulerActive
        _ = model.fingerDrawing
        _ = model.textFontSize
        controller.chromeInset = topInset
        controller.updatePlayback(model.playbackDate)
        controller.applySettings()
    }
}
