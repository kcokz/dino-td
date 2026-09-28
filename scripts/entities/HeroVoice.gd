# res://scripts/entities/HeroVoice.gd
class_name HeroVoice
extends Node

## What he says (v0.6 round three: "人自己也需要有些滚动的话在移动的时候idle的时候说，做事情说做的事情等"):
## a line now and then, of the moment -- set off walking, left standing, at a tree, at the rock,
## at a stake, eating, fighting, bitten, and when the raid comes, the leader or the boss shows
## itself, a tool comes off the bench, a stage of the beacon comes back on line.
##
## Each situation has a handful of lines (Config.BARKS.lines; the words are strings.csv's
## BARK_<SITUATION>_<n>), taken in no fixed order and never the same one twice running. He is
## not a radio: a line only so often (BARKS.gap), a situation only so often (its "again"), and
## the everyday ones only some of the time (its "chance"); the ones that matter -- bitten, the
## raid, the boss -- cut in whenever ("urgent").
##
## A line is said on the bus (EventBus.hero_spoke) and the HUD puts it over his head. If a
## recording of it is ever made (BARKS.voice_dir: <key in lower case>.wav or .ogg) it is played
## from where he stands; until then the words are read, not heard.
##
## Timed in the game's own time, and quiet while the game is paused: his idle thoughts do not
## run on through a pause.

var hero: Node3D = null
var _clock: float = 0.0
var _last_said_at: float = -1000.0
var _said_at: Dictionary = {}        # situation -> _clock when it was last said
var _last_line: Dictionary = {}      # situation -> the index of the line said last time
var _state_was: int = -1
var _idle_for: float = 0.0
var _next_idle: float = 0.0
var _enemy_was: Node = null
var _hp_before: float = INF
var _dice := RandomNumberGenerator.new()
var _mouth: AudioStreamPlayer3D = null

func _ready() -> void:
	if hero == null and get_parent() is Node3D:
		hero = get_parent() as Node3D
	_dice.randomize()
	_next_idle = _number("idle_after", 14.0)
	var eb = _bus()
	if eb == null:
		return
	for pair in _hooks():
		if eb.has_signal(pair[0]) and not eb.is_connected(pair[0], pair[1]):
			eb.connect(pair[0], pair[1])

func _exit_tree() -> void:
	var eb = _bus()
	if eb == null or not is_instance_valid(eb):
		return
	for pair in _hooks():
		if eb.has_signal(pair[0]) and eb.is_connected(pair[0], pair[1]):
			eb.disconnect(pair[0], pair[1])

func _hooks() -> Array:
	return [["raid_warning", _on_raid_warning], ["wave_ended", _on_wave_ended],
		["boss_arrived", _on_boss_arrived], ["unlock_granted", _on_unlock_granted],
		["beacon_changed", _on_beacon_changed], ["beacon_launched", _on_beacon_launched],
		["cabin_view_changed", _on_cabin_view_changed], ["hero_hp_changed", _on_hero_hp_changed]]

func _process(delta: float) -> void:
	if hero == null or not is_instance_valid(hero) or _dead():
		return
	_clock += delta
	var state: int = int(hero.get("current_state"))
	if state != _state_was:
		_state_was = state
		_on_state(state)
	# Left standing, he talks to himself: after a while, and then every so often.
	if state == 0:
		_idle_for += delta
		if _idle_for >= _next_idle:
			_idle_for = 0.0
			var every: Vector2 = _barks().get("idle_every", Vector2(28.0, 55.0))
			_next_idle = _dice.randf_range(every.x, every.y)
			consider("idle")
	else:
		_idle_for = 0.0
		_next_idle = _number("idle_after", 14.0)
	# What he was fighting is down.
	var enemy: Node = _his("target_enemy")
	if _enemy_was != null and enemy != _enemy_was:
		if not is_instance_valid(_enemy_was) or bool(_enemy_was.get("is_dead")):
			consider("kill")
	_enemy_was = enemy

## What he has just started doing, said as he starts it.
func _on_state(state: int) -> void:
	match state:
		1:
			# Only a walk he was sent on -- not the walk over to a tree or a stake.
			if _his("target_building") == null and _his("target_resource_node") == null and _his("target_enemy") == null:
				consider("move")
		2:
			var b: Node = _his("target_building")
			if b != null:
				consider("repair" if bool(b.get("is_constructed")) else "build")
		3:
			consider("fight")
		5:
			var node: Node = _his("target_resource_node")
			if node != null:
				var kind: String = String(node.get("resource_type"))
				var by_kind: Dictionary = _barks().get("harvest", {})
				if by_kind.has(kind):
					consider(String(by_kind[kind]))
		6:
			consider("eat")

