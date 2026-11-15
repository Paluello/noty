import NotyCore
import UIKit

/// What the paper tiles draw: one pattern repeated on every page of the stack.
struct PaperConfiguration: Equatable, Sendable {
    var style = PaperStyle.blank
    var color = PaperColor.white
    var pageSize = CGSize.zero
    var pageCount = 0
}

/// Draws the paper of the whole notebook in tiles, on demand (ADR-0020).
///
/// A tiled layer redraws only what is on screen, at the resolution of the
/// current zoom: lines stay sharp at any zoom level and memory does not grow
/// with the number of pages. Tiles are drawn on background threads, so the
/// configuration is protected by a lock.
final class PaperTiledLayer: CATiledLayer {
    static let separatorColor = UIColor(white: 0.62, alpha: 1)

    private let lock = NSLock()
    private var storedConfiguration = PaperConfiguration()

    var configuration: PaperConfiguration {
        get { lock.withLock { storedConfiguration } }
        set { lock.withLock { storedConfiguration = newValue } }
    }

    override init() {
        super.init()
    }

    /// Core Animation copies layers for presentation.
    override init(layer: Any) {
        super.init(layer: layer)
        if let other = layer as? PaperTiledLayer {
            storedConfiguration = other.configuration
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// No cross-fade: new tiles must not flash while writing or zooming.
    override class func fadeDuration() -> CFTimeInterval { 0 }

    override func draw(in context: CGContext) {
        let configuration = configuration
        let size = configuration.pageSize
        guard size.width > 0, size.height > 0, configuration.pageCount > 0 else { return }
        let clip = context.boundingBoxOfClipPath
        guard !clip.isNull, !clip.isInfinite else { return }
        let first = max(0, Int((clip.minY / size.height).rounded(.down)))
        let last = min(configuration.pageCount - 1, Int((clip.maxY / size.height).rounded(.down)))
        guard first <= last else { return }

        for index in first...last {
            let pageRect = CGRect(x: 0, y: CGFloat(index) * size.height, width: size.width, height: size.height)
            context.saveGState()
            context.clip(to: pageRect)
            context.setFillColor(configuration.color.uiColor.cgColor)
            context.fill(pageRect)
            context.translateBy(x: 0, y: pageRect.minY)
            PaperRenderer.draw(configuration.style, in: CGRect(origin: .zero, size: size), context: context)
            if index > 0 {
                // Page break: a thin line, like a continuous notebook.
                context.setStrokeColor(Self.separatorColor.cgColor)
                context.setLineWidth(1)
                context.move(to: CGPoint(x: 0, y: 0.5))
                context.addLine(to: CGPoint(x: size.width, y: 0.5))
                context.strokePath()
            }
            context.restoreGState()
        }
    }
}

/// Shows the background pattern of every page. It is separate from the
/// drawing, so the eraser never touches it and it stays vector-sharp in PDFs
/// (ADR-0006).
final class PaperView: UIView {
    override class var layerClass: AnyClass { PaperTiledLayer.self }

    private var tiledLayer: PaperTiledLayer { layer as! PaperTiledLayer }

    init() {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        tiledLayer.tileSize = CGSize(width: 512, height: 512)
        // Extra detail levels: sharp up to 16x the on-screen size.
        tiledLayer.levelsOfDetailBias = 4
        tiledLayer.needsDisplayOnBoundsChange = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func update(_ configuration: PaperConfiguration) {
        guard tiledLayer.configuration != configuration else { return }
        tiledLayer.configuration = configuration
        // Shown while a tile is still being drawn.
        backgroundColor = configuration.color.uiColor
        tiledLayer.setNeedsDisplay()
    }
}

extension PaperColor {
    public var uiColor: UIColor {
        switch self {
        case .white: .white
        case .ivory: UIColor(red: 0.984, green: 0.965, blue: 0.914, alpha: 1)
        case .gray: UIColor(red: 0.945, green: 0.949, blue: 0.957, alpha: 1)
        }
    }
}

public enum PaperRenderer {
    static let lineSpacing: CGFloat = 24
    static let gridSpacing: CGFloat = 20
    static let topMargin: CGFloat = 72
    static let leftMargin: CGFloat = 64

    static let lineColor = UIColor(red: 0.62, green: 0.74, blue: 0.88, alpha: 1)
    static let marginColor = UIColor(red: 0.93, green: 0.55, blue: 0.55, alpha: 1)

    /// Line thickness multiplier that keeps lines visible when a page is drawn
    /// at `scale` (e.g. 0.3 for a thumbnail).
    public static func lineScale(forDrawingScale scale: CGFloat) -> CGFloat {
        max(1, 0.5 / (0.6 * scale))
    }

    /// Draws the pattern in page coordinates; also used for PDF export.
    /// `lineScale` thickens lines and dots for small previews.
    public static func draw(_ style: PaperStyle, in bounds: CGRect, context: CGContext, lineScale: CGFloat = 1) {
        context.saveGState()
        defer { context.restoreGState() }

        switch style {
        case .blank:
            break

        case .lined:
            context.setStrokeColor(lineColor.cgColor)
            context.setLineWidth(0.6 * lineScale)
            var y = topMargin
            while y < bounds.maxY - lineSpacing / 2 {
                context.move(to: CGPoint(x: bounds.minX, y: y))
                context.addLine(to: CGPoint(x: bounds.maxX, y: y))
                y += lineSpacing
            }
            context.strokePath()
            context.setStrokeColor(marginColor.cgColor)
            context.move(to: CGPoint(x: leftMargin, y: bounds.minY))
            context.addLine(to: CGPoint(x: leftMargin, y: bounds.maxY))
            context.strokePath()

        case .grid:
            context.setStrokeColor(lineColor.withAlphaComponent(0.7).cgColor)
            context.setLineWidth(0.5 * lineScale)
            var x = gridSpacing
            while x < bounds.maxX {
                context.move(to: CGPoint(x: x, y: bounds.minY))
                context.addLine(to: CGPoint(x: x, y: bounds.maxY))
                x += gridSpacing
            }
            var y = gridSpacing
            while y < bounds.maxY {
                context.move(to: CGPoint(x: bounds.minX, y: y))
                context.addLine(to: CGPoint(x: bounds.maxX, y: y))
                y += gridSpacing
            }
            context.strokePath()

        case .dotted:
            context.setFillColor(lineColor.cgColor)
            let radius: CGFloat = 0.9 * lineScale
            var y = gridSpacing
            while y < bounds.maxY {
                var x = gridSpacing
                while x < bounds.maxX {
                    context.fillEllipse(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
                    x += gridSpacing
                }
                y += gridSpacing
            }
        }
    }
}
