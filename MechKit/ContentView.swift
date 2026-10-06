import RealityKit
import SwiftUI

struct ContentView: View {
    @Environment(ViewShortcutStore.self) private var shortcuts
    @State private var cameraState = CameraState()
    @State private var showingShortcutEditor = false

    var body: some View {
        RealityView { content in
            content.camera = .virtual

            // This scene uses meters in a right-handed frame with +Z up.
            let blockSizeMeters = SIMD3<Float>(0.12, 0.08, 0.04)
            let block = ModelEntity(
                mesh: .generateBox(size: blockSizeMeters),
                materials: [SimpleMaterial(color: .systemBlue, roughness: 0.6, isMetallic: false)]
            )
            block.name = "Sample block"
            block.position.z = blockSizeMeters.z / 2
            content.add(block)
            content.add(GroundGrid.makeEntity())

            let camera = PerspectiveCamera()
            camera.name = "Workspace camera"
            camera.camera = PerspectiveCameraComponent(
                near: 0.001,
                far: 10,
                fieldOfViewInDegrees: CameraState.fieldOfViewDegrees,
                fieldOfViewOrientation: .vertical
            )
            camera.transform = Transform(
                rotation: cameraState.orientation,
                translation: cameraState.positionMeters)
            content.add(camera)

            let light = DirectionalLight()
            light.light.intensity = 2_000  // Illuminance in lux.
            let lightPositionMeters = SIMD3<Float>(0.2, -0.3, 0.4)
            light.look(
                at: .zero, from: lightPositionMeters,
                upVector: SIMD3(0, 0, 1), relativeTo: nil)
            content.add(light)
        } update: { content in
            if let camera = content.entities.first(where: { $0.name == "Workspace camera" }) {
                camera.transform = Transform(
                    rotation: cameraState.orientation,
                    translation: cameraState.positionMeters)
            }
        }
        .realityViewCameraControls(.none)
        .overlay {
            CameraInputSurface(cameraState: $cameraState)
                .help("Drag to orbit. Shift-drag or right-drag to pan. Scroll or pinch to zoom.")
        }
        .overlay(alignment: .topTrailing) {
            Button("Reset view", systemImage: "arrow.counterclockwise") {
                cameraState.reset()
            }
            .padding(12)
        }
        .overlay(alignment: .bottomLeading) {
            CoordinateIndicator(cameraState: cameraState) { cameraState.setView($0) }
                .padding(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minWidth: 400, minHeight: 300)
        .focusedSceneValue(
            \.workspaceActions,
            WorkspaceActions(
                selectView: { cameraState.setView($0) },
                editShortcuts: { showingShortcutEditor = true }
            )
        )
        .sheet(isPresented: $showingShortcutEditor) {
            ShortcutEditor().environment(shortcuts)
        }
    }
}

#Preview {
    ContentView()
        .environment(ViewShortcutStore())
}
