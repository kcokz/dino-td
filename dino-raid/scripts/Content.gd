class_name Content
## What there is to build, make and fight (GAME-DESIGN 19-22) -- coloured blocks standing in for the gene ark's creatures
## and the alien monsters of each place it lands. The systems (Home, Fight, Run) read only this: change what is here
## and they follow.

## Units the nests make -- for one round only. hp; atk, each hit; every: seconds between hits; range, metres; speed,
## metres a second; armor: taken off each hit it takes; splash: metres round its mark that also take half; heal: hit
## points it gives the most hurt friend in reach (instead of hitting); pierce: damage more each hit, armour or not;
## burst: damage to the other side round it (BURST_RADIUS) when it falls; dive: flies over the front for the back;
## shock: those it hits strike slower for a while (SLOW, SHOCK_TIME); cloud: a foe it fells bursts into poison, this
## much to each of its side round it (CLOUD_RADIUS), armour or not;
## size: the block's edge; food: the population (人口) it takes. One for each kind of nest (its gift, TRAITS, is the nest's);
## four are species a nest evolves into (RECIPES); the titan comes with the star of that name (STARS).
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
	"scav": {"name": "拾荒兽", "color": Color(0.78, 0.66, 0.42), "hp": 8, "atk": 2, "every": 1.0, "range": 4.0,
		"speed": 2.6, "size": 0.8, "food": 1, "role": "远处扔石头，打得弱"},
	"mutant": {"name": "变异兽", "color": Color(0.92, 0.45, 0.75), "hp": 9, "atk": 2, "every": 1.0, "range": 1.4,
		"speed": 2.8, "size": 0.85, "food": 1, "role": "底子弱，好贴词条"},
	"falcon": {"name": "猎鹰兽", "color": Color(0.95, 0.5, 0.2), "hp": 22, "atk": 7, "every": 0.9, "range": 1.4,
		"speed": 4.0, "size": 1.0, "dive": true, "food": 2, "role": "进化来的：飞过前排，专咬后排"},
	"thunder": {"name": "雷甲兽", "color": Color(0.35, 0.6, 0.95), "hp": 34, "atk": 4, "every": 1.3, "range": 1.6,
		"speed": 2.2, "size": 1.3, "armor": 1, "splash": 1.5, "shock": true, "food": 2,
		"role": "进化来的：又硬，又电一圈；被电到的出手变慢"},
	"miasma": {"name": "毒雾兽", "color": Color(0.55, 0.85, 0.3), "hp": 10, "atk": 3, "every": 1.0, "range": 5.0,
		"speed": 2.4, "size": 0.95, "pierce": 2, "splash": 1.2, "cloud": 3, "food": 2,
		"role": "进化来的：远处喷毒雾，不管护甲；打死的敌人爆一团毒雾"},
	"magma": {"name": "熔岩兽", "color": Color(0.92, 0.32, 0.12), "hp": 30, "atk": 8, "every": 1.3, "range": 1.6,
		"speed": 2.4, "size": 1.25, "burst": 8, "food": 2, "role": "进化来的：重击，倒下时炸一圈"},
	"titan": {"name": "巨兽", "color": Color(0.55, 0.42, 0.3), "hp": 70, "atk": 9, "every": 1.6, "range": 1.8,
		"speed": 2.0, "size": 2.0, "armor": 1, "splash": 1.5, "food": 0, "role": "泰坦带来的：又大又狠"},
}

## Gene recipes: a nest carrying both affixes hatches the species instead -- the two affixes go into it (its other
## affixes still count). Found by trying; a nest with one of a pair says what the other would make.
const RECIPES := [
	{"affixes": ["blade", "wings"], "makes": "falcon"},
	{"affixes": ["shell", "plasma"], "makes": "thunder"},
	{"affixes": ["acid", "poison"], "makes": "miasma"},
	{"affixes": ["flame", "blade"], "makes": "magma"},
]

## What comes for the homeland. harm: hit points the homeland loses for each one still standing when a battle is
## lost; split: what it breaks into when it falls (splits of them); burst: as for units.
const ENEMIES := {
	"grey": {"name": "灰怪", "color": Color(0.52, 0.52, 0.55), "hp": 9, "atk": 3, "every": 1.0, "range": 1.4,
		"speed": 2.8, "size": 0.9, "harm": 1},
	"purple": {"name": "紫怪", "color": Color(0.6, 0.3, 0.76), "hp": 6, "atk": 2, "every": 1.0, "range": 6.0,
		"speed": 2.4, "size": 0.8, "harm": 1},
	"black": {"name": "黑怪", "color": Color(0.16, 0.16, 0.18), "hp": 22, "atk": 3, "every": 1.3, "range": 1.4,
		"speed": 2.0, "size": 1.2, "armor": 1, "harm": 2},
	"spore": {"name": "孢子虫", "color": Color(0.55, 0.62, 0.3), "hp": 9, "atk": 2, "every": 1.0, "range": 1.4,
		"speed": 2.6, "size": 1.0, "harm": 1, "split": "mite", "splits": 2},
	"mite": {"name": "小螨", "color": Color(0.72, 0.78, 0.42), "hp": 3, "atk": 1, "every": 0.8, "range": 1.2,
		"speed": 3.4, "size": 0.55, "harm": 0},
	"boss_rain": {"name": "母虫", "color": Color(0.36, 0.48, 0.16), "hp": 50, "atk": 5, "every": 1.5, "range": 1.8,
		"speed": 1.8, "size": 2.3, "armor": 1, "splash": 1.5, "harm": 8, "split": "spore", "splits": 3},
	"beetle": {"name": "熔岩甲虫", "color": Color(0.38, 0.2, 0.12), "hp": 16, "atk": 3, "every": 1.3, "range": 1.4,
		"speed": 2.0, "size": 1.2, "armor": 2, "harm": 2, "burst": 4},
	"salamander": {"name": "火蜥", "color": Color(0.95, 0.45, 0.15), "hp": 7, "atk": 3, "every": 1.2, "range": 5.0,
		"speed": 2.4, "size": 0.9, "harm": 1},
	"boss_lava": {"name": "熔岩巨兽", "color": Color(0.5, 0.08, 0.05), "hp": 90, "atk": 8, "every": 1.8, "range": 2.2,
		"speed": 1.6, "size": 2.6, "armor": 2, "splash": 1.6, "harm": 12, "burst": 8},
	"mini_rain": {"name": "巨颚虫", "color": Color(0.45, 0.55, 0.22), "hp": 34, "atk": 4, "every": 1.2, "range": 1.6,
		"speed": 2.2, "size": 1.8, "armor": 1, "splash": 1.2, "harm": 5},
	"mini_lava": {"name": "熔岩守卫", "color": Color(0.62, 0.22, 0.1), "hp": 60, "atk": 6, "every": 1.5, "range": 1.8,
		"speed": 1.8, "size": 2.1, "armor": 2, "burst": 5, "harm": 8},
	"mini_rain2": {"name": "刺背虫", "color": Color(0.36, 0.46, 0.3), "hp": 56, "atk": 5, "every": 1.3, "range": 1.8,
		"speed": 2.0, "size": 2.0, "armor": 1, "splash": 1.4, "harm": 6},
	"mini_lava2": {"name": "火山巨蜥", "color": Color(0.8, 0.3, 0.12), "hp": 82, "atk": 7, "every": 1.5, "range": 2.0,
		"speed": 1.8, "size": 2.2, "armor": 2, "burst": 6, "harm": 9},
	# The swamp.
	"leech": {"name": "泥蛭", "color": Color(0.42, 0.34, 0.24), "hp": 13, "atk": 3, "every": 1.1, "range": 1.4,
		"speed": 2.4, "size": 1.0, "harm": 1},
	"moth": {"name": "毒蛾", "color": Color(0.66, 0.7, 0.32), "hp": 6, "atk": 2, "every": 1.0, "range": 5.0,
		"speed": 2.8, "size": 0.8, "pierce": 1, "harm": 1},
	"mini_bog": {"name": "沼泽巨蛙", "color": Color(0.38, 0.52, 0.28), "hp": 40, "atk": 5, "every": 1.3, "range": 2.0,
		"speed": 2.2, "size": 1.9, "splash": 1.3, "harm": 5},
	"mini_bog2": {"name": "毒囊蟾", "color": Color(0.55, 0.6, 0.2), "hp": 58, "atk": 5, "every": 1.4, "range": 1.8,
		"speed": 1.8, "size": 2.0, "armor": 1, "burst": 6, "harm": 6},
	"boss_bog": {"name": "沼母", "color": Color(0.3, 0.33, 0.18), "hp": 85, "atk": 7, "every": 1.6, "range": 2.0,
		"speed": 1.6, "size": 2.5, "armor": 1, "splash": 1.4, "harm": 11, "split": "leech", "splits": 3},
	# The ice fields.
	"frostfang": {"name": "霜牙", "color": Color(0.72, 0.8, 0.88), "hp": 9, "atk": 4, "every": 0.9, "range": 1.4,
		"speed": 3.6, "size": 0.9, "harm": 1},
	"shard": {"name": "冰晶怪", "color": Color(0.5, 0.72, 0.95), "hp": 8, "atk": 2, "every": 1.1, "range": 5.0,
		"speed": 2.2, "size": 0.9, "armor": 1, "harm": 1},
	"mini_ice": {"name": "冰甲巨虫", "color": Color(0.55, 0.66, 0.78), "hp": 46, "atk": 4, "every": 1.3, "range": 1.8,
		"speed": 1.8, "size": 2.0, "armor": 2, "harm": 5},
	"mini_ice2": {"name": "雪原狂兽", "color": Color(0.88, 0.9, 0.94), "hp": 62, "atk": 7, "every": 1.3, "range": 2.0,
		"speed": 2.6, "size": 2.1, "splash": 1.4, "harm": 7},
	"boss_ice": {"name": "冰巢女王", "color": Color(0.36, 0.5, 0.72), "hp": 100, "atk": 8, "every": 1.7, "range": 2.2,
		"speed": 1.6, "size": 2.6, "armor": 2, "splash": 1.6, "harm": 12},
	# The desert.
	"sandworm": {"name": "沙虫", "color": Color(0.74, 0.6, 0.38), "hp": 16, "atk": 3, "every": 1.3, "range": 1.4,
		"speed": 2.0, "size": 1.1, "armor": 1, "harm": 2},
	"scorpion": {"name": "蝎怪", "color": Color(0.55, 0.32, 0.18), "hp": 10, "atk": 3, "every": 1.1, "range": 1.6,
		"speed": 2.6, "size": 1.0, "pierce": 2, "harm": 1},
	"mini_sand": {"name": "巨沙虫", "color": Color(0.66, 0.52, 0.3), "hp": 50, "atk": 5, "every": 1.4, "range": 1.8,
		"speed": 1.8, "size": 2.0, "armor": 1, "harm": 5, "split": "sandworm", "splits": 2},
	"mini_sand2": {"name": "毒尾蝎王", "color": Color(0.45, 0.22, 0.12), "hp": 58, "atk": 6, "every": 1.2, "range": 2.0,
		"speed": 2.4, "size": 2.0, "pierce": 3, "harm": 7},
	"boss_sand": {"name": "沙暴巨兽", "color": Color(0.6, 0.45, 0.25), "hp": 95, "atk": 8, "every": 1.7, "range": 2.2,
		"speed": 1.6, "size": 2.6, "armor": 1, "splash": 1.8, "harm": 12},
	# The coast.
	"crab": {"name": "甲蟹", "color": Color(0.82, 0.38, 0.28), "hp": 16, "atk": 3, "every": 1.3, "range": 1.4,
		"speed": 1.8, "size": 1.1, "armor": 2, "harm": 2},
	"jelly": {"name": "水母怪", "color": Color(0.62, 0.55, 0.9), "hp": 7, "atk": 2, "every": 1.1, "range": 5.0,
		"speed": 2.2, "size": 0.9, "splash": 1.2, "harm": 1},
	"mini_sea": {"name": "巨钳蟹", "color": Color(0.72, 0.28, 0.2), "hp": 48, "atk": 5, "every": 1.4, "range": 1.8,
		"speed": 1.6, "size": 2.0, "armor": 3, "harm": 5},
	"mini_sea2": {"name": "海蛇怪", "color": Color(0.2, 0.5, 0.52), "hp": 60, "atk": 6, "every": 1.1, "range": 2.0,
		"speed": 3.0, "size": 2.0, "harm": 7},
	"boss_sea": {"name": "深海母巢", "color": Color(0.22, 0.3, 0.48), "hp": 100, "atk": 7, "every": 1.6, "range": 2.2,
		"speed": 1.4, "size": 2.6, "armor": 2, "splash": 1.4, "harm": 12, "split": "jelly", "splits": 4},
}
const BURST_RADIUS := 2.0

