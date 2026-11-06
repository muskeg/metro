# Metro - repository memory

Last updated: 2026-11-06.

## Read first

This is the shared context handoff for Metro agents. Follow [AGENTS.md](./AGENTS.md)
at session start and completion. Check the source before relying on these notes.
Detailed controls and commands: [README.md](./README.md). Decisions and rationale:
[DESIGN.md](./DESIGN.md). Original requirements: [systemprompt.md](./systemprompt.md).

## Current product decisions

- Native Godot 4/GDScript relaxing transit builder, named **Metro**. No economy,
  failure pressure or demand simulation. Release targets: Windows x86_64 and
  universal macOS (Intel x86_64 + Apple Silicon arm64).
- English default; French can be selected live in Menu. Language is persisted
  through ConfigFile. Add all new UI messages to [ui.csv](./translations/ui.csv).
- Minimalist map: pure white at noon, a subtle blue night gradient and warm
  twilight, smoothly transitioning. No scenery or visible grid; the 48-pixel
  construction grid remains active.
  Earlier procedural-city iterations were deliberately removed, not unfinished.
- Elastic station-to-station drawing from one neutral + handle; no Draw/Move
  mode buttons. Center drag moves a station. Each free section has at most one
  bend using cardinal/45-degree segments, independent of pointer history.
  Drag directly or click to pin sections; releasing on empty space pins a section
  and continues by clicks. Tab or the source's two-arrow handle flips posture;
  Backspace undoes the last pinned section. Rail diamonds reshape bends or add
  a detour to a straight rail. Red previews identify invalid routes before commit.
- Connect the endpoints of a line with at least three stations to close a loop.
  Both directions run continuously around it; deleting a station or rail opens
  the loop into one continuous line without reconnecting removed rails.
- Station tool places stations on empty space or inserts them into rails.
  Insertion updates every shared line, including reversed station order.
- Deletion requires confirmation. Removing a station removes incident rails;
  lines split into selectable fragments, retaining settings and color. Do not
  automatically reconnect neighboring stations.
- Two actual running lanes, simultaneous directions, locomotive plus 1-6 wagons.
  Cars follow curves; safety includes the whole train.
- A line has a configurable maximum of 1-16 trains, default 4, counting both
  directions. Reducing it below current occupancy redispatches the network.
  Click a locomotive or wagon to follow it at 5x zoom; Escape, panning or
  redispatch ends the follow. Scroll adjusts the zoom while following.
- Lines are opaque color bands with darker running lanes, without rail glow.
  Lanes are at +/-8 pixels (16 apart); car width is 7. A tighter +/-7 attempt
  blocked shared curved routes and was rejected by simulation tests.
- Stations have a 10-pixel white interior and a 2-pixel border; no shadow or glow.
  Night slightly softens the fill and lightens the border.
- Compact main card (276 x 460 maximum), smaller settings popover and on-demand
  help. Per-line ColorPicker offers presets and no alpha. Recolor immediately
  updates rails, trains, tabs and preview without redispatching trains.
- Original gentle 48-second composed PCM music, separate music/train-effect
  volume, day/night lights and softly fading train headlights.
- Trains are top-down rectangular cars with short flexible gangways, windows
  and lamps; running gear is hidden, not represented by decorative wheels.
  They have no offset drop shadow.

## Architecture and invariants

- [main.gd](./scripts/main.gd): input, contextual gestures, UI, language/settings,
  graph-edit integration. Release over GUI cancels a gesture; Escape/right-click
  restores a movement's original station position and incident paths. Mouse input
  uses event coordinates transformed through the world canvas, not OS cursor reads.
  Drawing pins/history and rail-edit previews are separate from committed geometry.
- [transit_graph.gd](./scripts/sim/transit_graph.gd): stations/tracks and unordered
  station-pair lookup. IDs equal array indices. Deletions compact and remap all
  station/track references, route lists and lookup before rebuilding dispatch.
- [transit_line.gd](./scripts/sim/transit_line.gd): ordered station and track IDs.
  Physical tracks are shared; waypoint orientation is canonical track a-to-b.
  Lines extend only at endpoints. A loop repeats its first station at the end;
  it cannot be extended, but its tracks can be redrawn. Empty fragments remain reusable.
- Geometry edits validate all affected paths; invalid movement rolls back the
  full change. Moving a station reshapes its adjacent elbow from the gesture's
  original path, keeping distant bends fixed. Off-station crossings are rejected.
