# res://scripts/fx/ActorAnimator.gd
class_name ActorAnimator
extends Node

## The seam between game logic and art clips.
##
## Entities report what they are DOING (their State enum); this component decides what to PLAY.
## Entities never name an animation clip, because clip names belong to the asset pack: one pack
## names it "Walk", the next "walk", the next "run" or "Armature|Walk".
##
## Keeping clip resolution here and in Config.ANIMATIONS guarantees two invariants:
##   1. Swapping an asset pack changes data in Config, never entity logic.
##   2. Graceful degradation: entities without AnimationPlayers or models missing a clip
##      continue working silently without crashing or freezing.

var actor: Node3D = null
var actor_type: String = ""
var animation_player: AnimationPlayer = null

var current_clip: String = ""
var requested_clip: String = ""
var current_state_name: String = ""

func _ready() -> void:
	if actor == null and get_parent() is Node3D:
		actor = get_parent() as Node3D
	refresh_animation_player()

func setup(p_actor: Node3D, p_actor_type: String) -> void:
	actor = p_actor
	actor_type = p_actor_type
	refresh_animation_player()

## Finds or re-acquires the AnimationPlayer within the actor's visual hierarchy.
## Called automatically and whenever a model/body is swapped.
func refresh_animation_player() -> AnimationPlayer:
	animation_player = null
	if actor == null or not is_instance_valid(actor):
		return null

	var players = actor.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		animation_player = players[0] as AnimationPlayer
	return animation_player

## Plays the clip mapped to `state_value` according to Config.ANIMATIONS.
## `state_value` can be an integer enum value or a string state name.
func play_state(state_value: Variant) -> void:
	current_state_name = _resolve_state_name(state_value)
	var target_clip: String = _lookup_clip_for_state(current_state_name)
	requested_clip = target_clip

	if target_clip == "":
		return

	if animation_player == null or not is_instance_valid(animation_player):
		refresh_animation_player()

	# Graceful degradation: if entity has no AnimationPlayer, quiet no-op.
	if animation_player == null or not is_instance_valid(animation_player):
		return

	var clip_to_play: String = _find_best_clip(target_clip)
	if clip_to_play == "":
		# Missing clip: degrade gracefully rather than throwing an engine error.
		return

	if current_clip == clip_to_play and animation_player.is_playing():
		return

	var blend: float = _get_blend_time()
	current_clip = clip_to_play
	animation_player.play(clip_to_play, blend)

## Directly plays a clip by name with alias resolution and graceful degradation.
func play_clip(clip_name: String) -> void:
	requested_clip = clip_name
	if animation_player == null or not is_instance_valid(animation_player):
		refresh_animation_player()
	if animation_player == null or not is_instance_valid(animation_player):
		return

	var best = _find_best_clip(clip_name)
	if best != "":
		current_clip = best
		animation_player.play(best, _get_blend_time())

func stop() -> void:
	current_clip = ""
	if animation_player and is_instance_valid(animation_player):
		animation_player.stop()

# ==============================================================================
# Internal Resolution Helpers
# ==============================================================================

func _resolve_state_name(state_value: Variant) -> String:
	if state_value is String:
		return String(state_value).to_upper()
	if state_value is int:
		var int_val: int = int(state_value)
		if actor != null:
			var script_obj = actor.get_script()
			if script_obj != null:
				var constants: Dictionary = script_obj.get_script_constant_map()
				if constants.has("State") and constants["State"] is Dictionary:
					var state_map: Dictionary = constants["State"]
					for k in state_map:
						if state_map[k] == int_val:
							return String(k).to_upper()
		# Fallback standard keys by index
		if actor_type == "hero":
			var hero_states = ["IDLE", "MOVING", "BUILDING", "ATTACKING", "DEAD", "HARVESTING"]
			if int_val >= 0 and int_val < hero_states.size():
				return hero_states[int_val]
		elif actor_type == "dino":
			var dino_states = ["WALKING", "ATTACKING", "DEAD"]
			if int_val >= 0 and int_val < dino_states.size():
				return dino_states[int_val]
	return str(state_value).to_upper()

func _lookup_clip_for_state(state_name: String) -> String:
	var cfg = _get_config()
	if cfg == null or not ("ANIMATIONS" in cfg):
		return ""
	var anim_cfg: Dictionary = cfg.ANIMATIONS
	if not anim_cfg.has(actor_type):
		return ""
	var type_map: Dictionary = anim_cfg[actor_type]
	if type_map.has(state_name):
		return String(type_map[state_name])
	return ""

## Resolves the best available clip in the AnimationPlayer using exact match,
## lowercase, uppercase, and alias fallback list from Config.ANIMATIONS.
func _find_best_clip(wanted: String) -> String:
	if animation_player == null or not is_instance_valid(animation_player):
		return ""

	var anim_list: PackedStringArray = animation_player.get_animation_list()
	if anim_list.is_empty():
		return ""

	# 1. Exact match
	if animation_player.has_animation(wanted):
		return wanted

	# 2. Case-insensitive match
	var wanted_lower: String = wanted.to_lower()
	for a in anim_list:
		if a.to_lower() == wanted_lower:
			return a

	# 3. Aliases lookup from Config
	var cfg = _get_config()
	if cfg and ("ANIMATIONS" in cfg) and cfg.ANIMATIONS.has("aliases"):
		var aliases_map: Dictionary = cfg.ANIMATIONS["aliases"]
		if aliases_map.has(wanted_lower):
			var candidates: Array = aliases_map[wanted_lower]
			for cand in candidates:
				var cand_str: String = String(cand)
				if animation_player.has_animation(cand_str):
					return cand_str
				for a in anim_list:
					if a.to_lower() == cand_str.to_lower():
						return a

	return ""

func _get_blend_time() -> float:
	var cfg = _get_config()
	if cfg and ("ANIMATIONS" in cfg) and cfg.ANIMATIONS.has("blend_time"):
		return float(cfg.ANIMATIONS["blend_time"])
	return 0.2

func _get_config() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/Config")
	if Engine.get_main_loop() is SceneTree and Engine.get_main_loop().root:
		return Engine.get_main_loop().root.get_node_or_null("Config")
	return null
