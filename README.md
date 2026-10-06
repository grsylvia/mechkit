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

## Component and mass-property foundation

`MechKit/Physics` defines one `Component` instance for each individual rigid part.
It uses Foundation and SIMD, with no SwiftUI or RealityKit dependency. The model is
included in the app target but is not yet connected to the viewport or simulation.

- `Geometry` currently supports a solid rectangular block. `dimensionsMeters`
  gives its full side lengths along local X, Y, and Z. The local origin is the
  geometric center, and the frame is right-handed.
- `Material` is an immutable, explicitly supplied record with a name,
  `densityKgPerCubicMeter`, and nonempty `source` information. No real material
  records, default densities, material catalogue, or importer are provided.
- `MassProperties` contains volume in m³, mass in kg, center of mass in local
  meters, and inertia about that center in kg·m². For the uniform block, the
  center of mass is `(0, 0, 0)`. The symmetric tensor stores six entries;
  the initial block has zero off-diagonal entries in its local frame.
- `Placement` gives the local origin's position in assembly meters and a unit
  quaternion mapping local vectors into the right-handed, Z-up assembly frame.
  Quaternion components are `(x, y, z, w)`; positive rotation follows the
  right-hand rule. Finite nonzero input quaternions are normalized.

For lengths `a`, `b`, and `c` along local X, Y, and Z, and uniform density `rho`:

```text
volume = a * b * c
mass = rho * volume
Ixx = mass * (b² + c²) / 12
Iyy = mass * (a² + c²) / 12
Izz = mass * (a² + b²) / 12
Ixy = Ixz = Iyz = 0
```

These are analytical rigid-body calculations, not physical measurements. They
assume a completely solid block with uniform density and no holes, deformation,
or attached parts. All physics values use `Double`.

Read properties with `try component.massProperties`; they are calculated on
demand, without a cache. Replace geometry using `try component.setGeometry(...)`
or the entire assigned material record using `try component.setMaterial(...)`.
Both edits validate the resulting properties before changing state. Each component
has a stable UUID; equal geometry and material do not merge individual parts.
Changing `component.placement` preserves local mass properties. Future assembly
calculations must rotate the tensor and apply the parallel-axis theorem where
needed; those calculations are not implemented in this milestone.

Dimensions and density must be finite and strictly positive. Names and sources
must be nonempty. Positions must be finite, and orientations must be finite and
nonzero. Construction and geometry/material edits throw `PhysicsError` if volume,
mass, or a principal moment overflows or rounds to zero in `Double`. Failed edits
leave the component unchanged. Exponent-based multiplication avoids premature
intermediate overflow or underflow when final products remain representable.

Run the physics checks independently of the app:

```sh
swiftc -module-cache-path /tmp/mechkit-physics-module-cache MechKit/Physics/*.swift Checks/PhysicsChecks.swift -o /tmp/mechkit-physics-checks
/tmp/mechkit-physics-checks
```

The checks use synthetic densities, not real material specifications. Independent
analytical fixtures include a 2 m cube at 3 kg/m³ (8 m³, 24 kg, and 16 kg·m² on
each axis), a 0.2 × 0.3 × 0.4 m block at 500 kg/m³ (0.024 m³, 12 kg, and
`Ixx/Iyy/Izz = 0.25/0.20/0.13 kg·m²`), and a block with permuted axis lengths.
Checks also cover edits, identity, placement independence, input validation,
quaternion normalization, tensor symmetry, and numerical range failures.

Material sources, licensing, and an import format must be agreed before an
importer is implemented. Forces, joints, dynamics, and UI integration are deferred.
