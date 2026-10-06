import Foundation
import simd

enum CameraViewPreset: String, CaseIterable, Codable, Identifiable {
    case front, top, right, isometric

    var id: String { rawValue }
    var title: String {
        switch self {
        case .front: "Front"
        case .top: "Top"
        case .right: "Right"
        case .isometric: "Isometric"
        }
    }
    var planeLabel: String {
        switch self {
        case .front: "XZ"
        case .top: "XY"
        case .right: "YZ"
        case .isometric: "Iso"
        }
    }
}

struct CameraState: Equatable {
    static let fieldOfViewDegrees: Float = 45
    static let minimumDistanceMeters: Float = 0.1
    static let maximumDistanceMeters: Float = 3
    private static let elevationLimitRadians: Float = .pi / 2 - 0.01

    private(set) var targetMeters = SIMD3<Float>(0, 0, 0.02)
    private(set) var distanceMeters: Float = sqrt(3 * 0.24 * 0.24)
    private(set) var yawRadians: Float = .pi / 4
    private(set) var elevationRadians: Float = asin(1 / sqrt(3))

    // World +Z is up. Front is from -Y, Top from +Z, Right from +X.
    // Camera-local +X is right, +Y is up, and +Z points toward the viewer.
    var right: SIMD3<Float> { SIMD3(cos(yawRadians), sin(yawRadians), 0) }
    var up: SIMD3<Float> {
        SIMD3(
            -sin(elevationRadians) * sin(yawRadians),
            sin(elevationRadians) * cos(yawRadians), cos(elevationRadians))
    }
    var backward: SIMD3<Float> {
        SIMD3(
            cos(elevationRadians) * sin(yawRadians),
            -cos(elevationRadians) * cos(yawRadians), sin(elevationRadians))
    }
    var positionMeters: SIMD3<Float> { targetMeters + backward * distanceMeters }
    var orientation: simd_quatf {
        simd_quatf(simd_float3x3(columns: (right, up, backward)))
    }

    mutating func reset() {
        self = CameraState()
    }

    mutating func setView(_ preset: CameraViewPreset) {
        switch preset {
        case .front:
            yawRadians = 0
            elevationRadians = 0
        case .top:
            yawRadians = 0
            elevationRadians = .pi / 2
        case .right:
            yawRadians = .pi / 2
            elevationRadians = 0
        case .isometric:
            yawRadians = .pi / 4
            elevationRadians = asin(1 / sqrt(3))
        }
    }

    mutating func orbit(deltaYawRadians: Float, deltaElevationRadians: Float) {
        guard deltaYawRadians.isFinite, deltaElevationRadians.isFinite else { return }
        let turnRadians: Float = 2 * .pi
        yawRadians = (yawRadians + deltaYawRadians.truncatingRemainder(dividingBy: turnRadians))
            .truncatingRemainder(dividingBy: turnRadians)
        elevationRadians = min(
            Self.elevationLimitRadians,
            max(
                -Self.elevationLimitRadians,
                elevationRadians + min(.pi, max(-.pi, deltaElevationRadians))))
    }

    mutating func pan(rightMeters: Float, upMeters: Float) {
        guard rightMeters.isFinite, upMeters.isFinite else { return }
        let nextTargetMeters = targetMeters + right * rightMeters + up * upMeters
        guard simd_length(nextTargetMeters).isFinite else { return }
        targetMeters = nextTargetMeters
    }

    mutating func zoom(factor: Float) {
        guard factor.isFinite, factor > 0 else { return }
        distanceMeters = min(
            Self.maximumDistanceMeters,
            max(Self.minimumDistanceMeters, distanceMeters / factor))
    }

    mutating func zoom(logDistanceDelta: Float) {
        guard logDistanceDelta.isFinite else { return }
        zoom(factor: exp(-min(10, max(-10, logDistanceDelta))))
    }

    func metersPerPoint(viewportHeightPoints: Float) -> Float? {
        guard viewportHeightPoints.isFinite, viewportHeightPoints >= 1 else { return nil }
        return 2 * distanceMeters * tan(Self.fieldOfViewDegrees * .pi / 360)
            / viewportHeightPoints
    }

    // Orthographic projection for the orientation indicator; screen +Y is down.
    func projectAxis(_ worldAxis: SIMD3<Float>) -> SIMD2<Float> {
        SIMD2(simd_dot(worldAxis, right), -simd_dot(worldAxis, up))
    }
}