## The homeland (GAME-DESIGN 33): a map of plots of many shapes (LEVELS map), bare land between them, the top nearest
## the road out; the bottom middle plot open from the start, the others opened for gold (Home.open_plot) -- OPEN_BASE,
## and 1 more for each of its cells, and OPEN_MORE more for each opened before it in this place. Anything can be built
## on any open cell; what a building does for another, it does for those up, down, left or right of it, so that bare
## land between plots cuts it off. A nest's units fight in its column's lane, the close-fighting in front, those that
## reach far behind.
const OPEN_BASE := 2
const OPEN_MORE := 1
const START_PLOT := "S"           # the plot of a map open from the start
## The special ground put away for now (the player, 2026-10-23: "先只看摆放吧，简单点").
const TERRAIN_ON := false

## A nest makes one a round. Each raise (up to LEVEL_MAX) makes it elite once more: each of its units ELITE_HP times the
## hit points, ELITE_ATK times the attack, ELITE_SIZE times as big, taking no more of the population. More units come of
## more nests (the player, 2026-10-23: "精英和多个感觉没有选择的必要，因为你要增加人数就再造就行了").
const LEVEL_MAX := 3
const ELITE_HP := 1.5
const ELITE_ATK := 1.25
const ELITE_SIZE := 1.2
const CLUSTER := 1                # a red nest with at least this many red neighbours makes one more (its gift)
const SAMPLER_POOL := 1           # research points more a round for each culture or spore pool beside a sampler
const TREE_GENES := 1             # research points more a round for a sampler beside an old tree
const LAVA_GOLD := 1              # gold more a round for a mine or forge beside lava
const VAULT_MINE := 1             # the interest's cap more for each mine or forge beside a vault

## Each nest's gift (本事), the same for whatever it hatches -- most of them only where the nest stands: what is up,
## down, left or right of it (up: towards the road out), its column. Not tied to a school: what it does fits several ways of playing. when: where it
## works ("" anywhere); does: what it does there; says: both in short, for a card. The numbers they say are these:
const TRAITS := {
	"swarm": {"name": "成群", "when": "上下左右挨着红巢", "does": "多孵 1 只", "says": "挨着红巢，多孵 1 只"},
	"guard": {"name": "护住", "when": "下面挨着有巢", "does": "它的兵还站着时，怪打不着下面挨着的那个巢的兵",
		"says": "护住下面挨着的巢：它的兵还站着，怪就打不着那个巢的兵"},
	"cover": {"name": "掩护射击", "when": "上面挨着有巢", "does": "远程的兵射得远 2 米，每下多 1，不管护甲",
		"says": "上面挨着有巢挡着：射得更远，每下多 1"},
	"alone": {"name": "独当一面", "when": "上下左右都没有巢挨着", "does": "大一号，血和攻击 +30%",
		"says": "上下左右都没有巢：大一号，血和攻击 +30%"},
	"care": {"name": "照料", "when": "", "does": "只给同一列的兵回血，回得多一倍", "says": "只给同一列的兵回血，回得多一倍"},
	"scavenge": {"name": "拾荒", "when": "", "does": "打完仗还站着的，每只带回 2 金（输了也算）",
		"says": "打完仗还站着的，每只带回 2 金"},
	"mutant": {"name": "变异", "when": "", "does": "多 1 个词条位，好凑配方进化", "says": "多 1 个词条位"},
}
const COVER_RANGE := 2.0          # metres more for a unit reaching 3 m or more, under cover
const COVER_PIERCE := 1           # and damage more each hit, armour or not
const ALONE := 1.3                # alone: hit points and attack this many times
const ALONE_SIZE := 1.15          # and this much bigger
const CARE := 2                   # caring: heals this many times as much, only its own column
const SCAVENGE := 2               # gold each scavenger standing at a battle's end brings back
const MUTANT_SLOTS := 1           # affix places more on a mutant nest

