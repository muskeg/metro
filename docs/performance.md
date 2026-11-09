# Performance investigation

2026-11-08. This report combines measured diagnosis with implementation status.
Corridor shadow meshes and indexed route lookups are now in the game; the probe
remains in [performance_probe.gd](../tests/performance_probe.gd), excluded from exports.

## Executive finding

The strongest observed bottleneck is CPU-side redraw work, not a demonstrated
shortage of GPU horsepower. The original renderer resubmitted complex corridor
shadow polygons on every redraw. On Tokyo, that one stage took about **127 ms**
on the local software renderer. A whole 60 FPS frame has only **16.67 ms**, and
a 120 FPS frame has **8.33 ms**.

The integrated triangle meshes preserve the shadow geometry and captured pixels,
reducing Tokyo's daytime redraw callback from **133 ms to 7.9 ms** in the latest
local software-rendered probe. That is an approximately **94% reduction in
redraw CPU cost**, not a claim about the target PC's frame rate. The tested host
uses llvmpipe, so target-PC GPU and full-frame measurements remain outstanding.
Fleet-scaling fixes (see below) then removed most per-train costs. The remaining
priority is end-to-end measurement on the Web target and constrained hardware.

**Recommended order:** measure the Web build after the low-end rendering
changes on actual browser hardware, then profile remaining dynamic stations and
platforms on a constrained device. Keep the current visuals and signalling
rules.

## Low-end Web rendering follow-up

Implemented in the requested order (night illumination, merged static meshes,
train batching, paused-idle rendering, backdrop texture):

- Night rail-light polylines retain their original per-point colors and draw
  commands. Night strength now changes through node modulation; geometry and
  color arrays rebuild only on network/recolor changes.
- Corridor shadows are one retained mesh; halo polygons are merged into one
  colored mesh per line. Base rail paths were already retained in one canvas
  item, and remain individual path commands there. Station markers and active
  platforms remain dynamic to preserve their changing appearance and order.
- Shells and cab noses use their existing cached geometry, submitted as one
  triangle batch per train. Car details and gangways remain in the dynamic draw
  pass; this is batching, not persistent GPU instancing.
- Pausing freezes the day/night phase. After the title, interface fade and
  notifications settle, the render loop sleeps; input and resize wake it.
  Active play and the animated screensaver keep rendering normally.
- The backdrop samples a repeating 512 x 512 precomputed noise texture at the
  same two world-space scales instead of evaluating eight sine hashes per
  fragment. Grain remains world-anchored and uses the existing brightness and
  zoom attenuation.

The final Montreal graphical probe (11 trains, llvmpipe software rendering)
reports full redraw CPU of 1.16 ms by day / 1.55 ms at night at fitted overview,
and 1.09 / 1.13 ms at 5x zoom. All four legacy-vs-production full-frame
captures were byte-identical. Frame waits are not isolated GPU timings. The
fresh Web export starts and displays the map in the integrated browser, but
that is not a representative Web FPS measurement. The earlier Chromium
SwiftShader run measured 42-47 ms/frame before this work; native Windows and
real low-end browser hardware remain the deciding performance checks.

The merged transparent halo meshes use a shader-based screen-space edge fringe
to retain edge smoothing after consolidation. Train-visual, backdrop and
full-frame shadow-parity tests pass; inspect the Web result on the target
display before treating pixel appearance as final. No zoom/DPI cap or detail
reduction was introduced.

## Fleet scaling

`--fleet [map]` raises each line's `max_trains` ceiling (preset, 8, 16, 40),
disables dispatch-rate limiting, warms up 240 simulated seconds and samples 300
1/60 s ticks; graphical runs also measure draw CPU at overview and 5x, day and
night, moving the real camera. Tokyo (jr_east), WSL llvmpipe, 167 trains:

| Stage | Before | After |
|---|---|---|
| Simulation tick mean | 21.0 ms | 3.4 ms |
| Simulation tick p99 | ~8.4 ms (after estimate cache) | 4.4 ms |
| Night headlights | 35 ms | 5.6 ms |
| Train bodies | 8.3 ms | 5.5 ms |
| Overview draw, day | 20.7 ms | 14.9 ms |
| Overview draw, night | 55 ms | 21 ms |

Fleet sizes were identical before and after (20/68/109/167). An earlier probe
revision did not move the camera, so its 5x figures were invalid; 5x day draw
after culling is 7.3 ms. Implemented: memoized service estimates, a per-tick
circuit index for `movement_authority`, draw-only train/platform culling, cached
car-shell/nose meshes, batched headlight beams (float colors via
`canvas_item_add_triangle_array`) and lazily built `StationVisit` geometry.
All 12 legacy-vs-production frames remain byte-identical.

