import SwiftUI

@main
struct MechKitApp: App {
    @State private var assembly = AssemblyRecord.sample
    @State private var shortcuts = ViewShortcutStore()

    var body: some Scene {
        WindowGroup {
            ContentView(assembly: $assembly)
                .environment(shortcuts)
        }
        .defaultSize(width: 800, height: 600)
        .commands { WorkspaceCommands(shortcuts: shortcuts.shortcuts) }
    }
}