- [track_geometry.gd](./scripts/render/track_geometry.gd): canonical anchors,
  elastic_path (deterministic diagonal-first/straight-first sections),
  simplification, corner rounding, shared-corridor offsets and route circuits.
  Round the complete centerline BEFORE separating the two lanes. The former
  station joins between already-offset tracks pinched lanes and deadlocked trains.
- Circuit data includes `points` (closed simulation path), `centerline`,
  `running_paths` (two open visible lanes), `stops`, `outbound_end`, and `length`.
  A loop has closed visible lanes and a separate `reverse_route`; select the
  route by train direction for simulation, rendering and junction passages.
  Stops project onto segments, not only vertices: simplifying a collinear station
  vertex must not move its stop to another station.
- [dispatcher.gd](./scripts/dispatch/dispatcher.gd): 60 Hz substeps, braking,
  full-train following distance, geometric body collision checks and dispatch.
  Geometry/wagon edits reset the network safely, including reservations. The
  per-line maximum is also inherited by fragments and enforced during dispatch.
- Junctions use FIFO exclusive reservations before entry, held until the last
  wagon exits. Nearby zones merge when there is insufficient train clearance.
  All terminal turns also need protection, even on a single line. Parallel shared
  corridors have independent terminal reservations. Merge zones only when they
  share a participating line. Pause preserves reservations.
- [world_view.gd](./scripts/render/world_view.gd): draw rail bands from centerline
  and open running paths, not the closed simulation circuit. A rounded band cap
  finishes each open terminus behind its station; loops have no caps. Physical turnaround curves
  still exist in simulation; do not describe them as removed or teleport trains.
  Close-up train and rail outlines omit Godot's world-unit AA fringe at zoom
  1.5 or greater to avoid blurred contours. Headlights render before the cars.
- [urban_backdrop.gd](./scripts/render/urban_backdrop.gd) retains its historical
  filename/class but draws only the atmospheric day/night background.
- [ambient_audio.gd](./scripts/audio/ambient_audio.gd): cached composition and
  train effects. Avoid introducing audio shutdown leaks; headless playback is
  intentionally disabled.
- Native CSV import has escaped keys enabled for multiline help. Dynamic/nested
  errors must be translated before formatting, not only static control labels.
  New elastic help uses standard quoted multiline CSV cells for version portability.

## Validation and delivery

Every task requires fresh Windows and macOS release exports before completion,
as specified in [AGENTS.md](./AGENTS.md). Verify both and report any failure or
platform-specific checks that could not be run.

Godot version last used: 4.7.2, Compatibility renderer. `godot` below means an
available matching editor binary; it was not globally installed in the previous
environment. Temporary editor downloads were cleaned after validation.
Matching Windows and macOS templates were installed in the standard Godot user directory;
verify availability before the next build rather than assuming it.

```sh
godot --headless --editor --path . --quit
godot --headless --path . --script res://tests/simulation_smoke.gd
godot --headless --path . --script res://tests/loop_smoke.gd
godot --headless --path . --script res://tests/train_controls_smoke.gd
godot --headless --path . --script res://tests/intersection_smoke.gd
godot --headless --path . --script res://tests/editing_smoke.gd
godot --headless --path . --script res://tests/interface_smoke.gd
godot --headless --path . --script res://tests/localization_smoke.gd
godot --headless --path . --script res://tests/audio_smoke.gd
godot --headless --path . --script res://tests/urban_smoke.gd
godot --path . --script res://tests/urban_smoke.gd --audio-driver Dummy
godot --path . --script res://tests/interface_smoke.gd --audio-driver Dummy
godot --path . --script res://tests/visual_smoke.gd --audio-driver Dummy
godot --path . --script res://tests/train_visual_smoke.gd --audio-driver Dummy
godot --headless --path . --export-release "Windows Desktop" dist/Metro.exe
godot --headless --path . --export-release "macOS" dist/Metro-macOS.zip
```

- Inspect output for parser/script errors even when the editor exits zero.
- Intersection tests run six simulated minutes per scenario and can take several
  real minutes. A selector after `--` filters labels, for example `-- Screenshot`.
- Intersection checks cover full-wagon separation, both directions, continued
  arrivals in the second half, shared terminals, nearby junctions, three lines,
  busy single-line termini and a layout reproducing the reported screenshot.
