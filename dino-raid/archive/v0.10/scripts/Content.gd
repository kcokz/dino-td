class_name Content
## What there is to build, make and fight (GAME-DESIGN 19) -- coloured blocks standing in for the gene ark's creatures
## and the alien monsters of each place it lands. The systems (Home, Fight, Run) read only this: change what is here
## and they follow.

## Units the nests make -- for one round only. hp; atk, each hit; every: seconds between hits; range, metres; speed,
## metres a second; armor: taken off each hit it takes; splash: metres round its mark that also take half; heal: hit
## points it gives the most hurt friend in reach (instead of hitting); pierce: damage more each hit, armour or not;
## burst: damage to the other side round it (BURST_RADIUS) when it falls; dive: flies over the front for the back;
## size: the block's edge; food: biomass it takes to make. Four are species a nest evolves into (RECIPES); the titan
## comes with a wonder.
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
	"falcon": {"name": "猎鹰兽", "color": Color(0.95, 0.5, 0.2), "hp": 22, "atk": 7, "every": 0.9, "range": 1.4,
		"speed": 4.0, "size": 1.0, "dive": true, "food": 2, "role": "进化来的：飞过前排，专咬后排"},
	"thunder": {"name": "雷甲兽", "color": Color(0.35, 0.6, 0.95), "hp": 34, "atk": 4, "every": 1.3, "range": 1.6,
		"speed": 2.2, "size": 1.3, "armor": 1, "splash": 1.5, "food": 2, "role": "进化来的：又硬，又电一圈"},
	"miasma": {"name": "毒雾兽", "color": Color(0.55, 0.85, 0.3), "hp": 10, "atk": 3, "every": 1.0, "range": 5.0,
		"speed": 2.4, "size": 0.95, "pierce": 2, "splash": 1.2, "food": 2, "role": "进化来的：远处喷毒雾，不管护甲"},
	"magma": {"name": "熔岩兽", "color": Color(0.92, 0.32, 0.12), "hp": 30, "atk": 8, "every": 1.3, "range": 1.6,
		"speed": 2.4, "size": 1.25, "burst": 8, "food": 2, "role": "进化来的：重击，倒下时炸一圈"},
	"titan": {"name": "巨兽", "color": Color(0.55, 0.42, 0.3), "hp": 70, "atk": 9, "every": 1.6, "range": 1.8,
		"speed": 2.0, "size": 2.0, "armor": 1, "splash": 1.5, "food": 0, "role": "巨兽笼里放出来的：又大又狠"},
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
const CLUSTER := 2                # a nest with at least this many neighbours of its kind makes one more
const SAMPLER_POOL := 1           # genes more a round for each culture pool beside a sampler
const TREE_GENES := 1             # genes more a round for a sampler beside an old tree
const LAVA_GOLD := 1              # gold more a round for a mine or forge beside lava

## Buildings. A nest makes `nest` units. Each level of the others may give: biomass, genes, gold: that much more each
## round; slots: nests of its column can carry this many more affixes; gene_off: each affix this many genes cheaper;
## interest: the most interest this much more; rerolls: restocks of the shelf free each round; shelf: offers more on
## it; per: every this many units in an army, all of them +1 attack; elite: elite units' hit points and attack this %
## more; ranged: units reaching 3 m or more this much more damage each hit, armour or not (pierce); front: the front
## row's units this % more hit points. cost: its price, in gold. region: only found in that place (LEVELS). school:
## the way of playing it is for (SCHOOLS).
const BUILDINGS := {
	"nest_red": {"name": "红巢", "color": Color(0.9, 0.24, 0.2), "nest": "red", "cost": 3},
	"nest_blue": {"name": "蓝巢", "color": Color(0.24, 0.5, 0.96), "nest": "blue", "cost": 3},
	"nest_green": {"name": "绿巢", "color": Color(0.3, 0.74, 0.3), "nest": "green", "cost": 4},
	"nest_gold": {"name": "金巢", "color": Color(0.96, 0.74, 0.18), "nest": "gold", "cost": 6},
	"nest_white": {"name": "白巢", "color": Color(0.93, 0.93, 0.9), "nest": "white", "cost": 4},
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
		"levels": [{"elite": 30}, {"elite": 50}, {"elite": 80}]},
	"watchtower": {"name": "瞭望塔", "color": Color(0.5, 0.65, 0.85), "cost": 3, "school": "ranged",
		"levels": [{"ranged": 1}, {"ranged": 2}, {"ranged": 3}]},
	"vanguard": {"name": "前锋营", "color": Color(0.7, 0.55, 0.4), "cost": 3, "school": "front",
		"levels": [{"front": 30}, {"front": 60}, {"front": 100}]},
}

