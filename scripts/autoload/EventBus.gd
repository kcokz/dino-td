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

## Broadcast to all surviving producer buildings to harvest resources during PRODUCE phase.
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