- Native graphical tests need a display. They verify actual pixels: white noon
  and smooth night background, dark lanes, opaque colors, white station/border, no
  station shadow, rounded terminal band, recoloring and hover anchors. The visual test
  disables incidental mouse-hover state before measurements to avoid highlights
  corrupting sampled colors. Clean its named temporary screenshots afterward.
- llvmpipe's unsupported VSync warning occurred during successful graphical
  runs; distinguish it from script/test errors.
- [export_presets.cfg](./export_presets.cfg) embeds game data in
  `dist/Metro.exe` and packages `Metro.app` in `dist/Metro-macOS.zip`;
  tests and dist are excluded from both. macOS uses built-in ad-hoc signing,
  no notarization, bundle identifier `org.metro.game`. Keep project setting
  `textures/vram_compression/import_etc2_astc=true` for universal/arm64 exports.
  Mac launch and Gatekeeper behavior require a real Mac; Linux can only verify
  the archive structure. [`.gitignore`](./.gitignore)
  ignores dist and editor caches. WSL previously ran the Windows executable
  directly with `--headless --quit-after 10 --audio-driver Dummy`; use a valid
  Windows log-file path if specifying one.

## Recent work and verification record

### Metro cars and terminals (2026-11-06)

- Replaced capsule cars and decorative wheels with rectangular roof silhouettes,
  concealed running gear, and flexible gangways. Reduced shared car pitch from
  16 to 13 so simulation, collision spacing, following and rendering agree.
  Softened headlights; station circles no longer use world-space AA fringe.
  Open line bands end in rounded caps behind station rings; loop bands stay closed.
- Godot 4.7.2 editor import passed. Headless `train_controls_smoke.gd`,
  `simulation_smoke.gd`, `loop_smoke.gd`, `editing_smoke.gd`,
  `interface_smoke.gd`, `localization_smoke.gd`, and the six-scenario
  `intersection_smoke.gd` passed. Native `train_visual_smoke.gd`,
  `visual_smoke.gd`, `train_controls_smoke.gd` and `loop_smoke.gd` passed with
  `--audio-driver Dummy`; the driver reported its known VSync warning.
  Close-up screenshots and pixels checked the car silhouette, gangways, station
  ring, terminal cap, absence of decorative wheels, and headlight falloff.
- Commands: `godot --headless --editor --path . --quit`;
  `godot --headless --path . --script res://tests/train_controls_smoke.gd`
  (likewise other headless scripts above);
  `godot --path . --script res://tests/train_visual_smoke.gd --audio-driver Dummy`
  (likewise other native scripts above).
- Windows `godot --headless --path . --export-release "Windows Desktop"
  dist/Metro.exe` failed because the existing game was running and Windows
  locked the file. The same command with `dist/Metro-updated.exe` succeeded;
  `./dist/Metro-updated.exe --headless --quit-after 10 --audio-driver Dummy`
  passed. The original `dist/Metro.exe` remains the old build. macOS export
  `godot --headless --path . --export-release "macOS" dist/Metro-macOS.zip`
  and `unzip -t dist/Metro-macOS.zip` passed. The previously reported Mac
  launch failure remains unresolved and was not tested on a Mac.

### Train and atmosphere visuals (2026-11-06)

- Refined vector train bodies, round wheels and hubs, couplings, windows and
  lamps; removed train drop shadows. Headlights fade smoothly at night and the
  minimalist backdrop now has subtle twilight and night gradients. Close zoom
  avoids the Compatibility renderer's world-space anti-alias fringe.
- Godot 4.7.2 import passed. Headless `train_controls_smoke.gd`,
  `simulation_smoke.gd`, `loop_smoke.gd`, `editing_smoke.gd`,
  `interface_smoke.gd`, `localization_smoke.gd` passed. Native
  `train_visual_smoke.gd`, `visual_smoke.gd`, `urban_smoke.gd` and
  `interface_smoke.gd` passed with `--audio-driver Dummy`. The graphics driver
  emitted the known unsupported VSync warning.
- Commands: `godot --headless --editor --path . --quit`;
  `godot --headless --path . --script res://tests/train_controls_smoke.gd`
  (likewise other headless scripts above);
  `godot --path . --script res://tests/train_visual_smoke.gd --audio-driver Dummy`
  (likewise other graphical scripts above). Close-up graphical checks include
  round-wheel pixels, couplings, recoloring, absence of offset shadows, and
  daytime/nighttime headlight fade.
