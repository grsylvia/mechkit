import RealityKit
import SwiftUI

struct ContentView: View {
    @Binding var assembly: AssemblyRecord
    @Environment(ViewShortcutStore.self) private var shortcuts
    @Environment(\.undoManager) private var undoManager
    @State private var cameraState = CameraState()
    @State private var showingShortcutEditor = false
    @State private var selectedPartID: UUID?
    @State private var showingInspector = true

    init(assembly: Binding<AssemblyRecord>) {
        _assembly = assembly
        _selectedPartID = State(initialValue: assembly.wrappedValue.parts.first?.id)
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedPartID) {
                ForEach(assembly.parts) { part in
                    Label(part.name, systemImage: "cube")
                        .tag(part.id)
                }
            }
            .navigationTitle("Parts")
            .navigationSplitViewColumnWidth(min: 160, ideal: 200, max: 280)
            .overlay {
                if assembly.parts.isEmpty {
                    ContentUnavailableView(
                        "No Parts", systemImage: "cube", description: Text("Add a block to begin."))
                }
            }
        } detail: {
            workspace
        }
        .inspector(isPresented: $showingInspector) {
            if let part = selectedPart {
                PartInspector(part: part, apply: updatePart)
                    .id(part.id)
                    .inspectorColumnWidth(min: 260, ideal: 300, max: 360)
            } else {
                ContentUnavailableView(
                    "Select a Part", systemImage: "cube",
                    description: Text("Choose a part in the sidebar to edit it.")
                )
                .inspectorColumnWidth(min: 260, ideal: 300, max: 360)
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button("Add Block", systemImage: "plus", action: addBlock)
                    .help("Add a rectangular block")
                Button("Remove Part", systemImage: "minus", action: removePart)
                    .disabled(selectedPart == nil)
                    .help("Remove the selected part")
                Button("Reset View", systemImage: "arrow.counterclockwise") {
                    cameraState.reset()
                }
                .help("Restore the initial camera")
            }
            ToolbarItem {
                Button(
                    showingInspector ? "Hide Inspector" : "Show Inspector",
                    systemImage: "sidebar.right"
                ) {
                    showingInspector.toggle()
                }
                .help(showingInspector ? "Hide inspector" : "Show inspector")
            }
        }
        .onChange(of: assembly.parts.map(\.id)) { _, ids in
            if let selectedPartID, !ids.contains(selectedPartID) { self.selectedPartID = nil }
        }
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

    private var selectedPart: PartRecord? {
        assembly.parts.first { $0.id == selectedPartID }
    }

    private var renderingErrors: [String] {
        assembly.parts.compactMap { part in
            do {
                _ = try PartRenderValues(part: part)
                return nil
            } catch {
                return error.localizedDescription
            }
        }
    }

    private var workspace: some View {
        RealityView { content in
            content.camera = .virtual
            let parts = Entity()
            parts.name = "Assembly parts"
            synchronizeParts(parts)
            content.add(parts)
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
            if let parts = content.entities.first(where: { $0.name == "Assembly parts" }) {
                synchronizeParts(parts)
            }
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
        .overlay(alignment: .topLeading) {
            if !renderingErrors.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Some parts cannot be displayed", systemImage: "exclamationmark.triangle")
                        .font(.headline)
                    ForEach(Array(renderingErrors.enumerated()), id: \.offset) { error in
                        Text(error.element).font(.caption)
                    }
                }
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                .padding(12)
            }
        }
        .overlay(alignment: .bottomLeading) {
            CoordinateIndicator(cameraState: cameraState) { cameraState.setView($0) }
                .padding(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minWidth: 400, minHeight: 300)
    }

    private func synchronizeParts(_ root: Entity) {
        let ids = Set(assembly.parts.map { $0.id.uuidString })
        for child in Array(root.children) where !ids.contains(child.name) {
            child.removeFromParent()
        }
        for part in assembly.parts {
            guard let values = try? PartRenderValues(part: part) else {
                root.children.first { $0.name == part.id.uuidString }?.removeFromParent()
                continue  // The viewport reports the conversion error above.
            }
            let block: ModelEntity
            if let existing = root.children.first(where: { $0.name == part.id.uuidString })
                as? ModelEntity
            {
                block = existing
            } else {
                block = ModelEntity(mesh: .generateBox(size: SIMD3<Float>(repeating: 1)))
                block.name = part.id.uuidString
                root.addChild(block)
            }
            block.model?.materials = [
                SimpleMaterial(
                    color: part.id == selectedPartID ? .systemOrange : .systemBlue,
                    roughness: 0.6, isMetallic: false)
            ]
            block.transform = Transform(
                scale: values.dimensionsMeters, rotation: values.orientation,
                translation: values.positionMeters)
        }
    }

    private func addBlock() {
        let names = Set(assembly.parts.map(\.name))
        var number = 1
        while names.contains("Block \(number)") { number += 1 }
        let part = PartRecord(
            name: "Block \(number)", dimensionsMeters: Vector3Record(x: 0.12, y: 0.08, z: 0.04),
            positionMeters: Vector3Record(x: 0.15 * Double(assembly.parts.count), y: 0, z: 0.02))
        var candidate = assembly
        candidate.parts.append(part)
        assembly = candidate
        undoManager?.setActionName("Add Block")
        selectedPartID = part.id
    }

    private func removePart() {
        guard let selectedPartID else { return }
        var candidate = assembly
        candidate.parts.removeAll { $0.id == selectedPartID }
        assembly = candidate
        undoManager?.setActionName("Remove Part")
        self.selectedPartID = nil
    }

    private func updatePart(_ part: PartRecord) {
        guard let index = assembly.parts.firstIndex(where: { $0.id == part.id }) else { return }
        var candidate = assembly
        candidate.parts[index] = part
        assembly = candidate
        undoManager?.setActionName("Edit Part")
    }
}

#Preview {
    @Previewable @State var assembly = AssemblyRecord.sample
    ContentView(assembly: $assembly)
        .environment(ViewShortcutStore())
}
