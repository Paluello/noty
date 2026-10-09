import NotyCore
import PencilKit
import SwiftUI
import UIKit
import os

private let log = Logger(subsystem: "io.github.paluello.noty", category: "canvas")

/// Shows a notebook as a vertical stack of A4 pages (ADR-0006).
///
/// Every page has a cheap `PaperView`; only the pages near the viewport get a
/// `PKCanvasView`, taken from a small pool and recycled while scrolling.
/// Changes are saved per page, about a second after the last stroke (ADR-0004).
public final class NotebookCanvasViewController: UIViewController {
    static let pageGap: CGFloat = 28
    static let margin: CGFloat = 28
    static let saveDelay: Duration = .seconds(1)
    /// Writing below this distance from the bottom of the last page adds a new page.
    static let autoNewPageThreshold: CGFloat = 120

    let package: NotebookPackage
    private(set) var manifest: NotebookManifest
    let model: EditorModel

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private var paperViews: [PaperView] = []
    private let paperImages = PaperImageCache()
    private var activeCanvases: [Int: PKCanvasView] = [:]
    private var canvasPool: [PKCanvasView] = []
    private var dirtyPages: Set<Int> = []
    private var saveTask: Task<Void, Never>?
    private var isLoadingDrawing = false
    private var lastLayoutWidth: CGFloat = 0

    private var pageSize: CGSize {
        let size = PageGeometry.size(for: manifest.orientation)
        return CGSize(width: size.width, height: size.height)
    }

