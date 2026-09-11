# res://scripts/entities/Wall.gd
class_name Wall
extends "res://scripts/entities/Building.gd"

## High-durability defensive wall. Blocks dinosaur pathing until destroyed.

func _init() -> void:
	super("wall")
	building_type = "wall"
