# res://scripts/core/BugReport.gd
class_name BugReport
extends Node

## A BUG REPORT, in a development build only (the player, 2026-09-29: "你弄一个bug report功能（加到dev版，
## release版本没有这个功能），因为有时候截图你看不清也不知道哪里出问题，bug report功能snap所有你想要知道的当前参
## 数并dump出来……给个快捷键……类似于抽搐telemetry，但这个是就用于本地debug用").
##
## Its key (Config.CONTROLS.bug_report_key) writes everything a reader needs to know what the game was
## doing when something went wrong, to user://bugreports/bug-<time>.json, and a picture of the screen
## beside it (bug-<time>.png): the run and its clock; the view, and what the cursor was on; what was
## picked, and what was in hand to build; the Hero -- where, doing what, going where by what way; every
## animal's mind (Dino.debug_state); every building, node and drop; the stock, the meals and the
## beacon; the raids; the corner's commands; and the last things that happened, as the game said them
## (EventBus), with how long ago. The screen says where it went.
##
## Not in a release build: the level adds it only where OS.is_debug_build() (Main._add_bug_report).

const DIR := "user://bugreports"
const GROUP := "bug_report"

## The level it reports on.
var main: Node = null
## The last things that happened: [seconds into the level, signal, what it said], oldest first.
var _events: Array = []
var _clock: float = 0.0

func _ready() -> void:
	name = "BugReport"
	add_to_group(GROUP)
	# It reports a paused game as readily as a running one.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var eb = get_node_or_null("/root/EventBus")
	if eb == null:
		return
	var quiet: Array = _cfg().get("quiet", [])
	for s in eb.get_signal_list():
		var sig: String = String(s["name"])
		if quiet.has(sig):
			continue
		var name_of: String = sig
		match int((s["args"] as Array).size()):
			0:
				eb.connect(sig, func() -> void: _note(name_of, []))
			1:
				eb.connect(sig, func(a) -> void: _note(name_of, [a]))
			2:
				eb.connect(sig, func(a, b) -> void: _note(name_of, [a, b]))
			3:
				eb.connect(sig, func(a, b, c) -> void: _note(name_of, [a, b, c]))
			4:
				eb.connect(sig, func(a, b, c, d) -> void: _note(name_of, [a, b, c, d]))

func _process(delta: float) -> void:
	_clock += delta

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var cfg = get_node_or_null("/root/Config")
	var key: int = int(cfg.CONTROLS.get("bug_report_key", KEY_QUOTELEFT)) if (cfg and "CONTROLS" in cfg) else KEY_QUOTELEFT
	# By the letter or by where the key is: on a board laid out otherwise the key under Esc is still it.
	if (event as InputEventKey).keycode != key and (event as InputEventKey).physical_keycode != key:
		return
	get_viewport().set_input_as_handled()
	var path: String = save()
	var hud = main.get("hud") if (main != null and is_instance_valid(main)) else null
	if hud != null and is_instance_valid(hud) and hud.has_method("show_hint") and path != "":
		hud.show_hint(tr("HINT_BUG_REPORT") % ProjectSettings.globalize_path(path), UiTheme.toast_seconds("long"), "info")

func _note(sig: String, args: Array) -> void:
	var said: Array = []
	for a in args:
		said.append(_plain(a))
	_events.append([snappedf(_clock, 0.01), sig, said])
	var most: int = int(_cfg().get("events", 120))
	while _events.size() > most:
		_events.pop_front()

## Writes the report and the picture; returns the report's path ("" if it could not be written).
func save() -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "-")
	var path: String = "%s/bug-%s.json" % [DIR, stamp]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JSON.stringify(snapshot(), "  "))
	f.close()
	# A picture only where there is a screen: headless (the tests) there is nothing to take one of.
	var tex: Texture2D = get_viewport().get_texture() if (is_inside_tree() and DisplayServer.get_name() != "headless") else null
	if tex != null:
		var img: Image = tex.get_image()
		if img != null and not img.is_empty():
			img.save_png(path.replace(".json", ".png"))
	return path