## Buildings. A nest makes `nest` units and has a gift (`trait`, TRAITS). Each level of the others may give: biomass:
## the population (人口) more it feeds; genes (research points), gold: that much more each round; interest: the most
## interest this much more; and for the nests in its reach -- slots: this many more affixes; affix_off: each affix this
## much gold cheaper; per: every this many units in the army, +1 attack; elite: elite units' hit points and attack this
## % more; ranged: units reaching 3 m or more this much more damage each hit, armour or not (pierce); front: the
## close-fighting units this % more hit points. reach: where it works (REACH) -- a building that makes something, what its
## neighbours add to it; one that does something for nests, the nests it does it for. cost: its price, in gold. region:
## only found in that place (LEVELS). school: the way of playing it is for (SCHOOLS) -- a nest is for none, its gift for
## several.
const BUILDINGS := {
	"nest_red": {"name": "红巢", "color": Color(0.9, 0.24, 0.2), "nest": "red", "cost": 3, "trait": "swarm"},
	"nest_blue": {"name": "蓝巢", "color": Color(0.24, 0.5, 0.96), "nest": "blue", "cost": 3, "trait": "cover"},
	"nest_green": {"name": "绿巢", "color": Color(0.3, 0.74, 0.3), "nest": "green", "cost": 4, "trait": "guard"},
	"nest_gold": {"name": "金巢", "color": Color(0.96, 0.74, 0.18), "nest": "gold", "cost": 6, "trait": "alone"},
	"nest_white": {"name": "白巢", "color": Color(0.93, 0.93, 0.9), "nest": "white", "cost": 4, "trait": "care"},
	"nest_scav": {"name": "拾荒巢", "color": Color(0.78, 0.66, 0.42), "nest": "scav", "cost": 4, "trait": "scavenge"},
	"nest_mutant": {"name": "变异巢", "color": Color(0.92, 0.45, 0.75), "nest": "mutant", "cost": 3, "trait": "mutant"},
	"pool": {"name": "培养池", "color": Color(0.32, 0.72, 0.58), "cost": 2, "school": "horde", "reach": "near",
		"levels": [{"biomass": 3}, {"biomass": 5}, {"biomass": 8}]},
	"spore_pool": {"name": "孢子池", "color": Color(0.55, 0.7, 0.3), "cost": 3, "region": 0, "school": "horde", "reach": "near",
		"levels": [{"biomass": 5}, {"biomass": 7}, {"biomass": 10}]},
	"horde_totem": {"name": "兽群图腾", "color": Color(0.7, 0.3, 0.25), "cost": 4, "school": "horde", "reach": "near",
		"levels": [{"per": 6}, {"per": 5}, {"per": 4}]},
	"sampler": {"name": "采样站", "color": Color(0.72, 0.84, 0.95), "cost": 2, "school": "genes", "reach": "near",
		"levels": [{"genes": 1}, {"genes": 2}, {"genes": 3}]},
	"stabilizer": {"name": "稳定器", "color": Color(0.55, 0.72, 0.95), "cost": 3, "school": "genes", "reach": "near",
		"levels": [{"slots": 1}, {"slots": 1}, {"slots": 2}]},
	"gene_bank": {"name": "基因库", "color": Color(0.45, 0.85, 0.75), "cost": 3, "school": "genes", "reach": "near",
		"levels": [{"affix_off": 1}, {"affix_off": 2}, {"affix_off": 3}]},
	"mine": {"name": "矿场", "color": Color(0.96, 0.84, 0.3), "cost": 3, "school": "gold", "reach": "near",
		"levels": [{"gold": 1}, {"gold": 2}, {"gold": 3}]},
	"forge": {"name": "熔炉", "color": Color(0.75, 0.35, 0.15), "cost": 4, "region": 1, "school": "gold", "reach": "near",
		"levels": [{"gold": 2}, {"gold": 3}, {"gold": 5}]},
	"vault": {"name": "金库", "color": Color(0.85, 0.7, 0.25), "cost": 3, "school": "gold", "reach": "near",
		"levels": [{"interest": 1}, {"interest": 2}, {"interest": 3}]},
	"champion_hall": {"name": "冠军殿", "color": Color(0.8, 0.65, 0.95), "cost": 4, "school": "elite", "reach": "near",
		"levels": [{"elite": 15}, {"elite": 25}, {"elite": 40}]},
	"watchtower": {"name": "瞭望塔", "color": Color(0.5, 0.65, 0.85), "cost": 3, "school": "ranged", "reach": "near",
		"levels": [{"ranged": 1}, {"ranged": 2}, {"ranged": 3}]},
	"vanguard": {"name": "前锋营", "color": Color(0.7, 0.55, 0.4), "cost": 3, "school": "front", "reach": "near",
		"levels": [{"front": 30}, {"front": 60}, {"front": 100}]},
}
## Where a building works (its 作用范围, GAME-DESIGN 28; lit blue on the homeland while it is being placed or pointed
## at -- the player, 2026-10-22: "邻居互相加成,摆放的时候要有蓝色的hover来表示建筑作用范围"): "near", the four cells
## beside it, up, down, left and right -- every building's since the plots (GAME-DESIGN 33).
const REACH := {"near": "挨着的四块"}

## The ways of playing a run (流派), each with what it builds on and what it comes to late.
const SCHOOLS := {
	"gold": {"name": "攒钱流", "says": "金币多、利息多；矿场围着金库"},
	"genes": {"name": "进化流", "says": "词条位多、词条便宜；凑配方进化"},
	"horde": {"name": "兽群流", "says": "人口多，兵多；兵越多，图腾挨着的巢越狠"},
	"elite": {"name": "精英流", "says": "巢升级选精英；精英越来越强"},
	"ranged": {"name": "远程流", "says": "蓝兵、酸液腺；远程的兵越打越狠"},
	"front": {"name": "前锋流", "says": "前排放肉；前排的兵越来越厚"},
}

## Gene affixes, stuck on a nest: every unit it makes carries them -- the only way a unit itself grows stronger.
const AFFIXES := {
	"shell": {"name": "甲壳", "color": Color(0.35, 0.38, 0.42), "armor": 1, "says": "护甲 +1（每挨一下少掉 1）"},
	"blade": {"name": "刀锋", "color": Color(0.85, 0.88, 0.92), "atk": 2, "says": "攻击 +2"},
	"acid": {"name": "酸液腺", "color": Color(0.55, 0.95, 0.25), "range": 5.0, "says": "变成远程，够得着 5 米"},
	"wings": {"name": "翅膀", "color": Color(0.85, 0.75, 0.55), "dive": true, "says": "会飞，越过前排去打后排"},
	"plasma": {"name": "电浆囊", "color": Color(0.3, 0.9, 1.0), "splash": 1.5, "says": "一打一片（旁边 1.5 米挨一半）"},
	"poison": {"name": "毒刺", "color": Color(0.62, 0.92, 0.2), "pierce": 2, "says": "每下多 2 点伤害，不管护甲"},
	"flame": {"name": "火焰", "color": Color(1.0, 0.45, 0.1), "atk": 1, "splash": 1.2, "says": "攻击 +1，一打一片（旁边 1.2 米挨一半）"},
	"haste": {"name": "急速腺", "color": Color(1.0, 0.85, 0.25), "haste": 30, "says": "打得快 30%"},
	"hide": {"name": "厚皮", "color": Color(0.55, 0.45, 0.35), "hp": 40, "says": "血 +40%"},
	"horn": {"name": "冲锋角", "color": Color(0.95, 0.92, 0.8), "charge": true, "knock": 2.5,
		"says": "开战第一下打双倍，还把对方撞退 2.5 米、打断它这一下"},
	"devour": {"name": "吞噬", "color": Color(0.75, 0.2, 0.25), "devour": true,
		"says": "亲手咬死一个敌人：回 35% 血，这一仗攻击 +1、大一圈（最多 4 次）"},
	"roar": {"name": "低吼", "color": Color(0.6, 0.5, 0.75), "roar": true,
		"says": "第一下和以后每打 3 下吼一声：周围 2.2 米的敌人出手慢四成，2 秒"},
}
## What the affixes and species that act do (GAME-DESIGN 32), worked out in Fight with nothing random.
const DEVOUR_HEAL := 0.35         # a devourer felling a foe: this much of its hit points back...
const DEVOUR_MAX := 4             # ...attack +1, a tenth bigger, this many times at most
const ROAR_EVERY := 3             # a roarer roars at its first blow and every this many after
const ROAR_RADIUS := 2.2          # metres round it
const ROAR_TIME := 2.0            # seconds those it reaches strike slower
const SHOCK_TIME := 1.5           # seconds those a shocker hits strike slower
const SLOW := 1.4                 # slowed, a fighter's blows come this many times further apart
const CLOUD_RADIUS := 1.5         # metres round a foe felled by one that leaves a poison cloud

## What a fighter's numbers mean, in the player's words -- the codex's 属性 page (the player, 2026-10-23: "恐龙每个属性
## 需要明确，可以查看"). word: its mark; name; says: what it is; eg: an example (or ""). In the order a fighter's numbers
## are shown.
const STATS := {
	"hp": {"word": "血", "name": "血", "says": "能挨多少伤害，掉到 0 就倒下。", "eg": "厚皮：血 +40%，红兵 10 血变 14 血。"},
	"atk": {"word": "攻", "name": "攻击", "says": "每打一下的伤害。先减掉对方的护甲，最少也掉 1。", "eg": "刀锋：攻击 +2。"},
	"every": {"word": "快", "name": "几秒打一下", "says": "出手的快慢，越小越快。", "eg": "急速腺：打得快 30%，1 秒一下变 0.77 秒一下。"},
	"range": {"word": "远", "name": "够得着", "says": "离多远能打到。够得着 3 米以上的算远程，站在后面打。",
		"eg": "酸液腺：变成远程，够得着 5 米。"},
	"armor": {"word": "甲", "name": "护甲", "says": "每挨一下，伤害先减掉护甲这么多，最少还是掉 1。专挡一群小打击，挡不住重击。",
		"eg": "甲壳：护甲 +1。被每下打 2 的紫怪打，伤害减半；被每下打 8 的首领打，只少八分之一。"},
	"pierce": {"word": "穿", "name": "不管护甲", "says": "每下多打几点，这几点护甲挡不住。", "eg": "毒刺：每下多 2，不管护甲。"},
	"splash": {"word": "溅", "name": "一打一片", "says": "打中一个，它旁边这么多米里的敌人也挨一半伤害。", "eg": "电浆囊：旁边 1.5 米挨一半。"},
	"heal": {"word": "疗", "name": "回血", "says": "不打敌人，每下给够得着的、最受伤的同伴回这么多血。", "eg": "白兵。"},
	"burst": {"word": "爆", "name": "倒下时炸一圈", "says": "倒下时，周围 2 米的敌人挨这么多伤害。", "eg": "熔岩兽、熔岩甲虫。"},
	"dive": {"word": "飞", "name": "会飞", "says": "飞过前排，先咬后排。", "eg": "翅膀、猎鹰兽。"},
	"charge": {"word": "冲", "name": "冲锋", "says": "开战第一下打双倍。", "eg": "冲锋角。"},
	"knock": {"word": "撞", "name": "撞退", "says": "冲锋那一下把对方撞退几米，还打断它这一下。撞进后排的，正好挨一打一片。", "eg": "冲锋角：撞退 2.5 米。"},
	"devour": {"word": "吞", "name": "吞噬", "says": "亲手咬死一个敌人，回 35% 血，这一仗攻击 +1、大一圈，最多 4 次。专克一大群小怪。", "eg": "吞噬。"},
	"slow": {"word": "慢", "name": "出手变慢", "says": "被低吼吓到、被雷甲兽电到的敌人，一会儿里出手慢四成。", "eg": "低吼：周围 2.2 米，2 秒。"},
	"cloud": {"word": "雾", "name": "毒雾爆开", "says": "被它打死的敌人爆一团毒雾，旁边 1.5 米的敌人挨几点，不管护甲。", "eg": "毒雾兽：每团 3 点。"},
	"speed": {"word": "跑", "name": "跑多快", "says": "每秒跑几米。跑得快的先碰上敌人。", "eg": ""},
	"elite": {"word": "精", "name": "精英", "says": "巢升级就是变精英：血 ×1.5、攻击 ×1.25、大一号，不多占人口；一个巢最多变两次。", "eg": ""},
}

