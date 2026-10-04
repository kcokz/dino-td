# res://scripts/entities/RunnerDino.gd
class_name RunnerDino
extends "res://scripts/entities/Dino.gd"

## THE RUNNER (GAME-DESIGN 7.2, station one's Hesperosuchus; v0.6 round six, the player: "恐龙每次都是从一个地方来
## 进攻，物种到day 4也就一种，太单调" -- chosen "快跑的黄昏鳄"). Quick and brittle (Config.DINOS.hesperosuchus): it
## runs for the cabin, the thing that fell into its valley, and past whatever shoots at it -- it does not stop for a
## tower. It came for the man from across the field; since 2026-10-03 (the player: "对人，优先级低一些，优先攻击攻击
## 它们的") only for the man who strikes at it (Dino._provoker), as every raider does. What answers it is what is
## laid in its way (the spikes: CellTrap) or stands across it (a wall: gone round, or bitten through).

## The man who has just struck at it; else only what it runs into -- on its way to the cabin.
func _preferred_target() -> Node:
	var hero: Node = _provoker()
	if hero != null:
		return hero
	return _nearest_building_within(building_interest_range())

## Not for the man on his own (Dino._think).
func hero_interest_range() -> float:
	return 0.0

## Towers are not what it is after: it runs past them.
func trap_interest_range() -> float:
	return 0.0

## Only what it all but runs into.
func building_interest_range() -> float:
	return 1.0