## Everything, in plain values for JSON.
func snapshot() -> Dictionary:
	var gs = get_node_or_null("/root/GameState")
	var out: Dictionary = {
		"report": {"at": Time.get_datetime_string_from_system(), "version": AppInfo.get_version(),
			"engine": Engine.get_version_info().get("string", ""), "fps": Engine.get_frames_per_second(),
			"speed": Engine.time_scale, "seconds_in_level": snappedf(_clock, 0.01)},
	}
	if gs != null:
		out["run"] = {"map": String(gs.map_id), "seed": int(gs.run_seed), "day": int(gs.day_number()),
			"time_of_day": snappedf(float(gs.time_of_day()), 0.1), "day_part": String(gs.day_part()),
			"paused": bool(gs.is_paused), "game_over": bool(gs.is_game_over), "won": bool(gs.is_game_won),
			"stock": _plain(gs.resources), "meals": _plain(gs.meals), "fed": _plain(gs.fed),
			"unlocks": _plain(gs.unlocks), "known": _plain(gs.known),
			"beacon": {"steps": int(gs.beacon_steps), "charge": snappedf(float(gs.beacon_charge), 0.1),
				"final_wave_in": snappedf(float(gs.final_wave_in), 0.1)}}
	if main == null or not is_instance_valid(main):
		return out
	out["view"] = _view()
	out["picked"] = _picked()
	out["hero"] = _hero()
	var dinos: Array = []
	for d in get_tree().get_nodes_in_group("dinos"):
		if is_instance_valid(d) and d.has_method("debug_state"):
			var state: Dictionary = d.debug_state()
			state["hp"] = [snappedf(float(d.get("current_hp")), 0.01), snappedf(float(d.get("max_hp")), 0.01)] if "current_hp" in d else null
			state["drawn"] = (d as Node3D).is_visible_in_tree()
			dinos.append(state)
	out["dinos"] = dinos
	var buildings: Array = []
	for b in get_tree().get_nodes_in_group("buildings"):
		if not (b is Node3D) or not is_instance_valid(b):
			continue
		buildings.append({"type": String(b.get("building_type")), "id": b.get_instance_id(),
			"pos": _xz((b as Node3D).global_position), "cell": _plain(b.get("cell_pos")) if "cell_pos" in b else null,
			"hp": [snappedf(float(b.get("current_hp")), 0.01), snappedf(float(b.get("max_hp")), 0.01)] if "current_hp" in b else null,
			"built": bool(b.get("is_constructed")) if "is_constructed" in b else null,
			"destroyed": bool(b.get("is_destroyed")) if "is_destroyed" in b else null,
			"layer": int((b as CollisionObject3D).collision_layer) if b is CollisionObject3D else null})
	out["buildings"] = buildings
	var nodes: Array = []
	for n in get_tree().get_nodes_in_group("resource_nodes"):
		if is_instance_valid(n) and n is Node3D:
			nodes.append({"type": String(n.get("resource_type")), "pos": _xz((n as Node3D).global_position),
				"left": int(n.get("current_amount")), "depleted": bool(n.get("is_depleted")),
				"drawn": (n as Node3D).is_visible_in_tree()})
	out["nodes"] = nodes
	var drops: Array = []
	for d in get_tree().get_nodes_in_group(DropItem.GROUP):
		if is_instance_valid(d) and d is Node3D:
			drops.append({"type": String(d.get("resource_type")), "amount": int(d.get("amount")) if "amount" in d else 0,
				"pos": _xz((d as Node3D).global_position)})
	out["drops"] = drops
	out["raids"] = _raids()
	out["corner"] = _corner()
	out["events"] = _events.duplicate()
	return out

func _view() -> Dictionary:
	var out: Dictionary = {}
	var rig = main.get("camera_rig")
	if rig != null:
		out["focus"] = _xz(rig.focus)
		out["yaw"] = snappedf(float(rig.yaw), 0.1)
		out["tilt"] = snappedf(float(rig.tilt), 0.1)
		out["distance"] = snappedf(float(rig.distance), 0.01)
	var mouse: Vector2 = get_viewport().get_mouse_position()
	out["cursor"] = [snappedf(mouse.x, 1.0), snappedf(mouse.y, 1.0)]
	if main.has_method("_raycast_ground"):
		var ground = main._raycast_ground(mouse)
		out["cursor_ground"] = _xz(ground) if ground is Vector3 else null
	if main.has_method("_raycast_object"):
		out["cursor_on"] = _thing(main._raycast_object(mouse))
	out["hovered"] = _thing(main.get("_hovered"))
	var fog = main.get("fog")
	if fog != null and is_instance_valid(fog) and fog.has_method("is_in_sight"):
		out["fog_revealed"] = bool(fog.get("revealed"))
	return out

