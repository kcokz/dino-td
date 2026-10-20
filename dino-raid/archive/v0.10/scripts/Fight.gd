class_name Fight
extends RefCounted
## One battle outside the homeland, fought by itself (GAME-DESIGN 17, 19): this round's army -- standing where its
## nests stand on the homeland's battle line -- against a wave, each going for the nearest foe -- a flier for the one
## furthest back -- and hitting it once it is in reach, until one side is gone or the time is up. One with a charging
## horn strikes its first blow twice as hard. Some fall hard: they burst, harming the other side round them, or break
## into smaller ones. Worked out in fixed steps with nothing random, so the same two sides always end the same way;
## every blow struck in a step lands at its end, so no side strikes first.
##
## Plain data and rules, nothing on screen. A fighter:
##   {id, side "ours"|"theirs", kind, roster (the army unit's id, ours only), affixes, pos: Vector2 (x, z), hp, max,
##    atk, armor, every, range, speed, size, splash, heal, pierce, burst, split, splits, power, dive, charge, harm, cool;
##    ours also row, lane, slot, of (Home.army)}
## Events of a step: hit {from, to, dmg, charge}, heal {from, to, amount}, die {id}, burst {id, at, radius},
## spawn {unit: the new fighter}.

const STEP := 0.1
const LIMIT := 45.0               # seconds; the battle is lost if theirs still stand then
const FRONT := 5.0                # metres either side of the middle where the front ranks start
const BACK := 10.0
const SPACING := 1.8
const OUR_FRONT := 4.0            # metres from the middle where our front row stands...
const ROW_GAP := 3.0              # ...and the row behind it, this much further back
const LANE_GAP := 2.6             # metres between lanes (the homeland's columns)

var units: Array = []
var time := 0.0
var over := false
var result := ""                  # "won", "lost", or "time" (lost on time)
var _next := 1


## `army` (Home.army's units) against `wave` at `power`.
static func make(army: Array, wave: Array, power: float) -> Fight:
	var f := Fight.new()
	for u in army:
		var fu := f._add("ours", u.kind, Content.unit_stats(u), str(u.id), u.get("affixes", []), 1.0)
		fu.elite = int(u.get("elite", 0))
		if u.has("row"):
			fu.row = int(u.row)
			fu.lane = float(u.lane)
			fu.slot = int(u.get("slot", 0))
			fu.of = int(u.get("of", 1))
	for k in wave:
		f._add("theirs", k, Content.enemy_stats(k, power), "", [], power)
	f._form("ours")
	f._form("theirs")
	return f


## A step of the battle. Its events.
func step() -> Array:
	var ev: Array = []
	if over:
		return ev
	time += STEP
	var blows: Array = []            # [striker, struck, attack]
	for u in units:
		if int(u.hp) <= 0:
			continue
		u.cool = maxf(0.0, float(u.cool) - STEP)
		if int(u.heal) > 0 and float(u.cool) <= 0.0:
			var hurt: Variant = _most_hurt_friend(u)
			if hurt != null:
				var amount := mini(int(u.heal), int(hurt.max) - int(hurt.hp))
				hurt.hp = int(hurt.hp) + amount
				u.cool = float(u.every)
				ev.append({"t": "heal", "from": u.id, "to": hurt.id, "amount": amount})
				continue
		var foe: Variant = _foe_of(u)
		if foe == null:
			continue
		var gap: float = (foe.pos as Vector2).distance_to(u.pos) - (float(u.size) + float(foe.size)) * 0.5
		if gap > float(u.range):
			var dir: Vector2 = ((foe.pos as Vector2) - (u.pos as Vector2)).normalized()
			u.pos = (u.pos as Vector2) + dir * minf(float(u.speed) * STEP, gap - float(u.range) + 0.01)
		elif float(u.cool) <= 0.0:
			_strike(u, foe, blows)
			u.cool = float(u.every)
	var fell: Array = []
	for b in blows:
		_harm(b[0], b[1], b[2], ev, fell, b[3])
	# Those that fell this step burst and break -- and what a burst fells, in turn.
	var k := 0
	while k < fell.size():
		var d: Dictionary = fell[k]
		k += 1
		if int(d.burst) > 0:
			ev.append({"t": "burst", "id": d.id, "at": d.pos, "radius": Content.BURST_RADIUS})
			for o in units.duplicate():
				if o.side != d.side and int(o.hp) > 0 and (o.pos as Vector2).distance_to(d.pos) <= Content.BURST_RADIUS:
					_harm(d, o, int(d.burst), ev, fell)
		if str(d.get("split", "")) != "":
			for i in int(d.splits):
				var s := Content.enemy_stats(d.split, float(d.power))
				var child := _add(d.side, d.split, s, "", [], float(d.power))
				child.pos = (d.pos as Vector2) + Vector2(0.0, (i - (int(d.splits) - 1) * 0.5) * 0.9)
				child.cool = 0.5
				ev.append({"t": "spawn", "unit": child.duplicate()})
	_spread()
	var ours := alive("ours").size()
	var theirs := alive("theirs").size()
	if theirs == 0:
		over = true
		result = "won"
	elif ours == 0:
		over = true
		result = "lost"
	elif time >= LIMIT:
		over = true
		result = "time"
	return ev


