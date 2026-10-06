import SwiftUI
import simd

struct CoordinateIndicator: View {
    let cameraState: CameraState
    let selectView: (CameraViewPreset) -> Void

    var body: some View {
        VStack(spacing: UISpacing.controlGap) {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let planes: [(first: SIMD3<Float>, second: SIMD3<Float>, color: Color)] = [
                    (SIMD3(1, 0, 0), SIMD3(0, 0, 1), .green),  // Front: XZ.
                    (SIMD3(1, 0, 0), SIMD3(0, 1, 0), .blue),  // Top: XY.
                    (SIMD3(0, 1, 0), SIMD3(0, 0, 1), .red),  // Right: YZ.
                ]
                for plane in planes {
                    let corners = [
                        SIMD3<Float>.zero, plane.first,
                        plane.first + plane.second, plane.second,
                    ]
                    var face = Path()
                    for (index, corner) in corners.enumerated() {
                        let projected = cameraState.projectAxis(corner)
                        let point = CGPoint(
                            x: center.x + CGFloat(projected.x) * 26,
                            y: center.y + CGFloat(projected.y) * 26)
                        if index == 0 { face.move(to: point) } else { face.addLine(to: point) }
                    }
                    face.closeSubpath()
                    context.fill(face, with: .color(plane.color.opacity(0.15)))
                    context.stroke(face, with: .color(plane.color.opacity(0.4)), lineWidth: 0.75)
                }
                let axes: [(label: String, direction: SIMD3<Float>, color: Color)] = [
                    ("X", SIMD3(1, 0, 0), .red),
                    ("Y", SIMD3(0, 1, 0), .green),
                    ("Z", SIMD3(0, 0, 1), .blue),
                ]
                // Draw the axes farther from the viewer first.
                for axis in axes.sorted(by: {
                    simd_dot($0.direction, cameraState.backward)
                        < simd_dot($1.direction, cameraState.backward)
                }) {
                    let projected = cameraState.projectAxis(axis.direction)
                    let length = simd_length(projected)
                    let end = CGPoint(
                        x: center.x + CGFloat(projected.x) * 26,
                        y: center.y + CGFloat(projected.y) * 26)
                    var line = Path()
                    line.move(to: center)
                    line.addLine(to: end)
                    context.stroke(line, with: .color(axis.color), lineWidth: 2)

                    let labelPosition: CGPoint
                    if length > 0.1 {
                        let dx = CGFloat(projected.x / length)
                        let dy = CGFloat(projected.y / length)
                        var arrow = Path()
                        arrow.move(
                            to: CGPoint(
                                x: end.x - dx * 5 - dy * 3,
                                y: end.y - dy * 5 + dx * 3))
                        arrow.addLine(to: end)
                        arrow.addLine(
                            to: CGPoint(
                                x: end.x - dx * 5 + dy * 3,
                                y: end.y - dy * 5 - dx * 3))
                        context.stroke(arrow, with: .color(axis.color), lineWidth: 2)
                        labelPosition = CGPoint(x: end.x + dx * 10, y: end.y + dy * 10)
                    } else {
                        let marker = Path(
                            ellipseIn: CGRect(
                                x: end.x - 4, y: end.y - 4,
                                width: 8, height: 8))
                        if simd_dot(axis.direction, cameraState.backward) > 0 {
                            context.fill(marker, with: .color(axis.color))
                        } else {
                            context.stroke(marker, with: .color(axis.color), lineWidth: 2)
                        }
                        labelPosition = CGPoint(x: end.x + 10, y: end.y + 10)
                    }
                    context.draw(
                        Text(axis.label).font(.system(size: 12, weight: .semibold))
                            .foregroundColor(axis.color), at: labelPosition)
                }
            }
            .frame(width: 104, height: 104)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Coordinate axes: X red, Y green, Z blue. Z is up.")
            .allowsHitTesting(false)

            Grid(horizontalSpacing: UISpacing.controlGap, verticalSpacing: UISpacing.controlGap) {
                GridRow {
                    viewButton(.front)
                    viewButton(.top)
                }
                GridRow {
                    viewButton(.right)
                    viewButton(.isometric)
                }
            }
            .controlSize(.mini)
        }
        .padding(UISpacing.containerPadding)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private func viewButton(_ preset: CameraViewPreset) -> some View {
        Button(preset == .isometric ? "Iso" : "\(preset.title) · \(preset.planeLabel)") {
            selectView(preset)
        }
        .buttonStyle(.bordered)
        .help("Show \(preset.title.lowercased()) view")
    }
}
