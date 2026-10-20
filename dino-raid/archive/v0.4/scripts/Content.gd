class_name Content
## What there is to build, make and fight (GAME-DESIGN 12) -- for now coloured blocks standing in for what they
## will be. The systems (Home, Fight, Run) read only this: change what is here and they follow.

## Units we make. hp; atk, each hit; every: seconds between hits; range, metres; speed, metres a second;
## armor: taken off every hit it takes; splash: metres round its mark that also take half; heal: hit points it
## gives the most hurt friend in reach (instead of hitting) when one is hurt. size: the block's edge.
const UNITS := {
	"red": {"name": "红兵", "color": Color(0.9, 0.24, 0.2), "hp": 10, "atk": 3, "every": 1.0, "range": 1.4,
		"speed": 3.2, "size": 0.9, "role": "前排，打得快"},
	"blue": {"name": "蓝兵", "color": Color(0.24, 0.5, 0.96), "hp": 6, "atk": 2, "every": 1.0, "range": 6.0,
		"speed": 2.6, "size": 0.8, "role": "后排，远处打"},
	"green": {"name": "绿兵", "color": Color(0.3, 0.74, 0.3), "hp": 22, "atk": 2, "every": 1.3, "range": 1.4,
		"speed": 2.2, "size": 1.15, "armor": 1, "role": "前排，挡刀"},
	"gold": {"name": "金兵", "color": Color(0.96, 0.74, 0.18), "hp": 16, "atk": 6, "every": 1.5, "range": 1.6,
		"speed": 2.6, "size": 1.3, "splash": 1.8, "role": "重击，一打一片"},
	"white": {"name": "白兵", "color": Color(0.93, 0.93, 0.9), "hp": 8, "atk": 1, "every": 1.0, "range": 5.0,
		"speed": 2.4, "size": 0.8, "heal": 3, "role": "给受伤的同伴回血"},
}

## What comes for the homeland. harm: hit points the homeland loses for each one still standing when a battle
## is lost.
const ENEMIES := {
	"grey": {"name": "灰怪", "color": Color(0.52, 0.52, 0.55), "hp": 9, "atk": 3, "every": 1.0, "range": 1.4,
		"speed": 2.8, "size": 0.9, "harm": 1},
	"purple": {"name": "紫怪", "color": Color(0.6, 0.3, 0.76), "hp": 6, "atk": 2, "every": 1.0, "range": 6.0,
		"speed": 2.4, "size": 0.8, "harm": 1},
	"black": {"name": "黑怪", "color": Color(0.16, 0.16, 0.18), "hp": 22, "atk": 3, "every": 1.3, "range": 1.4,
		"speed": 2.0, "size": 1.2, "armor": 1, "harm": 2},
	"boss": {"name": "首领", "color": Color(0.58, 0.08, 0.1), "hp": 90, "atk": 8, "every": 1.6, "range": 2.0,
		"speed": 1.8, "size": 2.2, "armor": 2, "splash": 2.0, "harm": 8},
}

const STAR := [1.0, 1.8, 3.2]          # hp and atk at one, two and three stars

## Strength (战力): how strong a fighter is, as one number the player never sees -- for balancing. The square root
## of what it can take times what it deals a second, so that a side's strength is the sum of its fighters' and two
## sides of equal strength have an even fight (tools/strength_check.gd checks this). A grey is 10.
const STRENGTH_K := 1.9245              # 10 / sqrt(9 hp * 3 a second)
const TYPICAL_HIT := 4.0               # armour is worth what it takes off a hit this hard
const REACH_WORTH := 0.3                # standing back (a reach of 3 m or more): it takes this much more
const SPLASH_WORTH := 1.0               # each metre of splash: it deals this much more
const HEAL_WORTH := 0.6                 # a hit point healed, against one dealt
const MERGE := 3                       # this many the same, of the same stars, make one of a star more

