# res://scripts/autoload/EventBus.gd
extends Node

## Global Decoupled Signal Event Bus for Defend Dinosaur v0.0
## All system interactions and cross-boundary events must be broadcast here.
## Direct hard references between entities and systems are strictly forbidden.

# ==============================================================================
# 1. Turn & Phase State Machine Signals
# ==============================================================================
## Emitted when game transitions phase (0: PLAN, 1: ATTACK, 2: PRODUCE).
signal phase_changed(phase: int)

## Legacy phase-machine broadcast. Continuous mode never emits it.
signal produce_phase()

## Broadcast when the run is won: the beacon has charged and the capsule jumps (v0.6,
## GAME-DESIGN 8.3). It used to be the nest going down; the nest cannot be destroyed now.
signal game_won()

## Broadcast when Campfire Core HP drops to <= 0, transitioning game to Defeat state.
signal game_lost()

# ==============================================================================
# 2. Economy & Action Point Signals
# ==============================================================================

## Emitted whenever player resource inventory is modified (spend, harvest).
signal resources_changed(res: Dictionary)

# ==============================================================================
# 3. Building Lifecycle & Campfire Signals
# ==============================================================================
## Emitted when a building is successfully validated and placed on the grid.
signal building_placed(building: Node)

## Emitted when a blueprint becomes a finished building.
##
## SEPARATE FROM building_placed BECAUSE THEY ARE SEPARATE MOMENTS, and the difference is
## the whole of the blueprint rule: ordering a fence puts something on the grid that is
## solid to nobody, and finishing it is when the thing actually starts blocking the way.
## Anything that cares what the world is SHAPED like -- the navigation meshes above all
## -- has to hear the second one, and for a version it did not: the Hero finished a fence
## and the meshes were never rebuilt, so a raid walked through a wall that was standing
## right there. It only ever looked like it worked because placing the NEXT building
## happened to mark them stale.
signal building_completed(building: Node)

## Emitted when a building finishes being upgraded where it stands (v0.6): it is now the
## next building up its line -- its type, its numbers and perhaps its body have changed.
signal building_upgraded(building: Node)

## Emitted when a building's HP reaches 0, prior to deletion.
signal building_destroyed(building: Node)

## Emitted when Campfire Core takes damage or is initialized, for reactive HUD updates.
signal core_hp_changed(current: float, max: float)

# ==============================================================================
# 4. Wave & Spawner Signals
# ==============================================================================
## Emitted by WaveManager when wave n begins spawning.
signal wave_started(n: int, is_big: bool)

## Emitted by WaveManager when all dinosaurs in wave n are eliminated or reach the core.
signal wave_ended(n: int)
## The raid out is one a repaired beacon stage stirred up (WaveManager.start_stage_wave), this many
## strong -- said after its wave_started, which carries the raid count it leaves as it was.
signal stage_wave_started(size: int)
## A part of the day has begun (GameState.day_part: "day", "dusk", "night") on day `day`.
signal day_part_changed(part: String, day: int)
## The nest has come into sight for the first time (FogOfWar): found.
signal nest_found(nest: Node)
## A moment into a run: the mist is to be explained, once (FogOfWar; Config.FOG.hint_after).
signal fog_explained()
## A nest's guards are warning the Hero off (GuardDino, THREATENING): said once a run (HUD).
signal guards_warned(guard: Node)
## A raider whose hours are over is back at its nest and gone (Dino.go_home): not killed.
signal dino_went_home(dino: Node)
## A fire he built was lit, or went out (Fire.gd): at dusk and at first light.
signal fire_changed(fire: Node, lit: bool)
## A fire had no wood for its night in the stock (Fire.gd): said once a night for each (HUD).
signal fire_starved(fire: Node)
## The torch in his hand was lit, or burnt out (Hero.light_torch).
signal torch_changed(lit: bool)
## An animal twitched, and this is the report on it (TwitchWatch): for whatever keeps reports.
signal twitch_detected(record: Dictionary)

# ==============================================================================
# 5. Dinosaur Combat Signals
# ==============================================================================
## Emitted when a dinosaur instance is spawned at the Nest origin.
signal dino_spawned(dino: Node)

## Emitted when a dinosaur's HP reaches 0, prior to deletion.
signal dino_died(dino: Node)

## Emitted when a dinosaur reaches the terminal waypoint and damages the Campfire Core.
signal dino_reached_core(dino: Node)

# ==============================================================================
# 6. The beacon (v0.6): the run's main line
# ==============================================================================
## A step of the beacon is done at the cabin -- a stage repaired, or the launch -- and
## `steps_done` of them are done now (GameState.beacon_steps).
signal beacon_changed(steps_done: int)

