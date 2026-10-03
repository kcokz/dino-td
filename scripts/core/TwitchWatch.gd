# res://scripts/core/TwitchWatch.gd
class_name TwitchWatch
extends Node

## THE TWITCH WATCH (v0.6 round four: "我觉得你需要做一个恐龙抽搐detector，如果恐龙抽搐，它就立刻report一些
## debug 信息，这个在release的时候甚至可以作为telemetry"). Every animal on the field is watched, frame by
## frame, for what a player sees as a twitch -- and one that twitches is written up at once: what it
## has in mind and why, where it means to go and by what route, what is round it, and its last seconds.
##
## What counts (Config.TWITCH), each over the last seconds of game time:
##   JITTER   its body stepping back the way it came, again and again, getting nowhere;
##   SHAKE    its heading swinging one way and back, again and again, getting nowhere -- the
##            debug-agent's BUG-005, "左右各摆 48°";
##   FIDGET   standing, biting nothing, and its head going one way and back, however slowly --
##            "傻站着甩头" (BUG-008);
##   FLICKER  what it is drawn doing changing back and forth -- walk, stand, walk -- while it is
##            not biting (a bite is a clip and back, each bite);
##   DITHER   its mind changing back and forth: going for a thing, letting go, going for it;
##   PUSH     asking to walk and getting nowhere for longer than any rule of its own allows --
##            "全速顶着什么";
##   MILL     walking and walking, biting nothing, and ending where it began: "转来转去".
##
## A report is one line in the log ([TWITCH]), one line of JSON in this launch's file under
## Config.TWITCH.dir, and EventBus.twitch_detected, where anything else can take it -- one day an
## upload, if the player agrees to one; none is made. In a debug build the animal is marked on the
## field for a moment with the report's number, so what was seen and what was written can be put
## together. A child of the level: it stops with the game's pause, which is a snapshot.

## Whether reports are written to a file. The test runner turns it off: a test's twitches go to
## its log, not into the player's telemetry.
static var to_file: bool = true
## Whether a report puts its number over the animal's head (TwitchMark): for whoever is hunting
## twitches -- a test, the debug-agent's runs (DINO_TWITCH_MARKS in the environment) -- and not for the
## player, to whom "twitch#1" over a phytosaur at night was a bug of its own (the player's report,
## 2026-09-29).
static var show_marks: bool = OS.get_environment("DINO_TWITCH_MARKS") != ""
## Where this launch's file goes, when not Config.TWITCH.dir (a test's own folder), and the file
## itself -- named once a launch, on the first report.
static var file_dir: String = ""
static var file_path: String = ""
## This launch's reports so far: each is numbered by it, and no more than max_reports are made.
static var reports_made: int = 0

## A bucket of one animal's record: seconds; metres walked; metres it asked to walk; steps back,
## swings back, clips back, minds back; frames biting; where it stood when the bucket opened.
const B_SECONDS := 0
const B_PATH := 1
const B_ASKED := 2
const B_JITTER := 3
const B_SHAKE := 4
const B_FLICKER := 5
const B_DITHER := 6
const B_BITING := 7
const B_X := 8
const B_Z := 9
const B_FIDGET := 10
const B_FIELDS := 11

## One animal's record: where it was a frame ago and what it was doing, the way it has been going
## and turning since it last turned back, and its last seconds in buckets, oldest first.
class Track:
	var pos: Vector3
	var yaw: float
	var leg: Vector2 = Vector2.ZERO
	var swing: float = 0.0
	## The same swing, never let lapse for standing: FIDGET counts turns back however far apart.
	var slow_swing: float = 0.0
	## Seconds it has stood without a step, and without turning: a leg or a swing is over once it
	## has been still for Config.TWITCH.settle.
	var still: float = 0.0
	var steady: float = 0.0
	var clip: String = ""
	var clip_before: String = ""
	var mind: int = 0
	var mind_before: int = 0
	var open: PackedFloat32Array = PackedFloat32Array()
	var buckets: Array[PackedFloat32Array] = []
	## Its last frames, for the report: x, z and its heading in degrees.
	var frames: PackedVector3Array = PackedVector3Array()
	## Its last changes of clip and of mind, for the report: [the watch's clock, what it became].
	var clips: Array = []
	var minds: Array = []
	## Kind -> the watch's clock before which it is not reported for that again.
	var quiet_until: Dictionary = {}
	## Whether it was on its way home (Dino.going_home) -- turned for home, it is watched afresh.
	var home: bool = false
	## The watch's clock when it was last after the Hero (-INF never): MILL leaves alone the walk it took
	## after him and back.
	var after_him_at: float = -INF