## Buildings, by level. What a level may do:
##   makes, count, every[, star]: a producer -- `count` of unit `makes` every `every` rounds (at `star` stars).
##   room: that many more units can be kept.     income: that much more energy each round.
##   hurry: producers beside it make one round sooner (not sooner than every round).
##   drill: units made beside it hit this much harder, for good.
##   wall: the homeland's hit points this much higher; block: each lost battle harms it this much less.
const BUILDINGS := {
	"hatch_red": {"name": "红巢", "color": Color(0.9, 0.24, 0.2), "levels": [
		{"makes": "red", "count": 1, "every": 1}, {"makes": "red", "count": 2, "every": 1},
		{"makes": "red", "count": 1, "every": 1, "star": 2}]},
	"hatch_blue": {"name": "蓝巢", "color": Color(0.24, 0.5, 0.96), "levels": [
		{"makes": "blue", "count": 1, "every": 2}, {"makes": "blue", "count": 1, "every": 1},
		{"makes": "blue", "count": 2, "every": 1}]},
	"hatch_green": {"name": "绿巢", "color": Color(0.3, 0.74, 0.3), "levels": [
		{"makes": "green", "count": 1, "every": 2}, {"makes": "green", "count": 1, "every": 1},
		{"makes": "green", "count": 1, "every": 2, "star": 2}]},
	"hatch_gold": {"name": "金巢", "color": Color(0.96, 0.74, 0.18), "levels": [
		{"makes": "gold", "count": 1, "every": 3}, {"makes": "gold", "count": 1, "every": 2},
		{"makes": "gold", "count": 1, "every": 3, "star": 2}]},
	"hatch_white": {"name": "白巢", "color": Color(0.93, 0.93, 0.9), "levels": [
		{"makes": "white", "count": 1, "every": 3}, {"makes": "white", "count": 1, "every": 2},
		{"makes": "white", "count": 1, "every": 1}]},
	"pen": {"name": "围栏", "color": Color(0.55, 0.42, 0.26), "levels": [{"room": 1}, {"room": 2}, {"room": 3}]},
	"farm": {"name": "粮仓", "color": Color(0.85, 0.68, 0.36), "levels": [{"income": 1}, {"income": 2}, {"income": 3}]},
	"nursery": {"name": "暖巢", "color": Color(0.95, 0.55, 0.45), "levels": [{"hurry": 1}, {"hurry": 1, "room": 1}, {"hurry": 2, "room": 1}]},
	"gym": {"name": "训练场", "color": Color(0.45, 0.35, 0.6), "levels": [{"drill": 1}, {"drill": 2}, {"drill": 3}]},
	"wall": {"name": "城墙", "color": Color(0.5, 0.5, 0.48), "levels": [{"wall": 5, "block": 1}, {"wall": 8, "block": 2}, {"wall": 12, "block": 3}]},
}

## Cards. type "build" goes in an empty plot; "buff" makes the coming battle (or a unit) stronger; "upgrade"
## raises a building or a unit. target: "tile", "building", "producer", "unit", or "none" (played at once).
## rarity: 0 common, 1 uncommon, 2 rare. up: what the card's own upgrade (+) changes.
const CARDS := {
	"b_red": {"type": "build", "name": "造红巢", "cost": 3, "rarity": 0, "builds": "hatch_red"},
	"b_blue": {"type": "build", "name": "造蓝巢", "cost": 3, "rarity": 0, "builds": "hatch_blue"},
	"b_green": {"type": "build", "name": "造绿巢", "cost": 4, "rarity": 1, "builds": "hatch_green"},
	"b_gold": {"type": "build", "name": "造金巢", "cost": 6, "rarity": 2, "builds": "hatch_gold"},
	"b_white": {"type": "build", "name": "造白巢", "cost": 4, "rarity": 1, "builds": "hatch_white"},
	"b_pen": {"type": "build", "name": "造围栏", "cost": 2, "rarity": 0, "builds": "pen"},
	"b_farm": {"type": "build", "name": "造粮仓", "cost": 2, "rarity": 0, "builds": "farm"},
	"b_nursery": {"type": "build", "name": "造暖巢", "cost": 3, "rarity": 1, "builds": "nursery"},
	"b_gym": {"type": "build", "name": "造训练场", "cost": 3, "rarity": 1, "builds": "gym"},
	"b_wall": {"type": "build", "name": "造城墙", "cost": 3, "rarity": 1, "builds": "wall"},
	"rally": {"type": "buff", "name": "鼓舞", "cost": 1, "rarity": 0, "target": "none", "battle": {"atk": 2}, "up": {"battle": {"atk": 3}}},
	"plate": {"type": "buff", "name": "铁皮", "cost": 2, "rarity": 1, "target": "none", "battle": {"armor": 1}, "up": {"battle": {"armor": 2}}},
	"haste": {"type": "buff", "name": "急行", "cost": 1, "rarity": 1, "target": "none", "battle": {"haste": 30}, "up": {"battle": {"haste": 50}}},
	"mend": {"type": "buff", "name": "修补", "cost": 2, "rarity": 0, "target": "none", "mend": 5, "up": {"mend": 8}},
	"train": {"type": "buff", "name": "强化", "cost": 2, "rarity": 0, "target": "unit", "unit": {"hp": 4, "atk": 1}, "up": {"unit": {"hp": 6, "atk": 2}}},
	"expand": {"type": "upgrade", "name": "扩建", "cost": 3, "rarity": 0, "target": "building", "level_up": 1},
	"star": {"type": "upgrade", "name": "升星", "cost": 4, "rarity": 1, "target": "unit", "star_up": 1},
	"overtime": {"type": "upgrade", "name": "加班", "cost": 2, "rarity": 0, "target": "producer", "make_now": 1, "up": {"make_now": 2}},
}

