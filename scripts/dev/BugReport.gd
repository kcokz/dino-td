# res://scripts/dev/BugReport.gd
class_name BugReport
extends Node

## A BUG REPORT, in a development build only (the player, 2026-09-29: "你弄一个bug report功能（加到dev版，
## release版本没有这个功能），因为有时候截图你看不清也不知道哪里出问题，bug report功能snap所有你想要知道的当前参
## 数并dump出来……给个快捷键……类似于抽搐telemetry，但这个是就用于本地debug用").
##
## Its key (Config.CONTROLS.bug_report_key) writes everything a reader needs to know what the game was
## doing when something went wrong, to user://bugreports/bug-<time, to the millisecond>.json, and a picture of
## the screen beside it (bug-<time>.png): the run and its clock; the view, and what the cursor was on; what
## was picked, and what was in hand to build; the Hero -- where, doing what, going where by what way; every
## animal's mind and where it came from (Dino.debug_state); every building, node and drop; the stock, the
## meals and the beacon; the raids, and whose each place round a building is (Dino.attack_slots); the
## corner's commands; the last twitches the watch wrote up (TwitchWatch); and the last things that happened,
## as the game said them (EventBus), with how long ago. The screen says where it went.
##
## A BUTTON for it too (v0.6 round seven, the player: "Debug版本给我一个按钮可以按（上面显示快捷键），可以用比较透明
## 的方法显示（release版本没有这个功能和按钮），这在你的build file或者build script得区分"): at the bottom left beside
## the version, the key on a chip at its end as a command wears its key, faint until the cursor is on it
## (Config.BUG_REPORT button_alpha), over everything -- the menus and the start screen too -- in a layer of its
## own. Pressed, it does what the key does.
##
## Not in a release build, and that is the build's doing: everything under res://scripts/dev/ is left out of the
## release export (export_presets.cfg, "Windows Release": exclude_filter; tools/build.py checks the pack), and
## the level adds this by its path, only where the file was shipped and the build is a debug one
## (Main._add_bug_report) -- nothing the release ships names it.

const DIR := "user://bugreports"
const GROUP := "bug_report"

## The level it reports on.
var main: Node = null
## The last things that happened: [seconds into the level, signal, what it said], oldest first.
var _events: Array = []
## The last twitches the watch wrote up, whole: {at: seconds into the level, record}, oldest first.
var _twitches: Array = []
var _clock: float = 0.0

## Its button (_add_button), in a layer of its own over the rest.
var button: Button = null
var _layer: CanvasLayer = null

func _ready() -> void:
	name = "BugReport"
	add_to_group(GROUP)
	# It reports a paused game as readily as a running one.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_add_button.call_deferred()
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
	if eb.has_signal("twitch_detected"):
		eb.twitch_detected.connect(_on_twitch)

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
	report_now()

## Writes a report and says where it went -- the key's and the button's.
func report_now() -> String:
	var path: String = save()
	var hud = main.get("hud") if (main != null and is_instance_valid(main)) else null
	if hud != null and is_instance_valid(hud) and hud.has_method("show_hint") and path != "":
		hud.show_hint(tr("HINT_BUG_REPORT") % ProjectSettings.globalize_path(path), UiTheme.toast_seconds("long"), "info")
	return path

## The report's key as the board writes it: "`" for the key under Esc, a letter for a letter, else its name.
static func key_text(key: int) -> String:
	# A printable key's code is its character (KEY_QUOTELEFT is "`"): the engine's names for those
	# ("QuoteLeft") are words a chip has no room for.
	if key > KEY_SPACE and key < 127:
		return char(key).to_upper()
	return OS.get_keycode_string(key)