## Every animal watched, by instance id; the marks up on the field, [Label3D, seconds left]; and
## the game seconds this watch has run.
var _tracks: Dictionary = {}
var _marks: Array = []
var _clock: float = 0.0

func _cfg() -> Dictionary:
	var cfg = get_node_or_null("/root/Config") if is_inside_tree() else null
	return cfg.TWITCH if (cfg and "TWITCH" in cfg) else {}

func _physics_process(delta: float) -> void:
	if delta <= 0.0 or not is_inside_tree():
		return
	_clock += delta
	var cfg: Dictionary = _cfg()
	var alive: Dictionary = {}
	for d in get_tree().get_nodes_in_group("dinos"):
		if not (d is Node3D) or not is_instance_valid(d) or ("is_dead" in d and d.is_dead):
			continue
		var id: int = d.get_instance_id()
		alive[id] = true
		var t: Track = _tracks.get(id)
		# Its hours over, it turns for home: a new walk, watched afresh. The seconds either side of the
		# turn were a walk out and the same walk back, and read as round and round on the spot -- six
		# raiders reported milling at the first moment of dusk, going home at full speed (the
		# debug-agent's BUG-015). Milling on the way home is still seen: it is after the turn.
		# Shoved by a log (Dino.knock_back): carried back the way it came is not a twitch -- watched afresh after.
		if d.has_method("is_shoved") and d.is_shoved():
			var shoved: Track = _new_track(d as Node3D)
			if t != null:
				shoved.quiet_until = t.quiet_until
			_tracks[id] = shoved
			continue
		if t == null or t.home != _going_home(d):
			var fresh: Track = _new_track(d as Node3D)
			if t != null:
				fresh.quiet_until = t.quiet_until
			_tracks[id] = fresh
		else:
			_watch(d as Node3D, t, delta, cfg)
	for id in _tracks.keys():
		if not alive.has(id):
			_tracks.erase(id)
	_age_marks(delta)

# ==============================================================================
# Watching
# ==============================================================================

func _new_track(d: Node3D) -> Track:
	var t := Track.new()
	t.pos = d.global_position
	t.yaw = d.rotation.y
	t.open = _bucket_at(d.global_position)
	t.clip = _clip_of(d)
	t.mind = _mind_of(d)
	t.home = _going_home(d)
	return t

func _going_home(d: Node) -> bool:
	return "going_home" in d and bool(d.going_home)

func _bucket_at(pos: Vector3) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(B_FIELDS)
	b[B_X] = pos.x
	b[B_Z] = pos.z
	return b