const TYPES := {"build": "造建筑", "buff": "增益", "upgrade": "升级"}
const START_DECK := ["b_red", "b_blue", "b_pen", "b_farm", "rally", "rally", "expand", "overtime", "train"]
const FIRST := {"pos": Vector2i(2, 1), "kind": "hatch_red"}  # the homeland starts with one producer

## The most strength a player can have in the yard at each round of the run (all the levels one after another):
## no one coming, every battle won, everything spent on growing -- the best of ten runs, measured by
## tools/sim_runs.gd (limit). Measure again after changing what can be built or made.
const LIMIT := [21, 39, 47, 65, 89, 98, 126, 132, 150, 190, 227, 263, 308, 320, 324, 355, 397, 411, 411, 427, 475,
	486, 523, 542, 606, 641, 666, 666, 670, 677]

## The levels of a run: `rounds` battles each. Each wave is `share` of LIMIT strong (the harder the level, the nearer
## the most a player can have); `power` times as strong one by one; `mix`: which kinds come, [kind, share, from which
## round]; `bosses` come in the last round. The homeland and the deck carry on from one level to the next.
const LEVELS := [
	{"name": "第一关", "rounds": 10, "power": 1.0, "share": 0.45, "bosses": 1,
		"mix": [["grey", 0.6, 1], ["purple", 0.25, 2], ["black", 0.15, 5]]},
	{"name": "第二关", "rounds": 10, "power": 1.3, "share": 0.6, "bosses": 1,
		"mix": [["grey", 0.45, 1], ["purple", 0.25, 1], ["black", 0.3, 1]]},
	{"name": "第三关", "rounds": 10, "power": 1.6, "share": 0.75, "bosses": 2,
		"mix": [["grey", 0.35, 1], ["purple", 0.25, 1], ["black", 0.4, 1]]},
]


## A card's numbers, with its upgrade worked in when it has one.
static func card(ci: Dictionary) -> Dictionary:
	var c: Dictionary = CARDS[ci.id].duplicate(true)
	c.id = ci.id
	if not c.has("target"):
		c.target = "tile" if c.type == "build" else "none"
	if ci.get("up", false) and c.has("up"):
		c.merge(c.up, true)
		c.name = c.name + "+"
	elif ci.get("up", false):
		c.name = c.name + "+"
		c.cost = maxi(0, int(c.cost) - 1)
	return c


## What a building does at a level, as one line.
static func building_text(kind: String, level: int) -> String:
	var b: Dictionary = BUILDINGS[kind]
	var l: Dictionary = b.levels[clampi(level, 1, 3) - 1]
	var parts: Array = []
	if l.has("makes"):
		var star := (" %d 星" % int(l.star)) if l.has("star") else ""
		parts.append("每 %d 轮生产 %d 个%s%s" % [l.every, l.count, star, UNITS[l.makes].name] if int(l.every) > 1
			else "每轮生产 %d 个%s%s" % [l.count, star, UNITS[l.makes].name])
	if l.has("room"):
		parts.append("多养 %d 个" % l.room)
	if l.has("income"):
		parts.append("每轮多 %d 点力气" % l.income)
	if l.has("hurry"):
		parts.append("旁边的巢早 %d 轮生产" % l.hurry)
	if l.has("drill"):
		parts.append("旁边的巢生产的兵攻击 +%d" % l.drill)
	if l.has("wall"):
		parts.append("家园血 +%d，输一仗少掉 %d" % [l.wall, l.block])
	return "，".join(parts)


