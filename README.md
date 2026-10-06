# mechkit

A macOS application for assembling mechanical parts in a 3D workspace and
simulating how their connections produce motion.

The project is in early planning. Application implementation has not started;
the language and initial macOS framework are still open. A Qt port is planned
after the macOS version.

## First milestone

Build and animate a timing-belt drive with two toothed pulleys. Users place the
pulleys, generate a closed belt that fits the layout, and drag a pulley to turn
the connected mechanism. Tooth counts determine the motion ratio, assuming no
slip and ideal motion.

## Direction

Grow toward designing and simulating machines for robotics and automation. An
X-Y gantry is the first target machine after the belt-drive milestone. Future
simulation should include forces, loads, and required torque. Real motor control
is outside scope.

The interface should stay concise, simple, and clear. Detailed design decisions
are paused for now.

See [AGENTS.md](AGENTS.md) for agreed decisions, open questions, and project
guidance.