```sh
godot --headless --path . --script res://tests/performance_probe.gd -- --fleet jr_east
godot --path . --script res://tests/performance_probe.gd --audio-driver Dummy -- --render --fleet jr_east
```

## Measurement scope and reproducibility

- Godot 4.7.2, Compatibility renderer, Linux/WSL, X11, 1180 x 740.
- Graphics adapter is **llvmpipe**, a software renderer. There is no available
  hardware GPU here. Graphics/presentation waits are not gaming-PC benchmarks.
- CPU probe: bundled maps, 60 simulated seconds of warm-up, 600 individual
  `process(1.0 / 60.0, false)` samples, and 100 empty-space hover misses.
  Montreal has 11 trains at this point, not its final 20-train fleet.
- Rendering probe: freeze simulation, visits, camera and time; measure the draw
  callback and its stages for 30 frames per variant, at fitted overview and 5x
  zoom, noon and midnight. Compare full rendering with individual omitted
  stages and with cached shadow meshes. The final probe hides HUD/overlays.
- Render measurements exclude dispatch, input and audio. Stage timings nest
  inside `draw_total`; do not add them to it. Frame waits include engine,
  software rendering and presentation, and are not isolated GPU timings.
- The CPU samples run before the rendering phase in the same probe session.
  Short samples, instrumentation, system load and software rendering limit
  precise extrapolation; the later frame measurements remain software-renderer
  timing, not target GPU measurements.

```sh
godot --headless --path . --script res://tests/performance_probe.gd
godot --path . --script res://tests/performance_probe.gd --audio-driver Dummy -- --render
# Optional map selector:
godot --path . --script res://tests/performance_probe.gd --audio-driver Dummy -- --render montreal
```

Use `dist/Godot_v4.7.2-stable_linux.x86_64` instead of `godot` when it is not on
PATH. The probe disables VSync/frame limiting for its process only. It neither
loads player settings nor writes layouts/settings. Unknown arguments fail.
Indexed-lookup disagreement and frozen-frame mesh pixel disagreement fail.

### CPU baseline

| Map | Trains after measurement | Simulation mean / p99 | Hover full miss mean |
| --- | ---: | ---: | ---: |
| Metro demo | 12 | 0.91 / 1.77 ms | 0.18 ms |
| Montreal | 11 | 2.10 / 4.61 ms | 0.62 ms |
| Tokyo central JR | 20 | 3.52 / 6.62 ms | 1.41 ms |

Arrival-containing ticks were more expensive: mean 1.71 / 4.04 / 5.80 ms
respectively. These are subsets of the simulation samples, not additional
costs to add to them.

### Daytime redraw: legacy polygons versus integrated shadow meshes

Latest graphical run on WSL llvmpipe; mean CPU callback times in milliseconds
(legacy polygon path / production mesh path):

| Map | Overview legacy / mesh | 5x legacy / mesh |
| --- | ---: | ---: |
| Metro demo | 2.60 / 1.36 | 4.00 / 2.55 |
| Montreal | 6.57 / 1.99 | 11.77 / 6.57 |
| Tokyo central JR | 133.36 / 7.89 | 136.46 / 10.28 |

These results isolate shadow-path CPU changes; frame wait and total on-target
performance were not measured here. At midnight, corridor shadows are already
skipped, so this particular fix does not help.

## Ranked bottlenecks and remedies

### 1. Corridor shadows repeatedly process large polygons

**Measured and implemented; highest priority.** Before the fix,
[_draw_ground_shadows](../scripts/render/world_view.gd) called
`draw_colored_polygon` on every cached outline. Caching the boundary did not
cache the rendering triangles. Tokyo has 30 shadow polygons, **42,271 vertices**
in total, with the largest polygon containing 4,249 vertices. Montreal has
4,836 vertices; demo has 2,670. The paired legacy-versus-mesh probe isolates
this repeated polygon submission cost.

The implementation constructs indexed `ArrayMesh` resources once during
illumination refresh using `Geometry2D.triangulate_polygon`. Redraw updates only
shadow offset and opacity, preserving the original outlines, layer order,
overlap and alpha rather than using overlapping segment rectangles.

**Validation and measured effect:** all 12 frozen image comparisons (three maps,
two zooms, two times) were byte-identical after integration. On this WSL
software-rendering host, Tokyo overview daytime ground-shadow CPU fell from
125.54 ms to 0.03 ms per draw; full draw CPU fell from 133.36 ms to 7.89 ms.
These timings are not representative of the target gaming PC. Mesh generation
is paid once per illumination refresh (the Tokyo route/illumination/UI rebuild
measured 1.20 s here), not every frame.

### 2. Dense-route position lookups were costly for every car

