# Machine builder — project guidance

This is an early project draft. Update it incrementally as the user makes
decisions. Proposed features and architecture are not requirements until agreed.

## Confirmed concept

- Build a tool for assembling machines from discrete mechanical parts or mechanisms.
- Start with an empty workspace on a grid.
- Provide a selection of mechanisms, including rack and pinion, friction drives,
  belt drives, and chain drives.
- Let users combine and connect the selected components.
- The primary goal is an animated mechanism: users assemble components and see
  how their connections produce motion.
- Use a full 3D workspace for placing components and viewing the assembled mechanism.
- Offer both individual parts and ready-made mechanisms in the component library.
- Ready-made mechanisms are assemblies of individual parts, using the same parts
  available for building mechanisms from scratch.
- Users can modify the individual parts and connections within a ready-made mechanism.
- Support both explicit connections and assisted snapping in 3D.
- For explicit connections, users select connection points on two parts and choose
  the relationship, such as a fixed attachment, rotating joint, or gear mesh.
- For assisted snapping, dragging parts near compatible connection points previews
  a connection that users can accept or change.
- When users define a connection, automatically align the parts to satisfy it.
  Let users adjust placement where the connection permits it, such as a gear's
  position along a shaft.
- Physical supports are optional. Users can define a fixed rotation axis or sliding
  path directly in the workspace and add bearings, rails, or a frame if desired.
- The first version uses ideal motion: prescribed inputs drive connected components
  according to their motion relationships, ratios, and travel limits.
- Physical dynamics, including motion determined by torque, mass, friction, gravity,
  and loads, are outside the first version's scope.
- The first complete mechanism to build and animate is a simple belt drive with
  a timing belt and toothed pulleys, assuming no slip for ideal motion.
- Pulley tooth counts determine the drive's speed ratio. The belt and pulley teeth
  engage visually during animation.
- The first milestone supports a closed timing-belt loop around two pulleys:
  one driving pulley and one driven pulley.
- Generate the belt from the layout: users place and select two pulleys, then the
  app determines a suitable belt tooth count and generates the connecting belt.
- The app may adjust pulley spacing to fit a whole number of belt teeth.
- Drive motion through direct manipulation: users drag a pulley to turn it, and
  the belt and connected pulley follow according to the ideal motion relationship.
- Offer preset pulley sizes and allow users to edit pulley tooth counts.
- The first version's part library includes pulleys, belts, shafts, and bearings.
  Shafts and bearings can be included in assemblies but are not required to animate
  a belt drive.
- Routing around additional driven pulleys or idlers is outside the first milestone.
- Chain drives remain part of the broader concept and are outside the first milestone.

## Long-term direction

- Grow the tool to support robotics, machine design, and automation work.
- The first target machine beyond the initial belt-drive milestone is an X-Y
  gantry. Its task, mechanical arrangement, and drive types are still open.
- Support designing and simulating machines; real motor control is outside scope.
- Eventually include simulation of forces and loads and calculation of required
  torque. These capabilities are outside the first version's ideal-motion scope.
- Specific design workflows, physical models, and simulation fidelity are still open.

## Current preferences

- Build the first application for macOS.
- Plan a Qt port after the macOS version.
- The initial macOS application framework and the approach to sharing code with
  the later Qt port are still open.

## UI requirements

- Keep the UI concise, simple, and clear, with minimal text.
- Use short labels and show explanations only when needed.
- Apply these requirements to controls, component selection, connection workflows,
  and messages shown inside the application.

## Decisions still open

- Intended users and the X-Y gantry's task, mechanical arrangement, and drive types.
- Long-term robotics, machine-design, and automation workflows, and the physical
  models and fidelity for future force, torque, and load calculations.
- How the grid relates to mechanical placement in the 3D workspace.
- Available connection types, compatibility checks, and how supports attach to
  the stationary base or frame.
- Remaining first-version scope and interaction details.
- Implementation language, UI framework, persistence, and export formats.

## Working process

- Keep discussion at a broad level for now. Pause detailed design questions until
  the user wants to resume them.
- When interviewing resumes, focus on one topic at a time.
- Record agreed decisions here after each answer and revise superseded decisions.
- Keep unresolved questions distinct from requirements.
- Explain mechanical and software tradeoffs in plain language.
- Do not select a stack or begin application implementation solely from a proposal
  in the discussion. Wait for the user to request implementation.
