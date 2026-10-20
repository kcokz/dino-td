class_name Content
## What there is to build, make and fight (GAME-DESIGN 14) -- coloured blocks standing in for the gene ark's
## creatures and the alien monsters. The systems (Home, Fight, Run) read only this: change what is here and they
## follow.

## Units the nests make -- for one round only. hp; atk, each hit; every: seconds between hits; range, metres; speed,
## metres a second; armor: taken off each hit it takes; splash: metres round its mark that also take half; heal: hit
## points it gives the most hurt friend in reach (instead of hitting); size: the block's edge; food: biomass it takes
## to make.
const UNITS := {
	"red": {"name": "红兵", "color": Color(0.9, 0.24, 0.2), "hp": 10, "atk": 3, "every": 1.0, "range": 1.4,
		"speed": 3.2, "size": 0.9, "food": 1, "role": "前排，打得快"},
	"blue": {"name": "蓝兵", "color": Color(0.24, 0.5, 0.96), "hp": 6, "atk": 2, "every": 1.0, "range": 6.0,
		"speed": 2.6, "size": 0.8, "food": 1, "role": "后排，远处打"},
	"green": {"name": "绿兵", "color": Color(0.3, 0.74, 0.3), "hp": 22, "atk": 2, "every": 1.3, "range": 1.4,
		"speed": 2.2, "size": 1.15, "armor": 1, "food": 1, "role": "前排，挡刀"},
	"gold": {"name": "金兵", "color": Color(0.96, 0.74, 0.18), "hp": 16, "atk": 6, "every": 1.5, "range": 1.6,
		"speed": 2.6, "size": 1.3, "splash": 1.8, "food": 2, "role": "重击，一打一片"},
	"white": {"name": "白兵", "color": Color(0.93, 0.93, 0.9), "hp": 8, "atk": 1, "every": 1.0, "range": 5.0,
		"speed": 2.4, "size": 0.8, "heal": 3, "food": 1, "role": "给受伤的同伴回血"},
}

## What comes for the homeland. harm: hit points the homeland loses for each one still standing when a battle is
## lost.
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

## A nest at each level: how many it makes a round, and how much stronger (hp and atk) they are.
const NEST := [{"count": 1, "quality": 1.0}, {"count": 2, "quality": 1.0}, {"count": 2, "quality": 1.25},
	{"count": 3, "quality": 1.25}, {"count": 3, "quality": 1.5}]
const LEVEL_MAX := 5
const CLUSTER := 2                # a nest with at least this many neighbours of its kind makes one more
const POOL_HP := 25               # % more hp for units of a nest beside each culture pool
const POWER_HP := -15             # % (less) hp for units of a nest beside each power station
const SAMPLER_POOL := 1           # genes more a round for each culture pool beside a sampler
const WALL_CHAIN := 1             # each wall blocks this much more for each wall beside it

