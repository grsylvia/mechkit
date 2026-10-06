import Foundation
import simd

@main
struct WorkspaceChecks {
    static func expect(_ condition: Bool, _ message: String) {
        guard condition else { fatalError(message) }
    }

    static func close(_ actual: Float, _ expected: Float, _ message: String) {
        expect(abs(actual - expected) < 0.00001, message)
    }

    static func close(_ actual: SIMD3<Float>, _ expected: SIMD3<Float>, _ message: String) {
        expect(simd_length(actual - expected) < 0.00001, message)
    }

    static func main() {
        let positions = GroundGrid.linePositionsMeters
        expect(positions.count == 51, "Grid must have 51 lines per direction")
        close(positions.first!, -0.25, "Grid minimum extent")
        close(positions.last!, 0.25, "Grid maximum extent")
        close(positions[25], 0, "Grid must cross the origin")
        for index in 1..<positions.count {
            close(positions[index] - positions[index - 1], 0.01, "10 mm grid spacing")
        }
        close(
            Float(GroundGrid.majorLineInterval) * GroundGrid.spacingMeters, 0.05,
            "50 mm major grid spacing")

        let initial = CameraState()
        close(initial.positionMeters, SIMD3(0.24, -0.24, 0.26), "Initial camera position")
        close(simd_cross(initial.right, initial.up), initial.backward, "Right-handed basis")
        close(
            initial.orientation.act(SIMD3(0, 0, -1)), -initial.backward,
            "Camera looks toward its target")

        var front = initial
        front.setView(.front)
        close(front.right, SIMD3(1, 0, 0), "Front view right")
        close(front.up, SIMD3(0, 0, 1), "Front view is Z-up")
        close(front.backward, SIMD3(0, -1, 0), "Front view direction")
        let frontX = front.projectAxis(SIMD3(1, 0, 0))
        let frontY = front.projectAxis(SIMD3(0, 1, 0))
        let frontZ = front.projectAxis(SIMD3(0, 0, 1))
        close(frontX.x, 1, "Indicator X points right")
        close(frontX.y, 0, "Indicator X is horizontal")
        close(frontZ.y, -1, "Indicator Z points up")
        close(simd_length(frontY), 0, "Front-view Y is perpendicular to screen")

        var side = front
        side.setView(.right)
        close(side.backward, SIMD3(1, 0, 0), "Quarter-turn camera direction")
        close(side.projectAxis(SIMD3(0, 1, 0)).x, 1, "Right-view Y points right")
        let beforePan = side.targetMeters
        side.pan(rightMeters: 0.1, upMeters: 0.05)
        close(side.targetMeters - beforePan, SIMD3(0, 0.1, 0.05), "Pan in camera plane")
        close(side.distanceMeters, initial.distanceMeters, "Pan preserves distance")
        close(
            front.metersPerPoint(viewportHeightPoints: 600)! * 600,
            2 * front.distanceMeters * tan(.pi / 8), "Perspective pan scale")

        var top = side
        top.setView(.top)
        close(top.backward, SIMD3(0, 0, 1), "Top view looks down -Z")
        close(top.right, SIMD3(1, 0, 0), "Top-view X points right")
        close(top.up, SIMD3(0, 1, 0), "Top-view Y points up")
        close(
            top.orientation.act(SIMD3(0, 0, -1)), SIMD3(0, 0, -1),
            "Top camera transform has the expected direction")
        var moved = side
        moved.zoom(factor: 2)
        let savedTarget = moved.targetMeters
        let savedDistance = moved.distanceMeters
        for preset in CameraViewPreset.allCases {
            moved.setView(preset)
            close(moved.targetMeters, savedTarget, "Named views preserve pan")
            close(moved.distanceMeters, savedDistance, "Named views preserve zoom")
            close(simd_cross(moved.right, moved.up), moved.backward, "Named-view handedness")
        }
        for axis in [SIMD3<Float>(1, 0, 0), SIMD3(0, 1, 0), SIMD3(0, 0, 1)] {
            close(
                simd_length(moved.projectAxis(axis)), sqrt(2.0 / 3.0),
                "Isometric axes have equal foreshortening")
        }

        var zoom = initial
        zoom.zoom(factor: 2)
        close(zoom.distanceMeters, initial.distanceMeters / 2, "Zoom factor")
        zoom.zoom(factor: Float.greatestFiniteMagnitude)
        close(zoom.distanceMeters, CameraState.minimumDistanceMeters, "Near zoom limit")
        zoom.zoom(factor: Float.leastNonzeroMagnitude)
        close(zoom.distanceMeters, CameraState.maximumDistanceMeters, "Far zoom limit")
        zoom.zoom(logDistanceDelta: -Float.greatestFiniteMagnitude)
        close(zoom.distanceMeters, CameraState.minimumDistanceMeters, "Extreme scroll input")

        var poles = initial
        poles.orbit(
            deltaYawRadians: Float.greatestFiniteMagnitude,
            deltaElevationRadians: Float.greatestFiniteMagnitude)
        expect(poles.elevationRadians < .pi / 2, "Camera must not reach pole singularity")
        close(simd_length(poles.up), 1, "Camera up remains normalized")
        close(simd_dot(poles.up, poles.backward), 0, "Camera basis remains orthogonal")

        for invalid: Float in [.nan, .infinity, -.infinity] {
            var state = initial
            state.orbit(deltaYawRadians: invalid, deltaElevationRadians: 0)
            state.orbit(deltaYawRadians: 0, deltaElevationRadians: invalid)
            state.pan(rightMeters: invalid, upMeters: 0)
            state.pan(rightMeters: 0, upMeters: invalid)
            state.zoom(factor: invalid)
            state.zoom(logDistanceDelta: invalid)
            expect(state == initial, "Non-finite inputs must leave camera unchanged")
            expect(
                state.metersPerPoint(viewportHeightPoints: invalid) == nil,
                "Reject non-finite viewport dimensions")
        }
        var state = initial
        state.zoom(factor: 0)
        state.zoom(factor: -1)
        state.pan(rightMeters: .greatestFiniteMagnitude, upMeters: .greatestFiniteMagnitude)
        expect(state == initial, "Reject invalid zoom and overflowing pan")
        expect(state.metersPerPoint(viewportHeightPoints: 0) == nil, "Reject empty viewport")
        state = side
        state.reset()
        close(state.positionMeters, SIMD3(0.24, -0.24, 0.26), "Reset restores initial position")
        close(state.targetMeters, SIMD3(0, 0, 0.02), "Reset restores initial target")
        close(
            state.orientation.act(SIMD3(0, 0, -1)), -initial.backward,
            "Reset restores initial orientation")
        print(
            "Workspace checks passed: grid, camera poses, projection, pan, zoom, reset, invalid inputs."
        )
    }
}
