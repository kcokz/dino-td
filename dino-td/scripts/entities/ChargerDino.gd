# res://scripts/entities/ChargerDino.gd
class_name ChargerDino
extends "res://scripts/entities/SiegeDino.gd"

## 受惊冲撞 THE FRIGHTENED CHARGER (Config.DINOS behaviour "charger"; GAME-DESIGN 3.0 -- the player: "食草恐龙也可以进攻船舱
## 因为受到惊吓"): a plant-eater the capsule's fall frightened -- an aetosaur, a stegosaur -- come with the raids to ram
## the strange thing that fell into its valley. As the siege animals do, it goes through the defence rather than round
## it, bites (rams) what stands in its way to the cabin, and pays the man no mind unless he strikes it; it is armoured
## (Config.ARMOR), so arrows hardly hurt it -- what crushes does.
##
## AND IT IS AFRAID OF FIRE ("怕火：地上着火它就掉头"): come into a fire's light -- a campfire's or a brazier's while they
## burn, a fire pot's burning ground, his torch (ProwlerDino.lights) -- and it turns tail and runs off the field the way
## it came, not killed, nothing left behind (Dino.go_home). By day a campfire is out: a fire pot, a torch -- or what
## crushes.

## Set once it has taken fright, so it is said once.
var frightened: bool = false

## Its first thought each time: in a fire's light, it runs.
func _think() -> void:
	if not going_home and _in_firelight():
		_take_fright()
		return
	super._think()

## Whether a fire's light is on it (ProwlerDino.lights: the fires, the burning ground, his torch).
func _in_firelight() -> bool:
	return is_inside_tree() and not ProwlerDino.light_over(get_tree(), global_position).is_empty()

## It snorts, turns, and runs off the field the way it came in -- or, put down here by hand, back to the nest's side.
func _take_fright() -> void:
	frightened = true
	say("alert")
	var away: Vector3 = came_in_at if came_in_at != Vector3.INF else global_position
	var nest: Node3D = get_tree().get_first_node_in_group("nest") as Node3D if is_inside_tree() else null
	if came_in_at == Vector3.INF and nest != null:
		away = nest.global_position
	go_home(away)
