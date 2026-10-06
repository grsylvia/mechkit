import Foundation
import simd

@main
struct PhysicsChecks {
    static func expect(_ condition: Bool, _ message: String) {
        guard condition else { fatalError(message) }
    }

    static func rejects(_ expected: PhysicsError, _ message: String,
                        _ operation: () throws -> Void) {
        do {
            try operation()
            fatalError(message + ": input was accepted")
        } catch let error as PhysicsError {
            expect(error == expected, message + ": unexpected error \(error)")
        } catch {
            fatalError(message + ": unexpected error \(error)")
        }
    }

    static func checkGeometryAndMaterial() throws {
        let geometry = try Geometry(rectangularBlockDimensionsMeters: SIMD3(0.2, 0.3, 0.4))
        expect(geometry.shape == .solidRectangularBlock, "Explicit solid block shape")
        expect(geometry.dimensionsMeters == SIMD3(0.2, 0.3, 0.4), "Dimensions retain meters")
        // Synthetic numerical fixture; this is not a real material specification.
        let material = try Material(name: "  Synthetic fixture  ", densityKgPerCubicMeter: 500,
                                    source: "  PhysicsChecks analytical fixture  ")
        expect(material.name == "Synthetic fixture", "Trim material name")
        expect(material.source == "PhysicsChecks analytical fixture", "Retain material provenance")
        expect(material.densityKgPerCubicMeter == 500, "Retain explicitly supplied density")
        for invalid: Double in [0, -1, .nan, .infinity, -.infinity] {
            for axis in 0..<3 {
                var dimensions = geometry.dimensionsMeters
                dimensions[axis] = invalid
                rejects(.invalidDimensions, "Reject invalid dimension on axis \(axis)") {
                    _ = try Geometry(rectangularBlockDimensionsMeters: dimensions)
                }
            }
            rejects(.invalidDensity, "Reject invalid material density") {
                _ = try Material(name: "Synthetic fixture", densityKgPerCubicMeter: invalid,
                                 source: "PhysicsChecks")
            }
        }
        for blank in ["", " ", "\n\t"] {
            rejects(.invalidMaterialName, "Reject missing material name") {
                _ = try Material(name: blank, densityKgPerCubicMeter: 500, source: "PhysicsChecks")
            }
            rejects(.invalidMaterialSource, "Reject missing material provenance") {
                _ = try Material(name: "Synthetic fixture", densityKgPerCubicMeter: 500, source: blank)
            }
        }
    }

    static func close(_ actual: Double, _ expected: Double, _ message: String) {
        expect(actual.isFinite && expected.isFinite, message + ": finite values required")
        let matches = expected == 0 ? abs(actual) <= 1e-14 : abs((actual - expected) / expected) <= 1e-12
        expect(matches, message + ": \(actual) != \(expected)")
    }

    static func close(_ actual: SIMD3<Double>, _ expected: SIMD3<Double>, _ message: String) {
        for axis in 0..<3 { close(actual[axis], expected[axis], message + " axis \(axis)") }
    }