## The star dinosaurs (明星恐龙, GAME-DESIGN 24; the player, 2026-10-20: "把奇观，存货，遗物统一一下……可以加成的系统，但又
##有权衡的，互相还能配合的"): the park's own dinosaurs, which do not fight. Each its name, what it is (kind), what it eats
## (diet: "plant" or "meat" -- some count those of a diet), how rare (0 common, 1 uncommon, 2 rare, 3 legendary: these
## only after a boss), its price in gold, its appetite (biomass it eats each round, eat), and what it does: the keys Home
## reads, all of them only while it is fed --
##   keep: goods it keeps for the player (the stash); first_free: the first nest makes one more, eating nothing;
##   shelf: offers on the shelf more (fewer); rerolls: free restocks a round; gene_off: research points off an affix;
##   free_affix: affixes cost no research points; hp: the homeland's hit points more; mend: hit points back a round;
##   interest: the interest's cap more; biomass, gold: more each round; pool: biomass more from each culture pool;
##   front_armor: armour for the front row (one more with STARS_COUNT plant-eaters); red_atk: attack for red units (one
##   more with STARS_COUNT meat-eaters); haste: quicker strikes (%) for all; reach: range and armour-piercing for those
##   that reach far; atk, hp_pct: attack and hit points (%) for all; weak: hit points (%) less for all; count: one more
##   from every nest; slots: affix places more on every nest; ash: the homeland's hit points lost a round; win_gold:
##   gold more for a battle won; titan: a titan fights in every battle; grow_boss / grow_round (with grow_max): grows
##   one for each mini-boss or boss beaten / each round, and gives that much attack to all / biomass a round.
## model: the species it is shown as (the shared dinosaur library), with its colours (back, belly).
const STARS := {
	"mother": {"name": "慈母", "kind": "慈母龙", "diet": "plant", "rarity": 0, "price": 4, "eat": 1, "first_free": 1,
		"model": "edmontosaurus", "back": Color(0.55, 0.72, 0.42), "belly": Color(0.96, 0.92, 0.75), "says": "每轮第一个巢多孵 1 只，这只不吃生物质"},
	"doctor": {"name": "博士", "kind": "伤齿龙", "diet": "meat", "rarity": 0, "price": 4, "eat": 1, "gene_off": 1,
		"model": "velociraptor_alpha", "back": Color(0.4, 0.45, 0.7), "belly": Color(0.9, 0.9, 0.95), "says": "贴词条少花 1 研究点数"},
	"shield": {"name": "铁背", "kind": "甲龙", "diet": "plant", "rarity": 0, "price": 4, "eat": 1, "hp": 10, "mend": 1,
		"model": "placerias", "back": Color(0.5, 0.45, 0.4), "belly": Color(0.85, 0.8, 0.7), "says": "家园血 +10，每轮回 1 血"},
	"saver": {"name": "算盘", "kind": "原角龙", "diet": "plant", "rarity": 0, "price": 4, "eat": 1, "interest": 2,
		"model": "hesperosuchus", "back": Color(0.8, 0.7, 0.4), "belly": Color(0.98, 0.94, 0.8), "says": "利息最多多 2"},
	"belly": {"name": "大肚", "kind": "梁龙", "diet": "plant", "rarity": 0, "price": 5, "eat": 0, "biomass": 4,
		"model": "diplodocus", "back": Color(0.5, 0.62, 0.55), "belly": Color(0.9, 0.9, 0.8), "says": "每轮生物质 +4（它自己吃草）"},
	"tri": {"name": "三角", "kind": "三角龙", "diet": "plant", "rarity": 1, "price": 6, "eat": 2, "front_armor": 1,
		"model": "triceratops", "back": Color(0.7, 0.45, 0.3), "belly": Color(0.95, 0.85, 0.7), "says": "前排的兵护甲 +1；草食明星有 3 只以上时，再 +1"},
	"scar": {"name": "疤脸", "kind": "迅猛龙", "diet": "meat", "rarity": 1, "price": 6, "eat": 2, "red_atk": 1,
		"model": "acheroraptor", "back": Color(0.6, 0.2, 0.18), "belly": Color(0.95, 0.85, 0.75), "says": "红兵攻击 +1；肉食明星有 3 只以上时，再 +1"},
	"fisher": {"name": "渔夫", "kind": "植龙", "diet": "meat", "rarity": 1, "price": 6, "eat": 0, "pool": 1,
		"model": "phytosaur", "back": Color(0.35, 0.5, 0.45), "belly": Color(0.85, 0.85, 0.7), "says": "每座培养池多产 1 生物质（它自己捕鱼）"},
	"bounty": {"name": "赏金", "kind": "波斯特鳄", "diet": "meat", "rarity": 1, "price": 6, "eat": 1, "win_gold": 2,
		"model": "postosuchus", "back": Color(0.55, 0.4, 0.3), "belly": Color(0.9, 0.8, 0.6), "says": "每打赢一仗，多拿 2 金"},
	"horn": {"name": "号角", "kind": "副栉龙", "diet": "plant", "rarity": 1, "price": 6, "eat": 2, "haste": 15,
		"model": "edmontosaurus", "back": Color(0.75, 0.4, 0.55), "belly": Color(0.97, 0.88, 0.8), "says": "它一叫，所有兵打得快 15%"},
	"spitter": {"name": "双冠", "kind": "双冠龙", "diet": "meat", "rarity": 1, "price": 6, "eat": 2, "reach": 1,
		"model": "coelophysis_alpha", "back": Color(0.3, 0.55, 0.5), "belly": Color(0.95, 0.9, 0.6), "says": "够得着远处的兵：射程 +1，每下多 1，不管护甲"},
	"oldking": {"name": "老羽王", "kind": "羽王龙", "diet": "meat", "rarity": 2, "price": 9, "eat": 3, "grow_boss": 1,
		"grow_max": 4, "model": "yutyrannus", "back": Color(0.6, 0.55, 0.5), "belly": Color(0.95, 0.92, 0.85),
		"says": "每打败一个小首领或首领，所有兵攻击 +1，一直留着（最多 +4）"},
	"sickle": {"name": "镰刀", "kind": "镰刀龙", "diet": "plant", "rarity": 2, "price": 9, "eat": 2, "slots": 1, "ash": 1,
		"model": "sinocalliopteryx", "back": Color(0.55, 0.5, 0.35), "belly": Color(0.9, 0.85, 0.7), "says": "每个巢多 1 个词条位；但家园每轮掉 1 血"},
	"neck": {"name": "长颈", "kind": "腕龙", "diet": "plant", "rarity": 2, "price": 9, "eat": 0, "grow_round": 1, "grow_max": 8,
		"model": "diplodocus", "back": Color(0.6, 0.55, 0.4), "belly": Color(0.95, 0.9, 0.78), "says": "每过一轮，每轮生物质多 1（最多 +8；它自己吃树叶）"},
	"queen": {"name": "巢母", "kind": "巢母龙", "diet": "plant", "rarity": 3, "price": 16, "eat": 4, "count": 1, "weak": 10,
		"model": "edmontosaurus", "back": Color(0.6, 0.35, 0.6), "belly": Color(0.98, 0.85, 0.6), "says": "每个巢每轮多孵 1 只；但所有兵血少一成"},
	"firstbird": {"name": "始祖", "kind": "始祖鸟", "diet": "meat", "rarity": 3, "price": 16, "eat": 4, "slots": 1, "free_affix": 1,
		"model": "sinornithosaurus", "back": Color(0.3, 0.75, 0.7), "belly": Color(0.95, 0.95, 0.85), "says": "每个巢多 1 个词条位；贴词条不花研究点数"},
	"warlord": {"name": "霸主", "kind": "霸王龙", "diet": "meat", "rarity": 3, "price": 20, "eat": 6, "atk": 2, "hp_pct": 25,
		"model": "tyrannosaurus", "back": Color(0.75, 0.25, 0.2), "belly": Color(0.98, 0.85, 0.6), "says": "所有兵攻击 +2，血 +25%"},
	"titan": {"name": "泰坦", "kind": "阿根廷龙", "diet": "plant", "rarity": 3, "price": 20, "eat": 5, "titan": 1,
		"model": "diplodocus", "back": Color(0.5, 0.45, 0.4), "belly": Color(0.85, 0.8, 0.7), "says": "每仗多一只巨兽出战，站在前排正中"},
}
const PENS := 5                   # star dinosaurs kept at most, one a pen
const STARS_COUNT := 3            # a star that counts its diet's does more with this many of them
const STAR_ODDS := [3, 2, 1]      # how often the shop offers a common, an uncommon, a rare star (legendary: never)
const STARS_FROM := [1, 2, 2]     # the rarest the shop offers in each of the run's levels


