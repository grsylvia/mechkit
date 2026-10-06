import AppKit
import Observation
import SwiftUI

struct ViewShortcut: Codable, Equatable {
    let key: String
    var command = false
    var control = false
    var option = false
    var shift = false

    var isValid: Bool {
        guard key.count == 1, key == key.lowercased(), let scalar = key.unicodeScalars.first else {
            return false
        }
        // Enter and Escape are reserved for confirming and cancelling recording.
        return scalar.value == 9 || scalar.value == 127
            || (scalar.value >= 32 && scalar.value < 0xF700)
            || (0xF700...0xF70F).contains(scalar.value)
            || [0xF728, 0xF729, 0xF72B, 0xF72C, 0xF72D].contains(scalar.value)
    }

    var keyboardShortcut: KeyboardShortcut? {
        guard isValid, let character = key.first else { return nil }
        var modifiers: EventModifiers = []
        if command { modifiers.insert(.command) }
        if control { modifiers.insert(.control) }
        if option { modifiers.insert(.option) }
        if shift { modifiers.insert(.shift) }
        return KeyboardShortcut(KeyEquivalent(character), modifiers: modifiers)
    }

    var display: String {
        let names = [
            " ": "Space", "\t": "Tab", "\u{7F}": "⌫",
            "\u{F700}": "↑", "\u{F701}": "↓", "\u{F702}": "←", "\u{F703}": "→",
            "\u{F728}": "⌦", "\u{F729}": "Home", "\u{F72B}": "End",
            "\u{F72C}": "Page Up", "\u{F72D}": "Page Down",
        ]
        let name: String
        if let scalar = key.unicodeScalars.first, (0xF704...0xF70F).contains(scalar.value) {
            name = "F\(scalar.value - 0xF704 + 1)"
        } else {
            name = names[key] ?? key.uppercased()
        }
        return (control ? "⌃" : "") + (option ? "⌥" : "") + (shift ? "⇧" : "")
            + (command ? "⌘" : "") + name
    }

    init(
        key: String, command: Bool = false, control: Bool = false,
        option: Bool = false, shift: Bool = false
    ) {
        self.key = key.lowercased()
        self.command = command
        self.control = control
        self.option = option
        self.shift = shift
    }

    init?(event: NSEvent) {
        guard let key = event.characters(byApplyingModifiers: []), key.count == 1 else {
            return nil
        }
        self.init(
            key: key,
            command: event.modifierFlags.contains(.command),
            control: event.modifierFlags.contains(.control),
            option: event.modifierFlags.contains(.option),
            shift: event.modifierFlags.contains(.shift))
        guard isValid else { return nil }
    }

    @MainActor
    func matchesMenuItem(_ item: NSMenuItem) -> Bool {
        let modifiers = item.keyEquivalentModifierMask
        let hasShift =
            modifiers.contains(.shift)
            || item.keyEquivalent != item.keyEquivalent.lowercased()
        return item.keyEquivalent.lowercased() == key
            && modifiers.contains(.command) == command
            && modifiers.contains(.control) == control
            && modifiers.contains(.option) == option
            && hasShift == shift
    }
}

@MainActor
@Observable
final class ViewShortcutStore {
    static let storageKey = "viewShortcuts"
    private(set) var shortcuts: [CameraViewPreset: ViewShortcut]
    private(set) var loadWarning: String?
    @ObservationIgnored private let defaults: UserDefaults

    static var defaultShortcuts: [CameraViewPreset: ViewShortcut] {
        [
            .front: ViewShortcut(key: "1", command: true),
            .top: ViewShortcut(key: "2", command: true),
            .right: ViewShortcut(key: "3", command: true),
            .isometric: ViewShortcut(key: "4", command: true),
        ]
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        shortcuts = Self.defaultShortcuts
        guard let data = defaults.data(forKey: Self.storageKey) else { return }
        do {
            let saved = try JSONDecoder().decode([CameraViewPreset: ViewShortcut].self, from: data)
            guard saved.count == CameraViewPreset.allCases.count,
                CameraViewPreset.allCases.allSatisfy({ saved[$0]?.isValid == true }),
                Set(saved.values.map(\.display)).count == saved.count
            else {
                loadWarning = "Saved shortcuts were invalid. The default shortcuts are in use."
                return
            }
            shortcuts = saved
        } catch {
            loadWarning = "Saved shortcuts could not be read. The default shortcuts are in use."
        }
    }

    subscript(_ preset: CameraViewPreset) -> ViewShortcut {
        shortcuts[preset] ?? Self.defaultShortcuts[preset]!
    }

    func assign(
        _ shortcut: ViewShortcut, to preset: CameraViewPreset,
        menu: NSMenu?
    ) -> String? {
        guard shortcut.isValid else { return "Choose a letter, number, symbol, or navigation key." }
        if let conflict = CameraViewPreset.allCases.first(where: {
            $0 != preset && shortcuts[$0] == shortcut
        }) {
            return "\(shortcut.display) is already assigned to \(conflict.title)."
        }
        if let title = menuConflict(shortcut, in: menu) {
            return "\(shortcut.display) is already used by \(title)."
        }
        var updated = shortcuts
        updated[preset] = shortcut
        do {
            let data = try JSONEncoder().encode(updated)
            defaults.set(data, forKey: Self.storageKey)
            shortcuts = updated
            loadWarning = nil
            return nil
        } catch {
            return "The shortcut could not be saved: \(error.localizedDescription)"
        }
    }

    private func menuConflict(_ shortcut: ViewShortcut, in menu: NSMenu?) -> String? {
        guard let menu else { return nil }
        for item in menu.items {
            if let conflict = menuConflict(shortcut, in: item.submenu) { return conflict }
            // Our view commands are checked against the stored assignments above.
            if let preset = CameraViewPreset.allCases.first(where: { $0.title == item.title }),
                shortcuts[preset]?.matchesMenuItem(item) == true
            {
                continue
            }
            if !item.keyEquivalent.isEmpty && shortcut.matchesMenuItem(item) { return item.title }
        }
        return nil
    }
}

enum ShortcutRecordingInput {
    case shortcut(ViewShortcut)
    case confirm, cancel, unsupported
}

struct ShortcutRecording {
    let preset: CameraViewPreset
    private(set) var pending: ViewShortcut?
    private(set) var error: String?

    // Returns true when recording ends. Capture alone never changes the saved assignment.
    @MainActor
    mutating func handle(
        _ input: ShortcutRecordingInput, store: ViewShortcutStore,
        menu: NSMenu?
    ) -> Bool {
        switch input {
        case .shortcut(let shortcut):
            pending = shortcut
            error = nil
        case .unsupported:
            pending = nil
            error = "This key cannot be assigned. Choose another key combination."
        case .cancel:
            return true
        case .confirm:
            guard let pending else {
                error = "Press a key combination before pressing Enter."
                return false
            }
            error = store.assign(pending, to: preset, menu: menu)
            return error == nil
        }
        return false
    }
}