## Buildings. A nest makes `nest` units. Each level may give: biomass, genes, energy: that much more each round;
## drill: units of nests beside it hit this much harder; slots: nests beside it can carry this many more affixes;
## brew: a potion every so many rounds; store, store_genes: that much more biomass and genes can be kept; wall: the
## homeland's hit points this much higher; block: each lost battle harms it this much less. cost: the card's.
const BUILDINGS := {
	"nest_red": {"name": "红巢", "color": Color(0.9, 0.24, 0.2), "nest": "red", "cost": 3},
	"nest_blue": {"name": "蓝巢", "color": Color(0.24, 0.5, 0.96), "nest": "blue", "cost": 3},
	"nest_green": {"name": "绿巢", "color": Color(0.3, 0.74, 0.3), "nest": "green", "cost": 4},
	"nest_gold": {"name": "金巢", "color": Color(0.96, 0.74, 0.18), "nest": "gold", "cost": 6},
	"nest_white": {"name": "白巢", "color": Color(0.93, 0.93, 0.9), "nest": "white", "cost": 4},
	"pool": {"name": "培养池", "color": Color(0.32, 0.72, 0.58), "cost": 2,
		"levels": [{"biomass": 3}, {"biomass": 4}, {"biomass": 5}, {"biomass": 6}, {"biomass": 8}]},
	"sampler": {"name": "采样站", "color": Color(0.72, 0.84, 0.95), "cost": 2,
		"levels": [{"genes": 1}, {"genes": 1}, {"genes": 2}, {"genes": 2}, {"genes": 3}]},
	"power": {"name": "能源站", "color": Color(0.96, 0.84, 0.3), "cost": 3,
		"levels": [{"energy": 1}, {"energy": 1}, {"energy": 2}, {"energy": 2}, {"energy": 3}]},
	"gym": {"name": "训练场", "color": Color(0.45, 0.35, 0.6), "cost": 3,
		"levels": [{"drill": 1}, {"drill": 1}, {"drill": 2}, {"drill": 2}, {"drill": 3}]},
	"stabilizer": {"name": "稳定器", "color": Color(0.55, 0.72, 0.95), "cost": 3,
		"levels": [{"slots": 1}, {"slots": 1}, {"slots": 2}, {"slots": 2}, {"slots": 2}]},
	"lab": {"name": "药剂房", "color": Color(0.95, 0.5, 0.7), "cost": 4,
		"levels": [{"brew": 3}, {"brew": 3}, {"brew": 2}, {"brew": 2}, {"brew": 1}]},
	"store": {"name": "仓库", "color": Color(0.62, 0.47, 0.32), "cost": 2,
		"levels": [{"store": 10, "store_genes": 5}, {"store": 15, "store_genes": 7}, {"store": 20, "store_genes": 10},
			{"store": 25, "store_genes": 12}, {"store": 30, "store_genes": 15}]},
	"wall": {"name": "防护墙", "color": Color(0.5, 0.5, 0.48), "cost": 3,
		"levels": [{"wall": 5, "block": 1}, {"wall": 8, "block": 1}, {"wall": 12, "block": 2}, {"wall": 16, "block": 2},
			{"wall": 20, "block": 3}]},
}

## Gene affixes, stuck on a nest: every unit it makes carries them.
const AFFIXES := {
	"shell": {"name": "甲壳", "color": Color(0.35, 0.38, 0.42), "armor": 1, "says": "护甲 +1"},
	"blade": {"name": "刀锋", "color": Color(0.85, 0.88, 0.92), "atk": 2, "says": "攻击 +2"},
	"acid": {"name": "酸液腺", "color": Color(0.55, 0.95, 0.25), "range": 5.0, "says": "变成远程，够得着 5 米"},
	"wings": {"name": "翅膀", "color": Color(0.85, 0.75, 0.55), "dive": true, "says": "会飞，越过前排去打后排"},
	"plasma": {"name": "电浆囊", "color": Color(0.3, 0.9, 1.0), "splash": 1.5, "says": "一打一片（旁边 1.5 米挨一半）"},
}

## Potions: one battle's help, kept apart from the deck, at most POTION_SLOTS at once; used whenever, for nothing.
const POTIONS := {
	"rage": {"name": "狂暴激素", "color": Color(1.0, 0.42, 0.22), "battle": {"atk": 2}, "says": "这一仗所有兵攻击 +2"},
	"harden": {"name": "硬化剂", "color": Color(0.6, 0.68, 0.8), "battle": {"armor": 1}, "says": "这一仗所有兵护甲 +1"},
	"breed": {"name": "催产素", "color": Color(1.0, 0.55, 0.8), "breed": 1, "says": "这一轮每个巢多孵 1 只，不吃生物质"},
	"gel": {"name": "修复凝胶", "color": Color(0.45, 0.95, 0.5), "mend": 6, "says": "家园回 6 血"},
	"rush": {"name": "加速剂", "color": Color(1.0, 0.9, 0.3), "battle": {"haste": 30}, "says": "这一仗所有兵快 30%"},
}
const POTION_SLOTS := 3

## Strength (战力): how strong a fighter is, as one number the player never sees -- for balancing. The square root
## of what it can take times what it deals a second, so that a side's strength is the sum of its fighters' and two
## sides of equal strength have an even fight (tools/strength_check.gd checks this). A grey is 10.
const STRENGTH_K := 1.9245              # 10 / sqrt(9 hp * 3 a second)
const TYPICAL_HIT := 4.0                # armour is worth what it takes off a hit this hard
const REACH_WORTH := 0.3                # standing back (a reach of 3 m or more): it takes this much more
const DIVE_WORTH := 0.15                # flying over the front: it takes this much more
const SPLASH_WORTH := 1.0               # each metre of splash: it deals this much more
const HEAL_WORTH := 0.6                 # a hit point healed, against one dealt

