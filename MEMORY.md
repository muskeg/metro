# Metro - repository memory

Last updated: 2026-11-07.

## Read first

This is the shared context handoff for Metro agents. Follow [AGENTS.md](./AGENTS.md)
at session start and completion. Check the source before relying on these notes.
Detailed controls and commands: [docs/guide.md](./docs/guide.md). Decisions and rationale:
[DESIGN.md](./DESIGN.md). Original requirements: [systemprompt.md](./systemprompt.md).

## Current product decisions

- Native Godot 4/GDScript relaxing transit builder, named **Metro**. No economy,
  failure pressure or network-wide demand simulation. Light bounded local
  passenger exchanges affect stop times without destinations or transfers.
  Release targets: Windows x86_64, universal macOS (Intel x86_64 + Apple Silicon
  arm64), Linux x86_64, single-thread Web hosted on GitHub Pages, unsigned
  Android ARMv7/ARM64 APK and unsigned iOS Xcode project archive (not an IPA).
  Mobile artifacts require signing/building before installation.
- English default; French can be selected live in Menu. Language is persisted
  through ConfigFile. Add all new UI messages to [ui.csv](./translations/ui.csv).
- Menu provides Save / Load / Clear for multiple named local layouts, with
  confirmation before overwrite/load/clear. Clear preserves saved layouts;
  no autosave or cloud sync. Versioned JSON in `user://layouts` uses native
  files on Windows/macOS and IndexedDB on Web. Layouts retain topology,
  waypoint orientation, shared tracks, loops, colors, all line preferences and
  camera/active-line selection. Trains/visits restart; pause, time, language and audio remain
  session state. Browser storage can be cleared/evicted; warn when
  `OS.is_userfs_persistent()` is false, never promise retention when true.
  Names are at most 64 characters, files at most 16 MiB. See
  [docs/guide.md](./docs/guide.md) and [DESIGN.md](./DESIGN.md) for storage details.
  Menu Export/Import shares portable version-1 JSON: native file dialogs,
  browser download/file upload. Current map exports; import validates then
  confirms/fits, never overwrites local saves automatically. Use Save afterwards.
  Same validator enforces bounded JSON/collections/coordinates/fleets/geometry,
  exact grid, unique positions and safe track/train clearance before rendering.
  No scripts, external resources or paths taken from file content. Exact
  safety limits and platform caveats documented in docs/guide.md and DESIGN.md.
- Desktop launches open the bundled **Metro demo**: 16 stations, three lines,
  one loop, crossings only at interchanges. Load always offers the immutable
  included original, separately from user saves with identical names; Save
  writes user copies only. Clear starts empty but keeps the original available.
  All startup/menu loads (including user saves) center full station, waypoint
  and offset running-route bounds and fill one usable window dimension.
  Preserve aspect ratio, 24-world-unit safety margin and 32px side/80px top/
  112px bottom HUD space. Fit may zoom in or below 0.08; that lower fit becomes
  the navigation floor. Stored framing remains in JSON but is overridden on
  menu load. Empty loads use origin/1x; resizing does not refit manual views.
  Dedicated -/+ and four-corner Fit controls above the dock provide 44px
  targets and EN/FR tooltips. Fit ends following/gestures and closes sheets,
  but preserves live trains, pause and topology. Watch mode hides controls.
  The starter resource ships with Windows/macOS/Web without
  relying on writable storage or browser persistence.
  Web exports (including GitHub Pages) carry `montreal_startup` and instead
  open bundled Montreal on every launch; saved layouts remain untouched and
  all included presets stay accessible through Load.
- Load also offers named real-network presets: Tokyo central JR (80 stations,
  97 tracks, ten paths anchored by the full 30-station Yamanote loop; includes
  Tokaido Tokyo–Odawara via Hiratsuka and Shonan-Shinjuku Akabane–Odawara
  rapid / Akabane–Zushi local) and Montreal (68 stations,
  69 tracks, four metro-only paths; no REM/exo, bus or projected connections).
  Tokyo starts with `max_trains=2`; Montreal with 6 on green/orange/blue and 2
  on yellow, all two-wagon trains. Desired interval 12s on Montreal allows
  the requested fleets, progressively dispatched within existing service
  headway/capacity rules. Fleet ceilings remain editable.
  Original schematic coordinates, not copied artwork.
  Tokyo replaces the former regional JR East map; central station sequences
  are cross-checked against public route tables, with local/rapid patterns and
  cropped endpoints explicit. Sources, exclusions and projected/continuation labels are documented in
  [docs/guide.md](./docs/guide.md) and generated JSON metadata.
- Minimalist map: off-white matte noon, cool dawn, peach sunset, blue hour and
  a very dark blue night gradient. World-anchored subtle procedural grain is
  filtered at overview zoom; no glass reflections. No station shadows.
  Track/car shadows follow a shared left-to-right solar arc, lengthen/change
  direction at dawn/dusk and vanish at midnight. Whole-corridor shadows render beneath all tracks;
  only train shadows may land on rails. Corridor outlines are cached at refresh.
  No scenery or visible grid; the 48-pixel
  construction grid remains active.
  Earlier procedural-city iterations were deliberately removed, not unfinished.
- Metro branding uses an orange/teal/purple transit M with station rings,
  redrawn as self-contained SVG paths from the supplied image. Source mark and
  wordmark: [assets/branding](./assets/branding). The in-game title uses both;
  native/Web boot uses the stacked logo on cream paper. Native app icons,
  favicon and Apple touch icon use the matching rounded paper tile.
  [build_branding.gd](./scripts/tools/build_branding.gd) regenerates combined
  logo/icon SVGs and repository 1024px icon/600x520 splash PNGs without external
  graphics dependencies. Project settings and export presets wire all targets;
  Web styles extend the standard Godot shell, not a copied custom shell.
- Elastic station-to-station drawing from one neutral + handle; no Draw/Move
  mode buttons. Center drag moves a station. Each free section has at most one
  bend using cardinal/45-degree segments, independent of pointer history.
  Drag directly or click to pin sections; releasing on empty space pins a section
  and continues by clicks. Tab or the source's two-arrow handle flips posture;
  Backspace undoes the last pinned section. Rail diamonds reshape bends or add
  a detour to a straight rail. Red previews identify invalid routes before commit.
  Reshaping is local: a section preserves its two neighboring anchors and all
  distant bends; a bend preserves its neighbors. Fixed anchors remain editable
  even when collinear, and appear as small circles during dragging. Rail popups
  sit perpendicular to the section and retain priority over station hover halos.
  Once a station is hovered, its visible controls and center-to-handle corridors
  take priority over rail insertion, even above an existing rightward rail.
  Direct rail access outside those corridors still exposes insertion/reshape.
  Live wrapped feedback follows the dragged point and explains grid snapping or
  rejected geometry; unchanged releases do not restart trains.
- Connect the endpoints of a line with at least three stations to close a loop.
  Both directions run continuously around it; deleting a station reconnects
  the loop until fewer than three stations remain. Deleting a rail opens it.
- No Station tool/mode: clicking empty space places a station; clicking rails
  or their + inserts one. A translucent ghost previews the exact grid-snapped
  empty-space position, hidden over existing objects/UI or during gestures.
  Insertion updates every shared line, including reversed station order.
- Deletion requires confirmation in a borderless paper card with consistent
  rectangular body/buttons and action-specific text. Removing a station joins
  its neighbors per serving line, preserving oriented paths and anchors.
  Existing neighbor rails are reused; a two-station loop becomes open.
  Track deletion via the hovered rail's x (also visible beside bends) splits
  lines into selectable fragments, retaining settings and color.
- Two running lanes, simultaneous independent directions, locomotive plus
  1-6 wagons. Cars follow curves. Moving authority preserves full-train gaps on
  each independent circuit; multiple trains can share an interstation section.
  No station-slot locks, geometric cross-line collisions or junction FIFO.
  Open-line terminal crossover protection is the deliberate exception:
  each terminal shared track accepts one train at a time, independently per line.
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
  World panning is unbounded; wheel/pinch share 0.08-6x zoom for larger networks.
  Real-world layouts are built manually, without geographic import.
- Watch mode: H or Menu > Hide interface hides HUD and editing overlays;
  a faint bottom-center grip (36 x 3px) with a 96 x 44px touch target restores
  them, alongside H/Escape. No text or filled button; grip contrast adapts to
  day/night. It preserves pause and running trains/audio.
  Camera pan/zoom and train following work; placement/move/delete are disabled.
  Entering cancels in-progress edits safely. No setting is persisted.
- Lines are opaque color bands with darker running lanes by day and bounded
  colored rail glow/bright cores at night. Shared physical corridors are spaced
  48 pixels center-to-center (28-pixel bands), leaving a visible gap. Trains and
  rendering use the same separated geometry. Shared-station junction illumination
  fades away around the marker so crossings do not form a luminous cross.
  Lanes are at +/-8 pixels (16 apart); car width is 7. A tighter +/-7 attempt
  blocked shared curved routes and was rejected by simulation tests.
- Stations have a 10-pixel white center for zero/one line, growing by 1 pixel
  of radius per additional serving line. Each serving line contributes one
  2-pixel ring in its color darkened by 30%, matching running lanes. Older lines
  (array order) sit outside newer lines; repeated loop endpoints count once.
  Interchanges grow to radius 10 + max(0, line count - 1) + 2 x max(1, line count):
  12/15/18 pixels for one/two/three lines, preserving ring widths.
  No station glow or station shadows.
  Unconnected/ghost stations keep neutral
  borders; night softens fills and lightens only neutral borders.
  Radius-aware picking, handles, selection/hover and route-target rings keep
  interaction geometry outside the marker. Membership/recolor updates are live.
  Markers are opaque above trains again; the rejected transparency experiment
  exposed the rails and looked unfinished. No artificial car visibility guards.
- Map-first HUD: paper/ink toolbar and a flat, full-width 60px bottom rail,
  no floating capsule/shadow. Numbered line tabs use colored underlines, neutral
  selected backgrounds and readable text independent of the route color.
  Both + and collapse actions use shrink flags, never expand flags; otherwise
  they steal tab width and cause false overflow. Tabs scroll only as needed.
  Add-line is styled like the underlined tabs and placed immediately after the
  last tab inside their scrolling row; only collapse stays fixed at the far right.
  Line controls expand inside the same rail above the tabs, height based on
  content (max 300px), with 1/2/3/5 columns at <620/620/760/1366px. Same-tab
  click folds controls; switching lines keeps them open. Redundant Line settings
  button removed. Menu/help/layouts use mutually exclusive centered sheets.
  Settings use a direct content-sized stack, without scrolling. Help may scroll
  on narrow displays. Top-left launch branding is a 248x60px vector mark/wordmark
  row, stays opaque for 10s, fades smoothly until 30s,
  then never returns during that launch. Its timer runs independently of pause,
  watch mode and HUD idle opacity; resizing/waking never restores it.
  Collapse/restore use icon-only 44px buttons: outlined bottom panel with a
  down/up arrow and translated tooltips at the identical bottom-right position.
  Vertical shrink-end and upward panel growth keep that target fixed even with
  overflowing tabs. Watch restoration keeps its centered faint grip.
  Controls fade to 28% opacity by day, 70% in dark night, over 0.6s after eight
  idle seconds; the threshold follows day/night continuously. Movement,
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
  Line details have a fixed labelled Collapse header above scrolling controls,
  a wide swatch beside Line color, and confirmed Delete line. Deletion removes
  exclusive tracks/stations, preserves shared and unrelated infrastructure,
  reindexes surviving IDs and rebuilds service; the last deletion leaves an
  empty editable line. Pause/camera persist and stale following/visits clear.
- Original 48-second PCM music uses a consonant repeating eight-bar progression,
  a swung 80 BPM kick/snare groove, sparse melody and muted hats. Music starts
  at 0.4 volume; train effects have a separate volume.