    static func checkPlacementAndValues() throws {
        let identity = Placement()
        close(identity.positionMeters, .zero, "Identity position")
        close(identity.orientationLocalToAssembly.act(SIMD3(1, 0, 0)), SIMD3(1, 0, 0),
              "Identity orientation")
        let placement = try Placement(positionMeters: SIMD3(1, -2, 3),
            orientationLocalToAssembly: simd_quatd(angle: .pi / 2, axis: SIMD3(0, 0, 1)))
        close(placement.positionMeters, SIMD3(1, -2, 3), "Assembly position in meters")
        close(placement.orientationLocalToAssembly.act(SIMD3(1, 0, 0)), SIMD3(0, 1, 0),
              "Positive Z rotation maps local X to assembly Y")
        let x = placement.orientationLocalToAssembly.act(SIMD3(1, 0, 0))
        let y = placement.orientationLocalToAssembly.act(SIMD3(0, 1, 0))
        let z = placement.orientationLocalToAssembly.act(SIMD3(0, 0, 1))
        close(simd_cross(x, y), z, "Placement remains right-handed")
        for magnitude: Double in [2, .greatestFiniteMagnitude, .leastNonzeroMagnitude] {
            let normalized = try Placement(positionMeters: .zero,
                orientationLocalToAssembly: simd_quatd(ix: 0, iy: 0, iz: magnitude, r: magnitude))
            close(simd_length(normalized.orientationLocalToAssembly.vector), 1,
                  "Normalize scaled quaternion")
            close(normalized.orientationLocalToAssembly.act(SIMD3(1, 0, 0)), SIMD3(0, 1, 0),
                  "Scaled quaternion preserves rotation")
        }
        rejects(.invalidOrientation, "Reject zero quaternion") {
            _ = try Placement(positionMeters: .zero, orientationLocalToAssembly: simd_quatd(vector: .zero))
        }
        let tensor = try InertiaTensor(diagonalKgMetersSquared: SIMD3(2, 3, 4))
        let matrix = tensor.matrixKgMetersSquared
        for row in 0..<3 {
            for column in 0..<3 {
                close(matrix[column][row], matrix[row][column], "Symmetric inertia matrix")
                if row != column { close(matrix[column][row], 0, "Block off-diagonal entry") }
            }
        }
        rejects(.invalidInertiaTensor, "Reject physically impossible principal moments") {
            _ = try InertiaTensor(diagonalKgMetersSquared: SIMD3(1, 1, 3))
        }
        _ = try MassProperties(volumeCubicMeters: 1, massKilograms: 2,
                               centerOfMassLocalMeters: .zero, inertiaTensorAboutCenterOfMassLocal: tensor)
        for invalid: Double in [.nan, .infinity, -.infinity] {
            for axis in 0..<3 {
                var vector = SIMD3<Double>(0, 0, 0)
                vector[axis] = invalid
                rejects(.invalidPosition, "Reject non-finite position") {
                    _ = try Placement(positionMeters: vector)
                }
                rejects(.invalidCenterOfMass, "Reject non-finite center of mass") {
                    _ = try MassProperties(volumeCubicMeters: 1, massKilograms: 2,
                        centerOfMassLocalMeters: vector, inertiaTensorAboutCenterOfMassLocal: tensor)
                }
            }
            for axis in 0..<4 {
                var vector = SIMD4<Double>(0, 0, 0, 1)
                vector[axis] = invalid
                rejects(.invalidOrientation, "Reject non-finite quaternion component") {
                    _ = try Placement(positionMeters: .zero, orientationLocalToAssembly: simd_quatd(vector: vector))
                }
            }
        }
        for invalid: Double in [0, -1, .nan, .infinity, -.infinity] {
            rejects(.unrepresentableMassProperties, "Reject invalid volume") {
                _ = try MassProperties(volumeCubicMeters: invalid, massKilograms: 2,
                    centerOfMassLocalMeters: .zero, inertiaTensorAboutCenterOfMassLocal: tensor)
            }
            rejects(.unrepresentableMassProperties, "Reject invalid mass") {
                _ = try MassProperties(volumeCubicMeters: 1, massKilograms: invalid,
                    centerOfMassLocalMeters: .zero, inertiaTensorAboutCenterOfMassLocal: tensor)
            }
            for axis in 0..<3 {
                var moments = SIMD3<Double>(2, 3, 4)
                moments[axis] = invalid
                rejects(.unrepresentableMassProperties, "Reject invalid inertia moment") {
                    _ = try InertiaTensor(diagonalKgMetersSquared: moments)
                }
            }
        }
    }

    static func fixtureMaterial(densityKgPerCubicMeter: Double) throws -> Material {
        try Material(name: "Synthetic fixture", densityKgPerCubicMeter: densityKgPerCubicMeter,
                     source: "PhysicsChecks: synthetic density for analytical calculations")
    }