## Cards. type "build" goes on an open plot (an empty one, or one with another building, which is pulled down for half
## its cost back); "raise" raises a building a level; "affix" goes on a nest with a free affix place; "gain" gives at
## once. genes, alien: what it costs besides energy. from: the level (0-based) from which it can be won. up: what the
## card's own upgrade (+) changes.
const CARDS := {
	"b_red": {"type": "build", "name": "造红巢", "cost": 3, "rarity": 0, "builds": "nest_red"},
	"b_blue": {"type": "build", "name": "造蓝巢", "cost": 3, "rarity": 0, "builds": "nest_blue"},
	"b_green": {"type": "build", "name": "造绿巢", "cost": 4, "rarity": 1, "builds": "nest_green"},
	"b_gold": {"type": "build", "name": "造金巢", "cost": 6, "rarity": 2, "builds": "nest_gold", "from": 2},
	"b_white": {"type": "build", "name": "造白巢", "cost": 4, "rarity": 1, "builds": "nest_white"},
	"b_pool": {"type": "build", "name": "造培养池", "cost": 2, "rarity": 0, "builds": "pool"},
	"b_sampler": {"type": "build", "name": "造采样站", "cost": 2, "rarity": 0, "builds": "sampler"},
	"b_power": {"type": "build", "name": "造能源站", "cost": 3, "rarity": 1, "builds": "power"},
	"b_gym": {"type": "build", "name": "造训练场", "cost": 3, "rarity": 0, "builds": "gym"},
	"b_stab": {"type": "build", "name": "造稳定器", "cost": 3, "rarity": 1, "builds": "stabilizer", "from": 1},
	"b_lab": {"type": "build", "name": "造药剂房", "cost": 4, "rarity": 1, "builds": "lab", "from": 1},
	"b_store": {"type": "build", "name": "造仓库", "cost": 2, "rarity": 0, "builds": "store"},
	"b_wall": {"type": "build", "name": "造防护墙", "cost": 3, "rarity": 1, "builds": "wall"},
	"raise": {"type": "raise", "name": "扩建", "cost": 3, "rarity": 0, "up": {"cost": 2}},
	"a_shell": {"type": "affix", "name": "贴甲壳", "cost": 2, "genes": 2, "rarity": 0, "affix": "shell", "up": {"genes": 1}},
	"a_blade": {"type": "affix", "name": "贴刀锋", "cost": 2, "genes": 2, "rarity": 0, "affix": "blade", "from": 1,
		"up": {"genes": 1}},
	"a_acid": {"type": "affix", "name": "贴酸液腺", "cost": 3, "genes": 2, "alien": 1, "rarity": 1, "affix": "acid",
		"from": 1, "up": {"genes": 1}},
	"a_wings": {"type": "affix", "name": "贴翅膀", "cost": 3, "genes": 2, "alien": 1, "rarity": 2, "affix": "wings",
		"from": 2, "up": {"genes": 1}},
	"a_plasma": {"type": "affix", "name": "贴电浆囊", "cost": 3, "genes": 3, "alien": 1, "rarity": 2, "affix": "plasma",
		"from": 2, "up": {"genes": 2}},
	"sample": {"type": "gain", "name": "采样", "cost": 1, "rarity": 0, "gain_genes": 3, "up": {"gain_genes": 5}},
	"culture": {"type": "gain", "name": "培养", "cost": 1, "rarity": 0, "gain_biomass": 6, "up": {"gain_biomass": 10}},
}

const TYPES := {"build": "造建筑", "raise": "升级", "affix": "基因词条", "gain": "资源"}
const START_DECK := ["b_red", "b_blue", "b_pool", "b_sampler", "b_gym", "raise", "raise", "a_shell", "sample"]
## The homeland's first buildings, in its open rows (the south three).
const FIRST := [{"pos": Vector2i(2, 3), "kind": "nest_red"}, {"pos": Vector2i(3, 3), "kind": "pool"}]
const FIRST_STOCK := {"biomass": 3, "genes": 2, "potions": ["rage"]}

## The most strength a player's army can have at each round of the run (the levels one after another): no one coming,
## every battle won, everything spent on growing -- the best of ten runs, measured by tools/sim_runs.gd (limit).
## Measure again after changing what can be built or made.
const LIMIT := [24, 36, 48, 56, 64, 72, 86, 94, 99, 104, 128, 159, 159, 164, 164, 188, 188, 195, 203, 208, 220,
	232, 251, 264, 264, 264, 264, 275, 304, 319]
