# res://scripts/entities/PackDino.gd
class_name PackDino
extends "res://scripts/entities/Dino.gd"

## Small, fast, and never alone: the swarming habit.
##
## A pack dinosaur is interested in everything nearby. It will break off the path
## for a turret because a turret is what is shooting at it, it will turn on the
## Hero when he makes himself loud, and it bites whatever is in the way rather
## than picking a favourite. That is what makes a raid of them feel like a raid:
## they react to what the player does.
##
## Everything about how it moves, fights and dies lives in Dino. This file is only
## what a raptor *wants* -- which is the one thing that differs by species, and so
## the one thing a behaviour subclass is for. Any new small pack species uses this
## class as-is: the habits are shared, only the numbers in Config differ.

## A turret is the thing hurting it, and worth leaving the path for.
func tower_interest_range() -> float:
	return 4.5

## It will stop for anything it nearly walks into.
func building_interest_range() -> float:
	return 2.0

## And it will come for the Hero when he is close, whether or not he provoked
## them -- a pack notices you.
func hero_interest_range() -> float:
	return 3.0

## Threat order: whatever is shooting, then the man who just made himself the
## loudest thing on the field, then whatever happens to be in the way.
##
## Provocation outranks a turret only when the Hero is actually the nearer of the
## two; a raptor being shot in the back does not turn around for somebody shouting.
func _find_threat_priority_target() -> Node:
	if not is_inside_tree():
		return null

	var tower := _nearest_building_within(tower_interest_range(), "tower")
	var hero := _hero_within(hero_interest_range())

	if _hero_is_provoking() and hero != null:
		if tower == null or global_position.distance_to(hero.global_position) < global_position.distance_to(tower.global_position):
			return hero
	if tower != null:
		return tower

	var building := _nearest_building_within(building_interest_range())
	if building != null:
		return building
	return hero