func _picked() -> Dictionary:
	var hud = main.get("hud")
	var panel = hud.get("option_panel") if (hud != null and is_instance_valid(hud)) else null
	var out: Dictionary = {"in_hand": String(main.get("current_build_type")) if "current_build_type" in main else ""}
	if panel != null and is_instance_valid(panel):
		out["unit"] = _thing(panel.get("selected_unit"))
		out["menu"] = String(panel.get("current_menu"))
		out["view"] = String(panel.view()) if panel.has_method("view") else ""
	if hud != null and is_instance_valid(hud):
		var hint = hud.get("hint_label")
		out["hint"] = String(hint.text) if (hint != null and is_instance_valid(hint) and hint.is_visible_in_tree()) else ""
	out["in_cabin"] = bool(main.get("in_cabin")) if "in_cabin" in main else false
	return out

func _hero() -> Dictionary:
	var hero = main.get("hero")
	if hero == null or not is_instance_valid(hero):
		return {}
	return hero.debug_state() if hero.has_method("debug_state") else {"pos": _xz((hero as Node3D).global_position)}

func _raids() -> Dictionary:
	var wm = main.get("wave_manager")
	if wm == null or not is_instance_valid(wm):
		return {}
	return {"wave": int(wm.current_wave), "active": bool(wm.is_wave_active), "raid_in": snappedf(float(wm.raid_timer), 0.1),
		"to_spawn": int(wm.dinos_to_spawn), "spawned": int(wm.dinos_spawned_count), "alive": int(wm.dinos_alive_count),
		"stage_wave": bool(wm.stage_wave), "final_wave": bool(wm.final_wave), "auto": bool(wm.auto_raid_enabled)}

func _corner() -> Dictionary:
	var hud = main.get("hud")
	var tiles = hud.get("hero_commands") if (hud != null and is_instance_valid(hud)) else null
	if tiles == null or not is_instance_valid(tiles):
		return {}
	var out: Dictionary = {"came": _plain(tiles.came), "keys_live": bool(tiles.keys_live())}
	for id in tiles.came:
		var b: Button = tiles.tile(String(id))
		if b != null:
			out[String(id)] = {"key": tiles.key_of(String(id)), "disabled": b.disabled, "shown": b.is_visible_in_tree()}
	return out

## A node as the report names it: what it is, where -- or null.
func _thing(node: Variant) -> Variant:
	if node == null or not is_instance_valid(node) or not (node is Node):
		return null
	var n := node as Node
	var out: Dictionary = {"class": n.get_class(), "name": String(n.name), "id": n.get_instance_id()}
	for key in ["building_type", "resource_type", "dino_type", "station_id"]:
		if key in n:
			out[key] = String(n.get(key))
	if n is Node3D:
		out["pos"] = _xz((n as Node3D).global_position)
	return out

## `v` in plain values for JSON: vectors as lists, nodes as what they are, the rest as it is.
func _plain(v: Variant) -> Variant:
	match typeof(v):
		TYPE_VECTOR2, TYPE_VECTOR2I:
			return [snappedf(float(v.x), 0.01), snappedf(float(v.y), 0.01)]
		TYPE_VECTOR3, TYPE_VECTOR3I:
			return [snappedf(float(v.x), 0.01), snappedf(float(v.y), 0.01), snappedf(float(v.z), 0.01)]
		TYPE_COLOR:
			return (v as Color).to_html()
		TYPE_OBJECT:
			return _thing(v) if v is Node else (str(v) if v != null else null)
		TYPE_DICTIONARY:
			var d: Dictionary = {}
			for k in v:
				d[str(k)] = _plain(v[k])
			return d
		TYPE_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_FLOAT32_ARRAY:
			var a: Array = []
			for x in v:
				a.append(_plain(x))
			return a
		TYPE_FLOAT:
			return snappedf(float(v), 0.001)
	return v

static func _xz(p: Vector3) -> Array:
	return [snappedf(p.x, 0.01), snappedf(p.z, 0.01)]

func _cfg() -> Dictionary:
	var cfg = get_node_or_null("/root/Config") if is_inside_tree() else null
	return cfg.BUG_REPORT if (cfg and "BUG_REPORT" in cfg) else {}
