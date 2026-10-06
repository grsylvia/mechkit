import SwiftUI

@main
struct MechKitApp: App {
    @State private var shortcuts = ViewShortcutStore()

    var body: some Scene {
        DocumentGroup(newDocument: AssemblyDocument()) { configuration in
            ContentView(assembly: configuration.$document.assembly)
                .environment(shortcuts)
        }
        .defaultSize(width: 1100, height: 700)
        .commands { WorkspaceCommands(shortcuts: shortcuts.shortcuts) }
    }
}
