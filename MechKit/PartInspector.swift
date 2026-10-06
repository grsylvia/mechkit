import SwiftUI

struct PartInspector: View {
    let part: PartRecord
    let apply: (PartRecord) -> Void
    @State private var draft: PartDraft
    @State private var errorMessage: String?
    @AppStorage(MaterialNumberFormat.preferenceKey)
    private var storedSignificantFigures = MaterialNumberFormat.defaultSignificantFigures

    private var significantFigures: Int {
        MaterialNumberFormat.significantFigures(storedSignificantFigures)
    }

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
            Section("Rotation (°)") {
                VectorFields(vector: $draft.rotationDegrees)
                Text(
                    "Fixed assembly axes: X, then Y, then Z. Positive angles follow the right-hand rule."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Section("Material") {
                Toggle("Assign Material", isOn: $draft.material.isAssigned)
                if draft.material.isAssigned {
                    TextField("Name", text: $draft.material.name)
                    DensityField(
                        text: $draft.material.densityKgPerCubicMeter,
                        significantFigures: significantFigures)
                    TextField("Source", text: $draft.material.source)
                }
            }
            Section("Mass Properties") {
                Picker(
                    "Significant figures",
                    selection: Binding(
                        get: { significantFigures },
                        set: { storedSignificantFigures = $0 })
                ) {
                    ForEach(MaterialNumberFormat.allowedSignificantFigures, id: \.self) { digits in
                        Text("\(digits)").tag(digits)
                    }
                }
                MassPropertiesReadout(part: part, significantFigures: significantFigures)
            }
            Section {
                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .accessibilityLabel(errorMessage)
                }
                HStack(spacing: UISpacing.controlGap) {
                    Button("Revert") { resetDraft() }
                    Spacer()
                    Button("Apply", action: submit)
                }
                .disabled(draft == PartDraft(part: part))
            }
        }
        .formStyle(.grouped)
        .contentMargins(.horizontal, UISpacing.contentMargin, for: .scrollContent)
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

private struct DensityField: View {
    @Binding var text: String
    let significantFigures: Int
    @FocusState private var isEditing: Bool

    var body: some View {
        TextField(
            "Density (kg/m³)",
            text: Binding(
                get: {
                    MaterialNumberFormat.densityText(
                        text, isEditing: isEditing, significantFigures: significantFigures)
                },
                set: { text = $0 })
        )
        .focused($isEditing)
    }
}

private struct MassPropertiesReadout: View {
    let part: PartRecord
    let significantFigures: Int

    private func formatted(_ value: Double) -> String {
        MaterialNumberFormat.string(value, significantFigures: significantFigures)
    }

    var body: some View {
        let result = Result { try part.massProperties }
        switch result {
        case .success(let properties?):
            LabeledContent("Volume (m³)", value: formatted(properties.volumeCubicMeters))
            LabeledContent("Mass (kg)", value: formatted(properties.massKilograms))
            let inertia = properties.inertiaTensorAboutCenterOfMassLocal
            LabeledContent("Ixx (kg·m²)", value: formatted(inertia.xxKgMetersSquared))
            LabeledContent("Iyy (kg·m²)", value: formatted(inertia.yyKgMetersSquared))
            LabeledContent("Izz (kg·m²)", value: formatted(inertia.zzKgMetersSquared))
            Text(
                "Uniform solid block. Inertia is about the local center of mass; cross terms are zero."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        case .success(nil):
            Text("Assign a material and apply to calculate mass and inertia.")
                .foregroundStyle(.secondary)
        case .failure(let error):
            Label(error.localizedDescription, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
        }
    }
}
