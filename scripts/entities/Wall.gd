# res://scripts/entities/Wall.gd
class_name Wall
extends "res://scripts/entities/Building.gd"

## High-durability defensive wall. Blocks dinosaur pathing until destroyed.

func _init() -> void:
	super("wall")
	building_type = "wall"
	max_hp = 30.0
	current_hp = 30.0
