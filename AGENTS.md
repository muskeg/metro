# Metro agent workflow

These instructions apply only to this repository, to primary agents and subagents.

- At the start of every session or delegated task, read [MEMORY.md](./MEMORY.md).
  Read the linked source and documentation relevant to the task before editing;
  memory is a handoff, not a substitute for checking the current code.
- Before finishing, update MEMORY.md with the work performed, decisions and
  reasons, affected entry points, exact validation commands/results, and any
  remaining limitations or next steps. Record failures and unrun checks honestly.
  For a no-change session, add a short result only if it provides useful context.
- Keep the current-state sections accurate and the recent-work log concise.
  Replace superseded information rather than accumulating contradictory history.
  Link to README.md or DESIGN.md for detail. Do not record secrets, personal
  information, raw logs, or machine-specific session/attachment paths.
- Include this read/report requirement in every delegated task. Each subagent
  must return a memory-ready summary of its work, validation and open issues.
  Read-only or file-scoped subagents must not write outside their allowed scope.
- During parallel work, the coordinating agent is the sole MEMORY.md writer.
  Integrate every subagent's summary before the session ends, avoiding competing
  edits. A standalone write-enabled agent updates the file itself.
- Before finishing any task that changes shipped game code, the coordinating
  agent must produce fresh Windows and macOS release builds using the export
  commands in [MEMORY.md](./MEMORY.md). Game code means GDScript, scenes,
  shaders, `project.godot` and export presets. Do not rebuild for asset- or
  translation-only changes, documentation, MEMORY.md, agent instructions,
  export-excluded tests or probes, research, or answers. When builds are
  required, verify both exports, report any failure or platform-specific checks
  not run, and do not claim builds were refreshed unless both actually succeeded.
- In the final response, mention the memory update and any incomplete work.
  Do not claim tests passed, builds were refreshed, or memory was saved unless
  those actions actually completed.