**Implemented; high priority.** Each route and loop's reverse route now stores a
`PackedFloat64Array` of cumulative segment lengths. Runtime train rendering,
gangways, shadows, headlights, dispatch poses, train picking, station visits and
screensaver framing use binary search over that cache.
[point_at_distance](../scripts/render/track_geometry.gd) now uses the route's
cached index at runtime. Each train's car positions and axes are computed once
per draw and reused for bodies, gangways, train shadows and headlights.
[car_axis](../scripts/render/track_geometry.gd) still does two or sometimes
three point queries per car, but only once per displayed state.

Tokyo's longest circuit has **3,636 points**. Two thousand evenly distributed
queries took 126.05 ms through the legacy linear path versus 1.29 ms through the
production indexed path: **98x faster for this lookup** on this host. This is
not an overall FPS speedup claim.

**Remaining optimization:** a per-train segment cursor with a binary-search
fallback may be worth considering only after profiling; preserve wraparound,
segment-boundary behavior, terminal reversal cusps and the current very fine
curve geometry.

**Validation:** production cached and uncached point/axis results agree within
0.0001 world units at tested segment boundaries, sampled interior distances and
out-of-range inputs. The performance probe also checks evenly distributed
distances and every segment boundary on each bundled map's longest route; the
Tokyo run reported zero measured positional error. Do not lower curve quality
as the first remedy.

### 3. Invisible and stationary objects still incur redraw work

**Verified in code and stage measurements; high priority.**
[set_dynamic_state](../scripts/render/world_view.gd) queues a redraw every frame.
The same node redraws all tracks, all station rings, every train and every
platform. Individual passengers have a visibility check, but platform outlines,
seams and tactile dots do not. Train bodies, train shadows and headlights have
no viewport guard.

Tokyo spends about 14 ms on train bodies/gangways even at overview. At 5x, the
draw callback still processes the entire fleet, not just the train being followed.
Platform drawing adds about 5 ms at close zoom, including offscreen platforms.
At night, headlights add about 5.5-6 ms; each train builds 96 beam quads plus
six glow circles every redraw. Even daytime headlights calculate route poses
before discovering that their light strength is zero.

**Fix:**

- Cull a whole train before pose/detail/light work, using a conservative bound
  covering its full length, bends, shadow and beam extent. Never cull simulation.
- Cache platform bounds and reject offscreen visits before submitting polygons,
  seams or dots. Keep occupancy/exchange timing independent of zoom/visibility.
- Retain rails, station rings and platform geometry in separate nodes/meshes.
  Camera movement should transform retained drawing, not regenerate it.
  Invalidate geometry on edits, color on recolor, and AA/detail only when the
  applicable zoom threshold changes. Update day/night appearance through
  material parameters or retained-node modulation.
- Cache the small headlight mesh and car shells. Skip headlight pose work when
  the light strength is zero. Preserve the current bounded glow and fading beam.

**Status:** train/platform culling, cached shells and batched headlights are
implemented and measured (see Fleet scaling). Visit culling uses
`StationVisit.visible_in`; its bounds must enclose the platform and every
passenger disc, which a debug assertion and `schedule_smoke` enforce.
The base rail paths and corridor-shadow meshes now live in
`StaticTrackLayer`; their draw commands are retained across camera motion and
ordinary frames. Topology changes, line recolors and the antialias zoom
threshold invalidate the rail layer; shadow position/opacity update through
retained nodes. Station markers and active/fading platform visits remain in the
dynamic pass because their color, selection and passenger state change. Shadow
polygons are merged into one surface and night halo polygons into one mesh per
line. Train shell/nose geometry is submitted in one batch per train. When
paused and timed UI transitions are finished, the render loop sleeps until
input or resize; pause also holds the day/night phase.

### 4. Repeated service calculations and arrival geometry cause CPU spikes

**Measured baseline plus source trace; medium/high priority.**
[departure_headway](../scripts/dispatch/dispatcher.gd) calls `service_fleet`,
which calls capacity/recommendation calculations; these repeatedly walk station
stops and recompute cycle estimates. `_tick`, `_retire_surplus` and station
regulation/departure paths call them repeatedly. Just one headway query per
line costs about **0.8 ms on Montreal / 1.5 ms on Tokyo** in the final graphical
probe's CPU phase; this is a microbenchmark, not the complete dispatch tick.

`movement_authority` scans every train for every queried train. This becomes
quadratic as fleets grow. The bundled fleets do not establish its worst case.
Arrival ticks also synchronously construct [StationVisit](../scripts/sim/station_visit.gd)
platform geometry, smoothing, polygon operations and passenger walking paths,
even when their visuals will be hidden at overview.

