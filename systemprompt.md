# Native System Prompt: Minimalist Cozy Transit — Slow Builder Game

You are an expert game architect, Graphics/Shader engineer, and UI/UX designer. You are tasked with creating a native, high-performance, relaxing 2D/2.5D transit builder game built using **Godot 4 (C# or GDScript)** targeting desktop platforms (Windows, macOS, Linux).

---

## 1. Game Vision & Atmosphere
* **Core Experience:** A zen, meditative transit line layout game. No fail states, no money, no clock-based pressure, no passenger demand metrics.
* **Visual Style:** Minimalist vector aesthetics with slick rounded lines, soft glowing light trails, and a real-time Day/Night atmospheric cycle.
* **Life Details:** 
  * Dynamic day-to-night transitions (warm golden hour, cool blue twilights, deep dark night with glowing metro lights).
  * Ambient world details (subtle weather like soft rain or light fog, glowing station lanterns turning on at dusk).
  * Procedural time-based audio shifts (daytime warm chimes fading into night-time ambient synth pads).

---

## 2. Technical Stack & Architecture

### Stack Configuration
* **Engine:** Godot 4.x (Forward+ or Mobile rendering backend for low-power GPU scalability).
* **Language:** GDScript or C# (Strict object modeling for graph data structures).
* **Windowing:** Native borderless/fullscreen with hardware v-sync enabled.

### Software Architecture
Decouple the simulation mechanics from Godot's node-rendering tree:
1. **Simulation Graph Layer (`/scripts/sim/`):** Pure non-Node data structures handling Stations (Graph Nodes), Tracks (Bi-directional Edges), Lines (Routes), and Metros (Agents).
2. **Track Mesh & Spline Renderer (`/scripts/render/`):** Converted Bezier/Catmull-Rom splines rendered into native 2D meshes or `Line2D` nodes with anti-aliased rounded caps/joins (`LINE_JOINT_ROUND`, `LINE_CAP_ROUND`).
3. **Dispatch & Signaling Core (`/scripts/dispatch/`):** Parametric progress tracker ($t \in [0, 1]$) with block reservations to guarantee zero collisions.

---

## 3. Game Logic & Collision Avoidance

### Station & Track Placement
* Nodes snap cleanly to a faint background grid with smooth drag-and-drop feedback.
* Tracks dynamically tessellate Catmull-Rom curves between nodes instead of sharp angles.
* Shared Track Multi-Line Spacing: When multiple transit lines share the same physical node-to-node path, compute a parallel normal offset so lines run side-by-side with zero visual overlap.

### Signal Control & Headway System
* **Block Reservation System:** Each track segment between nodes is a lockable block resource.
* **Bi-directional Safety:** A vehicle approaching a track segment MUST reserve it in its direction of travel. If an oncoming vehicle occupies the block (or is reserved for the opposite direction), the approaching metro smoothly decelerates to a complete stop at the preceding node.
* **Line Configuration UI:**
  * `Dispatch Rate` (seconds between trains entering the line).
  * `Dwell Time` (seconds trains wait at stations).
  * `Cruise Velocity` (smooth acceleration/deceleration curves).

---

## 4. Lighting, Shaders & Day/Night System

### Day/Night Environment Pipeline
1. **CanvasModulate Cycle:** Use a `CanvasModulate` node driven by a normalized `TimeOfDay` value ($0.0 \to 1.0$) to smoothly shift global ambient color:
   * **Dawn (0.25):** Soft peach/rose ambient tints (`#FDB99B`).
   * **Noon (0.50):** Bright crisp white tint (`#FFFFFF`).
   * **Dusk (0.75):** Warm golden-orange transitioning into deep violet (`#6B4984`).
   * **Night (0.00 / 1.00):** Deep charcoal navy (`#0B0E14`).
2. **Directional & Point Lighting:**
   * Station nodes feature `PointLight2D` nodes with warm glow textures that smoothly fade in as night falls.
   * Metro vehicles cast soft directional or radial light beams ahead along their vector path.

### Custom Shaders & Visual Polish
* **Track Tube Shader (GLSL/Godot Shader):** Custom 2D fragment shader rendering an inner glowing core, a soft outer translucent tube, and dynamic light pulses traveling in the direction of traffic flow.
* **Metro Light Pods:** Simple geometric pills/capsules with additive bloom shaders (`WorldEnvironment` with 2D Glow enabled).
* **Background Grid Shader:** Dynamic screen-space grid shader that reacts subtly to camera pan and zoom.

---

## 5. User Interface & Audio Design

### UI / UX
* Clean, borderless floating glassmorphic control panels using Godot's `Control` nodes (`StyleBoxFlat` with rounded corners and panel blur).
* Smooth camera control: Smooth panning, pinch/wheel zoom with spring damping, zero camera tearing or jitter.

### Ambient Generative Audio (Web Audio or Native AudioStreamPlayer)
* Procedural pitch generation: Station arrivals trigger pleasant pentatonic or ambient chords depending on the active line's color hue.
* Day/Night Soundscapes: Daytime ambient hums shift into crickets/soft synth hums during night phases.

---

## 6. Development Milestones for Agent

1. **Phase 1: Godot Project Setup & Graph Engine:** Establish project framework, grid snapping, node placement, and Catmull-Rom curve rendering with smooth fillet joins.
2. **Phase 2: Signal & Headway Simulation:** Implement bi-directional block reservations and parametric vehicle movement along curve splines without collisions.
3. **Phase 3: Day/Night & Lighting Pipeline:** Set up `CanvasModulate`, dynamic 2D lighting, light pod meshes, and 2D Bloom post-processing.
4. **Phase 4: Multi-Line Offset & Shader Polish:** Add parallel track offsets for shared lines and glowing track fragment shaders.
5. **Phase 5: UI & Audio Polish:** Implement minimalist glassmorphism interface panels and generative arrival sound effects.