# res://scripts/entities/RunnerDino.gd
class_name RunnerDino
extends "res://scripts/entities/Dino.gd"

## THE RUNNER (GAME-DESIGN 7.2, station one's Hesperosuchus; v0.6 round six, the player: "恐龙每次都是从一个地方来
## 进攻，物种到day 4也就一种，太单调" -- chosen "快跑的黄昏鳄"). Quick and brittle (Config.DINOS.hesperosuchus): it
## comes for the man wherever he is within `hunts_within` metres, and past whatever shoots at it -- it does not
## stop for a trap, and it bites the cabin only with him nowhere near. What answers it needs no re-arming
## (spikes, a snare: CellTrap) or stands between him and it (a wall: gone round, or bitten through when he is
## shut away, as by any raider).

## The man, near enough; else only what it runs into.
func _preferred_target() -> Node:
	var hero := _hero_within(hero_interest_range())
	if hero != null:
		return hero
	return _nearest_building_within(building_interest_range())

## How far it comes for him from (Config.DINO_AI.runner_hunts_within).
func hero_interest_range() -> float:
	return _ai("runner_hunts_within", 18.0)

## Traps are not what it is after: it runs past them.
func trap_interest_range() -> float:
	return 0.0

## Only what it all but runs into.
func building_interest_range() -> float:
	return 1.0