## The whole battle at once (for tests, the forecast and the bot): all its events.
func run() -> Array:
	var ev: Array = []
	while not over:
		ev.append_array(step())
	return ev


func alive(side: String) -> Array:
	return units.filter(func(u: Dictionary) -> bool: return u.side == side and int(u.hp) > 0)


## What the homeland takes for a battle not won: each of theirs still standing.
func harm() -> int:
	var n := 0
	for u in alive("theirs"):
		n += int(u.harm)
	return n


## A side's strength all told (Content.strength of each fighter at full health).
func strength(side: String) -> float:
	var n := 0.0
	for u in units:
		if u.side == side and not u.get("spawned", false):
			n += Content.strength(u, float(u.power))
	return n


## How many of ours fell.
func fallen() -> int:
	return units.filter(func(u: Dictionary) -> bool: return u.side == "ours" and int(u.hp) <= 0).size()


func unit(id: int) -> Variant:
	for u in units:
		if u.id == id:
			return u
	return null


## u strikes the foe -- its first blow twice as hard with a charging horn -- and, with splash, everyone of the foe's
## side near it for half; to land at the step's end.
func _strike(u: Dictionary, foe: Dictionary, blows: Array) -> void:
	var atk := int(u.atk)
	var charged: bool = u.get("charge", false)
	if charged:
		atk *= 2
		u.charge = false
	blows.append([u, foe, atk, charged])
	if float(u.splash) > 0.0:
		for o in units:
			if o.side == foe.side and o.id != foe.id and int(o.hp) > 0 and (o.pos as Vector2).distance_to(foe.pos) <= float(u.splash):
				blows.append([u, o, ceili(atk / 2.0), false])


## A blow lands: less the armour (at least 1), and the striker's pierce on top. One it fells joins `fell`.
func _harm(u: Dictionary, foe: Dictionary, atk: int, ev: Array, fell: Array, charged := false) -> void:
	var was := int(foe.hp)
	var dmg := maxi(1, atk - int(foe.armor)) + int(u.get("pierce", 0))
	foe.hp = was - dmg
	ev.append({"t": "hit", "from": u.id, "to": foe.id, "dmg": dmg, "charge": charged})
	if was > 0 and int(foe.hp) <= 0:
		ev.append({"t": "die", "id": foe.id})
		fell.append(foe)


## Whom u goes for: the nearest foe standing (nearest, then weakest, then the first made -- never a doubt which);
## a flier, the one furthest back on the other side.
func _foe_of(u: Dictionary) -> Variant:
	var best: Variant = null
	var best_d := INF
	var forward := 1.0 if u.side == "ours" else -1.0
	for o in units:
		if o.side == u.side or int(o.hp) <= 0:
			continue
		var d: float = -(o.pos as Vector2).x * forward if u.dive else (o.pos as Vector2).distance_to(u.pos)
		if d < best_d - 0.001 or absf(d - best_d) <= 0.001 and best != null and int(o.hp) < int(best.hp):
			best = o
			best_d = d
	return best


