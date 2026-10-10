class_name Rules
## The numbers of a battle (GAME-DESIGN 9): the board, who is who, the cards, the levels and their waves.
## Everything is whole tiles, turns and points: the battle is worked out exactly (Sim), so the player can be
## shown beforehand what a turn will do.
##
## The board is COLS tiles across and ROWS deep: row 0 is our end, nearest the camera, with the sand where eggs
## are laid; the last row is the robots' end, with their time machine. Distances are counted the way a king
## moves in chess -- a diagonal step is one step.

const COLS := 5
const ROWS := 8
const NEST_ROWS := 2              # rows 0-1: sand -- eggs go here
const OUR_HALF := 4               # rows 0-3: buildings go here
const MACHINE_AT := Vector2i(2, 7)
const FIRST_NEST := Vector2i(2, 0)
const SPAWN := [Vector2i(1, 7), Vector2i(3, 7), Vector2i(0, 7), Vector2i(4, 7),
	Vector2i(2, 6), Vector2i(1, 6), Vector2i(3, 6), Vector2i(0, 6), Vector2i(4, 6)]

const HAND := 5                   # cards drawn each turn
const ENERGY_MAX := 10
const ENERGY_TURN := 4            # energy each turn; what is not spent is kept, up to the most
const NEST_HP := 10
const BUILDING_HP := 8
const SCENT_SMELL := 6            # hunters smell meat this far off
const NOISE_HEARD := 4            # hunters come this far to look into a noise
const STAMPEDE := 4               # tiles a frightened plant-eater runs
const TRAMPLE := 5                # to each one it runs into
const QUIET := 3                  # a tyrannosaur's eggs keep still with a robot this near
const FED := 2                    # a tyrannosaur this near a carrion pit is fed, and leaves its own kind be
const LEAD_HP := 1.25             # the first out of a clutch is the biggest

## Dinosaurs. A pack is one piece of `bodies` animals; hp and bite are each animal's.
const DINOS := {
	"coelophysis": {"name": "腔骨龙", "latin": "Coelophysis", "diet": "meat", "small": true,
		"hp": 4, "bite": 2, "move": 3, "sight": 4,
		"rule": "冲向最近的机器人去咬。一群一起咬，死一只少咬一口。"},
	"triceratops": {"name": "三角龙", "latin": "Triceratops", "diet": "plant",
		"hp": 24, "bite": 6, "move": 2, "sight": 1,
		"rule": "不惹它就吃草。机器人到跟前就顶；挨了打，就去顶打它的那个。"},
	"tyrannosaurus": {"name": "霸王龙", "latin": "Tyrannosaurus", "diet": "meat", "apex": true,
		"hp": 30, "bite": 12, "move": 2, "sight": 4,
		"rule": "咬最近的机器人。饿了，又没有机器人可咬，就吃旁边的小恐龙。"},
}

const ROBOTS := {
	"walker": {"name": "小兵", "hp": 12, "shot": 4, "range": 3, "move": 2,
		"rule": "走向最近的蛋窝；3 格内有恐龙，就停下来打最近的。"},
	"turret": {"name": "炮塔", "hp": 16, "shot": 4, "range": 4, "move": 0,
		"rule": "不动。打 4 格内最近的恐龙。"},
	"machine": {"name": "时光机", "hp": 40, "shot": 0, "range": 0, "move": 0,
		"rule": "机器人从这里出来。打掉它就赢了。"},
}

## Cards. rarity: 0 common, 1 uncommon, 2 rare (seldom offered). up: what the upgrade (+) changes.
const CARDS := {
	"egg_coelophysis": {"type": "egg", "name": "腔骨龙蛋", "cost": 2, "rarity": 0, "species": "coelophysis",
		"eggs": 1, "pack": 4, "hatch": 1, "needs": [], "up": {"pack": 6}},
	"egg_triceratops": {"type": "egg", "name": "三角龙蛋", "cost": 4, "rarity": 1, "species": "triceratops",
		"eggs": 2, "pack": 1, "hatch": 2, "needs": ["ferns"], "up": {"eggs": 3}},
	"egg_tyrannosaurus": {"type": "egg", "name": "霸王龙蛋", "cost": 6, "rarity": 2, "species": "tyrannosaurus",
		"eggs": 1, "pack": 1, "hatch": 3, "needs": ["carrion", "quiet"], "up": {"needs": ["carrion"]}},
	"ferns": {"type": "building", "name": "蕨类林", "cost": 2, "rarity": 0, "heal": 3, "up": {"heal": 6}},
	"carrion": {"type": "building", "name": "腐肉坑", "cost": 2, "rarity": 1, "heal": 2, "up": {"heal": 4}},
	"compost": {"type": "building", "name": "堆肥草堆", "cost": 3, "rarity": 1, "warm": 1, "up": {"warm": 2}},
	"scent": {"type": "help", "name": "撒肉味", "cost": 1, "rarity": 0, "turns": 2, "up": {"turns": 3}},
	"noise": {"type": "help", "name": "弄出响声", "cost": 1, "rarity": 0, "reach": 2, "up": {"reach": 3}},
	"blood": {"type": "help", "name": "血腥味", "cost": 2, "rarity": 1, "reach": 2, "turns": 2, "up": {"turns": 3}},
	"call": {"type": "help", "name": "求偶叫声", "cost": 1, "rarity": 0, "reach": 6, "up": {"reach": 9}},
	"ash": {"type": "help", "name": "火山灰", "cost": 3, "rarity": 1, "turns": 2, "up": {"turns": 3}},
	"quicken": {"type": "help", "name": "催孵", "cost": 1, "rarity": 0, "speed": 1, "up": {"speed": 2}},
}

