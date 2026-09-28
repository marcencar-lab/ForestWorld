# Forest World

A procedurally generated 3D open-world survival game for **Godot 4.7**: hills, a
lake full of fish, a low-poly forest, native wildlife, and a brown bear that hunts
anything it can hear or smell, including you. Gather, craft, build a cabin, search
abandoned ruins for supplies and weapons, and see how long you last, alone or
online with friends.

## Download and play

Grab the latest Windows build from the
[Releases page](../../releases/latest), unzip it anywhere and run
`ForestWorld.exe`. No install needed. It needs a graphics card with Vulkan
support (most from the last ~8 years).

Everything is generated in code at startup, geometry *and* sound. There are no
imported models, textures or audio files, so the project runs straight from a clone
(~1.3 s of generation on a mid-range machine).

## Running it

Requires **Godot 4.7** (Forward+ / Vulkan). No add-ons, no downloads.

Open `project.godot` in the Godot editor and press **F5**. The start menu offers
single player, hosting and joining.

To run from a terminal instead, a freshly cloned copy needs one import pass
first. The `class_name` registry lives in the gitignored `.godot/` folder, so
until the project has been scanned once, the scripts can't see each other:

```bash
godot --path . --headless --import
```

After that, this launches it directly and every time after:

```bash
godot --path .
```

## Playing online with friends

Up to 8 players can share one world. From the start menu:

- **Host a game**: your copy of the game runs the world. The bottom-right corner
  shows the address friends should use once it's ready.
- **Join**: type the host's address (for example `203.0.113.5`, or
  `203.0.113.5:24517` for a non-default port) and press Join.

**Getting connected.** The game uses **UDP port 24517**.

- **Same house / same Wi-Fi**: join with the host's local address (shown on the
  host's screen, looks like `192.168.x.x`). Nothing else to set up.
