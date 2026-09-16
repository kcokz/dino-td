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

## Broadcast when all nests are destroyed, transitioning game to Victory state.
signal game_won()

## Broadcast when Campfire Core HP drops to <= 0, transitioning game to Defeat state.
signal game_lost()

# ==============================================================================
# 2. Economy & Action Point Signals
# ==============================================================================
## Emitted whenever current AP or max AP changes (spend, reset, building bonus).
signal ap_changed(current: int, max: int)

## Emitted whenever player resource inventory is modified (spend, harvest).
signal resources_changed(res: Dictionary)

# ==============================================================================
# 3. Building Lifecycle & Campfire Signals
# ==============================================================================
## Emitted when a building is successfully validated and placed on the grid.
signal building_placed(building: Node)

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
# 6. Objective & Nest Signals
# ==============================================================================
## Emitted when the Dinosaur Nest HP reaches 0, prior to deletion.
signal nest_destroyed(nest: Node)

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
