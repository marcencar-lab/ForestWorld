# Forest World

A procedurally generated 3D open-world forest for **Godot 4.7** — hills, a lake with
fish, a low-poly conifer/broadleaf forest, native wildlife that wanders and grazes,
and a brown bear that hunts them.

Everything is generated in code at startup — geometry *and* sound. There are no
imported models, textures or audio files, so the project runs straight from a clone
(~1.2 s of generation on a mid-range machine).

## Running it

Open `project.godot` in Godot 4.7 and press **F5**, or from a terminal:

```bash
godot --path .
```

## Controls

| Key | Action |
| --- | --- |
| Mouse | Look |
| `W` `A` `S` `D` | Move (hold `Shift` to sprint) |
| `Space` | Jump / fly up |
| `Ctrl` | Fly down |
| `F` | Toggle fly mode |
| `Tab` | Cycle camera: player → bear → the bear's current prey |
| `R` | Teleport next to the bear |
| `T` | Toggle the day–night cycle (starts paused at mid-afternoon) |
| `V` | Toggle volumetric fog |
| `M` | Mute / unmute audio |
| `H` | Hide the controls panel |
| `Esc` | Release the mouse (click to recapture) |

## What's in the world

**Terrain** — a 440 × 440 m heightmap from layered, domain-warped simplex noise, with
a lake basin carved into it and a mountain rim to enclose the playfield. Height is
defined analytically in `ForestTerrain.sample_height()`, so animals, props and spawn
points query the ground directly instead of raycasting. The visual mesh is 220 × 220
quads with vertex colours (grass / dry meadow / rock / sand / silt); collision uses a
separate half-resolution trimesh.

**Lake** — a custom shader with vertex waves, depth-based colour, shoreline foam and
screen-space refraction, plus a belt of reeds in the shallows.

**Forest** — ~1500 trees in three species (pine, broadleaf, birch) plus bushes, rocks,
stumps and 22 000 grass tufts. All of it is baked into per-chunk `MultiMesh`
instances with visibility ranges, so the ground cover culls with distance. Trees have
cylinder colliders you can walk into.

**Wildlife** — 39 prey animals across four species (roe deer, hare, red fox, wild
boar). Each has a state machine: wander → graze → flee. They avoid water and steep
ground, follow the terrain slope with their bodies, and animate their legs, neck and
tail from their own gait. They tire while sprinting, which is what eventually lets the
bear catch one.

**The bear** — roams, then locks onto the nearest prey within 105 m, stalks, charges,
and swipes when it gets within range. After a kill it feeds on the carcass for a few
seconds before hunting again. Killed animals are removed after a while and the
population is topped back up away from the bear.

**Fish** — 84 trout in seven loose schools plus 6 solitary pike. Trout steer toward a
personal slot around a slowly drifting school anchor with separation from their
neighbours; they scatter if the bear or the player comes to the water's edge, and
occasionally breach the surface with a splash.

**Audio** — 20 sounds, all synthesised into `AudioStreamWAV` buffers at startup
(~0.5 s); no sample files. Four looping ambience beds (wind, lake wash, daytime
insects, night crickets) are mixed live against time of day, your altitude and your
distance to the shoreline. Everything else is positional: birdsong dropped randomly in
the canopy around you (owls after dark), per-species idle calls and alarm calls, pain
and death cries, the bear's growls, roars and swipes, undergrowth rustling as animals
bolt past, splashes when a trout breaches, and your own footsteps — which change when
you're wading.

The synthesis is in `AudioSynth`: filtered noise beds for ambience, swept-oscillator
chirps for birds, and a shared "glottal buzz through a formant filter" voice model that
every land animal is a preset of. Voices route through an SFX bus with a light reverb.

## Source layout

```
scenes/main.tscn        empty Node3D + world.gd — everything else is built at runtime
scripts/world.gd        orchestrator: terrain, lighting, scattering, cameras, HUD
scripts/forest_terrain.gd   heightmap, colouring, mesh + collision, ground queries
scripts/flora.gd        low-poly tree / bush / rock / grass mesh builders
scripts/species.gd      body plan + AI tuning tables for every land animal
scripts/critter_builder.gd  assembles a quadruped from primitives
scripts/animal.gd       prey AI, movement, procedural gait
scripts/bear.gd         predator AI: patrol / stalk / chase / attack / feed
scripts/fish.gd         fish body, schooling, breaching
scripts/wildlife_manager.gd spawning, shared queries, corpses, respawns, effects
scripts/audio_synth.gd  DSP: filters, oscillators, every sound in the game
scripts/audio_director.gd   buses, ambience mixing, positional one-shots
scripts/player_controller.gd  walk + fly observer camera
scripts/forest_hud.gd   controls panel, live stats, event toasts
shaders/sky.gdshader    gradient sky with drifting procedural clouds
shaders/water.gdshader  lake surface
```

## Tuning

Most of the feel lives in constants at the top of the relevant script:

- World size, lake position/radius and water level: `ForestTerrain`
- Vegetation counts and view distances: the `*_TARGET` / `*_VIEW` constants in `world.gd`
- Animal speeds, health, flee radius and stamina: `Species.DATA`
- Bear aggression (hunt radius, damage, cooldown, feed time): constants in `bear.gd`
- Fish counts and school sizes: constants in `wildlife_manager.gd`
- Sound design: the generator functions in `AudioSynth`; per-species call pitch and
  audible range in `AudioDirector.VOICES`; bus levels in `AudioDirector._setup_buses()`

`WORLD_SEED` in `world.gd` regenerates the entire map — terrain, forest layout and
spawn points are all derived from it.

## Known limitations

- Animals move kinematically over the heightmap rather than through the physics
  engine. This is deliberate (it is far cheaper for dozens of agents and never jitters
  on slopes), but it means they walk through trees and through each other.
- Corpses fade out on a timer rather than being eaten away.
- The synthesised audio is deliberately stylised — it reads as "forest", but it is
  oscillators and filtered noise, not recordings.
- Forward+ only. A web export would need the Compatibility renderer, which has no
  volumetric fog, no SSAO, and no depth texture — the last of which the lake shader
  relies on for its depth tinting and shoreline foam.

## License

MIT — see [LICENSE](LICENSE).