- Trains are top-down metro trainsets with matching cab ends, pale neutral roofs,
  line-colored body edges and articulated accordion gangways. Doors/windows,
  ventilation and folds fade in at zoom 1.5-3; fine seams/grilles at 3-4.5.
  Running gear is hidden; no decorative wheels or fixed offset drop shadows.
  Restrained solar shadows follow the day/night cycle.
  All cars/cabs gained another 10%: length 19.8px, pitch 20.8px, width 7px.
  `CAR_SCALE` shares longitudinal proportions and preserves the one-pixel gap.
  Body rendering,
  doors, gangways, platforms and full-train safety/capacity share the proportions.
  Very dark blue night (#03060c) uses bright rail cores and bounded colored
  halos, plus distinct local headlamp glow and stronger fading beams.
  Rail illumination is excluded within shared-marker radius + 24px and fades
  back over 16px; geometry and per-vertex strengths are cached on network refresh.
  Wide glow layers use cached Polygon2D rounded offset outlines, resolving
  inward folds without changing width. Loop holes are split/subtracted rather
  than filled. Vertex colors preserve junction fades; recolor refreshes without
  redispatch. Replaces the rejected Line2D curvature-width workaround.
- Close-up stops reveal one continuous transient platform per train and tiny passengers.
  The connected ribbon is guided by car centers and the two end caps, with
  paired 2px samples, local averaging and four corner-cutting passes. It follows
  tighter bends without per-car endpoint steps; safety edging and paving
  are placed along the smoothed edges. One polygon union resolves any folds.
  platforms never reshape routes or require the entire train to be straight.
  Alighting precedes boarding; people stay on the platform and fade there.
  Platforms fade out 1.2s after departure/withdrawal. Visible only above zoom 1.5,
  fading fully in by 3; boarding simulation is identical at every zoom.
  Platforms have concrete pavement, fine joints, a defined perimeter and a
  continuous warm tactile safety strip; detail stays inside their merged outline.
  People are smaller (body radius 0.34, formerly 0.48), with varied coats/skin,
  scattered queues and individual start/speed variation. Cached short walking
  segments stay inside the platform inset by body radius + 0.2px (miter inset
  preserves containment around concave corners); smoothstep
  motion is capped at 4 world units/s. Alighters have extra visual walking time
  after exiting; boarders approach earlier, shortening only when time is limited.
  Visual timing is independent of occupancy and never extends train dwell.
  Alighters stop walking at the end of their trip and fade in place.
  Each car has two doors and twelve abstract places. Local deterministic exchanges
  carry riders between stops, empty trains at termini, and add at most two
  seconds beyond the chosen minimum dwell at arrival. Recovery remains separate.
  Cycle/headway/capacity estimates include the two-second boarding allowance.
  Fuller flows use at least two boarders per door when capacity permits.
  Local seeded profiles are generated once per visit; rendering does not use
  global randomness. Actual occupancy follows individual completed journeys.
  Pause freezes activity, geometry rebuilds clear it; no demand objectives.

## Architecture and invariants

- [main.gd](./scripts/main.gd): input, contextual gestures, UI, language/settings,
  graph-edit integration. Release over GUI cancels a gesture; Escape/right-click
  restores a movement's original station position and incident paths. Mouse input
  uses event coordinates transformed through the world canvas, not OS cursor reads.
  Frame-to-frame hover uses the stored viewport pointer position from the last
  mouse event, transformed by the current canvas; it never polls OS coordinates.
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
- [layout_store.gd](./scripts/layout_store.gd): typed capture/restore and named
  version-1 JSON files. SHA-256 filenames keep user names out of paths; complete
  temporary writes are renamed over the destination. Types, finite coordinates,
  grid/waypoints, unique physical pairs, line references/settings and camera
  validate before constructing replacement state. Store failures are logged
  and exposed via `error_message`; main supplies localized feedback. Player
  names in the saved-layout OptionButton must never be auto-translated.
  `_open_layouts` / `_request_layout_action` / `_request_clear_map` /
  `_confirm_layout_operation` / `_replace_layout` in
  [main.gd](./scripts/main.gd) handle sheets, accessible keyboard focus,
  confirmations and complete dispatch/selection/follow reset on replacement.
  `load_starter_layout` reads [metro_demo.json](./layouts/metro_demo.json)
  through the same JSON validator; all export presets explicitly include
  `layouts/*.json`. Load uses per-item resource-path String metadata for bundled originals,
  never translated text matching; included labels translate live. Main's
  `startup_layout_enabled` defaults true; tests constructing an empty fixture
  set it false before adding the scene. Bundled `_replace_layout(..., true)`
  fits station extents with HUD margins without changing the stored resource.
  Optional `station_names` and `lines[].name` preserve factual names in
  version-1 saves without breaking older unnamed snapshots. Named station
  hover captions, service settings and compact-tab tooltips use untranslated
  factual text; fragments retain their service name.
- [transit_line.gd](./scripts/sim/transit_line.gd): ordered station and track IDs.
  Physical tracks are shared; waypoint orientation is canonical track a-to-b.
  Lines extend only at endpoints. A loop repeats its first station at the end;
  it cannot be extended, but its tracks can be redrawn. Empty fragments remain reusable.
- Geometry edits validate all affected paths; invalid movement rolls back the
  full change. Moving a station reshapes its adjacent elbow from the gesture's
  original path, keeping distant bends fixed. Off-station crossings between
  independent physical tracks are allowed globally without creating transfers
  or shared signaling; each individual stroke still rejects self-intersection
  and backtracking. A whole service may cross itself across different tracks.
- [track_geometry.gd](./scripts/render/track_geometry.gd): canonical grid guides,
  elastic_path, preview rounding, shared-corridor offsets and route circuits.
  Original tight quadratic bends restored everywhere: 12px at stations,
  24px elsewhere, capped at 35% of adjacent lengths. User rejected broad
  station curves and chose original bends over exact grid-marker centering.
  Station markers stay on the grid; curves cut slightly inside the corner.
  Rounding precedes lane offsets and uses adaptive de Casteljau subdivision (0.01 world-unit flatness,
  1-degree tangent/chord tolerance, depth 12) for smooth close-up corners.
  No forced straight berths, removed elbows, expanded terminal paths or special
  effective picking paths. Preserve sharper user-drawn bends and normal caps.
  `anchors` retains explicit collinear waypoints; `simplify` accepts protected
  points for local edits. Rendering still simplifies before corner rounding,
  so keeping an editing anchor does not alter the running path.
- Circuit data includes `points` (closed simulation path), `centerline`,
  `running_paths` (two open visible lanes), `stops`, `outbound_end`, and `length`.
  A loop has closed visible lanes and a separate `reverse_route`; select the
  route by train direction for simulation and rendering.
  Every leading cab stops on the approach side outside its station marker
  at radius + half-car + 3px, in both open-line and loop directions.
  Intermediate/loop projections walk back to that clearance-circle boundary;
  moving trains still pass underneath markers, without changed running paths.
  `terminal_insets` stores each end independently, including larger interchanges.
  Open terminals share a center track with a
  visible two-lane convergence, and reverse cabs at departure, not by U-turn.
  `terminal_ready`, `terminal_entries` and `terminal_exits` describe fit/protection.
  Shared zone length is wagon span + largest terminal inset + half-car;
  the crossover adds up to 64px,
  bounded before the adjacent station and before the two terminal zones overlap.
  No terminal path extends beyond the station cap. Too-short lines disable
  dispatch with explicit localized guidance; wagon increases validate terminal fit.
- [dispatcher.gd](./scripts/dispatch/dispatcher.gd): 60 Hz substeps; moving
  authority uses forward circuit distance minus leader length and safety gap.
  Braking envelope includes 0.25s reaction against a conservatively stationary
  obstacle; separate acceleration/braking defaults are 80/100 units/s squared.
  Known station stops instead use a single-substep braking margin to avoid a
  creeping approach tail. Arrival snap requires pre-step speed within one
  braking step; subpixel displacement does not reset speed.
  Open lines share an outbound/inbound distance circuit with retraced terminal
  center tracks; loop directions
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
  `_terminal_owners` protects each line's two terminal crossovers independently.
  Acquire before braking into a junction, hold through recovery/reversal until
  the tail clears with margin, release on withdrawal/rebuild. Other lines and
  loops never share these locks. `reverse_pending` advances the logical head
  by wagon span + twice that terminal's inset while stopped, after validating
  forward authority (`TrackGeometry.reversal_distance`): the
  old last car becomes head without moving any physical car. Cycle estimates
  subtract that logical jump. `car_axis` handles exact reversal cusps.
  A short line that cannot clear one terminal before reaching the opposite
  entry is capped at one train to prevent bidirectional terminal deadlock.
  See [DESIGN.md](./DESIGN.md) for formulas and intentional game simplifications.
- [station_visit.gd](./scripts/sim/station_visit.gd): stop exchange and immutable
  door/car geometry snapshot. Individual alight/board completions update train
  occupancy; cached visual walk timing is independent. Dispatcher-owned visits survive a train's
  departure/retirement for fade-out, expire promptly and clear on rebuild.
  Local flow does not use global train IDs, preserving cross-line independence.
  A smoothed car-center ribbon resolves into one exterior polygon at arrival,
  not per frame. Inner/safety edges and pavement details follow that same curve.
  [world_view.gd](./scripts/render/world_view.gd) consumes visits only for drawing;
  offscreen platform/person work is culled. [main.gd](./scripts/main.gd) passes
  visits alongside trains, without a separate wall-clock animation timer.
- [world_view.gd](./scripts/render/world_view.gd): draw rail bands from centerline
  and open running paths, not the closed simulation circuit. A rounded band cap
  finishes each open terminus behind its station; loops have no caps. Open
  termini use visible convergence and in-place cab reversal, not physical turns.
  All cars, gangways and lights remain drawn during terminal movement; there
  are no visibility-range guards in rendering or train picking.
  Close-up train and rail outlines omit Godot's world-unit AA fringe at zoom
  1.5 or greater to avoid blurred contours. Headlights render before the cars;
  station markers render opaque above overlapping trains; no fading opacity pass.
  Night glow is local layered geometry, compatible with native/Web Compatibility
  rendering, not an HDR/environment dependency. Compressed gangways use two
  triangles so a folded connector cannot fail polygon triangulation.
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
- [pages.yml](./.github/workflows/pages.yml): imports, tests simulation/audio/UI/localization/layouts,
  exports Web and uploads the Pages artifact on main pushes/PRs; only main
  pushes/manual runs deploy. Single-thread Web needs no COOP/COEP headers.
  [docs/](./docs/) contains README screenshots, ignored by Godot and excluded
  from every export preset.
- [releases.yml](./.github/workflows/releases.yml): manual versioned releases,
  separate from Pages. Validates MAJOR.MINOR.PATCH (optional v), rejects existing
  tags, tests once, then builds six targets using matching Godot/templates via
  [setup-godot](./.github/actions/setup-godot/action.yml). Only the publication
  job has contents-write permission. Publishes all six assets and SHA256SUMS
  via a draft, then makes it public after upload. No signing secrets used;
  iOS requires the documented placeholder team ID for project-only export.
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
bash tests/run_smoke.sh smoke
bash tests/run_smoke.sh extended
godot --path . --script res://tests/urban_smoke.gd --audio-driver Dummy
godot --path . --script res://tests/interface_smoke.gd --audio-driver Dummy
godot --path . --script res://tests/visual_smoke.gd --audio-driver Dummy
godot --path . --script res://tests/train_visual_smoke.gd --audio-driver Dummy
godot --headless --path . --export-release "Windows Desktop" dist/Metro.exe
godot --headless --path . --export-release "macOS" dist/Metro-macOS.zip
godot --headless --path . --export-release "Web" dist/web/index.html
```

- Inspect output for parser/script errors even when the editor exits zero.
- [run_smoke.sh](./tests/run_smoke.sh) is the shared CI/local entry point.
  Default `smoke` runs 14 headless scripts; Pages/PRs use it. `extended` runs
  all 15 headless scripts and all long service checks before release builds.
  Set `GODOT_BIN` when Godot is not on PATH. The runner reports per-script
  timings, rejects unknown modes and stops with the failed child's exit code.
  Individual scripts without flags retain full service coverage. Fast
  schedule mode omits the two 360s live-service tests and the two 1200s
  headway comparisons; fast preset mode uses 30s rather than Montreal's
  600s full-fleet soak. Fast terminal mode keeps all 18 wagon/orientation
  fixtures and assertions, stopping at their existing reversal/arrival
  thresholds instead of running the full 120s each. Graphical checks remain
  separate and require a display. See [guide](./docs/guide.md#vérifier).
- Dispatcher calls always subdivide at 1/60s; increasing the test's outer
  timestep does not eliminate simulation work. Keep sustained headway,
  deadlock and full-fleet regressions in extended coverage rather than
  arbitrarily shortening them.
- Intersection tests run six simulated minutes per scenario and can take several
  real minutes. A selector after `--` filters labels, for example `-- Screenshot`.
  Unmatched selectors fail instead of reporting success without exercising
  anything. Preset selectors are `jr-east`/`montreal`; `--fast` and
  `render-only` alone run both presets, and cannot be combined.
- Intersection checks cover full-train moving gaps, both directions, continued
  arrivals in the second half, shared terminals, nearby junctions, three lines,
  busy single-line termini and a layout reproducing the reported screenshot.
- Schedule tests compare a shared-station line against running alone, verify
  multi-train sections, route capacity/recommendations, independent motion rates,
  terminal recovery, stopped-leader braking and live timing/fleet changes.
  Seeded irregular loop departures compare regulated/unregulated headway
  standard deviation, requiring at least 25% improvement. Geometric collision
  assertions between different lines/directions intentionally no longer apply.
- Native graphical tests need a display. They verify actual pixels: matte noon,
  cool dawn/warm sunset, bounded texture and dark night gradient, solar shadows,
  dark lanes, opaque colors, white station centers, darkened concentric line
  rings, rounded terminal bands, recoloring and hover anchors. The visual test
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

### Non-Gradle Android SDK override correction (2026-11-07)

- Reported run 42447153570 reached export but Godot rejected the explicit
  target SDK override with Gradle disabled. Removed `gradle_build/target_sdk`
  from [export_presets.cfg](./export_presets.cfg), retaining the intended
  prebuilt unsigned APK export. The template now supplies its SDK versions.
  Added [branding_smoke.gd](./tests/branding_smoke.gd) regression checks:
  Gradle remains disabled and both minimum/target SDK overrides are empty.
  Updated [guide](./docs/guide.md#exporter). SDK installation workflow unchanged.
- Passed using `/Applications/Godot.app/Contents/MacOS/Godot`:
  `--headless --editor --path . --quit`,
  `--headless --path . --script res://tests/branding_smoke.gd`,
  `--headless --path . --export-release "Windows Desktop" dist/Metro.exe`,
  `--headless --path . --export-release "macOS" dist/Metro-macOS.zip`.
  Verified fresh modification times, Windows MZ header, Mac ZIP integrity,
  app executable and PCK; no script/parser errors. `git diff --check` passed.
- Attempted `--headless --path . --export-release "Android"
  dist/Metro-android-unsigned.apk`: exit 1 because local Java/Android SDK
  paths, platform-tools and build-tools are missing. The reported target
  SDK override error no longer appears. Actual Android export still needs
  a new Actions run from the fixed revision. Other smoke tests not rerun;
  no commit or push.

### Android SDK package setup correction (2026-11-07)

- The current clean checkout still used `setup-android@v3` without a packages
  override; the earlier local fix was absent. Reapplied it in
  [releases.yml](./.github/workflows/releases.yml): explicitly install
  `platform-tools build-tools;35.0.1 platforms;android-35`, excluding the
  unavailable legacy `tools` package that caused reported run 42443264042
  to fail. Removed the redundant subsequent sdkmanager installation.
  Updated [guide](./docs/guide.md#releases-github); other targets unchanged.
- Passed Ruby YAML parsing, exact SDK package-list assertions, `bash -n`
  for every release-build shell step and `git diff --check`.
  Fresh builds passed using `/Applications/Godot.app/Contents/MacOS/Godot`:
  `--headless --editor --path . --quit`,
  `--headless --path . --export-release "Windows Desktop" dist/Metro.exe`,
  `--headless --path . --export-release "macOS" dist/Metro-macOS.zip`.
  Verified new modification times, Windows MZ header, Mac ZIP integrity,
  app executable and PCK; no script/parser errors.
- No game-code changes; smoke tests/actionlint not rerun. Actual Android
  SDK installation/export and corrected GitHub Actions run remain unverified.
  Fix committed with the related guide and this memory update; no push.
  Repeated the exact import and Windows/macOS export commands above before
  committing; both fresh outputs passed the same integrity checks, without
  script/parser errors. Push and start a new workflow run from the fixed
  revision, rather than rerunning the old failed revision.

### Smoke-suite review and runtime refactoring (2026-11-07)

- Reviewed all 17 smoke scripts and measured all 15 headless scripts before
  editing. Main bottlenecks: presets 233.398s, schedule 101.422s,
  intersections 96.934s, terminal 25.229s and layout 23.572s.
  User approved fast PRs/Pages and full extended checks for releases.
  [pages.yml](./.github/workflows/pages.yml) and
  [releases.yml](./.github/workflows/releases.yml) now share
  [run_smoke.sh](./tests/run_smoke.sh), adding editing, loops, train controls
  and urban coverage to CI, plus intersections before releases.
- Removed the unrelated 600s regulation warmup by spawning its direct fixture.
  Platform geometry checks reuse each closed boundary, avoid successful
  diagnostic formatting and skip the identical second open-route circuit.
  Loop directions and every wagon/stop/passenger sample remain covered.
  Layout fitting loads/builds each preset once for the four viewport checks.
  Preset menu loading uses 2s rather than another redundant 30s simulation
  and explicitly checks that service starts. Train controls wait for actual
  fleet counts with the original maximum deadlines. Urban math checks no
  longer await render frames headlessly; graphical synchronization is intact.
  Production simulation code is unchanged.
- Measured, passed with
  `GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot bash tests/run_smoke.sh smoke`:
  14 scripts in 75.870s. The previous ten-script CI selection took 396.516s:
  80.9% faster despite broader quick coverage. Passed the same command with
  `extended`: 15 scripts in 473.917s versus the 515.280s full baseline,
  an 8.0% reduction without shortening the sustained release regressions.
  Headway standard deviation remained regulated 0.181s vs unregulated
  6.864s; the 25% improvement assertion passed. Timings are local observations,
  not cross-machine performance guarantees. Expected layout/transfer
  rejection errors occurred; neither suite had script/parser errors.
- Passed using the same Godot executable:
  `--path . --script res://tests/<test>_smoke.gd --audio-driver Dummy` for
  urban (2.367s), interface (6.017s), visual (3.211s) and train_visual (2.193s).
  All four actual graphical/pixel checks passed. Named PNG captures cleaned.
  Runner manifests/default mode, missing executable, invalid modes and
  child-failure propagation were verified. Actual schedule/preset/terminal
  invalid arguments and unmatched intersection selectors exited 1;
  preset `-- render-only` ran both presets successfully. The initial runner
  harness used nonexistent `/usr/bin/echo`; corrected to `/bin/echo` and
  reran successfully.
- Passed: `bash -n tests/run_smoke.sh`, Ruby YAML parsing,
  `actionlint .github/workflows/pages.yml .github/workflows/releases.yml`,
  project import and `git diff --check`. actionlint was missing; installed
  1.7.12 temporarily for validation, then cleaned.
  Fresh exports passed with `/Applications/Godot.app/Contents/MacOS/Godot`:
  `--headless --editor --path . --quit`,
  `--headless --path . --export-release "Windows Desktop" dist/Metro.exe`,
  `--headless --path . --export-release "macOS" dist/Metro-macOS.zip`.
  Verified refreshed modification times, Windows PE x86-64 and Mac archive
  integrity, app executable and PCK. No export script/parser errors.
  No Actions run, platform installation/runtime or Gatekeeper checks.
  Release and smoke-suite changes included in the subsequent commit below.

### Committing releases and smoke refactoring (2026-11-07)

- Committed the six-platform release workflow, export presets, shared fast/
  extended test runner, smoke refactoring and related documentation together.
  No push. Prior full-suite, graphical and workflow validation above remains
  applicable; tests were not rerun for this commit-only task.
- Fresh pre-commit builds passed using
  `/Applications/Godot.app/Contents/MacOS/Godot`:
  `--headless --editor --path . --quit`,
  `--headless --path . --export-release "Windows Desktop" dist/Metro.exe`,
  `--headless --path . --export-release "macOS" dist/Metro-macOS.zip`.
  Verified fresh modification times, Windows PE x86-64 and Mac ZIP integrity,
  executable and PCK; no script/parser errors. `git diff --check` passed.
  Actions, Android SDK export, platform installation and Gatekeeper checks
  remain unverified as detailed above.

### Manual six-platform GitHub releases (2026-11-07)

- Added [releases.yml](./.github/workflows/releases.yml) and a Linux/macOS
  Godot setup composite action. Manual version input creates a new v-prefixed
  tag at the selected commit; existing tags and invalid versions are rejected.
  All smoke tests and matrix builds must pass before publication. Assets:
  Windows ZIP, universal macOS ZIP, Linux executable tar.gz, Web ZIP, unsigned
  Android APK and unsigned iOS Xcode project ZIP, plus SHA256SUMS.txt.
  Android uses Java 17 and SDK 35/build-tools 35.0.1 without a Gradle build.
  iOS uses project-only export with explicit placeholder team 0000000000.
  Pages deployment remains unchanged. Usage and signing limits are in
  [docs/guide.md](./docs/guide.md#releases-github).
- Added Linux/Android/iOS presets with the existing bundled-layout and
  development-resource exclusion rules. Extended
  [branding_smoke.gd](./tests/branding_smoke.gd) to check all six presets,
  Linux embedded data, Android icon/unsigned APK and iOS project-only mode.
- Passed: `actionlint .github/workflows/pages.yml .github/workflows/releases.yml`,
  Ruby YAML parsing, `bash -n` on every workflow/composite shell step, and
  execution of the actual version-validation step with valid/malformed inputs.
  actionlint was initially absent and installed in isolated task storage;
  Python YAML parsing lacked PyYAML, so validation used existing Ruby YAML.
- Passed using `/Applications/Godot.app/Contents/MacOS/Godot`:
  `--headless --editor --path . --quit`;
  `--headless --path . --script res://tests/<test>_smoke.gd` for simulation,
  schedule, terminal, audio, interface, branding, localization, layout,
  transfer and preset. Branding rerun after adding the preset assertions.
  Negative layout/transfer errors were intentional; all ten scripts passed.
- Fresh exports passed with the same executable:
  `--headless --path . --export-release "Windows Desktop" dist/Metro.exe`,
  `--headless --path . --export-release "macOS" dist/Metro-macOS.zip`,
  `--headless --path . --export-release "Linux" dist/Metro.x86_64`,
  `--headless --path . --export-release "Web" dist/web/index.html`,
  `--headless --path . --export-release "iOS" dist/ios/Metro.zip`.
  Verified Windows PE x86-64, Linux ELF x86-64, Mac ZIP integrity, nonempty
  Web runtime files and iOS project.pbxproj/PCK. Executed the exact workflow
  export/packaging shell step for those five targets with a temporary 0.0.0
  asset label; archive integrity checks passed.
- Local Android export failed because Java SDK settings and Android
  platform-tools/build-tools are absent. The workflow provisions these
  explicitly, but its Android job still needs a real Actions run.
  Godot also prints missing local Android build-tools on editor imports;
  iOS export succeeded with an engine warning about boot_splash/fullsize.
  No GitHub workflow/publication, signed mobile installation, platform runtime
  or Gatekeeper checks performed. No commit or push. Temporary packaging
  assets/reference downloads cleaned. Local documentation links and
  `git diff --check` passed.

### Mobile two-finger navigation (2026-11-07)

- Added raw screen-touch tracking in [main.gd](./scripts/main.gd): two fingers
  on the map pan by their midpoint movement and zoom by their distance change,
  with zoom anchored beneath the gesture. Touches over interface controls
  remain available to those controls. Starting a two-finger gesture cancels
  pending edits and stops train following; single-finger map gestures defer
  their action until movement or release to avoid placing a station when the
  second finger starts a navigation gesture.
- Extended [interface_smoke.gd](./tests/interface_smoke.gd) to cover touch pan,
  pinch zoom, gesture cleanup and single-tap station placement. Updated
  [docs/guide.md](./docs/guide.md) to explicitly include touch pinch zoom.
- Validation passed: `/Applications/Godot.app/Contents/MacOS/Godot --headless
  --path . --script res://tests/interface_smoke.gd`; editor import; fresh
  Windows and macOS release exports. `file dist/Metro.exe` identified a PE32+
  x86-64 executable and `unzip -t dist/Metro-macOS.zip` passed. No live mobile
  browser/device test was run.

### README tone refinement (2026-11-07)

- Adjusted [README.md](./README.md) to keep its concise, welcoming introduction
  while replacing overly familiar wording with a more composed and neutral tone.
  The page remains focused on the game experience and links to the detailed
  guide; no implementation detail was added.
- Fresh Windows and macOS release exports completed with Godot 4.7.2.
  `file dist/Metro.exe` identified a PE32+ x86-64 executable, and
  `unzip -t dist/Metro-macOS.zip` found no archive errors. The local README and
  guide link check and `git --no-pager diff --check` passed. Smoke tests were
  not run for this documentation-only change.

### Simplified README and moved full guide (2026-11-07)

- Replaced the implementation-heavy French home page with a short, welcoming
  introduction, a direct browser-play link, current screenshots, and pointers
  to the complete guide and design notes.
- Preserved the former README content in [docs/guide.md](./docs/guide.md);
  adjusted its relative links and image paths for the new location.
- Validation passed: `/Applications/Godot.app/Contents/MacOS/Godot --headless
  --editor --path . --quit`; `/Applications/Godot.app/Contents/MacOS/Godot
  --headless --path . --export-release "Windows Desktop" dist/Metro.exe`;
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --path .
  --export-release "macOS" dist/Metro-macOS.zip`. `file dist/Metro.exe`
  identified a PE32+ x86-64 executable, and `unzip -t dist/Metro-macOS.zip`
  found no archive errors. A local README/guide link check and
  `git --no-pager diff --check` also passed. Smoke tests were not run for this
  documentation-only change.

### README refresh, current screenshots and commit preparation (2026-11-07)

- Reviewed [docs/guide.md](./docs/guide.md) against the current presets, camera actions,
  sharing/menu controls, branding and [Pages workflow](./.github/workflows/pages.yml).
  Added logo preview, current zoom/fit/delete-line/save/share command rows,
  corrected the fitted navigation floor and geographical-import wording,
  removed stale benchmark/first-deployment claims and listed current CI tests.
  Moved logo regeneration details into Development and separated Interface
  from sharing/storage guidance.
- Replaced day/night screenshots with actual fitted Montreal; added JR and
  native sharing-menu captures in [docs/images](./docs/images). All four are
  1180x740 and visually inspected. Capture shows current logo, four/ten-line
  docks, zoom/fit controls, compact geometry and Save/Load/Clear/Export/Import.
  [capture_readme.gd](./scripts/tools/capture_readme.gd) reproducibly loads the
  bundled networks, advances service 60s, uses noon/midnight and captures actual
  rendering without modifying presets or local saves. Excluded from exports
  with other tools; command documented in README.
- Native capture initially succeeded, but a rerun stalled awaiting
  frame_post_draw; stopped its specific process. A foreground retry also
  stalled, with a deprecated move_to_foreground warning. Final capture uses
  grab_focus and explicit RenderingServer.force_draw(false), plus synchronized
  camera/background framing; all four completed cleanly, removing an initial
  stale-background edge in the JR capture.
- Successful executable `/Applications/Godot.app/Contents/MacOS/Godot`:
  `--path . --script res://scripts/tools/capture_readme.gd --audio-driver Dummy`,
  `--headless --editor --path . --quit`;
  `--headless --path . --script res://tests/<test>.gd` for
  simulation_smoke, schedule_smoke, terminal_smoke, audio_smoke, interface_smoke,
  branding_smoke, localization_smoke, layout_smoke, transfer_smoke, preset_smoke,
  editing_smoke, loop_smoke, train_controls_smoke;
  `--path . --script res://tests/visual_smoke.gd --audio-driver Dummy`.
  All passed; logs checked for script/parse/assertion errors. Layout/transfer
  negative-validation messages intentional. Full preset test verified 20 JR
  trains after 30 simulated seconds and sustainable Montreal 6/6/2/6 fleets
  after 600 simulated seconds. Fifty adversarial rejections took 5.0ms in this
  run; timings are observations, not performance guarantees.
- Fresh Windows/macOS/Web exports succeeded with the three export commands
  in Validation and delivery. Verified Windows PE x86_64, Mac ZIP integrity,
  universal x86_64/arm64 executable, strict deep codesign and packaged startup
  `--headless --quit-after 10 --audio-driver Dummy`; all seven Web runtime/icon/
  splash outputs nonempty. Export logs clean. Windows/Intel Mac interactive
  runtime and Gatekeeper/notarization not run; browser not rerun in this
  documentation task (prior branding browser checks remain recorded below).
- README local links and exact PNG dimensions checked; `git --no-pager diff
  --check` passed. Delivery scope: one local commit of the accumulated layout/
  preset/interface/sharing/branding changes and this README refresh, as requested.
  No push/deployment requested. Task-native processes stopped/completed;
  extracted app, test screenshots and logs cleaned.

### Shared vector logo and complete platform branding (2026-11-07)

- Redrew the supplied three-color transit M and Metro lettering as SVG paths,
  retaining station rings and rounded routes, without tracing raster texture,
  embedding the image or requiring fonts. Source mark/wordmark and generated
  complete logo/icon are in [assets/branding](./assets/branding). Reference
  image remains untouched in dist and is not shipped.
- [build_branding.gd](./scripts/tools/build_branding.gd) generates combined
  SVGs, 1024px PNG app icon and 600x520 stacked boot logo using Godot's own SVG
  rasterizer. PNG derivatives stay with source for ordinary/Pages exports.
  [main.gd](./scripts/main.gd) uses two input-transparent TextureRects in a
  248x60 HBoxContainer; unchanged 10/20/30-second opacity 1/0.5/0, independent
  of HUD fade, pause and narrow-screen hiding. No new startup delay.
- [project.godot](./project.godot) replaces the engine icon and boot splash.
  [export_presets.cfg](./export_presets.cfg) sets Windows/macOS icon overrides
  and adds cream paper, purple text, teal progress, responsive splash and
  theme-color/description to the default Web shell. Exporter supplies matching
  favicon and 180px Apple touch icon. README/DESIGN explain sources/regeneration.
- Added [branding_smoke.gd](./tests/branding_smoke.gd) to Pages CI: self-contained
  vectors rasterize, platform settings/boot wiring, exact raster sizes, rounded
  transparency and all three colors at 16/32/64/180/256/512px. Updated interface
  assertions for actual vector textures and mouse filtering rather than a
  font-size proxy; existing fade/responsive/control behavior passed.
- Successful executable `/Applications/Godot.app/Contents/MacOS/Godot`:
  `--headless --path . --script res://scripts/tools/build_branding.gd` (including
  clean regeneration), `--headless --editor --path . --quit`,
  `--headless --path . --script res://tests/branding_smoke.gd`,
  `--headless --path . --script res://tests/interface_smoke.gd`,
  `--headless --path . --script res://tests/layout_smoke.gd`.
  Initial generator boot logged missing splash before creating it; subsequent
  import/regeneration clean. Changed test image reads to imported Texture2D
  images after raw Image.load_from_file warnings. Layout negative errors intentional.
- Fresh exports succeeded using all three export commands above. Windows PE
  x86_64 contains actual Metro PNG icon resources at 16/32/48/64/128/256px;
  extracted 256px icon visually verified. Mac archive integrity, universal
  x86_64/arm64 binary, strict deep codesign verification and packaged startup
  `--headless --quit-after 10 --audio-driver Dummy` passed; extracted ICNS
  pixels match source. Each actual Windows/Mac/Web pack loaded brand assets,
  verified title size/fade/phone hiding and preserved starter preset.
- Web browser verified cream stacked loading logo/progress, successful normal
  startup with Montreal and the vector in-game title; favicon/touch PNGs decode
  at 1024/180px. Exported full-size icon pixels match source; raw PNG bytes
  differ because of encoding, not artwork. Splash PNG matches exactly.
  A deliberately delayed WASM route captured loading but stalled across tool
  calls; removing interception and reloading launched normally.
- `git --no-pager diff --check` passed. No commit/deployment. Windows/Intel Mac
  interactive runtime, Gatekeeper/notarization and full service/performance
  suites not run for branding changes.
  Browser reset to blank and preview stopped; task verification helpers,
  extracted app/icons and logs cleaned.

### Portable layout sharing and hardened imports (2026-11-07)

- Menu Export/Import shares the current editable network as version-1 JSON.
  [layout_transfer.gd](./scripts/layout_transfer.gd) uses native file dialogs
  and browser download/file upload; [layout_store.gd](./scripts/layout_store.gd)
  supplies the shared full-precision codec and temporary-file/rename writer.
  [main.gd](./scripts/main.gd) confirms validated imports before replacing and
  fitting the map. Cancel/rejection preserves the live map; importing never
  overwrites local saves. Use Save explicitly to retain an imported copy.
- Security review reported no code-execution/path-injection vulnerabilities;
  its scope excluded denial-of-service/crash findings. Independently hardened
  that boundary: JSON only, no imported scripts/resources/HTML/destination
  paths; UTF-8 and lexical limits checked before JSON parsing, then schema,
  finite numbers, references, exact grid, unique positions, cardinal/diagonal
  geometry, per-track self-intersection/backtracking and train/station clearance.
  Independent-track crossings remain permitted.
- Limits: 16 MiB, depth 16, 32,768 JSON tokens, 4,096 raw bytes per string,
  128-byte numeric tokens; 256 stations, 512 tracks, 16 lines, 64 total requested
  trains; 32 waypoints per track/2,048 total, 512 anchors per line/4,096 service
  anchors, 2,048 total station calls; coordinates +/-48,000 and 200,000 units
  each for physical/service length. Recognized labels: 160 characters, no
  control characters. Same limits protect local saves/loads. These bound known
  application risks, not unknown engine/browser vulnerabilities.
- Added [transfer_smoke.gd](./tests/transfer_smoke.gd) to Pages CI; EN/FR sharing
  messages and README/DESIGN documentation. Reduced phone menu row spacing to
  keep all actions visible without shrinking 44px targets.
- Successful executable `/Applications/Godot.app/Contents/MacOS/Godot`:
  `--headless --editor --path . --quit`;
  `--headless --path . --script res://tests/transfer_smoke.gd`,
  and the same command for `layout_smoke.gd`, `editing_smoke.gd`,
  `interface_smoke.gd`, `localization_smoke.gd`;
  `--path . --script res://tests/preset_smoke.gd --audio-driver Dummy -- jr-east montreal render-only`.
  Covered all preset/menu/file round-trips, exact camera/settings, confirmation/
  cancel, invalid/missing/unwritable files, malicious data and exact thresholds.
  Fifty adversarial rejections took 3.1 ms in the final run (observation only).
  Negative-validation errors intentional; no final script/assertion errors.
  Fixed initial writer variable error, test active-line assumptions, default
  JSON precision loss and phone overflow. Control-name test uses a tab rather
  than relying on a GDScript NUL literal.
- Fresh Windows/macOS/Web exports succeeded with the three export commands
  above. Verified PE x86_64, ZIP integrity, universal Mac executable, strict
  deep codesign, packaged Mac startup with
  `--headless --quit-after 10 --audio-driver Dummy`, and nonempty Web assets.
  Each actual exported pack passed menu import, all preset round-trips,
  sharing controls and coordinate/depth rejection checks.
- Final Web browser: uploaded/confirmed Montreal and JR JSON, observed fitted
  maps and rejection of a valid-schema 1e30 coordinate without replacing
  Montreal; file chooser cancellation removed its temporary input. Captured
  exported JSON Blob (68 stations, then 80 stations/ten JR services) and actual
  download filename `Metro-layout.json`. Download-event wait timed out in the
  browser harness, so saving the download to disk is not verified; a later
  short-wait Blob probe ran before the frame, and the 1.5-second probe succeeded.
- `git --no-pager diff --check` passed. No commit/deployment. Windows/Intel Mac
  runtime, interactive native file dialogs, Gatekeeper/notarization and full
  service/performance suites were not run for sharing changes.
  Browser reset to blank, preview server stopped, task helpers/app/logs cleaned.

### Full-window layout fitting and camera controls (2026-11-07)

- Startup and every confirmed menu Load now fit the complete network, including
  user saves. Replaced saved-camera-centered, zoom-out-only fitting with bounds
  of stations, physical waypoints and offset running-route points, grown by 24
  world units. Fit fills exactly one usable window dimension (aspect ratio
  preserved, no cropping), with 32px side, 80px top and 112px bottom clearance
  for HUD/camera actions. Fits after rebuilding routes so separated corridors
  are included. Layout JSON retains saved camera for schema compatibility,
  but UI Load deliberately replaces framing. Clear remains origin/1x.
- Added 44px minus, plus and four-corner Fit controls above the bottom dock
  with EN/FR tooltips; remain available when dock collapsed and hide in Watch.
  Fit closes sheets, cancels gestures/following and resets camera smoothing
  without rebuilding service, modifying topology, restarting trains or pause.
  Camera zoom can exceed the preset's saved zoom or go below normal 0.08
  minimum for large phone layouts. Store the fitted navigation floor until
  next replacement/fit so zoom-in/out can return without a discontinuity.
  Empty fit restores normal floor; one station respects 6x maximum.
- Entry points: scripts/main.gd _replace_layout, _fit_layout_to_window,
  _fit_window, _zoom_camera, creation/positioning of _zoom_controls;
  translations/ui.csv and imported EN/FR resources. Updated README/DESIGN
  and current-state memory to supersede exact saved-camera restoration.
- Tests verify demo/Tokyo/Montreal full station/bend/corridor bounds at
  390x640, 760x520, 1180x740 and 1920x1080: no crop, exactly full dimension,
  correctly centered usable viewport, huge-map zoom round-trip, actual button
  signals and fit after manual pan. Added empty/single-node fit, preserved
  trains/pause and ended following, responsive 44px controls and EN/FR labels.
  Initial assertion assumed demo must zoom in on a narrow window; corrected
  it to viewport-dependent fitting and retained exact output-size assertions.
- Successful executable `/Applications/Godot.app/Contents/MacOS/Godot`:
  `--headless --editor --path . --quit`;
  `--headless --path . --script res://tests/layout_smoke.gd`;
  `--headless --path . --script res://tests/interface_smoke.gd`;
  `--headless --path . --script res://tests/localization_smoke.gd`;
  `--path . --script res://tests/preset_smoke.gd --audio-driver Dummy -- jr-east montreal render-only`.
  Layout smoke negative-validation errors intentional; final empty/single-node
  additions passed on rerun. Native day/night preset/menu render checks passed;
  render-only does not verify ten-minute fleet filling.
- Fresh releases using same Godot executable:
  `--headless --path . --export-release "Windows Desktop" dist/Metro.exe`,
  `--headless --path . --export-release "macOS" dist/Metro-macOS.zip`,
  `--headless --path . --export-release "Web" dist/web/index.html`.
  Clean logs; PE x86_64, ZIP integrity, universal Mac binary, strict deep
  codesign verification and packaged Mac startup
  `--headless --quit-after 10 --audio-driver Dummy` passed. All three actual
  packs tested exact full usable-window dimension for all included layouts
  and actual zoom/fit button signals. Web assets nonempty. Local browser
  confirmed enlarged auto-fitted Montreal and actual plus/minus/fit clicks
  restoring its complete view. `git --no-pager diff --check` passed.
  Browser reset to blank, task server stopped; helper/app/logs cleaned.
- No commit/deployment. Windows/Intel Mac runtime, Gatekeeper/notarization,
  full service/performance suites not rerun. Manual camera views are not
  automatically changed on resize; use Fit again for the new window size.

### Tokaido and both southern Shonan-Shinjuku branches (2026-11-07)

- Expanded [build_jr_east.gd](./scripts/tools/build_jr_east.gd) and generated
  [jr_east.json](./layouts/jr_east.json): Tokaido Tokyo–Odawara local (16
  calls, including Hiratsuka), Shonan-Shinjuku Akabane–Odawara rapid and
  Akabane–Zushi local. User selected both southern branches; northern regional
  extensions remain excluded. Rapid is not special rapid: it skips Nishi-Oi,
  Shin-Kawasaki, Hodogaya and Higashi-Totsuka but serves every Tokaido station
  south of Totsuka. Zushi local includes those four and Kita-Kamakura/Kamakura.
  Stop patterns checked against public Tokaido JR East and Shonan-Shinjuku
  station/service tables, linked in JSON/README. No timetable claims.
- Retained all original seven services, original 59 station coordinates and
  Yamanote loop. Now 80 distinct stations, 97 physical tracks, ten services,
  max two trains each with two wagons. Shared interchanges/physical tracks
  reuse IDs and existing side-by-side rendering; express bypasses use original
  guides rather than coinciding distinct rails or passing through local markers.
  Southwest coast extends through Hiratsuka to Odawara; Zushi branches east
  after Ofuna. Camera (-576,576), zoom 0.08 fits native 1180x740 HUD margins.
  Included catalog label/path retained; Montreal/demo/user saves untouched.
- [preset_smoke.gd](./tests/preset_smoke.gd) checks all ten exact stop sequences,
  topology totals, explicit rapid/local exclusions, shared Hiratsuka and
  southern side-by-side separation, train clearance, two actual trains on each
  new service, save round-trip, menu load, selection, clear and native day/night.
  Initial new Tokyo–Shimbashi guide overlapped Keiyo's departure: moved west
  and retained no-positive-length-collinear-overlap assertion. Initial headless
  menu test had an uninitialized tiny viewport (negative usable Rect2):
  explicitly size 1180x740/1x and await layout before loading. Corrected tests
  passed, without weakening fit/separation checks.
- Successful Godot executable: `/Applications/Godot.app/Contents/MacOS/Godot`.
  `--headless --path . --script res://scripts/tools/build_jr_east.gd --quit-after 120`;
  `--headless --path . --script res://tests/preset_smoke.gd -- jr-east render-only`;
  `--path . --script res://tests/preset_smoke.gd --audio-driver Dummy -- jr-east`.
  Final native 30 simulated seconds: 20 actual trains, parse 3.1ms, route +
  separation validation 780.3ms, simulation 7909.6ms, menu/cache 1400.6ms.
  Inline `python3 -` waypoint orientation/point-containment audit: no new
  strict off-station intersections or new tracks through unrelated markers.
  Browser fresh Web export: loaded Tokyo through real menu, checked overview,
  separate southern corridors, ten tabs and visible Hiratsuka hover label.
- Fresh exports succeeded:
  `--headless --path . --export-release "Windows Desktop" dist/Metro.exe`,
  `--headless --path . --export-release "macOS" dist/Metro-macOS.zip`,
  `--headless --path . --export-release "Web" dist/web/index.html`.
  Clean logs, PE x86_64, ZIP integrity, universal x86_64/arm64 Mac,
  strict deep codesign verification and packaged Mac
  `--headless --quit-after 10 --audio-driver Dummy` startup passed.
  All three actual packs verified 80/97/10 topology, Hiratsuka membership,
  Odawara/Zushi endpoints, two-train/two-wagon settings and unchanged
  platform startup (Web Montreal, desktop demo). Web assets nonempty;
  `git --no-pager diff --check` passed. Browser restored to blank, local
  server stopped, temporary pack helper/app/logs cleaned.
- Windows/Intel Mac runtime, Gatekeeper/notarization, Montreal full service
  regression and detailed performance profiling not rerun; no commit/deploy.
  Web logo customization was explained (custom boot splash/icon and HTML
  shell); no logo asset supplied and no branding files changed.

### Pages startup and clearer line controls (2026-11-07)

- Web export now carries `montreal_startup`; `LayoutStore.load_starter_layout()`
  loads included Montreal for that feature, otherwise Metro demo. The existing
  Pages workflow exports Web, so no domain checks, CI-only file rewrites or
  local-save changes are needed. Both originals stay available in Load.
  Updated export preset, layout startup test, README and DESIGN.
  Verified actual exported main scenes: Web 68 stations/four lines/fleets
  6/6/2/6; Windows/macOS demo 16 stations/three lines.
- Line controls now have a fixed, labelled Collapse header above the scrolling
  body, an 80-pixel color swatch immediately beside Line color, and Delete line.
  User chose deletion of exclusive tracks AND stations, preserving shared
  infrastructure. `TransitGraph.remove_line()` removes only the deleted
  service's exclusive tracks and disconnected exclusive stations, preserves
  unrelated infrastructure, and reindexes surviving topology/line IDs.
  Confirmation supports cancellation; surviving preferences/pause/camera
  remain, following and routes/visits are rebuilt, pending arrival feedback
  with obsolete line IDs is discarded. Last deletion creates one empty line.
  EN/FR actions and confirmation added through translations/ui.csv/import.
- Entry points: scripts/main.gd line-sheet creation, resize and deletion;
  scripts/sim/transit_graph.gd remove_line; scripts/layout_store.gd startup;
  export_presets.cfg Web feature; tests/interface_smoke.gd,
  tests/localization_smoke.gd and tests/layout_smoke.gd.
- Successful validation used `/Applications/Godot.app/Contents/MacOS/Godot`:
  `--headless --editor --path . --quit` (translations/script import);
  `--path . --script res://tests/interface_smoke.gd --audio-driver Dummy`;
  `--headless --path . --script res://tests/editing_smoke.gd`;
  `--headless --path . --script res://tests/localization_smoke.gd`;
  `--headless --path . --script res://tests/layout_smoke.gd`.
  Layout validation failures are intentional negative fixtures. Fixed a test
  lookup that still assumed the old line-popup ScrollContainer root: initial
  run logged SCRIPT ERROR despite printing success; corrected lookup and
  subsequent native runs passed. Tests cover real collapse input, fixed header
  during scrolling, visible footer on phones/laptops, picker, EN/FR, reversed
  shared track/waypoint retention, interchange-only sharing, unrelated rails,
  cancellation, last-line deletion, save/restore and stale visit/follow cleanup.
- Local browser check of the fresh Web export verified automatic Montreal,
  labelled controls, real swatch/picker opening and confirmed deletion of the
  green line while retaining orange/blue/yellow. Native responsive tests cover
  390x640 through 3840x2160 and Retina-scaled input. A browser wait for a
  nonexistent status element timed out; canvas then showed normal initialized
  gameplay. No deployment or commit; production Pages changes only on next
  workflow deployment. Windows/Intel Mac runtime and Gatekeeper/notarization
  remain unrun; full service/performance suite not rerun for these UI changes.
- Final state/arrival-ID regression:
  `--headless --path . --script res://tests/interface_smoke.gd` passed.
  A final native rerun stopped producing output and was stopped after several
  minutes; earlier native UI runs and browser checks passed, but that final
  native run did not complete. Initial headless rerun exposed a new fixture
  depending on inherited viewport sizing; explicitly set 760x520/1x and wait
  for layout before real-input tests. Corrected headless suite passed.
- Final fresh releases passed using the Godot executable above:
  `--headless --path . --export-release "Windows Desktop" dist/Metro.exe`,
  `--headless --path . --export-release "macOS" dist/Metro-macOS.zip`,
  `--headless --path . --export-release "Web" dist/web/index.html`.
  Clean export logs, Windows PE x86_64, ZIP integrity, universal x86_64/arm64
  Mac binary, `codesign --verify --deep --strict` and packaged Mac
  `--headless --quit-after 10 --audio-driver Dummy` startup verified.
  All actual packs checked for platform-specific startup and latest control
  nodes; Web pack also tested green deletion: 43 stations/43 tracks/three
  surviving lines, preserving shared interchanges. Web assets nonempty;
  `git --no-pager diff --check` passed. Browser restored to blank, task server
  stopped, temporary exported apps/helper/logs/screenshots cleaned.

### Minimum practical Montreal spacing and larger fleets (2026-11-07)

- User requested maximum compactness with two-wagon trains and actual fleets
  of six on green/orange/blue, two on yellow. Retained 48-unit base spacing:
  ordinary diagonal intervals use two grid steps (135.8 units) and horizontal
  western intervals three (144 units), the shortest valid grid lengths under
  the existing train-length-plus-40 clearance rule. Preserved defining bends
  and all 68 names/interchanges/four paths rather than flattening the shape.
  Shortened north orange tail and blue doglegs; yellow now uses a 240-unit
  east segment then two diagonal steps. Tokyo/demo/player saves untouched.
- Yellow individual train-fit was insufficient for simultaneous terminal
  clearance: tested horizontal 3–8 / diagonal 2–4 grid-step combinations
  against actual dispatcher capacity. Shortest supporting two trains was
  horizontal five / diagonal two (375.8 total units). Smaller attempted
  yellow variants capped service at one; did not weaken capacity checks.
  Initial blue bend edit failed cardinal/45-degree validation; corrected
  explicit grid bends before exporting.
- [build_montreal.gd](./scripts/tools/build_montreal.gd) initializes max fleets
  6/6/2/6 and desired interval 12s, retaining two wagons. Existing minimum
  headway/cycle calculations and progressive dispatch remain unchanged.
  [preset_smoke.gd](./tests/preset_smoke.gd) now tests actual counts, sustainable
  service fleets, wagon counts, minimum-grid fit and compact yellow coordinates.
  Montreal full test runs 600 simulated seconds to cover progressive fleet
  ramp-up; JR retains 30 seconds. Updated README/DESIGN/current-state memory.
- Successful commands used `/Applications/Godot.app/Contents/MacOS/Godot`:
  `--headless --path . --script res://scripts/tools/build_montreal.gd`;
  `--path . --script res://tests/preset_smoke.gd --audio-driver Dummy -- montreal`;
  `--headless --path . --script res://tests/preset_smoke.gd -- montreal render-only`
  (additional final minimum-spacing assertions).
  Full test verified 20 actual trains with counts 6/6/2/6, ongoing arrivals,
  save round-trip, menu load/selection/clear and native day/night rendering.
  Load/cache 166ms; 600 simulated seconds 212.609s. Desired fleets 6/6/2/6;
  capacities 37/43/3/16. Initial 90-second check was too early for ramp-up
  (long-line service headways 67.1/77.5 seconds); ten-minute test passed.
- Fresh exports passed using the same Godot executable:
  `--headless --path . --export-release "Windows Desktop" dist/Metro.exe`,
  `--headless --path . --export-release "macOS" dist/Metro-macOS.zip`,
  `--headless --path . --export-release "Web" dist/web/index.html`.
  Clean export logs, PE x86_64, ZIP integrity, universal Mac binary, strict
  deep codesign verification and packaged startup
  `--headless --quit-after 10 --audio-driver Dummy` passed; Web assets nonempty.
  All three actual packs verified for compact geometry, 68 stations, two
  wagons and 6/6/2/6 fleet settings. `git --no-pager diff --check` passed.
  Inline `python3 -` JSON waypoint audit compared all distinct-track segment
  pairs using strict orientation-sign intersections: all 80 schematic
  segments passed with no unintended off-station crossings.
  Temporary probes/helper/logs/extracted app cleaned.
  Browser, Windows/Intel Mac runtime, Gatekeeper/notarization and detailed
  profiling not rerun. No commit/deployment.

### Further compacting Montreal with two wagons (2026-11-07)

- User requested tighter again, then chose keeping two wagons with extra
  spacing on the shortest sections. Base spacing now 48 rather than 96 units;
  all stations/bends/camera uniformly halved except the horizontal
  Angrignon–De l'Eglise tail, whose four sections stay 144 units to satisfy
  existing train-clearance checks. Shape/diagonals/interchanges retained;
  68 stations, four lines, max two trains and two wagons unchanged.
  Regenerated [montreal.json](./layouts/montreal.json) through
  [build_montreal.gd](./scripts/tools/build_montreal.gd).
- Initial uniform halving failed four green-line clearance assertions.
  Did not weaken checks or shorten trains; user-approved local spacing fixed
  the issue. Updated exact compact-coordinate assertions in
  [preset_smoke.gd](./tests/preset_smoke.gd), README and DESIGN.
- Passed with `/Applications/Godot.app/Contents/MacOS/Godot`:
  `--headless --path . --script res://scripts/tools/build_montreal.gd`;
  `--path . --script res://tests/preset_smoke.gd --audio-driver Dummy -- montreal`.
  Clean native day/night frames, actual menu/save/clear, eight trains and
  full 30-second service check. Load/cache 157.6ms, simulation 3.733s.
- Fresh Windows/macOS/Web exports passed using the same Godot executable:
  `--headless --path . --export-release "Windows Desktop" dist/Metro.exe`,
  `--headless --path . --export-release "macOS" dist/Metro-macOS.zip`,
  `--headless --path . --export-release "Web" dist/web/index.html`.
  Clean logs, PE x86_64, ZIP integrity, universal Mac binary, strict deep
  codesign and packaged startup `--headless --quit-after 10 --audio-driver Dummy`
  verified; Web assets nonempty. All three actual packs verified for compact
  geometry, 68 stations/four lines and two wagons. `git --no-pager diff --check`
  passed. Temporary helper/logs/extracted app cleaned.
  Browser, Windows/Intel Mac runtime, Gatekeeper and profiling not rerun.
  No commit/deployment.

### Tightening Montreal station spacing (2026-11-07)

- User approved the shape but requested less space between stations.
  Uniformly reduced [build_montreal.gd](./scripts/tools/build_montreal.gd)
  base spacing 144→96 units (one third tighter), including every station
  and explicit bend. Scaled saved camera center accordingly; retained 0.08
  overview zoom so the tighter layout is visibly smaller at the same zoom.
  Regenerated [montreal.json](./layouts/montreal.json). All 68 stations,
  proportions, four paths, shared interchanges, colors and two-train ceilings
  unchanged. Tokyo/demo/player saves untouched. README/DESIGN updated.
- [preset_smoke.gd](./tests/preset_smoke.gd) now asserts exact compact
  interchange coordinates alongside existing shape checks, train fit,
  station counts/orders, service, naming, round-trip, menu load and clearing.
  Successful commands using `/Applications/Godot.app/Contents/MacOS/Godot`:
  `--headless --path . --script res://scripts/tools/build_montreal.gd`;
  `--path . --script res://tests/preset_smoke.gd --audio-driver Dummy -- montreal`.
  Native day/night frames passed with clean logs; eight trains still dispatch.
  On-grid audit passed for all 68 stations. Measured load/cache 166ms,
  30 simulated seconds 3.670s; not a frame-rate guarantee.
- Fresh release exports succeeded with the same Godot executable:
  `--headless --path . --export-release "Windows Desktop" dist/Metro.exe`,
  `--headless --path . --export-release "macOS" dist/Metro-macOS.zip`,
  `--headless --path . --export-release "Web" dist/web/index.html`.
  Clean export logs; PE x86_64, ZIP integrity, universal Mac architectures,
  strict deep codesign and packaged startup
  `--headless --quit-after 10 --audio-driver Dummy` verified. Web assets nonempty;
  actual Windows/Mac/Web packs checked for new spacing, 68 stations/four paths.
  `git --no-pager diff --check` passed. Temporary helper/logs/extracted app
  cleaned. Browser, Windows/Intel Mac execution, Gatekeeper/notarization and
  detailed profiling not rerun. No commit/deploy.

### Separating overlapping JR services (2026-11-07)

- User requested JR services/trains side by side where paths overlap.
  Increased shared `TrackGeometry.CORRIDOR_SPACING` from 32 to 48 pixels
  (28-pixel bands leave a 20-pixel gap on straight shared sections).
  Existing circuit geometry owns this offset for both rendering and trains,
  so shadows/halos, train paths and stop/service geometry agree. Applies to
  shared physical tracks in all layouts; Montreal has no shared physical
  tracks, so its accepted geometry/rendering remain unchanged.
- [build_jr_east.gd](./scripts/tools/build_jr_east.gd) reroutes distinct coincident
  sections: Joban bypasses the Ueno–Uguisudani segment, Chuo Rapid uses the
  south side of its Nakano–Shinjuku local corridor, Saikyo runs inside the
  western Yamanote arm. Regenerated [jr_east.json](./layouts/jr_east.json).
  All seven exact station sequences, 59 nodes/69 tracks, 14 dispatched trains
  and two-train ceilings preserved. Shared interchanges still converge and
  may overlap locally; independent crossings are not simulated collisions.
- [preset_smoke.gd](./tests/preset_smoke.gd) measures actual route-centerline
  separation >=40 pixels at four JR shared sections, including three-service
  Tokyo–Kanda, and rejects any positive-length collinear overlap between
  distinct physical tracks. Initial route edit created a short coincident
  Chuo/Saikyo approach; this exact audit caught it and final guides fixed it.
- Successful commands used `/Applications/Godot.app/Contents/MacOS/Godot`:
  `--headless --path . --script res://scripts/tools/build_jr_east.gd`;
  `--path . --script res://tests/preset_smoke.gd --audio-driver Dummy`
  (both presets, full service and native day/night frames);
  `--headless --path . --script res://tests/simulation_smoke.gd`;
  same headless command for `terminal_smoke.gd`, `loop_smoke.gd`,
  `editing_smoke.gd` and `train_controls_smoke.gd`;
  `--path . --script res://tests/visual_smoke.gd --audio-driver Dummy`;
  `--path . --script res://tests/train_visual_smoke.gd --audio-driver Dummy`.
  Final clean results: Tokyo load/cache 550.1ms, 30 simulated seconds 4.742s;
  Montreal load/cache 168.3ms, simulation 3.638s. Timing is not an FPS guarantee.
  Browser JR menu load and overview inspected with visibly parallel services;
  fresh console capture contained no errors. README/DESIGN updated.
- Fresh releases passed with the same Godot executable:
  `--headless --path . --export-release "Windows Desktop" dist/Metro.exe`,
  `--headless --path . --export-release "macOS" dist/Metro-macOS.zip`,
  `--headless --path . --export-release "Web" dist/web/index.html`.
  Clean logs, PE x86_64, ZIP integrity, universal Mac architectures, strict
  deep codesign verification and packaged startup
  `--headless --quit-after 10 --audio-driver Dummy` verified; Web assets nonempty.
  All three actual packs verified for 48-pixel corridor spacing and the
  59-station/seven-service JR preset. `git --no-pager diff --check` passed.
  Temporary helper, logs, extracted app and local browser server cleaned.
  Windows/Intel Mac execution, Gatekeeper/notarization, full six-minute
  intersection suite, browser-night-specific inspection and detailed profiling
  not run. No commit/deployment.

### Restoring recognizable Montreal schematic geometry (2026-11-07)

- User found Montreal visually unlike the supplied map. Compared the source
  image and replaced arbitrary station columns with an original hand-positioned
  schematic preserving the network's defining relationships: long diagonal
  orange north arm, diagonal western arm and southwest U, downtown green axis,
  horizontal Angrignon tail, northeast green zigzags, blue central dogleg and
  yellow east/northeast branch. No source artwork, typography or map assets
  copied. All 68 names, station order, interchanges, four colors and two-train
  settings retained; Tokyo/demo/player saves untouched.
- [build_montreal.gd](./scripts/tools/build_montreal.gd) now uses 144-unit base
  spacing, explicit corner guides on six defining segments and centered
  overview zoom 0.08. Regenerated [montreal.json](./layouts/montreal.json).
  [preset_smoke.gd](./tests/preset_smoke.gd) checks diagonal arms, southwest
  interchange ordering, horizontal green tail, blue dogleg and yellow heading,
  alongside existing topology/service/save/menu/native rendering checks.
  README/DESIGN updated.
- Successful commands with `/Applications/Godot.app/Contents/MacOS/Godot`:
  `--headless --path . --script res://scripts/tools/build_montreal.gd`;
  `--path . --script res://tests/preset_smoke.gd --audio-driver Dummy -- montreal`.
  Clean native day/night frames, eight trains, 68 stations/69 tracks/four paths.
  Final benchmark parse 3.1ms, routes 114.9ms, load/cache 173.4ms, 30 simulated
  seconds 3.718s; not a frame-rate guarantee. Separate strict segment-intersection
  audit found zero unintended rail crossings.
- Final browser menu load inspected at 1180x740: four-line map fits above the
  line rail and preserves the defining diagonals/bends; fresh console capture
  contains no errors. Native tests also render day/night. Source comparison is
  visual, not pixel matching or a copy of the official illustration.
- Fresh Windows/macOS/Web exports succeeded using the same Godot executable:
  `--headless --path . --export-release "Windows Desktop" dist/Metro.exe`,
  `--headless --path . --export-release "macOS" dist/Metro-macOS.zip`,
  `--headless --path . --export-release "Web" dist/web/index.html`.
  Clean export logs, PE x86_64, ZIP integrity, universal Mac architectures,
  strict deep codesign verification and packaged startup
  `--headless --quit-after 10 --audio-driver Dummy` passed. Web assets nonempty;
  all three actual packs verified for 68 stations/four lines and revised
  interchange coordinates. Initial helper compared JSON floats to integer
  arrays and falsely reported stale geometry; Vector2 comparisons corrected
  the check and all packs passed. `git --no-pager diff --check` passed.
- Temporary helper, logs, extracted app and browser server cleaned.
  Windows/Intel Mac execution, Gatekeeper/notarization, browser-night-specific
  inspection and detailed frame-time/audio profiling not run. No commit/deploy.

### Simplifying Montreal to the existing metro (2026-11-07)

- User requested only the current 68 metro stations. Removed all REM/exo
  paths, regional/continuation nodes, projected airport connection and pedestrian
  transfer metadata from [build_montreal.gd](./scripts/tools/build_montreal.gd);
  regenerated [montreal.json](./layouts/montreal.json). Existing metro names,
  coordinates, station order, colors and shared interchanges are unchanged.
  Four paths, 68 unique stations, 69 tracks, two-train initial ceilings and
  eight dispatched trains. Tokyo/demo and existing player saves are unchanged.
- [preset_smoke.gd](./tests/preset_smoke.gd) verifies exact 68-node/four-line
  scope, 27/31/3/12 calls, all nodes served by metro and unchanged interchange
  memberships (Berri-UQAM three lines; Lionel-Groulx/Snowdon/Jean-Talon two).
  README/DESIGN/current-state notes now describe metro-only Montreal.
- Successful exact commands with `/Applications/Godot.app/Contents/MacOS/Godot`:
  `--headless --path . --script res://scripts/tools/build_montreal.gd`;
  `--path . --script res://tests/preset_smoke.gd --audio-driver Dummy -- montreal`.
  Native day/night frames, service, two-train ceilings, names, save round-trip,
  actual menu loading, selection and clearing passed with clean logs.
  Measured parse 2.2ms, routes 218.8ms, menu/load/cache 354.9ms and
  30 simulated seconds 3.604s. Historical regional-Montreal counts/timings
  below are superseded; these measurements are not FPS guarantees.
- Fresh exports passed using the same Godot executable:
  `--headless --path . --export-release "Windows Desktop" dist/Metro.exe`,
  `--headless --path . --export-release "macOS" dist/Metro-macOS.zip`,
  `--headless --path . --export-release "Web" dist/web/index.html`.
  Clean logs, PE x86_64, ZIP integrity, universal Mac architectures,
  `codesign --verify --deep --strict`, packaged Mac startup
  `--headless --quit-after 10 --audio-driver Dummy` and nonempty Web assets
  verified. All three actual release packs contain the new 68-station/four-line
  metro-only resource. `git --no-pager diff --check` passed.
  Temporary helper, logs and extracted verification app cleaned.
  Windows/Intel Mac execution, Gatekeeper/notarization, browser execution and
  detailed frame-time/audio profiling not rerun. No commit or deployment.

### Replacing the regional preset with central Tokyo (2026-11-07)

- User found the regional network unrecognizable and chose central Tokyo JR,
  not Tokyo Metro/Toei or a combined subway network. Replaced the resource at
  [jr_east.json](./layouts/jr_east.json), preserving its catalog path but renaming
  its localized menu entry to Tokyo central JR. Existing player saves are not
  deleted or altered. Montreal's JSON/generator and demo remain unchanged.
- Rewrote [build_jr_east.gd](./scripts/tools/build_jr_east.gd) with explicit,
  north-up hand-positioned stations: 59 stations, 69 tracks, seven paths,
  max two trains per path (14 dispatched). Complete 30-station Yamanote loop
  includes Takanawa Gateway. Adjacent crops: Keihin-Tohoku Akabane–Kamata
  local, Chuo Rapid Nakano–Tokyo, Chuo-Sobu Local Nakano–Kinshicho,
  Saikyo Akabane–Osaki, Joban Rapid Ueno–Kita-Senju and Keiyo Local
  Tokyo–Shin-Kiba. These are preset boundaries, not promised real termini.
  No regional suburbs, subway, airport links or official timetable.
- Cross-checked each central sequence against public line station tables
  referenced in the generator/JSON. JR East supplied PDF remains a source,
  but regional coverage is intentionally abandoned. Geometry emphasizes
  Shinjuku west, Ikebukuro north, Shinagawa south and the Chuo cross-city axis
  inside a simple Yamanote oval; express guides bypass skipped local markers.
  Use 144-unit station spacing and startup zoom 0.09 to fit laptop HUD margins.
- [preset_smoke.gd](./tests/preset_smoke.gd) now asserts all seven exact station
  sequences, 30-stop loop, 59-node scope, geographic orientation, simple loop,
  inside-loop Chuo stations and HUD-safe fitted positions. Existing tests also
  cover line capacity, max two trains, simulation, names, saving, menu load,
  selection/clear and actual day/night rendering for both presets.
  Pages CI runs both full benchmarks again; regional render-only shortcut removed.
- Successful commands with `/Applications/Godot.app/Contents/MacOS/Godot`:
  `--headless --editor --path . --quit`;
  `--headless --path . --script res://scripts/tools/build_jr_east.gd`;
  `--path . --script res://tests/preset_smoke.gd --audio-driver Dummy`;
  `--headless --path . --script res://tests/localization_smoke.gd`;
  `--headless --path . --script res://tests/layout_smoke.gd`.
  Corrupt-save error fixtures are intentional. Initial 192-unit spacing clipped
  Kamata at minimum zoom; a new HUD-fit check caught the exact boundary after
  tightening spacing, so startup zoom was also reduced. Final tests are clean.
- Final native benchmark: Tokyo parse 1.3ms, routes 374.7ms, load/cache 627.7ms,
  30 simulated seconds 4.740s; Montreal load/cache 439.4ms, simulation 5.621s.
  Former regional observations (31s load, 58s simulation) are superseded for
  the bundled Tokyo entry; measured test time is not a FPS guarantee.
  README/DESIGN/current-state notes updated accordingly.
- Fresh release exports succeeded with the same Godot executable:
  `--headless --path . --export-release "Windows Desktop" dist/Metro.exe`,
  `--headless --path . --export-release "macOS" dist/Metro-macOS.zip`,
  `--headless --path . --export-release "Web" dist/web/index.html`.
  Clean export logs; PE x86_64, ZIP integrity, universal Mac architectures,
  `codesign --verify --deep --strict`, packaged Mac startup
  `--headless --quit-after 10 --audio-driver Dummy` and nonempty Web assets
  verified. Read all three preset JSON files from each actual release pack:
  new 59-station Tokyo, unchanged 80-node Montreal and 16-node demo.
- Inspected the final browser map at 1180x740: clean, untangled loop with
  cross-city Chuo axes and all cropped tails visible above the line rail.
  Actual menu loading produced no console errors. `git --no-pager diff --check`
  passed. Local browser server, downloaded public HTML, diagnostic logs,
  temporary verification helper and extracted app cleaned up; supplied PDFs
  preserved. Windows/Intel Mac execution, Gatekeeper/notarization, browser
  night-specific inspection and detailed frame-time/audio profiling not run.
  No commit or deployment.

### Real-network presets and independent rail crossings (2026-11-07)

- Added reproducible generators [build_jr_east.gd](./scripts/tools/build_jr_east.gd)
  and [build_montreal.gd](./scripts/tools/build_montreal.gd), generated
  [jr_east.json](./layouts/jr_east.json) and [montreal.json](./layouts/montreal.json),
  named topology, generic resource-path catalog loading, localized labels and
  two-train initial ceilings. Demo remains the automatic startup layout.
  Export filters include all JSON and exclude generator tools.
- JR East uses the supplied map revision 2026-03-14; secondary checks cover
  selected Joban/Narita/Sobu/Tsurumi/Musashino sequences. Corrected two misplaced
  Sobu stations, separated Sotetsu Ebina/Shonandai branches and restored the
  authentic Kita-Ayase–Ayase shuttle. Unnamed gray continuation stubs excluded.
  Independent verification of every station sequence is still outstanding:
  do not describe the preset as an exhaustive certified reproduction.
- Montreal includes metro call counts 27/31/3/12, 68 unique metro stations,
  partial REM/exo connections and explicitly projected airport branch.
  Off-map continuation endpoints are labeled; buses and unnamed projected
  blue-line stops excluded. Distinct pedestrian-transfer facilities remain
  separate nodes, with metadata only, not passenger-routing simulation.
- User explicitly allowed independent off-station crossings everywhere.
  Updated simulation/editing/visual tests while preserving per-stroke
  invalid geometry checks. Large JR rendering exposed Clipper outlines with
  repeated-vertex pinches that Godot cannot triangulate. `_polygon_loops`
  separates contours before hole subtraction; native day/night rendering now
  passes. Junction intensity uses spatial cells and cached radii instead of
  scanning all interchanges/line memberships per vertex. Original visuals
  remain covered by pixel tests and an enclosed-hole regression.
- Successful exact commands used `/Applications/Godot.app/Contents/MacOS/Godot`:
  `--path . --script res://tests/preset_smoke.gd --audio-driver Dummy`
  (both presets, full 30-second simulations and actual native day/night frames);
  `--path . --script res://tests/visual_smoke.gd --audio-driver Dummy`;
  `--path . --script res://tests/train_visual_smoke.gd --audio-driver Dummy`;
  `--headless --path . --script res://tests/layout_smoke.gd`;
  the same headless command for `localization_smoke.gd`, `interface_smoke.gd`,
  `editing_smoke.gd`, `simulation_smoke.gd` and `terminal_smoke.gd`.
  Schedule smoke also passed during integration (regulated headway stddev
  0.181s versus 6.864s unregulated). Layout corruption errors are intentional.
  Initial test scripts exited zero despite halo assertions; those runs were
  failures. Final native preset logs are clean. `render-only` skips the long
  benchmark but still checks topology, service, loading and actual frames;
  Pages CI runs full Montreal plus JR East `render-only`.
- Final native observations: JR East 104 trains, parse 11.8ms, routes 15.209s,
  menu/load/cache 30.960s, 30 simulated seconds 58.065s. Montreal 24 trains,
  parse 2.4ms, routes 257.1ms, menu/load/cache 458.6ms, 30 simulated seconds
  5.904s. These are measured test times, not FPS guarantees. JR East is not
  real-time at this stress-test rate; broader simulation optimization remains.
- Fresh Windows/macOS/Web release commands all succeeded with clean logs:
  `--headless --path . --export-release "Windows Desktop" dist/Metro.exe`,
  `--headless --path . --export-release "macOS" dist/Metro-macOS.zip`,
  `--headless --path . --export-release "Web" dist/web/index.html`.
  Verified PE x86_64, ZIP integrity, universal Mac binary, strict deep signing,
  packaged Mac startup (`--headless --quit-after 10 --audio-driver Dummy`),
  nonempty Web assets and all three JSON resources inside each actual export
  (Windows pack is embedded in the executable, not a separate Metro.pck).
  Browser menu loading and fitted maps were inspected for JR East and Montreal;
  fresh console capture showed no polygon errors after the fix.
  `git --no-pager diff --check` passed. Temporary verification app, diagnostic
  logs/helper and local browser server were cleaned up; supplied PDFs retained.
- Remaining: independent JR station-by-station verification, Windows and Intel
  Mac execution, Gatekeeper/notarization, browser-night-specific testing and
  detailed CPU/GPU/audio/frame-time profiling. No commit or deployment.

### Growing interchange white centers (2026-11-07)

- User chose +1 pixel center radius per additional serving line while keeping
  each colored ring 2 pixels thick. Single-line/unserved markers stay unchanged;
  outer radii are now 12/15/18 pixels for one/two/three lines. Added shared
  `TrackGeometry.station_center_radius` / `station_radius` helpers used by
  [world_view.gd](./scripts/render/world_view.gd) and `station_stop_clearance`,
  so rendering, picks/handles/overlays, night exclusions and train berths
  agree. Colors, line ordering and loop membership remain unchanged.
  README/DESIGN and current product notes updated.
- Passed exact commands:
  `/Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tests/visual_smoke.gd --audio-driver Dummy`;
  `/Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tests/train_visual_smoke.gd --audio-driver Dummy`;
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/terminal_smoke.gd`;
  same headless script command for `res://tests/interface_smoke.gd` and
  `res://tests/layout_smoke.gd`. Pixel assertions now measure expanded white
  centers and all 2px rings at 0/1/2/3/4/8 lines, day/night, 1x/2.5x and
  interaction overlays. Shared-terminal expected radii now 15/18; verified
  berth/platform clearance, 1–6 wagon reversal and ongoing service. Layout
  test's corrupt-input logs are intentional passing fixtures.
- Fresh export commands:
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "Windows Desktop" dist/Metro.exe`;
  same command for `"macOS" dist/Metro-macOS.zip` and `"Web" dist/web/index.html`.
  All succeeded with clean logs; Windows PE x86_64, universal Mac binary,
  ZIP integrity, strict deep signing and packaged Mac startup
  (`--headless --quit-after 30 --audio-driver Dummy`) verified, Web assets
  nonempty. `git --no-pager diff --check` passed. Temporary captures and build
  verification files cleaned. Windows/Intel Mac runtime, Gatekeeper and browser
  runtime not checked for this sizing change; full schedule/intersection suites
  unrun. No commit requested.

### Shipping an automatically opened starter layout (2026-11-07)

- User chose a small demo with intersecting lines/loop and automatic startup.
  Added [metro_demo.json](./layouts/metro_demo.json): purple octagonal loop,
  turquoise/coral diagonal approaches with offset bends, 16 stations and five shared
  interchanges. All sections fit the selected two-wagon trains; no off-station
  crossing. Original is read-only in `res://`, not seeded into `user://`, so
  storage permissions/eviction and same-name user saves cannot remove it.
  Main opens it quietly at each launch, offers it under Load with confirmation,
  and preserves empty-map Clear. Demo framing zooms out for smaller viewports.
  Startup failures show localized feedback rather than silently falling back.
  Existing fixture tests explicitly disable demo startup.
- Passed:
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/layout_smoke.gd`;
  same command for `res://tests/interface_smoke.gd`,
  `res://tests/localization_smoke.gd`, `res://tests/editing_smoke.gd`,
  `res://tests/loop_smoke.gd`, `res://tests/train_controls_smoke.gd` and
  `res://tests/simulation_smoke.gd`;
  `/Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tests/visual_smoke.gd --audio-driver Dummy`.
  Layout checks cover real startup, all geometry validation, every line running
  after 180 simulated seconds, >=20 arrivals, immutable original after
  edit/save/clear/reload, same-name user copies and 760x520/390x640 framing.
  User rejected the initial cross-like orthogonal demo; rerouted both open
  lines with diagonals and asymmetric bends. Tests require at least two
  diagonal sections and two headings per open line. Reran layout smoke and
  refreshed/verified all three exports after the reroute; inspected the final
  diagonal demo in the browser.
  Localization covers live included-label translation. Expected corrupt-input
  fixtures log errors during the passing layout test.
- Initial import found a loop-variable/parameter name collision; fixed before
  tests/exports. Initial exact demo snapshot checks incorrectly treated
  viewport-fitted/float32 zoom as immutable content; now compare all other
  persisted fields exactly, constrain zoom and measure every station's fit.
  One test variable needed an explicit Vector2 annotation after a Dictionary
  lookup; corrected and rerun.
- All three fresh exports succeeded with clean logs using
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "Windows Desktop" dist/Metro.exe`,
  the same command for `"macOS" dist/Metro-macOS.zip` and `"Web" dist/web/index.html`.
  Verified the demo JSON appears in all export logs, Windows PE x86_64,
  universal Mac x86_64/arm64, ZIP integrity, deep strict codesign, extracted Mac
  startup with `--headless --quit-after 30 --audio-driver Dummy` and nonempty
  Web assets. Browser verified automatic demo rendering, Clear followed by
  included Load/confirmation, and full phone-view framing. Temporary native
  captures/extracted app and local server cleaned after validation.
  `git --no-pager diff --check` passed. Windows runtime, Intel Mac runtime,
  Gatekeeper/notarization, Safari and full long-running schedule/intersection
  suites remain unrun. No commit or deployment requested.

### Named layout persistence and clear-map menu (2026-11-07)

- Added localized Menu Save/Load/Clear, named storage sheet, overwrite/load/clear
  confirmations, restart-safe layout reconstruction and storage failure feedback.
  Chose Godot `user://` with versioned JSON rather than SQLite or native file
  dialogs because it shares one implementation across Windows, universal macOS
  and Web/IndexedDB without dependencies. Saves include isolated stations,
  empty lines, canonical/shared tracks, loops, bends, all line settings and view.
  README/DESIGN describe local paths, limits and browser retention caveats.
  Pages CI now runs [layout_smoke.gd](./tests/layout_smoke.gd).
- Passed these exact commands (Godot 4.7.2):
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --path . --quit`;
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/layout_smoke.gd`;
  the same script command for `res://tests/interface_smoke.gd`,
  `res://tests/localization_smoke.gd`, `res://tests/editing_smoke.gd` and
  `res://tests/loop_smoke.gd`. Layout tests cover multiple names, overwrite
  cancellation/confirmation, complete loop/reversed-sharing/settings/view
  round-trip, fresh game/store instances, clear and corrupt-load preservation,
  responsive English/French sheets, invalid references/settings/JSON and
  coordinate overflow. Their logged validation errors are deliberate fixtures.
  Initial failures caught float32 minimum zoom and tall phone settings; fixed
  by normalizing capture zoom and grouping the three menu actions in one row.
- Local browser Web release verification used actual menu input and inspected
  IndexedDB: saved two stations, reloaded page, loaded/confirmed and saved an
  identical copy, then cleared/confirmed and saved an empty copy while original
  saves remained. Browser startup takes longer than initial page navigation;
  early automated clicks were lost, so repeated after engine readiness.
  Native fixture files and browser test layouts were cleaned.
- Fresh release export commands:
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "Windows Desktop" dist/Metro.exe`;
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "macOS" dist/Metro-macOS.zip`;
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "Web" dist/web/index.html`.
  All succeeded with clean logs; verified Windows PE x86_64, ZIP integrity,
  universal Mac x86_64/arm64, deep strict ad-hoc codesign, nonempty Web assets
  and extracted Mac binary startup with `--headless --quit-after 10 --audio-driver Dummy`.
  `git --no-pager diff --check` passed. Windows runtime, Intel Mac runtime,
  Gatekeeper/notarization, Safari/private-mode/eviction behavior and full
  simulation/graphical suites remain unrun. Release outputs are ignored.

### Committing accumulated lighting, editing and menu refinements (2026-11-07)

- User requested committing all accumulated changes since the previous commit:
  shape-preserving station reconnection and rail deletion controls, consistent
  confirmation dialog, original tight adaptively smooth bends, larger overview,
  matte day/night surface and shared moving sunlight/track shadows, centered
  menus without settings scrolling, permanent larger launch-title fade and
  fixed-location icon-only dock toggle. Includes related regression tests,
  translations and documentation. Earlier "not committed" entries describe
  their state at the time; this commit captures them together. No push requested.
- Fresh exports completed with clean logs using
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "Windows Desktop" dist/Metro.exe`,
  the same command for `"macOS" dist/Metro-macOS.zip` and `"Web" dist/web/index.html`.
  Verified macOS ZIP integrity, universal x86_64/arm64 binary, strict deep
  codesign and exported Apple Silicon startup (`--headless --quit-after 10 --audio-driver Dummy`),
  Windows PE x86_64, nonempty Web assets and `git --no-pager diff --check`.
  No tests rerun for this commit-only task; prior targeted results recorded
  below. Windows/Intel runtime/browser checks remain unrun. Release files are
  ignored build outputs, not committed.

### Larger launch title and fixed dock toggle location (2026-11-07)

- Increased Metro launch title from 26 to 48 logical pixels; preserved independent
  10–30s fade and permanent disappearance. Collapse and restore now share the
  same bottom-right 44px rectangle (16px right, 8px bottom), so repeated clicks
  toggle without pointer movement. Watch restore stays centered.
  [main.gd](./scripts/main.gd) uses vertical shrink-end for the dock button and
  upward panel growth to preserve bottom alignment during scrollbar overflow.
  README/DESIGN updated.
- Native interface smoke passed:
  `/Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tests/interface_smoke.gd --audio-driver Dummy`.
  Added exact rectangle equality before/after real collapse/restore clicks
  across phone/laptop resize and title font-size assertion. Inspected native
  menu capture. Initial test caught real overflow displacement, fixed by upward
  panel growth; stale pre-layout measurement corrected by awaiting layout.
- Fresh releases succeeded with clean logs using
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "Windows Desktop" dist/Metro.exe`,
  the same command for `"macOS" dist/Metro-macOS.zip` and `"Web" dist/web/index.html`.
  Verified ZIP integrity, PE x86_64, universal Mac binary, strict deep codesign,
  exported Apple Silicon startup (`--headless --quit-after 10 --audio-driver Dummy`),
  Web assets and `git --no-pager diff --check`. Windows/Intel runtime/browser
  checks and simulation suites unrun for UI-only changes. Not committed.

### Centered panels and permanent launch-title fade (2026-11-07)

- [main.gd](./scripts/main.gd) centers help/settings on the actual viewport,
  rather than above the bottom dock. Settings use a direct VBox instead of a
  ScrollContainer and take their content's minimum height. Minimum-size changes
  schedule fresh layout for wrapping/localization. Help keeps its bounded
  scrollable reference on narrow screens; line-control layout unchanged.
- Metro title remains opaque through 10s, smoothstep fades over the next 20s,
  and hides permanently at 30s. Separate CanvasLayer child prevents idle HUD
  fading from starting the title fade prematurely. Watch mode/narrow view hides
  it without resetting the launch timer; it ignores input wake and pause.
  README/DESIGN/current-state memory updated.
- Native interface and headless localization smoke passed with
  `/Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tests/interface_smoke.gd --audio-driver Dummy`
  and `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/localization_smoke.gd --audio-driver Dummy`.
  Checks cover exact panel centers, full settings bounds without scrolling in
  both languages at phone/laptop sizes, title alpha 1/0.5/0 at 10/20/30 seconds,
  and permanent disappearance after wake/resize. Native settings capture inspected.
  Initial centering assertions used requested 4K window size, which macOS clamps;
  corrected them to assert against the actual rendered viewport, not a proxy.
- Fresh release exports succeeded with clean logs using
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "Windows Desktop" dist/Metro.exe`,
  the same command for `"macOS" dist/Metro-macOS.zip` and `"Web" dist/web/index.html`.
  Verified ZIP integrity, Windows PE x86_64, universal Mac binary, strict deep
  codesign, exported Apple Silicon startup (`--headless --quit-after 10 --audio-driver Dummy`),
  Web assets and `git --no-pager diff --check`. Windows/Intel runtime/browser
  checks and simulation suites unrun for UI-only changes. Not committed.

### Icon-only dock collapse and restore (2026-11-07)

- User rejected the isolated v and then rejected visible text. Replaced dock
  collapse/restore with an antialiased outlined bottom-panel icon and down/up
  arrow in [main.gd](./scripts/main.gd), using the existing button theme,
  translated tooltips and 44px targets. Shrink sizing preserves tab space.
  Watch-mode grip and simulation/pause/line selection behavior unchanged.
  README/DESIGN and interface regressions updated. No new translation keys.
- Initial text-button attempt caused a narrow viewport dock overflow; removed
  labels and temporary sizing workaround after the user's correction.
  Final native interface and headless localization smoke passed:
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --path . --quit`,
  `/Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tests/interface_smoke.gd --audio-driver Dummy`,
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/localization_smoke.gd --audio-driver Dummy`.
  Logs checked for script errors; native menu capture inspected for icon output.
- Fresh release exports succeeded with clean logs using
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "Windows Desktop" dist/Metro.exe`,
  the same command for `"macOS" dist/Metro-macOS.zip` and `"Web" dist/web/index.html`.
  Verified ZIP integrity, PE x86_64, universal Mac binary, strict deep codesign,
  exported Apple Silicon startup (`--headless --quit-after 10 --audio-driver Dummy`),
  Web assets and `git --no-pager diff --check`. Windows/Intel runtime/browser
  checks and simulation suites unrun for this UI-only change. Not committed.

### Removing station shadows and sharing a moving sun (2026-11-07)

- Removed station shadow drawing entirely in [world_view.gd](./scripts/render/world_view.gd).
  Increased cached whole-track shadow opacity multiplier from 0.22 to 0.36
  per layer; keeps ground-only layering, rounded outlines and loop holes.
  [urban_backdrop.gd](./scripts/render/urban_backdrop.gd) supplies a shared
  `sun_position`: continuous left-to-right arc between dawn and sunset.
  Shadow horizontal offset opposes that source; the matte shader's warm light
  follows the same position rather than switching sides at noon. Train shadows
  follow the shared source as before. README/DESIGN/current-state memory updated.
- Native train_visual, urban and visual smoke passed with
  `/Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tests/train_visual_smoke.gd --audio-driver Dummy`
  and the same command separately for `urban_smoke.gd` and `visual_smoke.gd`.
  Pixel tests isolate halos and measure shadow on right at dawn/left at sunset
  (>0.05 RGB difference), no shadow on opposite side (<0.005), and no isolated
  station shadow (<0.005). Sun/shadow movement is monotonic over 100 daylight samples.
  Initial duplicate test variable fixed; cap probe moved outside the intentional
  stronger shadow and dawn/dusk halo interference excluded from shadow probes.
- Fresh Windows/macOS/Web releases succeeded with clean logs. Verified Windows
  PE x86_64, macOS ZIP integrity/universal x86_64+arm64, strict deep codesign,
  exported Apple Silicon startup (`--headless --quit-after 10 --audio-driver Dummy`),
  nonempty Web HTML/JS/WASM/PCK and `git --no-pager diff --check`. Simulation
  suites not rerun for rendering-only changes; Windows/Intel runtime/browser
  checks unrun. Pending changes preserved, not committed.

### Restoring original tight bends everywhere (2026-11-07)

- User rejected the broad station sweeps and explicitly chose restoring tight
  bends everywhere. [track_geometry.gd](./scripts/render/track_geometry.gd)
  returns to original quadratic 12px station/24px ordinary rounding, capped at
  35% adjacent lengths. Adaptive sampling remains smooth; no centered cubic or
  widened 96px transition remains. Grid markers retain their original slight
  cut-corner offset. Matte day/night, shadows, large overview and deletion changes
  are preserved. README/DESIGN/current-state memory supersede widening claims.
- Editing tests measure original 12px footprint/entry/exit, reverse equivalence,
  and less than 3-degree sample turns. Native train/visual, headless editing,
  simulation, schedule and loop tests all passed with
  `/Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tests/train_visual_smoke.gd --audio-driver Dummy`,
  the same native command for `visual_smoke.gd`, and `--headless --path .
  --script res://tests/{editing,simulation,schedule,loop}_smoke.gd --audio-driver Dummy`
  (each script run separately). Headway deviation 0.181s versus 6.864s.
- Fresh Windows/macOS/Web exports using documented commands succeeded with
  clean logs. Verified Windows PE x86_64, macOS ZIP/universal x86_64+arm64,
  strict deep codesign and Apple Silicon exported startup
  (`--headless --quit-after 10 --audio-driver Dummy`), nonempty Web assets,
  and `git --no-pager diff --check`. Windows/Intel runtime and browser unrun;
  terminal/intersection suites not rerun for this restoration. Not committed.

### Ground-only station shadows and subtle track shadow (2026-11-07)

- User requested station shadows not land on tracks, and a light shadow under
  the whole track instead. [world_view.gd](./scripts/render/world_view.gd)
  draws ground shadows before all corridors/lanes, preserving opaque rail colors.
  Train shadows remain above tracks. Cached rounded centerline offset polygons
  (29/31px) provide faint corridor shadows at 45% solar displacement and 22%
  opacity per layer; existing hole-preserving geometry avoids filled loop interiors
  and folded joins. Station shadows remain visible only on exposed background.
- Native tests passed:
  ```
  /Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tests/train_visual_smoke.gd --audio-driver Dummy
  /Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tests/visual_smoke.gd --audio-driver Dummy
  ```
  Corner corridor pixels stay within 0.025 total RGB difference of line color
  at noon/night/dawn/sunset; whole-track noon shadow difference is 0.005-0.2
  versus the exact bare-surface pixel. Native sunset capture inspected.
  README/DESIGN/current-state memory updated.
- Fresh Windows/macOS/Web exports succeeded using documented commands; logs
  had no errors/warnings. Verified PE x86_64, ZIP integrity, universal macOS
  x86_64/arm64, strict deep codesign, exported Apple Silicon startup
  (`--headless --quit-after 10 --audio-driver Dummy`), nonempty Web assets,
  and `git --no-pager diff --check`. No dispatch suites rerun for layering-only
  changes; Windows/Intel runtime, browser and large-network profiling unrun.
  Pending work preserved; not committed or pushed.

### Smooth station curves, matte daylight and larger overview (2026-11-07)

- User chose matte texture, sunrise/sunset palettes and subtle sun shadows,
  not glass reflections. [urban_backdrop.gd](./scripts/render/urban_backdrop.gd)
  and [matte_surface.gdshader](./scripts/render/matte_surface.gdshader) provide
  cool dawn, peach sunset, blue hour, off-white noon and a dark midnight gradient.
  World-anchored grain is filtered at dezoom; surface variation fades in darkness.
  [world_view.gd](./scripts/render/world_view.gd) draws restrained solar station/
  car shadows: short at noon, longer/opposite directions at dawn/dusk, no night
  shadow. Rail glow and opaque route/marker colors remain.
- Finer sampling exposed inward lane folds in the prior tight centered cubic.
  User explicitly accepted wider station curves to retain grid-centered markers.
  [track_geometry.gd](./scripts/render/track_geometry.gd) uses two broad cubic
  halves sharing a bisecting station tangent, capped at 96px/45% adjacent length.
  Ordinary 24px bends keep their quadratic shape. Both use adaptive de Casteljau
  sampling (0.01px flatness, 1-degree tangent tolerance, depth 12). Editing tests
  require less than 3 degrees between samples and at least 10px opposing lane
  clearance across 45/90/135-degree turns and 96/144/384px approaches.
- Map is already unbounded; [main.gd](./scripts/main.gd) lowers wheel/pinch minimum
  zoom from 0.45 to 0.08 through the same helper, retaining 6x close zoom.
  1440px now spans 18000 world units. UI tests exercise both controls and far-world
  pan scaling. Loop regression simulates an 80-station/30000+px circuit with
  actual arrivals in both directions, fleet ceiling and full-train gaps.
  This is manual map building, not geographic import or full JR East certification.
- Passed with `/Applications/Godot.app/Contents/MacOS/Godot`:
  ```
  --headless --path . --script res://tests/editing_smoke.gd --audio-driver Dummy
  --headless --path . --script res://tests/interface_smoke.gd --audio-driver Dummy
  --headless --path . --script res://tests/localization_smoke.gd --audio-driver Dummy
  --headless --path . --script res://tests/simulation_smoke.gd --audio-driver Dummy
  --headless --path . --script res://tests/loop_smoke.gd --audio-driver Dummy
  --headless --path . --script res://tests/terminal_smoke.gd --audio-driver Dummy
  --headless --path . --script res://tests/schedule_smoke.gd --audio-driver Dummy
  --headless --path . --script res://tests/schedule_smoke.gd --audio-driver Dummy -- --platforms-only
  --headless --path . --script res://tests/intersection_smoke.gd --audio-driver Dummy
  --path . --script res://tests/urban_smoke.gd --audio-driver Dummy
  --path . --script res://tests/train_visual_smoke.gd --audio-driver Dummy
  --path . --script res://tests/visual_smoke.gd --audio-driver Dummy
  ```
  Native captures inspected for smooth curves, texture and dawn/dusk shadows.
  Texture anchoring and bounded contrast measured in pixels. Headway deviation
  0.184s regulated versus 6.931s unregulated; all intersection scenarios passed.
- Initial failures corrected: misplaced drawing helper/untyped test span; fixed
  sampling failed measured angle limits, replaced by adaptive sampling; excessive
  texture/midnight contrast reduced; old no-shadow probes updated for intentional
  solar shadows. Dense platform vertices caused Godot float32 ray false negatives
  even 2px inside an edge (0.001px vertical shifts both returned inside). Platform
  tests now use scalar ray crossings plus exact nearest-boundary distance for the
  complete passenger circle, stronger than four radial probes. Passenger runtime
  behavior was not changed. Large-loop fixture now respects gradual fleet ramp-up.
- Fresh Windows/macOS/Web exports succeeded with no errors/warnings. Verified
  Windows PE x86_64, macOS ZIP integrity, universal x86_64/arm64, strict deep
  codesign, exported Apple Silicon startup (`--headless --quit-after 10
  --audio-driver Dummy`), nonempty Web HTML/JS/WASM/PCK and `git --no-pager diff --check`.
  README/DESIGN/current-state memory updated. No Windows/Intel runtime, browser,
  full native interface or full-network frame-time profiling run. Not committed.

### Centering corner stations on their running curves (2026-11-07)

- Screenshot showed the grid-positioned marker outside the quadratic curve.
  User explicitly chose keeping stations on the grid and moving the curve
  through their centers, rather than moving markers away from interaction data.
  [track_geometry.gd](./scripts/render/track_geometry.gd) now uses station-only
  cubic corner interpolation: 4/3-radius handles preserve approach tangents
  and place the midpoint exactly on the station. Existing 12px station rounding
  footprint, 35% short-segment limit, neighboring endpoints, ordinary 24px
  quadratic bends, lane separation and station markers remain unchanged.
- [editing_smoke.gd](./tests/editing_smoke.gd) measures centering below 0.0001
  world units across 45/90/135-degree turns, eight orientations, reversed paths,
  and actual open/loop circuits. Ordinary bend rounding is explicitly unchanged.
  [train_visual_smoke.gd](./tests/train_visual_smoke.gd) adds day/night corner
  captures, inspected natively for centered opaque markers.
- Passed with `/Applications/Godot.app/Contents/MacOS/Godot`:
  ```
  --headless --path . --script res://tests/editing_smoke.gd --audio-driver Dummy
  --headless --path . --script res://tests/schedule_smoke.gd --audio-driver Dummy
  --headless --path . --script res://tests/loop_smoke.gd --audio-driver Dummy
  --headless --path . --script res://tests/simulation_smoke.gd --audio-driver Dummy
  --headless --path . --script res://tests/terminal_smoke.gd --audio-driver Dummy
  --path . --script res://tests/train_visual_smoke.gd --audio-driver Dummy
  --path . --script res://tests/visual_smoke.gd --audio-driver Dummy
  ```
  Stop/platform clearance, passenger containment/speed, terminal reversals and
  sustained circulation remain valid. Headway deviation 0.193s regulated versus
  7.166s unregulated. README/DESIGN/current-state memory updated.
- Fresh Windows/macOS/Web exports succeeded using the documented commands;
  logs contained no errors/warnings. Verified Windows PE x86_64, macOS ZIP,
  universal x86_64/arm64 binary, strict deep codesign, exported Apple Silicon
  startup (`--headless --quit-after 10 --audio-driver Dummy`), nonempty Web
  HTML/JS/WASM/PCK and `git --no-pager diff --check`.
  Windows/Intel runtime, browser and frame-time profiling were not run.
  Pending station-deletion changes preserved; no commit or push requested.

### Reconnecting station deletion and consistent confirmation (2026-11-07)

- User chose shape-preserving automatic reconnection and identified the delete
  confirmation (not the temporary warning toast) as visually inconsistent.
  [transit_graph.gd](./scripts/sim/transit_graph.gd) joins oriented incident
  anchors per serving line before removal/remapping, without creating fragments
  or arbitrary connections between interchange branches. Existing neighbor
  tracks are reused without altering other lines. Terminals trim their line;
  loops stay closed with three or more stations, otherwise use the surviving
  open track. Physical track deletion still splits lines and preserves settings.
- [world_view.gd](./scripts/render/world_view.gd) now shows the existing rail
  delete x even when hovering a bend. Pointer-approach/cancel tests cover
  zoom 0.5/1/2/5. [main.gd](./scripts/main.gd) uses action-specific confirmation
  text, wrapped to fit a 360px viewport, in a borderless rectangular paper card
  with matching rectangular buttons. AcceptDialog theme constants preserve
  112px minimum button width and 44px height. Temporary warning styling unchanged.
  README, DESIGN and English/French translations updated.
- Validation passed with `/Applications/Godot.app/Contents/MacOS/Godot`:
  ```
  --headless --path . --script res://tests/editing_smoke.gd --audio-driver Dummy
  --path . --script res://tests/editing_smoke.gd --audio-driver Dummy
  --headless --path . --script res://tests/loop_smoke.gd --audio-driver Dummy
  --headless --path . --script res://tests/interface_smoke.gd --audio-driver Dummy
  --headless --path . --script res://tests/localization_smoke.gd --audio-driver Dummy
  --headless --path . --script res://tests/simulation_smoke.gd --audio-driver Dummy
  ```
  Editing covers shared/reversed reconnections, retained bend anchors, branching
  interchanges, endpoints, existing rails and minimum loop size. Simulation
  verifies resumed service/full-train spacing after deleting an inserted stop.
  Native confirmation capture inspected: no mixed window chrome/pill corners.
- Initial import/test found an inferred untyped array parse error; explicitly
  typed station order fixed it. A geometry assertion needed the retained former
  station anchor. Narrow-screen testing found AcceptDialog overwrites button
  minimum sizes; theme constants fixed the measured 44px height. Final tests
  above passed after these corrections.
- Fresh Windows/macOS/Web releases succeeded with the documented export
  commands, no log errors/warnings. Verified `file dist/Metro.exe`,
  `unzip -t dist/Metro-macOS.zip`, nonempty Web HTML/JS/WASM/PCK, universal
  x86_64/arm64 macOS binary, `codesign --verify --deep --strict`, and exported
  Apple Silicon startup (`--headless --quit-after 10 --audio-driver Dummy`).
  `git --no-pager diff --check` passed. No Windows/Intel runtime, browser,
  full native interface suite or profiling run. Changes not committed or pushed.

### Committing accumulated train, platform and interaction refinements (2026-11-07)

- User requested committing the pending changes together: terminal reversal,
  station clearances, platform/passenger simulation and visuals, local reshape
  anchors/feedback, station-handle priority, inline add-line action, proportions,
  night glow, translations, regression tests and terminal CI coverage.
- Fresh releases used the documented `godot --headless --path . --export-release`
  commands for Windows Desktop, macOS and Web. First macOS export reported an
  unreadable transient `dist/Metro.app` icon while packing; repeating the exact
  macOS command completed without errors/warnings. Windows/Web logs were clean.
- Verified `file dist/Metro.exe`, `unzip -t dist/Metro-macOS.zip`, nonempty Web
  HTML/JS/WASM/PCK, universal macOS x86_64/arm64, strict deep codesign and exported
  Apple Silicon startup with `--headless --quit-after 10 --audio-driver Dummy`.
  `git --no-pager diff --check` passed. No additional tests were rerun for this
  commit-only task; prior validation remains recorded below. Windows/Intel
  runtime and browser checks remain unrun. No push requested.

### Uniform merged glow, replacing distorted stroke joins (2026-11-07)

- User rejected continued inner folds and weird curved glow. Removed Line2D
  width profiles in [world_view.gd](./scripts/render/world_view.gd). Rounded
  `Geometry2D.offset_polyline` outlines resolve self-overlap before rendering as
  cached Polygon2D layers of constant 30/22/14px width. Closed-loop holes are
  split through their center before subtraction to produce simple polygons.
  Per-vertex junction fades and live recolor/night opacity remain.
- Expanded [train_visual_smoke.gd](./tests/train_visual_smoke.gd) with actual
  offset S-bends: halo boundaries stay within 15.1px of the lane, coverage never
  stacks within a layer, and loop interiors remain unlit. Tight-radius outlines
  triangulate cleanly. Native S-bend capture inspected: even bands, no wedge
  spikes or changing-width shoulders. README/DESIGN/current-state memory updated.
- Native train_visual and visual tests passed using
  `/Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tests/train_visual_smoke.gd --audio-driver Dummy`
  and the same command with `res://tests/visual_smoke.gd`.
- Fresh Windows/macOS/Web release exports succeeded using the documented
  export commands; all three logs had no errors/warnings. Windows PE x86_64,
  nonempty Web HTML/JS/WASM/PCK, macOS ZIP integrity, universal x86_64/arm64,
  `codesign --verify --deep --strict` and Apple Silicon exported startup
  (`--headless --quit-after 10 --audio-driver Dummy`) verified.
  `git --no-pager diff --check` passed.
- Exact user screenshot topology was approximated, not reconstructed; no
  Windows/Intel runtime, browser run or frame-time profiling this task.
  Dispatch/passenger/UI suites were not rerun for this rendering-only fix.

### Preventing inner-bend glow folds (2026-11-07)

- User screenshot showed a folded luminous wedge inside a tight running-lane
  bend after round joins fixed the outside corners. Added cached per-layer
  curvature width profiles in [world_view.gd](./scripts/render/world_view.gd):
  halo half-width stays below 80% of the local circumcircle radius. Profiles
  interpolate linearly and wrap closed-lane neighbors. No change to running
  paths, rail cores, passengers, UI, straight widths or junction fading.
- [train_visual_smoke.gd](./tests/train_visual_smoke.gd) verifies a 4px-radius
  bend limits the 30px halo below a 3.3px half-width and straight rails retain
  full width. Native train_visual and visual smoke passed using
  `/Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tests/train_visual_smoke.gd --audio-driver Dummy`
  and the same command with `res://tests/visual_smoke.gd`.
  README/DESIGN updated.
- Fresh exports passed with `/Applications/Godot.app/Contents/MacOS/Godot`:

  ```sh
  --headless --path . --export-release "Windows Desktop" dist/Metro.exe
  --headless --path . --export-release "macOS" dist/Metro-macOS.zip
  --headless --path . --export-release "Web" dist/web/index.html
  unzip -t dist/Metro-macOS.zip
  file dist/Metro.exe
  test -s dist/web/index.html
  test -s dist/web/index.js
  test -s dist/web/index.wasm
  test -s dist/web/index.pck
  git diff --check
  ```

  No export errors/warnings. Extracted universal x86_64/arm64 app passed
  `codesign --verify --deep --strict` and executable startup
  `--headless --quit-after 10 --audio-driver Dummy`. Ad-hoc, not notarized.
  Temporary captures/export logs/extracted app cleaned. Exact screenshot network
  not reproduced; coverage uses tight synthetic curvature and existing native
  round-corner pixel/visual fixtures. Windows/Intel/browser runtime, full traffic
  suite and frame-time profiling not rerun for this renderer-only change.
  No commit/push.

### Final train, glow, line-action and platform refinements (2026-11-07)

- User approved lengthening every car including cabs by exactly 10%.
  [track_geometry.gd](./scripts/render/track_geometry.gd) now uses length 19.8,
  pitch 20.8 (unchanged gap 1) and `CAR_SCALE`; renderer, doors, headlamp sources,
  gangway attachments, safety, terminal fit, stop clearance and platforms agree.
- [world_view.gd](./scripts/render/world_view.gd) builds cached Line2D halo layers
  with round joints/caps and precision 24, replacing overlapping thick primitive
  joins that exposed square light corners. Closed loops close their halo seam.
  Junction gradients and bounded widths remain; recoloring refreshes halo colors
  without rebuilding dispatch. Night opacity follows the existing phase.
- [main.gd](./scripts/main.gd) moves add-line into the scrolling tab row after
  the last numbered tab, with the same underline/paper style and 44px minimum
  target. Selection/recolor loops distinguish the action from toggled line tabs.
  Last-line reveal includes the adjacent + when space permits; collapse stays fixed.
- [station_visit.gd](./scripts/sim/station_visit.gd) uses four smoothing passes
  and stricter paired collinearity simplification, preserving smooth curves
  rather than cutting visible facets. Passenger inset increased to radius + 0.2
  using miter joins after exact containment tests exposed concave-edge clipping
  on the denser outline. Paths and bounded passenger timing remain unchanged.
- Updated native train probes for shared dimensions; exact 10% length, one-unit
  spacing and <8-degree platform edge turns pass. A synthetic sharp-corner
  pixel test verifies glow absent outside the round radius but present beside
  straight rails; native captures inspected. Added inline + adjacency/style/
  actual creation tests and updated line-child counts to include the action.
  README/DESIGN/current-state memory updated.
- Initial tests had stale cab/door pixel coordinates and tab child assumptions;
  corrected to actual scaled locations and pressed-tab identity. Added UI test
  variable redeclaration/type inference parse errors corrected. Native full
  interface run stalled without output and was stopped; headless version passed
  before final follow-up checks.
- Final successful commands used `/Applications/Godot.app/Contents/MacOS/Godot`:

  ```sh
  --headless --path . --script res://tests/interface_smoke.gd
  --headless --path . --script res://tests/terminal_smoke.gd
  --headless --path . --script res://tests/schedule_smoke.gd
  --headless --path . --script res://tests/simulation_smoke.gd
  --headless --path . --script res://tests/editing_smoke.gd
  --headless --path . --script res://tests/loop_smoke.gd
  --headless --path . --script res://tests/train_controls_smoke.gd
  --headless --path . --script res://tests/localization_smoke.gd
  --headless --path . --script res://tests/intersection_smoke.gd
  --path . --script res://tests/train_visual_smoke.gd --audio-driver Dummy
  --path . --script res://tests/visual_smoke.gd --audio-driver Dummy
  --headless --path . --export-release "Windows Desktop" dist/Metro.exe
  --headless --path . --export-release "macOS" dist/Metro-macOS.zip
  --headless --path . --export-release "Web" dist/web/index.html
  unzip -t dist/Metro-macOS.zip
  file dist/Metro.exe
  test -s dist/web/index.html
  test -s dist/web/index.js
  test -s dist/web/index.wasm
  test -s dist/web/index.pck
  git diff --check
  ```

  Headway deviation 0.181s regulated vs 6.864s unregulated. All six-minute
  intersection fixtures retained safe gaps/service; final arrivals perpendicular
  [110,110], shared terminal/through [88,42], shared segment [118,118], unequal
  speeds [110,110,74], busy terminal [31], screenshot layout [144,146].
  Final Windows/macOS/Web exports and asset checks passed without log errors/
  warnings. Universal x86_64/arm64 extracted app passed
  `codesign --verify --deep --strict` and startup
  `--headless --quit-after 10 --audio-driver Dummy`. Ad-hoc, not notarized.
  Temporary screenshots/export logs/extracted verification app cleaned.
  Full native interface smoke stalled and was stopped; only headless UI checks
  completed. Windows/Intel/browser execution and frame-time/audio profiling
  not rerun. No commit/push.

### Broader platform walks without faster passengers (2026-11-07)

- User found constrained passengers too close to the train. Extended the cached
  platform-contained paths in [station_visit.gd](./scripts/sim/station_visit.gd)
  across the pavement with more sideways spread. Separate visual walk timing
  lets alighters continue after exiting and boarders approach before their batch,
  retaining 4px/s peak speed, unchanged occupancy/dwell and platform containment.
  README/DESIGN updated. Schedule tests now measure visual timing, require
  >=2.5px platform walks and verify added walking time rather than added speed.
- Final successful commands used `/Applications/Godot.app/Contents/MacOS/Godot`:

  ```sh
  --headless --path . --script res://tests/schedule_smoke.gd
  --path . --script res://tests/train_visual_smoke.gd --audio-driver Dummy
  --headless --path . --export-release "Windows Desktop" dist/Metro.exe
  --headless --path . --export-release "macOS" dist/Metro-macOS.zip
  --headless --path . --export-release "Web" dist/web/index.html
  unzip -t dist/Metro-macOS.zip
  file dist/Metro.exe
  test -s dist/web/index.html
  test -s dist/web/index.js
  test -s dist/web/index.wasm
  test -s dist/web/index.pck
  git diff --check
  ```

  Schedule/body containment/peak-speed tests and native day/night visuals passed;
  inspected the broader platform crowd capture. Headway deviation remains
  0.181s regulated vs 6.944s unregulated. All three exports passed without
  errors/warnings; extracted universal x86_64/arm64 macOS app passed
  `codesign --verify --deep --strict` and startup
  `--headless --quit-after 10 --audio-driver Dummy`. Ad-hoc, not notarized.
  Temporary screenshots/export logs/extracted app cleaned. Windows/Intel/browser
  execution, full traffic suite and frame-time/audio profiling not rerun for
  this visual-timing change. No commit/push.

### Platform-contained, slower passengers (2026-11-07)

- User found passengers too fast/far-reaching and requested platform containment.
  [station_visit.gd](./scripts/sim/station_visit.gd) now caches short segments
  inside an inset walking polygon, including body clearance on corner platforms.
  Individual profiles keep timing and queue scatter, but walking distance scales
  with available time to cap smoothstep peak speed at 4 world units/s. Boarders
  fade at the platform-side door area; alighters stop and fade on the platform,
  without continued escape into the map. Occupancy, exchanges, recovery and
  the exact two-second extra-dwell bound are unchanged.
- [schedule_smoke.gd](./tests/schedule_smoke.gd) checks whole-body containment
  at five points per path for 1-6 wagons on open/loop curved platforms, measured
  speed, fade-in-place, and peak speed at minimum dwells 0/3/12 seconds.
  README/DESIGN and current-state memory updated. Initial added test reused
  an enclosing iterator name; corrected the parse error and reran successfully.
- Final validations used `/Applications/Godot.app/Contents/MacOS/Godot`:

  ```sh
  --headless --path . --script res://tests/schedule_smoke.gd
  --path . --script res://tests/train_visual_smoke.gd --audio-driver Dummy
  --headless --path . --export-release "Windows Desktop" dist/Metro.exe
  --headless --path . --export-release "macOS" dist/Metro-macOS.zip
  --headless --path . --export-release "Web" dist/web/index.html
  unzip -t dist/Metro-macOS.zip
  file dist/Metro.exe
  test -s dist/web/index.html
  test -s dist/web/index.js
  test -s dist/web/index.wasm
  test -s dist/web/index.pck
  git diff --check
  ```

  All passed. Peak-speed probe initially used subpixel deltas at large world
  coordinates and failed from float precision; use a wider midpoint interval
  plus the exact smoothstep derivative to verify the same 4px/s threshold.
  Headway deviation stays 0.181s regulated vs 6.944s unregulated. Native
  daytime platform capture inspected; people remain on pavement, not in the map.
  Windows/macOS/Web releases refreshed without log errors/warnings. Extracted
  universal x86_64/arm64 app passed `codesign --verify --deep --strict` and
  executable startup `--headless --quit-after 10 --audio-driver Dummy`.
  Ad-hoc signed, not notarized. Temporary screenshots, export logs and extracted
  verification app cleaned. Windows/Intel/browser runtime, full intersection
  suite and audio/frame-time profiling not rerun for this animation-only change.
  No commit/push.

### Smooth corner platforms and approach-side stops everywhere (2026-11-07)

- User rejected stepped corner platforms. [station_visit.gd](./scripts/sim/station_visit.gd)
  now guides the ribbon through car centers rather than every car end, with
  unchanged first/last caps. Paired uniform samples, weighted local averaging
  and two smoothing passes produce continuous curved inner/outer/safety edges.
  Paving joints and tactile points follow arc distance along those same edges.
  A single polygon union resolves folds; replacing repeated triangle unions
  avoids doing clipping for every finely sampled segment.
- User explicitly chose stop-before-every-station, while allowing trains to
  pass underneath in motion. [track_geometry.gd](./scripts/render/track_geometry.gd)
  shares radius-aware clearance across termini, intermediate stops and both
  loop directions. Intermediate/loop projections move backwards to the
  approach-side clearance circle. Rails, caps, edit anchors, circulation paths
  and terminal reversal metadata remain unchanged.
- Updated [simulation_smoke.gd](./tests/simulation_smoke.gd) and
  [loop_smoke.gd](./tests/loop_smoke.gd) with measured clearance/approach checks.
  [schedule_smoke.gd](./tests/schedule_smoke.gd) checks all car corners and all
  platform edges clear their visited marker for 1-6 wagons, open/loop directions.
  Its cross-line independence baseline now has an inactive membership marker,
  matching the shared station's ring radius; actual crossing trains must still
  produce identical motion. Larger ring clearance intentionally shifts stops.
  [train_visual_smoke.gd](./tests/train_visual_smoke.gd) measures <25-degree local
  turns on corner platform/safety edges; inspected the smooth native capture.
  README/DESIGN and current-state memory updated.
- Initial endpoint smoothing still retained 52-degree kinks; the new
  center-guided ribbon passes the same threshold. Original independence test
  failed because an extra serving line grows the marker and changes its stop;
  corrected the baseline geometry, not the no-cross-line-authority invariant.
  Superseded long schedule runs were stopped before rerunning final code.
- Successful commands used `/Applications/Godot.app/Contents/MacOS/Godot`:

  ```sh
  --headless --path . --script res://tests/simulation_smoke.gd
  --headless --path . --script res://tests/loop_smoke.gd
  --headless --path . --script res://tests/editing_smoke.gd
  --headless --path . --script res://tests/train_controls_smoke.gd
  --headless --path . --script res://tests/schedule_smoke.gd
  --headless --path . --script res://tests/terminal_smoke.gd
  --headless --path . --script res://tests/intersection_smoke.gd
  --path . --script res://tests/train_visual_smoke.gd --audio-driver Dummy
  --path . --script res://tests/visual_smoke.gd --audio-driver Dummy
  --headless --path . --export-release "Windows Desktop" dist/Metro.exe
  --headless --path . --export-release "macOS" dist/Metro-macOS.zip
  --headless --path . --export-release "Web" dist/web/index.html
  unzip -t dist/Metro-macOS.zip
  file dist/Metro.exe
  test -s dist/web/index.html
  test -s dist/web/index.js
  test -s dist/web/index.wasm
  test -s dist/web/index.pck
  git diff --check
  ```

  All exports passed without log errors/warnings. Extracted universal
  x86_64/arm64 app passed `codesign --verify --deep --strict` and executable
  startup `--headless --quit-after 10 --audio-driver Dummy`.
  Ad-hoc signing, not notarization. Final schedule/terminal/intersection tests
  passed without errors. Headway deviation remains 0.181s regulated vs 6.944s
  unregulated; all six-minute traffic fixtures retained safe moving-block gaps
  and service. Final arrivals: perpendicular [110,110], shared terminal/through
  [88,42], nearby/shared segment [118,118], unequal speeds [110,110,74],
  busy termini [30], screenshot layout [144,146]. Temporary screenshots,
  export logs and extracted verification app were cleaned.
  Windows/Intel/browser execution, audio and
  frame-time profiling not run. No commit/push.

### Finished platform detail, livelier crowds and connect priority (2026-11-07)

- Improved [station_visit.gd](./scripts/sim/station_visit.gd) and
  [world_view.gd](./scripts/render/world_view.gd): kept one continuous platform
  and terminal clearance, added concrete finish, subtle pavement joints,
  perimeter/inner edging and a warm continuous tactile strip. Cached dots/joints
  stay within the curved platform. Passenger bodies shrink from 0.48 to 0.34;
  fuller exchanges and 12 places per car replace the sparse six-place flow.
  Per-visit seeded profiles scatter queues and vary starts, walking speeds,
  sideways paths and dispersal. Coats/skin vary; day/night contrast remains.
  Individual completion drives occupancy; descending still precedes boarding,
  with the same exact maximum two-second extension and independent recovery.
- Follow-up user report: existing rightward rails stole the station connect +
  when attempting to connect left. [main.gd](./scripts/main.gd) now prioritizes
  a hovered station's center-to-handle corridors before rail/bend popup retention.
  General station hover halos do not capture short rails; direct rail insertion
  and nearest physical station centers retain their intended behavior.
- Expanded [schedule_smoke.gd](./tests/schedule_smoke.gd) for denser counts,
  measurable timing/queue spread, deterministic profiles, bounded occupancy,
  fade expiry and platform detail containment.
  [train_visual_smoke.gd](./tests/train_visual_smoke.gd) measures smaller people
  and distinct tactile edges by day/night; inspected both native captures.
  [editing_smoke.gd](./tests/editing_smoke.gd) walks center-to-connect paths at
  zoom 0.5/1/2/5, then actually completes a left connection while retaining the
  original rightward rail and all station IDs. README/DESIGN updated.
- Successful commands used `/Applications/Godot.app/Contents/MacOS/Godot`:

  ```sh
  --headless --path . --script res://tests/schedule_smoke.gd
  --headless --path . --script res://tests/terminal_smoke.gd
  --headless --path . --script res://tests/intersection_smoke.gd
  --headless --path . --script res://tests/editing_smoke.gd
  --headless --path . --script res://tests/simulation_smoke.gd
  --headless --path . --script res://tests/train_controls_smoke.gd
  --headless --path . --script res://tests/loop_smoke.gd
  --path . --script res://tests/train_visual_smoke.gd --audio-driver Dummy
  --path . --script res://tests/visual_smoke.gd --audio-driver Dummy
  --headless --path . --export-release "Windows Desktop" dist/Metro.exe
  --headless --path . --export-release "macOS" dist/Metro-macOS.zip
  --headless --path . --export-release "Web" dist/web/index.html
  unzip -t dist/Metro-macOS.zip
  file dist/Metro.exe
  test -s dist/web/index.html
  test -s dist/web/index.js
  test -s dist/web/index.wasm
  test -s dist/web/index.pck
  git diff --check
  git status --short
  ```

  Regulated headway deviation is 0.181s vs 6.944s unregulated with the fuller
  exchanges. Initial dwell assertion exposed floating-point equality at the
  two-second cap; its inequality now allows 0.000001s precision. Timing test
  initially sampled after the first batch finished, and direct-insertion test
  used the visible station approach; corrected probes to test the intended cases.
- Final Windows/macOS/Web builds and nonempty assets passed without export
  errors/warnings. Extracted app passed universal x86_64/arm64 inspection,
  `codesign --verify --deep --strict` and executable startup
  `--headless --quit-after 10 --audio-driver Dummy`. Ad-hoc, not notarized.
  Git now works again; final whitespace/status checks passed, superseding the
  earlier Xcode blocker. Full six-minute intersection fixtures passed with
  sustained arrivals and moving-block gaps: perpendicular [110,110], shared
  terminal/through [88,42], shared segment [118,118], three speeds [110,110,74],
  busy terminals [30], screenshot layout [130,146]. Extra boarding time slightly
  reduces throughput as intended, without deadlocks. Temporary screenshots,
  export logs and extracted verification app were cleaned.
  Windows/Intel/browser execution, subjective real-time crowd observation and
  audio/frame-time profiling not run. No commit or push.

### Outside-terminal stops and restrained junction illumination (2026-11-07)

- User clarified that terminal trains should stop slightly outside the marker,
  not move platforms above stations. Kept opaque station layering, normal caps,
  sharper routes and in-place reversal. Terminal offsets follow each serving-line
  radius, with a 3px cab gap; increased shared-track fit accordingly.
  Reversal authority and cycle estimates use the same terminal-specific jump,
  preserving physical car positions at both ends, including unequal ring counts.
- [track_geometry.gd](./scripts/render/track_geometry.gd) and
  [dispatcher.gd](./scripts/dispatch/dispatcher.gd) own the new stop/jump metadata.
  [world_view.gd](./scripts/render/world_view.gd) clips nighttime rail cores and
  halos at shared stations, with a smooth 16px return rather than abrupt lit ends.
  Cached paths/strengths refresh with geometry, not each frame; base colors,
  daytime rails, headlights and simulation remain unchanged.
- Expanded [terminal_smoke.gd](./tests/terminal_smoke.gd) to verify full platform
  edges clear terminal markers by >2.5px, cab clearance, and <0.02px reversal
  continuity for 1-6 wagons on horizontal/vertical/bent paths and independently
  sized shared terminals. [train_visual_smoke.gd](./tests/train_visual_smoke.gd)
  checks visible stopped cars/platforms, excluded illumination geometry and native
  junction pixels. [simulation_smoke.gd](./tests/simulation_smoke.gd) now limits
  station-center projections to intermediate stops. README/DESIGN updated.
- Successful validations used `/Applications/Godot.app/Contents/MacOS/Godot`:

  ```sh
  --headless --path . --script res://tests/terminal_smoke.gd
  --headless --path . --script res://tests/schedule_smoke.gd
  --headless --path . --script res://tests/simulation_smoke.gd
  --headless --path . --script res://tests/intersection_smoke.gd
  --headless --path . --script res://tests/loop_smoke.gd
  --headless --path . --script res://tests/train_controls_smoke.gd
  --headless --path . --script res://tests/editing_smoke.gd
  --path . --script res://tests/train_visual_smoke.gd --audio-driver Dummy
  --path . --script res://tests/visual_smoke.gd --audio-driver Dummy
  ```

  Terminal/schedule/simulation and all six-minute intersection scenarios passed;
  headway deviation remains 0.119s regulated vs 6.572s unregulated. Initial
  added-test constructor arguments caused a parser failure; corrected. The
  feathering pass exposed conditional typed-array assignment at runtime; fixed
  with packed float widths and reran native tests without errors.
- Final Windows/macOS/Web release exports succeeded using the same Godot binary:

  ```sh
  --headless --path . --export-release "Windows Desktop" dist/Metro.exe
  --headless --path . --export-release "macOS" dist/Metro-macOS.zip
  --headless --path . --export-release "Web" dist/web/index.html
  unzip -t dist/Metro-macOS.zip
  file dist/Metro.exe
  test -s dist/web/index.html
  test -s dist/web/index.js
  test -s dist/web/index.wasm
  test -s dist/web/index.pck
  ```

  All passed; export logs contain no errors/warnings. The extracted app passed
  `file` universal x86_64/arm64 inspection, `codesign --verify --deep --strict`
  and executable startup `--headless --quit-after 10 --audio-driver Dummy`.
  Ad-hoc signed, not notarized. Native final terminal and perpendicular-junction
  captures were inspected; bright cross arms are suppressed with smooth fades,
  and the full stopped platform/cars remain clear. Temporary verification app,
  captures and export logs were cleaned.
- `git diff --check` and `git status --short` remain blocked by the Xcode license
  (exit 69).
  Windows/Intel/browser execution and audio/frame-time profiling not rerun.
  No commit or push.

### Opaque stations, reversing terminals and stronger night visuals (2026-11-07)

- User rejected faded station markers. Restored the opaque white center and
  dark concentric rings in [world_view.gd](./scripts/render/world_view.gd).
  Removed the opacity pass and fading-specific tests. Local reshape anchors
  and short-rail controls remain unchanged; the prior fade decision is superseded.
- User chose stop-and-reverse with visible two-lane convergence into a shared,
  one-train-protected terminal. [track_geometry.gd](./scripts/render/track_geometry.gd)
  merges lanes onto a center track long enough for the full train, bounded
  before adjacent stations. No track extends past the station. The distance
  circuit retraces that terminal path; [dispatcher.gd](./scripts/dispatch/dispatcher.gd)
  originally switched logical head by wagon span while stopped (terminal
  stand-off now adds twice the inset; see the newer entry), after validating
  clearance. All physical car centers remain in place when cabs switch.
  `car_axis` handles the cusp for roofs, cab lights, gangways and visit doors.
- Dispatcher terminal owners gate entry before braking distance and hold until
  the tail clears with safety margin; pause/rebuild/retirement preserve or clear
  ownership appropriately. Other lines and loops remain independent.
  Cycle-time estimates subtract reversal jumps. Short lines unable to clear
  one terminal before the opposing entry are capped at one train, avoiding
  deadlock; insufficient terminal fit explicitly reports localized guidance
  rather than silently failing to dispatch. Wagon increases validate fit.
- User chose 50% longer cars (not wider) and very dark night with pronounced
  rail/headlamp glow. Car length/pitch are now 18/19px, width remains 7px.
  Body/door geometry, gangway attachments, platforms, clearance and capacity
  use the new proportions. Compressed gangways draw two ribbon triangles to
  avoid failed polygon triangulation on tight curves.
- [urban_backdrop.gd](./scripts/render/urban_backdrop.gd) uses near-black blue
  midnight (#03060c), retaining white noon and smooth dawn/dusk. Renderer adds
  a 1.2px luminous rail core and bounded 30/22/14px layered colored halo at
  night only, plus local headlamp glow and stronger fading beams. No HDR/glow
  environment dependency; native/Web Compatibility remains supported.
  Opaque paper UI keeps contrast; idle opacity interpolates from 28% day to
  70% dark night. Updated README/DESIGN, localization and current-state memory.
- Added [terminal_smoke.gd](./tests/terminal_smoke.gd) and wired it into Pages CI.
  It verifies physical car continuity (<0.02px) at cab switches, actual smooth
  departures, nonzero terminal axes, one-train reservations, moving gaps and
  sustained service for 1-6 wagons on horizontal/vertical/bent routes, plus
  short-line deadlock prevention and pause/rebuild cleanup.
- Initial native run caught a duplicated local `night` variable; fixed it.
  Longer cars exposed a folded-gangway triangulation error; fixed the ribbon
  rendering and reran without errors. Existing tests assumed globally separate
  lanes and unlit nights; updated probes to check separation outside shared
  terminal zones and explicit night-only core/halo bounds. Refined midnight
  until native background luminance was <=0.04. Inspected nighttime network,
  headlamp/long-car and opaque terminal captures.
- Final successful commands used `/Applications/Godot.app/Contents/MacOS/Godot`:

  ```sh
  --headless --path . --script res://tests/terminal_smoke.gd
  --headless --path . --script res://tests/schedule_smoke.gd
  --headless --path . --script res://tests/intersection_smoke.gd
  --headless --path . --script res://tests/editing_smoke.gd
  --headless --path . --script res://tests/interface_smoke.gd
  --headless --path . --script res://tests/simulation_smoke.gd
  --headless --path . --script res://tests/loop_smoke.gd
  --headless --path . --script res://tests/train_controls_smoke.gd
  --headless --path . --script res://tests/localization_smoke.gd
  --headless --path . --script res://tests/urban_smoke.gd
  --path . --script res://tests/visual_smoke.gd --audio-driver Dummy
  --path . --script res://tests/train_visual_smoke.gd --audio-driver Dummy
  --path . --script res://tests/interface_smoke.gd --audio-driver Dummy
  --path . --script res://tests/urban_smoke.gd --audio-driver Dummy
  --headless --path . --export-release "Windows Desktop" dist/Metro.exe
  --headless --path . --export-release "macOS" dist/Metro-macOS.zip
  --headless --path . --export-release "Web" dist/web/index.html
  ```

- Headway standard deviation remains 0.119s regulated versus 6.572s unregulated;
  all six-minute intersection fixtures preserve gaps and sustained arrivals.
  Final terminal/schedule/editing/train-control tests include the short-line
  capacity fix. Windows/macOS/Web exports succeeded without logged errors or
  warnings. `unzip -t dist/Metro-macOS.zip`, Windows x86_64 PE, nonempty Web
  assets, universal macOS x86_64/arm64, `codesign --verify --deep --strict`,
  and exported Apple Silicon startup (`--headless --quit-after 10 --audio-driver Dummy`)
  passed. Ad-hoc signing, not notarization.
- Final `git diff --check` and Git status/stat were blocked by the unaccepted
  Xcode license (exit 69); no standalone Git was installed. Earlier Git checks
  passed before this environment change, but do not count as final validation.
  User must accept the license with `sudo xcodebuild -license` to restore Git.
  Windows/Intel/browser runtime, audio and frame-time profiling not rerun.
  No commit/push/deploy; previous train/platform/reshape work remains pending.

### Local reshape anchors and fading station markers (fading superseded, 2026-11-07)

- Fixed the section popup's whole-track rewrite in
  [main.gd](./scripts/main.gd): retain the selected guide segment index, rebuild
  only between its adjacent anchors, and preserve all outside waypoints.
  Existing bend handles still use their two neighbors. Protected simplification
  and `TrackGeometry.anchors` keep explicit anchors even when made collinear.
  [world_view.gd](./scripts/render/world_view.gd) marks the fixed anchors.
- Short sections were obscured by station hover halos and along-rail vertical
  popups. Popups now sit perpendicular to their segment, retain their capsule
  hover corridor, and take priority over broad station halos. Physical station
  centers and visible station handles remain usable; overlapping hidden handles
  are resolved by distance to the rail's grid anchor. Repeated bend picks retain
  bend identity rather than falling through to insertion.
- Grid-stationary edits explain snapping; rejected edits show their exact reason
  beside the dragged point, not the distant terminus. Captions wrap at 16 logical
  pixels instead of shrinking/truncating. Added localized grid guidance and
  actionable train-length wording in [ui.csv](./translations/ui.csv).
  No-change releases avoid redispatch. Hover now uses cached event coordinates,
  fixing frame-to-frame OS-pointer disagreement exposed by real-input tests.
- User chose fading station markers, not drawing trains on top. Spatial opacity
  considers every oriented car body, fades fill/rings down to 20%, and recovers
  after the full train clears. Rings use nonoverlapping arcs to avoid stacking
  transparency below the center. Stop simulation, passengers and picking unchanged.
  Updated README/DESIGN and current-state memory.
- Initial tests caught bend identity loss, fixed anchors removed by collinear
  simplification, and OS hover-coordinate disagreement; corrected each.
  Test snapshots needed explicit packed-array duplication. Opaque-station pixel
  fixtures now omit trains; fixed visual fixtures disable incidental OS input.
  Fade recovery probes include the compact terminal turn before asserting full
  opacity. A failed loop fixture stalled after a script error and was stopped.
  One later native interface repeat stalled without errors; stopped and reran
  in isolation successfully. No success claims rely on either stopped run.
- Final validations passed with `/Applications/Godot.app/Contents/MacOS/Godot`:

  ```sh
  --headless --editor --path . --quit
  --headless --path . --script res://tests/editing_smoke.gd
  --headless --path . --script res://tests/interface_smoke.gd
  --headless --path . --script res://tests/simulation_smoke.gd
  --headless --path . --script res://tests/loop_smoke.gd
  --headless --path . --script res://tests/train_controls_smoke.gd
  --headless --path . --script res://tests/schedule_smoke.gd
  --headless --path . --script res://tests/localization_smoke.gd
  --path . --script res://tests/visual_smoke.gd --audio-driver Dummy
  --path . --script res://tests/interface_smoke.gd --audio-driver Dummy
  --path . --script res://tests/train_visual_smoke.gd --audio-driver Dummy
  --path . --script res://tests/editing_smoke.gd --audio-driver Dummy
  --headless --path . --export-release "Windows Desktop" dist/Metro.exe
  --headless --path . --export-release "macOS" dist/Metro-macOS.zip
  --headless --path . --export-release "Web" dist/web/index.html
  ```

  `unzip -t dist/Metro-macOS.zip`, `file dist/Metro.exe`, nonempty Web assets,
  universal x86_64/arm64 Mach-O, `codesign --verify --deep --strict`, exported
  Apple Silicon startup (`--headless --quit-after 10 --audio-driver Dummy`)
  and `git diff --check` passed. Export logs had no errors/warnings.
- Coverage: short horizontal/vertical/diagonal sections at zoom 0.5/1/2/5,
  local preview/commit/cancel, collinear anchor retention, length rejection,
  complete grid guidance, station-center priority and actual mouse input.
  Native train pixels verify station transparency day/night at map/follow zoom,
  multi-line rings, last-wagon influence and smooth opacity recovery. Inspected
  anchored-reshape and station-fade captures. Regulated headway deviation remains
  0.119s versus 6.572s unregulated.
- Windows/Intel/browser runtime, full intersections/audio/urban suites and
  frame-time profiling not rerun. macOS ad-hoc signed, not notarized.
  No commit/push/deploy; earlier train/platform work remains pending too.

### Restored routes and continuous curved platforms (2026-11-07)

- User rejected the station-berth geometry and invisible turnbacks. Restored
  [track_geometry.gd](./scripts/render/track_geometry.gd) exactly to commit
  `2c79f51`; restored original rail/train picking and always-visible cars.
  This supersedes the four geometry/visibility experiments below, including
  centered stops and special last-car-origin alignment. Normal terminal caps
  and compact turns are retained, not expanded into hidden straight paths.
- Kept the improved trainsets and bounded passenger exchanges. In
  [station_visit.gd](./scripts/sim/station_visit.gd), union overlapping ribbon
  triangles into one curve-following platform outline; draw once in
  [world_view.gd](./scripts/render/world_view.gd). No rectangular requirement or
  automatic route reshaping. Updated README/DESIGN and current-state memory.
- Initial polygon unions failed on exactly shared clipping edges; winding
  normalization and 0.02-world-unit overlap fixed the failures. One graphical
  diagnostic stalled and was explicitly stopped. Final tests verify renderable
  connected platforms and coverage beside every car at all stops, open/loop
  routes, both directions and 1-6 wagons. Native pixels verify inter-car gap
  coverage, terminal movement visibility and platform/passenger fade/zoom.
  Inspected the curved-platform capture with differently angled cars.
- Passed these exact commands (Godot 4.7.2):

  ```sh
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/schedule_smoke.gd
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/editing_smoke.gd
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/simulation_smoke.gd
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/loop_smoke.gd
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/train_controls_smoke.gd
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/intersection_smoke.gd
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/localization_smoke.gd
  /Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tests/train_visual_smoke.gd --audio-driver Dummy
  /Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tests/visual_smoke.gd --audio-driver Dummy
  /Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tests/interface_smoke.gd --audio-driver Dummy
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "Windows Desktop" dist/Metro.exe
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "macOS" dist/Metro-macOS.zip
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "Web" dist/web/index.html
  unzip -t dist/Metro-macOS.zip
  file dist/Metro.exe
  git diff --check
  ```

- Schedule deviation 0.119s regulated versus 6.572s unregulated. All six-minute
  intersection fixtures retain full-train gaps and sustained arrivals.
  Fresh Windows/macOS/Web exports succeeded without logged warnings/errors.
  Verified nonempty Web assets, Windows PE x86_64, macOS universal x86_64/arm64,
  `codesign --verify --deep --strict` and exported Apple Silicon startup
  `--headless --quit-after 10 --audio-driver Dummy`. Ad-hoc signed, not notarized.
  Windows/Intel/browser runtime, audio/urban suites and frame-time profiling
  not rerun. Changes remain uncommitted; no push/deploy.

### Hidden terminal trains rendering fix (superseded, 2026-11-07)

- Screenshot showed cars floating beyond a visible terminal, not an actual
  closed-loop route. Restored caps hid simulation extensions but car/gangway/
  headlight rendering still used the entire circuit. Added open-route
  `visible_ranges` and shared `TrackGeometry.car_visible` guard for each car,
  both gangway endpoints, headlights and [main.gd](./scripts/main.gd) picking.
  Cars vanish individually past the cap, with half-car-length tolerance.
  Closed loops remain entirely visible. Timetables/stops unchanged.
- [train_visual_smoke.gd](./tests/train_visual_smoke.gd) now positions a train
  on a hidden terminal turn, verifies all cars invisible and actual pixels
  match an empty night view. Passed with installed Godot binary:
  `/Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tests/train_visual_smoke.gd --audio-driver Dummy`,
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/train_controls_smoke.gd`,
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/schedule_smoke.gd`.
  Updated [DESIGN.md](./DESIGN.md).
- Fresh Windows/macOS/Web exports passed using the same binary with
  `--headless --path . --export-release "Windows Desktop" dist/Metro.exe`,
  `--headless --path . --export-release "macOS" dist/Metro-macOS.zip`,
  `--headless --path . --export-release "Web" dist/web/index.html`.
  Archive integrity (`unzip -t dist/Metro-macOS.zip`), Windows x86_64 PE
  (`file dist/Metro.exe`), nonempty Web assets and `git diff --check` passed;
  no export errors/warnings. Runtime/signature checks and broader suites not
  rerun. Following retains its existing simulation-camera behavior during
  hidden turnback. No commit/push/deploy. Task captures/logs cleaned.

### Restored normal terminal caps (superseded implementation, 2026-11-07)

- User confirmed restoring rounded visible caps at terminal markers without
  long straight extensions. [track_geometry.gd](./scripts/render/track_geometry.gd)
  now clips open-line visible centerline/running lanes to terminal projections,
  while retaining full simulation berths, end-car stops and continuous platforms.
  Effective rail picking paths are sliced from that visible centerline.
  Loops and timetable/movement calculations are unchanged.
- Updated [DESIGN.md](./DESIGN.md) and current memory. Added exact terminal
  endpoint checks for all train lengths; close-up pixel tests confirm normal
  cap extent. Passed with `/Applications/Godot.app/Contents/MacOS/Godot`:
  `--headless --path . --script res://tests/schedule_smoke.gd`,
  `--headless --path . --script res://tests/editing_smoke.gd`,
  `--path . --script res://tests/train_visual_smoke.gd --audio-driver Dummy`,
  `--path . --script res://tests/visual_smoke.gd --audio-driver Dummy`.
- Fresh exports passed using the same binary with
  `--headless --path . --export-release "Windows Desktop" dist/Metro.exe`,
  `--headless --path . --export-release "macOS" dist/Metro-macOS.zip`,
  `--headless --path . --export-release "Web" dist/web/index.html`.
  Verified archive integrity via `unzip -t dist/Metro-macOS.zip`, Windows
  x86_64 PE via `file dist/Metro.exe`, nonempty Web assets and
  `git diff --check`; no export errors/warnings. Runtime/signature checks
  not rerun for this visual-only clipping change. No commit/push/deploy.

### End-car station alignment (superseded, 2026-11-07)

- User rejected centered train stops and explicitly chose last-car alignment at
  the line's first station, leading-car alignment at every other station, in
  both directions. [track_geometry.gd](./scripts/render/track_geometry.gd) now
  projects stops directly at the marker except origin stops, whose head advances
  by `wagon_count * CAR_PITCH`. Straight berth half-span grows to that span +
  half a car length + 16px so neither train end boards around a curve.
  Continuous platform/fading/passengers and automatic curve easing retained.
- Updated [README.md](./README.md), [DESIGN.md](./DESIGN.md) and current memory;
  previous centered-stop decisions below are superseded. Tests verify designated
  end-car marker distance <= lane offset + 0.1px for all 1-6 wagon counts on
  open/loop routes in both directions, alongside whole-train straight alignment.
  Shared-loop tests initially assumed head-at-origin; corrected to designated
  end-car probes, then passed. Terminal visual probes match expanded straight
  berth. No translation changes needed.
- Passed with `/Applications/Godot.app/Contents/MacOS/Godot`:
  `--headless --path . --script res://tests/schedule_smoke.gd`,
  `--headless --path . --script res://tests/simulation_smoke.gd`,
  `--headless --path . --script res://tests/loop_smoke.gd`,
  `--headless --path . --script res://tests/train_controls_smoke.gd`,
  `--headless --path . --script res://tests/editing_smoke.gd`,
  `--headless --path . --script res://tests/intersection_smoke.gd`,
  `--path . --script res://tests/train_visual_smoke.gd --audio-driver Dummy`,
  `--path . --script res://tests/visual_smoke.gd --audio-driver Dummy`.
  Regulated headway deviation 0.115s vs 6.931s unregulated; all six-minute
  intersection scenarios retain full-train safe gaps and sustained arrivals.
- Fresh export commands using the same binary passed:
  `--headless --path . --export-release "Windows Desktop" dist/Metro.exe`,
  `--headless --path . --export-release "macOS" dist/Metro-macOS.zip`,
  `--headless --path . --export-release "Web" dist/web/index.html`.
  Verified `unzip -t dist/Metro-macOS.zip`, Windows x86_64 PE, universal
  x86_64/arm64 binary, strict deep signature, exported Mac headless startup
  `--headless --quit-after 10 --audio-driver Dummy`, nonempty Web assets and
  `git diff --check`. No export errors/warnings. Windows/Intel/browser runtime,
  interface/localization/audio/urban suites not rerun. Not committed/deployed.
  Task-owned verification files cleaned.

### Continuous platforms and straight station berths (superseded geometry, 2026-11-07)

- User chose automatic reshaping instead of rejecting tight approaches.
  [track_geometry.gd](./scripts/render/track_geometry.gd) now reserves a straight
  train-length + 32px berth centered at each station, using its travel bisector
  or terminal tangent. Cubic tangent connectors ease the route around these
  berths, discarding guide elbows within the platform approach footprint.
  Stations do not move. Stops put the head half the car-center span ahead,
  keeping the whole train straight before the next bend/terminal turnaround.
  Geometry is generated on rebuild/wagon changes, not every frame.
- [station_visit.gd](./scripts/sim/station_visit.gd) snapshots one continuous
  platform polygon covering the full train; [world_view.gd](./scripts/render/world_view.gd)
  draws it with the existing fade/passenger lifecycle. Effective per-track
  paths wire [main.gd](./scripts/main.gd) rail picking to eased geometry.
  Canonical grid guides, edit validation and train clearance remain unchanged.
  Updated [README.md](./README.md) and [DESIGN.md](./DESIGN.md).
- Tests cover all 1-6 wagon lengths at each station on open/loop routes in both
  travel phases: car axes dot >0.999, center spacing error <0.05px, continuous
  platform length error <0.05px. Sharp 135-degree source fixtures assert eased
  lane tangent dot >0.85 and no nonadjacent segment crossings. Visual tests
  sample the former inter-car platform gap; berth capture inspected. Editing
  test selects a visibly eased approach away from its original guide.
- Initial typed-array fixture failed at runtime despite Godot exiting zero;
  fixed and rerun cleanly. Shared-route endpoint offsets initially hid station
  knots and broke loop ordering; explicit station anchors and offset-join
  cleanup fixed it. Old tests assumed head-at-marker and unextended terminal
  caps; updated them to train-center alignment and geometry-derived probes.
  Visual rail probes now transform after the render frame, avoiding stale
  camera transforms. These are intentional geometry changes, not skipped tests.
- Passed with `/Applications/Godot.app/Contents/MacOS/Godot`:
  `--headless --path . --script res://tests/schedule_smoke.gd`,
  `--headless --path . --script res://tests/intersection_smoke.gd`,
  `--headless --path . --script res://tests/loop_smoke.gd`,
  `--headless --path . --script res://tests/simulation_smoke.gd`,
  `--headless --path . --script res://tests/train_controls_smoke.gd`,
  `--headless --path . --script res://tests/editing_smoke.gd`,
  `--headless --path . --script res://tests/localization_smoke.gd`,
  `--path . --script res://tests/visual_smoke.gd --audio-driver Dummy`,
  `--path . --script res://tests/train_visual_smoke.gd --audio-driver Dummy`,
  `--path . --script res://tests/interface_smoke.gd --audio-driver Dummy`.
  Full intersection scenarios retain safe gaps and continued service.
  Regulated headway standard deviation 0.112s vs 6.944s unregulated.
- Fresh exports passed using the same binary:
  `--headless --path . --export-release "Windows Desktop" dist/Metro.exe`,
  `--headless --path . --export-release "macOS" dist/Metro-macOS.zip`,
  `--headless --path . --export-release "Web" dist/web/index.html`.
  Verified `unzip -t dist/Metro-macOS.zip`, Windows x86_64 PE, universal
  x86_64/arm64 binary, `codesign --verify --deep --strict`, exported macOS
  startup `--headless --quit-after 10 --audio-driver Dummy`, nonempty Web assets
  and `git diff --check`. No final script/export errors or warnings.
  Windows/Intel/browser execution, audio/urban suites and frame-time profiling
  not rerun. Existing hidden terminal turns still carry moving trains; they are
  not station boarding areas. Canonical grid edit previews remain guides,
  effective eased geometry is built on commit. No commit/push/deploy.
  Task-owned captures/logs/verification app cleaned.

### Transient platforms and bounded passenger boarding (2026-11-07)

- User chose actual passenger effects on boarding time, transient platforms,
  and a cap of two extra seconds per stop. Implemented light local exchange,
  not full destination/demand simulation. Occupancy persists between stops,
  alighting precedes boarding and termini empty arriving trains. Dwell is at
  least the selected minimum and covers the exchange; terminal recovery
  remains additional. Fleet/cycle/headway estimates use the conservative
  two-second allowance. No new UI controls, notifications or gameplay pressure.
- Added [station_visit.gd](./scripts/sim/station_visit.gd) and UID;
  [metro.gd](./scripts/sim/metro.gd) stores riders/current visit;
  [dispatcher.gd](./scripts/dispatch/dispatcher.gd) owns simulation-time visits,
  bounded boarding and expiry; [main.gd](./scripts/main.gd) passes visits to
  [world_view.gd](./scripts/render/world_view.gd). Platform geometry matches
  stopped car orientations, doors open on that side, tiny figures emerge/board
  or walk outward/fade. Draws fade in with zoom 1.5-3 and out 1.2s after departure,
  including service withdrawal; offscreen activity culled. Pause freezes visits,
  watch/follow continue to show them, edits clear old snapshots.
- Updated [README.md](./README.md), [DESIGN.md](./DESIGN.md), live localized
  minimum-stop tooltip in [ui.csv](./translations/ui.csv) and imported resources.
  Added schedule tests (already in CI) for dwell bounds at minimum 0/0.1/3/12s,
  boarding affecting departure, terminal exchange ordering/capacity, fade
  continuity/expiry, pause and edit cleanup. Visual tests assert platforms,
  tiny passengers, map-zoom suppression and fade-out; close-up capture inspected.
- Passed with `/Applications/Godot.app/Contents/MacOS/Godot`:

  ```sh
  --headless --editor --path . --quit
  --headless --path . --script res://tests/schedule_smoke.gd
  --headless --path . --script res://tests/intersection_smoke.gd
  --headless --path . --script res://tests/loop_smoke.gd
  --headless --path . --script res://tests/simulation_smoke.gd
  --headless --path . --script res://tests/train_controls_smoke.gd
  --headless --path . --script res://tests/editing_smoke.gd
  --headless --path . --script res://tests/localization_smoke.gd
  --path . --script res://tests/train_visual_smoke.gd --audio-driver Dummy
  --path . --script res://tests/visual_smoke.gd --audio-driver Dummy
  --path . --script res://tests/interface_smoke.gd --audio-driver Dummy
  --headless --path . --export-release "Windows Desktop" dist/Metro.exe
  --headless --path . --export-release "macOS" dist/Metro-macOS.zip
  --headless --path . --export-release "Web" dist/web/index.html
  ```

- Initial terminal ordering test exposed float-boundary progress just under
  completion; fixed with microsecond tolerance and constant-time batch counts.
  Final schedule headway deviation: regulated 0.119s vs 6.572s unregulated.
  Full six-minute intersections retain independent lanes, safe gaps and arrivals.
  All final import/export logs have no parser/script errors or warnings.
- Fresh Windows/macOS/Web exports succeeded after final code changes.
  `unzip -t dist/Metro-macOS.zip`, `file dist/Metro.exe`, universal binary
  inspection, `codesign --verify --deep --strict`, exported Mac startup
  `--headless --quit-after 10 --audio-driver Dummy`, nonempty Web assets and
  `git diff --check` verified. Windows/Intel execution, browser runtime, audio/
  urban suites and large-network frame-time profiling not rerun. No commit,
  push or deployment. Task captures/export logs/verification apps cleaned.

### Refined metro trainsets (2026-11-07)

- Implemented all five approved visual refinements in
  [world_view.gd](./scripts/render/world_view.gd): matching softened cab ends
  and windscreens, neutral metal roofs/ventilation, paired door/window rhythm,
  accordion gangways attached to both car orientations, progressive zoom detail.
  Geometry dimensions, clearance, picking, headlights and simulation unchanged.
  Updated [README.md](./README.md), [DESIGN.md](./DESIGN.md).
- Passed with `/Applications/Godot.app/Contents/MacOS/Godot`:
  `--path . --script res://tests/train_visual_smoke.gd --audio-driver Dummy`,
  `--path . --script res://tests/visual_smoke.gd --audio-driver Dummy`,
  `--headless --path . --script res://tests/train_controls_smoke.gd`,
  `--headless --path . --script res://tests/loop_smoke.gd`.
  Expanded pixel/geometry assertions for matching cab glazing, neutral roof,
  equipment, paired doors, recoloring, map detail suppression, fixed-width
  gangway ends and inside-curve compression. Inspected straight/curved/map
  captures. Initial old body-color probes hit the newly neutral roof; moved
  them to the body edge. Roof/seam probes aligned to actual rasterized features.
  A Pillow pixel probe was unavailable; used renderer assertions instead.
- Fresh Windows/macOS/Web export commands from Validation and delivery passed.
  Archive integrity, x86_64 PE, universal x86_64/arm64 binary, strict deep Mac
  signature, exported Mac headless startup and nonempty Web assets verified;
  no export log errors/warnings. Windows/Intel/browser runtime not rerun.
  Not committed or deployed. Follow-up request adds transient zoomed platforms
  and passenger exchange affecting stops, capped at two extra seconds; this
  supersedes the purely decorative recommendation in the prior discussion.

### Train appearance discussion (2026-11-07)

- Inspected current car/gangway/headlight rendering in
  [world_view.gd](./scripts/render/world_view.gd). No implementation requested
  or made. Suggested restrained metro realism: matching cab ends instead of
  locomotive/trailer styling, roof equipment/seams, clearer door/window rhythm,
  believable articulated connections and zoom-dependent detail. These are
  proposals, not approved product decisions; changing proportions would also
  require geometry, clearance and picking updates.
- Required Windows/macOS release export commands from Validation and delivery
  succeeded with the installed Godot binary. `unzip -t dist/Metro-macOS.zip`
  and `file dist/Metro.exe` verified archive integrity and Windows x86_64 PE.
  Export logs contained no errors/warnings (the no-match log search exits 1).
  No runtime/tests/browser checks rerun for this design-only discussion.

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
