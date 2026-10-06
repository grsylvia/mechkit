import AppKit
import Foundation

@main
struct ShortcutChecks {
    static func expect(_ condition: Bool, _ message: String) {
        guard condition else { fatalError(message) }
    }

    @MainActor
    static func main() throws {
        let suite = "mechkit.shortcut-checks.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ViewShortcutStore(defaults: defaults)
        for (index, preset) in CameraViewPreset.allCases.enumerated() {
            expect(
                store[preset] == ViewShortcut(key: String(index + 1), command: true),
                "Default Command-1 through Command-4 assignments")
        }

        var session = ShortcutRecording(preset: .front)
        let replacement = ViewShortcut(key: "f", command: true, shift: true)
        expect(
            !session.handle(.shortcut(replacement), store: store, menu: nil),
            "Capture must keep recording open")
        expect(session.pending == replacement, "Captured combination must be shown as pending")
        expect(store[.front].key == "1", "Capture must not apply before Enter")
        expect(
            defaults.data(forKey: ViewShortcutStore.storageKey) == nil,
            "Capture must not persist before Enter")
        expect(session.handle(.cancel, store: store, menu: nil), "Escape ends recording")
        expect(store[.front].key == "1", "Escape preserves the original shortcut")

        session = ShortcutRecording(preset: .front)
        expect(!session.handle(.confirm, store: store, menu: nil), "Empty Enter cannot save")
        expect(session.error != nil, "Empty Enter explains missing input")
        _ = session.handle(.shortcut(replacement), store: store, menu: nil)
        expect(session.handle(.confirm, store: store, menu: nil), "Enter commits captured shortcut")
        expect(store[.front] == replacement, "Commit updates assignment")
        let reloaded = ViewShortcutStore(defaults: defaults)
        expect(reloaded[.front] == replacement, "Committed assignment survives reload")
        expect(reloaded[.top].key == "2", "Editing one assignment preserves others")

        session = ShortcutRecording(preset: .right)
        _ = session.handle(.shortcut(replacement), store: store, menu: nil)
        expect(!session.handle(.confirm, store: store, menu: nil), "Duplicate Enter is rejected")
        expect(session.error?.contains("Front") == true, "Duplicate error names conflicting view")
        expect(store[.right].key == "3", "Conflict preserves old assignment")

        let menu = NSMenu(title: "Test")
        let editMenu = NSMenu(title: "Edit")
        let editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        editItem.submenu = editMenu
        menu.addItem(editItem)
        let copyItem = NSMenuItem(title: "Copy", action: nil, keyEquivalent: "c")
        copyItem.keyEquivalentModifierMask = .command
        editMenu.addItem(copyItem)
        expect(
            store.assign(ViewShortcut(key: "c", command: true), to: .front, menu: menu)?
                .contains("Copy") == true, "Reject nested app-menu conflicts")
        expect(store[.front] == replacement, "Menu conflict preserves assignment")

        let redoItem = NSMenuItem(title: "Redo", action: nil, keyEquivalent: "Z")
        redoItem.keyEquivalentModifierMask = .command
        editMenu.addItem(redoItem)
        expect(
            store.assign(
                ViewShortcut(key: "z", command: true, shift: true), to: .front, menu: menu)?
                .contains("Redo") == true,
            "Uppercase menu keys imply Shift"
        )
        let otherRight = NSMenuItem(title: "Right", action: nil, keyEquivalent: "r")
        otherRight.keyEquivalentModifierMask = [.command, .option]
        menu.addItem(otherRight)
        expect(
            store.assign(
                ViewShortcut(key: "r", command: true, option: true), to: .front, menu: menu)?
                .contains("Right") == true,
            "Matching a view title must not hide another menu command's conflict"
        )

        session = ShortcutRecording(preset: .top)
        _ = session.handle(
            .shortcut(ViewShortcut(key: "t", command: true)), store: store, menu: nil)
        _ = session.handle(.unsupported, store: store, menu: nil)
        expect(
            !session.handle(.confirm, store: store, menu: nil),
            "Unsupported input must not commit an earlier pending combination")
        expect(store[.top].key == "2", "Unsupported input preserves saved shortcut")

        for key in ["", "ab", "\r", "\n", "\u{1B}"] {
            expect(
                store.assign(ViewShortcut(key: key), to: .front, menu: nil) != nil,
                "Reject invalid saved keys")
        }
        expect(ViewShortcut(key: "F", command: true).key == "f", "Normalize key case")
        expect(ViewShortcut(key: "\u{F700}", option: true).display == "⌥↑", "Arrow labels")
        expect(ViewShortcut(key: "\u{F704}").display == "F1", "Function key labels")

        let savedData = defaults.data(forKey: ViewShortcutStore.storageKey)!
        defaults.set(Data("invalid JSON".utf8), forKey: ViewShortcutStore.storageKey)
        let corrupted = ViewShortcutStore(defaults: defaults)
        expect(
            corrupted[.front].key == "1" && corrupted.loadWarning != nil,
            "Corrupt settings fall back with an explanation")
        var duplicates = ViewShortcutStore.defaultShortcuts
        duplicates[.top] = duplicates[.front]
        defaults.set(try JSONEncoder().encode(duplicates), forKey: ViewShortcutStore.storageKey)
        let invalid = ViewShortcutStore(defaults: defaults)
        expect(
            invalid[.top].key == "2" && invalid.loadWarning != nil,
            "Reject persisted duplicate assignments")
        defaults.set(savedData, forKey: ViewShortcutStore.storageKey)
        print(
            "Shortcut checks passed: defaults, staging, Enter, Escape, conflicts, persistence, invalid settings."
        )
    }
}
