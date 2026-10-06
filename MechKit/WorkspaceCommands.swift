import SwiftUI

struct WorkspaceActions {
    let selectView: (CameraViewPreset) -> Void
    let editShortcuts: () -> Void
}

private struct WorkspaceActionsKey: FocusedValueKey {
    typealias Value = WorkspaceActions
}

extension FocusedValues {
    var workspaceActions: WorkspaceActions? {
        get { self[WorkspaceActionsKey.self] }
        set { self[WorkspaceActionsKey.self] = newValue }
    }
}

struct WorkspaceCommands: Commands {
    let shortcuts: [CameraViewPreset: ViewShortcut]
    @FocusedValue(\.workspaceActions) private var actions

    var body: some Commands {
        CommandGroup(after: .toolbar) {
            Divider()
            ForEach(CameraViewPreset.allCases) { preset in
                Button(preset.title) { actions?.selectView(preset) }
                    .keyboardShortcut(shortcuts[preset]?.keyboardShortcut)
                    .disabled(actions == nil)
            }
            Divider()
            Button("Edit Shortcuts…") { actions?.editShortcuts() }
                .disabled(actions == nil)
        }
    }
}