const BIG_ROUNDS := [5, 10]             # a big wave: BIG times as strong as the round would be
const BIG := 1.25

## The levels of a run: `rounds` battles each. Each wave is `share` of LIMIT strong (the harder the level, the nearer
## the most a player can have); `power` times as strong one by one; `mix`: which kinds come, [kind, share, from which
## round]; `bosses` come in the last round. The homeland and the deck carry on from one level to the next.
const LEVELS := [
	{"name": "第一关", "rounds": 10, "power": 1.0, "share": 0.45, "bosses": 1,
		"mix": [["grey", 0.6, 1], ["purple", 0.25, 2], ["black", 0.15, 5]]},
	{"name": "第二关", "rounds": 10, "power": 1.3, "share": 0.42, "bosses": 1,
		"mix": [["grey", 0.45, 1], ["purple", 0.25, 1], ["black", 0.3, 1]]},
	{"name": "第三关", "rounds": 10, "power": 1.6, "share": 0.7, "bosses": 2,
		"mix": [["grey", 0.35, 1], ["purple", 0.25, 1], ["black", 0.4, 1]]},
]


## A card's numbers, with its upgrade worked in when it has one.
static func card(ci: Dictionary) -> Dictionary:
	var c: Dictionary = CARDS[ci.id].duplicate(true)
	c.id = ci.id
	if not c.has("target"):
		c.target = {"build": "tile", "raise": "building", "affix": "nest"}.get(c.type, "none")
	if ci.get("up", false) and c.has("up"):
		c.merge(c.up, true)
		c.name = c.name + "+"
	elif ci.get("up", false):
		c.name = c.name + "+"
		c.cost = maxi(0, int(c.cost) - 1)
	return c


static func is_nest(kind: String) -> bool:
	return BUILDINGS[kind].has("nest")


## A building's numbers at a level: for a nest its count and quality, else its level's line.
static func level(kind: String, lv: int) -> Dictionary:
	var b: Dictionary = BUILDINGS[kind]
	if b.has("nest"):
		return NEST[clampi(lv, 1, LEVEL_MAX) - 1]
	return b.levels[clampi(lv, 1, LEVEL_MAX) - 1]


## What a building does at a level, for itself and for its neighbours (上下左右).
static func building_text(kind: String, lv: int) -> String:
	var b: Dictionary = BUILDINGS[kind]
	var l := level(kind, lv)
	if b.has("nest"):
		var u: Dictionary = UNITS[b.nest]
		var better := "，兵血和攻击 +%d%%" % roundi((float(l.quality) - 1.0) * 100.0) if float(l.quality) > 1.0 else ""
		return "每轮孵 %d 只%s%s（每只吃 %d 生物质）。旁边有 %d 个%s，多孵 1 只" % [l.count, u.name, better, u.food,
			CLUSTER, b.name]
	match kind:
		"pool":
			return "每轮产 %d 生物质。旁边的巢孵的兵血 +%d%%" % [l.biomass, POOL_HP]
		"sampler":
			return "每轮产 %d 基因。旁边每有一个培养池，再多 %d" % [l.genes, SAMPLER_POOL]
		"power":
			return "每轮多 %d 能量。可旁边的巢孵的兵血 %d%%（太吵）" % [l.energy, POWER_HP]
		"gym":
			return "旁边的巢孵的兵攻击 +%d" % l.drill
		"stabilizer":
			return "旁边的巢能多贴 %d 个词条" % l.slots
		"lab":
			return "每 %d 轮配一瓶药剂（药剂最多存 %d 瓶）" % [l.brew, POTION_SLOTS]
		"store":
			return "生物质能多存 %d，基因能多存 %d" % [l.store, l.store_genes]
		"wall":
			return "家园血 +%d，输一仗少掉 %d。旁边每有一段墙，再少掉 %d" % [l.wall, l.block, WALL_CHAIN]
	return ""


## What a card does, in the player's words.
static func text(c: Dictionary) -> String:
	match c.type:
		"build":
			return BUILDINGS[c.builds].name + "：" + building_text(c.builds, 1) + "。"
		"raise":
			return "一座建筑升一级（最多 %d 级）。" % LEVEL_MAX
		"affix":
			var a: Dictionary = AFFIXES[c.affix]
			return "给一个巢贴上%s：它孵的兵%s。" % [a.name, a.says]
		"gain":
			if c.has("gain_genes"):
				return "马上得到 %d 基因。" % c.gain_genes
			return "马上得到 %d 生物质。" % c.gain_biomass
	return ""


