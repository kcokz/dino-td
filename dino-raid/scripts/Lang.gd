class_name Lang
## The game's languages (GAME-DESIGN 23): Chinese, as it is written, and English. Every word the player reads is
## written in Chinese in the scripts; that Chinese is the key, and EN is what it is in English. A control showing
## words straight from a script is put into the language by Godot on its own; words put together at play (with
## numbers in them) or drawn by hand go through t() first. Settings keeps the choice (Settings.language).

const LOCALES := {"zh": "中文", "en": "English"}

const EN := {
	# Cards: rarity, tokens, footers.
	"普通": "Common", "少见": "Uncommon", "稀有": "Rare", "已买": "Bought", "带": "Take", "存": "Kept", "去掉": "Remove",
	"巢 · 阵地": "Nest · battle line", "后方": "Rear", " · ": " · ", "「%s」": "\"%s\"",
	# Our units.
	"红兵": "Red Raptor", "前排，打得快": "Front row, strikes fast",
	"蓝兵": "Blue Spitter", "后排，远处打": "Back row, strikes from afar",
	"绿兵": "Green Shield", "前排，挡刀": "Front row, takes the blows",
	"金兵": "Gold Crusher", "重击，一打一片": "Heavy blows that hit an area",
	"白兵": "White Mender", "给受伤的同伴回血": "Heals hurt allies",
	"拾荒兽": "Scavenger", "远处扔石头，打得弱": "Throws stones from afar, weak",
	"变异兽": "Mutant", "底子弱，好贴词条": "Weak, but takes affixes well",
	"猎鹰兽": "Falcon", "进化来的：飞过前排，专咬后排": "Evolved: flies over the front, bites the back row",
	"雷甲兽": "Thunderback", "进化来的：又硬，又电一圈": "Evolved: tough, shocks all around it",
	"毒雾兽": "Miasma Beast", "进化来的：远处喷毒雾，不管护甲": "Evolved: sprays poison from afar, ignores armour",
	"熔岩兽": "Magma Beast", "进化来的：重击，倒下时炸一圈": "Evolved: heavy blows, bursts when it falls",
	"巨兽": "Titan", "巨兽笼里放出来的：又大又狠": "Let out of the Titan Cage: huge and fierce",
	# Their monsters.
	"灰怪": "Grey Crawler", "紫怪": "Purple Crawler", "黑怪": "Black Crawler", "孢子虫": "Spore Bug", "小螨": "Mite",
	"母虫": "Brood Mother", "熔岩甲虫": "Lava Beetle", "火蜥": "Fire Newt", "熔岩巨兽": "Lava Colossus",
	"巨颚虫": "Great Jaw", "熔岩守卫": "Lava Warden", "刺背虫": "Spineback", "火山巨蜥": "Volcano Monitor",
	"泥蛭": "Mud Leech", "毒蛾": "Venom Moth", "沼泽巨蛙": "Bog Frog", "毒囊蟾": "Poison-Sac Toad", "沼母": "Bog Mother",
	"霜牙": "Frostfang", "冰晶怪": "Ice Shard", "冰甲巨虫": "Ice-Shell Grub", "雪原狂兽": "Snow Berserker",
	"冰巢女王": "Ice Hive Queen", "沙虫": "Sandworm", "蝎怪": "Scorpion", "巨沙虫": "Great Sandworm",
	"毒尾蝎王": "Venomtail King", "沙暴巨兽": "Sandstorm Colossus", "甲蟹": "Shell Crab", "水母怪": "Jelly",
	"巨钳蟹": "Great Claw Crab", "海蛇怪": "Sea Serpent", "深海母巢": "Deep Hive",
	# The nests' gifts.
	"成群": "Swarm", "上下左右挨着红巢": "beside a Red Nest, any side", "多孵 1 只": "hatches 1 more",
	"挨着红巢，多孵 1 只": "Beside a Red Nest: hatches 1 more",
	"护住一列": "Guard", "站第一排": "in the front row",
	"怪要先打倒它，才打得着它身后同一列的兵": "monsters must fell it before they reach the units behind it in its column",
	"站第一排，护住身后同一列的兵": "In the front row: guards the units behind it in its column",
	"掩护射击": "Covering Fire", "站第二排、身前同一列有巢": "in the second row, a nest in front of it",
	"远程的兵射得远 2 米，每下多 1，不管护甲": "ranged units reach 2 m further and deal 1 more a hit, through armour",
	"站第二排、身前有巢挡着：射得更远，每下多 1": "Second row behind a nest: reaches further, 1 more a hit",
	"独当一面": "Lone Champion", "同一排左右都没有巢": "no nest left or right of it in its row",
	"大一号，血和攻击 +30%": "bigger, +30% health and attack", "左右都没有巢：大一号，血和攻击 +30%": "No nest left or right: bigger, +30% health and attack",
	"照料": "Tend", "只给同一列的兵回血，回得多一倍": "heals only its own column, twice as much",
	"拾荒": "Scavenge", "打完仗还站着的，每只带回 2 金（输了也算）": "each one still standing after a battle brings back 2 gold (lost or won)",
	"打完仗还站着的，每只带回 2 金": "Each one standing after a battle brings back 2 gold",
	"变异": "Mutate", "多 1 个词条位，好凑配方进化": "one more affix slot, to complete a recipe and evolve",
	"多 1 个词条位": "One more affix slot",
	# Buildings.
	"红巢": "Red Nest", "蓝巢": "Blue Nest", "绿巢": "Green Nest", "金巢": "Gold Nest", "白巢": "White Nest",
	"拾荒巢": "Scavenger Nest", "变异巢": "Mutant Nest", "培养池": "Culture Pool", "孢子池": "Spore Pool",
	"兽群图腾": "Horde Totem", "采样站": "Sampler", "稳定器": "Stabilizer", "基因库": "Gene Bank", "矿场": "Mine",
	"熔炉": "Forge", "金库": "Vault", "商栈": "Trading Post", "冠军殿": "Champion Hall", "瞭望塔": "Watchtower",
	"前锋营": "Vanguard Camp",
	# Schools.
	"攒钱流": "Hoarder", "金币多、利息多、刷新便宜；攒够了造奇观": "More gold, more interest, cheap restocks; save up for a wonder",
	"进化流": "Evolver", "研究点数多、词条位多、词条便宜；凑配方进化": "More research, more affix slots, cheap affixes; evolve by recipe",
	"兽群流": "Horde", "生物质多，兵多；兵越多，全体越狠": "More biomass, more units; the more there are, the fiercer all of them",
	"精英流": "Elite", "巢升级选精英；精英越来越强": "Raise nests to elite; elites grow ever stronger",
	"远程流": "Ranged", "蓝兵、酸液腺；远程的兵越打越狠": "Blue Spitters, acid glands; ranged units hit harder and harder",
	"前锋流": "Vanguard", "前排放肉；前排的兵越来越厚": "Tough units up front; the front row grows ever thicker",
	# Affixes.
	"甲壳": "Carapace", "护甲 +1": "Armour +1", "刀锋": "Blades", "攻击 +2": "Attack +2",
	"酸液腺": "Acid Gland", "变成远程，够得着 5 米": "Becomes ranged, reaches 5 m",
	"翅膀": "Wings", "会飞，越过前排去打后排": "Flies over the front row to strike the back",
	"电浆囊": "Plasma Sac", "一打一片（旁边 1.5 米挨一半）": "Hits an area (half within 1.5 m)",
	"毒刺": "Venom Sting", "每下多 2 点伤害，不管护甲": "2 more damage a hit, through armour",
	"火焰": "Flame", "攻击 +1，一打一片（1.2 米）": "Attack +1, hits an area (1.2 m)",
	"急速腺": "Haste Gland", "打得快 30%": "Strikes 30% faster",
	"厚皮": "Thick Hide", "血多 40%": "40% more health",
	"冲锋角": "Charging Horn", "开战第一下打双倍": "First blow of a battle hits double",
	# Wonders.
	"母巢": "Brood Hive", "每个巢每轮多孵 1 只": "Every nest hatches 1 more each round",
	"黄金城": "City of Gold", "每轮多 6 金币": "6 more gold each round",
	"进化之塔": "Tower of Evolution", "每个巢多 1 个词条位；贴词条不花研究点数": "Every nest has 1 more affix slot; affixes cost no research",
	"万兽战旗": "Banner of Beasts", "所有兵攻击 +2，血 +25%": "All units attack +2, health +25%",
	"巨兽笼": "Titan Cage", "每轮多一只巨兽出战，站前排正中": "A Titan joins every battle, in the middle of the front row",
	# Kinds of goods.
	"扩建": "Raise", "建筑": "Building", "升级": "Raise", "基因词条": "Gene Affix",
	# Relics.
	"琥珀": "Amber", "商店每轮多摆 1 样": "The shop shows 1 more each round",
	"霸王龙的牙": "T. rex Tooth", "贴词条少花 1 研究点数": "Affixes cost 1 less research",
	"三角龙的颈盾": "Triceratops Frill", "家园血 +10，每轮回 1 血": "Homeland health +10, heals 1 each round",
	"菊石": "Ammonite", "利息最多多 2": "Interest can be 2 higher",
	"粪化石": "Coprolite", "每轮生物质 +3": "Biomass +3 each round",
	"硅化木": "Petrified Wood", "造建筑便宜 1 金币": "Buildings cost 1 gold less",
	"三叶虫": "Trilobite", "每轮第一次刷新商店不要钱": "The first restock each round is free",
	"恐龙蛋化石": "Fossil Egg", "每轮第一个巢多孵 1 只，不吃生物质": "The first nest hatches 1 more each round, eating no biomass",
	"母虫的核": "Brood Core", "每个巢多孵 1 只；但生物质产量少三成": "Every nest hatches 1 more; but biomass income is 30% lower",
	"熔岩之心": "Heart of Lava", "每个巢多 1 个词条位；但家园每轮掉 1 血": "Every nest has 1 more affix slot; but the homeland loses 1 health each round",
	"古老的晶簇": "Ancient Crystal", "每轮多 4 金币；但商店少摆 1 样": "4 more gold each round; but the shop shows 1 fewer",
	"虫后的卵囊": "Queen's Egg Sac", "存货多 2 格；但每轮的牌只剩二选一": "2 more stash slots; but each round's card is one of two",
	# Arks.
	"战斗方舟": "War Ark", "开局：2 级红巢、培养池。带着霸王龙的牙（贴词条少花 1 研究点数）": "Starts with: a level 2 Red Nest, a Culture Pool. Carries the T. rex Tooth (affixes cost 1 less research)",
	"繁殖方舟": "Brood Ark", "开局：红巢、两座培养池。带着恐龙蛋化石": "Starts with: a Red Nest, two Culture Pools. Carries the Fossil Egg",
	"商队方舟": "Trade Ark", "开局：红巢、培养池、矿场，多 5 金币。带着琥珀": "Starts with: a Red Nest, a Culture Pool, a Mine, 5 more gold. Carries the Amber",
	# Places, their rules, their ground.
	"雨林": "Rainforest", "火山": "Volcano", "沼泽": "Swamp", "冰原": "Ice Fields", "荒漠": "Desert", "海岸": "Coast",
	"潮湿": "Damp", "生物质产量多五成，但存着的生物质每轮烂掉一半": "Biomass income +50%, but half the stored biomass rots each round",
	"火山灰": "Ashfall", "升级便宜 1 金币，但家园每轮掉 1 血": "Raises cost 1 gold less, but the homeland loses 1 health each round",
	"瘴气": "Miasma", "生物质产量多五成，但兵中了瘴气，出战时血少一成半": "Biomass income +50%, but units breathe miasma: 15% less health in battle",
	"严寒": "Frost", "金币每轮多 2，但兵冻得打得慢一成半": "2 more gold each round, but units are chilled: 15% slower blows",
	"干旱": "Drought", "研究点数每轮多 2，但缺水，生物质产量少三成": "2 more research each round, but little water: biomass income 30% lower",
	"潮汐": "Tides", "单数轮退潮，海滩上捡到 3 金；双数轮涨潮，最后一排的建筑那一轮不产东西": "Odd rounds, low tide: 3 gold found on the beach; even rounds, high tide: the last row's buildings bring in nothing",
	"水塘": "Pond", "培养池、孢子池造在这里，生物质翻倍": "A Culture or Spore Pool built here makes double biomass",
	"古树": "Old Tree", "不能造。旁边的采样站每轮多 1 研究点数": "Nothing can be built. A Sampler beside it makes 1 more research",
	"矿脉": "Ore Vein", "矿场、熔炉造在这里，金币 +2": "A Mine or Forge built here makes 2 more gold",
	"岩浆": "Lava Pool", "不能造。旁边的矿场、熔炉每轮多 1 金币": "Nothing can be built. A Mine or Forge beside it makes 1 more gold",
	"泥塘": "Mire", "毒菇林": "Toadstools", "冰矿": "Ice Ore", "冰封遗骸": "Frozen Remains", "绿洲": "Oasis", "遗迹": "Ruins",
	"潮池": "Tide Pool", "沉船": "Wreck",
	# Card texts.
	"%d 级": "level %d", "精英": "elite", "（%s）": " (%s)", "，": ", ", "孵%s。本事「%s」：%s": "Hatches %s. Gift \"%s\": %s",
	"每轮产 %d 生物质": "Makes %d biomass a round", "出战的兵每满 %d 只，所有兵攻击 +1": "For every %d units in battle, all attack +1",
	"每轮产 %d 研究点数。旁边每有一个培养池，再多 %d": "Makes %d research a round; %d more for each Culture Pool beside it",
	"同一列的巢能多贴 %d 个词条": "Nests in its column take %d more affixes", "贴词条少花 %d 研究点数": "Affixes cost %d less research",
	"每轮多 %d 金币": "%d more gold a round", "利息最多多 %d（每存 %d 金，利息 +1）": "Interest can be %d higher (1 more for every %d gold kept)",
	"每轮头两次刷新不要钱": "The first two restocks each round are free", "每轮第一次刷新不要钱": "The first restock each round is free",
	"，商店多摆 1 样": ", the shop shows 1 more", "所有精英兵的血和攻击再 +%d%%": "All elite units +%d%% health and attack",
	"所有远程兵（够得着 3 米以上）每下多 %d 点伤害，不管护甲": "All ranged units (reach 3 m or more) deal %d more a hit, through armour",
	"前排的兵血 +%d%%": "Front-row units +%d%% health",
	"二选一：多孵 1 只，或者变精英（血 ×%s、攻击 ×%s、大一号）": "One of two: hatch 1 more, or turn elite (health ×%s, attack ×%s, bigger)",
	"孵%s。%s。": "Hatches %s. %s.", "。": ". ", "放下就是 2 级（多孵或精英，二选一）。": "Goes down at level 2 (hatch more or elite, one of two). ",
	"放下就是 2 级。": "Goes down at level 2. ", "%d 级。": "Level %d. ", "孵%s。": "Hatches %s. ", "贴着": "wearing ", "、": ", ",
	"便宜 %d 金。": "%d gold cheaper. ", "一座建筑升一级（最多 %d 级）。巢升级二选一：多孵 1 只，或变精英。": "A building one level up (at most %d). A nest: hatch 1 more, or turn elite. ",
	"能凑配方。": "Can complete a recipe. ", "不花研究点数。": "Costs no research. ", "孵的兵%s。%s": "Its units: %s. %s",
	# Floating words.
	"+%d 金": "+%d gold", "冲锋！": "Charge!", "炸！": "Boom!", "退 %d 金": "%d gold back", "精英！": "Elite!", "进化！%s": "Evolved! %s",
	"存起来了": "Kept", "%s 造好了！": "%s built!", "装满了：最多 %d 样，先放下一样": "Full: %d at most -- put one down first",
	# The changes a good would make.
	"%+d 只": "%+d units", "%s本事「%s」": "%s gift \"%s\"", "进化：": "Evolves: ", "血 %+d%%": "Health %+d%%", "攻击 %+d": "Attack %+d",
	"快 %+d%%": "Speed %+d%%", "词条位 %+d": "Affix slots %+d", "金币": "Gold", "/轮": "/round", "生物质": "Biomass",
	"研究点数": "Research", "利息上限": "Interest cap", "家园血": "Homeland health",
	# Hints while a good is held.
	"选一样：多孵 1 只，还是变精英 · 右键算了": "Choose: hatch 1 more, or turn elite · right-click to cancel",
	"现在没有地方放得下": "Nowhere it can go now",
	"拆掉%s，放下%s（退 %d 金）· 右键放回去": "Pull down %s, put down %s (%d gold back) · right-click to put it back",
	"点一块地放下%s（已经是你的，不要钱）· 右键放回去": "Click a plot to put down %s (yours already, free) · right-click to put it back",
	"点一个还有空词条位的巢贴上%s（不要钱）· 右键放回去": "Click a nest with a free affix slot to give it %s (free) · right-click to put it back",
	"研究点数不够（要 %d）": "Not enough research (needs %d)", "金币不够（要 %d）": "Not enough gold (needs %d)",
	"现在没有地方用得上": "Nowhere it can be used now",
	"金币不够升任何一座（升几级的，就要几加 %d）": "Not enough gold to raise any (a building at level N costs N + %d)",
	"拆掉%s换成%s（%d 金，退 %d 金）": "Pull down %s for %s (%d gold, %d back)",
	"点一块空地造%s（%d 金）；点一座别的建筑，就拆了换成它": "Click an empty plot to build %s (%d gold), or a building to replace it",
	"%s升到 %d 级（%d 金）%s": "%s to level %d (%d gold)%s", "，点了再选多孵还是精英": ", then choose: hatch more or elite",
	"点一座建筑升一级（最多 %d 级；几级升上去，就要几加 %d 金）": "Click a building to raise it (at most level %d; a building at level N costs N + %d gold)",
	"点一个还有空词条位的巢（%d 金）": "Click a nest with a free affix slot (%d gold)", "；或点左下的空格存起来（%d 金）": "; or keep it in the slot at the bottom left (%d gold)",
	" · 右键放下": " · right-click: let go",
	# Pointed at: plots, units, nests.
	"阵地（%s）：只能造巢。巢造在这里，它孵的兵打仗时就站在这里": "Battle line (%s): nests only. Units stand here in battle, where their nest is",
	"前排": "front row", "后排": "back row", "后方：巢以外的建筑造在这里": "Rear: buildings other than nests go here",
	"\n建在%s上：%s": "\nBuilt on %s: %s", "点一下：留下，不带走\n": "Click: leave it behind\n", "点一下：带走\n": "Click: take it along\n",
	"巨兽笼放出来的": "From the Titan Cage", "%s %d 级孵的": "Hatched by a %s, level %d",
	"%s%s（%s，站%s）": "%s%s (%s, in the %s)",
	"血 %d · 攻击 %d · %s 秒打一下 · 够得着 %s 米": "Health %d · attack %d · a blow every %s s · reach %s m",
	"护甲 %d": "armour %d", "每下多 %d，不管护甲": "%d more a hit, through armour", "一打一片（%s 米）": "hits an area (%s m)",
	"每下回血 %d": "heals %d a blow", "倒下时炸一圈（%d）": "bursts when it falls (%d)", "会飞，打后排": "flies, strikes the back row",
	"开战第一下双倍": "first blow double", "护住身后同一列": "guards its column", "身前有绿兵护着": "guarded by a Green Shield in front",
	"只给同一列回血": "heals its own column only", "打完还站着，带回 %d 金": "standing at the end: brings back %d gold",
	"吃 %d 生物质，只活这一仗": "eats %d biomass, lives this battle only",
	"只活这一仗（恐龙蛋化石多孵的，不吃生物质）": "Lives this battle only (an extra from the Fossil Egg, eats no biomass)",
	"%s · %d 级": "%s · level %d", "进化了：孵的是%s（%s）": "Evolved: hatches %s (%s)",
	"孵%s：%s（每只吃 %d 生物质）": "Hatches %s: %s (each eats %d biomass)", "生效": "working", "没生效（%s）": "not working (%s)",
	"本事「%s」%s：%s": "Gift \"%s\" %s: %s", "这一轮孵 %d 只%s，打仗时站%s": "Hatches %d this round%s, standing in the %s in battle",
	"（生物质不够，少 %d）": " (short of biomass: %d fewer)", "精英%s：血 ×%s、攻击 ×%s、大一号": "Elite%s: health ×%s, attack ×%s, bigger",
	"冠军殿：精英再 +%d%%": "Champion Hall: elites +%d%%", "前锋营：前排血 +%d%%": "Vanguard Camp: front row +%d%% health",
	"瞭望塔：每下多 %d，不管护甲": "Watchtower: %d more a hit, through armour", "词条：%s（还能贴 %d 个）": "Affixes: %s (room for %d more)",
	"没有": "none", "再贴上%s，会进化成%s": "With %s as well, it evolves into %s", "升到 %d 级：%s": "At level %d: %s",
	"多孵 1 只，或者变精英": "hatch 1 more, or turn elite",
	"兽群：出战 %d 只，全体攻击 +%d；再多 %d 只 +%d": "Horde: %d in battle, all attack +%d; %d more for +%d",
	"冠军殿：精英 +%d%%": "Champion Hall: elites +%d%%", "瞭望塔：远程每下多 %d，不管护甲": "Watchtower: ranged %d more a hit, through armour",
	"万兽战旗：全体攻击 +2、血 +25%": "Banner of Beasts: all attack +2, health +25%",
	# A round's banners and what comes in.
	"进账，商店换货，孵兵": "Income, a new shelf, hatching",
	"新地方。带来的东西在左下，点它放下；新放的池子下一轮才产生物质": "A new place. What you brought is at the bottom left: click to put it down; pools put down now make biomass from next round",
	"首领来了": "The boss is coming", "小首领来了。打完可以整理牌库": "A mini-boss is coming. Afterwards you can work on your deck",
	"大波要来了": "A big wave is coming", "%s · 第 %d 轮": "%s · round %d", "金币 +%d": "Gold +%d", "生物质 +%d": "Biomass +%d",
	"研究点数 +%d": "Research +%d", "潮湿：生物质烂了 %d": "Damp: %d biomass rotted", "火山灰：家园 −%d": "Ashfall: homeland −%d",
	"颈盾：家园 +%d": "Frill: homeland +%d", "开战": "Battle", "我方 %d 只，敌方 %d 只": "Ours %d, theirs %d",
	"拾荒 +%d 金": "Scavenged +%d gold", "利息 +%d": "Interest +%d", "赢了！": "Won!", "得到：": "Gained: ",
	"拖到时间，算输": "Out of time: a loss", "家园 −%d": "Homeland −%d", "输了": "Lost",
	"家园被毁了……": "The homeland has fallen…", "撑到了%s第 %d 轮": "Held out to %s, round %d", "再来一局": "Play again",
	"回主菜单": "Main menu", "全部守住了！": "All held!", "%s都撑过来了，家园还剩 %d 血": "%s all held, the homeland at %d health",
	"再玩一遍": "Play again", "挑一张，加进牌库": "Pick a card for your deck",
	"以后商店会从牌库里拿出来卖，照原价买": "The shop will draw it from your deck, at its usual price",
	"不要牌，拿 %d 金": "No card: take %d gold",
	# What a nest's gift lacks.
	"还差 %d 个红巢挨着": "needs %d more Red Nest beside it", "要站第一排": "must stand in the front row",
	"要站第二排": "must stand in the second row", "身前同一列还没有巢": "no nest in front of it yet", "左右有巢挨着": "a nest beside it",
	# The panel and the buttons.
	"生物质：每轮产多少，出战的兵要吃": "Biomass: made each round, eaten by the units that fight",
	"研究点数：贴词条、强化牌要花": "Research: spent on affixes and upgrading cards",
	"奇观（一局只能造一座）": "Wonders (one a run)", "%s · %d 金": "%s · %d gold", "刷新": "Restock", "牌库": "Deck",
	"出战！": "Fight!", "菜单": "Menu", "快进": "Fast", "正常": "Normal", "这个巢升级：": "Raise this nest:",
	"变精英（血 ×%s、攻击 ×%s、大一号）": "Turn elite (health ×%s, attack ×%s, bigger)", "%s（%s）\n%s": "%s (%s)\n%s",
	"首领遗物": "Boss relic", "化石遗物": "Fossil relic",
	"%s（奇观）\n%s\n%d 金。一局只能造一座，搬家也带着%s": "%s (wonder)\n%s\n%d gold. One a run, it moves with the ark%s",
	"（还差 %d 金）": " (%d gold short)", "我方 %d  对  敌方 %d   ·   还剩 %d 秒": "Ours %d  vs  theirs %d   ·   %d s left",
	"出发！": "Set off!", "刷新（%s）": "Restock (%s)", "免费": "free", "%d 金": "%d gold", "%s · 第 %d / %d 轮": "%s · round %d / %d",
	"%s：%s": "%s: %s", "%d（+%d）": "%d (+%d)", "这一轮出战 %d 只，吃 ": "%d units fight this round, eating ",
	"牌库（%d 张）": "Deck (%d)", "奇观：%s（已造）": "Wonder: %s (built)", "带走 %d / %d": "Taking %d / %d",
	"存货 %d / %d": "Stash %d / %d",
	"搬家去%s！点建筑和存货，选要带走的（最多 %d 样，已选 %d）\n金币、生物质、研究点数、牌库全带上，没选的留在这里。选好了点「出发！」": "Moving to %s! Click buildings and stash goods to choose what to take (%d at most, %d chosen)\nGold, biomass, research and the deck all come along; the rest stays. When ready, click \"Set off!\"",
	"到了那边（算上方舟自带的红巢和培养池）：兵每轮要吃 %d 生物质，池子每轮产 %d%s": "Over there (with the ark's own Red Nest and Culture Pool): units eat %d biomass a round, pools make %d%s",
	"——不够吃": " -- not enough", "这一仗": "This battle", "下一仗": "Next battle", "（首领）": " (boss)", "（小首领）": " (mini-boss)",
	"（大波）": " (big wave)", "这样以后，这一仗会：": "After this, the battle will be:", "照现在这样，这一仗会：": "As things stand, the battle will be:",
	"拾荒兽带回 %d 金%s": "Scavengers bring back %d gold%s", "（现在 %d）": " (now %d)", "现在是：": "Now: ",
	"（每一仗都照规矩打，结果算得出来）": "(every battle follows the rules: its end can be worked out)",
	"赢，站着的还有 %d / %d 个": "Won, %d / %d still standing", "没有兵出战，家园 −%d": "No units fight: homeland −%d",
	"拖到时间算输，家园 −%d": "Out of time, a loss: homeland −%d", "输，家园 −%d": "Lost: homeland −%d",
	# Screens.
	"选一艘方舟": "Choose an ark", "方舟带着基因库出发，落到哪里，就在哪里建家园": "The ark sets out with its gene bank; wherever it lands, a homeland is built",
	"到了%s！": "Arrived: %s!", "撑过 %d 轮：第 %s 轮来小首领，最后一轮是首领": "Hold out for %d rounds: mini-bosses in rounds %s, the boss in the last",
	"阵地：家园最上面两排只能造巢。兵打仗时就站在巢的位置，最上面一排在最前": "Battle line: the homeland's top two rows take nests only. Units stand where their nest is; the top row is at the front",
	"开始": "Start", "%s守住了！": "%s held!", "选一件遗物，整局都有用。红边的是首领留下的：很强，但有代价": "Choose a relic for the rest of the run. Red-rimmed ones are a boss's: strong, at a cost",
	"首领遗物\n": "Boss relic\n", "化石遗物\n": "Fossil relic\n", "；": "; ",
	"商店每轮从这里抽货。每轮打完可以加一张；小首领打完可以删、可以强化": "The shop draws from here each round. After each round you may add a card; after a mini-boss, cut or upgrade",
	"关闭": "Close", "整理牌库": "Work on the deck",
	"删一张 %d 金（每删一张，下一张贵 %d 金）；强化一张 %d 研究点数。现在有 %d 金、%d 研究点数": "Cut a card: %d gold (each cut, the next costs %d more); upgrade one: %d research. You have %d gold, %d research",
	"删掉这张（%d 金）": "Cut this (%d gold)", "强化这张（%d 研究点数）": "Upgrade this (%d research)", "完成": "Done",
	"下一站去哪？": "Where next?", "越往右越难。选好了，再回家园挑要带走的东西": "Harder further right. Once chosen, pick what to take along at the homeland",
	"指着一处看看": "Point at a place", "去这里": "Go here", "第 %d 关": "Level %d", "方舟在这里": "The ark is here", "去%s": "Go to %s",
	"%s：%s\n\n%s\n\n会来：%s\n小首领：%s\n首领：%s": "%s: %s\n\n%s\n\nComing: %s\nMini-bosses: %s\nBoss: %s",
	"金币 · 每轮 +%d": "Gold · +%d a round", "存着，利息 +%d": "Kept: interest +%d", "存起来": "Keep", "家园 %d / %d": "Homeland %d / %d",
	# The title, the pause menu, settings, the codex.
	"基因方舟　·　异星虫群": "Gene Ark  ·  Alien Swarm", "开始新的一局": "New run", "图鉴": "Codex", "设置": "Settings",
	"退出游戏": "Quit", "退出游戏？": "Quit the game?", "暂停": "Paused", "继续": "Resume", "重新开始这一局": "Restart this run",
	"重新开始？这一局就不要了": "Restart? This run will be lost", "回主菜单？这一局就不要了": "Back to the main menu? This run will be lost",
	"退出游戏？这一局就不要了": "Quit? This run will be lost", "全屏": "Fullscreen", "音量": "Volume", "按钮声": "Button sounds",
	"开战就快进": "Fast battles", "返回": "Back", "算了": "Cancel", "确定": "OK", "开": "On", "关": "Off",
	"我们的兵": "Our units", "巢和建筑": "Nests & buildings", "遗物": "Relics", "怪物": "Monsters", "奇观": "Wonders",
	"%s孵的": "Hatched by the %s", "\n巢的本事「%s」：%s%s": "\nNest gift \"%s\": %s%s", "进化来的：%s + %s": "Evolved: %s + %s",
	"奇观巨兽笼放出来的": "Let out of the Titan Cage wonder", "不吃生物质": "eats no biomass", "每只吃 %d 生物质": "each eats %d biomass",
	" · 只在": " · only in ", "孵%s。\n本事「%s」：%s%s\n升级：多孵 1 只，或者变精英": "Hatches %s.\nGift \"%s\": %s%s\nRaise: hatch 1 more, or turn elite",
	"%d 级：%s": "Level %d: %s", "和%s凑在一个巢上：进化成%s": "With %s on one nest: evolves into %s",
	"%d 金 · %d 研究点数": "%d gold · %d research", "基因词条 · ": "Gene affix · ", "贴上的巢，孵的兵%s。%s": "A nest wearing it hatches units that: %s. %s",
	"首领遗物：很强，但有代价": "Boss relic: strong, at a cost", "%s的首领": "Boss of the %s", "%s的小首领": "Mini-boss of the %s",
	"%s倒下时裂出来": "Breaks out of a falling %s", "倒下时裂成 %d 只%s": "Breaks into %d %s when it falls",
	"打输时，每只还站着的让家园掉 %d 血": "Each one standing at a loss costs the homeland %d health", "异星虫群": "Alien swarm",
	"奇观 · %d 金 · 一局只能造一座": "Wonder · %d gold · one a run", "血 %d": "Health %d", "攻击 %d": "Attack %d",
	"%s 秒打一下": "a blow every %s s", "够得着 %s 米": "reach %s m", "带走": "Take", "留下": "Leave",
	"孵 %d%s": "Hatch %d%s", "少孵 %d": "%d fewer",
	# Language.
	"语言": "Language",
}

static var _english: Translation


## Puts the game into `code` ("zh" or "en"). The English table is with Godot only while the game is in English: Godot
## falls back to English for a language it has no table for, so Chinese would come out in English.
static func use(code: String) -> void:
	if _english == null:
		_english = Translation.new()
		_english.locale = "en"
		for k in EN:
			_english.add_message(k, EN[k])
	if code == "en":
		TranslationServer.add_translation(_english)
	else:
		TranslationServer.remove_translation(_english)
	TranslationServer.set_locale(code if LOCALES.has(code) else "zh")


## Words in the language the game is in (Chinese as it is when the game is in Chinese).
static func t(words: String) -> String:
	return TranslationServer.translate(words)


## Whether the game is in English.
static func english() -> bool:
	return TranslationServer.get_locale().begins_with("en")
