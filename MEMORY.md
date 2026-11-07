# Metro - repository memory

Last updated: 2026-11-07.

## Read first

This is the shared context handoff for Metro agents. Follow [AGENTS.md](./AGENTS.md)
at session start and completion. Check the source before relying on these notes.
Detailed controls and commands: [README.md](./README.md). Decisions and rationale:
[DESIGN.md](./DESIGN.md). Original requirements: [systemprompt.md](./systemprompt.md).

## Current product decisions

- Native Godot 4/GDScript relaxing transit builder, named **Metro**. No economy,
  failure pressure or demand simulation. Release targets: Windows x86_64 and
  universal macOS (Intel x86_64 + Apple Silicon arm64), plus single-thread Web
  hosted on GitHub Pages.
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
- No Station tool/mode: clicking empty space places a station; clicking rails
  or their + inserts one. A translucent ghost previews the exact grid-snapped
  empty-space position, hidden over existing objects/UI or during gestures.
  Insertion updates every shared line, including reversed station order.
- Deletion requires confirmation. Removing a station removes incident rails;
  lines split into selectable fragments, retaining settings and color. Do not
  automatically reconnect neighboring stations.
- Two running lanes, simultaneous independent directions, locomotive plus
  1-6 wagons. Cars follow curves. Moving authority preserves full-train gaps on
  each independent circuit; multiple trains can share an interstation section.
  No station-slot locks, geometric cross-line collisions or junction FIFO.
  User explicitly accepted visual overlap where station paths converge.
- A line has a manual desired maximum (default 4), capped by conservative route
  geometry/service capacity, not station count. Recommended fleet uses cycle
  time and requested interval. Actual service respects both recommendation and
  manual ceiling; loop fleets split between directions. Empty/single-station
  lines cannot dispatch. Fragments inherit preferences and motion/recovery
  settings but obey their own capacity. Tooltips show target interval and
  recommended/capacity counts. Speed, dwell, interval and manual fleet changes
  apply without redispatch: surplus withdraws at termini/loop origin after dwell.
  Independent acceleration/braking, four-second terminal recovery, bounded
  station holds and modest run-speed correction reduce bunching.
  Click a locomotive or wagon to follow it at 5x zoom; Escape, panning or
  redispatch ends the follow. Scroll adjusts the zoom while following.
  Following suppresses all map editing overlays and map/Delete edits, not HUD
  or camera controls. Clicking another train switches following. Shared
  `_update_interaction_overlays` gates visibility on both watch and follow;
  restoring HUD during follow must not re-enable overlays.
- Mouse-wheel zoom and middle/Space-drag pan are supported, as are native
  trackpad two-finger pan and pinch zoom gestures.
- Watch mode: H or Menu > Hide interface hides HUD and editing overlays;
  a faint bottom-center grip (36 x 3px) with a 96 x 44px touch target restores
  them, alongside H/Escape. No text or filled button; grip contrast adapts to
  day/night. It preserves pause and running trains/audio.
  Camera pan/zoom and train following work; placement/move/delete are disabled.
  Entering cancels in-progress edits safely. No setting is persisted.
- Lines are opaque color bands with darker running lanes, without rail glow.
  Lanes are at +/-8 pixels (16 apart); car width is 7. A tighter +/-7 attempt
  blocked shared curved routes and was rejected by simulation tests.
- Stations retain a 10-pixel white center. Each serving line contributes one
  2-pixel ring in its color darkened by 30%, matching running lanes. Older lines
  (array order) sit outside newer lines; repeated loop endpoints count once.
  Interchanges grow to radius 10 + 2 x line count (minimum 12), preserving center
  and ring widths. No shadow/glow. Unconnected/ghost stations keep neutral
  borders; night softens fills and lightens only neutral borders.
  Radius-aware picking, handles, selection/hover and route-target rings keep
  interaction geometry outside the marker. Membership/recolor updates are live.
- Map-first HUD: paper/ink toolbar and a flat, full-width 60px bottom rail,
  no floating capsule/shadow. Numbered line tabs use colored underlines, neutral
  selected backgrounds and readable text independent of the route color.
  Both + and collapse actions use shrink flags, never expand flags; otherwise
  they steal tab width and cause false overflow. Tabs scroll only as needed.
  Line controls expand inside the same rail above the tabs, height based on
  content (max 300px), with 1/2/3/5 columns at <620/620/760/1366px. Same-tab
  click folds controls; switching lines keeps them open. Redundant Line settings
  button removed. Menu/help remain separate, mutually exclusive sheets.
  Collapsing the rail leaves the same faint grip used for watch restoration.
  Controls fade to 28% opacity over 0.6s after eight idle seconds; movement,
  touch, keys and action feedback immediately wake them without consuming input.
  Sheets, dialogs, picker and active gestures prevent fading. The independent
  watch restore grip never fades. Collapse/watch are not persisted.
  Body text is at least 16 logical pixels; buttons are at least 44 pixels tall.
  Phone details scroll vertically, leaving tabs accessible. Line overflow
  scrolls to the selection. See [DESIGN.md](./DESIGN.md) for rationale.
- macOS/Web display density drives canvas-items scaling, not reduced font sizes.
  Native startup is 1180 x 740 logical pixels, constrained to usable screen;
  minimum is 760 x 520 logical pixels. The old 1x rendering on a 2x Retina
  screen made text half its intended apparent size.
- Per-line ColorPicker keeps free hue selection, hex input and presets, with
  RGB/mode/sampler controls hidden to fit small screens. No alpha. Recolor
  updates rails, trains, tabs and preview without redispatching trains.
- Original 48-second PCM music uses a consonant repeating eight-bar progression,
  a swung 80 BPM kick/snare groove, sparse melody and muted hats. Music starts
  at 0.4 volume; train effects have a separate volume.
- Trains are top-down rectangular cars with short flexible gangways, windows
  and lamps; running gear is hidden, not represented by decorative wheels.
  They have no offset drop shadow.

## Architecture and invariants

- [main.gd](./scripts/main.gd): input, contextual gestures, UI, language/settings,
  graph-edit integration. Release over GUI cancels a gesture; Escape/right-click
  restores a movement's original station position and incident paths. Mouse input
  uses event coordinates transformed through the world canvas, not OS cursor reads.
  Drawing pins/history and rail-edit previews are separate from committed geometry.
  `_configure_display` / `_update_display_density` handle logical display units;
  `_resize_interface` lays out the HUD. Sheets never pause simulation.
  Visible successes are silent: no placement/save/move/insert/delete/color/line
  selection/follow confirmations or startup toast. Errors/warnings retain eight
  seconds. Reducing the train ceiling no longer redispatches or shows a warning.
  Before the first connection in a session, a static local + appears on the
  first station; it retires permanently for the session after any track exists.
  While drawing, valid destination rings use the current pinned path/posture
  and `_connection_error`, including geometry and train-length checks. Cancel
  clears rings; sheets/watch/active pan suppress first-step guidance.
  Feedback appears only in the visible sheet or over the
  map. Never populate/show feedback in closed sheets: zero-width wrapped labels
  can inflate hidden layouts and displace content when they open.
  Help is a concise gesture reference, fitting without scrolling on laptops.
  Notifications use a plain Panel with manually sized RichTextLabel (no
  fit_content); `_resize_notification` measures current font/text/wrapping,
  max width 520px plus viewport constraint. Never use Label/PanelContainer
  cached autowrap minimum heights for toast sizing.
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
  Round the complete centerline BEFORE separating the two lanes. Use a tighter
  12-pixel smooth corner at stations to center the rail marker without hard
  elbows; the latter deadlocked shared junctions.
- Circuit data includes `points` (closed simulation path), `centerline`,
  `running_paths` (two open visible lanes), `stops`, `outbound_end`, and `length`.
  A loop has closed visible lanes and a separate `reverse_route`; select the
  route by train direction for simulation and rendering.
  Stops project onto segments, not only vertices: simplifying a collinear station
  vertex must not move its stop to another station.