## One frame of one animal, into its open bucket; a bucket full, it is closed and the animal judged.
func _watch(d: Node3D, t: Track, delta: float, cfg: Dictionary) -> void:
	var pos: Vector3 = d.global_position
	var yaw: float = d.rotation.y
	var biting: bool = "current_state" in d and int(d.current_state) == int(Dino.State.ATTACKING)
	var after = d.current_target if "current_target" in d else null
	if after != null and is_instance_valid(after) and (after as Node).is_in_group("hero"):
		t.after_him_at = _clock
	var b: PackedFloat32Array = t.open
	b[B_SECONDS] += delta
	# JITTER: a step back against the way it has been going, once that way was long enough to see.
	var step := Vector2(pos.x - t.pos.x, pos.z - t.pos.z)
	var along: float = step.length()
	b[B_PATH] += along
	# A leg or a swing is over once it has been still a moment: a turn one way, a stand, and a turn
	# the other way seconds later is not a shake (a guard that did just that was reported).
	var settle: float = float(cfg.get("settle", 0.3))
	t.still = t.still + delta if along <= 0.0001 else 0.0
	if t.still >= settle:
		t.leg = Vector2.ZERO
	if along > 0.0001:
		if t.leg != Vector2.ZERO and step.dot(t.leg) < -0.5 * along * t.leg.length():
			if t.leg.length() >= float(cfg.get("leg_min", 0.03)):
				b[B_JITTER] += 1.0
			t.leg = step
		else:
			t.leg += step
	# SHAKE: a turn back against the way it has been turning, once that swing was big enough to see.
	var turn: float = wrapf(yaw - t.yaw, -PI, PI)
	t.steady = t.steady + delta if absf(turn) <= 0.0001 else 0.0
	if t.steady >= settle:
		t.swing = 0.0
	if absf(turn) > 0.0001:
		var swing_min: float = deg_to_rad(float(cfg.get("swing_min_deg", 15.0)))
		if t.swing != 0.0 and signf(turn) != signf(t.swing):
			if absf(t.swing) >= swing_min:
				b[B_SHAKE] += 1.0
			t.swing = turn
		else:
			t.swing += turn
		if t.slow_swing != 0.0 and signf(turn) != signf(t.slow_swing):
			if absf(t.slow_swing) >= swing_min:
				b[B_FIDGET] += 1.0
			t.slow_swing = turn
		else:
			t.slow_swing += turn
	# FLICKER: drawn doing again what it was drawn doing the change before -- not while it bites.
	var clip: String = _clip_of(d)
	if clip != t.clip:
		if clip == t.clip_before and not biting:
			b[B_FLICKER] += 1.0
		t.clip_before = t.clip
		t.clip = clip
		_log_change(t.clips, clip, cfg)
	# DITHER: back to the mind it had the change before.
	var mind: int = _mind_of(d)
	if mind != t.mind:
		if mind == t.mind_before:
			b[B_DITHER] += 1.0
		t.mind_before = t.mind
		t.mind = mind
		var target = d.current_target if "current_target" in d else null
		var what: String = ""
		if target != null and is_instance_valid(target):
			what = String(target.get("building_type")) if "building_type" in target else String((target as Node).name)
		_log_change(t.minds, "%s %s" % [_mind_name(d), what], cfg)
	if biting:
		b[B_BITING] += 1.0
	var asked: Vector3 = (d as CharacterBody3D).velocity if d is CharacterBody3D else Vector3.ZERO
	b[B_ASKED] += Vector2(asked.x, asked.z).length() * delta
	t.pos = pos
	t.yaw = yaw
	t.frames.append(Vector3(snappedf(pos.x, 0.001), snappedf(pos.z, 0.001), snappedf(rad_to_deg(yaw), 0.1)))
	while t.frames.size() > int(cfg.get("frames", 30)):
		t.frames.remove_at(0)
	if b[B_SECONDS] < float(cfg.get("bucket", 0.25)):
		t.open = b
		return
	t.buckets.append(b)
	var keep: int = _buckets_in(maxf(maxf(float(cfg.get("mill_window", 6.0)), float(cfg.get("push_window", 4.0))),
		float(cfg.get("fidget_window", 6.0))), cfg)
	while t.buckets.size() > keep:
		t.buckets.pop_front()
	t.open = _bucket_at(pos)
	_judge(d, t, cfg)

func _log_change(log: Array, what: String, cfg: Dictionary) -> void:
	log.append([snappedf(_clock, 0.01), what])
	while log.size() > int(cfg.get("changes", 8)):
		log.pop_front()