## Strength (战力): how strong a fighter is, as one number the player never sees -- for balancing. The square root of
## what it can take times what it deals a second, so that a side's strength is the sum of its fighters' and two sides
## of equal strength have an even fight (tools/strength_check.gd checks this). A grey is 10.
const STRENGTH_K := 1.9245              # 10 / sqrt(9 hp * 3 a second)
const TYPICAL_HIT := 4.0                # armour is worth what it takes off a hit this hard
const REACH_WORTH := 0.3                # standing back (a reach of 3 m or more): it takes this much more
const DIVE_WORTH := 0.15                # flying over the front: it takes this much more
const SPLASH_WORTH := 1.0               # each metre of splash: it deals this much more
const HEAL_WORTH := 0.6                 # a hit point healed, against one dealt
const SPLIT_WORTH := 0.45               # what it breaks into, against standing there from the start
const BURST_WORTH := 0.25               # a burst, against a hit a second
const CHARGE_WORTH := 0.1               # a first blow twice as hard, against a hit a second
const KNOCK_WORTH := 0.1                # knocking the one it charges back, against a hit a second
const DEVOUR_WORTH := 0.15              # devouring: it deals this much more
const SLOWING_WORTH := 0.1              # roaring or shocking: it takes this much more (they strike slower)
const CLOUD_WORTH := 0.3                # a poison cloud, against a hit a second

## The blueprints (图纸, GAME-DESIGN 27-29, 32): what can be built or stuck on -- only what lasts, nothing used up at
## once. A place starts with none: first one of the nests of FIRST_NESTS is picked (free); the rest are techs of the
## tech tree (科技树), researched while the player builds (Home.research): each for its research points (研究点数,
## cost), once what it needs (needs: the tech before it on its line; "" for the first of a line) is had (the player,
## 2026-10-23: "做成类似杀戮尖塔的商店……类似于做一个科技树，某些科技需要之前的科技解锁"). Where a line forks in two
## (mutex: the other of the two), one of the two only, in this place: the other is shut once one is had (v0.15). A
## blueprint had can be built as often as there is gold, room and population for it -- a building each the more of its
## kind there are the dearer (Home.price_at). type "build": a building, on an open plot of its part of the homeland --
## an empty one, or one with another building, pulled down for half its price back; "affix": a gene affix on a nest with
## a free place. price: in gold (a building's is its own) -- research points buy techs, nothing else (the player,
## 2026-10-22: "各管一件事"). region: only in that place. rarity: how far down its line it is (0 the first, 2 the
## furthest) -- its metal, bronze, silver or gold. Raising a building a level is no blueprint: any building can be, for
## RAISE gold more than its level (a nest's makes it elite). In the order of the tree, line by line (TECH_PANELS).
const OFFERS := {
	# The nests, and the battle's buildings that go with them: the horde or the heavy, the wall or the healers.
	"b_red": {"type": "build", "rarity": 0, "builds": "nest_red", "cost": 1, "needs": ""},
	"b_totem": {"type": "build", "rarity": 1, "builds": "horde_totem", "cost": 3, "needs": "b_red", "mutex": "b_gold"},
	"b_gold": {"type": "build", "rarity": 1, "builds": "nest_gold", "cost": 3, "needs": "b_red", "mutex": "b_totem"},
	"b_hall": {"type": "build", "rarity": 2, "builds": "champion_hall", "cost": 3, "needs": "b_gold"},
	"b_green": {"type": "build", "rarity": 0, "builds": "nest_green", "cost": 1, "needs": ""},
	"b_vanguard": {"type": "build", "rarity": 1, "builds": "vanguard", "cost": 3, "needs": "b_green", "mutex": "b_white"},
	"b_white": {"type": "build", "rarity": 1, "builds": "nest_white", "cost": 2, "needs": "b_green", "mutex": "b_vanguard"},
	"b_blue": {"type": "build", "rarity": 0, "builds": "nest_blue", "cost": 1, "needs": ""},
	"b_tower": {"type": "build", "rarity": 1, "builds": "watchtower", "cost": 3, "needs": "b_blue"},
	"b_scav": {"type": "build", "rarity": 0, "builds": "nest_scav", "cost": 1, "needs": ""},
	# The resources, and the gene lab: the bank or the mutants, the vault or the forge.
	"b_pool": {"type": "build", "rarity": 0, "builds": "pool", "cost": 1, "needs": ""},
	"b_spore": {"type": "build", "rarity": 1, "builds": "spore_pool", "cost": 2, "needs": "b_pool", "region": 0},
	"b_sampler": {"type": "build", "rarity": 0, "builds": "sampler", "cost": 1, "needs": ""},
	"b_stab": {"type": "build", "rarity": 1, "builds": "stabilizer", "cost": 3, "needs": "b_sampler"},
	"b_genebank": {"type": "build", "rarity": 2, "builds": "gene_bank", "cost": 3, "needs": "b_stab", "mutex": "b_mutant"},
	"b_mutant": {"type": "build", "rarity": 2, "builds": "nest_mutant", "cost": 3, "needs": "b_stab", "mutex": "b_genebank"},
	"b_mine": {"type": "build", "rarity": 0, "builds": "mine", "cost": 1, "needs": ""},
	"b_vault": {"type": "build", "rarity": 1, "builds": "vault", "cost": 3, "needs": "b_mine", "mutex": "b_forge"},
	"b_forge": {"type": "build", "rarity": 1, "builds": "forge", "cost": 3, "needs": "b_mine", "region": 1, "mutex": "b_vault"},
	# The gene affixes: each recipe's second half after its first; the falcon's or the magma beast's, not both.
	"a_shell": {"type": "affix", "price": 3, "rarity": 0, "affix": "shell", "cost": 2, "needs": ""},
	"a_plasma": {"type": "affix", "price": 4, "rarity": 1, "affix": "plasma", "cost": 4, "needs": "a_shell"},
	"a_blade": {"type": "affix", "price": 3, "rarity": 0, "affix": "blade", "cost": 2, "needs": ""},
	"a_wings": {"type": "affix", "price": 4, "rarity": 1, "affix": "wings", "cost": 4, "needs": "a_blade", "mutex": "a_flame"},
	"a_flame": {"type": "affix", "price": 4, "rarity": 1, "affix": "flame", "cost": 3, "needs": "a_blade", "mutex": "a_wings"},
	"a_haste": {"type": "affix", "price": 3, "rarity": 0, "affix": "haste", "cost": 2, "needs": ""},
	"a_acid": {"type": "affix", "price": 4, "rarity": 1, "affix": "acid", "cost": 3, "needs": "a_haste", "mutex": "a_devour"},
	"a_poison": {"type": "affix", "price": 3, "rarity": 2, "affix": "poison", "cost": 3, "needs": "a_acid", "region": 0},
	"a_devour": {"type": "affix", "price": 4, "rarity": 1, "affix": "devour", "cost": 3, "needs": "a_haste", "mutex": "a_acid"},
	"a_hide": {"type": "affix", "price": 3, "rarity": 0, "affix": "hide", "cost": 2, "needs": ""},
	"a_horn": {"type": "affix", "price": 3, "rarity": 1, "affix": "horn", "cost": 3, "needs": "a_hide", "mutex": "a_roar"},
	"a_roar": {"type": "affix", "price": 3, "rarity": 1, "affix": "roar", "cost": 3, "needs": "a_hide", "mutex": "a_horn"},
}
## The tech tree's three parts, by what their lines are for, each with the first tech of its lines, in order: the nests
## (and the battle's buildings that go with each), the resources (and the gene lab, behind the samplers -- open from the
## start, the player, 2026-10-23: "研究所应该一开始就能做，不然研究点数增加太难"), the affixes.
const TECH_PANELS := {"巢": ["b_red", "b_green", "b_blue", "b_scav"], "资源": ["b_pool", "b_sampler", "b_mine"],
	"词条": ["a_shell", "a_blade", "a_haste", "a_hide"]}
## The nests a place's first is picked from (the player, 2026-10-22: "开场什么建筑都没有，先三选一一个巢穴"): those
## the round's pay builds that can hold the first rounds by themselves -- not the healers, not the gold, not the
## mutants (weak but for their affixes: of 48 runs, every one that a mutant began fell in the first place).
const FIRST_NESTS := ["b_red", "b_blue", "b_green", "b_scav"]
const FIRST_CHOICE := 3           # of them to pick from
## The build bar's groups, by what the blueprints do (the player, 2026-10-21: "以能力归类"): nests hatch; the
## resources' buildings bring in population, research points and gold; the battle's make the nests in front of them
## stronger; the genes' are affixes, and the buildings that help with them.
const GROUPS := {"nest": "巢", "resource": "资源", "battle": "战斗", "gene": "基因"}
const RAISE := 2                  # a raise costs this much more than the building's level
const MORE := 1                   # a building costs this much more for each of its kind there is already (v0.15)...
const NEVER_MORE := ["pool", "spore_pool"]  # ...but the pools and the nests (the player's choice, 2026-10-23)
const INTEREST_STEP := 5          # each this much gold kept to a round's end brings one more...
const INTEREST_MAX := 5           # ...up to this much
const WIN_GOLD := 2               # gold for a battle won
const HOME_POP := 2               # the population the homeland feeds of itself, before any pool (the player: 家园自带)
## The star dinosaurs (STARS, GAME-DESIGN 24) put away for now (the player, 2026-10-22: "暂时把明星恐龙去掉"): none
## comes to be had, the pens are not shown, the round has no eating. Everything of theirs is kept, to come back.
const STARS_ON := false

const TYPES := {"build": "建筑", "affix": "基因词条"}
const DIETS := {"plant": "草食", "meat": "肉食"}
const RARITY_NAMES := ["普通", "少见", "稀有", "传说"]