- [dispatcher.gd](./scripts/dispatch/dispatcher.gd): 60 Hz substeps; moving
  authority uses forward circuit distance minus leader length and safety gap.
  Braking envelope includes 0.25s reaction against a conservatively stationary
  obstacle; separate acceleration/braking defaults are 80/100 units/s squared.
  Known station stops instead use a single-substep braking margin to avoid a
  creeping approach tail. Arrival snap requires pre-step speed within one
  braking step; subpixel displacement does not reset speed.
  Open lines share a continuous outbound/turn/inbound circuit; loop directions
  have separate circuits. Independent lines never constrain each other.
  Safety can brake mid-section; regulation normally holds at stations, at most
  three extra seconds. `_last_departures` stores timing, not occupancy.
  Nominal running speed is 90% of the chosen ceiling; departure-gap feedback
  permits 10% slower running or recovery up to that ceiling. Live speed
  reductions brake smoothly rather than snapping speed instantaneously.
  `cycle_time`, `minimum_headway`, `route_capacity`, `recommended_fleet` and
  `service_fleet` separate running estimates, conservative capacity and service.
  `departure_headway` is max(requested interval, cycle/fleet, minimum headway).
  `_retire_surplus` withdraws stopped trains at termini/loop origin, never moving
  trains. Dispatch starts both ends, retries blocked origins and alternates.
  Geometry/wagon edits clear trains/routes/timetables; pause freezes simulation.
  See [DESIGN.md](./DESIGN.md) for formulas and intentional game simplifications.
- [world_view.gd](./scripts/render/world_view.gd): draw rail bands from centerline
  and open running paths, not the closed simulation circuit. A rounded band cap
  finishes each open terminus behind its station; loops have no caps. Physical turnaround curves
  still exist in simulation; do not describe them as removed or teleport trains.
  Close-up train and rail outlines omit Godot's world-unit AA fringe at zoom
  1.5 or greater to avoid blurred contours. Headlights render before the cars;
  station markers render above passing trains.
  `station_line_colors` derives membership once per line, in array order;
  `station_radius` is shared with input picking. `_draw_network_station` is
  also used for route source/target repaint, preserving committed line rings.
- [urban_backdrop.gd](./scripts/render/urban_backdrop.gd) retains its historical
  filename/class but draws only the atmospheric day/night background.
