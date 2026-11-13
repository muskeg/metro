# Metro - repository memory

Last updated: 2026-11-13.

## Read first

Follow [AGENTS.md](./AGENTS.md) at startup/completion. Check relevant source;
this is a handoff, not its substitute. Replace superseded notes; Git history
retains the old work log.

- [README.md](./README.md) / [guide](./docs/guide.md): play, controls, presets, development/releases.
- [DESIGN.md](./DESIGN.md): rationale, geometry and simulation formulas.
- [docs/performance.md](./docs/performance.md): profiling and performance detail.

## Current product decisions

- Godot 4/GDScript, verified **4.7.2**, Compatibility renderer. Relaxing builder:
  no economy/failure pressure/network demand/transfers; local exchanges affect dwell.
- Targets: Windows/Linux x86_64, universal ad-hoc-signed/non-notarized macOS,
  single-thread Web, Android ARMv7/ARM64 APK, unsigned iOS Xcode project.
  iOS needs Xcode building/signing. Invisible construction grid: 48 world units.
- English default, live persisted French. Add messages to [ui.csv](./translations/ui.csv);
  translate nested errors before formatting; import escaped multiline keys.
  Never auto-translate factual station/service or player save names.

### Editing and navigation

- **Desktop:** empty click places; rail click/+ inserts; center drag moves;
  station + connects. No tools/modes; grid-snapped ghost only on free map space.
- **Touch:** one finger pans, pinch zooms, taps select without creating stations.
  Persistent 48px actions offer Move/Connect/Delete or Insert/Reshape/Delete.
  With no selection, Add station starts a single placement preview. Add/Move/
  Reshape require Confirm; Cancel restores movement and incident paths.
  Connect has Undo step/Flip bend/Cancel; taps pin bends or finish at a station.
  Pinching cancels active edits before navigating; canceled OS touches do not commit.
- Web emits an emulated mouse press **before** the first ScreenTouch. Recognize
  emulation even before touch mode is active: GUI receives it, world editing
  never does. Genuine mouse input returns to desktop controls.
- Mobile supports sensor-driven portrait **and** landscape. Rotation preserves
  manual camera center/zoom, cancels a held touch gesture and relays out the HUD.
  Native/CSS safe areas bound controls; Android uses DPI scaling as needed.
  Desktop starts at 1180x740 logical pixels; minimum window size is 320x320.
  Use canvas-items display-density scaling, not smaller fonts.
- Elastic sections use cardinal/45-degree segments, at most one free bend.
  Tab/flip changes posture; Backspace undoes a pin. Diamonds reshape locally,
  preserving neighbors/distant bends and explicit collinear anchors. Invalid
  paths show red feedback; unchanged releases must not restart trains.
- Station centers/handle corridors beat rail insertion; rail controls are
  perpendicular. Mouse release over GUI cancels; Escape/right-click restores
  original move geometry. Transform event coordinates through the world canvas;
  hover reuses stored viewport coordinates, never polls OS cursor position.
- Confirm deletion. Station removal reconnects serving lines with oriented
  geometry; rail removal splits fragments. Line removal preserves shared/
  unrelated infrastructure and leaves an empty line after deleting the last.
- Lines extend only at endpoints. Connecting endpoints with at least three
  stations closes a loop; fewer than three after deletion makes it open.
  Closed lines cannot extend, but existing tracks remain redrawable.
- Wheel/pinch zoom normally spans 0.08-6x; panning is unbounded. Loads/Fit may
  zoom below 0.08, establishing that view's lower navigation floor. Fit includes
  stations, waypoints and offset running paths, preserves aspect, adds a
  24-world-unit margin and HUD clearance; it ends edits/following, not trains.
  Resize does not refit. Stored framing is overridden on menu/startup loads.
- Train follow targets the interpolated pose at 5x, hides editing but not HUD/
  navigation, resets smoothing and applies scroll immediately. Pan/Escape/
  redispatch ends follow.
