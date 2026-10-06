# mechkit

mechkit is a tool for designing and simulating machines and robots.
It supports machine design, robotics, and automation work.

Its goals are to let users assemble parts and reusable mechanisms in a 3D
workspace, connect them, and explore how the resulting machines and robots move
and behave.
Simulation will support understanding motion, forces, loads, and required torque.

## Run the macOS app

Open `MechKit.xcodeproj` in Xcode, select the `MechKit` scheme and `My Mac`,
then press Command-R. The app is native to macOS, uses SwiftUI and RealityKit,
and requires macOS 26 or later.

Choose **File → New** to create an assembly and **File → Open…** to open a
`.mechkit` file. Each document has its own window and assembly. **File → Save**
saves changes; use Option-Shift-Command-S for **Save As…** (hold Option while
opening the File menu to reveal it). Standard Undo/Redo applies to assembly edits.
Camera movement and panel visibility are view state and are not saved.

Assembly files are versioned JSON. Dimensions and positions use meters in Double
precision; orientation is a unit quaternion `(x, y, z, w)` rotating part-local
coordinates into the right-handed, Z-up assembly frame. Invalid files report an
error rather than replacing the open assembly. New documents begin with the
sample block.

The workspace uses a right-handed coordinate frame with +Z up. The ground grid
lies in the XY plane with 10 mm spacing and major lines every 50 mm. The
bottom-left indicator follows the camera orientation and shows the Front (XZ),
Top (XY), and Right (YZ) planes.

- Drag to orbit.
- Shift-drag, right-drag, or middle-drag to pan.
- Scroll or pinch to zoom.
- Use **Reset view** to restore the initial camera.
- Use Command-1 for Front, Command-2 for Top, Command-3 for Right, and Command-4
  for Isometric. Named views preserve the current pan and zoom.

Front looks from -Y, Top from +Z, and Right from +X toward the view target.
Isometric looks from the +X/-Y/+Z direction with equal axis foreshortening.

Choose **View → Edit Shortcuts…** to change the view shortcuts. Click a box,
press the new key combination, then press Enter to save it. Escape cancels.
Changes persist across launches; conflicts with other view or app-menu shortcuts
prevent saving.

The **Parts** sidebar selects a block and highlights it in orange. Use the
native toolbar to add or remove blocks, reset the camera, or show and hide the
inspector. The sidebar toggle is in the window toolbar.

The inspector edits the selected part’s name, full local X/Y/Z dimensions, and
assembly-frame center position. All numeric fields are in meters. Press Return
or **Apply** to commit the whole edit; **Revert** discards its draft. Invalid,
non-finite, non-positive dimensions, or values outside the renderer’s numeric
range display an error and leave the assembly unchanged. A loaded assembly that
exceeds render precision reports which parts cannot be displayed.

To build from Terminal:

```sh
xcodebuild -project MechKit.xcodeproj -scheme MechKit -configuration Debug -destination 'platform=macOS' build
```

To run the numerical workspace checks:

```sh
swiftc MechKit/CameraState.swift MechKit/GroundGrid.swift Checks/WorkspaceChecks.swift -o /tmp/mechkit-workspace-checks
/tmp/mechkit-workspace-checks
```

To check shortcut recording and persistence in an isolated preferences domain:

```sh
swiftc MechKit/CameraState.swift MechKit/ViewShortcuts.swift Checks/ShortcutChecks.swift -o /tmp/mechkit-shortcut-checks
/tmp/mechkit-shortcut-checks
```

To check inspector drafts and the renderer's numeric boundary:

```sh
swiftc MechKit/AssemblyRecord.swift MechKit/PartEditing.swift Checks/EditingChecks.swift -o /tmp/mechkit-editing-checks
/tmp/mechkit-editing-checks
```

To check document serialization, independent assembly values, save/reopen, and
invalid files:

```sh
swiftc MechKit/AssemblyRecord.swift MechKit/AssemblyDocument.swift Checks/DocumentChecks.swift -o /tmp/mechkit-document-checks
/tmp/mechkit-document-checks
```

DocumentGroup handles the native document windows, menu commands, autosave, and
undo through the FileDocument binding on macOS 26. Native Save/Open dialogs and
menu Undo/Redo still require an interactive check.