    public init(package: NotebookPackage, model: EditorModel) throws {
        self.package = package
        self.manifest = try package.readManifest()
        self.model = model
        super.init(nibName: nil, bundle: nil)
        model.canvasController = self
        model.pageIDs = manifest.pageIDs
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    // MARK: - View lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        scrollView.frame = view.bounds
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scrollView.delegate = self
        scrollView.backgroundColor = .clear
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.showsHorizontalScrollIndicator = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        // Pages are always light, even in dark mode (UI-3); otherwise PencilKit
        // inverts ink colors and black strokes turn white.
        contentView.overrideUserInterfaceStyle = .light

        buildPages()

        let undoTap = UITapGestureRecognizer(target: self, action: #selector(undo))
        undoTap.numberOfTouchesRequired = 2
        let redoTap = UITapGestureRecognizer(target: self, action: #selector(redo))
        redoTap.numberOfTouchesRequired = 3
        scrollView.addGestureRecognizer(undoTap)
        scrollView.addGestureRecognizer(redoTap)

        let pencilInteraction = UIPencilInteraction(delegate: self)
        view.addInteraction(pencilInteraction)

        NotificationCenter.default.addObserver(
            self, selector: #selector(saveNow),
            name: UIApplication.didEnterBackgroundNotification, object: nil
        )
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let width = view.bounds.width
        guard width > 0, width != lastLayoutWidth else { return }
        let isFirstLayout = lastLayoutWidth == 0
        let page = model.currentPage - 1
        lastLayoutWidth = width

        // Fit the page width to the screen; zoom up to 4x from there.
        let fit = width / contentView.bounds.width
        scrollView.minimumZoomScale = fit
        scrollView.maximumZoomScale = fit * 4
        scrollView.zoomScale = fit
        applyInsets()
        if isFirstLayout {
            scrollView.contentOffset = CGPoint(x: 0, y: -scrollView.contentInset.top)
        } else {
            scrollToPage(page, animated: false)
        }
        updateRenderScale()
        updateVisiblePages()
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        saveNow()
    }

    // MARK: - Layout

    private func frameForPage(at index: Int) -> CGRect {
        CGRect(
            x: Self.margin,
            y: Self.pageGap + CGFloat(index) * (pageSize.height + Self.pageGap),
            width: pageSize.width,
            height: pageSize.height
        )
    }

    private func buildPages() {
        for index in manifest.pageIDs.indices {
            addPaperView(at: index)
        }
        updateContentSize()
    }

    private func addPaperView(at index: Int) {
        let paper = PaperView(style: manifest.paper, frame: frameForPage(at: index))
        paper.show(currentPaperImage)
        contentView.insertSubview(paper, at: 0)
        paperViews.append(paper)
    }

    private func updateContentSize() {
        let size = CGSize(
            width: pageSize.width + Self.margin * 2,
            height: Self.pageGap + CGFloat(paperViews.count) * (pageSize.height + Self.pageGap)
        )
        contentView.bounds = CGRect(origin: .zero, size: size)
        let scaled = CGSize(width: size.width * scrollView.zoomScale, height: size.height * scrollView.zoomScale)
        contentView.center = CGPoint(x: scaled.width / 2, y: scaled.height / 2)
        scrollView.contentSize = scaled
    }

    func applyInsets() {
        let insets = UIEdgeInsets(top: model.topContentInset, left: 0, bottom: view.safeAreaInsets.bottom + 80, right: 0)
        guard scrollView.contentInset != insets else { return }
        scrollView.contentInset = insets
        scrollView.verticalScrollIndicatorInsets = insets
    }

    private var renderScale: CGFloat {
        (view.window?.screen.scale ?? traitCollection.displayScale) * scrollView.zoomScale
    }

    private var currentPaperImage: CGImage? {
        paperImages.image(manifest.paper, size: pageSize, scale: renderScale)
    }

    /// Re-renders paper and ink at the current zoom so they stay sharp.
    private func updateRenderScale() {
        let scale = renderScale
        let paperImage = currentPaperImage
        for paper in paperViews {
            paper.show(paperImage)
        }
        for canvas in activeCanvases.values {
            setContentScale(scale, on: canvas)
        }
    }

    private func setContentScale(_ scale: CGFloat, on view: UIView) {
        view.contentScaleFactor = scale
        for subview in view.subviews {
            setContentScale(scale, on: subview)
        }
    }

    // MARK: - Canvas recycling

    private func updateVisiblePages() {
        guard !paperViews.isEmpty else { return }
        let visible = scrollView.convert(scrollView.bounds, to: contentView)
        let stride = pageSize.height + Self.pageGap
        let first = max(0, Int(floor((visible.minY - Self.pageGap) / stride)) - 1)
        let last = min(paperViews.count - 1, Int(floor((visible.maxY - Self.pageGap) / stride)) + 1)
        guard first <= last else { return }
        let wanted = Set(first...last)

        for index in activeCanvases.keys where !wanted.contains(index) {
            detachCanvas(from: index)
        }
        for index in wanted where activeCanvases[index] == nil {
            attachCanvas(to: index)
        }

        let center = Int(floor((visible.midY - Self.pageGap / 2) / stride))
        let page = min(max(center, 0), paperViews.count - 1) + 1
        if model.currentPage != page {
            model.currentPage = page
            updateRuler()
        }
    }

    /// One ruler, on the page in the middle of the screen (STR-4).
    private func updateRuler() {
        for (index, canvas) in activeCanvases {
            let isActive = model.isRulerActive && index == model.currentPage - 1
            if canvas.isRulerActive != isActive {
                canvas.isRulerActive = isActive
            }
        }
    }

    private func makeCanvas() -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.isScrollEnabled = false
        canvas.delegate = self
        canvas.drawingPolicy = model.drawingPolicy
        return canvas
    }

    private func attachCanvas(to index: Int) {
        let canvas = canvasPool.popLast() ?? makeCanvas()
        canvas.frame = frameForPage(at: index)
        canvas.tool = model.pkTool
        canvas.drawingPolicy = model.drawingPolicy
        canvas.tag = index

        isLoadingDrawing = true
        canvas.drawing = loadDrawing(at: index)
        isLoadingDrawing = false

        contentView.addSubview(canvas)
        setContentScale(renderScale, on: canvas)
        activeCanvases[index] = canvas
        canvas.isRulerActive = model.isRulerActive && index == model.currentPage - 1
    }

    private func detachCanvas(from index: Int) {
        guard let canvas = activeCanvases.removeValue(forKey: index) else { return }
        if dirtyPages.contains(index) {
            save(canvas.drawing, at: index)
        }
        // Undo actions point at this canvas instance, which will show another page next.
        undoManager?.removeAllActions(withTarget: canvas)
        canvas.isRulerActive = false
        canvas.removeFromSuperview()
        isLoadingDrawing = true
        canvas.drawing = PKDrawing()
        isLoadingDrawing = false
        canvasPool.append(canvas)
    }

    // MARK: - Persistence

    private func loadDrawing(at index: Int) -> PKDrawing {
        do {
            guard let data = try package.readPage(manifest.pageIDs[index]) else { return PKDrawing() }
            return try PKDrawing(data: data)
        } catch {
            log.error("Failed to load page \(index): \(error)")
            return PKDrawing()
        }
    }

    private func save(_ drawing: PKDrawing, at index: Int) {
        do {
            try package.writePage(manifest.pageIDs[index], data: drawing.dataRepresentation())
            dirtyPages.remove(index)
        } catch {
            log.error("Failed to save page \(index): \(error)")
        }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: Self.saveDelay)
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    @objc func saveNow() {
        saveTask?.cancel()
        let pending = dirtyPages
        guard !pending.isEmpty else { return }
        for index in pending {
            if let canvas = activeCanvases[index] {
                save(canvas.drawing, at: index)
            }
        }
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

    func apply(tool: PKTool, drawingPolicy: PKCanvasViewDrawingPolicy) {
        for canvas in activeCanvases.values {
            canvas.tool = tool
            canvas.drawingPolicy = drawingPolicy
        }
        for canvas in canvasPool {
            canvas.drawingPolicy = drawingPolicy
        }
        updateRuler()
    }

    // MARK: - Commands

    @objc func undo() { undoManager?.undo() }
    @objc func redo() { undoManager?.redo() }

    func scrollToPage(_ index: Int, animated: Bool) {
        guard paperViews.indices.contains(index) else { return }
        let pageTop = frameForPage(at: index).minY - Self.pageGap / 2
        let maxOffset = max(scrollView.contentSize.height - scrollView.bounds.height + scrollView.contentInset.bottom, -scrollView.contentInset.top)
        let y = min(pageTop * scrollView.zoomScale - scrollView.contentInset.top, maxOffset)
        scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: y), animated: animated)
        if !animated {
            updateVisiblePages()
        }
    }