- [ambient_audio.gd](./scripts/audio/ambient_audio.gd): cached composition and
  train effects. Avoid introducing audio shutdown leaks; headless playback is
  intentionally disabled. Web overrides `audio/general/default_playback_type`
  to Stream (`0` in ProjectSettings, NOT AudioServer's enum value `1`).
  Sample playback threw browser AudioBuffer duplication errors on the generated
  48-second WAV's pause/unpause and loop restart.
- [pages.yml](./.github/workflows/pages.yml): imports, tests simulation/audio/UI/localization,
  exports Web and uploads the Pages artifact on main pushes/PRs; only main
  pushes/manual runs deploy. Single-thread Web needs no COOP/COEP headers.
  [docs/](./docs/) contains README screenshots, ignored by Godot and excluded
  from every export preset.
- Native CSV import has escaped keys enabled for multiline help. Dynamic/nested
  errors must be translated before formatting, not only static control labels.
  New elastic help uses standard quoted multiline CSV cells for version portability.

## Validation and delivery

Every task requires fresh Windows and macOS release exports before completion,
as specified in [AGENTS.md](./AGENTS.md). Verify both and report any failure or
platform-specific checks that could not be run.

Godot version last verified: 4.7.2, Compatibility renderer. On macOS, the editor
is installed at `/Applications/Godot.app/Contents/MacOS/Godot`; invoke that
binary unless a `godot` command is configured. The standard export-templates
directory may not exist on a fresh setup; verify matching templates before
building.

```sh
godot --headless --editor --path . --quit
godot --headless --path . --script res://tests/simulation_smoke.gd
godot --headless --path . --script res://tests/loop_smoke.gd
godot --headless --path . --script res://tests/train_controls_smoke.gd
godot --headless --path . --script res://tests/schedule_smoke.gd
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
godot --headless --path . --export-release "Web" dist/web/index.html
```

- Inspect output for parser/script errors even when the editor exits zero.
- Intersection tests run six simulated minutes per scenario and can take several
  real minutes. A selector after `--` filters labels, for example `-- Screenshot`.
- Intersection checks cover full-train moving gaps, both directions, continued
  arrivals in the second half, shared terminals, nearby junctions, three lines,
  busy single-line termini and a layout reproducing the reported screenshot.
- Schedule tests compare a shared-station line against running alone, verify
  multi-train sections, route capacity/recommendations, independent motion rates,
  terminal recovery, stopped-leader braking and live timing/fleet changes.
  Seeded irregular loop departures compare regulated/unregulated headway
  standard deviation, requiring at least 25% improvement. Geometric collision
  assertions between different lines/directions intentionally no longer apply.
- Native graphical tests need a display. They verify actual pixels: white noon
  and smooth night background, dark lanes, opaque colors, white station centers,
  darkened concentric line rings, no
  station shadow, rounded terminal band, recoloring and hover anchors. The visual test
  disables incidental mouse-hover state before measurements to avoid highlights
  corrupting sampled colors. Clean its named temporary screenshots afterward.
- llvmpipe's unsupported VSync warning occurred during successful graphical
  runs; distinguish it from script/test errors.
- [export_presets.cfg](./export_presets.cfg) embeds game data in
  `dist/Metro.exe` and packages `Metro.app` in `dist/Metro-macOS.zip`;
  tests, dist and docs are excluded from all presets. macOS uses built-in ad-hoc signing,
  no notarization, bundle identifier `org.metro.game`. Keep project setting
  `textures/vram_compression/import_etc2_astc=true` for universal/arm64 exports.
  Mac launch and Gatekeeper behavior require a real Mac; archive validation
  alone does not verify Gatekeeper. [`.gitignore`](./.gitignore)
  ignores dist and editor caches. WSL previously ran the Windows executable
  directly with `--headless --quit-after 10 --audio-driver Dummy`; use a valid
  Windows log-file path if specifying one.

## Recent work and verification record

### Consolidating pending changes (2026-11-07)

- User requested one commit of all pending changes and will push themselves.
  Includes map-first HUD/watch/guidance, concentric station rings, natural
  moving-block circulation and fleet controls, approach smoothing, reachable
  rail gizmos, localized UI, regression tests/CI, screenshots and documentation.
- Fresh native exports passed:
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "Windows Desktop" dist/Metro.exe`
  and `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "macOS" dist/Metro-macOS.zip`.
  `unzip -t dist/Metro-macOS.zip`, `file dist/Metro.exe` and
  `git diff --check` passed; no export log errors/warnings.
  No runtime/test suites rerun for the commit-only task; preceding entries
  record their validation. Release outputs remain ignored. No push/deploy.

### Reachable rail reshape popup (2026-11-07)

- Fixed disappearing/chasing rail gizmos reported on vertical rails.
  `_update_hover` in [main.gd](./scripts/main.gd) previously retained each
  individual handle only within 11 screen pixels; the gaps between 32px-spaced
  handles reacquired the rail and changed its snapped anchor. It now retains
  the existing popup in an 11px-wide-radius capsule around the connecting
  spine. Station/bend priority and actual action hit areas remain unchanged;
  leaving the capsule permits normal reacquisition/clearing.
- Added continuous pointer-path tests in
  [editing_smoke.gd](./tests/editing_smoke.gd): vertical, horizontal and diagonal
  rails at zoom 0.5/1/2/5, both reshape/delete paths, stable anchor throughout,
  correct edit/confirmation action, no accidental insertion and hover clearing.
  Regression failed before the fix and passed afterward.
  Updated [DESIGN.md](./DESIGN.md).
- Passed:
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/editing_smoke.gd`
  and `/Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tests/interface_smoke.gd --audio-driver Dummy`.
- Fresh exports passed with the same Godot binary:
  `--headless --path . --export-release "Windows Desktop" dist/Metro.exe`,
  `--headless --path . --export-release "macOS" dist/Metro-macOS.zip`,
  `--headless --path . --export-release "Web" dist/web/index.html`.
  Verified archive via `unzip -t dist/Metro-macOS.zip`, Windows x86_64 PE,
  macOS x86_64/arm64 binary, `codesign --verify --deep --strict`, exported Mac
  startup `--headless --quit-after 10 --audio-driver Dummy`, nonempty Web
  HTML/JS/WASM/PCK and `git diff --check`; no export errors/warnings.
  Windows/Intel execution and browser runtime not rerun. Simulation untouched;
  simulation suites not rerun. Verification files cleaned; no commit/deploy.

### Smoother final station approaches (2026-11-07)

- User requested slightly smoother movement after the hesitation investigation.
  [dispatcher.gd](./scripts/dispatch/dispatcher.gd) now computes separate braking
  envelopes: the fixed platform uses a substep margin, while moving authority
  retains the conservative stationary-leader 0.25s reaction buffer and full
  train length plus 14px safety gap. This removes the slow station approach
  tail without weakening leader protection or changing regulation holds.
- Removed the 0.001-displacement speed reset: arbitrarily small positive moves
  retain acceleration. Station snap uses pre-step speed <= braking * delta,
  preserving deceleration bounds when arriving. No new settings or caching.
  Updated [README.md](./README.md) and [DESIGN.md](./DESIGN.md).
- Added [schedule_smoke.gd](./tests/schedule_smoke.gd) regressions requiring
  the last 10px from 40px/s to reach a platform in under 1s and uninterrupted
  acceleration at 1ms steps. First regression failed before the fix; initial
  smoothing exposed an arrival speed snap violating existing deceleration
  assertions, fixed by checking pre-step speed rather than post-step speed.
- Passed using `/Applications/Godot.app/Contents/MacOS/Godot`:
  `--headless --path . --script res://tests/schedule_smoke.gd`,
  `--headless --path . --script res://tests/intersection_smoke.gd`,
  `--headless --path . --script res://tests/loop_smoke.gd`,
  `--headless --path . --script res://tests/simulation_smoke.gd`,
  `--headless --path . --script res://tests/train_controls_smoke.gd`,
  `--path . --script res://tests/interface_smoke.gd --audio-driver Dummy`.
  Full six-minute intersection suite retained safe gaps and sustained arrivals;
  stopped-leader and independent acceleration/braking tests passed.
  Regulated headway deviation now 0.006s vs 4.991s unregulated in seeded test.
- Fresh Windows/macOS/Web exports passed using the same binary with
  `--headless --path . --export-release "Windows Desktop" dist/Metro.exe`,
  `--headless --path . --export-release "macOS" dist/Metro-macOS.zip`, and
  `--headless --path . --export-release "Web" dist/web/index.html`.
  Verified `unzip -t dist/Metro-macOS.zip`, Windows x86_64 PE, macOS
  x86_64/arm64 architectures, `codesign --verify --deep --strict`, exported
  Mac startup `--headless --quit-after 10 --audio-driver Dummy`, nonempty Web
  HTML/JS/WASM/PCK and `git diff --check`. No export log errors/warnings.
  Windows/Intel execution, browser runtime and subjective crowded-station
  observation not rerun; deliberate braking/holds still occur. No performance
  optimization or benchmark rerun. Verification files cleaned, no commit/deploy.

### Station-approach hesitation investigation (2026-11-07)

- User clarified that individual trains hesitate during simultaneous station
  arrivals in the native macOS app, without following a train; not whole-view
  stuttering. No gameplay code changed. Reviewed dispatcher tick, braking,
  station-release and rendering entry points.
- Temporary headless 4-station-loop probe on Apple M2, Godot 4.7.2: warm up 240
  simulated seconds, measure 3600 individual `process(1.0 / 60.0, false)` calls.
  Mean/p99 tick cost: 1 line/4 trains 0.207/0.286ms; 4 lines/32 trains
  1.245/1.590ms; 10 lines/200 trains 15.026/16.265ms. Excludes rendering,
  main UI, audio and actual display frame pacing; not a regression comparison.
  Fleet/headway estimates are recomputed repeatedly; moving-authority scans
  all trains per train, so large fleets can exhaust a 16.67ms frame budget.
- Individual hesitation at crowded approaches is consistent with conservative
  stationary-leader braking, bounded holds and very-small-movement speed reset
  in `_advance_metro`; exact reported event not reproduced or profiled.
  Independent lines do not share signalling authority. Next step: instrument
  crowded same-line arrivals and distinguish deliberate braking/holding from
  stop/start numerical artifacts before changing safety or adding caches.
- Fresh release commands passed:
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "Windows Desktop" dist/Metro.exe`
  and `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "macOS" dist/Metro-macOS.zip`.
  `unzip -t dist/Metro-macOS.zip`, `file dist/Metro.exe`, universal binary
  inspection, `codesign --verify --deep --strict` on the extracted app,
  exported macOS startup `--headless --quit-after 10 --audio-driver Dummy`,
  and `git diff --check` succeeded; no export log errors/warnings.
  Windows runtime, GPU/frame-time capture, Web and regression suites not run
  for this investigation. Probe and extracted verification app cleaned.

### Moving authority and natural service regulation (2026-11-07)

- Implemented the operator/research findings below. User explicitly approved
  replacing station-count caps with route capacity and recommended fleet.
  Removed whole-section/destination locks; separated safety, motion and service
  regulation. Defaults: acceleration 80, braking 100, terminal recovery 4s,
  nominal speed 90%, bounded additional hold 3s. Multiple trains may now move
  between the same two stations, with independent lines and loop directions.
- Route geometry and cycle/headway estimates determine conservative capacity
  and suggested fleet; neither is a certified real-world signalling model.
  Slider target/fleet tooltips are localized. Surplus retires only at stopped
  terminal/origin visits, including manual slider reductions; these no longer
  reset independent lines. Geometry/wagon edits still rebuild as before.
- Entry points: [dispatcher.gd](./scripts/dispatch/dispatcher.gd),
  [transit_line.gd](./scripts/sim/transit_line.gd),
  [metro.gd](./scripts/sim/metro.gd),
  [transit_graph.gd](./scripts/sim/transit_graph.gd),
  [main.gd](./scripts/main.gd), [ui.csv](./translations/ui.csv).
  Updated [README.md](./README.md), [DESIGN.md](./DESIGN.md) and related smoke
  tests; added nondefault fragment motion inheritance and live-language tooltip
  assertions. Schedule test remains wired into Pages CI.
- Validation commands below passed (commands using `godot` earlier in this task
  resolve to the same installed 4.7.2 binary):

  ```sh
  /Applications/Godot.app/Contents/MacOS/Godot --headless --editor --path . --quit
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/simulation_smoke.gd
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/intersection_smoke.gd
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/schedule_smoke.gd
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/train_controls_smoke.gd
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/loop_smoke.gd
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/editing_smoke.gd
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/localization_smoke.gd
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/audio_smoke.gd
  /Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tests/interface_smoke.gd --audio-driver Dummy
  /Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tests/visual_smoke.gd --audio-driver Dummy
  /Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tests/train_visual_smoke.gd --audio-driver Dummy
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "Windows Desktop" dist/Metro.exe
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "macOS" dist/Metro-macOS.zip
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "Web" dist/web/index.html
  unzip -t dist/Metro-macOS.zip
  file dist/Metro.exe
  git diff --check
  ```

- Regulated departure-gap standard deviation: **0.048s vs 5.272s** unregulated
  in the seeded 1200s unequal-headway loop comparison (final 300s sampled).
  Full six-minute intersection scenarios and sustained live-setting scenarios
  retain arrivals and full-train safety gaps. Audio generated its 48s PCM and
  passed lifecycle checks. Final manual-cap test confirms other-line identity
  survives withdrawal, not merely that replacement trains eventually spawn.
- Initial typed Dictionary inference parse error was fixed. Live-speed test
  initially assumed instant speed clamping; corrected to require braking-rate
  compliance. Watch fixture initially sampled terminal dwell; corrected timing.
  Final tests and import/export logs have no parser/script failures.
- Fresh Windows, universal macOS and Web exports succeeded after final code
  changes. Verified Windows x86_64 PE, archive integrity, macOS x86_64/arm64
  binary, deep strict signature and exported macOS headless startup with
  `--headless --quit-after 10 --audio-driver Dummy`. All four Web assets nonempty.
  Browser startup at 1024x600 passed with loader hidden and no console/page
  errors; browser simulation/input/audio soak and phone checks not rerun.
  Windows runtime and Intel macOS execution not available; Gatekeeper/notarization
  not tested, macOS remains ad-hoc signed. Urban tests not rerun this task.
  No commit/push/deploy. Temporary preview stopped; browser restored.
- The station-block implementation and pending cap decision in older entries
  below are historical and superseded by this implementation.

### Real metro operations research (2026-11-06)

- Research only; no circulation changes. Compared current dispatcher/DESIGN
  with operator publications, a complete operator timetable, engineering
  reporting and rail-specific RATP-associated research. Initial delegated
  synthesis leaned on Wikipedia/bus analogies; coordinator excluded unsupported
  claims and independently verified the sources below. TCRP PDFs returned
  server errors and MTA/FTA resources were inaccessible; no claims attributed
  to their unread contents. Numeric examples below are historical, not universal.
- Verified [TfL working timetable index](https://tfl.gov.uk/corporate/publications-and-reports/working-timetables)
  and [Victoria WTT 42](https://tfl.gov.uk/cdn/static/cms/documents/vic-wtt-42.pdf):
  PDF page 5 / printed page 4 lists 41 trains at 09:00 on weekdays. The
  16-station line exceeds our open station-count ceiling of 30; fleet sizing
  is not a station-count law. Index also explicitly includes depot/empty moves.
  [TfL 2018 anniversary release](https://tfl.gov.uk/info-for/media/press-releases/2018/august/victoria-line-celebrates-50-years-of-serving-london)
  confirms 36 trains/hour, 100-second peak intervals.
- [TfL Four Lines Modernisation](https://tfl.gov.uk/travel-information/improvements-and-projects/four-lines-modernisation)
  distinguishes genuinely shared track/infrastructure and complex junctions;
  new signalling permits closer running. Independent interchange platforms
  need not conflict, but physical merges/shared tracks do. Current game lanes
  remain intentionally independent despite projected visual crossings.
- Complete [Rail Engineer: Squeezing more from the tube (2013)](https://www.railengineer.co.uk/squeezing-more-from-the-tube/)
  reports LU engineers' explanation: separate ATP safety, ATO motion and ATS
  service regulation; many short signalling blocks or moving blocks; controlled
  dwell and turnbacks. Historical Brixton example: 218s turnaround allowance,
  assessed minimum 203s (15s margin), involving change of driver/cab, passengers,
  crossover route and platform clearance, not continuous train-loop timing alone.
  Later vendor plans in that old article are not evidence of today's installation.
  [Victoria line renaissance](https://www.railengineer.co.uk/victoria-line-renaissance/)
  describes station-specific door countdowns and ATO/ATP roles.
- Read rail-specific [Schanzenbacher et al. 2018](https://arxiv.org/html/1809.02876v2),
  particularly Introduction, II-B, III, IV and Conclusion: safety constraints
  and steady average frequency alone do not eliminate headway irregularity.
  Feedback on dwell/run times, with bounded recovery margins, regulates gaps.
  Their results are models/simulation on RATP-associated work, not proof the
  exact policy is deployed network-wide. Also read [junction model (2017)](https://arxiv.org/html/1801.00931v2)
  and [Farhi et al. metro traffic/control abstract](https://arxiv.org/abs/1604.04593):
  train density, signalling segments, dwell and separation influence frequency;
  passenger-dependent dwell can destabilize service without control.
- Recommendations, not adopted decisions: separate safety authority from a
  target service interval; replace whole interstation/destination-slot lockstep
  with shorter virtual or moving blocks within each independent lane; permit
  safe approaches while keeping regulator holds primarily at stations.
  Add bounded gap-feedback and independent acceleration/braking limits, plus
  meaningful terminal recovery. Derive fleet guidance from cycle time / target
  headway including dwell/turnback/recovery; retain the user-chosen station cap
  only as an explicit game rule unless they approve replacing it. Avoid adding
  random delays before a stable regulator. Do not reintroduce global cross-line
  geometric waits. Bottlenecks are real, but ours artificially make the longest
  entire station segment a one-train bottleneck. Fully occupied atomic exchanges
  can synchronize waves; realistic signalling allows independent staggered flow.
- Research handoff limits: no new runtime behavior validated and no simulation
  tests rerun (research/documentation only). Fresh required releases succeeded:

  ```sh
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "Windows Desktop" dist/Metro.exe
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "macOS" dist/Metro-macOS.zip
  unzip -t dist/Metro-macOS.zip
  file dist/Metro.exe
  git diff --check
  ```

  Export logs had no warning/error matches. Verified universal x86_64/arm64,
  `codesign --verify --deep --strict` on extracted app and exported startup
  with `--headless --quit-after 10 --audio-driver Dummy`. Still ad-hoc signed,
  not notarized. Windows runtime/graphical gameplay not checked; Web not rebuilt.
  No commit/push/deploy. Research scratch and extracted app cleaned. Further
  mechanics changes need confirmation because real signalling contradicts the
  previous all-waits-at-stations and station-count-cap choices.

### Independent lanes and station-based scheduling (2026-11-06)

- User chose independent lines at shared stations, then explicitly confirmed
  independent directions despite visual overlap at converging station paths.
  Kept the manual maximum, with open capacity 2 x N - 2 and loop capacity 2 x N.
  Replaced global FIFO junction/body collision constraints and train-following
  braking with directional section and destination-platform reservations.
- [dispatcher.gd](./scripts/dispatch/dispatcher.gd) now releases sections on
  arrival, retains station slots until departure, and atomically exchanges
  ready slots after pruning dependencies. This handles fully occupied circuits
  without circular waits. Timetable holds happen at stations, with live
  cycle/fleet/bottleneck-derived minimum headways; staggered spawn attempts
  retry free origins rather than missing a whole interval.
- [transit_line.gd](./scripts/sim/transit_line.gd) exposes station capacity and
  effective manual limit; [metro.gd](./scripts/sim/metro.gd) tracks station/block
  state. [main.gd](./scripts/main.gd) refreshes cap controls after edits,
  disables empty-line limits and shows the live effective headway in the
  translated minimum-interval tooltip. Fragments retain their desired settings.
  README/DESIGN/current memory replace superseded collision/interlocking policy.
- Added [schedule_smoke.gd](./tests/schedule_smoke.gd) and wired Pages CI.
  Tests compare the same line's exact distances/arrivals when alone or crossed
  by a slow line; assert exclusive moving sections and reserved destination
  slots, waits only at stations, live minimum departure gaps, numerical
  full-train separation within loop lanes, pause/reset, capacity/balance and
  explicitly seeded full open/loop circuits. Existing simulation/loop/intersection
  tests now verify the chosen block contract instead of cross-lane body geometry.
  Updated train-cap tests and follow-zoom marker assertions for line-colored
  borders (the previous neutral-border probes were stale).
- Initial experiments retaining same-line/opposite-direction body rejection
  deadlocked short shared sections; independent-direction approval removed that
  coupling. Section-only prototypes exposed destination bunching under a
  full-train gap test; added station-slot reservations and atomic exchanges.
  A natural-dispatch fixture did not always fill the theoretical cap (intended
  ceiling); explicit full-cap fixtures now test atomic swaps. Their typed-array
  conditional briefly emitted script errors despite exit zero; fixed and reran.
  No final script errors or failed assertions remain.
- Final commands passed with `/Applications/Godot.app/Contents/MacOS/Godot`
  (shown here as `godot`):

  ```sh
  godot --headless --editor --path . --quit
  godot --headless --path . --script res://tests/schedule_smoke.gd
  godot --headless --path . --script res://tests/simulation_smoke.gd
  godot --headless --path . --script res://tests/loop_smoke.gd
  godot --headless --path . --script res://tests/train_controls_smoke.gd
  godot --headless --path . --script res://tests/intersection_smoke.gd
  godot --headless --path . --script res://tests/interface_smoke.gd
  godot --headless --path . --script res://tests/editing_smoke.gd
  godot --headless --path . --script res://tests/localization_smoke.gd
  godot --headless --path . --script res://tests/audio_smoke.gd
  godot --path . --script res://tests/interface_smoke.gd --audio-driver Dummy
  godot --path . --script res://tests/visual_smoke.gd --audio-driver Dummy
  godot --path . --script res://tests/train_visual_smoke.gd --audio-driver Dummy
  godot --headless --path . --export-release "Windows Desktop" dist/Metro.exe
  godot --headless --path . --export-release "macOS" dist/Metro-macOS.zip
  godot --headless --path . --export-release "Web" dist/web/index.html
  unzip -t dist/Metro-macOS.zip
  file dist/Metro.exe
  git diff --check
  ```

- Six-minute scenarios continued serving in the second half: perpendicular
  [82,82] to [174,174], nearby shared sections [55,55] to [115,115], three
  lines [82,82,30] to [174,174,70], screenshot layout [103,95] to [218,213].
  Fresh Windows/macOS/Web exports all succeeded; import/export logs had no
  error/warning matches. Verified Windows PE x86_64, nonempty Web HTML/JS/WASM/PCK,
  macOS ZIP contents, universal x86_64/arm64 executable, strict deep signature
  (`codesign --verify --deep --strict`) and exported startup
  (`--headless --quit-after 10 --audio-driver Dummy`).
  macOS remains ad-hoc signed, not notarized. No commit/push/deploy.
  Browser/physical phone/Safari and Windows runtime not rerun; no unfinished
  implementation. Temporary captures, logs and verification app cleaned.

### Line-colored concentric station borders (2026-11-06)

- User chose slightly larger shared stations rather than squeezing inner rings.
  Added darkened per-line borders, oldest line outside/newer inside, neutral
  unconnected/ghost fallback and unchanged white center. Membership follows
  current ordered lines, not per-station attachment timestamps; fragments keep
  the existing line ordering policy.
- [world_view.gd](./scripts/render/world_view.gd) shares station membership/radius
  and committed painting with source/target previews; outer selection, hover,
  valid-target rings, captions and handle connectors follow marker size.
  [main.gd](./scripts/main.gd) uses the radius for center picking and station
  snapping, without changing coordinates, rails or dispatcher geometry.
- Visual regression covers 0/1/2/4/8 lines, loop deduplication, day/night,
  zoom 1/2.5, exact ring color/order, preserved white core, recoloring, removal
  and source/target/hover/watch preservation. Interface regression exercises
  outer-border moves and connection handles at zoom 0.65/1/2.5.
  README/DESIGN and both documentation screenshots refreshed.
- Initial capture failed because camera smoothing left the marker offscreen;
  fixed fixture with reset/force scroll. Expanded test briefly had indentation
  and inferred-Color parser errors, corrected before final clean runs.
- Final validation passed using `/Applications/Godot.app/Contents/MacOS/Godot`:

  ```sh
  /Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tests/visual_smoke.gd --audio-driver Dummy
  /Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tests/interface_smoke.gd --audio-driver Dummy
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/interface_smoke.gd
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/editing_smoke.gd
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/localization_smoke.gd
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "Windows Desktop" dist/Metro.exe
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "macOS" dist/Metro-macOS.zip
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "Web" dist/web/index.html
  unzip -t dist/Metro-macOS.zip
  file dist/Metro.exe
  git diff --check
  ```

- All three release exports succeeded; logs had no error/warning matches.
  Verified nonempty Web HTML/JS/WASM/PCK, Windows PE x86_64, macOS universal
  x86_64/arm64, `codesign --verify --deep --strict` on the extracted app, and
  exported macOS startup with `--headless --quit-after 10 --audio-driver Dummy`.
  Ad-hoc signing, not notarization. No commit/push/deploy. Browser, physical
  phone/Safari, Windows runtime and full simulation/audio suites not rerun.

### Train-follow editing overlay suppression (2026-11-06)

- [main.gd](./scripts/main.gd): following cancels gestures and clears hover
  immediately; `_update_interaction_overlays` suppresses selection/ghost/gizmos
  while hidden or following, consistently on follow/stop/watch/frame changes.
  Hover and first-connection guidance reject following; map clicks only select
  trains and Delete is ignored. HUD/camera remain usable. Stopping follow
  restores overlays only when HUD is shown.
- [world_view.gd](./scripts/render/world_view.gd) also gates route preview
  drawing on overlay visibility. Updated README/DESIGN and interface regression
  assertions for ghost/edit suppression, Delete, watch toggling during follow,
  frame stability and resumed placement preview after stopping.
- Initial regression read an empty train array after an earlier gesture rebuilt
  dispatch; corrected fixture by advancing dispatcher before selecting train.
  Initial graphical run was stopped after the script error. Final runs clean:

  ```sh
  godot --headless --path . --script res://tests/interface_smoke.gd
  godot --path . --script res://tests/interface_smoke.gd --audio-driver Dummy
  godot --path . --script res://tests/visual_smoke.gd --audio-driver Dummy
  godot --headless --path . --script res://tests/train_controls_smoke.gd
  godot --headless --path . --export-release "Web" dist/web/index.html
  godot --headless --path . --export-release "Windows Desktop" dist/Metro.exe
  godot --headless --path . --export-release "macOS" dist/Metro-macOS.zip
  unzip -t dist/Metro-macOS.zip
  file dist/Metro.exe
  git diff --check
  ```

- Used `/Applications/Godot.app/Contents/MacOS/Godot`. All final fresh exports
  succeeded without logged warnings/errors. Verified Web assets, Windows PE
  x86_64, universal macOS x86_64/arm64, strict deep signature and exported startup
  (`--headless --quit-after 10 --audio-driver Dummy`).
- Browser/physical phone/Safari/Windows runtime and full intersection/audio
  suites not run. No commit, push or deployment performed.

### Silent success and contextual connection cues (2026-11-06)

- Implemented the agreed guidance direction in [main.gd](./scripts/main.gd)
  and [world_view.gd](./scripts/render/world_view.gd). Removed `_notify` and all
  obvious-success messages, including startup, selection clearing, moving,
  train following and recoloring. Error/warning paths remain explicit.
  Shortened length-related English/French errors to actionable instructions.
- `_update_connection_guidance` exposes the first station's neutral + until
  first successful connection, no pulsation/text. Session-only completion
  stays retired if network is later deleted. `_extend_stroke` computes valid
  destination IDs against pinned path and posture using existing validation;
  WorldView renders restrained destination rings only during route drawing.
  Existing hover handles, ghost, help and watch controls remain.
- Tests cover silent placement/routes/line changes/recoloring, first-step cue
  retirement, sheet/watch suppression, invalid short/valid pinned destinations
  and cancellation. Day/night pixel checks verify local + and target rings.
  Initial test placed a short destination over the source's handle; moved the
  test station off that handle to exercise intended hit-testing.
  Updated README/DESIGN and localization expectations; error toast tests now
  exercise real error paths instead of removed success notifications.
- Passed with `/Applications/Godot.app/Contents/MacOS/Godot`:

  ```sh
  godot --headless --editor --path . --quit
  godot --headless --path . --script res://tests/interface_smoke.gd
  godot --path . --script res://tests/interface_smoke.gd --audio-driver Dummy
  godot --headless --path . --script res://tests/localization_smoke.gd
  godot --headless --path . --script res://tests/editing_smoke.gd
  godot --path . --script res://tests/visual_smoke.gd --audio-driver Dummy
  godot --headless --path . --export-release "Web" dist/web/index.html
  godot --headless --path . --export-release "Windows Desktop" dist/Metro.exe
  godot --headless --path . --export-release "macOS" dist/Metro-macOS.zip
  unzip -t dist/Metro-macOS.zip
  file dist/Metro.exe
  git diff --check
  ```

- All final exports succeeded without logged warnings/errors. Verified Web
  assets, Windows PE x86_64, universal macOS x86_64/arm64, strict deep signature
  and exported startup (`--headless --quit-after 10 --audio-driver Dummy`).
- Browser/Safari/physical phone/Windows runtime and full simulation/audio/
  intersection suites not run this task; route validation reused, dispatch
  unchanged. No commit, push or deployment performed.

### Actual text-sized notification fix (2026-11-06)

- User's new capture confirmed the oversized element was the map notification,
  not only help. Prior fix did not address its retained Label/PanelContainer
  minimum height. [main.gd](./scripts/main.gd) now uses Panel plus explicitly
  measured RichTextLabel, without fit_content. `_resize_notification` computes
  text width, wrapped height and style margins on message/locale/viewport
  changes. Short messages shrink immediately after longer errors.
- Initial Panel/Label attempt still retained a 153px Label minimum height;
  new actual-label-bounds regression caught it. Replaced Label with manually
  sized RichTextLabel and verified real content height is not clipped.
  [interface_smoke.gd](./tests/interface_smoke.gd) asserts short toasts <=200x52,
  long-error-to-short-message shrinkage, error content containment, both
  languages at phone/laptop widths. Native screenshot visibly confirmed small
  Station added toast. Updated README/DESIGN and localization test type.
- Passed with `/Applications/Godot.app/Contents/MacOS/Godot`:

  ```sh
  godot --headless --path . --script res://tests/interface_smoke.gd
  godot --path . --script res://tests/interface_smoke.gd --audio-driver Dummy
  godot --headless --path . --script res://tests/localization_smoke.gd
  godot --headless --path . --export-release "Web" dist/web/index.html
  godot --headless --path . --export-release "Windows Desktop" dist/Metro.exe
  godot --headless --path . --export-release "macOS" dist/Metro-macOS.zip
  unzip -t dist/Metro-macOS.zip
  file dist/Metro.exe
  git diff --check
  ```

- Final fresh exports all succeeded without logged warnings/errors. Verified
  nonempty Web assets, Windows PE x86_64, universal macOS x86_64/arm64, strict
  deep signature and exported startup (`--headless --quit-after 10
  --audio-driver Dummy`). Native toast capture inspected.
- Browser/Safari/physical phone/Windows runtime checks not run this task.
  Full simulation/audio/geometry suites not rerun for toast-only change.
  No commit, push or deployment performed.

### Help feedback layout and shorter messages (2026-11-06)

- User showed an oversized mostly blank panel with route feedback. Corrected
  `_refresh_status_translation` in [main.gd](./scripts/main.gd): it previously
  populated/showed every sheet feedback label whenever any sheet was open.
  Only the visible sheet receives it now; closed-sheet labels are cleared and
  hidden, avoiding zero-width autowrap/minimum-size contamination.
- Help is now a compact six-action reference plus navigation/watch shortcuts,
  with tighter spacing. Routine create/move/save/insert/delete/follow messages
  use short translated confirmations and `_notify` (2.5 seconds). Existing
  `_set_status` errors/warnings retain eight seconds and visible-sheet feedback.
  Updated README/DESIGN and English/French translations.
- [interface_smoke.gd](./tests/interface_smoke.gd) reproduces feedback in line
  controls followed by help, both languages at 1024x640/760x520/390x640.
  Checks closed labels stay empty/hidden, help bounds/visible instructions,
  no laptop scrollbar, <=390-character main help, no inflated short-message
  panel, 2.5-second expiry and unchanged error duration. Localization checks
  verify the new action-reference text.
- Passed with `/Applications/Godot.app/Contents/MacOS/Godot`:

  ```sh
  godot --headless --editor --path . --quit
  godot --headless --path . --script res://tests/interface_smoke.gd
  godot --path . --script res://tests/interface_smoke.gd --audio-driver Dummy
  godot --headless --path . --script res://tests/localization_smoke.gd
  godot --headless --path . --script res://tests/editing_smoke.gd
  godot --path . --script res://tests/visual_smoke.gd --audio-driver Dummy
  godot --headless --path . --export-release "Web" dist/web/index.html
  godot --headless --path . --export-release "Windows Desktop" dist/Metro.exe
  godot --headless --path . --export-release "macOS" dist/Metro-macOS.zip
  unzip -t dist/Metro-macOS.zip
  file dist/Metro.exe
  git diff --check
  ```

- All fresh exports succeeded without logged warnings/errors. Verified nonempty
  Web assets, Windows PE x86_64, universal macOS x86_64/arm64, strict deep
  signature and exported startup (`--headless --quit-after 10 --audio-driver
  Dummy`). Chromium at 1024x640 visually shows complete concise help without
  scrollbar; fresh load produced no page errors.
- No physical phone/Safari/Windows runtime or full intersection/audio tests;
  layout/text/timing only. No commit, push or deployment performed.

### Full-width integrated rail and subtle watch grip (2026-11-06)

- User chose a full-width bottom rail over the floating pill. In
  [main.gd](./scripts/main.gd), `_main_panel` now holds a single VBox containing
  the integrated `_line_popup` controls and fixed bottom tab/action row.
  Removed rounded rail/shadow and redundant settings action; line tabs use
  neutral text/background with colored underlines. `_resize_interface` derives
  expanded height from content and uses responsive columns; tabs remain
  reachable while phone details scroll. Same selected tab folds its controls.
- `_edge_handle` / `_draw_edge_handle` replace both collapsed pill and Show
  interface button with a small translucent bottom grip, no text/background.
  Touch area remains 96x44, tooltips/help translated, contrast follows day/night.
  Watch grip is independent of hidden/dimmed UI. Existing watch safety, gestures,
  train following and eight-second dim behavior remain.
- Updated README/DESIGN, removed obsolete watch instructions from translations,
  refreshed native day/night documentation captures. Tests now assert integrated
  containment, full-width rail, true overflow, no laptop detail scrollbar,
  same-tab folding, real Retina tab/picker input and textless transparent grip.
  Native pixel regression verifies grip visibility/subtlety at day/night and
  unchanged background outside its small stroke.
- Passed with `/Applications/Godot.app/Contents/MacOS/Godot`:

  ```sh
  godot --headless --editor --path . --quit
  godot --headless --path . --script res://tests/interface_smoke.gd
  godot --path . --script res://tests/interface_smoke.gd --audio-driver Dummy
  godot --headless --path . --script res://tests/localization_smoke.gd
  godot --headless --path . --script res://tests/editing_smoke.gd
  godot --path . --script res://tests/visual_smoke.gd --audio-driver Dummy
  godot --headless --path . --export-release "Web" dist/web/index.html
  godot --headless --path . --export-release "Windows Desktop" dist/Metro.exe
  godot --headless --path . --export-release "macOS" dist/Metro-macOS.zip
  unzip -t dist/Metro-macOS.zip
  file dist/Metro.exe
  git diff --check
  ```

- Initial visual inspection showed legacy `_update_configuration_ui` reapplying
  the old colored rounded sheet border and margins. Removed that obsolete
  styling; added exact laptop scrollbar regression (initially failed, now
  passes), rather than merely checking last slider position.
- Fresh Web/Windows/macOS exports completed without logged warnings/errors.
  Verified Web assets, Windows PE x86_64, universal macOS x86_64/arm64, strict
  deep signature and exported startup (`--headless --quit-after 10
  --audio-driver Dummy`). Chromium inspected at 1024x600 and 390x640/2x:
  integrated controls, subtle watch grip and touch restoration without station
  placement. Native night watch and day/night docs captures inspected.
- No physical phone/Safari/Windows runtime or full intersection/audio checks;
  dispatch/geometry/audio unchanged. No commit, push or deployment performed.

### Dock overflow sizing correction (2026-11-06)

- User reported a growing dock still displaying a scrollbar. The collapse
  button inherited `SIZE_EXPAND_FILL` from `_button`, stealing flexible space
  from the tab scroll area. Its shrink flag now matches the fixed + action.
  Replaced the line-count width estimate with measured HBox/action, tab and
  panel-style minimum sizes. Genuine overflow still scrolls at the 760px cap
  or viewport edge. No changes to collapse/watch/idle behavior.
- Updated [main.gd](./scripts/main.gd), [interface_smoke.gd](./tests/interface_smoke.gd)
  and [DESIGN.md](./DESIGN.md). Tests assert scrollbar visibility matches actual
  required width, no clipping/scroll offset when content fits, collapse target
  stays fixed, and viewport/cap bounds hold. Covers one/two lines initially,
  then three through twelve at 390/760/1024px in English and French.
- Passed with `/Applications/Godot.app/Contents/MacOS/Godot`:

  ```sh
  godot --headless --path . --script res://tests/interface_smoke.gd
  godot --path . --script res://tests/interface_smoke.gd --audio-driver Dummy
  godot --headless --path . --export-release "Web" dist/web/index.html
  godot --headless --path . --export-release "Windows Desktop" dist/Metro.exe
  godot --headless --path . --export-release "macOS" dist/Metro-macOS.zip
  unzip -t dist/Metro-macOS.zip
  file dist/Metro.exe
  git diff --check
  ```

- All three fresh exports completed without logged warnings/errors. Verified
  nonempty Web assets, Windows PE x86_64, universal macOS x86_64/arm64, strict
  deep signature and exported startup (`--headless --quit-after 10
  --audio-driver Dummy`). Chromium at 1024x600: visually confirmed one, two
  and three full line tabs without false scrollbars; creation uses actual +.
  Initial Web load had no page errors.
- Windows runtime, Safari and physical phone checks not run. Simulation,
  audio and full geometry suites not rerun for this layout-only correction.
  No commit, push or deployment performed.

### Collapsible dock, idle fade and touch-safe watch mode (2026-11-06)

- [main.gd](./scripts/main.gd): `_toggle_dock` switches the bottom dock to
  an active-line colored/numbered pill without changing simulation/selection.
  `_update_ui_idle` measures eight seconds, then fades the UI root to 0.28
  over 0.6 seconds. `_wake_interface` immediately restores opacity on input or
  feedback; open sheets/dialogs/picker and active edits/panning hold it awake.
- Watch mode keeps a separate, themed Show interface button outside the hidden
  UI root. It never dims, has a 44px touch target and exits watch via GUI input,
  without letting the tap place a station. Collapse survives watch transitions.
  Updated English/French UI/help, README and DESIGN.
- Phone-width browser inspection exposed the extra collapse button squeezing
  the first route tab. Hide the redundant Line settings button below 620px;
  tabs already open the same sheet. A new measured regression requires at
  least 104px for route scrolling at all tested viewport sizes.
- Passed with `/Applications/Godot.app/Contents/MacOS/Godot`:

  ```sh
  godot --headless --editor --path . --quit
  godot --headless --path . --script res://tests/interface_smoke.gd
  godot --path . --script res://tests/interface_smoke.gd --audio-driver Dummy
  godot --headless --path . --script res://tests/localization_smoke.gd
  godot --path . --script res://tests/visual_smoke.gd --audio-driver Dummy
  godot --headless --path . --script res://tests/editing_smoke.gd
  godot --headless --path . --export-release "Web" dist/web/index.html
  godot --headless --path . --export-release "Windows Desktop" dist/Metro.exe
  godot --headless --path . --export-release "macOS" dist/Metro-macOS.zip
  unzip -t dist/Metro-macOS.zip
  file dist/Metro.exe
  git diff --check
  ```

- Interface tests measure exact idle threshold, intermediate/final alpha,
  mouse/touch wakeup, menu/gesture protection, visible feedback, phone pill
  bounds, real collapse/expand/restore clicks and no graph/pause/line changes.
  All final exports completed without logged warnings/errors. Verified Web
  assets, Windows PE x86_64, universal macOS x86_64/arm64, deep strict ad-hoc
  signature and exported startup (`--headless --quit-after 10 --audio-driver
  Dummy`).
- Chromium at 390x640 CSS / 2x density: observed touch collapse, eight-second
  fade, watch restore affordance and successful touch-only restoration.
  Initial browser load had no JavaScript errors. Hidden integrated page
  stalled CDP touch dispatch; focus emulation made the page visible and allowed
  validation (not an application fix).
- No physical phone/Safari/Windows runtime checks, full intersection or audio
  suites this task; simulation/render geometry/audio unchanged. No commit,
  push or deployment performed.

### Station ghost and watch mode (2026-11-06)

- Removed the Station toggle and its tool-mode branches. Empty-space clicks
  always place stations; existing station, rail and train actions retain
  priority. Ghost position shares `_station_placement_position` with placement.
  Faint station fill/border adapt to night; ghost never mutates the graph.
- [main.gd](./scripts/main.gd) suppresses ghosts over rails/stations/trains,
  controls, sheets/dialogs, while panning/Space-dragging/drawing/moving, on
  pointer exit and in watch mode. Clicking the map with a sheet open dismisses
  the sheet without placing a station.
- Added H/Menu hide action, translated help/tooltip, H/Escape restoration.
  `_toggle_ui` cancels gestures, closes sheets/dialogs, hides UI root and
  [world_view.gd](./scripts/render/world_view.gd) editing overlays, not the
  network. Watch clicks can follow trains but cannot edit; Delete is ignored.
  Pause state is unchanged, so previously running trains continue.
- Updated README/DESIGN and day/night screenshots. Added real-input and
  behavior assertions for exact preview/click agreement, context priority,
  pointer exit/pan/sheet suppression, safe cancellation, H/Escape, train
  following, continued train movement and camera gestures. Native pixel tests
  verify translucent ghosts across day/night and zoom 0.65/1/2.5, removal in
  watch mode, and preserved visible stations.
- Passed commands with Godot executable
  `/Applications/Godot.app/Contents/MacOS/Godot`:

  ```sh
  godot --headless --editor --path . --quit
  godot --headless --path . --script res://tests/interface_smoke.gd
  godot --headless --path . --script res://tests/localization_smoke.gd
  godot --headless --path . --script res://tests/editing_smoke.gd
  godot --headless --path . --script res://tests/train_controls_smoke.gd
  godot --headless --path . --script res://tests/simulation_smoke.gd
  godot --path . --script res://tests/visual_smoke.gd --audio-driver Dummy
  godot --path . --script res://tests/interface_smoke.gd --audio-driver Dummy
  godot --headless --path . --export-release "Web" dist/web/index.html
  godot --headless --path . --export-release "Windows Desktop" dist/Metro.exe
  godot --headless --path . --export-release "macOS" dist/Metro-macOS.zip
  unzip -t dist/Metro-macOS.zip
  file dist/Metro.exe
  git diff --check
  ```

- All three fresh exports completed without logged warnings/errors. Verified
  Web entry assets, Windows PE x86_64, universal macOS x86_64/arm64, strict deep
  signature and exported macOS startup (`--headless --quit-after 10
  --audio-driver Dummy`). Inspected native ghost/watch captures at 2x density.
  Browser `/web/` at 1024 x 600 loaded without JS errors; observed ghost,
  station placement, H hiding all UI/ghost and Escape restoring HUD. Integrated
  browser needed explicit canvas focus before keyboard events.
- Initial test issues corrected: rail-priority probe used an outdated straight
  path after route editing; switched to current geometry. Pixel test needed
  explicit redraw with main processing disabled, and screen-bounds guards for
  a station offscreen at 2.5x. Final native runs had no logged errors.
- Intersection/audio suites not rerun (dispatch/audio unchanged). Safari,
  Windows runtime and physical trackpad not exercised. No commit/push/deploy.

### Map-first menu and readable Retina UI (2026-11-06)

- Replaced the tiny always-visible sidebar with a quiet top toolbar, compact
  route dock, and on-demand sheets. Paper/ink colours, numbered colour-coded
  routes, larger slider handles, active-button states and thin station-like
  outlines fit the map's visual language. Referenced official Mini Metro
  presentation, Game Accessibility Guidelines and Godot hiDPI docs; sources
  and design choices are linked in [DESIGN.md](./DESIGN.md).
- Measured native scale 2.0 while the old viewport rendered at 1x. Fixed root
  canvas-items density and physical native window/minimum sizes. Web resize
  also rechecks device density. World input retains logical coordinates;
  real physical pointer tests cover menu, picker, slider and station placement
  at 2x. Windows display scaling/runtime was not manually checked.
- Body text 16+, titles 22/26, buttons 44+, sliders 32+ logical pixels.
  Tests measure 7:1 primary contrast, 4.5:1 secondary/selected-tab contrast,
  English/French bounds from 3840 x 2160 through 760 x 520 and 390 x 640,
  all five line settings without scrolling on laptop sizes, overflow with
  twelve lines, exclusive sheets, Escape, and visible/transient error feedback.
- Updated README controls and real day/night screenshots; documentation captures
  also inspected native sheets at 1024 x 600 and 760 x 520 at 2x density.
  Simplified ColorPicker retains free colours and presets within 520px height.
  Added headless interface/localization regressions to Pages CI.
- Passed commands (Godot executable is
  `/Applications/Godot.app/Contents/MacOS/Godot`):

  ```sh
  godot --headless --editor --path . --quit
  godot --headless --path . --script res://tests/interface_smoke.gd
  godot --path . --script res://tests/interface_smoke.gd --audio-driver Dummy
  godot --headless --path . --script res://tests/localization_smoke.gd
  godot --headless --path . --script res://tests/simulation_smoke.gd
  godot --headless --path . --script res://tests/editing_smoke.gd
  godot --headless --path . --script res://tests/train_controls_smoke.gd
  godot --headless --path . --script res://tests/loop_smoke.gd
  godot --headless --path . --script res://tests/audio_smoke.gd
  godot --path . --script res://tests/visual_smoke.gd --audio-driver Dummy
  godot --headless --path . --export-release "Web" dist/web/index.html
  godot --headless --path . --export-release "Windows Desktop" dist/Metro.exe
  godot --headless --path . --export-release "macOS" dist/Metro-macOS.zip
  unzip -t dist/Metro-macOS.zip
  file dist/Metro.exe
  git diff --check
  ```

- All three fresh exports succeeded without logged errors/warnings. Verified
  nonempty Web entry assets, PE x86_64, universal macOS x86_64/arm64, strict
  deep signature and exported-app startup with
  `--headless --quit-after 10 --audio-driver Dummy`. Native project UI/world
  tests used Apple M2 graphics with Dummy audio.
- Browser loaded under `/web/` without JS errors at 1024 x 600 / 760 x 520 CSS
  pixels; observed settings and line sheets opening via pointer. Emulated 2x
  density produced a 2048 x 1200 canvas at 1024 x 600 CSS pixels with unchanged
  apparent UI size and working line-settings input. Inspected 390 x 640 CSS
  layout on a 780 x 1280 canvas. The integrated browser reports hidden state
  and can defer resize/first-click processing; native automated tests provide
  the deterministic input/resize checks. Safari and physical Air testing remain.
- Initial failures corrected: deferred route scrolling referenced removed tabs
  when several lines changed in one frame; now resolves the current tab at
  execution. A world pixel probe hit the relocated HUD; fixed-scale world tests
  now hide HUD, whose rendering/input has separate tests. `actionlint` was
  absent from PATH; temporary official 1.7.12 validated the updated workflow.
- Full intersection suite was not rerun (dispatch/geometry unchanged).
  No commit, push or hosted deployment performed for this redesign.

### GitHub Pages and concise README (2026-11-06)

- Added single-thread Web preset and GitHub Actions build/deployment workflow,
  pinned to matching Godot/editor templates 4.7.2. PRs validate without deployment;
  pushes/manual runs on main deploy using the official Pages actions.
- Reorganized the French README into quick start, controls, development and
  deployment sections, with actual day/night screenshots of the same network.
  Added docs import/export exclusions so screenshots are not shipped in the game.
- Browser testing found real Web Sample-backend AudioBuffer errors. A first
  override mistakenly used AudioServer's enum value; verified engine source and
  corrected ProjectSettings' value to Stream (`0`). Added an audio regression
  assertion and included the audio smoke test in CI.
- Validation passed:

  ```sh
  actionlint .github/workflows/pages.yml
  git diff --check
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/simulation_smoke.gd
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/audio_smoke.gd
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "Web" dist/web/index.html
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "Windows Desktop" dist/Metro.exe
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "macOS" dist/Metro-macOS.zip
  unzip -t dist/Metro-macOS.zip
  file dist/Metro.exe
  ```

- Used temporary actionlint 1.7.12. All three exports completed without logged
  errors/warnings; required Web files are nonempty. Verified universal macOS
  architectures, strict deep code signature and exported-app headless startup
  (`--headless --quit-after 10 --audio-driver Dummy`). Windows runtime not run.
- Served `dist` with `python3 -m http.server 8765 --bind 127.0.0.1 --directory dist`.
  Browser rendered at 1180 x 740, accepted station placement under `/web/`,
  and ran for 55 seconds after interaction (beyond the 48-second music loop)
  without page errors, console errors or failed requests, with cross-origin
  isolation disabled. Initial loading-poll timeouts were test-harness failures;
  subsequent inspection confirmed the loading element was removed and game ready.
- Hosted run 42316780697 reached Pages deployment; the user-provided log shows
  the artifact accepted and deployment progressing from queued to syncing files.
  Public API inspection during follow-up found the run still in progress;
  final publication remains unverified. The action's punycode deprecation is
  an upstream Node dependency warning, not a deployment failure. Its deployment
  timeout defaults to 600000 ms; the workflow deploy job also caps at 10 minutes.
  No workflow change was needed for these normal progress messages.
- Follow-up native refresh reran the exact Windows/macOS export commands above:
  both succeeded without logged errors/warnings; `unzip -t dist/Metro-macOS.zip`
  and `file dist/Metro.exe` passed. No gameplay tests were rerun for this
  explanation-only follow-up. Safari, physical trackpad feel and subjective
  music quality were not manually verified.

### Station alignment, laptop controls, and music (2026-11-06)

- Tightened rounded corners at station anchors to 12 pixels while retaining
  smooth turns. A first hard-corner variant caused two shared-station deadlock
  checks; the smooth radius passed the full intersection safety suite. Station
  circles now draw above trains, confirmed by a native pixel test.
- Added Godot pan and magnify gesture handling for trackpad pan/pinch, with
  synthetic input tests. Reduced startup window/viewport to 1180 x 740, minimum
  760 x 520; made the settings popover scrollable and reposition it inside the
  viewport. Added translated navigation instructions and README documentation.
- Reworked the 48-second score to use a repeating C-major eight-bar progression,
  a steady 80 BPM kick/backbeat, sparse melody and softer hats/snare; reduced
  default music volume from 0.55 to 0.4. Audio tests check key, progression,
  per-bar beat and loop boundaries.
- Godot 4.7.2 import, audio, loop, controls, UI, simulation, editing,
  localization, visual and six-scenario intersection tests passed. Native
  rendering tests ran on Apple M2 with `--audio-driver Dummy`; trackpad hardware
  gestures were not manually exercised. Each standard test command listed
  above was run with `/Applications/Godot.app/Contents/MacOS/Godot` in place
  of `godot`.
- Fresh release exports and checks:

  ```sh
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "Windows Desktop" dist/Metro.exe
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "macOS" dist/Metro-macOS.zip
  ```

- Windows PE and universal macOS ZIP/binary verified; the exported macOS app
  passed `unzip -t`, `file`, `codesign --verify --deep --strict` and headless
  startup checks. Windows runtime was not run on this Mac. Apple notarization is
  not configured; physical trackpad behavior awaits user confirmation.

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

### macOS release build repaired (2026-11-06)

- User installed Godot 4.7.2 and matching export templates. Created ignored
  `dist/` output folder after the first export attempt reported it missing.
  macOS universal and Windows x86_64 release exports both succeeded with:

  ```sh
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "macOS" dist/Metro-macOS.zip
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "Windows Desktop" dist/Metro.exe
  ```

- Verified ZIP integrity and bundle layout with `unzip -t`, universal Mach-O
  x86_64 + arm64 via `file`, and Windows PE32+ x86_64 via `file`. macOS bundle
  also launched headlessly and quit successfully using
  `Metro --headless --quit-after 10 --audio-driver Dummy`. Windows runtime and
  gameplay suites were not run. Godot rewrote project settings while scanning;
  those unrelated changes were restored, leaving the required ARM64 texture
  import setting intact.

## Open limits and next-session cautions

- Off-station independent rail crossings remain unsupported.
- Hidden simulation turnarounds still carry trains continuously; visible rails
  do not draw these loops. If train motion itself still looks like spinning,
  inspect a new reproduction rather than assuming cap removal changed motion.
- Station alignment, trackpad and revised music changes pass automated tests;
  user confirmation of MacBook trackpad feel and music quality remains useful.
- Elastic drawing is implemented and exported; the earlier research alternatives
  are historical, not pending. Await user feedback on the interaction feel.
  Keep this file current instead of relying on prior chats or private session files.
