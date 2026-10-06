# mechkit — goals and working principles

mechkit supports machine design, robotics, and automation through design and
simulation. Real motor control is outside its scope.

## Goals

- Assemble machines and robots from parts and reusable mechanisms in a 3D workspace.
- Make mechanical connections and their resulting motion easy to explore.
- Simulate motion, forces, loads, and required torque.
- Keep the interface concise, simple, and clear.
- Build a native macOS application.

Keep this file focused on broad goals and working principles. Detailed features,
architecture, and implementation choices require agreement with the user.

## Working principles

- **First principles:** Reason from design goals, required behavior, and verified
  physical constraints. State assumptions.
- **Scope:** Complete only requested work. Do not add unrequested features,
  refactors, or fixes. Report unrelated issues separately.
- **Decisions:** Decide routine, reversible details within the approved step.
  Discuss major product, architecture, and physical-model choices with the user;
  give a recommendation and tradeoffs. Ask about missing details that materially
  affect the result; otherwise use the simplest reasonable interpretation.
- **Code:** Write the smallest correct, readable solution. Match nearby style.
  Add abstractions and dependencies only for concrete needs; explain new
  dependencies. Handle errors explicitly.
- **Tooling:** Prefer modern, supported macOS tooling and APIs. Backward
  compatibility is not a requirement unless explicitly requested.
- **Interface design:** Follow Apple's
  [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/),
  especially [Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos/),
  when designing and implementing the interface.
- **Physics:** Define units, coordinate frames, and sign conventions for geometry,
  motion, forces, and torque. Show units in names or types. Validate external
  inputs for ranges and non-finite values (NaN or infinity). Keep mechanical
  properties consistent across design and simulation.
- **Verification:** Run relevant existing checks before finishing each step.
  Report changes, checks, and uncertainties. Distinguish simulation from physical
  measurements and state simulation assumptions. Never invent commands or claim
  checks that were not run.

## Step-by-step approval

- Before editing files, propose numbered steps with each change and its check.
  Keep steps small and independently checkable. Separate multiple goals and
  confirm their order. Wait for approval before starting step 1.
- Complete one step per approval. List approval authorizes only step 1 unless
  the user explicitly approves more steps.
- Keep routine approval requests brief; do not repeat or cite this policy.
- When asked to break down a step, reply only with numbered substeps (3.1, 3.2),
  each with its change and check. Wait for approval before starting. Apply these
  rules at every substep level.
- Propose work outside the approved step separately and request approval.
- Finish and check the approved step. Report results, mark completed steps, and
  identify the next step. Then stop and wait for approval to continue.