- Watch (H/Menu) hides HUD/editing but permits navigation/follow; a bottom grip
  or H/Escape restores it. Screensaver (K/Menu) is separate: overview, follow,
  slow pan, other follow; smooth transitions, no idle autostart/persistence.
  Entry temporarily unpauses without rebuilding trains. Escape/click/tap
  consumes both exit press/release and restores prior camera, pause, window,
  smoothing, cursor, surviving follow and Watch state. Other input cannot exit.

### Storage, startup and presets

- [layout_store.gd](./scripts/layout_store.gd): v1 JSON in `user://layouts`
  (IndexedDB on Web); SHA-256 filenames, 64-char names, temporary-write/rename.
  Confirm destructive replacement; Clear preserves saves. No autosave/cloud.
  Browser storage may be evicted; warn on unavailable persistence, never promise it.
- Export/Import uses native dialogs or browser download/upload; validate,
  confirm, replace and fit, then Save separately. JSON is data, never supplied
  scripts/paths/resources. Limits: 16 MiB, 256 stations, 512 tracks, 16 lines,
  64 trains; full bounds in the [guide](./docs/guide.md). Validate finite values,
  grid, unique positions, references, geometry/clearance before rendering;
  log errors and surface `error_message`, never silent defaults.
- Saves retain topology/waypoints/shared tracks, names, line preferences/render
  priority and camera/selection. Trains/visits restart; pause/time/language/audio do not.
- Desktop startup loads immutable [Metro demo](./layouts/metro_demo.json):
  16 stations, three lines, one loop. Web feature `montreal_startup` instead
  loads bundled [Montreal](./layouts/montreal.json). All bundled originals remain
  in Load; Save only writes user copies. Tests needing an empty scene must set
  `startup_layout_enabled = false` before adding it.
- Web `?kiosk=1` opts into screensaver; independent `layout=metro_demo`,
  `montreal`, `jr_east` or `saved:Name` selects a preset/same-browser-site save.
  URL-encode save names; no remote JSON/paths. Invalid/missing layouts show an
  error and skip kiosk. Configure browser fullscreen externally for URL entry.
- [Tokyo](./layouts/jr_east.json): central JR, 90 stations/107 tracks/11 paths;
  full Yamanote loop plus documented local/rapid corridors and Tokyo Monorail.
  [build_jr_east.gd](./scripts/tools/build_jr_east.gd) owns geometry/fleets:
  96px schematic spacing; three wagons; fleets 10/8/4/6/4/4/4/8/6/6/4 (64 total).
  Do not reduce spacing blindly: compact segments/terminal throats stop fitting.
- Montreal: 68 stations/69 tracks/four metro-only lines, no REM/exo/extensions.
  [build_montreal.gd](./scripts/tools/build_montreal.gd): fleets 10/12/2/6,
  interval 12s, three wagons except yellow at two (three caps yellow at one
  train; four do not fit diagonals). Presets use original schematics;
  regeneration affects originals, not saved copies: reload for updates.

## Architecture and invariants

- [main.gd](./scripts/main.gd): input/UI/settings/editing; `_configure_display`/
  `_update_display_density` handle logical units, `_resize_interface` safe areas.
  Sheets never pause. Successes stay silent; errors retain eight seconds.
  Feedback belongs only in open sheets/map: hidden zero-width wrapped labels
  inflate layouts. Toasts use manually measured RichTextLabel/plain Panel,
  not cached autowrap minimum heights.
- [transit_graph.gd](./scripts/sim/transit_graph.gd) and
  [transit_line.gd](./scripts/sim/transit_line.gd): IDs equal array indices.
  Deletion compacts/remaps every reference and lookup. Physical tracks are
  shared; waypoint orientation is canonical track a-to-b. Loops repeat the
  first station at the end. Shared/reversed insertions update every line;
  fragments preserve settings, name and render priority.
