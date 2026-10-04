# res://scripts/entities/PackDino.gd
class_name PackDino
extends "res://scripts/entities/Dino.gd"

## Small, fast, and never alone: the swarming habit.
##
## A pack dinosaur answers whatever attacks it. It will break off the path for a
## tower because a tower is what is shooting at it, it will turn on the Hero when
## he strikes at one of them, and it bites whatever is in the way rather than
## picking a favourite. That is what makes a raid of them feel like a raid: they
## react to what the player does. The man on his own it leaves be: it came for the
## cabin (Dino._think).
##
## Everything about how it moves, fights and dies lives in Dino. This file is only
## what a raptor *wants* -- which is the one thing that differs by species, and so
## the one thing a behaviour subclass is for. Any new small pack species uses this
## class as-is: the habits are shared, only the numbers in Config differ.

## A trap is the thing hurting it, and worth leaving the path for.
func trap_interest_range() -> float:
	return 4.5

## It will stop for anything it nearly walks into.
func building_interest_range() -> float:
	return 2.0

## Not for the man on his own (2026-10-03, the player: "对人，优先级低一些，优先攻击攻击它们的"): only for the man who
## has struck at them (Dino._provoker). It was three metres -- a pack noticed you -- and walked off the cabin for him.
func hero_interest_range() -> float:
	return 0.0

## Threat order: whatever is attacking it -- the tower shooting, the man who has just
## struck at one of them, the nearer of the two -- then whatever happens to be in the
## way. A raptor being shot in the back does not turn round for somebody further off.
## What a pack wants. Whether it may have it is decided by Dino._find_threat_priority_target,
## which applies the rule about walls that are not in the way -- this used to override
## THAT method and so skipped the rule entirely.
func _preferred_target() -> Node:
	# The trap that is shooting at it, first; else the nearest -- and neither if every place round
	# it is taken (Dino._is_crowded, BUG-009).
	var trap: Node = _shot_lately()
	# Not across the base for it: one that shot it from the far side is left to the others there.
	if trap != null and _flat((trap as Node3D).global_position).distance_to(_flat(global_position)) > trap_interest_range() * 2.0:
		trap = null
	if trap == null:
		trap = _nearest_building_within(trap_interest_range(), "shooter")
	var hero: Node = _provoker()
	if hero != null:
		if trap == null or global_position.distance_to((hero as Node3D).global_position) < global_position.distance_to(trap.global_position):
			return hero
	if trap != null:
		return trap
	return _nearest_building_within(building_interest_range())