- A 2D MSAA experiment was rejected because Godot's Compatibility renderer
  reported it unsupported; the project setting was removed. Windows and macOS
  export commands in the validation section succeeded; Windows headless
  `./dist/Metro.exe --headless --quit-after 10 --audio-driver Dummy` and macOS
  `unzip -t dist/Metro-macOS.zip` passed. The previously reported Mac launch
  issue remains unresolved and actual Mac launch was not tested.

### Train limits, following, and Mac launch report (2026-11-06)

- Added per-line maximum train slider (1-16, default 4), redispatch when lowering
  below current occupancy, fragment inheritance, and click-to-follow locomotive
  or wagons. Escape/pan/redispatch stops following; scroll adjusts close-up zoom.
  Updated English/French UI text, README and DESIGN.
- User reported macOS build shows a bouncing Godot icon and never launches,
  without an error message. Cause is unconfirmed; user deferred diagnosis.
  Archive integrity, executable permissions and universal x86_64/arm64 were
  checked on Linux, but none proves Mac launch works. Terminal output, macOS
  version and architecture are needed to investigate on the affected Mac.
- Godot 4.7.2 import passed. Headless `train_controls_smoke.gd`,
  `simulation_smoke.gd`, `loop_smoke.gd`, `editing_smoke.gd`,
  `interface_smoke.gd`, `localization_smoke.gd` and all six scenarios of
  `intersection_smoke.gd` passed. Native `train_controls_smoke.gd`,
  `interface_smoke.gd` and `visual_smoke.gd` passed with `--audio-driver Dummy`;
  the driver emitted its known unsupported VSync warning.
- Commands: `godot --headless --editor --path . --quit`;
  `godot --headless --path . --script res://tests/train_controls_smoke.gd`
  (likewise the other headless scripts above);
  `godot --path . --script res://tests/train_controls_smoke.gd --audio-driver Dummy`
  (likewise the other native scripts above).
- Fresh exports succeeded using `godot --headless --path . --export-release
  "Windows Desktop" dist/Metro.exe` and the same command with `"macOS"
  dist/Metro-macOS.zip`. `./dist/Metro.exe --headless --quit-after 10
  --audio-driver Dummy` and `unzip -t dist/Metro-macOS.zip` passed. The Mac
  launch issue is not fixed or validated by the successful archive check.

### Release builds and workflow (2026-11-06)

- Added the per-task Windows and macOS export requirement to
  [AGENTS.md](./AGENTS.md).
- Godot 4.7.2: `godot --headless --editor --path . --quit`, followed by
  `godot --headless --path . --export-release "Windows Desktop" dist/Metro.exe`
  and `godot --headless --path . --export-release "macOS" dist/Metro-macOS.zip`,
  succeeded. These exports include the loop-line changes.
- `./dist/Metro.exe --headless --quit-after 10 --audio-driver Dummy` succeeded
  on Windows via WSL. `unzip -t dist/Metro-macOS.zip` passed; the bundled Mach-O
  contains x86_64 and arm64. Actual macOS launch and Gatekeeper checks remain
  unverified without a Mac; the build is ad-hoc signed and not notarized.

### Loop lines (2026-11-06)

- Added endpoint-to-endpoint closure in either drawing direction, cyclic geometry
  and independent clockwise/counterclockwise train routes. Closing-track insertion,
  redrawing, removal, shared-track offsets and junction reservations are supported.
- Godot 4.7.2: editor import, headless `loop_smoke.gd`, `simulation_smoke.gd`,
  `editing_smoke.gd`, `interface_smoke.gd`, `localization_smoke.gd` and the
  full six-scenario `intersection_smoke.gd` passed.
  Native `loop_smoke.gd` and `visual_smoke.gd` with `--audio-driver Dummy` passed;
  the graphics driver reported its known unsupported VSync warning.
- The new loop test checks both travel directions, ordered stops, actual closure
  pixels, whole-train collision safety and sustained service through a shared
  station and segment. Release binaries were subsequently rebuilt as above.
- Validation commands, using `godot` for the Godot 4.7.2 editor binary:
  `godot --headless --editor --path . --quit`;
  `godot --headless --path . --script res://tests/loop_smoke.gd` (likewise
  `simulation_smoke.gd`, `editing_smoke.gd`, `interface_smoke.gd`,
  `localization_smoke.gd`, and `intersection_smoke.gd`);
  `godot --path . --script res://tests/loop_smoke.gd --audio-driver Dummy`
  (likewise `visual_smoke.gd`).

### Gameplay and visual iterations (completed before this memory file)

- Added continuous drawing, physical two-way circulation, wagon controls,
  bilingual UI, audio composition and Windows export.