func _most_hurt_friend(u: Dictionary) -> Variant:
	var best: Variant = null
	for o in units:
		if o.side != u.side or int(o.hp) <= 0 or int(o.hp) >= int(o.max):
			continue
		if (o.pos as Vector2).distance_to(u.pos) > float(u.range) + 1.0:
			continue
		if best == null or float(o.hp) / int(o.max) < float(best.hp) / int(best.max):
			best = o
	return best


## Overlapping fighters pushed apart, so a crowd stays a crowd and not one block.
func _spread() -> void:
	var live := units.filter(func(u: Dictionary) -> bool: return int(u.hp) > 0)
	for i in live.size():
		for j in range(i + 1, live.size()):
			var a: Dictionary = live[i]
			var b: Dictionary = live[j]
			var d: Vector2 = (b.pos as Vector2) - (a.pos as Vector2)
			var need := (float(a.size) + float(b.size)) * 0.5
			var len := d.length()
			if len >= need:
				continue
			var push := (need - len) * 0.5
			var dir := d / len if len > 0.0001 else Vector2(0.0, 1.0)
			a.pos = (a.pos as Vector2) - dir * push
			b.pos = (b.pos as Vector2) + dir * push


func _add(side: String, kind: String, s: Dictionary, roster: String, affixes: Array, power: float) -> Dictionary:
	var u := {"id": _next, "side": side, "kind": kind, "roster": roster, "affixes": affixes, "pos": Vector2.ZERO,
		"hp": int(s.hp), "max": int(s.hp), "atk": int(s.atk), "armor": int(s.armor), "every": float(s.every),
		"range": float(s.range), "speed": float(s.speed), "size": float(s.size), "splash": float(s.splash),
		"heal": int(s.heal), "pierce": int(s.get("pierce", 0)), "burst": int(s.get("burst", 0)),
		"split": str(s.get("split", "")), "splits": int(s.get("splits", 0)), "power": power,
		"dive": bool(s.get("dive", false)), "charge": bool(s.get("charge", false)), "harm": int(s.get("harm", 0)),
		"cool": 0.0, "spawned": time > 0.0}
	units.append(u)
	_next += 1
	return u


## The ranks a side starts in. Ours stand where their nests stand on the homeland's battle line (Home): its top row in
## front, each column a lane -- the homeland turned to face the enemy -- a nest's units side by side in their place,
## more behind them when there are many. Theirs (and any of ours from no nest) by reach: the short-reach ones in front,
## the long-reach behind, each rank spread along the line, more ranks behind when a rank is full.
func _form(side: String) -> void:
	var sign := -1.0 if side == "ours" else 1.0
	var list := units.filter(func(u: Dictionary) -> bool: return u.side == side)
	for u in list.filter(func(u: Dictionary) -> bool: return u.has("row")):
		var n := mini(int(u.of), 3)
		var depth: float = OUR_FRONT + float(u.row) * ROW_GAP + (int(u.slot) / 3) * 0.8
		var across: float = (float(u.lane) - (Home.COLS - 1) * 0.5) * LANE_GAP + ((int(u.slot) % 3) - (n - 1) * 0.5) * 0.85
		u.pos = Vector2(sign * depth, across)
	list = list.filter(func(u: Dictionary) -> bool: return not u.has("row"))
	var front := list.filter(func(u: Dictionary) -> bool: return float(u.range) < 3.0)
	var back := list.filter(func(u: Dictionary) -> bool: return float(u.range) >= 3.0)
	for pair in [[front, FRONT], [back, BACK]]:
		var rank: Array = pair[0]
		var per := 8
		for i in rank.size():
			var col := i / per
			var row := i % per
			var n := mini(per, rank.size() - col * per)
			var z := (row - (n - 1) * 0.5) * SPACING
			rank[i].pos = Vector2(sign * (float(pair[1]) + col * 2.2), z)
