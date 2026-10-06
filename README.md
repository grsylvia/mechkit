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