- All affected paths validate atomically; rejected movement restores the whole
  change. Reshape an endpoint from the gesture's original path, not accumulated
  intermediate geometry. Independent physical tracks may cross without
  transfers/signaling; each stroke rejects self-intersection/backtracking.
- [track_geometry.gd](./scripts/render/track_geometry.gd): canonical guides,
  elastic paths, rounding, corridor offsets and route circuits. Shared spans
  use stable 48px service slots; most-calling service stays on the spine.
  Slot changes occur only where all crossing services stop, so express skippers
  never jog. Each service rejoins its actual stops. Compute/share corridor
  context once per rebuild, never per frame.
- Preserve tight quadratic rounding (12px stations/24px elsewhere, <=35% of
  adjacent lengths), adaptive subdivision before lane offsets and on-grid
  markers. No forced straight berths/expanded terminals/alternate picking paths.
  Lanes are +/-8px, cars 7px wide; +/-7 was rejected.
- Routes separate simulation `points`, `centerline`, visible `running_paths`,
  stops and loop `reverse_route`; select by direction. Cabs stop on approach
  at radius + half-car + 3px. Per-end insets/entries/exits/`terminal_ready`
  govern fit; too-short lines disable dispatch with localized guidance.
- [dispatcher.gd](./scripts/dispatch/dispatcher.gd): 60Hz substeps and full-train
  forward moving authority, not station-slot locks. Lines and loop directions
  run independently; multiple trains may occupy one section. Cross-line
  geometric overlap is intentional, not a collision bug or junction FIFO.
- Open-line terminal center tracks converge visibly and reverse cabs in place,
  never U-turn or extend past caps. `_terminal_owners` protects each line's
  crossover until its tail clears; never share locks across lines/loops.
  `reverse_pending`/`reversal_distance` advance the logical head after authority
  validation without moving physical cars. Cap short circuits at one train
  when opposite terminal ownership would otherwise deadlock.
- Fleet ceilings (default 4) depend on geometry/cycle/headway, not stop count.
  Keep `route_capacity`, `recommended_fleet`, `service_fleet` and headway distinct.
  Empty/single-stop lines do not dispatch. Regulation normally holds at stations
  (<=3s); bounded speed corrections use nominal 90% of ceiling. Live service
  settings never redispatch; surplus retires stopped at termini/loop origin.
  Geometry/wagons rebuild routes/trains/visits/timetables. Pause freezes
  simulation, day/night and visual histories.
- [station_visit.gd](./scripts/sim/station_visit.gd): deterministic alight-before-
  board exchanges, two doors/12 places per car, <=2s extra boarding included in
  cycle/headway estimates; recovery stays separate. Completed journeys update
  occupancy; visual walks never extend dwell or use global randomness/train IDs.
  Lazy curved platform ribbons never reshape routes; visits fade after departure/
  retirement and clear on rebuild. `platform_bounds` encloses platform/passenger
  discs. Cull visits via `visible_in` and train drawing only, never simulation.

### Rendering, HUD and audio

- [world_view.gd](./scripts/render/world_view.gd) draws visible running lanes,
  not closed simulation circuits. [static_track_layer.gd](./scripts/render/static_track_layer.gd)
  retains rails/shadows; topology/recolor/AA-threshold changes invalidate them.
  Resolve callbacks by current ID after loads, not stale model references.
- Ascending line `render_priority` (0-15, default 0), stable array-order ties:
  each line's rails/highlights/platforms/train shadows/lights/cars form one
  layer. Higher rails occlude lower trains; opaque stations/edit overlays stay
  above all lines. Tokyo Yamanote is priority 1. No manual section heights.
- Matte day/night background and subtle grain; no glass/scenery/station shadows/
  glow. Shared solar arc drives track/car shadows; corridor shadows stay below
  rails. [urban_backdrop.gd](./scripts/render/urban_backdrop.gd) draws only atmosphere.
- Station centers/rings grow with unique serving-line membership; share
  `station_radius` with picking/handles/selection. Darkened colored rings follow
  line-array order; never add transparency to reveal trains underneath.