## `situation` happened: he may say something about it -- as often as its "chance" says.
func consider(situation: String) -> bool:
	var spec: Dictionary = _barks().get("lines", {}).get(situation, {})
	if spec.is_empty():
		return false
	if _dice.randf() >= float(spec.get("chance", 1.0)):
		return false
	return speak(situation)

## A line about `situation`, now, if it is not too soon: after his last line (BARKS.gap) unless it
## is urgent, and after the last line about the same thing (its "again"). Never the line he said
## last time about it.
func speak(situation: String) -> bool:
	var spec: Dictionary = _barks().get("lines", {}).get(situation, {})
	var count: int = int(spec.get("count", 0))
	if count <= 0 or _dead():
		return false
	var urgent: bool = bool(spec.get("urgent", false))
	if not urgent and _clock - _last_said_at < _number("gap", 7.0):
		return false
	if _clock - float(_said_at.get(situation, -1000.0)) < float(spec.get("again", 0.0)):
		return false
	var index: int = _dice.randi_range(0, count - 1)
	if count > 1 and index == int(_last_line.get(situation, -1)):
		index = (index + 1 + _dice.randi_range(0, count - 2)) % count
	_last_line[situation] = index
	_said_at[situation] = _clock
	_last_said_at = _clock
	var key: String = "BARK_%s_%d" % [situation.to_upper(), index + 1]
	var words: String = tr(key)
	var seconds: float = clampf(float(words.length()) * _number("seconds_per_char", 0.07),
		_number("min_seconds", 2.2), _number("max_seconds", 5.0))
	var eb = _bus()
	if eb and eb.has_signal("hero_spoke"):
		eb.hero_spoke.emit(key, seconds)
	_say_aloud(key)
	return true

## A recording of the line, if there is one, from where he stands.
func _say_aloud(key: String) -> void:
	var dir: String = String(_barks().get("voice_dir", ""))
	if dir == "" or not is_inside_tree():
		return
	for ext in [".ogg", ".wav"]:
		var path: String = dir + key.to_lower() + ext
		if ResourceLoader.exists(path):
			if _mouth == null:
				_mouth = AudioStreamPlayer3D.new()
				_mouth.name = "Mouth"
				hero.add_child(_mouth)
				_mouth.position = Vector3(0.0, 1.5, 0.0)
			_mouth.stream = load(path)
			_mouth.play()
			return

# ------------------------------------------------------------------------------
# What happens round him

func _on_raid_warning(_time_left: float) -> void:
	consider("raid")

func _on_wave_ended(_n: int) -> void:
	consider("raid_over")

func _on_boss_arrived(dino: Node) -> void:
	var cfg = get_node_or_null("/root/Config")
	if cfg == null or dino == null or not is_instance_valid(dino):
		return
	var rank: String = String(cfg.DINOS.get(String(dino.get("dino_type")), {}).get("boss", ""))
	consider("boss" if rank == "major" else "leader")

func _on_unlock_granted(_unlock_id: String) -> void:
	consider("tool")

func _on_beacon_changed(steps_done: int) -> void:
	if steps_done > 0:
		consider("beacon_stage")

func _on_beacon_launched() -> void:
	consider("launched")

func _on_cabin_view_changed(inside: bool) -> void:
	consider("enter" if inside else "leave")

func _on_hero_hp_changed(cur: float, max_val: float) -> void:
	# Bitten, and it is getting serious: under half.
	if cur < _hp_before - 0.001 and cur > 0.0 and cur < max_val * 0.5:
		consider("hurt")
	_hp_before = cur

# ------------------------------------------------------------------------------

## What he is after -- `what` of his -- or null: also when it is gone, freed under him (a raptor
## killed, a tree felled) before he has let go of it.
func _his(what: String) -> Node:
	var it: Variant = hero.get(what)
	return it as Node if is_instance_valid(it) else null

func _dead() -> bool:
	return hero == null or not is_instance_valid(hero) or int(hero.get("current_state")) == 4

func _barks() -> Dictionary:
	var cfg = get_node_or_null("/root/Config")
	return cfg.BARKS if (cfg and "BARKS" in cfg) else {}

func _number(key: String, fallback: float) -> float:
	return float(_barks().get(key, fallback))

func _bus() -> Node:
	return get_node_or_null("/root/EventBus") if is_inside_tree() else null