    static func checkProperties(_ component: Component, volume: Double, mass: Double,
                                moments: SIMD3<Double>, _ message: String) throws {
        let properties = try component.massProperties
        close(properties.volumeCubicMeters, volume, message + " volume in m³")
        close(properties.massKilograms, mass, message + " mass in kg")
        close(properties.centerOfMassLocalMeters, .zero, message + " local center of mass in meters")
        let tensor = properties.inertiaTensorAboutCenterOfMassLocal
        close(tensor.xxKgMetersSquared, moments.x, message + " Ixx in kg·m²")
        close(tensor.yyKgMetersSquared, moments.y, message + " Iyy in kg·m²")
        close(tensor.zzKgMetersSquared, moments.z, message + " Izz in kg·m²")
        close(tensor.xyKgMetersSquared, 0, message + " Ixy")
        close(tensor.xzKgMetersSquared, 0, message + " Ixz")
        close(tensor.yzKgMetersSquared, 0, message + " Iyz")
    }

    static func checkComponents() throws {
        let cube = try Component(geometry: Geometry(rectangularBlockDimensionsMeters: SIMD3(2, 2, 2)),
                                 material: fixtureMaterial(densityKgPerCubicMeter: 3))
        // Independent integration over [-1, 1]³: volume = 8; mass = 24.
        // integral(y² dm) = integral(z² dm) = 8, giving each axial inertia = 16.
        try checkProperties(cube, volume: 8, mass: 24, moments: SIMD3(16, 16, 16), "Cube")

        let geometry = try Geometry(rectangularBlockDimensionsMeters: SIMD3(0.2, 0.3, 0.4))
        let material = try fixtureMaterial(densityKgPerCubicMeter: 500)
        let block = try Component(geometry: geometry, material: material)
        // Independent separable integrals over x ±0.1, y ±0.15, z ±0.2:
        // volume = 0.024; mass = 12; integral(x² dm) = 0.04, y² = 0.09, z² = 0.16.
        try checkProperties(block, volume: 0.024, mass: 12, moments: SIMD3(0.25, 0.20, 0.13),
                            "Asymmetric block")
        let sameData = try Component(geometry: geometry, material: material)
        expect(block.id != sameData.id, "Individual parts have distinct identities")
        let originalID = block.id
        let originalProperties = try block.massProperties
        let alias = block
        expect(alias === block, "Component has reference identity")

        block.placement = try Placement(positionMeters: SIMD3(1, -2, 3),
            orientationLocalToAssembly: simd_quatd(angle: .pi / 2, axis: SIMD3(0, 0, 1)))
        let movedProperties = try block.massProperties
        expect(movedProperties == originalProperties, "Translation and rotation preserve local mass properties")
        close(block.placement.positionMeters + block.placement.orientationLocalToAssembly
            .act(movedProperties.centerOfMassLocalMeters), SIMD3(1, -2, 3),
            "Local center maps to placement position")
        let savedPlacement = block.placement
        try alias.setGeometry(Geometry(rectangularBlockDimensionsMeters: SIMD3(0.4, 0.6, 0.8)))
        // Doubling every dimension multiplies volume and mass by 8 and inertia by 32.
        try checkProperties(block, volume: 0.192, mass: 96, moments: SIMD3(8, 6.4, 4.16),
                            "Dimension edit")
        try block.setMaterial(fixtureMaterial(densityKgPerCubicMeter: 1000))
        try checkProperties(block, volume: 0.192, mass: 192, moments: SIMD3(16, 12.8, 8.32),
                            "Density edit")
        expect(block.id == originalID, "Edits preserve identity")
        expect(block.placement == savedPlacement, "Dimension and material edits preserve placement")
        expect(sameData.material == material && sameData.geometry == geometry,
               "Replacing a value record changes only the edited part")
        try checkProperties(sameData, volume: 0.024, mass: 12, moments: SIMD3(0.25, 0.20, 0.13),
                            "Other instance remains unchanged")

        let permuted = try Component(geometry: Geometry(rectangularBlockDimensionsMeters: SIMD3(4, 2, 3)),
                                     material: fixtureMaterial(densityKgPerCubicMeter: 2))
        // mass = 48; integral(x² dm) = 64, y² = 16, z² = 36.
        try checkProperties(permuted, volume: 24, mass: 48, moments: SIMD3(52, 100, 80),
                            "Distinct axis ordering")

        let beforeFailure = try block.massProperties
        let beforeGeometry = block.geometry
        let beforeMaterial = block.material
        rejects(.unrepresentableMassProperties, "Reject overflowing edit without changing geometry") {
            try block.setGeometry(Geometry(rectangularBlockDimensionsMeters: SIMD3(repeating: 1e200)))
        }
        rejects(.unrepresentableMassProperties, "Reject underflowing edit without changing material") {
            try block.setMaterial(fixtureMaterial(densityKgPerCubicMeter: .leastNonzeroMagnitude))
        }
        let afterFailure = try block.massProperties
        expect(block.geometry == beforeGeometry && block.material == beforeMaterial
            && block.placement == savedPlacement && block.id == originalID && afterFailure == beforeFailure,
            "Failed edits preserve all current state")
        rejects(.unrepresentableMassProperties, "Reject overflowing density edit") {
            try cube.setMaterial(fixtureMaterial(densityKgPerCubicMeter: .greatestFiniteMagnitude))
        }
        try checkProperties(cube, volume: 8, mass: 24, moments: SIMD3(16, 16, 16),
                            "Rejected material edit")
    }