## The beacon is switched on: it starts to charge, and the final wave sets out.
signal beacon_launched()

## A raid is over and held: what it cost -- {"wave", "killed", "drops", "lost"} (RunStats).
signal raid_summary(summary: Dictionary)

# ==============================================================================
# 7. Real-Time Deployment & Modern Hero Signals (v0.1)
# ==============================================================================
## Emitted as deployment countdown updates.
signal deploy_time_changed(remaining: float, total: float)

## Emitted when the game is paused or resumed during DEPLOY phase.
signal pause_toggled(is_paused: bool)

## Emitted when Modern Hero takes damage or heals.
signal hero_hp_changed(current: float, max: float)

## Emitted when Modern Hero dies, triggering game over.
signal hero_died()

## Emitted when a building's construction progress changes.
signal build_progress_updated(building: Node, progress: float)

# ==============================================================================
# 8. Continuous Real-Time, Selection & v0.2 Ecosystem Signals
# ==============================================================================
## Emitted when active locale changes ('en' or 'zh_CN').
signal locale_changed(locale: String)

## Emitted prior to a dinosaur raid (e.g. 15s warning) with remaining countdown.
signal raid_warning(time_left: float)

## Emitted with the raid warning when the coming raid brings a boss (v0.6, GAME-DESIGN
## 7.5): which species, so the player knows what to get ready for.
signal boss_warning(species_id: String)

## Emitted when a boss steps out of the nest.
signal boss_arrived(dino: Node)

## Emitted when player selects an interactive unit (Hero, Building, Dino, Resource).
signal unit_selected(unit: Node)

## Emitted when unit selection is cleared.
signal unit_deselected()

## Emitted when game speed multiplier changes (1x, 2x, 3x).
signal game_speed_changed(multiplier: float)

# ==============================================================================
# 9. Drops (v0.3)
# ==============================================================================
## Emitted when a drop on the ground is collected and banked. `by` is whoever
## walked over it (the Hero today), or null.
signal resource_picked_up(res_id: String, amount: int, by: Node)

## Emitted when a drop is created, so anything watching the ground can react
## without having to poll the group.
signal resource_dropped(res_id: String, amount: int, world_pos: Vector3)

# ==============================================================================
# 10. The cabin workshop (v0.4)
# ==============================================================================
## Emitted when a recipe finishes and its flag is granted. Carries the flag, not
## the recipe: what the rest of the game cares about is the ability, not how it
## was made.
signal unlock_granted(unlock_id: String)

## Emitted at every stroke of a wreck's search (ResourceNode.harvest): `struck` of its `strokes` so far --
## what its din carries to (Din).
signal wreck_struck(wreck: Node, struck: int, strokes: int)

## Emitted the first time in a search its din brings something (Din): what -- "river", "guards", "edge".
signal din_carried(wreck: Node, draws: String)

## Emitted when the player pins a goal, or unpins it (GameState.goal): the material bar counts
## against its price (GAME-DESIGN 6.0 rule 4).
signal goal_changed(goal: Dictionary)

## Emitted the first time in a run a material comes into the stock (GameState.known): what
## is built and made of it shows from then on (v0.6: the run unfolds a material at a time).
signal material_discovered(res_id: String)

## Emitted when the player steps into the cabin or back out of it. The world keeps
## running either way -- this only says where the camera and the orders are going.
signal cabin_view_changed(inside: bool)

# ==============================================================================
# 11. Eating (v0.6)
# ==============================================================================
## Emitted when the Hero eats a meal from the kitchen: what it was and what it does,
## as Config.meal_of describes it. The Hero heals from it; GameState keeps the rest.
signal meal_eaten(meal: Dictionary)

## Emitted when the stock of cooked meals changes -- one cooked, one eaten, a new run:
## GameState.meals, "dish/method" -> how many (v0.6 round two).
signal meals_changed(meals: Dictionary)

## Emitted when the Hero becomes fed, or stops being: GameState.fed, empty when the
## last meal has worn off.
signal fed_changed(fed: Dictionary)

# ==============================================================================
# 12. His voice (v0.6 round three)
# ==============================================================================
## Emitted when the Hero says something (HeroVoice): the strings.csv key of the line, and how long
## it stays up. The HUD puts it over his head.
signal hero_spoke(line_key: String, seconds: float)

## Emitted at the launch when the valley will answer after a while (MAPS.beacon.launch_grace): the
## seconds until the final wave sets out. GameState.final_wave_in counts them down.
signal final_wave_warning(seconds: float)