## What a card does, in the player's words.
static func text(c: Dictionary) -> String:
	if c.type == "build":
		return BUILDINGS[c.builds].name + "：" + building_text(c.builds, 1)
	var parts: Array = []
	if c.has("battle"):
		var b: Dictionary = c.battle
		if b.has("atk"):
			parts.append("这一仗所有兵攻击 +%d" % b.atk)
		if b.has("armor"):
			parts.append("这一仗所有兵护甲 +%d" % b.armor)
		if b.has("haste"):
			parts.append("这一仗所有兵快 %d%%" % b.haste)
	if c.has("mend"):
		parts.append("家园回 %d 血" % c.mend)
	if c.has("unit"):
		parts.append("一个兵永久 血 +%d，攻击 +%d" % [c.unit.hp, c.unit.atk])
	if c.has("level_up"):
		parts.append("一座建筑升一级（最多 3 级）")
	if c.has("star_up"):
		parts.append("一个兵升一星（最多 3 星）")
	if c.has("make_now"):
		parts.append("一个巢马上多生产 %d 次" % c.make_now)
	return "，".join(parts) + "。"


## A unit's numbers, at its stars and with what it has been given for good.
static func stats(side: String, kind: String, star := 1, bonus_hp := 0, bonus_atk := 0, power := 1.0) -> Dictionary:
	var base: Dictionary = (UNITS if side == "ours" else ENEMIES)[kind]
	var k: float = STAR[clampi(star, 1, 3) - 1] * (power if side == "theirs" else 1.0)
	var s := base.duplicate()
	s.hp = roundi(base.hp * k) + bonus_hp
	s.atk = roundi(base.atk * k) + bonus_atk
	s.armor = int(base.get("armor", 0))
	s.splash = float(base.get("splash", 0.0))
	s.heal = roundi(base.get("heal", 0) * k)
	s.size = base.size * (1.0 + 0.15 * (star - 1))
	return s


## A fighter's strength, from its numbers (stats(), or a Fight fighter with `max` for its full health).
static func strength(s: Dictionary) -> float:
	var hp := float(s.get("max", s.hp))
	var armor := float(s.get("armor", 0))
	var take := hp * TYPICAL_HIT / maxf(1.0, TYPICAL_HIT - armor) * (1.0 + REACH_WORTH if float(s.range) >= 3.0 else 1.0)
	var deal := float(s.atk) / float(s.every) * (1.0 + SPLASH_WORTH * float(s.get("splash", 0.0))) 		+ HEAL_WORTH * float(s.get("heal", 0)) / float(s.every)
	return STRENGTH_K * sqrt(take * deal)


static func unit_strength(side: String, kind: String, star := 1, bonus_hp := 0, bonus_atk := 0, power := 1.0) -> float:
	return strength(stats(side, kind, star, bonus_hp, bonus_atk, power))


## Who comes in round `r` (1-based) of `level`: a list of kinds, as strong all told as the level's share of LIMIT --
## the bosses in the last round, then each kind of the mix its share, the strongest first, the weakest making up
## what is left.
static func wave(level: int, r: int) -> Array:
	var lv: Dictionary = LEVELS[level]
	var g := r
	for i in level:
		g += int(LEVELS[i].rounds)
	var power := float(lv.power)
	var budget := float(LIMIT[clampi(g, 1, LIMIT.size()) - 1]) * float(lv.share)
	var out: Array = []
	if r >= int(lv.rounds):
		for i in int(lv.get("bosses", 0)):
			out.append("boss")
			budget -= unit_strength("theirs", "boss", 1, 0, 0, power)
	var mix: Array = lv.mix.filter(func(m: Array) -> bool: return r >= int(m[2]))
	mix.sort_custom(func(a: Array, b: Array) -> bool:
		return unit_strength("theirs", a[0]) > unit_strength("theirs", b[0]))
	var shares := 0.0
	for m in mix:
		shares += float(m[1])
	var left := budget
	for m in mix:
		var one := unit_strength("theirs", m[0], 1, 0, 0, power)
		var n := floori(maxf(0.0, budget) * float(m[1]) / shares / one)
		for i in n:
			out.append(m[0])
		left -= n * one
	var weakest: String = mix[-1][0]
	var w := unit_strength("theirs", weakest, 1, 0, 0, power)
	while left >= w * 0.5:
		out.append(weakest)
		left -= w
	if out.is_empty():
		out.append(weakest)
	return out