    static func checkNumericalRange() throws {
        // Valid primitive values can still produce volume, mass, or inertia outside Double's range.
        let rejected: [(SIMD3<Double>, Double)] = [
            (SIMD3(repeating: 1e200), 1),       // volume overflow
            (SIMD3(repeating: 1e-200), 1),      // volume underflow
            (SIMD3(repeating: 1e100), 1e100),   // mass overflow
            (SIMD3(repeating: 1e-100), 1e-100), // mass underflow
            (SIMD3(1e160, 1, 1), 1),           // inertia overflow
            (SIMD3(repeating: 1e-70), 1)       // inertia underflow
        ]
        for (dimensions, density) in rejected {
            rejects(.unrepresentableMassProperties, "Reject unrepresentable derived properties") {
                _ = try Component(geometry: Geometry(rectangularBlockDimensionsMeters: dimensions),
                                  material: fixtureMaterial(densityKgPerCubicMeter: density))
            }
        }
        // Each separate second moment would round to zero, but their sum rounds to a positive value.
        let subnormal = try Component(geometry: Geometry(rectangularBlockDimensionsMeters: SIMD3(repeating: 1)),
                                      material: fixtureMaterial(densityKgPerCubicMeter: 4 * .leastNonzeroMagnitude))
        try checkProperties(subnormal, volume: 1, mass: 4 * .leastNonzeroMagnitude,
                            moments: SIMD3(repeating: .leastNonzeroMagnitude), "Subnormal inertia")
        // Final values are representable even though directly squaring the X length would overflow.
        let extreme = try Component(geometry: Geometry(rectangularBlockDimensionsMeters: SIMD3(1e160, 1e-5, 1e-5)),
                                    material: fixtureMaterial(densityKgPerCubicMeter: 1e-300))
        try checkProperties(extreme, volume: 1e150, mass: 1e-150,
                            moments: SIMD3(1.6666666666666667e-161, 8.333333333333333e168, 8.333333333333333e168),
                            "Representable extreme block")
    }

    static func main() throws {
        try checkGeometryAndMaterial()
        try checkPlacementAndValues()
        try checkComponents()
        try checkNumericalRange()
        print("Physics checks passed: analytical block properties, edits, identity, placement, validation, numerical range.")
    }
}