## What it is drawn doing: its animator's clip, or "" with none.
func _clip_of(d: Node) -> String:
	var anim = d.get("animator") if "animator" in d else null
	if anim == null or not is_instance_valid(anim) or not ("current_clip" in anim):
		return ""
	return String(anim.current_clip)

## What it has in mind, as one number to compare: its state -- a guard's own, or the raid's Mode --
## and what it is going for.
func _mind_of(d: Node) -> int:
	var state: int = int(d.guard_state) if "guard_state" in d else (int(d.mode) if "mode" in d else 0)
	var target = d.current_target if "current_target" in d else null
	var target_id: int = target.get_instance_id() if (target != null and is_instance_valid(target)) else 0
	return target_id * 8 + state

func _buckets_in(seconds: float, cfg: Dictionary) -> int:
	return maxi(1, int(round(seconds / maxf(0.01, float(cfg.get("bucket", 0.25))))))

# ==============================================================================
# Judging
# ==============================================================================

## The last `seconds` of an animal's record, summed -- or {} while it has not been watched that long.
func _sum(t: Track, seconds: float, cfg: Dictionary) -> Dictionary:
	var n: int = _buckets_in(seconds, cfg)
	if t.buckets.size() < n:
		return {}
	var s: Dictionary = {"seconds": 0.0, "path": 0.0, "asked": 0.0, "jitter": 0, "shake": 0, "flicker": 0,
		"dither": 0, "fidget": 0, "biting_frames": 0}
	for i in range(t.buckets.size() - n, t.buckets.size()):
		var b: PackedFloat32Array = t.buckets[i]
		s["seconds"] += b[B_SECONDS]
		s["path"] += b[B_PATH]
		s["asked"] += b[B_ASKED]
		s["jitter"] += int(b[B_JITTER])
		s["shake"] += int(b[B_SHAKE])
		s["flicker"] += int(b[B_FLICKER])
		s["dither"] += int(b[B_DITHER])
		s["fidget"] += int(b[B_FIDGET])
		s["biting_frames"] += int(b[B_BITING])
	var first: PackedFloat32Array = t.buckets[t.buckets.size() - n]
	s["net"] = Vector2(t.pos.x - first[B_X], t.pos.z - first[B_Z]).length()
	for key in ["seconds", "path", "asked", "net"]:
		s[key] = snappedf(float(s[key]), 0.01)
	return s

## Whether the animal twitched, by each rule in turn (Config.TWITCH); the first it breaks is reported.
func _judge(d: Node3D, t: Track, cfg: Dictionary) -> void:
	var w: Dictionary = _sum(t, float(cfg.get("window", 2.0)), cfg)
	if w.is_empty():
		return
	if int(w["jitter"]) >= int(cfg.get("jitter_flips", 4)) and float(w["net"]) <= float(cfg.get("jitter_net", 0.5)):
		_report(d, t, "jitter", w, cfg)
	elif int(w["shake"]) >= int(cfg.get("shake_flips", 3)) and float(w["path"]) <= float(cfg.get("shake_path", 1.5)) \
			and float(w["net"]) <= float(cfg.get("shake_net", 1.0)):
		_report(d, t, "shake", w, cfg)
	elif int(w["flicker"]) >= int(cfg.get("flicker_flips", 4)):
		_report(d, t, "flicker", w, cfg)
	elif int(w["dither"]) >= int(cfg.get("dither_flips", 3)):
		_report(d, t, "dither", w, cfg)
	else:
		var push_s: float = float(cfg.get("push_window", 4.0))
		var p: Dictionary = _sum(t, push_s, cfg)
		if not p.is_empty() and int(p["biting_frames"]) == 0 \
				and float(p["asked"]) >= float(cfg.get("push_speed", 1.0)) * push_s \
				and float(p["path"]) <= float(p["asked"]) * float(cfg.get("push_share", 0.25)) \
				and float(p["net"]) <= float(cfg.get("push_net", 0.3)):
			_report(d, t, "push", p, cfg)
			return
		var m: Dictionary = _sum(t, float(cfg.get("mill_window", 6.0)), cfg)
		if not m.is_empty() and _mills(d, m, cfg):
			_report(d, t, "mill", m, cfg)
			return
		var f: Dictionary = _sum(t, float(cfg.get("fidget_window", 6.0)), cfg)
		if not f.is_empty() and int(f["biting_frames"]) == 0 and int(f["fidget"]) >= int(cfg.get("fidget_flips", 4)) \
				and float(f["path"]) <= float(cfg.get("fidget_path", 0.5)):
			_report(d, t, "fidget", f, cfg)

