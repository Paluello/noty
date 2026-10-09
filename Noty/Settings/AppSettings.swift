import NotyCanvas
import SwiftUI

enum SettingsKey {
    static let appearance = "appearance"
    static let fingerDrawing = "fingerDrawing"
    static let autoNewPage = "autoNewPage"
    static let defaultEraser = "defaultEraser"
    static let sortOrder = "sortOrder"
    static let lastTool = "lastTool"
    static let lastColorIndex = "lastColorIndex"
    static let widthPresets = "widthPresets"
    static let widthIndex = "widthIndex"
    static let toolbarPosition = "toolbarPosition"
    static let floatingToolbarX = "floatingToolbarX"
    static let floatingToolbarY = "floatingToolbarY"
    static let pencilTapAction = "pencilTapAction"
    static let pencilSqueezeAction = "pencilSqueezeAction"
}

/// Where the editor toolbar sits (UI-1).
enum ToolbarPosition: String, CaseIterable, Identifiable {
    case top, leading, trailing, floating

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .top: "Top"
        case .leading: "Left"
        case .trailing: "Right"
        case .floating: "Floating"
        }
    }

    var symbolName: String {
        switch self {
        case .top: "rectangle.tophalf.inset.filled"
        case .leading: "rectangle.lefthalf.inset.filled"
        case .trailing: "rectangle.righthalf.inset.filled"
        case .floating: "rectangle.inset.filled.on.rectangle"
        }
    }
}

extension PencilAction {
    var title: LocalizedStringKey {
        switch self {
        case .system: "As in iPad Settings"
        case .switchEraser: "Switch to Eraser"
        case .previousTool: "Previous Tool"
        case .undo: "Undo"
        case .toggleRuler: "Show or Hide Ruler"
        case .none: "Nothing"
        }
    }
}

/// Theme of the interface; pages always stay light (UI-3).
enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .system: "Automatic"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

/// Remembers the last tool, color and widths between sessions (flow F1).
@MainActor
enum EditorPreferences {
    private static var defaults: UserDefaults { .standard }

    static func load(into model: EditorModel) {
        if let tool = defaults.string(forKey: SettingsKey.lastTool).flatMap(ToolKind.init(rawValue:)) {
            model.tool = tool
        }
        model.colorIndex = min(defaults.integer(forKey: SettingsKey.lastColorIndex), Palette.size - 1)
        if let data = defaults.data(forKey: SettingsKey.widthPresets),
           let presets = try? JSONDecoder().decode([String: [CGFloat]].self, from: data) {
            for (key, widths) in presets {
                if let tool = ToolKind(rawValue: key), widths.count == 3 {
                    model.widthPresets[tool] = widths
                }
            }
        }
        if let data = defaults.data(forKey: SettingsKey.widthIndex),
           let indexes = try? JSONDecoder().decode([String: Int].self, from: data) {
            for (key, index) in indexes {
                if let tool = ToolKind(rawValue: key) {
                    model.widthIndex[tool] = min(max(index, 0), 2)
                }
            }
        }
        model.eraserMode = defaults.string(forKey: SettingsKey.defaultEraser).flatMap(EraserMode.init(rawValue:)) ?? .partial
        model.fingerDrawing = defaults.bool(forKey: SettingsKey.fingerDrawing)
        model.autoNewPage = defaults.object(forKey: SettingsKey.autoNewPage) as? Bool ?? true
        model.pencilTapAction = defaults.string(forKey: SettingsKey.pencilTapAction).flatMap(PencilAction.init(rawValue:)) ?? .system
        model.pencilSqueezeAction = defaults.string(forKey: SettingsKey.pencilSqueezeAction).flatMap(PencilAction.init(rawValue:)) ?? .system
    }

    static func save(from model: EditorModel) {
        defaults.set(model.tool.rawValue, forKey: SettingsKey.lastTool)
        defaults.set(model.colorIndex, forKey: SettingsKey.lastColorIndex)
        let presets = Dictionary(uniqueKeysWithValues: model.widthPresets.map { ($0.key.rawValue, $0.value) })
        defaults.set(try? JSONEncoder().encode(presets), forKey: SettingsKey.widthPresets)
        let indexes = Dictionary(uniqueKeysWithValues: model.widthIndex.map { ($0.key.rawValue, $0.value) })
        defaults.set(try? JSONEncoder().encode(indexes), forKey: SettingsKey.widthIndex)
    }
}
