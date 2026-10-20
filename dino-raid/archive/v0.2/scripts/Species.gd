class_name Species
## Who each dinosaur is, and the instincts that move it -- the player never orders one, so these are the
## whole of its behaviour. (What hatches them is a card: Cards.)
##
##   diet     "meat": goes for a robot it sees, follows the smell of meat, looks into a noise.
##            "plant": grazes; bolts from a noise and tramples what is in its way.
##   small    a small hunter: keeps clear of a tyrannosaur.
##   apex     eats small hunters when there is nothing better.
##   temper   a plant-eater hurt: "fight" turns on what hurt it, "flee" bolts.
##   sight    metres it sees a robot at; smell: metres it smells meat at.
##   walk/run metres a second it moves at; paces: the speeds its clips are drawn at (default DRAWN).
##   trample  damage it does to each robot it runs into while bolting.
##
## The models are life-size (common/assets/models/dinos).

const DRAWN := {"walk": 1.6, "run": 4.0}

const ALL := {
	"coelophysis": {"name": "腔骨龙", "diet": "meat", "small": true,
		"hp": 45, "bite": 8, "bite_every": 0.5, "walk": 1.4, "run": 6.0, "sight": 9.0, "smell": 26.0},
	"dakotaraptor": {"name": "达科塔盗龙", "diet": "meat", "small": true,
		"hp": 140, "bite": 16, "bite_every": 0.6, "walk": 1.8, "run": 7.0, "sight": 10.0, "smell": 30.0},
	"ceratosaurus": {"name": "角鼻龙", "diet": "meat",
		"hp": 380, "bite": 40, "bite_every": 1.0, "walk": 1.6, "run": 5.5, "sight": 11.0, "smell": 30.0},
	"tyrannosaurus": {"name": "霸王龙", "diet": "meat", "apex": true,
		"hp": 950, "bite": 90, "bite_every": 1.5, "walk": 1.8, "run": 5.0, "sight": 14.0, "smell": 36.0},
	"triceratops": {"name": "三角龙", "diet": "plant", "temper": "fight",
		"hp": 700, "bite": 45, "bite_every": 1.2, "walk": 1.2, "run": 5.0, "trample": 90,
		"paces": {"walk": 0.8, "run": 2.4}},
	"stegosaurus": {"name": "剑龙", "diet": "plant", "temper": "fight",
		"hp": 560, "bite": 40, "bite_every": 1.4, "walk": 0.9, "run": 2.6, "trample": 60,
		"paces": {"walk": 0.6, "run": 1.2}},
	"edmontosaurus": {"name": "埃德蒙顿龙", "diet": "plant", "temper": "flee",
		"hp": 320, "bite": 0, "bite_every": 1.0, "walk": 1.0, "run": 3.0, "trample": 55,
		"paces": {"walk": 0.6, "run": 1.4}},
	"diplodocus": {"name": "梁龙", "diet": "plant", "temper": "fight",
		"hp": 1600, "bite": 60, "bite_every": 2.0, "walk": 0.8, "run": 2.2, "trample": 160,
		"paces": {"walk": 0.5, "run": 1.0}},
}


static func scene_path(kind: String) -> String:
	return "res://common/assets/models/dinos/%s.gltf" % kind