## MILL is a raider's: a guard ambles about its post by design, and one after the Hero follows him
## round whatever he walks round -- and, let go of him, walks back the way it came: out after him and
## back is not round and round on the spot (a dash after him, then the cabin again, was reported -- the
## player, 2026-10-02, "恐龙追不上人": a raider set on him bursts now, Config.DINO_AI.bursts).
func _mills(d: Node3D, m: Dictionary, cfg: Dictionary) -> bool:
	if d.is_in_group("guard_dinos") or int(m["biting_frames"]) > 0:
		return false
	var target = d.current_target if "current_target" in d else null
	if target != null and is_instance_valid(target) and (target as Node).is_in_group("hero"):
		return false
	var t: Track = _tracks.get(d.get_instance_id())
	if t != null and _clock - t.after_him_at <= float(cfg.get("mill_window", 6.0)):
		return false
	return float(m["path"]) >= float(cfg.get("mill_path", 6.0)) and float(m["net"]) <= float(cfg.get("mill_net", 1.5)) \
		and float(m["path"]) / float(int(m["jitter"]) + 1) >= float(cfg.get("mill_leg", 1.0))

# ==============================================================================
# Reporting
# ==============================================================================

func _report(d: Node3D, t: Track, kind: String, window: Dictionary, cfg: Dictionary) -> void:
	if _clock < float(t.quiet_until.get(kind, -1.0)):
		return
	t.quiet_until[kind] = _clock + float(cfg.get("cooldown", 8.0))
	if reports_made >= int(cfg.get("max_reports", 200)):
		return
	reports_made += 1
	var record: Dictionary = {
		"v": 1,
		"n": reports_made,
		"kind": kind,
		"at": Time.get_datetime_string_from_system(true),
		"game": _game_now(),
		"dino": d.debug_state() if d.has_method("debug_state") else {"id": d.get_instance_id(), "name": String(d.name)},
		"window": window,
		"trail": _trail_of(t),
		"near": _round_about(d, float(cfg.get("near", 3.0))),
	}
	print(_line_for(record))
	if to_file:
		_write(record, cfg)
	var eb = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("twitch_detected"):
		eb.twitch_detected.emit(record)
	if OS.is_debug_build() and show_marks:
		_mark(d, reports_made, cfg)

## The run it happened in: the build, the map and its seed, the raid, the hour, the speed.
func _game_now() -> Dictionary:
	var out: Dictionary = {"version": AppInfo.get_version(), "speed": Engine.time_scale,
		"fps": Engine.get_frames_per_second(), "watched": snappedf(_clock, 0.01),
		"dinos": get_tree().get_nodes_in_group("dinos").size()}
	var gs = get_node_or_null("/root/GameState")
	if gs:
		out["map"] = String(gs.map_id)
		out["seed"] = int(gs.run_seed)
		out["wave"] = int(gs.wave_number)
		if gs.has_method("day_part"):
			out["day"] = int(gs.day_number())
			out["day_part"] = String(gs.day_part())
			out["day_clock"] = snappedf(float(gs.day_clock), 0.1)
	var level: Node = get_parent()
	var wm = level.get("wave_manager") if (level != null and "wave_manager" in level) else null
	if wm != null and is_instance_valid(wm):
		out["raid"] = bool(wm.is_wave_active)
		out["raid_alive"] = int(wm.dinos_alive_count)
	return out