## One of our units' numbers, from what the nest gives it (Home.army's spec: kind, hp_mult, atk_mult, atk_bonus,
## armor, range, splash, dive) and this battle's buffs (atk, armor, haste).
static func unit_stats(spec: Dictionary, buffs := {}) -> Dictionary:
	var base: Dictionary = UNITS[spec.kind]
	var s := base.duplicate()
	s.hp = maxi(1, roundi(float(base.hp) * float(spec.get("hp_mult", 1.0))))
	s.atk = roundi(float(base.atk) * float(spec.get("atk_mult", 1.0))) + int(spec.get("atk_bonus", 0)) + int(buffs.get("atk", 0))
	s.armor = int(base.get("armor", 0)) + int(spec.get("armor", 0)) + int(buffs.get("armor", 0))
	s.range = maxf(float(base.range), float(spec.get("range", 0.0)))
	s.splash = float(base.get("splash", 0.0)) + float(spec.get("splash", 0.0))
	s.heal = roundi(float(base.get("heal", 0)) * float(spec.get("atk_mult", 1.0)))
	s.every = float(base.every) * 100.0 / (100.0 + float(buffs.get("haste", 0)))
	s.dive = bool(spec.get("dive", false))
	s.size = float(base.size) * (1.0 + 0.3 * (float(spec.get("atk_mult", 1.0)) - 1.0))
	s.harm = 0
	return s


static func enemy_stats(kind: String, power := 1.0) -> Dictionary:
	var base: Dictionary = ENEMIES[kind]
	var s := base.duplicate()
	s.hp = roundi(float(base.hp) * power)
	s.atk = roundi(float(base.atk) * power)
	s.armor = int(base.get("armor", 0))
	s.splash = float(base.get("splash", 0.0))
	s.heal = 0
	s.dive = false
	return s


## A fighter's strength, from its numbers (unit_stats, enemy_stats, or a Fight fighter with `max` for its full health).
static func strength(s: Dictionary) -> float:
	var hp := float(s.get("max", s.hp))
	var armor := float(s.get("armor", 0))
	var take := hp * TYPICAL_HIT / maxf(1.0, TYPICAL_HIT - armor) * (1.0 + REACH_WORTH if float(s.range) >= 3.0 else 1.0)
	if s.get("dive", false):
		take *= 1.0 + DIVE_WORTH
	var deal := float(s.atk) / float(s.every) * (1.0 + SPLASH_WORTH * float(s.get("splash", 0.0))) \
		+ HEAL_WORTH * float(s.get("heal", 0)) / float(s.every)
	return STRENGTH_K * sqrt(take * deal)


static func enemy_strength(kind: String, power := 1.0) -> float:
	return strength(enemy_stats(kind, power))


## Who comes in round `r` (1-based) of `level`: a list of kinds, as strong all told as the level's share of LIMIT (and
## more in a big round) -- the bosses in the last round, then each kind of the mix its share, the strongest first, the
## weakest making up what is left.
static func wave(level: int, r: int) -> Array:
	var lv: Dictionary = LEVELS[level]
	var g := r
	for i in level:
		g += int(LEVELS[i].rounds)
	var power := float(lv.power)
	var budget := float(LIMIT[clampi(g, 1, LIMIT.size()) - 1]) * float(lv.share) * (BIG if r in BIG_ROUNDS else 1.0)
	var out: Array = []
	if r >= int(lv.rounds):
		for i in int(lv.get("bosses", 0)):
			out.append("boss")
			budget -= enemy_strength("boss", power)
	var mix: Array = lv.mix.filter(func(m: Array) -> bool: return r >= int(m[2]))
	mix.sort_custom(func(a: Array, b: Array) -> bool: return enemy_strength(a[0]) > enemy_strength(b[0]))
	var shares := 0.0
	for m in mix:
		shares += float(m[1])
	var left := budget
	for m in mix:
		var one := enemy_strength(m[0], power)
		var n := floori(maxf(0.0, budget) * float(m[1]) / shares / one)
		for i in n:
			out.append(m[0])
		left -= n * one
	var weakest: String = mix[-1][0]
	var w := enemy_strength(weakest, power)
	while left >= w * 0.5:
		out.append(weakest)
		left -= w
	if out.is_empty():
		out.append(weakest)
	return out
