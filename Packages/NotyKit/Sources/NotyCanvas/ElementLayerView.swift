import NotyCore
import UIKit

extension UIColor {
    /// `#RRGGBB`, as stored in palettes and text elements.
    public convenience init(hex: String) {
        let value = UInt32(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0
        self.init(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }

    public var hex: String {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        func byte(_ value: CGFloat) -> Int { Int((min(max(value, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(red), byte(green), byte(blue))
    }
}

/// Text boxes and images of one page, between the paper and the ink (ADR-0014).
///
/// Editable only while the Text tool is active: then the ink canvas lets
/// touches through, a tap on empty paper creates a text box, and elements
/// can be moved, resized and deleted.
final class ElementLayerView: UIView {
    static let defaultFontSize: Double = 18

    let pageID: UUID
    let package: NotebookPackage
    private(set) var elements: [PageElement]
    private(set) var isDirty = false
    /// Called after every change, to schedule a save.
    var onChange: (() -> Void)?
    /// Color for new text boxes: the current palette color.
    var textColorHex = "#000000"
    /// Size of new text boxes; changing it resizes the selected one too.
    var textFontSize = ElementLayerView.defaultFontSize {
        didSet {
            guard textFontSize != oldValue, let id = selectedID, let text = views[id] as? TextElementView else { return }
            setFontSize(textFontSize, of: id, view: text)
        }
    }
    /// Called when the selection changes, with the size of the selected text
    /// box, or `nil` when no text box is selected.
    var onSelectText: ((Double?) -> Void)?

    /// Size of the selected text box, if a text box is selected.
    var selectedTextSize: Double? {
        guard let id = selectedID, let element = elements.first(where: { $0.id == id }),
              case .text(_, let size, _) = element.content
        else { return nil }
        return size
    }

    var isEditable = false {
        didSet {
            isUserInteractionEnabled = isEditable
            if !isEditable {
                select(nil)
            }
        }
    }

    private var views: [UUID: ElementView] = [:]
    private var selectedID: UUID?

    init(pageID: UUID, package: NotebookPackage, frame: CGRect) {
        self.pageID = pageID
        self.package = package
        self.elements = (try? package.readElements(pageID)) ?? []
        super.init(frame: frame)
        backgroundColor = .clear
        clipsToBounds = true
        isUserInteractionEnabled = false
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
        for element in elements {
            addView(for: element)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func save() {
        guard isDirty else { return }
        do {
            try package.writeElements(elements.filter { !$0.isEmptyText }, page: pageID)
            isDirty = false
        } catch {
            print("Failed to save elements: \(error)")
        }
    }

    // MARK: - Adding

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: self)
        let hit = subviews.reversed().compactMap { $0 as? ElementView }.first { $0.frame.contains(point) }
        if let hit {
            if hit.id == selectedID, let text = hit as? TextElementView {
                text.beginEditing()
            } else {
                select(hit.id)
            }
        } else if selectedID != nil {
            endEditing(true)
            select(nil)
        } else {
            addText(at: point)
        }
    }

    private func addText(at point: CGPoint) {
        // Near the right edge the box moves left instead of becoming too narrow.
        let x = max(16, min(point.x, bounds.maxX - 200))
        let width = min(320, bounds.maxX - x - 16)
        let element = PageElement(
            content: .text(string: "", fontSize: textFontSize, colorHex: textColorHex),
            frame: CGRect(x: x, y: max(0, point.y - 22), width: width, height: 44)
        )
        elements.append(element)
        let view = addView(for: element)
        select(element.id)
        (view as? TextElementView)?.beginEditing()
        changed()
    }

    /// Places an image in the middle of the page, at most 60% of its width.
    func addImage(fileName: String, size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let width = min(size.width, bounds.width * 0.6)
        let height = width * size.height / size.width
        let frame = CGRect(x: (bounds.width - width) / 2, y: max(40, (bounds.height - height) / 3), width: width, height: height)
        let element = PageElement(content: .image(fileName: fileName), frame: frame)
        elements.append(element)
        addView(for: element)
        select(element.id)
        changed()
    }

    @discardableResult
    private func addView(for element: PageElement) -> ElementView {
        let view: ElementView
        switch element.content {
        case .text(let string, let fontSize, let colorHex):
            view = TextElementView(id: element.id, frame: element.frame, text: string, fontSize: fontSize, color: UIColor(hex: colorHex))
        case .image(let fileName):
            view = ImageElementView(id: element.id, frame: element.frame, image: UIImage(contentsOfFile: package.assetURL(fileName).path(percentEncoded: false)))
        }
        view.onFrameChange = { [weak self] frame in self?.update(element.id) { $0.frame = frame } }
        view.onDelete = { [weak self] in self?.remove(element.id) }
        if let text = view as? TextElementView {
            text.onTextChange = { [weak self] string in
                self?.update(element.id) { element in
                    if case .text(_, let size, let color) = element.content {
                        element.content = .text(string: string, fontSize: size, colorHex: color)
                    }
                }
            }
            text.onEndEditing = { [weak self] isEmpty in
                if isEmpty {
                    self?.remove(element.id)
                }
            }
        }
        addSubview(view)
        views[element.id] = view
        return view
    }

    // MARK: - Changing

    private func update(_ id: UUID, _ change: (inout PageElement) -> Void) {
        guard let index = elements.firstIndex(where: { $0.id == id }) else { return }
        change(&elements[index])
        changed()
    }

    private func remove(_ id: UUID) {
        elements.removeAll { $0.id == id }
        views.removeValue(forKey: id)?.removeFromSuperview()
        if selectedID == id {
            selectedID = nil
        }
        changed()
    }

    private func select(_ id: UUID?) {
        let changed = selectedID != id
        selectedID = id
        for (viewID, view) in views {
            view.isSelected = viewID == id
        }
        if changed {
            onSelectText?(selectedTextSize)
        }
    }

    func clearSelection() {
        guard selectedID != nil else { return }
        endEditing(true)
        select(nil)
    }

    private func setFontSize(_ size: Double, of id: UUID, view: TextElementView) {
        view.setFontSize(size)
        update(id) { element in
            if case .text(let string, _, let color) = element.content {
                element.content = .text(string: string, fontSize: size, colorHex: color)
            }
            element.frame = view.frame
        }
    }

    /// Turns the lines of the selected text box into a list. Returns `false`
    /// when no text box is selected.
    @discardableResult
    func toggleList(_ style: TextListStyle) -> Bool {
        guard let id = selectedID, let text = views[id] as? TextElementView else { return false }
        text.toggleList(style)
        return true
    }

    private func changed() {
        isDirty = true
        onChange?()
    }
}

// MARK: - Element views

/// Shared selection chrome: dashed border, delete button, resize handle; drag to move.
class ElementView: UIView {
    let id: UUID
    var onFrameChange: ((CGRect) -> Void)?
    var onDelete: (() -> Void)?

    var isSelected = false {
        didSet { updateSelection() }
    }

    private let border = CAShapeLayer()
    private let deleteButton = UIButton(type: .system)
    private let resizeHandle = UIView()
    private var dragStart = CGRect.zero

    init(id: UUID, frame: CGRect) {
        self.id = id
        super.init(frame: frame)
        clipsToBounds = false

        border.strokeColor = tintColor.cgColor
        border.fillColor = UIColor.clear.cgColor
        border.lineWidth = 1.5
        border.lineDashPattern = [6, 4]
        layer.addSublayer(border)

        deleteButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        deleteButton.tintColor = .systemRed
        deleteButton.backgroundColor = .white
        deleteButton.layer.cornerRadius = 12
        deleteButton.accessibilityLabel = String(localized: "Delete", bundle: .module)
        deleteButton.addAction(UIAction { [weak self] _ in self?.onDelete?() }, for: .touchUpInside)
        addSubview(deleteButton)

        resizeHandle.backgroundColor = tintColor
        resizeHandle.layer.cornerRadius = 9
        resizeHandle.layer.borderColor = UIColor.white.cgColor
        resizeHandle.layer.borderWidth = 2
        resizeHandle.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(dragResizeHandle)))
        addSubview(resizeHandle)

        addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(dragElement)))
        updateSelection()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func layoutSubviews() {
        super.layoutSubviews()
        border.path = UIBezierPath(roundedRect: bounds, cornerRadius: 4).cgPath
        deleteButton.frame = CGRect(x: bounds.maxX - 12, y: -12, width: 24, height: 24)
        resizeHandle.frame = CGRect(x: bounds.maxX - 9, y: bounds.maxY - 9, width: 18, height: 18)
    }

    /// Lets the handles outside the frame receive touches.
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        super.point(inside: point, with: event)
            || (isSelected && (deleteButton.frame.insetBy(dx: -8, dy: -8).contains(point) || resizeHandle.frame.insetBy(dx: -10, dy: -10).contains(point)))
    }

    func updateSelection() {
        border.isHidden = !isSelected
        deleteButton.isHidden = !isSelected
        resizeHandle.isHidden = !isSelected
    }

    @objc private func dragElement(_ gesture: UIPanGestureRecognizer) {
        guard isSelected, let container = superview else { return }
        switch gesture.state {
        case .began:
            dragStart = frame
        case .changed:
            let translation = gesture.translation(in: container)
            var newFrame = dragStart.offsetBy(dx: translation.x, dy: translation.y)
            newFrame.origin.x = min(max(newFrame.origin.x, -newFrame.width / 2), container.bounds.width - newFrame.width / 2)
            newFrame.origin.y = min(max(newFrame.origin.y, 0), container.bounds.height - 20)
            frame = newFrame
        case .ended, .cancelled:
            onFrameChange?(frame)
        default:
            break
        }
    }

    @objc private func dragResizeHandle(_ gesture: UIPanGestureRecognizer) {
        guard let container = superview else { return }
        switch gesture.state {
        case .began:
            dragStart = frame
        case .changed:
            let translation = gesture.translation(in: container)
            frame = resized(dragStart, by: translation)
            setNeedsLayout()
        case .ended, .cancelled:
            onFrameChange?(frame)
        default:
            break
        }
    }

    /// The new frame while dragging the resize handle by `translation`.
    func resized(_ start: CGRect, by translation: CGPoint) -> CGRect {
        CGRect(origin: start.origin, size: CGSize(width: max(40, start.width + translation.x), height: max(30, start.height + translation.y)))
    }
}

final class TextElementView: ElementView, UITextViewDelegate {
    /// Text inset inside its box; PDF export draws with the same insets.
    static let textInsets = UIEdgeInsets(top: 8, left: 5, bottom: 8, right: 5)

    var onTextChange: ((String) -> Void)?
    var onEndEditing: ((Bool) -> Void)?
    private let textView = UITextView()

    init(id: UUID, frame: CGRect, text: String, fontSize: Double, color: UIColor) {
        super.init(id: id, frame: frame)
        textView.text = text
        textView.font = .systemFont(ofSize: fontSize)
        textView.textColor = color
        textView.backgroundColor = .clear
        textView.isScrollEnabled = false
        textView.isEditable = false
        textView.isUserInteractionEnabled = false
        textView.textContainerInset = UIEdgeInsets(top: Self.textInsets.top, left: 0, bottom: Self.textInsets.bottom, right: 0)
        textView.textContainer.lineFragmentPadding = Self.textInsets.left
        textView.delegate = self
        insertSubview(textView, at: 0)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        textView.frame = bounds
    }

    func beginEditing() {
        textView.isUserInteractionEnabled = true
        textView.isEditable = true
        textView.becomeFirstResponder()
    }

    override func updateSelection() {
        super.updateSelection()
        if !isSelected, textView.isFirstResponder {
            textView.resignFirstResponder()
        }
    }

    func textViewDidChange(_ textView: UITextView) {
        fitHeight()
        onTextChange?(textView.text)
        onFrameChange?(frame)
    }

    func setFontSize(_ size: Double) {
        textView.font = .systemFont(ofSize: size)
        fitHeight()
    }

    // MARK: Lists

    /// Pressing Return in a list line continues the list; on an empty item it ends it.
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        guard text == "\n", range.length == 0 else { return true }
        let string = textView.text as NSString
        let lineRange = string.lineRange(for: NSRange(location: range.location, length: 0))
        let line = string.substring(with: lineRange).trimmingCharacters(in: .newlines)
        guard let marker = ListMarker(line: line) else { return true }
        if line.count == marker.prefix.count {
            // Return on an empty item: the list ends here.
            replace(NSRange(location: lineRange.location, length: marker.prefix.utf16.count), with: "", selection: lineRange.location)
        } else {
            let insert = "\n" + marker.next.prefix
            replace(range, with: insert, selection: range.location + insert.utf16.count)
        }
        return false
    }

    /// Adds `• ` or `1. ` before the selected lines, or removes it when they
    /// all have it already. Without a cursor it applies to the whole box.
    func toggleList(_ style: TextListStyle) {
        let string = textView.text as NSString
        let selection = textView.isFirstResponder ? textView.selectedRange : NSRange(location: 0, length: string.length)
        let range = string.paragraphRange(for: selection)
        var lines = string.substring(with: range).components(separatedBy: "\n")
        let endsWithNewline = lines.count > 1 && lines.last == ""
        if endsWithNewline { lines.removeLast() }

        let isAlreadyList = lines.allSatisfy { line in
            guard let marker = ListMarker(line: line) else { return line.isEmpty }
            return marker.style == style
        } && lines.contains { !$0.isEmpty }
        var number = 0
        let newLines = lines.map { line -> String in
            let body = ListMarker(line: line).map { String(line.dropFirst($0.prefix.count)) } ?? line
            if isAlreadyList { return body }
            number += 1
            return ListMarker(style: style, number: number).prefix + body
        }
        var replacement = newLines.joined(separator: "\n")
        if endsWithNewline { replacement += "\n" }
        let caret = range.location + (replacement as NSString).length - (endsWithNewline ? 1 : 0)
        replace(range, with: replacement, selection: caret)
    }

    private func replace(_ range: NSRange, with replacement: String, selection: Int) {
        let string = textView.text as NSString
        textView.text = string.replacingCharacters(in: range, with: replacement)
        textView.selectedRange = NSRange(location: min(selection, (textView.text as NSString).length), length: 0)
        textViewDidChange(textView)
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        textView.isEditable = false
        textView.isUserInteractionEnabled = false
        onEndEditing?(textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private func fitHeight() {
        let height = textView.sizeThatFits(CGSize(width: bounds.width, height: .greatestFiniteMagnitude)).height
        frame.size.height = max(44, height)
    }

    /// Text boxes only change width; the height follows the text.
    override func resized(_ start: CGRect, by translation: CGPoint) -> CGRect {
        var frame = start
        frame.size.width = max(60, start.width + translation.x)
        let height = textView.sizeThatFits(CGSize(width: frame.width, height: .greatestFiniteMagnitude)).height
        frame.size.height = max(44, height)
        return frame
    }
}

final class ImageElementView: ElementView {
    private let imageView = UIImageView()

    init(id: UUID, frame: CGRect, image: UIImage?) {
        super.init(id: id, frame: frame)
        imageView.image = image
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = image == nil ? .secondarySystemFill : .clear
        insertSubview(imageView, at: 0)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = bounds
    }

    /// Images keep their proportions.
    override func resized(_ start: CGRect, by translation: CGPoint) -> CGRect {
        let width = max(40, start.width + translation.x)
        return CGRect(origin: start.origin, size: CGSize(width: width, height: width * start.height / max(start.width, 1)))
    }
}

/// The marker at the start of a list line: `• ` or `12. `.
struct ListMarker: Equatable {
    static let bullet = "• "

    let style: TextListStyle
    let number: Int

    init(style: TextListStyle, number: Int) {
        self.style = style
        self.number = number
    }

    /// The marker `line` starts with, if any.
    init?(line: String) {
        if line.hasPrefix(Self.bullet) {
            self.init(style: .bulleted, number: 0)
            return
        }
        let digits = line.prefix { $0.isASCII && $0.isNumber }
        guard !digits.isEmpty, digits.count <= 4, let number = Int(digits),
              line.dropFirst(digits.count).hasPrefix(". ")
        else { return nil }
        self.init(style: .numbered, number: number)
    }

    var prefix: String {
        switch style {
        case .bulleted: Self.bullet
        case .numbered: "\(number). "
        }
    }

    /// The marker of the item after this one.
    var next: ListMarker {
        ListMarker(style: style, number: style == .numbered ? number + 1 : 0)
    }
}
