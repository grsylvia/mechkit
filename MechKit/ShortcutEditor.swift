import AppKit
import SwiftUI

struct ShortcutEditor: View {
    @Environment(ViewShortcutStore.self) private var shortcuts
    @Environment(\.dismiss) private var dismiss
    @State private var recording: ShortcutRecording?

    var body: some View {
        VStack(alignment: .leading, spacing: UISpacing.sectionGap) {
            Text("View Shortcuts").font(.title2.bold())
            Text(
                "Click a shortcut box, press a key combination, then press Enter to save. Escape cancels."
            )
            .font(.callout)
            .foregroundStyle(.secondary)

            Grid(
                alignment: .leading, horizontalSpacing: UISpacing.contentMargin,
                verticalSpacing: UISpacing.controlGap
            ) {
                ForEach(CameraViewPreset.allCases) { preset in
                    GridRow {
                        Text(preset.title)
                        Button {
                            recording = ShortcutRecording(preset: preset)
                        } label: {
                            Text(boxLabel(for: preset))
                                .monospaced()
                                .frame(width: 160, height: 24)
                        }
                        .buttonStyle(.bordered)
                        .tint(recording?.preset == preset ? .accentColor : nil)
                        .accessibilityLabel("\(preset.title) shortcut")
                    }
                }
            }
            Text(
                recording?.error ?? shortcuts.loadWarning
                    ?? (recording == nil ? " " : "Listening… Enter saves; Escape cancels.")
            )
            .font(.callout)
            .foregroundStyle(recording?.error == nil ? Color.secondary : Color.red)
            .frame(minHeight: 32, alignment: .topLeading)

            HStack(spacing: UISpacing.controlGap) {
                Spacer()
                Button("Done") { dismiss() }
                    .disabled(recording != nil)
            }
        }
        .padding(UISpacing.contentMargin)
        .frame(width: 420)
        .background {
            ShortcutKeyCapture(isRecording: recording != nil) { input in
                guard var session = recording else { return }
                recording =
                    session.handle(input, store: shortcuts, menu: NSApp?.mainMenu) ? nil : session
            }
        }
        .interactiveDismissDisabled(recording != nil)
    }

    private func boxLabel(for preset: CameraViewPreset) -> String {
        guard let recording, recording.preset == preset else { return shortcuts[preset].display }
        return recording.pending?.display ?? "Press keys…"
    }
}

private struct ShortcutKeyCapture: NSViewRepresentable {
    let isRecording: Bool
    let receiveInput: (ShortcutRecordingInput) -> Void

    func makeNSView(context: Context) -> ShortcutKeyCaptureView {
        let view = ShortcutKeyCaptureView()
        updateNSView(view, context: context)
        return view
    }

    func updateNSView(_ view: ShortcutKeyCaptureView, context: Context) {
        view.isRecording = isRecording
        view.receiveInput = receiveInput
    }

    static func dismantleNSView(_ view: ShortcutKeyCaptureView, coordinator: ()) {
        view.stopMonitoring()
    }
}

private final class ShortcutKeyCaptureView: NSView {
    var isRecording = false
    var receiveInput: (ShortcutRecordingInput) -> Void = { _ in }
    private var monitor: Any?

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        stopMonitoring()
        guard window != nil else { return }
        // App-local monitoring only, limited to this editor's window and recording session.
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isRecording, let window = self.window,
                event.window === window
            else { return event }
            switch event.keyCode {
            case 36, 76: self.receiveInput(.confirm)
            case 53: self.receiveInput(.cancel)
            default:
                if let shortcut = ViewShortcut(event: event) {
                    self.receiveInput(.shortcut(shortcut))
                } else {
                    self.receiveInput(.unsupported)
                }
            }
            return nil
        }
    }

    func stopMonitoring() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}
