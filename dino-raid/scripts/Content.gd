class_name Content
## What there is to build, make and fight (GAME-DESIGN 19-22) -- coloured blocks standing in for the gene ark's creatures
## and the alien monsters of each place it lands. The systems (Home, Fight, Run) read only this: change what is here
## and they follow.

## Units the nests make -- for one round only. hp; atk, each hit; every: seconds between hits; range, metres; speed,
## metres a second; armor: taken off each hit it takes; splash: metres round its mark that also take half; heal: hit
## points it gives the most hurt friend in reach (instead of hitting); pierce: damage more each hit, armour or not;
## burst: damage to the other side round it (BURST_RADIUS) when it falls; dive: flies over the front for the back;
## size: the block's edge; food: biomass it takes to make. One for each kind of nest (its gift, TRAITS, is the nest's);
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
		"speed": 2.2, "size": 1.3, "armor": 1, "splash": 1.5, "food": 2, "role": "进化来的：又硬，又电一圈"},
	"miasma": {"name": "毒雾兽", "color": Color(0.55, 0.85, 0.3), "hp": 10, "atk": 3, "every": 1.0, "range": 5.0,
		"speed": 2.4, "size": 0.95, "pierce": 2, "splash": 1.2, "food": 2, "role": "进化来的：远处喷毒雾，不管护甲"},
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

## The homeland's two parts: the top FRONT_ROWS rows (nearest the road out) are the battle line -- nests only, and a
## nest's units stand in battle where it stands, the top row in front, its column their lane; the rows behind are for
## everything else, a building there doing what it does for the nests of its column or the whole homeland.
const FRONT_ROWS := 2

## A nest begins making one a round. Each raise (up to LEVEL_MAX) is a choice: "count", one more a round, or "elite",
## each of its units ELITE_HP times the hit points, ELITE_ATK times the attack, ELITE_SIZE times as big.
const LEVEL_MAX := 3
const ELITE_HP := 1.5
const ELITE_ATK := 1.25
const ELITE_SIZE := 1.2
const CLUSTER := 1                # a red nest with at least this many red neighbours makes one more (its gift)
const SAMPLER_POOL := 1           # genes more a round for each culture pool beside a sampler
const TREE_GENES := 1             # genes more a round for a sampler beside an old tree
const LAVA_GOLD := 1              # gold more a round for a mine or forge beside lava