- **Over the internet**: when you host, the game asks your router to open the port
  automatically (UPnP). If that works, the host's screen shows the public address to
  share. If the router refuses, either forward UDP port 24517 to the host's PC in
  your router settings, or have everyone install a free virtual-LAN tool such as
  [Tailscale](https://tailscale.com) and join with the host's Tailscale address.
- The first time you host, Windows may ask whether Forest World may use the
  network; allow it on private networks.

**What's shared:** the world itself. Wildlife, the bear, fish, weather and time of
day come from the host, so everyone sees the same thing. Felled trees, picked-up
rocks, buildings, doors, campfires and looted crates are shared too, including
for players who join later. The bear hunts whoever it senses, and you can see each
other walking around with name tags.

**What's yours:** your own inventory, tools and vitals. If you die online you
respawn by the lake with empty pockets while the world carries on. Sleeping can't
skip the night while others are playing; it just gives you a rest.

## Playing

You start by the lake with a fishing rod and nothing else. Five bars keep you
alive: **health**, **stamina** (sprinting, swimming), **food**, **water** and
**warmth**. Any of the last three reaching zero starts costing health. The game ends
when you die, and your best survival time is saved.

**The progression loop**

1. Pick up loose **rocks** from the ground (`E`).
2. Hold a rock and hit a tree (left click) to knock **branches** off.
3. Craft a **stone axe** (`Tab`, 1 rock + 3 branches).
4. Fell trees for **logs**. They topple away from you.
5. Saw logs into **planks** (`Tab`, needs an axe).
6. Build (`B`): a lean-to and campfire early on, then floors, walls, a door and a roof.

**The bear** notices you at a distance that depends on how much noise you make
(crouch with `C` to sneak, sprinting is loud) and how much fish or meat you're
carrying. Your sprint is slower than its charge. It wades only into the shallows,
so deep water is a refuge, but swimming drains stamina and you drown when it runs out.
It can't walk through walls: it will claw at a wall between you and it, then lose
interest. A branch lean-to won't stop it, but plank walls will. Damaged pieces can
be repaired (`R`). Hurt it badly enough and it flees; kill it and another bear
wanders in later.

**Weather**: rain showers roll in every few minutes. Rain and cold nights drain
warmth; a roof, lean-to or campfire warms you back up. Rain particles stop at roofs.

**Abandoned cabins**: five weathered, half-collapsed ruins are scattered through
the forest (the compass at the top points to the nearest one you haven't searched).
Their crates hold canned food, bandages, water bottles, planks, arrows, and weapons:
hunting knife, steel hatchet, wooden spear, hunting bow. A ruin is built from the
same pieces as your own buildings, so you can repair one into a base.

**Survival mechanics**

- **Food**: fish with the rod, or hunt deer, boar, foxes and hares for meat.
  Cook it on a lit campfire (`E`); raw food fills you less and can give you
  food poisoning (hunger and thirst drain faster, no healing).
- **Water**: drink at the lake (`E`, or `C`+`E` while holding the rod). Water
  bottles from loot carry four sips each (`X` to drink).
- **Bleeding**: bear claws open wounds that keep draining health until you use
  a bandage (`Z`).
- **Sleep**: build a bedroll under a roof and sleep through the night (`E`),
  as long as nothing dangerous is near.
- **Durability**: tools and weapons wear out with use.

## Controls

| Key | Action |
| --- | --- |
| Mouse | Look |
| `W` `A` `S` `D` | Move (hold `Shift` to sprint) |
| `C` | Crouch / sneak |
| `Space` | Jump |
| Left click | Use the held item (hit, chop, attack, shoot) / place a piece in build mode |
| `E` | Interact: pick up, open, search, cook, fuel a fire, sleep, drink, cast / reel |
| `R` | Repair the building piece you're looking at |
| `1`-`9` | Choose held item (or pick a recipe / build piece when those menus are open) |
| `Tab` | Crafting menu |
| `B` | Build mode (mouse wheel changes piece, right click exits) |
| `Q` | Eat (best food first) |
| `X` | Drink from a water bottle |
| `Z` | Use a bandage |
| `T` | Toggle the day-night cycle |
| `M` | Mute / unmute audio |
| `H` | Cycle the HUD: compact → controls → hidden |
| `P` | Switch to sandbox mode (and back, which restarts); single player only |
| `Enter` | After dying: try again (single player) / respawn (online) |
| `Esc` | Release the mouse (click to recapture) |

**Sandbox mode** (`P`) turns you into an invulnerable observer with free building.
Extra keys there: `F` fly (`Space`/`Ctrl` up/down), `Tab` cycles the camera
between you, the bear and its prey, `R` teleports to the bear, `G` toggles rain,
`V` toggles volumetric fog.

## What's in the world

**Terrain**: a 440 × 440 m heightmap from layered, domain-warped simplex noise, with
a lake basin carved into it and a mountain rim to enclose the playfield. Height is
defined analytically in `ForestTerrain.sample_height()`, so animals, props and spawn
points query the ground directly instead of raycasting. The visual mesh is 220 × 220
quads with vertex colours (grass / dry meadow / rock / sand / silt); collision uses a
separate half-resolution trimesh.

**Lake**: a custom shader with vertex waves, depth-based colour, shoreline foam and
screen-space refraction, plus a belt of reeds in the shallows.

**Forest**: ~1500 trees in three species (pine, broadleaf, birch) plus bushes, rocks,
stumps and 22 000 grass tufts, all baked into per-chunk `MultiMesh` instances with
visibility ranges. `TreeRegistry` remembers which MultiMesh slot and collider belong
to each tree, so a single tree can lose its branches, be chopped down and replaced
with a falling trunk and a stump.

**Wildlife**: 39 prey animals across four species (roe deer, hare, red fox, wild
boar). Each has a state machine: wander → graze → flee. They avoid water, steep
ground and buildings, follow the terrain slope with their bodies, and animate their
legs, neck and tail from their own gait.

**The bear**: roams, then locks onto the nearest prey within 105 m (or you, if it
senses you), stalks, charges, and swipes when it gets within range. It feeds after
a kill, heals while calm, flees below 35 % health, and can be killed. It belongs
to the `hostile` group, which is what weapons, arrows and the kill/reward logic
look for, so future enemies only need to join that group and implement
`is_alive()` / `take_damage(amount, from)`.

**Fish**: 84 trout in seven loose schools plus 6 solitary pike. Trout steer toward a
personal slot around a slowly drifting school anchor; they scatter from the shore
when something big comes near, and occasionally breach. A caught fish leaves the
lake for real, and the lake restocks slowly.

**Buildings**: pieces snap to a 3 m grid (walls and doors to cell edges). Each piece
is a `Structure` with health; walls and doors also keep 2D segments that the bear
and animals test against, since they move kinematically rather than through physics.

**Audio**: about 25 sounds, all synthesised into `AudioStreamWAV` buffers at startup;
no sample files. Looping ambience beds (wind, lake wash, daytime insects, night
crickets, rain) are mixed live against time of day, weather, shelter, altitude and
distance to the shoreline. Everything else is positional: birdsong, animal calls,
the bear, splashes, chopping, falling trees, campfire crackle and your footsteps.

## Source layout

```
scenes/menu.tscn            start menu (menu.gd): single player / host / join
scenes/main.tscn            empty Node3D + world.gd; everything else is built at runtime
scripts/world.gd            orchestrator: world build, survival rules, input, crafting, interaction,
                            and the shared-world action layer (_act / _do) used online
scripts/session.gd          how the game was started (mode, address, name), saved settings
scripts/net_sync.gd         online play: ENet host/join, UPnP, snapshots, requests, events
scripts/remote_player.gd    other players as seen on your screen
scripts/forest_terrain.gd   heightmap, colouring, mesh + collision, ground queries
scripts/flora.gd            low-poly tree / bush / rock / grass mesh builders
scripts/tree_registry.gd    per-tree state: branches, chopping, felling
scripts/loose_rocks.gd      pick-up stones on the forest floor
scripts/species.gd          body plan + AI tuning tables for every land animal
scripts/critter_builder.gd  assembles a quadruped from primitives
scripts/animal.gd           prey AI, movement, procedural gait
scripts/bear.gd             predator AI: patrol / stalk / chase / attack / feed / flee
scripts/fish.gd             fish body, schooling, breaching
scripts/wildlife_manager.gd spawning, shared queries, corpses, respawns, effects
scripts/player_controller.gd  movement, vitals, inventory
scripts/fishing_rod.gd      cast, bite, catch
scripts/tool_hand.gd        first-person held items and swing animations
scripts/arrow.gd            bow projectiles
scripts/items.gd            item, food, weapon and loot-table data
scripts/build_system.gd     grid placement, ghost preview, piece geometry, shelter queries
scripts/structure.gd        one placed piece: health, door, campfire, crate
scripts/ruins.gd            abandoned cabins and their crates
scripts/weather.gd          rain showers
scripts/audio_synth.gd      DSP: filters, oscillators, every sound in the game
scripts/audio_director.gd   buses, ambience mixing, positional one-shots
scripts/forest_hud.gd       vitals, prompts, compass, menus, toasts, game over
shaders/sky.gdshader        gradient sky with drifting procedural clouds
shaders/water.gdshader      lake surface
```

## Tuning

Most of the feel lives in constants at the top of the relevant script:

- Player speeds, vitals drain rates, warmth, bleeding: `PlayerController`
- Food values, weapon damage / reach / durability, loot tables: `Items`
- Recipes, tool cooldowns, sleep hour: the constants above `_unhandled_input` in `world.gd`
- Building costs and health: `BuildSystem.PIECES`
- Bear aggression, hearing, wall behaviour and fleeing: constants in `bear.gd`
- Rain timing: `Weather`
- World size, lake position/radius and water level: `ForestTerrain`
- Vegetation counts and view distances: the `*_TARGET` / `*_VIEW` constants in `world.gd`
- Animal speeds, health, flee radius and stamina: `Species.DATA`
- Fish counts, restocking and bear respawns: constants in `wildlife_manager.gd`

`WORLD_SEED` in `world.gd` regenerates the entire map: terrain, forest layout,
ruins and spawn points are all derived from it.

## Tests

Headless playtests live in `tests/`. From the project folder:

```bash
godot --path . --headless --fixed-fps 60 -s tests/survival_test.gd
```

`build_test.gd` and `loot_test.gd` run the same way. The multiplayer pair needs two
terminals: start `tests/mp_host.gd` first, then `tests/mp_client.gd`.

## Known limitations

- Animals and the bear move kinematically over the heightmap rather than through
  the physics engine. They respect buildings, but walk through trees and each other.
- The bear heads straight for you; it claws at a wall rather than pathing round to
  an open door.
- Corpses fade out on a timer rather than being eaten away.
- The synthesised audio is deliberately stylised.
- Online play has no host migration: when the host quits, the game ends for
  everyone. There's no server browser; you share the host's address yourself.
- Forward+ only. A web export would need the Compatibility renderer, which has no
  volumetric fog, no SSAO, no depth texture (the lake shader needs it) and no GPU
  particle collision (the rain needs it).

## License

MIT (see [LICENSE](LICENSE)).