## Its last seconds: each bucket -- where it stood as it opened, and what was counted in it -- and its
## last frames.
func _trail_of(t: Track) -> Dictionary:
	var buckets: Array = []
	for b in t.buckets:
		buckets.append([snappedf(b[B_X], 0.01), snappedf(b[B_Z], 0.01), snappedf(b[B_PATH], 0.01),
			snappedf(b[B_ASKED], 0.01), int(b[B_JITTER]), int(b[B_SHAKE]), int(b[B_FLICKER]),
			int(b[B_DITHER]), int(b[B_BITING]), int(b[B_FIDGET])])
	var frames: Array = []
	for f in t.frames:
		frames.append([f.x, f.y, f.z])
	return {"bucket_fields": ["x", "z", "path", "asked", "jitter", "shake", "flicker", "dither", "biting_frames", "fidget"],
		"buckets": buckets, "frame_fields": ["x", "z", "heading"], "frames": frames,
		"now": snappedf(_clock, 0.01), "clips": t.clips.duplicate(), "minds": t.minds.duplicate()}

## What is round it: the other animals, the buildings and the Hero within `radius` metres.
func _round_about(d: Node3D, radius: float) -> Dictionary:
	var at := Vector2(d.global_position.x, d.global_position.z)
	var animals: Array = []
	for o in get_tree().get_nodes_in_group("dinos"):
		if o == d or not (o is Node3D) or not is_instance_valid(o) or animals.size() >= 8:
			continue
		var dist: float = at.distance_to(Vector2((o as Node3D).global_position.x, (o as Node3D).global_position.z))
		if dist <= radius:
			animals.append({"id": o.get_instance_id(), "species": String(o.get("dino_type")),
				"pos": [snappedf((o as Node3D).global_position.x, 0.01), snappedf((o as Node3D).global_position.z, 0.01)],
				"mind": _mind_name(o), "dist": snappedf(dist, 0.01)})
	var built: Array = []
	for b in get_tree().get_nodes_in_group("buildings"):
		if not (b is Node3D) or not is_instance_valid(b) or built.size() >= 8:
			continue
		var dist: float = at.distance_to(Vector2((b as Node3D).global_position.x, (b as Node3D).global_position.z))
		if dist <= radius + 2.0:
			built.append({"type": String(b.get("building_type")),
				"pos": [snappedf((b as Node3D).global_position.x, 0.01), snappedf((b as Node3D).global_position.z, 0.01)],
				"dist": snappedf(dist, 0.01)})
	var hero = get_tree().get_first_node_in_group("hero")
	var out: Dictionary = {"animals": animals, "buildings": built}
	if hero is Node3D and is_instance_valid(hero):
		out["hero_dist"] = snappedf(at.distance_to(Vector2((hero as Node3D).global_position.x, (hero as Node3D).global_position.z)), 0.01)
	return out

func _mind_name(d: Node) -> String:
	if "guard_state" in d:
		return String(GuardDino.GuardState.keys()[int(d.guard_state)])
	if "mode" in d:
		return String(Dino.Mode.keys()[int(d.mode)])
	return ""

## The report in one line of the log.
func _line_for(r: Dictionary) -> String:
	var dino: Dictionary = r.get("dino", {})
	var w: Dictionary = r.get("window", {})
	var pos: Array = dino.get("pos", [0.0, 0.0, 0.0])
	var target = dino.get("target")
	var going: String = "%s %s" % [String(target.get("kind", "")), String(target.get("type", ""))] if target is Dictionary else "-"
	var mind: String = String(dino["guard"].get("state", "")) if dino.get("guard") is Dictionary else String(dino.get("mode", ""))
	return "[TWITCH] #%d %s: %s %s at (%.1f, %.1f), %s -> %s | %d s: jitter %d, shake %d, fidget %d, flicker %d, dither %d, walked %.1f m, asked %.1f m, net %.2f m" % [
		int(r.get("n", 0)), String(r.get("kind", "")), String(dino.get("species", "")), String(dino.get("name", "")),
		float(pos[0]), float(pos[pos.size() - 1]), mind, going.strip_edges(),
		int(round(float(w.get("seconds", 0.0)))), int(w.get("jitter", 0)), int(w.get("shake", 0)),
		int(w.get("fidget", 0)), int(w.get("flicker", 0)), int(w.get("dither", 0)), float(w.get("path", 0.0)), float(w.get("asked", 0.0)),
		float(w.get("net", 0.0))]