## Each nest's gift (本事), the same for whatever it hatches -- most of them only where the nest stands: in front or
## behind, its column, its neighbours. Not tied to a school: what it does fits several ways of playing. when: where it
## works ("" anywhere); does: what it does there; says: both in short, for a card. The numbers they say are these:
const TRAITS := {
	"swarm": {"name": "成群", "when": "上下左右挨着红巢", "does": "多孵 1 只", "says": "挨着红巢，多孵 1 只"},
	"guard": {"name": "护住一列", "when": "站第一排", "does": "怪要先打倒它，才打得着它身后同一列的兵",
		"says": "站第一排，护住身后同一列的兵"},
	"cover": {"name": "掩护射击", "when": "站第二排、身前同一列有巢", "does": "远程的兵射得远 2 米，每下多 1，不管护甲",
		"says": "站第二排、身前有巢挡着：射得更远，每下多 1"},
	"alone": {"name": "独当一面", "when": "同一排左右都没有巢", "does": "大一号，血和攻击 +30%",
		"says": "左右都没有巢：大一号，血和攻击 +30%"},
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

## Buildings. A nest makes `nest` units and has a gift (`trait`, TRAITS). Each level of the others may give: biomass,
## genes, gold: that much more each round; slots: nests of its column can carry this many more affixes; gene_off: each
## affix this many genes cheaper; interest: the most interest this much more; rerolls: restocks of the shelf free each
## round; shelf: offers more on it; per: every this many units in an army, all of them +1 attack; elite: elite units'
## hit points and attack this % more; ranged: units reaching 3 m or more this much more damage each hit, armour or not
## (pierce); front: the front row's units this % more hit points. cost: its price, in gold. region: only found in that
## place (LEVELS). school: the way of playing it is for (SCHOOLS) -- a nest is for none, its gift for several.
const BUILDINGS := {
	"nest_red": {"name": "红巢", "color": Color(0.9, 0.24, 0.2), "nest": "red", "cost": 3, "trait": "swarm"},
	"nest_blue": {"name": "蓝巢", "color": Color(0.24, 0.5, 0.96), "nest": "blue", "cost": 3, "trait": "cover"},
	"nest_green": {"name": "绿巢", "color": Color(0.3, 0.74, 0.3), "nest": "green", "cost": 4, "trait": "guard"},
	"nest_gold": {"name": "金巢", "color": Color(0.96, 0.74, 0.18), "nest": "gold", "cost": 6, "trait": "alone"},
	"nest_white": {"name": "白巢", "color": Color(0.93, 0.93, 0.9), "nest": "white", "cost": 4, "trait": "care"},
	"nest_scav": {"name": "拾荒巢", "color": Color(0.78, 0.66, 0.42), "nest": "scav", "cost": 4, "trait": "scavenge"},
	"nest_mutant": {"name": "变异巢", "color": Color(0.92, 0.45, 0.75), "nest": "mutant", "cost": 3, "trait": "mutant"},
	"pool": {"name": "培养池", "color": Color(0.32, 0.72, 0.58), "cost": 2, "school": "horde",
		"levels": [{"biomass": 3}, {"biomass": 5}, {"biomass": 8}]},
	"spore_pool": {"name": "孢子池", "color": Color(0.55, 0.7, 0.3), "cost": 3, "region": 0, "school": "horde",
		"levels": [{"biomass": 5}, {"biomass": 7}, {"biomass": 10}]},
	"horde_totem": {"name": "兽群图腾", "color": Color(0.7, 0.3, 0.25), "cost": 4, "school": "horde",
		"levels": [{"per": 6}, {"per": 5}, {"per": 4}]},
	"sampler": {"name": "采样站", "color": Color(0.72, 0.84, 0.95), "cost": 2, "school": "genes",
		"levels": [{"genes": 1}, {"genes": 2}, {"genes": 3}]},
	"stabilizer": {"name": "稳定器", "color": Color(0.55, 0.72, 0.95), "cost": 3, "school": "genes",
		"levels": [{"slots": 1}, {"slots": 1}, {"slots": 2}]},
	"gene_bank": {"name": "基因库", "color": Color(0.45, 0.85, 0.75), "cost": 3, "school": "genes",
		"levels": [{"gene_off": 1}, {"gene_off": 2}, {"gene_off": 3}]},
	"mine": {"name": "矿场", "color": Color(0.96, 0.84, 0.3), "cost": 3, "school": "gold",
		"levels": [{"gold": 1}, {"gold": 2}, {"gold": 3}]},
	"forge": {"name": "熔炉", "color": Color(0.75, 0.35, 0.15), "cost": 4, "region": 1, "school": "gold",
		"levels": [{"gold": 2}, {"gold": 3}, {"gold": 5}]},
	"vault": {"name": "金库", "color": Color(0.85, 0.7, 0.25), "cost": 3, "school": "gold",
		"levels": [{"interest": 2}, {"interest": 4}, {"interest": 6}]},
	"market": {"name": "商栈", "color": Color(0.85, 0.5, 0.3), "cost": 3, "school": "gold",
		"levels": [{"rerolls": 1}, {"rerolls": 1, "shelf": 1}, {"rerolls": 2, "shelf": 1}]},
	"champion_hall": {"name": "冠军殿", "color": Color(0.8, 0.65, 0.95), "cost": 4, "school": "elite",
		"levels": [{"elite": 15}, {"elite": 25}, {"elite": 40}]},
	"watchtower": {"name": "瞭望塔", "color": Color(0.5, 0.65, 0.85), "cost": 3, "school": "ranged",
		"levels": [{"ranged": 1}, {"ranged": 2}, {"ranged": 3}]},
	"vanguard": {"name": "前锋营", "color": Color(0.7, 0.55, 0.4), "cost": 3, "school": "front",
		"levels": [{"front": 30}, {"front": 60}, {"front": 100}]},
}

## The ways of playing a run (流派), each with what it builds on and what it comes to late.
const SCHOOLS := {
	"gold": {"name": "攒钱流", "says": "金币多、利息多、刷新便宜；攒够了造奇观"},
	"genes": {"name": "进化流", "says": "研究点数多、词条位多、词条便宜；凑配方进化"},
	"horde": {"name": "兽群流", "says": "生物质多，兵多；兵越多，全体越狠"},
	"elite": {"name": "精英流", "says": "巢升级选精英；精英越来越强"},
	"ranged": {"name": "远程流", "says": "蓝兵、酸液腺；远程的兵越打越狠"},
	"front": {"name": "前锋流", "says": "前排放肉；前排的兵越来越厚"},
}

## Gene affixes, stuck on a nest: every unit it makes carries them -- the only way a unit itself grows stronger.
const AFFIXES := {
	"shell": {"name": "甲壳", "color": Color(0.35, 0.38, 0.42), "armor": 1, "says": "护甲 +1"},
	"blade": {"name": "刀锋", "color": Color(0.85, 0.88, 0.92), "atk": 2, "says": "攻击 +2"},
	"acid": {"name": "酸液腺", "color": Color(0.55, 0.95, 0.25), "range": 5.0, "says": "变成远程，够得着 5 米"},
	"wings": {"name": "翅膀", "color": Color(0.85, 0.75, 0.55), "dive": true, "says": "会飞，越过前排去打后排"},
	"plasma": {"name": "电浆囊", "color": Color(0.3, 0.9, 1.0), "splash": 1.5, "says": "一打一片（旁边 1.5 米挨一半）"},
	"poison": {"name": "毒刺", "color": Color(0.62, 0.92, 0.2), "pierce": 2, "says": "每下多 2 点伤害，不管护甲"},
	"flame": {"name": "火焰", "color": Color(1.0, 0.45, 0.1), "atk": 1, "splash": 1.2, "says": "攻击 +1，一打一片（1.2 米）"},
	"haste": {"name": "急速腺", "color": Color(1.0, 0.85, 0.25), "haste": 30, "says": "打得快 30%"},
	"hide": {"name": "厚皮", "color": Color(0.55, 0.45, 0.35), "hp": 40, "says": "血多 40%"},
	"horn": {"name": "冲锋角", "color": Color(0.95, 0.92, 0.8), "charge": true, "says": "开战第一下打双倍"},
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
	"hoarder": {"name": "囤囤", "kind": "偷蛋龙", "diet": "meat", "rarity": 0, "price": 4, "eat": 1, "keep": 3,
		"model": "ornitholestes", "back": Color(0.95, 0.55, 0.2), "belly": Color(0.98, 0.9, 0.7), "says": "替你留 3 张牌，买下来先不用"},
	"mother": {"name": "慈母", "kind": "慈母龙", "diet": "plant", "rarity": 0, "price": 4, "eat": 1, "first_free": 1,
		"model": "edmontosaurus", "back": Color(0.55, 0.72, 0.42), "belly": Color(0.96, 0.92, 0.75), "says": "每轮第一个巢多孵 1 只，这只不吃生物质"},
	"trader": {"name": "飞飞", "kind": "翼龙", "diet": "meat", "rarity": 0, "price": 4, "eat": 1, "shelf": 1,
		"model": "harpactognathus", "back": Color(0.3, 0.6, 0.85), "belly": Color(0.95, 0.92, 0.8), "says": "飞去远处进货：商店每轮多摆 1 样"},
	"scout": {"name": "快腿", "kind": "盗龙", "diet": "meat", "rarity": 0, "price": 4, "eat": 1, "rerolls": 1,
		"model": "dakotaraptor", "back": Color(0.45, 0.55, 0.3), "belly": Color(0.9, 0.86, 0.66), "says": "每轮第一次刷新商店不要钱"},
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
	"goldcrown": {"name": "金冠", "kind": "冠龙", "diet": "meat", "rarity": 3, "price": 14, "eat": 3, "gold": 6, "shelf": -1,
		"model": "dilong", "back": Color(0.95, 0.75, 0.25), "belly": Color(1.0, 0.95, 0.75), "says": "每轮多 6 金；但商店少摆 1 样"},
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

## What the shop can offer (GAME-DESIGN 18, 19, 22) -- only what lasts, nothing used up at once -- as cards of the
## player's deck (DECK). type "build": a building, on an open plot of its part of the homeland -- an empty one, or one
## with another building, pulled down for half its price back; "raise": a building one level up, for RAISE gold more
## than its level (a nest's raise is a choice); "affix": a gene affix on a nest with a free place. price: in gold (a
## building's is its own); genes: the research points (研究点数) it costs too. from: the place (0-based) from which the
## shop can offer it; region: only in that place. rarity: 0 common, 1 uncommon, 2 rare -- how often it comes as a
## reward. A card upgraded (+): a building put down at level 2 (a nest choosing its raise); a raise PLUS_RAISE gold
## cheaper; an affix costing no research points.
const OFFERS := {
	"b_red": {"type": "build", "rarity": 0, "builds": "nest_red"},
	"b_blue": {"type": "build", "rarity": 0, "builds": "nest_blue"},
	"b_green": {"type": "build", "rarity": 1, "builds": "nest_green"},
	"b_gold": {"type": "build", "rarity": 2, "builds": "nest_gold", "from": 1},
	"b_white": {"type": "build", "rarity": 1, "builds": "nest_white"},
	"b_scav": {"type": "build", "rarity": 1, "builds": "nest_scav"},
	"b_mutant": {"type": "build", "rarity": 1, "builds": "nest_mutant"},
	"b_pool": {"type": "build", "rarity": 0, "builds": "pool"},
	"b_spore": {"type": "build", "rarity": 0, "builds": "spore_pool", "region": 0},
	"b_totem": {"type": "build", "rarity": 1, "builds": "horde_totem"},
	"b_sampler": {"type": "build", "rarity": 0, "builds": "sampler"},
	"b_stab": {"type": "build", "rarity": 1, "builds": "stabilizer"},
	"b_genebank": {"type": "build", "rarity": 1, "builds": "gene_bank"},
	"b_mine": {"type": "build", "rarity": 0, "builds": "mine"},
	"b_forge": {"type": "build", "rarity": 1, "builds": "forge", "region": 1},
	"b_vault": {"type": "build", "rarity": 1, "builds": "vault"},
	"b_market": {"type": "build", "rarity": 1, "builds": "market"},
	"b_hall": {"type": "build", "rarity": 1, "builds": "champion_hall"},
	"b_tower": {"type": "build", "rarity": 1, "builds": "watchtower"},
	"b_vanguard": {"type": "build", "rarity": 1, "builds": "vanguard"},
	"raise": {"type": "raise", "name": "扩建", "rarity": 0},
	"a_shell": {"type": "affix", "price": 2, "genes": 2, "rarity": 0, "affix": "shell"},
	"a_blade": {"type": "affix", "price": 2, "genes": 2, "rarity": 0, "affix": "blade"},
	"a_haste": {"type": "affix", "price": 2, "genes": 2, "rarity": 0, "affix": "haste"},
	"a_hide": {"type": "affix", "price": 2, "genes": 2, "rarity": 0, "affix": "hide"},
	"a_horn": {"type": "affix", "price": 2, "genes": 2, "rarity": 1, "affix": "horn"},
	"a_acid": {"type": "affix", "price": 3, "genes": 3, "rarity": 1, "affix": "acid"},
	"a_wings": {"type": "affix", "price": 3, "genes": 3, "rarity": 2, "affix": "wings", "from": 1},
	"a_plasma": {"type": "affix", "price": 3, "genes": 4, "rarity": 2, "affix": "plasma", "from": 1},
	"a_poison": {"type": "affix", "price": 2, "genes": 2, "rarity": 0, "affix": "poison", "region": 0},
	"a_flame": {"type": "affix", "price": 3, "genes": 3, "rarity": 1, "affix": "flame", "region": 1},
}
## The deck (牌库) a run starts with -- the common goods, the plainest twice; the shop draws its shelf from it. Rarer
## cards come only as rewards: after each round, one of REWARDS added, or REWARD_GOLD taken instead. After a place's
## mini-boss the deck can be cut -- CUT gold a card, CUT_STEP more each time -- and cards upgraded, UPGRADE research
## points each.
const DECK := ["b_red", "b_red", "b_blue", "b_pool", "b_pool", "b_spore", "b_sampler", "b_mine", "raise", "raise",
	"a_shell", "a_blade", "a_haste", "a_hide", "a_poison"]
const REWARDS := 3
const REWARD_GOLD := 3
const CUT := 3
const CUT_STEP := 1
const UPGRADE := 3
const PLUS_RAISE := 2             # gold off an upgraded raise
const SHOP := 5                   # offers on the shelf each round (and a star dinosaur after them)
const REROLL := 1                 # gold to stock the shelf again; one more each time in a round
const RAISE := 2                  # a raise costs this much more than the building's level
const INTEREST_STEP := 5          # each this much gold kept to a round's end brings one more...
const INTEREST_MAX := 2           # ...up to this much
const WIN_GOLD := 2               # gold for a battle won

const TYPES := {"build": "建筑", "raise": "升级", "affix": "基因词条"}
const DIETS := {"plant": "草食", "meat": "肉食"}
const RARITY_NAMES := ["普通", "少见", "稀有", "传说"]

## What every place's homeland starts with ([kind, level]): the same for everyone, the run's start too (the player,
## 2026-10-20: "先不选"); nothing else is carried from place to place but the stars, the gold, the deck and the
## research points ("先不要带任何东西，往少了做").
const LANDING := [["nest_red", 1], ["pool", 1]]
const FIRST_STOCK := {"gold": 0, "biomass": 3, "genes": 2}

## A run (GAME-DESIGN 22): TIERS big levels of ROUNDS rounds each (half an hour or so). The first is always the
## rainforest; for each after it the map offers two places (Run.map), one to pick. A level's monsters are as strong as
## its tier (TIER_POWER), wherever it is; each wave is SHARE of LIMIT strong for its tier -- the second level's the
## smallest: there the calm curve (LIMIT) outruns the armies of runs that fight the most (by mid-level they stand at
## about three quarters of it, where in the first and the third they stand at nine tenths and more). A later level's
## first rounds come weaker still (EASE): its homeland starts again from a red nest and a pool, where the calm runs that
## LIMIT was measured from had kept all their biomass. (2026-10-21, 48 runs by school each time: with the first SHARE
## at 0.66 and no EASE 26 held all three, most falling in the first rainforest's last rounds and in the first rounds of
## the levels after it; as now 38, none in the rainforest, most of the rest in the third level's third and fourth.)
const TIERS := 3
const ROUNDS := 12
const TIER_POWER := [1.0, 1.25, 1.5]
const SHARE := [0.6, 0.43, 0.46]
const EASE := [0.8, 0.85, 0.9, 0.95]   # a later level's rounds 1 to 4, of what SHARE would make them

## The places a run goes to -- each a big level, the rounds of MINI_ROUNDS against its `minis` in turn, the last
## against its `boss`. mix: which kinds come, [kind, share, from which round]. terrain: how many of each special plot
## (TERRAIN) lie about, behind the battle line -- what makes one place's homeland unlike another's (the player,
## 2026-10-20: "先只用地形differenciate"; the places' rules, damp, ash and the rest, are gone). ground, grass: the homeland's
## earth and the land round it; sky: [top, horizon]; color: on the map.
const LEVELS := [
	{"name": "雨林", "boss": "boss_rain", "minis": ["mini_rain", "mini_rain2"],
		"terrain": {"pond": 3, "tree": 2}, "ground": Color(0.42, 0.36, 0.26), "grass": Color(0.24, 0.42, 0.2),
		"sky": [Color(0.36, 0.55, 0.82), Color(0.74, 0.82, 0.88)], "color": Color(0.36, 0.62, 0.32),
		"mix": [["grey", 0.3, 1], ["spore", 0.45, 1], ["purple", 0.25, 2]]},
	{"name": "火山", "boss": "boss_lava", "minis": ["mini_lava", "mini_lava2"],
		"terrain": {"ore": 3, "lava": 2}, "ground": Color(0.36, 0.3, 0.27), "grass": Color(0.32, 0.28, 0.24),
		"sky": [Color(0.42, 0.4, 0.44), Color(0.82, 0.62, 0.48)], "color": Color(0.85, 0.36, 0.18),
		"mix": [["grey", 0.2, 1], ["beetle", 0.45, 1], ["salamander", 0.35, 1]]},
	{"name": "沼泽", "boss": "boss_bog", "minis": ["mini_bog", "mini_bog2"],
		"terrain": {"mire": 3, "toadstool": 2}, "ground": Color(0.32, 0.29, 0.21), "grass": Color(0.22, 0.29, 0.17),
		"sky": [Color(0.38, 0.44, 0.4), Color(0.66, 0.7, 0.58)], "color": Color(0.46, 0.52, 0.3),
		"mix": [["grey", 0.2, 1], ["leech", 0.45, 1], ["moth", 0.35, 2]]},
	{"name": "冰原", "boss": "boss_ice", "minis": ["mini_ice", "mini_ice2"],
		"terrain": {"ice_ore": 3, "glacier": 2}, "ground": Color(0.3, 0.34, 0.42), "grass": Color(0.7, 0.75, 0.81),
		"sky": [Color(0.46, 0.57, 0.74), Color(0.74, 0.8, 0.86)], "color": Color(0.6, 0.78, 0.95),
		"mix": [["grey", 0.2, 1], ["frostfang", 0.45, 1], ["shard", 0.35, 2]]},
	{"name": "荒漠", "boss": "boss_sand", "minis": ["mini_sand", "mini_sand2"],
		"terrain": {"oasis": 3, "ruin": 2}, "ground": Color(0.6, 0.48, 0.32), "grass": Color(0.8, 0.68, 0.46),
		"sky": [Color(0.42, 0.6, 0.85), Color(0.95, 0.85, 0.66)], "color": Color(0.9, 0.72, 0.4),
		"mix": [["grey", 0.2, 1], ["sandworm", 0.45, 1], ["scorpion", 0.35, 2]]},
	{"name": "海岸", "boss": "boss_sea", "minis": ["mini_sea", "mini_sea2"],
		"terrain": {"tidepool": 3, "wreck": 2}, "ground": Color(0.58, 0.52, 0.4), "grass": Color(0.2, 0.42, 0.52),
		"sky": [Color(0.34, 0.56, 0.84), Color(0.78, 0.88, 0.92)], "color": Color(0.3, 0.6, 0.78),
		"mix": [["grey", 0.2, 1], ["crab", 0.45, 1], ["jelly", 0.35, 2]]},
]
## Special plots, all behind the battle line: build: whether a building can go on it; like: which of the four ways it
## works (a pond's, an old tree's, a vein of ore's, a lava pool's) -- each place has its own two.
const TERRAIN := {
	"pond": {"name": "水塘", "build": true, "like": "pond", "color": Color(0.3, 0.55, 0.75),
		"says": "培养池、孢子池造在这里，生物质翻倍"},
	"tree": {"name": "古树", "build": false, "like": "tree", "color": Color(0.2, 0.36, 0.15),
		"says": "不能造。旁边的采样站每轮多 1 研究点数"},
	"ore": {"name": "矿脉", "build": true, "like": "ore", "color": Color(0.4, 0.37, 0.34), "says": "矿场、熔炉造在这里，金币 +2"},
	"lava": {"name": "岩浆", "build": false, "like": "lava", "color": Color(0.85, 0.3, 0.08),
		"says": "不能造。旁边的矿场、熔炉每轮多 1 金币"},
	"mire": {"name": "泥塘", "build": true, "like": "pond", "color": Color(0.3, 0.34, 0.22),
		"says": "培养池、孢子池造在这里，生物质翻倍"},
	"toadstool": {"name": "毒菇林", "build": false, "like": "tree", "color": Color(0.58, 0.36, 0.52),
		"says": "不能造。旁边的采样站每轮多 1 研究点数"},
	"ice_ore": {"name": "冰矿", "build": true, "like": "ore", "color": Color(0.62, 0.74, 0.84), "says": "矿场、熔炉造在这里，金币 +2"},
	"glacier": {"name": "冰封遗骸", "build": false, "like": "tree", "color": Color(0.8, 0.88, 0.94),
		"says": "不能造。旁边的采样站每轮多 1 研究点数"},
	"oasis": {"name": "绿洲", "build": true, "like": "pond", "color": Color(0.28, 0.6, 0.55),
		"says": "培养池、孢子池造在这里，生物质翻倍"},
	"ruin": {"name": "遗迹", "build": false, "like": "tree", "color": Color(0.7, 0.62, 0.46),
		"says": "不能造。旁边的采样站每轮多 1 研究点数"},
	"tidepool": {"name": "潮池", "build": true, "like": "pond", "color": Color(0.24, 0.5, 0.64),
		"says": "培养池、孢子池造在这里，生物质翻倍"},
	"wreck": {"name": "沉船", "build": false, "like": "lava", "color": Color(0.42, 0.33, 0.24),
		"says": "不能造。旁边的矿场、熔炉每轮多 1 金币"},
}

## The strength a player's army comes to at each round of the run (the levels one after another) when no one comes,
## every battle is won and everything goes to growing -- for the middle school of the six (the median of each school's
## average, so one school growing far past the rest does not make every wave too strong for the others), over runs
## keeping to each school, measured by tools/sim_runs.gd (school ... limit; tools/limit.py). Each level starts lower:
## the homeland starts again from a red nest and a pool (the biomass kept and the stars help the first armies). Measured
## again 2026-10-20 with the stars, no ark, nothing carried and no places' rules (GAME-DESIGN 24). Measure again after
## changing what can be built or made.
const LIMIT := [32, 47, 74, 94, 126, 153, 197, 240, 311, 380, 455, 522,
	142, 202, 301, 363, 433, 554, 632, 699, 784, 856, 916, 960,
	250, 426, 554, 696, 826, 902, 1004, 1083, 1226, 1313, 1444, 1685]
const BIG_ROUNDS := [4, 8, 12]          # a big wave, with the place's mini-boss or boss: BIG times as strong as the round
const BIG := 1.15                       # would be
const MINI_ROUNDS := [4, 8]             # the rounds against the place's mini-bosses; after each, the deck worked on
## How dangerous a wave looks to the player (GAME-DESIGN 22), by its strength: one skull below the first of these, one
## more past each -- a feel for it, not whether it will be won (that is worked out only for the tools and F3).
const DANGER := [45.0, 90.0, 175.0, 320.0, 560.0]


## An offer's numbers (oi: a shelf's or stash's {id, plus}): its name, price, type and what it goes on. A raise's price
## is RAISE more than the level of what it raises (Home.price); here, the least it can be.
static func offer(oi: Dictionary) -> Dictionary:
	var o: Dictionary = OFFERS[oi.id].duplicate(true)
	o.id = oi.id
	o.plus = bool(oi.get("plus", false))
	o.target = {"build": "tile", "raise": "building", "affix": "nest"}.get(o.type, "none")
	match o.type:
		"build":
			o.name = Lang.t(BUILDINGS[o.builds].name)
			o.price = int(BUILDINGS[o.builds].cost)
		"raise":
			o.price = RAISE + 1
			o.name = Lang.t(str(o.name))
		"affix":
			o.name = Lang.t(AFFIXES[o.affix].name)
	if o.plus:
		o.name += "+"
		match o.type:
			"raise":
				o.price = maxi(1, int(o.price) - PLUS_RAISE)
			"affix":
				o.genes = 0
	return o



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
			return Lang.t("每轮产 %d 生物质") % l.biomass
		"horde_totem":
			return Lang.t("出战的兵每满 %d 只，所有兵攻击 +1") % l.per
		"sampler":
			return Lang.t("每轮产 %d 研究点数。旁边每有一个培养池，再多 %d") % [l.genes, SAMPLER_POOL]
		"stabilizer":
			return Lang.t("同一列的巢能多贴 %d 个词条") % l.slots
		"gene_bank":
			return Lang.t("贴词条少花 %d 研究点数") % l.gene_off
		"mine", "forge":
			return Lang.t("每轮多 %d 金币") % l.gold
		"vault":
			return Lang.t("利息最多多 %d（每存 %d 金，利息 +1）") % [l.interest, INTEREST_STEP]
		"market":
			return Lang.t("每轮头两次刷新不要钱" if int(l.rerolls) > 1 else "每轮第一次刷新不要钱") \
				+ (Lang.t("，商店多摆 1 样") if l.has("shelf") else "")
		"champion_hall":
			return Lang.t("所有精英兵的血和攻击再 +%d%%") % l.elite
		"watchtower":
			return Lang.t("所有远程兵（够得着 3 米以上）每下多 %d 点伤害，不管护甲") % l.ranged
		"vanguard":
			return Lang.t("前排的兵血 +%d%%") % l.front
	return ""


## What a building does at a level, in short -- what changes when it is raised: for a nest, the choice.
static func level_text(kind: String, lv: int) -> String:
	if BUILDINGS[kind].has("nest"):
		return Lang.t("二选一：多孵 1 只，或者变精英（血 ×%s、攻击 ×%s、大一号）") % [_num(ELITE_HP), _num(ELITE_ATK)]
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
			if o.plus:
				text = Lang.t("放下就是 2 级（多孵或精英，二选一）。" if b.has("nest") else "放下就是 2 级。") + text
			if o.has("level"):
				var sp := species(b.get("nest", ""), o.affixes)
				text = Lang.t("%d 级。") % lv + (Lang.t("孵%s。") % Lang.t(UNITS[sp.kind].name) if b.has("nest") \
					else building_text(o.builds, lv) + stop)
				if not o.affixes.is_empty():
					text += Lang.t("贴着") + Lang.t("、").join(o.affixes.map(func(a: String) -> String: return Lang.t(AFFIXES[a].name))) + stop
			return text
		"raise":
			return (Lang.t("便宜 %d 金。") % PLUS_RAISE if o.plus else "") \
				+ Lang.t("一座建筑升一级（最多 %d 级）。巢升级二选一：多孵 1 只，或变精英。") % LEVEL_MAX
		"affix":
			var a: Dictionary = AFFIXES[o.affix]
			var also := ""
			for r in RECIPES:
				if o.affix in r.affixes:
					also = Lang.t("能凑配方。")
			return (Lang.t("不花研究点数。") if o.plus else "") + Lang.t("孵的兵%s。%s") % [Lang.t(a.says), also]
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
	return s


## A fighter's strength, from its numbers (unit_stats, enemy_stats, or a Fight fighter with `max` for its full health).
static func strength(s: Dictionary, power := 1.0) -> float:
	var hp := float(s.get("max", s.hp))
	var armor := float(s.get("armor", 0))
	var take := hp * TYPICAL_HIT / maxf(1.0, TYPICAL_HIT - armor) * (1.0 + REACH_WORTH if float(s.range) >= 3.0 else 1.0)
	if s.get("dive", false):
		take *= 1.0 + DIVE_WORTH
	var deal := (float(s.atk) + float(s.get("pierce", 0))) / float(s.every) * (1.0 + SPLASH_WORTH * float(s.get("splash", 0.0))) \
		+ HEAL_WORTH * float(s.get("heal", 0)) / float(s.every) + BURST_WORTH * float(s.get("burst", 0)) \
		+ (CHARGE_WORTH * float(s.atk) if s.get("charge", false) else 0.0)
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
	if tier > 0 and r <= EASE.size():
		budget *= float(EASE[r - 1])
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
