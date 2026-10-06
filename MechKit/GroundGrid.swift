import AppKit
import RealityKit

enum GroundGrid {
    static let spacingMeters: Float = 0.01
    static let majorLineInterval = 5
    static let halfLineCount = 25
    static let linePositionsMeters = (-halfLineCount...halfLineCount).map {
        Float($0) * spacingMeters
    }

    @MainActor
    static func makeEntity() -> Entity {
        let grid = Entity()
        grid.name = "Ground grid"
        let lengthMeters = Float(halfLineCount * 2) * spacingMeters
        let minorWidthMeters: Float = 0.00015
        let majorWidthMeters: Float = 0.00035
        let heightMeters: Float = 0.00005
        let minorMesh = MeshResource.generateBox(
            size: SIMD3(lengthMeters, minorWidthMeters, heightMeters)
        )
        let majorMesh = MeshResource.generateBox(
            size: SIMD3(lengthMeters, majorWidthMeters, heightMeters)
        )
        let minorMaterial = UnlitMaterial(color: NSColor(white: 0.3, alpha: 1))
        let majorMaterial = UnlitMaterial(color: NSColor(white: 0.5, alpha: 1))

        // The grid lies in XY at Z = 0, with all lengths in meters.
        for (offset, positionMeters) in linePositionsMeters.enumerated() {
            let index = offset - halfLineCount
            let isMajor = index.isMultiple(of: majorLineInterval)
            let mesh = isMajor ? majorMesh : minorMesh
            let material = isMajor ? majorMaterial : minorMaterial

            let xLine = ModelEntity(mesh: mesh, materials: [material])
            xLine.position = SIMD3(0, positionMeters, -heightMeters / 2)
            grid.addChild(xLine)

            let yLine = ModelEntity(mesh: mesh, materials: [material])
            yLine.position = SIMD3(positionMeters, 0, -heightMeters / 2)
            yLine.orientation = simd_quatf(angle: .pi / 2, axis: SIMD3(0, 0, 1))
            grid.addChild(yLine)
        }
        return grid
    }
}