**Fix:** cache cycle/capacity/headway estimates and invalidate on topology,
wagons, interval, dwell, speed, acceleration, braking and recovery changes.
Keep per-circuit train collections; consider ordered leaders only after
profiling larger fleets, with explicit correctness around withdrawal, spawning,
wraparound and terminal reversal. Separate authoritative passenger counts/timing
from optional visual geometry; build/reuse the latter when needed, without
changing exchanges or dwell. Do not weaken safety to gain speed.

**Status:** implemented (estimate cache, circuit index, lazy visit geometry).

### 5. Editing and color selection perform unnecessary rebuilds

**Measured rebuild/hover costs; medium priority for snappiness.**
Tokyo's topology/illumination/UI rebuild takes about **1 second** locally.
[_on_line_color_changed](../scripts/main.gd) previously rebuilt shadow outlines,
junction masks, halo polygons and nodes even though topology had not changed.
Continuous recoloring now updates retained rail colors and existing halo
vertex colors without clipping/offsetting the paths or rebuilding UI controls.

[_update_hover](../scripts/main.gd) previously rescanned tracks and called
`TrackGeometry.sample`, re-running adaptive curve subdivision even for an
unmoving pointer. It now reuses sampled paths, anchors and broad-phase bounds
until topology changes, and skips the query when pointer, camera, zoom and
interaction state are unchanged. Destination validity is cached by route source,
pinned geometry, posture, active line and network revision.

**Implemented behavior:** cached picking paths/anchors and broad-phase bounds
invalidate on network rebuild; hover recomputes only when pointer, camera, zoom
or interaction state changes. Destination validity is cached by source,
pinned geometry, posture and network revision. Recolor updates existing
retained nodes and vertex colors without redoing polygon clipping/offsets or
refreshing unrelated configuration controls. Station-handle precedence and
error previews are unchanged.

**Status:** implemented. Tokyo on WSL llvmpipe: stationary-pointer hover
cache-hit mean/p99 **0.001/0.001 ms** (600 calls); moving full-miss hover
mean **0.510 ms** (100 samples); retained-geometry line-color refresh mean
**0.332 ms** (100 samples). These are CPU microbenchmarks, not target-PC frame
rates.

### 6. GPU cost and frame pacing still need target-PC measurement

**Candidates, not established causes on the user's GPU.**
[matte_surface.gdshader](../scripts/render/matte_surface.gdshader) now reads
world-anchored grain from a precomputed repeating texture at its original two
scales, avoiding per-fragment sine hashes. The Web export and an actual browser
on the underpowered target still need end-to-end frame-time measurement.

[TransitDispatcher.process](../scripts/dispatch/dispatcher.gd) is now driven by
a 60 Hz accumulator, independent of render refresh. Rendered car/camera poses
interpolate between simulation ticks with wrap-safe route distances; a direction
reversal snaps to the new route pose rather than blending incompatible routes.
Manual and cinematic follow use that same rendered position. Manual follow
resets Camera2D smoothing each frame (without changing normal navigation's
smoothing setting), and both paths apply the camera transform before drawing.
Otherwise a second smoothing stage or a simulation/render mismatch lets the
followed train drift across pixels despite steady frame times.
At most four simulation ticks are run in one rendered frame. Any remaining time
stays in the accumulator and catches up on later frames; no elapsed simulation
time is discarded, though a long hitch can leave simulation temporarily behind
wall time. Pause freezes that backlog. Validate input-to-display latency and
VSync on the target PC; disabling VSync is a diagnostic, not the recommended
permanent fix.

## Definition of smooth enough

Proposed acceptance criteria, to verify on the gaming PC before promising results:

1. Full Montreal fleet and Tokyo, overview/pan/follow, day/night, at native
   window size and fullscreen/high-DPI. Measure at least 60 seconds per case,
   including simultaneous arrivals, recolor, zoom and edit activity.
2. Aim for **120 FPS** on the high-end PC: frame p95 <= 8.33 ms, p99 <= 12 ms,
   no recurrent >16.67 ms frames during steady pan/follow/arrivals. Match refresh
   up to 144 Hz where feasible; retain a stable 60 FPS floor on slower targets.
3. Keep dispatch p99 under 2 ms for bundled full fleets and leave headroom for
   input, draw submission and GPU work. These are targets, not current results.
4. No visible curve/glow/shadow degradation, broken picking, teleporting cars,
   altered dwell/occupancy, safety-gap regression or terminal deadlock.
5. Run existing simulation/schedule/terminal/preset and pixel tests after each
   production optimization. Use `extended` coverage before release publication.

The prior investigation refreshed and verified Windows and universal macOS
exports; the Windows executable also passed headless startup. For this follow-up,
native Windows GPU/pacing, macOS execution/Gatekeeper, browser Web timing,
4K/high-refresh and low-end device profiling remain unverified. Local smoke and
graphical checks are not a substitute for those platform measurements.
