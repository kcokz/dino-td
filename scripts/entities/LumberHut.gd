# res://scripts/entities/LumberHut.gd
class_name LumberHut
extends ProducerBuilding

## Lumber Hut: harvests wood out of real tree ResourceNodes within `harvest_range`.
## All harvesting, tending and range-indicator behaviour lives in ProducerBuilding;
## this class only supplies the wood-specific status wording and legacy aliases.

func _init() -> void:
	super("lumber_hut")

## Alias kept for callers and tests written against the wood-specific name.
var target_tree: Node:
	get: return target_source

func find_nearest_tree() -> Node:
	return find_nearest_source("wood")

func _source_status_text(src: Node) -> String:
	var raw := tr("STATUS_CHOPPING_TREE")
	if "%" in raw:
		return raw % [src.current_amount, src.max_capacity]
	return raw

func _no_source_status_text() -> String:
	return tr("STATUS_NO_TREES_IN_RANGE")

func get_display_info() -> Dictionary:
	var info = super.get_display_info()
	info["target_tree"] = target_source
	return info