## The ways of playing a run (流派), each with what it builds on and what it comes to late.
const SCHOOLS := {
	"gold": {"name": "攒钱流", "says": "金币多、利息多、刷新便宜；攒够了造奇观"},
	"genes": {"name": "进化流", "says": "基因多、词条位多、词条便宜；凑配方进化"},
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

## Wonders (奇观): WONDERS_OFFERED of them on offer from a run's start, to be seen all along; one can be built, for
## much gold -- where saving gold leads. It goes with the ark from place to place.
const WONDERS := {
	"brood": {"name": "母巢", "price": 18, "color": Color(0.85, 0.35, 0.35), "says": "每个巢每轮多孵 1 只"},
	"gold_city": {"name": "黄金城", "price": 14, "color": Color(1.0, 0.82, 0.3), "says": "每轮多 6 金币"},
	"evo_tower": {"name": "进化之塔", "price": 16, "color": Color(0.45, 0.9, 0.8), "says": "每个巢多 1 个词条位；贴词条不要基因"},
	"banner": {"name": "万兽战旗", "price": 20, "color": Color(0.85, 0.3, 0.6), "says": "所有兵攻击 +2，血 +25%"},
	"titan": {"name": "巨兽笼", "price": 20, "color": Color(0.55, 0.42, 0.3), "says": "每轮多一只巨兽出战，站前排正中"},
}
const WONDERS_OFFERED := 2


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

## What the shop can offer (GAME-DESIGN 18, 19) -- only what lasts, nothing used up at once. type "build": a building,
## on an open plot of its part of the homeland -- an empty one, or one with another building, pulled down for half its
## price back; "raise": a building one level up, for RAISE gold more than its level (a nest's raise is a choice);
## "affix": a gene affix on a nest with a free place. price: in gold (a building's is its own); genes, alien: what else
## it costs. from: the place (0-based) from which the shop can offer it; region: only in that place. rarity: 0 often, 1
## sometimes, 2 seldom.
const OFFERS := {
	"b_red": {"type": "build", "rarity": 0, "builds": "nest_red"},
	"b_blue": {"type": "build", "rarity": 0, "builds": "nest_blue"},
	"b_green": {"type": "build", "rarity": 1, "builds": "nest_green"},
	"b_gold": {"type": "build", "rarity": 2, "builds": "nest_gold", "from": 1},
	"b_white": {"type": "build", "rarity": 1, "builds": "nest_white"},
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
	"a_acid": {"type": "affix", "price": 3, "genes": 2, "alien": 1, "rarity": 1, "affix": "acid"},
	"a_wings": {"type": "affix", "price": 3, "genes": 2, "alien": 1, "rarity": 2, "affix": "wings", "from": 1},
	"a_plasma": {"type": "affix", "price": 3, "genes": 3, "alien": 1, "rarity": 2, "affix": "plasma", "from": 1},
	"a_poison": {"type": "affix", "price": 2, "genes": 2, "rarity": 0, "affix": "poison", "region": 0},
	"a_flame": {"type": "affix", "price": 3, "genes": 2, "alien": 1, "rarity": 1, "affix": "flame", "region": 1},
}
const SHOP := 5                   # offers on the shelf each round
const STASH := 4                  # goods kept (bought or given or packed) at most
const REROLL := 1                 # gold to stock the shelf again; one more each time in a round
const REMOVES := 1                # kinds of offer that can be taken out of the shop each round, for the rest of the run
const RAISE := 2                  # a raise costs this much more than the building's level
const INTEREST_STEP := 5          # each this much gold kept to a round's end brings one more...
const INTEREST_MAX := 2           # ...up to this much
const WIN_GOLD := 2               # gold for a battle won

const TYPES := {"build": "建筑", "raise": "升级", "affix": "基因词条"}

## Relics: when a place is held, one of three is chosen (two fossils and a boss's); each helps for the rest of the run.
## A boss's is strong but costs something too.
const RELICS := {
	"amber": {"name": "琥珀", "color": Color(0.95, 0.65, 0.2), "says": "商店每轮多摆 1 样"},
	"tooth": {"name": "霸王龙的牙", "color": Color(0.95, 0.92, 0.85), "says": "贴词条少花 1 基因"},
	"frill": {"name": "三角龙的颈盾", "color": Color(0.75, 0.6, 0.45), "says": "家园血 +10，每轮回 1 血"},
	"ammonite": {"name": "菊石", "color": Color(0.85, 0.7, 0.5), "says": "利息最多多 2"},
	"coprolite": {"name": "粪化石", "color": Color(0.5, 0.4, 0.3), "says": "每轮生物质 +3"},
	"wood": {"name": "硅化木", "color": Color(0.7, 0.55, 0.4), "says": "造建筑便宜 1 金币"},
	"trilobite": {"name": "三叶虫", "color": Color(0.55, 0.6, 0.65), "says": "每轮第一次刷新商店不要钱"},
	"egg": {"name": "恐龙蛋化石", "color": Color(0.9, 0.85, 0.75), "says": "每轮第一个巢多孵 1 只，不吃生物质"},
	"core": {"name": "母虫的核", "color": Color(0.4, 0.55, 0.2), "boss": true, "says": "每个巢多孵 1 只；但生物质产量少三成"},
	"heart": {"name": "熔岩之心", "color": Color(0.85, 0.25, 0.1), "boss": true, "says": "每个巢多 1 个词条位；但家园每轮掉 1 血"},
	"crystal": {"name": "古老的晶簇", "color": Color(0.6, 0.45, 0.85), "boss": true, "says": "每轮多 4 金币；但商店少摆 1 样"},
	"sac": {"name": "虫后的卵囊", "color": Color(0.85, 0.75, 0.6), "boss": true, "says": "存货多 2 格；但送货只剩二选一"},
}

## The arks a run can start with: what stands in the first place ([kind, level] -- a nest's levels each one more a
## round), what it carries.
const ARKS := {
	"war": {"name": "战斗方舟", "says": "开局：2 级红巢、培养池。带着霸王龙的牙（贴词条少花 1 基因）", "relic": "tooth",
		"gold": 0, "buildings": [["nest_red", 2], ["pool", 1]]},
	"brood": {"name": "繁殖方舟", "says": "开局：红巢、两座培养池。带着恐龙蛋化石", "relic": "egg", "gold": 0,
		"buildings": [["nest_red", 1], ["pool", 1], ["pool", 1]]},
	"trade": {"name": "商队方舟", "says": "开局：红巢、培养池、矿场，多 5 金币。带着琥珀", "relic": "amber", "gold": 5,
		"buildings": [["nest_red", 1], ["pool", 1], ["mine", 1]]},
}
## What the ark itself sets down wherever it lands, besides what was packed.
const LANDING := [["nest_red", 1], ["pool", 1]]
const FIRST_STOCK := {"gold": 0, "biomass": 3, "genes": 2}

## The places a run's ark lands in, in order -- each a big level of `rounds` small ones, the last against its `boss`.
## Each wave is `share` of LIMIT strong; `power` times as strong one by one; `mix`: which kinds come, [kind, share, from
## which round]. rule: what is different there (RULES). terrain: how many of each special plot (TERRAIN) lie about,
## behind the battle line.
const LEVELS := [
	{"name": "雨林", "rounds": 5, "power": 1.0, "share": 0.7, "boss": "boss_rain", "rule": "damp",
		"terrain": {"pond": 3, "tree": 2}, "ground": Color(0.42, 0.36, 0.26), "grass": Color(0.24, 0.42, 0.2),
		"mix": [["grey", 0.3, 1], ["spore", 0.45, 1], ["purple", 0.25, 2]]},
	{"name": "火山", "rounds": 5, "power": 1.25, "share": 0.68, "boss": "boss_lava", "rule": "ash",
		"terrain": {"ore": 3, "lava": 2}, "ground": Color(0.36, 0.3, 0.27), "grass": Color(0.32, 0.28, 0.24),
		"mix": [["grey", 0.2, 1], ["beetle", 0.45, 1], ["salamander", 0.35, 1]]},
]
const RULES := {
	"damp": {"name": "潮湿", "says": "生物质产量多五成，但存着的生物质每轮烂掉一半"},
	"ash": {"name": "火山灰", "says": "升级便宜 1 金币，但家园每轮掉 1 血"},
}
## Special plots, all behind the battle line: build: whether a building can go on it.
const TERRAIN := {
	"pond": {"name": "水塘", "build": true, "color": Color(0.3, 0.55, 0.75), "says": "培养池、孢子池造在这里，生物质翻倍"},
	"tree": {"name": "古树", "build": false, "color": Color(0.2, 0.36, 0.15), "says": "不能造。旁边的采样站每轮多 1 基因"},
	"ore": {"name": "矿脉", "build": true, "color": Color(0.4, 0.37, 0.34), "says": "矿场、熔炉造在这里，金币 +2"},
	"lava": {"name": "岩浆", "build": false, "color": Color(0.85, 0.3, 0.08), "says": "不能造。旁边的矿场、熔炉每轮多 1 金币"},
}

## The strength a player's army comes to at each round of the run (the places one after another) when no one comes,
## every battle is won and everything goes to growing -- on average, over runs keeping to each school, measured by
## tools/sim_runs.gd (school ... limit). Measure again after changing what can be built or made.
const LIMIT := [27, 42, 60, 79, 106, 106, 141, 216, 331, 422]
const BIG_ROUNDS := [5]                 # a big wave, with the place's boss: BIG times as strong as the round would be
const BIG := 1.15


## An offer's numbers (oi: a shelf's or stash's {id, gift, packed}): its name, price, type and what it goes on. A
## raise's price is RAISE more than the level of what it raises (Home.price); here, the least it can be. A packed
## building keeps its level, its nest's choices and its affixes (level, path, affixes).
static func offer(oi: Dictionary) -> Dictionary:
	var o: Dictionary = OFFERS[oi.id].duplicate(true)
	o.id = oi.id
	o.target = {"build": "tile", "raise": "building", "affix": "nest"}.get(o.type, "none")
	match o.type:
		"build":
			o.name = BUILDINGS[o.builds].name
			o.price = int(BUILDINGS[o.builds].cost)
			if oi.has("packed"):
				var pk: Dictionary = oi.packed
				o.level = int(pk.level)
				o.path = pk.get("path", []).duplicate()
				o.affixes = pk.affixes.duplicate()
				var bits: Array = ["%d 级" % pk.level]
				if o.path.count("elite") > 0:
					bits.append("精英" + ("×%d" % o.path.count("elite") if o.path.count("elite") > 1 else ""))
				bits.append_array(pk.affixes.map(func(a: String) -> String: return AFFIXES[a].name))
				o.name += "（%s）" % "，".join(bits)
		"raise":
			o.price = RAISE + 1
		"affix":
			o.name = AFFIXES[o.affix].name
	return o


## What a good cost, all told: its price (and half its genes, twice its alien genes, in gold); for a packed building,
## its raises and its affixes too. The goods worth most are what the ark carries on unless the player says otherwise.
static func worth(oi: Dictionary) -> float:
	var o := offer(oi)
	var n := float(o.get("price", 0)) + 0.5 * float(o.get("genes", 0)) + 2.0 * float(o.get("alien", 0))
	if oi.has("packed"):
		for lv in range(1, int(oi.packed.level)):
			n += RAISE + lv
		for a in oi.packed.affixes:
			n += worth({"id": "a_" + a})
	return n


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
		var u: Dictionary = UNITS[b.nest]
		return "每轮孵 1 只%s（每只吃 %d 生物质），只能造在阵地上：它的兵打仗时就站在这里。旁边有 %d 个%s，多孵 1 只" % [
			u.name, u.food, CLUSTER, b.name]
	var l := level(kind, lv)
	match kind:
		"pool", "spore_pool":
			return "每轮产 %d 生物质" % l.biomass
		"horde_totem":
			return "出战的兵每满 %d 只，所有兵攻击 +1" % l.per
		"sampler":
			return "每轮产 %d 基因。旁边每有一个培养池，再多 %d" % [l.genes, SAMPLER_POOL]
		"stabilizer":
			return "同一列的巢能多贴 %d 个词条" % l.slots
		"gene_bank":
			return "贴词条少花 %d 基因" % l.gene_off
		"mine", "forge":
			return "每轮多 %d 金币" % l.gold
		"vault":
			return "利息最多多 %d（每存 %d 金，利息 +1）" % [l.interest, INTEREST_STEP]
		"market":
			return ("每轮头两次刷新不要钱" if int(l.rerolls) > 1 else "每轮第一次刷新不要钱") + ("，商店多摆 1 样" if l.has("shelf") else "")
		"champion_hall":
			return "所有精英兵的血和攻击再 +%d%%" % l.elite
		"watchtower":
			return "所有远程兵（够得着 3 米以上）每下多 %d 点伤害，不管护甲" % l.ranged
		"vanguard":
			return "前排的兵血 +%d%%" % l.front
	return ""


## What a building does at a level, in short -- what changes when it is raised: for a nest, the choice.
static func level_text(kind: String, lv: int) -> String:
	if BUILDINGS[kind].has("nest"):
		return "二选一：多孵 1 只，或者变精英（血 ×%s、攻击 ×%s、大一号）" % [_num(ELITE_HP), _num(ELITE_ATK)]
	return building_text(kind, lv)


static func _num(x: float) -> String:
	return ("%d" % x) if is_equal_approx(x, roundf(x)) else str(snappedf(x, 0.01))


## What an offer does, in the player's words.
static func offer_text(o: Dictionary) -> String:
	match o.type:
		"build":
			var lv := int(o.get("level", 1))
			var text: String = BUILDINGS[o.builds].name + "：" + building_text(o.builds, lv) + "。"
			if o.has("level"):
				var sp := species(BUILDINGS[o.builds].get("nest", ""), o.affixes)
				text = "%d 级%s：%s。" % [lv, BUILDINGS[o.builds].name, building_text(o.builds, lv)]
				if not o.affixes.is_empty():
					text += "贴着" + "、".join(o.affixes.map(func(a: String) -> String: return AFFIXES[a].name)) + "。"
				if sp.used.size() > 0:
					text += "孵的是%s。" % UNITS[sp.kind].name
			return text
		"raise":
			return "一座建筑升一级（最多 %d 级）。巢升级时二选一：多孵 1 只，或者变精英。几级升上去，就多花几金币。" % LEVEL_MAX
		"affix":
			var a: Dictionary = AFFIXES[o.affix]
			var also := ""
			for r in RECIPES:
				if o.affix in r.affixes:
					also = "有的词条凑在一起，会进化出新物种。"
			return "给一个巢贴上%s：它孵的兵%s。%s" % [a.name, a.says, also]
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
	s.heal = roundi(float(base.get("heal", 0)) * float(spec.get("atk_mult", 1.0)))
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


## Who comes in round `r` (1-based) of `level`: a list of kinds, as strong all told as the place's share of LIMIT (and
## more in a big round) -- the boss in the last round, then each kind of the mix its share, the strongest first, the
## weakest making up what is left.
static func wave(level: int, r: int) -> Array:
	var lv: Dictionary = LEVELS[level]
	var g := r
	for i in level:
		g += int(LEVELS[i].rounds)
	var power := float(lv.power)
	var budget := float(LIMIT[clampi(g, 1, LIMIT.size()) - 1]) * float(lv.share) * (BIG if r in BIG_ROUNDS else 1.0)
	var out: Array = []
	if r >= int(lv.rounds) and lv.has("boss"):
		out.append(lv.boss)
		budget -= enemy_strength(lv.boss, power)
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