- Physical car proportions also govern safety/platforms. Cache meshes/glow/
  headlights; folded gangways use triangles. Night lighting is local geometry,
  not HDR; preserve marker fades/loop holes. No world-unit AA fringe at zoom
  >=1.5. Screensaver motion-AA uses CanvasLayer 1, never HUD 2; exit restores parity.
- Overview trains crossfade to outlined comet heads over 0.5-0.8x. Actual
  interpolated history (1s/~30Hz) is capped at 1.5 train lengths/one circuit,
  no minimum. Expire/retract from the rear, not by global front fade. Freeze in
  pause; reset on rebuild/retirement/reversal, never fabricate startup tails.
  Drawing/culling/picking include vertices, loop seams and glow; preserve layering.
- HUD: flat 60px bottom rail, horizontally scrolling line tabs, fixed collapse
  action, inline + after the last tab. Use shrink flags on +/collapse to avoid
  stealing tab width. Same-tab folds integrated settings; switching keeps open.
  Line header/Collapse stays fixed above scrolling controls. Menu/help/save
  sheets are exclusive, centered within the safe area and vertically bounded.
  Body text >=16px, desktop targets >=44px, touch actions >=48px.
- Branding fades at 10-30s and hides under sheets. HUD fades after 8s idle
  (28% day/70% dark night), not during sheets/dialogs/gestures/touch selection.
  Wake never consumes input; Watch grip never fades. Paused settled scenes
  stop rendering; input/resize wakes it. Recolor never redispatches.
- [ambient_audio.gd](./scripts/audio/ambient_audio.gd): looping supplied no-drums
  MP3; no synthetic train music. Effects default muted/slider removed pending
  replacements; master/music remain. No supplied license: never infer old CC0.
  Headless audio is disabled. Web uses **Stream**, ProjectSettings `0` (not
  AudioServer enum `1`); Sample caused AudioBuffer duplication on pause/restart.
- [build_branding.gd](./scripts/tools/build_branding.gd) regenerates
  [branding](./assets/branding); Web extends the standard Godot shell.

## Validation and delivery

Follow [AGENTS.md](./AGENTS.md): shipped GDScript/scenes/shaders/project/export
changes require **fresh Windows and macOS release exports**, verified before
completion. Asset/translation-only, docs/memory/instructions, excluded tests/
probes and answers do not. Report failures/unrun platform checks honestly.
Use matching Godot/export templates. Commands assume `godot`; locally the
verified Linux binary is `./dist/Godot_v4.7.2-stable_linux.x86_64`.
On macOS, use `/Applications/Godot.app/Contents/MacOS/Godot` if not on PATH.

```sh
godot --headless --path . --editor --import --quit
bash tests/run_smoke.sh smoke
bash tests/run_smoke.sh extended
godot --path . --script res://tests/interface_smoke.gd --audio-driver Dummy
godot --path . --script res://tests/screensaver_smoke.gd --audio-driver Dummy
godot --path . --script res://tests/visual_smoke.gd --audio-driver Dummy
godot --path . --script res://tests/train_visual_smoke.gd --audio-driver Dummy
godot --path . --script res://tests/urban_smoke.gd --audio-driver Dummy
mkdir -p dist/web
godot --headless --path . --export-release "Windows Desktop" dist/Metro.exe
godot --headless --path . --export-release "macOS" dist/Metro-macOS.zip
godot --headless --path . --export-release "Web" dist/web/index.html
unzip -t dist/Metro-macOS.zip
```

- [run_smoke.sh](./tests/run_smoke.sh) is CI/local authority: 17 headless scripts
  in `smoke`, 18 in `extended`; set `GODOT_BIN` if needed. Smoke uses `--fast`
  for preset/schedule/terminal. Individual scripts without flags retain full
  coverage. Extended is required before versioned releases; preserve long
  headway/deadlock/fleet checks. Larger outer timesteps still subdivide at 60Hz.
  Schedule regulation must improve headway deviation by >=25%.