    /// Rebuilds every page after the page list changed (PAG-4).
    private func reloadPages() {
        for index in Array(activeCanvases.keys) {
            detachCanvas(from: index)
        }
        undoManager?.removeAllActions()
        paperViews.forEach { $0.removeFromSuperview() }
        paperViews.removeAll()
        buildPages()
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
            // Appending is cheap: no need to rebuild the other pages.
            saveNow()
            manifest.pageIDs.append(UUID())
            manifest.modifiedAt = .now
            writeManifest()
            addPaperView(at: paperViews.count)
            updateContentSize()
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

// MARK: - UIScrollViewDelegate

extension NotebookCanvasViewController: UIScrollViewDelegate {
    public func viewForZooming(in scrollView: UIScrollView) -> UIView? { contentView }

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateVisiblePages()
    }

    public func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        updateRenderScale()
        updateVisiblePages()
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

// MARK: - PKCanvasViewDelegate

extension NotebookCanvasViewController: PKCanvasViewDelegate {
    public func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        guard !isLoadingDrawing else { return }
        let index = canvasView.tag
        dirtyPages.insert(index)
        scheduleSave()

        let isLastPage = index == paperViews.count - 1
        let bounds = canvasView.drawing.bounds
        if model.autoNewPage, isLastPage, !bounds.isEmpty, bounds.maxY > pageSize.height - Self.autoNewPageThreshold {
            insertPage(at: paperViews.count, scrollToIt: false)
        }
    }
}

// MARK: - SwiftUI

/// SwiftUI wrapper around `NotebookCanvasViewController`.
public struct NotebookCanvas: UIViewControllerRepresentable {
    let package: NotebookPackage
    let model: EditorModel

    public init(package: NotebookPackage, model: EditorModel) {
        self.package = package
        self.model = model
    }

    public func makeUIViewController(context: Context) -> UIViewController {
        do {
            return try NotebookCanvasViewController(package: package, model: model)
        } catch {
            log.error("Failed to open notebook: \(error)")
            return UIHostingController(rootView: Text(verbatim: "⚠︎"))
        }
    }

    public func updateUIViewController(_ controller: UIViewController, context: Context) {
        guard let controller = controller as? NotebookCanvasViewController else { return }
        // Reading the model here makes SwiftUI call this again when a setting changes.
        _ = model.isRulerActive
        controller.apply(tool: model.pkTool, drawingPolicy: model.drawingPolicy)
        _ = model.topContentInset
        if controller.isViewLoaded {
            controller.applyInsets()
        }
    }
}