## Appends the report to this launch's file, starting the file -- and clearing out the oldest past
## keep_files -- with the first.
func _write(record: Dictionary, cfg: Dictionary) -> void:
	if file_path == "":
		# Which launch: the game itself, or a tool driving it (tools/playtest.gd, the debug-agent's bot)
		# -- whose files keep to a folder of their own, so a morning of them never clears out the
		# player's own (keep_files).
		var runner = Engine.get_main_loop().get_script()
		var dir: String = file_dir if file_dir != "" else String(cfg.get("dir", "user://telemetry"))
		if file_dir == "" and runner != null:
			dir = dir.path_join("tools")
		if DirAccess.make_dir_recursive_absolute(dir) != OK:
			return
		_prune(dir, int(cfg.get("keep_files", 20)) - 1)
		file_path = dir.path_join("twitch-%s.jsonl" % Time.get_datetime_string_from_system(false).replace(":", "-"))
		_append(file_path, JSON.stringify({"v": 1, "launch": Time.get_datetime_string_from_system(true),
			"version": AppInfo.get_version(), "engine": String(Engine.get_version_info().get("string", "")),
			"os": OS.get_name(), "debug": OS.is_debug_build(),
			"runner": String(runner.resource_path) if runner != null else "game"}))
		print("[TWITCH] reports go to ", ProjectSettings.globalize_path(file_path))
	_append(file_path, JSON.stringify(record))

static func _append(path: String, line: String) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ_WRITE) if FileAccess.file_exists(path) \
		else FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(line)
	f.close()

## Keeps the newest `keep` of the watch's files in `dir`.
static func _prune(dir: String, keep: int) -> void:
	var names: Array = []
	for f in DirAccess.get_files_at(dir):
		if String(f).begins_with("twitch-") and String(f).ends_with(".jsonl"):
			names.append(String(f))
	names.sort()
	while names.size() > maxi(0, keep):
		DirAccess.remove_absolute(dir.path_join(String(names.pop_front())))

# ==============================================================================
# The mark, in a debug build
# ==============================================================================

## Over its head for a moment: the report's number, in the interface's warning red.
func _mark(d: Node3D, n: int, cfg: Dictionary) -> void:
	var old: Node = d.get_node_or_null("TwitchMark")
	if old != null:
		d.remove_child(old)
		old.queue_free()
	var label := Label3D.new()
	label.name = "TwitchMark"
	UiTheme.style_world_label(label)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = UiTheme.color("danger")
	label.text = tr("TWITCH_MARK") % n
	var height: float = 1.0
	var config = get_node_or_null("/root/Config")
	if config and config.has_method("get_visual_size") and "dino_type" in d:
		height = float(config.get_visual_size("dino/" + String(d.dino_type)).y)
	label.position = Vector3(0.0, height + float(cfg.get("mark_above", 0.6)), 0.0)
	d.add_child(label)
	_marks.append([label, float(cfg.get("mark_seconds", 4.0))])

func _age_marks(delta: float) -> void:
	for i in range(_marks.size() - 1, -1, -1):
		var label = _marks[i][0]
		_marks[i][1] = float(_marks[i][1]) - delta
		if not is_instance_valid(label):
			_marks.remove_at(i)
		elif float(_marks[i][1]) <= 0.0:
			label.queue_free()
			_marks.remove_at(i)