- Added hover gizmos, rail/station deletion, route-fragment preservation,
  shared-track station insertion and non-distorting movement/cancellation.
- Replaced the experimental city with the requested solid minimalist background.
- Added sticky drawing, thinner solid rails, darker running lanes, compact
  controls, live per-line color picker and simpler day/night station dots.
- Earlier individual validations passed for audio, background uniformity,
  localization, editing, picker interactions and rendered day/night behavior.
  These are historical results, not a claim that every suite ran on every edit.

### Latest simulation and terminal fix (completed before this memory file)

- Reproduced the reported screenshot layout: previous lane joins caused
  nose-to-nose blocking; terminal queues could also obstruct a returning train.
- Rounded the whole centerline before lane separation, projected stops onto
  path segments, protected terminal turns and kept parallel shared corridors
  independently reserved. Visible rail paths now stop at stations without caps.
- Last final checks passed: editor import, `simulation_smoke.gd`,
  `intersection_smoke.gd`, native `visual_smoke.gd`, `editing_smoke.gd` and
  `interface_smoke.gd`, using the commands above.
- Screenshot-layout arrivals progressed from [56, 114] at three minutes to
  [114, 217] at six minutes, with full-body collision checks passing.
- Windows export and actual Windows headless startup passed after those changes.
  The executable remains in `dist/Metro.exe`. No commits have been created by
  these sessions; the project was still untracked at this handoff. Preserve it.

### 2026-11-06 - shared agent memory workflow

- Created this handoff and root AGENTS.md, scoped to Metro as explicitly chosen.
  All sessions must read memory; write-enabled sessions update it before ending.
  Delegated agents report memory-ready summaries; a coordinator merges parallel
  reports as the single writer, respecting read-only and file ownership limits.
- Linked memory from README. Documentation-only change: checked source/docs for
  consistency and relative-link targets; no game tests or export rerun for this
  documentation task.

### 2026-11-06 - diagonal drawing design research

- User requested research and alternatives before choosing; no gameplay, tests,
  or exports changed. Await selection before implementing a drawing redesign.
- Inspected main.gd `_begin_world_interaction`, `_extend_stroke`,
  `_extend_stroke_to`, editing smoke coverage, README and DESIGN. Initial
  snapping explicitly favors cardinal directions, then retains the last segment
  within 38.4 world pixels. Four cardinal start handles also make diagonal intent
  less obvious. This is a source-based diagnosis, not a graphical reproduction.
- Existing diagonal test jumps directly to (96, 96); it does not cover gradual,
  slightly off-angle diagonal starts or pointer-event sampling sensitivity.
- Reviewed official Inkscape advanced tutorial (click-placed nodes, angular
  constraints, editable paths) and Blender axis-locking manual (direction
  selection and visible lock feedback). Attempted draw.io reference URLs returned
  HTTP 404 and are not supporting evidence.
- Alternatives presented: equal eight-direction gesture snapping; click-placed
  bend points; elastic station-to-station routing with optional pinned bends
  (recommended); free-angle/Bezier drawing (larger geometry/simulation risk).
  These are proposals, not accepted product decisions. Preserve invisible grid,
  rounded corners and existing topology validation unless explicitly changed.
- Validation: `git diff --check -- MEMORY.md` initially failed because the shell
  was outside the repository; `git -C /mnt/c/raph/dev/metro diff --check -- MEMORY.md`
  passed. No Godot tests or graphical checks required or run for this research.

### 2026-11-06 - elastic drawing and unified gizmos implemented

- User selected option 3 and authorized unified gizmo changes. Replaced sampled
  sticky strokes with deterministic elastic sections in TrackGeometry.elastic_path
  and main.gd `_extend_stroke`. One station + starts a drag or click workflow.
  Empty-space release/click pins the current section; Tab/two-arrow source control
  flips posture; Backspace restores the previous pinned section snapshot.
- WorldView uses matching day/night disc handles, green connect/insert, red delete,
  neutral reshape diamonds and action tooltips. Local guides, target ring and red
  invalid previews are temporary. Long error tooltips stay within the viewport.
- Added nonmutating open-end validation to TransitGraph.path_error. New and
  reshaped rails validate before commit, including shared-line train lengths.
  Invalid destination attempts stay correctable; invalid reshapes preserve the
  original rail. Escape/right-click and GUI release discard previews.