## A round's parts, in turn (GAME-DESIGN 26), from the start again after the battle; more can come between them (the
## player, 2026-10-21: "阶段是可扩展的"). Each thing a card does happens in one of them (PHASE_OF).
const PHASES := {
	"start": {"name": "开始", "says": "每轮的 5 金和利息到手"},
	"play": {"name": "玩家", "says": "造、升级、贴词条、研究科技"},
	"make": {"name": "生产", "says": "建筑产研究点数、金币，巢里孵出这一轮的兵"},
	"eat": {"name": "消耗", "says": "明星恐龙吃东西（明星恐龙先去掉了，这一步跳过）", "stars": true},
	"fight": {"name": "战斗", "says": "兵出去打仗，打赢拿金币和研究点数"},
}
## The part of the round each thing a card does happens in ("每个牌的效果都要落在某个阶段"): the keys of the buildings'
## levels and of the stars, a nest's gift (TRAITS), a nest's raise ("elite"; "count", the brood queen's one more), an
## affix ("affix").
const PHASE_OF := {
	# The start: the round's pay.
	"interest": "start",
	# The player's part: what buying and putting down cost, what can be had and kept.
	"gene_off": "play", "free_affix": "play", "slots": "play", "mutant": "play", "affix_off": "play",
	# The making: what comes in, the young hatched.
	"biomass": "make", "genes": "make", "gold": "make", "pool": "make", "grow_round": "make", "mend": "make",
	"count": "make", "first_free": "make", "titan": "make", "swarm": "make",
	# The eating.
	"eat": "eat", "ash": "eat",
	# The battle, and what it brings.
	"atk": "fight", "hp_pct": "fight", "front_armor": "fight", "red_atk": "fight", "haste": "fight", "reach": "fight",
	"weak": "fight", "grow_boss": "fight", "win_gold": "fight", "hp": "fight", "elite": "fight", "per": "fight",
	"ranged": "fight", "front": "fight", "guard": "fight", "cover": "fight", "alone": "fight", "care": "fight",
	"scavenge": "fight", "affix": "fight",
}
## What a star's entry holds besides what it does.
const STAR_FACTS := ["name", "kind", "diet", "rarity", "price", "model", "back", "belly", "says", "grow_max"]


## The round's parts as they are played now: all of PHASES but those only the star dinosaurs have, while they are put
## away (STARS_ON).
static func phases() -> Array:
	return PHASES.keys().filter(func(k: String) -> bool: return STARS_ON or not PHASES[k].get("stars", false))


## The population a blueprint takes, as the bar shows it (where it goes it can take more: Home.pop_need): a nest, what
## the young it hatches at first eat; a culture pool, what it feeds, as less than nothing; anything else none.
static func pop_of(o: Dictionary) -> int:
	if o.type != "build":
		return 0
	var b: Dictionary = BUILDINGS[o.builds]
	if b.has("nest"):
		return int(UNITS[b.nest].food)
	return -int(b.levels[0].get("biomass", 0))

## A run (GAME-DESIGN 22): TIERS big levels of ROUNDS rounds each (half an hour or so). The first is always the
## rainforest; for each after it the map offers two places (Run.map), one to pick. A level's monsters are as strong as
## its tier (TIER_POWER), wherever it is; each wave is SHARE of LIMIT strong for its tier. Every level is begun from
## nothing (Home.fresh), the calm runs that measure LIMIT too, so each level's own curve tells how strong the armies
## there grow. (2026-10-21, 48 runs by school: at 0.6, 0.66, 0.72 23 held all three, the schools far apart; all at 0.6,
## 44 -- every school 6 to 8 of 8. 2026-10-22, every place begun with one nest: all at 0.6, 43 held all, but the first
## place all but never lost a battle -- 1 of 576 -- its homeland growing fastest, the spore pools; the first at 0.8,
## the second 0.66, the third 0.6: 40 held all, battles lost in every place. 2026-10-23, the tech tree: at those, of 37
## runs only 22 held all; the first at 0.72 or 0.8, the second 0.66, the third 0.54: 44 of 48, though the first place
## is lost but 6 or 7 times in 576 by the tools. All a fifth less, the player not getting through it in many runs:
## 0.64, 0.53, 0.43.)
const TIERS := 3
const ROUNDS := 12
const TIER_POWER := [1.0, 1.25, 1.5]
const SHARE := [0.64, 0.53, 0.43]

## The places a run goes to -- each a big level, the rounds of MINI_ROUNDS against its `minis` in turn, the last
## against its `boss`. mix: which kinds come, [kind, share, from which round]. lay: what its map is like, in a few
## words. map: its homeland (GAME-DESIGN 33), a row
## of letters a line of cells from the top (nearest the road out) down -- "." bare land, a letter a plot, START_PLOT the
## one open from the start; no two plots up, down, left or right of each other -- what makes one place's homeland
## unlike another's. terrain: how many of each special cell (TERRAIN) lie about, with TERRAIN_ON only (put away; the
## player, 2026-10-20: "先只用地形differenciate"; the places' rules, damp, ash and the rest, are gone). ground, grass: the
## homeland's earth and the land round it; sky: [top, horizon]; color: on the map.
const LEVELS := [
	{"name": "雨林", "lay": "大小搭配，中间一个十字", "boss": "boss_rain", "minis": ["mini_rain", "mini_rain2"],
		"map": ["AA.BBB", "A.C.B.", ".CCC.D", "E.C.DD", "EE...D", "..SS..", "G.SS.H"],
		"terrain": {"pond": 3, "tree": 2}, "ground": Color(0.42, 0.36, 0.26), "grass": Color(0.24, 0.42, 0.2),
		"sky": [Color(0.36, 0.55, 0.82), Color(0.74, 0.82, 0.88)], "color": Color(0.36, 0.62, 0.32),
		"mix": [["grey", 0.3, 1], ["spore", 0.45, 1], ["purple", 0.25, 2]]},
	{"name": "火山", "lay": "中间一个大十字，四周小石块", "boss": "boss_lava", "minis": ["mini_lava", "mini_lava2"],
		"map": ["AAA.BB", "...C.B", "D.CCC.", "D..C.E", ".F...E", "FF.SS.", "..SS.G"],
		"terrain": {"ore": 3, "lava": 2}, "ground": Color(0.36, 0.3, 0.27), "grass": Color(0.32, 0.28, 0.24),
		"sky": [Color(0.42, 0.4, 0.44), Color(0.82, 0.62, 0.48)], "color": Color(0.85, 0.36, 0.18),
		"mix": [["grey", 0.2, 1], ["beetle", 0.45, 1], ["salamander", 0.35, 1]]},
	{"name": "沼泽", "lay": "小岛多，一块两三格", "boss": "boss_bog", "minis": ["mini_bog", "mini_bog2"],
		"map": ["AA.B.C", "...B.C", "D.E.F.", "D.E.FF", ".G....", "GG.SS.", "..SS.H"],
		"terrain": {"mire": 3, "toadstool": 2}, "ground": Color(0.32, 0.29, 0.21), "grass": Color(0.22, 0.29, 0.17),
		"sky": [Color(0.38, 0.44, 0.4), Color(0.66, 0.7, 0.58)], "color": Color(0.46, 0.52, 0.3),
		"mix": [["grey", 0.2, 1], ["leech", 0.45, 1], ["moth", 0.35, 2]]},
	{"name": "冰原", "lay": "横长条，一块顾好几路", "boss": "boss_ice", "minis": ["mini_ice", "mini_ice2"],
		"map": ["AAAA.B", ".....B", "CC.DD.", ".C..D.", "E.FF.G", "E....G", ".SSSS."],
		"terrain": {"ice_ore": 3, "glacier": 2}, "ground": Color(0.3, 0.34, 0.42), "grass": Color(0.7, 0.75, 0.81),
		"sky": [Color(0.46, 0.57, 0.74), Color(0.74, 0.8, 0.86)], "color": Color(0.6, 0.78, 0.95),
		"mix": [["grey", 0.2, 1], ["frostfang", 0.45, 1], ["shard", 0.35, 2]]},
	{"name": "荒漠", "lay": "2×2 的方块，中间大片沙地", "boss": "boss_sand", "minis": ["mini_sand", "mini_sand2"],
		"map": ["AA..BB", "AA..BB", "..CC..", "D.CC.E", "D....E", "..SS..", "F.SS.G"],
		"terrain": {"oasis": 3, "ruin": 2}, "ground": Color(0.6, 0.48, 0.32), "grass": Color(0.8, 0.68, 0.46),
		"sky": [Color(0.42, 0.6, 0.85), Color(0.95, 0.85, 0.66)], "color": Color(0.9, 0.72, 0.4),
		"mix": [["grey", 0.2, 1], ["sandworm", 0.45, 1], ["scorpion", 0.35, 2]]},
	{"name": "海岸", "lay": "竖长条，一块只顾一路", "boss": "boss_sea", "minis": ["mini_sea", "mini_sea2"],
		"map": ["A.B.C.", "A.B.C.", "A.B.C.", ".D.E.F", ".D.E.F", "G....F", "G.SSS."],
		"terrain": {"tidepool": 3, "wreck": 2}, "ground": Color(0.58, 0.52, 0.4), "grass": Color(0.2, 0.42, 0.52),
		"sky": [Color(0.34, 0.56, 0.84), Color(0.78, 0.88, 0.92)], "color": Color(0.3, 0.6, 0.78),
		"mix": [["grey", 0.2, 1], ["crab", 0.45, 1], ["jelly", 0.35, 2]]},
]
## Special plots, all behind the battle line: build: whether a building can go on it; like: which of the four ways it
## works (a pond's, an old tree's, a vein of ore's, a lava pool's) -- each place has its own two.
const TERRAIN := {
	"pond": {"name": "水塘", "build": true, "like": "pond", "color": Color(0.3, 0.55, 0.75),
		"says": "培养池、孢子池造在这里，人口翻倍"},
	"tree": {"name": "古树", "build": false, "like": "tree", "color": Color(0.2, 0.36, 0.15),
		"says": "不能造。旁边的采样站每轮多 1 研究点数"},
	"ore": {"name": "矿脉", "build": true, "like": "ore", "color": Color(0.4, 0.37, 0.34), "says": "矿场、熔炉造在这里，金币 +2"},
	"lava": {"name": "岩浆", "build": false, "like": "lava", "color": Color(0.85, 0.3, 0.08),
		"says": "不能造。旁边的矿场、熔炉每轮多 1 金币"},
	"mire": {"name": "泥塘", "build": true, "like": "pond", "color": Color(0.3, 0.34, 0.22),
		"says": "培养池、孢子池造在这里，人口翻倍"},
	"toadstool": {"name": "毒菇林", "build": false, "like": "tree", "color": Color(0.58, 0.36, 0.52),
		"says": "不能造。旁边的采样站每轮多 1 研究点数"},
	"ice_ore": {"name": "冰矿", "build": true, "like": "ore", "color": Color(0.62, 0.74, 0.84), "says": "矿场、熔炉造在这里，金币 +2"},
	"glacier": {"name": "冰封遗骸", "build": false, "like": "tree", "color": Color(0.8, 0.88, 0.94),
		"says": "不能造。旁边的采样站每轮多 1 研究点数"},
	"oasis": {"name": "绿洲", "build": true, "like": "pond", "color": Color(0.28, 0.6, 0.55),
		"says": "培养池、孢子池造在这里，人口翻倍"},
	"ruin": {"name": "遗迹", "build": false, "like": "tree", "color": Color(0.7, 0.62, 0.46),
		"says": "不能造。旁边的采样站每轮多 1 研究点数"},
	"tidepool": {"name": "潮池", "build": true, "like": "pond", "color": Color(0.24, 0.5, 0.64),
		"says": "培养池、孢子池造在这里，人口翻倍"},
	"wreck": {"name": "沉船", "build": false, "like": "lava", "color": Color(0.42, 0.33, 0.24),
		"says": "不能造。旁边的矿场、熔炉每轮多 1 金币"},
}