- Preset selectors: `jr-east`/`montreal`; `--fast` and `render-only` alone test
  both and cannot be combined. Intersection selectors follow `--`; unmatched
  labels fail. Cross-line geometric collision assertions are intentionally absent.
- Graphical tests need a display; do not run fullscreen checks concurrently.
  Inspect logs even after exit zero. Expected invalid-layout diagnostics are
  deliberate in layout/screensaver tests; llvmpipe's unsupported VSync warning
  is not a script failure. Clean named screenshots afterward.
- [export_presets.cfg](./export_presets.cfg) embeds desktop data; tests/docs/dist/
  tool scripts are excluded. Keep ETC2/ASTC imports enabled for ARM64.
  Close a running Windows build before overwriting its executable.
  WSL launch check: `./dist/Metro.exe --headless --quit-after 10 --audio-driver Dummy`.
  Mac ZIP integrity does not validate native launch or Gatekeeper.
- [pages.yml](./.github/workflows/pages.yml): import/test/export on PRs/main;
  deploy only main pushes/manual. Single-thread Web needs no COOP/COEP.
  A local export/commit does not publish Pages.
- [releases.yml](./.github/workflows/releases.yml): manual default-branch-only
  versioned six-target release, separate from Pages. Validates semver/rejects
  existing tags, tests once, builds with [setup-godot](./.github/actions/setup-godot/action.yml),
  uploads assets/SHA256SUMS to a draft before publishing. Only publisher has
  contents-write. Android signs/verifies using Actions-managed secrets; unsigned
  APK stays in packaging, published filename is `Metro-<version>-android.apk`.
  Keystore setup/SDK/iOS placeholder details: [guide](./docs/guide.md#releases-github).

## Recent verification and remaining limitations

### Mobile editing and rotation - 2026-11-13

- Implemented deliberate touch controls, safe-area-aware rotation, scrolling
  sheets and first-emulated-press protection; covered in
  [interface_smoke.gd](./tests/interface_smoke.gd).
- Passed with `./dist/Godot_v4.7.2-stable_linux.x86_64`:
  `--headless --path . --editor --import --quit`;
  `--headless --path . --script res://tests/interface_smoke.gd`;
  `--path . --script res://tests/interface_smoke.gd --audio-driver Dummy`;
  and this dependent-test command:
  `for test in editing localization screensaver idle_render layout; do ./dist/Godot_v4.7.2-stable_linux.x86_64 --headless --path . --script "res://tests/${test}_smoke.gd" || exit; done`.
- Fresh Windows/macOS/Web exports passed using the three export commands above
  with that binary; no export errors/warnings. `unzip -t dist/Metro-macOS.zip`
  and `./dist/Metro.exe --headless --quit-after 10 --audio-driver Dummy` passed.
- Browser synthetic touches at 390x844/844x390 checked first-tap safety and
  menu activation/rotation; fixed short-landscape branding overlap.
- **Not run:** physical Android/iOS sensor/notch tests, native Mac/Gatekeeper,
  Android/iOS package refresh or full long-running simulation suite for this UI change.

### Android publication follow-up - 2026-11-11

- Earlier CI built all six artifacts and signed Android successfully, but
  publication expected the obsolete `-android-unsigned.apk` filename.
  Publisher/release notes now expect the signed `-android.apk`.
- Ruby YAML parsing, `bash -n` on all 11 workflow run blocks, a stubbed-`gh`
  publish fixture producing SHA256SUMS and `git diff --check` passed.
  PyYAML/actionlint were unavailable for that follow-up; live publication was
  not reverified in the recorded work. Do not equate fixture success with deployment.

### Memory condensation - 2026-11-13

- Replaced the 5,155-line transcript with current decisions/invariants, entry
  points, commands, recent results and open checks; history remains in Git.
- Checked local links, incoming `validation-and-delivery` anchor, size and
  `git diff --check`. Docs only; no game tests/exports rerun.
