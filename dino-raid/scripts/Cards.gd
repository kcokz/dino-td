class_name Cards
## The cards (GAME-DESIGN 5): eggs to plant, buildings to put up beside them, and help let loose on the
## field. None costs anything -- every so often three are offered and the player keeps one. What a strong
## card costs is what it needs: ground, time, the right building beside it, quiet. Everything the player does
## is a card -- even scattering meat or making a noise: nothing is always to hand.
##
##   type   "egg": goes in an empty plot or an empty nest. A clutch of `eggs` hatching one at a time, each
##          in `hatch` seconds when the eggs have all they `need`, twice as long for each thing missing.
##          size: an egg's length, metres; nest: the scrape's radius; shell: its colour.
##          "building": goes in an empty plot and works on the eight plots round it.
##          "help": let loose anywhere on the field, and gone.

const ALL := {
	"egg_coelophysis": {"type": "egg", "name": "腔骨龙蛋", "species": "coelophysis", "eggs": 6, "hatch": 5.0,
		"needs": [], "size": 0.22, "nest": 1.1, "shell": Color(0.88, 0.84, 0.72),
		"text": "一窝 6 个\n孵得快"},
	"egg_triceratops": {"type": "egg", "name": "三角龙蛋", "species": "triceratops", "eggs": 3, "hatch": 20.0,
		"needs": ["ferns"], "size": 0.36, "nest": 1.3, "shell": Color(0.8, 0.79, 0.74),
		"text": "一窝 3 个\n要挨着蕨类林"},
	"egg_tyrannosaurus": {"type": "egg", "name": "霸王龙蛋", "species": "tyrannosaurus", "eggs": 1, "hatch": 75.0,
		"needs": ["carrion", "quiet"], "size": 0.5, "nest": 1.2, "shell": Color(0.56, 0.47, 0.39),
		"text": "一窝 1 个，孵得最慢\n要挨着腐肉坑，要安静"},
	"ferns": {"type": "building", "name": "蕨类林", "text": "挨着它的\n三角龙蛋孵得好"},
	"carrion": {"type": "building", "name": "腐肉坑", "text": "挨着它的\n霸王龙蛋孵得好"},
	"compost": {"type": "building", "name": "堆肥草堆", "text": "草烂了会发热\n挨着的蛋孵得快"},
	"scent": {"type": "help", "name": "撒肉味", "text": "肉食龙闻到\n就扑过去"},
	"noise": {"type": "help", "name": "弄出响声", "text": "草食龙往反方向跑\n肉食龙过来看"},
	"blood": {"type": "help", "name": "血腥味", "text": "附近的肉食龙\n发狂一会儿"},
	"call": {"type": "help", "name": "求偶叫声", "text": "把草食龙\n引过来"},
	"ash": {"type": "help", "name": "火山灰", "text": "机器人看不清\n老打偏"},
}

## What an egg may need, as the player reads it.
const NEEDS := {"ferns": "蕨类林", "carrion": "腐肉坑", "quiet": "安静"}

## The colour round each kind of card.
const EDGE := {"egg": Color(0.92, 0.7, 0.38), "building": Color(0.5, 0.8, 0.42), "help": Color(0.62, 0.68, 1.0)}


## How many times as likely as the rest a card is to be offered: the meat and the noise are what steers.
const OFTEN := {"scent": 2, "noise": 2}


## Three different cards, at random.
static func offer() -> Array:
	var pool: Array = []
	for id in ALL:
		for i in OFTEN.get(id, 1):
			pool.append(id)
	pool.shuffle()
	var out: Array = []
	for id in pool:
		if not id in out:
			out.append(id)
			if out.size() == 3:
				break
	return out