## Its button: a faint one at the bottom left, beside the version the HUD writes there, the key on a chip
## at its end -- in a layer of its own over the rest of the screen, the menus and the start screen with it.
func _add_button() -> void:
	if button != null or not is_inside_tree():
		return
	var cfg: Dictionary = _cfg()
	_layer = CanvasLayer.new()
	_layer.name = "BugReportLayer"
	_layer.layer = int(cfg.get("button_layer", 90))
	add_child(_layer)
	button = UiKit.action_button(tr("DEV_BUG_REPORT"), UiTheme.icon("warning"), func() -> void: report_now(), &"GhostButton")
	button.name = "BugReportButton"
	button.tooltip_text = tr("DEV_BUG_REPORT_TIP")
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.focus_mode = Control.FOCUS_NONE
	# Its whole word: a command trims its word to the width it is given, and so leaves the word out of the
	# width it asks for -- a button sized to what it asks for showed its first letter.
	button.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	# A layer is no Control: the theme the HUD's controls take from its root is given here again.
	var root := Control.new()
	root.name = "BugReportRoot"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.get_theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(root)
	root.add_child(button)
	var cfg_node = get_node_or_null("/root/Config")
	var key: int = int(cfg_node.CONTROLS.get("bug_report_key", KEY_QUOTELEFT)) if (cfg_node and "CONTROLS" in cfg_node) else KEY_QUOTELEFT
	# The key at the button's end, where a plain command wears it (UiKit.keycap) -- the button as much wider
	# as the chip, so its word never runs under it.
	var cap: Label = UiKit.keycap(button, key_text(key))
	button.custom_minimum_size.x = button.get_minimum_size().x + cap.get_combined_minimum_size().x + float(UiTheme.space("s"))
	# Faint: it is for whoever is testing, not part of the game -- there when wanted, clear when not.
	button.modulate.a = float(cfg.get("button_alpha", 0.45))
	button.mouse_entered.connect(func() -> void: button.modulate.a = float(_cfg().get("button_alpha_hover", 1.0)))
	button.mouse_exited.connect(func() -> void: button.modulate.a = float(_cfg().get("button_alpha", 0.45)))
	var hud = main.get("hud") if (main != null and is_instance_valid(main)) else null
	var version: Control = hud.get("version_label") if (hud != null and is_instance_valid(hud)) else null
	if version != null:
		version.resized.connect(_place_button)
	get_viewport().size_changed.connect(_place_button)
	button.resized.connect(_place_button)
	_place_button()

## Beside the version at the bottom left, its middle on the version's line as far as the screen's foot lets it
## -- it is taller than the line, and the line sits on the foot: centred, its lower half was off the screen.
## With no version to stand by, in that corner.
func _place_button() -> void:
	if button == null or not is_instance_valid(button):
		return
	var hud = main.get("hud") if (main != null and is_instance_valid(main)) else null
	var version: Control = hud.get("version_label") if (hud != null and is_instance_valid(hud)) else null
	var seen: Vector2 = get_viewport().get_visible_rect().size
	var size: Vector2 = button.get_combined_minimum_size()
	var gap: float = float(UiTheme.space("s"))
	var at: Vector2 = Vector2(gap, seen.y - size.y - gap)
	if version != null and is_instance_valid(version) and version.is_visible_in_tree():
		var by: Rect2 = version.get_global_rect()
		at = Vector2(by.end.x + gap, minf(by.get_center().y - size.y * 0.5, seen.y - size.y))
	button.position = at
	button.size = size

func _on_twitch(record: Dictionary) -> void:
	_twitches.append({"at": snappedf(_clock, 0.01), "record": _plain(record)})
	var most: int = int(_cfg().get("twitches", 5))
	while _twitches.size() > most:
		_twitches.pop_front()

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
	# To the millisecond, and never over another: two presses in a second were one report, the second
	# written over the first (the debug-agent's TASK-027: "文件名只到秒，一秒里按两次，后一份会盖掉前一份").
	var stamp: String = "%s-%03d" % [Time.get_datetime_string_from_system().replace(":", "-"),
		int(fmod(Time.get_unix_time_from_system(), 1.0) * 1000.0)]
	var path: String = "%s/bug-%s.json" % [DIR, stamp]
	var again: int = 1
	while FileAccess.file_exists(path):
		again += 1
		path = "%s/bug-%s-%d.json" % [DIR, stamp, again]
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
	out["slots"] = _slots()
	out["twitches"] = _twitches.duplicate()
	out["corner"] = _corner()
	out["events"] = _events.duplicate()
	return out

## The places round each building an animal bites it from (inner) or waits at, and which animal holds each
## (Dino.attack_slots).
func _slots() -> Array:
	var out: Array = []
	var all: Dictionary = Dino.attack_slots()
	for b_id in all:
		var b: Object = instance_from_id(int(b_id))
		var places: Array = []
		for s in all[b_id]:
			var who: int = int(s.get("dino_id", 0))
			var holder: Object = instance_from_id(who) if who != 0 else null
			places.append({"pos": _xz(s["pos"]), "inner": bool(s.get("inner", false)),
				"held_by": who if who != 0 else null,
				"name": String((holder as Node).name) if (holder is Node and is_instance_valid(holder)) else null})
		out.append({"building": String(b.get("building_type")) if (b != null and is_instance_valid(b)) else "(gone)",
			"id": int(b_id), "places": places})
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