## The strength a player's army comes to at each round of the run (the levels one after another) when no one comes,
## every battle is won and everything goes to growing -- for the middle school of the six (the median of each school's
## average, so one school growing far past the rest does not make every wave too strong for the others), over runs
## keeping to each school, measured by tools/sim_runs.gd (school ... limit; tools/limit.py). Each level starts low
## again: the homeland is begun afresh, carrying nothing. Measured again 2026-10-23 with the plots (GAME-DESIGN 33: a
## map of plots opened for gold, a building's help only to those beside it; before them, the tech tree's forks and a
## building dearer for each of its kind there is, GAME-DESIGN 32; the tech tree, GAME-DESIGN 29, and
## 2026-10-22: every place begun with one nest picked, the population a bound, research points for blueprints, the
## buildings' reach, GAME-DESIGN 28) -- 48 calm
## runs, 8 a school, the scavengers' loot not counted (with no one coming they all stand, Policy._battle), the
## population counted only as far as the nests use it (Policy.score); a level's curve never below the one before it,
## round for round. Measure again after changing what can be built or made.
const LIMIT := [13, 29, 43, 47, 66, 98, 121, 145, 163, 182, 198, 213,
	12, 27, 40, 52, 72, 93, 116, 139, 162, 186, 208, 227,
	12, 30, 40, 54, 69, 88, 105, 120, 137, 163, 190, 205]
const BIG_ROUNDS := [4, 8, 12]          # a big wave, with the place's mini-boss or boss: BIG times as strong as the round
const BIG := 1.15                       # would be
const MINI_ROUNDS := [4, 8]             # the rounds against the place's mini-bosses
## How dangerous a wave looks to the player (GAME-DESIGN 22), by its strength: one skull below the first of these, one
## more past each -- a feel for it, not whether it will be won (that is worked out only for the tools and F3).
const DANGER := [14.0, 27.0, 54.0, 97.0, 171.0]


## A blueprint's numbers (oi: {id}): its name, price, type and what it goes on.
static func offer(oi: Dictionary) -> Dictionary:
	var o: Dictionary = OFFERS[oi.id].duplicate(true)
	o.id = oi.id
	o.target = {"build": "tile", "affix": "nest"}.get(o.type, "none")
	match o.type:
		"build":
			o.name = Lang.t(BUILDINGS[o.builds].name)
			o.price = int(BUILDINGS[o.builds].cost)
		"affix":
			o.name = Lang.t(AFFIXES[o.affix].name)
	return o


## The build bar's group of blueprint `id` (GROUPS).
static func group_of(id: String) -> String:
	var o: Dictionary = OFFERS[id]
	if o.type == "affix":
		return "gene"
	var b: Dictionary = BUILDINGS[o.builds]
	if b.has("nest"):
		return "nest"
	if b.get("school", "") == "genes" and o.builds != "sampler":
		return "gene"
	if o.builds in ["horde_totem", "champion_hall", "watchtower", "vanguard"]:
		return "battle"
	return "resource"



static func is_nest(kind: String) -> bool:
	return BUILDINGS[kind].has("nest")


## A building (not a nest) at a level: its level's line. A nest's own numbers come from its choices (Home).
static func level(kind: String, lv: int) -> Dictionary:
	var b: Dictionary = BUILDINGS[kind]
	if b.has("nest"):
		return {}
	return b.levels[clampi(lv, 1, LEVEL_MAX) - 1]


## The species a nest of `base` units hatches with these affixes: {kind, used: the affixes that went into it}.
static func species(base: String, affixes: Array) -> Dictionary:
	for r in RECIPES:
		if r.affixes[0] in affixes and r.affixes[1] in affixes:
			return {"kind": r.makes, "used": r.affixes.duplicate()}
	return {"kind": base, "used": []}


## What a nest with this one affix could become: [[the other affix, the species]].
static func could_become(affixes: Array) -> Array:
	var out: Array = []
	for r in RECIPES:
		for k in 2:
			if r.affixes[k] in affixes and not r.affixes[1 - k] in affixes:
				out.append([r.affixes[1 - k], r.makes])
	return out


## What a building does at a level.
static func building_text(kind: String, lv: int) -> String:
	var b: Dictionary = BUILDINGS[kind]
	if b.has("nest"):
		return Lang.t("孵%s。本事「%s」：%s") % [Lang.t(UNITS[b.nest].name), Lang.t(TRAITS[b.trait].name), Lang.t(TRAITS[b.trait].says)]
	var l := level(kind, lv)
	match kind:
		"pool", "spore_pool":
			return Lang.t("人口上限 +%d。挨着的采样站每轮多 %d 研究点数") % [l.biomass, SAMPLER_POOL]
		"horde_totem":
			return Lang.t("挨着的巢孵的兵：出战的兵每满 %d 只，攻击 +1") % l.per
		"sampler":
			return Lang.t("每轮产 %d 研究点数（解锁图纸用）。挨着的每个培养池、孢子池，再多 %d") % [l.genes, SAMPLER_POOL]
		"stabilizer":
			return Lang.t("挨着的巢，能多贴 %d 个词条") % l.slots
		"gene_bank":
			return Lang.t("挨着的巢，贴词条便宜 %d 金") % l.affix_off
		"mine", "forge":
			return Lang.t("每轮多 %d 金币。挨着的金库，利息上限多 %d") % [l.gold, VAULT_MINE]
		"vault":
			return Lang.t("利息上限多 %d。挨着的每座矿场、熔炉，再多 %d") % [l.interest, VAULT_MINE]
		"champion_hall":
			return Lang.t("挨着的巢孵的精英兵，血和攻击再 +%d%%") % l.elite
		"watchtower":
			return Lang.t("挨着的巢孵的远程兵（够得着 3 米以上），每下多 %d 点伤害，不管护甲") % l.ranged
		"vanguard":
			return Lang.t("挨着的巢孵的近战兵，血 +%d%%") % l.front
	return ""


## What a building does at a level, in short -- what changes when it is raised: for a nest, elite.
static func level_text(kind: String, lv: int) -> String:
	if BUILDINGS[kind].has("nest"):
		return Lang.t("变精英：血 ×%s、攻击 ×%s、大一号，不多占人口") % [_num(ELITE_HP), _num(ELITE_ATK)]
	return building_text(kind, lv)


static func _num(x: float) -> String:
	return ("%d" % x) if is_equal_approx(x, roundf(x)) else str(snappedf(x, 0.01))


## What an offer does, in the player's words -- short, for a card's slip (its name is on the card already; a nest's
## gift's name over its picture).
static func offer_text(o: Dictionary) -> String:
	match o.type:
		"build":
			var lv := int(o.get("level", 1))
			var b: Dictionary = BUILDINGS[o.builds]
			var stop := Lang.t("。")
			var text := (Lang.t("孵%s。%s。") % [Lang.t(UNITS[b.nest].name), Lang.t(TRAITS[b.trait].says)]) if b.has("nest") \
				else building_text(o.builds, lv) + stop
			if o.has("level"):
				var sp := species(b.get("nest", ""), o.affixes)
				text = Lang.t("%d 级。") % lv + (Lang.t("孵%s。") % Lang.t(UNITS[sp.kind].name) if b.has("nest") \
					else building_text(o.builds, lv) + stop)
				if not o.affixes.is_empty():
					text += Lang.t("贴着") + Lang.t("、").join(o.affixes.map(func(a: String) -> String: return Lang.t(AFFIXES[a].name))) + stop
			return text
		"affix":
			var a: Dictionary = AFFIXES[o.affix]
			var also := ""
			for r in RECIPES:
				if o.affix in r.affixes:
					also = Lang.t("能凑配方。")
			return Lang.t("孵的兵%s。%s") % [Lang.t(a.says), also]
	return ""