- Existing bends are draggable; straight rails expose a lower reshape handle.
  Only adjacent sections change, keeping station endpoints and distant bends fixed.
  `_event_world_position` uses the event's coordinates through the canvas transform.
- Updated README, DESIGN, English/French help, and existing editing, simulation,
  interface, localization and visual suites. Reimported translation resources.
- Intermediate failures: preview simplification removed collinear explicit pins
  (fixed by retaining preview pins); new help lookup failed under a temporary 4.5.1
  import (fixed with standard multiline CSV and restoring unescape_keys=true under
  4.7.2). Three native synthetic-pointer attempts failed; user approved continued
  debugging. Fixed event-coordinate handling and framed test controls outside GUI.
  All affected focused checks subsequently passed; temporary downloads/screenshots
  were removed. Final validation/export used Godot 4.7.2, not the temporary 4.5.1.
- Exact successful final commands (run from project root, `godot` = Godot 4.7.2):

  ```sh
  godot --headless --editor --path . --quit
  godot --headless --path . --script res://tests/editing_smoke.gd
  godot --headless --path . --script res://tests/simulation_smoke.gd
  godot --headless --path . --script res://tests/localization_smoke.gd
  godot --path . --script res://tests/interface_smoke.gd --audio-driver Dummy
  godot --path . --script res://tests/visual_smoke.gd --audio-driver Dummy
  godot --headless --path . --script res://tests/intersection_smoke.gd -- Screenshot
  godot --headless --path . --export-release "Windows Desktop" dist/Metro.exe
  ./dist/Metro.exe --headless --quit-after 10 --audio-driver Dummy
  ```

- Native visual checks cover 900x600 and 1440x900 day/night diagonal previews,
  target rendering, gizmos and invalid-route feedback; screenshots inspected.
  Native input checks cover real viewport press/release, mouse-only posture flip,
  one pin per click, completion/redraw and release-over-GUI cancellation.
- Screenshot-layout traffic remained [56, 114] arrivals at half-time and [114, 217]
  finally, with full-body safety passing. Expected llvmpipe VSync warning only.
  Windows executable rebuilt and actual Windows headless startup passed via WSL.
- Not rerun: full unfiltered intersection suite, audio and urban suites; no audio,
  backdrop or dispatch code changed. User feel-testing remains useful, especially
  routing in dense maps. No commits created; worktree remains untracked as before.

### 2026-11-06 - Windows and universal macOS release builds

- User requested both platform builds. Added macOS preset to export_presets.cfg:
  universal architecture, ZIP distribution, built-in ad-hoc signing, no Apple
  notarization, identifier `org.metro.game`. Updated README export instructions.
- Installed official Godot 4.7.2 macOS template alongside existing Windows ones.
  Used a temporary matching native editor; removed it and downloaded archives
  after verification, preserving installed templates and release artifacts.
- Initial template-asset lookup could not use jq (not installed); downloaded
  the official known template archive directly instead. First macOS export
  failed because ETC2/ASTC import was disabled; enabled the required project
  setting and reran both exports successfully. No gameplay source changed.
- Successful commands, from project root with Godot 4.7.2:

  ```sh
  godot --headless --path . --export-release macOS dist/Metro-macOS.zip
  godot --headless --path . --export-release "Windows Desktop" dist/Metro.exe
  ./dist/Metro.exe --headless --quit-after 10 --audio-driver Dummy
  ```

- Windows actual headless startup passed via WSL. Python stdlib zipfile,
  plistlib, stat and struct assertions passed for macOS ZIP integrity, valid
  bundle metadata, universal Mach-O CPU types (x86_64 + arm64), executable
  permissions, signing resources and Godot game-pack header. Artifact sizes:
  Windows 104.2 MiB; macOS ZIP 57.7 MiB.
- macOS runtime testing and Apple notarization remain unperformed: no Mac host
  or Apple Developer credentials available. Gatekeeper may require explicit
  approval. Gameplay suites not rerun for this build/configuration-only task.

## Open limits and next-session cautions

- Off-station independent rail crossings remain unsupported.
- Hidden simulation turnarounds still carry trains continuously; visible rails
  do not draw these loops. If train motion itself still looks like spinning,
  inspect a new reproduction rather than assuming cap removal changed motion.
- Latest automated scenarios passed, but no subsequent user confirmation of the
  final terminal fix has been received.
- Elastic drawing is implemented and exported; the earlier research alternatives
  are historical, not pending. Await user feedback on the interaction feel.
  Keep this file current instead of relying on prior chats or private session files.