const NEEDS := {"ferns": "蕨类林", "carrion": "腐肉坑"}
const TYPES := {"egg": "蛋", "building": "建筑", "help": "辅助"}

const START_DECK := ["egg_coelophysis", "egg_coelophysis", "egg_coelophysis", "egg_triceratops", "ferns",
	"scent", "scent", "noise"]

## The levels of a run. waves: turn -> who comes out of the time machine at the start of that turn; after the
## last, `then` every `every` turns, one more walker every second time.
const LEVELS := [
	{"name": "河边沙地", "machine": 30, "turrets": [], "rocks": [Vector2i(0, 4), Vector2i(4, 3)],
		"waves": {2: ["walker", "walker"], 4: ["walker", "walker"], 6: ["walker", "walker", "walker"]},
		"every": 2, "then": 3},
	{"name": "干旱平地", "machine": 40, "turrets": [Vector2i(2, 6)], "rocks": [Vector2i(1, 4), Vector2i(3, 2)],
		"waves": {2: ["walker", "walker"], 4: ["walker", "walker", "walker"], 6: ["walker", "walker", "walker"]},
		"every": 2, "then": 3},
	{"name": "峡谷", "machine": 50, "turrets": [Vector2i(1, 6), Vector2i(3, 6)],
		"rocks": [Vector2i(0, 3), Vector2i(4, 4), Vector2i(2, 4)],
		"waves": {2: ["walker", "walker"], 3: ["walker"], 5: ["walker", "walker", "walker"],
			7: ["walker", "walker", "walker"]},
		"every": 2, "then": 4},
]


## A card's numbers, with its upgrade worked in when it has one.
static func card(ci: Dictionary) -> Dictionary:
	var c: Dictionary = CARDS[ci.id].duplicate(true)
	c.id = ci.id
	if ci.get("up", false):
		c.merge(c.up, true)
		c.name = c.name + "+"
	return c


## Who comes out of the time machine at the start of `turn`.
static func wave(level: int, turn: int) -> Array:
	var lv: Dictionary = LEVELS[level]
	if lv.waves.has(turn):
		return lv.waves[turn]
	var last: int = lv.waves.keys().max()
	if turn <= last or (turn - last) % int(lv.every) != 0:
		return []
	var n: int = lv.then + (turn - last) / (lv.every * 2)
	var out := []
	for i in n:
		out.append("walker")
	return out


## What a card does, in the player's words, with its numbers (upgraded ones too).
static func text(c: Dictionary) -> String:
	match c.id:
		"egg_coelophysis":
			return "一窝 %d 只，%d 回合孵出。" % [c.pack, c.hatch]
		"egg_triceratops":
			return "%d 个蛋，每 %d 回合孵出 1 只。要挨着蕨类林，不然慢一倍。" % [c.eggs, c.hatch]
		"egg_tyrannosaurus":
			var t := "1 个蛋，%d 回合孵出。要挨着腐肉坑，不然慢一倍。" % c.hatch
			return t + ("3 格内有机器人就不孵。" if "quiet" in c.needs else "")
		"ferns":
			return "挨着的草食龙每回合回 %d 血。三角龙蛋要挨着它。" % c.heal
		"carrion":
			return "%d 格内的霸王龙吃饱了，不吃自家小龙。挨着的肉食龙每回合回 %d 血。" % [FED, c.heal]
		"compost":
			return "挨着的蛋早 %d 回合孵出。" % c.warm
		"scent":
			return "肉味留 %d 回合。%d 格内没看见机器人的肉食龙，都往这儿走。" % [c.turns, SCENT_SMELL]
		"noise":
			return "%d 格内的草食龙往反方向冲 %d 格，撞上谁就踩谁 %d。肉食龙会过来看。" % [c.reach, STAMPEDE, TRAMPLE]
		"blood":
			return "%d 格内的肉食龙发狂 %d 回合：多走 2 格，咬一口算两口。" % [c.reach, c.turns]
		"call":
			return "%d 格内的草食龙，这回合都往这儿走。" % c.reach
		"ash":
			return "3×3 一团灰，留 %d 回合。里面的机器人只能打旁边一格。" % c.turns
		"quicken":
			return "一窝蛋早 %d 回合孵出。" % c.speed
	return ""
