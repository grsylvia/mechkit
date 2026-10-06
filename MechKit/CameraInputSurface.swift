import AppKit
import SwiftUI

struct CameraInputSurface: NSViewRepresentable {
    @Binding var cameraState: CameraState

    func makeNSView(context: Context) -> CameraInputView {
        let view = CameraInputView()
        updateNSView(view, context: context)
        return view
    }

    func updateNSView(_ view: CameraInputView, context: Context) {
        view.onOrbit = { deltaXPoints, deltaYPoints in
            cameraState.orbit(deltaYawRadians: -deltaXPoints * 0.008,
                              deltaElevationRadians: deltaYPoints * 0.008)
        }
        view.onPan = { deltaXPoints, deltaYPoints, heightPoints in
            guard let scale = cameraState.metersPerPoint(viewportHeightPoints: heightPoints) else {
                return
            }
            // Move the camera opposite the pointer so the scene follows the drag.
            cameraState.pan(rightMeters: -deltaXPoints * scale, upMeters: deltaYPoints * scale)
        }
        view.onScroll = { delta in cameraState.zoom(logDistanceDelta: delta) }
        view.onMagnify = { factor in cameraState.zoom(factor: factor) }
    }
}

final class CameraInputView: NSView {
    var onOrbit: (Float, Float) -> Void = { _, _ in }
    var onPan: (Float, Float, Float) -> Void = { _, _, _ in }
    var onScroll: (Float) -> Void = { _ in }
    var onMagnify: (Float) -> Void = { _ in }
    private var isPanning = false

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        isPanning = event.modifierFlags.contains(.shift)
        window?.makeFirstResponder(self)
    }

    override func mouseDragged(with event: NSEvent) {
        if isPanning {
            pan(with: event)
        } else {
            onOrbit(Float(event.deltaX), Float(event.deltaY))
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }
    override func rightMouseDragged(with event: NSEvent) { pan(with: event) }
    override func otherMouseDragged(with event: NSEvent) { pan(with: event) }

    override func scrollWheel(with event: NSEvent) {
        let sensitivity: Float = event.hasPreciseScrollingDeltas ? 0.005 : 0.1
        onScroll(-Float(event.scrollingDeltaY) * sensitivity)
    }

    override func magnify(with event: NSEvent) {
        onMagnify(1 + Float(event.magnification))
    }

    private func pan(with event: NSEvent) {
        onPan(Float(event.deltaX), Float(event.deltaY), Float(bounds.height))
    }
}
