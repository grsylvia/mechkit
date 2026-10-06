import SwiftUI

struct PartInspector: View {
    let part: PartRecord
    let apply: (PartRecord) -> Void
    @State private var draft: PartDraft
    @State private var errorMessage: String?

    init(part: PartRecord, apply: @escaping (PartRecord) -> Void) {
        self.part = part
        self.apply = apply
        _draft = State(initialValue: PartDraft(part: part))
    }

    var body: some View {
        Form {
            Section("Part") {
                TextField("Name", text: $draft.name)
            }
            Section("Dimensions (m)") {
                VectorFields(vector: $draft.dimensions)
            }
            Section("Position (m)") {
                VectorFields(vector: $draft.position)
                Text("Part center in the assembly frame. +Z is up.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .accessibilityLabel(errorMessage)
                }
                HStack {
                    Button("Revert") { resetDraft() }
                    Spacer()
                    Button("Apply", action: submit)
                }
                .disabled(draft == PartDraft(part: part))
            }
        }
        .formStyle(.grouped)
        .onSubmit(submit)
        .onChange(of: part) { _, _ in resetDraft() }
    }

    private func resetDraft() {
        draft = PartDraft(part: part)
        errorMessage = nil
    }

    private func submit() {
        do {
            let edited = try draft.applying(to: part)
            if edited != part { apply(edited) }
            draft = PartDraft(part: edited)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct VectorFields: View {
    @Binding var vector: VectorDraft

    var body: some View {
        TextField("X", text: $vector.x)
        TextField("Y", text: $vector.y)
        TextField("Z", text: $vector.z)
    }
}
