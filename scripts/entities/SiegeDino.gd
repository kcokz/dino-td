# res://scripts/entities/SiegeDino.gd
class_name SiegeDino
extends "res://scripts/entities/Dino.gd"

## Big, slow, and here for the buildings: the siege habit.
##
## A siege dinosaur walks through the defence rather than fighting the defenders.
## It does not stop for the Hero -- something the size of a house has no reason to
## turn aside for one man -- and it does not chase a turret either: it bites
## whatever is standing in front of it, which on the way to the cabin is the
## fence and then the cabin.
##
## The contrast with PackDino is the point. A raid of raptors reacts to what the
## player does; a theropod ignores it. Defending against one is a different
## problem from defending against the other, and that difference is entirely in
## this file -- movement, combat and death are shared in Dino.

## It notices buildings further out than a raptor does, because knocking them
## down is what it came for.
func building_interest_range() -> float:
	return 3.5

## And it does not go round them. A pack funnels through the gap in a fence; a theropod
## eats the fence. That difference is the reason this species exists, so the rule about
## walls that are not in the way -- which is right for a raid -- does not apply here.
func walks_round_walls() -> bool:
	return false

## And it walks straight past the Hero. Provocation does not move it.
func hero_interest_range() -> float:
	return 0.0

## A turret is just another building to it -- no detour, no priority.
func tower_interest_range() -> float:
	return 0.0

## Whatever building is nearest, and nothing else.
## Whatever building is nearest. Whether it is worth stopping for is decided by
## Dino._find_threat_priority_target, which this used to override and step past.
func _preferred_target() -> Node:
	return _nearest_building_within(building_interest_range())

## Longer reach to match the size.
func attack_reach() -> float:
	return super.attack_reach() * 1.4