## One of our units' numbers, from what the nest gives it (Home.army's spec: kind, hp_mult, atk_mult, atk_bonus, armor,
## range, splash, dive, pierce, haste, charge, size_mult).
static func unit_stats(spec: Dictionary) -> Dictionary:
	var base: Dictionary = UNITS[spec.kind]
	var s := base.duplicate()
	s.hp = maxi(1, roundi(float(base.hp) * float(spec.get("hp_mult", 1.0))))
	s.atk = roundi(float(base.atk) * float(spec.get("atk_mult", 1.0))) + int(spec.get("atk_bonus", 0))
	s.armor = int(base.get("armor", 0)) + int(spec.get("armor", 0))
	s.range = maxf(float(base.range), float(spec.get("range", 0.0)))
	s.splash = float(base.get("splash", 0.0)) + float(spec.get("splash", 0.0))
	s.heal = roundi(float(base.get("heal", 0)) * float(spec.get("atk_mult", 1.0))) * (CARE if spec.get("care", false) else 1)
	s.pierce = int(base.get("pierce", 0)) + int(spec.get("pierce", 0))
	s.burst = int(base.get("burst", 0))
	s.every = float(base.every) * 100.0 / (100.0 + float(spec.get("haste", 0)))
	s.dive = bool(base.get("dive", false)) or bool(spec.get("dive", false))
	s.charge = bool(spec.get("charge", false))
	s.knock = float(spec.get("knock", 0.0))
	s.devour = bool(spec.get("devour", false))
	s.roar = bool(spec.get("roar", false))
	s.shock = bool(base.get("shock", false))
	s.cloud = int(base.get("cloud", 0))
	s.size = float(base.size) * float(spec.get("size_mult", 1.0))
	s.harm = 0
	return s


static func enemy_stats(kind: String, power := 1.0) -> Dictionary:
	var base: Dictionary = ENEMIES[kind]
	var s := base.duplicate()
	s.hp = maxi(1, roundi(float(base.hp) * power))
	s.atk = maxi(1, roundi(float(base.atk) * power))
	s.armor = int(base.get("armor", 0))
	s.splash = float(base.get("splash", 0.0))
	s.heal = 0
	s.pierce = 0
	s.burst = roundi(float(base.get("burst", 0)) * power)
	s.dive = false
	s.charge = false
	s.knock = 0.0
	s.devour = false
	s.roar = false
	s.shock = false
	s.cloud = 0
	return s


## A fighter's strength, from its numbers (unit_stats, enemy_stats, or a Fight fighter with `max` for its full health).
static func strength(s: Dictionary, power := 1.0) -> float:
	var hp := float(s.get("max", s.hp))
	var armor := float(s.get("armor", 0))
	var take := hp * TYPICAL_HIT / maxf(1.0, TYPICAL_HIT - armor) * (1.0 + REACH_WORTH if float(s.range) >= 3.0 else 1.0)
	if s.get("dive", false):
		take *= 1.0 + DIVE_WORTH
	if s.get("roar", false) or s.get("shock", false):
		take *= 1.0 + SLOWING_WORTH
	var deal := (float(s.atk) + float(s.get("pierce", 0))) / float(s.every) * (1.0 + SPLASH_WORTH * float(s.get("splash", 0.0))) \
		+ HEAL_WORTH * float(s.get("heal", 0)) / float(s.every) + BURST_WORTH * float(s.get("burst", 0)) \
		+ (CHARGE_WORTH * float(s.atk) if s.get("charge", false) else 0.0) \
		+ (KNOCK_WORTH * float(s.atk) if float(s.get("knock", 0.0)) > 0.0 else 0.0) + CLOUD_WORTH * float(s.get("cloud", 0))
	if s.get("devour", false):
		deal *= 1.0 + DEVOUR_WORTH
	var n := STRENGTH_K * sqrt(take * deal)
	if s.has("split") and ENEMIES.has(s.split):
		n += SPLIT_WORTH * int(s.get("splits", 0)) * strength(enemy_stats(s.split, power))
	return n


static func enemy_strength(kind: String, power := 1.0) -> float:
	return strength(enemy_stats(kind, power), power)


## Who comes in round `r` (1-based) at `place` (LEVELS), the run's `tier`-th level: a list of kinds, as strong all told
## as the tier's share of LIMIT (and more in a big round) -- the boss in the last round, a mini-boss in its rounds, then
## each kind of the mix its share, the strongest first, the weakest making up what is left.
static func wave(place: int, tier: int, r: int) -> Array:
	var lv: Dictionary = LEVELS[place]
	var g := tier * ROUNDS + r
	var power := float(TIER_POWER[tier])
	var budget := float(LIMIT[clampi(g, 1, LIMIT.size()) - 1]) * float(SHARE[tier]) * (BIG if r in BIG_ROUNDS else 1.0)
	var out: Array = []
	if r >= ROUNDS and lv.has("boss"):
		out.append(lv.boss)
		budget -= enemy_strength(lv.boss, power)
	elif r in MINI_ROUNDS and lv.has("minis"):
		var which: String = lv.minis[mini(MINI_ROUNDS.find(r), lv.minis.size() - 1)]
		out.append(which)
		budget -= enemy_strength(which, power)
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


## How a wave stands on the field (GAME-DESIGN 32; v0.15): the round's plan of attack, the same each time for a place,
## a level and a round, so known while the player builds. Each its weights for the six lanes (the homeland's columns,
## 0 at the left): for those that fight close (in front), those that reach far (behind) and -- in the middle's -- the
## heavy (the boss, the mini-bosses, the armoured). A flank comes down one side, its other side mirrored.
const FORMATIONS := {
	"line": {"name": "全线压境", "melee": [1, 1, 1, 1, 1, 1], "ranged": [1, 1, 1, 1, 1, 1]},
	"flank": {"name": "侧翼突袭", "melee": [4, 4, 1.5, 1, 0.5, 0.5], "ranged": [2, 2, 1, 0.5, 0.5, 0.5]},
	"middle": {"name": "中路重装", "heavy": [0, 0, 1, 1, 0, 0], "melee": [1, 1, 0.3, 0.3, 1, 1], "ranged": [1, 1, 0.5, 0.5, 1, 1]},
	"pincer": {"name": "分路夹击", "melee": [3, 3, 0, 0, 3, 3], "ranged": [0.5, 0.5, 2, 2, 0.5, 0.5]},
}


## The plan a wave comes in (FORMATIONS): the middle with a mini-boss or the boss; the whole line the first two rounds;
## else the four in turn over the rounds between, where the turn starts depending on the place and the level -- so
## that each comes in every level.
static func formation_of(place: int, tier: int, r: int) -> String:
	if r >= ROUNDS or r in MINI_ROUNDS:
		return "middle"
	if r <= 2:
		return "line"
	var k := 0
	for q in range(3, r):
		if not q in MINI_ROUNDS:
			k += 1
	return ["flank", "pincer", "line", "middle"][(k + place + tier) % 4]


## Whether a wave in round `r` comes down the right side, where its plan has a side.
static func from_right(place: int, tier: int, r: int) -> bool:
	return (place + tier + r) % 2 == 1


## The lane (0 to 5) each of `kinds` -- a wave, in order -- stands in (GAME-DESIGN 32): the heavy first, then the rest,
## each to the lane of its sort (heavy, close, far) furthest below its share of the plan's weights.
static func lanes(place: int, tier: int, r: int, kinds: Array) -> Array:
	var plan: Dictionary = FORMATIONS[formation_of(place, tier, r)]
	var flip := from_right(place, tier, r)
	var out: Array = []
	out.resize(kinds.size())
	var tally := {}
	var order: Array = range(kinds.size())
	var heavy := func(k: String) -> bool:
		return k.begins_with("boss_") or k.begins_with("mini_") or int(ENEMIES[k].get("armor", 0)) >= 1
	order.sort_custom(func(a: int, b: int) -> bool:
		var ha: bool = heavy.call(kinds[a])
		var hb: bool = heavy.call(kinds[b])
		return ha and not hb or ha == hb and a < b)
	for i in order:
		var k: String = kinds[i]
		var sort := "ranged" if float(ENEMIES[k].range) >= 3.0 else "melee"
		if plan.has("heavy") and heavy.call(k):
			sort = "heavy"
		var w: Array = (plan[sort] as Array).duplicate()
		if flip:
			w.reverse()
		var c: Array = tally.get(sort, [0, 0, 0, 0, 0, 0])
		var sum_w := 0.0
		var n := 0
		for j in 6:
			sum_w += float(w[j])
			n += int(c[j])
		var best := -1
		var best_gap := -INF
		for j in 6:
			if float(w[j]) <= 0.0:
				continue
			var gap := float(w[j]) / sum_w * (n + 1) - int(c[j])
			if gap > best_gap + 0.0001 or absf(gap - best_gap) <= 0.0001 and absf(j - 2.5) < absf(best - 2.5):
				best = j
				best_gap = gap
		c[best] = int(c[best]) + 1
		tally[sort] = c
		out[i] = best
	return out


## How dangerous a wave looks: one skull, and one more for each of DANGER its strength all told reaches.
static func danger(kinds: Array, power := 1.0) -> int:
	var s := 0.0
	for k in kinds:
		s += enemy_strength(k, power)
	var n := 1
	for t in DANGER:
		if s >= t:
			n += 1
	return n
